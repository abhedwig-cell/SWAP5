program test_sw_rib_adm01_owner_xor
  use mod_surface_water_ownership_profile
  implicit none
  type(surface_water_ownership_profile_t) :: p

  p = surface_water_ownership_profile_t()
  if (validate_surface_water_ownership_profile(p) /= SURFACE_WATER_OWNERSHIP_OK) error stop 1

  p%owner = SURFACE_WATER_OWNER_SWAP_FIXED_WEIR
  p%internal_fixed_weir_state_active = .true.
  p%external_surface_water_head_available = .false.
  if (validate_surface_water_ownership_profile(p) /= SURFACE_WATER_OWNERSHIP_OK) error stop 2

  p%external_surface_water_head_available = .true.
  if (validate_surface_water_ownership_profile(p) /= SURFACE_WATER_OWNERSHIP_DUPLICATE_STATE_OWNER) error stop 3

  p%owner = SURFACE_WATER_OWNER_EXTERNAL_RIBASIM
  p%internal_fixed_weir_state_active = .true.
  if (validate_surface_water_ownership_profile(p) /= SURFACE_WATER_OWNERSHIP_INTERNAL_STATE_FORBIDDEN) error stop 4

  p%internal_fixed_weir_state_active = .false.
  p%external_surface_water_head_available = .false.
  if (validate_surface_water_ownership_profile(p) /= SURFACE_WATER_OWNERSHIP_EXTERNAL_HEAD_MISSING) error stop 5

  p%external_surface_water_head_available = .true.
  if (validate_surface_water_ownership_profile(p) /= SURFACE_WATER_OWNERSHIP_OK) error stop 6

  write(*,'(A)') 'SW_RIB_ADM01_OWNER_XOR=PASS'
end program test_sw_rib_adm01_owner_xor
