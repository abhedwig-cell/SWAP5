program test_f_romv2_d21_dynamic_top_provider_preflight
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, initialize_b110_default_mvg_parameters
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t, &
       b110_dynamic_top_boundary_result_t, evaluate_b110_dynamic_top_boundary, B110_DYN_TOP_AVAILABLE
  implicit none

  integer, parameter :: NN=16, NBINS=200, IBASE=100, J0=101, J1=199, NF=7
  real(real64), parameter :: TR=0.02_real64, TS=0.427494_real64
  real(real64), parameter :: ALPHA=0.021659_real64, NPAR=1.734737_real64
  real(real64), parameter :: KS=31.225016_real64, LAM=0.98087_real64
  real(real64), parameter :: DT=10.0_real64/86400.0_real64
  real(real64), parameter :: factors(NF)=[0.25_real64,0.5_real64,1.0_real64,2.0_real64,4.0_real64,8.0_real64,16.0_real64]

  type(soil_water_parameter_set_t) :: geometry
  type(b110_default_mvg_parameters_t) :: hp
  type(b110_dynamic_top_boundary_request_t) :: req
  type(b110_dynamic_top_boundary_result_t) :: res
  real(real64) :: cofgen(24,NN), theta_top, h_top, dtheta, pondmax, candidate, prev_candidate
  integer :: k,ifac,it,flux_idx,pond_idx,run_idx
  logical :: converged

  call initialize_geometry_and_hydraulics(geometry,hp,cofgen)
  call initial_top_state(theta_top,h_top)
  pondmax=KS*DT
  flux_idx=0;pond_idx=0;run_idx=0

  do ifac=1,NF
    candidate=0.0_real64
    converged=.false.
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
      prev_candidate=candidate
      call evaluate_b110_dynamic_top_boundary(geometry,hp,req,res)
      call require(res%status==B110_DYN_TOP_AVAILABLE,'D21 dynamic-top provider available')
      call require(all_finite(res),'D21 finite provider result')
      candidate=res%candidate_ponding_depth_cm
      if (same_bits(candidate,prev_candidate) .or. abs(candidate-prev_candidate)<=1.0e-14_real64) then
        converged=.true.
        exit
      end if
    end do
    call require(converged,'D21 provider candidate iteration converged')

    write(*,'(*(g0))') 'F_ROMV2_D21_PROVIDER|FACTOR=',factors(ifac),'|ROUTE=',trim(res%route), &
         '|POND_CM=',res%candidate_ponding_depth_cm,'|RUNOFF_CM=',res%runoff_depth_cm, &
         '|TOP_FLUX_NATIVE=',res%actual_top_flux_cm_per_day,'|SURFACE_HEAD=',res%surface_head_cm, &
         '|ITER=',it

    if (trim(res%route)=='surface-flux' .and. res%candidate_ponding_depth_cm==0.0_real64 .and. &
        res%runoff_depth_cm==0.0_real64) then
      if(flux_idx==0) flux_idx=ifac
    end if
    if (trim(res%route)=='ponded-head' .and. res%candidate_ponding_depth_cm>0.0_real64 .and. &
        res%runoff_depth_cm==0.0_real64) then
      if(pond_idx==0) pond_idx=ifac
    end if
    if (trim(res%route)=='ponded-head-linear-runoff' .and. res%candidate_ponding_depth_cm>pondmax .and. &
        res%runoff_depth_cm>0.0_real64) then
      if(run_idx==0) run_idx=ifac
    end if
  end do

  call require(flux_idx>0,'D21 flux regime exists')
  call require(pond_idx>0,'D21 ponded no-runoff regime exists')
  call require(run_idx>0,'D21 active runoff regime exists')
  call require(factors(flux_idx)<factors(pond_idx).and.factors(pond_idx)<factors(run_idx), &
       'D21 selected factors strictly ordered')

  write(*,'(*(g0))') 'F_ROMV2_D21_SELECTION|FLUX_FACTOR=',factors(flux_idx), &
       '|POND_FACTOR=',factors(pond_idx),'|RUNOFF_FACTOR=',factors(run_idx), &
       '|PONDING_MAX_CM=',pondmax,'|TOP_THETA=',theta_top,'|TOP_H_CM=',h_top
  write(*,'(A)') 'F_ROMV2_D21_PROVIDER_PREFLIGHT=PASS'

