module mod_rutter_interception_process
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: RUTTER_OK = 0
  integer, parameter, public :: RUTTER_INVALID_INPUT = 1
  integer, parameter, public :: RUTTER_INVALID_STATE = 2
  integer, parameter, public :: RUTTER_INVALID_RESULT = 3
  real(real64), parameter :: NIHIL = 1.0e-10_real64
  real(real64), parameter :: SMALL = 1.0e-6_real64

  type, public :: rutter_state_t
    real(real64) :: canopy_storage_cm = 0.0_real64
  end type

  type, public :: rutter_interval_input_t
    real(real64) :: gross_rain_cm_per_day = 0.0_real64
    real(real64) :: surface_irrigation_cm_per_day = 0.0_real64
    logical :: surface_irrigation_is_intercepted = .true.
    real(real64) :: vegetation_cover_fraction = 0.0_real64
    real(real64) :: canopy_storage_capacity_cm = 0.0_real64
    real(real64) :: interception_evaporation_capacity_cm_per_day = 0.0_real64
    real(real64) :: potential_transpiration_dry_cm_per_day = 0.0_real64
    real(real64) :: potential_transpiration_wet_cm_per_day = 0.0_real64
    real(real64) :: interval_days = 0.0_real64
  end type

  type, public :: rutter_interval_result_t
    real(real64) :: reservoir_inflow_cm_per_day = 0.0_real64
    real(real64) :: reservoir_outflow_cm_per_day = 0.0_real64
    real(real64) :: interception_rate_cm_per_day = 0.0_real64
    real(real64) :: net_rain_cm_per_day = 0.0_real64
    real(real64) :: net_surface_irrigation_cm_per_day = 0.0_real64
    real(real64) :: wet_canopy_fraction = 0.0_real64
    real(real64) :: potential_transpiration_cm_per_day = 0.0_real64
    real(real64) :: maximum_event_timestep_days = 1.0_real64
    type(rutter_state_t) :: candidate_state
  end type

  type, public :: rutter_diagnostics_t
    integer :: status = RUTTER_OK
    logical :: result_produced = .false.
  end type

  public :: evaluate_rutter_interval

