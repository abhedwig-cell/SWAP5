module mod_fkt02_test_model
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t
  implicit none
  private

  type, extends(canonical_state_t), public :: fkt02_state_t
    real(real64) :: water = 0.0_real64
  contains
    procedure :: clone => fkt02_clone
  end type fkt02_state_t

  type, extends(kernel_parameters_t), public :: fkt02_parameters_t
    real(real64) :: rate = 1.0_real64
  end type fkt02_parameters_t

  type, extends(canonical_forcing_t), public :: fkt02_forcing_t
    real(real64) :: scale = 1.0_real64
  end type fkt02_forcing_t

  type, extends(kernel_model_t), public :: fkt02_model_t
    real(real64) :: rate = 1.0_real64
    real(real64) :: forcing_scale = 1.0_real64
    real(real64) :: warm_seed = 0.0_real64
    logical :: admitted = .true.
    logical :: inject_mass_defect = .false.
    real(real64) :: mass_defect = 0.0_real64
  contains
    procedure :: configure_parameters => fkt02_configure_parameters
    procedure :: execution_admitted => fkt02_execution_admitted
    procedure :: prepare_interval => fkt02_prepare_interval
    procedure :: advance => fkt02_advance
    procedure :: storage => fkt02_storage
    procedure :: temporal_error => fkt02_temporal_error
  end type fkt02_model_t

