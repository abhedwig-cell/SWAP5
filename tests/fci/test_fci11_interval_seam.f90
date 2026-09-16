program test_fci11_interval_seam
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b1_10_interval_seam, only: b1_10_interval_seam_t, begin_b1_10_interval, b1_10_interval_valid
  implicit none
  type(b1_10_interval_seam_t) :: i
  call begin_b1_10_interval(i, 1234.25_real64, 1234.75_real64)
  if (.not. i%active) error stop 'valid interval not active'
  if (.not. b1_10_interval_valid(i)) error stop 'valid interval rejected'
  if (i%prepared .or. i%complete) error stop 'fresh interval lifecycle wrong'
  call begin_b1_10_interval(i, 9.0_real64, 9.0_real64)
  if (i%active .or. b1_10_interval_valid(i)) error stop 'zero interval accepted'
  call begin_b1_10_interval(i, 10.0_real64, 9.0_real64)
  if (i%active .or. b1_10_interval_valid(i)) error stop 'negative interval accepted'
  write(*,'(A)') 'FCI11_INTERVAL_SEAM PASS'
end program test_fci11_interval_seam
