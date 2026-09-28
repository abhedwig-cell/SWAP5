program test_ppa_sol_age_report_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_sol_age_report
  implicit none

  integer, parameter :: nnode = 7, nlevel = 4, ncase = 100000
  real(real64) :: age(nnode), acc_drain(nlevel), drainage(nlevel, nnode), outper
  real(real64), allocatable :: profile_out(:), drain_out(:), q_out(:)
  real(real64) :: acc_bot, acc_root, acc_surface, bot_out, root_out, surface_out
  real(real64) :: qsum, expected, values(3)
  integer :: status, j, i, level

  do j = 1, ncase
    outper = 0.1_real64 + real(mod(j, 73), real64) / 11.0_real64
    acc_bot = real(mod(j * 7, 113), real64) / 10.0_real64
    acc_root = real(mod(j * 11, 127), real64) / 10.0_real64
    acc_surface = real(mod(j * 13, 131), real64) / 10.0_real64
    do i = 1, nnode
      age(i) = real(mod(j * (i + 5), 149), real64) / 10.0_real64
    end do
    do level = 1, nlevel
      acc_drain(level) = real(mod(j * (level + 7), 137), real64) / 10.0_real64
      do i = 1, nnode
        drainage(level, i) = real(mod(j * (i + level * 11), 101) - 50, real64) / 10.0_real64
      end do
    end do
    call ppa_sol_age_report_values(age, acc_bot, acc_root, acc_surface, acc_drain, outper, drainage, &
         profile_out, bot_out, root_out, surface_out, drain_out, q_out, status)
    if (status /= PPA_SOL_AGE_REPORT_OK) error stop 'valid report candidate rejected'
    do i = 1, nnode
      if (transfer(age(i), 0_int64) /= transfer(profile_out(i), 0_int64)) error stop 'profile copy mismatch'
    end do
    values = [acc_bot / outper, acc_root / outper, acc_surface / outper]
    if (transfer(values(1), 0_int64) /= transfer(bot_out, 0_int64) .or. &
        transfer(values(2), 0_int64) /= transfer(root_out, 0_int64) .or. &
        transfer(values(3), 0_int64) /= transfer(surface_out, 0_int64)) error stop 'normalized report mismatch'
    do level = 1, nlevel
      expected = acc_drain(level) / outper
      if (transfer(expected, 0_int64) /= transfer(drain_out(level), 0_int64)) error stop 'drain age normalization mismatch'
      qsum = 0.0_real64
      do i = 1, nnode
        if (drainage(level, i) > 0.0_real64) qsum = qsum + drainage(level, i)
      end do
      if (transfer(qsum, 0_int64) /= transfer(q_out(level), 0_int64)) error stop 'positive drainage sum mismatch'
    end do
  end do
  print '(a)', 'PPA_SOL_AGE_REPORT_B1_11_NUMERIC_VALUES_100000x7x4=PASS'
  print '(a)', 'PPA_SOL_AGE_REPORT_POSITIVE_DRAINAGE_AND_INTERVAL_NORMALIZATION=PASS'

  age(1) = ieee_value(0.0_real64, ieee_quiet_nan)
  call ppa_sol_age_report_values(age, acc_bot, acc_root, acc_surface, acc_drain, outper, drainage, &
       profile_out, bot_out, root_out, surface_out, drain_out, q_out, status)
  if (status /= PPA_SOL_AGE_REPORT_INVALID_INPUT) error stop 'nonfinite report input accepted'
  call ppa_sol_age_report_values(age, acc_bot, acc_root, acc_surface, acc_drain, 0.0_real64, drainage, &
       profile_out, bot_out, root_out, surface_out, drain_out, q_out, status)
  if (status /= PPA_SOL_AGE_REPORT_INVALID_INPUT) error stop 'invalid output interval accepted'
  print '(a)', 'PPA_SOL_AGE_REPORT_INVALID_INPUT_FAIL_CLOSED=PASS'
end program test_ppa_sol_age_report_source_oracle
