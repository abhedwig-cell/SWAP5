module mod_wofost81_one_day_candidate
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_wofost81_crop_owner_state, only: wofost81_crop_owner_state_t, WOFOST81_CROP_OWNER_OK
  use mod_wofost_one_day_structural_evolution, only: wofost_one_day_forcing_t, &
       wofost_accepted_window_aggregates_t, wofost_one_day_update_parameters_t, &
       wofost_one_day_rate_packet_t, wofost_one_day_window_context_t, &
       prepare_wofost_one_day_candidate, WOFOST_ONE_DAY_OK
  use mod_wofost_one_day_rate_state_view, only: wofost_one_day_rate_state_view_t, &
       assemble_wofost_one_day_rate_state_view, WOFOST_RATE_STATE_VIEW_OK
  use mod_wofost_rate_parameters, only: wofost_rate_parameter_bundle_t, &
       wofost_rate_scalar_parameters_t, WOFOST_RATE_PARAMETER_OK
  use mod_wofost_prepare_assimilation, only: wofost_prepare_assimilation_result_t
  use mod_wofost_finalize_rates, only: wofost_finalize_rate_forcing_t, &
       finalize_wofost_one_day_rates, WOFOST_FINALIZE_RATES_OK
  use mod_wofost81_daily_parameter_contract, only: wofost81_daily_parameter_contract_t, &
       WOFOST81_DAILY_PARAMETER_OK
  use mod_wofost81_prepare_assimilation, only: wofost81_prepare_assimilation_result_t, &
       prepare_wofost81_actual_assimilation, WOFOST81_PREPARE_ASSIMILATION_OK
  use mod_wofost81_rate_correction, only: wofost81_rate_correction_diagnostics_t, &
       correct_wofost81_leaf_rates, WOFOST81_RATE_CORRECTION_OK
  use mod_wofost81_leaf_structural_evolution, only: wofost81_leaf_structure_diagnostics_t, &
       apply_wofost81_leaf_structural_update, WOFOST81_LEAF_STRUCTURE_OK
  use mod_wofost81_n_owner_state, only: wofost81_n_owner_state_t, WOFOST81_N_OWNER_OK
  use MOD_wofost81_nitrogen, only: WOFOST81_n_request, WOFOST81_n_flux, WOFOST81_n_state, &
       prepare_wofost81_n_request, apply_wofost81_n_supply, WOFN81_OK
  implicit none
  private

  integer, parameter, public :: WOFOST81_DAY_OK = 0
  integer, parameter, public :: WOFOST81_DAY_INVALID_OWNER = 1
  integer, parameter, public :: WOFOST81_DAY_PREPARE_FAILURE = 2
  integer, parameter, public :: WOFOST81_DAY_STATE_VIEW_FAILURE = 3
  integer, parameter, public :: WOFOST81_DAY_ASSIMILATION_FAILURE = 4
  integer, parameter, public :: WOFOST81_DAY_RATE_FAILURE = 5
  integer, parameter, public :: WOFOST81_DAY_CORRECTION_FAILURE = 6
  integer, parameter, public :: WOFOST81_DAY_PARAMETER_FAILURE = 7
  integer, parameter, public :: WOFOST81_DAY_N_REQUEST_FAILURE = 8
  integer, parameter, public :: WOFOST81_DAY_STRUCTURE_FAILURE = 9
  integer, parameter, public :: WOFOST81_DAY_INVALID_CANDIDATE = 10
  integer, parameter, public :: WOFOST81_DAY_INVALID_SUPPLY = 11
  integer, parameter, public :: WOFOST81_DAY_N_APPLY_FAILURE = 12

  type, public :: wofost81_one_day_prepared_candidate_t
    logical :: ready = .false.
    logical :: active = .false.
    type(wofost81_crop_owner_state_t) :: candidate
    type(wofost81_n_owner_state_t) :: nitrogen_before
    type(WOFOST81_n_request) :: nitrogen_request
    type(wofost_one_day_rate_packet_t) :: corrected_rates
    type(wofost81_rate_correction_diagnostics_t) :: rate_diagnostics
    type(wofost81_leaf_structure_diagnostics_t) :: leaf_diagnostics
    real(real64) :: wlv_before = 0.0_real64
    real(real64) :: wst_before = 0.0_real64
    real(real64) :: wrt_before = 0.0_real64
    real(real64) :: wso_before = 0.0_real64
    real(real64) :: drlv = 0.0_real64
    real(real64) :: drst = 0.0_real64
    real(real64) :: drrt = 0.0_real64
    real(real64) :: grlv = 0.0_real64
    real(real64) :: grst = 0.0_real64
    real(real64) :: grrt = 0.0_real64
    real(real64) :: grso = 0.0_real64
  end type wofost81_one_day_prepared_candidate_t

  public :: prepare_wofost81_one_day_candidate
  public :: apply_wofost81_one_day_n_supply

