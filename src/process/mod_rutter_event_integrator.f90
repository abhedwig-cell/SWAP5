module mod_rutter_event_integrator
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_rutter_interception_process, only: rutter_state_t, rutter_interval_input_t, &
       rutter_interval_result_t, rutter_diagnostics_t, RUTTER_OK, RUTTER_INVALID_INPUT, &
       RUTTER_INVALID_STATE, RUTTER_INVALID_RESULT, evaluate_rutter_interval
  implicit none
  private
  real(real64), parameter :: EVENT_TOL_FACTOR = 64.0_real64
  integer, parameter :: MAX_EVENT_SUBSTEPS = 100000

  public :: evaluate_rutter_forcing_interval

contains

  ! Integrate one constant-forcing interval independently of the hydraulic
  ! solver's step size. The admitted legacy interval API remains unchanged.
  pure subroutine evaluate_rutter_forcing_interval(accepted_state, input, result, diagnostics, event_substeps)
    type(rutter_state_t), intent(in) :: accepted_state
    type(rutter_interval_input_t), intent(in) :: input
    type(rutter_interval_result_t), intent(out) :: result
    type(rutter_diagnostics_t), intent(out) :: diagnostics
    integer, intent(out), optional :: event_substeps
    type(rutter_state_t) :: state
    type(rutter_interval_input_t) :: subinput
    type(rutter_interval_result_t) :: subresult
    type(rutter_diagnostics_t) :: subdiagnostics
    real(real64) :: remaining, step_days, elapsed, event_tolerance, capacity_release
    real(real64) :: inflow_integral, outflow_integral, interception_integral
    real(real64) :: rain_integral, irrigation_integral, wet_integral, ptra_integral
    integer :: iterations

    result = rutter_interval_result_t()
    diagnostics = rutter_diagnostics_t()
    if (present(event_substeps)) event_substeps = 0
    if (.not. valid_input(input)) then
      diagnostics%status = RUTTER_INVALID_INPUT
      return
    end if
    if (.not. ieee_is_finite(accepted_state%canopy_storage_cm) .or. &
        accepted_state%canopy_storage_cm < 0.0_real64) then
      diagnostics%status = RUTTER_INVALID_STATE
      return
    end if

    state = accepted_state
    capacity_release = max(0.0_real64, state%canopy_storage_cm - input%canopy_storage_capacity_cm)
    state%canopy_storage_cm = min(state%canopy_storage_cm, input%canopy_storage_capacity_cm)
    remaining = input%interval_days
    elapsed = 0.0_real64
    inflow_integral = 0.0_real64
    outflow_integral = 0.0_real64
    interception_integral = 0.0_real64
    ! Capacity loss is an instantaneous canopy-to-surface transfer.
    rain_integral = capacity_release
    irrigation_integral = 0.0_real64
    wet_integral = 0.0_real64
    ptra_integral = 0.0_real64
    iterations = 0

    do while (remaining > 0.0_real64)
      iterations = iterations + 1
      if (iterations > MAX_EVENT_SUBSTEPS) then
        diagnostics%status = RUTTER_INVALID_RESULT
        return
      end if
      subinput = input
      subinput%interval_days = remaining
      call evaluate_rutter_interval(state, subinput, subresult, subdiagnostics)
      if (subdiagnostics%status /= RUTTER_OK .or. .not. subdiagnostics%result_produced) then
        diagnostics%status = subdiagnostics%status
        return
      end if

      step_days = min(remaining, subresult%maximum_event_timestep_days)
      event_tolerance = EVENT_TOL_FACTOR * epsilon(1.0_real64) * max(1.0_real64, input%interval_days)
      if (.not. ieee_is_finite(step_days) .or. step_days <= event_tolerance) then
        diagnostics%status = RUTTER_INVALID_RESULT
        return
      end if
      subinput%interval_days = step_days
      call evaluate_rutter_interval(state, subinput, subresult, subdiagnostics)
      if (subdiagnostics%status /= RUTTER_OK .or. .not. subdiagnostics%result_produced) then
        diagnostics%status = subdiagnostics%status
        return
      end if

      inflow_integral = inflow_integral + subresult%reservoir_inflow_cm_per_day * step_days
      outflow_integral = outflow_integral + subresult%reservoir_outflow_cm_per_day * step_days
      interception_integral = interception_integral + subresult%interception_rate_cm_per_day * step_days
      rain_integral = rain_integral + subresult%net_rain_cm_per_day * step_days
      irrigation_integral = irrigation_integral + subresult%net_surface_irrigation_cm_per_day * step_days
      wet_integral = wet_integral + subresult%wet_canopy_fraction * step_days
      ptra_integral = ptra_integral + subresult%potential_transpiration_cm_per_day * step_days
      state = subresult%candidate_state
      elapsed = elapsed + step_days
      remaining = max(0.0_real64, input%interval_days - elapsed)
      if (remaining <= event_tolerance) remaining = 0.0_real64
    end do

    result%reservoir_inflow_cm_per_day = inflow_integral / input%interval_days
    result%reservoir_outflow_cm_per_day = outflow_integral / input%interval_days
    result%interception_rate_cm_per_day = interception_integral / input%interval_days
    result%net_rain_cm_per_day = rain_integral / input%interval_days
    result%net_surface_irrigation_cm_per_day = irrigation_integral / input%interval_days
    result%wet_canopy_fraction = wet_integral / input%interval_days
    result%potential_transpiration_cm_per_day = ptra_integral / input%interval_days
    result%maximum_event_timestep_days = input%interval_days
    result%candidate_state = state
    if (.not. valid_result(result)) then
      result = rutter_interval_result_t()
      diagnostics%status = RUTTER_INVALID_RESULT
      return
    end if
    if (present(event_substeps)) event_substeps = iterations
    diagnostics%result_produced = .true.
  end subroutine evaluate_rutter_forcing_interval

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
  end function valid_input

  pure logical function valid_result(result)
    type(rutter_interval_result_t), intent(in) :: result
    valid_result = ieee_is_finite(result%reservoir_inflow_cm_per_day) .and. &
      ieee_is_finite(result%reservoir_outflow_cm_per_day) .and. &
      ieee_is_finite(result%interception_rate_cm_per_day) .and. &
      ieee_is_finite(result%net_rain_cm_per_day) .and. &
      ieee_is_finite(result%net_surface_irrigation_cm_per_day) .and. &
      ieee_is_finite(result%wet_canopy_fraction) .and. &
      ieee_is_finite(result%potential_transpiration_cm_per_day) .and. &
      ieee_is_finite(result%maximum_event_timestep_days) .and. &
      ieee_is_finite(result%candidate_state%canopy_storage_cm)
    if (.not. valid_result) return
    valid_result = result%reservoir_inflow_cm_per_day >= 0.0_real64 .and. &
      result%reservoir_outflow_cm_per_day >= 0.0_real64 .and. &
      result%interception_rate_cm_per_day >= 0.0_real64 .and. &
      result%net_rain_cm_per_day >= -1.0e-10_real64 .and. &
      result%net_surface_irrigation_cm_per_day >= -1.0e-10_real64 .and. &
      result%wet_canopy_fraction >= 0.0_real64 .and. result%wet_canopy_fraction <= 1.0_real64 + 1.0e-10_real64 .and. &
      result%potential_transpiration_cm_per_day >= 0.0_real64 .and. &
      result%maximum_event_timestep_days >= 0.0_real64 .and. result%candidate_state%canopy_storage_cm >= 0.0_real64
  end function valid_result

end module mod_rutter_event_integrator