contains

  pure subroutine evaluate_rutter_interval(accepted_state, input, result, diagnostics)
    type(rutter_state_t), intent(in) :: accepted_state
    type(rutter_interval_input_t), intent(in) :: input
    type(rutter_interval_result_t), intent(out) :: result
    type(rutter_diagnostics_t), intent(out) :: diagnostics
    real(real64) :: rpd, flux_in, flux_out, interception, denom

    result = rutter_interval_result_t()
    diagnostics = rutter_diagnostics_t()

    if (.not. valid_input(input)) then
      diagnostics%status = RUTTER_INVALID_INPUT
      return
    end if
    if (.not. ieee_is_finite(accepted_state%canopy_storage_cm) .or. &
        accepted_state%canopy_storage_cm < 0.0_real64 .or. &
        accepted_state%canopy_storage_cm > input%canopy_storage_capacity_cm + NIHIL) then
      diagnostics%status = RUTTER_INVALID_STATE
      return
    end if

    rpd = input%gross_rain_cm_per_day
    if (input%surface_irrigation_is_intercepted) rpd = rpd + input%surface_irrigation_cm_per_day
    flux_in = rpd * input%vegetation_cover_fraction
    flux_out = input%interception_evaporation_capacity_cm_per_day
    result%maximum_event_timestep_days = 1.0_real64

    if (flux_in + flux_out < NIHIL) then
      result%reservoir_inflow_cm_per_day = 0.0_real64
      result%reservoir_outflow_cm_per_day = 0.0_real64
      result%wet_canopy_fraction = 0.0_real64
    else if (flux_in >= flux_out) then
      if (input%canopy_storage_capacity_cm - accepted_state%canopy_storage_cm > NIHIL) then
        result%reservoir_inflow_cm_per_day = flux_in
        result%reservoir_outflow_cm_per_day = flux_out
        denom = result%reservoir_inflow_cm_per_day - result%reservoir_outflow_cm_per_day
        if (denom > 0.0_real64) then
          result%maximum_event_timestep_days = &
            (input%canopy_storage_capacity_cm - accepted_state%canopy_storage_cm) / denom
        end if
      else
        result%reservoir_inflow_cm_per_day = flux_out
        result%reservoir_outflow_cm_per_day = flux_out
      end if
      result%wet_canopy_fraction = 1.0_real64
    else
      if (accepted_state%canopy_storage_cm > NIHIL) then
        result%reservoir_inflow_cm_per_day = flux_in
        result%reservoir_outflow_cm_per_day = flux_out
        denom = result%reservoir_outflow_cm_per_day - result%reservoir_inflow_cm_per_day
        if (denom > 0.0_real64) result%maximum_event_timestep_days = accepted_state%canopy_storage_cm / denom
        result%wet_canopy_fraction = 1.0_real64
      else
        result%reservoir_inflow_cm_per_day = flux_in
        result%reservoir_outflow_cm_per_day = flux_in
        if (flux_out > 0.0_real64) result%wet_canopy_fraction = flux_in / flux_out
      end if
    end if

    interception = result%reservoir_inflow_cm_per_day
    result%interception_rate_cm_per_day = interception

    if (interception < SMALL) then
      result%net_rain_cm_per_day = input%gross_rain_cm_per_day
      result%net_surface_irrigation_cm_per_day = input%surface_irrigation_cm_per_day
    else if (input%gross_rain_cm_per_day + input%surface_irrigation_cm_per_day > SMALL) then
      if (input%surface_irrigation_is_intercepted) then
        denom = input%gross_rain_cm_per_day + input%surface_irrigation_cm_per_day
        result%net_rain_cm_per_day = input%gross_rain_cm_per_day - interception * input%gross_rain_cm_per_day / denom
        result%net_surface_irrigation_cm_per_day = input%surface_irrigation_cm_per_day - &
          interception * input%surface_irrigation_cm_per_day / denom
      else
        result%net_rain_cm_per_day = input%gross_rain_cm_per_day - interception
        result%net_surface_irrigation_cm_per_day = input%surface_irrigation_cm_per_day
      end if
    end if

    result%potential_transpiration_cm_per_day = &
      result%wet_canopy_fraction * input%potential_transpiration_wet_cm_per_day + &
      (1.0_real64 - result%wet_canopy_fraction) * input%potential_transpiration_dry_cm_per_day

    result%candidate_state%canopy_storage_cm = min(max(0.0_real64, accepted_state%canopy_storage_cm + &
      (result%reservoir_inflow_cm_per_day - result%reservoir_outflow_cm_per_day) * input%interval_days), &
      input%canopy_storage_capacity_cm)

    if (.not. valid_result(result)) then
      result = rutter_interval_result_t()
      diagnostics%status = RUTTER_INVALID_RESULT
      return
    end if
    diagnostics%result_produced = .true.
  end subroutine

  pure logical function valid_input(input)
    type(rutter_interval_input_t), intent(in) :: input
    valid_input = ieee_is_finite(input%gross_rain_cm_per_day) .and. &
      ieee_is_finite(input%surface_irrigation_cm_per_day) .and. &
      ieee_is_finite(input%vegetation_cover_fraction) .and. &
      ieee_is_finite(input%canopy_storage_capacity_cm) .and. &
      ieee_is_finite(input%interception_evaporation_capacity_cm_per_day) .and. &
      ieee_is_finite(input%potential_transpiration_dry_cm_per_day) .and. &
      ieee_is_finite(input%potential_transpiration_wet_cm_per_day) .and. &
      ieee_is_finite(input%interval_days)
    if (.not. valid_input) return
    valid_input = input%gross_rain_cm_per_day >= 0.0_real64 .and. &
      input%surface_irrigation_cm_per_day >= 0.0_real64 .and. &
      input%vegetation_cover_fraction >= 0.0_real64 .and. input%vegetation_cover_fraction <= 1.0_real64 .and. &
      input%canopy_storage_capacity_cm >= 0.0_real64 .and. &
      input%interception_evaporation_capacity_cm_per_day >= 0.0_real64 .and. &
      input%potential_transpiration_dry_cm_per_day >= 0.0_real64 .and. &
      input%potential_transpiration_wet_cm_per_day >= 0.0_real64 .and. input%interval_days > 0.0_real64
  end function

  pure logical function valid_result(result)
    type(rutter_interval_result_t), intent(in) :: result
    valid_result = ieee_is_finite(result%reservoir_inflow_cm_per_day) .and. &
      ieee_is_finite(result%reservoir_outflow_cm_per_day) .and. ieee_is_finite(result%interception_rate_cm_per_day) .and. &
      ieee_is_finite(result%net_rain_cm_per_day) .and. ieee_is_finite(result%net_surface_irrigation_cm_per_day) .and. &
      ieee_is_finite(result%wet_canopy_fraction) .and. ieee_is_finite(result%potential_transpiration_cm_per_day) .and. &
      ieee_is_finite(result%maximum_event_timestep_days) .and. ieee_is_finite(result%candidate_state%canopy_storage_cm)
    if (.not. valid_result) return
    valid_result = result%reservoir_inflow_cm_per_day >= 0.0_real64 .and. &
      result%reservoir_outflow_cm_per_day >= 0.0_real64 .and. result%interception_rate_cm_per_day >= 0.0_real64 .and. &
      result%net_rain_cm_per_day >= -NIHIL .and. result%net_surface_irrigation_cm_per_day >= -NIHIL .and. &
      result%wet_canopy_fraction >= 0.0_real64 .and. result%wet_canopy_fraction <= 1.0_real64 + NIHIL .and. &
      result%potential_transpiration_cm_per_day >= 0.0_real64 .and. result%maximum_event_timestep_days >= 0.0_real64 .and. &
      result%candidate_state%canopy_storage_cm >= 0.0_real64
  end function
end module mod_rutter_interception_process
