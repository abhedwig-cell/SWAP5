program test_mig431_crop_observation
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_crop_calendar_management_process, only: crop_calendar_management_observation_t
  use mod_fmr_crop_calendar_observation_binding
  implicit none
  type(crop_calendar_management_observation_t) :: o
  integer :: status
  call bind_crop_calendar_observation([10.0_real64,20.0_real64], &
       [-10.0_real64,-100.0_real64],[7.0_real64,12.0_real64], &
       0.0_real64,15.0_real64,30.0_real64,10.0_real64,16.0_real64,o,status)
  if (status /= CROP_OBSERVATION_OK) error stop 1
  if (abs(o%preparation_average_head_cm+10.0_real64) > 1.e-12_real64 .or. &
      abs(o%sowing_average_head_cm+10.0_real64**(4.0_real64/3.0_real64)) > 1.e-12_real64 .or. &
      abs(o%germination_average_head_cm+10.0_real64**(5.0_real64/3.0_real64)) > 1.e-12_real64) error stop 2
  if (o%sowing_soil_temperature_c /= 7.0_real64 .or. &
      o%daily_mean_air_temperature_c /= 16.0_real64) error stop 3
  call bind_crop_calendar_observation([10.0_real64,20.0_real64], &
       [-10.0_real64,-100.0_real64],[7.0_real64,12.0_real64], &
       0.0_real64,15.0_real64,30.0_real64,10.001_real64,16.0_real64,o,status)
  if (status /= CROP_OBSERVATION_OK .or. o%sowing_soil_temperature_c /= 12.0_real64) error stop 4
  call bind_crop_calendar_observation([10.0_real64,20.0_real64], &
       [-10.0_real64,-100.0_real64],[7.0_real64,12.0_real64], &
       0.0_real64,15.0_real64,31.0_real64,10.0_real64,16.0_real64,o,status)
  if (status /= CROP_OBSERVATION_INVALID) error stop 5
  print '(a)', 'F_MIG431_CROP_PROFILE_OBSERVATION=PASS'
end program