contains

  subroutine prepare_wofost81_one_day_candidate(committed, forcing, t0, t1, common_parameters, &
       parameters81, update_parameters, aggregates, stem_area_coefficient, storage_area_coefficient, &
       nitrogen_stress_active, prepared, status)
    type(wofost81_crop_owner_state_t), intent(in) :: committed
    type(wofost_one_day_forcing_t), intent(in) :: forcing
    real(real64), intent(in) :: t0, t1
    type(wofost_rate_parameter_bundle_t), intent(in) :: common_parameters
    type(wofost81_daily_parameter_contract_t), intent(in) :: parameters81
    type(wofost_one_day_update_parameters_t), intent(in) :: update_parameters
    type(wofost_accepted_window_aggregates_t), intent(in) :: aggregates
    real(real64), intent(in) :: stem_area_coefficient, storage_area_coefficient
    logical, intent(in) :: nitrogen_stress_active
    type(wofost81_one_day_prepared_candidate_t), intent(out) :: prepared
    integer, intent(out) :: status

    type(wofost_one_day_window_context_t) :: crop_context
    type(wofost_one_day_rate_state_view_t) :: state_view
    type(wofost81_prepare_assimilation_result_t) :: assimilation81
    type(wofost_prepare_assimilation_result_t) :: common_assimilation
    type(wofost_finalize_rate_forcing_t) :: rate_forcing
    type(wofost_one_day_rate_packet_t) :: base_rates
    type(wofost_rate_scalar_parameters_t) :: common_scalars
    real(real64) :: rdr_root, rdr_stem, nmaxlv, dvr_applied
    logical :: available
    integer :: local_status

    prepared = wofost81_one_day_prepared_candidate_t()
    status = WOFOST81_DAY_INVALID_OWNER
    if (committed%validate() /= WOFOST81_CROP_OWNER_OK) return
    prepared%candidate = committed
    prepared%nitrogen_before = committed%nitrogen

    call prepare_wofost_one_day_candidate(committed%crop, forcing, t0, t1, &
         prepared%candidate%crop, crop_context, local_status)
    if (local_status /= WOFOST_ONE_DAY_OK) then
      status = WOFOST81_DAY_PREPARE_FAILURE
      return
    end if
    if (.not. committed%crop%crop_emerged) then
      prepared%ready = .true.
      status = WOFOST81_DAY_OK
      return
    end if
    prepared%active = .true.

    call assemble_wofost_one_day_rate_state_view(prepared%candidate%crop, &
         stem_area_coefficient, storage_area_coefficient, state_view, available, local_status)
    if (local_status /= WOFOST_RATE_STATE_VIEW_OK .or. .not. available) then
      status = WOFOST81_DAY_STATE_VIEW_FAILURE
      return
    end if

    call prepare_wofost81_actual_assimilation(state_view, common_parameters, parameters81, &
         committed%nitrogen, forcing, crop_context%running_minimum_temperature, assimilation81, local_status)
    if (local_status /= WOFOST81_PREPARE_ASSIMILATION_OK) then
      status = WOFOST81_DAY_ASSIMILATION_FAILURE
      return
    end if
    common_assimilation%actual_pgass = assimilation81%actual_pgass
    rate_forcing%average_temperature = forcing%average_temperature
    rate_forcing%photoperiodic_daylength_hours = forcing%photoperiodic_daylength_hours
    call finalize_wofost_one_day_rates(state_view, common_parameters, common_assimilation, aggregates, &
         rate_forcing, base_rates, local_status)
    if (local_status /= WOFOST_FINALIZE_RATES_OK) then
      status = WOFOST81_DAY_RATE_FAILURE
      return
    end if

    common_scalars = common_parameters%scalar_view()
    call correct_wofost81_leaf_rates(state_view, prepared%candidate%crop%biomass%leaf_biomass, &
         prepared%candidate%crop%biomass%leaf_age, update_parameters%leaf_lifespan, t1 - t0, &
         common_scalars%maximum_relative_lai_growth_rate, nitrogen_stress_active, parameters81, &
         committed%nitrogen, base_rates, prepared%corrected_rates, prepared%rate_diagnostics, local_status)
    if (local_status /= WOFOST81_RATE_CORRECTION_OK) then
      status = WOFOST81_DAY_CORRECTION_FAILURE
      return
    end if

    call common_parameters%evaluate_relative_root_death_rate(state_view%development_stage, rdr_root, local_status)
    if (local_status /= WOFOST_RATE_PARAMETER_OK) then
      status = WOFOST81_DAY_PARAMETER_FAILURE
      return
    end if
    call common_parameters%evaluate_relative_stem_death_rate(state_view%development_stage, rdr_stem, local_status)
    if (local_status /= WOFOST_RATE_PARAMETER_OK) then
      status = WOFOST81_DAY_PARAMETER_FAILURE
      return
    end if
    call parameters81%evaluate_maximum_leaf_n_concentration(state_view%development_stage, nmaxlv, local_status)
    if (local_status /= WOFOST81_DAILY_PARAMETER_OK) then
      status = WOFOST81_DAY_PARAMETER_FAILURE
      return
    end if

    prepared%wlv_before = state_view%living_leaf_biomass
    prepared%wst_before = state_view%actual_stem_biomass
    prepared%wrt_before = state_view%actual_root_biomass
    prepared%wso_before = state_view%actual_storage_biomass
    prepared%drlv = prepared%corrected_rates%leaf_stress_death_rate
    prepared%drst = prepared%wst_before * rdr_stem
    prepared%drrt = prepared%wrt_before * rdr_root
    prepared%grlv = prepared%corrected_rates%leaf_growth_rate
    prepared%grst = prepared%corrected_rates%stem_net_growth_rate + prepared%drst
    prepared%grrt = prepared%corrected_rates%root_net_growth_rate + prepared%drrt
    prepared%grso = prepared%corrected_rates%storage_net_growth_rate
    if (.not. valid_nonnegative_rates(prepared)) then
      status = WOFOST81_DAY_PARAMETER_FAILURE
      return
    end if

    call prepare_wofost81_n_request(parameters81%base%nitrogen%donor_view(), committed%nitrogen%value, &
         state_view%development_stage, nmaxlv, prepared%wlv_before, prepared%wst_before, &
         prepared%wrt_before, prepared%wso_before, prepared%grlv, prepared%grst, prepared%grrt, &
         prepared%grso, prepared%corrected_rates%relative_transpiration_used, prepared%nitrogen_request)
    if (prepared%nitrogen_request%status /= WOFN81_OK) then
      status = WOFOST81_DAY_N_REQUEST_FAILURE
      return
    end if

    call apply_wofost81_leaf_structural_update(prepared%candidate%crop, prepared%corrected_rates, &
         prepared%leaf_diagnostics, local_status)
    if (local_status /= WOFOST81_LEAF_STRUCTURE_OK) then
      status = WOFOST81_DAY_STRUCTURE_FAILURE
      return
    end if
    prepared%candidate%crop%biomass%root_biomass = prepared%candidate%crop%biomass%root_biomass + &
         prepared%corrected_rates%root_net_growth_rate
    prepared%candidate%crop%biomass%stem_biomass = prepared%candidate%crop%biomass%stem_biomass + &
         prepared%corrected_rates%stem_net_growth_rate
    prepared%candidate%crop%biomass%storage_biomass = prepared%candidate%crop%biomass%storage_biomass + &
         prepared%corrected_rates%storage_net_growth_rate

    dvr_applied = prepared%corrected_rates%development_rate
    if (prepared%candidate%crop%development_stage + dvr_applied >= 1.0_real64 .and. &
         .not. prepared%candidate%crop%evolution_continuation%anthesis_reached) then
      prepared%candidate%crop%evolution_continuation%anthesis_reached = .true.
      dvr_applied = 1.0_real64 - prepared%candidate%crop%development_stage
    end if
    prepared%candidate%crop%evolution_continuation%temperature_sum = &
         prepared%candidate%crop%evolution_continuation%temperature_sum + &
         prepared%corrected_rates%temperature_sum_increment
    prepared%candidate%crop%development_stage = min(prepared%candidate%crop%development_stage + dvr_applied, &
         update_parameters%development_stage_end)

    status = WOFOST81_DAY_INVALID_CANDIDATE
    if (prepared%candidate%validate() /= WOFOST81_CROP_OWNER_OK) return
    prepared%ready = .true.
    status = WOFOST81_DAY_OK
  end subroutine prepare_wofost81_one_day_candidate

  subroutine apply_wofost81_one_day_n_supply(prepared, parameters81, soil_supply, candidate, flux, status)
    type(wofost81_one_day_prepared_candidate_t), intent(in) :: prepared
    type(wofost81_daily_parameter_contract_t), intent(in) :: parameters81
    real(real64), intent(in) :: soil_supply
    type(wofost81_crop_owner_state_t), intent(out) :: candidate
    type(WOFOST81_n_flux), intent(out) :: flux
    integer, intent(out) :: status
    type(WOFOST81_n_state) :: nitrogen_candidate

    candidate = prepared%candidate
    flux = WOFOST81_n_flux()
    status = WOFOST81_DAY_INVALID_CANDIDATE
    if (.not. prepared%ready) return
    if (.not. prepared%active) then
      status = WOFOST81_DAY_OK
      return
    end if
    status = WOFOST81_DAY_INVALID_SUPPLY
    if (.not. ieee_is_finite(soil_supply) .or. soil_supply < 0.0_real64) return

    call apply_wofost81_n_supply(parameters81%base%nitrogen%donor_view(), prepared%nitrogen_before%value, &
         prepared%nitrogen_request, prepared%wlv_before, prepared%wst_before, prepared%wrt_before, &
         prepared%drlv, prepared%drst, prepared%drrt, soil_supply, nitrogen_candidate, flux)
    if (flux%status /= WOFN81_OK) then
      candidate%nitrogen = prepared%nitrogen_before
      status = WOFOST81_DAY_N_APPLY_FAILURE
      return
    end if
    candidate%nitrogen%value = nitrogen_candidate
    if (candidate%nitrogen%validate() /= WOFOST81_N_OWNER_OK) then
      candidate%nitrogen = prepared%nitrogen_before
      status = WOFOST81_DAY_N_APPLY_FAILURE
      return
    end if
    status = WOFOST81_DAY_INVALID_CANDIDATE
    if (candidate%validate() /= WOFOST81_CROP_OWNER_OK) return
    status = WOFOST81_DAY_OK
  end subroutine apply_wofost81_one_day_n_supply

  pure logical function valid_nonnegative_rates(prepared) result(valid)
    type(wofost81_one_day_prepared_candidate_t), intent(in) :: prepared
    real(real64) :: values(12)
    values = [prepared%wlv_before, prepared%wst_before, prepared%wrt_before, prepared%wso_before, &
         prepared%drlv, prepared%drst, prepared%drrt, prepared%grlv, prepared%grst, prepared%grrt, &
         prepared%grso, prepared%corrected_rates%relative_transpiration_used]
    valid = all(ieee_is_finite(values)) .and. all(values >= 0.0_real64)
  end function valid_nonnegative_rates

end module mod_wofost81_one_day_candidate
