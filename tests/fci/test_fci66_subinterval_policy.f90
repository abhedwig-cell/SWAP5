module mod_fci66_test_support
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
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

  public :: select_window_02, select_full_cap0, select_full_cap99
  public :: select_overshoot, select_negative_cap, select_no_progress, select_nan

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

  subroutine select_window_02(cursor, requested_t1, target_t1, max_retries_cap, valid)
    real(real64), intent(in) :: cursor, requested_t1
    real(real64), intent(out) :: target_t1
    integer, intent(out) :: max_retries_cap
    logical, intent(out) :: valid
    target_t1 = min(requested_t1, cursor + 0.2_real64)
    max_retries_cap = 3
    valid = requested_t1 > cursor
  end subroutine select_window_02

  subroutine select_full_cap0(cursor, requested_t1, target_t1, max_retries_cap, valid)
    real(real64), intent(in) :: cursor, requested_t1
    real(real64), intent(out) :: target_t1
    integer, intent(out) :: max_retries_cap
    logical, intent(out) :: valid
    target_t1 = requested_t1
    max_retries_cap = 0
    valid = requested_t1 > cursor
  end subroutine select_full_cap0

  subroutine select_full_cap99(cursor, requested_t1, target_t1, max_retries_cap, valid)
    real(real64), intent(in) :: cursor, requested_t1
    real(real64), intent(out) :: target_t1
    integer, intent(out) :: max_retries_cap
    logical, intent(out) :: valid
    target_t1 = requested_t1
    max_retries_cap = 99
    valid = requested_t1 > cursor
  end subroutine select_full_cap99

  subroutine select_overshoot(cursor, requested_t1, target_t1, max_retries_cap, valid)
    real(real64), intent(in) :: cursor, requested_t1
    real(real64), intent(out) :: target_t1
    integer, intent(out) :: max_retries_cap
    logical, intent(out) :: valid
    target_t1 = requested_t1 + 0.1_real64
    max_retries_cap = 3
    valid = requested_t1 > cursor
  end subroutine select_overshoot

  subroutine select_negative_cap(cursor, requested_t1, target_t1, max_retries_cap, valid)
    real(real64), intent(in) :: cursor, requested_t1
    real(real64), intent(out) :: target_t1
    integer, intent(out) :: max_retries_cap
    logical, intent(out) :: valid
    target_t1 = min(requested_t1, cursor + 0.2_real64)
    max_retries_cap = -1
    valid = requested_t1 > cursor
  end subroutine select_negative_cap

  subroutine select_no_progress(cursor, requested_t1, target_t1, max_retries_cap, valid)
    real(real64), intent(in) :: cursor, requested_t1
    real(real64), intent(out) :: target_t1
    integer, intent(out) :: max_retries_cap
    logical, intent(out) :: valid
    target_t1 = cursor
    max_retries_cap = 3
    valid = requested_t1 > cursor
  end subroutine select_no_progress

  subroutine select_nan(cursor, requested_t1, target_t1, max_retries_cap, valid)
    real(real64), intent(in) :: cursor, requested_t1
    real(real64), intent(out) :: target_t1
    integer, intent(out) :: max_retries_cap
    logical, intent(out) :: valid
    target_t1 = ieee_value(cursor, ieee_quiet_nan)
    max_retries_cap = 3
    valid = requested_t1 > cursor
  end subroutine select_nan

end module mod_fci66_test_support

