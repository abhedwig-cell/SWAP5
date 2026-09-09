program test_fwof33_two_phase_crop_window
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_wofost_crop_owner_state, only: wofost_crop_owner_state_t, &
       wofost_common_evolution_continuation_t
  use mod_wofost_rate_table, only: wofost_rate_table_t, construct_wofost_rate_table, &
       WOFOST_RATE_TABLE_OK
  use mod_wofost_rate_parameters
  use mod_wofost_one_day_structural_evolution
  use mod_wofost_one_day_rate_state_view
  use mod_wofost_prepare_assimilation
  use mod_wofost_finalize_rates
  use mod_wofost_two_phase_crop_window
  implicit none

  type(wofost_crop_owner_state_t) :: seed, seed_before, inactive, prepared_manual
  type(wofost_crop_owner_state_t) :: prepared1, prepared2, candidate1, candidate2, manual_candidate
  type(wofost_crop_owner_state_t) :: failure_candidate, inactive_candidate
  type(wofost_one_day_forcing_t) :: forcing, inactive_bad_forcing
  type(wofost_one_day_window_context_t) :: manual_structural_context
  type(wofost_one_day_rate_state_view_t) :: manual_view
  type(wofost_prepare_assimilation_forcing_t) :: manual_phase_a_forcing
  type(wofost_prepare_assimilation_result_t) :: manual_prepared
  type(wofost_finalize_rate_forcing_t) :: manual_phase_b_forcing
  type(wofost_accepted_window_aggregates_t) :: aggregates, bad_aggregates
  type(wofost_one_day_update_parameters_t) :: update_parameters, bad_update_parameters
  type(wofost_one_day_rate_packet_t) :: rates1, rates2, manual_rates, failure_rates
  type(wofost_one_day_diagnostics_t) :: manual_structural_diagnostics
  type(wofost_rate_parameter_bundle_t) :: bundle, unready_bundle
  type(wofost_two_phase_crop_window_t) :: window1, window2, inactive_window, failed_window
  type(wofost_crop_window_begin_diagnostics_t) :: begin1, begin2, inactive_begin, failed_begin
  type(wofost_crop_window_complete_diagnostics_t) :: complete1, complete2, inactive_complete, failure_complete
  real(real64) :: pgass1, pgass2, nanv
  logical :: available, manual_view_available
  integer :: status, component_status, count_before

  nanv = ieee_value(0.0_real64, ieee_quiet_nan)
  call seed_active_owner(seed)
  seed_before = seed
  call configure_forcing(forcing)
  call make_bundle(bundle)
  aggregates%actual_root_uptake = 3.0_real64
  aggregates%potential_transpiration = 5.0_real64
  update_parameters%development_stage_end = 2.0_real64
  update_parameters%leaf_lifespan = 10.0_real64

  ! New composition begin.
  call begin_wofost_one_day_crop_window(seed, forcing, 100.0_real64, 101.0_real64, &
       0.005_real64, 0.002_real64, bundle, window1, begin1, status)
  call require(status == WOFOST_CROP_WINDOW_OK, 'composition begin status')
  call require(window1%ready(), 'composition window ready')
  call require(window1%crop_active(), 'composition active crop')
  call require(begin1%prepared_candidate_built .and. begin1%rate_state_view_available .and. &
       begin1%phase_a_evaluated, 'all active begin phases evaluated')
  call window1%copy_prepared_candidate(prepared1, available)
  call require(available, 'prepared candidate accessor')
  call window1%read_prepared_actual_pgass(pgass1, available)
  call require(available, 'prepared PGASS accessor')
  call require(same_owner(seed, seed_before), 'begin cannot mutate committed seed')

  ! Manual qualified component chain must be bitwise identical to composition begin.
  call prepare_wofost_one_day_candidate(seed, forcing, 100.0_real64, 101.0_real64, &
       prepared_manual, manual_structural_context, component_status)
  call require(component_status == WOFOST_ONE_DAY_OK, 'manual structural prepare')
  call assemble_wofost_one_day_rate_state_view(prepared_manual, 0.005_real64, 0.002_real64, &
       manual_view, manual_view_available, component_status)
  call require(component_status == WOFOST_RATE_STATE_VIEW_OK .and. manual_view_available, 'manual state view')
  call translate_phase_a_forcing(forcing, manual_structural_context, manual_phase_a_forcing)
  call prepare_wofost_actual_assimilation(manual_view, bundle, manual_phase_a_forcing, &
       manual_prepared, component_status)
  call require(component_status == WOFOST_PREPARE_ASSIMILATION_OK, 'manual phase A')
  call require(same_owner(prepared1, prepared_manual), 'prepared candidate exact component composition')
  call require(bitwise_equal(pgass1, manual_prepared%actual_pgass), 'prepared PGASS exact component composition')
  print '(a)', 'FWOF33_PHASE_A_COMPONENT_ORDER_AND_BITWISE_COMPOSITION=PASS'

  ! Complete the new composition and the same manual component chain.
  count_before = prepared1%biomass%active_leaf_cohort_count()
  call complete_wofost_one_day_crop_window(window1, bundle, update_parameters, aggregates, &
       candidate1, rates1, complete1, status)
  call require(status == WOFOST_CROP_WINDOW_OK, 'composition complete status')
  call require(complete1%phase_b_evaluated .and. complete1%rate_packet_built .and. &
       complete1%candidate_built, 'all active complete phases evaluated')

  manual_phase_b_forcing%average_temperature = forcing%average_temperature
  manual_phase_b_forcing%photoperiodic_daylength_hours = forcing%photoperiodic_daylength_hours
  call finalize_wofost_one_day_rates(manual_view, bundle, manual_prepared, aggregates, &
       manual_phase_b_forcing, manual_rates, component_status)
  call require(component_status == WOFOST_FINALIZE_RATES_OK, 'manual phase B')
  call finalize_wofost_one_day_candidate(prepared_manual, manual_structural_context, &
       update_parameters, aggregates, manual_rates, manual_candidate, &
       manual_structural_diagnostics, component_status)
  call require(component_status == WOFOST_ONE_DAY_OK, 'manual structural finalize')
  call require(same_packet(rates1, manual_rates), 'rate packet exact component composition')
  call require(same_owner(candidate1, manual_candidate), 'candidate exact component composition')
  call require(same_structural_diagnostics(complete1%structural, manual_structural_diagnostics), &
       'structural diagnostics exact component composition')
  call require(candidate1%biomass%active_leaf_cohort_count() == count_before + 1, &
       'exactly one cohort shift/create in one complete call')
  call require(same_owner(seed, seed_before), 'complete cannot mutate committed seed')
  print '(a)', 'FWOF33_PHASE_B_AND_STRUCTURAL_COMPONENT_ORDER_BITWISE_COMPOSITION=PASS'
  print '(a)', 'FWOF33_EXACTLY_ONE_COHORT_SHIFT_PER_COMPLETE=PASS'
  print '(a)', 'FWOF33_BEGIN_AND_COMPLETE_LEAVE_COMMITTED_STATE_UNCHANGED=PASS'

  ! Same committed checkpoint/event must replay through both phases bitwise identically.
  call begin_wofost_one_day_crop_window(seed, forcing, 100.0_real64, 101.0_real64, &
       0.005_real64, 0.002_real64, bundle, window2, begin2, status)
  call require(status == WOFOST_CROP_WINDOW_OK, 'second begin replay')
  call window2%copy_prepared_candidate(prepared2, available)
  call require(available, 'second prepared accessor')
  call window2%read_prepared_actual_pgass(pgass2, available)
  call require(available, 'second PGASS accessor')
  call require(same_owner(prepared1, prepared2), 'begin prepared candidate replay bits')
  call require(bitwise_equal(pgass1, pgass2), 'begin PGASS replay bits')
  call require(same_begin_diagnostics(begin1, begin2), 'begin diagnostics replay bits')
  call complete_wofost_one_day_crop_window(window2, bundle, update_parameters, aggregates, &
       candidate2, rates2, complete2, status)
  call require(status == WOFOST_CROP_WINDOW_OK, 'second complete replay')
  call require(same_owner(candidate1, candidate2), 'complete candidate replay bits')
  call require(same_packet(rates1, rates2), 'complete packet replay bits')
  call require(same_complete_diagnostics(complete1, complete2), 'complete diagnostics replay bits')
  print '(a)', 'FWOF33_SAME_CHECKPOINT_BEGIN_REPLAY_BITWISE_IDENTITY=PASS'
  print '(a)', 'FWOF33_SAME_CONTEXT_COMPLETE_REPLAY_BITWISE_IDENTITY=PASS'

  ! Phase-B failure must not expose a partially advanced candidate and must not damage the context.
  bad_aggregates = aggregates
  bad_aggregates%actual_root_uptake = nanv
  call complete_wofost_one_day_crop_window(window1, bundle, update_parameters, bad_aggregates, &
       failure_candidate, failure_rates, failure_complete, status)
  call require(status == WOFOST_CROP_WINDOW_PHASE_B_ERROR, 'phase-B failure status')
  call require(same_owner(failure_candidate, prepared1), 'phase-B failure returns prepared candidate')
  call require(.not. failure_complete%candidate_built, 'phase-B failure not candidate built')
  call complete_wofost_one_day_crop_window(window1, bundle, update_parameters, aggregates, &
       failure_candidate, failure_rates, failure_complete, status)
  call require(status == WOFOST_CROP_WINDOW_OK, 'context reusable after failed completion')
  call require(same_owner(failure_candidate, candidate1), 'failed completion did not mutate context')
  print '(a)', 'FWOF33_FAILED_PHASE_B_RETURNS_UNADVANCED_PREPARED_CANDIDATE=PASS'
  print '(a)', 'FWOF33_WINDOW_CONTEXT_REUSABLE_AFTER_DISCARDED_COMPLETE=PASS'

  bad_update_parameters = update_parameters
  bad_update_parameters%leaf_lifespan = -1.0_real64
  call complete_wofost_one_day_crop_window(window1, bundle, bad_update_parameters, aggregates, &
       failure_candidate, failure_rates, failure_complete, status)
  call require(status == WOFOST_CROP_WINDOW_STRUCTURAL_FINALIZE_ERROR, 'structural failure status')
  call require(same_owner(failure_candidate, prepared1), 'structural failure returns prepared candidate')
  print '(a)', 'FWOF33_FAILED_STRUCTURAL_FINALIZE_RETURNS_UNADVANCED_PREPARED_CANDIDATE=PASS'

  ! Inactive crop is a true optional no-op: no active forcing/canopy/rate/update/aggregate dependency.
  call seed_inactive_owner(inactive)
  inactive_bad_forcing = forcing
  inactive_bad_forcing%minimum_temperature = nanv
  bad_aggregates%actual_root_uptake = nanv
  bad_aggregates%potential_transpiration = nanv
  bad_update_parameters%development_stage_end = -1.0_real64
  bad_update_parameters%leaf_lifespan = -1.0_real64
  call begin_wofost_one_day_crop_window(inactive, inactive_bad_forcing, 7.0_real64, 8.0_real64, &
       nanv, nanv, unready_bundle, inactive_window, inactive_begin, status)
  call require(status == WOFOST_CROP_WINDOW_OK, 'inactive begin no active dependencies')
  call require(inactive_window%ready() .and. .not. inactive_window%crop_active(), 'inactive window semantics')
  call require(.not. inactive_begin%rate_state_view_available .and. .not. inactive_begin%phase_a_evaluated, &
       'inactive skips state-view and phase A')
  call complete_wofost_one_day_crop_window(inactive_window, unready_bundle, bad_update_parameters, &
       bad_aggregates, inactive_candidate, failure_rates, inactive_complete, status)
  call require(status == WOFOST_CROP_WINDOW_OK, 'inactive complete no active dependencies')
  call require(same_owner(inactive_candidate, inactive), 'inactive complete exact no-op')
  call require(.not. inactive_complete%phase_b_evaluated .and. inactive_complete%candidate_built, &
       'inactive skips phase B but structural no-op candidate built')
  print '(a)', 'FWOF33_INACTIVE_CROP_SKIPS_ALL_ACTIVE_ONLY_DEPENDENCIES=PASS'

  ! Rejected begin has no usable context and leaves source state untouched.
  call begin_wofost_one_day_crop_window(seed, forcing, 100.0_real64, 100.5_real64, &
       0.005_real64, 0.002_real64, bundle, failed_window, failed_begin, status)
  call require(status == WOFOST_CROP_WINDOW_STRUCTURAL_PREPARE_ERROR, 'half-day begin rejected')
  call require(.not. failed_window%ready(), 'failed begin context not ready')
  call require(same_owner(seed, seed_before), 'failed begin cannot mutate source')
  print '(a)', 'FWOF33_ONLY_QUALIFIED_ONE_DAY_EVENT_AND_FAILED_BEGIN_IS_ATOMIC=PASS'

  print '(a)', 'FWOF33_TWO_PHASE_CROP_WINDOW_TEST PASS'

