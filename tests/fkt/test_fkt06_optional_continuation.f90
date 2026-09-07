module mod_fkt06_test_model
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t
  implicit none
  private

  type, public :: fkt06_optional_process_t
    integer :: nstep = 0
  end type fkt06_optional_process_t

  type, extends(canonical_state_t), public :: fkt06_state_t
    real(real64) :: water = 0.0_real64
    type(fkt06_optional_process_t), allocatable :: optional_process
  contains
    procedure :: clone => fkt06_clone
  end type fkt06_state_t

  type, extends(kernel_parameters_t), public :: fkt06_parameters_t
    real(real64) :: rate = 0.1_real64
  end type fkt06_parameters_t

  type, extends(canonical_forcing_t), public :: fkt06_forcing_t
    real(real64) :: scale = 1.0_real64
  end type fkt06_forcing_t

  type, extends(kernel_model_t), public :: fkt06_model_t
    real(real64) :: rate = 0.1_real64
    real(real64) :: forcing_scale = 1.0_real64
    logical :: admitted = .true.
    logical :: inject_mass_defect = .false.
    integer :: advance_calls = 0
  contains
    procedure :: configure_parameters => configure_parameters
    procedure :: execution_admitted => execution_admitted
    procedure :: prepare_interval => prepare_interval
    procedure :: advance => advance
    procedure :: storage => storage
    procedure :: temporal_error => temporal_error
  end type fkt06_model_t

