module mod_fkt04_test_model
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t
  implicit none
  private

  type, extends(canonical_state_t), public :: fkt04_state_t
    real(real64) :: water = 0.0_real64
  contains
    procedure :: clone => fkt04_clone
  end type fkt04_state_t

  type, extends(kernel_parameters_t), public :: fkt04_parameters_t
    real(real64) :: rate = 0.1_real64
  end type fkt04_parameters_t

  type, extends(canonical_forcing_t), public :: fkt04_forcing_t
    real(real64) :: scale = 1.0_real64
  end type fkt04_forcing_t

  type, extends(kernel_model_t), public :: fkt04_model_t
    real(real64) :: rate = 0.1_real64
    real(real64) :: forcing_scale = 1.0_real64
    integer :: advance_calls = 0
  contains
    procedure :: configure_parameters => fkt04_configure_parameters
    procedure :: execution_admitted => fkt04_execution_admitted
    procedure :: prepare_interval => fkt04_prepare_interval
    procedure :: advance => fkt04_advance
    procedure :: storage => fkt04_storage
    procedure :: temporal_error => fkt04_temporal_error
  end type fkt04_model_t

contains

  subroutine fkt04_clone(self, copy)
    class(fkt04_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fkt04_state_t :: copy)
    select type (copy)
    type is (fkt04_state_t)
      copy%water = self%water
    end select
  end subroutine fkt04_clone

  subroutine fkt04_configure_parameters(self, parameters)
    class(fkt04_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    select type (parameters)
    type is (fkt04_parameters_t)
      self%rate = parameters%rate
    class default
      error stop 'FKT04 unexpected parameter type'
    end select
  end subroutine fkt04_configure_parameters

  logical function fkt04_execution_admitted(self, parameters, numerical_config)
    class(fkt04_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    logical :: parameter_ok

    parameter_ok = .false.
    select type (parameters)
    type is (fkt04_parameters_t)
      parameter_ok = parameters%rate >= 0.0_real64
    class default
      parameter_ok = .false.
    end select
    fkt04_execution_admitted = parameter_ok .and. numerical_config%max_committed_substeps > 0 .and. &
         self%advance_calls >= 0
  end function fkt04_execution_admitted

  subroutine fkt04_prepare_interval(self, forcing, interval, config)
    class(fkt04_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config

    select type (forcing)
    type is (fkt04_forcing_t)
      self%forcing_scale = forcing%scale
    class default
      error stop 'FKT04 unexpected forcing type'
    end select
    if (interval%t1 <= interval%t0) error stop 'FKT04 invalid interval reached model'
    if (config%max_committed_substeps <= 0) error stop 'FKT04 invalid config reached model'
  end subroutine fkt04_prepare_interval

  subroutine fkt04_advance(self, state, t0, t1, outcome)
    class(fkt04_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: dt, start_water, end_water, k

    outcome = trial_outcome_t()
    dt = t1 - t0
    k = self%rate * self%forcing_scale
    self%advance_calls = self%advance_calls + 1
    select type (state)
    type is (fkt04_state_t)
      start_water = state%water
      end_water = start_water * (1.0_real64 - k * dt)
      state%water = end_water
      outcome%mass_out = start_water - end_water
      outcome%solver_ok = .true.
      outcome%nonlinear_iterations = 1
    class default
      error stop 'FKT04 unexpected state type'
    end select
  end subroutine fkt04_advance

  function fkt04_storage(self, state) result(value)
    class(fkt04_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value
    if (self%advance_calls < 0) error stop 'unreachable'
    select type (state)
    type is (fkt04_state_t)
      value = state%water
    class default
      error stop 'FKT04 unexpected state type'
    end select
  end function fkt04_storage

  function fkt04_temporal_error(self, full_state, half_state) result(value)
    class(fkt04_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    real(real64) :: value, full_water, half_water
    if (self%advance_calls < 0) error stop 'unreachable'

    select type (full_state)
    type is (fkt04_state_t)
      full_water = full_state%water
    class default
      error stop 'FKT04 unexpected full state type'
    end select
    select type (half_state)
    type is (fkt04_state_t)
      half_water = half_state%water
    class default
      error stop 'FKT04 unexpected half state type'
    end select
    value = abs(half_water - full_water)
  end function fkt04_temporal_error

end module mod_fkt04_test_model

program test_fkt04_temporal_provenance
  use, intrinsic :: ieee_arithmetic, only: ieee_quiet_nan, ieee_value
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED, &
       CANONICAL_STATUS_INVALID_REQUEST
  use mod_kernel_transactions
  use mod_fkt04_test_model
  implicit none

  integer :: failures
  failures = 0

  call test_explicit_initial_time(failures)
  call test_post_commit_continuity(failures)
  call test_unbound_first_commit_binds_time(failures)
  call test_roundoff_equivalent_origin(failures)
  call test_nonfinite_time_fails_closed(failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'FKT04_TEMPORAL_PROVENANCE_GATE FAIL failures=', failures
    error stop 1
  end if
  write(*,'(A)') 'FKT04_TEMPORAL_PROVENANCE_GATE PASS'

contains

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

  subroutine new_physical(state, water)
    class(transaction_state_t), allocatable, intent(out) :: state
    real(real64), intent(in) :: water
    allocate(fkt04_state_t :: state)
    select type (state)
    type is (fkt04_state_t)
      state%water = water
    end select
  end subroutine new_physical

  subroutine new_bound_committed(committed, lineage_id, water, initial_time, did_initialize)
    type(kernel_committed_state_t), intent(out) :: committed
    integer(int64), intent(in) :: lineage_id
    real(real64), intent(in) :: water, initial_time
    logical, intent(out) :: did_initialize
    class(transaction_state_t), allocatable :: physical

    call new_physical(physical, water)
    call committed%initialize(lineage_id, physical, did_initialize, initial_time)
  end subroutine new_bound_committed

  subroutine new_unbound_committed(committed, lineage_id, water)
    type(kernel_committed_state_t), intent(out) :: committed
    integer(int64), intent(in) :: lineage_id
    real(real64), intent(in) :: water
    class(transaction_state_t), allocatable :: physical
    logical :: did_initialize

    call new_physical(physical, water)
    call committed%initialize(lineage_id, physical, did_initialize)
    if (.not. did_initialize) error stop 'FKT04 unbound initialization failed'
  end subroutine new_unbound_committed

  function committed_water(committed) result(value)
    type(kernel_committed_state_t), intent(in) :: committed
    real(real64) :: value
    class(transaction_state_t), allocatable :: snapshot
    logical :: available

    call committed%snapshot(snapshot, available)
    if (.not. available) error stop 'FKT04 committed snapshot unavailable'
    select type (snapshot)
    type is (fkt04_state_t)
      value = snapshot%water
    class default
      error stop 'FKT04 unexpected snapshot type'
    end select
  end function committed_water

  subroutine standard_setup(parameters, forcing, config)
    type(fkt04_parameters_t), intent(out) :: parameters
    type(fkt04_forcing_t), intent(out) :: forcing
    type(canonical_numerical_config_t), intent(out) :: config

    parameters%rate = 0.1_real64
    forcing%scale = 1.0_real64
    config%transaction%temporal_tolerance = 1.0_real64
    config%transaction%mass_tolerance = 1.0e-13_real64
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 2
    config%max_committed_substeps = 8
    config%progress_tolerance = 0.0_real64
  end subroutine standard_setup

  subroutine test_explicit_initial_time(failures)
    integer, intent(inout) :: failures
    type(kernel_committed_state_t) :: committed
    type(fkt04_parameters_t) :: parameters
    type(fkt04_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt04_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    logical :: did_initialize, did_commit, available
    integer :: commit_status
    real(real64) :: current_time

    call new_bound_committed(committed, 401_int64, 1.0_real64, 5.125_real64, did_initialize)
    call expect_true(did_initialize, 'explicit-time initialization succeeds', failures)
    call expect_true(committed%time_is_bound(), 'explicit time is bound', failures)
    call committed%current_time(current_time, available)
    call expect_true(available, 'explicit current time available', failures)
    call expect_close(current_time, 5.125_real64, 0.0_real64, 'explicit current time exact', failures)

    call standard_setup(parameters, forcing, config)
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 5.0_real64, 5.5_real64, &
         result, candidate, diagnostics)
    call expect_true(result%status == KERNEL_STATUS_TIME_MISMATCH, 'wrong t0 rejected', failures)
    call expect_true(diagnostics%time_origin_rejections == 1, 'wrong t0 diagnosed', failures)
    call expect_true(model%advance_calls == 0, 'wrong t0 rejected before model execution', failures)
    call expect_true(.not. candidate%ready(), 'wrong t0 creates no candidate', failures)
    call expect_close(committed_water(committed), 1.0_real64, 0.0_real64, &
         'wrong t0 leaves committed physical state unchanged', failures)

    call kernel%advance_interval(parameters, committed, forcing, config, 5.125_real64, 5.625_real64, &
         result, candidate, diagnostics)
    call expect_true(result%status == CANONICAL_STATUS_COMPLETED, 'matching t0 completes', failures)
    call kernel%commit_candidate(committed, candidate, diagnostics, did_commit, commit_status)
    call expect_true(did_commit, 'matching candidate commits', failures)
    call expect_true(commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'commit status exact', failures)
    call committed%current_time(current_time, available)
    call expect_true(available, 'committed time remains available', failures)
    call expect_close(current_time, 5.625_real64, 0.0_real64, 'commit advances time to candidate t1', failures)
  end subroutine test_explicit_initial_time

  subroutine test_post_commit_continuity(failures)
    integer, intent(inout) :: failures
    type(kernel_committed_state_t) :: committed
    type(fkt04_parameters_t) :: parameters
    type(fkt04_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt04_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    logical :: did_initialize, did_commit

    call new_bound_committed(committed, 402_int64, 1.0_real64, 1.0_real64, did_initialize)
    if (.not. did_initialize) error stop 'FKT04 bound initialization failed'
    call standard_setup(parameters, forcing, config)
    call kernel%bind_model(model)

    call kernel%advance_interval(parameters, committed, forcing, config, 1.0_real64, 2.0_real64, &
         result, candidate, diagnostics)
    call kernel%commit_candidate(committed, candidate, diagnostics, did_commit)
    call expect_true(did_commit, 'first interval commits', failures)

    call kernel%advance_interval(parameters, committed, forcing, config, 1.5_real64, 2.5_real64, &
         result, candidate, diagnostics)
    call expect_true(result%status == KERNEL_STATUS_TIME_MISMATCH, 'overlap rejected', failures)

    call kernel%advance_interval(parameters, committed, forcing, config, 2.5_real64, 3.0_real64, &
         result, candidate, diagnostics)
    call expect_true(result%status == KERNEL_STATUS_TIME_MISMATCH, 'gap rejected', failures)

    call kernel%advance_interval(parameters, committed, forcing, config, 2.0_real64, 2.5_real64, &
         result, candidate, diagnostics)
    call expect_true(result%status == CANONICAL_STATUS_COMPLETED, 'contiguous interval accepted', failures)
    call kernel%rollback_candidate(candidate, diagnostics)
    call expect_true(committed%current_revision() == 1_int64, 'rollback keeps committed revision', failures)
  end subroutine test_post_commit_continuity

  subroutine test_unbound_first_commit_binds_time(failures)
    integer, intent(inout) :: failures
    type(kernel_committed_state_t) :: committed
    type(fkt04_parameters_t) :: parameters
    type(fkt04_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt04_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    logical :: did_commit, available
    real(real64) :: current_time

    call new_unbound_committed(committed, 403_int64, 1.0_real64)
    call expect_true(.not. committed%time_is_bound(), 'legacy-compatible initial carrier is unbound', failures)
    call committed%current_time(current_time, available)
    call expect_true(.not. available, 'unbound carrier exposes no current time', failures)

    call standard_setup(parameters, forcing, config)
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 12.25_real64, 12.75_real64, &
         result, candidate, diagnostics)
    call expect_true(result%status == CANONICAL_STATUS_COMPLETED, 'first unbound interval completes', failures)
    call kernel%commit_candidate(committed, candidate, diagnostics, did_commit)
    call expect_true(did_commit, 'first unbound candidate commits', failures)
    call expect_true(committed%time_is_bound(), 'first commit binds timeline', failures)
    call committed%current_time(current_time, available)
    call expect_true(available, 'bound current time becomes available', failures)
    call expect_close(current_time, 12.75_real64, 0.0_real64, 'first commit binds candidate t1', failures)
  end subroutine test_unbound_first_commit_binds_time

  subroutine test_roundoff_equivalent_origin(failures)
    integer, intent(inout) :: failures
    type(kernel_committed_state_t) :: committed
    type(fkt04_parameters_t) :: parameters
    type(fkt04_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt04_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    logical :: did_initialize
    real(real64) :: represented_time

    represented_time = 0.1_real64 + 0.2_real64
    call new_bound_committed(committed, 404_int64, 1.0_real64, represented_time, did_initialize)
    if (.not. did_initialize) error stop 'FKT04 roundoff initialization failed'
    call standard_setup(parameters, forcing, config)
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 0.3_real64, 0.4_real64, &
         result, candidate, diagnostics)
    call expect_true(result%status == CANONICAL_STATUS_COMPLETED, &
         'machine-roundoff-equivalent t0 accepted', failures)
    call kernel%rollback_candidate(candidate, diagnostics)
  end subroutine test_roundoff_equivalent_origin

  subroutine test_nonfinite_time_fails_closed(failures)
    integer, intent(inout) :: failures
    type(kernel_committed_state_t) :: invalid_committed, committed
    type(fkt04_parameters_t) :: parameters
    type(fkt04_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt04_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    logical :: did_initialize
    real(real64) :: nan_value

    nan_value = ieee_value(0.0_real64, ieee_quiet_nan)
    call new_bound_committed(invalid_committed, 405_int64, 1.0_real64, nan_value, did_initialize)
    call expect_true(.not. did_initialize, 'nonfinite initial time rejected', failures)
    call expect_true(.not. invalid_committed%ready(), 'nonfinite initialization leaves carrier unready', failures)

    call new_bound_committed(committed, 406_int64, 1.0_real64, 1.0_real64, did_initialize)
    if (.not. did_initialize) error stop 'FKT04 finite initialization failed'
    call standard_setup(parameters, forcing, config)
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, nan_value, 2.0_real64, &
         result, candidate, diagnostics)
    call expect_true(result%status == CANONICAL_STATUS_INVALID_REQUEST, 'nonfinite t0 rejected', failures)
    call expect_true(model%advance_calls == 0, 'nonfinite interval rejected before model execution', failures)
  end subroutine test_nonfinite_time_fails_closed

end program test_fkt04_temporal_provenance
