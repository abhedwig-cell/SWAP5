module mod_fkt08_test_model
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, &
       TX_MASS_MISSING_NONE, TX_MASS_MISSING_ACTIVE_CONTRIBUTION
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t
  implicit none
  private

  type, extends(canonical_state_t), public :: fkt08_state_t
    real(real64) :: store_a = 0.0_real64
    real(real64) :: store_b = 0.0_real64
    real(real64), allocatable :: optional_store
  contains
    procedure :: clone => fkt08_clone
  end type fkt08_state_t

  type, extends(kernel_parameters_t), public :: fkt08_parameters_t
    logical :: optional_active = .false.
    logical :: external_accounting_complete = .true.
  end type fkt08_parameters_t

  type, extends(canonical_forcing_t), public :: fkt08_forcing_t
    real(real64) :: inflow_rate = 0.0_real64
    real(real64) :: outflow_rate = 0.0_real64
    real(real64) :: internal_transfer_rate = 0.0_real64
  end type fkt08_forcing_t

  type, extends(kernel_model_t), public :: fkt08_model_t
    logical :: optional_active = .false.
    logical :: external_accounting_complete = .true.
    logical :: always_fail = .false.
    integer :: fail_first_advances = 0
    integer :: advance_calls = 0
    real(real64) :: inflow_rate = 0.0_real64
    real(real64) :: outflow_rate = 0.0_real64
    real(real64) :: internal_transfer_rate = 0.0_real64
  contains
    procedure :: configure_parameters => configure_parameters
    procedure :: execution_admitted => execution_admitted
    procedure :: prepare_interval => prepare_interval
    procedure :: advance => advance
    procedure :: storage => storage
    procedure :: storage_accounting_status => storage_accounting_status
    procedure :: temporal_error => temporal_error
  end type fkt08_model_t