program test_fci66_subinterval_policy
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts
  use mod_canonical_interval_runtime
  use mod_fci66_test_support
  implicit none

  integer :: failures
  failures = 0
  call test_default_unchanged(failures)
  call test_bounded_window_completion(failures)
  call test_bounded_window_atomic_substep_limit(failures)
  call test_retry_cap_tightens(failures)
  call test_retry_cap_cannot_relax(failures)
  call test_invalid_selectors_fail_closed(failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'FCI66_SUBINTERVAL_POLICY_GATE FAIL failures=', failures
    error stop 1
  end if
  write(*,'(A)') 'FCI66_SUBINTERVAL_POLICY_GATE PASS'

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
    call expect_true(abs(actual-expected) <= tol, label, failures)
  end subroutine expect_close

  subroutine standard_setup(interval, config, forcing)
    type(canonical_interval_t), intent(out) :: interval
    type(canonical_numerical_config_t), intent(out) :: config
    type(fci66_forcing_t), intent(out) :: forcing
    interval%t0 = 5.0_real64
    interval%t1 = 5.5_real64
    forcing%k = 1.0_real64
    config%transaction%temporal_tolerance = 0.02_real64
    config%transaction%mass_tolerance = 1.0e-13_real64
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 3
    config%max_committed_substeps = 10
  end subroutine standard_setup

  subroutine test_default_unchanged(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(fci66_model_t) :: model
    type(fci66_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result

    call new_state(state, 1.0_real64)
    call standard_setup(interval, config, forcing)
    call run_canonical_interval(model, state, forcing, interval, config, result)
    call expect_true(result%status == CANONICAL_STATUS_COMPLETED, 'default path completes', failures)
    call expect_true(result%diagnostics%transaction_calls == 2, 'default transaction count unchanged', failures)
    call expect_true(result%diagnostics%retries == 1, 'default retry count unchanged', failures)
    call expect_true(result%diagnostics%external_commits == 1, 'default one external commit', failures)
    call expect_close(water_of(state), 0.586181640625_real64, 1.0e-14_real64, &
         'default endpoint unchanged', failures)
  end subroutine test_default_unchanged

  subroutine test_bounded_window_completion(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(fci66_model_t) :: model
    type(fci66_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result

    call new_state(state, 1.0_real64)
    call standard_setup(interval, config, forcing)
    config%transaction%temporal_tolerance = 1.0_real64
    call run_canonical_interval(model, state, forcing, interval, config, result, select_window_02)
    call expect_true(result%status == CANONICAL_STATUS_COMPLETED, 'bounded path completes outer interval', failures)
    call expect_true(result%diagnostics%transaction_calls == 3, 'bounded path uses three transaction windows', failures)
    call expect_true(result%diagnostics%committed_substeps == 3, 'three private committed substeps', failures)
    call expect_true(result%diagnostics%external_commits == 1, 'bounded path publishes once', failures)
    call expect_close(result%completed_t, interval%t1, 1.0e-14_real64, 'bounded path reaches outer t1', failures)
  end subroutine test_bounded_window_completion

  subroutine test_bounded_window_atomic_substep_limit(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(fci66_model_t) :: model
    type(fci66_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result

    call new_state(state, 1.0_real64)
    call standard_setup(interval, config, forcing)
    config%transaction%temporal_tolerance = 1.0_real64
    config%max_committed_substeps = 2
    call run_canonical_interval(model, state, forcing, interval, config, result, select_window_02)
    call expect_true(result%status == CANONICAL_STATUS_SUBSTEP_LIMIT, 'bounded substep limit reported', failures)
    call expect_true(result%diagnostics%committed_substeps == 2, 'two private bounded substeps ran', failures)
    call expect_true(result%diagnostics%external_commits == 0, 'bounded partial interval not published', failures)
    call expect_close(water_of(state), 1.0_real64, 0.0_real64, 'bounded partial interval keeps external state', failures)
  end subroutine test_bounded_window_atomic_substep_limit

  subroutine test_retry_cap_tightens(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(fci66_model_t) :: model
    type(fci66_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result

    call new_state(state, 1.0_real64)
    call standard_setup(interval, config, forcing)
    call run_canonical_interval(model, state, forcing, interval, config, result, select_full_cap0)
    call expect_true(result%status == CANONICAL_STATUS_TRANSACTION_FAILED, 'cap zero blocks required retry', failures)
    call expect_true(result%diagnostics%retries == 0, 'cap zero permits no retries', failures)
    call expect_true(result%diagnostics%external_commits == 0, 'cap failure not published', failures)
    call expect_close(water_of(state), 1.0_real64, 0.0_real64, 'cap failure keeps external state', failures)
  end subroutine test_retry_cap_tightens

  subroutine test_retry_cap_cannot_relax(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(fci66_model_t) :: model
    type(fci66_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result

    call new_state(state, 1.0_real64)
    call standard_setup(interval, config, forcing)
    config%transaction%max_retries = 0
    call run_canonical_interval(model, state, forcing, interval, config, result, select_full_cap99)
    call expect_true(result%status == CANONICAL_STATUS_TRANSACTION_FAILED, 'selector cannot relax configured cap', failures)
    call expect_true(result%diagnostics%retries == 0, 'configured zero retry remains binding', failures)
    call expect_true(result%diagnostics%external_commits == 0, 'relax attempt not published', failures)
    call expect_close(water_of(state), 1.0_real64, 0.0_real64, 'relax attempt keeps external state', failures)
  end subroutine test_retry_cap_cannot_relax

  subroutine test_invalid_selectors_fail_closed(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(fci66_model_t) :: model
    type(fci66_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result

    call standard_setup(interval, config, forcing)

    call new_state(state, 1.0_real64)
    call run_canonical_interval(model, state, forcing, interval, config, result, select_overshoot)
    call expect_true(result%status == CANONICAL_STATUS_INVALID_REQUEST, 'overshoot selector rejected', failures)
    call expect_true(result%diagnostics%transaction_calls == 0, 'overshoot executes no transaction', failures)
    call expect_close(water_of(state), 1.0_real64, 0.0_real64, 'overshoot keeps external state', failures)

    call new_state(state, 1.0_real64)
    call run_canonical_interval(model, state, forcing, interval, config, result, select_negative_cap)
    call expect_true(result%status == CANONICAL_STATUS_INVALID_REQUEST, 'negative retry cap rejected', failures)
    call expect_true(result%diagnostics%transaction_calls == 0, 'negative cap executes no transaction', failures)
    call expect_close(water_of(state), 1.0_real64, 0.0_real64, 'negative cap keeps external state', failures)

    call new_state(state, 1.0_real64)
    call run_canonical_interval(model, state, forcing, interval, config, result, select_no_progress)
    call expect_true(result%status == CANONICAL_STATUS_INVALID_REQUEST, 'no-progress selector rejected', failures)
    call expect_true(result%diagnostics%transaction_calls == 0, 'no-progress executes no transaction', failures)
    call expect_close(water_of(state), 1.0_real64, 0.0_real64, 'no-progress keeps external state', failures)

    call new_state(state, 1.0_real64)
    call run_canonical_interval(model, state, forcing, interval, config, result, select_nan)
    call expect_true(result%status == CANONICAL_STATUS_INVALID_REQUEST, 'NaN selector rejected', failures)
    call expect_true(result%diagnostics%transaction_calls == 0, 'NaN executes no transaction', failures)
    call expect_close(water_of(state), 1.0_real64, 0.0_real64, 'NaN keeps external state', failures)
  end subroutine test_invalid_selectors_fail_closed

end program test_fci66_subinterval_policy
