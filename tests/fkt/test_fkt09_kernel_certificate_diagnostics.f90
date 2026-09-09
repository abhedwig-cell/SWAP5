module mod_fkt09_kernel_certificate_model
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference
  use mod_canonical_contracts
  use mod_kernel_transactions
  implicit none
  private

  type, extends(transaction_state_t), public :: kernel_certificate_state_t
    real(real64) :: storage = 0.0_real64
  contains
    procedure :: clone => kernel_certificate_clone
  end type kernel_certificate_state_t

  type, extends(kernel_parameters_t), public :: kernel_certificate_parameters_t
    real(real64) :: certified_dt = 0.25_real64
  end type kernel_certificate_parameters_t

  type, extends(canonical_forcing_t), public :: kernel_certificate_forcing_t
    real(real64) :: rate = 1.0_real64
  end type kernel_certificate_forcing_t

  type, extends(transaction_attempt_context_t) :: kernel_certificate_context_t
    integer :: counter = 0
  end type kernel_certificate_context_t

  type, extends(kernel_model_t), public :: kernel_certificate_model_t
    real(real64) :: rate = 0.0_real64
    real(real64) :: certified_dt = 0.25_real64
    integer :: counter = 0
  contains
    procedure :: configure_parameters => kernel_certificate_configure
    procedure :: execution_admitted => kernel_certificate_admitted
    procedure :: prepare_interval => kernel_certificate_prepare
    procedure :: advance => kernel_certificate_advance
    procedure :: storage => kernel_certificate_storage
    procedure :: temporal_error => kernel_certificate_external_error
    procedure :: storage_accounting_status => kernel_certificate_storage_status
    procedure :: capture_attempt_context => kernel_certificate_capture
    procedure :: restore_attempt_context => kernel_certificate_restore
  end type kernel_certificate_model_t

