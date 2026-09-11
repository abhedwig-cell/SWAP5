module fkt14_test_support
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference, only: transaction_state_t, transaction_model_t, trial_outcome_t, &
       transaction_policy_t, transaction_result_t, transaction_attempt_context_t, execute_reference_interval, &
       TX_STATUS_ACCEPTED, TX_STATUS_RETRY_EXHAUSTED, TX_ROUTE_TWO_HALF, &
       TX_TEMPORAL_EXTERNAL_FULL_HALF, TX_TEMPORAL_MODEL_CERTIFICATE, &
       TX_INTERFACE_SENSITIVITY_LOCAL_TERMINAL, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_forcing_t, canonical_interval_t, canonical_numerical_config_t, &
       canonical_result_t, CANONICAL_STATUS_COMPLETED, CANONICAL_STATUS_TRANSACTION_FAILED
  use mod_canonical_interval_runtime, only: run_canonical_interval
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t, kernel_committed_state_t, &
       kernel_executor_t, kernel_result_t, kernel_candidate_state_t, kernel_diagnostics_t
  implicit none

  type, extends(transaction_state_t) :: test_state_t
    real(real64) :: storage_value = 0.0_real64
  contains
    procedure :: clone => clone_test_state
  end type test_state_t

  type, extends(canonical_forcing_t) :: test_forcing_t
    integer :: marker = 0
  end type test_forcing_t

  type, extends(kernel_parameters_t) :: test_parameters_t
    integer :: marker = 0
  end type test_parameters_t

  type, extends(kernel_model_t) :: test_model_t
    real(real64) :: max_success_dt = huge(0.0_real64)
    real(real64) :: fail_from_t0 = huge(0.0_real64)
    logical :: always_fail = .false.
    logical :: emit_sensitivity = .true.
    integer :: advance_calls = 0
  contains
    procedure :: advance => test_advance
    procedure :: storage => test_storage
    procedure :: temporal_error => test_temporal_error
    procedure :: storage_accounting_status => test_storage_status
    procedure :: capture_attempt_context => test_capture_context
    procedure :: restore_attempt_context => test_restore_context
    procedure :: prepare_interval => test_prepare_interval
    procedure :: configure_parameters => test_configure_parameters
    procedure :: execution_admitted => test_execution_admitted
  end type test_model_t

