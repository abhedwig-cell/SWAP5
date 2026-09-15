module mod_wofost81_prepare_assimilation
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_wofost_one_day_rate_state_view, only: wofost_one_day_rate_state_view_t, WOFOST_RATE_STATE_VIEW_OK
  use mod_wofost_one_day_structural_evolution, only: wofost_one_day_forcing_t
  use mod_wofost_rate_parameters, only: wofost_rate_parameter_bundle_t, wofost_rate_scalar_parameters_t, &
       WOFOST_RATE_PARAMETER_OK
  use mod_wofost81_daily_parameter_contract, only: wofost81_daily_parameter_contract_t, &
       WOFOST81_DAILY_PARAMETER_OK
  use mod_wofost81_n_owner_state, only: wofost81_n_owner_state_t, WOFOST81_N_OWNER_OK
  use MOD_wofost81_assimilation, only: totass81
  implicit none
  private

  integer, parameter, public :: WOFOST81_PREPARE_ASSIMILATION_OK = 0
  integer, parameter, public :: WOFOST81_PREPARE_ASSIMILATION_INVALID_STATE = 1
  integer, parameter, public :: WOFOST81_PREPARE_ASSIMILATION_INVALID_COMMON_PARAMETERS = 2
  integer, parameter, public :: WOFOST81_PREPARE_ASSIMILATION_INVALID_81_PARAMETERS = 3
  integer, parameter, public :: WOFOST81_PREPARE_ASSIMILATION_INVALID_N_STATE = 4
  integer, parameter, public :: WOFOST81_PREPARE_ASSIMILATION_INVALID_FORCING = 5
  integer, parameter, public :: WOFOST81_PREPARE_ASSIMILATION_PARAMETER_EVALUATION = 6
  integer, parameter, public :: WOFOST81_PREPARE_ASSIMILATION_INVALID_RESULT = 7

  type, public :: wofost81_prepare_assimilation_result_t
    real(real64) :: actual_pgass = 0.0_real64
    real(real64) :: light_use_efficiency = 0.0_real64
    real(real64) :: diffuse_extinction_coefficient = 0.0_real64
  end type wofost81_prepare_assimilation_result_t

  public :: prepare_wofost81_actual_assimilation