contains

  subroutine kernel_certificate_clone(self, copy)
    class(kernel_certificate_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(kernel_certificate_state_t :: copy)
    select type (copy)
    type is (kernel_certificate_state_t)
      copy%storage = self%storage
    class default
      error stop 'F-KT09 kernel clone type mismatch'
    end select
  end subroutine kernel_certificate_clone

  subroutine kernel_certificate_configure(self, parameters)
    class(kernel_certificate_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    select type (parameters)
    type is (kernel_certificate_parameters_t)
      self%certified_dt = parameters%certified_dt
    class default
      error stop 'F-KT09 kernel parameter type mismatch'
    end select
  end subroutine kernel_certificate_configure

  logical function kernel_certificate_admitted(self, parameters, numerical_config) result(admitted)
    class(kernel_certificate_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    logical :: parameter_ok
    parameter_ok = .false.
    select type (parameters)
    type is (kernel_certificate_parameters_t)
      parameter_ok = parameters%certified_dt > 0.0_real64
    class default
      parameter_ok = .false.
    end select
    admitted = self%certified_dt > 0.0_real64 .and. parameter_ok .and. &
         numerical_config%transaction%temporal_mode == TX_TEMPORAL_MODEL_CERTIFICATE
  end function kernel_certificate_admitted

  subroutine kernel_certificate_prepare(self, forcing, interval, config)
    class(kernel_certificate_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    if (interval%t1 <= interval%t0 .or. config%max_committed_substeps <= 0) then
      error stop 'F-KT09 kernel invalid interval'
    end if
    select type (forcing)
    type is (kernel_certificate_forcing_t)
      self%rate = forcing%rate
    class default
      error stop 'F-KT09 kernel forcing type mismatch'
    end select
  end subroutine kernel_certificate_prepare

  subroutine kernel_certificate_capture(self, context)
    class(kernel_certificate_model_t), intent(inout) :: self
    class(transaction_attempt_context_t), allocatable, intent(out) :: context
    allocate(kernel_certificate_context_t :: context)
    select type (context)
    type is (kernel_certificate_context_t)
      context%counter = self%counter
    class default
      error stop 'F-KT09 kernel context allocation mismatch'
    end select
  end subroutine kernel_certificate_capture

  subroutine kernel_certificate_restore(self, context)
    class(kernel_certificate_model_t), intent(inout) :: self
    class(transaction_attempt_context_t), intent(in) :: context
    select type (context)
    type is (kernel_certificate_context_t)
      self%counter = context%counter
    class default
      error stop 'F-KT09 kernel context type mismatch'
    end select
  end subroutine kernel_certificate_restore

  subroutine kernel_certificate_advance(self, state, t0, t1, outcome)
    class(kernel_certificate_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: dt, amount

    outcome = trial_outcome_t()
    dt = t1 - t0
    amount = self%rate * dt
    self%counter = self%counter + 1
    select type (state)
    type is (kernel_certificate_state_t)
      state%storage = state%storage + amount
    class default
      error stop 'F-KT09 kernel advance state mismatch'
    end select
    outcome%solver_ok = .true.
    outcome%mass_in = amount
    outcome%mass_out = 0.0_real64
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    outcome%temporal_certificate_available = .true.
    outcome%temporal_indicator = dt / self%certified_dt
    outcome%nonlinear_iterations = 1
    outcome%linear_solves = 1
  end subroutine kernel_certificate_advance

  function kernel_certificate_storage(self, state) result(value)
    class(kernel_certificate_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value
    if (self%certified_dt <= 0.0_real64) error stop 'F-KT09 invalid kernel certified dt'
    select type (state)
    type is (kernel_certificate_state_t)
      value = state%storage
    class default
      error stop 'F-KT09 kernel storage state mismatch'
    end select
  end function kernel_certificate_storage

  subroutine kernel_certificate_storage_status(self, state, complete, missing_mask)
    class(kernel_certificate_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    if (self%certified_dt <= 0.0_real64) error stop 'F-KT09 invalid kernel status model'
    select type (state)
    type is (kernel_certificate_state_t)
      complete = .true.
      missing_mask = TX_MASS_MISSING_NONE
    class default
      complete = .false.
      missing_mask = TX_MASS_MISSING_UNSPECIFIED
    end select
  end subroutine kernel_certificate_storage_status

  function kernel_certificate_external_error(self, full_state, half_state) result(value)
    class(kernel_certificate_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    real(real64) :: value
    if (self%counter < -huge(0)) error stop 'F-KT09 unreachable kernel model state'
    if (.not. same_type_as(full_state, half_state)) error stop 'F-KT09 kernel external type mismatch'
    value = 0.0_real64
  end function kernel_certificate_external_error

end module mod_fkt09_kernel_certificate_model

program test_fkt09_kernel_certificate_diagnostics
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference
  use mod_canonical_contracts
  use mod_kernel_transactions
  use mod_fkt09_kernel_certificate_model
  implicit none

  class(transaction_state_t), allocatable :: initial_state, snapshot
  type(kernel_committed_state_t) :: committed
  type(kernel_candidate_state_t) :: candidate
  type(kernel_certificate_parameters_t) :: parameters
  type(kernel_certificate_forcing_t) :: forcing
  type(kernel_certificate_model_t), target :: model
  type(kernel_executor_t) :: executor
  type(canonical_numerical_config_t) :: config
  type(kernel_result_t) :: result
  type(kernel_diagnostics_t) :: diagnostics
  type(canonical_mass_accounting_t) :: accepted_mass
  logical :: did_initialize, available, did_commit
  integer :: commit_status
  integer :: failures
  real(real64), parameter :: t0 = 50.125_real64, t1 = 51.125_real64

  failures = 0
  allocate(kernel_certificate_state_t :: initial_state)
  select type (initial_state)
  type is (kernel_certificate_state_t)
    initial_state%storage = 0.0_real64
  end select
  call committed%initialize(9009_int64, initial_state, did_initialize, t0)
  call expect_true(did_initialize, 'guarded committed state initialized', failures)

  parameters%certified_dt = 0.25_real64
  forcing%rate = 1.0_real64
  config = canonical_numerical_config_t()
  config%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
  config%transaction%mass_tolerance = 1.0e-12_real64
  config%transaction%retry_scale = 0.5_real64
  config%transaction%max_retries = 4
  config%max_committed_substeps = 10
  call executor%bind_model(model)

  call executor%advance_interval(parameters, committed, forcing, config, t0, t1, result, candidate, diagnostics)
  call expect_true(result%completed, 'kernel certificate interval completed', failures)
  call expect_true(candidate%ready(), 'kernel candidate materialized', failures)
  call expect_true(committed%current_revision() == 0_int64, 'advance does not mutate committed revision', failures)
  call committed%snapshot(snapshot, available)
  call expect_true(available, 'committed snapshot available before commit', failures)
  call expect_close(storage_of(snapshot), 0.0_real64, 0.0_real64, 'committed state unchanged before commit', failures)

  call expect_true(diagnostics%temporal_acceptance_source == TX_TEMPORAL_MODEL_CERTIFICATE, &
       'kernel exposes temporal acceptance source', failures)
  call expect_true(diagnostics%temporal_rejections > 0 .and. diagnostics%trial_rollbacks > 0, &
       'kernel exposes certificate retries', failures)
  call expect_true(diagnostics%temporal_certificate_unavailable_rejections == 0, &
       'kernel unavailable-certificate count clean', failures)
  call expect_true(diagnostics%accepted_substeps == 5, 'kernel exposes five accepted private substeps', failures)
  call expect_close(diagnostics%max_temporal_indicator, 1.0_real64, 1.0e-14_real64, &
       'kernel exposes bounded temporal indicator', failures)
  call expect_close(diagnostics%min_accepted_substep_duration, 0.140625_real64, 1.0e-14_real64, &
       'kernel exposes minimum accepted dt', failures)
  call expect_close(diagnostics%max_accepted_substep_duration, 0.25_real64, 1.0e-14_real64, &
       'kernel exposes maximum accepted dt', failures)
  call expect_true(result%mass%complete, 'kernel candidate mass ledger complete', failures)
  call expect_close(result%mass%residual, 0.0_real64, 1.0e-14_real64, 'kernel candidate hard mass closure', failures)

  call executor%commit_candidate(committed, candidate, diagnostics, did_commit, commit_status, accepted_mass)
  call expect_true(did_commit .and. commit_status == KERNEL_COMMIT_STATUS_COMMITTED, &
       'explicit candidate commit succeeds', failures)
  call expect_true(committed%current_revision() == 1_int64, 'commit increments guarded revision', failures)
  call committed%snapshot(snapshot, available)
  call expect_true(available, 'committed snapshot available after commit', failures)
  call expect_close(storage_of(snapshot), 1.0_real64, 1.0e-14_real64, 'committed state advances only on commit', failures)
  call expect_true(accepted_mass%complete, 'accepted committed mass ledger complete', failures)
  call expect_true(diagnostics%committed_state_mutations == 1, 'one explicit committed-state mutation', failures)

  if (failures /= 0) then
    print '(A,I0)', 'FKT09_KERNEL_CERTIFICATE_GATE FAIL failures=', failures
    error stop 1
  end if
  print '(A)', 'FKT09_KERNEL_CERTIFICATE_GATE PASS'

contains

  function storage_of(state) result(value)
    class(transaction_state_t), allocatable, intent(in) :: state
    real(real64) :: value
    select type (state)
    type is (kernel_certificate_state_t)
      value = state%storage
    class default
      error stop 'F-KT09 kernel snapshot state mismatch'
    end select
  end function storage_of

  subroutine expect_true(condition, label, failures)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    if (.not. condition) then
      failures = failures + 1
      print '(A,A)', 'FAIL ', trim(label)
    end if
  end subroutine expect_true

  subroutine expect_close(actual, expected, tol, label, failures)
    real(real64), intent(in) :: actual, expected, tol
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    call expect_true(abs(actual-expected) <= tol, label, failures)
  end subroutine expect_close

end program test_fkt09_kernel_certificate_diagnostics
