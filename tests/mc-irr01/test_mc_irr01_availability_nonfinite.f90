program test_mc_irr01_availability_nonfinite
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_irrigation_availability_policy
  implicit none
  real(real64) :: q, rate, duration
  integer :: status
  q = ieee_value(0.0_real64, ieee_quiet_nan)
  rate = 4.0_real64
  duration = 0.25_real64
  call apply_irrigation_availability(.true., q, .true., rate, duration, status)
  if (status /= IRR_AVAIL_INVALID) error stop 1
  if (rate /= 4.0_real64 .or. duration /= 0.25_real64) error stop 2
  rate = q
  call apply_irrigation_availability(.true., 0.5_real64, .true., rate, duration, status)
  if (status /= IRR_AVAIL_INVALID) error stop 3
  rate = 4.0_real64
  duration = q
  call apply_irrigation_availability(.true., 0.5_real64, .true., rate, duration, status)
  if (status /= IRR_AVAIL_INVALID) error stop 4
  rate = 4.0_real64
  duration = 0.25_real64
  call apply_irrigation_availability(.true., 0.5_real64, .true., rate, duration, status)
  if (status /= IRR_AVAIL_OK) error stop 5
  if (rate /= 2.0_real64 .or. duration /= 0.125_real64) error stop 6
  print '(A)', 'MC_IRR01_AVAILABILITY_NONFINITE=PASS'
end program test_mc_irr01_availability_nonfinite
