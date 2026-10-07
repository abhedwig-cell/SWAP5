program test_swap431_crop_rotation_owner
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_crop_rotation_owner
  implicit none
  type(crop_rotation_schedule_t)::sched
  type(crop_rotation_state_t)::s,c
  type(crop_rotation_day_result_t)::r
  integer::status

  allocate(sched%entries(2))
  sched%entries(1)%start_day=100._real64
  sched%entries(1)%end_day=120._real64
  sched%entries(1)%crop_key=11
  sched%entries(1)%crop_type=2
  sched%entries(2)%start_day=130._real64
  sched%entries(2)%end_day=150._real64
  sched%entries(2)%crop_key=22
  sched%entries(2)%crop_type=1
  if(.not.sched%ready())error stop 1

  call initialize_crop_rotation_owner(sched,95._real64,s,r,status)
  if(status/=CROP_ROTATION_OK)error stop 2
  if(s%current_crop_index/=1.or.s%crop_calendar_active.or.r%bind_crop_parameters)error stop 3

  call evaluate_crop_rotation_day(sched,s,100._real64,.false.,c,r,status)
  if(status/=CROP_ROTATION_OK.or..not.c%crop_calendar_active)error stop 4
  if(.not.r%start_rotation.or..not.r%bind_crop_parameters.or..not.r%reset_preemergence.or..not.r%reset_active_crop_flags)error stop 5
  if(r%crop_key/=11.or.r%crop_type/=2)error stop 6

  ! Replay same source state is deterministic; owner itself has no side effects.
  call evaluate_crop_rotation_day(sched,s,100._real64,.false.,c,r,status)
  if(status/=CROP_ROTATION_OK.or..not.r%start_rotation.or.r%crop_index/=1)error stop 7

  ! End tolerance: still active just below +0.1, fallow at +0.1.
  s=c
  call evaluate_crop_rotation_day(sched,s,120.099_real64,.false.,c,r,status)
  if(status/=CROP_ROTATION_OK.or..not.c%crop_calendar_active)error stop 8
  s=c
  call evaluate_crop_rotation_day(sched,s,120.1001_real64,.false.,c,r,status)
  if(status/=CROP_ROTATION_OK.or.c%crop_calendar_active)error stop 9
  if(c%current_crop_index/=2.or.c%exhausted)error stop 10

  ! Fallow cursor already points at the next crop.
  s=c
  call evaluate_crop_rotation_day(sched,s,125._real64,.false.,c,r,status)
  if(status/=CROP_ROTATION_OK.or.c%crop_calendar_active.or.c%current_crop_index/=2)error stop 11

  s=c
  call evaluate_crop_rotation_day(sched,s,130._real64,.false.,c,r,status)
  if(status/=CROP_ROTATION_OK.or..not.r%start_rotation.or.r%crop_key/=22)error stop 12

  ! Initialization inside an active season binds parameters but does not issue
  ! runtime reset requests; source preserves initialized continuation semantics.
  call initialize_crop_rotation_owner(sched,140._real64,s,r,status)
  if(status/=CROP_ROTATION_OK.or..not.s%crop_calendar_active.or.s%current_crop_index/=2)error stop 13
  if(.not.r%bind_crop_parameters.or.r%reset_preemergence.or.r%reset_active_crop_flags)error stop 14

  call evaluate_crop_rotation_day(sched,s,150.1001_real64,.false.,c,r,status)
  if(status/=CROP_ROTATION_OK.or..not.c%exhausted.or.c%crop_calendar_active)error stop 15

  print '(a)','SW431_CROP_ROTATION_OWNER=PASS'
end program
