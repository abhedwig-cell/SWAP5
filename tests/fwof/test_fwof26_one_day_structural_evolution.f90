program test_fwof26_one_day_structural_evolution
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t
  use mod_wofost_crop_owner_state, only: wofost_crop_owner_state_t, &
       wofost_common_evolution_continuation_t, WOFOST_CROP_OWNER_OK
  use mod_wofost_one_day_structural_evolution, only: &
       wofost_one_day_forcing_t, wofost_accepted_window_aggregates_t, &
       wofost_one_day_update_parameters_t, wofost_one_day_rate_packet_t, &
       wofost_one_day_window_context_t, wofost_one_day_diagnostics_t, &
       prepare_wofost_one_day_candidate, finalize_wofost_one_day_candidate, &
       WOFOST_ONE_DAY_OK, WOFOST_ONE_DAY_INVALID_TIME, WOFOST_ONE_DAY_RELTR_MISMATCH, &
       WOFOST_ONE_DAY_MISSING_GLAIEXP_CARRYOVER
  implicit none

  type(wofost_crop_owner_state_t) :: seed, inactive_seed
  type(wofost_crop_owner_state_t) :: prepared1, candidate1, prepared2, candidate2
  type(wofost_crop_owner_state_t) :: replay_prepared, replay_candidate, missing_prepared
  type(wofost_one_day_forcing_t) :: forcing1, forcing2, invalid_forcing
  type(wofost_accepted_window_aggregates_t) :: aggregates1, aggregates2
  type(wofost_one_day_update_parameters_t) :: parameters
  type(wofost_one_day_rate_packet_t) :: rates1, rates2, bad_rates
  type(wofost_one_day_window_context_t) :: context1, context2, replay_context, missing_context
  type(wofost_one_day_diagnostics_t) :: diagnostics1, diagnostics2, replay_diagnostics, missing_diagnostics
  type(kernel_committed_state_t) :: committed
  type(kernel_checkpoint_t) :: checkpoint
  class(transaction_state_t), allocatable :: initial, origin1, origin2, inactive_poly
  logical :: did_initialize, available
  integer :: status
  real(real64) :: nanv

  nanv = ieee_value(0.0_real64, ieee_quiet_nan)
  call seed_active_owner(seed)
  call seed_inactive_owner(inactive_seed)
  call configure_forcing(forcing1, -2.0_real64)
  call configure_forcing(forcing2, -3.0_real64)
  call configure_parameters(parameters)
  call configure_day1(aggregates1, rates1)
  call configure_day2(aggregates2, rates2)

  invalid_forcing = forcing1
  invalid_forcing%minimum_temperature = nanv
  call prepare_wofost_one_day_candidate(inactive_seed, invalid_forcing, 10.0_real64, 11.0_real64, &
       prepared1, context1, status)
  call require(status == WOFOST_ONE_DAY_OK, 'inactive route does not inspect active forcing')
  call require(.not. context1%active, 'inactive route context inactive')
  call require(same_owner(inactive_seed, prepared1), 'inactive route exact no-op')
  write(*,'(A)') 'FWOF26_INACTIVE_ROUTE_NO_OPTIONAL_STATE_OR_FORCING_DEPENDENCY=PASS'

  call prepare_wofost_one_day_candidate(seed, forcing1, 100.0_real64, 100.5_real64, &
       prepared1, context1, status)
  call require(status == WOFOST_ONE_DAY_INVALID_TIME, 'half-day crop event rejected')
  call require(same_owner(seed, seed), 'seed remains valid after rejected half-day event')
  write(*,'(A)') 'FWOF26_ONLY_EXPLICIT_ONE_DAY_EVENT_ADMITTED=PASS'

  allocate(initial, source=seed)
  call committed%initialize(2601_int64, initial, did_initialize, 100.0_real64)
  call require(did_initialize, 'F-KT owner initialization')
  call require(committed%ready(), 'F-KT committed owner ready')
  call committed%capture_checkpoint(checkpoint, available)
  call require(available, 'F-KT checkpoint available')
  call require(checkpoint%ready(), 'F-KT checkpoint ready')

  call checkpoint%snapshot(origin1, available)
  call require(available, 'first checkpoint snapshot available')
  select type (typed_origin => origin1)
  type is (wofost_crop_owner_state_t)
    call require(same_owner(typed_origin, seed), 'checkpoint equals source seed')
    call prepare_wofost_one_day_candidate(typed_origin, forcing1, 100.0_real64, 101.0_real64, &
         prepared1, context1, status)
  class default
    error stop 'unexpected checkpoint dynamic type'
  end select
  call require(status == WOFOST_ONE_DAY_OK, 'day1 prepare succeeds')
  call require(context1%active, 'day1 context active')
  call require(prepared1%evolution_continuation%minimum_temperature_history_count == 3, &
       'day1 running temperature count')
  call require(all_same_bits(prepared1%evolution_continuation%minimum_temperature_history, &
       [-2.0_real64, -1.0_real64, 1.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64]), &
       'day1 minimum-temperature shift')
  call require(abs(context1%running_minimum_temperature + 2.0_real64 / 3.0_real64) <= 1.0e-14_real64, &
       'day1 running minimum-temperature mean')
  select type (typed_origin => origin1)
  type is (wofost_crop_owner_state_t)
    call require(same_owner(typed_origin, seed), 'prepare cannot mutate checkpoint snapshot')
  end select
  write(*,'(A)') 'FWOF26_DAY_START_PREPARE_IS_CANDIDATE_LOCAL=PASS'

  call finalize_wofost_one_day_candidate(prepared1, context1, parameters, aggregates1, rates1, &
       candidate1, diagnostics1, status)
  call require(status == WOFOST_ONE_DAY_OK, 'day1 finalize succeeds')
  call require(diagnostics1%candidate_built, 'day1 candidate built')
  call require(abs(diagnostics1%relative_transpiration - 0.6_real64) <= 1.0e-15_real64, 'B1.10 RELTR')
  call require(diagnostics1%anthesis_triggered, 'anthesis threshold triggered')
  call require(same_bits(candidate1%development_stage, 1.0_real64), 'anthesis lands exactly on DVS one')
  call require(same_bits(candidate1%evolution_continuation%temperature_sum, 105.0_real64), 'TSUM updated once')
  call require(candidate1%evolution_continuation%anthesis_reached, 'anthesis persisted in candidate')
  call require(same_bits(candidate1%biomass%root_biomass, 11.0_real64), 'root biomass integrated')
  call require(same_bits(candidate1%biomass%stem_biomass, 18.0_real64), 'stem biomass integrated')
  call require(same_bits(candidate1%biomass%storage_biomass, 30.5_real64), 'storage biomass integrated')
  call require(all_same_bits(candidate1%biomass%leaf_biomass, [1.0_real64, 4.0_real64, 3.0_real64]), &
       'stress and age death then one cohort insert')
  call require(all_same_bits(candidate1%biomass%specific_leaf_area, [0.025_real64, 0.02_real64, 0.03_real64]), &
       'youngest SLA and survivor ordering')
  call require(all_same_bits(candidate1%biomass%leaf_age, [0.0_real64, 0.2_real64, 1.2_real64]), &
       'survivor physiological ageing after daily shift')
  call require(diagnostics1%leaf_cohort_count_before == 3 .and. diagnostics1%leaf_cohort_count_after == 3, &
       'exactly one cohort inserted after one old cohort dies')
  call require(same_bits(candidate1%biomass%exponential_leaf_area_index, 6.1_real64), 'LAIEXP threshold crossed')
  call require(allocated(candidate1%b110_reference_compatibility), 'GLAIEXP carryover sidecar allocated at threshold')
  call require(same_bits(candidate1%b110_reference_compatibility%lai_exponential_rate_carryover, 0.2_real64), &
       'GLAIEXP carryover captured')
  call require(diagnostics1%captured_lai_exponential_carryover, 'GLAIEXP capture diagnosed')
  write(*,'(A)') 'FWOF26_ONE_DAY_STATE_UPDATE_ORDER_AND_ANTHESIS=PASS'
  write(*,'(A)') 'FWOF26_EXACTLY_ONE_DAILY_LEAF_COHORT_SHIFT=PASS'
  write(*,'(A)') 'FWOF26_GLAIEXP_THRESHOLD_CARRYOVER_CAPTURE=PASS'

  bad_rates = rates1
  bad_rates%relative_transpiration_used = 0.5_real64
  call finalize_wofost_one_day_candidate(prepared1, context1, parameters, aggregates1, bad_rates, &
       replay_candidate, replay_diagnostics, status)
  call require(status == WOFOST_ONE_DAY_RELTR_MISMATCH, 'rate packet must bind to accepted aggregates')
  write(*,'(A)') 'FWOF26_ACCEPTED_IQROT_IPTRA_RELTR_BINDING_FAILS_CLOSED=PASS'

  call prepare_wofost_one_day_candidate(candidate1, forcing2, 101.0_real64, 102.0_real64, &
       prepared2, context2, status)
  call require(status == WOFOST_ONE_DAY_OK, 'day2 prepare succeeds')
  call finalize_wofost_one_day_candidate(prepared2, context2, parameters, aggregates2, rates2, &
       candidate2, diagnostics2, status)
  call require(status == WOFOST_ONE_DAY_OK, 'day2 finalize succeeds')
  call require(diagnostics2%used_lai_exponential_carryover, 'day2 uses stored GLAIEXP carryover')
  call require(.not. diagnostics2%captured_lai_exponential_carryover, 'day2 does not recapture GLAIEXP')
  call require(same_bits(candidate2%biomass%exponential_leaf_area_index, 6.3_real64), &
       'day2 LAIEXP uses prior B1.10 rate')
  call require(candidate2%biomass%active_leaf_cohort_count() == 4, 'day2 adds exactly one zero-mass cohort')
  call require(same_bits(candidate2%biomass%leaf_biomass(1), 0.0_real64), &
       'zero leaf growth still creates daily cohort')
  write(*,'(A)') 'FWOF26_GLAIEXP_POST_THRESHOLD_USES_STORED_REFERENCE_MEMORY=PASS'
  write(*,'(A)') 'FWOF26_ZERO_GROWTH_STILL_PRESERVES_DAILY_COHORT_CARDINALITY=PASS'

  missing_prepared = prepared2
  if (allocated(missing_prepared%b110_reference_compatibility)) deallocate(missing_prepared%b110_reference_compatibility)
  missing_context = context2
  call finalize_wofost_one_day_candidate(missing_prepared, missing_context, parameters, aggregates2, rates2, &
       replay_candidate, missing_diagnostics, status)
  call require(status == WOFOST_ONE_DAY_MISSING_GLAIEXP_CARRYOVER, &
       'post-threshold reference path fails closed without carryover')
  write(*,'(A)') 'FWOF26_POST_THRESHOLD_REFERENCE_WITHOUT_CARRYOVER_FAILS_CLOSED=PASS'

  call checkpoint%snapshot(origin2, available)
  call require(available, 'replay checkpoint snapshot available')
  select type (typed_origin => origin2)
  type is (wofost_crop_owner_state_t)
    call require(same_owner(typed_origin, seed), 'checkpoint unchanged after discarded day1 candidate')
    call prepare_wofost_one_day_candidate(typed_origin, forcing1, 100.0_real64, 101.0_real64, &
         replay_prepared, replay_context, status)
  class default
    error stop 'unexpected replay checkpoint dynamic type'
  end select
  call require(status == WOFOST_ONE_DAY_OK, 'replay prepare succeeds')
  call finalize_wofost_one_day_candidate(replay_prepared, replay_context, parameters, aggregates1, rates1, &
       replay_candidate, replay_diagnostics, status)
  call require(status == WOFOST_ONE_DAY_OK, 'replay finalize succeeds')
  call require(same_owner(candidate1, replay_candidate), 'same checkpoint event replays bitwise identical')
  call require(same_diagnostics(diagnostics1, replay_diagnostics), 'replay diagnostics bitwise identical')
  write(*,'(A)') 'FWOF26_FKT_CHECKPOINT_DISCARD_LEAVES_COMMITTED_STATE_UNCHANGED=PASS'
  write(*,'(A)') 'FWOF26_SAME_CHECKPOINT_SAME_EVENT_REPLAY_BITWISE_IDENTITY=PASS'

  call require(candidate2%validate() == WOFOST_CROP_OWNER_OK, 'final candidate owner valid')
  write(*,'(A)') 'FWOF26_ONE_DAY_STRUCTURAL_EVOLUTION_TEST PASS'

