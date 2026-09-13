program test_fvq64_fgc21_independent_sequences
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_executor_t, kernel_committed_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_head_datum_t
  use mod_groundwater_coupling_policy, only: groundwater_head_convergence_policy_t
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t, &
       groundwater_interface_mass_snapshot_t, GW_MASS_LEDGER_OK
  use mod_groundwater_predictor_corrector_window, only: groundwater_coupling_origin_t, groundwater_pc_result_t, &
       run_restricted_groundwater_coupling_window, GW_PC_OK, GW_PC_NOT_CONVERGED
  use mod_fgc21_restricted_predictor_corrector_owner_test, only: dummy_state_t, dummy_parameters_t, &
       dummy_materializer_t, dummy_model_t, dummy_groundwater_service_t, setup_common
  implicit none

  integer :: failures

  failures = 0
  call test_unequal_consecutive_windows(failures)
  call test_rejected_window_then_smaller_retry(failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'F-VQ64 INDEPENDENT FAILURES=', failures
    error stop 1
  end if
  write(*,'(A)') 'F-VQ64 INDEPENDENT F-GC21 SEQUENCES PASS'

contains

  subroutine test_unequal_consecutive_windows(failures)
    integer, intent(inout) :: failures
    type(kernel_executor_t) :: executor
    type(kernel_committed_state_t) :: committed
    type(dummy_model_t), target :: model
    type(dummy_parameters_t) :: parameters
    type(dummy_materializer_t) :: materializer
    type(dummy_groundwater_service_t) :: groundwater
    type(groundwater_interface_mass_ledger_t) :: ledger
    type(groundwater_head_datum_t) :: datum
    type(groundwater_head_convergence_policy_t) :: policy
    type(groundwater_coupling_window_t) :: window
    type(groundwater_coupling_origin_t) :: origin
    type(groundwater_pc_result_t) :: first_result, second_result
    type(canonical_numerical_config_t) :: numerical
    type(groundwater_interface_mass_snapshot_t) :: ledger_snapshot
    class(transaction_state_t), allocatable :: initial_state, snapshot
    real(real64) :: first_dt, second_dt, rate, first_exchange, second_exchange
    real(real64) :: expected_q, t_mid, t_end
    logical :: initialized, snapshot_available
    integer :: status

    call setup_common(executor, model, parameters, groundwater, ledger, datum, policy, window, origin, numerical, &
         committed, initial_state, initialized, status)
    call assert_true(initialized, 'two-window: initial state available', failures)
    call assert_true(status == GW_MASS_LEDGER_OK, 'two-window: ledger identity bound', failures)

    first_dt = window%t1 - window%t0
    t_mid = window%t1
    rate = 0.2_real64 + 0.01_real64 * 0.5_real64
    first_exchange = rate * first_dt
    expected_q = rate * 0.01_real64 / 86400.0_real64

    call run_restricted_groundwater_coupling_window(executor, parameters, committed, materializer, numerical, &
         groundwater, ledger, datum, policy, window, origin, first_result)

    call assert_true(first_result%status == GW_PC_OK .and. first_result%committed, &
         'two-window: first generic window commits', failures)
    call assert_close(first_result%corrector_swap_outward_exchange_cm, first_exchange, 1.0e-13_real64, &
         'two-window: first exact accepted exchange', failures)
    call assert_close(first_result%corrector_q_swap_m_per_s, expected_q, 1.0e-18_real64, &
         'two-window: first mean flux derives from integrated exchange', failures)
    call assert_exact_opposites(first_result%corrector_q_swap_m_per_s, first_result%corrector_q_groundwater_m_per_s, &
         'two-window: first q action-reaction exact', failures)
    call assert_exact_zero(first_result%residual%flux_residual_m_per_s, &
         'two-window: first interface flux residual exact zero', failures)

    window%t0 = t_mid
    window%t1 = t_mid + 0.125_real64
    second_dt = window%t1 - window%t0
    t_end = window%t1
    second_exchange = rate * second_dt

    call run_restricted_groundwater_coupling_window(executor, parameters, committed, materializer, numerical, &
         groundwater, ledger, datum, policy, window, origin, second_result)

    call assert_true(second_result%status == GW_PC_OK .and. second_result%committed, &
         'two-window: second unequal generic window commits', failures)
    call assert_close(second_result%corrector_swap_outward_exchange_cm, second_exchange, 1.0e-13_real64, &
         'two-window: second exact accepted exchange', failures)
    call assert_close(second_result%corrector_q_swap_m_per_s, expected_q, 1.0e-18_real64, &
         'two-window: second mean flux independent of window duration', failures)
    call assert_exact_opposites(second_result%corrector_q_swap_m_per_s, second_result%corrector_q_groundwater_m_per_s, &
         'two-window: second q action-reaction exact', failures)
    call assert_exact_zero(second_result%residual%flux_residual_m_per_s, &
         'two-window: second interface flux residual exact zero', failures)

    call assert_true(model%advance_count == 4, 'two-window: exactly predictor+corrector per window', failures)
    call assert_true(groundwater%trial_count == 4, 'two-window: exactly two groundwater trials per window', failures)
    call assert_true(groundwater%discard_count == 2, 'two-window: predictor groundwater discarded in each window', failures)
    call assert_true(groundwater%commit_count == 2, 'two-window: one groundwater publication per window', failures)
    call assert_true(committed%current_revision() == 2_int64, 'two-window: SWAP revision advances once per accepted window', failures)
    call assert_true(groundwater%revision == 2_int64, 'two-window: groundwater revision advances once per accepted window', failures)
    call assert_true(origin%swap_revision == 2_int64 .and. origin%groundwater_revision == 2_int64, &
         'two-window: coupling origin provenance advances deterministically', failures)
    call assert_close(origin%accepted_time, t_end, 1.0e-14_real64, &
         'two-window: coupling origin time equals second t1', failures)

    call ledger%snapshot(ledger_snapshot)
    call assert_true(ledger_snapshot%available, 'two-window: ledger snapshot available', failures)
    call assert_true(ledger_snapshot%committed_exchange_count == 2, 'two-window: two accepted ledger publications', failures)
    call assert_close(ledger_snapshot%committed_swap_outward_exchange_m, &
         (first_exchange + second_exchange) * 0.01_real64, 1.0e-15_real64, &
         'two-window: cumulative ledger mass is exact sum of accepted exchanges', failures)
    call assert_exact_zero(ledger_snapshot%conservation_residual_m, &
         'two-window: cumulative ledger conservation residual exact zero', failures)

    call committed%snapshot(snapshot, snapshot_available)
    call assert_true(snapshot_available, 'two-window: committed physical snapshot available', failures)
    if (snapshot_available) then
      select type (typed_snapshot => snapshot)
      type is (dummy_state_t)
        call assert_close(typed_snapshot%storage, 10.0_real64-first_exchange-second_exchange, 1.0e-13_real64, &
             'two-window: only accepted corrector exchanges change physical storage', failures)
      class default
        call assert_true(.false., 'two-window: committed snapshot type', failures)
      end select
    end if
  end subroutine test_unequal_consecutive_windows

  subroutine test_rejected_window_then_smaller_retry(failures)
    integer, intent(inout) :: failures
    type(kernel_executor_t) :: executor
    type(kernel_committed_state_t) :: committed
    type(dummy_model_t), target :: model
    type(dummy_parameters_t) :: parameters
    type(dummy_materializer_t) :: materializer
    type(dummy_groundwater_service_t) :: groundwater
    type(groundwater_interface_mass_ledger_t) :: ledger
    type(groundwater_head_datum_t) :: datum
    type(groundwater_head_convergence_policy_t) :: policy
    type(groundwater_coupling_window_t) :: window
    type(groundwater_coupling_origin_t) :: origin, original_origin
    type(groundwater_pc_result_t) :: rejected_result, retry_result
    type(canonical_numerical_config_t) :: numerical
    type(groundwater_interface_mass_snapshot_t) :: ledger_snapshot
    class(transaction_state_t), allocatable :: initial_state, snapshot
    real(real64) :: rate, retry_dt, retry_exchange, original_t0
    logical :: initialized, snapshot_available
    integer :: status

    call setup_common(executor, model, parameters, groundwater, ledger, datum, policy, window, origin, numerical, &
         committed, initial_state, initialized, status)
    call assert_true(initialized .and. status == GW_MASS_LEDGER_OK, 'retry: setup', failures)
    original_origin = origin
    original_t0 = window%t0

    groundwater%response_mode = 1
    call run_restricted_groundwater_coupling_window(executor, parameters, committed, materializer, numerical, &
         groundwater, ledger, datum, policy, window, origin, rejected_result)

    call assert_true(rejected_result%status == GW_PC_NOT_CONVERGED, 'retry: first window rejects on head residual', failures)
    call assert_true(rejected_result%request_smaller_window, 'retry: rejected window requests smaller outer window', failures)
    call assert_true(.not. rejected_result%committed, 'retry: rejected window publishes nothing', failures)
    call assert_true(committed%current_revision() == 0_int64 .and. groundwater%revision == 0_int64, &
         'retry: committed revisions unchanged after rejection', failures)
    call assert_true(origin%swap_revision == original_origin%swap_revision .and. &
         origin%groundwater_revision == original_origin%groundwater_revision, &
         'retry: coupling provenance unchanged after rejection', failures)
    call assert_close(origin%accepted_time, original_origin%accepted_time, 0.0_real64, &
         'retry: coupling origin time unchanged after rejection', failures)
    call assert_close(origin%accepted_h_groundwater_m, original_origin%accepted_h_groundwater_m, 0.0_real64, &
         'retry: coupling head unchanged after rejection', failures)
    call ledger%snapshot(ledger_snapshot)
    call assert_true(ledger_snapshot%committed_exchange_count == 0, 'retry: rejected exchange absent from ledger', failures)
    call assert_exact_zero(ledger_snapshot%committed_swap_outward_exchange_m, &
         'retry: rejected window contributes exactly zero committed interface mass', failures)

    groundwater%response_mode = 0
    window%t0 = original_t0
    window%t1 = original_t0 + 0.0625_real64
    retry_dt = window%t1 - window%t0
    rate = 0.2_real64 + 0.01_real64 * 0.5_real64
    retry_exchange = rate * retry_dt

    call run_restricted_groundwater_coupling_window(executor, parameters, committed, materializer, numerical, &
         groundwater, ledger, datum, policy, window, origin, retry_result)

    call assert_true(retry_result%status == GW_PC_OK .and. retry_result%committed, &
         'retry: smaller new outer window commits from unchanged origin', failures)
    call assert_true(model%advance_count == 4, 'retry: bounded two trajectories per attempted outer window', failures)
    call assert_true(groundwater%trial_count == 4, 'retry: two groundwater trials per attempted outer window', failures)
    call assert_true(groundwater%discard_count == 3, 'retry: rejected candidates plus accepted-window predictor discarded', failures)
    call assert_true(groundwater%commit_count == 1, 'retry: exactly one groundwater publication after retry', failures)
    call assert_true(committed%current_revision() == 1_int64 .and. groundwater%revision == 1_int64, &
         'retry: revisions advance exactly once after accepted retry', failures)
    call assert_close(retry_result%corrector_swap_outward_exchange_cm, retry_exchange, 1.0e-13_real64, &
         'retry: accepted mass belongs to smaller window only', failures)
    call assert_exact_opposites(retry_result%corrector_q_swap_m_per_s, retry_result%corrector_q_groundwater_m_per_s, &
         'retry: accepted q action-reaction exact', failures)
    call assert_exact_zero(retry_result%residual%flux_residual_m_per_s, &
         'retry: accepted flux residual exact zero', failures)

    call ledger%snapshot(ledger_snapshot)
    call assert_true(ledger_snapshot%committed_exchange_count == 1, 'retry: only accepted retry reaches ledger', failures)
    call assert_close(ledger_snapshot%committed_swap_outward_exchange_m, retry_exchange*0.01_real64, 1.0e-15_real64, &
         'retry: no rejected-window water leaks into ledger', failures)
    call assert_exact_zero(ledger_snapshot%conservation_residual_m, &
         'retry: ledger remains exactly conservative', failures)

    call committed%snapshot(snapshot, snapshot_available)
    call assert_true(snapshot_available, 'retry: committed snapshot available', failures)
    if (snapshot_available) then
      select type (typed_snapshot => snapshot)
      type is (dummy_state_t)
        call assert_close(typed_snapshot%storage, 10.0_real64-retry_exchange, 1.0e-13_real64, &
             'retry: rejected physical trajectory leaves no storage trace', failures)
      class default
        call assert_true(.false., 'retry: committed snapshot type', failures)
      end select
    end if
  end subroutine test_rejected_window_then_smaller_retry

  subroutine assert_true(condition, label, failures)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    if (.not. condition) then
      failures = failures + 1
      write(*,'(A)') 'FAIL: '//trim(label)
    end if
  end subroutine assert_true

  subroutine assert_close(actual, expected, tolerance, label, failures)
    real(real64), intent(in) :: actual, expected, tolerance
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    call assert_true(abs(actual-expected) <= tolerance, label, failures)
  end subroutine assert_close

  subroutine assert_exact_zero(value, label, failures)
    real(real64), intent(in) :: value
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    call assert_true(transfer(value, 0_int64) == transfer(0.0_real64, 0_int64), label, failures)
  end subroutine assert_exact_zero

  subroutine assert_exact_opposites(lhs, rhs, label, failures)
    real(real64), intent(in) :: lhs, rhs
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    call assert_true(transfer(rhs, 0_int64) == transfer(-lhs, 0_int64), label, failures)
  end subroutine assert_exact_opposites

end program test_fvq64_fgc21_independent_sequences
