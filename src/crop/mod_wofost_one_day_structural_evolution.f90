module mod_wofost_one_day_structural_evolution
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_wofost_crop_owner_state, only: wofost_crop_owner_state_t, &
       wofost_b110_reference_compatibility_t, WOFOST_CROP_OWNER_OK
  implicit none
  private

  real(real64), parameter :: B110_NIHIL = 1.0e-10_real64
  real(real64), parameter :: LAIEXP_CARRYOVER_THRESHOLD = 6.0_real64

  integer, parameter, public :: WOFOST_ONE_DAY_OK = 0
  integer, parameter, public :: WOFOST_ONE_DAY_INVALID_TIME = 1
  integer, parameter, public :: WOFOST_ONE_DAY_INVALID_OWNER = 2
  integer, parameter, public :: WOFOST_ONE_DAY_MISSING_CONTINUATION = 3
  integer, parameter, public :: WOFOST_ONE_DAY_INVALID_FORCING = 4
  integer, parameter, public :: WOFOST_ONE_DAY_INVALID_AGGREGATES = 5
  integer, parameter, public :: WOFOST_ONE_DAY_INVALID_PARAMETERS = 6
  integer, parameter, public :: WOFOST_ONE_DAY_INVALID_RATES = 7
  integer, parameter, public :: WOFOST_ONE_DAY_RELTR_MISMATCH = 8
  integer, parameter, public :: WOFOST_ONE_DAY_MISSING_GLAIEXP_CARRYOVER = 9
  integer, parameter, public :: WOFOST_ONE_DAY_INVALID_RESULT = 10
  integer, parameter, public :: WOFOST_ONE_DAY_INCONSISTENT_ANTHESIS = 11

  type, public :: wofost_one_day_forcing_t
    real(real64) :: minimum_temperature = 0.0_real64
    real(real64) :: average_temperature = 0.0_real64
    real(real64) :: daytime_average_temperature = 0.0_real64
    real(real64) :: global_radiation = 0.0_real64
    real(real64) :: daylength_hours = 0.0_real64
    real(real64) :: photoperiodic_daylength_hours = 0.0_real64
    real(real64) :: sinld = 0.0_real64
    real(real64) :: cosld = 0.0_real64
    real(real64) :: diffuse_perpendicular_radiation = 0.0_real64
    real(real64) :: daily_sine_solar_elevation_integral = 0.0_real64
    real(real64) :: co2_efficiency_factor = 1.0_real64
    real(real64) :: co2_amax_factor = 1.0_real64
  end type wofost_one_day_forcing_t

  type, public :: wofost_accepted_window_aggregates_t
    real(real64) :: actual_root_uptake = 0.0_real64
    real(real64) :: potential_transpiration = 0.0_real64
  end type wofost_accepted_window_aggregates_t

  type, public :: wofost_one_day_update_parameters_t
    real(real64) :: development_stage_end = 2.0_real64
    real(real64) :: leaf_lifespan = 0.0_real64
  end type wofost_one_day_update_parameters_t

  type, public :: wofost_one_day_rate_packet_t
    real(real64) :: temperature_sum_increment = 0.0_real64
    real(real64) :: development_rate = 0.0_real64
    real(real64) :: root_net_growth_rate = 0.0_real64
    real(real64) :: stem_net_growth_rate = 0.0_real64
    real(real64) :: storage_net_growth_rate = 0.0_real64
    real(real64) :: leaf_growth_rate = 0.0_real64
    real(real64) :: leaf_stress_death_rate = 0.0_real64
    real(real64) :: leaf_age_increment = 0.0_real64
    real(real64) :: youngest_specific_leaf_area = 0.0_real64
    real(real64) :: lai_exponential_growth_rate = 0.0_real64
    logical :: lai_exponential_rate_recomputed = .true.
    real(real64) :: relative_transpiration_used = 1.0_real64
  end type wofost_one_day_rate_packet_t

  type, public :: wofost_one_day_window_context_t
    logical :: active = .false.
    real(real64) :: t0 = 0.0_real64
    real(real64) :: t1 = 0.0_real64
    real(real64) :: running_minimum_temperature = 0.0_real64
  end type wofost_one_day_window_context_t

  type, public :: wofost_one_day_diagnostics_t
    logical :: candidate_built = .false.
    logical :: anthesis_triggered = .false.
    logical :: used_lai_exponential_carryover = .false.
    logical :: captured_lai_exponential_carryover = .false.
    integer :: leaf_cohort_count_before = 0
    integer :: leaf_cohort_count_after = 0
    real(real64) :: relative_transpiration = 1.0_real64
  end type wofost_one_day_diagnostics_t

  public :: prepare_wofost_one_day_candidate
  public :: finalize_wofost_one_day_candidate
  public :: b110_relative_transpiration

