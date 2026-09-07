module mod_fkt03_test_model
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t
  implicit none
  private

  type, extends(canonical_state_t), public :: fkt03_state_t
    real(real64) :: water = 0.0_real64
  contains
    procedure :: clone => fkt03_clone
  end type fkt03_state_t

  type, extends(kernel_parameters_t), public :: fkt03_parameters_t
    real(real64) :: rate = 1.0_real64
  end type fkt03_parameters_t

  type, extends(canonical_forcing_t), public :: fkt03_forcing_t
    real(real64) :: scale = 1.0_real64
  end type fkt03_forcing_t

  type, extends(kernel_model_t), public :: fkt03_model_t
    real(real64) :: rate = 1.0_real64
    real(real64) :: forcing_scale = 1.0_real64
    real(real64) :: warm_seed = 0.0_real64
    logical :: admitted = .true.
    logical :: inject_mass_defect = .false.
    real(real64) :: mass_defect = 0.0_real64
  contains
    procedure :: configure_parameters => fkt03_configure_parameters
    procedure :: execution_admitted => fkt03_execution_admitted
    procedure :: prepare_interval => fkt03_prepare_interval
    procedure :: advance => fkt03_advance
    procedure :: storage => fkt03_storage
    procedure :: temporal_error => fkt03_temporal_error
  end type fkt03_model_t

