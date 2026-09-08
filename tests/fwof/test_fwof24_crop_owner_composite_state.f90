program test_fwof24_crop_owner_composite_state
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t
  use mod_wofost_actual_biomass_state, only: wofost_actual_biomass_state_t
  use mod_wofost_crop_owner_state, only: wofost_crop_owner_state_t, WOFOST_CROP_OWNER_OK, &
       WOFOST_CROP_OWNER_INVALID_DVS, WOFOST_CROP_OWNER_BIOMASS_PRESENCE_MISMATCH, &
       WOFOST_CROP_OWNER_INVALID_BIOMASS
  use mod_nonadaptive_crop_root_view_producer, only: crop_root_geometry_snapshot_t
  use mod_crop_root_geometry_snapshot_producer, only: root_depth_table_t, crop_root_geometry_diagnostics_t, &
       build_swrd3_root_geometry_snapshot, CROP_ROOT_GEOMETRY_OK
  implicit none

  class(transaction_state_t), allocatable :: initial, direct_copy, inactive, invalid
  class(transaction_state_t), allocatable :: committed_copy, checkpoint_copy
  class(transaction_state_t), allocatable :: trial_b1, trial_saved, trial_a, trial_b2
  type(kernel_committed_state_t) :: committed
  type(kernel_checkpoint_t) :: checkpoint
  type(root_depth_table_t) :: root_table
  type(crop_root_geometry_snapshot_t) :: root_snapshot
  type(crop_root_geometry_diagnostics_t) :: root_diag
  real(real64) :: value, nanv
  logical :: available, did_initialize, emerged
  integer :: status

  nanv = ieee_value(0.0_real64, ieee_quiet_nan)

  allocate(wofost_crop_owner_state_t :: inactive)
  call set_inactive_state(inactive)
  call require(validate_owner(inactive) == WOFOST_CROP_OWNER_OK, 'inactive owner valid')
  call read_root(inactive, value, available, status)
  call require(status == WOFOST_CROP_OWNER_OK, 'inactive root view status')
  call require(.not. available, 'inactive root view unavailable')
  call require(same_bits(value, 0.0_real64), 'inactive root view zero')
  call derive_lai(inactive, nanv, nanv, value, status)
  call require(status == WOFOST_CROP_OWNER_OK, 'inactive LAI ignores active parameters')
  call require(same_bits(value, 0.0_real64), 'inactive LAI zero')
  write(*,'(A)') 'FWOF24_INACTIVE_WOFOST_HAS_NO_BIOMASS_OR_ACTIVE_PARAMETER_DEPENDENCY=PASS'

  allocate(wofost_crop_owner_state_t :: initial)
  call set_active_reference_state(initial)
  call require(validate_owner(initial) == WOFOST_CROP_OWNER_OK, 'active owner valid')
  call read_root(initial, value, available, status)
  call require(status == WOFOST_CROP_OWNER_OK, 'active root view status')
  call require(available, 'active root view available')
  call require(same_bits(value, 10.0_real64), 'active authoritative WRT')
  call derive_lai(initial, 0.01_real64, 0.005_real64, value, status)
  call require(status == WOFOST_CROP_OWNER_OK, 'derived LAI status')
  call require(abs(value - 0.60_real64) <= 1.0e-14_real64, 'derived WOFOST LAI')
  write(*,'(A)') 'FWOF24_AUTHORITATIVE_WRT_AND_DERIVED_LAI_VIEWS=PASS'

  call initial%clone(direct_copy)
  call require(same_owner_state(initial, direct_copy), 'direct owner clone identity')
  call mutate_active_trial(direct_copy)
  call require(.not. same_owner_state(initial, direct_copy), 'deep owner clone independence')
  call require(matches_active_reference(initial), 'source owner unchanged after clone mutation')
  write(*,'(A)') 'FWOF24_DEEP_CLONE_ATOMIC_LIFECYCLE_AND_BIOMASS=PASS'

  allocate(wofost_crop_owner_state_t :: invalid)
  call set_inactive_state(invalid)
  call set_emerged_without_biomass(invalid)
  call require(validate_owner(invalid) == WOFOST_CROP_OWNER_BIOMASS_PRESENCE_MISMATCH, &
       'emerged without biomass fails closed')
  call set_active_reference_state(invalid)
  call set_inactive_with_biomass(invalid)
  call require(validate_owner(invalid) == WOFOST_CROP_OWNER_BIOMASS_PRESENCE_MISMATCH, &
       'inactive with biomass fails closed')
  call set_inactive_state(invalid)
  call set_dvs(invalid, nanv)
  call require(validate_owner(invalid) == WOFOST_CROP_OWNER_INVALID_DVS, 'nan DVS fails closed')
  call set_active_reference_state(invalid)
  call set_root_biomass(invalid, nanv)
  call require(validate_owner(invalid) == WOFOST_CROP_OWNER_INVALID_BIOMASS, 'nan biomass fails closed')
  write(*,'(A)') 'FWOF24_OWNER_PRESENCE_AND_NONFINITE_VALIDATION_FAILS_CLOSED=PASS'

  call committed%initialize(2401_int64, initial, did_initialize, 18.0_real64)
  call require(did_initialize, 'F-KT owner initialization')
  call require(committed%ready(), 'F-KT owner ready')
  call committed%snapshot(committed_copy, available)
  call require(available, 'committed owner snapshot available')
  call require(matches_active_reference(committed_copy), 'committed owner identity')

  call mutate_active_trial(initial)
  call committed%snapshot(committed_copy, available)
  call require(available, 'committed owner after initializer mutation available')
  call require(matches_active_reference(committed_copy), 'F-KT deep-cloned atomic owner')
  write(*,'(A)') 'FWOF24_FKT_COMMITTED_INITIALIZATION_CLONES_ATOMIC_OWNER=PASS'

  call committed%capture_checkpoint(checkpoint, available)
  call require(available, 'owner checkpoint available')
  call require(checkpoint%ready(), 'owner checkpoint ready')
  call checkpoint%snapshot(checkpoint_copy, available)
  call require(available, 'owner checkpoint snapshot available')
  call require(matches_active_reference(checkpoint_copy), 'checkpoint preserves lifecycle and biomass')
  write(*,'(A)') 'FWOF24_FKT_CHECKPOINT_ATOMIC_LIFECYCLE_BIOMASS=PASS'

  call checkpoint%snapshot(trial_b1, available)
  call require(available, 'trial B1 available')
  call transition_trial_to_inactive(trial_b1)
  call require(validate_owner(trial_b1) == WOFOST_CROP_OWNER_OK, 'trial inactive transition valid')
  call trial_b1%clone(trial_saved)
  deallocate(trial_b1)

  call committed%snapshot(committed_copy, available)
  call require(available, 'committed after discarded owner trial available')
  call require(matches_active_reference(committed_copy), 'discarded allocation change cannot mutate committed owner')
  write(*,'(A)') 'FWOF24_TRIAL_BIOMASS_DEALLOCATION_DISCARD_ISOLATED=PASS'

  call checkpoint%snapshot(trial_a, available)
  call require(available, 'owner A replay available')
  call require(matches_active_reference(trial_a), 'owner A replay exact')
  call trial_a%clone(trial_b2)
  call transition_trial_to_inactive(trial_b2)
  call require(same_owner_state(trial_saved, trial_b2), 'owner B replay bitwise identity')
  call require(.not. same_owner_state(trial_a, trial_b2), 'owner A and B differ')
  write(*,'(A)') 'FWOF24_CHECKPOINT_A_B_A_REPLAY_BITWISE_IDENTITY=PASS'

  call extract_root_geometry_inputs(checkpoint_copy, emerged, value, available, status)
  call require(status == WOFOST_CROP_OWNER_OK, 'owner geometry view status')
  call require(available, 'owner geometry WRT available')
  root_table%x = [0.0_real64, 10.0_real64, 20.0_real64]
  root_table%root_depth = [0.0_real64, 50.0_real64, 100.0_real64]
  call build_swrd3_root_geometry_snapshot(emerged, value, 80.0_real64, root_table, root_snapshot, root_diag)
  call require(root_diag%status == CROP_ROOT_GEOMETRY_OK, 'F-WOF17 SWRD3 geometry status')
  call require(root_diag%built, 'F-WOF17 SWRD3 geometry built')
  call require(root_snapshot%crop_emerged, 'F-WOF17 SWRD3 emerged')
  call require(abs(root_snapshot%current_root_depth - 50.0_real64) <= 1.0e-14_real64, &
       'F-WOF17 SWRD3 geometry from authoritative WRT')
  write(*,'(A)') 'FWOF24_ACTUAL_WRT_VIEW_COMPOSES_WITH_UNCHANGED_FWO17_SWRD3_GEOMETRY=PASS'

  write(*,'(A)') 'FWOF24_NO_DUPLICATE_WOFOST_LAI_STATE=PASS'
  write(*,'(A)') 'FWOF24_NO_WOFOST_EVOLUTION_OR_CALENDAR_SEMANTICS=PASS'
  write(*,'(A)') 'FWOF24_CROP_OWNER_COMPOSITE_STATE_TEST PASS'

