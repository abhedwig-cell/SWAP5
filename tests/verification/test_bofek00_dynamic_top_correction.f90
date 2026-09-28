program test_bofek00_dynamic_top_correction
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, initialize_b110_default_mvg_parameters
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t, &
       b110_dynamic_top_boundary_result_t, evaluate_b110_dynamic_top_boundary, B110_DYN_TOP_AVAILABLE
  implicit none

  integer, parameter :: NN=16, NBINS=200, IBASE=100, J0=101, J1=199
  real(real64), parameter :: TR=0.02_real64, TS=0.427494_real64
  real(real64), parameter :: ALPHA=0.021659_real64, NPAR=1.734737_real64
  real(real64), parameter :: KS=31.225016_real64, LAM=0.98087_real64
  real(real64), parameter :: DT=10.0_real64/86400.0_real64
  real(real64), parameter :: EPS=1.0e-6_real64

  type(soil_water_parameter_set_t) :: geometry
  type(b110_default_mvg_parameters_t) :: hp
  type(b110_dynamic_top_boundary_request_t) :: req
  type(b110_dynamic_top_boundary_result_t) :: r0, r1, rp, rm
  real(real64) :: cofgen(24,NN), theta_top, h_top, pondmax, fd, analytic, bp, bm
  real(real64) :: fixed_k
  integer :: factor

  call initialize_geometry_and_hydraulics(geometry,hp,cofgen)
  call initial_top_state(theta_top,h_top)
  pondmax=KS*DT
  fixed_k=KS

  do factor=2,4,2
    call make_request(req,real(factor,real64),h_top,theta_top,0.0_real64,fixed_k)
    call evaluate_b110_dynamic_top_boundary(geometry,hp,req,r0)
    call require(r0%status==B110_DYN_TOP_AVAILABLE,'provider available')
    call require(r0%surface_head_dpressure_available,'surface-head derivative available')

    req%pressure_head_top_cm=h_top+EPS
    call evaluate_b110_dynamic_top_boundary(geometry,hp,req,rp)
    req%pressure_head_top_cm=h_top-EPS
    call evaluate_b110_dynamic_top_boundary(geometry,hp,req,rm)

    bp=-rp%surface_face_conductivity_cm_per_day*((rp%surface_head_cm-(h_top+EPS))/geometry%node_distance(1)+1.0_real64)
    bm=-rm%surface_face_conductivity_cm_per_day*((rm%surface_head_cm-(h_top-EPS))/geometry%node_distance(1)+1.0_real64)
    fd=(bp-bm)/(2.0_real64*EPS)
    analytic=r0%surface_face_conductivity_cm_per_day/geometry%node_distance(1) * &
         (1.0_real64-r0%surface_head_dpressure)
    call require(relerr(fd,analytic)<=1.0e-7_real64,'finite-difference Jacobian match')

    write(*,'(*(g0))') 'BOFEK00_JAC|FACTOR=',factor,'|ROUTE=',trim(r0%route), &
         '|FD=',fd,'|ANALYTIC=',analytic,'|DHS_DH=',r0%surface_head_dpressure
  end do

  call make_request(req,4.0_real64,h_top,theta_top,0.0_real64,fixed_k)
  call evaluate_b110_dynamic_top_boundary(geometry,hp,req,r0)
  call make_request(req,4.0_real64,h_top,theta_top,2.0_real64*pondmax,fixed_k)
  call evaluate_b110_dynamic_top_boundary(geometry,hp,req,r1)
  call require(trim(r0%route)=='ponded-head-linear-runoff','zero seed selects analytical runoff')
  call require(trim(r1%route)=='ponded-head-linear-runoff','large seed selects analytical runoff')
  call require(abs(r0%candidate_ponding_depth_cm-r1%candidate_ponding_depth_cm)<=1.0e-14_real64, &
       'candidate ponding seed independent')
  call require(abs(r0%runoff_depth_cm-r1%runoff_depth_cm)<=1.0e-14_real64,'runoff seed independent')

  write(*,'(*(g0))') 'BOFEK00_BRANCH|ROUTE=',trim(r0%route),'|POND=',r0%candidate_ponding_depth_cm, &
       '|RUNOFF=',r0%runoff_depth_cm
  write(*,'(A)') 'F_PE_BOFEK00_DYNAMIC_TOP_CORRECTION=PASS'

contains

  subroutine make_request(r,factor,h,theta,candidate,fixed)
    type(b110_dynamic_top_boundary_request_t),intent(out) :: r
    real(real64),intent(in) :: factor,h,theta,candidate,fixed
    r=b110_dynamic_top_boundary_request_t()
    r%conductivity_mean_method=1
    r%pressure_head_top_cm=h
    r%water_content_top=theta
    r%candidate_ponding_depth_cm=candidate
    r%previous_ponding_depth_cm=0.0_real64
    r%step_duration_day=DT
    r%precipitation_rate_cm_per_day=factor*KS
    r%ponding_max_cm=pondmax
    r%runoff_resistance_day=0.001_real64
    r%runoff_exponent=1.0_real64
    r%fixed_top_node_conductivity_cm_per_day=fixed
  end subroutine make_request

  subroutine initialize_geometry_and_hydraulics(g,h,c)
    type(soil_water_parameter_set_t),intent(out) :: g
    type(b110_default_mvg_parameters_t),intent(out) :: h
    real(real64),intent(out) :: c(24,NN)
    real(real64) :: mm
    integer :: n
    mm=1.0_real64-1.0_real64/NPAR
    g%parameter_set_id=22001_int64
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
    real(real64) :: zfront,overlap,mm,se,ztop,zbot,dtheta
    integer :: j
    dtheta=(TS-TR)/real(NBINS,real64)
    theta=TR+real(IBASE,real64)*dtheta
    ztop=0.0_real64;zbot=10.0_real64
    do j=J0,J1
      zfront=120.0_real64+(10.0_real64-120.0_real64)*real(j-J0,real64)/real(J1-J0,real64)
      overlap=max(0.0_real64,min(zfront,zbot)-ztop)
      theta=theta+dtheta*overlap/10.0_real64
    end do
    mm=1.0_real64-1.0_real64/NPAR
    se=(theta-TR)/(TS-TR)
    h=-(se**(-1.0_real64/mm)-1.0_real64)**(1.0_real64/NPAR)/ALPHA
  end subroutine initial_top_state

  pure real(real64) function relerr(a,b) result(e)
    real(real64),intent(in)::a,b
    e=abs(a-b)/max(abs(a),abs(b),1.0e-30_real64)
  end function relerr

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A)') 'F_PE_BOFEK00_FAIL='//trim(msg)
      error stop 1
    end if
  end subroutine require
end program test_bofek00_dynamic_top_correction
