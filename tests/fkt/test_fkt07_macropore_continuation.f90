module mod_fkt07_test_model
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t
  use mod_canonical_contracts, only: canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t
  use mod_b1_10_process_checkpoint, only: b1_10_process_state_t, &
       bind_b1_10_macropore_continuation, read_b1_10_macropore_continuation
  implicit none
  private

  type, extends(kernel_parameters_t), public :: fkt07_parameters_t
    real(real64) :: rate = 0.1_real64
  end type fkt07_parameters_t

  type, extends(canonical_forcing_t), public :: fkt07_forcing_t
    real(real64) :: scale = 1.0_real64
  end type fkt07_forcing_t

  type, extends(kernel_model_t), public :: fkt07_model_t
    real(real64) :: rate = 0.1_real64
    real(real64) :: forcing_scale = 1.0_real64
    logical :: inject_mass_defect = .false.
    integer :: advance_calls = 0
  contains
    procedure :: configure_parameters => configure_parameters
    procedure :: execution_admitted => execution_admitted
    procedure :: prepare_interval => prepare_interval
    procedure :: advance => advance
    procedure :: storage => storage
    procedure :: temporal_error => temporal_error
  end type fkt07_model_t

contains

  subroutine configure_parameters(self, parameters)
    class(fkt07_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters

    select type (parameters)
    type is (fkt07_parameters_t)
      self%rate = parameters%rate
    class default
      error stop 'FKT07 unexpected parameter type'
    end select
  end subroutine configure_parameters

  logical function execution_admitted(self, parameters, numerical_config)
    class(fkt07_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    logical :: parameter_ok

    parameter_ok = .false.
    select type (parameters)
    type is (fkt07_parameters_t)
      parameter_ok = parameters%rate >= 0.0_real64
    class default
      parameter_ok = .false.
    end select
    execution_admitted = parameter_ok .and. numerical_config%max_committed_substeps > 0
  end function execution_admitted

  subroutine prepare_interval(self, forcing, interval, config)
    class(fkt07_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config

    select type (forcing)
    type is (fkt07_forcing_t)
      self%forcing_scale = forcing%scale
    class default
      error stop 'FKT07 unexpected forcing type'
    end select
    if (interval%t1 <= interval%t0) error stop 'FKT07 invalid interval'
    if (config%max_committed_substeps <= 0) error stop 'FKT07 invalid config'
  end subroutine prepare_interval

  subroutine advance(self, state, t0, t1, outcome)
    class(fkt07_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: start_water, end_water, dt
    integer :: nstep
    logical :: available, accepted

    outcome = trial_outcome_t()
    dt = t1 - t0
    self%advance_calls = self%advance_calls + 1
    select type (state)
    type is (b1_10_process_state_t)
      start_water = state%volact
      end_water = start_water - self%rate*self%forcing_scale*dt
      state%volact = end_water
      call read_b1_10_macropore_continuation(state, nstep, available)
      if (available) then
        call bind_b1_10_macropore_continuation(state, nstep + 1, accepted)
        if (.not. accepted) error stop 'FKT07 continuation update rejected'
      end if
      outcome%mass_out = start_water - end_water
      if (self%inject_mass_defect) outcome%mass_out = outcome%mass_out + 1.0e-4_real64
      outcome%solver_ok = .true.
      outcome%nonlinear_iterations = 1
    class default
      error stop 'FKT07 unexpected state type'
    end select
  end subroutine advance

  function storage(self, state) result(value)
    class(fkt07_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value

    if (self%advance_calls < 0) error stop 'unreachable'
    select type (state)
    type is (b1_10_process_state_t)
      value = state%volact
    class default
      error stop 'FKT07 unexpected state type'
    end select
  end function storage

  function temporal_error(self, full_state, half_state) result(value)
    class(fkt07_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    real(real64) :: value

    if (self%rate < -huge(0.0_real64)) error stop 'unreachable'
    if (.not. same_type_as(full_state, half_state)) error stop 'FKT07 state mismatch'
    value = 0.0_real64
  end function temporal_error

end module mod_fkt07_test_model

program test_fkt07_macropore_continuation
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t, &
       CANONICAL_STATUS_COMPLETED, CANONICAL_STATUS_TRANSACTION_FAILED
  use mod_kernel_transactions
  use mod_b1_10_process_checkpoint, only: b1_10_process_state_t, &
       capture_b1_10_process_state, bind_b1_10_macropore_continuation, &
       read_b1_10_macropore_continuation, clear_b1_10_macropore_continuation, &
       b1_10_macropore_continuation_complete
  use mod_fkt07_test_model
  implicit none

  integer :: failures

  failures = 0
  call test_explicit_adapter_seam(failures)
  call test_active_transaction_lifecycle(failures)
  call test_mass_failure_isolation(failures)
  call test_inactive_route_unallocated(failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'FKT07_MACROPORE_CONTINUATION_GATE FAIL failures=', failures
    error stop 1
  end if
  write(*,'(A)') 'FKT07_MACROPORE_CONTINUATION_GATE PASS'

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
    type(fkt07_parameters_t), intent(out) :: parameters
    type(fkt07_forcing_t), intent(out) :: forcing
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
    logical :: ok, accepted

    allocate(b1_10_process_state_t :: state)
    select type (state)
    type is (b1_10_process_state_t)
      state%volact = water
      if (active) then
        call bind_b1_10_macropore_continuation(state, nstep, accepted)
        if (.not. accepted) error stop 'FKT07 initial continuation bind failed'
      end if
    end select
    call committed%initialize(lineage, state, ok, initial_time)
    if (.not. ok) error stop 'FKT07 committed initialization failed'
  end subroutine new_committed

  subroutine snapshot_process(state, active, nstep)
    class(transaction_state_t), allocatable, intent(in) :: state
    logical, intent(out) :: active
    integer, intent(out) :: nstep

    select type (state)
    type is (b1_10_process_state_t)
      call read_b1_10_macropore_continuation(state, nstep, active)
    class default
      error stop 'FKT07 snapshot type mismatch'
    end select
  end subroutine snapshot_process

  subroutine committed_process(committed, active, nstep)
    type(kernel_committed_state_t), intent(in) :: committed
    logical, intent(out) :: active
    integer, intent(out) :: nstep
    class(transaction_state_t), allocatable :: state
    logical :: ok

    call committed%snapshot(state, ok)
    if (.not. ok) error stop 'FKT07 committed snapshot unavailable'
    call snapshot_process(state, active, nstep)
  end subroutine committed_process

  subroutine checkpoint_process(checkpoint, active, nstep)
    type(kernel_checkpoint_t), intent(in) :: checkpoint
    logical, intent(out) :: active
    integer, intent(out) :: nstep
    class(transaction_state_t), allocatable :: state
    logical :: ok

    call checkpoint%snapshot(state, ok)
    if (.not. ok) error stop 'FKT07 checkpoint snapshot unavailable'
    call snapshot_process(state, active, nstep)
  end subroutine checkpoint_process

  subroutine candidate_process(candidate, active, nstep)
    type(kernel_candidate_state_t), intent(in) :: candidate
    logical, intent(out) :: active
    integer, intent(out) :: nstep
    class(transaction_state_t), allocatable :: state
    logical :: ok

    call candidate%snapshot(state, ok)
    if (.not. ok) error stop 'FKT07 candidate snapshot unavailable'
    call snapshot_process(state, active, nstep)
  end subroutine candidate_process

  subroutine test_explicit_adapter_seam(failures)
    integer, intent(inout) :: failures
    type(b1_10_process_state_t) :: state
    integer :: nstep
    logical :: accepted, available

    call read_b1_10_macropore_continuation(state, nstep, available)
    call expect_true(.not. available, 'fresh state has no macropore continuation', failures)
    call expect_true(b1_10_macropore_continuation_complete(state, .false.), &
         'inactive fresh state is complete', failures)
    call expect_true(.not. b1_10_macropore_continuation_complete(state, .true.), &
         'active fresh state is incomplete', failures)

    call bind_b1_10_macropore_continuation(state, -1, accepted)
    call expect_true(.not. accepted .and. .not. allocated(state%macropore), &
         'negative nstep rejected without allocation', failures)
    call bind_b1_10_macropore_continuation(state, 4, accepted)
    call expect_true(accepted, 'valid nstep accepted', failures)
    call read_b1_10_macropore_continuation(state, nstep, available)
    call expect_true(available .and. nstep == 4, 'bound nstep readable exactly', failures)
    call expect_true(b1_10_macropore_continuation_complete(state, .true.), &
         'active bound state is complete', failures)
    call expect_true(.not. b1_10_macropore_continuation_complete(state, .false.), &
         'inactive route rejects allocated optional state', failures)

    call clear_b1_10_macropore_continuation(state)
    call capture_b1_10_process_state(state)
    call expect_true(.not. allocated(state%macropore), &
         'legacy process capture does not infer reporting-history nstep', failures)
  end subroutine test_explicit_adapter_seam

  subroutine test_active_transaction_lifecycle(failures)
    integer, intent(inout) :: failures
    type(kernel_committed_state_t) :: committed
    type(kernel_checkpoint_t) :: checkpoint
    type(fkt07_parameters_t) :: parameters
    type(fkt07_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt07_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    logical :: ok, active, did_commit
    integer :: nstep, calls_before

    call new_committed(committed, 701_int64, 1.0_real64, .true., 4, 6.25_real64)
    call committed%capture_checkpoint(checkpoint, ok)
    call expect_true(ok, 'active checkpoint capture', failures)
    call checkpoint_process(checkpoint, active, nstep)
    call expect_true(active .and. nstep == 4, 'checkpoint carries exact nstep', failures)

    call setup(parameters, forcing, config)
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, &
         6.25_real64, 6.75_real64, result, candidate, diagnostics, checkpoint)
    call expect_true(result%status == CANONICAL_STATUS_COMPLETED, 'active trial completes', failures)
    call candidate_process(candidate, active, nstep)
    call expect_true(active .and. nstep == 6, 'candidate carries accepted half-route nstep', failures)
    call committed_process(committed, active, nstep)
    call expect_true(active .and. nstep == 4, 'trial leaves committed nstep unchanged', failures)

    call kernel%rollback_candidate(candidate, diagnostics)
    call committed_process(committed, active, nstep)
    call expect_true(active .and. nstep == 4, 'candidate rollback preserves committed nstep', failures)
    call checkpoint_process(checkpoint, active, nstep)
    call expect_true(active .and. nstep == 4, 'rollback preserves checkpoint nstep', failures)

    call kernel%advance_interval(parameters, committed, forcing, config, &
         6.25_real64, 6.75_real64, result, candidate, diagnostics, checkpoint)
    call candidate_process(candidate, active, nstep)
    call expect_true(active .and. nstep == 6, 'checkpoint replay reproduces nstep', failures)
    call kernel%commit_candidate(committed, candidate, diagnostics, did_commit)
    call expect_true(did_commit, 'active candidate commits', failures)
    call committed_process(committed, active, nstep)
    call expect_true(active .and. nstep == 6, 'commit publishes nstep', failures)
    call expect_true(committed%current_revision() == 1_int64, 'commit increments revision once', failures)

    calls_before = model%advance_calls
    call kernel%advance_interval(parameters, committed, forcing, config, &
         6.75_real64, 7.0_real64, result, candidate, diagnostics, checkpoint)
    call expect_true(result%status == KERNEL_STATUS_CHECKPOINT_MISMATCH, &
         'stale checkpoint rejected', failures)
    call expect_true(model%advance_calls == calls_before, &
         'stale checkpoint rejected before model', failures)
  end subroutine test_active_transaction_lifecycle

  subroutine test_mass_failure_isolation(failures)
    integer, intent(inout) :: failures
    type(kernel_committed_state_t) :: committed
    type(kernel_checkpoint_t) :: checkpoint
    type(fkt07_parameters_t) :: parameters
    type(fkt07_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt07_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    logical :: ok, active
    integer :: nstep

    call new_committed(committed, 702_int64, 1.0_real64, .true., 7, 8.0_real64)
    call committed%capture_checkpoint(checkpoint, ok)
    call setup(parameters, forcing, config)
    model%inject_mass_defect = .true.
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, &
         8.0_real64, 8.5_real64, result, candidate, diagnostics, checkpoint)

    call expect_true(result%status == CANONICAL_STATUS_TRANSACTION_FAILED, &
         'mass defect fails transaction', failures)
    call expect_true(.not. candidate%ready(), 'mass defect creates no candidate', failures)
    call committed_process(committed, active, nstep)
    call expect_true(active .and. nstep == 7, 'mass failure preserves committed nstep', failures)
    call checkpoint_process(checkpoint, active, nstep)
    call expect_true(active .and. nstep == 7, 'mass failure preserves checkpoint nstep', failures)
    call expect_true(committed%current_revision() == 0_int64, &
         'mass failure leaves revision unchanged', failures)
  end subroutine test_mass_failure_isolation

  subroutine test_inactive_route_unallocated(failures)
    integer, intent(inout) :: failures
    type(kernel_committed_state_t) :: committed
    type(kernel_checkpoint_t) :: checkpoint
    type(fkt07_parameters_t) :: parameters
    type(fkt07_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt07_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    logical :: ok, active, did_commit
    integer :: nstep

    call new_committed(committed, 703_int64, 1.0_real64, .false., 0, 9.0_real64)
    call committed%capture_checkpoint(checkpoint, ok)
    call checkpoint_process(checkpoint, active, nstep)
    call expect_true(.not. active, 'inactive checkpoint stays unallocated', failures)
    call setup(parameters, forcing, config)
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, &
         9.0_real64, 9.5_real64, result, candidate, diagnostics, checkpoint)
    call expect_true(result%status == CANONICAL_STATUS_COMPLETED, 'inactive trial completes', failures)
    call candidate_process(candidate, active, nstep)
    call expect_true(.not. active, 'inactive candidate stays unallocated', failures)
    call kernel%commit_candidate(committed, candidate, diagnostics, did_commit)
    call expect_true(did_commit, 'inactive candidate commits', failures)
    call committed_process(committed, active, nstep)
    call expect_true(.not. active, 'inactive committed state stays unallocated', failures)
  end subroutine test_inactive_route_unallocated

end program test_fkt07_macropore_continuation
