program test_ppa_sol_age_surface_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_sol_age_surface
  implicit none

  integer, parameter :: ncase = 100000
  real(real64) :: irr, ageirr, rain, agepre, dt, pondm1, agepondm1, qtop, pond, snow, runots
  real(real64) :: agepond, agefluxt, isqtop, icdown, icsurface
  real(real64) :: refpond, refflux, refisq, refdown, refsurface, agesurf, denominator
  integer :: status, j

  do j = 1, ncase
    irr = real(mod(j * 7, 61), real64) / 100.0_real64
    ageirr = real(mod(j * 11, 37), real64) / 10.0_real64
    rain = real(mod(j * 13, 43), real64) / 100.0_real64
    agepre = real(mod(j * 17, 29), real64) / 10.0_real64
    dt = 0.001_real64 + real(mod(j, 100), real64) / 1000.0_real64
    pondm1 = 0.01_real64 + real(mod(j * 3, 97), real64) / 1000.0_real64
    agepondm1 = real(mod(j * 19, 31), real64) / 10.0_real64
    qtop = -1.1e-6_real64 - real(mod(j, 71), real64) / 100000.0_real64
    pond = 0.02_real64 + real(mod(j * 23, 89), real64) / 1000.0_real64
    snow = real(mod(j, 11), real64) / 10.0_real64
    runots = dt

    agesurf = (irr * ageirr + rain * agepre) * dt + pondm1 * agepondm1
    denominator = pond - qtop * dt
    refpond = agesurf / denominator
    refflux = qtop * (1.0_real64 - snow) * refpond * dt
    agesurf = agesurf + refflux
    refisq = qtop * (1.0_real64 - snow) * refpond
    refdown = qtop * (1.0_real64 - snow) * 0.5_real64 * (refpond + agepondm1) * dt
    refsurface = 0.5_real64 * (refpond + agepondm1) * runots

    call ppa_sol_age_surface_candidate(irr, ageirr, rain, agepre, dt, pondm1, agepondm1, qtop, pond, snow, &
         runots, agepond, agefluxt, isqtop, icdown, icsurface, status)
    if (status /= PPA_SOL_AGE_SURFACE_OK) error stop 'valid active boundary rejected'
    if (transfer(refpond, 0_int64) /= transfer(agepond, 0_int64)) error stop 'pond age mismatch'
    if (transfer(refflux, 0_int64) /= transfer(agefluxt, 0_int64)) error stop 'top age amount mismatch'
    if (transfer(refisq, 0_int64) /= transfer(isqtop, 0_int64)) error stop 'top age rate mismatch'
    if (transfer(refdown, 0_int64) /= transfer(icdown, 0_int64)) error stop 'downward cumulative increment mismatch'
    if (transfer(refsurface, 0_int64) /= transfer(icsurface, 0_int64)) error stop 'surface cumulative mismatch'
    if (j == 1) then
      call ppa_sol_age_surface_candidate(irr, ageirr, rain, agepre, dt, pondm1, agepondm1, -1.0e-6_real64, &
           pond, snow, runots, agepond, agefluxt, isqtop, icdown, icsurface, status)
      if (status /= PPA_SOL_AGE_SURFACE_OK .or. abs(agepond) > tiny(agepond) .or. abs(agefluxt) > tiny(agefluxt)) &
           error stop 'threshold branch mismatch'
      call ppa_sol_age_surface_candidate(irr, ageirr, rain, agepre, dt, pondm1, agepondm1, 0.0_real64, &
           pond, snow, runots, agepond, agefluxt, isqtop, icdown, icsurface, status)
      if (status /= PPA_SOL_AGE_SURFACE_OK .or. abs(isqtop) > tiny(isqtop)) error stop 'nonnegative flux branch mismatch'
    end if
  end do
  print '(a)', 'PPA_SOL_AGE_SURFACE_B1_11_ACTIVE_BRANCH_100000=PASS'
  print '(a)', 'PPA_SOL_AGE_SURFACE_TOP_THRESHOLD_AND_INACTIVE_BRANCH=PASS'

  pond = ieee_value(0.0_real64, ieee_quiet_nan)
  call ppa_sol_age_surface_candidate(irr, ageirr, rain, agepre, dt, pondm1, agepondm1, qtop, pond, snow, &
       runots, agepond, agefluxt, isqtop, icdown, icsurface, status)
  if (status /= PPA_SOL_AGE_SURFACE_INVALID_INPUT) error stop 'nonfinite boundary input accepted'
  call ppa_sol_age_surface_candidate(irr, ageirr, rain, agepre, dt, pondm1, agepondm1, qtop, -0.001_real64, snow, &
       runots, agepond, agefluxt, isqtop, icdown, icsurface, status)
  if (status /= PPA_SOL_AGE_SURFACE_INVALID_INPUT) error stop 'invalid active denominator accepted'
  print '(a)', 'PPA_SOL_AGE_SURFACE_INVALID_INPUT_FAIL_CLOSED=PASS'
end program test_ppa_sol_age_surface_source_oracle