contains

  subroutine run_fkt14_tests()
    call test_two_half_terminal_only()
    call test_retry_stale_exclusion()
    call test_retry_exhausted_unavailable()
    call test_canonical_single_substep()
    call test_canonical_multi_substep_terminal_only()
    call test_canonical_failure_suppresses_prior_acceptance()
    call test_canonical_mass_identity_with_without_sensitivity()
    call test_kernel_exact_publication()
    print '(a)', 'F-KT14 PASS: accepted-only local-terminal sensitivity transport'
  end subroutine run_fkt14_tests

  subroutine fail(message)
    character(len=*), intent(in) :: message
    write(*,'(a)') 'F-KT14 FAIL: '//trim(message)
    error stop 1
  end subroutine fail

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) call fail(message)
  end subroutine require

  subroutine require_close(actual, expected, message)
    real(real64), intent(in) :: actual, expected
    character(len=*), intent(in) :: message
    if (abs(actual-expected) > 1.0e-12_real64*max(1.0_real64,abs(expected))) call fail(message)
  end subroutine require_close

  subroutine allocate_state(state, value)
    class(transaction_state_t), allocatable, intent(out) :: state
    real(real64), intent(in) :: value
    allocate(test_state_t :: state)
    select type (s => state)
    type is (test_state_t)
      s%storage_value = value
    end select
  end subroutine allocate_state

  subroutine clone_test_state(self, copy)
    class(test_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(test_state_t :: copy)
    select type (typed => copy)
    type is (test_state_t)
      typed%storage_value = self%storage_value
    end select
  end subroutine clone_test_state

  subroutine test_advance(self, state, t0, t1, outcome)
    class(test_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: dt

    outcome = trial_outcome_t()
    self%advance_calls = self%advance_calls + 1
    dt = t1-t0

    if (self%emit_sensitivity) then
      outcome%interface_sensitivity%available = .true.
      outcome%interface_sensitivity%dh_bottom_dq_bottom = 1000.0_real64*t0 + 100.0_real64*t1
      outcome%interface_sensitivity%method = 'test-local'
    end if

    if (self%always_fail .or. t0 >= self%fail_from_t0 .or. dt > self%max_success_dt) then
      if (self%emit_sensitivity) outcome%interface_sensitivity%dh_bottom_dq_bottom = 9999.0_real64
      return
    end if

    select type (s => state)
    type is (test_state_t)
      s%storage_value = s%storage_value + dt
    class default
      call fail('unexpected transaction state type')
    end select

    outcome%solver_ok = .true.
    outcome%mass_in = dt
    outcome%mass_out = 0.0_real64
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    outcome%temporal_certificate_available = .true.
    outcome%temporal_indicator = 0.0_real64
    outcome%nonlinear_iterations = 1
    outcome%jacobian_builds = 1
    outcome%linear_solves = 1
  end subroutine test_advance

  function test_storage(self, state) result(value)
    class(test_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value
    if (self%advance_calls < 0) call fail('unreachable model counter')
    select type (s => state)
    type is (test_state_t)
      value = s%storage_value
    class default
      call fail('unexpected storage state type')
    end select
  end function test_storage

  function test_temporal_error(self, full_state, half_state) result(value)
    class(test_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state
    class(transaction_state_t), intent(in) :: half_state
    real(real64) :: value
    real(real64) :: full_value, half_value
    if (self%advance_calls < 0) call fail('unreachable temporal counter')
    select type (s => full_state)
    type is (test_state_t)
      full_value = s%storage_value
    class default
      call fail('unexpected full state type')
    end select
    select type (s => half_state)
    type is (test_state_t)
      half_value = s%storage_value
    class default
      call fail('unexpected half state type')
    end select
    value = abs(full_value-half_value)
  end function test_temporal_error

  subroutine test_storage_status(self, state, complete, missing_mask)
    class(test_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    if (self%advance_calls < 0 .or. .not. same_type_as(state,state)) call fail('invalid storage status call')
    complete = .true.
    missing_mask = TX_MASS_MISSING_NONE
  end subroutine test_storage_status

  subroutine test_capture_context(self, context)
    class(test_model_t), intent(inout) :: self
    class(transaction_attempt_context_t), allocatable, intent(out) :: context
    if (self%advance_calls < 0) call fail('unreachable capture counter')
    allocate(transaction_attempt_context_t :: context)
  end subroutine test_capture_context

  subroutine test_restore_context(self, context)
    class(test_model_t), intent(inout) :: self
    class(transaction_attempt_context_t), intent(in) :: context
    if (self%advance_calls < 0 .or. .not. same_type_as(context,context)) call fail('invalid restore context call')
  end subroutine test_restore_context

  subroutine test_prepare_interval(self, forcing, interval, config)
    class(test_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    if (.not. same_type_as(forcing,forcing)) call fail('invalid forcing')
    if (interval%t1 <= interval%t0) call fail('invalid prepared interval')
    if (config%max_committed_substeps <= 0) call fail('invalid prepared config')
    self%advance_calls = 0
  end subroutine test_prepare_interval

  subroutine test_configure_parameters(self, parameters)
    class(test_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    if (.not. same_type_as(parameters,parameters)) call fail('invalid parameters')
    if (self%advance_calls < 0) call fail('unreachable configure counter')
  end subroutine test_configure_parameters

  logical function test_execution_admitted(self, parameters, numerical_config)
    class(test_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    test_execution_admitted = same_type_as(parameters,parameters) .and. numerical_config%max_committed_substeps > 0 .and. &
         .not. self%always_fail
  end function test_execution_admitted

  subroutine setup_model_certificate(config, retries)
    type(canonical_numerical_config_t), intent(out) :: config
    integer, intent(in) :: retries
    config = canonical_numerical_config_t()
    config%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    config%transaction%max_retries = retries
    config%transaction%retry_scale = 0.5_real64
    config%transaction%mass_tolerance = 1.0e-12_real64
    config%max_committed_substeps = 8
  end subroutine setup_model_certificate

  subroutine test_two_half_terminal_only()
    type(test_model_t) :: model
    class(transaction_state_t), allocatable :: committed
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result

    call allocate_state(committed, 0.0_real64)
    policy = transaction_policy_t()
    policy%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
    policy%max_retries = 0
    policy%mass_tolerance = 1.0e-12_real64
    policy%temporal_tolerance = 1.0e-12_real64
    call execute_reference_interval(model, committed, 0.0_real64, 1.0_real64, policy, result)

    call require(result%status == TX_STATUS_ACCEPTED, 'two-half interval not accepted')
    call require(result%accepted_route == TX_ROUTE_TWO_HALF, 'two-half route not reported')
    call require(result%interface_sensitivity%available, 'two-half terminal sensitivity unavailable')
    call require(result%interface_sensitivity%semantic == TX_INTERFACE_SENSITIVITY_LOCAL_TERMINAL, &
         'two-half sensitivity semantic is not local terminal')
    call require_close(result%interface_sensitivity%origin_t0, 0.5_real64, 'two-half origin t0 is not half2')
    call require_close(result%interface_sensitivity%origin_t1, 1.0_real64, 'two-half origin t1 mismatch')
    call require_close(result%interface_sensitivity%dh_bottom_dq_bottom, 600.0_real64, &
         'two-half did not publish half2 value')
    call require(.not. result%interface_sensitivity%covers_requested_interval, &
         'half2 local tangent mislabeled as whole requested interval')
    call require_close(result%accepted_mass_residual, 0.0_real64, 'two-half mass residual changed')
  end subroutine test_two_half_terminal_only

  subroutine test_retry_stale_exclusion()
    type(test_model_t) :: model
    class(transaction_state_t), allocatable :: committed
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result

    model%max_success_dt = 0.5_real64
    call allocate_state(committed, 0.0_real64)
    policy = transaction_policy_t()
    policy%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
    policy%max_retries = 1
    policy%retry_scale = 0.5_real64
    policy%mass_tolerance = 1.0e-12_real64
    policy%temporal_tolerance = 1.0e-12_real64
    call execute_reference_interval(model, committed, 0.0_real64, 1.0_real64, policy, result)

    call require(result%status == TX_STATUS_ACCEPTED, 'retry interval not accepted')
    call require(result%retries == 1, 'retry count mismatch')
    call require(result%interface_sensitivity%available, 'retry accepted sensitivity unavailable')
    call require_close(result%interface_sensitivity%origin_t0, 0.25_real64, 'retry terminal origin t0 mismatch')
    call require_close(result%interface_sensitivity%origin_t1, 0.5_real64, 'retry terminal origin t1 mismatch')
    call require_close(result%interface_sensitivity%dh_bottom_dq_bottom, 300.0_real64, &
         'retry leaked rejected sensitivity or wrong terminal value')
    call require(result%interface_sensitivity%dh_bottom_dq_bottom /= 9999.0_real64, &
         'rejected trial sensitivity leaked')
  end subroutine test_retry_stale_exclusion

  subroutine test_retry_exhausted_unavailable()
    type(test_model_t) :: model
    class(transaction_state_t), allocatable :: committed
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result

    model%always_fail = .true.
    call allocate_state(committed, 0.0_real64)
    policy = transaction_policy_t()
    policy%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
    policy%max_retries = 1
    call execute_reference_interval(model, committed, 0.0_real64, 1.0_real64, policy, result)

    call require(result%status == TX_STATUS_RETRY_EXHAUSTED, 'retry exhaustion status mismatch')
    call require(.not. result%interface_sensitivity%available, 'failed transaction published stale sensitivity')
  end subroutine test_retry_exhausted_unavailable

  subroutine test_canonical_single_substep()
    type(test_model_t) :: model
    type(test_forcing_t) :: forcing
    class(transaction_state_t), allocatable :: committed
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result

    call allocate_state(committed, 0.0_real64)
    interval%t0 = 0.0_real64
    interval%t1 = 1.0_real64
    call setup_model_certificate(config, 0)
    call run_canonical_interval(model, committed, forcing, interval, config, result)

    call require(result%status == CANONICAL_STATUS_COMPLETED .and. result%completed, &
         'single-substep canonical interval failed')
    call require(result%mass%accepted_transaction_count == 1, 'single-substep transaction count mismatch')
    call require(result%interface_sensitivity%available, 'single-substep sensitivity unavailable')
    call require(result%interface_sensitivity%covers_requested_interval, &
         'single accepted transaction should cover requested interval')
    call require_close(result%interface_sensitivity%origin_t0, 0.0_real64, 'single origin t0 mismatch')
    call require_close(result%interface_sensitivity%origin_t1, 1.0_real64, 'single origin t1 mismatch')
    call require_close(result%mass%residual, 0.0_real64, 'single canonical mass residual changed')
  end subroutine test_canonical_single_substep

  subroutine test_canonical_multi_substep_terminal_only()
    type(test_model_t) :: model
    type(test_forcing_t) :: forcing
    class(transaction_state_t), allocatable :: committed
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result

    model%max_success_dt = 0.5_real64
    call allocate_state(committed, 0.0_real64)
    interval%t0 = 0.0_real64
    interval%t1 = 1.0_real64
    call setup_model_certificate(config, 1)
    call run_canonical_interval(model, committed, forcing, interval, config, result)

    call require(result%status == CANONICAL_STATUS_COMPLETED .and. result%completed, &
         'multi-substep canonical interval failed')
    call require(result%mass%accepted_transaction_count == 2, 'multi-substep transaction count mismatch')
    call require(result%interface_sensitivity%available, 'multi-substep terminal sensitivity unavailable')
    call require_close(result%interface_sensitivity%origin_t0, 0.5_real64, 'multi-substep terminal origin t0 mismatch')
    call require_close(result%interface_sensitivity%origin_t1, 1.0_real64, 'multi-substep terminal origin t1 mismatch')
    call require_close(result%interface_sensitivity%dh_bottom_dq_bottom, 600.0_real64, &
         'multi-substep did not retain final accepted local tangent')
    call require(.not. result%interface_sensitivity%covers_requested_interval, &
         'multi-substep local tangent mislabeled whole-window')
    call require_close(result%mass%residual, 0.0_real64, 'multi-substep canonical mass residual changed')
  end subroutine test_canonical_multi_substep_terminal_only

  subroutine test_canonical_failure_suppresses_prior_acceptance()
    type(test_model_t) :: model
    type(test_forcing_t) :: forcing
    class(transaction_state_t), allocatable :: committed
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result

    model%max_success_dt = 0.5_real64
    model%fail_from_t0 = 0.5_real64
    call allocate_state(committed, 0.0_real64)
    interval%t0 = 0.0_real64
    interval%t1 = 1.0_real64
    call setup_model_certificate(config, 1)
    call run_canonical_interval(model, committed, forcing, interval, config, result)

    call require(result%status == CANONICAL_STATUS_TRANSACTION_FAILED .and. .not. result%completed, &
         'canonical late failure status mismatch')
    call require(result%mass%accepted_transaction_count == 1, 'expected one private accepted substep before failure')
    call require(.not. result%interface_sensitivity%available, &
         'failed canonical interval exposed sensitivity from prior private accepted substep')
    select type (s => committed)
    type is (test_state_t)
      call require_close(s%storage_value, 0.0_real64, 'failed canonical interval mutated external committed state')
    class default
      call fail('unexpected committed state after canonical failure')
    end select
  end subroutine test_canonical_failure_suppresses_prior_acceptance

  subroutine test_canonical_mass_identity_with_without_sensitivity()
    type(test_model_t) :: model_on, model_off
    type(test_forcing_t) :: forcing
    class(transaction_state_t), allocatable :: state_on, state_off
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result_on, result_off

    model_off%emit_sensitivity = .false.
    call allocate_state(state_on, 0.0_real64)
    call allocate_state(state_off, 0.0_real64)
    interval%t0 = 0.0_real64
    interval%t1 = 1.0_real64
    call setup_model_certificate(config, 0)
    call run_canonical_interval(model_on, state_on, forcing, interval, config, result_on)
    call run_canonical_interval(model_off, state_off, forcing, interval, config, result_off)

    call require(result_on%mass%complete .eqv. result_off%mass%complete, 'mass completeness changed with sensitivity')
    call require(result_on%mass%storage_start == result_off%mass%storage_start, 'mass storage start changed')
    call require(result_on%mass%storage_end == result_off%mass%storage_end, 'mass storage end changed')
    call require(result_on%mass%total_in == result_off%mass%total_in, 'mass inflow changed')
    call require(result_on%mass%total_out == result_off%mass%total_out, 'mass outflow changed')
    call require(result_on%mass%residual == result_off%mass%residual, 'mass residual changed')
    call require(result_on%diagnostics%jacobian_builds == result_off%diagnostics%jacobian_builds, &
         'transport changed Jacobian accounting')
    call require(result_on%diagnostics%linear_solves == result_off%diagnostics%linear_solves, &
         'transport changed linear-solve accounting')
  end subroutine test_canonical_mass_identity_with_without_sensitivity

  subroutine test_kernel_exact_publication()
    type(test_model_t), target :: model
    type(test_forcing_t) :: forcing
    type(test_parameters_t) :: parameters
    class(transaction_state_t), allocatable :: initial
    type(kernel_committed_state_t) :: committed
    type(kernel_executor_t) :: executor
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    type(canonical_numerical_config_t) :: config
    logical :: initialized

    call allocate_state(initial, 0.0_real64)
    call committed%initialize(17_int64, initial, initialized, initial_time=0.0_real64)
    call require(initialized, 'kernel committed state initialization failed')
    call executor%bind_model(model)
    call setup_model_certificate(config, 0)
    call executor%advance_interval(parameters, committed, forcing, config, 0.0_real64, 1.0_real64, &
         result, candidate, diagnostics)

    call require(result%completed, 'kernel interval did not complete')
    call require(result%interface_sensitivity%available, 'kernel sensitivity unavailable')
    call require(result%interface_sensitivity%semantic == TX_INTERFACE_SENSITIVITY_LOCAL_TERMINAL, &
         'kernel sensitivity semantic changed')
    call require_close(result%interface_sensitivity%dh_bottom_dq_bottom, 100.0_real64, &
         'kernel changed native sensitivity value/sign')
    call require_close(result%interface_sensitivity%origin_t0, 0.0_real64, 'kernel origin t0 changed')
    call require_close(result%interface_sensitivity%origin_t1, 1.0_real64, 'kernel origin t1 changed')
    call require(result%interface_sensitivity%covers_requested_interval, 'kernel full-interval provenance lost')
    call require_close(result%mass%residual, 0.0_real64, 'kernel mass residual changed')
    call require(diagnostics%committed_state_mutations == 0, 'kernel trial mutated committed state')
  end subroutine test_kernel_exact_publication

end module fkt14_test_support

program test_fkt14_interface_sensitivity_transport
  use fkt14_test_support, only: run_fkt14_tests
  implicit none
  call run_fkt14_tests()
end program test_fkt14_interface_sensitivity_transport
