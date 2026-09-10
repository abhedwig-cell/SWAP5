program test_fvq48_forcing_candidate_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_executor_t, kernel_result_t, kernel_diagnostics_t, KERNEL_COMMIT_STATUS_COMMITTED
  use mod_fmr_serialized_reference_backend, only: fvq48_physical_state_t, fvq48_parameters_t, fvq48_model_t, &
       fmr_b110_physical_forcing_t
  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t, fmr_commit_candidate_with_receipt, &
       FMR_COMMIT_RECEIPT_OK
  use mod_fmr_root_uptake_attribution_receipt, only: fmr_prepared_root_uptake_attribution_t, &
       fmr_root_uptake_attribution_receipt_t, fmr_prepare_root_uptake_attribution, &
       fmr_finalize_root_uptake_attribution, FMR_ROOT_ATTRIBUTION_OK
  implicit none

  type(fvq48_parameters_t) :: parameters
  type(fmr_b110_physical_forcing_t) :: forcing_a, forcing_b
  type(fvq48_model_t), target :: model
  type(kernel_executor_t) :: kernel
  type(kernel_committed_state_t) :: committed
  type(kernel_checkpoint_t) :: checkpoint
  type(kernel_candidate_state_t) :: candidate
  type(kernel_result_t) :: result
  type(kernel_diagnostics_t) :: diagnostics
  type(canonical_numerical_config_t) :: config
  type(fmr_prepared_root_uptake_attribution_t) :: prepared_a, prepared_b
  type(fmr_root_uptake_attribution_receipt_t) :: attribution_a, attribution_b
  type(fmr_accepted_commit_receipt_t) :: commit_receipt
  logical :: ok, did_commit, wrong_prepare_accepted, wrong_publication
  integer :: status_a, status_b, receipt_status, commit_status
  real(real64) :: t0, t1, expected_a, expected_b, published_b

  t0 = 1.25_real64
  t1 = 4.0_real64
  allocate(forcing_a%root_extraction_sink(3), forcing_b%root_extraction_sink(3))
  forcing_a%root_extraction_sink = [0.125_real64, 0.25_real64, 0.5_real64]
  forcing_b%root_extraction_sink = [0.25_real64, 0.5_real64, 0.75_real64]
  expected_a = sum(forcing_a%root_extraction_sink) * (t1 - t0)
  expected_b = sum(forcing_b%root_extraction_sink) * (t1 - t0)

  call initialize_committed(committed, 4801_int64, t0)
  call kernel%bind_model(model)
  call committed%capture_checkpoint(checkpoint, ok)
  call assert_true(ok, 'checkpoint capture')

  ! Physical candidate A is created exclusively with forcing A.
  call kernel%advance_interval(parameters, committed, forcing_a, config, t0, t1, result, candidate, diagnostics, checkpoint)
  call assert_true(result%completed, 'candidate A completion')
  call assert_true(candidate%ready(), 'candidate A ready')
  call assert_close(result%mass%total_out, expected_a, 'candidate A transaction mass_out')
  call assert_close(result%mass%residual, 0.0_real64, 'candidate A hard mass residual')

  ! Positive control: prepare the physically matching forcing A.
  call fmr_prepare_root_uptake_attribution(forcing_a, candidate, prepared_a, status_a)
  call assert_true(status_a == FMR_ROOT_ATTRIBUTION_OK, 'prepare A status')
  call assert_true(prepared_a%ready(), 'prepare A ready')

  ! Independent hard-negative attack: the same physical candidate is paired
  ! with a different, individually valid and immutable forcing vector B.
  call fmr_prepare_root_uptake_attribution(forcing_b, candidate, prepared_b, status_b)
  wrong_prepare_accepted = status_b == FMR_ROOT_ATTRIBUTION_OK .and. prepared_b%ready()

  call fmr_commit_candidate_with_receipt(kernel, checkpoint, committed, candidate, diagnostics, did_commit, &
       commit_receipt, receipt_status, commit_status)
  call assert_true(did_commit, 'physical candidate A commit')
  call assert_true(receipt_status == FMR_COMMIT_RECEIPT_OK, 'generic accepted receipt')
  call assert_true(commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'generic commit status')
  call assert_true(commit_receipt%ready(), 'generic receipt ready')

  call fmr_finalize_root_uptake_attribution(prepared_a, commit_receipt, attribution_a, status_a)
  call assert_true(status_a == FMR_ROOT_ATTRIBUTION_OK, 'correct A finalize status')
  call assert_true(attribution_a%ready(), 'correct A attribution ready')
  call assert_close(attribution_a%actual_transpiration_amount(), expected_a, 'correct A attribution amount')
  call assert_close(attribution_a%actual_transpiration_amount(), result%mass%total_out, 'correct A mass reconciliation')
  print '(a)', 'FVQ48_VALID_MATCHING_FORCING_CONTROL=PASS'

  call fmr_finalize_root_uptake_attribution(prepared_b, commit_receipt, attribution_b, status_b)
  published_b = attribution_b%actual_transpiration_amount()
  wrong_publication = wrong_prepare_accepted .and. status_b == FMR_ROOT_ATTRIBUTION_OK .and. attribution_b%ready() .and. &
       close_value(published_b, expected_b) .and. .not. close_value(published_b, result%mass%total_out)

  write(*,'(a,es24.16)') 'FVQ48_PHYSICAL_CANDIDATE_A_ROOT_MASS_OUT=', result%mass%total_out
  write(*,'(a,es24.16)') 'FVQ48_MISMATCHED_FORCING_B_DERIVED_AMOUNT=', expected_b
  write(*,'(a,l1)') 'FVQ48_WRONG_FORCING_PREPARE_ACCEPTED=', wrong_prepare_accepted
  write(*,'(a,l1)') 'FVQ48_WRONG_FORCING_POSTCOMMIT_PUBLISHED=', wrong_publication

  if (wrong_publication) then
    print '(a)', 'FVQ48_HN1_FORCING_CANDIDATE_BINDING=FAIL_OPEN'
    print '(a)', 'FVQ48_FINDING=VALID_COMMIT_RECEIPT_CAN_PUBLISH_ATTRIBUTION_FROM_QROT_NOT_USED_BY_PHYSICAL_CANDIDATE'
  else
    print '(a)', 'FVQ48_HN1_FORCING_CANDIDATE_BINDING=FAIL_CLOSED'
  end if