contains

  subroutine fkt03_clone(self, copy)
    class(fkt03_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fkt03_state_t :: copy)
    select type (copy)
    type is (fkt03_state_t)
      copy%water = self%water
    end select
  end subroutine fkt03_clone

  subroutine fkt03_configure_parameters(self, parameters)
    class(fkt03_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    select type (parameters)
    type is (fkt03_parameters_t)
      self%rate = parameters%rate
    class default
      error stop 'FKT03 unexpected parameter type'
    end select
  end subroutine fkt03_configure_parameters

  logical function fkt03_execution_admitted(self, parameters, numerical_config)
    class(fkt03_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    logical :: parameter_ok

    parameter_ok = .false.
    select type (parameters)
    type is (fkt03_parameters_t)
      parameter_ok = parameters%rate >= 0.0_real64
    class default
      parameter_ok = .false.
    end select
    fkt03_execution_admitted = self%admitted .and. parameter_ok .and. &
         numerical_config%max_committed_substeps > 0
  end function fkt03_execution_admitted

  subroutine fkt03_prepare_interval(self, forcing, interval, config)
    class(fkt03_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config

    select type (forcing)
    type is (fkt03_forcing_t)
      self%forcing_scale = forcing%scale
    class default
      error stop 'FKT03 unexpected forcing type'
    end select
    if (interval%t1 <= interval%t0) error stop 'FKT03 invalid interval reached model'
    if (config%max_committed_substeps <= 0) error stop 'FKT03 invalid config reached model'
  end subroutine fkt03_prepare_interval

  subroutine fkt03_advance(self, state, t0, t1, outcome)
    class(fkt03_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: dt, start_water, end_water, k

    outcome = trial_outcome_t()
    dt = t1 - t0
    k = self%rate * self%forcing_scale
    self%warm_seed = self%warm_seed + 1.0_real64
    select type (state)
    type is (fkt03_state_t)
      start_water = state%water
      end_water = start_water * (1.0_real64 - k * dt)
      state%water = end_water
      outcome%mass_out = start_water - end_water
      if (self%inject_mass_defect) outcome%mass_out = outcome%mass_out + self%mass_defect
      outcome%solver_ok = .true.
      outcome%nonlinear_iterations = 1
    class default
      error stop 'FKT03 unexpected state type'
    end select
  end subroutine fkt03_advance

  function fkt03_storage(self, state) result(value)
    class(fkt03_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value
    if (self%rate < -huge(0.0_real64)) error stop 'unreachable'
    select type (state)
    type is (fkt03_state_t)
      value = state%water
    class default
      error stop 'FKT03 unexpected state type'
    end select
  end function fkt03_storage

  function fkt03_temporal_error(self, full_state, half_state) result(value)
    class(fkt03_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    real(real64) :: value, full_water, half_water
    if (self%rate < -huge(0.0_real64)) error stop 'unreachable'

    select type (full_state)
    type is (fkt03_state_t)
      full_water = full_state%water
    class default
      error stop 'FKT03 unexpected full state type'
    end select
    select type (half_state)
    type is (fkt03_state_t)
      half_water = half_state%water
    class default
      error stop 'FKT03 unexpected half state type'
    end select
    value = abs(half_water - full_water)
  end function fkt03_temporal_error

end module mod_fkt03_test_model

program test_fkt03_opaque_transaction_carriers
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED, &
       CANONICAL_STATUS_TRANSACTION_FAILED
  use mod_kernel_transactions
  use mod_fkt03_test_model
  implicit none

  integer :: failures
  failures = 0

  call test_snapshot_isolation_and_metadata(failures)
  call test_commit_and_stale_protection(failures)
  call test_cross_lineage_protection(failures)
  call test_same_committed_replay(failures)
  call test_rollback_preserves_committed(failures)
  call test_mass_rejection_preserves_committed(failures)
  call test_uninitialized_carrier_fails_closed(failures)
  call test_reference_style_admission_fails_closed(failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'FKT03_OPAQUE_TRANSACTION_GATE FAIL failures=', failures
    error stop 1
  end if
  write(*,'(A)') 'FKT03_OPAQUE_TRANSACTION_GATE PASS'

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
    allocate(fkt03_state_t :: state)
    select type (state)
    type is (fkt03_state_t)
      state%water = water
    end select
  end subroutine new_physical

  subroutine new_committed(committed, lineage_id, water)
    type(kernel_committed_state_t), intent(out) :: committed
    integer(int64), intent(in) :: lineage_id
    real(real64), intent(in) :: water
    class(transaction_state_t), allocatable :: physical
    logical :: did_initialize

    call new_physical(physical, water)
    call committed%initialize(lineage_id, physical, did_initialize)
    if (.not. did_initialize) error stop 'FKT03 committed initialization failed'
  end subroutine new_committed

  function physical_water(state) result(value)
    class(transaction_state_t), allocatable, intent(in) :: state
    real(real64) :: value
    select type (state)
    type is (fkt03_state_t)
      value = state%water
    class default
      error stop 'FKT03 unexpected snapshot type'
    end select
  end function physical_water

  function committed_water(committed) result(value)
    type(kernel_committed_state_t), intent(in) :: committed
    real(real64) :: value
    class(transaction_state_t), allocatable :: snapshot
    logical :: available

    call committed%snapshot(snapshot, available)
    if (.not. available) error stop 'FKT03 committed snapshot unavailable'
    value = physical_water(snapshot)
  end function committed_water

  function candidate_water(candidate) result(value)
    type(kernel_candidate_state_t), intent(in) :: candidate
    real(real64) :: value
    class(transaction_state_t), allocatable :: snapshot
    logical :: available

    call candidate%snapshot(snapshot, available)
    if (.not. available) error stop 'FKT03 candidate snapshot unavailable'
    value = physical_water(snapshot)
  end function candidate_water

  subroutine mutate_snapshot(snapshot, water)
    class(transaction_state_t), allocatable, intent(inout) :: snapshot
    real(real64), intent(in) :: water
    select type (snapshot)
    type is (fkt03_state_t)
      snapshot%water = water
    class default
      error stop 'FKT03 unexpected mutable snapshot type'
    end select
  end subroutine mutate_snapshot

  subroutine standard_setup(parameters, forcing, config)
    type(fkt03_parameters_t), intent(out) :: parameters
    type(fkt03_forcing_t), intent(out) :: forcing
    type(canonical_numerical_config_t), intent(out) :: config

    parameters%rate = 1.0_real64
    forcing%scale = 1.0_real64
    config%transaction%temporal_tolerance = 0.02_real64
    config%transaction%mass_tolerance = 1.0e-13_real64
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 3
    config%max_committed_substeps = 10
  end subroutine standard_setup

  subroutine test_snapshot_isolation_and_metadata(failures)
    integer, intent(inout) :: failures
    type(kernel_committed_state_t) :: committed
    type(fkt03_parameters_t) :: parameters
    type(fkt03_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt03_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    class(transaction_state_t), allocatable :: snapshot
    logical :: available
    real(real64) :: origin_t0, origin_t1, original_candidate_water

    call new_committed(committed, 101_int64, 1.0_real64)
    call standard_setup(parameters, forcing, config)
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 5.125_real64, 5.625_real64, &
         result, candidate, diagnostics)

    call expect_true(result%status == CANONICAL_STATUS_COMPLETED, 'typed advance completes', failures)
    call expect_true(candidate%ready(), 'candidate is ready', failures)
    call expect_true(candidate%current_lineage_id() == 101_int64, 'candidate lineage visible read-only', failures)
    call expect_true(candidate%origin_revision() == 0_int64, 'candidate revision visible read-only', failures)
    call candidate%origin_interval(origin_t0, origin_t1, available)
    call expect_true(available, 'candidate origin interval available', failures)
    call expect_close(origin_t0, 5.125_real64, 0.0_real64, 'origin t0 preserved', failures)
    call expect_close(origin_t1, 5.625_real64, 0.0_real64, 'origin t1 preserved', failures)

    call committed%snapshot(snapshot, available)
    call expect_true(available, 'committed snapshot available', failures)
    call mutate_snapshot(snapshot, 99.0_real64)
    call expect_close(committed_water(committed), 1.0_real64, 0.0_real64, &
         'mutating committed snapshot cannot mutate carrier', failures)

    original_candidate_water = candidate_water(candidate)
    call candidate%snapshot(snapshot, available)
    call mutate_snapshot(snapshot, 77.0_real64)
    call expect_close(candidate_water(candidate), original_candidate_water, 0.0_real64, &
         'mutating candidate snapshot cannot mutate candidate', failures)
  end subroutine test_snapshot_isolation_and_metadata

  subroutine test_commit_and_stale_protection(failures)
    integer, intent(inout) :: failures
    type(kernel_committed_state_t) :: committed
    type(fkt03_parameters_t) :: parameters
    type(fkt03_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt03_model_t), target :: model
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
    call kernel%advance_interval(parameters, committed, forcing, config, 5.0_real64, 5.5_real64, &
         result_a, candidate_a, diag_a)
    forcing%scale = 0.5_real64
    call kernel%advance_interval(parameters, committed, forcing, config, 5.0_real64, 5.5_real64, &
         result_b, candidate_b, diag_b)

    call kernel%commit_candidate(committed, candidate_b, diag_b, did_commit, commit_status)
    call expect_true(did_commit, 'sibling candidate commits', failures)
    call expect_true(committed%current_revision() == 1_int64, 'revision increments once', failures)
    accepted_water = committed_water(committed)

    call kernel%commit_candidate(committed, candidate_a, diag_a, did_commit, commit_status)
    call expect_true(.not. did_commit, 'stale candidate rejected', failures)
    call expect_true(commit_status == KERNEL_COMMIT_STATUS_STALE_REVISION, 'stale status exact', failures)
    call expect_true(candidate_a%ready(), 'stale rejection preserves candidate', failures)
    call expect_close(committed_water(committed), accepted_water, 0.0_real64, &
         'stale candidate cannot mutate committed', failures)
    call kernel%rollback_candidate(candidate_a, diag_a)
  end subroutine test_commit_and_stale_protection

  subroutine test_cross_lineage_protection(failures)
    integer, intent(inout) :: failures
    type(kernel_committed_state_t) :: committed_a, committed_b
    type(fkt03_parameters_t) :: parameters
    type(fkt03_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt03_model_t), target :: model
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
    call kernel%advance_interval(parameters, committed_a, forcing, config, 7.25_real64, 7.5_real64, &
         result, candidate, diagnostics)
    call kernel%commit_candidate(committed_b, candidate, diagnostics, did_commit, commit_status)

    call expect_true(.not. did_commit, 'cross-lineage candidate rejected', failures)
    call expect_true(commit_status == KERNEL_COMMIT_STATUS_LINEAGE_MISMATCH, 'lineage status exact', failures)
    call expect_close(committed_water(committed_b), 2.0_real64, 0.0_real64, &
         'wrong committed carrier untouched', failures)
    call expect_true(candidate%ready(), 'lineage rejection preserves candidate', failures)
    call kernel%rollback_candidate(candidate, diagnostics)
  end subroutine test_cross_lineage_protection

  subroutine test_same_committed_replay(failures)
    integer, intent(inout) :: failures
    type(kernel_committed_state_t) :: committed
    type(fkt03_parameters_t) :: parameters
    type(fkt03_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt03_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result_a, result_b
    type(kernel_candidate_state_t) :: candidate_a, candidate_b
    type(kernel_diagnostics_t) :: diag_a, diag_b

    call new_committed(committed, 301_int64, 1.0_real64)
    call standard_setup(parameters, forcing, config)
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 123.456_real64, 123.956_real64, &
         result_a, candidate_a, diag_a)
    call kernel%advance_interval(parameters, committed, forcing, config, 123.456_real64, 123.956_real64, &
         result_b, candidate_b, diag_b)

    call expect_true(result_a%completed .and. result_b%completed, 'same committed replay completes', failures)
    call expect_close(candidate_water(candidate_a), candidate_water(candidate_b), 0.0_real64, &
         'replay candidate state exact', failures)
    call expect_true(candidate_a%origin_revision() == candidate_b%origin_revision(), &
         'replay origin revision exact', failures)
    call expect_true(diag_a%attempts == diag_b%attempts .and. diag_a%retries == diag_b%retries, &
         'replay route exact', failures)
    call expect_true(committed%current_revision() == 0_int64, 'replay leaves revision unchanged', failures)
    call kernel%rollback_candidate(candidate_a, diag_a)
    call kernel%rollback_candidate(candidate_b, diag_b)
  end subroutine test_same_committed_replay

  subroutine test_rollback_preserves_committed(failures)
    integer, intent(inout) :: failures
    type(kernel_committed_state_t) :: committed
    type(fkt03_parameters_t) :: parameters
    type(fkt03_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt03_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics

    call new_committed(committed, 401_int64, 1.0_real64)
    call standard_setup(parameters, forcing, config)
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 9.125_real64, 9.375_real64, &
         result, candidate, diagnostics)
    call kernel%rollback_candidate(candidate, diagnostics)

    call expect_close(committed_water(committed), 1.0_real64, 0.0_real64, 'rollback preserves state', failures)
    call expect_true(committed%current_revision() == 0_int64, 'rollback preserves revision', failures)
    call expect_true(.not. candidate%ready(), 'rollback clears candidate', failures)
    call expect_true(diagnostics%candidate_rollbacks == 1, 'rollback diagnosed', failures)
  end subroutine test_rollback_preserves_committed

  subroutine test_mass_rejection_preserves_committed(failures)
    integer, intent(inout) :: failures
    type(kernel_committed_state_t) :: committed
    type(fkt03_parameters_t) :: parameters
    type(fkt03_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt03_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics

    call new_committed(committed, 501_int64, 1.0_real64)
    call standard_setup(parameters, forcing, config)
    model%inject_mass_defect = .true.
    model%mass_defect = 1.0e-4_real64
    config%transaction%temporal_tolerance = 1.0_real64
    config%transaction%max_retries = 1
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 8.0_real64, 8.5_real64, &
         result, candidate, diagnostics)

    call expect_true(result%status == CANONICAL_STATUS_TRANSACTION_FAILED, 'mass failure propagated', failures)
    call expect_true(diagnostics%mass_rejections > 0, 'hard mass rejection retained', failures)
    call expect_close(committed_water(committed), 1.0_real64, 0.0_real64, 'mass reject preserves state', failures)
    call expect_true(committed%current_revision() == 0_int64, 'mass reject preserves revision', failures)
    call expect_true(.not. candidate%ready(), 'mass reject creates no candidate', failures)
  end subroutine test_mass_rejection_preserves_committed

  subroutine test_uninitialized_carrier_fails_closed(failures)
    integer, intent(inout) :: failures
    type(kernel_committed_state_t) :: committed
    type(fkt03_parameters_t) :: parameters
    type(fkt03_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt03_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics

    call standard_setup(parameters, forcing, config)
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 1.0_real64, 1.25_real64, &
         result, candidate, diagnostics)

    call expect_true(result%status == KERNEL_STATUS_UNGUARDED_STATE, 'uninitialized carrier rejected', failures)
    call expect_true(diagnostics%unguarded_state_rejections == 1, 'invalid carrier diagnosed', failures)
    call expect_true(.not. candidate%ready(), 'invalid carrier creates no candidate', failures)
  end subroutine test_uninitialized_carrier_fails_closed

  subroutine test_reference_style_admission_fails_closed(failures)
    integer, intent(inout) :: failures
    type(kernel_committed_state_t) :: committed
    type(fkt03_parameters_t) :: parameters
    type(fkt03_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fkt03_model_t), target :: model
    type(kernel_executor_t) :: kernel
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics

    call new_committed(committed, 601_int64, 1.0_real64)
    call standard_setup(parameters, forcing, config)
    model%admitted = .false.
    call kernel%bind_model(model)
    call kernel%advance_interval(parameters, committed, forcing, config, 12.0_real64, 12.25_real64, &
         result, candidate, diagnostics)

    call expect_true(result%status == KERNEL_STATUS_NOT_ADMITTED, 'missing policy evidence fails closed', failures)
    call expect_close(committed_water(committed), 1.0_real64, 0.0_real64, 'admission reject preserves state', failures)
    call expect_true(.not. candidate%ready(), 'admission reject creates no candidate', failures)
    call expect_true(diagnostics%admission_rejections == 1, 'admission rejection diagnosed', failures)
  end subroutine test_reference_style_admission_fails_closed

end program test_fkt03_opaque_transaction_carriers
