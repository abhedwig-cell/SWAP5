program test_fpe_timearch10_profile
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_timestep_numerical_profile
  implicit none
  type(timestep_numerical_profile_t) :: cfg
  integer :: status

  cfg=make_legacy_numerics_profile(1.0e-6_real64,0.04_real64,2.0e-4_real64,4,30,2.0_real64,0.5_real64,2.0_real64)
  call cfg%validate(status)
  if(status/=TIMESTEP_PROFILE_STATUS_OK) error stop 'valid legacy rejected'
  if(.not.cfg%execution_ready()) error stop 'legacy not ready'
  if(cfg%kind/=TIMESTEP_PROFILE_LEGACY_NUMERICS) error stop 'legacy kind'
  if(cfg%legacy%dtmin/=1.0e-6_real64) error stop 'legacy dtmin roundtrip'
  if(cfg%legacy%dtmax/=0.04_real64) error stop 'legacy dtmax roundtrip'
  if(cfg%legacy%initial_dt/=2.0e-4_real64) error stop 'legacy initial dt roundtrip'
  if(cfg%legacy%numbit_crit/=4 .or. cfg%legacy%maxit/=30) error stop 'legacy integer roundtrip'
  if(cfg%legacy%fact_increase/=2.0_real64 .or. cfg%legacy%fact_decrease/=0.5_real64 .or. &
     cfg%legacy%fact_failure/=2.0_real64) error stop 'legacy factor roundtrip'

  cfg=make_legacy_numerics_profile(0.01_real64,0.005_real64,0.007_real64,4,8,2.0_real64,0.5_real64,2.0_real64)
  call cfg%validate(status)
  if(status/=TIMESTEP_PROFILE_STATUS_INVALID) error stop 'invalid bounds accepted'

  cfg=make_legacy_numerics_profile(0.001_real64,0.02_real64,0.005_real64,4,8,0.9_real64,0.5_real64,2.0_real64)
  call cfg%validate(status)
  if(status/=TIMESTEP_PROFILE_STATUS_INVALID) error stop 'invalid increase accepted'

  cfg=make_auto_reference_profile('future-auto-reference',1.0e-6_real64,.false.,0.0_real64)
  call cfg%validate(status)
  if(status/=TIMESTEP_PROFILE_STATUS_OK) error stop 'auto without user ceiling rejected'
  if(cfg%execution_ready()) error stop 'unadmitted auto executable'
  if(cfg%kind/=TIMESTEP_PROFILE_AUTO_REFERENCE) error stop 'auto kind'
  if(cfg%automatic%expert_ceiling_present) error stop 'auto unexpectedly requires ceiling'
  if(cfg%automatic%internal_retry_floor/=1.0e-6_real64) error stop 'internal floor roundtrip'

  cfg=make_auto_reference_profile('future-auto-reference',1.0e-6_real64,.true.,0.25_real64)
  call cfg%validate(status)
  if(status/=TIMESTEP_PROFILE_STATUS_OK) error stop 'expert ceiling rejected'
  if(cfg%execution_ready()) error stop 'expert ceiling enabled controller'
  if(.not.cfg%automatic%expert_ceiling_present .or. cfg%automatic%expert_ceiling/=0.25_real64) &
    error stop 'expert ceiling roundtrip'

  cfg=make_auto_reference_profile('future-auto-reference',1.0e-6_real64,.true.,0.25_real64,.true.)
  call cfg%validate(status)
  if(status/=TIMESTEP_PROFILE_STATUS_OK) error stop 'admitted auto invalid'
  if(.not.cfg%execution_ready()) error stop 'admitted auto not ready'

  cfg=make_auto_reference_profile('',1.0e-6_real64,.false.,0.0_real64)
  call cfg%validate(status)
  if(status/=TIMESTEP_PROFILE_STATUS_INVALID) error stop 'missing controller id accepted'

  print '(A)', 'F_PE_TIMEARCH10_PROFILE=PASS'
end program test_fpe_timearch10_profile
