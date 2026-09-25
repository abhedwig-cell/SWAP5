module mod_b110_adaptive_runtime_policy
  implicit none
  private
  public :: b110_adaptive_runtime_eligible

contains

  pure logical function b110_adaptive_runtime_eligible(effective_bottom_mode, swkimpl, swsophy, &
       reference_solver_selected, macropore_active, hysteresis_active, tabulated_hydraulics_active, &
       ksatexm_extension_active, elasticity_active, frost_active, root_extraction_active, snow_active, &
       soil_temperature_active, black_evaporation_active, boesten_evaporation_active, drainage_response_active, &
       fixed_weir_surface_water_active) result(ok)
    integer, intent(in) :: effective_bottom_mode, swkimpl, swsophy
    logical, intent(in) :: reference_solver_selected
    logical, intent(in) :: macropore_active, hysteresis_active, tabulated_hydraulics_active
    logical, intent(in) :: ksatexm_extension_active, elasticity_active, frost_active
    logical, intent(in) :: root_extraction_active, snow_active, soil_temperature_active
    logical, intent(in) :: black_evaporation_active, boesten_evaporation_active
    logical, intent(in) :: drainage_response_active, fixed_weir_surface_water_active

    ok = reference_solver_selected .and. effective_bottom_mode == 5 .and. swkimpl == 0 .and. swsophy == 0 .and. &
         .not. macropore_active .and. .not. hysteresis_active .and. .not. tabulated_hydraulics_active .and. &
         .not. ksatexm_extension_active .and. .not. elasticity_active .and. .not. frost_active .and. &
         .not. root_extraction_active .and. .not. snow_active .and. .not. soil_temperature_active .and. &
         .not. black_evaporation_active .and. .not. boesten_evaporation_active .and. &
         .not. drainage_response_active .and. .not. fixed_weir_surface_water_active
  end function b110_adaptive_runtime_eligible

end module mod_b110_adaptive_runtime_policy
