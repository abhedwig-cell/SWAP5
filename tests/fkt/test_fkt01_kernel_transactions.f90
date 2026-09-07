module mod_fkt01_test_model
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t
  implicit none
  private

  type, extends(canonical_state_t), public :: fkt01_state_t
    real(real64) :: water = 0.0_real64
  contains
    procedure :: clone => fkt01_clone
  end type fkt01_state_t

  type, extends(kernel_parameters_t), public :: fkt01_parameters_t
    real(real64) :: rate = 1.0_real64
  end type fkt01_parameters_t

  type, extends(canonical_forcing_t), public :: fkt01_forcing_t
    real(real64) :: scale = 1.0_real64
  end type fkt01_forcing_t

  type, extends(kernel_model_t), public :: fkt01_model_t
    real(real64) :: rate = 1.0_real64
    real(real64) :: forcing_scale = 1.0_real64
    real(real64) :: warm_seed = 0.0_real64
    logical :: admitted = .false.
    logical :: inject_mass_defect = .false.
    real(real64) :: mass_defect = 0.0_real64
    integer :: configure_calls = 0
    integer :: prepare_calls = 0
  contains
    procedure :: configure_parameters => fkt01_configure_parameters
    procedure :: execution_admitted => fkt01_execution_admitted
    procedure :: prepare_interval => fkt01_prepare_interval
    procedure :: advance => fkt01_advance
    procedure :: storage => fkt01_storage
    procedure :: temporal_error => fkt01_temporal_error
  end type fkt01_model_t