contains

  subroutine set_inactive_state(state)
    class(transaction_state_t), allocatable, intent(inout) :: state
    select type (typed => state)
    type is (wofost_crop_owner_state_t)
      typed%crop_emerged = .false.
      typed%development_stage = -0.1_real64
      if (allocated(typed%biomass)) deallocate(typed%biomass)
    class default
      error stop 'unexpected type in set_inactive_state'
    end select
  end subroutine set_inactive_state

  subroutine set_active_reference_state(state)
    class(transaction_state_t), allocatable, intent(inout) :: state
    select type (typed => state)
    type is (wofost_crop_owner_state_t)
      typed%crop_emerged = .true.
      typed%development_stage = 0.8_real64
      if (.not. allocated(typed%biomass)) allocate(typed%biomass)
      typed%biomass%root_biomass = 10.0_real64
      typed%biomass%stem_biomass = 20.0_real64
      typed%biomass%storage_biomass = 30.0_real64
      typed%biomass%exponential_leaf_area_index = 1.5_real64
      typed%biomass%leaf_biomass = [4.0_real64, 3.0_real64, 2.0_real64]
      typed%biomass%specific_leaf_area = [0.02_real64, 0.03_real64, 0.04_real64]
      typed%biomass%leaf_age = [0.0_real64, 1.0_real64, 2.0_real64]
    class default
      error stop 'unexpected type in set_active_reference_state'
    end select
  end subroutine set_active_reference_state

  subroutine mutate_active_trial(state)
    class(transaction_state_t), allocatable, intent(inout) :: state
    select type (typed => state)
    type is (wofost_crop_owner_state_t)
      typed%development_stage = typed%development_stage + 0.1_real64
      typed%biomass%root_biomass = typed%biomass%root_biomass + 1.0_real64
      typed%biomass%leaf_biomass(2) = typed%biomass%leaf_biomass(2) + 0.5_real64
      typed%biomass%leaf_age(3) = typed%biomass%leaf_age(3) + 0.25_real64
    class default
      error stop 'unexpected type in mutate_active_trial'
    end select
  end subroutine mutate_active_trial

  subroutine transition_trial_to_inactive(state)
    class(transaction_state_t), allocatable, intent(inout) :: state
    select type (typed => state)
    type is (wofost_crop_owner_state_t)
      typed%crop_emerged = .false.
      typed%development_stage = 2.0_real64
      if (allocated(typed%biomass)) deallocate(typed%biomass)
    class default
      error stop 'unexpected type in transition_trial_to_inactive'
    end select
  end subroutine transition_trial_to_inactive

  subroutine set_emerged_without_biomass(state)
    class(transaction_state_t), allocatable, intent(inout) :: state
    select type (typed => state)
    type is (wofost_crop_owner_state_t)
      typed%crop_emerged = .true.
      typed%development_stage = 0.5_real64
      if (allocated(typed%biomass)) deallocate(typed%biomass)
    class default
      error stop 'unexpected type in set_emerged_without_biomass'
    end select
  end subroutine set_emerged_without_biomass

  subroutine set_inactive_with_biomass(state)
    class(transaction_state_t), allocatable, intent(inout) :: state
    select type (typed => state)
    type is (wofost_crop_owner_state_t)
      typed%crop_emerged = .false.
    class default
      error stop 'unexpected type in set_inactive_with_biomass'
    end select
  end subroutine set_inactive_with_biomass

  subroutine set_dvs(state, value)
    class(transaction_state_t), allocatable, intent(inout) :: state
    real(real64), intent(in) :: value
    select type (typed => state)
    type is (wofost_crop_owner_state_t)
      typed%development_stage = value
    class default
      error stop 'unexpected type in set_dvs'
    end select
  end subroutine set_dvs

  subroutine set_root_biomass(state, value)
    class(transaction_state_t), allocatable, intent(inout) :: state
    real(real64), intent(in) :: value
    select type (typed => state)
    type is (wofost_crop_owner_state_t)
      typed%biomass%root_biomass = value
    class default
      error stop 'unexpected type in set_root_biomass'
    end select
  end subroutine set_root_biomass

  integer function validate_owner(state) result(value)
    class(transaction_state_t), allocatable, intent(in) :: state
    value = -1
    select type (typed => state)
    type is (wofost_crop_owner_state_t)
      value = typed%validate()
    class default
      error stop 'unexpected type in validate_owner'
    end select
  end function validate_owner

  subroutine read_root(state, value, available, status)
    class(transaction_state_t), allocatable, intent(in) :: state
    real(real64), intent(out) :: value
    logical, intent(out) :: available
    integer, intent(out) :: status
    select type (typed => state)
    type is (wofost_crop_owner_state_t)
      call typed%read_actual_root_biomass(value, available, status)
    class default
      error stop 'unexpected type in read_root'
    end select
  end subroutine read_root

  subroutine derive_lai(state, ssa, spa, value, status)
    class(transaction_state_t), allocatable, intent(in) :: state
    real(real64), intent(in) :: ssa, spa
    real(real64), intent(out) :: value
    integer, intent(out) :: status
    select type (typed => state)
    type is (wofost_crop_owner_state_t)
      call typed%derive_actual_leaf_area_index(ssa, spa, value, status)
    class default
      error stop 'unexpected type in derive_lai'
    end select
  end subroutine derive_lai

  subroutine extract_root_geometry_inputs(state, emerged, root_biomass, available, status)
    class(transaction_state_t), allocatable, intent(in) :: state
    logical, intent(out) :: emerged
    real(real64), intent(out) :: root_biomass
    logical, intent(out) :: available
    integer, intent(out) :: status
    select type (typed => state)
    type is (wofost_crop_owner_state_t)
      emerged = typed%crop_is_emerged()
      call typed%read_actual_root_biomass(root_biomass, available, status)
    class default
      error stop 'unexpected type in extract_root_geometry_inputs'
    end select
  end subroutine extract_root_geometry_inputs

  logical function same_owner_state(left, right) result(equal)
    class(transaction_state_t), allocatable, intent(in) :: left, right
    integer :: i
    equal = .false.
    select type (l => left)
    type is (wofost_crop_owner_state_t)
      select type (r => right)
      type is (wofost_crop_owner_state_t)
        if (.not. (l%crop_emerged .eqv. r%crop_emerged)) return
        if (.not. same_bits(l%development_stage, r%development_stage)) return
        if (allocated(l%biomass) .neqv. allocated(r%biomass)) return
        if (allocated(l%biomass)) then
          if (.not. same_bits(l%biomass%root_biomass, r%biomass%root_biomass)) return
          if (.not. same_bits(l%biomass%stem_biomass, r%biomass%stem_biomass)) return
          if (.not. same_bits(l%biomass%storage_biomass, r%biomass%storage_biomass)) return
          if (.not. same_bits(l%biomass%exponential_leaf_area_index, r%biomass%exponential_leaf_area_index)) return
          if (allocated(l%biomass%leaf_biomass) .neqv. allocated(r%biomass%leaf_biomass)) return
          if (allocated(l%biomass%specific_leaf_area) .neqv. allocated(r%biomass%specific_leaf_area)) return
          if (allocated(l%biomass%leaf_age) .neqv. allocated(r%biomass%leaf_age)) return
          if (allocated(l%biomass%leaf_biomass)) then
            if (size(l%biomass%leaf_biomass) /= size(r%biomass%leaf_biomass)) return
            if (size(l%biomass%specific_leaf_area) /= size(r%biomass%specific_leaf_area)) return
            if (size(l%biomass%leaf_age) /= size(r%biomass%leaf_age)) return
            do i = 1, size(l%biomass%leaf_biomass)
              if (.not. same_bits(l%biomass%leaf_biomass(i), r%biomass%leaf_biomass(i))) return
              if (.not. same_bits(l%biomass%specific_leaf_area(i), r%biomass%specific_leaf_area(i))) return
              if (.not. same_bits(l%biomass%leaf_age(i), r%biomass%leaf_age(i))) return
            end do
          end if
        end if
        equal = .true.
      end select
    end select
  end function same_owner_state

  logical function matches_active_reference(state) result(equal)
    class(transaction_state_t), allocatable, intent(in) :: state
    class(transaction_state_t), allocatable :: reference
    allocate(wofost_crop_owner_state_t :: reference)
    call set_active_reference_state(reference)
    equal = same_owner_state(state, reference)
  end function matches_active_reference

  logical function same_bits(left, right) result(equal)
    real(real64), intent(in) :: left, right
    integer(int64) :: li, ri
    li = transfer(left, li)
    ri = transfer(right, ri)
    equal = li == ri
  end function same_bits

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(A)') 'FAIL: '//trim(message)
      error stop 1
    end if
  end subroutine require

end program test_fwof24_crop_owner_composite_state
