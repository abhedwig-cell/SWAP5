module mod_fkt05_test_model
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t
  implicit none
  private

  type, extends(canonical_state_t), public :: fkt05_state_t
    real(real64) :: water = 0.0_real64
  contains
    procedure :: clone => fkt05_clone
  end type fkt05_state_t

  type, extends(kernel_parameters_t), public :: fkt05_parameters_t
    real(real64) :: rate = 0.1_real64
  end type fkt05_parameters_t

  type, extends(canonical_forcing_t), public :: fkt05_forcing_t
    real(real64) :: scale = 1.0_real64
  end type fkt05_forcing_t

  type, extends(kernel_model_t), public :: fkt05_model_t
    real(real64) :: rate = 0.1_real64
    real(real64) :: forcing_scale = 1.0_real64
    real(real64) :: warm_seed = 0.0_real64
    logical :: admitted = .true.
    logical :: inject_mass_defect = .false.
    integer :: configure_calls = 0
    integer :: advance_calls = 0
  contains
    procedure :: configure_parameters => fkt05_configure_parameters
    procedure :: execution_admitted => fkt05_execution_admitted
    procedure :: prepare_interval => fkt05_prepare_interval
    procedure :: advance => fkt05_advance
    procedure :: storage => fkt05_storage
    procedure :: temporal_error => fkt05_temporal_error
  end type fkt05_model_t