contains

  subroutine fkt06_clone(self, copy)
    class(fkt06_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy

    allocate(fkt06_state_t :: copy)
    select type (copy)
    type is (fkt06_state_t)
      copy%water = self%water
      if (allocated(self%optional_process)) then
        allocate(copy%optional_process)
        copy%optional_process%nstep = self%optional_process%nstep
      end if
    end select
  end subroutine fkt06_clone

  subroutine configure_parameters(self, parameters)
    class(fkt06_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters

    select type (parameters)
    type is (fkt06_parameters_t)
      self%rate = parameters%rate
    class default
      error stop 'FKT06 unexpected parameter type'
    end select
  end subroutine configure_parameters

  logical function execution_admitted(self, parameters, numerical_config)
    class(fkt06_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    logical :: parameter_ok

    parameter_ok = .false.
    select type (parameters)
    type is (fkt06_parameters_t)
      parameter_ok = parameters%rate >= 0.0_real64
    class default
      parameter_ok = .false.
    end select
    execution_admitted = self%admitted .and. parameter_ok .and. &
         numerical_config%max_committed_substeps > 0
  end function execution_admitted

  subroutine prepare_interval(self, forcing, interval, config)
    class(fkt06_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config

    select type (forcing)
    type is (fkt06_forcing_t)
      self%forcing_scale = forcing%scale
    class default
      error stop 'FKT06 unexpected forcing type'
    end select
    if (interval%t1 <= interval%t0) error stop 'FKT06 invalid interval'
    if (config%max_committed_substeps <= 0) error stop 'FKT06 invalid config'
  end subroutine prepare_interval

  subroutine advance(self, state, t0, t1, outcome)
    class(fkt06_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: start_water, end_water, dt

    outcome = trial_outcome_t()
    dt = t1 - t0
    self%advance_calls = self%advance_calls + 1
    select type (state)
    type is (fkt06_state_t)
      start_water = state%water
      end_water = start_water - self%rate*self%forcing_scale*dt
      state%water = end_water
      if (allocated(state%optional_process)) then
        state%optional_process%nstep = state%optional_process%nstep + 1
      end if
      outcome%mass_out = start_water - end_water
      if (self%inject_mass_defect) outcome%mass_out = outcome%mass_out + 1.0e-4_real64
      outcome%solver_ok = .true.
      outcome%nonlinear_iterations = 1
    class default
      error stop 'FKT06 unexpected state type'
    end select
  end subroutine advance

  function storage(self, state) result(value)
    class(fkt06_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value

    if (self%advance_calls < 0) error stop 'unreachable'
    select type (state)
    type is (fkt06_state_t)
      value = state%water
    class default
      error stop 'FKT06 unexpected state type'
    end select
  end function storage

  function temporal_error(self, full_state, half_state) result(value)
    class(fkt06_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    real(real64) :: value

    if (self%rate < -huge(0.0_real64)) error stop 'unreachable'
    if (.not. same_type_as(full_state, half_state)) error stop 'FKT06 state mismatch'
    value = 0.0_real64
  end function temporal_error

end module mod_fkt06_test_model

program test_fkt06_optional_continuation
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t, &
       CANONICAL_STATUS_COMPLETED, CANONICAL_STATUS_TRANSACTION_FAILED
  use mod_kernel_transactions
  use mod_fkt06_test_model
  implicit none

  integer :: failures

  failures = 0
  call test_active_continuation_commit_and_replay(failures)
  call test_mass_failure_preserves_continuation(failures)
  call test_inactive_option_stays_unallocated(failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'FKT06_OPTIONAL_CONTINUATION_GATE FAIL failures=', failures
    error stop 1
  end if
  write(*,'(A)') 'FKT06_OPTIONAL_CONTINUATION_GATE PASS'

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

  subroutine setup(parameters, forcing, config)
    type(fkt06_parameters_t), intent(out) :: parameters
    type(fkt06_forcing_t), intent(out) :: forcing
    type(canonical_numerical_config_t), intent(out) :: config

    parameters%rate = 0.1_real64
    forcing%scale = 1.0_real64
    config%transaction%temporal_tolerance = 0.0_real64
    config%transaction%mass_tolerance = 1.0e-12_real64
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 0
    config%max_committed_substeps = 8
    config%progress_tolerance = 0.0_real64
  end subroutine setup

  subroutine new_committed(committed, lineage, water, active, nstep, initial_time)
    type(kernel_committed_state_t), intent(out) :: committed
    integer(int64), intent(in) :: lineage
    real(real64), intent(in) :: water, initial_time
    logical, intent(in) :: active
    integer, intent(in) :: nstep
    class(transaction_state_t), allocatable :: state
    logical :: ok

    allocate(fkt06_state_t :: state)
    select type (state)
    type is (fkt06_state_t)
      state%water = water
      if (active) then
        allocate(state%optional_process)
        state%optional_process%nstep = nstep
      end if
    end select
    call committed%initialize(lineage, state, ok, initial_time)
    if (.not. ok) error stop 'FKT06 committed initialization failed'
  end subroutine new_committed

  subroutine snapshot_process(state, active, nstep)
    class(transaction_state_t), allocatable, intent(in) :: state
    logical, intent(out) :: active
    integer, intent(out) :: nstep

    active = .false.
    nstep = -1
    select type (state)
    type is (fkt06_state_t)
      active = allocated(state%optional_process)
      if (active) nstep = state%optional_process%nstep
    class default
      error stop 'FKT06 snapshot type mismatch'
    end select
  end subroutine snapshot_process

  subroutine committed_process(committed, active, nstep)
    type(kernel_committed_state_t), intent(in) :: committed
    logical, intent(out) :: active
    integer, intent(out) :: nstep
    class(transaction_state_t), allocatable :: state
    logical :: ok

    call committed%snapshot(state, ok)
    if (.not. ok) error stop 'FKT06 committed snapshot unavailable'
    call snapshot_process(state, active, nstep)
  end subroutine committed_process

  subroutine checkpoint_process(checkpoint, active, nstep)
    type(kernel_checkpoint_t), intent(in) :: checkpoint
    logical, intent(out) :: active
    integer, intent(out) :: nstep
    class(transaction_state_t), allocatable :: state
    logical :: ok

    call checkpoint%snapshot(state, ok)
    if (.not. ok) error stop 'FKT06 checkpoint snapshot unavailable'
    call snapshot_process(state, active, nstep)
  end subroutine checkpoint_process

  subroutine candidate_process(candidate, active, nstep)
    type(kernel_candidate_state_t), intent(in) :: candidate
    logical, intent(out) :: active
    integer, intent(out) :: nstep
    class(transaction_state_t), allocatable :: state
    logical :: ok

    call candidate%snapshot(state, ok)
    if (.not. ok) error stop 'FKT06 candidate snapshot unavailable'
    call snapshot_process(state, active, nstep)
  end subroutine candidate_process

  subroutine test_active_continuation_commit_and_replay(failures)
    integer, intent(inout) :: failures
    type(kernel_committed_state_t) :: committed
    type(kernel_checkpoint_t) :: checkpoint
    type(fkt06_parameters_t) :: parameters
    type(fkt06_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt06_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    logical :: ok, active, did_commit
    integer :: nstep, calls_before

    call new_committed(committed, 601_int64, 1.0_real64, .true., 10, 2.25_real64)
    call committed%capture_checkpoint(checkpoint, ok)
    call expect_true(ok, 'active checkpoint capture', failures)
    call checkpoint_process(checkpoint, active, nstep)
    call expect_true(active .and. nstep == 10, 'checkpoint carries active continuation', failures)

    call setup(parameters, forcing, config)
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 2.25_real64, 2.75_real64, &
         result, candidate, diagnostics, checkpoint)
    call expect_true(result%status == CANONICAL_STATUS_COMPLETED, 'active trial completes', failures)
    call candidate_process(candidate, active, nstep)
    call expect_true(active .and. nstep == 12, 'accepted half-route candidate advances continuation twice', failures)
    call committed_process(committed, active, nstep)
    call expect_true(active .and. nstep == 10, 'trial does not mutate committed continuation', failures)

    call kernel%rollback_candidate(candidate, diagnostics)
    call expect_true(.not. candidate%ready(), 'rollback consumes active candidate', failures)
    call committed_process(committed, active, nstep)
    call expect_true(active .and. nstep == 10, 'rollback preserves committed continuation', failures)
    call checkpoint_process(checkpoint, active, nstep)
    call expect_true(active .and. nstep == 10, 'rollback preserves reusable checkpoint continuation', failures)

    call kernel%advance_interval(parameters, committed, forcing, config, 2.25_real64, 2.75_real64, &
         result, candidate, diagnostics, checkpoint)
    call candidate_process(candidate, active, nstep)
    call expect_true(active .and. nstep == 12, 'checkpoint replay reproduces continuation', failures)
    call kernel%commit_candidate(committed, candidate, diagnostics, did_commit)
    call expect_true(did_commit, 'active candidate commits', failures)
    call committed_process(committed, active, nstep)
    call expect_true(active .and. nstep == 12, 'commit publishes continuation', failures)
    call expect_true(committed%current_revision() == 1_int64, 'active commit increments revision once', failures)

    calls_before = model%advance_calls
    call kernel%advance_interval(parameters, committed, forcing, config, 2.75_real64, 3.0_real64, &
         result, candidate, diagnostics, checkpoint)
    call expect_true(result%status == KERNEL_STATUS_CHECKPOINT_MISMATCH, 'stale checkpoint rejected', failures)
    call expect_true(diagnostics%checkpoint_revision_rejections == 1, 'stale checkpoint diagnosed', failures)
    call expect_true(model%advance_calls == calls_before, 'stale checkpoint rejected before physical model', failures)
  end subroutine test_active_continuation_commit_and_replay

  subroutine test_mass_failure_preserves_continuation(failures)
    integer, intent(inout) :: failures
    type(kernel_committed_state_t) :: committed
    type(kernel_checkpoint_t) :: checkpoint
    type(fkt06_parameters_t) :: parameters
    type(fkt06_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt06_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    logical :: ok, active
    integer :: nstep

    call new_committed(committed, 602_int64, 1.0_real64, .true., 20, 4.0_real64)
    call committed%capture_checkpoint(checkpoint, ok)
    call setup(parameters, forcing, config)
    model%inject_mass_defect = .true.
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 4.0_real64, 4.5_real64, &
         result, candidate, diagnostics, checkpoint)

    call expect_true(result%status == CANONICAL_STATUS_TRANSACTION_FAILED, 'mass-defect trial fails transaction', failures)
    call expect_true(.not. candidate%ready(), 'mass-defect trial creates no candidate', failures)
    call expect_true(diagnostics%mass_rejections > 0, 'mass rejection diagnosed', failures)
    call committed_process(committed, active, nstep)
    call expect_true(active .and. nstep == 20, 'mass rejection preserves committed continuation', failures)
    call checkpoint_process(checkpoint, active, nstep)
    call expect_true(active .and. nstep == 20, 'mass rejection preserves checkpoint continuation', failures)
    call expect_true(committed%current_revision() == 0_int64, 'mass rejection leaves revision unchanged', failures)
  end subroutine test_mass_failure_preserves_continuation

  subroutine test_inactive_option_stays_unallocated(failures)
    integer, intent(inout) :: failures
    type(kernel_committed_state_t) :: committed
    type(kernel_checkpoint_t) :: checkpoint
    type(fkt06_parameters_t) :: parameters
    type(fkt06_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt06_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    logical :: ok, active, did_commit
    integer :: nstep

    call new_committed(committed, 603_int64, 1.0_real64, .false., 0, 6.125_real64)
    call committed_process(committed, active, nstep)
    call expect_true(.not. active, 'inactive committed state has no optional allocation', failures)
    call committed%capture_checkpoint(checkpoint, ok)
    call checkpoint_process(checkpoint, active, nstep)
    call expect_true(.not. active, 'inactive checkpoint has no optional allocation', failures)

    call setup(parameters, forcing, config)
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 6.125_real64, 6.625_real64, &
         result, candidate, diagnostics, checkpoint)
    call expect_true(result%status == CANONICAL_STATUS_COMPLETED, 'inactive trial completes', failures)
    call candidate_process(candidate, active, nstep)
    call expect_true(.not. active, 'inactive trial does not allocate optional continuation', failures)
    call kernel%commit_candidate(committed, candidate, diagnostics, did_commit)
    call expect_true(did_commit, 'inactive candidate commits', failures)
    call committed_process(committed, active, nstep)
    call expect_true(.not. active, 'inactive commit remains allocation-free', failures)
  end subroutine test_inactive_option_stays_unallocated

end program test_fkt06_optional_continuation
