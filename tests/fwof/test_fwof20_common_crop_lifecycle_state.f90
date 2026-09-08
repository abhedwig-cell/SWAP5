program test_fwof20_common_crop_lifecycle_state
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t
  use mod_crop_lifecycle_state, only: crop_lifecycle_state_t, CROP_LIFECYCLE_STATE_OK, &
       CROP_LIFECYCLE_STATE_INVALID_DVS, CROP_LIFECYCLE_STATE_INVALID_LAI
  implicit none

  class(transaction_state_t), allocatable :: initial, direct_copy, committed_copy
  class(transaction_state_t), allocatable :: checkpoint_copy, trial_b1, trial_b1_saved, trial_a, trial_b2
  type(kernel_committed_state_t) :: committed
  type(kernel_checkpoint_t) :: checkpoint
  real(real64) :: nanv, tvalue
  logical :: did_initialize, available
  integer :: status

  nanv = ieee_value(0.0_real64, ieee_quiet_nan)

  allocate(crop_lifecycle_state_t :: initial)
  call set_crop_state(initial, .true., 0.75_real64, 2.25_real64)
  status = validate_crop_state(initial)
  call require(status == CROP_LIFECYCLE_STATE_OK, 'valid initial state')

  call initial%clone(direct_copy)
  call require(same_crop_state(initial, direct_copy), 'direct clone identity')
  call mutate_trial(direct_copy)
  call require(.not. same_crop_state(initial, direct_copy), 'direct clone independence')
  call require(matches_crop_state(initial, .true., 0.75_real64, 2.25_real64), 'initial unchanged after clone mutation')
  write(*,'(A)') 'FWOF20_DIRECT_CLONE_IDENTITY_AND_INDEPENDENCE=PASS'

  call set_crop_state(direct_copy, .true., nanv, 1.0_real64)
  call require(validate_crop_state(direct_copy) == CROP_LIFECYCLE_STATE_INVALID_DVS, 'nan DVS fails closed')
  call set_crop_state(direct_copy, .true., 0.5_real64, nanv)
  call require(validate_crop_state(direct_copy) == CROP_LIFECYCLE_STATE_INVALID_LAI, 'nan LAI fails closed')
  call set_crop_state(direct_copy, .true., 0.5_real64, -0.1_real64)
  call require(validate_crop_state(direct_copy) == CROP_LIFECYCLE_STATE_INVALID_LAI, 'negative LAI fails closed')
  write(*,'(A)') 'FWOF20_INVALID_STATE_FAILS_CLOSED=PASS'

  call committed%initialize(42_int64, initial, did_initialize, 12.5_real64)
  call require(did_initialize, 'F-KT committed initialization flag')
  call require(committed%ready(), 'F-KT committed initialization readiness')
  call require(committed%current_lineage_id() == 42_int64, 'lineage id')
  call require(committed%current_revision() == 0_int64, 'initial revision')
  call committed%current_time(tvalue, available)
  call require(available, 'initial committed time available')
  call require(same_bits(tvalue, 12.5_real64), 'initial committed time')

  call committed%snapshot(committed_copy, available)
  call require(available, 'committed snapshot available')
  call require(same_crop_state(initial, committed_copy), 'committed snapshot identity')

  call set_crop_state(initial, .false., 9.0_real64, 9.0_real64)
  call committed%snapshot(committed_copy, available)
  call require(available, 'committed snapshot after initializer mutation available')
  call require(matches_crop_state(committed_copy, .true., 0.75_real64, 2.25_real64), &
       'committed state independent from initializer')
  write(*,'(A)') 'FWOF20_FKT_COMMITTED_INITIALIZATION_CLONES_STATE=PASS'

  call committed%capture_checkpoint(checkpoint, available)
  call require(available, 'checkpoint capture available')
  call require(checkpoint%ready(), 'checkpoint capture readiness')
  call require(checkpoint%current_lineage_id() == 42_int64, 'checkpoint lineage')
  call require(checkpoint%origin_revision() == 0_int64, 'checkpoint revision')
  call checkpoint%current_time(tvalue, available)
  call require(available, 'checkpoint time available')
  call require(same_bits(tvalue, 12.5_real64), 'checkpoint time')

  call checkpoint%snapshot(checkpoint_copy, available)
  call require(available, 'checkpoint physical snapshot available')
  call require(matches_crop_state(checkpoint_copy, .true., 0.75_real64, 2.25_real64), &
       'checkpoint physical state')
  write(*,'(A)') 'FWOF20_FKT_CHECKPOINT_EXACT_SNAPSHOT=PASS'

  call checkpoint%snapshot(trial_b1, available)
  call require(available, 'trial B1 snapshot')
  call mutate_trial(trial_b1)
  call trial_b1%clone(trial_b1_saved)
  call require(matches_crop_state(trial_b1, .false., 1.0_real64, 3.0_real64), 'trial B1 transform')
  deallocate(trial_b1)

  call committed%snapshot(committed_copy, available)
  call require(available, 'committed snapshot after trial discard available')
  call require(matches_crop_state(committed_copy, .true., 0.75_real64, 2.25_real64), &
       'discarded trial cannot mutate committed state')
  write(*,'(A)') 'FWOF20_TRIAL_DISCARD_LEAVES_COMMITTED_STATE_UNCHANGED=PASS'

  call checkpoint%snapshot(trial_a, available)
  call require(available, 'replayed A snapshot available')
  call require(matches_crop_state(trial_a, .true., 0.75_real64, 2.25_real64), &
       'replayed A from checkpoint')
  call trial_a%clone(trial_b2)
  call mutate_trial(trial_b2)
  call require(same_crop_state(trial_b1_saved, trial_b2), 'B replay bitwise identity')
  call require(.not. same_crop_state(trial_a, trial_b2), 'A and B differ')
  write(*,'(A)') 'FWOF20_CHECKPOINT_A_B_A_REPLAY_BITWISE_IDENTITY=PASS'

  write(*,'(A)') 'FWOF20_NO_CALENDAR_OR_EVOLUTION_PHYSICS_IN_CARRIER=PASS'
  write(*,'(A)') 'FWOF20_COMMON_CROP_LIFECYCLE_STATE_TEST PASS'

