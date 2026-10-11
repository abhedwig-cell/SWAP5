module mod_rutter_event_integrator
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_rutter_interception_process, only: rutter_state_t, rutter_interval_input_t, &
       rutter_interval_result_t, rutter_diagnostics_t, RUTTER_OK, RUTTER_INVALID_INPUT, &
       RUTTER_INVALID_STATE, RUTTER_INVALID_RESULT
  implicit none
  private
  real(real64), parameter :: NIHIL = 1.0e-10_real64
  real(real64), parameter :: SMALL = 1.0e-6_real64
  real(real64), parameter :: TOL = 1.0e-12_real64
  public :: evaluate_rutter_forcing_interval
contains
  ! Integrate the B1.11 Rutter piecewise-constant flux regimes inside a
  ! forcing interval. These process events never request a Richards step.
  pure subroutine evaluate_rutter_forcing_interval(accepted_state, input, result, diagnostics, event_substeps)
    type(rutter_state_t), intent(in) :: accepted_state
    type(rutter_interval_input_t), intent(in) :: input
    type(rutter_interval_result_t), intent(out) :: result
    type(rutter_diagnostics_t), intent(out) :: diagnostics
    integer, intent(out), optional :: event_substeps
    real(real64) :: cap, s, release, gross_total, irrig_total, inrate, outrate, rain, irrigation
    real(real64) :: fin, fout, wet, remaining, dt, event_dt, tfill, tdry
    real(real64) :: vin, vout, vwet, vptrans, vnetrain, vnetirr, intercepted, ratio
    integer :: n

    result = rutter_interval_result_t()
    diagnostics = rutter_diagnostics_t()
    if (present(event_substeps)) event_substeps = 0
    if (.not. valid_input(input)) then
      diagnostics%status = RUTTER_INVALID_INPUT
      return
    end if
    if (.not. ieee_is_finite(accepted_state%canopy_storage_cm) .or. accepted_state%canopy_storage_cm < 0.0_real64) then
      diagnostics%status = RUTTER_INVALID_STATE
      return
    end if

    cap = input%canopy_storage_capacity_cm
    release = 0.0_real64
    s = min(accepted_state%canopy_storage_cm, cap)
    release = max(0.0_real64, accepted_state%canopy_storage_cm - s)
    gross_total = input%gross_rain_cm_per_day
    irrig_total = input%surface_irrigation_cm_per_day
    rain = gross_total
    irrigation = irrig_total
    if (input%surface_irrigation_is_intercepted) rain = rain + irrigation
    fin = rain * input%vegetation_cover_fraction
    fout = input%interception_evaporation_capacity_cm_per_day
    remaining = input%interval_days
    vin = 0.0_real64
    vout = 0.0_real64
    vwet = 0.0_real64
    vptrans = 0.0_real64
    n = 0

    ! Every nonterminal regime ends at a canopy fill or dry event. A guard
    ! catches roundoff-induced zero-duration loops without hiding bad states.
    do while (remaining > TOL)
      if (fin + fout < NIHIL) then
        inrate = 0.0_real64
        outrate = 0.0_real64
        wet = 0.0_real64
        event_dt = remaining
      else if (fin >= fout) then
        if (cap - s > NIHIL) then
          inrate = fin
          outrate = fout
          wet = 1.0_real64
          tfill = huge(1.0_real64)
          if (inrate > outrate) tfill = max(0.0_real64, (cap-s)/(inrate-outrate))
          event_dt = min(remaining, tfill)
        else
          inrate = fout
          outrate = fout
          wet = 1.0_real64
          event_dt = remaining
        end if
      else
        if (s > NIHIL) then
          inrate = fin
          outrate = fout
          wet = 1.0_real64
          tdry = huge(1.0_real64)
          if (outrate > inrate) tdry = max(0.0_real64, s/(outrate-inrate))
          event_dt = min(remaining, tdry)
        else
          inrate = fin
          outrate = fin
          wet = 0.0_real64
          if (fout > 0.0_real64) wet = min(1.0_real64, fin/fout)
          event_dt = remaining
        end if
      end if
      if (event_dt <= TOL) then
        ! Snap to the corresponding boundary and re-evaluate the next regime.
        if (fin >= fout .and. cap-s <= NIHIL) then
          s = cap
        else if (fin < fout .and. s <= NIHIL) then
          s = 0.0_real64
        else
          diagnostics%status = RUTTER_INVALID_RESULT
          return
        end if
        cycle
      end if
      dt = event_dt
      vin = vin + inrate*dt
      vout = vout + outrate*dt
      vwet = vwet + wet*dt
      vptrans = vptrans + (wet*input%potential_transpiration_wet_cm_per_day + &
        (1.0_real64-wet)*input%potential_transpiration_dry_cm_per_day)*dt
      s = s + (inrate-outrate)*dt
      if (abs(s-cap) <= TOL) s=cap
      if (abs(s) <= TOL) s=0.0_real64
      s = min(cap, max(0.0_real64, s))
      remaining = remaining-dt
      n = n+1
      if (n > 4) then
        diagnostics%status = RUTTER_INVALID_RESULT
        return
      end if
    end do

    ! B1.11 partitions intercepted water proportionally between rain and
    ! irrigation when ISUA=0, and assigns the interception to rain otherwise.
    ratio = 0.0_real64
    intercepted = vin/input%interval_days
    if (intercepted < SMALL) then
      vnetrain = gross_total*input%interval_days
      vnetirr = irrig_total*input%interval_days
    else if (gross_total + irrig_total > SMALL) then
      if (input%surface_irrigation_is_intercepted) then
        ratio = vin / ((gross_total + irrig_total)*input%interval_days)
        vnetrain = gross_total*input%interval_days*(1.0_real64-ratio)
        vnetirr = irrig_total*input%interval_days*(1.0_real64-ratio)
      else
        vnetrain = gross_total*input%interval_days-vin
        vnetirr = irrig_total*input%interval_days
      end if
    else
      vnetrain = gross_total*input%interval_days
      vnetirr = irrig_total*input%interval_days
    end if
    ! Capacity released by canopy/crop changes is transferred to the surface.
    vnetrain = vnetrain + release
    result%reservoir_inflow_cm_per_day = intercepted
    result%reservoir_outflow_cm_per_day = vout/input%interval_days
    result%interception_rate_cm_per_day = intercepted
    result%net_rain_cm_per_day = vnetrain/input%interval_days
    result%net_surface_irrigation_cm_per_day = vnetirr/input%interval_days
    result%wet_canopy_fraction = vwet/input%interval_days
    result%potential_transpiration_cm_per_day = vptrans/input%interval_days
    result%maximum_event_timestep_days = input%interval_days
    result%candidate_state%canopy_storage_cm = s
    if (.not. valid_result(result)) then
      result = rutter_interval_result_t()
      diagnostics%status = RUTTER_INVALID_RESULT
      return
    end if
    if (present(event_substeps)) event_substeps = n
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
      result%net_rain_cm_per_day >= -NIHIL .and. result%net_surface_irrigation_cm_per_day >= -NIHIL .and. &
      result%wet_canopy_fraction >= 0.0_real64 .and. result%wet_canopy_fraction <= 1.0_real64+NIHIL .and. &
      result%potential_transpiration_cm_per_day >= 0.0_real64 .and. &
      result%candidate_state%canopy_storage_cm >= 0.0_real64
  end function valid_result
end module mod_rutter_event_integrator