contains

  subroutine fkt05_clone(self, copy)
    class(fkt05_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fkt05_state_t :: copy)
    select type (copy)
    type is (fkt05_state_t)
      copy%water = self%water
    end select
  end subroutine fkt05_clone

  subroutine fkt05_configure_parameters(self, parameters)
    class(fkt05_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    select type (parameters)
    type is (fkt05_parameters_t)
      self%rate = parameters%rate
    class default
      error stop 'FKT05 unexpected parameter type'
    end select
    self%configure_calls = self%configure_calls + 1
  end subroutine fkt05_configure_parameters

  logical function fkt05_execution_admitted(self, parameters, numerical_config)
    class(fkt05_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    logical :: parameter_ok

    parameter_ok = .false.
    select type (parameters)
    type is (fkt05_parameters_t)
      parameter_ok = parameters%rate >= 0.0_real64
    class default
      parameter_ok = .false.
    end select
    fkt05_execution_admitted = self%admitted .and. parameter_ok .and. &
         numerical_config%max_committed_substeps > 0
  end function fkt05_execution_admitted

  subroutine fkt05_prepare_interval(self, forcing, interval, config)
    class(fkt05_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config

    select type (forcing)
    type is (fkt05_forcing_t)
      self%forcing_scale = forcing%scale
    class default
      error stop 'FKT05 unexpected forcing type'
    end select
    if (interval%t1 <= interval%t0) error stop 'FKT05 invalid interval reached model'
    if (config%max_committed_substeps <= 0) error stop 'FKT05 invalid config reached model'
  end subroutine fkt05_prepare_interval

  subroutine fkt05_advance(self, state, t0, t1, outcome)
    class(fkt05_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: dt, start_water, end_water

    outcome = trial_outcome_t()
    dt = t1 - t0
    self%advance_calls = self%advance_calls + 1
    self%warm_seed = self%warm_seed + 1.0_real64
    select type (state)
    type is (fkt05_state_t)
      start_water = state%water
      end_water = start_water * (1.0_real64 - self%rate*self%forcing_scale*dt)
      state%water = end_water
      outcome%mass_out = start_water - end_water
      if (self%inject_mass_defect) outcome%mass_out = outcome%mass_out + 1.0e-4_real64
      outcome%solver_ok = .true.
      outcome%nonlinear_iterations = 1
    class default
      error stop 'FKT05 unexpected state type'
    end select
  end subroutine fkt05_advance

  function fkt05_storage(self, state) result(value)
    class(fkt05_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value
    if (self%advance_calls < 0) error stop 'unreachable'
    select type (state)
    type is (fkt05_state_t)
      value = state%water
    class default
      error stop 'FKT05 unexpected state type'
    end select
  end function fkt05_storage

  function fkt05_temporal_error(self, full_state, half_state) result(value)
    class(fkt05_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    real(real64) :: value
    if (self%warm_seed < -huge(0.0_real64)) error stop 'unreachable'
    if (.not. same_type_as(full_state, half_state)) error stop 'FKT05 state type mismatch'
    value = 0.0_real64
  end function fkt05_temporal_error

end module mod_fkt05_test_model

program test_fkt05_reusable_checkpoint
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED, &
       CANONICAL_STATUS_TRANSACTION_FAILED
  use mod_kernel_transactions
  use mod_fkt05_test_model
  implicit none

  integer :: failures
  failures = 0

  call test_checkpoint_snapshot_isolation(failures)
  call test_same_checkpoint_replay(failures)
  call test_stale_checkpoint_rejected(failures)
  call test_cross_lineage_checkpoint_rejected(failures)
  call test_checkpoint_time_mismatch_rejected(failures)
  call test_unbound_checkpoint_first_commit(failures)
  call test_invalid_checkpoint_fails_closed(failures)
  call test_mass_failure_preserves_checkpoint_and_committed(failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'FKT05_REUSABLE_CHECKPOINT_GATE FAIL failures=', failures
    error stop 1
  end if
  write(*,'(A)') 'FKT05_REUSABLE_CHECKPOINT_GATE PASS'

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
    call expect_true(abs(actual-expected) <= tol, label, failures)
  end subroutine expect_close

  subroutine new_physical(state, water)
    class(transaction_state_t), allocatable, intent(out) :: state
    real(real64), intent(in) :: water
    allocate(fkt05_state_t :: state)
    select type (state)
    type is (fkt05_state_t)
      state%water = water
    end select
  end subroutine new_physical

  subroutine new_committed(committed, lineage_id, water, bind_time, initial_time)
    type(kernel_committed_state_t), intent(out) :: committed
    integer(int64), intent(in) :: lineage_id
    real(real64), intent(in) :: water
    logical, intent(in) :: bind_time
    real(real64), intent(in) :: initial_time
    class(transaction_state_t), allocatable :: physical
    logical :: did_initialize

    call new_physical(physical, water)
    if (bind_time) then
      call committed%initialize(lineage_id, physical, did_initialize, initial_time)
    else
      call committed%initialize(lineage_id, physical, did_initialize)
    end if
    if (.not. did_initialize) error stop 'FKT05 committed initialization failed'
  end subroutine new_committed

  subroutine standard_setup(parameters, forcing, config)
    type(fkt05_parameters_t), intent(out) :: parameters
    type(fkt05_forcing_t), intent(out) :: forcing
    type(canonical_numerical_config_t), intent(out) :: config

    parameters%rate = 0.1_real64
    forcing%scale = 1.0_real64
    config%transaction%temporal_tolerance = 1.0_real64
    config%transaction%mass_tolerance = 1.0e-12_real64
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 1
    config%max_committed_substeps = 8
    config%progress_tolerance = 0.0_real64
  end subroutine standard_setup

  function state_water(snapshot) result(value)
    class(transaction_state_t), allocatable, intent(in) :: snapshot
    real(real64) :: value
    select type (snapshot)
    type is (fkt05_state_t)
      value = snapshot%water
    class default
      error stop 'FKT05 unexpected snapshot type'
    end select
  end function state_water

  function committed_water(committed) result(value)
    type(kernel_committed_state_t), intent(in) :: committed
    class(transaction_state_t), allocatable :: snapshot
    logical :: available
    real(real64) :: value
    call committed%snapshot(snapshot, available)
    if (.not. available) error stop 'FKT05 committed snapshot unavailable'
    value = state_water(snapshot)
  end function committed_water

  function checkpoint_water(checkpoint) result(value)
    type(kernel_checkpoint_t), intent(in) :: checkpoint
    class(transaction_state_t), allocatable :: snapshot
    logical :: available
    real(real64) :: value
    call checkpoint%snapshot(snapshot, available)
    if (.not. available) error stop 'FKT05 checkpoint snapshot unavailable'
    value = state_water(snapshot)
  end function checkpoint_water

  function candidate_water(candidate) result(value)
    type(kernel_candidate_state_t), intent(in) :: candidate
    class(transaction_state_t), allocatable :: snapshot
    logical :: available
    real(real64) :: value
    call candidate%snapshot(snapshot, available)
    if (.not. available) error stop 'FKT05 candidate snapshot unavailable'
    value = state_water(snapshot)
  end function candidate_water

  subroutine set_snapshot_water(snapshot, water)
    class(transaction_state_t), allocatable, intent(inout) :: snapshot
    real(real64), intent(in) :: water
    select type (snapshot)
    type is (fkt05_state_t)
      snapshot%water = water
    class default
      error stop 'FKT05 unexpected mutable snapshot type'
    end select
  end subroutine set_snapshot_water

  subroutine test_checkpoint_snapshot_isolation(failures)
    integer, intent(inout) :: failures
    type(kernel_committed_state_t) :: committed
    type(kernel_checkpoint_t) :: checkpoint
    class(transaction_state_t), allocatable :: snapshot
    logical :: available
    real(real64) :: checkpoint_time

    call new_committed(committed, 501_int64, 1.0_real64, .true., 12.25_real64)
    call committed%capture_checkpoint(checkpoint, available)
    call expect_true(available .and. checkpoint%ready(), 'checkpoint captured', failures)
    call expect_true(checkpoint%current_lineage_id() == 501_int64, 'checkpoint lineage exact', failures)
    call expect_true(checkpoint%origin_revision() == 0_int64, 'checkpoint revision exact', failures)
    call expect_true(checkpoint%time_is_bound(), 'checkpoint time bound', failures)
    call checkpoint%current_time(checkpoint_time, available)
    call expect_true(available, 'checkpoint time available', failures)
    call expect_close(checkpoint_time, 12.25_real64, 0.0_real64, 'checkpoint time exact', failures)

    call checkpoint%snapshot(snapshot, available)
    call set_snapshot_water(snapshot, 77.0_real64)
    call expect_close(checkpoint_water(checkpoint), 1.0_real64, 0.0_real64, &
         'mutating checkpoint snapshot cannot mutate checkpoint', failures)
    call expect_close(committed_water(committed), 1.0_real64, 0.0_real64, &
         'checkpoint capture cannot mutate committed', failures)
  end subroutine test_checkpoint_snapshot_isolation

  subroutine test_same_checkpoint_replay(failures)
    integer, intent(inout) :: failures
    type(kernel_committed_state_t) :: committed
    type(kernel_checkpoint_t) :: checkpoint
    type(fkt05_parameters_t) :: parameters
    type(fkt05_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt05_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result_a, result_b, result_direct
    type(kernel_candidate_state_t) :: candidate_a, candidate_b, candidate_direct
    type(kernel_diagnostics_t) :: diag_a, diag_b, diag_direct
    logical :: available
    real(real64) :: water_a, warm_after_a

    call new_committed(committed, 502_int64, 1.0_real64, .true., 3.125_real64)
    call committed%capture_checkpoint(checkpoint, available)
    call standard_setup(parameters, forcing, config)
    call kernel%bind_model(model)

    call kernel%advance_interval(parameters, committed, forcing, config, 3.125_real64, 3.625_real64, &
         result_a, candidate_a, diag_a, checkpoint)
    water_a = candidate_water(candidate_a)
    warm_after_a = model%warm_seed
    call kernel%advance_interval(parameters, committed, forcing, config, 3.125_real64, 3.625_real64, &
         result_b, candidate_b, diag_b, checkpoint)

    call expect_true(result_a%status == CANONICAL_STATUS_COMPLETED, 'checkpoint replay A completes', failures)
    call expect_true(result_b%status == CANONICAL_STATUS_COMPLETED, 'checkpoint replay B completes', failures)
    call expect_true(model%warm_seed > warm_after_a, 'worker numerical seed evolves between replays', failures)
    call expect_close(candidate_water(candidate_b), water_a, 0.0_real64, 'checkpoint replay physical identity', failures)
    call expect_true(diag_a%attempts == diag_b%attempts, 'checkpoint replay attempts identity', failures)
    call expect_true(diag_a%retries == diag_b%retries, 'checkpoint replay retries identity', failures)
    call expect_true(diag_a%checkpoint_uses == 1 .and. diag_b%checkpoint_uses == 1, &
         'checkpoint use diagnosed', failures)
    call expect_true(committed%current_revision() == 0_int64, 'replays do not mutate revision', failures)
    call expect_close(committed_water(committed), 1.0_real64, 0.0_real64, 'replays do not mutate committed', failures)

    call kernel%advance_interval(parameters, committed, forcing, config, 3.125_real64, 3.625_real64, &
         result_direct, candidate_direct, diag_direct)
    call expect_true(result_direct%status == CANONICAL_STATUS_COMPLETED, 'direct path remains available', failures)
    call expect_close(candidate_water(candidate_direct), water_a, 0.0_real64, &
         'checkpoint and direct path physical identity', failures)
  end subroutine test_same_checkpoint_replay

  subroutine test_stale_checkpoint_rejected(failures)
    integer, intent(inout) :: failures
    type(kernel_committed_state_t) :: committed
    type(kernel_checkpoint_t) :: checkpoint
    type(fkt05_parameters_t) :: parameters
    type(fkt05_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt05_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    logical :: available, did_commit
    integer :: calls_before

    call new_committed(committed, 503_int64, 1.0_real64, .true., 4.0_real64)
    call committed%capture_checkpoint(checkpoint, available)
    call standard_setup(parameters, forcing, config)
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 4.0_real64, 4.5_real64, &
         result, candidate, diagnostics, checkpoint)
    call kernel%commit_candidate(committed, candidate, diagnostics, did_commit)
    call expect_true(did_commit, 'candidate commits before stale check', failures)
    calls_before = model%advance_calls

    call kernel%advance_interval(parameters, committed, forcing, config, 4.5_real64, 5.0_real64, &
         result, candidate, diagnostics, checkpoint)
    call expect_true(result%status == KERNEL_STATUS_CHECKPOINT_MISMATCH, 'stale checkpoint rejected', failures)
    call expect_true(diagnostics%checkpoint_revision_rejections == 1, 'stale revision diagnosed', failures)
    call expect_true(model%advance_calls == calls_before, 'stale checkpoint rejected before model', failures)
    call expect_true(checkpoint%ready(), 'stale rejection does not consume checkpoint', failures)
  end subroutine test_stale_checkpoint_rejected

  subroutine test_cross_lineage_checkpoint_rejected(failures)
    integer, intent(inout) :: failures
    type(kernel_committed_state_t) :: committed_a, committed_b
    type(kernel_checkpoint_t) :: checkpoint
    type(fkt05_parameters_t) :: parameters
    type(fkt05_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt05_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    logical :: available

    call new_committed(committed_a, 504_int64, 1.0_real64, .true., 6.0_real64)
    call new_committed(committed_b, 505_int64, 2.0_real64, .true., 6.0_real64)
    call committed_a%capture_checkpoint(checkpoint, available)
    call standard_setup(parameters, forcing, config)
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed_b, forcing, config, 6.0_real64, 6.5_real64, &
         result, candidate, diagnostics, checkpoint)
    call expect_true(result%status == KERNEL_STATUS_CHECKPOINT_MISMATCH, 'cross-lineage checkpoint rejected', failures)
    call expect_true(diagnostics%checkpoint_lineage_rejections == 1, 'checkpoint lineage diagnosed', failures)
    call expect_true(model%advance_calls == 0, 'cross-lineage rejected before model', failures)
  end subroutine test_cross_lineage_checkpoint_rejected

  subroutine test_checkpoint_time_mismatch_rejected(failures)
    integer, intent(inout) :: failures
    type(kernel_committed_state_t) :: committed_a, committed_b
    type(kernel_checkpoint_t) :: checkpoint
    type(fkt05_parameters_t) :: parameters
    type(fkt05_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt05_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    logical :: available

    call new_committed(committed_a, 506_int64, 1.0_real64, .true., 7.0_real64)
    call new_committed(committed_b, 506_int64, 1.0_real64, .true., 7.25_real64)
    call committed_a%capture_checkpoint(checkpoint, available)
    call standard_setup(parameters, forcing, config)
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed_b, forcing, config, 7.25_real64, 7.75_real64, &
         result, candidate, diagnostics, checkpoint)
    call expect_true(result%status == KERNEL_STATUS_CHECKPOINT_MISMATCH, 'checkpoint time mismatch rejected', failures)
    call expect_true(diagnostics%checkpoint_time_rejections == 1, 'checkpoint time mismatch diagnosed', failures)
    call expect_true(model%advance_calls == 0, 'checkpoint time mismatch rejected before model', failures)
  end subroutine test_checkpoint_time_mismatch_rejected

  subroutine test_unbound_checkpoint_first_commit(failures)
    integer, intent(inout) :: failures
    type(kernel_committed_state_t) :: committed
    type(kernel_checkpoint_t) :: checkpoint
    type(fkt05_parameters_t) :: parameters
    type(fkt05_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt05_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    logical :: available, did_commit
    real(real64) :: current_time

    call new_committed(committed, 507_int64, 1.0_real64, .false., 0.0_real64)
    call committed%capture_checkpoint(checkpoint, available)
    call expect_true(available .and. .not. checkpoint%time_is_bound(), 'unbound checkpoint captured', failures)
    call standard_setup(parameters, forcing, config)
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 123.456_real64, 123.506_real64, &
         result, candidate, diagnostics, checkpoint)
    call expect_true(result%status == CANONICAL_STATUS_COMPLETED, 'unbound checkpoint generic interval completes', failures)
    call kernel%commit_candidate(committed, candidate, diagnostics, did_commit)
    call expect_true(did_commit .and. committed%time_is_bound(), 'first commit binds time', failures)
    call committed%current_time(current_time, available)
    call expect_true(available, 'first commit time available', failures)
    call expect_close(current_time, 123.506_real64, 0.0_real64, 'first commit time exact', failures)
  end subroutine test_unbound_checkpoint_first_commit

  subroutine test_invalid_checkpoint_fails_closed(failures)
    integer, intent(inout) :: failures
    type(kernel_committed_state_t) :: committed
    type(kernel_checkpoint_t) :: checkpoint
    type(fkt05_parameters_t) :: parameters
    type(fkt05_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt05_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics

    call new_committed(committed, 508_int64, 1.0_real64, .true., 9.0_real64)
    call standard_setup(parameters, forcing, config)
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 9.0_real64, 9.5_real64, &
         result, candidate, diagnostics, checkpoint)
    call expect_true(result%status == KERNEL_STATUS_CHECKPOINT_MISMATCH, 'invalid checkpoint rejected', failures)
    call expect_true(diagnostics%invalid_checkpoint_rejections == 1, 'invalid checkpoint diagnosed', failures)
    call expect_true(model%configure_calls == 0 .and. model%advance_calls == 0, &
         'invalid checkpoint rejected before physical execution', failures)
  end subroutine test_invalid_checkpoint_fails_closed

  subroutine test_mass_failure_preserves_checkpoint_and_committed(failures)
    integer, intent(inout) :: failures
    type(kernel_committed_state_t) :: committed
    type(kernel_checkpoint_t) :: checkpoint
    type(fkt05_parameters_t) :: parameters
    type(fkt05_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt05_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    logical :: available

    call new_committed(committed, 509_int64, 1.0_real64, .true., 10.0_real64)
    call committed%capture_checkpoint(checkpoint, available)
    call standard_setup(parameters, forcing, config)
    model%inject_mass_defect = .true.
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 10.0_real64, 10.5_real64, &
         result, candidate, diagnostics, checkpoint)
    call expect_true(result%status == CANONICAL_STATUS_TRANSACTION_FAILED, 'mass defect rejected', failures)
    call expect_true(.not. candidate%ready(), 'mass defect creates no candidate', failures)
    call expect_true(diagnostics%mass_rejections > 0, 'mass rejection diagnosed', failures)
    call expect_true(diagnostics%checkpoint_uses == 1, 'failed trial records checkpoint use', failures)
    call expect_close(committed_water(committed), 1.0_real64, 0.0_real64, &
         'mass failure leaves committed unchanged', failures)
    call expect_close(checkpoint_water(checkpoint), 1.0_real64, 0.0_real64, &
         'mass failure leaves checkpoint unchanged', failures)
  end subroutine test_mass_failure_preserves_checkpoint_and_committed

end program test_fkt05_reusable_checkpoint