contains

  subroutine prepare_wofost_one_day_candidate(committed, forcing, t0, t1, candidate, context, status)
    type(wofost_crop_owner_state_t), intent(in) :: committed
    type(wofost_one_day_forcing_t), intent(in) :: forcing
    real(real64), intent(in) :: t0, t1
    type(wofost_crop_owner_state_t), intent(out) :: candidate
    type(wofost_one_day_window_context_t), intent(out) :: context
    integer, intent(out) :: status
    integer :: count

    context = wofost_one_day_window_context_t()
    status = WOFOST_ONE_DAY_OK

    if (committed%validate() /= WOFOST_CROP_OWNER_OK) then
      status = WOFOST_ONE_DAY_INVALID_OWNER
      return
    end if
    if (.not. valid_one_day_interval(t0, t1)) then
      status = WOFOST_ONE_DAY_INVALID_TIME
      return
    end if

    candidate = committed
    context%t0 = t0
    context%t1 = t1

    if (.not. committed%crop_emerged) return

    if (.not. allocated(committed%evolution_continuation)) then
      status = WOFOST_ONE_DAY_MISSING_CONTINUATION
      return
    end if
    if (.not. valid_forcing(forcing)) then
      status = WOFOST_ONE_DAY_INVALID_FORCING
      return
    end if
    if (committed%development_stage < 0.0_real64) then
      status = WOFOST_ONE_DAY_INVALID_OWNER
      return
    end if
    if (committed%development_stage >= 1.0_real64 .and. &
         .not. committed%evolution_continuation%anthesis_reached) then
      status = WOFOST_ONE_DAY_INCONSISTENT_ANTHESIS
      return
    end if

    context%active = .true.
    count = min(candidate%evolution_continuation%minimum_temperature_history_count + 1, 7)
    candidate%evolution_continuation%minimum_temperature_history(2:7) = &
         candidate%evolution_continuation%minimum_temperature_history(1:6)
    candidate%evolution_continuation%minimum_temperature_history(1) = forcing%minimum_temperature
    candidate%evolution_continuation%minimum_temperature_history_count = count
    context%running_minimum_temperature = &
         sum(candidate%evolution_continuation%minimum_temperature_history) / real(count, real64)
  end subroutine prepare_wofost_one_day_candidate

  subroutine finalize_wofost_one_day_candidate(prepared, context, parameters, aggregates, rates, candidate, diagnostics, status)
    type(wofost_crop_owner_state_t), intent(in) :: prepared
    type(wofost_one_day_window_context_t), intent(in) :: context
    type(wofost_one_day_update_parameters_t), intent(in) :: parameters
    type(wofost_accepted_window_aggregates_t), intent(in) :: aggregates
    type(wofost_one_day_rate_packet_t), intent(in) :: rates
    type(wofost_crop_owner_state_t), intent(out) :: candidate
    type(wofost_one_day_diagnostics_t), intent(out) :: diagnostics
    integer, intent(out) :: status
    real(real64) :: reltr, dvr_applied

    diagnostics = wofost_one_day_diagnostics_t()
    status = WOFOST_ONE_DAY_OK

    if (prepared%validate() /= WOFOST_CROP_OWNER_OK) then
      status = WOFOST_ONE_DAY_INVALID_OWNER
      return
    end if
    if (.not. valid_one_day_interval(context%t0, context%t1)) then
      status = WOFOST_ONE_DAY_INVALID_TIME
      return
    end if

    candidate = prepared
    if (.not. prepared%crop_emerged) then
      diagnostics%candidate_built = .true.
      return
    end if
    if (.not. context%active) then
      status = WOFOST_ONE_DAY_INVALID_TIME
      return
    end if
    if (.not. allocated(prepared%evolution_continuation)) then
      status = WOFOST_ONE_DAY_MISSING_CONTINUATION
      return
    end if
    if (.not. valid_parameters(parameters)) then
      status = WOFOST_ONE_DAY_INVALID_PARAMETERS
      return
    end if
    if (.not. valid_aggregates(aggregates)) then
      status = WOFOST_ONE_DAY_INVALID_AGGREGATES
      return
    end if
    if (.not. valid_rates(rates)) then
      status = WOFOST_ONE_DAY_INVALID_RATES
      return
    end if

    reltr = b110_relative_transpiration(aggregates)
    diagnostics%relative_transpiration = reltr
    if (.not. close_enough(rates%relative_transpiration_used, reltr)) then
      status = WOFOST_ONE_DAY_RELTR_MISMATCH
      return
    end if

    diagnostics%leaf_cohort_count_before = candidate%biomass%active_leaf_cohort_count()
    call apply_leaf_state_update(candidate, parameters, rates, diagnostics, status)
    if (status /= WOFOST_ONE_DAY_OK) return

    candidate%biomass%root_biomass = candidate%biomass%root_biomass + rates%root_net_growth_rate
    candidate%biomass%stem_biomass = candidate%biomass%stem_biomass + rates%stem_net_growth_rate
    candidate%biomass%storage_biomass = candidate%biomass%storage_biomass + rates%storage_net_growth_rate

    dvr_applied = rates%development_rate
    if (candidate%development_stage + dvr_applied >= 1.0_real64 .and. &
         .not. candidate%evolution_continuation%anthesis_reached) then
      candidate%evolution_continuation%anthesis_reached = .true.
      dvr_applied = 1.0_real64 - candidate%development_stage
      diagnostics%anthesis_triggered = .true.
    end if

    candidate%evolution_continuation%temperature_sum = &
         candidate%evolution_continuation%temperature_sum + rates%temperature_sum_increment
    candidate%development_stage = min(candidate%development_stage + dvr_applied, &
         parameters%development_stage_end)

    diagnostics%leaf_cohort_count_after = candidate%biomass%active_leaf_cohort_count()
    if (candidate%validate() /= WOFOST_CROP_OWNER_OK) then
      status = WOFOST_ONE_DAY_INVALID_RESULT
      return
    end if

    diagnostics%candidate_built = .true.
  end subroutine finalize_wofost_one_day_candidate

  subroutine apply_leaf_state_update(candidate, parameters, rates, diagnostics, status)
    type(wofost_crop_owner_state_t), intent(inout) :: candidate
    type(wofost_one_day_update_parameters_t), intent(in) :: parameters
    type(wofost_one_day_rate_packet_t), intent(in) :: rates
    type(wofost_one_day_diagnostics_t), intent(inout) :: diagnostics
    integer, intent(out) :: status
    real(real64), allocatable :: new_leaf(:), new_sla(:), new_age(:)
    real(real64) :: remaining_death, lai_rate, lai_before
    integer :: n

    status = WOFOST_ONE_DAY_OK
    n = candidate%biomass%active_leaf_cohort_count()
    remaining_death = rates%leaf_stress_death_rate

    do while (remaining_death > 0.0_real64 .and. n >= 1)
      if (remaining_death >= candidate%biomass%leaf_biomass(n)) then
        remaining_death = remaining_death - candidate%biomass%leaf_biomass(n)
        candidate%biomass%leaf_biomass(n) = 0.0_real64
        n = n - 1
      else
        candidate%biomass%leaf_biomass(n) = candidate%biomass%leaf_biomass(n) - remaining_death
        remaining_death = 0.0_real64
      end if
    end do

    do while (n >= 1)
      if (candidate%biomass%leaf_age(n) <= parameters%leaf_lifespan) exit
      candidate%biomass%leaf_biomass(n) = 0.0_real64
      n = n - 1
    end do

    allocate(new_leaf(n + 1), new_sla(n + 1), new_age(n + 1))
    new_leaf(1) = rates%leaf_growth_rate
    new_sla(1) = rates%youngest_specific_leaf_area
    new_age(1) = 0.0_real64
    if (n > 0) then
      new_leaf(2:n + 1) = candidate%biomass%leaf_biomass(1:n)
      new_sla(2:n + 1) = candidate%biomass%specific_leaf_area(1:n)
      new_age(2:n + 1) = candidate%biomass%leaf_age(1:n) + rates%leaf_age_increment
    end if
    call move_alloc(new_leaf, candidate%biomass%leaf_biomass)
    call move_alloc(new_sla, candidate%biomass%specific_leaf_area)
    call move_alloc(new_age, candidate%biomass%leaf_age)

    lai_before = candidate%biomass%exponential_leaf_area_index
    if (lai_before < LAIEXP_CARRYOVER_THRESHOLD) then
      if (.not. rates%lai_exponential_rate_recomputed) then
        status = WOFOST_ONE_DAY_INVALID_RATES
        return
      end if
      lai_rate = rates%lai_exponential_growth_rate
      candidate%biomass%exponential_leaf_area_index = lai_before + lai_rate
      if (candidate%biomass%exponential_leaf_area_index >= LAIEXP_CARRYOVER_THRESHOLD) then
        if (.not. allocated(candidate%b110_reference_compatibility)) then
          allocate(wofost_b110_reference_compatibility_t :: candidate%b110_reference_compatibility)
        end if
        candidate%b110_reference_compatibility%lai_exponential_rate_carryover = lai_rate
        diagnostics%captured_lai_exponential_carryover = .true.
      end if
    else
      if (rates%lai_exponential_rate_recomputed) then
        status = WOFOST_ONE_DAY_INVALID_RATES
        return
      end if
      if (.not. allocated(candidate%b110_reference_compatibility)) then
        status = WOFOST_ONE_DAY_MISSING_GLAIEXP_CARRYOVER
        return
      end if
      lai_rate = candidate%b110_reference_compatibility%lai_exponential_rate_carryover
      candidate%biomass%exponential_leaf_area_index = lai_before + lai_rate
      diagnostics%used_lai_exponential_carryover = .true.
    end if
  end subroutine apply_leaf_state_update

  real(real64) function b110_relative_transpiration(aggregates) result(value)
    type(wofost_accepted_window_aggregates_t), intent(in) :: aggregates

    value = 1.0_real64
    if (abs(aggregates%potential_transpiration) < B110_NIHIL) return
    value = max(0.0_real64, min(1.0_real64, &
         aggregates%actual_root_uptake / aggregates%potential_transpiration))
  end function b110_relative_transpiration

  logical function valid_one_day_interval(t0, t1) result(valid)
    real(real64), intent(in) :: t0, t1
    real(real64) :: scale, tolerance

    valid = .false.
    if (.not. ieee_is_finite(t0) .or. .not. ieee_is_finite(t1)) return
    if (t1 <= t0) return
    scale = max(1.0_real64, abs(t0), abs(t1))
    tolerance = 32.0_real64 * epsilon(1.0_real64) * scale
    valid = abs((t1 - t0) - 1.0_real64) <= tolerance
  end function valid_one_day_interval

  logical function valid_forcing(forcing) result(valid)
    type(wofost_one_day_forcing_t), intent(in) :: forcing
    real(real64) :: values(12)

    values = [forcing%minimum_temperature, forcing%average_temperature, &
         forcing%daytime_average_temperature, forcing%global_radiation, &
         forcing%daylength_hours, forcing%photoperiodic_daylength_hours, &
         forcing%sinld, forcing%cosld, forcing%diffuse_perpendicular_radiation, &
         forcing%daily_sine_solar_elevation_integral, forcing%co2_efficiency_factor, &
         forcing%co2_amax_factor]
    valid = all(ieee_is_finite(values))
    if (.not. valid) return
    valid = forcing%global_radiation >= 0.0_real64 .and. &
         forcing%daylength_hours >= 0.0_real64 .and. forcing%daylength_hours <= 24.0_real64 .and. &
         forcing%photoperiodic_daylength_hours >= 0.0_real64 .and. &
         forcing%photoperiodic_daylength_hours <= 24.0_real64 .and. &
         forcing%diffuse_perpendicular_radiation >= 0.0_real64 .and. &
         forcing%daily_sine_solar_elevation_integral >= 0.0_real64 .and. &
         forcing%co2_efficiency_factor >= 0.0_real64 .and. forcing%co2_amax_factor >= 0.0_real64
  end function valid_forcing

  logical function valid_aggregates(aggregates) result(valid)
    type(wofost_accepted_window_aggregates_t), intent(in) :: aggregates

    valid = ieee_is_finite(aggregates%actual_root_uptake) .and. &
         ieee_is_finite(aggregates%potential_transpiration)
    if (.not. valid) return
    valid = aggregates%actual_root_uptake >= 0.0_real64 .and. &
         aggregates%potential_transpiration >= 0.0_real64
  end function valid_aggregates

  logical function valid_parameters(parameters) result(valid)
    type(wofost_one_day_update_parameters_t), intent(in) :: parameters

    valid = ieee_is_finite(parameters%development_stage_end) .and. &
         ieee_is_finite(parameters%leaf_lifespan)
    if (.not. valid) return
    valid = parameters%development_stage_end > 0.0_real64 .and. parameters%leaf_lifespan >= 0.0_real64
  end function valid_parameters

  logical function valid_rates(rates) result(valid)
    type(wofost_one_day_rate_packet_t), intent(in) :: rates
    real(real64) :: values(11)

    values = [rates%temperature_sum_increment, rates%development_rate, &
         rates%root_net_growth_rate, rates%stem_net_growth_rate, rates%storage_net_growth_rate, &
         rates%leaf_growth_rate, rates%leaf_stress_death_rate, rates%leaf_age_increment, &
         rates%youngest_specific_leaf_area, rates%lai_exponential_growth_rate, &
         rates%relative_transpiration_used]
    valid = all(ieee_is_finite(values))
    if (.not. valid) return
    valid = rates%temperature_sum_increment >= 0.0_real64 .and. &
         rates%development_rate >= 0.0_real64 .and. rates%leaf_growth_rate >= 0.0_real64 .and. &
         rates%leaf_stress_death_rate >= 0.0_real64 .and. rates%leaf_age_increment >= 0.0_real64 .and. &
         rates%youngest_specific_leaf_area >= 0.0_real64 .and. &
         rates%lai_exponential_growth_rate >= 0.0_real64 .and. &
         rates%relative_transpiration_used >= 0.0_real64 .and. rates%relative_transpiration_used <= 1.0_real64
  end function valid_rates

  logical function close_enough(left, right) result(close)
    real(real64), intent(in) :: left, right
    real(real64) :: tolerance

    tolerance = 64.0_real64 * epsilon(1.0_real64) * max(1.0_real64, abs(left), abs(right))
    close = abs(left - right) <= tolerance
  end function close_enough

end module mod_wofost_one_day_structural_evolution
