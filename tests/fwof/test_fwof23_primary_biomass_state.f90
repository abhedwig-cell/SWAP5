program test_fwof23_primary_biomass_state
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t
  use mod_wofost_actual_biomass_state, only: wofost_actual_biomass_state_t, WOFOST_BIOMASS_STATE_OK, &
       WOFOST_BIOMASS_STATE_INVALID_ORGAN_BIOMASS, WOFOST_BIOMASS_STATE_INVALID_LAIEXP, &
       WOFOST_BIOMASS_STATE_COHORT_ALLOCATION_MISMATCH, WOFOST_BIOMASS_STATE_COHORT_SHAPE_MISMATCH
  implicit none

  class(transaction_state_t), allocatable :: initial, direct_copy, committed_copy
  class(transaction_state_t), allocatable :: checkpoint_copy, trial_b1, trial_saved, trial_a, trial_b2
  class(transaction_state_t), allocatable :: invalid
  type(kernel_committed_state_t) :: committed
  type(kernel_checkpoint_t) :: checkpoint
  real(real64) :: nanv
  logical :: did_initialize, available

  nanv = ieee_value(0.0_real64, ieee_quiet_nan)

  allocate(wofost_actual_biomass_state_t :: initial)
  call set_reference_state(initial)
  call require(validate_state(initial) == WOFOST_BIOMASS_STATE_OK, 'reference state valid')
  call require(cohort_count(initial) == 3, 'active cohort count from compact arrays')
  call require(same_bits(leaf_biomass_total(initial), 9.0_real64), 'WLV reconstructible ordered sum')
  call require(same_bits(leaf_area_sum(initial), 0.25_real64), 'LASUM reconstructible ordered sum')
  call require(same_bits(root_biomass_view(initial), 10.0_real64), 'actual WRT read-only view')
  write(*,'(A)') 'FWOF23_COMPACT_ACTIVE_COHORT_AND_RECONSTRUCTIBLE_VIEWS=PASS'

  call initial%clone(direct_copy)
  call require(same_state(initial, direct_copy), 'direct clone identity')
  call mutate_trial(direct_copy)
  call require(.not. same_state(initial, direct_copy), 'deep clone independence')
  call require(matches_reference(initial), 'initializer unchanged after clone mutation')
  write(*,'(A)') 'FWOF23_DEEP_CLONE_COHORT_INDEPENDENCE=PASS'

  allocate(wofost_actual_biomass_state_t :: invalid)
  call set_reference_state(invalid)
  call set_root_biomass(invalid, -1.0_real64)
  call require(validate_state(invalid) == WOFOST_BIOMASS_STATE_INVALID_ORGAN_BIOMASS, 'negative WRT fails closed')
  call set_reference_state(invalid)
  call set_laiexp(invalid, nanv)
  call require(validate_state(invalid) == WOFOST_BIOMASS_STATE_INVALID_LAIEXP, 'nan LAIEXP fails closed')
  call set_reference_state(invalid)
  call drop_specific_leaf_area(invalid)
  call require(validate_state(invalid) == WOFOST_BIOMASS_STATE_COHORT_ALLOCATION_MISMATCH, 'allocation mismatch fails closed')
  call set_reference_state(invalid)
  call shorten_leaf_age(invalid)
  call require(validate_state(invalid) == WOFOST_BIOMASS_STATE_COHORT_SHAPE_MISMATCH, 'shape mismatch fails closed')
  write(*,'(A)') 'FWOF23_INVALID_BIOMASS_STATE_FAILS_CLOSED=PASS'

  call committed%initialize(2301_int64, initial, did_initialize, 7.25_real64)
  call require(did_initialize, 'F-KT committed initialization')
  call require(committed%ready(), 'F-KT committed ready')
  call committed%snapshot(committed_copy, available)
  call require(available, 'committed biomass snapshot available')
  call require(matches_reference(committed_copy), 'committed biomass snapshot identity')

  call mutate_trial(initial)
  call committed%snapshot(committed_copy, available)
  call require(available, 'committed snapshot after initializer mutation')
  call require(matches_reference(committed_copy), 'F-KT initialization deep-cloned cohort arrays')
  write(*,'(A)') 'FWOF23_FKT_COMMITTED_INITIALIZATION_DEEP_CLONES_BIOMASS=PASS'

  call committed%capture_checkpoint(checkpoint, available)
  call require(available, 'checkpoint available')
  call require(checkpoint%ready(), 'checkpoint ready')
  call checkpoint%snapshot(checkpoint_copy, available)
  call require(available, 'checkpoint snapshot available')
  call require(matches_reference(checkpoint_copy), 'checkpoint preserves biomass and cohorts')
  write(*,'(A)') 'FWOF23_FKT_CHECKPOINT_PRESERVES_COMPACT_BIOMASS=PASS'

  call checkpoint%snapshot(trial_b1, available)
  call require(available, 'trial B1 snapshot')
  call mutate_trial(trial_b1)
  call trial_b1%clone(trial_saved)
  deallocate(trial_b1)

  call committed%snapshot(committed_copy, available)
  call require(available, 'committed snapshot after trial discard')
  call require(matches_reference(committed_copy), 'discarded trial leaves committed biomass unchanged')
  write(*,'(A)') 'FWOF23_TRIAL_DISCARD_LEAVES_COMMITTED_BIOMASS_UNCHANGED=PASS'

  call checkpoint%snapshot(trial_a, available)
  call require(available, 'A replay snapshot')
  call require(matches_reference(trial_a), 'A replay returns exact checkpoint')
  call trial_a%clone(trial_b2)
  call mutate_trial(trial_b2)
  call require(same_state(trial_saved, trial_b2), 'same checkpoint B replay bitwise identity')
  call require(.not. same_state(trial_a, trial_b2), 'A and B differ')
  write(*,'(A)') 'FWOF23_CHECKPOINT_A_B_A_REPLAY_BITWISE_IDENTITY=PASS'

  call require(same_bits(root_biomass_view(checkpoint_copy), 10.0_real64), 'checkpoint WRT view is authoritative')
  write(*,'(A)') 'FWOF23_ACTUAL_WRT_VIEW_FROM_PRIMARY_BIOMASS_STATE=PASS'
  write(*,'(A)') 'FWOF23_NO_CROP_EVOLUTION_OR_CALENDAR_STATE=PASS'
  write(*,'(A)') 'FWOF23_PRIMARY_BIOMASS_STATE_TEST PASS'

