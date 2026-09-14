module mod_fci66_test_model
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t
  use mod_canonical_contracts
  implicit none
  private

  type, extends(canonical_state_t), public :: fci66_state_t
    real(real64) :: water = 0.0_real64
  contains
    procedure :: clone => fci66_clone
  end type fci66_state_t

  type, extends(canonical_forcing_t), public :: fci66_forcing_t
    real(real64) :: k = 1.0_real64
  end type fci66_forcing_t

  type, extends(canonical_physical_model_t), public :: fci66_model_t
    real(real64) :: k = 1.0_real64
    integer :: prepare_calls = 0
  contains
    procedure :: advance => fci66_advance
    procedure :: storage => fci66_storage
    procedure :: temporal_error => fci66_temporal_error
    procedure :: prepare_interval => fci66_prepare_interval
  end type fci66_model_t

contains

  subroutine fci66_clone(self, copy)
    class(fci66_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fci66_state_t :: copy)
    select type(copy)
    type is(fci66_state_t)
      copy%water = self%water
    end select
  end subroutine fci66_clone

  subroutine fci66_prepare_interval(self, forcing, interval, config)
    class(fci66_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config

    self%prepare_calls = self%prepare_calls + 1
    select type(forcing)
    type is(fci66_forcing_t)
      self%k = forcing%k
    class default
      error stop 'FCI66 unexpected forcing type'
    end select
    if (interval%t1 <= interval%t0) error stop 'FCI66 prepare got invalid interval'
    if (config%max_committed_substeps <= 0) error stop 'FCI66 prepare got invalid config'
  end subroutine fci66_prepare_interval

  subroutine fci66_advance(self, state, t0, t1, outcome)
    class(fci66_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: dt, start_water, end_water

    outcome = trial_outcome_t()
    dt = t1 - t0
    select type(state)
    type is(fci66_state_t)
      start_water = state%water
      end_water = start_water * (1.0_real64 - self%k * dt)
      state%water = end_water
      outcome%mass_out = start_water - end_water
      outcome%solver_ok = .true.
      outcome%nonlinear_iterations = 1
    class default
      error stop 'FCI66 unexpected state type'
    end select
  end subroutine fci66_advance

  function fci66_storage(self, state) result(value)
    class(fci66_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value

    if (self%k < -huge(0.0_real64)) error stop 'unreachable'
    select type(state)
    type is(fci66_state_t)
      value = state%water
    class default
      error stop 'FCI66 unexpected state type'
    end select
  end function fci66_storage

  function fci66_temporal_error(self, full_state, half_state) result(value)
    class(fci66_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    real(real64) :: value, full_water, half_water

    if (self%k < -huge(0.0_real64)) error stop 'unreachable'
    select type(full_state)
    type is(fci66_state_t)
      full_water = full_state%water
    class default
      error stop 'FCI66 unexpected full state type'
    end select
    select type(half_state)
    type is(fci66_state_t)
      half_water = half_state%water
    class default
      error stop 'FCI66 unexpected half state type'
    end select
    value = abs(half_water - full_water)
  end function fci66_temporal_error

end module mod_fci66_test_model

program test_fci66_window_target_selector
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts
  use mod_canonical_interval_runtime
  use mod_fci66_test_model
  implicit none

  integer :: failures

  failures = 0
  call test_bounded_selector_completes_atomically(failures)
  call test_stalled_selector_fails_before_transaction(failures)
  call test_overshoot_selector_fails_before_transaction(failures)
  call test_nonfinite_selector_fails_before_transaction(failures)
  call test_negative_retry_cap_fails_before_transaction(failures)
  call test_retry_cap_tightens_transaction_budget(failures)
  call test_retry_cap_cannot_relax_caller_budget(failures)
  call test_selector_substep_limit_keeps_external_state(failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'FCI66_WINDOW_TARGET_SELECTOR_GATE FAIL failures=', failures
    error stop 1
  end if
  write(*,'(A)') 'FCI66_WINDOW_TARGET_SELECTOR_GATE PASS'

contains

  subroutine new_state(state, water)
    class(transaction_state_t), allocatable, intent(out) :: state
    real(real64), intent(in) :: water

    allocate(fci66_state_t :: state)
    select type(state)
    type is(fci66_state_t)
      state%water = water
    end select
  end subroutine new_state

  function water_of(state) result(value)
    class(transaction_state_t), allocatable, intent(in) :: state
    real(real64) :: value

    select type(state)
    type is(fci66_state_t)
      value = state%water
    class default
      error stop 'FCI66 unexpected state in water_of'
    end select
  end function water_of

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

    call expect_true(abs(actual - expected) <= tol, label, failures)
  end subroutine expect_close

  subroutine standard_setup(interval, config, forcing)
    type(canonical_interval_t), intent(out) :: interval
    type(canonical_numerical_config_t), intent(out) :: config
    type(fci66_forcing_t), intent(out) :: forcing

    interval%t0 = 2.0_real64
    interval%t1 = 2.5_real64
    forcing%k = 0.5_real64
    config%transaction%temporal_tolerance = 1.0_real64
    config%transaction%mass_tolerance = 1.0e-13_real64
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 3
    config%max_committed_substeps = 16
  end subroutine standard_setup

  subroutine test_bounded_selector_completes_atomically(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(fci66_model_t) :: model
    type(fci66_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result

    call new_state(state, 1.0_real64)
    call standard_setup(interval, config, forcing)
    call run_canonical_interval(model, state, forcing, interval, config, result, bounded_selector)

    call expect_true(result%status == CANONICAL_STATUS_COMPLETED, 'bounded selector completes', failures)
    call expect_true(result%completed, 'bounded selector completed flag', failures)
    call expect_true(result%diagnostics%transaction_calls == 4, 'four bounded transaction windows', failures)
    call expect_true(result%diagnostics%committed_substeps == 4, 'four private commits', failures)
    call expect_true(result%diagnostics%external_commits == 1, 'single external commit', failures)
    call expect_close(result%completed_t, interval%t1, 1.0e-14_real64, 'global t1 reached', failures)
    call expect_true(water_of(state) < 1.0_real64, 'completed state published', failures)
    call expect_true(model%prepare_calls == 1, 'model prepared once', failures)
  end subroutine test_bounded_selector_completes_atomically

  subroutine test_stalled_selector_fails_before_transaction(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(fci66_model_t) :: model
    type(fci66_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result

    call new_state(state, 1.0_real64)
    call standard_setup(interval, config, forcing)
    call run_canonical_interval(model, state, forcing, interval, config, result, stalled_selector)

    call expect_true(result%status == CANONICAL_STATUS_INVALID_REQUEST, 'stalled selector rejected', failures)
    call expect_true(result%diagnostics%transaction_calls == 0, 'stalled selector executes no transaction', failures)
    call expect_true(result%diagnostics%external_commits == 0, 'stalled selector has no external commit', failures)
    call expect_close(water_of(state), 1.0_real64, 0.0_real64, 'stalled selector keeps state', failures)
  end subroutine test_stalled_selector_fails_before_transaction

  subroutine test_overshoot_selector_fails_before_transaction(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(fci66_model_t) :: model
    type(fci66_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result

    call new_state(state, 1.0_real64)
    call standard_setup(interval, config, forcing)
    call run_canonical_interval(model, state, forcing, interval, config, result, overshoot_selector)

    call expect_true(result%status == CANONICAL_STATUS_INVALID_REQUEST, 'overshoot selector rejected', failures)
    call expect_true(result%diagnostics%transaction_calls == 0, 'overshoot executes no transaction', failures)
    call expect_true(result%diagnostics%external_commits == 0, 'overshoot has no external commit', failures)
    call expect_close(water_of(state), 1.0_real64, 0.0_real64, 'overshoot keeps state', failures)
  end subroutine test_overshoot_selector_fails_before_transaction

  subroutine test_nonfinite_selector_fails_before_transaction(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(fci66_model_t) :: model
    type(fci66_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result

    call new_state(state, 1.0_real64)
    call standard_setup(interval, config, forcing)
    call run_canonical_interval(model, state, forcing, interval, config, result, nonfinite_selector)

    call expect_true(result%status == CANONICAL_STATUS_INVALID_REQUEST, 'nonfinite selector rejected', failures)
    call expect_true(result%diagnostics%transaction_calls == 0, 'nonfinite executes no transaction', failures)
    call expect_true(result%diagnostics%external_commits == 0, 'nonfinite has no external commit', failures)
    call expect_close(water_of(state), 1.0_real64, 0.0_real64, 'nonfinite keeps state', failures)
  end subroutine test_nonfinite_selector_fails_before_transaction

  subroutine test_negative_retry_cap_fails_before_transaction(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(fci66_model_t) :: model
    type(fci66_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result

    call new_state(state, 1.0_real64)
    call standard_setup(interval, config, forcing)
    call run_canonical_interval(model, state, forcing, interval, config, result, negative_retry_cap_selector)

    call expect_true(result%status == CANONICAL_STATUS_INVALID_REQUEST, 'negative retry cap rejected', failures)
    call expect_true(result%diagnostics%transaction_calls == 0, 'negative cap executes no transaction', failures)
    call expect_true(result%diagnostics%external_commits == 0, 'negative cap has no external commit', failures)
    call expect_close(water_of(state), 1.0_real64, 0.0_real64, 'negative cap keeps state', failures)
  end subroutine test_negative_retry_cap_fails_before_transaction

  subroutine test_retry_cap_tightens_transaction_budget(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(fci66_model_t) :: model
    type(fci66_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result

    call new_state(state, 1.0_real64)
    call standard_setup(interval, config, forcing)
    config%transaction%temporal_tolerance = 1.0e-12_real64
    config%transaction%max_retries = 3
    call run_canonical_interval(model, state, forcing, interval, config, result, zero_retry_cap_selector)

    call expect_true(result%status == CANONICAL_STATUS_TRANSACTION_FAILED, 'tight retry cap terminates transaction', failures)
    call expect_true(result%diagnostics%transaction_calls == 1, 'tight cap makes one transaction call', failures)
    call expect_true(result%diagnostics%attempts == 1, 'zero retry cap allows one attempt only', failures)
    call expect_true(result%diagnostics%external_commits == 0, 'tight cap has no external commit', failures)
    call expect_close(water_of(state), 1.0_real64, 0.0_real64, 'tight cap keeps external state', failures)
  end subroutine test_retry_cap_tightens_transaction_budget

  subroutine test_retry_cap_cannot_relax_caller_budget(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(fci66_model_t) :: model
    type(fci66_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result

    call new_state(state, 1.0_real64)
    call standard_setup(interval, config, forcing)
    config%transaction%temporal_tolerance = 1.0e-12_real64
    config%transaction%max_retries = 0
    call run_canonical_interval(model, state, forcing, interval, config, result, relax_retry_cap_selector)

    call expect_true(result%status == CANONICAL_STATUS_TRANSACTION_FAILED, 'selector cannot relax retry budget', failures)
    call expect_true(result%diagnostics%transaction_calls == 1, 'relax request makes one transaction call', failures)
    call expect_true(result%diagnostics%attempts == 1, 'caller zero-retry budget remains authoritative', failures)
    call expect_true(result%diagnostics%external_commits == 0, 'relax request has no external commit', failures)
    call expect_close(water_of(state), 1.0_real64, 0.0_real64, 'relax request keeps external state', failures)
  end subroutine test_retry_cap_cannot_relax_caller_budget

  subroutine test_selector_substep_limit_keeps_external_state(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(fci66_model_t) :: model
    type(fci66_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result

    call new_state(state, 1.0_real64)
    call standard_setup(interval, config, forcing)
    config%max_committed_substeps = 2
    call run_canonical_interval(model, state, forcing, interval, config, result, bounded_selector)

    call expect_true(result%status == CANONICAL_STATUS_SUBSTEP_LIMIT, 'selector substep limit reported', failures)
    call expect_true(result%diagnostics%transaction_calls == 2, 'two bounded transactions before limit', failures)
    call expect_true(result%diagnostics%committed_substeps == 2, 'two private commits before limit', failures)
    call expect_true(result%diagnostics%external_commits == 0, 'substep limit has no external commit', failures)
    call expect_close(water_of(state), 1.0_real64, 0.0_real64, 'substep limit keeps external state', failures)
  end subroutine test_selector_substep_limit_keeps_external_state

  subroutine bounded_selector(cursor, requested_t1, target_t1, max_retries_cap, valid)
    real(real64), intent(in) :: cursor, requested_t1
    real(real64), intent(out) :: target_t1
    integer, intent(out) :: max_retries_cap
    logical, intent(out) :: valid

    target_t1 = min(requested_t1, cursor + 0.125_real64)
    max_retries_cap = 3
    valid = requested_t1 > cursor
  end subroutine bounded_selector

  subroutine stalled_selector(cursor, requested_t1, target_t1, max_retries_cap, valid)
    real(real64), intent(in) :: cursor, requested_t1
    real(real64), intent(out) :: target_t1
    integer, intent(out) :: max_retries_cap
    logical, intent(out) :: valid

    target_t1 = cursor
    max_retries_cap = 3
    valid = requested_t1 > cursor
  end subroutine stalled_selector

  subroutine overshoot_selector(cursor, requested_t1, target_t1, max_retries_cap, valid)
    real(real64), intent(in) :: cursor, requested_t1
    real(real64), intent(out) :: target_t1
    integer, intent(out) :: max_retries_cap
    logical, intent(out) :: valid

    target_t1 = requested_t1 + max(1.0_real64, requested_t1 - cursor)
    max_retries_cap = 3
    valid = requested_t1 > cursor
  end subroutine overshoot_selector

  subroutine nonfinite_selector(cursor, requested_t1, target_t1, max_retries_cap, valid)
    real(real64), intent(in) :: cursor, requested_t1
    real(real64), intent(out) :: target_t1
    integer, intent(out) :: max_retries_cap
    logical, intent(out) :: valid

    target_t1 = ieee_value(0.0_real64, ieee_quiet_nan)
    max_retries_cap = 3
    valid = requested_t1 > cursor
  end subroutine nonfinite_selector

  subroutine negative_retry_cap_selector(cursor, requested_t1, target_t1, max_retries_cap, valid)
    real(real64), intent(in) :: cursor, requested_t1
    real(real64), intent(out) :: target_t1
    integer, intent(out) :: max_retries_cap
    logical, intent(out) :: valid

    target_t1 = min(requested_t1, cursor + 0.125_real64)
    max_retries_cap = -1
    valid = requested_t1 > cursor
  end subroutine negative_retry_cap_selector

  subroutine zero_retry_cap_selector(cursor, requested_t1, target_t1, max_retries_cap, valid)
    real(real64), intent(in) :: cursor, requested_t1
    real(real64), intent(out) :: target_t1
    integer, intent(out) :: max_retries_cap
    logical, intent(out) :: valid

    target_t1 = requested_t1
    max_retries_cap = 0
    valid = requested_t1 > cursor
  end subroutine zero_retry_cap_selector

  subroutine relax_retry_cap_selector(cursor, requested_t1, target_t1, max_retries_cap, valid)
    real(real64), intent(in) :: cursor, requested_t1
    real(real64), intent(out) :: target_t1
    integer, intent(out) :: max_retries_cap
    logical, intent(out) :: valid

    target_t1 = requested_t1
    max_retries_cap = 99
    valid = requested_t1 > cursor
  end subroutine relax_retry_cap_selector

end program test_fci66_window_target_selector
