module mod_b1_10_recoverable_reference_model
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t
  use mod_b1_10_reference_model, only: b1_10_reference_model_t
  use mod_b1_10_process_checkpoint, only: b1_10_process_state_t, capture_b1_10_process_state, restore_b1_10_process_state
  use mod_b1_10_trial_mass, only: b1_10_trial_mass_t
  use mod_b1_10_trial_status, only: b1_10_trial_status_t
  use mod_b1_10_recoverable_interval_executor, only: run_b1_10_recoverable_interval
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t
  implicit none
  private

  type, extends(b1_10_reference_model_t), public :: b1_10_recoverable_reference_model_t
  contains
    procedure :: bind_worker => b1_10_bind_recoverable_worker
    procedure :: advance => b1_10_advance_with_recoverable_status
  end type b1_10_recoverable_reference_model_t

contains

  subroutine b1_10_bind_recoverable_worker(self, worker)
    class(b1_10_recoverable_reference_model_t), intent(inout) :: self
    type(a23bu_worker_context_t), target, intent(inout) :: worker
    self%worker => worker
    self%capabilities%generic_interval_advance = .true.
    self%capabilities%trial_mass_flux_contract = .true.
    self%capabilities%mass_storage_contract = .true.
    self%capabilities%temporal_error_contract = .false.
    self%reference_capabilities%recoverable_solver_failure_status = .true.
    self%reference_capabilities%scalar_temporal_error_policy = .false.
  end subroutine b1_10_bind_recoverable_worker

  subroutine b1_10_advance_with_recoverable_status(self, state, t0, t1, outcome)
    class(b1_10_recoverable_reference_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    type(b1_10_trial_mass_t) :: trial_mass
    type(b1_10_trial_status_t) :: status

    outcome = trial_outcome_t()
    if (.not. associated(self%worker)) error stop 'B1.10 recoverable reference model: worker not bound'
    if (.not. self%capabilities%generic_interval_advance .or. &
        .not. self%capabilities%trial_mass_flux_contract) &
      error stop 'B1.10 recoverable reference model: physical interval capabilities disabled'

    select type (physical => state)
    type is (b1_10_process_state_t)
      if (.not. allocated(physical%h)) error stop 'B1.10 recoverable reference model: incomplete physical state'
      call restore_b1_10_process_state(physical)
      call run_b1_10_recoverable_interval(t0, t1, self%worker, trial_mass, status)

      if (status%fatal()) then
        call restore_b1_10_process_state(physical)
        error stop 'B1.10 recoverable reference model: fatal physical trial contract failure'
      end if

      if (status%retryable()) then
        call restore_b1_10_process_state(physical)
        call copy_worker_diagnostics(self%worker, outcome)
        return
      end if

      if (.not. status%succeeded()) then
        call restore_b1_10_process_state(physical)
        error stop 'B1.10 recoverable reference model: unset physical trial status'
      end if
      call capture_b1_10_process_state(physical)
    class default
      error stop 'B1.10 recoverable reference model: unexpected state passed to advance'
    end select

    outcome%solver_ok = .true.
    outcome%mass_in = trial_mass%total_in
    outcome%mass_out = trial_mass%total_out
    call copy_worker_diagnostics(self%worker, outcome)
  end subroutine b1_10_advance_with_recoverable_status

  subroutine copy_worker_diagnostics(worker, outcome)
    type(a23bu_worker_context_t), intent(in) :: worker
    type(trial_outcome_t), intent(inout) :: outcome
    outcome%nonlinear_iterations = worker%diagnostics%nonlinear_iterations
    outcome%internal_retries = worker%diagnostics%internal_retries
    outcome%headcalc_calls = worker%diagnostics%headcalc_calls
    outcome%jacobian_builds = worker%diagnostics%jacobian_builds
    outcome%linear_solves = worker%diagnostics%linear_solves
    outcome%backtracking_attempts = worker%diagnostics%backtracking_attempts
    outcome%alternative_solver_calls = worker%diagnostics%alternative_solver_calls
  end subroutine copy_worker_diagnostics

end module mod_b1_10_recoverable_reference_model
