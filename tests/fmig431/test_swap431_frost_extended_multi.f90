program test_swap431_frost_extended_multi
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_extended_exchange, only: extended_drainage_parameters_t, extended_drainage_control_t, &
       extended_drainage_result_t, extended_drainage_diagnostics_t, evaluate_extended_drainage_exchange, &
       EXT_DRAIN_OK, EXT_DRAIN_TUBE, EXT_DRAIN_TOP_NONE
  use mod_frost_drainage_effect, only: frost_drainage_result_t, compose_legacy_normal_frost_drainage, FROST_DRAIN_OK
  implicit none
  integer,parameter :: n=4,levels=2
  type(process_hydraulic_view_t) :: view
  type(extended_drainage_parameters_t) :: p(levels)
  type(extended_drainage_control_t) :: c(levels)
  type(extended_drainage_result_t) :: r(levels)
  type(extended_drainage_diagnostics_t) :: d(levels)
  type(frost_drainage_result_t) :: frost
  real(real64) :: proposal(levels,n),final(levels,n)
  real(real64) :: temperature(n),theta(n),sat(n),dz(n),factor(n)
  real(real64),parameter :: tol=512.0_real64*epsilon(1.0_real64)
  integer :: i

  view%active_nodes=n
  allocate(view%pressure_head(n),view%water_content(n))
  view%pressure_head=0._real64
  view%water_content=.25_real64
  view%groundwater_level=-20._real64
  view%ponding_depth=0._real64
  do i=1,levels
    p(i)%zbotdr_cm=-40._real64-10._real64*i
    p(i)%drain_type=EXT_DRAIN_TUBE
    p(i)%spacing_cm=1000._real64+200._real64*i
    p(i)%rdrain_day=100._real64+50._real64*i
    p(i)%rinfi_day=120._real64+50._real64*i
    p(i)%rentry_day=0._real64
    p(i)%rexit_day=0._real64
    p(i)%gwlinf_cm=p(i)%zbotdr_cm
    p(i)%pondmx_cm=10._real64
    p(i)%highest_level=.false.
    p(i)%highest_surface_mode=EXT_DRAIN_TOP_NONE
    c(i)%resolved_surface_water_head_cm=-60._real64-10._real64*i
    call evaluate_extended_drainage_exchange(p(i),view,c(i),r(i),d(i))
    call require(d(i)%status==EXT_DRAIN_OK,'extended level evaluates')
  end do
  proposal=0._real64
  do i=1,levels
    proposal(i,n)=r(i)%signed_soil_to_surface_rate_cm_day
  end do
  call require(all(abs([sum(proposal(1,:)),sum(proposal(2,:))]- &
       [r(1)%signed_soil_to_surface_rate_cm_day,r(2)%signed_soil_to_surface_rate_cm_day])<=tol), &
       'multilevel extended proposal accounting')

  temperature=[-1._real64,-1._real64,1._real64,1._real64]
  theta=.2_real64;sat=.45_real64;dz=1._real64
  factor=[.2_real64,.5_real64,1._real64,1._real64]
  call compose_legacy_normal_frost_drainage(.true.,temperature,-2._real64,theta,sat,dz,factor,proposal,final,frost)
  call require(frost%status==FROST_DRAIN_OK.and.frost%available,'frost accepts extended multilevel proposal')
  call require(all(abs(final-proposal*spread(factor,1,levels))<=tol),'nodewise frost composition')
  call require(all(abs(frost%level_rate-[sum(final(1,:)),sum(final(2,:))])<=tol),'per-level frost accounting')
  call require(abs(frost%total_rate-sum(final))<=tol,'single total owner')

  print '(a)','SW431_FROST_EXT_MULTI_RESPONSES=PASS'
  print '(a)','SW431_FROST_EXT_MULTI_FROST=PASS'
  print '(a)','SW431_FROST_EXT_MULTI_MASS=PASS'
  print '(a)','SW431_FROST_EXT_MULTI=PASS'
contains
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then
      write(*,'(a,1x,a)')'SW431_FROST_EXT_MULTI_FAIL',trim(label)
      error stop 431
    end if
  end subroutine
end program
