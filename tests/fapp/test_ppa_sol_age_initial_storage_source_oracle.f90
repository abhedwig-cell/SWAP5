program test_ppa_sol_age_initial_storage_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_sol_age_initial_storage
  implicit none
  integer, parameter :: n = 9, ncase = 100000
  real(real64) :: age(n), theta(n), dz(n), ref_storage(n), ref_total, total
  real(real64), allocatable :: storage(:)
  integer :: i, j, status

  do j = 1, ncase
    ref_total = 0.0_real64
    do i = 1, n
      age(i) = real(mod(j * (i + 3), 121), real64) / 10.0_real64
      theta(i) = 0.05_real64 + real(mod(j * (i + 5), 79), real64) / 500.0_real64
      dz(i) = 0.01_real64 + real(mod(j * (i + 7), 61), real64) / 100.0_real64
      ref_storage(i) = theta(i) * age(i)
      ref_total = ref_total + ref_storage(i) * dz(i)
    end do
    call ppa_sol_age_initial_storage(age, theta, dz, storage, total, status)
    if (status /= PPA_SOL_AGE_STORAGE_OK) error stop 'valid initial profile rejected'
    if (transfer(ref_total, 0_int64) /= transfer(total, 0_int64)) error stop 'samini mismatch'
    do i = 1, n
      if (transfer(ref_storage(i), 0_int64) /= transfer(storage(i), 0_int64)) error stop 'initial storage mismatch'
    end do
  end do
  print '(a)', 'PPA_SOL_AGE_INITIAL_STORAGE_B1_11_100000x9=PASS'

  age(1) = ieee_value(0.0_real64, ieee_quiet_nan)
  call ppa_sol_age_initial_storage(age, theta, dz, storage, total, status)
  if (status /= PPA_SOL_AGE_STORAGE_INVALID_INPUT) error stop 'nonfinite initial input accepted'
  print '(a)', 'PPA_SOL_AGE_INITIAL_STORAGE_INVALID_INPUT_FAIL_CLOSED=PASS'
end program test_ppa_sol_age_initial_storage_source_oracle
