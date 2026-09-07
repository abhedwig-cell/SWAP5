module mod_fmr01_checkpoint_probe_model
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t
  implicit none
  private

  type, extends(canonical_state_t), public :: probe_state_t
    real(real64) :: water = 0.0_real64
  contains
    procedure :: clone => probe_clone
  end type probe_state_t

  type, extends(kernel_parameters_t), public :: probe_parameters_t
    real(real64) :: rate = 0.1_real64
  end type probe_parameters_t

  type, extends(canonical_forcing_t), public :: probe_forcing_t
    real(real64) :: scale = 1.0_real64
  end type probe_forcing_t

  type, extends(kernel_model_t), public :: probe_model_t
    real(real64) :: rate = 0.1_real64
    real(real64) :: scale = 1.0_real64
    integer :: advance_calls = 0
  contains
    procedure :: configure_parameters => configure_parameters
    procedure :: execution_admitted => execution_admitted
    procedure :: prepare_interval => prepare_interval
    procedure :: advance => advance
    procedure :: storage => storage
    procedure :: temporal_error => temporal_error
  end type probe_model_t

contains

  subroutine probe_clone(self, copy)
    class(probe_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(probe_state_t :: copy)
    select type (copy)
    type is (probe_state_t)
      copy%water = self%water
    end select
  end subroutine probe_clone

  subroutine configure_parameters(self, parameters)
    class(probe_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    select type (parameters)
    type is (probe_parameters_t)
      self%rate = parameters%rate
    class default
      error stop 'F-MR checkpoint probe parameter mismatch'
    end select
  end subroutine configure_parameters

  logical function execution_admitted(self, parameters, numerical_config)
    class(probe_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    logical :: ok

    ok = .false.
    select type (parameters)
    type is (probe_parameters_t)
      ok = parameters%rate >= 0.0_real64
    end select
    execution_admitted = ok .and. numerical_config%max_committed_substeps > 0 .and. self%rate >= 0.0_real64
  end function execution_admitted

  subroutine prepare_interval(self, forcing, interval, config)
    class(probe_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config

    select type (forcing)
    type is (probe_forcing_t)
      self%scale = forcing%scale
    class default
      error stop 'F-MR checkpoint probe forcing mismatch'
    end select
    if (interval%t1 <= interval%t0) error stop 'F-MR checkpoint probe invalid interval'
    if (config%max_committed_substeps <= 0) error stop 'F-MR checkpoint probe invalid config'
  end subroutine prepare_interval

  subroutine advance(self, state, t0, t1, outcome)
    class(probe_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: before, after

    outcome = trial_outcome_t()
    self%advance_calls = self%advance_calls + 1
    select type (state)
    type is (probe_state_t)
      before = state%water
      after = before - self%rate * self%scale * (t1 - t0)
      state%water = after
      outcome%mass_out = before - after
      outcome%solver_ok = .true.
    class default
      error stop 'F-MR checkpoint probe state mismatch'
    end select
  end subroutine advance

  real(real64) function storage(self, state) result(value)
    class(probe_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    if (self%advance_calls < 0) error stop 'unreachable F-MR checkpoint probe'
    select type (state)
    type is (probe_state_t)
      value = state%water
    class default
      error stop 'F-MR checkpoint probe storage mismatch'
    end select
  end function storage

  real(real64) function temporal_error(self, full_state, half_state) result(value)
    class(probe_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    if (self%rate < 0.0_real64) error stop 'unreachable F-MR checkpoint probe rate'
    if (.not. same_type_as(full_state, half_state)) error stop 'F-MR checkpoint probe temporal mismatch'
    value = 0.0_real64
  end function temporal_error

end module mod_fmr01_checkpoint_probe_model

program test_fmr01_checkpoint_integration
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED
  use mod_kernel_transactions
  use mod_fmr_checkpoint_orchestrator
  use mod_fmr01_checkpoint_probe_model
  implicit none

  type(kernel_committed_state_t) :: committed, other, same_lineage_other_time
  type(kernel_checkpoint_t) :: checkpoint
  type(probe_parameters_t) :: parameters
  type(probe_forcing_t) :: forcing
  type(canonical_numerical_config_t) :: config
  type(probe_model_t), target :: model
  type(kernel_executor_t) :: kernel
  type(kernel_result_t) :: result_a, result_b, result_bad
  type(kernel_candidate_state_t) :: candidate_a, candidate_b, candidate_bad
  type(kernel_diagnostics_t) :: diag_a, diag_b, diag_bad
  integer :: failures, calls_before
  logical :: ok, did_commit
  real(real64) :: candidate_a_water

  failures = 0
  call new_committed(committed, 701_int64, 5.0_real64, 3.125_real64)
  call new_committed(other, 702_int64, 9.0_real64, 3.125_real64)
  call new_committed(same_lineage_other_time, 701_int64, 5.0_real64, 4.125_real64)
  call setup(parameters, forcing, config)
  call kernel%bind_model(model)

  call fmr_capture_checkpoint(committed, checkpoint, ok)
  call expect_true(ok, 'F-MR captures real F-KT checkpoint', failures)
  call expect_true(checkpoint%current_lineage_id() == 701_int64, 'checkpoint lineage bound', failures)
  call expect_true(checkpoint%origin_revision() == 0_int64, 'checkpoint revision bound', failures)

  call fmr_trial_from_checkpoint(kernel, parameters, committed, forcing, config, 3.125_real64, &
       3.625_real64, checkpoint, result_a, candidate_a, diag_a)
  candidate_a_water = candidate_water(candidate_a)
  call expect_true(result_a%status == CANONICAL_STATUS_COMPLETED, 'checkpoint trial completes', failures)
  call expect_bits(committed_water(committed), 5.0_real64, 'trial leaves committed unchanged', failures)
  call expect_true(diag_a%checkpoint_uses == 1, 'checkpoint use diagnosed', failures)

  call fmr_trial_from_checkpoint(kernel, parameters, committed, forcing, config, 3.125_real64, &
       3.625_real64, checkpoint, result_b, candidate_b, diag_b)
  call expect_true(result_b%status == CANONICAL_STATUS_COMPLETED, 'same checkpoint replay completes', failures)
  call expect_bits(candidate_water(candidate_b), candidate_a_water, 'multiple trials same physical result', failures)
  call expect_bits(committed_water(committed), 5.0_real64, 'replay still leaves committed unchanged', failures)

  calls_before = model%advance_calls
  call fmr_trial_from_checkpoint(kernel, parameters, other, forcing, config, 3.125_real64, &
       3.625_real64, checkpoint, result_bad, candidate_bad, diag_bad)
  call expect_true(result_bad%status == KERNEL_STATUS_CHECKPOINT_MISMATCH, &
       'wrong column checkpoint fails closed', failures)
  call expect_true(model%advance_calls == calls_before, 'wrong column rejected before model', failures)
  call expect_true(diag_bad%checkpoint_lineage_rejections == 1, 'wrong lineage diagnosed', failures)

  call fmr_trial_from_checkpoint(kernel, parameters, same_lineage_other_time, forcing, config, &
       4.125_real64, 4.625_real64, checkpoint, result_bad, candidate_bad, diag_bad)
  call expect_true(result_bad%status == KERNEL_STATUS_CHECKPOINT_MISMATCH, &
       'wrong committed time checkpoint fails closed', failures)
  call expect_true(diag_bad%checkpoint_time_rejections == 1, 'wrong time diagnosed', failures)

  call fmr_commit_candidate(kernel, committed, candidate_a, diag_a, did_commit)
  call expect_true(did_commit, 'candidate committed through F-KT', failures)
  call expect_true(committed%current_revision() == 1_int64, 'commit advances F-KT revision', failures)
  calls_before = model%advance_calls
  call fmr_trial_from_checkpoint(kernel, parameters, committed, forcing, config, 3.625_real64, &
       4.125_real64, checkpoint, result_bad, candidate_bad, diag_bad)
  call expect_true(result_bad%status == KERNEL_STATUS_CHECKPOINT_MISMATCH, &
       'stale checkpoint fails closed after commit', failures)
  call expect_true(model%advance_calls == calls_before, 'stale checkpoint rejected before model', failures)
  call expect_true(diag_bad%checkpoint_revision_rejections == 1, 'stale revision diagnosed', failures)

  call fmr_discard_candidate(kernel, candidate_b, diag_b)
  call expect_true(committed%current_revision() == 1_int64, 'discard cannot alter committed revision', failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'FMR01_CHECKPOINT_GATE FAIL failures=', failures
    error stop 1
  end if
  write(*,'(A)') 'FMR01_CHECKPOINT_GATE PASS'

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

  subroutine expect_bits(actual, expected, label, failures)
    real(real64), intent(in) :: actual, expected
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    call expect_true(transfer(actual, 0_int64) == transfer(expected, 0_int64), label, failures)
  end subroutine expect_bits

  subroutine setup(parameters, forcing, config)
    type(probe_parameters_t), intent(out) :: parameters
    type(probe_forcing_t), intent(out) :: forcing
    type(canonical_numerical_config_t), intent(out) :: config
    parameters%rate = 0.1_real64
    forcing%scale = 1.0_real64
    config%transaction%temporal_tolerance = 1.0_real64
    config%transaction%mass_tolerance = 1.0e-12_real64
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 1
    config%max_committed_substeps = 8
    config%progress_tolerance = 0.0_real64
  end subroutine setup

  subroutine new_committed(committed_state, lineage, water, initial_time)
    type(kernel_committed_state_t), intent(out) :: committed_state
    integer(int64), intent(in) :: lineage
    real(real64), intent(in) :: water, initial_time
    class(transaction_state_t), allocatable :: state
    logical :: initialized

    allocate(probe_state_t :: state)
    select type (state)
    type is (probe_state_t)
      state%water = water
    end select
    call committed_state%initialize(lineage, state, initialized, initial_time)
    if (.not. initialized) error stop 'F-MR checkpoint probe init failed'
  end subroutine new_committed

  real(real64) function committed_water(committed_state) result(value)
    type(kernel_committed_state_t), intent(in) :: committed_state
    class(transaction_state_t), allocatable :: state
    logical :: available
    call committed_state%snapshot(state, available)
    if (.not. available) error stop 'F-MR checkpoint probe committed unavailable'
    select type (state)
    type is (probe_state_t)
      value = state%water
    class default
      error stop 'F-MR checkpoint probe committed type mismatch'
    end select
  end function committed_water

  real(real64) function candidate_water(candidate) result(value)
    type(kernel_candidate_state_t), intent(in) :: candidate
    class(transaction_state_t), allocatable :: state
    logical :: available
    call candidate%snapshot(state, available)
    if (.not. available) error stop 'F-MR checkpoint probe candidate unavailable'
    select type (state)
    type is (probe_state_t)
      value = state%water
    class default
      error stop 'F-MR checkpoint probe candidate type mismatch'
    end select
  end function candidate_water

end program test_fmr01_checkpoint_integration
