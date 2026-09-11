program test_fpm06g_surface_evaporation_accepted_publication
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_executor_t, kernel_result_t, kernel_diagnostics_t, KERNEL_COMMIT_STATUS_COMMITTED
  use mod_restricted_surface_evaporation, only: surface_evaporation_result_t, SURFACE_EVAP_AVAILABLE
  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t, fmr_commit_candidate_with_receipt, &
       FMR_COMMIT_RECEIPT_OK
  use mod_fmr_surface_evaporation_accepted_publication, only: &
       fmr_prepared_surface_evaporation_publication_t, fmr_surface_evaporation_publication_t, &
       fmr_prepare_surface_evaporation_publication, fmr_finalize_surface_evaporation_publication, &
       FMR_SURFACE_EVAP_PUBLICATION_OK, FMR_SURFACE_EVAP_PUBLICATION_INVALID_RESULT, &
       FMR_SURFACE_EVAP_PUBLICATION_INVALID_COMMIT_RECEIPT, &
       FMR_SURFACE_EVAP_PUBLICATION_PROVENANCE_MISMATCH, FMR_SURFACE_EVAP_PUBLICATION_TIME_MISMATCH
  use mod_fpm06g_publication_test_backend, only: fpm06g_test_state_t, fpm06g_test_parameters_t, &
       fpm06g_test_forcing_t, fpm06g_test_model_t
  implicit none

  type(fpm06g_test_parameters_t) :: parameters
  type(fpm06g_test_forcing_t) :: forcing
  type(fpm06g_test_model_t), target :: model
  type(kernel_executor_t) :: kernel
  type(kernel_committed_state_t) :: committed
  type(kernel_checkpoint_t) :: checkpoint
  type(kernel_candidate_state_t) :: candidate
  type(kernel_result_t) :: kernel_result
  type(kernel_diagnostics_t) :: diagnostics
  type(canonical_numerical_config_t) :: config
  type(surface_evaporation_result_t) :: dry_result, ponded_result, invalid_result
  type(fmr_prepared_surface_evaporation_publication_t) :: dry_prepared, ponded_prepared, invalid_prepared
  type(fmr_surface_evaporation_publication_t) :: publication
  type(fmr_accepted_commit_receipt_t) :: commit_receipt, empty_receipt, lineage_receipt, revision_receipt, time_receipt
  logical :: ok, did_commit, available
  integer :: status, receipt_status, commit_status
  real(real64) :: t0, t1, rt0, rt1

  t0 = 2.0_real64
  t1 = 4.5_real64
  call initialize_committed(committed, 901_int64, t0)
  call kernel%bind_model(model)
  call committed%capture_checkpoint(checkpoint, ok)
  call require(ok, 'checkpoint capture')
  call kernel%advance_interval(parameters, committed, forcing, config, t0, t1, kernel_result, candidate, diagnostics, checkpoint)
  call require(kernel_result%completed .and. kernel_result%mass%complete, 'candidate completion and mass')
  call require(candidate%ready(), 'candidate ready')

  dry_result = surface_evaporation_result_t()
  dry_result%status = SURFACE_EVAP_AVAILABLE
  dry_result%bare_soil_evaporation = 0.31_real64
  dry_result%ponded_water_evaporation = 0.0_real64
  dry_result%route = 'dry'

  ponded_result = surface_evaporation_result_t()
  ponded_result%status = SURFACE_EVAP_AVAILABLE
  ponded_result%bare_soil_evaporation = 0.0_real64
  ponded_result%ponded_water_evaporation = 0.47_real64
  ponded_result%route = 'ponded'

  invalid_result = dry_result
  invalid_result%bare_soil_evaporation = -0.01_real64
  call fmr_prepare_surface_evaporation_publication(invalid_result, candidate, invalid_prepared, status)
  call require(status == FMR_SURFACE_EVAP_PUBLICATION_INVALID_RESULT .and. .not. invalid_prepared%ready(), &
       'negative rate fail closed')
  invalid_result = dry_result
  invalid_result%bare_soil_evaporation = ieee_value(0.0_real64, ieee_quiet_nan)
  call fmr_prepare_surface_evaporation_publication(invalid_result, candidate, invalid_prepared, status)
  call require(status == FMR_SURFACE_EVAP_PUBLICATION_INVALID_RESULT .and. .not. invalid_prepared%ready(), &
       'nonfinite rate fail closed')
  invalid_result = dry_result
  invalid_result%ponded_water_evaporation = 0.1_real64
  call fmr_prepare_surface_evaporation_publication(invalid_result, candidate, invalid_prepared, status)
  call require(status == FMR_SURFACE_EVAP_PUBLICATION_INVALID_RESULT .and. .not. invalid_prepared%ready(), &
       'route decomposition mismatch fail closed')
  write(*,'(A)') 'FPM06G_INVALID_RESULT_FAIL_CLOSED=PASS'

  call fmr_prepare_surface_evaporation_publication(dry_result, candidate, dry_prepared, status)
  call require(status == FMR_SURFACE_EVAP_PUBLICATION_OK .and. dry_prepared%ready(), 'dry prepare')
  call fmr_prepare_surface_evaporation_publication(ponded_result, candidate, ponded_prepared, status)
  call require(status == FMR_SURFACE_EVAP_PUBLICATION_OK .and. ponded_prepared%ready(), 'ponded prepare')
  call require(committed%current_revision() == 0_int64, 'prepare must not commit')
  write(*,'(A)') 'FPM06G_DRY_AND_PONDED_PREPARATION=PASS'

  call fmr_finalize_surface_evaporation_publication(dry_prepared, empty_receipt, publication, status)
  call require(status == FMR_SURFACE_EVAP_PUBLICATION_INVALID_COMMIT_RECEIPT .and. .not. publication%ready(), &
       'precommit publication rejected')
  write(*,'(A)') 'FPM06G_PRECOMMIT_PUBLICATION_REJECTED=PASS'

  call build_receipt(902_int64, t0, t1, lineage_receipt)
  call fmr_finalize_surface_evaporation_publication(dry_prepared, lineage_receipt, publication, status)
  call require(status == FMR_SURFACE_EVAP_PUBLICATION_PROVENANCE_MISMATCH .and. .not. publication%ready(), &
       'lineage mismatch')
  write(*,'(A)') 'FPM06G_LINEAGE_MISMATCH_FAIL_CLOSED=PASS'

  call build_revision_one_receipt(901_int64, 1.0_real64, t0, t1, revision_receipt)
  call fmr_finalize_surface_evaporation_publication(dry_prepared, revision_receipt, publication, status)
  call require(status == FMR_SURFACE_EVAP_PUBLICATION_PROVENANCE_MISMATCH .and. .not. publication%ready(), &
       'revision mismatch')
  write(*,'(A)') 'FPM06G_REVISION_MISMATCH_FAIL_CLOSED=PASS'

  call build_receipt(901_int64, t0, 5.0_real64, time_receipt)
  call fmr_finalize_surface_evaporation_publication(dry_prepared, time_receipt, publication, status)
  call require(status == FMR_SURFACE_EVAP_PUBLICATION_TIME_MISMATCH .and. .not. publication%ready(), 'time mismatch')
  write(*,'(A)') 'FPM06G_TIME_MISMATCH_FAIL_CLOSED=PASS'

  call fmr_commit_candidate_with_receipt(kernel, checkpoint, committed, candidate, diagnostics, did_commit, &
       commit_receipt, receipt_status, commit_status)
  call require(did_commit .and. receipt_status == FMR_COMMIT_RECEIPT_OK, 'real commit receipt')
  call require(commit_status == KERNEL_COMMIT_STATUS_COMMITTED .and. commit_receipt%ready(), 'commit status')

  call fmr_finalize_surface_evaporation_publication(dry_prepared, commit_receipt, publication, status)
  call require(status == FMR_SURFACE_EVAP_PUBLICATION_OK .and. publication%ready(), 'dry publication')
  call require(publication%current_lineage_id() == 901_int64, 'lineage')
  call require(publication%origin_revision() == 0_int64 .and. publication%committed_revision() == 1_int64, 'revision')
  call publication%origin_interval(rt0, rt1, available)
  call require(available, 'publication interval')
  call require_close(rt0, t0, 'publication t0')
  call require_close(rt1, t1, 'publication t1')
  call require_close(publication%bare_soil_evaporation_rate(), 0.31_real64, 'dry rate unchanged')
  call require_close(publication%ponded_water_evaporation_rate(), 0.0_real64, 'dry ponded zero')
  call require(trim(publication%route()) == 'dry', 'dry route')
  call require(abs(publication%bare_soil_evaporation_rate() - 0.31_real64*(t1-t0)) > 1.0e-6_real64, &
       'rate must not be interval-integrated')
  write(*,'(A)') 'FPM06G_ACCEPTED_DRY_PUBLICATION=PASS'
  write(*,'(A)') 'FPM06G_GENERIC_TIME_RATE_NOT_INTEGRATED=PASS'

  call fmr_finalize_surface_evaporation_publication(ponded_prepared, commit_receipt, publication, status)
  call require(status == FMR_SURFACE_EVAP_PUBLICATION_OK .and. publication%ready(), 'ponded publication')
  call require_close(publication%bare_soil_evaporation_rate(), 0.0_real64, 'ponded bare zero')
  call require_close(publication%ponded_water_evaporation_rate(), 0.47_real64, 'ponded rate unchanged')
  call require(trim(publication%route()) == 'ponded', 'ponded route')
  call require(committed%current_revision() == 1_int64, 'finalization must not recommit')
  call committed%current_time(rt1, available)
  call require(available, 'committed time available')
  call require_close(rt1, t1, 'committed time')
  write(*,'(A)') 'FPM06G_ACCEPTED_PONDED_PUBLICATION=PASS'
  write(*,'(A)') 'FPM06G_NO_DUPLICATE_MASS_BOOKING=PASS'
  write(*,'(A)') 'FPM06G_ACCEPTED_PUBLICATION_TEST PASS'