contains

  subroutine seed_active_owner(state)
    type(wofost_crop_owner_state_t), intent(out) :: state

    state%crop_emerged = .true.
    state%development_stage = 0.8_real64
    allocate(state%biomass)
    state%biomass%root_biomass = 10.0_real64
    state%biomass%stem_biomass = 20.0_real64
    state%biomass%storage_biomass = 30.0_real64
    state%biomass%exponential_leaf_area_index = 5.9_real64
    state%biomass%leaf_biomass = [4.0_real64, 3.0_real64, 2.0_real64]
    state%biomass%specific_leaf_area = [0.02_real64, 0.03_real64, 0.04_real64]
    state%biomass%leaf_age = [0.0_real64, 1.0_real64, 5.0_real64]
    allocate(wofost_common_evolution_continuation_t :: state%evolution_continuation)
    state%evolution_continuation%temperature_sum = 100.0_real64
    state%evolution_continuation%anthesis_reached = .false.
    state%evolution_continuation%minimum_temperature_history_count = 2
    state%evolution_continuation%minimum_temperature_history = &
         [-1.0_real64, 1.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64]
  end subroutine seed_active_owner

  subroutine seed_inactive_owner(state)
    type(wofost_crop_owner_state_t), intent(out) :: state
    state%crop_emerged = .false.
    state%development_stage = -0.1_real64
  end subroutine seed_inactive_owner

  subroutine configure_forcing(forcing, minimum_temperature)
    type(wofost_one_day_forcing_t), intent(out) :: forcing
    real(real64), intent(in) :: minimum_temperature
    forcing%minimum_temperature = minimum_temperature
    forcing%average_temperature = 12.0_real64
    forcing%daytime_average_temperature = 15.0_real64
    forcing%global_radiation = 1.5e7_real64
    forcing%daylength_hours = 12.0_real64
    forcing%photoperiodic_daylength_hours = 12.5_real64
    forcing%sinld = 0.3_real64
    forcing%cosld = 0.7_real64
    forcing%diffuse_perpendicular_radiation = 100.0_real64
    forcing%daily_sine_solar_elevation_integral = 20000.0_real64
    forcing%co2_efficiency_factor = 1.0_real64
    forcing%co2_amax_factor = 1.0_real64
  end subroutine configure_forcing

  subroutine configure_parameters(value)
    type(wofost_one_day_update_parameters_t), intent(out) :: value
    value%development_stage_end = 2.0_real64
    value%leaf_lifespan = 4.0_real64
  end subroutine configure_parameters

  subroutine configure_day1(aggregates, rates)
    type(wofost_accepted_window_aggregates_t), intent(out) :: aggregates
    type(wofost_one_day_rate_packet_t), intent(out) :: rates
    aggregates%actual_root_uptake = 0.3_real64
    aggregates%potential_transpiration = 0.5_real64
    rates%temperature_sum_increment = 5.0_real64
    rates%development_rate = 0.3_real64
    rates%root_net_growth_rate = 1.0_real64
    rates%stem_net_growth_rate = -2.0_real64
    rates%storage_net_growth_rate = 0.5_real64
    rates%leaf_growth_rate = 1.0_real64
    rates%leaf_stress_death_rate = 0.5_real64
    rates%leaf_age_increment = 0.2_real64
    rates%youngest_specific_leaf_area = 0.025_real64
    rates%lai_exponential_growth_rate = 0.2_real64
    rates%lai_exponential_rate_recomputed = .true.
    rates%relative_transpiration_used = 0.6_real64
  end subroutine configure_day1

  subroutine configure_day2(aggregates, rates)
    type(wofost_accepted_window_aggregates_t), intent(out) :: aggregates
    type(wofost_one_day_rate_packet_t), intent(out) :: rates
    aggregates%actual_root_uptake = 0.0_real64
    aggregates%potential_transpiration = 0.0_real64
    rates%temperature_sum_increment = 4.0_real64
    rates%development_rate = 0.1_real64
    rates%root_net_growth_rate = 0.0_real64
    rates%stem_net_growth_rate = 0.0_real64
    rates%storage_net_growth_rate = 0.0_real64
    rates%leaf_growth_rate = 0.0_real64
    rates%leaf_stress_death_rate = 0.0_real64
    rates%leaf_age_increment = 0.3_real64
    rates%youngest_specific_leaf_area = 0.02_real64
    rates%lai_exponential_growth_rate = 0.0_real64
    rates%lai_exponential_rate_recomputed = .false.
    rates%relative_transpiration_used = 1.0_real64
  end subroutine configure_day2

  logical function same_owner(left, right) result(equal)
    type(wofost_crop_owner_state_t), intent(in) :: left, right
    integer :: i

    equal = .false.
    if (left%crop_emerged .neqv. right%crop_emerged) return
    if (.not. same_bits(left%development_stage, right%development_stage)) return
    if (allocated(left%biomass) .neqv. allocated(right%biomass)) return
    if (allocated(left%evolution_continuation) .neqv. allocated(right%evolution_continuation)) return
    if (allocated(left%b110_reference_compatibility) .neqv. allocated(right%b110_reference_compatibility)) return
    if (allocated(left%biomass)) then
      if (.not. same_bits(left%biomass%root_biomass, right%biomass%root_biomass)) return
      if (.not. same_bits(left%biomass%stem_biomass, right%biomass%stem_biomass)) return
      if (.not. same_bits(left%biomass%storage_biomass, right%biomass%storage_biomass)) return
      if (.not. same_bits(left%biomass%exponential_leaf_area_index, right%biomass%exponential_leaf_area_index)) return
      if (left%biomass%active_leaf_cohort_count() /= right%biomass%active_leaf_cohort_count()) return
      do i = 1, left%biomass%active_leaf_cohort_count()
        if (.not. same_bits(left%biomass%leaf_biomass(i), right%biomass%leaf_biomass(i))) return
        if (.not. same_bits(left%biomass%specific_leaf_area(i), right%biomass%specific_leaf_area(i))) return
        if (.not. same_bits(left%biomass%leaf_age(i), right%biomass%leaf_age(i))) return
      end do
    end if
    if (allocated(left%evolution_continuation)) then
      if (.not. same_bits(left%evolution_continuation%temperature_sum, &
           right%evolution_continuation%temperature_sum)) return
      if (left%evolution_continuation%anthesis_reached .neqv. &
           right%evolution_continuation%anthesis_reached) return
      if (left%evolution_continuation%minimum_temperature_history_count /= &
           right%evolution_continuation%minimum_temperature_history_count) return
      if (.not. all_same_bits(left%evolution_continuation%minimum_temperature_history, &
           right%evolution_continuation%minimum_temperature_history)) return
    end if
    if (allocated(left%b110_reference_compatibility)) then
      if (.not. same_bits(left%b110_reference_compatibility%lai_exponential_rate_carryover, &
           right%b110_reference_compatibility%lai_exponential_rate_carryover)) return
    end if
    equal = .true.
  end function same_owner

  logical function same_diagnostics(left, right) result(equal)
    type(wofost_one_day_diagnostics_t), intent(in) :: left, right
    equal = left%candidate_built .eqv. right%candidate_built .and. &
         left%anthesis_triggered .eqv. right%anthesis_triggered .and. &
         left%used_lai_exponential_carryover .eqv. right%used_lai_exponential_carryover .and. &
         left%captured_lai_exponential_carryover .eqv. right%captured_lai_exponential_carryover .and. &
         left%leaf_cohort_count_before == right%leaf_cohort_count_before .and. &
         left%leaf_cohort_count_after == right%leaf_cohort_count_after .and. &
         same_bits(left%relative_transpiration, right%relative_transpiration)
  end function same_diagnostics

  logical function all_same_bits(left, right) result(equal)
    real(real64), intent(in) :: left(:), right(:)
    integer :: i
    equal = .false.
    if (size(left) /= size(right)) return
    do i = 1, size(left)
      if (.not. same_bits(left(i), right(i))) return
    end do
    equal = .true.
  end function all_same_bits

  logical function same_bits(left, right) result(equal)
    real(real64), intent(in) :: left, right
    equal = transfer(left, 0_int64) == transfer(right, 0_int64)
  end function same_bits

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(A)') 'FAIL: ' // trim(message)
      error stop 1
    end if
  end subroutine require

end program test_fwof26_one_day_structural_evolution