contains

  subroutine fkt02_clone(self, copy)
    class(fkt02_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fkt02_state_t :: copy)
    select type (copy)
    type is (fkt02_state_t)
      copy%water = self%water
    end select
  end subroutine fkt02_clone

  subroutine fkt02_configure_parameters(self, parameters)
    class(fkt02_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    select type (parameters)
    type is (fkt02_parameters_t)
      self%rate = parameters%rate
    class default
      error stop 'FKT02 unexpected parameter type'
    end select
  end subroutine fkt02_configure_parameters

  logical function fkt02_execution_admitted(self, parameters, numerical_config)
    class(fkt02_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    logical :: parameter_ok

    parameter_ok = .false.
    select type (parameters)
    type is (fkt02_parameters_t)
      parameter_ok = parameters%rate >= 0.0_real64
    class default
      parameter_ok = .false.
    end select
    fkt02_execution_admitted = self%admitted .and. parameter_ok .and. &
         numerical_config%max_committed_substeps > 0
  end function fkt02_execution_admitted

  subroutine fkt02_prepare_interval(self, forcing, interval, config)
    class(fkt02_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config

    select type (forcing)
    type is (fkt02_forcing_t)
      self%forcing_scale = forcing%scale
    class default
      error stop 'FKT02 unexpected forcing type'
    end select
    if (interval%t1 <= interval%t0) error stop 'FKT02 invalid interval reached model'
    if (config%max_committed_substeps <= 0) error stop 'FKT02 invalid config reached model'
  end subroutine fkt02_prepare_interval

  subroutine fkt02_advance(self, state, t0, t1, outcome)
    class(fkt02_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: dt, start_water, end_water, k

    outcome = trial_outcome_t()
    dt = t1 - t0
    k = self%rate * self%forcing_scale
    self%warm_seed = self%warm_seed + 1.0_real64
    select type (state)
    type is (fkt02_state_t)
      start_water = state%water
      end_water = start_water * (1.0_real64 - k * dt)
      state%water = end_water
      outcome%mass_out = start_water - end_water
      if (self%inject_mass_defect) outcome%mass_out = outcome%mass_out + self%mass_defect
      outcome%solver_ok = .true.
      outcome%nonlinear_iterations = 1
    class default
      error stop 'FKT02 unexpected physical state type'
    end select
  end subroutine fkt02_advance

  function fkt02_storage(self, state) result(value)
    class(fkt02_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value
    if (self%rate < -huge(0.0_real64)) error stop 'unreachable'
    select type (state)
    type is (fkt02_state_t)
      value = state%water
    class default
      error stop 'FKT02 unexpected state in storage'
    end select
  end function fkt02_storage

  function fkt02_temporal_error(self, full_state, half_state) result(value)
    class(fkt02_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    real(real64) :: value, full_water, half_water
    if (self%rate < -huge(0.0_real64)) error stop 'unreachable'
    select type (full_state)
    type is (fkt02_state_t)
      full_water = full_state%water
    class default
      error stop 'FKT02 unexpected full state'
    end select
    select type (half_state)
    type is (fkt02_state_t)
      half_water = half_state%water
    class default
      error stop 'FKT02 unexpected half state'
    end select
    value = abs(half_water - full_water)
  end function fkt02_temporal_error

end module mod_fkt02_test_model

program test_fkt02_candidate_lineage
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED, &
       CANONICAL_STATUS_TRANSACTION_FAILED
  use mod_kernel_transactions
  use mod_fkt02_test_model
  implicit none

  integer :: failures
  failures = 0
  call test_guarded_commit(failures)
  call test_stale_candidate_rejected(failures)
  call test_cross_lineage_rejected(failures)
  call test_raw_state_fails_closed(failures)
  call test_same_committed_replay(failures)
  call test_mass_rejection_preserves_committed(failures)
  call test_rollback_preserves_revision(failures)
  call test_reference_style_admission_still_fails_closed(failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'FKT02_CANDIDATE_LINEAGE_GATE FAIL failures=', failures
    error stop 1
  end if
  write(*,'(A)') 'FKT02_CANDIDATE_LINEAGE_GATE PASS'

contains

  subroutine new_raw_state(state, water)
    class(transaction_state_t), allocatable, intent(out) :: state
    real(real64), intent(in) :: water
    allocate(fkt02_state_t :: state)
    select type (state)
    type is (fkt02_state_t)
      state%water = water
    end select
  end subroutine new_raw_state

  subroutine new_committed(committed, lineage, water)
    class(transaction_state_t), allocatable, intent(out) :: committed
    integer(int64), intent(in) :: lineage
    real(real64), intent(in) :: water
    class(transaction_state_t), allocatable :: raw
    logical :: ok

    call new_raw_state(raw, water)
    allocate(kernel_committed_state_t :: committed)
    select type (typed => committed)
    type is (kernel_committed_state_t)
      call typed%initialize(lineage, raw, ok)
    class default
      ok = .false.
    end select
    if (.not. ok) error stop 'FKT02 committed-state initialization failed'
  end subroutine new_committed

  function committed_water(committed) result(value)
    class(transaction_state_t), allocatable, intent(in) :: committed
    real(real64) :: value
    class(transaction_state_t), allocatable :: snapshot
    logical :: ok

    value = huge(0.0_real64)
    select type (typed => committed)
    type is (kernel_committed_state_t)
      call typed%snapshot(snapshot, ok)
    class default
      ok = .false.
    end select
    if (.not. ok) error stop 'FKT02 committed snapshot unavailable'
    select type (snapshot)
    type is (fkt02_state_t)
      value = snapshot%water
    class default
      error stop 'FKT02 snapshot has wrong physical type'
    end select
  end function committed_water

  function committed_revision(committed) result(value)
    class(transaction_state_t), allocatable, intent(in) :: committed
    integer(int64) :: value
    select type (typed => committed)
    type is (kernel_committed_state_t)
      value = typed%current_revision()
    class default
      value = -1_int64
    end select
  end function committed_revision

  function candidate_water(candidate) result(value)
    type(kernel_candidate_state_t), intent(in) :: candidate
    real(real64) :: value
    value = huge(0.0_real64)
    if (.not. allocated(candidate%state)) return
    select type (state => candidate%state)
    type is (fkt02_state_t)
      value = state%water
    class default
      error stop 'FKT02 candidate has wrong physical type'
    end select
  end function candidate_water

  subroutine standard_setup(parameters, forcing, config)
    type(fkt02_parameters_t), intent(out) :: parameters
    type(fkt02_forcing_t), intent(out) :: forcing
    type(canonical_numerical_config_t), intent(out) :: config
    parameters%rate = 1.0_real64
    forcing%scale = 1.0_real64
    config%transaction%temporal_tolerance = 0.02_real64
    config%transaction%mass_tolerance = 1.0e-13_real64
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 3
    config%max_committed_substeps = 10
  end subroutine standard_setup

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

  subroutine test_guarded_commit(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: committed
    type(fkt02_parameters_t) :: parameters
    type(fkt02_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt02_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    logical :: did_commit
    integer :: commit_status

    call new_committed(committed, 101_int64, 1.0_real64)
    call standard_setup(parameters, forcing, config)
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 5.0_real64, 5.5_real64, &
         result, candidate, diagnostics)

    call expect_true(result%status == CANONICAL_STATUS_COMPLETED, 'guarded interval completed', failures)
    call expect_close(committed_water(committed), 1.0_real64, 0.0_real64, 'advance keeps committed physical state', failures)
    call expect_true(candidate%origin_lineage_id == 101_int64, 'candidate records lineage', failures)
    call expect_true(candidate%origin_revision == 0_int64, 'candidate records origin revision', failures)
    call expect_close(candidate_water(candidate), 0.586181640625_real64, 1.0e-14_real64, 'candidate endpoint', failures)

    call kernel%commit_candidate(committed, candidate, diagnostics, did_commit, commit_status)
    call expect_true(did_commit .and. commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'guarded commit accepted', failures)
    call expect_true(committed_revision(committed) == 1_int64, 'commit increments revision exactly once', failures)
    call expect_close(committed_water(committed), 0.586181640625_real64, 1.0e-14_real64, 'commit publishes physical candidate', failures)
    call expect_true(.not. candidate%valid .and. .not. allocated(candidate%state), 'successful commit consumes candidate', failures)
  end subroutine test_guarded_commit

  subroutine test_stale_candidate_rejected(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: committed
    type(fkt02_parameters_t) :: parameters
    type(fkt02_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt02_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result_a, result_b
    type(kernel_candidate_state_t) :: candidate_a, candidate_b
    type(kernel_diagnostics_t) :: diag_a, diag_b
    logical :: did_commit
    integer :: commit_status
    real(real64) :: accepted_water

    call new_committed(committed, 111_int64, 1.0_real64)
    call standard_setup(parameters, forcing, config)
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 5.0_real64, 5.5_real64, result_a, candidate_a, diag_a)
    forcing%scale = 0.5_real64
    call kernel%advance_interval(parameters, committed, forcing, config, 5.0_real64, 5.5_real64, result_b, candidate_b, diag_b)

    call kernel%commit_candidate(committed, candidate_b, diag_b, did_commit, commit_status)
    call expect_true(did_commit, 'newer sibling candidate commits', failures)
    accepted_water = committed_water(committed)
    call kernel%commit_candidate(committed, candidate_a, diag_a, did_commit, commit_status)
    call expect_true(.not. did_commit, 'stale sibling candidate rejected', failures)
    call expect_true(commit_status == KERNEL_COMMIT_STATUS_STALE_REVISION, 'stale revision status exact', failures)
    call expect_true(diag_a%stale_revision_rejections == 1, 'stale rejection diagnosed', failures)
    call expect_close(committed_water(committed), accepted_water, 0.0_real64, 'stale commit cannot mutate committed', failures)
    call expect_true(candidate_a%valid, 'rejected stale candidate not silently consumed', failures)
    call kernel%rollback_candidate(candidate_a, diag_a)
  end subroutine test_stale_candidate_rejected

  subroutine test_cross_lineage_rejected(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: committed_a, committed_b
    type(fkt02_parameters_t) :: parameters
    type(fkt02_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt02_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    logical :: did_commit
    integer :: commit_status

    call new_committed(committed_a, 201_int64, 1.0_real64)
    call new_committed(committed_b, 202_int64, 2.0_real64)
    call standard_setup(parameters, forcing, config)
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed_a, forcing, config, 7.25_real64, 7.5_real64, result, candidate, diagnostics)
    call kernel%commit_candidate(committed_b, candidate, diagnostics, did_commit, commit_status)

    call expect_true(.not. did_commit, 'cross-lineage commit rejected', failures)
    call expect_true(commit_status == KERNEL_COMMIT_STATUS_LINEAGE_MISMATCH, 'lineage mismatch status exact', failures)
    call expect_true(diagnostics%lineage_mismatch_rejections == 1, 'lineage mismatch diagnosed', failures)
    call expect_close(committed_water(committed_b), 2.0_real64, 0.0_real64, 'wrong column remains untouched', failures)
    call expect_true(candidate%valid, 'wrong-target rejection preserves candidate', failures)
    call kernel%rollback_candidate(candidate, diagnostics)
  end subroutine test_cross_lineage_rejected

  subroutine test_raw_state_fails_closed(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: raw
    type(fkt02_parameters_t) :: parameters
    type(fkt02_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt02_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics

    call new_raw_state(raw, 1.0_real64)
    call standard_setup(parameters, forcing, config)
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, raw, forcing, config, 5.0_real64, 5.25_real64, result, candidate, diagnostics)
    call expect_true(result%status == KERNEL_STATUS_UNGUARDED_STATE, 'raw committed state fails closed', failures)
    call expect_true(diagnostics%unguarded_state_rejections == 1, 'unguarded state diagnosed', failures)
    call expect_true(.not. candidate%valid, 'unguarded state creates no candidate', failures)
  end subroutine test_raw_state_fails_closed

  subroutine test_same_committed_replay(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: committed
    type(fkt02_parameters_t) :: parameters
    type(fkt02_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt02_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result_a, result_b
    type(kernel_candidate_state_t) :: candidate_a, candidate_b
    type(kernel_diagnostics_t) :: diag_a, diag_b

    call new_committed(committed, 301_int64, 1.0_real64)
    call standard_setup(parameters, forcing, config)
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 123.456_real64, 123.956_real64, result_a, candidate_a, diag_a)
    call kernel%advance_interval(parameters, committed, forcing, config, 123.456_real64, 123.956_real64, result_b, candidate_b, diag_b)

    call expect_true(result_a%completed .and. result_b%completed, 'same-state replay completes', failures)
    call expect_true(candidate_a%origin_revision == candidate_b%origin_revision, 'replay origin revision identical', failures)
    call expect_close(candidate_water(candidate_a), candidate_water(candidate_b), 0.0_real64, 'replay endpoint exact', failures)
    call expect_true(diag_a%attempts == diag_b%attempts .and. diag_a%retries == diag_b%retries, 'replay route exact', failures)
    call expect_true(committed_revision(committed) == 0_int64, 'replay does not advance committed revision', failures)
    call kernel%rollback_candidate(candidate_a, diag_a)
    call kernel%rollback_candidate(candidate_b, diag_b)
  end subroutine test_same_committed_replay

  subroutine test_mass_rejection_preserves_committed(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: committed
    type(fkt02_parameters_t) :: parameters
    type(fkt02_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt02_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics

    call new_committed(committed, 401_int64, 1.0_real64)
    call standard_setup(parameters, forcing, config)
    model%inject_mass_defect = .true.
    model%mass_defect = 1.0e-4_real64
    config%transaction%temporal_tolerance = 1.0_real64
    config%transaction%max_retries = 1
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 8.0_real64, 8.5_real64, result, candidate, diagnostics)

    call expect_true(result%status == CANONICAL_STATUS_TRANSACTION_FAILED, 'mass failure propagated', failures)
    call expect_true(diagnostics%mass_rejections > 0, 'hard mass rejection retained', failures)
    call expect_close(committed_water(committed), 1.0_real64, 0.0_real64, 'mass rejection preserves committed', failures)
    call expect_true(committed_revision(committed) == 0_int64, 'mass rejection preserves revision', failures)
    call expect_true(.not. candidate%valid, 'mass rejection creates no candidate', failures)
  end subroutine test_mass_rejection_preserves_committed

  subroutine test_rollback_preserves_revision(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: committed
    type(fkt02_parameters_t) :: parameters
    type(fkt02_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt02_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics

    call new_committed(committed, 501_int64, 1.0_real64)
    call standard_setup(parameters, forcing, config)
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 9.125_real64, 9.375_real64, result, candidate, diagnostics)
    call kernel%rollback_candidate(candidate, diagnostics)

    call expect_true(committed_revision(committed) == 0_int64, 'rollback leaves committed revision unchanged', failures)
    call expect_close(committed_water(committed), 1.0_real64, 0.0_real64, 'rollback leaves committed physical state unchanged', failures)
    call expect_true(diagnostics%candidate_rollbacks == 1, 'candidate rollback diagnosed', failures)
  end subroutine test_rollback_preserves_revision

  subroutine test_reference_style_admission_still_fails_closed(failures)
    integer, intent(inout) :: failures
    class(transaction_state_t), allocatable :: committed
    type(fkt02_parameters_t) :: parameters
    type(fkt02_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt02_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics

    call new_committed(committed, 601_int64, 1.0_real64)
    call standard_setup(parameters, forcing, config)
    model%admitted = .false.
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 10.0_real64, 10.25_real64, result, candidate, diagnostics)
    call expect_true(result%status == KERNEL_STATUS_NOT_ADMITTED, 'unqualified execution remains fail-closed', failures)
    call expect_true(diagnostics%admission_rejections == 1, 'admission rejection retained', failures)
    call expect_true(committed_revision(committed) == 0_int64, 'admission rejection preserves revision', failures)
    call expect_close(committed_water(committed), 1.0_real64, 0.0_real64, 'admission rejection preserves physical state', failures)
  end subroutine test_reference_style_admission_still_fails_closed

end program test_fkt02_candidate_lineage
