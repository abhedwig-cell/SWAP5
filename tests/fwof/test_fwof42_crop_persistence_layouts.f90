program test_fwof42_crop_persistence_layouts
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_wofost_crop_owner_state
  use mod_wofost_one_day_structural_evolution, only: wofost_one_day_forcing_t, &
       wofost_one_day_update_parameters_t, wofost_accepted_window_aggregates_t, &
       wofost_one_day_rate_packet_t, wofost_one_day_window_context_t, wofost_one_day_diagnostics_t, &
       prepare_wofost_one_day_candidate, finalize_wofost_one_day_candidate, WOFOST_ONE_DAY_OK
  use mod_fmr_wofost_crop_transaction
  use mod_fwof40_external_crop_restart_adapter
  implicit none

  character(len=32) :: mode, arg
  character(len=512) :: input_path, output_path
  integer :: layout, ios

  call get_command_argument(1, mode)
  select case (trim(mode))
  case ('direct')
    do layout = 1, 7
      call test_direct_roundtrip(layout)
    end do
    write(*,'(A)') 'FWOF42_DIRECT_PRODUCTION_PERSISTENCE_ALL_LAYOUTS=PASS'
  case ('produce')
    call get_command_argument(2, arg)
    read(arg,*,iostat=ios) layout
    call require(ios == 0 .and. layout >= 1 .and. layout <= 7, 'produce layout argument')
    call get_command_argument(3, output_path)
    call require(len_trim(output_path) > 0, 'produce output path')
    call produce_artifact(layout, trim(output_path))
  case ('consume')
    call get_command_argument(2, arg)
    read(arg,*,iostat=ios) layout
    call require(ios == 0 .and. layout >= 1 .and. layout <= 7, 'consume layout argument')
    call get_command_argument(3, input_path)
    call get_command_argument(4, output_path)
    call require(len_trim(input_path) > 0 .and. len_trim(output_path) > 0, 'consume paths')
    call consume_artifact(layout, trim(input_path), trim(output_path))
  case ('invalid')
    call test_invalid_layouts()
    write(*,'(A)') 'FWOF42_INVALID_LAYOUTS_FAIL_CLOSED=PASS'
  case ('zero_behavior')
    call test_zero_length_canonicalization_behavior()
    write(*,'(A)') 'FWOF42_ZERO_LENGTH_COHORT_CANONICALIZATION_BEHAVIOR_EQUIVALENT=PASS'
  case default
    error stop 'F-WOF42 mode must be direct, produce, consume, invalid or zero_behavior'
  end select

