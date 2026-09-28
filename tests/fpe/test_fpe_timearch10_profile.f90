program test_fpe_timearch10_profile
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_timestep_numerical_profile
  implicit none
  type(timestep_numerical_profile_t) :: cfg
  integer :: status

  cfg=make_legacy_numerics_profile(1.0e-6_real64,0.04_real64,sqrt(4.0e-8_real64), &
       4,30,2.0_real64,0.5_real64,2.0_real64)
  call cfg%validate(status)
  if(status/=TIMESTEP_PROFILE_STATUS_OK) error stop 'valid legacy rejected'
  if(.not.cfg%execution_ready()) error stop 'legacy not execution ready'
  if(cfg%legacy%dtmin/=1.0e-6_real64) error stop 'legacy dtmin changed'
  if(cfg%legacy%dtmax/=0.04_real64) error stop 'legacy dtmax changed'
  if(cfg%legacy%numbit_crit/=4 .or. cfg%legacy%maxit/=30) error stop 'legacy integer policy changed'

  cfg=make_legacy_numerics_profile(0.02_real64,0.01_real64,0.015_real64,4,8,2.0_real64,0.5_real64,2.0_real64)
  call cfg%validate(status)
  if(status==TIMESTEP_PROFILE_STATUS_OK) error stop 'invalid legacy accepted'

  cfg=make_auto_reference_profile('future-auto-reference',1.0e-6_real64,.false.,0.0_real64)
  call cfg%validate(status)
  if(status/=TIMESTEP_PROFILE_STATUS_OK) error stop 'auto representation rejected'
  if(cfg%execution_ready()) error stop 'unadmitted auto executable'
  if(cfg%automatic%expert_ceiling_present) error stop 'auto unexpectedly requires ceiling'

  cfg=make_auto_reference_profile('future-auto-reference',1.0e-6_real64,.true.,0.25_real64,.false.)
  call cfg%validate(status)
  if(status/=TIMESTEP_PROFILE_STATUS_OK) error stop 'auto expert ceiling rejected'
  if(cfg%execution_ready()) error stop 'expert ceiling bypassed admission'

  cfg=make_auto_reference_profile('future-auto-reference',1.0e-6_real64,.true.,0.25_real64,.true.)
  if(.not.cfg%execution_ready()) error stop 'admitted auto not ready'

  print '(A)', 'F_PE_TIMEARCH10_PROFILE=PASS'
end program test_fpe_timearch10_profile
