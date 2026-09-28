program test_ppa_sol_age_gwl1m_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_ppa_sol_age_gwl1m
  implicit none

  integer, parameter :: n = 8, ncase = 100000
  real(real64), parameter :: sentinel = -9999.9_real64
  real(real64) :: top(n), bottom(n), age(n), thetas(n), gwl, ztop, zbot, dz, sum0, sum1, reference
  real(real64) :: got_age, got_sum0
  integer :: status, i, j

  do j = 1, ncase
    gwl = 2.0_real64 + real(mod(j, 200), real64) / 100.0_real64
    do i = 1, n
      top(i) = gwl - 0.05_real64 - real(i - 1, real64) * 0.18_real64 + real(mod(j + i, 13), real64) / 1000.0_real64
      bottom(i) = top(i) - (0.07_real64 + real(mod(j * (i + 1), 17), real64) / 100.0_real64)
      age(i) = real(mod(j * (i + 3), 109), real64) / 10.0_real64
      thetas(i) = 0.25_real64 + real(mod(j * (i + 7), 73), real64) / 500.0_real64
    end do
    sum0 = 0.0_real64
    sum1 = 0.0_real64
    do i = 1, n
      ztop = top(i)
      zbot = bottom(i)
      if (gwl < ztop) ztop = gwl
      if (gwl - 100.0_real64 > zbot) zbot = gwl - 100.0_real64
      dz = ztop - zbot
      sum1 = sum1 + dz * age(i) * thetas(i)
      sum0 = sum0 + dz * thetas(i)
    end do
    reference = sentinel
    if (sum0 > 1.0e-12_real64) reference = sum1 / sum0
    call ppa_sol_age_gwl1m_candidate(top, bottom, age, thetas, gwl, sentinel, got_age, got_sum0, status)
    if (status /= PPA_SOL_AGE_GWL1M_OK) error stop 'valid profile rejected'
    if (transfer(reference, 0_int64) /= transfer(got_age, 0_int64)) error stop 'weighted age mismatch'
    if (transfer(sum0, 0_int64) /= transfer(got_sum0, 0_int64)) error stop 'weighted depth mismatch'
  end do
  print '(a)', 'PPA_SOL_AGE_GWL1M_B1_11_CLIPPED_PROFILE_100000x8=PASS'

  top = 0.1_real64
  bottom = 0.0_real64
  age = 3.0_real64
  thetas = 0.4_real64
  call ppa_sol_age_gwl1m_candidate(top, bottom, age, thetas, 0.0_real64, sentinel, got_age, got_sum0, status)
  if (status /= PPA_SOL_AGE_GWL1M_OK .or. transfer(got_age, 0_int64) /= transfer(sentinel, 0_int64)) &
       error stop 'no-overlap sentinel mismatch'
  print '(a)', 'PPA_SOL_AGE_GWL1M_NO_OVERLAP_SENTINEL=PASS'

  top(1) = bottom(1)
  call ppa_sol_age_gwl1m_candidate(top, bottom, age, thetas, 0.0_real64, sentinel, got_age, got_sum0, status)
  if (status /= PPA_SOL_AGE_GWL1M_INVALID_INPUT) error stop 'inverted geometry accepted'
  print '(a)', 'PPA_SOL_AGE_GWL1M_INVALID_INPUT_FAIL_CLOSED=PASS'
end program test_ppa_sol_age_gwl1m_source_oracle
