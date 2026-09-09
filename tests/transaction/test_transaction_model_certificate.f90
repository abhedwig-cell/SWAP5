module mod_fkt09_certificate_test_model
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference
  implicit none
  private

  type, extends(transaction_state_t), public :: certificate_state_t
    real(real64) :: storage = 0.0_real64
  contains
    procedure :: clone => certificate_clone
  end type certificate_state_t

  type, extends(transaction_attempt_context_t) :: certificate_context_t
    integer :: counter = 0
  end type certificate_context_t

  type, extends(transaction_model_t), public :: certificate_model_t
    integer :: counter = 0
    integer :: advance_calls = 0
    logical :: provide_certificate = .true.
    logical :: inject_mass_defect = .false.
    real(real64) :: certified_dt = 0.5_real64
  contains
    procedure :: advance => certificate_advance
    procedure :: storage => certificate_storage
    procedure :: temporal_error => certificate_unused_external_error
    procedure :: storage_accounting_status => certificate_storage_status
    procedure :: capture_attempt_context => certificate_capture
    procedure :: restore_attempt_context => certificate_restore
  end type certificate_model_t

contains

  subroutine certificate_clone(self, copy)
    class(certificate_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(certificate_state_t :: copy)
    select type (copy)
    type is (certificate_state_t)
      copy%storage = self%storage
    class default
      error stop 'F-KT09 clone type mismatch'
    end select
  end subroutine certificate_clone

  subroutine certificate_capture(self, context)
    class(certificate_model_t), intent(inout) :: self
    class(transaction_attempt_context_t), allocatable, intent(out) :: context
    allocate(certificate_context_t :: context)
    select type (context)
    type is (certificate_context_t)
      context%counter = self%counter
    class default
      error stop 'F-KT09 context allocation mismatch'
    end select
  end subroutine certificate_capture

  subroutine certificate_restore(self, context)
    class(certificate_model_t), intent(inout) :: self
    class(transaction_attempt_context_t), intent(in) :: context
    select type (context)
    type is (certificate_context_t)
      self%counter = context%counter
    class default
      error stop 'F-KT09 context type mismatch'
    end select
  end subroutine certificate_restore

  subroutine certificate_advance(self, state, t0, t1, outcome)
    class(certificate_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: dt

    outcome = trial_outcome_t()
    dt = t1 - t0
    self%advance_calls = self%advance_calls + 1
    self%counter = self%counter + 1
    select type (state)
    type is (certificate_state_t)
      state%storage = state%storage + dt
    class default
      error stop 'F-KT09 advance state mismatch'
    end select

    outcome%solver_ok = .true.
    outcome%mass_in = dt
    if (self%inject_mass_defect) outcome%mass_in = outcome%mass_in + 1.0e-4_real64
    outcome%mass_out = 0.0_real64
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    outcome%temporal_certificate_available = self%provide_certificate
    if (self%provide_certificate) then
      outcome%temporal_indicator = dt / self%certified_dt
    end if
    outcome%nonlinear_iterations = 2
    outcome%internal_retries = 1
    outcome%linear_solves = 2
  end subroutine certificate_advance

  function certificate_storage(self, state) result(value)
    class(certificate_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value
    if (self%certified_dt < 0.0_real64) error stop 'F-KT09 invalid synthetic model'
    select type (state)
    type is (certificate_state_t)
      value = state%storage
    class default
      error stop 'F-KT09 storage state mismatch'
    end select
  end function certificate_storage

  subroutine certificate_storage_status(self, state, complete, missing_mask)
    class(certificate_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    if (self%certified_dt < 0.0_real64) error stop 'F-KT09 invalid status model'
    select type (state)
    type is (certificate_state_t)
      complete = .true.
      missing_mask = TX_MASS_MISSING_NONE
    class default
      complete = .false.
      missing_mask = TX_MASS_MISSING_UNSPECIFIED
    end select
  end subroutine certificate_storage_status

  function certificate_unused_external_error(self, full_state, half_state) result(value)
    class(certificate_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    real(real64) :: value
    if (self%counter < -huge(0)) error stop 'F-KT09 unreachable model state'
    if (.not. same_type_as(full_state, half_state)) error stop 'F-KT09 external error type mismatch'
    value = 0.0_real64
  end function certificate_unused_external_error

end module mod_fkt09_certificate_test_model

program test_transaction_model_certificate
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference
  use mod_fkt09_certificate_test_model
  implicit none

  integer :: failures
  failures = 0

  call test_default_mode_is_legacy(failures)
  call test_retry_to_certified_step(failures)
  call test_unavailable_certificate_fails_closed(failures)
  call test_mass_gate_remains_independent(failures)
  call test_invalid_temporal_mode_rejected(failures)

  if (failures /= 0) then
    print '(A,I0)', 'FKT09_MODEL_CERTIFICATE_GATE FAIL failures=', failures
    error stop 1
  end if
  print '(A)', 'FKT09_MODEL_CERTIFICATE_GATE PASS'

contains

  subroutine new_state(state, value)
    class(transaction_state_t), allocatable, intent(out) :: state
    real(real64), intent(in) :: value
    allocate(certificate_state_t :: state)
    select type (state)
    type is (certificate_state_t)
      state%storage = value
    end select
  end subroutine new_state

  function storage_of(state) result(value)
    class(transaction_state_t), allocatable, intent(in) :: state
    real(real64) :: value
    select type (state)
    type is (certificate_state_t)
      value = state%storage
    class default
      error stop 'F-KT09 output state mismatch'
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

  subroutine test_default_mode_is_legacy(failures)
    integer, intent(inout) :: failures
    type(transaction_policy_t) :: policy
    call expect_true(policy%temporal_mode == TX_TEMPORAL_EXTERNAL_FULL_HALF, &
         'default temporal mode remains external full-half', failures)
  end subroutine test_default_mode_is_legacy

  subroutine test_retry_to_certified_step(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(certificate_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result

    call new_state(state, 10.0_real64)
    policy%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    policy%mass_tolerance = 1.0e-12_real64
    policy%retry_scale = 0.5_real64
    policy%max_retries = 2
    call execute_reference_interval(model, state, 20.25_real64, 21.25_real64, policy, result)

    call expect_true(result%status == TX_STATUS_ACCEPTED, 'certified retry accepted', failures)
    call expect_true(result%accepted_route == TX_ROUTE_MODEL_CERTIFIED, 'certified route reported', failures)
    call expect_true(result%temporal_acceptance_source == TX_TEMPORAL_MODEL_CERTIFICATE, &
         'certificate source reported', failures)
    call expect_true(result%attempts == 2 .and. result%full_trials == 2 .and. result%half_trials == 0, &
         'one candidate branch per certificate attempt', failures)
    call expect_true(result%temporal_rejections == 1 .and. result%retries == 1 .and. result%rollbacks == 1, &
         'certificate rejection retry accounting', failures)
    call expect_true(result%temporal_certificate_unavailable_rejections == 0, &
         'available certificate not classified unavailable', failures)
    call expect_close(result%accepted_dt, 0.5_real64, 0.0_real64, 'shorter certified dt', failures)
    call expect_close(result%temporal_indicator, 1.0_real64, 0.0_real64, 'accepted indicator', failures)
    call expect_close(storage_of(state), 10.5_real64, 0.0_real64, 'rejected attempt state did not leak', failures)
    call expect_true(model%counter == 1, 'accepted worker context committed only once', failures)
    call expect_true(model%advance_calls == 2, 'two physical attempts executed', failures)
    call expect_true(result%accepted_nonlinear_iterations == 2 .and. result%accepted_internal_retries == 1, &
         'accepted solver diagnostics preserved', failures)
    call expect_true(result%accepted_mass_complete, 'accepted certificate mass accounting complete', failures)
    call expect_close(result%accepted_mass_residual, 0.0_real64, 1.0e-15_real64, &
         'certificate route hard mass residual', failures)
  end subroutine test_retry_to_certified_step

  subroutine test_unavailable_certificate_fails_closed(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(certificate_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result

    call new_state(state, 4.0_real64)
    model%provide_certificate = .false.
    policy%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    policy%mass_tolerance = 1.0e-12_real64
    policy%retry_scale = 0.5_real64
    policy%max_retries = 2
    call execute_reference_interval(model, state, 3.0_real64, 4.0_real64, policy, result)

    call expect_true(result%status == TX_STATUS_RETRY_EXHAUSTED, 'missing certificate fails closed', failures)
    call expect_true(result%attempts == 3 .and. result%temporal_rejections == 3, &
         'missing certificate rejected each attempt', failures)
    call expect_true(result%temporal_certificate_unavailable_rejections == 3, &
         'missing certificate diagnostics counted', failures)
    call expect_true(result%commits == 0, 'missing certificate never commits', failures)
    call expect_close(storage_of(state), 4.0_real64, 0.0_real64, 'missing certificate keeps committed state', failures)
    call expect_true(model%counter == 0, 'missing certificate restores worker context', failures)
  end subroutine test_unavailable_certificate_fails_closed

  subroutine test_mass_gate_remains_independent(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(certificate_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result

    call new_state(state, 2.0_real64)
    model%inject_mass_defect = .true.
    model%certified_dt = 10.0_real64
    policy%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    policy%mass_tolerance = 1.0e-12_real64
    policy%retry_scale = 0.5_real64
    policy%max_retries = 1
    call execute_reference_interval(model, state, 8.0_real64, 8.25_real64, policy, result)

    call expect_true(result%status == TX_STATUS_RETRY_EXHAUSTED, 'mass defect fails certificate route', failures)
    call expect_true(result%mass_rejections == 2, 'mass gate rejects every attempt', failures)
    call expect_true(result%temporal_rejections == 0, 'mass gate evaluated independently before certificate', failures)
    call expect_true(result%commits == 0, 'mass defect never commits certified route', failures)
    call expect_close(storage_of(state), 2.0_real64, 0.0_real64, 'mass failure keeps committed state', failures)
    call expect_true(model%counter == 0, 'mass failure restores worker context', failures)
  end subroutine test_mass_gate_remains_independent

  subroutine test_invalid_temporal_mode_rejected(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(certificate_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result

    call new_state(state, 1.0_real64)
    policy%temporal_mode = 999
    call execute_reference_interval(model, state, 0.0_real64, 1.0_real64, policy, result)
    call expect_true(result%status == TX_STATUS_INVALID_INTERVAL, 'unknown temporal mode invalid', failures)
    call expect_close(storage_of(state), 1.0_real64, 0.0_real64, 'invalid policy leaves state unchanged', failures)
  end subroutine test_invalid_temporal_mode_rejected

end program test_transaction_model_certificate
