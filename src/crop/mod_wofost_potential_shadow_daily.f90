module mod_wofost_potential_shadow_daily
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_wofost_crop_owner_state, only: wofost_crop_owner_state_t, WOFOST_CROP_OWNER_OK
  use mod_wofost_potential_shadow_state, only: wofost_potential_shadow_state_t, &
       WOFOST_POTENTIAL_SHADOW_OK
  use mod_wofost_one_day_structural_evolution, only: wofost_one_day_forcing_t, &
       wofost_accepted_window_aggregates_t, wofost_one_day_update_parameters_t, &
       wofost_one_day_rate_packet_t, wofost_one_day_window_context_t, &
       wofost_one_day_diagnostics_t, prepare_wofost_one_day_candidate, &
       finalize_wofost_one_day_candidate, WOFOST_ONE_DAY_OK
  use mod_wofost_one_day_rate_state_view, only: wofost_one_day_rate_state_view_t, &
       assemble_wofost_one_day_rate_state_view, WOFOST_RATE_STATE_VIEW_OK
  use mod_wofost_rate_parameters, only: wofost_rate_parameter_bundle_t
  use mod_wofost_prepare_assimilation, only: wofost_prepare_assimilation_forcing_t, &
       wofost_prepare_assimilation_result_t, prepare_wofost_actual_assimilation, &
       WOFOST_PREPARE_ASSIMILATION_OK
  use mod_wofost_finalize_rates, only: wofost_finalize_rate_forcing_t, &
       finalize_wofost_one_day_rates, WOFOST_FINALIZE_RATES_OK
  use mod_wofost_phenology_rate_contract, only: wofost_phenology_rate_t
  implicit none
  private

  integer, parameter, public :: WOFOST_POTENTIAL_DAILY_OK = 0
  integer, parameter, public :: WOFOST_POTENTIAL_DAILY_INVALID_OWNER = 1
  integer, parameter, public :: WOFOST_POTENTIAL_DAILY_INVALID_POLICY = 2
  integer, parameter, public :: WOFOST_POTENTIAL_DAILY_PREPARE_ERROR = 3
  integer, parameter, public :: WOFOST_POTENTIAL_DAILY_VIEW_ERROR = 4
  integer, parameter, public :: WOFOST_POTENTIAL_DAILY_ASSIMILATION_ERROR = 5
  integer, parameter, public :: WOFOST_POTENTIAL_DAILY_RATE_ERROR = 6
  integer, parameter, public :: WOFOST_POTENTIAL_DAILY_FINALIZE_ERROR = 7
  integer, parameter, public :: WOFOST_POTENTIAL_DAILY_SHADOW_ERROR = 8

  type, public :: wofost_potential_daily_result_t
    real(real64) :: potential_pgass = 0.0_real64
    real(real64) :: gross_root_growth_rate = 0.0_real64 ! GRRTPOT
    real(real64) :: potential_root_biomass = 0.0_real64 ! WRTPOT after update
    type(wofost_potential_shadow_state_t) :: candidate_shadow
  end type

  public :: evaluate_wofost_potential_shadow_day

