program test_sw_rib_adm01_external_head_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_surface_water_ownership_profile
  use mod_fmr_drainage_response_binding, only: fmr_drainage_response_level_parameters_t, &
       fmr_drainage_response_level_control_t, FMR_DRAIN_VARIANT_EXTENDED_SIGNED, FMR_DRAIN_VARIANT_LINEAR
  use mod_fmr_external_surface_water_head_adapter
  implicit none

  type(surface_water_ownership_profile_t) :: profile
  type(external_surface_water_head_snapshot_t) :: snapshot
  type(fmr_drainage_response_level_parameters_t) :: p(2)
  type(fmr_drainage_response_level_control_t), allocatable :: controls(:)
  integer :: status

  profile%owner = SURFACE_WATER_OWNER_EXTERNAL_RIBASIM
  profile%internal_fixed_weir_state_active = .false.
  profile%external_surface_water_head_available = .true.

  p(1)%variant = FMR_DRAIN_VARIANT_EXTENDED_SIGNED
  p(2)%variant = FMR_DRAIN_VARIANT_LINEAR

  allocate(snapshot%head_cm_by_level(2))
  snapshot%head_cm_by_level = [-35.0_real64, -20.0_real64]

  snapshot%accepted = .false.
  snapshot%accepted_revision = 7
  call bind_external_surface_water_heads(profile, snapshot, p, controls, status)
  if (status /= EXT_SW_HEAD_BIND_UNACCEPTED_SNAPSHOT) error stop 1

  snapshot%accepted = .true.
  call bind_external_surface_water_heads(profile, snapshot, p, controls, status)
  if (status /= EXT_SW_HEAD_BIND_OK) error stop 2
  if (.not. allocated(controls) .or. size(controls) /= 2) error stop 3
  if (.not. controls(1)%resolved_surface_water_head_supplied) error stop 4
  if (controls(1)%resolved_surface_water_head_cm /= -35.0_real64) error stop 5
  if (controls(2)%resolved_surface_water_head_supplied) error stop 6

  deallocate(controls)
  profile%internal_fixed_weir_state_active = .true.
  call bind_external_surface_water_heads(profile, snapshot, p, controls, status)
  if (status /= EXT_SW_HEAD_BIND_INVALID_OWNER) error stop 7

  profile%internal_fixed_weir_state_active = .false.
  snapshot%accepted_revision = -1
  call bind_external_surface_water_heads(profile, snapshot, p, controls, status)
  if (status /= EXT_SW_HEAD_BIND_UNACCEPTED_SNAPSHOT) error stop 8

  write(*,'(A)') 'SW_RIB_ADM01_EXTERNAL_HEAD_BINDING=PASS'
end program test_sw_rib_adm01_external_head_binding
