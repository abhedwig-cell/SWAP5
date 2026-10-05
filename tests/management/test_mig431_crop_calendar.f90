program test_mig431_crop_calendar
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_crop_calendar_management_process
  use mod_fmr_crop_calendar_restart
  implicit none
  type(crop_calendar_management_parameters_t) :: p
  type(crop_calendar_management_observation_t) :: o
  type(crop_calendar_management_state_t) :: committed, candidate
  type(crop_calendar_restart_record_t) :: restart
  integer :: status

  p%preparation_mode = 1
  p%sowing_mode = 1
  p%germination_mode = 2
  p%maximum_preparation_delay = 1
  p%maximum_sowing_delay = 1
  p%preparation_head_limit_cm = -10.0_real64
  p%sowing_head_limit_cm = -10.0_real64
  p%sowing_temperature_c = 8.0_real64
  p%optimum_emergence_temperature_sum = 20.0_real64
  p%base_temperature_c = 2.0_real64
  p%maximum_effective_temperature_c = 20.0_real64
  p%dry_germination_head_cm = -500.0_real64
  p%wet_germination_head_cm = -2.0_real64
  p%germination_head_coefficient = 10.0_real64
  o%preparation_average_head_cm = -5.0_real64
  o%sowing_average_head_cm = -5.0_real64
  o%sowing_soil_temperature_c = 5.0_real64
  o%germination_average_head_cm = -50.0_real64
  o%daily_mean_air_temperature_c = 12.0_real64

  call advance_crop_calendar_day(p,o,committed,candidate,status)
  if (status /= CROP_CALENDAR_OK .or. candidate%prepared .or. candidate%preparation_delay_days /= 1) error stop 1
  ! Rejecting the proposal leaves the committed state untouched.
  if (committed%preparation_delay_days /= 0) error stop 2
  committed = candidate
  call advance_crop_calendar_day(p,o,committed,candidate,status)
  if (status /= CROP_CALENDAR_OK .or. .not. candidate%prepared) error stop 3
  committed = candidate
  call advance_crop_calendar_day(p,o,committed,candidate,status)
  if (status /= CROP_CALENDAR_OK .or. candidate%sown .or. candidate%sowing_delay_days /= 1) error stop 4
  committed = candidate
  call advance_crop_calendar_day(p,o,committed,candidate,status)
  if (status /= CROP_CALENDAR_OK .or. .not. candidate%sown) error stop 5
  committed = candidate
  call advance_crop_calendar_day(p,o,committed,candidate,status)
  if (status /= CROP_CALENDAR_OK .or. candidate%emerged) error stop 6
  if (abs(candidate%germination_temperature_sum-10.0_real64) > 1.e-12_real64) error stop 7
  call export_crop_calendar_restart(candidate,9,restart,status)
  if (status /= CROP_CALENDAR_RESTART_OK) error stop 12
  call restore_crop_calendar_restart(restart,9,committed,status)
  if (status /= CROP_CALENDAR_RESTART_OK) error stop 13
  if (abs(committed%germination_temperature_sum-10.0_real64) > 1.e-12_real64) error stop 14
  call restore_crop_calendar_restart(restart,10,candidate,status)
  if (status /= CROP_CALENDAR_RESTART_INVALID) error stop 15
  call advance_crop_calendar_day(p,o,committed,candidate,status)
  if (status /= CROP_CALENDAR_OK .or. .not. candidate%emerged) error stop 8
  o%germination_average_head_cm = -1000.0_real64
  committed%emerged = .false.
  committed%germination_temperature_sum = 0.0_real64
  call advance_crop_calendar_day(p,o,committed,candidate,status)
  if (status /= CROP_CALENDAR_OK .or. candidate%germination_temperature_sum >= 10.0_real64) error stop 9
  p%germination_mode = 0
  call advance_crop_calendar_day(p,o,committed,candidate,status)
  if (status /= CROP_CALENDAR_OK .or. .not. candidate%emerged) error stop 10
  p%germination_mode = 3
  call advance_crop_calendar_day(p,o,committed,candidate,status)
  if (status /= CROP_CALENDAR_INVALID .or. candidate%emerged) error stop 11
  print '(a)', 'F_MIG431_CROP_CALENDAR_GATE_ORACLE=PASS'
  print '(a)', 'F_MIG431_CROP_CALENDAR_RESTART_IDENTITY=PASS'
end program
