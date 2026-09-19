program test_f_romv2_d22_swap_threshold_response
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, initialize_b110_default_mvg_parameters
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t, &
       b110_dynamic_top_boundary_result_t, evaluate_b110_dynamic_top_boundary, B110_DYN_TOP_AVAILABLE
  implicit none
  integer, parameter :: NBINS=200, IBASE=100, J0=101, J1=199, NF=7
  real(real64), parameter :: TR=0.02_real64, TS=0.427494_real64, ALPHA=0.021659_real64
  real(real64), parameter :: NPAR=1.734737_real64, KS=31.225016_real64, LAM=0.98087_real64
  real(real64), parameter :: DT=10.0_real64/86400.0_real64
  real(real64), parameter :: factors(NF)=[0.25_real64,0.5_real64,1.0_real64,2.0_real64,4.0_real64,8.0_real64,16.0_real64]

  call run_grid('R16',16,10.0_real64)
  call run_grid('R2',2,80.0_real64)
  write(*,'(A)') 'F_ROMV2_D22_SWAP_RESPONSE=PASS'

contains

  subroutine run_grid(label,nnode,dzcm)
    character(len=*),intent(in)::label
    integer,intent(in)::nnode
    real(real64),intent(in)::dzcm
    type(soil_water_parameter_set_t)::g
    type(b110_default_mvg_parameters_t)::hp
    type(b110_dynamic_top_boundary_request_t)::req
    type(b110_dynamic_top_boundary_result_t)::res
    real(real64),allocatable::cof(:,:)
    real(real64)::theta_top,h_top,candidate,previous,pondmax,rain,infil,ledger
    integer::ifac,it
    logical::conv

    call setup(g,hp,cof,nnode,dzcm)
    call mapped_top_state(dzcm,theta_top,h_top)
    pondmax=KS*DT
    do ifac=1,NF
      candidate=0.0_real64;conv=.false.
      do it=1,32
        req=b110_dynamic_top_boundary_request_t()
        req%conductivity_mean_method=1
        req%pressure_head_top_cm=h_top
        req%water_content_top=theta_top
        req%candidate_ponding_depth_cm=candidate
        req%previous_ponding_depth_cm=0.0_real64
        req%step_duration_day=DT
        req%precipitation_rate_cm_per_day=factors(ifac)*KS
        req%ponding_max_cm=pondmax
        req%runoff_resistance_day=0.001_real64
        req%runoff_exponent=1.0_real64
        previous=candidate
        call evaluate_b110_dynamic_top_boundary(g,hp,req,res)
        call require(res%status==B110_DYN_TOP_AVAILABLE,'D22 provider available')
        call require(finite_result(res),'D22 finite provider result')
        candidate=res%candidate_ponding_depth_cm
        if(same_bits(candidate,previous).or.abs(candidate-previous)<=1.0e-14_real64)then
          conv=.true.;exit
        end if
      end do
      call require(conv,'D22 provider candidate iteration')
      rain=factors(ifac)*KS*DT
      infil=-res%actual_top_flux_cm_per_day*DT
      ledger=rain-infil-res%candidate_ponding_depth_cm-res%runoff_depth_cm
      call require(abs(ledger)<=1.0e-12_real64,'D22 surface ledger')
      write(*,'(*(g0))') 'F_ROMV2_D22_SWAP|GRID=',trim(label),'|FACTOR=',factors(ifac), &
           '|ROUTE=',trim(res%route),'|INFIL_CM=',infil,'|POND_CM=',res%candidate_ponding_depth_cm, &
           '|RUNOFF_CM=',res%runoff_depth_cm,'|LEDGER_CM=',ledger,'|TOP_THETA=',theta_top,'|TOP_H_CM=',h_top
    end do
  end subroutine run_grid

  subroutine setup(g,h,c,nnode,dzcm)
    type(soil_water_parameter_set_t),intent(out)::g
    type(b110_default_mvg_parameters_t),intent(out)::h
    real(real64),allocatable,intent(out)::c(:,:)
    integer,intent(in)::nnode
    real(real64),intent(in)::dzcm
    integer::n
    real(real64)::mm
    mm=1.0_real64-1.0_real64/NPAR
    g%parameter_set_id=22000_int64+int(nnode,int64);g%active_nodes=nnode
    allocate(g%z(nnode),g%dz(nnode),g%node_distance(nnode),c(24,nnode))
    do n=1,nnode
      g%z(n)=-dzcm*(real(n,real64)-0.5_real64)
    end do
    g%dz=dzcm;g%node_distance=dzcm;c=0.0_real64
    do n=1,nnode
      c(1,n)=TR;c(2,n)=TS;c(3,n)=KS;c(4,n)=ALPHA;c(5,n)=LAM;c(6,n)=NPAR;c(7,n)=mm
      c(8,n)=ALPHA;c(9,n)=0.0_real64;c(10,n)=KS;c(11,n)=0.999_real64;c(12,n)=0.99_real64*KS
      c(22,n)=-1.0e6_real64;c(23,n)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(h,c)
  end subroutine setup

  subroutine mapped_top_state(depth,theta_out,h_out)
    real(real64),intent(in)::depth
    real(real64),intent(out)::theta_out,h_out
    real(real64)::dtheta,zfront,overlap,se,mm,theta_i
    integer::j
    dtheta=(TS-TR)/real(NBINS,real64)
    theta_i=TR+real(IBASE,real64)*dtheta
    theta_out=theta_i
    do j=J0,J1
      zfront=120.0_real64+(10.0_real64-120.0_real64)*real(j-J0,real64)/real(J1-J0,real64)
      overlap=max(0.0_real64,min(zfront,depth))
      theta_out=theta_out+dtheta*overlap/depth
    end do
    call require(theta_out>TR.and.theta_out<TS,'D22 mapped top theta')
    mm=1.0_real64-1.0_real64/NPAR
    se=(theta_out-TR)/(TS-TR)
    h_out=-(se**(-1.0_real64/mm)-1.0_real64)**(1.0_real64/NPAR)/ALPHA
    call require(ieee_is_finite(h_out).and.h_out<0.0_real64,'D22 mapped top head')
  end subroutine mapped_top_state

  pure logical function finite_result(r) result(ok)
    type(b110_dynamic_top_boundary_result_t),intent(in)::r
    real(real64)::v(9)
    v=[r%actual_top_flux_cm_per_day,r%surface_head_cm,r%surface_face_conductivity_cm_per_day, &
       r%candidate_ponding_depth_cm,r%bare_soil_evaporation_cm_per_day,r%ponded_water_evaporation_cm_per_day, &
       r%runoff_depth_cm,r%net_potential_surface_flux_cm_per_day,r%evaporation_capacity_cm_per_day]
    ok=all(ieee_is_finite(v))
  end function finite_result
  pure logical function same_bits(a,b) result(eq)
    real(real64),intent(in)::a,b
    integer(int64)::ia,ib
    ia=transfer(a,ia);ib=transfer(b,ib);eq=ia==ib
  end function same_bits
  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then;write(*,'(A)')'F_ROMV2_D22_FAIL='//trim(msg);error stop 1;end if
  end subroutine require
end program test_f_romv2_d22_swap_threshold_response
