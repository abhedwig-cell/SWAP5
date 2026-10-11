module mod_fci04_test_model
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t
  use mod_canonical_contracts
  implicit none
  private

  type, extends(canonical_state_t), public :: fci04_state_t
    real(real64) :: water = 0.0_real64
  contains
    procedure :: clone => fci04_clone
  end type fci04_state_t

  type, extends(canonical_forcing_t), public :: fci04_forcing_t
    real(real64) :: k = 1.0_real64
  end type fci04_forcing_t

  type, extends(canonical_physical_model_t), public :: fci04_model_t
    real(real64) :: k = 1.0_real64
    logical :: inject_mass_defect = .false.
    real(real64) :: mass_defect = 0.0_real64
    integer :: prepare_calls = 0
  contains
    procedure :: advance => fci04_advance
    procedure :: storage => fci04_storage
    procedure :: temporal_error => fci04_temporal_error
    procedure :: prepare_interval => fci04_prepare_interval
  end type fci04_model_t

contains

  subroutine fci04_clone(self, copy)
    class(fci04_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fci04_state_t :: copy)
    select type(copy)
    type is(fci04_state_t)
      copy%water = self%water
    end select
  end subroutine fci04_clone

  subroutine fci04_prepare_interval(self, forcing, interval, config)
    class(fci04_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    self%prepare_calls = self%prepare_calls + 1
    select type(forcing)
    type is(fci04_forcing_t)
      self%k = forcing%k
    class default
      error stop 'FCI04 unexpected forcing type'
    end select
    if (interval%t1 <= interval%t0) error stop 'FCI04 prepare got invalid interval'
    if (config%max_committed_substeps <= 0) error stop 'FCI04 prepare got invalid config'
  end subroutine fci04_prepare_interval

  subroutine fci04_advance(self, state, t0, t1, outcome)
    class(fci04_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: dt, start_water, end_water

    outcome = trial_outcome_t()
    dt = t1 - t0
    select type(state)
    type is(fci04_state_t)
      start_water = state%water
      end_water = start_water * (1.0_real64 - self%k * dt)
      state%water = end_water
      outcome%mass_out = start_water - end_water
      if (self%inject_mass_defect) outcome%mass_out = outcome%mass_out + self%mass_defect
      outcome%solver_ok = .true.
      outcome%nonlinear_iterations = 1
    class default
      error stop 'FCI04 unexpected state type'
    end select
  end subroutine fci04_advance

  function fci04_storage(self, state) result(value)
    class(fci04_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value
    if (self%k < -huge(0.0_real64)) error stop 'unreachable'
    select type(state)
    type is(fci04_state_t)
      value = state%water
    class default
      error stop 'FCI04 unexpected state type'
    end select
  end function fci04_storage

  function fci04_temporal_error(self, full_state, half_state) result(value)
    class(fci04_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    real(real64) :: value, full_water, half_water
    if (self%k < -huge(0.0_real64)) error stop 'unreachable'
    select type(full_state)
    type is(fci04_state_t)
      full_water = full_state%water
    class default
      error stop 'FCI04 unexpected full state type'
    end select
    select type(half_state)
    type is(fci04_state_t)
      half_water = half_state%water
    class default
      error stop 'FCI04 unexpected half state type'
    end select
    value = abs(half_water - full_water)
  end function fci04_temporal_error

end module mod_fci04_test_model

program test_fci04_interval_runtime
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts
  use mod_canonical_interval_runtime
  use mod_fci04_test_model
  implicit none

  integer :: failures
  failures = 0
  call test_complete_requested_interval(failures)
  call test_external_atomicity_on_substep_limit(failures)
  call test_mass_failure_keeps_committed_state(failures)
  call test_generic_noncalendar_interval(failures)
  call test_repeatability(failures)
  call test_forcing_is_separate_input(failures)
  call test_invalid_request(failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'FCI04_INTERVAL_RUNTIME_GATE FAIL failures=', failures
    error stop 1
  end if
  write(*,'(A)') 'FCI04_INTERVAL_RUNTIME_GATE PASS'

contains

  subroutine new_state(state, water)
    class(transaction_state_t), allocatable, intent(out) :: state
    real(real64), intent(in) :: water
    allocate(fci04_state_t :: state)
    select type(state)
    type is(fci04_state_t)
      state%water = water
    end select
  end subroutine new_state

  function water_of(state) result(value)
    class(transaction_state_t), allocatable, intent(in) :: state
    real(real64) :: value
    select type(state)
    type is(fci04_state_t)
      value = state%water
    class default
      error stop 'FCI04 unexpected state in water_of'
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
    type(fci04_forcing_t), intent(out) :: forcing
    interval%t0 = 5.0_real64
    interval%t1 = 5.5_real64
    forcing%k = 1.0_real64
    config%transaction%temporal_tolerance = 0.02_real64
    config%transaction%mass_tolerance = 1.0e-13_real64
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 3
    config%max_committed_substeps = 10
  end subroutine standard_setup

  subroutine test_complete_requested_interval(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(fci04_model_t) :: model
    type(fci04_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result

    call new_state(state, 1.0_real64)
    call standard_setup(interval, config, forcing)
    call run_canonical_interval(model, state, forcing, interval, config, result)
    call expect_true(result%status == CANONICAL_STATUS_COMPLETED, 'full interval completed', failures)
    call expect_true(result%completed, 'completed flag', failures)
    call expect_true(result%diagnostics%committed_substeps == 2, 'two accepted internal substeps', failures)
    call expect_true(result%diagnostics%transaction_calls == 2, 'two transaction calls', failures)
    call expect_true(result%diagnostics%external_commits == 1, 'one external commit', failures)
    call expect_true(result%diagnostics%retries == 1, 'one internal interval shrink', failures)
    call expect_close(result%completed_t, 5.5_real64, 1.0e-14_real64, 'requested t1 reached', failures)
    call expect_close(water_of(state), 0.586181640625_real64, 1.0e-14_real64, 'endpoint from complete interval', failures)
    call expect_true(.not. result%mass%complete, 'aggregate mass not fabricated', failures)
    call expect_true(model%prepare_calls == 1, 'forcing/config prepared once', failures)
  end subroutine test_complete_requested_interval

  subroutine test_external_atomicity_on_substep_limit(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(fci04_model_t) :: model
    type(fci04_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result

    call new_state(state, 1.0_real64)
    call standard_setup(interval, config, forcing)
    config%max_committed_substeps = 1
    call run_canonical_interval(model, state, forcing, interval, config, result)
    call expect_true(result%status == CANONICAL_STATUS_SUBSTEP_LIMIT, 'substep limit reported', failures)
    call expect_true(result%diagnostics%committed_substeps == 1, 'working state did one substep', failures)
    call expect_true(result%diagnostics%external_commits == 0, 'no partial external commit', failures)
    call expect_close(water_of(state), 1.0_real64, 0.0_real64, 'external state atomic on incomplete interval', failures)
  end subroutine test_external_atomicity_on_substep_limit

  subroutine test_mass_failure_keeps_committed_state(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(fci04_model_t) :: model
    type(fci04_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result

    call new_state(state, 1.0_real64)
    call standard_setup(interval, config, forcing)
    model%inject_mass_defect = .true.
    model%mass_defect = 1.0e-4_real64
    config%transaction%temporal_tolerance = 1.0_real64
    config%transaction%max_retries = 1
    call run_canonical_interval(model, state, forcing, interval, config, result)
    call expect_true(result%status == CANONICAL_STATUS_TRANSACTION_FAILED, 'mass failure propagated', failures)
    call expect_true(result%diagnostics%mass_rejections > 0, 'hard mass gate active', failures)
    call expect_true(result%diagnostics%external_commits == 0, 'mass failure never externally commits', failures)
    call expect_close(water_of(state), 1.0_real64, 0.0_real64, 'mass failure keeps committed state', failures)
  end subroutine test_mass_failure_keeps_committed_state

  subroutine test_generic_noncalendar_interval(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(fci04_model_t) :: model
    type(fci04_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result

    call new_state(state, 2.0_real64)
    call standard_setup(interval, config, forcing)
    interval%t0 = 123.456_real64
    interval%t1 = 123.506_real64
    config%transaction%temporal_tolerance = 0.1_real64
    call run_canonical_interval(model, state, forcing, interval, config, result)
    call expect_true(result%status == CANONICAL_STATUS_COMPLETED, 'noncalendar interval completed', failures)
    call expect_close(result%completed_t, interval%t1, 1.0e-13_real64, 'noncalendar t1 preserved', failures)
  end subroutine test_generic_noncalendar_interval

  subroutine test_repeatability(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state_a, state_b
    type(fci04_model_t) :: model_a, model_b
    type(fci04_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result_a, result_b

    call new_state(state_a, 1.0_real64)
    call new_state(state_b, 1.0_real64)
    call standard_setup(interval, config, forcing)
    call run_canonical_interval(model_a, state_a, forcing, interval, config, result_a)
    call run_canonical_interval(model_b, state_b, forcing, interval, config, result_b)
    call expect_close(water_of(state_a), water_of(state_b), 0.0_real64, 'repeat endpoint exact', failures)
    call expect_true(result_a%diagnostics%retries == result_b%diagnostics%retries, 'repeat retries exact', failures)
    call expect_true(result_a%diagnostics%attempts == result_b%diagnostics%attempts, 'repeat attempts exact', failures)
  end subroutine test_repeatability

  subroutine test_forcing_is_separate_input(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state_a, state_b
    type(fci04_model_t) :: model_a, model_b
    type(fci04_forcing_t) :: forcing_a, forcing_b
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result_a, result_b

    call new_state(state_a, 1.0_real64)
    call new_state(state_b, 1.0_real64)
    call standard_setup(interval, config, forcing_a)
    interval%t1 = 5.1_real64
    config%transaction%temporal_tolerance = 0.1_real64
    forcing_b = forcing_a
    forcing_b%k = 0.5_real64
    call run_canonical_interval(model_a, state_a, forcing_a, interval, config, result_a)
    call run_canonical_interval(model_b, state_b, forcing_b, interval, config, result_b)
    call expect_true(result_a%status == CANONICAL_STATUS_COMPLETED .and. &
                     result_b%status == CANONICAL_STATUS_COMPLETED, 'forcing cases completed', failures)
    call expect_true(abs(water_of(state_a)-water_of(state_b)) > 1.0e-6_real64, &
                     'forcing changes without changing persistent state type', failures)
  end subroutine test_forcing_is_separate_input

  subroutine test_invalid_request(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: state
    type(fci04_model_t) :: model
    type(fci04_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result

    call new_state(state, 1.0_real64)
    call standard_setup(interval, config, forcing)
    interval%t1 = interval%t0
    call run_canonical_interval(model, state, forcing, interval, config, result)
    call expect_true(result%status == CANONICAL_STATUS_INVALID_REQUEST, 'invalid interval rejected', failures)
    call expect_close(water_of(state), 1.0_real64, 0.0_real64, 'invalid request keeps state', failures)
    call expect_true(model%prepare_calls == 0, 'invalid request never reaches model', failures)
  end subroutine test_invalid_request

end program test_fci04_interval_runtime