contains

  subroutine fkt08_clone(self, copy)
    class(fkt08_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy

    allocate(fkt08_state_t :: copy)
    select type (copy)
    type is (fkt08_state_t)
      copy%store_a = self%store_a
      copy%store_b = self%store_b
      if (allocated(self%optional_store)) then
        allocate(copy%optional_store)
        copy%optional_store = self%optional_store
      end if
    end select
  end subroutine fkt08_clone

  subroutine configure_parameters(self, parameters)
    class(fkt08_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters

    select type (parameters)
    type is (fkt08_parameters_t)
      self%optional_active = parameters%optional_active
      self%external_accounting_complete = parameters%external_accounting_complete
    class default
      error stop 'FKT08 unexpected parameter type'
    end select
  end subroutine configure_parameters

  logical function execution_admitted(self, parameters, numerical_config)
    class(fkt08_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    logical :: parameter_ok

    parameter_ok = .false.
    select type (parameters)
    type is (fkt08_parameters_t)
      parameter_ok = .true.
    class default
      parameter_ok = .false.
    end select
    execution_admitted = parameter_ok .and. numerical_config%max_committed_substeps > 0
    if (self%advance_calls < 0) execution_admitted = .false.
  end function execution_admitted

  subroutine prepare_interval(self, forcing, interval, config)
    class(fkt08_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config

    if (interval%t1 <= interval%t0) error stop 'FKT08 invalid interval'
    if (config%max_committed_substeps <= 0) error stop 'FKT08 invalid numerical config'
    select type (forcing)
    type is (fkt08_forcing_t)
      self%inflow_rate = forcing%inflow_rate
      self%outflow_rate = forcing%outflow_rate
      self%internal_transfer_rate = forcing%internal_transfer_rate
    class default
      error stop 'FKT08 unexpected forcing type'
    end select
  end subroutine prepare_interval

  subroutine advance(self, state, t0, t1, outcome)
    class(fkt08_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: dt, transfer

    outcome = trial_outcome_t()
    self%advance_calls = self%advance_calls + 1
    if (self%always_fail .or. self%advance_calls <= self%fail_first_advances) return

    dt = t1 - t0
    if (dt <= 0.0_real64) return
    transfer = self%internal_transfer_rate * dt

    select type (state)
    type is (fkt08_state_t)
      state%store_a = state%store_a + self%inflow_rate*dt - self%outflow_rate*dt - transfer
      state%store_b = state%store_b + transfer
      outcome%mass_in = self%inflow_rate * dt
      outcome%mass_out = self%outflow_rate * dt
      outcome%solver_ok = .true.
      outcome%nonlinear_iterations = 1
      if (self%external_accounting_complete) then
        outcome%mass_accounting_complete = .true.
        outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
      else
        outcome%mass_accounting_complete = .false.
        outcome%missing_mass_contribution_mask = TX_MASS_MISSING_ACTIVE_CONTRIBUTION
      end if
    class default
      error stop 'FKT08 unexpected state type'
    end select
  end subroutine advance

  function storage(self, state) result(value)
    class(fkt08_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value

    value = 0.0_real64
    select type (state)
    type is (fkt08_state_t)
      value = state%store_a + state%store_b
      if (allocated(state%optional_store)) value = value + state%optional_store
    class default
      error stop 'FKT08 unexpected state type in storage'
    end select
    if (self%advance_calls < 0) error stop 'unreachable FKT08 storage state'
  end function storage

  subroutine storage_accounting_status(self, state, complete, missing_mask)
    class(fkt08_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask

    complete = .false.
    missing_mask = TX_MASS_MISSING_ACTIVE_CONTRIBUTION
    select type (state)
    type is (fkt08_state_t)
      if (self%optional_active .and. .not. allocated(state%optional_store)) return
      if (.not. self%optional_active .and. allocated(state%optional_store)) return
      complete = .true.
      missing_mask = TX_MASS_MISSING_NONE
    class default
      return
    end select
  end subroutine storage_accounting_status

  function temporal_error(self, full_state, half_state) result(value)
    class(fkt08_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    real(real64) :: value

    if (.not. same_type_as(full_state, half_state)) error stop 'FKT08 state mismatch'
    value = 0.0_real64
    if (self%advance_calls < 0) value = huge(0.0_real64)
  end function temporal_error

end module mod_fkt08_test_model

program test_fkt08_mass_accounting
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference, only: transaction_state_t, TX_MASS_MISSING_NONE, &
       TX_MASS_MISSING_STORAGE_START, TX_MASS_MISSING_ACTIVE_CONTRIBUTION
  use mod_canonical_contracts, only: canonical_numerical_config_t, canonical_mass_accounting_t, &
       CANONICAL_STATUS_COMPLETED, CANONICAL_STATUS_TRANSACTION_FAILED
  use mod_kernel_transactions
  use mod_fkt08_test_model
  implicit none

  integer :: failures

  failures = 0
  call test_complete_simple_case(failures)
  call test_missing_active_contribution(failures)
  call test_inactive_optional_no_payload(failures)
  call test_active_optional_missing(failures)
  call test_internal_transfer(failures)
  call test_rejected_trial(failures)
  call test_retry_no_double_count(failures)
  call test_rollback(failures)
  call test_stale_second_commit(failures)
  call test_generic_time(failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'FKT08_MASS_ACCOUNTING_GATE FAIL failures=', failures
    error stop 1
  end if
  write(*,'(A)') 'FKT08_MASS_ACCOUNTING_GATE PASS'

contains

  subroutine expect_true(condition, label, failures)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures

    if (.not. condition) then
      failures = failures + 1
      write(*,'(A,A)') 'FAIL ', trim(label)
    end if
  end subroutine expect_true

  subroutine expect_exact(actual, expected, label, failures)
    real(real64), intent(in) :: actual, expected
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures

    call expect_true(transfer(actual, 0_int64) == transfer(expected, 0_int64), label, failures)
  end subroutine expect_exact

  subroutine expect_mask(mask, bit, label, failures)
    integer(int64), intent(in) :: mask, bit
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures

    call expect_true(iand(mask, bit) /= 0_int64, label, failures)
  end subroutine expect_mask

  subroutine new_physical(state, store_a, store_b, with_optional, optional_value)
    class(transaction_state_t), allocatable, intent(out) :: state
    real(real64), intent(in) :: store_a, store_b, optional_value
    logical, intent(in) :: with_optional

    allocate(fkt08_state_t :: state)
    select type (state)
    type is (fkt08_state_t)
      state%store_a = store_a
      state%store_b = store_b
      if (with_optional) then
        allocate(state%optional_store)
        state%optional_store = optional_value
      end if
    end select
  end subroutine new_physical

  subroutine new_committed(committed, lineage, t0, with_optional)
    type(kernel_committed_state_t), intent(out) :: committed
    integer(int64), intent(in) :: lineage
    real(real64), intent(in) :: t0
    logical, intent(in) :: with_optional
    class(transaction_state_t), allocatable :: state
    logical :: ok

    call new_physical(state, 6.0_real64, 4.0_real64, with_optional, 2.0_real64)
    call committed%initialize(lineage, state, ok, t0)
    if (.not. ok) error stop 'FKT08 committed-state initialization failed'
  end subroutine new_committed

  subroutine setup(parameters, forcing, config)
    type(fkt08_parameters_t), intent(out) :: parameters
    type(fkt08_forcing_t), intent(out) :: forcing
    type(canonical_numerical_config_t), intent(out) :: config

    parameters%optional_active = .false.
    parameters%external_accounting_complete = .true.
    forcing%inflow_rate = 0.5_real64
    forcing%outflow_rate = 0.25_real64
    forcing%internal_transfer_rate = 0.125_real64
    config%transaction%temporal_tolerance = 0.0_real64
    config%transaction%mass_tolerance = 0.0_real64
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 2
    config%max_committed_substeps = 8
    config%progress_tolerance = 0.0_real64
  end subroutine setup

  subroutine snapshot_total(committed, total, optional_allocated)
    type(kernel_committed_state_t), intent(in) :: committed
    real(real64), intent(out) :: total
    logical, intent(out), optional :: optional_allocated
    class(transaction_state_t), allocatable :: state
    logical :: available

    total = -1.0_real64
    if (present(optional_allocated)) optional_allocated = .false.
    call committed%snapshot(state, available)
    if (.not. available) return
    select type (state)
    type is (fkt08_state_t)
      total = state%store_a + state%store_b
      if (allocated(state%optional_store)) total = total + state%optional_store
      if (present(optional_allocated)) optional_allocated = allocated(state%optional_store)
    class default
      error stop 'FKT08 snapshot type mismatch'
    end select
  end subroutine snapshot_total

  subroutine test_complete_simple_case(failures)
    integer, intent(inout) :: failures
    type(fkt08_parameters_t) :: parameters
    type(fkt08_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt08_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_committed_state_t) :: committed
    type(kernel_candidate_state_t) :: candidate
    type(kernel_result_t) :: result
    type(kernel_diagnostics_t) :: diagnostics
    type(canonical_mass_accounting_t) :: accepted_mass, second_mass
    real(real64) :: total
    logical :: did_commit
    integer :: commit_status

    call setup(parameters, forcing, config)
    call new_committed(committed, 101_int64, 0.25_real64, .false.)
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 0.25_real64, 0.625_real64, &
         result, candidate, diagnostics)

    call expect_true(result%status == CANONICAL_STATUS_COMPLETED, 'simple completed', failures)
    call expect_true(result%completed, 'simple completion flag', failures)
    call expect_true(result%mass%complete, 'simple complete mass', failures)
    call expect_true(result%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, &
         'simple missing mask', failures)
    call expect_true(result%mass%accepted_transaction_count == 1, 'simple accepted tx count', failures)
    call expect_exact(result%mass%interval_t0, 0.25_real64, 'simple interval t0', failures)
    call expect_exact(result%mass%interval_t1, 0.625_real64, 'simple interval t1', failures)
    call expect_true(result%mass%origin_lineage_id == 101_int64, 'simple lineage provenance', failures)
    call expect_true(result%mass%origin_revision == 0_int64, 'simple revision provenance', failures)
    call expect_exact(result%mass%storage_start, 10.0_real64, 'simple storage start', failures)
    call expect_exact(result%mass%storage_end, 10.09375_real64, 'simple storage end', failures)
    call expect_exact(result%mass%storage_change, 0.09375_real64, 'simple storage change', failures)
    call expect_exact(result%mass%total_in, 0.1875_real64, 'simple total in', failures)
    call expect_exact(result%mass%total_out, 0.09375_real64, 'simple total out', failures)
    call expect_exact(result%mass%residual, 0.0_real64, 'simple residual', failures)
    call snapshot_total(committed, total)
    call expect_exact(total, 10.0_real64, 'trial does not mutate committed state', failures)

    call kernel%commit_candidate(committed, candidate, diagnostics, did_commit, commit_status, accepted_mass)
    call expect_true(did_commit, 'simple commit succeeds', failures)
    call expect_true(commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'simple commit status', failures)
    call expect_true(accepted_mass%complete, 'commit publishes complete accepted mass', failures)
    call expect_exact(accepted_mass%residual, 0.0_real64, 'commit mass residual', failures)
    call snapshot_total(committed, total)
    call expect_exact(total, 10.09375_real64, 'commit publishes candidate state', failures)
    call expect_true(committed%current_revision() == 1_int64, 'commit increments revision once', failures)

    call kernel%commit_candidate(committed, candidate, diagnostics, did_commit, commit_status, second_mass)
    call expect_true(.not. did_commit, 'second commit rejected', failures)
    call expect_true(.not. second_mass%complete, 'second commit publishes no accepted mass', failures)
  end subroutine test_complete_simple_case

  subroutine test_missing_active_contribution(failures)
    integer, intent(inout) :: failures
    type(fkt08_parameters_t) :: parameters
    type(fkt08_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt08_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_committed_state_t) :: committed
    type(kernel_candidate_state_t) :: candidate
    type(kernel_result_t) :: result
    type(kernel_diagnostics_t) :: diagnostics

    call setup(parameters, forcing, config)
    parameters%external_accounting_complete = .false.
    call new_committed(committed, 102_int64, 0.0_real64, .false.)
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 0.0_real64, 0.25_real64, &
         result, candidate, diagnostics)

    call expect_true(result%completed, 'missing active still physical completion', failures)
    call expect_true(.not. result%mass%complete, 'missing active blocks completeness', failures)
    call expect_mask(result%mass%missing_contribution_mask, TX_MASS_MISSING_ACTIVE_CONTRIBUTION, &
         'missing active diagnostic bit', failures)
  end subroutine test_missing_active_contribution

  subroutine test_inactive_optional_no_payload(failures)
    integer, intent(inout) :: failures
    type(fkt08_parameters_t) :: parameters
    type(fkt08_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt08_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_committed_state_t) :: committed
    type(kernel_candidate_state_t) :: candidate
    type(kernel_result_t) :: result
    type(kernel_diagnostics_t) :: diagnostics
    real(real64) :: total
    logical :: optional_allocated

    call setup(parameters, forcing, config)
    parameters%optional_active = .false.
    call new_committed(committed, 103_int64, 0.0_real64, .false.)
    call snapshot_total(committed, total, optional_allocated)
    call expect_true(.not. optional_allocated, 'inactive optional has no allocated payload', failures)
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 0.0_real64, 0.25_real64, &
         result, candidate, diagnostics)
    call expect_true(result%mass%complete, 'inactive optional does not block completeness', failures)
  end subroutine test_inactive_optional_no_payload

  subroutine test_active_optional_missing(failures)
    integer, intent(inout) :: failures
    type(fkt08_parameters_t) :: parameters
    type(fkt08_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt08_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_committed_state_t) :: committed
    type(kernel_candidate_state_t) :: candidate
    type(kernel_result_t) :: result
    type(kernel_diagnostics_t) :: diagnostics

    call setup(parameters, forcing, config)
    parameters%optional_active = .true.
    call new_committed(committed, 104_int64, 0.0_real64, .false.)
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 0.0_real64, 0.25_real64, &
         result, candidate, diagnostics)
    call expect_true(result%completed, 'active optional missing physical completion', failures)
    call expect_true(.not. result%mass%complete, 'active optional missing blocks complete', failures)
    call expect_mask(result%mass%missing_contribution_mask, TX_MASS_MISSING_STORAGE_START, &
         'active optional missing start storage bit', failures)
    call expect_mask(result%mass%missing_contribution_mask, TX_MASS_MISSING_ACTIVE_CONTRIBUTION, &
         'active optional missing owner bit', failures)
  end subroutine test_active_optional_missing

  subroutine test_internal_transfer(failures)
    integer, intent(inout) :: failures
    type(fkt08_parameters_t) :: parameters
    type(fkt08_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt08_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_committed_state_t) :: committed
    type(kernel_candidate_state_t) :: candidate
    type(kernel_result_t) :: result
    type(kernel_diagnostics_t) :: diagnostics

    call setup(parameters, forcing, config)
    forcing%inflow_rate = 0.0_real64
    forcing%outflow_rate = 0.0_real64
    forcing%internal_transfer_rate = 0.5_real64
    call new_committed(committed, 105_int64, 0.0_real64, .false.)
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 0.0_real64, 0.5_real64, &
         result, candidate, diagnostics)
    call expect_true(result%mass%complete, 'internal transfer complete', failures)
    call expect_exact(result%mass%storage_start, 10.0_real64, 'internal storage start', failures)
    call expect_exact(result%mass%storage_end, 10.0_real64, 'internal storage end', failures)
    call expect_exact(result%mass%total_in, 0.0_real64, 'internal not external inflow', failures)
    call expect_exact(result%mass%total_out, 0.0_real64, 'internal not external outflow', failures)
    call expect_exact(result%mass%residual, 0.0_real64, 'internal transfer residual', failures)
  end subroutine test_internal_transfer

  subroutine test_rejected_trial(failures)
    integer, intent(inout) :: failures
    type(fkt08_parameters_t) :: parameters
    type(fkt08_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt08_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_committed_state_t) :: committed
    type(kernel_candidate_state_t) :: candidate
    type(kernel_result_t) :: result
    type(kernel_diagnostics_t) :: diagnostics
    real(real64) :: total, current_time
    logical :: time_available

    call setup(parameters, forcing, config)
    config%transaction%max_retries = 1
    model%always_fail = .true.
    call new_committed(committed, 106_int64, 0.25_real64, .false.)
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 0.25_real64, 0.5_real64, &
         result, candidate, diagnostics)
    call expect_true(result%status == CANONICAL_STATUS_TRANSACTION_FAILED, 'rejected trial status', failures)
    call expect_true(.not. result%completed, 'rejected trial incomplete', failures)
    call expect_true(.not. result%mass%complete, 'rejected trial no accepted mass', failures)
    call expect_true(.not. candidate%ready(), 'rejected trial no candidate', failures)
    call expect_true(committed%current_revision() == 0_int64, 'rejected trial revision unchanged', failures)
    call snapshot_total(committed, total)
    call expect_exact(total, 10.0_real64, 'rejected trial state unchanged', failures)
    call committed%current_time(current_time, time_available)
    call expect_true(time_available, 'rejected trial time remains available', failures)
    call expect_exact(current_time, 0.25_real64, 'rejected trial time unchanged', failures)
  end subroutine test_rejected_trial

  subroutine test_retry_no_double_count(failures)
    integer, intent(inout) :: failures
    type(fkt08_parameters_t) :: parameters
    type(fkt08_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt08_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_committed_state_t) :: committed
    type(kernel_candidate_state_t) :: candidate
    type(kernel_result_t) :: result
    type(kernel_diagnostics_t) :: diagnostics

    call setup(parameters, forcing, config)
    model%fail_first_advances = 1
    call new_committed(committed, 107_int64, 0.25_real64, .false.)
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 0.25_real64, 0.75_real64, &
         result, candidate, diagnostics)
    call expect_true(result%completed, 'retry full interval completes', failures)
    call expect_true(diagnostics%retries == 1, 'retry recorded once', failures)
    call expect_true(result%mass%accepted_transaction_count == 2, 'retry accepted segments count', failures)
    call expect_true(result%mass%complete, 'retry mass complete', failures)
    call expect_exact(result%mass%storage_start, 10.0_real64, 'retry storage start', failures)
    call expect_exact(result%mass%storage_end, 10.125_real64, 'retry storage end', failures)
    call expect_exact(result%mass%total_in, 0.25_real64, 'retry no duplicate inflow', failures)
    call expect_exact(result%mass%total_out, 0.125_real64, 'retry no duplicate outflow', failures)
    call expect_exact(result%mass%residual, 0.0_real64, 'retry residual', failures)
  end subroutine test_retry_no_double_count

  subroutine test_rollback(failures)
    integer, intent(inout) :: failures
    type(fkt08_parameters_t) :: parameters
    type(fkt08_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt08_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_committed_state_t) :: committed
    type(kernel_candidate_state_t) :: candidate
    type(kernel_result_t) :: result
    type(kernel_diagnostics_t) :: diagnostics
    real(real64) :: total, current_time
    logical :: time_available

    call setup(parameters, forcing, config)
    call new_committed(committed, 108_int64, 0.25_real64, .false.)
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 0.25_real64, 0.5_real64, &
         result, candidate, diagnostics)
    call expect_true(result%mass%complete, 'rollback candidate mass complete before rollback', failures)
    call kernel%rollback_candidate(candidate, diagnostics)
    call expect_true(.not. candidate%ready(), 'rollback invalidates candidate', failures)
    call expect_true(committed%current_revision() == 0_int64, 'rollback revision unchanged', failures)
    call snapshot_total(committed, total)
    call expect_exact(total, 10.0_real64, 'rollback state unchanged', failures)
    call committed%current_time(current_time, time_available)
    call expect_true(time_available, 'rollback time remains available', failures)
    call expect_exact(current_time, 0.25_real64, 'rollback time unchanged', failures)
  end subroutine test_rollback

  subroutine test_stale_second_commit(failures)
    integer, intent(inout) :: failures
    type(fkt08_parameters_t) :: parameters
    type(fkt08_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt08_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_committed_state_t) :: committed
    type(kernel_candidate_state_t) :: candidate_a, candidate_b
    type(kernel_result_t) :: result_a, result_b
    type(kernel_diagnostics_t) :: diagnostics_a, diagnostics_b
    type(canonical_mass_accounting_t) :: accepted_a, accepted_b
    logical :: did_commit
    integer :: commit_status

    call setup(parameters, forcing, config)
    call new_committed(committed, 109_int64, 0.0_real64, .false.)
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 0.0_real64, 0.25_real64, &
         result_a, candidate_a, diagnostics_a)
    call kernel%advance_interval(parameters, committed, forcing, config, 0.0_real64, 0.25_real64, &
         result_b, candidate_b, diagnostics_b)
    call kernel%commit_candidate(committed, candidate_a, diagnostics_a, did_commit, commit_status, accepted_a)
    call expect_true(did_commit .and. accepted_a%complete, 'first sibling commit publishes mass', failures)
    call kernel%commit_candidate(committed, candidate_b, diagnostics_b, did_commit, commit_status, accepted_b)
    call expect_true(.not. did_commit, 'stale sibling rejected', failures)
    call expect_true(commit_status == KERNEL_COMMIT_STATUS_STALE_REVISION, 'stale sibling status', failures)
    call expect_true(.not. accepted_b%complete, 'stale sibling publishes no mass', failures)
    call expect_true(committed%current_revision() == 1_int64, 'stale sibling no second revision', failures)
  end subroutine test_stale_second_commit

  subroutine test_generic_time(failures)
    integer, intent(inout) :: failures

    call run_generic_case(201_int64, 0.125_real64, 0.375_real64, 'subdaily', failures)
    call run_generic_case(202_int64, 10.25_real64, 10.5_real64, 'non-midnight', failures)
    call run_generic_case(203_int64, 0.875_real64, 1.125_real64, 'cross-midnight', failures)
  end subroutine test_generic_time

  subroutine run_generic_case(lineage, t0, t1, label, failures)
    integer(int64), intent(in) :: lineage
    real(real64), intent(in) :: t0, t1
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    type(fkt08_parameters_t) :: parameters
    type(fkt08_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt08_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_committed_state_t) :: committed
    type(kernel_candidate_state_t) :: candidate
    type(kernel_result_t) :: result
    type(kernel_diagnostics_t) :: diagnostics

    call setup(parameters, forcing, config)
    call new_committed(committed, lineage, t0, .false.)
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, t0, t1, result, candidate, diagnostics)
    call expect_true(result%completed, trim(label)//' completed', failures)
    call expect_true(result%mass%complete, trim(label)//' mass complete', failures)
    call expect_exact(result%mass%interval_t0, t0, trim(label)//' mass t0', failures)
    call expect_exact(result%mass%interval_t1, t1, trim(label)//' mass t1', failures)
    call expect_exact(result%mass%residual, 0.0_real64, trim(label)//' residual', failures)
  end subroutine run_generic_case

end program test_fkt08_mass_accounting