contains

  subroutine prepare_wofost81_actual_assimilation(state_view, common_parameters, parameters81, nitrogen, &
                                                   forcing, running_minimum_temperature, result, status)
    type(wofost_one_day_rate_state_view_t), intent(in) :: state_view
    type(wofost_rate_parameter_bundle_t), intent(in) :: common_parameters
    type(wofost81_daily_parameter_contract_t), intent(in) :: parameters81
    type(wofost81_n_owner_state_t), intent(in) :: nitrogen
    type(wofost_one_day_forcing_t), intent(in) :: forcing
    real(real64), intent(in) :: running_minimum_temperature
    type(wofost81_prepare_assimilation_result_t), intent(out) :: result
    integer, intent(out) :: status

    type(wofost_rate_scalar_parameters_t) :: common_scalars
    real(real64) :: eff, kdif, tmpf, tmnf, dtga, effc, pgass
    integer :: pstatus

    result = wofost81_prepare_assimilation_result_t()
    status = WOFOST81_PREPARE_ASSIMILATION_INVALID_STATE
    if (state_view%validate() /= WOFOST_RATE_STATE_VIEW_OK) return
    status = WOFOST81_PREPARE_ASSIMILATION_INVALID_COMMON_PARAMETERS
    if (.not. common_parameters%ready()) return
    status = WOFOST81_PREPARE_ASSIMILATION_INVALID_81_PARAMETERS
    if (parameters81%validate() /= WOFOST81_DAILY_PARAMETER_OK) return
    status = WOFOST81_PREPARE_ASSIMILATION_INVALID_N_STATE
    if (nitrogen%validate() /= WOFOST81_N_OWNER_OK) return
    status = WOFOST81_PREPARE_ASSIMILATION_INVALID_FORCING
    if (.not. valid_forcing(forcing, running_minimum_temperature)) return

    call parameters81%evaluate_light_use_efficiency(forcing%daytime_average_temperature, eff, pstatus)
    if (pstatus /= WOFOST81_DAILY_PARAMETER_OK) then
      status = WOFOST81_PREPARE_ASSIMILATION_PARAMETER_EVALUATION
      return
    end if
    call parameters81%evaluate_diffuse_extinction_coefficient(state_view%development_stage, kdif, pstatus)
    if (pstatus /= WOFOST81_DAILY_PARAMETER_OK) then
      status = WOFOST81_PREPARE_ASSIMILATION_PARAMETER_EVALUATION
      return
    end if
    call common_parameters%evaluate_daytime_temperature_factor(forcing%average_temperature, tmpf, pstatus)
    if (pstatus /= WOFOST_RATE_PARAMETER_OK) then
      status = WOFOST81_PREPARE_ASSIMILATION_PARAMETER_EVALUATION
      return
    end if
    call common_parameters%evaluate_minimum_temperature_factor(running_minimum_temperature, tmnf, pstatus)
    if (pstatus /= WOFOST_RATE_PARAMETER_OK) then
      status = WOFOST81_PREPARE_ASSIMILATION_PARAMETER_EVALUATION
      return
    end if
    if (.not. valid_nonnegative(tmpf) .or. .not. valid_nonnegative(tmnf)) then
      status = WOFOST81_PREPARE_ASSIMILATION_PARAMETER_EVALUATION
      return
    end if

    common_scalars = common_parameters%scalar_view()
    if (common_scalars%co2_to_dry_matter_fraction <= 0.0_real64 .or. &
        common_scalars%attainable_yield_multiplier < 0.0_real64) then
      status = WOFOST81_PREPARE_ASSIMILATION_INVALID_COMMON_PARAMETERS
      return
    end if

    if (state_view%actual_leaf_area_index <= 0.0_real64 .or. forcing%global_radiation <= 0.0_real64 .or. &
        forcing%daylength_hours <= 0.0_real64) then
      result%actual_pgass = 0.0_real64
      result%light_use_efficiency = eff
      result%diffuse_extinction_coefficient = kdif
      status = WOFOST81_PREPARE_ASSIMILATION_OK
      return
    end if

    effc = forcing%co2_efficiency_factor * eff
    call totass81(parameters81%base%assimilation%amax_lnb, parameters81%base%assimilation%amax_ref, &
                  parameters81%base%assimilation%amax_slp, forcing%daylength_hours, forcing%co2_amax_factor, &
                  tmpf, effc, parameters81%base%assimilation%kn, state_view%actual_leaf_area_index, &
                  nitrogen%value%namountlv, kdif, forcing%global_radiation, &
                  forcing%diffuse_perpendicular_radiation, forcing%daily_sine_solar_elevation_integral, &
                  forcing%sinld, forcing%cosld, dtga)

    pgass = dtga * tmnf * 30.0_real64 * (0.4_real64/common_scalars%co2_to_dry_matter_fraction) / 44.0_real64
    pgass = pgass * common_scalars%attainable_yield_multiplier
    status = WOFOST81_PREPARE_ASSIMILATION_INVALID_RESULT
    if (.not. valid_nonnegative(pgass)) return
    result%actual_pgass = pgass
    result%light_use_efficiency = eff
    result%diffuse_extinction_coefficient = kdif
    status = WOFOST81_PREPARE_ASSIMILATION_OK
  end subroutine prepare_wofost81_actual_assimilation

  pure logical function valid_forcing(forcing, running_minimum_temperature) result(valid)
    type(wofost_one_day_forcing_t), intent(in) :: forcing
    real(real64), intent(in) :: running_minimum_temperature
    real(real64) :: values(13)
    values = [forcing%minimum_temperature, forcing%average_temperature, forcing%daytime_average_temperature, &
              forcing%global_radiation, forcing%daylength_hours, forcing%photoperiodic_daylength_hours, &
              forcing%sinld, forcing%cosld, forcing%diffuse_perpendicular_radiation, &
              forcing%daily_sine_solar_elevation_integral, forcing%co2_efficiency_factor, &
              forcing%co2_amax_factor, running_minimum_temperature]
    valid = all(ieee_is_finite(values))
    if (.not. valid) return
    valid = forcing%global_radiation >= 0.0_real64 .and. &
            forcing%daylength_hours >= 0.0_real64 .and. forcing%daylength_hours <= 24.0_real64 .and. &
            forcing%diffuse_perpendicular_radiation >= 0.0_real64 .and. &
            forcing%daily_sine_solar_elevation_integral >= 0.0_real64 .and. &
            forcing%co2_efficiency_factor >= 0.0_real64 .and. forcing%co2_amax_factor >= 0.0_real64
    if (.not. valid) return
    if (forcing%global_radiation > 0.0_real64 .and. forcing%daylength_hours > 0.0_real64) then
      valid = forcing%daily_sine_solar_elevation_integral > 0.0_real64
    end if
  end function valid_forcing

  pure logical function valid_nonnegative(value) result(valid)
    real(real64), intent(in) :: value
    valid = ieee_is_finite(value) .and. value >= 0.0_real64
  end function valid_nonnegative

end module mod_wofost81_prepare_assimilation
