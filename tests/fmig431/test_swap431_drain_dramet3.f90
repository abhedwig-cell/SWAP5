program test_swap431_drain_dramet3
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_drainage_dramet3_response
  implicit none
  type(dramet3_channel_control_t) :: control
  type(dramet3_level_parameters_t) :: p
  type(dramet3_level_result_t) :: r
  integer :: status
  real(real64), parameter :: tol=1.0e-12_real64

  call initialize_dramet3_channel_control(control,100._real64,40000._real64, &
       [40000._real64,40002._real64],[-80._real64,-40._real64],status)
  if(status/=DRAMET3_OK) error stop 1
  p%drain_bottom_cm=-100._real64
  p%drainage_resistance_day=200._real64
  p%infiltration_resistance_day=400._real64

  call evaluate_dramet3_level(p,control,-30._real64,102._real64,r)
  if(r%status/=DRAMET3_OK.or.abs(r%signed_exchange_cm_per_day-.05_real64)>tol) error stop 2
  call evaluate_dramet3_level(p,control,-60._real64,102._real64,r)
  if(r%status/=DRAMET3_OK.or.abs(r%signed_exchange_cm_per_day+.05_real64)>tol) error stop 3

  p%allocation_mode=DRAMET3_INFILTRATION_ONLY
  call evaluate_dramet3_level(p,control,-30._real64,102._real64,r)
  if(.not.r%drainage_suppressed.or.abs(r%signed_exchange_cm_per_day)>tol) error stop 4

  p%allocation_mode=DRAMET3_DRAINAGE_ONLY
  call evaluate_dramet3_level(p,control,-60._real64,102._real64,r)
  if(.not.r%infiltration_suppressed.or.abs(r%signed_exchange_cm_per_day)>tol) error stop 5

  p%allocation_mode=DRAMET3_ALLOW_BOTH
  p%drain_type=DRAMET3_OPEN_CHANNEL
  p%limit_channel_infiltration=.true.
  call initialize_dramet3_channel_control(control,0._real64,0._real64,[0._real64],[-50._real64],status)
  call evaluate_dramet3_level(p,control,-150._real64,1._real64,r)
  if(.not.r%infiltration_head_limited) error stop 6
  if(abs(r%head_difference_cm+50._real64)>tol.or.abs(r%signed_exchange_cm_per_day+.125_real64)>tol) error stop 7

  call initialize_dramet3_channel_control(control,0._real64,0._real64, &
       [0._real64,10._real64],[-120._real64,-80._real64],status)
  call evaluate_dramet3_level(p,control,-90._real64,0._real64,r)
  if(abs(r%resolved_channel_head_cm+100._real64)>tol) error stop 8
  if(abs(r%signed_exchange_cm_per_day-.05_real64)>tol) error stop 9

  print '(a)','SW431_DRAIN_DRAMET3_COMPONENT=PASS'
  print '(a)','SW431_DRAIN_ALLOCATION_COMPONENT=PASS'
  print '(a)','SW431_DRAIN_INF_LIMIT_COMPONENT=PASS'
end program
