program test_fpe_nlglob14z43f_profile
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_timestep_numerical_profile, only: timestep_numerical_profile_t, &
       make_legacy_numerics_profile, make_moving_interface_manager_profile, &
       TIMESTEP_PROFILE_INVALID, TIMESTEP_PROFILE_LEGACY_NUMERICS, &
       TIMESTEP_PROFILE_MOVING_INTERFACE_MANAGER, TIMESTEP_PROFILE_STATUS_OK
  implicit none
  type(timestep_numerical_profile_t) :: unset_profile, legacy_profile, manager_not_ready, manager_ready
  integer :: status
  logical :: ok

  ok=.true.
  if(unset_profile%kind/=TIMESTEP_PROFILE_INVALID) ok=.false.
  if(unset_profile%execution_ready()) ok=.false.

  legacy_profile=make_legacy_numerics_profile(1.0e-6_real64,1.0_real64,0.01_real64,2,8,1.2_real64,0.5_real64,2.0_real64)
  call legacy_profile%validate(status)
  if(status/=TIMESTEP_PROFILE_STATUS_OK) ok=.false.
  if(legacy_profile%kind/=TIMESTEP_PROFILE_LEGACY_NUMERICS) ok=.false.
  if(.not.legacy_profile%execution_ready()) ok=.false.

  manager_not_ready=make_moving_interface_manager_profile('MOVING_INTERFACE_MANAGER')
  call manager_not_ready%validate(status)
  if(status/=TIMESTEP_PROFILE_STATUS_OK) ok=.false.
  if(manager_not_ready%kind/=TIMESTEP_PROFILE_MOVING_INTERFACE_MANAGER) ok=.false.
  if(manager_not_ready%execution_ready()) ok=.false.

  manager_ready=make_moving_interface_manager_profile('MOVING_INTERFACE_MANAGER',.true.)
  call manager_ready%validate(status)
  if(status/=TIMESTEP_PROFILE_STATUS_OK) ok=.false.
  if(.not.manager_ready%execution_ready()) ok=.false.

  if(.not.ok) error stop 'Z43F profile seam qualification failed'
  write(*,'(a)') 'F_PE_NLGLOB14Z43F_PROFILE|DEFAULT_INVALID=1|LEGACY_READY=1|MANAGER_OPT_IN=1|MANAGER_NOT_DEFAULT=1'
  write(*,'(a)') 'F_PE_NLGLOB14Z43F_PROFILE=PASS'
end program test_fpe_nlglob14z43f_profile
