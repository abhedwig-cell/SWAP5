program test_fpe_timearch10_profile
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_timestep_configuration_contract
  implicit none
  type(timestep_profile_t) :: cfg

  cfg=timestep_profile_t()
  cfg%profile=TS_PROFILE_LEGACY_NUMERICS
  cfg%legacy%dtmin=1.0e-6_real64
  cfg%legacy%dtmax=0.04_real64
  cfg%legacy%initial_dt=sqrt(cfg%legacy%dtmin*cfg%legacy%dtmax)
  cfg%legacy%numbit_crit=4
  cfg%legacy%maxit=30
  cfg%legacy%increase_factor=2.0_real64
  cfg%legacy%decrease_factor=0.5_real64
  cfg%legacy%failure_divisor=2.0_real64
  if(.not.valid_timestep_profile(cfg)) error stop 'valid legacy rejected'
  if(.not.execution_ready_timestep_profile(cfg)) error stop 'legacy not ready'

  cfg%legacy%dtmax=0.5_real64*cfg%legacy%dtmin
  if(valid_timestep_profile(cfg)) error stop 'invalid legacy accepted'

  cfg=timestep_profile_t()
  cfg%profile=TS_PROFILE_AUTO_REFERENCE
  cfg%automatic%controller_id='future-auto-reference'
  cfg%automatic%solver_retry_floor_dt=1.0e-6_real64
  cfg%automatic%expert_ceiling_present=.false.
  cfg%automatic%controller_admitted=.false.
  if(.not.valid_timestep_profile(cfg)) error stop 'valid auto representation rejected'
  if(execution_ready_timestep_profile(cfg)) error stop 'unadmitted auto executable'

  cfg%automatic%expert_ceiling_present=.true.
  cfg%automatic%expert_ceiling_dt=0.25_real64
  if(.not.valid_timestep_profile(cfg)) error stop 'expert ceiling rejected'
  if(execution_ready_timestep_profile(cfg)) error stop 'expert ceiling made unadmitted auto executable'

  cfg%automatic%controller_admitted=.true.
  if(.not.execution_ready_timestep_profile(cfg)) error stop 'admitted auto not ready'

  print '(A)', 'F_PE_TIMEARCH10_PROFILE=PASS'
end program test_fpe_timearch10_profile
