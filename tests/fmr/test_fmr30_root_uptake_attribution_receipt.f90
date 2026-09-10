program test_fmr30_root_uptake_attribution_receipt
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_executor_t, kernel_result_t, kernel_diagnostics_t, KERNEL_COMMIT_STATUS_COMMITTED
  use mod_fmr_serialized_reference_backend, only: fmr30_test_physical_state_t, fmr30_test_parameters_t, &
       fmr30_test_model_t, fmr_b110_physical_forcing_t
  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t, fmr_commit_candidate_with_receipt, &
       FMR_COMMIT_RECEIPT_OK
  use mod_fmr_root_uptake_attribution_receipt, only: fmr_prepared_root_uptake_attribution_t, &
       fmr_root_uptake_attribution_receipt_t, fmr_prepare_root_uptake_attribution, &
       fmr_finalize_root_uptake_attribution, FMR_ROOT_ATTRIBUTION_OK, &
       FMR_ROOT_ATTRIBUTION_INVALID_FORCING, FMR_ROOT_ATTRIBUTION_INVALID_COMMIT_RECEIPT, &
       FMR_ROOT_ATTRIBUTION_PROVENANCE_MISMATCH, FMR_ROOT_ATTRIBUTION_TIME_MISMATCH
  implicit none

  type(fmr30_test_parameters_t) :: parameters
  type(fmr_b110_physical_forcing_t) :: forcing, bad_forcing
  type(fmr30_test_model_t), target :: model
  type(kernel_executor_t) :: kernel
  type(kernel_committed_state_t) :: committed
  type(kernel_checkpoint_t) :: checkpoint
  type(kernel_candidate_state_t) :: candidate
  type(kernel_result_t) :: result
  type(kernel_diagnostics_t) :: diagnostics
  type(canonical_numerical_config_t) :: config
  type(fmr_prepared_root_uptake_attribution_t) :: prepared, bad_prepared
  type(fmr_root_uptake_attribution_receipt_t) :: attribution
  type(fmr_accepted_commit_receipt_t) :: commit_receipt, empty_receipt, mismatch_receipt, time_receipt
  logical :: ok, did_commit, available
  integer :: status, receipt_status, commit_status
  real(real64) :: t0, t1, expected, rt0, rt1

  t0 = 2.0_real64
  t1 = 4.5_real64
  allocate(forcing%root_extraction_sink(3))
  forcing%root_extraction_sink = [0.1_real64, 0.2_real64, 0.3_real64]
  expected = sum(forcing%root_extraction_sink) * (t1 - t0)

  call initialize_committed(committed, 701_int64, t0)
  call kernel%bind_model(model)
  call committed%capture_checkpoint(checkpoint, ok)
  call assert_true(ok, 'checkpoint capture')
  call kernel%advance_interval(parameters, committed, forcing, config, t0, t1, result, candidate, diagnostics, checkpoint)
  call assert_true(result%completed, 'candidate result completion')
  call assert_true(candidate%ready(), 'candidate ready')
  call assert_close(result%mass%total_out, expected, 'transaction root mass_out')
  call assert_close(result%mass%residual, 0.0_real64, 'transaction hard mass residual')

  allocate(bad_forcing%root_extraction_sink(3))
  bad_forcing%root_extraction_sink = forcing%root_extraction_sink
  bad_forcing%root_extraction_sink(2) = -0.01_real64
  call fmr_prepare_root_uptake_attribution(bad_forcing, candidate, bad_prepared, status)
  call assert_true(status == FMR_ROOT_ATTRIBUTION_INVALID_FORCING .and. .not. bad_prepared%ready(), &
       'negative qrot fail closed')
  print '(a)', 'FMR30_INVALID_ROOT_FORCING_FAIL_CLOSED=PASS'

  call fmr_prepare_root_uptake_attribution(forcing, candidate, prepared, status)
  call assert_true(status == FMR_ROOT_ATTRIBUTION_OK .and. prepared%ready(), 'prepare attribution')
  call fmr_finalize_root_uptake_attribution(prepared, empty_receipt, attribution, status)
  call assert_true(status == FMR_ROOT_ATTRIBUTION_INVALID_COMMIT_RECEIPT .and. .not. attribution%ready(), &
       'precommit publication rejection')
  print '(a)', 'FMR30_PRECOMMIT_PUBLICATION_REJECTED=PASS'

  call build_other_receipt(702_int64, t0, t1, forcing, mismatch_receipt)
  call fmr_finalize_root_uptake_attribution(prepared, mismatch_receipt, attribution, status)
  call assert_true(status == FMR_ROOT_ATTRIBUTION_PROVENANCE_MISMATCH .and. .not. attribution%ready(), &
       'provenance mismatch')
  print '(a)', 'FMR30_PROVENANCE_MISMATCH_FAIL_CLOSED=PASS'

  call build_other_receipt(701_int64, t0, 5.0_real64, forcing, time_receipt)
  call fmr_finalize_root_uptake_attribution(prepared, time_receipt, attribution, status)
  call assert_true(status == FMR_ROOT_ATTRIBUTION_TIME_MISMATCH .and. .not. attribution%ready(), 'time mismatch')
  print '(a)', 'FMR30_TIME_MISMATCH_FAIL_CLOSED=PASS'

  call fmr_commit_candidate_with_receipt(kernel, checkpoint, committed, candidate, diagnostics, did_commit, &
       commit_receipt, receipt_status, commit_status)
  call assert_true(did_commit .and. receipt_status == FMR_COMMIT_RECEIPT_OK, 'real commit receipt')
  call assert_true(commit_status == KERNEL_COMMIT_STATUS_COMMITTED .and. commit_receipt%ready(), 'commit status')

  call fmr_finalize_root_uptake_attribution(prepared, commit_receipt, attribution, status)
  call assert_true(status == FMR_ROOT_ATTRIBUTION_OK .and. attribution%ready(), 'postcommit attribution')
  call assert_true(attribution%current_lineage_id() == 701_int64, 'lineage')
  call assert_true(attribution%origin_revision() == 0_int64 .and. attribution%committed_revision() == 1_int64, 'revision')
  call attribution%origin_interval(rt0, rt1, available)
  call assert_true(available, 'attribution interval available')
  call assert_close(rt0, t0, 'attribution t0')
  call assert_close(rt1, t1, 'attribution t1')
  call assert_close(attribution%actual_transpiration_amount(), expected, 'actual transpiration amount')
  call assert_close(attribution%actual_transpiration_amount(), result%mass%total_out, 'mass reconciliation')
  call assert_true(committed%current_revision() == 1_int64, 'committed revision')
  call committed%current_time(rt1, available)
  call assert_true(available, 'committed time available')
  call assert_close(rt1, t1, 'committed time')

  print '(a)', 'FMR30_REAL_COMMIT_ROOT_ATTRIBUTION=PASS'
  print '(a)', 'FMR30_ATTRIBUTION_EQUALS_ALREADY_BOOKED_ROOT_MASS_OUT=PASS'
  print '(a)', 'FMR30_NO_DUPLICATE_MASS_BOOKING=PASS'
  print '(a)', 'FMR30_ROOT_UPTAKE_ATTRIBUTION_RECEIPT_TEST PASS'