contains

  subroutine fkt01_clone(self, copy)
    class(fkt01_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fkt01_state_t :: copy)
    select type(copy)
    type is(fkt01_state_t)
      copy%water = self%water
    end select
  end subroutine fkt01_clone

  subroutine fkt01_configure_parameters(self, parameters)
    class(fkt01_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    self%configure_calls = self%configure_calls + 1
    select type(parameters)
    type is(fkt01_parameters_t)
      self%rate = parameters%rate
    class default
      error stop 'FKT01 unexpected parameter type'
    end select
  end subroutine fkt01_configure_parameters

  logical function fkt01_execution_admitted(self, parameters, numerical_config)
    class(fkt01_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    logical :: parameter_ok

    parameter_ok = .false.
    select type(parameters)
    type is(fkt01_parameters_t)
      parameter_ok = parameters%rate >= 0.0_real64
    class default
      parameter_ok = .false.
    end select
    fkt01_execution_admitted = self%admitted .and. parameter_ok .and. &
         numerical_config%max_committed_substeps > 0
  end function fkt01_execution_admitted

  subroutine fkt01_prepare_interval(self, forcing, interval, config)
    class(fkt01_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    self%prepare_calls = self%prepare_calls + 1
    select type(forcing)
    type is(fkt01_forcing_t)
      self%forcing_scale = forcing%scale
    class default
      error stop 'FKT01 unexpected forcing type'
    end select
    if (interval%t1 <= interval%t0) error stop 'FKT01 invalid interval reached model'
    if (config%max_committed_substeps <= 0) error stop 'FKT01 invalid config reached model'
  end subroutine fkt01_prepare_interval

  subroutine fkt01_advance(self, state, t0, t1, outcome)
    class(fkt01_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: dt, start_water, end_water, k

    outcome = trial_outcome_t()
    dt = t1 - t0
    k = self%rate * self%forcing_scale
    self%warm_seed = self%warm_seed + 1.0_real64
    select type(state)
    type is(fkt01_state_t)
      start_water = state%water
      end_water = start_water * (1.0_real64 - k * dt)
      state%water = end_water
      outcome%mass_out = start_water - end_water
      if (self%inject_mass_defect) outcome%mass_out = outcome%mass_out + self%mass_defect
      outcome%solver_ok = .true.
      outcome%nonlinear_iterations = 1
    class default
      error stop 'FKT01 unexpected state type'
    end select
  end subroutine fkt01_advance

  function fkt01_storage(self, state) result(value)
    class(fkt01_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value
    if (self%rate < -huge(0.0_real64)) error stop 'unreachable'
    select type(state)
    type is(fkt01_state_t)
      value = state%water
    class default
      error stop 'FKT01 unexpected state type'
    end select
  end function fkt01_storage

  function fkt01_temporal_error(self, full_state, half_state) result(value)
    class(fkt01_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    real(real64) :: value, full_water, half_water
    if (self%rate < -huge(0.0_real64)) error stop 'unreachable'
    select type(full_state)
    type is(fkt01_state_t)
      full_water = full_state%water
    class default
      error stop 'FKT01 unexpected full state type'
    end select
    select type(half_state)
    type is(fkt01_state_t)
      half_water = half_state%water
    class default
      error stop 'FKT01 unexpected half state type'
    end select
    value = abs(half_water - full_water)
  end function fkt01_temporal_error

end module mod_fkt01_test_model

program test_fkt01_kernel_transactions
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED, &
       CANONICAL_STATUS_TRANSACTION_FAILED
  use mod_kernel_transactions
  use mod_fkt01_test_model
  implicit none

  integer :: failures
  failures = 0
  call test_candidate_boundary(failures)
  call test_fail_closed_admission(failures)
  call test_same_committed_replay(failures)
  call test_rejected_trials_do_not_escape(failures)
  call test_generic_time_and_separate_inputs(failures)
  call test_candidate_rollback(failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'FKT01_KERNEL_TRANSACTION_GATE FAIL failures=', failures
    error stop 1
  end if
  write(*,'(A)') 'FKT01_KERNEL_TRANSACTION_GATE PASS'

contains

  subroutine new_state(state, water)
    class(transaction_state_t), allocatable, intent(out) :: state
    real(real64), intent(in) :: water
    allocate(fkt01_state_t :: state)
    select type(state)
    type is(fkt01_state_t)
      state%water = water
    end select
  end subroutine new_state

  function water_of(state) result(value)
    class(transaction_state_t), allocatable, intent(in) :: state
    real(real64) :: value
    select type(state)
    type is(fkt01_state_t)
      value = state%water
    class default
      error stop 'FKT01 unexpected state type in water_of'
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

  subroutine standard_setup(parameters, forcing, config)
    type(fkt01_parameters_t), intent(out) :: parameters
    type(fkt01_forcing_t), intent(out) :: forcing
    type(canonical_numerical_config_t), intent(out) :: config
    parameters%rate = 1.0_real64
    forcing%scale = 1.0_real64
    config%transaction%temporal_tolerance = 0.02_real64
    config%transaction%mass_tolerance = 1.0e-13_real64
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 3
    config%max_committed_substeps = 10
  end subroutine standard_setup

  subroutine test_candidate_boundary(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: committed
    type(fkt01_parameters_t) :: parameters
    type(fkt01_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt01_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    logical :: did_commit

    call new_state(committed, 1.0_real64)
    call standard_setup(parameters, forcing, config)
    model%admitted = .true.
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 5.0_real64, 5.5_real64, &
         result, candidate, diagnostics)

    call expect_true(result%status == CANONICAL_STATUS_COMPLETED, 'completed candidate result', failures)
    call expect_true(result%completed, 'completed flag', failures)
    call expect_close(water_of(committed), 1.0_real64, 0.0_real64, 'advance never mutates committed', failures)
    call expect_true(candidate%valid .and. allocated(candidate%state), 'candidate materialized', failures)
    call expect_close(water_of(candidate%state), 0.586181640625_real64, 1.0e-14_real64, &
         'candidate endpoint', failures)
    call expect_true(diagnostics%committed_state_mutations == 0, 'no pre-commit mutation diagnostic', failures)
    call expect_true(diagnostics%candidate_materializations == 1, 'one candidate materialization', failures)
    call expect_true(diagnostics%retries == 1, 'qualified retry path preserved', failures)
    call expect_true(.not. result%mass%complete, 'full interval mass not fabricated', failures)

    call kernel%commit_candidate(committed, candidate, diagnostics, did_commit)
    call expect_true(did_commit, 'candidate commit accepted', failures)
    call expect_close(water_of(committed), 0.586181640625_real64, 1.0e-14_real64, &
         'commit publishes candidate', failures)
    call expect_true(.not. candidate%valid .and. .not. allocated(candidate%state), &
         'candidate consumed by commit', failures)
    call expect_true(diagnostics%committed_state_mutations == 1, 'exactly one explicit mutation', failures)
  end subroutine test_candidate_boundary

  subroutine test_fail_closed_admission(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: committed
    type(fkt01_parameters_t) :: parameters
    type(fkt01_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt01_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics

    call new_state(committed, 1.0_real64)
    call standard_setup(parameters, forcing, config)
    model%admitted = .false.
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 5.0_real64, 5.5_real64, &
         result, candidate, diagnostics)

    call expect_true(result%status == KERNEL_STATUS_NOT_ADMITTED, 'missing qualification fails closed', failures)
    call expect_close(water_of(committed), 1.0_real64, 0.0_real64, 'fail-closed keeps committed', failures)
    call expect_true(.not. candidate%valid .and. .not. allocated(candidate%state), &
         'fail-closed creates no candidate', failures)
    call expect_true(model%configure_calls == 0 .and. model%prepare_calls == 0, &
         'fail-closed never enters physical execution', failures)
    call expect_true(diagnostics%admission_rejections == 1, 'admission rejection diagnosed', failures)
  end subroutine test_fail_closed_admission

  subroutine test_same_committed_replay(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: committed
    type(fkt01_parameters_t) :: parameters
    type(fkt01_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt01_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result_a, result_b
    type(kernel_candidate_state_t) :: candidate_a, candidate_b
    type(kernel_diagnostics_t) :: diagnostics_a, diagnostics_b

    call new_state(committed, 1.0_real64)
    call standard_setup(parameters, forcing, config)
    model%admitted = .true.
    call kernel%bind_model(model)

    call kernel%advance_interval(parameters, committed, forcing, config, 5.0_real64, 5.5_real64, &
         result_a, candidate_a, diagnostics_a)
    call kernel%advance_interval(parameters, committed, forcing, config, 5.0_real64, 5.5_real64, &
         result_b, candidate_b, diagnostics_b)

    call expect_close(water_of(committed), 1.0_real64, 0.0_real64, 'replay origin remains committed', failures)
    call expect_close(water_of(candidate_a%state), water_of(candidate_b%state), 0.0_real64, &
         'same committed replay endpoint exact despite warm seed', failures)
    call expect_true(diagnostics_a%attempts == diagnostics_b%attempts, 'replay attempts exact', failures)
    call expect_true(diagnostics_a%retries == diagnostics_b%retries, 'replay retries exact', failures)
    call expect_true(result_a%completed .and. result_b%completed, 'both replay runs complete', failures)
  end subroutine test_same_committed_replay

  subroutine test_rejected_trials_do_not_escape(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: committed
    type(fkt01_parameters_t) :: parameters
    type(fkt01_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt01_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics

    call new_state(committed, 1.0_real64)
    call standard_setup(parameters, forcing, config)
    model%admitted = .true.
    model%inject_mass_defect = .true.
    model%mass_defect = 1.0e-4_real64
    config%transaction%temporal_tolerance = 1.0_real64
    config%transaction%max_retries = 1
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 5.0_real64, 5.5_real64, &
         result, candidate, diagnostics)

    call expect_true(result%status == CANONICAL_STATUS_TRANSACTION_FAILED, 'mass rejection propagated', failures)
    call expect_close(water_of(committed), 1.0_real64, 0.0_real64, 'rejected trials keep committed', failures)
    call expect_true(.not. candidate%valid .and. .not. allocated(candidate%state), &
         'rejected interval has no candidate', failures)
    call expect_true(diagnostics%mass_rejections > 0, 'hard unrounded mass gate active', failures)
    call expect_true(diagnostics%trial_rollbacks > 0, 'trial rollback diagnosed', failures)
    call expect_true(diagnostics%committed_state_mutations == 0, 'failure never mutates committed', failures)
  end subroutine test_rejected_trials_do_not_escape

  subroutine test_generic_time_and_separate_inputs(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: committed
    type(fkt01_parameters_t) :: parameters_a, parameters_b
    type(fkt01_forcing_t) :: forcing_a, forcing_b
    type(canonical_numerical_config_t) :: config
    type(fkt01_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result_a, result_b
    type(kernel_candidate_state_t) :: candidate_a, candidate_b
    type(kernel_diagnostics_t) :: diagnostics_a, diagnostics_b

    call new_state(committed, 2.0_real64)
    call standard_setup(parameters_a, forcing_a, config)
    parameters_a%rate = 0.5_real64
    parameters_b = parameters_a
    parameters_b%rate = 1.0_real64
    forcing_b = forcing_a
    forcing_b%scale = 0.5_real64
    config%transaction%temporal_tolerance = 0.1_real64
    model%admitted = .true.
    call kernel%bind_model(model)

    call kernel%advance_interval(parameters_a, committed, forcing_a, config, 123.456_real64, 123.506_real64, &
         result_a, candidate_a, diagnostics_a)
    call kernel%advance_interval(parameters_b, committed, forcing_b, config, 123.456_real64, 123.506_real64, &
         result_b, candidate_b, diagnostics_b)

    call expect_true(result_a%completed .and. result_b%completed, 'generic noncalendar intervals complete', failures)
    call expect_close(result_a%completed_t, 123.506_real64, 1.0e-13_real64, 'generic t1 preserved', failures)
    call expect_close(water_of(candidate_a%state), water_of(candidate_b%state), 0.0_real64, &
         'parameters and forcing remain independent multiplicative inputs', failures)
    call expect_close(water_of(committed), 2.0_real64, 0.0_real64, 'generic trials keep committed', failures)
  end subroutine test_generic_time_and_separate_inputs

  subroutine test_candidate_rollback(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: committed
    type(fkt01_parameters_t) :: parameters
    type(fkt01_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt01_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics

    call new_state(committed, 1.0_real64)
    call standard_setup(parameters, forcing, config)
    model%admitted = .true.
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 5.0_real64, 5.5_real64, &
         result, candidate, diagnostics)
    call expect_true(candidate%valid, 'rollback setup candidate exists', failures)
    call kernel%rollback_candidate(candidate, diagnostics)
    call expect_close(water_of(committed), 1.0_real64, 0.0_real64, 'candidate rollback keeps committed', failures)
    call expect_true(.not. candidate%valid .and. .not. allocated(candidate%state), &
         'candidate rollback discards candidate', failures)
    call expect_true(diagnostics%candidate_rollbacks == 1, 'candidate rollback diagnosed', failures)
    call expect_true(diagnostics%committed_state_mutations == 0, 'rollback makes no committed mutation', failures)
  end subroutine test_candidate_rollback

end program test_fkt01_kernel_transactions
