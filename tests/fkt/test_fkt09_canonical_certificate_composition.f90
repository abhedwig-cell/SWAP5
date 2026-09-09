module mod_fkt09_canonical_certificate_model
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference
  use mod_canonical_contracts
  implicit none
  private

  type, extends(canonical_state_t), public :: canonical_certificate_state_t
    real(real64) :: storage = 0.0_real64
  contains
    procedure :: clone => canonical_certificate_clone
  end type canonical_certificate_state_t

  type, extends(canonical_forcing_t), public :: canonical_certificate_forcing_t
    real(real64) :: rate = 1.0_real64
  end type canonical_certificate_forcing_t

  type, extends(transaction_attempt_context_t) :: canonical_certificate_context_t
    integer :: counter = 0
  end type canonical_certificate_context_t

  type, extends(canonical_physical_model_t), public :: canonical_certificate_model_t
    real(real64) :: rate = 0.0_real64
    real(real64) :: certified_dt = 0.25_real64
    integer :: counter = 0
  contains
    procedure :: prepare_interval => canonical_certificate_prepare
    procedure :: advance => canonical_certificate_advance
    procedure :: storage => canonical_certificate_storage
    procedure :: temporal_error => canonical_certificate_external_error
    procedure :: storage_accounting_status => canonical_certificate_storage_status
    procedure :: capture_attempt_context => canonical_certificate_capture
    procedure :: restore_attempt_context => canonical_certificate_restore
  end type canonical_certificate_model_t