contains

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(A)') 'FAIL: '//trim(message)
      error stop 1
    end if
  end subroutine require

  subroutine build_valid_owner(layout, owner)
    integer, intent(in) :: layout
    type(wofost_crop_owner_state_t), intent(out) :: owner

    owner = wofost_crop_owner_state_t()
    select case (layout)
    case (1)
      owner%crop_emerged = .false.
      owner%development_stage = 0.0_real64
    case (2:7)
      owner%crop_emerged = .true.
      owner%development_stage = 0.4_real64
      allocate(owner%biomass)
      owner%biomass%root_biomass = 101.0_real64 + real(layout, real64)
      owner%biomass%stem_biomass = 81.0_real64 + real(layout, real64)
      owner%biomass%storage_biomass = 11.0_real64 + real(layout, real64)
      owner%biomass%exponential_leaf_area_index = 4.0_real64
      if (layout == 3 .or. layout == 4 .or. layout == 6) then
        owner%biomass%leaf_biomass = [12.0_real64 + real(layout,real64), 7.0_real64]
        owner%biomass%specific_leaf_area = [0.02_real64, 0.03_real64]
        owner%biomass%leaf_age = [0.5_real64, 1.5_real64]
      else if (layout == 7) then
        allocate(owner%biomass%leaf_biomass(0), owner%biomass%specific_leaf_area(0), owner%biomass%leaf_age(0))
      end if
      if (layout == 4 .or. layout == 6 .or. layout == 7) call add_evolution(owner, layout)
      if (layout == 5 .or. layout == 6) then
        owner%biomass%exponential_leaf_area_index = 6.5_real64
        allocate(wofost_b110_reference_compatibility_t :: owner%b110_reference_compatibility)
        owner%b110_reference_compatibility%lai_exponential_rate_carryover = 0.125_real64 + &
             0.01_real64 * real(layout, real64)
      end if
    case default
      error stop 'F-WOF42 unknown valid layout'
    end select
    call require(owner%validate() == WOFOST_CROP_OWNER_OK, 'valid owner construction')
  end subroutine build_valid_owner

  subroutine add_evolution(owner, layout)
    type(wofost_crop_owner_state_t), intent(inout) :: owner
    integer, intent(in) :: layout
    allocate(wofost_common_evolution_continuation_t :: owner%evolution_continuation)
    owner%evolution_continuation%temperature_sum = 120.0_real64 + real(layout,real64)
    owner%evolution_continuation%anthesis_reached = .false.
    owner%evolution_continuation%minimum_temperature_history_count = 3
    owner%evolution_continuation%minimum_temperature_history = &
         [-2.0_real64, -1.0_real64, 1.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64]
  end subroutine add_evolution

  subroutine canonical_external_owner(layout, owner)
    integer, intent(in) :: layout
    type(wofost_crop_owner_state_t), intent(out) :: owner
    call build_valid_owner(layout, owner)
    if (layout == 7) then
      if (allocated(owner%biomass%leaf_biomass)) deallocate(owner%biomass%leaf_biomass)
      if (allocated(owner%biomass%specific_leaf_area)) deallocate(owner%biomass%specific_leaf_area)
      if (allocated(owner%biomass%leaf_age)) deallocate(owner%biomass%leaf_age)
    end if
  end subroutine canonical_external_owner

  subroutine test_direct_roundtrip(layout)
    integer, intent(in) :: layout
    type(wofost_crop_owner_state_t) :: owner, restored_owner
    type(fmr_wofost_crop_transaction_state_t) :: state, restored
    type(fmr_wofost_crop_transaction_persistence_t) :: view
    logical :: exported, reconstructed, available
    integer :: status

    call build_valid_owner(layout, owner)
    call initialize_fmr_wofost_crop_transaction_state(owner, state, status)
    call require(status == FMR_WOF38_OK, 'direct initialize state')
    call require(state%ready(), 'direct initialized state ready')
    call export_fmr_wofost_crop_transaction_persistence(state, view, exported, status)
    call require(exported, 'direct persistence export flag')
    call require(status == FMR_WOFOST_CROP_PERSISTENCE_OK, 'direct persistence export status')
    call require(view%ready(), 'direct persistence view ready')
    call require(.not. view%receipt_present, 'direct initial state has no receipt')
    call reconstruct_fmr_wofost_crop_transaction_from_persistence(view, restored, reconstructed, status)
    call require(reconstructed, 'direct persistence reconstruction flag')
    call require(status == FMR_WOFOST_CROP_PERSISTENCE_OK, 'direct persistence reconstruction status')
    call require(restored%ready(), 'direct reconstructed state ready')
    call restored%snapshot_owner(restored_owner, available)
    call require(available, 'direct restored owner available')
    call require(same_owner_exact(owner, restored_owner), 'direct owner exact including allocation presence')
    write(*,'(A,I0,A)') 'FWOF42_DIRECT_LAYOUT_', layout, '_EXACT=PASS'
  end subroutine test_direct_roundtrip

  subroutine produce_artifact(layout, path)
    integer, intent(in) :: layout
    character(len=*), intent(in) :: path
    type(wofost_crop_owner_state_t) :: owner
    type(fmr_wofost_crop_transaction_state_t) :: state
    type(kernel_committed_state_t) :: committed
    class(transaction_state_t), allocatable :: physical
    logical :: initialized, written
    integer :: status

    call build_valid_owner(layout, owner)
    call initialize_fmr_wofost_crop_transaction_state(owner, state, status)
    call require(status == FMR_WOF38_OK, 'producer initialize transaction')
    allocate(fmr_wofost_crop_transaction_state_t :: physical)
    select type (typed => physical)
    type is (fmr_wofost_crop_transaction_state_t)
      typed = state
    class default
      error stop 'F-WOF42 producer physical allocation type'
    end select
    call committed%initialize(42000_int64 + int(layout,int64), physical, initialized, &
         300.0_real64 + real(layout,real64))
    call require(initialized, 'producer committed initialize')
    call write_fwof40_crop_restart_artifact(path, committed, written, status)
    call require(written, 'producer artifact written')
    call require(status == FWO40_EXTERNAL_OK, 'producer artifact status')
    write(*,'(A,I0,A)') 'FWOF42_PRODUCER_LAYOUT_', layout, '=PASS'
  end subroutine produce_artifact

  subroutine consume_artifact(layout, input_path, output_path)
    integer, intent(in) :: layout
    character(len=*), intent(in) :: input_path, output_path
    type(kernel_committed_state_t) :: committed
    class(transaction_state_t), allocatable :: physical
    type(wofost_crop_owner_state_t) :: expected, restored_owner
    logical :: restored, available, written
    integer :: status

    call read_fwof40_crop_restart_artifact(input_path, committed, restored, status)
    call require(restored, 'consumer restored flag')
    call require(status == FWO40_EXTERNAL_OK, 'consumer restored status')
    call require(committed%ready(), 'consumer committed ready')
    call require(committed%current_lineage_id() == 42000_int64 + int(layout,int64), 'consumer lineage')
    call require(committed%current_revision() == 0_int64, 'consumer revision zero')
    call committed%snapshot(physical, available)
    call require(available, 'consumer physical snapshot')
    select type (tx => physical)
    type is (fmr_wofost_crop_transaction_state_t)
      call tx%snapshot_owner(restored_owner, available)
      call require(available, 'consumer owner snapshot')
    class default
      error stop 'F-WOF42 consumer transaction state type'
    end select
    call canonical_external_owner(layout, expected)
    call require(same_owner_exact(expected, restored_owner), 'consumer canonical owner exact')
    call write_fwof40_crop_restart_artifact(output_path, committed, written, status)
    call require(written, 'consumer rewrite written')
    call require(status == FWO40_EXTERNAL_OK, 'consumer rewrite status')
    write(*,'(A,I0,A)') 'FWOF42_CONSUMER_LAYOUT_', layout, '=PASS'
  end subroutine consume_artifact

  subroutine test_invalid_layouts()
    integer :: invalid_case, status
    type(wofost_crop_owner_state_t) :: owner
    type(fmr_wofost_crop_transaction_state_t) :: initialized_state, reconstructed_state
    type(fmr_wofost_crop_transaction_persistence_t) :: view
    logical :: reconstructed

    do invalid_case = 1, 6
      call build_invalid_owner(invalid_case, owner)
      call require(owner%validate() /= WOFOST_CROP_OWNER_OK, 'invalid owner must fail validate')
      call initialize_fmr_wofost_crop_transaction_state(owner, initialized_state, status)
      call require(status /= FMR_WOF38_OK, 'invalid owner rejected by transaction initialize')
      call require(.not. initialized_state%ready(), 'invalid initialize publishes no ready state')

      view = fmr_wofost_crop_transaction_persistence_t()
      view%owner = owner
      view%valid = .true.
      call reconstruct_fmr_wofost_crop_transaction_from_persistence(view, reconstructed_state, reconstructed, status)
      call require(.not. reconstructed, 'invalid persistence reconstruction rejected')
      call require(status /= FMR_WOFOST_CROP_PERSISTENCE_OK, 'invalid persistence status rejected')
      call require(.not. reconstructed_state%ready(), 'invalid reconstruction publishes no ready state')
      write(*,'(A,I0,A)') 'FWOF42_INVALID_LAYOUT_', invalid_case, '_REJECTED=PASS'
    end do
  end subroutine test_invalid_layouts

  subroutine build_invalid_owner(invalid_case, owner)
    integer, intent(in) :: invalid_case
    type(wofost_crop_owner_state_t), intent(out) :: owner

    owner = wofost_crop_owner_state_t()
    select case (invalid_case)
    case (1)
      owner%crop_emerged = .false.
      allocate(owner%biomass)
    case (2)
      owner%crop_emerged = .false.
      allocate(wofost_common_evolution_continuation_t :: owner%evolution_continuation)
    case (3)
      owner%crop_emerged = .false.
      allocate(wofost_b110_reference_compatibility_t :: owner%b110_reference_compatibility)
    case (4)
      owner%crop_emerged = .true.
      owner%development_stage = 0.4_real64
    case (5)
      owner%crop_emerged = .true.
      owner%development_stage = 0.4_real64
      allocate(owner%biomass)
      owner%biomass%root_biomass = 1.0_real64
      owner%biomass%stem_biomass = 1.0_real64
      owner%biomass%storage_biomass = 1.0_real64
      owner%biomass%exponential_leaf_area_index = 5.5_real64
      allocate(wofost_b110_reference_compatibility_t :: owner%b110_reference_compatibility)
      owner%b110_reference_compatibility%lai_exponential_rate_carryover = 0.2_real64
    case (6)
      owner%crop_emerged = .true.
      owner%development_stage = 0.4_real64
      allocate(owner%biomass)
      owner%biomass%root_biomass = 1.0_real64
      owner%biomass%stem_biomass = 1.0_real64
      owner%biomass%storage_biomass = 1.0_real64
      owner%biomass%exponential_leaf_area_index = 4.0_real64
      owner%biomass%leaf_biomass = [1.0_real64]
    case default
      error stop 'F-WOF42 unknown invalid layout'
    end select
  end subroutine build_invalid_owner

  subroutine test_zero_length_canonicalization_behavior()
    type(wofost_crop_owner_state_t) :: allocated_zero, canonical_zero
    type(wofost_crop_owner_state_t) :: prepared_a, prepared_b, final_a, final_b
    type(wofost_one_day_forcing_t) :: forcing
    type(wofost_one_day_update_parameters_t) :: parameters
    type(wofost_accepted_window_aggregates_t) :: aggregates
    type(wofost_one_day_rate_packet_t) :: rates
    type(wofost_one_day_window_context_t) :: context_a, context_b
    type(wofost_one_day_diagnostics_t) :: diagnostics_a, diagnostics_b
    integer :: status_a, status_b

    call build_valid_owner(7, allocated_zero)
    call canonical_external_owner(7, canonical_zero)
    call require(allocated(allocated_zero%biomass%leaf_biomass), 'zero edge original leaf allocation')
    call require(size(allocated_zero%biomass%leaf_biomass) == 0, 'zero edge original leaf size')
    call require(.not. allocated(canonical_zero%biomass%leaf_biomass), 'zero edge canonical leaf absence')
    call require(allocated_zero%biomass%active_leaf_cohort_count() == 0, 'zero edge original cohort count')
    call require(canonical_zero%biomass%active_leaf_cohort_count() == 0, 'zero edge canonical cohort count')
    call require(same_real_bits(allocated_zero%biomass%living_leaf_biomass(), &
         canonical_zero%biomass%living_leaf_biomass()), 'zero edge living leaf biomass equivalent')
    call require(same_real_bits(allocated_zero%biomass%leaf_area_sum(), &
         canonical_zero%biomass%leaf_area_sum()), 'zero edge leaf area equivalent')

    call configure_forcing(forcing)
    call prepare_wofost_one_day_candidate(allocated_zero, forcing, 10.0_real64, 11.0_real64, &
         prepared_a, context_a, status_a)
    call prepare_wofost_one_day_candidate(canonical_zero, forcing, 10.0_real64, 11.0_real64, &
         prepared_b, context_b, status_b)
    call require(status_a == WOFOST_ONE_DAY_OK .and. status_b == WOFOST_ONE_DAY_OK, 'zero edge prepare statuses')

    parameters%development_stage_end = 2.0_real64
    parameters%leaf_lifespan = 10.0_real64
    aggregates%actual_root_uptake = 1.0_real64
    aggregates%potential_transpiration = 1.0_real64
    rates%temperature_sum_increment = 5.0_real64
    rates%development_rate = 0.01_real64
    rates%root_net_growth_rate = 0.0_real64
    rates%stem_net_growth_rate = 0.0_real64
    rates%storage_net_growth_rate = 0.0_real64
    rates%leaf_growth_rate = 2.0_real64
    rates%leaf_stress_death_rate = 0.0_real64
    rates%leaf_age_increment = 1.0_real64
    rates%youngest_specific_leaf_area = 0.02_real64
    rates%lai_exponential_growth_rate = 0.1_real64
    rates%lai_exponential_rate_recomputed = .true.
    rates%relative_transpiration_used = 1.0_real64

    call finalize_wofost_one_day_candidate(prepared_a, context_a, parameters, aggregates, rates, &
         final_a, diagnostics_a, status_a)
    call finalize_wofost_one_day_candidate(prepared_b, context_b, parameters, aggregates, rates, &
         final_b, diagnostics_b, status_b)
    call require(status_a == WOFOST_ONE_DAY_OK .and. status_b == WOFOST_ONE_DAY_OK, 'zero edge finalize statuses')
    call require(same_owner_exact(final_a, final_b), 'zero edge subsequent structural evolution exact')
    call require(diagnostics_a%leaf_cohort_count_before == diagnostics_b%leaf_cohort_count_before, &
         'zero edge diagnostics before')
    call require(diagnostics_a%leaf_cohort_count_after == diagnostics_b%leaf_cohort_count_after, &
         'zero edge diagnostics after')
  end subroutine test_zero_length_canonicalization_behavior

  subroutine configure_forcing(forcing)
    type(wofost_one_day_forcing_t), intent(out) :: forcing
    forcing = wofost_one_day_forcing_t()
    forcing%minimum_temperature = -2.0_real64
    forcing%average_temperature = 20.0_real64
    forcing%daytime_average_temperature = 20.0_real64
    forcing%global_radiation = 2000000.0_real64
    forcing%daylength_hours = 12.0_real64
    forcing%photoperiodic_daylength_hours = 12.0_real64
    forcing%sinld = 0.4_real64
    forcing%cosld = 0.5_real64
    forcing%diffuse_perpendicular_radiation = 10.0_real64
    forcing%daily_sine_solar_elevation_integral = 30000.0_real64
    forcing%co2_efficiency_factor = 1.1_real64
    forcing%co2_amax_factor = 1.05_real64
  end subroutine configure_forcing

  pure logical function same_real_bits(left, right) result(same)
    real(real64), intent(in) :: left, right
    same = transfer(left, 0_int64) == transfer(right, 0_int64)
  end function same_real_bits

  pure logical function same_real_vector_bits(left, right) result(same)
    real(real64), intent(in) :: left(:), right(:)
    integer :: i
    same = .false.
    if (size(left) /= size(right)) return
    do i = 1, size(left)
      if (.not. same_real_bits(left(i), right(i))) return
    end do
    same = .true.
  end function same_real_vector_bits

  logical function same_owner_exact(left, right) result(same)
    type(wofost_crop_owner_state_t), intent(in) :: left, right
    same = .false.
    if (left%crop_emerged .neqv. right%crop_emerged) return
    if (.not. same_real_bits(left%development_stage, right%development_stage)) return
    if (allocated(left%biomass) .neqv. allocated(right%biomass)) return
    if (allocated(left%evolution_continuation) .neqv. allocated(right%evolution_continuation)) return
    if (allocated(left%b110_reference_compatibility) .neqv. allocated(right%b110_reference_compatibility)) return
    if (allocated(left%biomass)) then
      if (.not. same_real_bits(left%biomass%root_biomass, right%biomass%root_biomass)) return
      if (.not. same_real_bits(left%biomass%stem_biomass, right%biomass%stem_biomass)) return
      if (.not. same_real_bits(left%biomass%storage_biomass, right%biomass%storage_biomass)) return
      if (.not. same_real_bits(left%biomass%exponential_leaf_area_index, &
          right%biomass%exponential_leaf_area_index)) return
      if (allocated(left%biomass%leaf_biomass) .neqv. allocated(right%biomass%leaf_biomass)) return
      if (allocated(left%biomass%specific_leaf_area) .neqv. allocated(right%biomass%specific_leaf_area)) return
      if (allocated(left%biomass%leaf_age) .neqv. allocated(right%biomass%leaf_age)) return
      if (allocated(left%biomass%leaf_biomass)) then
        if (size(left%biomass%leaf_biomass) /= size(right%biomass%leaf_biomass)) return
        if (.not. same_real_vector_bits(left%biomass%leaf_biomass, right%biomass%leaf_biomass)) return
        if (.not. same_real_vector_bits(left%biomass%specific_leaf_area, right%biomass%specific_leaf_area)) return
        if (.not. same_real_vector_bits(left%biomass%leaf_age, right%biomass%leaf_age)) return
      end if
    end if
    if (allocated(left%evolution_continuation)) then
      if (.not. same_real_bits(left%evolution_continuation%temperature_sum, &
          right%evolution_continuation%temperature_sum)) return
      if (left%evolution_continuation%anthesis_reached .neqv. right%evolution_continuation%anthesis_reached) return
      if (left%evolution_continuation%minimum_temperature_history_count /= &
          right%evolution_continuation%minimum_temperature_history_count) return
      if (.not. same_real_vector_bits(left%evolution_continuation%minimum_temperature_history, &
          right%evolution_continuation%minimum_temperature_history)) return
    end if
    if (allocated(left%b110_reference_compatibility)) then
      if (.not. same_real_bits(left%b110_reference_compatibility%lai_exponential_rate_carryover, &
          right%b110_reference_compatibility%lai_exponential_rate_carryover)) return
    end if
    same = .true.
  end function same_owner_exact

end program test_fwof42_crop_persistence_layouts
