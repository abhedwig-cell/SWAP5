program test_mig431_solute_depth
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_irrigation_solute_depth_process
  implicit none
  real(real64) :: depth
  integer :: status
  call select_solute_overirrigation_depth(2.0_real64,5.0_real64,4.0_real64,25.0_real64, &
       .true.,depth,status)
  if (status /= IRRIGATION_SOLUTE_DEPTH_OK .or. abs(depth-2.5_real64) > 1.e-14_real64) error stop 1
  call select_solute_overirrigation_depth(2.0_real64,4.0_real64,4.0_real64,25.0_real64, &
       .true.,depth,status)
  if (status /= IRRIGATION_SOLUTE_DEPTH_OK .or. depth /= 2.0_real64) error stop 2
  call select_solute_overirrigation_depth(2.0_real64,5.0_real64,4.0_real64,25.0_real64, &
       .false.,depth,status)
  if (status /= IRRIGATION_SOLUTE_DEPTH_OK .or. depth /= 2.0_real64) error stop 3
  call select_solute_overirrigation_depth(2.0_real64,5.0_real64,4.0_real64,101.0_real64, &
       .true.,depth,status)
  if (status /= IRRIGATION_SOLUTE_DEPTH_INVALID .or. depth /= 0.0_real64) error stop 4
  print '(a)', 'F_MIG431_SOLUTE_OVERIRRIGATION_DEPTH=PASS'
end program
