module mod_fmr18_test_model
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t
  implicit none
  private

  type, extends(canonical_state_t), public :: fmr18_state_t
    real(real64) :: storage_value = 1.0_real64
  contains
    procedure :: clone => fmr18_clone
  end type fmr18_state_t

  type, extends(kernel_parameters_t), public :: fmr18_parameters_t
    real(real64) :: flux_rate = 0.1_real64
  end type fmr18_parameters_t

  type, extends(canonical_forcing_t), public :: fmr18_forcing_t
    real(real64) :: scale = 1.0_real64
  end type fmr18_forcing_t

  type, extends(kernel_model_t), public :: fmr18_model_t
    real(real64) :: flux_rate = 0.1_real64
    real(real64) :: scale = 1.0_real64
    real(real64) :: maximum_trial_span = huge(1.0_real64)
  contains
    procedure :: configure_parameters => fmr18_configure_parameters
    procedure :: execution_admitted => fmr18_execution_admitted
    procedure :: prepare_interval => fmr18_prepare_interval
    procedure :: advance => fmr18_advance
    procedure :: storage => fmr18_storage
    procedure :: storage_accounting_status => fmr18_storage_accounting_status
    procedure :: temporal_error => fmr18_temporal_error
  end type fmr18_model_t

contains

  subroutine fmr18_clone(self, copy)
    class(fmr18_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fmr18_state_t :: copy)
    select type (copy)
    type is (fmr18_state_t)
      copy%storage_value = self%storage_value
    end select
  end subroutine fmr18_clone

  subroutine fmr18_configure_parameters(self, parameters)
    class(fmr18_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    select type (parameters)
    type is (fmr18_parameters_t)
      self%flux_rate = parameters%flux_rate
    class default
      error stop 'FMR18 unexpected parameter type'
    end select
  end subroutine fmr18_configure_parameters

  logical function fmr18_execution_admitted(self, parameters, numerical_config)
    class(fmr18_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    logical :: parameter_ok
    parameter_ok = .false.
    select type (parameters)
    type is (fmr18_parameters_t)
      parameter_ok = parameters%flux_rate >= 0.0_real64
    class default
      parameter_ok = .false.
    end select
    fmr18_execution_admitted = parameter_ok .and. numerical_config%max_committed_substeps > 0 .and. &
         self%scale >= 0.0_real64
  end function fmr18_execution_admitted

  subroutine fmr18_prepare_interval(self, forcing, interval, config)
    class(fmr18_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    select type (forcing)
    type is (fmr18_forcing_t)
      self%scale = forcing%scale
    class default
      error stop 'FMR18 unexpected forcing type'
    end select
    if (interval%t1 <= interval%t0) error stop 'FMR18 invalid interval'
    if (config%max_committed_substeps <= 0) error stop 'FMR18 invalid config'
  end subroutine fmr18_prepare_interval

  subroutine fmr18_advance(self, state, t0, t1, outcome)
    class(fmr18_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: transfer_mass

    outcome = trial_outcome_t()
    transfer_mass = self%flux_rate * self%scale * (t1 - t0)
    select type (state)
    type is (fmr18_state_t)
      state%storage_value = state%storage_value + transfer_mass
    class default
      error stop 'FMR18 unexpected state type'
    end select
    outcome%solver_ok = t1 - t0 <= self%maximum_trial_span
    outcome%mass_in = transfer_mass
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    outcome%nonlinear_iterations = 1
  end subroutine fmr18_advance

  real(real64) function fmr18_storage(self, state) result(value)
    class(fmr18_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    if (self%scale < 0.0_real64) error stop 'FMR18 unreachable scale'
    select type (state)
    type is (fmr18_state_t)
      value = state%storage_value
    class default
      error stop 'FMR18 unexpected state type'
    end select
  end function fmr18_storage

  subroutine fmr18_storage_accounting_status(self, state, complete, missing_mask)
    class(fmr18_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    complete = .false.
    missing_mask = TX_MASS_MISSING_NONE
    if (.not. same_type_as(self, self)) error stop 'FMR18 unreachable model type'
    select type (state)
    type is (fmr18_state_t)
      complete = .true.
    class default
      error stop 'FMR18 unexpected accounting state type'
    end select
  end subroutine fmr18_storage_accounting_status

  real(real64) function fmr18_temporal_error(self, full_state, half_state) result(value)
    class(fmr18_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    if (self%scale < 0.0_real64 .or. .not. same_type_as(full_state, half_state)) then
      error stop 'FMR18 unexpected temporal state'
    end if
    value = 0.0_real64
  end function fmr18_temporal_error

end module mod_fmr18_test_model

program test_fmr18_accepted_commit_receipt
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED, &
       CANONICAL_STATUS_TRANSACTION_FAILED
  use mod_kernel_transactions
  use mod_fmr_accepted_commit_receipt
  use mod_fmr_vonhhbraden_source_window_progress
  use mod_ppa_wu04c_runtime_publication
  use mod_gash_interception
  use mod_vonhhbraden_interception, only: vonhhbraden_source_window_t, VONHHBRADEN_AVAILABLE
  use mod_fmr18_test_model
  implicit none

  type(kernel_committed_state_t) :: committed, other
  type(kernel_checkpoint_t) :: checkpoint0, checkpoint1, checkpoint2, checkpoint3, checkpoint_other
  type(kernel_checkpoint_t) :: other0, other1
  type(kernel_executor_t) :: kernel
  type(fmr18_model_t), target :: model
  type(fmr18_parameters_t) :: parameters
  type(fmr18_forcing_t) :: forcing
  type(canonical_numerical_config_t) :: config
  type(kernel_candidate_state_t) :: candidate, stale_candidate, winner_candidate, probe_candidate
  type(kernel_candidate_state_t) :: other_candidate, candidate3
  type(kernel_candidate_state_t) :: failed_retry_candidate
  type(kernel_diagnostics_t) :: diagnostics, stale_diagnostics, winner_diagnostics, probe_diagnostics, other_diagnostics
  type(kernel_diagnostics_t) :: diagnostics3
  type(kernel_diagnostics_t) :: failed_retry_diagnostics
  type(kernel_result_t) :: failed_retry_result
  type(fmr_accepted_commit_receipt_t) :: receipt
  type(fmr_vonhhbraden_source_window_progress_t) :: interception_progress
  type(fmr_vonhhbraden_source_window_progress_t) :: foreign_lineage_progress
  type(fmr_vonhhbraden_source_window_progress_t) :: restored_interception_progress
  type(fmr_vonhhbraden_source_window_restart_t) :: interception_restart
  type(gash_parameters_t) :: gash_parameters
  type(vonhhbraden_source_window_t) :: gash_source
  logical :: ok, did_commit, interval_available, restart_exported, restart_restored, failed_candidate_ready
  integer :: receipt_status, commit_status
  real(real64) :: t0, t1, committed_time, gash_aggregate
  integer(int64) :: revision_before

  call setup_solver(parameters, forcing, config)
  call kernel%bind_model(model)
  call setup_committed(committed, 1801_int64, 0.0_real64)
  call committed%capture_checkpoint(checkpoint0, ok)
  call require(ok, 'capture initial checkpoint')

  call advance_candidate(kernel, parameters, forcing, config, committed, checkpoint0, 0.0_real64, 0.5_real64, &
       candidate, diagnostics)
  call fmr_commit_candidate_with_receipt(kernel, checkpoint0, committed, candidate, diagnostics, did_commit, &
       receipt, receipt_status, commit_status)
  call require(did_commit, 'first receipt commit succeeds')
  call require(receipt_status == FMR_COMMIT_RECEIPT_OK, 'first receipt status')
  call require(commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'first kernel commit status')
  call require(receipt%ready(), 'first receipt ready')
  call require(receipt%current_lineage_id() == 1801_int64, 'receipt lineage')
  call require(receipt%origin_revision() == 0_int64, 'receipt origin revision')
  call require(receipt%committed_revision() == 1_int64, 'receipt committed revision')
  call receipt%origin_interval(t0, t1, interval_available)
  call require(interval_available .and. bitwise_equal(t0, 0.0_real64) .and. bitwise_equal(t1, 0.5_real64), &
       'receipt interval identity')
  call require(committed%current_revision() == 1_int64, 'committed revision after receipt')
  gash_parameters%free_throughfall=0.2_real64; gash_parameters%stemflow=0.1_real64
  gash_parameters%canopy_storage_cm=0.07_real64; gash_parameters%average_evaporation=0.15_real64
  gash_parameters%average_precipitation=0.5_real64
  gash_source%leaf_area_index=2.0_real64; gash_source%gross_rain_cm_per_day=0.5_real64
  call evaluate_gash_source_window(gash_parameters,gash_source,gash_aggregate,receipt_status)
  call require(receipt_status==VONHHBRADEN_AVAILABLE .and. gash_aggregate>0.0_real64, 'Gash aggregate available')
  call fmr_initialize_vonhhbraden_source_window_progress(1802_int64, 0.0_real64, 1.0_real64, &
       gash_aggregate, interception_progress, receipt_status, 1801_int64, 0_int64)
  call require(receipt_status == FMR_VONHHBRADEN_PROGRESS_OK, 'initialize interception progress')
  call fmr_initialize_vonhhbraden_source_window_progress(1803_int64, 0.0_real64, 1.0_real64, &
       gash_aggregate, foreign_lineage_progress, receipt_status, 9999_int64, 0_int64)
  call require(receipt_status == FMR_VONHHBRADEN_PROGRESS_OK, 'initialize foreign-lineage probe')
  call publish_ppa_wu04c_accepted_progress(foreign_lineage_progress, receipt, 0.5_real64*gash_aggregate, receipt_status)
  call require(receipt_status == PPA_WU04C_PUBLICATION_REJECTED .and. &
       abs(foreign_lineage_progress%remaining_interception()-gash_aggregate) < 1.e-14_real64, &
       'foreign lineage receipt rejected without advancing progress')
  print '(a)', 'PPA_WU04C_FOREIGN_LINEAGE_RECEIPT_REJECTED=PASS'
  call publish_ppa_wu04c_accepted_progress(interception_progress, receipt, 0.5_real64*gash_aggregate, receipt_status)
  call require(receipt_status == PPA_WU04C_PUBLICATION_OK .and. &
       abs(interception_progress%remaining_interception()-0.5_real64*gash_aggregate) < 1.e-14_real64, &
       'accepted receipt advances interception progress exactly once')
  call interception_progress%export_restart(interception_restart, restart_exported)
  call require(restart_exported, 'export mid-window interception restart')
  call fmr_restore_vonhhbraden_source_window_progress(interception_restart, restored_interception_progress, &
       restart_restored, receipt_status)
  call require(restart_restored .and. receipt_status == FMR_VONHHBRADEN_PROGRESS_OK .and. &
       abs(restored_interception_progress%remaining_interception()-0.5_real64*gash_aggregate) < 1.e-14_real64, &
       'mid-window restart preserves remaining interception exactly')
  call publish_ppa_wu04c_accepted_progress(restored_interception_progress, receipt, 0.1_real64*gash_aggregate, receipt_status)
  call require(receipt_status == PPA_WU04C_PUBLICATION_REJECTED, 'replayed receipt revision rejected after restart')
  print '(a)', 'PPA_WU04C_REAL_FKT_RECEIPT_PROGRESS=PASS'
  print '(a)', 'PPA_WU04C_MID_WINDOW_RESTART_PROGRESS=PASS'
  print '(a)', 'PPA_WU04D_GASH_FKT_RECEIPT_PROGRESS=PASS'
  call committed%current_time(committed_time, ok)
  call require(ok .and. bitwise_equal(committed_time, 0.5_real64), 'committed time after receipt')
  call require(.not. candidate%ready(), 'successful commit consumes candidate')
  print '(a)', 'FMR18_REAL_FKT_COMMIT_CREATES_EXACT_RECEIPT=PASS'

  ! Two candidates from the same checkpoint. Commit one directly, then prove
  ! the stale sibling is rejected by F-KT and cannot produce a receipt.
  call committed%capture_checkpoint(checkpoint1, ok)
  call require(ok, 'capture revision-one checkpoint')
  call advance_candidate(kernel, parameters, forcing, config, committed, checkpoint1, 0.5_real64, 0.75_real64, &
       stale_candidate, stale_diagnostics)
  call advance_candidate(kernel, parameters, forcing, config, committed, checkpoint1, 0.5_real64, 0.6_real64, &
       winner_candidate, winner_diagnostics)
  call fmr_commit_candidate_with_receipt(kernel, checkpoint1, committed, winner_candidate, winner_diagnostics, &
       did_commit, receipt, receipt_status, commit_status)
  call require(did_commit .and. receipt_status == FMR_COMMIT_RECEIPT_OK .and. &
       commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'winner candidate commits with receipt')
  call require(committed%current_revision() == 2_int64, 'winner advances revision')
  call publish_ppa_wu04c_accepted_progress(interception_progress, receipt, 0.1_real64*gash_aggregate, receipt_status)
  call require(receipt_status == PPA_WU04C_PUBLICATION_OK .and. &
       abs(interception_progress%remaining_interception()-0.4_real64*gash_aggregate) < 1.e-14_real64, &
       'accepted short interval advances source-window progress')
  revision_before = committed%current_revision()
  call fmr_commit_candidate_with_receipt(kernel, checkpoint1, committed, stale_candidate, stale_diagnostics, &
       did_commit, receipt, receipt_status, commit_status)
  call require(.not. did_commit, 'stale receipt commit rejected')
  call require(receipt_status == FMR_COMMIT_RECEIPT_COMMIT_REJECTED, 'stale receipt status')
  call require(commit_status == KERNEL_COMMIT_STATUS_STALE_REVISION, 'stale kernel status preserved')
  call require(.not. receipt%ready(), 'stale rejection emits no receipt')
  call require(committed%current_revision() == revision_before, 'stale rejection does not mutate committed state')
  call publish_ppa_wu04c_accepted_progress(interception_progress, receipt, 0.15_real64*gash_aggregate, receipt_status)
  call require(receipt_status == PPA_WU04C_PUBLICATION_REJECTED, 'rejected trial cannot publish source progress')
  call interception_progress%export_restart(interception_restart, restart_exported)
  call require(restart_exported .and. bitwise_equal(interception_restart%accepted_through_time, 0.6_real64) .and. &
       abs(interception_restart%accepted_interception_cm-0.6_real64*gash_aggregate) < 1.e-14_real64, &
       'rejected retry candidate leaves accepted source-window boundary unchanged')
  call require(stale_candidate%ready(), 'stale rejected candidate remains rollback-capable')
  call kernel%rollback_candidate(stale_candidate, stale_diagnostics)
  call require(.not. stale_candidate%ready(), 'stale candidate explicitly discarded')
  print '(a)', 'FMR18_COMMIT_REJECTION_EMITS_NO_RECEIPT=PASS'

  ! Build a second state with the same lineage and revision but a different
  ! committed time. Its checkpoint must fail receipt prevalidation before the
  ! candidate associated with the real checkpoint can reach F-KT commit.
  call setup_committed(other, 1801_int64, 0.0_real64)
  call other%capture_checkpoint(other0, ok)
  call require(ok, 'capture other initial checkpoint')
  call advance_candidate(kernel, parameters, forcing, config, other, other0, 0.0_real64, 0.3_real64, &
       other_candidate, other_diagnostics)
  call kernel%commit_candidate(other, other_candidate, other_diagnostics, did_commit, commit_status)
  call require(did_commit, 'other first commit')
  call other%capture_checkpoint(other1, ok)
  call require(ok, 'capture other revision-one checkpoint')
  call advance_candidate(kernel, parameters, forcing, config, other, other1, 0.3_real64, 0.61_real64, &
       other_candidate, other_diagnostics)
  call kernel%commit_candidate(other, other_candidate, other_diagnostics, did_commit, commit_status)
  call require(did_commit .and. other%current_revision() == 2_int64, 'other reaches revision two')
  call other%capture_checkpoint(checkpoint_other, ok)
  call require(ok, 'capture mismatching-time checkpoint')

  call committed%capture_checkpoint(checkpoint2, ok)
  call require(ok, 'capture real revision-two checkpoint')
  model%maximum_trial_span = 0.025_real64
  call kernel%advance_interval(parameters, committed, forcing, config, 0.6_real64, 0.8_real64, &
       failed_retry_result, failed_retry_candidate, failed_retry_diagnostics, checkpoint2)
  failed_candidate_ready = failed_retry_candidate%ready()
  call require(failed_retry_result%status == CANONICAL_STATUS_TRANSACTION_FAILED .and. &
       .not. failed_retry_result%completed .and. .not. failed_candidate_ready, &
       'exhausted changed-dt retry publishes no candidate')
  call fmr_commit_candidate_with_receipt(kernel, checkpoint2, committed, failed_retry_candidate, &
       failed_retry_diagnostics, did_commit, receipt, receipt_status, commit_status)
  call require(.not. did_commit .and. .not. receipt%ready(), 'exhausted retry emits no commit receipt')
  call publish_ppa_wu04c_accepted_progress(interception_progress, receipt, 0.2_real64*gash_aggregate, receipt_status)
  call require(receipt_status == PPA_WU04C_PUBLICATION_REJECTED, &
       'exhausted retry cannot publish source-window progress')
  call interception_progress%export_restart(interception_restart, restart_exported)
  call require(restart_exported .and. bitwise_equal(interception_restart%accepted_through_time, 0.6_real64) .and. &
       abs(interception_restart%accepted_interception_cm-0.6_real64*gash_aggregate) < 1.e-14_real64, &
       'exhausted retry leaves restart progress at prior accepted boundary')
  model%maximum_trial_span = 0.1_real64
  call advance_candidate(kernel, parameters, forcing, config, committed, checkpoint2, 0.6_real64, 0.8_real64, &
       probe_candidate, probe_diagnostics)
  call require(probe_diagnostics%retries > 0, 'changed-dt request exercised transaction retry')
  revision_before = committed%current_revision()
  call fmr_commit_candidate_with_receipt(kernel, checkpoint_other, committed, probe_candidate, probe_diagnostics, &
       did_commit, receipt, receipt_status, commit_status)
  call require(.not. did_commit, 'mismatching checkpoint rejected before commit')
  call require(receipt_status == FMR_COMMIT_RECEIPT_TIME_MISMATCH, 'mismatching checkpoint time status')
  call require(.not. receipt%ready(), 'precommit mismatch emits no receipt')
  call require(committed%current_revision() == revision_before, 'precommit mismatch leaves committed revision')
  call require(probe_candidate%ready(), 'precommit mismatch leaves candidate reusable')
  call publish_ppa_wu04c_accepted_progress(interception_progress, receipt, 0.2_real64*gash_aggregate, receipt_status)
  call require(receipt_status == PPA_WU04C_PUBLICATION_REJECTED, &
       'precommit checkpoint rejection cannot publish source progress')
  print '(a)', 'FMR18_EXPECTED_RECEIPT_FAILURES_PRECEDE_PHYSICAL_COMMIT=PASS'

  ! The same untouched candidate remains valid with its real checkpoint. This
  ! proves receipt prevalidation itself has no hidden candidate mutation.
  call fmr_commit_candidate_with_receipt(kernel, checkpoint2, committed, probe_candidate, probe_diagnostics, &
       did_commit, receipt, receipt_status, commit_status)
  call require(did_commit .and. receipt_status == FMR_COMMIT_RECEIPT_OK .and. receipt%ready(), &
       'correct checkpoint commits after prevalidation rejection')
  call require(receipt%origin_revision() == 2_int64 .and. receipt%committed_revision() == 3_int64, &
       'second receipt revision identity')
  call receipt%origin_interval(t0, t1, interval_available)
  call require(interval_available .and. bitwise_equal(t0, 0.6_real64) .and. bitwise_equal(t1, 0.8_real64), &
       'second receipt interval identity')
  model%maximum_trial_span = huge(1.0_real64)
  call publish_ppa_wu04c_accepted_progress(interception_progress, receipt, 0.2_real64*gash_aggregate, receipt_status)
  call require(receipt_status == PPA_WU04C_PUBLICATION_OK .and. &
       abs(interception_progress%remaining_interception()-0.2_real64*gash_aggregate) < 1.e-14_real64, &
       'accepted changed-dt retry publishes only committed interval progress')
  call interception_progress%export_restart(interception_restart, restart_exported)
  call require(restart_exported, 'export after changed-dt retry')
  call fmr_restore_vonhhbraden_source_window_progress(interception_restart, restored_interception_progress, &
       restart_restored, receipt_status)
  call require(restart_restored .and. receipt_status == FMR_VONHHBRADEN_PROGRESS_OK .and. &
       abs(restored_interception_progress%remaining_interception()-0.2_real64*gash_aggregate) < 1.e-14_real64, &
       'restart after changed-dt retry preserves accepted progress')
  call committed%capture_checkpoint(checkpoint3, ok)
  call require(ok, 'capture post-retry checkpoint')
  call advance_candidate(kernel, parameters, forcing, config, committed, checkpoint3, 0.8_real64, 1.0_real64, &
       candidate3, diagnostics3)
  call fmr_commit_candidate_with_receipt(kernel, checkpoint3, committed, candidate3, diagnostics3, &
       did_commit, receipt, receipt_status, commit_status)
  call require(did_commit .and. receipt_status == FMR_COMMIT_RECEIPT_OK, 'commit final source-window interval')
  call publish_ppa_wu04c_accepted_progress(restored_interception_progress, receipt, &
       0.2_real64*gash_aggregate, receipt_status)
  call require(receipt_status == PPA_WU04C_PUBLICATION_OK .and. &
       restored_interception_progress%remaining_interception() <= 1.0e-14_real64, &
       'accepted receipts close source-window aggregate exactly once')
  print '(a)', 'PPA_WU04C_REJECTED_RETRY_NO_PROGRESS=PASS'
  print '(a)', 'PPA_WU04C_CHANGED_DT_ACCEPTED_REPLAY=PASS'
  print '(a)', 'PPA_WU04C_SOURCE_WINDOW_CLOSED_EXACTLY=PASS'
  print '(a)', 'FMR18_PREVALIDATION_REJECTION_IS_NONMUTATING_AND_REPLAYABLE=PASS'

  print '(a)', 'FMR18_ACCEPTED_COMMIT_RECEIPT_TEST PASS'

contains

  subroutine setup_committed(state, lineage_id, initial_time)
    type(kernel_committed_state_t), intent(out) :: state
    integer(int64), intent(in) :: lineage_id
    real(real64), intent(in) :: initial_time
    class(transaction_state_t), allocatable :: physical
    logical :: initialized

    allocate(fmr18_state_t :: physical)
    select type (physical)
    type is (fmr18_state_t)
      physical%storage_value = 1.0_real64
    end select
    call state%initialize(lineage_id, physical, initialized, initial_time)
    call require(initialized, 'initialize committed test state')
  end subroutine setup_committed

  subroutine setup_solver(p, f, c)
    type(fmr18_parameters_t), intent(out) :: p
    type(fmr18_forcing_t), intent(out) :: f
    type(canonical_numerical_config_t), intent(out) :: c
    p%flux_rate = 0.1_real64
    f%scale = 1.0_real64
    c%transaction%temporal_tolerance = 1.0_real64
    c%transaction%mass_tolerance = 1.0e-12_real64
    c%transaction%retry_scale = 0.5_real64
    c%transaction%max_retries = 2
    c%max_committed_substeps = 8
    c%progress_tolerance = 0.0_real64
  end subroutine setup_solver

  subroutine advance_candidate(k, p, f, c, state, checkpoint, t0_in, t1_in, candidate_out, diagnostics_out)
    type(kernel_executor_t), intent(inout) :: k
    type(fmr18_parameters_t), intent(in) :: p
    type(fmr18_forcing_t), intent(in) :: f
    type(canonical_numerical_config_t), intent(in) :: c
    type(kernel_committed_state_t), intent(in) :: state
    type(kernel_checkpoint_t), intent(in) :: checkpoint
    real(real64), intent(in) :: t0_in, t1_in
    type(kernel_candidate_state_t), intent(out) :: candidate_out
    type(kernel_diagnostics_t), intent(out) :: diagnostics_out
    type(kernel_result_t) :: result

    call k%advance_interval(p, state, f, c, t0_in, t1_in, result, candidate_out, diagnostics_out, checkpoint)
    call require(result%status == CANONICAL_STATUS_COMPLETED .and. result%completed, 'F-KT trial completes')
    call require(candidate_out%ready(), 'F-KT candidate materialized')
  end subroutine advance_candidate

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,A)') 'FAIL ', trim(label)
      error stop 1
    end if
  end subroutine require

  logical function bitwise_equal(left, right) result(equal)
    real(real64), intent(in) :: left, right
    integer(int64) :: li, ri
    li = transfer(left, li)
    ri = transfer(right, ri)
    equal = li == ri
  end function bitwise_equal

end program test_fmr18_accepted_commit_receipt
