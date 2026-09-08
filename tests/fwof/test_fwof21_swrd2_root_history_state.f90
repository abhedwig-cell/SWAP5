program test_fwof21_swrd2_root_history_state
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t
  use mod_crop_lifecycle_state, only: crop_lifecycle_state_t, CROP_LIFECYCLE_STATE_INVALID_LAI
  use mod_swrd2_crop_lifecycle_state, only: swrd2_crop_lifecycle_state_t, SWRD2_CROP_STATE_OK, &
       SWRD2_CROP_STATE_INVALID_ACTUAL_DEPTH, SWRD2_CROP_STATE_INVALID_POTENTIAL_DEPTH, &
       SWRD2_CROP_STATE_INVALID_DEPTH_ORDER
  implicit none

  type(crop_lifecycle_state_t) :: swrd1_state
  class(transaction_state_t), allocatable :: initial, direct_copy, committed_copy
  class(transaction_state_t), allocatable :: checkpoint_copy, trial_b1, trial_b1_saved, trial_a, trial_b2
  type(kernel_committed_state_t) :: committed
  type(kernel_checkpoint_t) :: checkpoint
  real(real64) :: nanv
  logical :: did_initialize, available

  nanv = ieee_value(0.0_real64, ieee_quiet_nan)

  swrd1_state%crop_emerged = .true.
  swrd1_state%development_stage = 0.8_real64
  swrd1_state%leaf_area_index = 2.0_real64
  call require(swrd1_state%validate() == 0, 'SWRD1/base state valid')
  write(*,'(A)') 'FWOF21_SWRD1_USES_COMMON_STATE_WITHOUT_ROOT_HISTORY=PASS'

  allocate(swrd2_crop_lifecycle_state_t :: initial)
  call set_swrd2_state(initial, .true., 0.8_real64, 2.0_real64, 25.0_real64, 35.0_real64)
  call require(validate_swrd2_state(initial) == SWRD2_CROP_STATE_OK, 'valid SWRD2 state')

  call initial%clone(direct_copy)
  call require(is_swrd2_type(direct_copy), 'direct clone preserves dynamic subtype')
  call require(same_swrd2_state(initial, direct_copy), 'direct clone identity')
  call mutate_swrd2_trial(direct_copy)
  call require(.not. same_swrd2_state(initial, direct_copy), 'direct clone independent')
  call require(matches_swrd2_state(initial, .true., 0.8_real64, 2.0_real64, 25.0_real64, 35.0_real64), &
       'initial unchanged')
  write(*,'(A)') 'FWOF21_CLONE_PRESERVES_SWRD2_DYNAMIC_SUBTYPE=PASS'

  call set_swrd2_state(direct_copy, .true., 0.8_real64, 2.0_real64, nanv, 35.0_real64)
  call require(validate_swrd2_state(direct_copy) == SWRD2_CROP_STATE_INVALID_ACTUAL_DEPTH, 'NaN actual depth')
  call set_swrd2_state(direct_copy, .true., 0.8_real64, 2.0_real64, 25.0_real64, nanv)
  call require(validate_swrd2_state(direct_copy) == SWRD2_CROP_STATE_INVALID_POTENTIAL_DEPTH, 'NaN potential depth')
  call set_swrd2_state(direct_copy, .true., 0.8_real64, 2.0_real64, -1.0_real64, 35.0_real64)
  call require(validate_swrd2_state(direct_copy) == SWRD2_CROP_STATE_INVALID_ACTUAL_DEPTH, 'negative actual depth')
  call set_swrd2_state(direct_copy, .true., 0.8_real64, 2.0_real64, 36.0_real64, 35.0_real64)
  call require(validate_swrd2_state(direct_copy) == SWRD2_CROP_STATE_INVALID_DEPTH_ORDER, 'actual exceeds potential')
  call set_swrd2_state(direct_copy, .true., 0.8_real64, -0.1_real64, 25.0_real64, 35.0_real64)
  call require(validate_swrd2_state(direct_copy) == CROP_LIFECYCLE_STATE_INVALID_LAI, 'parent validation retained')
  write(*,'(A)') 'FWOF21_INVALID_ROOT_HISTORY_FAILS_CLOSED=PASS'

  call committed%initialize(84_int64, initial, did_initialize, 3.25_real64)
  call require(did_initialize, 'F-KT initialization flag')
  call require(committed%ready(), 'F-KT initialization ready')
  call committed%snapshot(committed_copy, available)
  call require(available, 'F-KT committed snapshot available')
  call require(is_swrd2_type(committed_copy), 'F-KT committed clone preserves subtype')
  call require(matches_swrd2_state(committed_copy, .true., 0.8_real64, 2.0_real64, 25.0_real64, 35.0_real64), &
       'F-KT committed values')
  write(*,'(A)') 'FWOF21_FKT_COMMITTED_STATE_PRESERVES_SWRD2_SUBTYPE=PASS'

  call committed%capture_checkpoint(checkpoint, available)
  call require(available, 'checkpoint available')
  call require(checkpoint%ready(), 'checkpoint ready')
  call checkpoint%snapshot(checkpoint_copy, available)
  call require(available, 'checkpoint snapshot available')
  call require(is_swrd2_type(checkpoint_copy), 'checkpoint preserves subtype')
  call require(matches_swrd2_state(checkpoint_copy, .true., 0.8_real64, 2.0_real64, 25.0_real64, 35.0_real64), &
       'checkpoint values')
  write(*,'(A)') 'FWOF21_FKT_CHECKPOINT_PRESERVES_ROOT_HISTORY=PASS'

  call checkpoint%snapshot(trial_b1, available)
  call require(available, 'trial B1 available')
  call mutate_swrd2_trial(trial_b1)
  call trial_b1%clone(trial_b1_saved)
  call require(matches_swrd2_state(trial_b1, .true., 0.9_real64, 2.5_real64, 30.0_real64, 40.0_real64), &
       'trial B1 transform')
  deallocate(trial_b1)

  call committed%snapshot(committed_copy, available)
  call require(available, 'committed after discard available')
  call require(matches_swrd2_state(committed_copy, .true., 0.8_real64, 2.0_real64, 25.0_real64, 35.0_real64), &
       'discard leaves committed root history unchanged')
  write(*,'(A)') 'FWOF21_TRIAL_DISCARD_LEAVES_SWRD2_HISTORY_UNCHANGED=PASS'

  call checkpoint%snapshot(trial_a, available)
  call require(available, 'A replay available')
  call require(matches_swrd2_state(trial_a, .true., 0.8_real64, 2.0_real64, 25.0_real64, 35.0_real64), &
       'A replay exact')
  call trial_a%clone(trial_b2)
  call mutate_swrd2_trial(trial_b2)
  call require(same_swrd2_state(trial_b1_saved, trial_b2), 'B replay bitwise identical')
  call require(.not. same_swrd2_state(trial_a, trial_b2), 'A and B differ')
  write(*,'(A)') 'FWOF21_CHECKPOINT_REPLAY_BITWISE_IDENTITY=PASS'

  write(*,'(A)') 'FWOF21_WRT_NOT_DUPLICATED_IN_SWRD2_STATE=PASS'
  write(*,'(A)') 'FWOF21_SWRD2_ROOT_HISTORY_STATE_TEST PASS'

