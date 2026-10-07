program test_swap431_crop_end_event
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_crop_end_event_owner
  implicit none
  type(crop_end_event_request_t) :: q
  type(crop_end_event_result_t) :: r
  integer :: status

  q%scheduled_crop_end_t1900=1000.0_real64
  q%development_stage=1.2_real64
  q%development_stage_end=1.5_real64

  q%current_time_t1900=1001.0_real64
  call evaluate_crop_end_event(q,r,status)
  if(status/=CROP_END_EVENT_OK.or..not.r%crop_end_due.or..not.r%due_to_calendar.or.r%due_to_development_stage) error stop 1

  ! Strict source boundary: exactly 0.1 is not due.
  q%current_time_t1900=1001.1_real64
  call evaluate_crop_end_event(q,r,status)
  if(status/=CROP_END_EVENT_OK.or.r%crop_end_due) error stop 2

  q%current_time_t1900=1001.099999_real64
  call evaluate_crop_end_event(q,r,status)
  if(status/=CROP_END_EVENT_OK.or..not.r%due_to_calendar) error stop 3

  q%current_time_t1900=900.0_real64
  q%development_stage_harvest_enabled=.true.
  q%development_stage=1.5_real64
  call evaluate_crop_end_event(q,r,status)
  if(status/=CROP_END_EVENT_OK.or..not.r%crop_end_due.or..not.r%due_to_development_stage.or.r%due_to_calendar) error stop 4

  q%development_stage=1.499_real64
  call evaluate_crop_end_event(q,r,status)
  if(status/=CROP_END_EVENT_OK.or.r%crop_end_due) error stop 5

  print '(a)','SW431_CROP_END_EVENT_OWNER=PASS'
end program
