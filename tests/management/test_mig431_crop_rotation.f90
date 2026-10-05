program test_mig431_crop_rotation
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_crop_rotation_calendar_binding
  implicit none
  integer :: active,next,status
  real(real64), parameter :: starts(2) = [10.0_real64,30.0_real64]
  real(real64), parameter :: ends(2) = [20.0_real64,40.0_real64]
  call select_crop_rotation_event(starts,ends,5.0_real64,active,next,status)
  if (status /= CROP_ROTATION_OK .or. active /= 0 .or. next /= 1) error stop 1
  call select_crop_rotation_event(starts,ends,20.0_real64,active,next,status)
  if (status /= CROP_ROTATION_OK .or. active /= 1 .or. next /= 2) error stop 2
  call select_crop_rotation_event(starts,ends,40.0_real64,active,next,status)
  if (status /= CROP_ROTATION_OK .or. active /= 2 .or. next /= 0) error stop 3
  call select_crop_rotation_event(starts,ends,41.0_real64,active,next,status)
  if (status /= CROP_ROTATION_OK .or. active /= 0 .or. next /= 0) error stop 4
  call select_crop_rotation_event([10.0_real64,20.0_real64],ends,20.0_real64,active,next,status)
  if (status /= CROP_ROTATION_INVALID .or. active /= 0) error stop 5
  print '(a)', 'F_MIG431_CROP_ROTATION_TERMINAL_BOUNDARY=PASS'
end program
