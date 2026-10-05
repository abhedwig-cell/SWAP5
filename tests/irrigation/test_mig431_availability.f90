program test_mig431_availability
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_irrigation_availability_process
  implicit none
  real(real64) :: delivered,rate,duration
  integer :: status
  call select_available_irrigation_event(2.0_real64,4.0_real64,0.25_real64, &
       delivered,rate,duration,status)
  if (status /= IRRIGATION_AVAILABILITY_OK .or. &
      abs(delivered-0.5_real64) > 1.e-14_real64 .or. &
      abs(rate*duration-0.5_real64) > 1.e-14_real64) error stop 1
  call select_available_irrigation_event(2.0_real64,0.0_real64,0.5_real64, &
       delivered,rate,duration,status)
  if (status /= IRRIGATION_AVAILABILITY_OK .or. &
      abs(delivered-1.0_real64) > 1.e-14_real64 .or. &
      abs(duration-1.0_real64) > 1.e-14_real64) error stop 2
  call select_available_irrigation_event(2.0_real64,4.0_real64,0.0_real64, &
       delivered,rate,duration,status)
  if (status /= IRRIGATION_AVAILABILITY_OK .or. delivered > 0.0_real64 .or. duration > 0.0_real64) error stop 3
  call select_available_irrigation_event(2.0_real64,4.0_real64,1.1_real64, &
       delivered,rate,duration,status)
  if (status /= IRRIGATION_AVAILABILITY_INVALID .or. delivered > 0.0_real64) error stop 4
  print '(a)', 'F_MIG431_EXTERNAL_AVAILABILITY_MASS=PASS'
end program
