program test_fvq48_independent_root_uptake_attribution
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_quiet_nan, ieee_value
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_executor_t, kernel_result_t, kernel_diagnostics_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_forcing_t
  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t, fmr_commit_candidate_with_receipt, &
       FMR_COMMIT_RECEIPT_OK
  use mod_fmr_root_uptake_attribution_receipt, only: fmr_prepared_root_uptake_attribution_t, &
       fmr_root_uptake_attribution_receipt_t, fmr_prepare_root_uptake_attribution, &
       fmr_finalize_root_uptake_attribution, FMR_ROOT_ATTRIBUTION_OK, FMR_ROOT_ATTRIBUTION_INVALID_FORCING, &
       FMR_ROOT_ATTRIBUTION_INVALID_COMMIT_RECEIPT, FMR_ROOT_ATTRIBUTION_PROVENANCE_MISMATCH, &
       FMR_ROOT_ATTRIBUTION_TIME_MISMATCH
  use mod_fvq48_independent_root_mass_model, only: fvq48_independent_state_t, fvq48_independent_parameters_t, &
       fvq48_independent_model_t
  implicit none

  type(canonical_numerical_config_t) :: config
  type(fvq48_independent_parameters_t) :: parameters
  type(fvq48_independent_model_t), target :: model
  type(kernel_executor_t) :: kernel
  type(kernel_committed_state_t) :: committed
  type(kernel_checkpoint_t) :: checkpoint
  type(kernel_candidate_state_t) :: candidate
  type(kernel_result_t) :: result
  type(kernel_diagnostics_t) :: diagnostics
  type(fmr_b110_physical_forcing_t) :: forcing_a, forcing_b, bad_forcing, nan_forcing
  type(fmr_prepared_root_uptake_attribution_t) :: prepared_a1, prepared_b, prepared_a2, bad_prepared
  type(fmr_root_uptake_attribution_receipt_t) :: attr_a1, attr_b, attr_a2, rejected_attr
  type(fmr_accepted_commit_receipt_t) :: empty_receipt, commit_receipt, wrong_lineage_receipt, &
       wrong_revision_receipt, wrong_time_receipt
  logical :: ok, did_commit, candidate_ready
  integer :: status, receipt_status, commit_status
  real(real64) :: amount_a, amount_b
  real(real64), parameter :: t0 = 3.125_real64, t1 = 5.875_real64

  config%transaction%mass_tolerance = 1.0e-11_real64
  config%transaction%temporal_tolerance = 1.0e-11_real64
  config%max_committed_substeps = 128

  call run_case(1, 48001_int64, -0.375_real64, 0.125_real64, &
       [0.0_real64, 0.0_real64, 0.0_real64], config)
  call run_case(2, 48002_int64, 2.75_real64, 2.78125_real64, &
       [0.0_real64, 0.12_real64, 0.0_real64, 0.03_real64], config)
  call run_case(3, 48003_int64, 100.125_real64, 103.875_real64, &
       [0.001_real64, 0.25_real64, 0.0004_real64, 0.8_real64, 0.002_real64], config)
  call run_case(4, 48004_int64, 0.0_real64, 17.25_real64, &
       [12.0_real64, 0.5_real64], config)
  call run_case(5, 48005_int64, 10000.5_real64, 10000.500001_real64, &
       [1.0e-14_real64, 2.0e-14_real64], config)
  print '(a)', 'FVQ48_INDEPENDENT_QROT_INTERVAL_MATRIX=PASS'

  allocate(forcing_a%root_extraction_sink(4))
  forcing_a%root_extraction_sink = [0.04_real64, 0.0_real64, 0.16_real64, 0.02_real64]
  allocate(forcing_b%root_extraction_sink(4))
  forcing_b%root_extraction_sink = [0.40_real64, 0.10_real64, 0.00_real64, 0.30_real64]
  amount_a = sum(forcing_a%root_extraction_sink) * (t1 - t0)
  amount_b = sum(forcing_b%root_extraction_sink) * (t1 - t0)
  call assert_true(abs(amount_a - amount_b) > 1.0e-6_real64, 'A and B must differ')

  call initialize_committed(committed, 48100_int64, t0)
  call kernel%bind_model(model)
  call committed%capture_checkpoint(checkpoint, ok)
  call assert_true(ok, 'main checkpoint')
  call kernel%advance_interval(parameters, committed, forcing_a, config, t0, t1, result, candidate, diagnostics, checkpoint)
  call assert_true(result%completed, 'main result completion')
  candidate_ready = candidate%ready()
  call assert_true(candidate_ready, 'main candidate ready')
  call assert_close(result%mass%total_out, amount_a, 'independently booked qrot mass_out')
  call assert_close(result%mass%residual, 0.0_real64, 'main mass residual')

  allocate(bad_forcing%root_extraction_sink(2))
  bad_forcing%root_extraction_sink = [0.1_real64, -0.01_real64]
  call fmr_prepare_root_uptake_attribution(bad_forcing, candidate, bad_prepared, status)
  call assert_true(status == FMR_ROOT_ATTRIBUTION_INVALID_FORCING, 'negative forcing status')
  call assert_true(.not. bad_prepared%ready(), 'negative forcing not prepared')

  allocate(nan_forcing%root_extraction_sink(2))
  nan_forcing%root_extraction_sink = [0.1_real64, ieee_value(0.0_real64, ieee_quiet_nan)]
  call fmr_prepare_root_uptake_attribution(nan_forcing, candidate, bad_prepared, status)
  call assert_true(status == FMR_ROOT_ATTRIBUTION_INVALID_FORCING, 'NaN forcing status')
  call assert_true(.not. bad_prepared%ready(), 'NaN forcing not prepared')
  deallocate(nan_forcing%root_extraction_sink)
  call fmr_prepare_root_uptake_attribution(nan_forcing, candidate, bad_prepared, status)
  call assert_true(status == FMR_ROOT_ATTRIBUTION_INVALID_FORCING, 'unallocated forcing status')
  call assert_true(.not. bad_prepared%ready(), 'unallocated forcing not prepared')
  print '(a)', 'FVQ48_INVALID_FORCING_FAIL_CLOSED=PASS'

  call fmr_prepare_root_uptake_attribution(forcing_a, candidate, prepared_a1, status)
  call assert_true(status == FMR_ROOT_ATTRIBUTION_OK, 'prepare A1')
  call assert_true(prepared_a1%ready(), 'prepared A1 ready')
  call fmr_prepare_root_uptake_attribution(forcing_b, candidate, prepared_b, status)
  call assert_true(status == FMR_ROOT_ATTRIBUTION_OK, 'prepare B')
  call assert_true(prepared_b%ready(), 'prepared B ready')
  call fmr_prepare_root_uptake_attribution(forcing_a, candidate, prepared_a2, status)
  call assert_true(status == FMR_ROOT_ATTRIBUTION_OK, 'prepare A2')
  call assert_true(prepared_a2%ready(), 'prepared A2 ready')

  call fmr_finalize_root_uptake_attribution(prepared_a1, empty_receipt, rejected_attr, status)
  call assert_true(status == FMR_ROOT_ATTRIBUTION_INVALID_COMMIT_RECEIPT, 'precommit rejected')
  call assert_true(.not. rejected_attr%ready(), 'precommit not published')
  print '(a)', 'FVQ48_PRECOMMIT_PUBLICATION_FAIL_CLOSED=PASS'

  call build_receipt(49999_int64, t0, t1, forcing_a%root_extraction_sink, config, wrong_lineage_receipt)
  call fmr_finalize_root_uptake_attribution(prepared_a1, wrong_lineage_receipt, rejected_attr, status)
  call assert_true(status == FMR_ROOT_ATTRIBUTION_PROVENANCE_MISMATCH, 'wrong lineage rejected')
  call assert_true(.not. rejected_attr%ready(), 'wrong lineage no publication')

  call build_revision_one_receipt(48100_int64, t0, t1, forcing_a%root_extraction_sink, config, wrong_revision_receipt)
  call assert_true(wrong_revision_receipt%origin_revision() == 1_int64, 'revision-one control')
  call fmr_finalize_root_uptake_attribution(prepared_a1, wrong_revision_receipt, rejected_attr, status)
  call assert_true(status == FMR_ROOT_ATTRIBUTION_PROVENANCE_MISMATCH, 'wrong revision rejected')
  call assert_true(.not. rejected_attr%ready(), 'wrong revision no publication')
  print '(a)', 'FVQ48_LINEAGE_REVISION_MISMATCH_FAIL_CLOSED=PASS'

  call build_receipt(48100_int64, t0 + 0.25_real64, t1 + 0.25_real64, &
       forcing_a%root_extraction_sink, config, wrong_time_receipt)
  call fmr_finalize_root_uptake_attribution(prepared_a1, wrong_time_receipt, rejected_attr, status)
  call assert_true(status == FMR_ROOT_ATTRIBUTION_TIME_MISMATCH, 'wrong interval rejected')
  call assert_true(.not. rejected_attr%ready(), 'wrong interval no publication')
  print '(a)', 'FVQ48_INTERVAL_MISMATCH_FAIL_CLOSED=PASS'

  call fmr_commit_candidate_with_receipt(kernel, checkpoint, committed, candidate, diagnostics, did_commit, &
       commit_receipt, receipt_status, commit_status)
  call assert_true(did_commit, 'main commit')
  call assert_true(receipt_status == FMR_COMMIT_RECEIPT_OK, 'main commit receipt status')
  call assert_true(commit_receipt%ready(), 'main commit receipt ready')

  call fmr_finalize_root_uptake_attribution(prepared_a1, commit_receipt, attr_a1, status)
  call assert_true(status == FMR_ROOT_ATTRIBUTION_OK, 'A1 finalize')
  call fmr_finalize_root_uptake_attribution(prepared_b, commit_receipt, attr_b, status)
  call assert_true(status == FMR_ROOT_ATTRIBUTION_OK, 'B finalize')
  call fmr_finalize_root_uptake_attribution(prepared_a2, commit_receipt, attr_a2, status)
  call assert_true(status == FMR_ROOT_ATTRIBUTION_OK, 'A2 finalize')
  call assert_true(attr_a1%ready() .and. attr_b%ready() .and. attr_a2%ready(), 'A-B-A receipts ready')
  call assert_close(attr_a1%actual_transpiration_amount(), amount_a, 'A1 amount')
  call assert_close(attr_a2%actual_transpiration_amount(), amount_a, 'A2 amount')
  call assert_close(attr_b%actual_transpiration_amount(), amount_b, 'B amount')
  call assert_close(attr_a1%actual_transpiration_amount(), result%mass%total_out, 'correct forcing reconciliation')
  call assert_true(abs(attr_b%actual_transpiration_amount() - result%mass%total_out) > 1.0e-6_real64, &
       'valid mismatched forcing must expose pairing gap')
  print '(a)', 'FVQ48_A_B_A_PREPARED_CONTEXT_INDEPENDENCE=PASS'
  print '(a)', 'FVQ48_CORRECT_PAIRING_RECONCILES_WITH_BOOKED_ROOT_MASS=PASS'
  print '(a)', 'FVQ48_VALID_FORCING_MISPAIR_NOT_DETECTABLE=OBSERVED'
  print '(a)', 'FVQ48_STANDALONE_CALLER_PAIRING_PRECONDITION=UNENFORCED'
  print '(a)', 'FVQ48_INDEPENDENT_ROOT_UPTAKE_ATTRIBUTION_ORACLE PASS'