contains

  subroutine evaluate_wofost_potential_shadow_day(actual_owner, committed_shadow, forcing, t0, t1, &
       stem_area_coefficient, storage_area_coefficient, rate_parameters, update_parameters, &
       potential_attainable_multiplier, result, status, phenology_override)
    type(wofost_crop_owner_state_t), intent(in) :: actual_owner
    type(wofost_potential_shadow_state_t), intent(in) :: committed_shadow
    type(wofost_one_day_forcing_t), intent(in) :: forcing
    real(real64), intent(in) :: t0, t1
    real(real64), intent(in) :: stem_area_coefficient, storage_area_coefficient
    type(wofost_rate_parameter_bundle_t), intent(in) :: rate_parameters
    type(wofost_one_day_update_parameters_t), intent(in) :: update_parameters
    real(real64), intent(in) :: potential_attainable_multiplier
    type(wofost_potential_daily_result_t), intent(out) :: result
    integer, intent(out) :: status
    type(wofost_phenology_rate_t), intent(in), optional :: phenology_override

    type(wofost_crop_owner_state_t) :: materialized, prepared, evolved
    type(wofost_one_day_window_context_t) :: context
    type(wofost_one_day_rate_state_view_t) :: view
    type(wofost_prepare_assimilation_forcing_t) :: phase_a
    type(wofost_prepare_assimilation_result_t) :: assimilation
    type(wofost_finalize_rate_forcing_t) :: phase_b
    type(wofost_accepted_window_aggregates_t) :: potential_aggregates
    type(wofost_one_day_rate_packet_t) :: rates
    type(wofost_one_day_diagnostics_t) :: structural_diagnostics
    logical :: available
    integer :: component_status

    result = wofost_potential_daily_result_t()
    status = WOFOST_POTENTIAL_DAILY_INVALID_OWNER
    if (actual_owner%validate() /= WOFOST_CROP_OWNER_OK) return
    if (committed_shadow%validate() /= WOFOST_POTENTIAL_SHADOW_OK) return

    status = WOFOST_POTENTIAL_DAILY_INVALID_POLICY
    if (.not. ieee_is_finite(potential_attainable_multiplier)) return
    if (potential_attainable_multiplier < 0.0_real64 .or. potential_attainable_multiplier > 1.0_real64) return

    result%candidate_shadow = committed_shadow
    if (.not. committed_shadow%active) then
      status = WOFOST_POTENTIAL_DAILY_OK
      return
    end if

    call committed_shadow%materialize_owner(actual_owner, materialized, available, component_status)
    if (component_status /= WOFOST_POTENTIAL_SHADOW_OK .or. .not. available) return

    call prepare_wofost_one_day_candidate(materialized, forcing, t0, t1, prepared, context, component_status)
    if (component_status /= WOFOST_ONE_DAY_OK) then
      status = WOFOST_POTENTIAL_DAILY_PREPARE_ERROR
      return
    end if

    call assemble_wofost_one_day_rate_state_view(prepared, stem_area_coefficient, storage_area_coefficient, &
         view, available, component_status)
    if (component_status /= WOFOST_RATE_STATE_VIEW_OK .or. .not. available) then
      status = WOFOST_POTENTIAL_DAILY_VIEW_ERROR
      return
    end if

    phase_a = wofost_prepare_assimilation_forcing_t()
    phase_a%daytime_mean_temperature = forcing%daytime_average_temperature
    phase_a%global_radiation = forcing%global_radiation
    phase_a%daylength_hours = forcing%daylength_hours
    phase_a%sine_solar_height_offset = forcing%sinld
    phase_a%sine_solar_height_amplitude = forcing%cosld
    phase_a%diffuse_irradiation_perpendicular = forcing%diffuse_perpendicular_radiation
    phase_a%daily_effective_solar_height = forcing%daily_sine_solar_elevation_integral
    phase_a%co2_efficiency_factor = forcing%co2_efficiency_factor
    phase_a%co2_amax_factor = forcing%co2_amax_factor
    phase_a%running_minimum_temperature = context%running_minimum_temperature

    call prepare_wofost_actual_assimilation(view, rate_parameters, phase_a, assimilation, component_status, &
         attainable_multiplier_override=potential_attainable_multiplier)
    if (component_status /= WOFOST_PREPARE_ASSIMILATION_OK) then
      status = WOFOST_POTENTIAL_DAILY_ASSIMILATION_ERROR
      return
    end if

    ! The legacy potential crop branch is explicitly unstressed: RELTR=1.
    potential_aggregates%actual_root_uptake = 1.0_real64
    potential_aggregates%potential_transpiration = 1.0_real64

    phase_b%average_temperature = forcing%average_temperature
    phase_b%photoperiodic_daylength_hours = forcing%photoperiodic_daylength_hours
    if (present(phenology_override)) then
      call finalize_wofost_one_day_rates(view, rate_parameters, assimilation, potential_aggregates, phase_b, &
           rates, component_status, phenology_override)
    else
      call finalize_wofost_one_day_rates(view, rate_parameters, assimilation, potential_aggregates, phase_b, &
           rates, component_status)
    end if
    if (component_status /= WOFOST_FINALIZE_RATES_OK) then
      status = WOFOST_POTENTIAL_DAILY_RATE_ERROR
      return
    end if

    call finalize_wofost_one_day_candidate(prepared, context, update_parameters, potential_aggregates, rates, &
         evolved, structural_diagnostics, component_status)
    if (component_status /= WOFOST_ONE_DAY_OK .or. .not. structural_diagnostics%candidate_built) then
      status = WOFOST_POTENTIAL_DAILY_FINALIZE_ERROR
      return
    end if

    ! Discard evolved DVS/TSUM/anthesis. Pinned B1.11 advances those shared
    ! phenology variables once, in the actual branch only. Accept only the
    ! potential biomass/reference continuation into the optional shadow.
    result%candidate_shadow = committed_shadow
    call result%candidate_shadow%absorb_owner(evolved, component_status)
    if (component_status /= WOFOST_POTENTIAL_SHADOW_OK) then
      result%candidate_shadow = committed_shadow
      status = WOFOST_POTENTIAL_DAILY_SHADOW_ERROR
      return
    end if

    result%potential_pgass = assimilation%actual_pgass
    result%gross_root_growth_rate = rates%gross_root_growth_rate
    result%potential_root_biomass = result%candidate_shadow%root_biomass()
    status = WOFOST_POTENTIAL_DAILY_OK
  end subroutine evaluate_wofost_potential_shadow_day

end module mod_wofost_potential_shadow_daily
