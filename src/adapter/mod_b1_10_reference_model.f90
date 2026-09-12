module mod_b1_10_reference_model
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t
  use mod_soil_water_solver_contract, only: soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_soil_water_transaction_result_bridge, only: map_soil_water_interface_sensitivity_to_trial
  use mod_b1_10_transaction_binding, only: b1_10_transaction_model_t
  use mod_b1_10_process_checkpoint, only: b1_10_process_state_t, capture_b1_10_process_state, restore_b1_10_process_state
  use mod_b1_10_mass_seam, only: b1_10_qualified_profile_storage
  use mod_b1_10_trial_mass, only: b1_10_trial_mass_t
  use mod_b1_10_physical_interval_executor, only: run_b1_10_physical_interval
  use mod_b1_10_temporal_characterization, only: b1_10_temporal_characterization_t, characterize_b1_10_temporal_difference
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t
  implicit none
  private

  type, public :: b1_10_reference_capabilities_t
    logical :: physical_interval_binding = .true.
    logical :: normal_return_status = .true.
    logical :: recoverable_solver_failure_status = .false.
    logical :: temporal_characterization = .true.
    logical :: scalar_temporal_error_policy = .false.
  end type b1_10_reference_capabilities_t

  type, extends(b1_10_transaction_model_t), public :: b1_10_reference_model_t
    type(b1_10_reference_capabilities_t) :: reference_capabilities
    type(a23bu_worker_context_t), pointer :: worker => null()
  contains
    procedure :: bind_worker => b1_10_bind_reference_worker
    procedure :: advance => b1_10_advance_qualified_interval
    procedure :: storage => b1_10_storage_qualified_profile
    procedure :: temporal_error => b1_10_temporal_error_policy_not_admitted
    procedure :: reference_execution_admitted => b1_10_reference_execution_still_blocked
  end type b1_10_reference_model_t

contains

  subroutine b1_10_bind_reference_worker(self, worker)
    class(b1_10_reference_model_t), intent(inout) :: self
    type(a23bu_worker_context_t), target, intent(inout) :: worker
    self%worker => worker
    self%capabilities%generic_interval_advance = .true.
    self%capabilities%trial_mass_flux_contract = .true.
    self%capabilities%mass_storage_contract = .true.
    self%capabilities%temporal_error_contract = .false.
  end subroutine b1_10_bind_reference_worker

  subroutine b1_10_advance_qualified_interval(self, state, t0, t1, outcome)
    class(b1_10_reference_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    type(b1_10_trial_mass_t) :: trial_mass
    type(soil_water_solve_result_t) :: accepted_soil_water_result
    logical :: normal_return

    outcome = trial_outcome_t()
    if (.not. associated(self%worker)) return
    if (.not. self%capabilities%generic_interval_advance .or. &
        .not. self%capabilities%trial_mass_flux_contract) return
    if (t1 <= t0) return

    select type (physical => state)
    type is (b1_10_process_state_t)
      if (.not. allocated(physical%h)) return
      call restore_b1_10_process_state(physical)
      call run_b1_10_physical_interval(t0, t1, self%worker, trial_mass, normal_return)
      if (.not. normal_return) then
        call restore_b1_10_process_state(physical)
        call copy_worker_diagnostics(self%worker, outcome)
        return
      end if
      call capture_b1_10_process_state(physical)
    class default
      error stop 'B1.10 reference model: unexpected state passed to advance'
    end select

    outcome%solver_ok = .true.
    outcome%mass_in = trial_mass%total_in
    outcome%mass_out = trial_mass%total_out
    call copy_worker_diagnostics(self%worker, outcome)

    ! F-KT15 keeps the full typed solve result trial-local. Reconstruct only the
    ! accepted sensitivity metadata needed by the already-qualified F-KT14 bridge.
    ! Direct-HeadCalc fallback leaves the default outcome unchanged.
    if (self%worker%soil_water_trial%typed_accepted) then
      accepted_soil_water_result = soil_water_solve_result_t()
      accepted_soil_water_result%status = SW_SOLVE_CONVERGED
      if (self%worker%soil_water_trial%sensitivity_available) then
        accepted_soil_water_result%interface_sensitivity%available = .true.
        accepted_soil_water_result%interface_sensitivity%dh_bottom_dq_bottom = &
             self%worker%soil_water_trial%dh_bottom_dq_bottom
        accepted_soil_water_result%interface_sensitivity%method = &
             self%worker%soil_water_trial%sensitivity_method
      end if
      call map_soil_water_interface_sensitivity_to_trial(accepted_soil_water_result, outcome)
    end if
  end subroutine b1_10_advance_qualified_interval

  function b1_10_storage_qualified_profile(self, state) result(value)
    class(b1_10_reference_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value
    logical :: complete

    value = 0.0_real64
    if (.not. self%capabilities%mass_storage_contract) &
      error stop 'B1.10 reference model: mass storage contract disabled'
    select type (physical => state)
    type is (b1_10_process_state_t)
      call b1_10_qualified_profile_storage(physical, value, complete)
      if (.not. complete) error stop 'B1.10 reference model: profile storage accounting incomplete'
    class default
      error stop 'B1.10 reference model: unexpected state passed to storage'
    end select
  end function b1_10_storage_qualified_profile

  function b1_10_temporal_error_policy_not_admitted(self, full_state, half_state) result(value)
    class(b1_10_reference_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state
    class(transaction_state_t), intent(in) :: half_state
    real(real64) :: value
    type(b1_10_temporal_characterization_t) :: delta

    value = huge(0.0_real64)
    if (self%capabilities%temporal_error_contract .or. self%reference_capabilities%scalar_temporal_error_policy) &
      error stop 'B1.10 reference model: scalar temporal policy flag set without qualified implementation'
    select type (full_physical => full_state)
    type is (b1_10_process_state_t)
      select type (half_physical => half_state)
      type is (b1_10_process_state_t)
        call characterize_b1_10_temporal_difference(full_physical, half_physical, delta)
      class default
        error stop 'B1.10 reference model: unexpected half state passed to temporal error'
      end select
    class default
      error stop 'B1.10 reference model: unexpected full state passed to temporal error'
    end select
    if (.not. delta%compatible) error stop 'B1.10 reference model: incompatible states for temporal characterization'
    error stop 'B1.10 reference model: scalar temporal error policy not admitted'
  end function b1_10_temporal_error_policy_not_admitted

  pure logical function b1_10_reference_execution_still_blocked(self) result(admitted)
    class(b1_10_reference_model_t), intent(in) :: self
    admitted = associated(self%worker) .and. &
               self%capabilities%process_state_binding .and. &
               self%capabilities%attempt_context_binding .and. &
               self%capabilities%generic_interval_advance .and. &
               self%capabilities%trial_mass_flux_contract .and. &
               self%capabilities%mass_storage_contract .and. &
               self%capabilities%temporal_error_contract .and. &
               self%reference_capabilities%recoverable_solver_failure_status .and. &
               self%reference_capabilities%scalar_temporal_error_policy
  end function b1_10_reference_execution_still_blocked

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

end module mod_b1_10_reference_model
