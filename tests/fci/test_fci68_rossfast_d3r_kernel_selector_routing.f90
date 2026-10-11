module mod_fci68_kernel_model
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_forcing_t, canonical_interval_t, canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t
  implicit none
  private

  type, extends(transaction_state_t), public :: fci68_state_t
    real(real64) :: water = 1.0_real64
  contains
    procedure :: clone => fci68_clone
  end type fci68_state_t

  type, extends(kernel_parameters_t), public :: fci68_parameters_t
  end type fci68_parameters_t

  type, extends(canonical_forcing_t), public :: fci68_forcing_t
  end type fci68_forcing_t

  type, extends(kernel_model_t), public :: fci68_model_t
    integer :: prepare_calls = 0
    integer :: configure_calls = 0
  contains
    procedure :: configure_parameters => fci68_configure_parameters
    procedure :: execution_admitted => fci68_execution_admitted
    procedure :: prepare_interval => fci68_prepare_interval
    procedure :: advance => fci68_advance
    procedure :: storage => fci68_storage
    procedure :: storage_accounting_status => fci68_storage_accounting_status
    procedure :: temporal_error => fci68_temporal_error
  end type fci68_model_t

contains

  subroutine fci68_clone(self, copy)
    class(fci68_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy

    allocate(fci68_state_t :: copy)
    select type (copy)
    type is (fci68_state_t)
      copy%water = self%water
    end select
  end subroutine fci68_clone

  subroutine fci68_configure_parameters(self, parameters)
    class(fci68_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters

    select type (parameters)
    type is (fci68_parameters_t)
      self%configure_calls = self%configure_calls + 1
    class default
      error stop 'FCI68 unexpected parameter type'
    end select
  end subroutine fci68_configure_parameters

  logical function fci68_execution_admitted(self, parameters, numerical_config)
    class(fci68_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config

    fci68_execution_admitted = self%prepare_calls >= 0 .and. numerical_config%max_committed_substeps > 0
    select type (parameters)
    type is (fci68_parameters_t)
      continue
    class default
      fci68_execution_admitted = .false.
    end select
  end function fci68_execution_admitted

  subroutine fci68_prepare_interval(self, forcing, interval, config)
    class(fci68_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config

    select type (forcing)
    type is (fci68_forcing_t)
      if (interval%t1 <= interval%t0 .or. config%max_committed_substeps <= 0) then
        error stop 'FCI68 invalid prepared interval'
      end if
      self%prepare_calls = self%prepare_calls + 1
    class default
      error stop 'FCI68 unexpected forcing type'
    end select
  end subroutine fci68_prepare_interval

  subroutine fci68_advance(self, state, t0, t1, outcome)
    class(fci68_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome

    if (self%configure_calls <= 0 .or. t1 <= t0) error stop 'FCI68 invalid advance context'
    outcome = trial_outcome_t()
    select type (state)
    type is (fci68_state_t)
      outcome%solver_ok = .true.
      outcome%mass_accounting_complete = .true.
      outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
      outcome%temporal_certificate_available = .true.
      outcome%temporal_indicator = 0.0_real64
      outcome%nonlinear_iterations = 1
    class default
      error stop 'FCI68 unexpected state type'
    end select
  end subroutine fci68_advance

  real(real64) function fci68_storage(self, state) result(value)
    class(fci68_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state

    if (self%configure_calls < 0) error stop 'FCI68 unreachable configure count'
    select type (state)
    type is (fci68_state_t)
      value = state%water
    class default
      error stop 'FCI68 unexpected storage state type'
    end select
  end function fci68_storage

  subroutine fci68_storage_accounting_status(self, state, complete, missing_mask)
    class(fci68_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask

    complete = self%configure_calls >= 0
    missing_mask = TX_MASS_MISSING_NONE
    select type (state)
    type is (fci68_state_t)
      complete = complete .and. state%water >= 0.0_real64
    class default
      complete = .false.
    end select
    if (.not. complete) missing_mask = 1_int64
  end subroutine fci68_storage_accounting_status

  real(real64) function fci68_temporal_error(self, full_state, half_state) result(value)
    class(fci68_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state

    if (self%configure_calls < 0 .or. .not. same_type_as(full_state, half_state)) then
      value = huge(0.0_real64)
    else
      value = 0.0_real64
    end if
  end function fci68_temporal_error

end module mod_fci68_kernel_model

program test_fci68_rossfast_d3r_kernel_selector_routing
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED, &
       CANONICAL_STATUS_INVALID_REQUEST
  use mod_kernel_transactions, only: kernel_executor_t, kernel_committed_state_t, kernel_checkpoint_t, &
       kernel_result_t, kernel_candidate_state_t, kernel_diagnostics_t, KERNEL_COMMIT_STATUS_COMMITTED
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint, fmr_trial_from_checkpoint, fmr_commit_candidate
  use mod_rossfast_d3r_execution_policy, only: apply_rossfast_d3r_retry_policy, &
       rossfast_d3r_select_transaction_window
  use mod_fci68_kernel_model
  implicit none

  integer :: failures

  failures = 0
  call test_default_path_unchanged(failures)
  call test_rossfast_selector_routes_through_checkpoint_kernel(failures)
  call test_rossfast_selector_fails_closed_off_grid(failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'FCI68_ROSSFAST_D3R_KERNEL_SELECTOR_ROUTING FAIL failures=', failures
    error stop 1
  end if
  write(*,'(A)') 'FCI68_ROSSFAST_D3R_KERNEL_SELECTOR_ROUTING PASS'

contains

  subroutine initialize_case(model, kernel, committed, checkpoint, parameters, forcing, config)
    type(fci68_model_t), target, intent(out) :: model
    type(kernel_executor_t), intent(out) :: kernel
    type(kernel_committed_state_t), intent(out) :: committed
    type(kernel_checkpoint_t), intent(out) :: checkpoint
    type(fci68_parameters_t), intent(out) :: parameters
    type(fci68_forcing_t), intent(out) :: forcing
    type(canonical_numerical_config_t), intent(out) :: config

    class(transaction_state_t), allocatable :: initial_state
    logical :: ok

    allocate(fci68_state_t :: initial_state)
    select type (initial_state)
    type is (fci68_state_t)
      initial_state%water = 1.0_real64
    end select

    call committed%initialize(68_int64, initial_state, ok, 0.0_real64)
    if (.not. ok) error stop 'FCI68 failed to initialize committed state'
    call fmr_capture_checkpoint(committed, checkpoint, ok)
    if (.not. ok) error stop 'FCI68 failed to capture checkpoint'
    call kernel%bind_model(model)

    call apply_rossfast_d3r_retry_policy(config)
    config%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    config%transaction%mass_tolerance = 1.0e-12_real64
    config%max_committed_substeps = 16
    config%progress_tolerance = 0.0_real64
  end subroutine initialize_case

  subroutine test_default_path_unchanged(failures)
    integer, intent(inout) :: failures
    type(fci68_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_committed_state_t) :: committed
    type(kernel_checkpoint_t) :: checkpoint
    type(fci68_parameters_t) :: parameters
    type(fci68_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics

    call initialize_case(model, kernel, committed, checkpoint, parameters, forcing, config)
    call fmr_trial_from_checkpoint(kernel, parameters, committed, forcing, config, 0.0_real64, 0.0012_real64, &
         checkpoint, result, candidate, diagnostics)

    call expect_true(result%status == CANONICAL_STATUS_COMPLETED, 'default route status', failures)
    call expect_true(result%completed, 'default route completed', failures)
    call expect_true(diagnostics%transaction_calls == 1, 'default route one transaction', failures)
    call expect_true(diagnostics%accepted_substeps == 1, 'default route one accepted substep', failures)
    call expect_true(diagnostics%checkpoint_uses == 1, 'default route checkpoint used', failures)
    call expect_true(candidate%ready(), 'default route candidate materialized', failures)
    call expect_true(committed%current_revision() == 0_int64, 'default route committed revision untouched', failures)
  end subroutine test_default_path_unchanged

  subroutine test_rossfast_selector_routes_through_checkpoint_kernel(failures)
    integer, intent(inout) :: failures
    type(fci68_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_committed_state_t) :: committed
    type(kernel_checkpoint_t) :: checkpoint
    type(fci68_parameters_t) :: parameters
    type(fci68_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    real(real64) :: committed_time
    logical :: time_available, did_commit
    integer :: commit_status

    call initialize_case(model, kernel, committed, checkpoint, parameters, forcing, config)
    call fmr_trial_from_checkpoint(kernel, parameters, committed, forcing, config, 0.0_real64, 0.0012_real64, &
         checkpoint, result, candidate, diagnostics, rossfast_d3r_select_transaction_window)

    call expect_true(result%status == CANONICAL_STATUS_COMPLETED, 'selector route status', failures)
    call expect_true(result%completed, 'selector route completed', failures)
    call expect_close(result%completed_t, 0.0012_real64, 1.0e-15_real64, 'selector reaches requested endpoint', failures)
    call expect_true(diagnostics%transaction_calls == 2, 'selector decomposes 0.0012 into two transactions', failures)
    call expect_true(diagnostics%accepted_substeps == 2, 'selector commits two private substeps', failures)
    call expect_true(diagnostics%retries == 0, 'selector decomposition needs no retry', failures)
    call expect_true(diagnostics%checkpoint_uses == 1, 'selector route checkpoint used', failures)
    call expect_true(candidate%ready(), 'selector candidate materialized', failures)
    call expect_true(committed%current_revision() == 0_int64, 'selector trial leaves committed revision untouched', failures)
    call committed%current_time(committed_time, time_available)
    call expect_true(time_available, 'selector committed time remains available', failures)
    call expect_close(committed_time, 0.0_real64, 0.0_real64, 'selector trial leaves committed time untouched', failures)

    call fmr_commit_candidate(kernel, committed, candidate, diagnostics, did_commit, commit_status)
    call expect_true(did_commit, 'selector candidate explicit commit succeeds', failures)
    call expect_true(commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'selector commit status', failures)
    call expect_true(committed%current_revision() == 1_int64, 'selector explicit commit increments revision once', failures)
    call committed%current_time(committed_time, time_available)
    call expect_true(time_available, 'selector committed endpoint available', failures)
    call expect_close(committed_time, 0.0012_real64, 1.0e-15_real64, 'selector explicit commit publishes endpoint', failures)
    call expect_true(.not. candidate%ready(), 'selector candidate consumed by commit', failures)
  end subroutine test_rossfast_selector_routes_through_checkpoint_kernel

  subroutine test_rossfast_selector_fails_closed_off_grid(failures)
    integer, intent(inout) :: failures
    type(fci68_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_committed_state_t) :: committed
    type(kernel_checkpoint_t) :: checkpoint
    type(fci68_parameters_t) :: parameters
    type(fci68_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics

    call initialize_case(model, kernel, committed, checkpoint, parameters, forcing, config)
    call fmr_trial_from_checkpoint(kernel, parameters, committed, forcing, config, 0.0_real64, 0.001201_real64, &
         checkpoint, result, candidate, diagnostics, rossfast_d3r_select_transaction_window)

    call expect_true(result%status == CANONICAL_STATUS_INVALID_REQUEST, 'off-grid route fails closed', failures)
    call expect_true(.not. result%completed, 'off-grid route not completed', failures)
    call expect_true(diagnostics%transaction_calls == 0, 'off-grid route rejects before transaction', failures)
    call expect_true(.not. candidate%ready(), 'off-grid route has no candidate', failures)
    call expect_true(committed%current_revision() == 0_int64, 'off-grid route leaves committed revision untouched', failures)
  end subroutine test_rossfast_selector_fails_closed_off_grid

  subroutine expect_true(condition, label, failures)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures

    if (.not. condition) then
      failures = failures + 1
      write(*,'(A,A)') 'FAIL ', trim(label)
    end if
  end subroutine expect_true

  subroutine expect_close(actual, expected, tolerance, label, failures)
    real(real64), intent(in) :: actual, expected, tolerance
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures

    call expect_true(abs(actual - expected) <= tolerance, label, failures)
  end subroutine expect_close

end program test_fci68_rossfast_d3r_kernel_selector_routing
