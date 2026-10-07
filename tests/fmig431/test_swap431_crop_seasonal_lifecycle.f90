program test_swap431_crop_seasonal_lifecycle
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_crop_rotation_owner
  use mod_crop_preemergence_owner
  use mod_crop_seasonal_lifecycle_owner
  implicit none

  type(crop_rotation_schedule_t) :: sched
  type(crop_preemergence_parameters_t) :: p1,p2
  type(crop_preemergence_daily_forcing_t) :: f
  type(crop_seasonal_lifecycle_state_t) :: s
  type(crop_seasonal_lifecycle_result_t) :: r,rr
  integer :: status
  real(real64), parameter :: tol=1.0e-12_real64

  allocate(sched%entries(2))
  sched%entries(1)%start_day=100.0_real64
  sched%entries(1)%end_day=120.0_real64
  sched%entries(1)%crop_key=11
  sched%entries(1)%crop_type=2
  sched%entries(2)%start_day=130.0_real64
  sched%entries(2)%end_day=150.0_real64
  sched%entries(2)%crop_key=22
  sched%entries(2)%crop_type=1
  if(.not.sched%ready()) error stop 1

  ! First crop uses temperature-sum germination. Preparation/sowing are
  ! immediately complete, but germination requires two 10-degree days.
  p1%preparation_enabled=.false.
  p1%sowing_enabled=.false.
  p1%maximum_preparation_delay_days=1
  p1%maximum_sowing_delay_days=1
  p1%germination_mode=GERMINATION_TEMPERATURE
  p1%optimal_emergence_temperature_sum=20.0_real64
  p1%germination_base_temperature_c=0.0_real64
  p1%germination_effective_max_temperature_c=20.0_real64
  if(.not.p1%ready()) error stop 2

  p2%preparation_enabled=.false.
  p2%sowing_enabled=.false.
  p2%maximum_preparation_delay_days=1
  p2%maximum_sowing_delay_days=1
  p2%germination_mode=GERMINATION_OFF
  if(.not.p2%ready()) error stop 3

  f%average_air_temperature_c=10.0_real64

  call initialize_crop_seasonal_lifecycle(sched,99.0_real64,s,status)
  if(status/=CROP_SEASON_OK.or.s%crop_emerged.or.s%preemergence_active()) error stop 4

  ! Season start initializes pre-emergence and advances today's germination,
  ! but source does not re-check emergence after the task-3 update.
  call evaluate_crop_seasonal_lifecycle_day(sched,s,100.0_real64,.false.,11,p1,f,.false.,r,status)
  if(status/=CROP_SEASON_OK) error stop 5
  if(.not.r%bind_crop_parameters.or..not.r%reset_crop_owner) error stop 6
  if(r%start_crop_emergence.or.r%candidate%crop_emerged) error stop 7
  if(.not.r%candidate%preemergence_active().or..not.r%preemergence_advanced) error stop 8
  if(abs(r%candidate%preemergence%germination_temperature_sum-10.0_real64)>tol) error stop 9
  if(abs(r%preemergence_development_stage_marker+0.05_real64)>tol) error stop 10

  s=r%candidate
  call evaluate_crop_seasonal_lifecycle_day(sched,s,101.0_real64,.false.,11,p1,f,.false.,r,status)
  if(status/=CROP_SEASON_OK.or.r%start_crop_emergence) error stop 11
  if(.not.r%candidate%preemergence_active()) error stop 12
  if(.not.r%candidate%preemergence%germination_complete) error stop 13

  ! Completion from yesterday becomes emergence today.
  s=r%candidate
  call evaluate_crop_seasonal_lifecycle_day(sched,s,102.0_real64,.false.,11,p1,f,.false.,r,status)
  if(status/=CROP_SEASON_OK.or..not.r%start_crop_emergence.or..not.r%candidate%crop_emerged) error stop 14
  if(r%candidate%preemergence_active()) error stop 15

  ! The same committed state at the post-season boundary without the crop-end
  ! receipt must fail closed instead of silently dropping biomass ownership.
  s=r%candidate
  call evaluate_crop_seasonal_lifecycle_day(sched,s,121.0_real64,.false.,22,p2,f,.false.,rr,status)
  if(status/=CROP_SEASON_MISSING_HARVEST) error stop 16

  ! With the committed harvest receipt, the crop owner is retired while
  ! rotation cursor advances through fallow to the next crop.
  call evaluate_crop_seasonal_lifecycle_day(sched,s,121.0_real64,.false.,22,p2,f,.true.,r,status)
  if(status/=CROP_SEASON_OK.or..not.r%retire_crop_owner) error stop 17
  if(r%candidate%crop_emerged.or..not.r%candidate%crop_harvested) error stop 18
  if(r%candidate%rotation%current_crop_index/=2.or.r%crop_calendar_active) error stop 19

  ! During fallow the lifecycle is state-stable.
  s=r%candidate
  call evaluate_crop_seasonal_lifecycle_day(sched,s,125.0_real64,.false.,22,p2,f,.false.,r,status)
  if(status/=CROP_SEASON_OK.or.r%crop_calendar_active.or.r%start_crop_emergence) error stop 20

  ! Second crop has all pre-emergence selectors disabled. B1.11 initialization
  ! therefore makes all flags true and emergence starts immediately at season start.
  s=r%candidate
  call evaluate_crop_seasonal_lifecycle_day(sched,s,130.0_real64,.false.,22,p2,f,.false.,r,status)
  if(status/=CROP_SEASON_OK.or..not.r%bind_crop_parameters.or..not.r%start_crop_emergence) error stop 21
  if(.not.r%candidate%crop_emerged.or.r%candidate%crop_harvested) error stop 22
  if(r%candidate%bound_crop_key/=22.or.r%candidate%preemergence_active()) error stop 23

  ! Same checkpoint evaluation is deterministic and does not mutate source state.
  s=r%candidate
  call evaluate_crop_seasonal_lifecycle_day(sched,s,131.0_real64,.false.,22,p2,f,.false.,r,status)
  if(status/=CROP_SEASON_OK.or.r%bind_crop_parameters.or.r%start_crop_emergence) error stop 24
  call evaluate_crop_seasonal_lifecycle_day(sched,s,131.0_real64,.false.,22,p2,f,.false.,rr,status)
  if(status/=CROP_SEASON_OK) error stop 25
  if(rr%candidate%bound_crop_key/=r%candidate%bound_crop_key.or. &
     rr%candidate%crop_emerged.neqv.r%candidate%crop_emerged) error stop 26

  ! Wrong parameter registry key is rejected on a fresh season start.
  call initialize_crop_seasonal_lifecycle(sched,99.0_real64,s,status)
  call evaluate_crop_seasonal_lifecycle_day(sched,s,100.0_real64,.false.,999,p1,f,.false.,r,status)
  if(status/=CROP_SEASON_PARAMETER_KEY_MISMATCH) error stop 27

  print '(a)','SW431_CROP_SEASONAL_LIFECYCLE=PASS'
end program
