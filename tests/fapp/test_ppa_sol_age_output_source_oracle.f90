program test_ppa_sol_age_output_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_sol_age_output
  implicit none

  integer, parameter :: n = 5, nlevel = 3, ncase = 100000
  real(real64) :: age(n), old_age(n), qrot(n), qdra(nlevel, n), qtop, qbottom, dt
  real(real64) :: inc_top, inc_root, inc_bottom, ref_top, ref_root, ref_bottom
  real(real64) :: inc_dra(nlevel), ref_dra(nlevel), mean_age
  integer :: status, i, level, j

  do j = 1, ncase
    dt = 0.001_real64 + real(mod(j, 97), real64) / 10000.0_real64
    qtop = real(mod(j * 7, 101) - 50, real64) / 100.0_real64
    qbottom = real(mod(j * 11, 103) - 51, real64) / 100.0_real64
    do i = 1, n
      age(i) = real(mod(j * (i + 3), 83), real64) / 10.0_real64
      old_age(i) = real(mod(j * (i + 9), 71), real64) / 10.0_real64
      qrot(i) = real(mod(j * (i + 5), 67) - 33, real64) / 1000.0_real64
      do level = 1, nlevel
        qdra(level, i) = real(mod(j * (i + level * 7), 59) - 29, real64) / 500.0_real64
      end do
    end do
    ref_top = max(0.0_real64, qtop) * 0.5_real64 * (age(1) + old_age(1)) * dt
    ref_root = 0.0_real64
    ref_dra = 0.0_real64
    do i = 1, n
      mean_age = 0.5_real64 * (age(i) + old_age(i))
      ref_root = ref_root + qrot(i) * mean_age * dt
      do level = 1, nlevel
        ref_dra(level) = ref_dra(level) + qdra(level, i) * mean_age * dt
      end do
    end do
    ref_bottom = -min(qbottom, 0.0_real64) * 0.5_real64 * (age(n) + old_age(n)) * dt

    call ppa_sol_age_output_increments(age, old_age, qtop, qrot, qdra, qbottom, dt, &
         inc_top, inc_root, inc_dra, inc_bottom, status)
    if (status /= PPA_SOL_AGE_OUTPUT_OK) error stop 'valid output vector rejected'
    if (transfer(ref_top, 0_int64) /= transfer(inc_top, 0_int64)) error stop 'top increment mismatch'
    if (transfer(ref_root, 0_int64) /= transfer(inc_root, 0_int64)) error stop 'root increment mismatch'
    do level = 1, nlevel
      if (transfer(ref_dra(level), 0_int64) /= transfer(inc_dra(level), 0_int64)) error stop 'lateral increment mismatch'
    end do
    if (transfer(ref_bottom, 0_int64) /= transfer(inc_bottom, 0_int64)) error stop 'bottom increment mismatch'
  end do
  print '(a)', 'PPA_SOL_AGE_OUTPUT_B1_11_INCREMENT_100000x5x3=PASS'
  print '(a)', 'PPA_SOL_AGE_OUTPUT_TOP_ROOT_LATERAL_BOTTOM_SIGN_BRANCHES=PASS'

  age(1) = ieee_value(0.0_real64, ieee_quiet_nan)
  call ppa_sol_age_output_increments(age, old_age, qtop, qrot, qdra, qbottom, dt, &
       inc_top, inc_root, inc_dra, inc_bottom, status)
  if (status /= PPA_SOL_AGE_OUTPUT_INVALID_INPUT) error stop 'nonfinite input accepted'
  call ppa_sol_age_output_increments(old_age, old_age, qtop, qrot, qdra, qbottom, 0.0_real64, &
       inc_top, inc_root, inc_dra, inc_bottom, status)
  if (status /= PPA_SOL_AGE_OUTPUT_INVALID_INPUT) error stop 'nonpositive interval accepted'
  print '(a)', 'PPA_SOL_AGE_OUTPUT_INVALID_INPUT_FAIL_CLOSED=PASS'
end program test_ppa_sol_age_output_source_oracle