contains

  subroutine seed_active_owner(state)
    type(wofost_crop_owner_state_t), intent(out) :: state
    state%crop_emerged = .true.
    state%development_stage = 0.5_real64
    allocate(state%biomass)
    state%biomass%root_biomass = 1000.0_real64
    state%biomass%stem_biomass = 800.0_real64
    state%biomass%storage_biomass = 100.0_real64
    state%biomass%exponential_leaf_area_index = 4.0_real64
    state%biomass%leaf_biomass = [100.0_real64, 80.0_real64]
    state%biomass%specific_leaf_area = [0.02_real64, 0.03_real64]
    state%biomass%leaf_age = [0.0_real64, 1.0_real64]
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

  subroutine configure_forcing(value)
    type(wofost_one_day_forcing_t), intent(out) :: value
    value%minimum_temperature = -2.0_real64
    value%average_temperature = 20.0_real64
    value%daytime_average_temperature = 20.0_real64
    value%global_radiation = 2000000.0_real64
    value%daylength_hours = 12.0_real64
    value%photoperiodic_daylength_hours = 12.0_real64
    value%sinld = 0.4_real64
    value%cosld = 0.5_real64
    value%diffuse_perpendicular_radiation = 10.0_real64
    value%daily_sine_solar_elevation_integral = 30000.0_real64
    value%co2_efficiency_factor = 1.1_real64
    value%co2_amax_factor = 1.05_real64
  end subroutine configure_forcing

  subroutine make_bundle(b)
    type(wofost_rate_parameter_bundle_t), intent(out) :: b
    type(wofost_rate_scalar_parameters_t) :: s
    type(wofost_rate_parameter_tables_t) :: t
    integer :: st

    s = wofost_rate_scalar_parameters_t()
    s%development_daylength_mode = 1
    s%daylength_upper_hours = 16.0_real64
    s%daylength_lower_hours = 8.0_real64
    s%vegetative_temperature_sum_required = 1000.0_real64
    s%generative_temperature_sum_required = 800.0_real64
    s%diffuse_extinction_coefficient = 0.6_real64
    s%initial_light_use_efficiency = 0.45_real64
    s%co2_to_dry_matter_fraction = 0.4_real64
    s%attainable_yield_multiplier = 0.9_real64
    s%conversion_efficiency_root = 0.7_real64
    s%conversion_efficiency_stem = 0.65_real64
    s%conversion_efficiency_leaf = 0.72_real64
    s%conversion_efficiency_storage = 0.8_real64
    s%respiration_temperature_q10 = 2.0_real64
    s%maintenance_respiration_root = 0.01_real64
    s%maintenance_respiration_leaf = 0.02_real64
    s%maintenance_respiration_stem = 0.015_real64
    s%maintenance_respiration_storage = 0.005_real64
    s%maximum_leaf_relative_death_rate = 0.03_real64
    s%leaf_age_base_temperature = 0.0_real64
    s%maximum_relative_lai_growth_rate = 0.04_real64

    call constant_table(10.0_real64, t%temperature_sum_increment)
    call constant_table(30.0_real64, t%maximum_assimilation)
    call constant_table(1.0_real64, t%daytime_temperature_factor)
    call constant_table(1.0_real64, t%minimum_temperature_factor)
    call constant_table(1.0_real64, t%maintenance_respiration_factor)
    call constant_table(0.2_real64, t%root_partition_fraction)
    call constant_table(0.4_real64, t%leaf_partition_fraction)
    call constant_table(0.4_real64, t%stem_partition_fraction)
    call constant_table(0.2_real64, t%storage_partition_fraction)
    call constant_table(0.01_real64, t%relative_root_death_rate)
    call constant_table(0.01_real64, t%relative_stem_death_rate)
    call constant_table(0.02_real64, t%specific_leaf_area)

    call construct_wofost_rate_parameter_bundle(s, t, b, st)
    call require(st == WOFOST_RATE_PARAMETER_OK, 'test parameter bundle construction')
  end subroutine make_bundle

  subroutine constant_table(value, table)
    real(real64), intent(in) :: value
    type(wofost_rate_table_t), intent(out) :: table
    real(real64) :: x(1), y(1)
    integer :: st
    x = [0.0_real64]
    y = [value]
    call construct_wofost_rate_table(x, y, table, st)
    call require(st == WOFOST_RATE_TABLE_OK, 'constant table construction')
  end subroutine constant_table

  subroutine translate_phase_a_forcing(source, context, target)
    type(wofost_one_day_forcing_t), intent(in) :: source
    type(wofost_one_day_window_context_t), intent(in) :: context
    type(wofost_prepare_assimilation_forcing_t), intent(out) :: target
    target = wofost_prepare_assimilation_forcing_t()
    target%daytime_mean_temperature = source%daytime_average_temperature
    target%global_radiation = source%global_radiation
    target%daylength_hours = source%daylength_hours
    target%sine_solar_height_offset = source%sinld
    target%sine_solar_height_amplitude = source%cosld
    target%diffuse_irradiation_perpendicular = source%diffuse_perpendicular_radiation
    target%daily_effective_solar_height = source%daily_sine_solar_elevation_integral
    target%co2_efficiency_factor = source%co2_efficiency_factor
    target%co2_amax_factor = source%co2_amax_factor
    target%running_minimum_temperature = context%running_minimum_temperature
  end subroutine translate_phase_a_forcing

  logical function same_owner(left, right) result(same)
    type(wofost_crop_owner_state_t), intent(in) :: left, right
    same = .false.
    if (left%crop_emerged .neqv. right%crop_emerged) return
    if (.not. bitwise_equal(left%development_stage, right%development_stage)) return
    if (allocated(left%biomass) .neqv. allocated(right%biomass)) return
    if (allocated(left%evolution_continuation) .neqv. allocated(right%evolution_continuation)) return
    if (allocated(left%b110_reference_compatibility) .neqv. allocated(right%b110_reference_compatibility)) return
    if (allocated(left%biomass)) then
      if (.not. bitwise_equal(left%biomass%root_biomass, right%biomass%root_biomass)) return
      if (.not. bitwise_equal(left%biomass%stem_biomass, right%biomass%stem_biomass)) return
      if (.not. bitwise_equal(left%biomass%storage_biomass, right%biomass%storage_biomass)) return
      if (.not. bitwise_equal(left%biomass%exponential_leaf_area_index, right%biomass%exponential_leaf_area_index)) return
      if (.not. same_real_array(left%biomass%leaf_biomass, right%biomass%leaf_biomass)) return
      if (.not. same_real_array(left%biomass%specific_leaf_area, right%biomass%specific_leaf_area)) return
      if (.not. same_real_array(left%biomass%leaf_age, right%biomass%leaf_age)) return
    end if
    if (allocated(left%evolution_continuation)) then
      if (.not. bitwise_equal(left%evolution_continuation%temperature_sum, &
           right%evolution_continuation%temperature_sum)) return
      if (left%evolution_continuation%anthesis_reached .neqv. &
           right%evolution_continuation%anthesis_reached) return
      if (left%evolution_continuation%minimum_temperature_history_count /= &
           right%evolution_continuation%minimum_temperature_history_count) return
      if (.not. all_bits(left%evolution_continuation%minimum_temperature_history, &
           right%evolution_continuation%minimum_temperature_history)) return
    end if
    if (allocated(left%b110_reference_compatibility)) then
      if (.not. bitwise_equal(left%b110_reference_compatibility%lai_exponential_rate_carryover, &
           right%b110_reference_compatibility%lai_exponential_rate_carryover)) return
    end if
    same = .true.
  end function same_owner

  logical function same_real_array(left, right) result(same)
    real(real64), allocatable, intent(in) :: left(:), right(:)
    same = .false.
    if (allocated(left) .neqv. allocated(right)) return
    if (.not. allocated(left)) then
      same = .true.
      return
    end if
    if (size(left) /= size(right)) return
    same = all_bits(left, right)
  end function same_real_array

  logical function all_bits(left, right) result(same)
    real(real64), intent(in) :: left(:), right(:)
    integer :: i
    same = .false.
    if (size(left) /= size(right)) return
    do i = 1, size(left)
      if (.not. bitwise_equal(left(i), right(i))) return
    end do
    same = .true.
  end function all_bits

  logical function same_packet(left, right) result(same)
    type(wofost_one_day_rate_packet_t), intent(in) :: left, right
    same = bitwise_equal(left%temperature_sum_increment, right%temperature_sum_increment) .and. &
         bitwise_equal(left%development_rate, right%development_rate) .and. &
         bitwise_equal(left%root_net_growth_rate, right%root_net_growth_rate) .and. &
         bitwise_equal(left%stem_net_growth_rate, right%stem_net_growth_rate) .and. &
         bitwise_equal(left%storage_net_growth_rate, right%storage_net_growth_rate) .and. &
         bitwise_equal(left%leaf_growth_rate, right%leaf_growth_rate) .and. &
         bitwise_equal(left%leaf_stress_death_rate, right%leaf_stress_death_rate) .and. &
         bitwise_equal(left%leaf_age_increment, right%leaf_age_increment) .and. &
         bitwise_equal(left%youngest_specific_leaf_area, right%youngest_specific_leaf_area) .and. &
         bitwise_equal(left%lai_exponential_growth_rate, right%lai_exponential_growth_rate) .and. &
         (left%lai_exponential_rate_recomputed .eqv. right%lai_exponential_rate_recomputed) .and. &
         bitwise_equal(left%relative_transpiration_used, right%relative_transpiration_used)
  end function same_packet

  logical function same_structural_diagnostics(left, right) result(same)
    type(wofost_one_day_diagnostics_t), intent(in) :: left, right
    same = (left%candidate_built .eqv. right%candidate_built) .and. &
         (left%anthesis_triggered .eqv. right%anthesis_triggered) .and. &
         (left%used_lai_exponential_carryover .eqv. right%used_lai_exponential_carryover) .and. &
         (left%captured_lai_exponential_carryover .eqv. right%captured_lai_exponential_carryover) .and. &
         left%leaf_cohort_count_before == right%leaf_cohort_count_before .and. &
         left%leaf_cohort_count_after == right%leaf_cohort_count_after .and. &
         bitwise_equal(left%relative_transpiration, right%relative_transpiration)
  end function same_structural_diagnostics

  logical function same_begin_diagnostics(left, right) result(same)
    type(wofost_crop_window_begin_diagnostics_t), intent(in) :: left, right
    same = left%structural_prepare_status == right%structural_prepare_status .and. &
         left%rate_state_view_status == right%rate_state_view_status .and. &
         left%phase_a_status == right%phase_a_status .and. &
         (left%prepared_candidate_built .eqv. right%prepared_candidate_built) .and. &
         (left%crop_active .eqv. right%crop_active) .and. &
         (left%rate_state_view_available .eqv. right%rate_state_view_available) .and. &
         (left%phase_a_evaluated .eqv. right%phase_a_evaluated) .and. &
         bitwise_equal(left%actual_pgass, right%actual_pgass)
  end function same_begin_diagnostics

  logical function same_complete_diagnostics(left, right) result(same)
    type(wofost_crop_window_complete_diagnostics_t), intent(in) :: left, right
    same = left%phase_b_status == right%phase_b_status .and. &
         left%structural_finalize_status == right%structural_finalize_status .and. &
         (left%phase_b_evaluated .eqv. right%phase_b_evaluated) .and. &
         (left%rate_packet_built .eqv. right%rate_packet_built) .and. &
         (left%candidate_built .eqv. right%candidate_built) .and. &
         same_structural_diagnostics(left%structural, right%structural)
  end function same_complete_diagnostics

  logical function bitwise_equal(left, right) result(equal)
    real(real64), intent(in) :: left, right
    equal = transfer(left, 0_int64) == transfer(right, 0_int64)
  end function bitwise_equal

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a)') 'FAIL: '//trim(message)
      error stop 1
    end if
  end subroutine require

end program test_fwof33_two_phase_crop_window
