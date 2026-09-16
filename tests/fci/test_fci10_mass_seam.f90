program test_fci10_mass_seam
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_canonical_contracts, only: canonical_mass_accounting_t
  use mod_b1_10_process_checkpoint, only: b1_10_process_state_t
  use mod_b1_10_mass_seam
  use mod_b1_10_trial_mass, only: b1_10_trial_mass_t, begin_b1_10_trial_mass, &
       record_b1_10_trial_mass_step, record_b1_10_trial_interception_loss, invalidate_b1_10_trial_mass
  use MOD_swap_base, only: swcrop, swsnow, swmacro
  implicit none
  type(b1_10_process_state_t) :: a,b
  type(canonical_mass_accounting_t) :: m
  type(b1_10_trial_mass_t) :: trial
  real(real64) :: s
  logical :: complete

  call begin_b1_10_trial_mass(trial)
  call record_b1_10_trial_mass_step(trial,0.2_real64,0.1_real64,0.05_real64,0.0_real64,-0.03_real64, &
       0.02_real64,0.04_real64,0.01_real64,-0.02_real64,0.06_real64,0.01_real64,0.03_real64)
  call record_b1_10_trial_interception_loss(trial,0.005_real64)
  if (abs(trial%total_in-0.39_real64)>1.0e-14_real64) error stop 'trial total in mismatch'
  if (abs(trial%total_out-0.185_real64)>1.0e-14_real64) error stop 'trial total out mismatch'
  call invalidate_b1_10_trial_mass(trial)
  if (trial%complete) error stop 'trial invalidation failed'

  swcrop=1; swsnow=0; swmacro=0
  a%volact=10.0_real64; a%pond=0.2_real64
  b%volact=9.8_real64; b%pond=0.1_real64
  allocate(a%crop,b%crop)
  a%crop%sicact=0.05_real64; b%crop%sicact=0.02_real64
  call b1_10_qualified_profile_storage(a,s,complete)
  if (.not.complete .or. abs(s-10.25_real64)>1.0e-14_real64) error stop 'storage seam mismatch'
  call begin_b1_10_trial_mass(trial)
  trial%total_in=0.4_real64; trial%total_out=0.73_real64
  call b1_10_build_mass_accounting(a,b,trial,m)
  if (.not.m%complete) error stop 'mass accounting unexpectedly incomplete'
  if (abs(m%residual) > 1.0e-14_real64) error stop 'mass residual mismatch'

  swsnow=1
  call b1_10_qualified_profile_storage(a,s,complete)
  if (complete) error stop 'snow profile must fail closed'
  swsnow=0; swmacro=1
  call b1_10_qualified_profile_storage(a,s,complete)
  if (complete) error stop 'macropore profile must fail closed'
  swmacro=0
  trial%complete=.false.
  call b1_10_build_mass_accounting(a,b,trial,m)
  if (m%complete) error stop 'missing flux seam must fail closed'

  print *, 'FCI10_MASS_SEAM PASS'
end program
