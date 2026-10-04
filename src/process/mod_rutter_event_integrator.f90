module mod_rutter_event_integrator
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_rutter_interception_process, only: rutter_state_t, rutter_interval_input_t, &
       rutter_interval_result_t, rutter_diagnostics_t, RUTTER_OK, RUTTER_INVALID_INPUT, &
       RUTTER_INVALID_STATE, RUTTER_INVALID_RESULT
  implicit none
  private
  real(real64), parameter :: LEGACY_DC = 1.0e-4_real64
  real(real64), parameter :: STATE_TOL = 1.0e-10_real64

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
    real(real64) :: state0, state1, capacity_release, p, cover_inflow, evap, intercept
    real(real64) :: beta, zeta, tentative, tcap, ratio, dt, rain_out, irrigation_out
    real(real64) :: wet, evap_capacity, fimin

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

    if (.not. input%minimum_relative_canopy_evaporation_factor_present) then
      diagnostics%status = RUTTER_INVALID_INPUT
      return
    end if

    ! Capacity loss above the dry-canopy cutoff is an instantaneous
    ! canopy-to-surface transfer. The legacy zero-capacity branch instead
    ! evaporates residual storage as vegetation dies off.
    if (input%canopy_storage_capacity_cm < LEGACY_DC) then
      state0=accepted_state%canopy_storage_cm
      capacity_release=0.0_real64
    else
      state0=min(accepted_state%canopy_storage_cm,input%canopy_storage_capacity_cm)
      capacity_release=max(0.0_real64,accepted_state%canopy_storage_cm-state0)
    end if
    p = input%gross_rain_cm_per_day
    if (input%surface_irrigation_is_intercepted) p=p+input%surface_irrigation_cm_per_day
    dt = input%interval_days
    cover_inflow = p*input%vegetation_cover_fraction
    evap_capacity = input%interception_evaporation_capacity_cm_per_day
    fimin = input%minimum_relative_canopy_evaporation_factor
    state1 = state0
    evap = 0.0_real64

    ! The legacy Rutter kernel solves the reservoir analytically, including
    ! the time to capacity (tcap), and uses fimin below full storage.
    if (input%canopy_storage_capacity_cm < LEGACY_DC .or. &
        (state0 < LEGACY_DC .and. p < LEGACY_DC)) then
      if (state0 > LEGACY_DC) then
        evap=state0/dt
        state1=0.0_real64
      end if
      intercept=0.0_real64
    else if (state0 >= input%canopy_storage_capacity_cm-2.0_real64*LEGACY_DC .and. &
             cover_inflow >= evap_capacity) then
      state1=input%canopy_storage_capacity_cm
      evap=evap_capacity
      intercept=max(0.0_real64,(state1-state0)/dt+evap)
    else if (evap_capacity < LEGACY_DC .or. fimin > 0.99999_real64) then
      state1=min(input%canopy_storage_capacity_cm, &
                 max(0.0_real64,state0+(cover_inflow-evap_capacity)*dt))
      if (state1 < input%canopy_storage_capacity_cm) then
        evap=(state0-state1)/dt+cover_inflow
      else
        evap=evap_capacity
      end if
      intercept=max(0.0_real64,(state1-state0)/dt+evap)
    else
      beta=(1.0_real64-fimin)*evap_capacity/input%canopy_storage_capacity_cm
      zeta=cover_inflow-fimin*evap_capacity
      tentative=(state0-zeta/beta)*exp(-beta*dt)+zeta/beta
      tentative=max(tentative,0.0_real64)
      if (tentative < input%canopy_storage_capacity_cm) then
        state1=tentative
        evap=(state0-state1)/dt+cover_inflow
      else
        state1=input%canopy_storage_capacity_cm
        ratio=(state0-zeta/beta)/(input%canopy_storage_capacity_cm-zeta/beta)
        if (.not. ieee_is_finite(ratio) .or. ratio <= 0.0_real64) then
          diagnostics%status=RUTTER_INVALID_RESULT
          return
        end if
        tcap=log(ratio)/beta
        if (.not. ieee_is_finite(tcap) .or. tcap < -STATE_TOL .or. tcap > dt+STATE_TOL) then
          diagnostics%status=RUTTER_INVALID_RESULT
          return
        end if
        tcap=min(dt,max(0.0_real64,tcap))
        evap=(state0-state1+cover_inflow*tcap+evap_capacity*(dt-tcap))/dt
      end if
      intercept=max(0.0_real64,(state1-state0)/dt+evap)
    end if

    if (input%surface_irrigation_is_intercepted .and. &
        input%gross_rain_cm_per_day+input%surface_irrigation_cm_per_day > 0.0_real64) then
      p=input%gross_rain_cm_per_day+input%surface_irrigation_cm_per_day
      rain_out=input%gross_rain_cm_per_day-intercept*input%gross_rain_cm_per_day/p
      irrigation_out=input%surface_irrigation_cm_per_day-intercept*input%surface_irrigation_cm_per_day/p
    else
      rain_out=input%gross_rain_cm_per_day-intercept
      irrigation_out=input%surface_irrigation_cm_per_day
    end if
    rain_out=rain_out+capacity_release/dt
    if (rain_out < -STATE_TOL .or. irrigation_out < -STATE_TOL .or. &
        intercept > input%gross_rain_cm_per_day+input%surface_irrigation_cm_per_day+STATE_TOL) then
      diagnostics%status=RUTTER_INVALID_RESULT
      return
    end if
    wet=0.0_real64
    if (evap_capacity > LEGACY_DC) wet=min(1.0_real64,max(0.0_real64,evap/evap_capacity))
    result%reservoir_inflow_cm_per_day=intercept
    result%reservoir_outflow_cm_per_day=evap
    result%interception_rate_cm_per_day=intercept
    result%net_rain_cm_per_day=max(0.0_real64,rain_out)
    result%net_surface_irrigation_cm_per_day=max(0.0_real64,irrigation_out)
    result%wet_canopy_fraction=wet
    result%potential_transpiration_cm_per_day=wet*input%potential_transpiration_wet_cm_per_day + &
      (1.0_real64-wet)*input%potential_transpiration_dry_cm_per_day
    result%maximum_event_timestep_days=input%interval_days
    result%candidate_state%canopy_storage_cm=state1
    if (.not. valid_result(result)) then
      result = rutter_interval_result_t()
      diagnostics%status = RUTTER_INVALID_RESULT
      return
    end if
    if (present(event_substeps)) event_substeps = 1
    diagnostics%result_produced = .true.
  end subroutine evaluate_rutter_forcing_interval

  pure logical function valid_input(input)
    type(rutter_interval_input_t), intent(in) :: input
    valid_input = ieee_is_finite(input%gross_rain_cm_per_day) .and. &
      ieee_is_finite(input%surface_irrigation_cm_per_day) .and. &
      ieee_is_finite(input%vegetation_cover_fraction) .and. &
      ieee_is_finite(input%canopy_storage_capacity_cm) .and. &
      ieee_is_finite(input%interception_evaporation_capacity_cm_per_day) .and. &
      ieee_is_finite(input%minimum_relative_canopy_evaporation_factor) .and. &
      ieee_is_finite(input%potential_transpiration_dry_cm_per_day) .and. &
      ieee_is_finite(input%potential_transpiration_wet_cm_per_day) .and. &
      ieee_is_finite(input%interval_days)
    if (.not. valid_input) return
    valid_input = input%gross_rain_cm_per_day >= 0.0_real64 .and. &
      input%surface_irrigation_cm_per_day >= 0.0_real64 .and. &
      input%vegetation_cover_fraction >= 0.0_real64 .and. input%vegetation_cover_fraction <= 1.0_real64 .and. &
      input%canopy_storage_capacity_cm >= 0.0_real64 .and. &
      input%interception_evaporation_capacity_cm_per_day >= 0.0_real64 .and. &
      input%minimum_relative_canopy_evaporation_factor >= 0.0_real64 .and. &
      input%minimum_relative_canopy_evaporation_factor <= 1.0_real64 .and. &
      (input%canopy_storage_capacity_cm <= LEGACY_DC .or. input%vegetation_cover_fraction >= LEGACY_DC) .and. &
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