contains

  subroutine initialize_committed(state, lineage, initial_time)
    type(kernel_committed_state_t), intent(out) :: state
    integer(int64), intent(in) :: lineage
    real(real64), intent(in) :: initial_time
    class(transaction_state_t), allocatable :: physical
    logical :: initialized

    allocate(fvq48_physical_state_t :: physical)
    select type (physical)
    type is (fvq48_physical_state_t)
      physical%storage = 100.0_real64
    end select
    call state%initialize(lineage, physical, initialized, initial_time)
    call assert_true(initialized, 'committed initialize')
  end subroutine initialize_committed

  subroutine assert_true(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,1x,a)') 'FVQ48_CONTROL_ASSERT_FAIL', trim(label)
      error stop 1
    end if
  end subroutine assert_true

  subroutine assert_close(actual, expected, label)
    real(real64), intent(in) :: actual, expected
    character(len=*), intent(in) :: label
    call assert_true(close_value(actual, expected), label)
  end subroutine assert_close

  pure logical function close_value(a, b) result(close)
    real(real64), intent(in) :: a, b
    real(real64) :: tol
    tol = 256.0_real64 * epsilon(1.0_real64) * max(1.0_real64, abs(a), abs(b))
    close = abs(a-b) <= tol
  end function close_value

end program test_fvq48_forcing_candidate_binding