contains

  subroutine set_swrd2_state(state, emerged, dvs, lai, actual_depth, potential_depth)
    class(transaction_state_t), allocatable, intent(inout) :: state
    logical, intent(in) :: emerged
    real(real64), intent(in) :: dvs, lai, actual_depth, potential_depth

    select type (typed => state)
    type is (swrd2_crop_lifecycle_state_t)
      typed%crop_emerged = emerged
      typed%development_stage = dvs
      typed%leaf_area_index = lai
      typed%actual_root_depth = actual_depth
      typed%potential_root_depth = potential_depth
    class default
      error stop 'unexpected state type in set_swrd2_state'
    end select
  end subroutine set_swrd2_state

  integer function validate_swrd2_state(state) result(status)
    class(transaction_state_t), allocatable, intent(in) :: state

    status = -1
    select type (typed => state)
    type is (swrd2_crop_lifecycle_state_t)
      status = typed%validate()
    class default
      error stop 'unexpected state type in validate_swrd2_state'
    end select
  end function validate_swrd2_state

  logical function is_swrd2_type(state) result(is_type)
    class(transaction_state_t), allocatable, intent(in) :: state

    is_type = .false.
    select type (typed => state)
    type is (swrd2_crop_lifecycle_state_t)
      is_type = .true.
    class default
      is_type = .false.
    end select
  end function is_swrd2_type

  subroutine mutate_swrd2_trial(state)
    class(transaction_state_t), allocatable, intent(inout) :: state

    select type (typed => state)
    type is (swrd2_crop_lifecycle_state_t)
      typed%development_stage = typed%development_stage + 0.1_real64
      typed%leaf_area_index = typed%leaf_area_index + 0.5_real64
      typed%actual_root_depth = typed%actual_root_depth + 5.0_real64
      typed%potential_root_depth = typed%potential_root_depth + 5.0_real64
    class default
      error stop 'unexpected state type in mutate_swrd2_trial'
    end select
  end subroutine mutate_swrd2_trial

  logical function same_swrd2_state(left, right) result(equal)
    class(transaction_state_t), allocatable, intent(in) :: left, right

    equal = .false.
    select type (l => left)
    type is (swrd2_crop_lifecycle_state_t)
      select type (r => right)
      type is (swrd2_crop_lifecycle_state_t)
        if (.not. (l%crop_emerged .eqv. r%crop_emerged)) return
        if (.not. same_bits(l%development_stage, r%development_stage)) return
        if (.not. same_bits(l%leaf_area_index, r%leaf_area_index)) return
        if (.not. same_bits(l%actual_root_depth, r%actual_root_depth)) return
        if (.not. same_bits(l%potential_root_depth, r%potential_root_depth)) return
        equal = .true.
      end select
    end select
  end function same_swrd2_state

  logical function matches_swrd2_state(state, emerged, dvs, lai, actual_depth, potential_depth) result(equal)
    class(transaction_state_t), allocatable, intent(in) :: state
    logical, intent(in) :: emerged
    real(real64), intent(in) :: dvs, lai, actual_depth, potential_depth

    equal = .false.
    select type (typed => state)
    type is (swrd2_crop_lifecycle_state_t)
      if (.not. (typed%crop_emerged .eqv. emerged)) return
      if (.not. same_bits(typed%development_stage, dvs)) return
      if (.not. same_bits(typed%leaf_area_index, lai)) return
      if (.not. same_bits(typed%actual_root_depth, actual_depth)) return
      if (.not. same_bits(typed%potential_root_depth, potential_depth)) return
      equal = .true.
    end select
  end function matches_swrd2_state

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

end program test_fwof21_swrd2_root_history_state