contains

  subroutine initialize_geometry_and_hydraulics(g,h,c)
    type(soil_water_parameter_set_t),intent(out) :: g
    type(b110_default_mvg_parameters_t),intent(out) :: h
    real(real64),intent(out) :: c(24,NN)
    real(real64) :: mm
    integer :: n
    mm=1.0_real64-1.0_real64/NPAR
    g%parameter_set_id=21001_int64
    g%active_nodes=NN
    allocate(g%z(NN),g%dz(NN),g%node_distance(NN))
    do n=1,NN
      g%z(n)=-10.0_real64*(real(n,real64)-0.5_real64)
    end do
    g%dz=10.0_real64
    g%node_distance=10.0_real64
    c=0.0_real64
    do n=1,NN
      c(1,n)=TR;c(2,n)=TS;c(3,n)=KS;c(4,n)=ALPHA;c(5,n)=LAM;c(6,n)=NPAR
      c(7,n)=mm;c(8,n)=ALPHA;c(9,n)=0.0_real64;c(10,n)=KS
      c(11,n)=0.999_real64;c(12,n)=0.99_real64*KS;c(22,n)=-1.0e6_real64;c(23,n)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(h,c)
  end subroutine initialize_geometry_and_hydraulics

  subroutine initial_top_state(theta,h)
    real(real64),intent(out) :: theta,h
    real(real64) :: zfront,overlap,mm,se,ztop,zbot
    integer :: j
    dtheta=(TS-TR)/real(NBINS,real64)
    theta=TR+real(IBASE,real64)*dtheta
    ztop=0.0_real64;zbot=10.0_real64
    do j=J0,J1
      zfront=120.0_real64+(10.0_real64-120.0_real64)*real(j-J0,real64)/real(J1-J0,real64)
      overlap=max(0.0_real64,min(zfront,zbot)-ztop)
      theta=theta+dtheta*overlap/10.0_real64
    end do
    call require(theta>TR.and.theta<TS,'D21 top theta bounds')
    mm=1.0_real64-1.0_real64/NPAR
    se=(theta-TR)/(TS-TR)
    h=-(se**(-1.0_real64/mm)-1.0_real64)**(1.0_real64/NPAR)/ALPHA
    call require(ieee_is_finite(h).and.h<0.0_real64,'D21 top inverse retention')
  end subroutine initial_top_state

  pure logical function all_finite(r) result(ok)
    type(b110_dynamic_top_boundary_result_t),intent(in) :: r
    real(real64) :: v(9)
    v=[r%actual_top_flux_cm_per_day,r%surface_head_cm,r%surface_face_conductivity_cm_per_day, &
       r%candidate_ponding_depth_cm,r%bare_soil_evaporation_cm_per_day,r%ponded_water_evaporation_cm_per_day, &
       r%runoff_depth_cm,r%net_potential_surface_flux_cm_per_day,r%evaporation_capacity_cm_per_day]
    ok=all(ieee_is_finite(v))
  end function all_finite

  pure logical function same_bits(a,b) result(eq)
    real(real64),intent(in)::a,b
    integer(int64)::ia,ib
    ia=transfer(a,ia);ib=transfer(b,ib);eq=ia==ib
  end function same_bits

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A)') 'F_ROMV2_D21_FAIL='//trim(msg)
      error stop 1
    end if
  end subroutine require
end program test_f_romv2_d21_dynamic_top_provider_preflight
