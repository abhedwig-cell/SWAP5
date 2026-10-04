program test_matrix_only_surface
 use,intrinsic::iso_fortran_env,only:real64
 use,intrinsic::ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_soil_water_solver_contract
 use mod_rfm_unponded_activation
 use mod_rfm_unponded_surface_composition
 use mod_rfm_matrix_only_surface_composition
 implicit none
 type(soil_water_top_boundary_result_t)::p
 type(rfm_unponded_activation_result_t)::a
 type(rfm_unponded_activation_request_t)::q
 type(rfm_unponded_surface_composition_result_t)::r
 p%status=SW_TOP_BOUNDARY_AVAILABLE;p%regime=SW_TOP_BOUNDARY_REGIME_HEAD
 p%carries_surface_mass_terms=.true.;p%runoff_resolved=.true.
 p%candidate_ponding_depth=.25_real64;p%runoff_depth=.03_real64;p%net_potential_surface_flux=10.0_real64
 a%status=RFM_ACTIVATION_AVAILABLE;a%matrix_rate_cm_per_day=10.0_real64
 call check(RFM_SURFACE_COMPOSITION_AVAILABLE)
 ! Actual infiltration is not ownership of incoming rainfall.
 p%actual_top_flux=123.0_real64;call check(RFM_SURFACE_COMPOSITION_AVAILABLE)
 call compose_rfm_unponded_surface_receipt(p,a,1e-12_real64,r)
 if(r%status/=RFM_SURFACE_COMPOSITION_REFERENCE_REQUIRED)error stop 'A15 widened'
 a%preferential_rate_cm_per_day=1e-30_real64;call check(RFM_SURFACE_COMPOSITION_REFERENCE_REQUIRED)
 a%preferential_rate_cm_per_day=0.;a%preferential_fraction=1e-30_real64;call check(RFM_SURFACE_COMPOSITION_REFERENCE_REQUIRED)
 a%preferential_fraction=0.;a%matrix_rate_cm_per_day=9.;call check(RFM_SURFACE_COMPOSITION_INVALID)
 a%matrix_rate_cm_per_day=10.;p%runoff_resolved=.false.;call check(RFM_SURFACE_COMPOSITION_INVALID)
 p%runoff_resolved=.true.;p%candidate_ponding_depth=ieee_value(0.0_real64,ieee_quiet_nan)
 call check(RFM_SURFACE_COMPOSITION_INVALID)
 p%candidate_ponding_depth=.25;p%net_potential_surface_flux=0.;a%matrix_rate_cm_per_day=0.
 call check(RFM_SURFACE_COMPOSITION_AVAILABLE)
 ! A ponded activation result's default zeros are not an available zero receipt.
 q%sigma_b=.05_real64;q%matrix_conductivity_cm_per_day=1.0849365899776511_real64
 q%surface_sorptivity_cm_sqrt_day=1.;q%source_rate_cm_per_day=10.
 q%event_age_day=7.324218749_real64*1e-8_real64;q%ponding_depth_cm=7.330432755e-8_real64
 call evaluate_rfm_unponded_activation(q,a)
 if(a%status==RFM_ACTIVATION_AVAILABLE)error stop 'unponded activation silently widened'
 p%net_potential_surface_flux=10.;call check(RFM_SURFACE_COMPOSITION_INVALID)
 print '(a)','A28_MATRIX_ONLY_SURFACE=PASS'
contains
 subroutine check(expected)
 integer,intent(in)::expected
 call compose_rfm_matrix_only_surface_receipt(p,a,1e-12_real64,r)
 if(r%status/=expected)error stop 'matrix-only surface status'
 if(expected==RFM_SURFACE_COMPOSITION_AVAILABLE)then
  if(r%preferential_supply_cm_per_day/=0.)error stop 'invented preferential source'
  if(r%effective_supply_cm_per_day/=p%net_potential_surface_flux)error stop 'incoming owner'
 end if
 end subroutine
end program
