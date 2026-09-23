program test_sw_rib_adm01_geometry_policy
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_surface_water_geometry_policy
  implicit none
  type(surface_water_geometry_policy_t) :: p

  if (validate_surface_water_geometry_policy(p) /= SW_GEOMETRY_POLICY_MISSING) error stop 1

  p%mode = SW_GEOMETRY_LEGACY_STTAB_EPSILON
  p%transition_epsilon_m = 1.0e-6_real64
  if (validate_surface_water_geometry_policy(p) /= SW_GEOMETRY_POLICY_INVALID_ERROR_BUDGET) error stop 2
  p%declared_max_storage_error_m3_per_m2 = 1.0e-6_real64
  if (validate_surface_water_geometry_policy(p) /= SW_GEOMETRY_POLICY_OK) error stop 3

  p = surface_water_geometry_policy_t()
  p%mode = SW_GEOMETRY_RIBASIM_NATIVE
  if (validate_surface_water_geometry_policy(p) /= SW_GEOMETRY_POLICY_NATIVE_ID_MISSING) error stop 4
  p%native_geometry_contract_id = 'ribasim-profile-v1'
  if (validate_surface_water_geometry_policy(p) /= SW_GEOMETRY_POLICY_OK) error stop 5

  write(*,'(A)') 'SW_RIB_ADM01_G4_GEOMETRY_POLICY_GUARD=PASS'
end program test_sw_rib_adm01_geometry_policy
