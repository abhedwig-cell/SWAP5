program test_bofek00_dynamic_top_correction
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
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
  real(real64), parameter :: EPS_H=1.0e-6_real64

  type(soil_water_parameter_set_t) :: geometry
  type(b110_default_mvg_parameters_t) :: hp
  real(real64) :: cofgen(24,NN), theta_top, h_top

  call initialize_geometry_and_hydraulics(geometry,hp,cofgen)
  call initial_top_state(theta_top,h_top)

  call check_route(2.0_real64*KS,'ponded-head',theta_top,h_top)
  call check_route(4.0_real64*KS,'ponded-head-linear-runoff',theta_top,h_top)
  call check_candidate_independence(4.0_real64*KS,theta_top,h_top)

  write(*,'(A)') 'F_PE_BOFEK00_DYNAMIC_TOP_CORRECTION=PASS'

contains

  subroutine make_request(req,rain,h,candidate)
    type(b110_dynamic_top_boundary_request_t),intent(out) :: req
    real(real64),intent(in) :: rain,h,candidate
    req=b110_dynamic_top_boundary_request_t()
    req%conductivity_mean_method=1
    req%pressure_head_top_cm=h
    req%water_content_top=theta_top
    req%candidate_ponding_depth_cm=candidate
    req%previous_ponding_depth_cm=0.0_real64
    req%step_duration_day=DT
    req%precipitation_rate_cm_per_day=rain
    req%ponding_max_cm=KS*DT
    req%runoff_resistance_day=0.001_real64
    req%runoff_exponent=1.0_real64
  end subroutine make_request

  subroutine check_route(rain,expected_route,theta,h)
    real(real64),intent(in)::rain,theta,h
    character(len=*),intent(in)::expected_route
    type(b110_dynamic_top_boundary_request_t)::r0,rp,rm
    type(b110_dynamic_top_boundary_result_t)::z,p,m
    real(real64)::fd,rel
    call make_request(r0,rain,h,0.0_real64)
    r0%water_content_top=theta
    call evaluate_b110_dynamic_top_boundary(geometry,hp,r0,z)
    call require(z%status==B110_DYN_TOP_AVAILABLE,'base provider available')
    call require(trim(z%route)==trim(expected_route),'expected smooth route')
    call require(z%surface_head_derivative_available,'surface-head derivative available')
    call make_request(rp,rain,h+EPS_H,z%candidate_ponding_depth_cm)
    call make_request(rm,rain,h-EPS_H,z%candidate_ponding_depth_cm)
    rp%water_content_top=theta;rm%water_content_top=theta
    call evaluate_b110_dynamic_top_boundary(geometry,hp,rp,p)
    call evaluate_b110_dynamic_top_boundary(geometry,hp,rm,m)
    call require(trim(p%route)==trim(expected_route).and.trim(m%route)==trim(expected_route),'FD route frozen')
    fd=(p%surface_head_cm-m%surface_head_cm)/(2.0_real64*EPS_H)
    rel=abs(fd-z%surface_head_dpressure_head_top)/max(abs(fd),abs(z%surface_head_dpressure_head_top),1.0e-30_real64)
    call require(rel<=1.0e-7_real64,'provider derivative matches finite difference')
    call require(ieee_is_finite(fd),'finite derivative')
    write(*,'(*(g0))') 'F_PE_BOFEK00_DERIVATIVE|ROUTE=',trim(expected_route),'|FD=',fd, &
         '|ANALYTIC=',z%surface_head_dpressure_head_top,'|RELERR=',rel
  end subroutine check_route

  subroutine check_candidate_independence(rain,theta,h)
    real(real64),intent(in)::rain,theta,h
    type(b110_dynamic_top_boundary_request_t)::ra,rb
    type(b110_dynamic_top_boundary_result_t)::a,b
    real(real64)::pmax
    pmax=KS*DT
    call make_request(ra,rain,h,pmax+1.0e-10_real64)
    call make_request(rb,rain,h,pmax+0.1_real64)
    ra%water_content_top=theta;rb%water_content_top=theta
    call evaluate_b110_dynamic_top_boundary(geometry,hp,ra,a)
    call evaluate_b110_dynamic_top_boundary(geometry,hp,rb,b)
    call require(a%status==B110_DYN_TOP_AVAILABLE.and.b%status==B110_DYN_TOP_AVAILABLE,'active runoff available')
    call require(trim(a%route)=='ponded-head-linear-runoff'.and.trim(b%route)=='ponded-head-linear-runoff', &
         'active runoff route independent of Newton candidate')
    call require(abs(a%candidate_ponding_depth_cm-b%candidate_ponding_depth_cm)<=1.0e-14_real64, &
         'ponding solution independent of Newton candidate')
    call require(abs(a%runoff_depth_cm-b%runoff_depth_cm)<=1.0e-14_real64, &
         'runoff solution independent of Newton candidate')
    write(*,'(*(g0))') 'F_PE_BOFEK00_BRANCH|ROUTE=',trim(a%route),'|POND=',a%candidate_ponding_depth_cm, &
         '|RUNOFF=',a%runoff_depth_cm
  end subroutine check_candidate_independence

  subroutine initialize_geometry_and_hydraulics(g,h,c)
    type(soil_water_parameter_set_t),intent(out) :: g
    type(b110_default_mvg_parameters_t),intent(out) :: h
    real(real64),intent(out) :: c(24,NN)
    real(real64) :: mm
    integer :: n
    mm=1.0_real64-1.0_real64/NPAR
    g%parameter_set_id=26092801_int64;g%active_nodes=NN
    allocate(g%z(NN),g%dz(NN),g%node_distance(NN))
    do n=1,NN
      g%z(n)=-10.0_real64*(real(n,real64)-0.5_real64)
    end do
    g%dz=10.0_real64;g%node_distance=10.0_real64;c=0.0_real64
    do n=1,NN
      c(1,n)=TR;c(2,n)=TS;c(3,n)=KS;c(4,n)=ALPHA;c(5,n)=LAM;c(6,n)=NPAR
      c(7,n)=mm;c(8,n)=ALPHA;c(9,n)=0.0_real64;c(10,n)=KS
      c(11,n)=0.999_real64;c(12,n)=0.99_real64*KS;c(22,n)=-1.0e6_real64;c(23,n)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(h,c)
  end subroutine initialize_geometry_and_hydraulics

  subroutine initial_top_state(theta,h)
    real(real64),intent(out) :: theta,h
    real(real64) :: dtheta,zfront,overlap,mm,se
    integer :: j
    dtheta=(TS-TR)/real(NBINS,real64)
    theta=TR+real(IBASE,real64)*dtheta
    do j=J0,J1
      zfront=120.0_real64+(10.0_real64-120.0_real64)*real(j-J0,real64)/real(J1-J0,real64)
      overlap=max(0.0_real64,min(zfront,10.0_real64))
      theta=theta+dtheta*overlap/10.0_real64
    end do
    mm=1.0_real64-1.0_real64/NPAR
    se=(theta-TR)/(TS-TR)
    h=-(se**(-1.0_real64/mm)-1.0_real64)**(1.0_real64/NPAR)/ALPHA
    call require(theta>TR.and.theta<TS.and.ieee_is_finite(h).and.h<0.0_real64,'initial top state')
  end subroutine initial_top_state

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)') 'F_PE_BOFEK00_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine require
end program test_bofek00_dynamic_top_correction
