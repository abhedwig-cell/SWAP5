module mod_fwof34_test_model
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t
  implicit none
  private

  type, extends(canonical_state_t), public :: fwof34_state_t
    real(real64) :: water = 1.0_real64
  contains
    procedure :: clone => fwof34_clone
  end type fwof34_state_t

  type, extends(kernel_parameters_t), public :: fwof34_parameters_t
    real(real64) :: flux_rate = 0.1_real64
  end type fwof34_parameters_t

  type, extends(canonical_forcing_t), public :: fwof34_forcing_t
    real(real64) :: scale = 1.0_real64
  end type fwof34_forcing_t

  type, extends(kernel_model_t), public :: fwof34_model_t
    real(real64) :: flux_rate = 0.1_real64
    real(real64) :: scale = 1.0_real64
  contains
    procedure :: configure_parameters => fwof34_configure_parameters
    procedure :: execution_admitted => fwof34_execution_admitted
    procedure :: prepare_interval => fwof34_prepare_interval
    procedure :: advance => fwof34_advance
    procedure :: storage => fwof34_storage
    procedure :: temporal_error => fwof34_temporal_error
  end type fwof34_model_t

contains

  subroutine fwof34_clone(self, copy)
    class(fwof34_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fwof34_state_t :: copy)
    select type (copy)
    type is (fwof34_state_t)
      copy%water = self%water
    end select
  end subroutine fwof34_clone

  subroutine fwof34_configure_parameters(self, parameters)
    class(fwof34_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    select type (parameters)
    type is (fwof34_parameters_t)
      self%flux_rate = parameters%flux_rate
    class default
      error stop 'FWOF34 unexpected parameter type'
    end select
  end subroutine fwof34_configure_parameters

  logical function fwof34_execution_admitted(self, parameters, numerical_config)
    class(fwof34_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    logical :: parameter_ok
    parameter_ok = .false.
    select type (parameters)
    type is (fwof34_parameters_t)
      parameter_ok = parameters%flux_rate >= 0.0_real64
    class default
      parameter_ok = .false.
    end select
    fwof34_execution_admitted = parameter_ok .and. numerical_config%max_committed_substeps > 0 .and. &
         self%scale >= 0.0_real64
  end function fwof34_execution_admitted

  subroutine fwof34_prepare_interval(self, forcing, interval, config)
    class(fwof34_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    select type (forcing)
    type is (fwof34_forcing_t)
      self%scale = forcing%scale
    class default
      error stop 'FWOF34 unexpected forcing type'
    end select
    if (interval%t1 <= interval%t0) error stop 'FWOF34 invalid interval'
    if (config%max_committed_substeps <= 0) error stop 'FWOF34 invalid config'
  end subroutine fwof34_prepare_interval

  subroutine fwof34_advance(self, state, t0, t1, outcome)
    class(fwof34_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: transfer_mass

    outcome = trial_outcome_t()
    transfer_mass = self%flux_rate * self%scale * (t1 - t0)
    select type (state)
    type is (fwof34_state_t)
      state%water = state%water + transfer_mass
    class default
      error stop 'FWOF34 unexpected state type'
    end select
    outcome%solver_ok = .true.
    outcome%mass_in = transfer_mass
    outcome%nonlinear_iterations = 1
  end subroutine fwof34_advance

  real(real64) function fwof34_storage(self, state) result(value)
    class(fwof34_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    if (self%scale < 0.0_real64) error stop 'FWOF34 unreachable scale'
    select type (state)
    type is (fwof34_state_t)
      value = state%water
    class default
      error stop 'FWOF34 unexpected state type'
    end select
  end function fwof34_storage

  real(real64) function fwof34_temporal_error(self, full_state, half_state) result(value)
    class(fwof34_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    if (self%scale < 0.0_real64 .or. .not. same_type_as(full_state, half_state)) then
      error stop 'FWOF34 unexpected temporal state'
    end if
    value = 0.0_real64
  end function fwof34_temporal_error

end module mod_fwof34_test_model

program test_fwof34_accepted_window_runtime_lineage
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED
  use mod_kernel_transactions
  use mod_wofost_one_day_structural_evolution, only: wofost_accepted_window_aggregates_t
  use mod_fmr_wofost_accepted_window_lineage
  use mod_fwof34_test_model
  implicit none

  type(kernel_committed_state_t) :: committed
  type(kernel_checkpoint_t) :: checkpoint0, checkpoint1
  type(kernel_executor_t) :: kernel
  type(fwof34_model_t), target :: model
  type(fwof34_parameters_t) :: parameters
  type(fwof34_forcing_t) :: forcing
  type(canonical_numerical_config_t) :: config
  type(fmr_wofost_accepted_window_t) :: window, window_copy
  type(fmr_wofost_trial_contribution_t) :: rejected_trial, trial0, trial1, probe_trial
  type(fmr_wofost_accepted_interval_certificate_t) :: certificate0, certificate1, invalid_certificate
  type(fmr_wofost_crop_event_token_t) :: token1, token2
  type(wofost_accepted_window_aggregates_t) :: aggregates1, aggregates2
  integer :: status
  logical :: ok, available

  call setup_committed(committed, 3401_int64, 0.0_real64)
  call setup_solver(parameters, forcing, config)
  call kernel%bind_model(model)
  call committed%capture_checkpoint(checkpoint0, ok)
  call require(ok, 'initial F-KT checkpoint')

  call open_wofost_accepted_window(checkpoint0, 1.0_real64, window, status)
  call require(status == FMR_WOFOST_LINEAGE_OK .and. window%ready(), 'open one-day accepted window')
  call require(.not. window%complete() .and. .not. window%event_due(), 'new window incomplete')

  call certify_fkt_accepted_interval(checkpoint0, committed, invalid_certificate, status)
  call require(status == FMR_WOFOST_LINEAGE_COMMIT_NOT_PROVEN, 'certificate requires actual F-KT revision advance')
  call require(.not. invalid_certificate%ready(), 'uncommitted certificate unavailable')
  print '(a)', 'FWOF34_CERTIFICATE_REQUIRES_REAL_FKT_COMMIT=PASS'

  ! Rejected/retried trial: deliberately large process values are accumulated
  ! in worker-local scratch, then discarded before any accepted certificate.
  call begin_wofost_trial_contribution(checkpoint0, 0.4_real64, rejected_trial, status)
  call require(status == FMR_WOFOST_LINEAGE_OK, 'begin rejected trial scratch')
  call accumulate_wofost_trial_process_rate(rejected_trial, 0.0_real64, 0.4_real64, &
       1000.0_real64, 2000.0_real64, status)
  call require(status == FMR_WOFOST_LINEAGE_OK .and. rejected_trial%complete(), 'fill rejected trial scratch')
  call discard_wofost_trial_contribution(rejected_trial)
  call require(.not. rejected_trial%ready(), 'discard clears rejected trial scratch')
  call require(window%interval_count() == 0, 'discarded trial cannot enter accepted window')

  call prepare_wofost_crop_event_delivery(window, aggregates1, token1, available, status)
  call require(status == FMR_WOFOST_LINEAGE_WINDOW_INCOMPLETE .and. .not. available, &
       'incomplete window cannot emit crop event')
  print '(a)', 'FWOF34_REJECTED_TRIAL_ZERO_CONTRIBUTION=PASS'

  ! Trial subintervals themselves must be contiguous. Failed gap/overlap calls
  ! are nonmutating and a correct continuation can still finish the trial.
  call begin_wofost_trial_contribution(checkpoint0, 0.4_real64, probe_trial, status)
  call require(status == FMR_WOFOST_LINEAGE_OK, 'begin continuity probe')
  call accumulate_wofost_trial_process_rate(probe_trial, 0.0_real64, 0.1_real64, 1.0_real64, 2.0_real64, status)
  call require(status == FMR_WOFOST_LINEAGE_OK, 'first probe interval')
  call accumulate_wofost_trial_process_rate(probe_trial, 0.2_real64, 0.3_real64, 1.0_real64, 2.0_real64, status)
  call require(status == FMR_WOFOST_LINEAGE_NONCONTIGUOUS, 'gap rejected')
  call accumulate_wofost_trial_process_rate(probe_trial, 0.05_real64, 0.2_real64, 1.0_real64, 2.0_real64, status)
  call require(status == FMR_WOFOST_LINEAGE_NONCONTIGUOUS, 'overlap rejected')
  call discard_wofost_trial_contribution(probe_trial)
  print '(a)', 'FWOF34_TRIAL_SUBINTERVAL_GAP_OVERLAP_REJECTED=PASS'

  call begin_wofost_trial_contribution(checkpoint0, 0.4_real64, trial0, status)
  call require(status == FMR_WOFOST_LINEAGE_OK, 'begin accepted interval zero')
  call accumulate_wofost_trial_process_rate(trial0, 0.0_real64, 0.2_real64, 2.0_real64, 4.0_real64, status)
  call require(status == FMR_WOFOST_LINEAGE_OK, 'accepted interval zero first process substep')
  call accumulate_wofost_trial_process_rate(trial0, 0.2_real64, 0.4_real64, 3.0_real64, 5.0_real64, status)
  call require(status == FMR_WOFOST_LINEAGE_OK .and. trial0%complete(), 'accepted interval zero complete process coverage')

  call advance_and_commit(kernel, model, parameters, forcing, config, committed, checkpoint0, &
       0.0_real64, 0.4_real64)
  call certify_fkt_accepted_interval(checkpoint0, committed, certificate0, status)
  call require(status == FMR_WOFOST_LINEAGE_OK .and. certificate0%ready(), 'first real accepted certificate')
  call admit_wofost_accepted_trial(window, certificate0, trial0, status)
  call require(status == FMR_WOFOST_LINEAGE_OK, 'admit first accepted trial')
  call require(window%interval_count() == 1 .and. .not. window%complete(), 'first accepted interval advances only coverage')
  print '(a)', 'FWOF34_FIRST_ACCEPTED_INTERVAL_ADMITTED_ONLY_AFTER_COMMIT=PASS'

  ! Reusing the already-consumed certificate against a new trial is rejected
  ! without advancing the accepted window.
  call committed%capture_checkpoint(checkpoint1, ok)
  call require(ok, 'second F-KT checkpoint')
  call begin_wofost_trial_contribution(checkpoint1, 1.0_real64, trial1, status)
  call require(status == FMR_WOFOST_LINEAGE_OK, 'begin accepted interval one')
  call accumulate_wofost_trial_process_rate(trial1, 0.4_real64, 0.7_real64, 1.0_real64, 2.0_real64, status)
  call require(status == FMR_WOFOST_LINEAGE_OK, 'second interval first process substep')
  call accumulate_wofost_trial_process_rate(trial1, 0.7_real64, 1.0_real64, 2.0_real64, 3.0_real64, status)
  call require(status == FMR_WOFOST_LINEAGE_OK .and. trial1%complete(), 'second interval process coverage complete')

  call admit_wofost_accepted_trial(window, certificate0, trial1, status)
  call require(status == FMR_WOFOST_LINEAGE_CERTIFICATE_MISMATCH, 'stale certificate rejected')
  call require(window%interval_count() == 1 .and. .not. window%complete(), 'certificate mismatch does not mutate window')
  print '(a)', 'FWOF34_LINEAGE_REVISION_INTERVAL_MISMATCH_FAILS_WITHOUT_MUTATION=PASS'

  call advance_and_commit(kernel, model, parameters, forcing, config, committed, checkpoint1, &
       0.4_real64, 1.0_real64)
  call certify_fkt_accepted_interval(checkpoint1, committed, certificate1, status)
  call require(status == FMR_WOFOST_LINEAGE_OK .and. certificate1%ready(), 'second real accepted certificate')
  call admit_wofost_accepted_trial(window, certificate1, trial1, status)
  call require(status == FMR_WOFOST_LINEAGE_OK, 'admit second accepted trial')
  call require(window%interval_count() == 2 .and. window%complete() .and. window%event_due(), &
       'two contiguous committed intervals complete crop window')
  print '(a)', 'FWOF34_MULTI_INTERVAL_ACCEPTED_WINDOW_CONTIGUOUS_COVERAGE=PASS'

  call prepare_wofost_crop_event_delivery(window, aggregates1, token1, available, status)
  call require(status == FMR_WOFOST_LINEAGE_OK .and. available .and. token1%ready(), 'prepare complete crop event delivery')
  call require_close(aggregates1%actual_root_uptake, 1.9_real64, 2.0e-15_real64, 'accepted IQROT integral excludes rejected trial')
  call require_close(aggregates1%potential_transpiration, 3.3_real64, 2.0e-15_real64, 'accepted IPTRA integral excludes rejected trial')

  call prepare_wofost_crop_event_delivery(window, aggregates2, token2, available, status)
  call require(status == FMR_WOFOST_LINEAGE_OK .and. available .and. token2%ready(), 'repeat prepare is allowed before delivery commit')
  call require(bitwise_equal(aggregates1%actual_root_uptake, aggregates2%actual_root_uptake), &
       'retry aggregate IQROT bitwise identity')
  call require(bitwise_equal(aggregates1%potential_transpiration, aggregates2%potential_transpiration), &
       'retry aggregate IPTRA bitwise identity')
  print '(a)', 'FWOF34_FROZEN_AGGREGATE_RETRY_BITWISE_IDENTITY=PASS'

  ! Independently prepared event tokens must both authorize identical copies of
  ! the same completed window. This proves deterministic token replay without
  ! exposing private token fields.
  window_copy = window
  call commit_wofost_crop_event_delivery(window, token1, status)
  call require(status == FMR_WOFOST_LINEAGE_OK .and. window%delivery_committed(), &
       'first event delivery commit')
  call commit_wofost_crop_event_delivery(window_copy, token2, status)
  call require(status == FMR_WOFOST_LINEAGE_OK .and. window_copy%delivery_committed(), &
       'replayed token commits identical window copy')
  call commit_wofost_crop_event_delivery(window, token2, status)
  call require(status == FMR_WOFOST_LINEAGE_EVENT_ALREADY_DELIVERED, 'second delivery commit rejected')
  call require(.not. window%event_due(), 'delivered window no longer schedules crop event')
  call prepare_wofost_crop_event_delivery(window, aggregates2, token2, available, status)
  call require(status == FMR_WOFOST_LINEAGE_EVENT_ALREADY_DELIVERED .and. .not. available, &
       'delivered window cannot be prepared again')
  print '(a)', 'FWOF34_CROP_EVENT_DELIVERY_EXACTLY_ONCE_WITH_RETRYABLE_PREPARE=PASS'

  print '(a)', 'FWOF34_ACCEPTED_WINDOW_RUNTIME_LINEAGE_TEST PASS'

contains

  subroutine setup_committed(state, lineage_id, initial_time)
    type(kernel_committed_state_t), intent(out) :: state
    integer(int64), intent(in) :: lineage_id
    real(real64), intent(in) :: initial_time
    class(transaction_state_t), allocatable :: physical
    logical :: initialized

    allocate(fwof34_state_t :: physical)
    select type (physical)
    type is (fwof34_state_t)
      physical%water = 1.0_real64
    end select
    call state%initialize(lineage_id, physical, initialized, initial_time)
    call require(initialized, 'initialize F-KT committed test state')
  end subroutine setup_committed

  subroutine setup_solver(p, f, c)
    type(fwof34_parameters_t), intent(out) :: p
    type(fwof34_forcing_t), intent(out) :: f
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

  subroutine advance_and_commit(k, m, p, f, c, state, checkpoint, t0, t1)
    type(kernel_executor_t), intent(inout) :: k
    type(fwof34_model_t), target, intent(inout) :: m
    type(fwof34_parameters_t), intent(in) :: p
    type(fwof34_forcing_t), intent(in) :: f
    type(canonical_numerical_config_t), intent(in) :: c
    type(kernel_committed_state_t), intent(inout) :: state
    type(kernel_checkpoint_t), intent(in) :: checkpoint
    real(real64), intent(in) :: t0, t1
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    logical :: did_commit
    integer :: commit_status

    if (.not. same_type_as(m, m)) error stop 'FWOF34 unreachable model type'
    call k%advance_interval(p, state, f, c, t0, t1, result, candidate, diagnostics, checkpoint)
    call require(result%status == CANONICAL_STATUS_COMPLETED .and. result%completed, 'F-KT trial completes')
    call require(candidate%ready(), 'F-KT candidate materialized')
    call k%commit_candidate(state, candidate, diagnostics, did_commit, commit_status)
    call require(did_commit .and. commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'F-KT candidate commits')
  end subroutine advance_and_commit

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,A)') 'FAIL ', trim(label)
      error stop 1
    end if
  end subroutine require

  subroutine require_close(actual, expected, tolerance, label)
    real(real64), intent(in) :: actual, expected, tolerance
    character(len=*), intent(in) :: label
    call require(abs(actual - expected) <= tolerance, label)
  end subroutine require_close

  logical function bitwise_equal(left, right) result(equal)
    real(real64), intent(in) :: left, right
    integer(int64) :: li, ri
    li = transfer(left, li)
    ri = transfer(right, ri)
    equal = li == ri
  end function bitwise_equal

end program test_fwof34_accepted_window_runtime_lineage
