! Bounded degeneration, not a ponded preferential-entry model.
module mod_rfm_matrix_only_surface_composition
 use,intrinsic::iso_fortran_env,only:real64
 use,intrinsic::ieee_arithmetic,only:ieee_is_finite
 use mod_soil_water_solver_contract,only:soil_water_top_boundary_result_t,SW_TOP_BOUNDARY_AVAILABLE, &
      SW_TOP_BOUNDARY_REGIME_FLUX,SW_TOP_BOUNDARY_REGIME_HEAD
 use mod_rfm_unponded_activation,only:rfm_unponded_activation_result_t,RFM_ACTIVATION_AVAILABLE
 use mod_rfm_unponded_surface_composition,only:rfm_unponded_surface_composition_result_t, &
      RFM_SURFACE_COMPOSITION_AVAILABLE,RFM_SURFACE_COMPOSITION_REFERENCE_REQUIRED,RFM_SURFACE_COMPOSITION_INVALID
 implicit none
 private
 public::compose_rfm_matrix_only_surface_receipt
contains
 pure subroutine compose_rfm_matrix_only_surface_receipt(preflight,activation,tolerance,result)
  type(soil_water_top_boundary_result_t),intent(in)::preflight
  type(rfm_unponded_activation_result_t),intent(in)::activation
  real(real64),intent(in)::tolerance
  type(rfm_unponded_surface_composition_result_t),intent(out)::result
  real(real64)::v(6),residual
  result=rfm_unponded_surface_composition_result_t()
  result%status=RFM_SURFACE_COMPOSITION_INVALID
  if(.not.ieee_is_finite(tolerance))return
  if(tolerance<0.0_real64)return
  if(preflight%status/=SW_TOP_BOUNDARY_AVAILABLE)return
  if(.not.preflight%carries_surface_mass_terms.or..not.preflight%runoff_resolved)return
  if(preflight%regime/=SW_TOP_BOUNDARY_REGIME_FLUX.and.preflight%regime/=SW_TOP_BOUNDARY_REGIME_HEAD)return
  if(activation%status/=RFM_ACTIVATION_AVAILABLE)return
  v=[preflight%net_potential_surface_flux,preflight%candidate_ponding_depth,preflight%runoff_depth, &
     activation%matrix_rate_cm_per_day,activation%preferential_rate_cm_per_day,activation%preferential_fraction]
  if(.not.all(ieee_is_finite(v)))return
  if(any(v<0.0_real64))return
  ! Exact zero: never suppress a small, physically nonzero receipt.
  if(activation%preferential_rate_cm_per_day/=0.0_real64.or.activation%preferential_fraction/=0.0_real64)then
   result%status=RFM_SURFACE_COMPOSITION_REFERENCE_REQUIRED
   return
  end if
  residual=preflight%net_potential_surface_flux-activation%matrix_rate_cm_per_day
  if(abs(residual)>tolerance)return
  result%effective_supply_cm_per_day=preflight%net_potential_surface_flux
  result%matrix_supply_cm_per_day=activation%matrix_rate_cm_per_day
  result%partition_residual_cm_per_day=residual
  result%status=RFM_SURFACE_COMPOSITION_AVAILABLE
 end subroutine
end module