contains

  subroutine initialize_committed(state, lineage, initial_time)
    type(kernel_committed_state_t), intent(out) :: state
    integer(int64), intent(in) :: lineage
    real(real64), intent(in) :: initial_time
    class(transaction_state_t), allocatable :: physical
    logical :: initialized

    allocate(fmr30_test_physical_state_t :: physical)
    select type (physical)
    type is (fmr30_test_physical_state_t)
      physical%storage_value = 10.0_real64
    end select
    call state%initialize(lineage, physical, initialized, initial_time)
    call assert_true(initialized, 'committed initialize')
  end subroutine initialize_committed

  subroutine build_other_receipt(lineage, start_time, end_time, local_forcing, receipt)
    integer(int64), intent(in) :: lineage
    real(real64), intent(in) :: start_time, end_time
    type(fmr_b110_physical_forcing_t), intent(in) :: local_forcing
    type(fmr_accepted_commit_receipt_t), intent(out) :: receipt
    type(kernel_committed_state_t) :: local_committed
    type(kernel_checkpoint_t) :: local_checkpoint
    type(kernel_candidate_state_t) :: local_candidate
    type(kernel_result_t) :: local_result
    type(kernel_diagnostics_t) :: local_diag
    type(kernel_executor_t) :: local_kernel
    type(fmr30_test_model_t), target :: local_model
    logical :: local_ok, local_commit
    integer :: local_receipt_status, local_commit_status

    call initialize_committed(local_committed, lineage, start_time)
    call local_kernel%bind_model(local_model)
    call local_committed%capture_checkpoint(local_checkpoint, local_ok)
    call assert_true(local_ok, 'other checkpoint')
    call local_kernel%advance_interval(parameters, local_committed, local_forcing, config, start_time, end_time, &
         local_result, local_candidate, local_diag, local_checkpoint)
    call assert_true(local_result%completed, 'other candidate result completion')
    call assert_true(local_candidate%ready(), 'other candidate ready')
    call fmr_commit_candidate_with_receipt(local_kernel, local_checkpoint, local_committed, local_candidate, local_diag, &
         local_commit, receipt, local_receipt_status, local_commit_status)
    call assert_true(local_commit .and. local_receipt_status == FMR_COMMIT_RECEIPT_OK .and. receipt%ready(), 'other receipt')
  end subroutine build_other_receipt

  subroutine assert_true(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,1x,a)') 'FMR30_ASSERT_FAIL', trim(label)
      error stop 1
    end if
  end subroutine assert_true

  subroutine assert_close(actual, expected_value, label)
    real(real64), intent(in) :: actual, expected_value
    character(len=*), intent(in) :: label
    real(real64) :: tol
    tol = 256.0_real64 * epsilon(1.0_real64) * max(1.0_real64, abs(actual), abs(expected_value))
    call assert_true(abs(actual - expected_value) <= tol, label)
  end subroutine assert_close

end program test_fmr30_root_uptake_attribution_receipt
