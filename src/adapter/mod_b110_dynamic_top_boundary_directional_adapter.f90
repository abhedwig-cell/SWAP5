module mod_b110_dynamic_top_boundary_directional_adapter
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_boundary_conditions_t, soil_water_top_boundary_result_t, &
       SW_TOP_BOUNDARY_AVAILABLE, SW_TOP_BOUNDARY_REGIME_FLUX
  use mod_b110_default_mvg_provider, only: evaluate_b110_default_mvg_conductivity
  use mod_b110_dynamic_top_boundary_provider, only: B110_DYN_TOP_ATMOSPHERIC_HEAD_CM, &
       B110_DYN_TOP_PONDING_CLASSIFICATION_CM, B110_DYN_TOP_HEAD_SWITCH_CM
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t
  implicit none
  private

  public :: evaluate_b110_dynamic_surface_flux_direction

contains

  subroutine evaluate_b110_dynamic_surface_flux_direction(provider, pressure_head_top, water_content_top, &
       candidate_ponding_depth, requested, incoming_previous_ponding_direction, &
       available, top_flux_direction, outgoing_ponding_direction, route)
    type(b110_dynamic_top_boundary_solver_provider_t), intent(in) :: provider
    real(real64), intent(in) :: pressure_head_top, water_content_top, candidate_ponding_depth
    type(soil_water_boundary_conditions_t), intent(in) :: requested
    real(real64), intent(in) :: incoming_previous_ponding_direction
    logical, intent(out) :: available
    real(real64), intent(out) :: top_flux_direction, outgoing_ponding_direction
    character(len=*), intent(out) :: route

    type(soil_water_top_boundary_result_t) :: top
    real(real64) :: k_atm, k_top, k_sat, k1_atm, k1_max
    real(real64) :: emax, q1, h0, distance, top_dz, demand, previous_ponding
    real(real64) :: scale, guard
    logical :: ok

    available = .false.
    top_flux_direction = 0.0_real64
    outgoing_ponding_direction = 0.0_real64
    route = 'dynamic-surface-flux-direction-unavailable'

    if (.not. associated(provider%geometry) .or. .not. associated(provider%hydraulics)) then
       route = 'dynamic-provider-unbound'
       return
    end if
    if (.not. ieee_is_finite(pressure_head_top) .or. .not. ieee_is_finite(water_content_top) .or. &
        .not. ieee_is_finite(candidate_ponding_depth) .or. &
        .not. ieee_is_finite(incoming_previous_ponding_direction)) then
       route = 'dynamic-direction-input-nonfinite'
       return
    end if
    if (provider%step_duration <= 0.0_real64) then
       route = 'dynamic-step-duration-invalid'
       return
    end if

    ! Reuse the qualified value provider as the route authority. The sibling
    ! capability below differentiates only a strict smooth subset and never
    ! changes the value-provider ABI or physical result.
    call provider%evaluate(pressure_head_top, water_content_top, candidate_ponding_depth, requested, top)
    if (top%status /= SW_TOP_BOUNDARY_AVAILABLE .or. top%regime /= SW_TOP_BOUNDARY_REGIME_FLUX .or. &
        trim(top%route) /= 'surface-flux') then
       route = 'dynamic-route-not-surface-flux'
       return
    end if

    top_dz = provider%geometry%dz(1)
    distance = provider%geometry%node_distance(1)
    if (top_dz <= 0.0_real64 .or. distance <= 0.0_real64) then
       route = 'dynamic-top-geometry-invalid'
       return
    end if

    call evaluate_b110_default_mvg_conductivity(provider%hydraulics, 1, &
         B110_DYN_TOP_ATMOSPHERIC_HEAD_CM, k_atm, ok)
    if (.not. ok) then
       route = 'dynamic-atmospheric-k-invalid'
       return
    end if
    call evaluate_b110_default_mvg_conductivity(provider%hydraulics, 1, pressure_head_top, k_top, ok)
    if (.not. ok) then
       route = 'dynamic-top-k-invalid'
       return
    end if
    call evaluate_b110_default_mvg_conductivity(provider%hydraulics, 1, 0.0_real64, k_sat, ok)
    if (.not. ok) then
       route = 'dynamic-saturated-k-invalid'
       return
    end if
    call hmean_value(provider%conductivity_mean_method, k_atm, k_top, top_dz, top_dz, k1_atm, ok)
    if (.not. ok) then
       route = 'dynamic-atmospheric-mean-invalid'
       return
    end if
    call hmean_value(provider%conductivity_mean_method, k_sat, k_top, top_dz, top_dz, k1_max, ok)
    if (.not. ok .or. k1_max <= 0.0_real64) then
       route = 'dynamic-saturated-mean-invalid'
       return
    end if

    emax = -k1_atm * ((B110_DYN_TOP_ATMOSPHERIC_HEAD_CM-pressure_head_top)/distance + 1.0_real64)
    q1 = top%actual_top_flux
    h0 = pressure_head_top - distance*(q1/k1_max + 1.0_real64)
    if (.not. ieee_is_finite(emax) .or. .not. ieee_is_finite(q1) .or. .not. ieee_is_finite(h0)) then
       route = 'dynamic-route-guard-nonfinite'
       return
    end if

    previous_ponding = provider%previous_ponding_depth
    demand = provider%potential_bare_soil_evaporation
    scale = max(1.0_real64, abs(previous_ponding), abs(emax), abs(q1), abs(h0), abs(demand))
    guard = 4096.0_real64*epsilon(1.0_real64)*scale

    ! Ponded-vs-dry evaporation is a physical switch. Away from that switch the
    ! ponded branch is head-independent. On the dry branch only zero-clamped or
    ! demand-limited evaporation is admitted here; the capacity-limited branch
    ! has dqtop/dh_top != 0 and would require a modified accepted Jacobian.
    if (abs(previous_ponding-B110_DYN_TOP_PONDING_CLASSIFICATION_CM) <= guard) then
       route = 'dynamic-ponding-classification-switch'
       return
    end if
    if (previous_ponding <= B110_DYN_TOP_PONDING_CLASSIFICATION_CM) then
       if (abs(emax) <= guard .or. abs(emax-demand) <= guard) then
          route = 'dynamic-evaporation-switch'
          return
       end if
       if (emax > 0.0_real64 .and. emax < demand) then
          route = 'dynamic-surface-flux-capacity-limited-unavailable'
          return
       end if
    end if

    ! Fail closed exactly at the atmospheric-head and surface-head regime
    ! boundaries. Strictly inside surface-flux these guards do not contribute to
    ! the derivative of q1.
    if (q1 >= 0.0_real64 .and. abs(q1-emax) <= guard) then
       route = 'dynamic-atmospheric-head-switch'
       return
    end if
    if (abs(h0-B110_DYN_TOP_HEAD_SWITCH_CM) <= guard) then
       route = 'dynamic-surface-head-switch'
       return
    end if
    if (h0 > B110_DYN_TOP_HEAD_SWITCH_CM) then
       route = 'dynamic-surface-flux-route-inconsistent'
       return
    end if

    ! On the admitted constant-evaporation surface-flux branch:
    !   qtop = q1 = -q0 - pond_previous/dt.
    ! Forcing and evaporation demand are immutable step data, therefore only
    ! the incoming previous-ponding direction contributes. The accepted surface
    ! ponding is identically zero on this fixed branch.
    top_flux_direction = -incoming_previous_ponding_direction/provider%step_duration
    outgoing_ponding_direction = 0.0_real64
    if (.not. ieee_is_finite(top_flux_direction)) then
       route = 'dynamic-top-flux-direction-nonfinite'
       top_flux_direction = 0.0_real64
       return
    end if

    available = .true.
    route = 'dynamic-surface-flux-constant-evap-direction'
  end subroutine evaluate_b110_dynamic_surface_flux_direction

  subroutine hmean_value(method, kup, klow, dzup, dzlow, value, ok)
    integer, intent(in) :: method
    real(real64), intent(in) :: kup, klow, dzup, dzlow
    real(real64), intent(out) :: value
    logical, intent(out) :: ok
    real(real64) :: a

    value = 0.0_real64
    ok = .false.
    if (.not. ieee_is_finite(kup) .or. .not. ieee_is_finite(klow)) return
    if (dzup <= 0.0_real64 .or. dzlow <= 0.0_real64) return
    if (method >= 3 .and. method <= 6) then
       if (kup <= 0.0_real64 .or. klow <= 0.0_real64) return
    end if
    select case (method)
    case (1)
       value = 0.5_real64*(kup+klow)
    case (2)
       value = (dzup*kup+dzlow*klow)/(dzup+dzlow)
    case (3)
       value = sqrt(kup*klow)
    case (4)
       a = dzup/(dzup+dzlow)
       value = kup**a * klow**(1.0_real64-a)
    case (5)
       if (kup <= 0.0_real64 .or. klow <= 0.0_real64) return
       value = 1.0_real64/(0.5_real64/kup+0.5_real64/klow)
    case (6)
       if (kup <= 0.0_real64 .or. klow <= 0.0_real64) return
       a = dzup/(dzup+dzlow)
       value = 1.0_real64/(a/kup+(1.0_real64-a)/klow)
    case default
       return
    end select
    ok = ieee_is_finite(value)
  end subroutine hmean_value

end module mod_b110_dynamic_top_boundary_directional_adapter
