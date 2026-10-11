program test_ppa_wu05a15_rfm_unponded_surface_composition
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_top_boundary_result_t, &
       SW_TOP_BOUNDARY_AVAILABLE, SW_TOP_BOUNDARY_UNAVAILABLE, &
       SW_TOP_BOUNDARY_REGIME_FLUX, SW_TOP_BOUNDARY_REGIME_HEAD
  use mod_rfm_unponded_activation, only: rfm_unponded_activation_result_t, &
       RFM_ACTIVATION_AVAILABLE
  use mod_rfm_unponded_surface_composition
  implicit none

  real(real64), parameter :: tol = 1.0e-12_real64
  type(soil_water_top_boundary_result_t) :: preflight
  type(rfm_unponded_activation_result_t) :: activation
  type(rfm_unponded_surface_composition_result_t) :: result

  preflight%status = SW_TOP_BOUNDARY_AVAILABLE
  preflight%regime = SW_TOP_BOUNDARY_REGIME_FLUX
  preflight%carries_surface_mass_terms = .true.
  preflight%runoff_resolved = .true.
  preflight%candidate_ponding_depth = 0.0_real64
  preflight%runoff_depth = 0.0_real64
  preflight%net_potential_surface_flux = 8.0_real64
  ! Deliberately not used as partition source.
  preflight%actual_top_flux = -8.0_real64

  activation%status = RFM_ACTIVATION_AVAILABLE
  activation%matrix_rate_cm_per_day = 5.961748798503473_real64
  activation%preferential_rate_cm_per_day = 2.038251201496527_real64
  activation%preferential_fraction = 0.25478140018706585_real64

  call compose_rfm_unponded_surface_receipt(preflight,activation,tol,result)
  if (result%status /= RFM_SURFACE_COMPOSITION_AVAILABLE) error stop 'A15 available'
  if (abs(result%effective_supply_cm_per_day-8.0_real64)>tol) error stop 'A15 supply'
  if (abs(result%matrix_supply_cm_per_day-activation%matrix_rate_cm_per_day)>tol) error stop 'A15 matrix'
  if (abs(result%preferential_supply_cm_per_day-activation%preferential_rate_cm_per_day)>tol) error stop 'A15 pref'
  if (abs(result%partition_residual_cm_per_day)>tol) error stop 'A15 residual'

  ! Prove actual_top_flux is not the owner of the activation source.
  preflight%actual_top_flux = -123.0_real64
  call compose_rfm_unponded_surface_receipt(preflight,activation,tol,result)
  if (result%status /= RFM_SURFACE_COMPOSITION_AVAILABLE) error stop 'A15 actual flux leaked into ownership'
  if (abs(result%effective_supply_cm_per_day-8.0_real64)>tol) error stop 'A15 actual flux changed supply'

  preflight%runoff_depth = 1.0e-4_real64
  call compose_rfm_unponded_surface_receipt(preflight,activation,tol,result)
  if (result%status /= RFM_SURFACE_COMPOSITION_REFERENCE_REQUIRED) error stop 'A15 runoff fail closed'

  preflight%runoff_depth = 0.0_real64
  preflight%candidate_ponding_depth = 1.0e-4_real64
  call compose_rfm_unponded_surface_receipt(preflight,activation,tol,result)
  if (result%status /= RFM_SURFACE_COMPOSITION_REFERENCE_REQUIRED) error stop 'A15 ponding fail closed'

  preflight%candidate_ponding_depth = 0.0_real64
  preflight%regime = SW_TOP_BOUNDARY_REGIME_HEAD
  call compose_rfm_unponded_surface_receipt(preflight,activation,tol,result)
  if (result%status /= RFM_SURFACE_COMPOSITION_REFERENCE_REQUIRED) error stop 'A15 head fail closed'

  preflight%regime = SW_TOP_BOUNDARY_REGIME_FLUX
  preflight%status = SW_TOP_BOUNDARY_UNAVAILABLE
  call compose_rfm_unponded_surface_receipt(preflight,activation,tol,result)
  if (result%status /= RFM_SURFACE_COMPOSITION_INVALID) error stop 'A15 unavailable accepted'

  preflight%status = SW_TOP_BOUNDARY_AVAILABLE
  preflight%carries_surface_mass_terms = .false.
  call compose_rfm_unponded_surface_receipt(preflight,activation,tol,result)
  if (result%status /= RFM_SURFACE_COMPOSITION_INVALID) error stop 'A15 no mass terms accepted'

  preflight%carries_surface_mass_terms = .true.
  activation%preferential_rate_cm_per_day = 2.0_real64
  call compose_rfm_unponded_surface_receipt(preflight,activation,tol,result)
  if (result%status /= RFM_SURFACE_COMPOSITION_INVALID) error stop 'A15 mismatch accepted'

  print '(a)', 'PPA_WU05A15_RFM_UNPONDED_SURFACE_COMPOSITION=PASS'
end program test_ppa_wu05a15_rfm_unponded_surface_composition