contains

  subroutine run_case(case_id, lineage, start_time, end_time, rates, local_config)
    integer, intent(in) :: case_id
    integer(int64), intent(in) :: lineage
    real(real64), intent(in) :: start_time, end_time, rates(:)
    type(canonical_numerical_config_t), intent(in) :: local_config
    type(fvq48_independent_parameters_t) :: local_parameters
    type(fvq48_independent_model_t), target :: local_model
    type(kernel_executor_t) :: local_kernel
    type(kernel_committed_state_t) :: local_committed
    type(kernel_checkpoint_t) :: local_checkpoint
    type(kernel_candidate_state_t) :: local_candidate
    type(kernel_result_t) :: local_result
    type(kernel_diagnostics_t) :: local_diagnostics
    type(fmr_b110_physical_forcing_t) :: local_forcing
    type(fmr_prepared_root_uptake_attribution_t) :: local_prepared
    type(fmr_root_uptake_attribution_receipt_t) :: local_attribution
    type(fmr_accepted_commit_receipt_t) :: local_receipt
    logical :: local_ok, local_commit, local_candidate_ready
    integer :: local_status, local_receipt_status
    real(real64) :: expected

    call assert_true(case_id > 0, 'case id')
    expected = sum(rates) * (end_time - start_time)
    allocate(local_forcing%root_extraction_sink(size(rates)))
    local_forcing%root_extraction_sink = rates
    call initialize_committed(local_committed, lineage, start_time)
    call local_kernel%bind_model(local_model)
    call local_committed%capture_checkpoint(local_checkpoint, local_ok)
    call assert_true(local_ok, 'case checkpoint')
    call local_kernel%advance_interval(local_parameters, local_committed, local_forcing, local_config, &
         start_time, end_time, local_result, local_candidate, local_diagnostics, local_checkpoint)
    call assert_true(local_result%completed, 'case completed')
    local_candidate_ready = local_candidate%ready()
    call assert_true(local_candidate_ready, 'case candidate')
    call assert_close(local_result%mass%total_out, expected, 'case independently booked mass_out')
    call assert_close(local_result%mass%residual, 0.0_real64, 'case mass residual')
    call fmr_prepare_root_uptake_attribution(local_forcing, local_candidate, local_prepared, local_status)
    call assert_true(local_status == FMR_ROOT_ATTRIBUTION_OK, 'case prepare')
    call fmr_commit_candidate_with_receipt(local_kernel, local_checkpoint, local_committed, local_candidate, &
         local_diagnostics, local_commit, local_receipt, local_receipt_status)
    call assert_true(local_commit .and. local_receipt_status == FMR_COMMIT_RECEIPT_OK, 'case commit')
    call fmr_finalize_root_uptake_attribution(local_prepared, local_receipt, local_attribution, local_status)
    call assert_true(local_status == FMR_ROOT_ATTRIBUTION_OK, 'case finalize')
    call assert_true(local_attribution%ready(), 'case attribution ready')
    call assert_close(local_attribution%actual_transpiration_amount(), expected, 'case amount')
    call assert_close(local_attribution%actual_transpiration_amount(), local_result%mass%total_out, &
         'case root mass reconciliation')
  end subroutine run_case

  subroutine initialize_committed(state, lineage, initial_time)
    type(kernel_committed_state_t), intent(out) :: state
    integer(int64), intent(in) :: lineage
    real(real64), intent(in) :: initial_time
    class(transaction_state_t), allocatable :: physical
    logical :: initialized

    allocate(fvq48_independent_state_t :: physical)
    select type (physical)
    type is (fvq48_independent_state_t)
      physical%storage_value = 1000.0_real64
    end select
    call state%initialize(lineage, physical, initialized, initial_time)
    call assert_true(initialized, 'committed initialization')
  end subroutine initialize_committed

  subroutine build_receipt(lineage, start_time, end_time, rates, local_config, receipt)
    integer(int64), intent(in) :: lineage
    real(real64), intent(in) :: start_time, end_time, rates(:)
    type(canonical_numerical_config_t), intent(in) :: local_config
    type(fmr_accepted_commit_receipt_t), intent(out) :: receipt
    type(fvq48_independent_parameters_t) :: local_parameters
    type(fvq48_independent_model_t), target :: local_model
    type(kernel_executor_t) :: local_kernel
    type(kernel_committed_state_t) :: local_committed
    type(kernel_checkpoint_t) :: local_checkpoint
    type(kernel_candidate_state_t) :: local_candidate
    type(kernel_result_t) :: local_result
    type(kernel_diagnostics_t) :: local_diagnostics
    type(fmr_b110_physical_forcing_t) :: local_forcing
    logical :: local_ok, local_commit, local_candidate_ready
    integer :: local_receipt_status

    allocate(local_forcing%root_extraction_sink(size(rates)))
    local_forcing%root_extraction_sink = rates
    call initialize_committed(local_committed, lineage, start_time)
    call local_kernel%bind_model(local_model)
    call local_committed%capture_checkpoint(local_checkpoint, local_ok)
    call assert_true(local_ok, 'receipt checkpoint')
    call local_kernel%advance_interval(local_parameters, local_committed, local_forcing, local_config, &
         start_time, end_time, local_result, local_candidate, local_diagnostics, local_checkpoint)
    call assert_true(local_result%completed, 'receipt candidate complete')
    local_candidate_ready = local_candidate%ready()
    call assert_true(local_candidate_ready, 'receipt candidate ready')
    call fmr_commit_candidate_with_receipt(local_kernel, local_checkpoint, local_committed, local_candidate, &
         local_diagnostics, local_commit, receipt, local_receipt_status)
    call assert_true(local_commit .and. local_receipt_status == FMR_COMMIT_RECEIPT_OK, 'receipt build commit')
  end subroutine build_receipt

  subroutine build_revision_one_receipt(lineage, start_time, end_time, rates, local_config, receipt)
    integer(int64), intent(in) :: lineage
    real(real64), intent(in) :: start_time, end_time, rates(:)
    type(canonical_numerical_config_t), intent(in) :: local_config
    type(fmr_accepted_commit_receipt_t), intent(out) :: receipt
    type(fvq48_independent_parameters_t) :: local_parameters
    type(fvq48_independent_model_t), target :: local_model
    type(kernel_executor_t) :: local_kernel
    type(kernel_committed_state_t) :: local_committed
    type(kernel_checkpoint_t) :: local_checkpoint
    type(kernel_candidate_state_t) :: local_candidate
    type(kernel_result_t) :: local_result
    type(kernel_diagnostics_t) :: local_diagnostics
    type(fmr_b110_physical_forcing_t) :: local_forcing
    type(fmr_accepted_commit_receipt_t) :: first_receipt
    logical :: local_ok, local_commit, local_candidate_ready
    integer :: local_receipt_status
    real(real64) :: midpoint

    midpoint = start_time + 0.2_real64 * (end_time - start_time)
    allocate(local_forcing%root_extraction_sink(size(rates)))
    local_forcing%root_extraction_sink = rates
    call initialize_committed(local_committed, lineage, start_time)
    call local_kernel%bind_model(local_model)

    call local_committed%capture_checkpoint(local_checkpoint, local_ok)
    call assert_true(local_ok, 'revision first checkpoint')
    call local_kernel%advance_interval(local_parameters, local_committed, local_forcing, local_config, &
         start_time, midpoint, local_result, local_candidate, local_diagnostics, local_checkpoint)
    call assert_true(local_result%completed, 'revision first candidate complete')
    local_candidate_ready = local_candidate%ready()
    call assert_true(local_candidate_ready, 'revision first candidate ready')
    call fmr_commit_candidate_with_receipt(local_kernel, local_checkpoint, local_committed, local_candidate, &
         local_diagnostics, local_commit, first_receipt, local_receipt_status)
    call assert_true(local_commit .and. local_receipt_status == FMR_COMMIT_RECEIPT_OK, 'revision first commit')

    call local_committed%capture_checkpoint(local_checkpoint, local_ok)
    call assert_true(local_ok, 'revision second checkpoint')
    call local_kernel%advance_interval(local_parameters, local_committed, local_forcing, local_config, &
         midpoint, end_time, local_result, local_candidate, local_diagnostics, local_checkpoint)
    call assert_true(local_result%completed, 'revision second candidate complete')
    local_candidate_ready = local_candidate%ready()
    call assert_true(local_candidate_ready, 'revision second candidate ready')
    call fmr_commit_candidate_with_receipt(local_kernel, local_checkpoint, local_committed, local_candidate, &
         local_diagnostics, local_commit, receipt, local_receipt_status)
    call assert_true(local_commit .and. local_receipt_status == FMR_COMMIT_RECEIPT_OK, 'revision second commit')
  end subroutine build_revision_one_receipt

  subroutine assert_true(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,1x,a)') 'FVQ48_ASSERT_FAIL', trim(label)
      error stop 1
    end if
  end subroutine assert_true

  subroutine assert_close(actual, expected, label)
    real(real64), intent(in) :: actual, expected
    character(len=*), intent(in) :: label
    real(real64) :: tol

    tol = 512.0_real64 * epsilon(1.0_real64) * max(1.0_real64, abs(actual), abs(expected))
    call assert_true(abs(actual - expected) <= tol, label)
  end subroutine assert_close

end program test_fvq48_independent_root_uptake_attribution
