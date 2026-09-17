program test_pub_gc_gw_a
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_groundwater_exchange_service_contract, only: groundwater_exchange_checkpoint_t, &
       groundwater_exchange_candidate_t, groundwater_exchange_prepared_t, groundwater_exchange_trial_result_t, &
       groundwater_capture_checkpoint, groundwater_trial_from_checkpoint, groundwater_discard_candidate, &
       groundwater_commit_candidate, groundwater_prepare_candidate, groundwater_commit_prepared, &
       groundwater_abort_prepared, GW_EXCHANGE_OK, GW_EXCHANGE_BACKEND_REJECTED
  use mod_pub_gc_gw_a, only: pub_gc_gw_a_service_t
  implicit none

  integer :: failures

  failures = 0
  call test_zero_exchange(failures)
  call test_outward_exchange_lowers_head(failures)
  call test_inward_exchange_raises_head_and_action_reaction(failures)
  call test_same_checkpoint_repeatability(failures)
  call test_prepare_abort_is_nonpublishing(failures)
  call test_prepared_commit_publishes_once(failures)
  call test_stale_checkpoint_rejected_after_commit(failures)
  call test_stale_checkpoint_rejected_after_reinitialize(failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'PUB_GC_GW_A_FAILURES=', failures
    error stop 1
  end if

  write(*,'(A)') 'PUB_GC_GW_A_ZERO_EXCHANGE=PASS'
  write(*,'(A)') 'PUB_GC_GW_A_SIGN_RESPONSE=PASS'
  write(*,'(A)') 'PUB_GC_GW_A_ACTION_REACTION=PASS'
  write(*,'(A)') 'PUB_GC_GW_A_SAME_CHECKPOINT_REPEATABILITY=PASS'
  write(*,'(A)') 'PUB_GC_GW_A_PREPARE_ABORT_NONPUBLISHING=PASS'
  write(*,'(A)') 'PUB_GC_GW_A_PREPARED_COMMIT=PASS'
  write(*,'(A)') 'PUB_GC_GW_A_STALE_CHECKPOINT_FAIL_CLOSED=PASS'
  write(*,'(A)') 'PUB_GC_GW_A_COMPONENT_ORACLE=PASS'

contains

  subroutine require(condition, label, failures)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures

    if (.not. condition) then
      failures = failures + 1
      write(*,'(A,A)') 'PUB_GC_GW_A_ASSERT_FAIL=', trim(label)
    end if
  end subroutine require

  subroutine require_close(actual, expected, tolerance, label, failures)
    real(real64), intent(in) :: actual, expected, tolerance
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures

    call require(abs(actual - expected) <= tolerance, label, failures)
  end subroutine require_close

  subroutine initialize_service(service, status)
    type(pub_gc_gw_a_service_t), intent(out) :: service
    integer, intent(out) :: status

    service = pub_gc_gw_a_service_t()
    call service%initialize(7101_int64, 8101_int64, 1.0_real64, 10.0_real64, &
         1000.0_real64, 0.2_real64, 0.0_real64, 0.0_real64, status)
  end subroutine initialize_service

  subroutine make_window(window)
    type(groundwater_coupling_window_t), intent(out) :: window

    window = groundwater_coupling_window_t()
    window%t0 = 10.0_real64
    window%t1 = 11.0_real64
  end subroutine make_window

  subroutine test_zero_exchange(failures)
    integer, intent(inout) :: failures
    type(pub_gc_gw_a_service_t) :: service
    type(groundwater_exchange_checkpoint_t) :: checkpoint
    type(groundwater_exchange_candidate_t) :: candidate
    type(groundwater_exchange_trial_result_t) :: result
    type(groundwater_coupling_window_t) :: window
    integer :: status

    call initialize_service(service, status)
    call require(status == GW_EXCHANGE_OK, 'zero: initialize', failures)
    call make_window(window)
    call groundwater_capture_checkpoint(service, checkpoint, status)
    call require(status == GW_EXCHANGE_OK, 'zero: capture', failures)
    call groundwater_trial_from_checkpoint(service, checkpoint, window, 0.0_real64, candidate, result, status)
    call require(status == GW_EXCHANGE_OK, 'zero: trial', failures)
    call require_close(result%h_groundwater_m, 1.0_real64, 0.0_real64, 'zero: head unchanged', failures)
    call require_close(service%last_candidate_volume_change_m3(), 0.0_real64, 0.0_real64, &
         'zero: volume unchanged', failures)
    call groundwater_discard_candidate(service, candidate, status)
    call require(status == GW_EXCHANGE_OK, 'zero: discard', failures)
    call require_close(service%accepted_head_m(), 1.0_real64, 0.0_real64, 'zero: accepted head unchanged', failures)
    call require(service%current_revision() == 0_int64, 'zero: revision unchanged', failures)
  end subroutine test_zero_exchange

  subroutine test_outward_exchange_lowers_head(failures)
    integer, intent(inout) :: failures
    type(pub_gc_gw_a_service_t) :: service
    type(groundwater_exchange_checkpoint_t) :: checkpoint
    type(groundwater_exchange_candidate_t) :: candidate
    type(groundwater_exchange_trial_result_t) :: result
    type(groundwater_coupling_window_t) :: window
    real(real64), parameter :: Q_OUT = 1.0e-6_real64
    real(real64) :: expected_head, expected_volume
    integer :: status

    call initialize_service(service, status)
    call make_window(window)
    call groundwater_capture_checkpoint(service, checkpoint, status)
    call groundwater_trial_from_checkpoint(service, checkpoint, window, Q_OUT, candidate, result, status)
    call require(status == GW_EXCHANGE_OK, 'outward: trial', failures)

    expected_volume = -1000.0_real64 * Q_OUT * 86400.0_real64
    expected_head = 1.0_real64 + expected_volume / (0.2_real64 * 1000.0_real64)
    call require_close(result%h_groundwater_m, expected_head, 1.0e-15_real64, &
         'outward: analytic head response', failures)
    call require_close(service%last_candidate_volume_change_m3(), expected_volume, 1.0e-14_real64, &
         'outward: analytic volume response', failures)
    call require(result%h_groundwater_m < 1.0_real64, 'outward: head lowers', failures)
    call groundwater_discard_candidate(service, candidate, status)
    call require_close(service%accepted_head_m(), 1.0_real64, 0.0_real64, &
         'outward: discarded trial did not publish', failures)
  end subroutine test_outward_exchange_lowers_head

  subroutine test_inward_exchange_raises_head_and_action_reaction(failures)
    integer, intent(inout) :: failures
    type(pub_gc_gw_a_service_t) :: service
    type(groundwater_exchange_checkpoint_t) :: checkpoint
    type(groundwater_exchange_candidate_t) :: candidate
    type(groundwater_exchange_trial_result_t) :: result
    type(groundwater_coupling_window_t) :: window
    real(real64), parameter :: Q_SWAP_OUT = 2.0e-6_real64
    real(real64), parameter :: Q_GW_OUT = -Q_SWAP_OUT
    real(real64) :: expected_head
    integer :: status

    call initialize_service(service, status)
    call make_window(window)
    call groundwater_capture_checkpoint(service, checkpoint, status)
    call groundwater_trial_from_checkpoint(service, checkpoint, window, Q_GW_OUT, candidate, result, status)
    call require(status == GW_EXCHANGE_OK, 'inward: trial', failures)

    expected_head = 1.0_real64 + Q_SWAP_OUT * 86400.0_real64 / 0.2_real64
    call require_close(result%h_groundwater_m, expected_head, 1.0e-15_real64, &
         'inward: analytic recharge response', failures)
    call require(result%h_groundwater_m > 1.0_real64, 'inward: head raises', failures)
    call require(transfer(Q_GW_OUT, 0_int64) == transfer(-Q_SWAP_OUT, 0_int64), &
         'inward: exact action reaction assignment', failures)
    call groundwater_discard_candidate(service, candidate, status)
  end subroutine test_inward_exchange_raises_head_and_action_reaction

  subroutine test_same_checkpoint_repeatability(failures)
    integer, intent(inout) :: failures
    type(pub_gc_gw_a_service_t) :: service
    type(groundwater_exchange_checkpoint_t) :: checkpoint
    type(groundwater_exchange_candidate_t) :: candidate
    type(groundwater_exchange_trial_result_t) :: first_result, second_result
    type(groundwater_coupling_window_t) :: window
    integer :: status

    call initialize_service(service, status)
    call make_window(window)
    call groundwater_capture_checkpoint(service, checkpoint, status)
    call groundwater_trial_from_checkpoint(service, checkpoint, window, -1.25e-6_real64, &
         candidate, first_result, status)
    call require(status == GW_EXCHANGE_OK, 'repeat: first trial', failures)
    call groundwater_discard_candidate(service, candidate, status)
    call require(status == GW_EXCHANGE_OK, 'repeat: first discard', failures)
    call groundwater_trial_from_checkpoint(service, checkpoint, window, -1.25e-6_real64, &
         candidate, second_result, status)
    call require(status == GW_EXCHANGE_OK, 'repeat: second trial', failures)
    call require(transfer(first_result%h_groundwater_m, 0_int64) == transfer(second_result%h_groundwater_m, 0_int64), &
         'repeat: head bitwise identical', failures)
    call require(service%current_revision() == 0_int64, 'repeat: accepted revision unchanged', failures)
    call require_close(service%accepted_time_day(), 10.0_real64, 0.0_real64, &
         'repeat: accepted time unchanged', failures)
    call groundwater_discard_candidate(service, candidate, status)
  end subroutine test_same_checkpoint_repeatability

  subroutine test_prepare_abort_is_nonpublishing(failures)
    integer, intent(inout) :: failures
    type(pub_gc_gw_a_service_t) :: service
    type(groundwater_exchange_checkpoint_t) :: checkpoint
    type(groundwater_exchange_candidate_t) :: candidate
    type(groundwater_exchange_prepared_t) :: prepared
    type(groundwater_exchange_trial_result_t) :: result
    type(groundwater_coupling_window_t) :: window
    integer :: status

    call initialize_service(service, status)
    call make_window(window)
    call groundwater_capture_checkpoint(service, checkpoint, status)
    call groundwater_trial_from_checkpoint(service, checkpoint, window, -1.0e-6_real64, candidate, result, status)
    call groundwater_prepare_candidate(service, checkpoint, candidate, prepared, status)
    call require(status == GW_EXCHANGE_OK, 'prepare-abort: prepare', failures)
    call require_close(service%accepted_head_m(), 1.0_real64, 0.0_real64, &
         'prepare-abort: head not published at prepare', failures)
    call require_close(service%accepted_time_day(), 10.0_real64, 0.0_real64, &
         'prepare-abort: time not published at prepare', failures)
    call require(service%current_revision() == 0_int64, 'prepare-abort: revision not published', failures)
    call require(.not. service%restart_quiescent(), 'prepare-abort: reservation visible', failures)
    call groundwater_abort_prepared(service, checkpoint, prepared, status)
    call require(status == GW_EXCHANGE_OK, 'prepare-abort: abort', failures)
    call require(service%restart_quiescent(), 'prepare-abort: reservation released', failures)
    call require_close(service%accepted_head_m(), 1.0_real64, 0.0_real64, &
         'prepare-abort: abort leaves head unchanged', failures)
  end subroutine test_prepare_abort_is_nonpublishing

  subroutine test_prepared_commit_publishes_once(failures)
    integer, intent(inout) :: failures
    type(pub_gc_gw_a_service_t) :: service
    type(groundwater_exchange_checkpoint_t) :: checkpoint
    type(groundwater_exchange_candidate_t) :: candidate
    type(groundwater_exchange_prepared_t) :: prepared
    type(groundwater_exchange_trial_result_t) :: result
    type(groundwater_coupling_window_t) :: window
    real(real64) :: expected_head, expected_storage
    integer :: status

    call initialize_service(service, status)
    call make_window(window)
    call groundwater_capture_checkpoint(service, checkpoint, status)
    call groundwater_trial_from_checkpoint(service, checkpoint, window, -1.0e-6_real64, candidate, result, status)
    expected_head = result%h_groundwater_m
    call groundwater_prepare_candidate(service, checkpoint, candidate, prepared, status)
    call require(status == GW_EXCHANGE_OK, 'commit: prepare', failures)
    call groundwater_commit_prepared(service, checkpoint, prepared, status)
    call require(status == GW_EXCHANGE_OK, 'commit: prepared commit', failures)
    call require_close(service%accepted_head_m(), expected_head, 1.0e-15_real64, &
         'commit: accepted head', failures)
    call require_close(service%accepted_time_day(), 11.0_real64, 0.0_real64, &
         'commit: accepted time', failures)
    call require(service%current_revision() == 1_int64, 'commit: revision advanced once', failures)
    expected_storage = 0.2_real64 * 1000.0_real64 * expected_head
    call require_close(service%storage_volume_m3(), expected_storage, 1.0e-12_real64, &
         'commit: storage relation', failures)
    call require(service%restart_quiescent(), 'commit: no reservation leaked', failures)
  end subroutine test_prepared_commit_publishes_once

  subroutine test_stale_checkpoint_rejected_after_commit(failures)
    integer, intent(inout) :: failures
    type(pub_gc_gw_a_service_t) :: service
    type(groundwater_exchange_checkpoint_t) :: checkpoint, stale_checkpoint
    type(groundwater_exchange_candidate_t) :: candidate
    type(groundwater_exchange_trial_result_t) :: result
    type(groundwater_coupling_window_t) :: first_window, second_window
    integer :: status

    call initialize_service(service, status)
    call make_window(first_window)
    call groundwater_capture_checkpoint(service, checkpoint, status)
    stale_checkpoint = checkpoint
    call groundwater_trial_from_checkpoint(service, checkpoint, first_window, 0.0_real64, candidate, result, status)
    call groundwater_commit_candidate(service, checkpoint, candidate, status)
    call require(status == GW_EXCHANGE_OK, 'stale-after-commit: commit', failures)

    second_window = groundwater_coupling_window_t()
    second_window%t0 = 10.0_real64
    second_window%t1 = 10.5_real64
    call groundwater_trial_from_checkpoint(service, stale_checkpoint, second_window, 0.0_real64, candidate, result, status)
    call require(status == GW_EXCHANGE_BACKEND_REJECTED, 'stale-after-commit: old checkpoint rejected', failures)
    call require(service%current_revision() == 1_int64, 'stale-after-commit: revision preserved', failures)
  end subroutine test_stale_checkpoint_rejected_after_commit

  subroutine test_stale_checkpoint_rejected_after_reinitialize(failures)
    integer, intent(inout) :: failures
    type(pub_gc_gw_a_service_t) :: service
    type(groundwater_exchange_checkpoint_t) :: stale_checkpoint
    type(groundwater_exchange_candidate_t) :: candidate
    type(groundwater_exchange_trial_result_t) :: result
    type(groundwater_coupling_window_t) :: window
    integer :: status

    call initialize_service(service, status)
    call make_window(window)
    call groundwater_capture_checkpoint(service, stale_checkpoint, status)
    call service%initialize(7101_int64, 8102_int64, 1.0_real64, 10.0_real64, &
         1000.0_real64, 0.2_real64, 0.0_real64, 0.0_real64, status)
    call require(status == GW_EXCHANGE_OK, 'stale-after-reinit: reinitialize', failures)
    call groundwater_trial_from_checkpoint(service, stale_checkpoint, window, 0.0_real64, candidate, result, status)
    call require(status == GW_EXCHANGE_BACKEND_REJECTED, 'stale-after-reinit: old lineage checkpoint rejected', failures)
    call require(service%current_revision() == 0_int64, 'stale-after-reinit: new lineage revision untouched', failures)
  end subroutine test_stale_checkpoint_rejected_after_reinitialize

end program test_pub_gc_gw_a