contains

  subroutine initialize_committed(state, lineage, initial_time)
    type(kernel_committed_state_t), intent(out) :: state
    integer(int64), intent(in) :: lineage
    real(real64), intent(in) :: initial_time
    class(transaction_state_t), allocatable :: physical
    logical :: initialized

    allocate(fpm06g_test_state_t :: physical)
    select type (physical)
    type is (fpm06g_test_state_t)
      physical%storage_value = 10.0_real64
    end select
    call state%initialize(lineage, physical, initialized, initial_time)
    call require(initialized, 'committed initialize')
  end subroutine initialize_committed

  subroutine build_receipt(lineage, start_time, end_time, receipt)
    integer(int64), intent(in) :: lineage
    real(real64), intent(in) :: start_time, end_time
    type(fmr_accepted_commit_receipt_t), intent(out) :: receipt
    type(kernel_committed_state_t) :: local_committed
    type(kernel_checkpoint_t) :: local_checkpoint
    type(kernel_candidate_state_t) :: local_candidate
    type(kernel_result_t) :: local_result
    type(kernel_diagnostics_t) :: local_diag
    type(kernel_executor_t) :: local_kernel
    type(fpm06g_test_model_t), target :: local_model
    logical :: local_ok, local_commit
    integer :: local_receipt_status, local_commit_status

    call initialize_committed(local_committed, lineage, start_time)
    call local_kernel%bind_model(local_model)
    call local_committed%capture_checkpoint(local_checkpoint, local_ok)
    call require(local_ok, 'other checkpoint')
    call local_kernel%advance_interval(parameters, local_committed, forcing, config, start_time, end_time, &
         local_result, local_candidate, local_diag, local_checkpoint)
    call require(local_result%completed .and. local_candidate%ready(), 'other candidate')
    call fmr_commit_candidate_with_receipt(local_kernel, local_checkpoint, local_committed, local_candidate, local_diag, &
         local_commit, receipt, local_receipt_status, local_commit_status)
    call require(local_commit .and. local_receipt_status == FMR_COMMIT_RECEIPT_OK .and. receipt%ready(), 'other receipt')
  end subroutine build_receipt

  subroutine build_revision_one_receipt(lineage, initial_time, second_t0, second_t1, receipt)
    integer(int64), intent(in) :: lineage
    real(real64), intent(in) :: initial_time, second_t0, second_t1
    type(fmr_accepted_commit_receipt_t), intent(out) :: receipt
    type(kernel_committed_state_t) :: local_committed
    type(kernel_checkpoint_t) :: cp
    type(kernel_candidate_state_t) :: cand
    type(kernel_result_t) :: res
    type(kernel_diagnostics_t) :: diag
    type(kernel_executor_t) :: local_kernel
    type(fpm06g_test_model_t), target :: local_model
    type(fmr_accepted_commit_receipt_t) :: first_receipt
    logical :: local_ok, local_commit
    integer :: rs, cs

    call initialize_committed(local_committed, lineage, initial_time)
    call local_kernel%bind_model(local_model)
    call local_committed%capture_checkpoint(cp, local_ok)
    call require(local_ok, 'revision first checkpoint')
    call local_kernel%advance_interval(parameters, local_committed, forcing, config, initial_time, second_t0, res, cand, diag, cp)
    call require(res%completed .and. cand%ready(), 'revision first candidate')
    call fmr_commit_candidate_with_receipt(local_kernel, cp, local_committed, cand, diag, local_commit, first_receipt, rs, cs)
    call require(local_commit .and. rs == FMR_COMMIT_RECEIPT_OK, 'revision first commit')
    call local_committed%capture_checkpoint(cp, local_ok)
    call require(local_ok, 'revision second checkpoint')
    call local_kernel%advance_interval(parameters, local_committed, forcing, config, second_t0, second_t1, res, cand, diag, cp)
    call require(res%completed .and. cand%ready(), 'revision second candidate')
    call fmr_commit_candidate_with_receipt(local_kernel, cp, local_committed, cand, diag, local_commit, receipt, rs, cs)
    call require(local_commit .and. rs == FMR_COMMIT_RECEIPT_OK .and. receipt%ready(), 'revision second receipt')
  end subroutine build_revision_one_receipt

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FPM06G_ASSERT_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

  subroutine require_close(actual, expected, label)
    real(real64), intent(in) :: actual, expected
    character(len=*), intent(in) :: label
    real(real64) :: tol
    tol = 256.0_real64 * epsilon(1.0_real64) * max(1.0_real64, abs(actual), abs(expected))
    call require(abs(actual-expected) <= tol, label)
  end subroutine require_close

end program test_fpm06g_surface_evaporation_accepted_publication