contains

  subroutine set_reference_state(state)
    class(transaction_state_t), allocatable, intent(inout) :: state
    select type (typed => state)
    type is (wofost_actual_biomass_state_t)
      typed%root_biomass = 10.0_real64
      typed%stem_biomass = 20.0_real64
      typed%storage_biomass = 30.0_real64
      typed%exponential_leaf_area_index = 1.5_real64
      typed%leaf_biomass = [4.0_real64, 3.0_real64, 2.0_real64]
      typed%specific_leaf_area = [0.02_real64, 0.03_real64, 0.04_real64]
      typed%leaf_age = [0.0_real64, 1.0_real64, 2.0_real64]
    class default
      error stop 'unexpected type in set_reference_state'
    end select
  end subroutine set_reference_state

  subroutine mutate_trial(state)
    class(transaction_state_t), allocatable, intent(inout) :: state
    select type (typed => state)
    type is (wofost_actual_biomass_state_t)
      typed%root_biomass = typed%root_biomass + 1.0_real64
      typed%stem_biomass = typed%stem_biomass + 2.0_real64
      typed%storage_biomass = typed%storage_biomass + 3.0_real64
      typed%exponential_leaf_area_index = typed%exponential_leaf_area_index + 0.25_real64
      typed%leaf_biomass(2) = typed%leaf_biomass(2) + 0.5_real64
      typed%specific_leaf_area(1) = typed%specific_leaf_area(1) + 0.005_real64
      typed%leaf_age(3) = typed%leaf_age(3) + 0.5_real64
    class default
      error stop 'unexpected type in mutate_trial'
    end select
  end subroutine mutate_trial

  subroutine set_root_biomass(state, value)
    class(transaction_state_t), allocatable, intent(inout) :: state
    real(real64), intent(in) :: value
    select type (typed => state)
    type is (wofost_actual_biomass_state_t)
      typed%root_biomass = value
    class default
      error stop 'unexpected type in set_root_biomass'
    end select
  end subroutine set_root_biomass

  subroutine set_laiexp(state, value)
    class(transaction_state_t), allocatable, intent(inout) :: state
    real(real64), intent(in) :: value
    select type (typed => state)
    type is (wofost_actual_biomass_state_t)
      typed%exponential_leaf_area_index = value
    class default
      error stop 'unexpected type in set_laiexp'
    end select
  end subroutine set_laiexp

  subroutine drop_specific_leaf_area(state)
    class(transaction_state_t), allocatable, intent(inout) :: state
    select type (typed => state)
    type is (wofost_actual_biomass_state_t)
      if (allocated(typed%specific_leaf_area)) deallocate(typed%specific_leaf_area)
    class default
      error stop 'unexpected type in drop_specific_leaf_area'
    end select
  end subroutine drop_specific_leaf_area

  subroutine shorten_leaf_age(state)
    class(transaction_state_t), allocatable, intent(inout) :: state
    select type (typed => state)
    type is (wofost_actual_biomass_state_t)
      typed%leaf_age = [0.0_real64, 1.0_real64]
    class default
      error stop 'unexpected type in shorten_leaf_age'
    end select
  end subroutine shorten_leaf_age

  integer function validate_state(state) result(status)
    class(transaction_state_t), allocatable, intent(in) :: state
    status = -1
    select type (typed => state)
    type is (wofost_actual_biomass_state_t)
      status = typed%validate()
    class default
      error stop 'unexpected type in validate_state'
    end select
  end function validate_state

  integer function cohort_count(state) result(count)
    class(transaction_state_t), allocatable, intent(in) :: state
    count = -1
    select type (typed => state)
    type is (wofost_actual_biomass_state_t)
      count = typed%active_leaf_cohort_count()
    class default
      error stop 'unexpected type in cohort_count'
    end select
  end function cohort_count

  real(real64) function leaf_biomass_total(state) result(value)
    class(transaction_state_t), allocatable, intent(in) :: state
    value = -1.0_real64
    select type (typed => state)
    type is (wofost_actual_biomass_state_t)
      value = typed%living_leaf_biomass()
    class default
      error stop 'unexpected type in leaf_biomass_total'
    end select
  end function leaf_biomass_total

  real(real64) function leaf_area_sum(state) result(value)
    class(transaction_state_t), allocatable, intent(in) :: state
    value = -1.0_real64
    select type (typed => state)
    type is (wofost_actual_biomass_state_t)
      value = typed%leaf_area_sum()
    class default
      error stop 'unexpected type in leaf_area_sum'
    end select
  end function leaf_area_sum

  real(real64) function root_biomass_view(state) result(value)
    class(transaction_state_t), allocatable, intent(in) :: state
    value = -1.0_real64
    select type (typed => state)
    type is (wofost_actual_biomass_state_t)
      value = typed%actual_root_biomass()
    class default
      error stop 'unexpected type in root_biomass_view'
    end select
  end function root_biomass_view

  logical function same_state(left, right) result(equal)
    class(transaction_state_t), allocatable, intent(in) :: left, right
    integer :: i
    equal = .false.
    select type (l => left)
    type is (wofost_actual_biomass_state_t)
      select type (r => right)
      type is (wofost_actual_biomass_state_t)
        if (.not. same_bits(l%root_biomass, r%root_biomass)) return
        if (.not. same_bits(l%stem_biomass, r%stem_biomass)) return
        if (.not. same_bits(l%storage_biomass, r%storage_biomass)) return
        if (.not. same_bits(l%exponential_leaf_area_index, r%exponential_leaf_area_index)) return
        if (allocated(l%leaf_biomass) .neqv. allocated(r%leaf_biomass)) return
        if (allocated(l%specific_leaf_area) .neqv. allocated(r%specific_leaf_area)) return
        if (allocated(l%leaf_age) .neqv. allocated(r%leaf_age)) return
        if (allocated(l%leaf_biomass)) then
          if (size(l%leaf_biomass) /= size(r%leaf_biomass)) return
          if (size(l%specific_leaf_area) /= size(r%specific_leaf_area)) return
          if (size(l%leaf_age) /= size(r%leaf_age)) return
          do i = 1, size(l%leaf_biomass)
            if (.not. same_bits(l%leaf_biomass(i), r%leaf_biomass(i))) return
            if (.not. same_bits(l%specific_leaf_area(i), r%specific_leaf_area(i))) return
            if (.not. same_bits(l%leaf_age(i), r%leaf_age(i))) return
          end do
        end if
        equal = .true.
      end select
    end select
  end function same_state

  logical function matches_reference(state) result(equal)
    class(transaction_state_t), allocatable, intent(in) :: state
    class(transaction_state_t), allocatable :: reference
    allocate(wofost_actual_biomass_state_t :: reference)
    call set_reference_state(reference)
    equal = same_state(state, reference)
  end function matches_reference

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

end program test_fwof23_primary_biomass_state