contains

  subroutine canonical_certificate_clone(self, copy)
    class(canonical_certificate_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(canonical_certificate_state_t :: copy)
    select type (copy)
    type is (canonical_certificate_state_t)
      copy%storage = self%storage
    class default
      error stop 'F-KT09 canonical clone type mismatch'
    end select
  end subroutine canonical_certificate_clone

  subroutine canonical_certificate_prepare(self, forcing, interval, config)
    class(canonical_certificate_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    if (interval%t1 <= interval%t0 .or. config%max_committed_substeps <= 0) then
      error stop 'F-KT09 invalid canonical test interval'
    end if
    select type (forcing)
    type is (canonical_certificate_forcing_t)
      self%rate = forcing%rate
    class default
      error stop 'F-KT09 canonical forcing type mismatch'
    end select
  end subroutine canonical_certificate_prepare

  subroutine canonical_certificate_capture(self, context)
    class(canonical_certificate_model_t), intent(inout) :: self
    class(transaction_attempt_context_t), allocatable, intent(out) :: context
    allocate(canonical_certificate_context_t :: context)
    select type (context)
    type is (canonical_certificate_context_t)
      context%counter = self%counter
    class default
      error stop 'F-KT09 canonical context allocation mismatch'
    end select
  end subroutine canonical_certificate_capture

  subroutine canonical_certificate_restore(self, context)
    class(canonical_certificate_model_t), intent(inout) :: self
    class(transaction_attempt_context_t), intent(in) :: context
    select type (context)
    type is (canonical_certificate_context_t)
      self%counter = context%counter
    class default
      error stop 'F-KT09 canonical context type mismatch'
    end select
  end subroutine canonical_certificate_restore

  subroutine canonical_certificate_advance(self, state, t0, t1, outcome)
    class(canonical_certificate_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: dt, amount

    outcome = trial_outcome_t()
    dt = t1 - t0
    amount = self%rate * dt
    self%counter = self%counter + 1
    select type (state)
    type is (canonical_certificate_state_t)
      state%storage = state%storage + amount
    class default
      error stop 'F-KT09 canonical advance state mismatch'
    end select
    outcome%solver_ok = .true.
    if (amount >= 0.0_real64) then
      outcome%mass_in = amount
      outcome%mass_out = 0.0_real64
    else
      outcome%mass_in = 0.0_real64
      outcome%mass_out = -amount
    end if
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    outcome%temporal_certificate_available = .true.
    outcome%temporal_indicator = dt / self%certified_dt
    outcome%nonlinear_iterations = 1
    outcome%linear_solves = 1
  end subroutine canonical_certificate_advance

  function canonical_certificate_storage(self, state) result(value)
    class(canonical_certificate_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value
    if (self%certified_dt <= 0.0_real64) error stop 'F-KT09 invalid certified dt'
    select type (state)
    type is (canonical_certificate_state_t)
      value = state%storage
    class default
      error stop 'F-KT09 canonical storage state mismatch'
    end select
  end function canonical_certificate_storage

  subroutine canonical_certificate_storage_status(self, state, complete, missing_mask)
    class(canonical_certificate_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    if (self%certified_dt <= 0.0_real64) error stop 'F-KT09 invalid storage-status model'
    select type (state)
    type is (canonical_certificate_state_t)
      complete = .true.
      missing_mask = TX_MASS_MISSING_NONE
    class default
      complete = .false.
      missing_mask = TX_MASS_MISSING_UNSPECIFIED
    end select
  end subroutine canonical_certificate_storage_status

  function canonical_certificate_external_error(self, full_state, half_state) result(value)
    class(canonical_certificate_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    real(real64) :: value
    if (self%counter < -huge(0)) error stop 'F-KT09 unreachable canonical model state'
    if (.not. same_type_as(full_state, half_state)) error stop 'F-KT09 canonical external type mismatch'
    value = 0.0_real64
  end function canonical_certificate_external_error

end module mod_fkt09_canonical_certificate_model

program test_fkt09_canonical_certificate_composition
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference
  use mod_canonical_contracts
  use mod_canonical_interval_runtime, only: run_canonical_interval
  use mod_fkt09_canonical_certificate_model
  implicit none

  integer :: failures
  failures = 0
  call test_full_interval_composition(failures)
  call test_substep_limit_does_not_publish_partial_state(failures)

  if (failures /= 0) then
    print '(A,I0)', 'FKT09_CANONICAL_CERTIFICATE_GATE FAIL failures=', failures
    error stop 1
  end if
  print '(A)', 'FKT09_CANONICAL_CERTIFICATE_GATE PASS'

contains

  subroutine new_state(state, value)
    class(transaction_state_t), allocatable, intent(out) :: state
    real(real64), intent(in) :: value
    allocate(canonical_certificate_state_t :: state)
    select type (state)
    type is (canonical_certificate_state_t)
      state%storage = value
    end select
  end subroutine new_state

  function storage_of(state) result(value)
    class(transaction_state_t), allocatable, intent(in) :: state
    real(real64) :: value
    select type (state)
    type is (canonical_certificate_state_t)
      value = state%storage
    class default
      error stop 'F-KT09 canonical output state mismatch'
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

  subroutine configure(config, max_substeps)
    type(canonical_numerical_config_t), intent(out) :: config
    integer, intent(in) :: max_substeps
    config = canonical_numerical_config_t()
    config%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    config%transaction%mass_tolerance = 1.0e-12_real64
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 4
    config%max_committed_substeps = max_substeps
    config%progress_tolerance = 0.0_real64
  end subroutine configure

  subroutine test_full_interval_composition(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(canonical_certificate_model_t) :: model
    type(canonical_certificate_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result

    call new_state(state, 0.0_real64)
    forcing%rate = 1.0_real64
    interval%t0 = 100.125_real64
    interval%t1 = 101.125_real64
    call configure(config, 10)
    call run_canonical_interval(model, state, forcing, interval, config, result)

    call expect_true(result%status == CANONICAL_STATUS_COMPLETED .and. result%completed, &
         'certificate substeps complete requested interval', failures)
    call expect_close(result%completed_t, interval%t1, 0.0_real64, 'completed t1 exact', failures)
    call expect_close(storage_of(state), 1.0_real64, 1.0e-14_real64, 'full interval state published once complete', failures)
    call expect_true(result%diagnostics%committed_substeps == 5, 'five private accepted substeps', failures)
    call expect_true(result%diagnostics%external_commits == 1, 'one external runtime publication', failures)
    call expect_true(result%diagnostics%temporal_acceptance_source == TX_TEMPORAL_MODEL_CERTIFICATE, &
         'canonical diagnostics retain certificate source', failures)
    call expect_true(result%diagnostics%temporal_rejections > 0 .and. result%diagnostics%retries > 0, &
         'canonical diagnostics retain certificate retries', failures)
    call expect_true(result%diagnostics%temporal_certificate_unavailable_rejections == 0, &
         'all canonical certificates available', failures)
    call expect_close(result%diagnostics%max_temporal_indicator, 1.0_real64, 1.0e-14_real64, &
         'accepted certificate indicator bounded', failures)
    call expect_close(result%diagnostics%min_accepted_substep_duration, 0.140625_real64, 1.0e-14_real64, &
         'minimum accepted certified dt', failures)
    call expect_close(result%diagnostics%max_accepted_substep_duration, 0.25_real64, 1.0e-14_real64, &
         'maximum accepted certified dt', failures)
    call expect_true(result%mass%complete, 'canonical certificate mass record complete', failures)
    call expect_true(result%mass%accepted_transaction_count == 5, 'mass ledger contains five accepted transactions', failures)
    call expect_close(result%mass%storage_change, 1.0_real64, 1.0e-14_real64, 'canonical storage change', failures)
    call expect_close(result%mass%total_in, 1.0_real64, 1.0e-14_real64, 'canonical total input', failures)
    call expect_close(result%mass%residual, 0.0_real64, 1.0e-14_real64, 'canonical hard mass closure', failures)
    call expect_close(result%diagnostics%max_abs_step_mass_residual, 0.0_real64, 1.0e-14_real64, &
         'certificate mass diagnostic uses accepted route', failures)
  end subroutine test_full_interval_composition

  subroutine test_substep_limit_does_not_publish_partial_state(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(canonical_certificate_model_t) :: model
    type(canonical_certificate_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result

    call new_state(state, 3.0_real64)
    forcing%rate = 1.0_real64
    interval%t0 = 7.25_real64
    interval%t1 = 8.25_real64
    call configure(config, 2)
    call run_canonical_interval(model, state, forcing, interval, config, result)

    call expect_true(result%status == CANONICAL_STATUS_SUBSTEP_LIMIT .and. .not. result%completed, &
         'bounded substep limit fails closed', failures)
    call expect_true(result%diagnostics%committed_substeps == 2, 'two private substeps before limit', failures)
    call expect_true(result%diagnostics%external_commits == 0, 'partial interval never externally published', failures)
    call expect_close(storage_of(state), 3.0_real64, 0.0_real64, 'partial private working state does not leak', failures)
    call expect_true(.not. result%mass%complete, 'partial interval has no complete external mass record', failures)
  end subroutine test_substep_limit_does_not_publish_partial_state

end program test_fkt09_canonical_certificate_composition
