program test_ppa_sol_age_timestep_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_sol_age_timestep
  implicit none

  integer, parameter :: n = 4, nlayer = 2, ncase = 100000
  real(real64) :: theta(n + 1), upper(n + 1), lower(n + 1), q(n + 1), porosity(nlayer), ldis(nlayer), dz(n)
  real(real64) :: ref_value, got_value, diff, dispr, dummy, dt, dtmin, step, elapsed, next_elapsed
  integer :: layer(n), status, i, j
  logical :: loop

  do j = 1, ncase
    dt = 0.02_real64 + real(mod(j, 200), real64) * 1.0e-5_real64
    dtmin = 1.0e-5_real64
    do i = 1, n
      theta(i) = 0.08_real64 + real(mod(j * (i + 3), 67), real64) / 500.0_real64
      dz(i) = 0.1_real64 + real(mod(j + i * 11, 33), real64) / 300.0_real64
      layer(i) = 1 + mod(j + i, nlayer)
      q(i) = real(mod(j * (i + 7), 91) - 45, real64) / 10000.0_real64
    end do
    do i = 1, n + 1
      upper(i) = 0.2_real64 + real(mod(j + i * 5, 17), real64) / 100.0_real64
      lower(i) = 0.2_real64 + real(mod(j * 3 + i, 19), real64) / 100.0_real64
    end do
    porosity = [0.42_real64, 0.47_real64]
    ldis = [0.004_real64, 0.009_real64]

    ref_value = dt
    do i = 1, n
      diff = 0.17_real64 * ((upper(i + 1) * theta(i) + lower(i) * theta(i + 1)) ** 2.33_real64) / &
           (porosity(layer(i)) ** 2)
      dispr = diff + ldis(layer(i)) * abs(q(i)) / theta(i)
      if (dispr < 1.0e-8_real64) dispr = 1.0e-8_real64
      dummy = dz(i) * dz(i) * theta(i) / 2.0_real64 / dispr
      ref_value = min(ref_value, dummy)
    end do
    call ppa_sol_age_stable_candidate(dt, theta(1:n), theta(2:n+1), upper, lower, 0.17_real64, ldis, q, porosity, dz, &
         layer, got_value, status)
    if (status /= PPA_SOL_AGE_DT_OK .or. transfer(ref_value, 0_int64) /= transfer(got_value, 0_int64)) &
         error stop 'stable candidate mismatch'

    elapsed = 0.0_real64
    call ppa_sol_age_next_substep(dt, elapsed, got_value, dtmin, step, next_elapsed, loop, status)
    if (status /= PPA_SOL_AGE_DT_OK .or. .not. loop .or. step <= 0.0_real64 .or. &
        abs(next_elapsed - (elapsed + step)) > epsilon(step)) &
         error stop 'first interval step mismatch'
    if (j == 1) then
      call ppa_sol_age_next_substep(1.0e-8_real64, 0.0_real64, 1.0e-4_real64, dtmin, step, next_elapsed, loop, status)
      if (status /= PPA_SOL_AGE_DT_OK .or. loop .or. abs(step) > tiny(step)) error stop 'strict threshold mismatch'
      call ppa_sol_age_next_substep(1.0e-3_real64, 0.0_real64, 1.0e-6_real64, 2.0e-3_real64, &
           step, next_elapsed, loop, status)
      if (status /= PPA_SOL_AGE_DT_OK .or. .not. loop .or. abs(step - 2.0e-3_real64) > epsilon(step) .or. &
          abs(next_elapsed - 2.0e-3_real64) > epsilon(step)) error stop 'minimum-step source order mismatch'
    end if
  end do
  print '(a)', 'PPA_SOL_AGE_DT_B1_11_STABLE_CANDIDATE_100000=PASS'
  print '(a)', 'PPA_SOL_AGE_DT_STRICT_REMAINDER_AND_DTMIN=PASS'

  theta(1) = ieee_value(0.0_real64, ieee_quiet_nan)
  call ppa_sol_age_stable_candidate(dt, theta(2:n+1), theta(1:n), upper, lower, 0.17_real64, ldis, q, porosity, dz, &
       layer, got_value, status)
  if (status /= PPA_SOL_AGE_DT_INVALID_INPUT) error stop 'nonfinite input accepted'
  call ppa_sol_age_next_substep(dt, 0.0_real64, 0.0_real64, dtmin, step, next_elapsed, loop, status)
  if (status /= PPA_SOL_AGE_DT_INVALID_INPUT) error stop 'invalid step accepted'
  print '(a)', 'PPA_SOL_AGE_DT_INVALID_INPUT_FAIL_CLOSED=PASS'
end program test_ppa_sol_age_timestep_source_oracle
