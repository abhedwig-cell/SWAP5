module mod_fsi32_test_model
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference
  implicit none
  private

  type, extends(transaction_state_t), public :: fsi32_state_t
    real(real64) :: water = 1.0_real64
  contains
    procedure :: clone => fsi32_clone
  end type fsi32_state_t

  type, extends(transaction_model_t), public :: fsi32_model_t
    integer :: advance_calls = 0
    integer :: fail_on_call = 0
  contains
    procedure :: advance => fsi32_advance
    procedure :: storage => fsi32_storage
    procedure :: temporal_error => fsi32_temporal_error
  end type fsi32_model_t

contains

  subroutine fsi32_clone(self, copy)
    class(fsi32_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fsi32_state_t :: copy)
    select type(copy)
    type is(fsi32_state_t)
      copy%water = self%water
    end select
  end subroutine fsi32_clone

  subroutine fsi32_advance(self, state, t0, t1, outcome)
    class(fsi32_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome

    self%advance_calls = self%advance_calls + 1
    outcome = trial_outcome_t()
    outcome%solver_ok = .true.
    outcome%temporal_certificate_available = .true.
    outcome%temporal_indicator = 0.0_real64
    outcome%interface_sensitivity%available = .true.
    outcome%interface_sensitivity%dh_bottom_dq_bottom = 100.0_real64 + t0
    outcome%interface_sensitivity%method = 'fsi32-probe'

    if (self%advance_calls == self%fail_on_call) then
      outcome%solver_ok = .false.
      return
    end if

    select type(state)
    type is(fsi32_state_t)
      ! Intentionally unchanged state: exact zero mass residual.
      state%water = state%water
    class default
      error stop 'FSI32 unexpected state type'
    end select
    if (t1 <= t0) error stop 'FSI32 invalid model interval'
  end subroutine fsi32_advance

  function fsi32_storage(self, state) result(value)
    class(fsi32_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value
    if (self%advance_calls < -1) error stop 'FSI32 unreachable'
    select type(state)
    type is(fsi32_state_t)
      value = state%water
    class default
      error stop 'FSI32 unexpected storage type'
    end select
  end function fsi32_storage

  function fsi32_temporal_error(self, full_state, half_state) result(value)
    class(fsi32_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state
    class(transaction_state_t), intent(in) :: half_state
    real(real64) :: value
    if (self%advance_calls < -1 .or. .not. same_type_as(full_state, half_state)) error stop 'FSI32 unreachable'
    value = 0.0_real64
  end function fsi32_temporal_error

end module mod_fsi32_test_model

program test_fsi32_scoped_interface_sensitivity
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference
  use mod_fsi32_test_model
  implicit none

  integer :: failures
  failures = 0
  call test_two_half_is_terminal_only(failures)
  call test_full_origin_coverage_does_not_upgrade_semantic(failures)
  call test_retry_coverage_is_provenance_only(failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'FSI32_SCOPED_SENSITIVITY_GATE FAIL failures=', failures
    error stop 1
  end if
  write(*,'(A)') 'FSI32_SCOPED_SENSITIVITY_GATE PASS'

contains

  subroutine make_state(state)
    class(transaction_state_t), allocatable, intent(out) :: state
    allocate(fsi32_state_t :: state)
  end subroutine make_state

  subroutine expect_true(condition, label, failures)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    if (.not. condition) then
      failures = failures + 1
      write(*,'(A,A)') 'FAIL ', trim(label)
    end if
  end subroutine expect_true

  subroutine expect_close(actual, expected, tol, label, failures)
    real(real64), intent(in) :: actual, expected, tol
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    call expect_true(abs(actual-expected) <= tol, label, failures)
  end subroutine expect_close

  subroutine test_two_half_is_terminal_only(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(fsi32_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result

    call make_state(state)
    policy%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
    policy%temporal_tolerance = 1.0_real64
    policy%mass_tolerance = 0.0_real64
    call execute_reference_interval(model, state, 0.0_real64, 1.0_real64, policy, result)

    call expect_true(result%status == TX_STATUS_ACCEPTED, 'two-half accepted', failures)
    call expect_true(result%accepted_route == TX_ROUTE_TWO_HALF, 'two-half route', failures)
    call expect_true(result%interface_sensitivity%available, 'two-half sensitivity available', failures)
    call expect_true(result%interface_sensitivity%semantic == TX_INTERFACE_SENSITIVITY_LOCAL_TERMINAL, &
         'two-half remains local-terminal', failures)
    call expect_close(result%interface_sensitivity%origin_t0, 0.5_real64, 0.0_real64, &
         'two-half origin starts at terminal half', failures)
    call expect_close(result%interface_sensitivity%origin_t1, 1.0_real64, 0.0_real64, &
         'two-half origin ends at accepted endpoint', failures)
    call expect_true(.not. result%interface_sensitivity%covers_requested_interval, &
         'two-half does not cover requested interval', failures)
    call expect_close(result%interface_sensitivity%dh_bottom_dq_bottom, 100.5_real64, 0.0_real64, &
         'two-half publishes terminal half value only', failures)
  end subroutine test_two_half_is_terminal_only

  subroutine test_full_origin_coverage_does_not_upgrade_semantic(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(fsi32_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result

    call make_state(state)
    policy%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    policy%mass_tolerance = 0.0_real64
    call execute_reference_interval(model, state, 2.0_real64, 3.0_real64, policy, result)

    call expect_true(result%status == TX_STATUS_ACCEPTED, 'model-certified accepted', failures)
    call expect_true(result%accepted_route == TX_ROUTE_MODEL_CERTIFIED, 'model-certified route', failures)
    call expect_true(result%interface_sensitivity%available, 'model-certified sensitivity available', failures)
    call expect_true(result%interface_sensitivity%semantic == TX_INTERFACE_SENSITIVITY_LOCAL_TERMINAL, &
         'coverage true never upgrades local-terminal semantic', failures)
    call expect_true(result%interface_sensitivity%covers_requested_interval, &
         'single accepted solve has full origin coverage', failures)
    call expect_close(result%interface_sensitivity%origin_t0, 2.0_real64, 0.0_real64, &
         'full origin t0', failures)
    call expect_close(result%interface_sensitivity%origin_t1, 3.0_real64, 0.0_real64, &
         'full origin t1', failures)
  end subroutine test_full_origin_coverage_does_not_upgrade_semantic

  subroutine test_retry_coverage_is_provenance_only(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(fsi32_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result

    call make_state(state)
    model%fail_on_call = 1
    policy%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    policy%mass_tolerance = 0.0_real64
    policy%retry_scale = 0.5_real64
    policy%max_retries = 2
    call execute_reference_interval(model, state, 4.0_real64, 5.0_real64, policy, result)

    call expect_true(result%status == TX_STATUS_ACCEPTED, 'retry accepted', failures)
    call expect_true(result%retries == 1, 'retry occurred', failures)
    call expect_true(result%interface_sensitivity%semantic == TX_INTERFACE_SENSITIVITY_LOCAL_TERMINAL, &
         'retry remains local-terminal', failures)
    call expect_close(result%interface_sensitivity%origin_t0, 4.0_real64, 0.0_real64, 'retry origin t0', failures)
    call expect_close(result%interface_sensitivity%origin_t1, 4.5_real64, 0.0_real64, 'retry origin t1', failures)
    call expect_true(.not. result%interface_sensitivity%covers_requested_interval, &
         'retry shortened interval has coverage false', failures)
  end subroutine test_retry_coverage_is_provenance_only

end program test_fsi32_scoped_interface_sensitivity