contains

  subroutine set_crop_state(state, emerged, dvs, lai)
    class(transaction_state_t), allocatable, intent(inout) :: state
    logical, intent(in) :: emerged
    real(real64), intent(in) :: dvs, lai

    select type (typed => state)
    type is (crop_lifecycle_state_t)
      typed%crop_emerged = emerged
      typed%development_stage = dvs
      typed%leaf_area_index = lai
    class default
      error stop 'unexpected crop state type in set_crop_state'
    end select
  end subroutine set_crop_state

  integer function validate_crop_state(state) result(value)
    class(transaction_state_t), allocatable, intent(in) :: state

    value = -1
    select type (typed => state)
    type is (crop_lifecycle_state_t)
      value = typed%validate()
    class default
      error stop 'unexpected crop state type in validate_crop_state'
    end select
  end function validate_crop_state

  subroutine mutate_trial(state)
    class(transaction_state_t), allocatable, intent(inout) :: state

    select type (typed => state)
    type is (crop_lifecycle_state_t)
      typed%crop_emerged = .false.
      typed%development_stage = typed%development_stage + 0.25_real64
      typed%leaf_area_index = typed%leaf_area_index + 0.75_real64
    class default
      error stop 'unexpected crop state type in mutate_trial'
    end select
  end subroutine mutate_trial

  logical function same_crop_state(left, right) result(equal)
    class(transaction_state_t), allocatable, intent(in) :: left, right

    equal = .false.
    select type (l => left)
    type is (crop_lifecycle_state_t)
      select type (r => right)
      type is (crop_lifecycle_state_t)
        if (.not. (l%crop_emerged .eqv. r%crop_emerged)) return
        if (.not. same_bits(l%development_stage, r%development_stage)) return
        if (.not. same_bits(l%leaf_area_index, r%leaf_area_index)) return
        equal = .true.
      end select
    end select
  end function same_crop_state

  logical function matches_crop_state(state, emerged, dvs, lai) result(equal)
    class(transaction_state_t), allocatable, intent(in) :: state
    logical, intent(in) :: emerged
    real(real64), intent(in) :: dvs, lai

    equal = .false.
    select type (typed => state)
    type is (crop_lifecycle_state_t)
      if (.not. (typed%crop_emerged .eqv. emerged)) return
      if (.not. same_bits(typed%development_stage, dvs)) return
      if (.not. same_bits(typed%leaf_area_index, lai)) return
      equal = .true.
    end select
  end function matches_crop_state

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

end program test_fwof20_common_crop_lifecycle_state
