program test_swap431_crop_calendar_end
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_crop_calendar_end_event
  implicit none
  type(crop_end_event_request_t) :: q
  type(crop_end_event_result_t) :: r
  integer :: status

  q%mode=CROP_END_BY_CALENDAR
  q%configured_crop_end_day=100.0_real64
  q%current_time_day=101.0_real64
  q%development_stage=0.5_real64
  call evaluate_crop_end_event(q,r,status)
  if(status/=CROP_END_OK.or..not.r%end_crop.or..not.r%calendar_triggered.or.r%development_triggered) error stop 1

  ! Strict source tolerance: exactly 0.1 is not a calendar trigger.
  q%current_time_day=101.1_real64
  call evaluate_crop_end_event(q,r,status)
  if(status/=CROP_END_OK.or.r%end_crop) error stop 2

  q%mode=CROP_END_BY_DVS_OR_CALENDAR
  q%current_time_day=50.0_real64
  q%development_stage=1.5_real64
  q%development_stage_end=1.5_real64
  call evaluate_crop_end_event(q,r,status)
  if(status/=CROP_END_OK.or..not.r%end_crop.or.r%calendar_triggered.or..not.r%development_triggered) error stop 3

  q%development_stage=1.49_real64
  call evaluate_crop_end_event(q,r,status)
  if(status/=CROP_END_OK.or.r%end_crop) error stop 4

  print '(a)','SW431_CROP_CALENDAR_END=PASS'
end program
