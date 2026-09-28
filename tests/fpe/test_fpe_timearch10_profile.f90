program test_fpe_timearch10_profile
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_timestep_numerical_profile
  implicit none

  type(timestep_numerical_profile_t) :: legacy, auto, invalid
  integer :: status

  legacy = make_legacy_numerics_profile(1.0e-6_real64, 0.04_real64, 0.002_real64, 4, 30, &
       2.0_real64, 0.5_real64, 2.0_real64)
  call legacy%validate(status)
  if(status /= TIMESTEP_PROFILE_STATUS_OK) error stop 'valid legacy rejected'
  if(.not. legacy%execution_ready()) error stop 'legacy not ready'
  if(legacy%legacy%dtmin /= 1.0e-6_real64) error stop 'legacy dtmin changed'
  if(legacy%legacy%dtmax /= 0.04_real64) error stop 'legacy dtmax changed'
  if(legacy%legacy%initial_dt /= 0.002_real64) error stop 'legacy initial dt changed'
  if(legacy%legacy%numbit_crit /= 4) error stop 'legacy numbit changed'
  if(legacy%legacy%maxit /= 30) error stop 'legacy maxit changed'
  if(legacy%legacy%fact_increase /= 2.0_real64) error stop 'legacy increase changed'
  if(legacy%legacy%fact_decrease /= 0.5_real64) error stop 'legacy decrease changed'
  if(legacy%legacy%fact_failure /= 2.0_real64) error stop 'legacy failure changed'

  invalid = make_legacy_numerics_profile(0.1_real64, 0.01_real64, 0.02_real64, 4, 30, &
       2.0_real64, 0.5_real64, 2.0_real64)
  call invalid%validate(status)
  if(status /= TIMESTEP_PROFILE_STATUS_INVALID) error stop 'invalid legacy accepted'
  if(invalid%execution_ready()) error stop 'invalid legacy ready'

  auto = make_auto_reference_profile('future-auto-reference', 1.0e-8_real64, .false., 0.0_real64)
  call auto%validate(status)
  if(status /= TIMESTEP_PROFILE_STATUS_OK) error stop 'auto representation rejected'
  if(auto%automatic%expert_ceiling_present) error stop 'auto requires user ceiling'
  if(auto%execution_ready()) error stop 'unadmitted auto executable'

  auto = make_auto_reference_profile('future-auto-reference', 1.0e-8_real64, .true., 0.25_real64)
  call auto%validate(status)
  if(status /= TIMESTEP_PROFILE_STATUS_OK) error stop 'expert ceiling rejected'
  if(auto%automatic%expert_ceiling /= 0.25_real64) error stop 'expert ceiling changed'
  if(auto%execution_ready()) error stop 'expert ceiling admitted controller'

  auto = make_auto_reference_profile('qualified-test-controller', 1.0e-8_real64, .false., 0.0_real64, .true.)
  call auto%validate(status)
  if(status /= TIMESTEP_PROFILE_STATUS_OK) error stop 'qualified auto invalid'
  if(.not. auto%execution_ready()) error stop 'qualified auto not ready'

  print '(A)', 'F_PE_TIMEARCH10_PROFILE=PASS'
end program test_fpe_timearch10_profile
