module mod_b1_10_transaction_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_model_t, transaction_state_t, transaction_attempt_context_t, trial_outcome_t
  use mod_b1_10_process_checkpoint, only: b1_10_process_state_t, capture_b1_10_process_state, restore_b1_10_process_state
  use mod_b1_10_legacy_trial_capsule, only: b1_10_legacy_trial_capsule_t, &
       capture_b1_10_legacy_trial_capsule, restore_b1_10_legacy_trial_capsule
  implicit none
  private

  type, public :: b1_10_transaction_binding_capabilities_t
    logical :: process_state_binding = .true.
    logical :: attempt_context_binding = .true.
    logical :: whole_day_restore_rerun_qualified = .true.
    logical :: generic_interval_advance = .false.
    logical :: trial_mass_flux_contract = .false.
    logical :: mass_storage_contract = .false.
    logical :: temporal_error_contract = .false.
  end type b1_10_transaction_binding_capabilities_t

  type, extends(transaction_attempt_context_t), public :: b1_10_attempt_context_t
    type(b1_10_legacy_trial_capsule_t) :: legacy
  end type b1_10_attempt_context_t

  type, extends(transaction_model_t), public :: b1_10_transaction_model_t
    type(b1_10_transaction_binding_capabilities_t) :: capabilities
  contains
    procedure :: capture_committed_state => b1_10_capture_committed_state
    procedure :: restore_committed_state => b1_10_restore_committed_state
    procedure :: capture_attempt_context => b1_10_capture_attempt_context
    procedure :: restore_attempt_context => b1_10_restore_attempt_context
    procedure :: advance => b1_10_advance_not_admitted
    procedure :: storage => b1_10_storage_not_admitted
    procedure :: temporal_error => b1_10_temporal_error_not_admitted
    procedure :: reference_execution_admitted => b1_10_reference_execution_admitted
  end type b1_10_transaction_model_t

contains

  subroutine b1_10_capture_committed_state(self, state)
    class(b1_10_transaction_model_t), intent(inout) :: self
    class(transaction_state_t), allocatable, intent(out) :: state

    if (.not. self%capabilities%process_state_binding) then
      error stop 'B1.10 transaction binding: process-state binding disabled'
    end if
    allocate(b1_10_process_state_t :: state)
    select type (target => state)
    type is (b1_10_process_state_t)
      call capture_b1_10_process_state(target)
    class default
      error stop 'B1.10 transaction binding: process-state allocation failure'
    end select
  end subroutine b1_10_capture_committed_state

  subroutine b1_10_restore_committed_state(self, state)
    class(b1_10_transaction_model_t), intent(inout) :: self
    class(transaction_state_t), intent(in) :: state

    if (.not. self%capabilities%process_state_binding) then
      error stop 'B1.10 transaction binding: process-state binding disabled'
    end if
    select type (source => state)
    type is (b1_10_process_state_t)
      call restore_b1_10_process_state(source)
    class default
      error stop 'B1.10 transaction binding: unexpected committed state type'
    end select
  end subroutine b1_10_restore_committed_state

  subroutine b1_10_capture_attempt_context(self, context)
    class(b1_10_transaction_model_t), intent(inout) :: self
    class(transaction_attempt_context_t), allocatable, intent(out) :: context

    if (.not. self%capabilities%attempt_context_binding) then
      error stop 'B1.10 transaction binding: attempt-context binding disabled'
    end if
    allocate(b1_10_attempt_context_t :: context)
    select type (target => context)
    type is (b1_10_attempt_context_t)
      call capture_b1_10_legacy_trial_capsule(target%legacy)
    class default
      error stop 'B1.10 transaction binding: attempt-context allocation failure'
    end select
  end subroutine b1_10_capture_attempt_context

  subroutine b1_10_restore_attempt_context(self, context)
    class(b1_10_transaction_model_t), intent(inout) :: self
    class(transaction_attempt_context_t), intent(in) :: context

    if (.not. self%capabilities%attempt_context_binding) then
      error stop 'B1.10 transaction binding: attempt-context binding disabled'
    end if
    select type (source => context)
    type is (b1_10_attempt_context_t)
      call restore_b1_10_legacy_trial_capsule(source%legacy)
    class default
      error stop 'B1.10 transaction binding: unexpected attempt context type'
    end select
  end subroutine b1_10_restore_attempt_context

  subroutine b1_10_advance_not_admitted(self, state, t0, t1, outcome)
    class(b1_10_transaction_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome

    outcome = trial_outcome_t()
    select type (state)
    type is (b1_10_process_state_t)
      if (.not. allocated(state%h)) return
    class default
      error stop 'B1.10 transaction binding: unexpected state passed to advance'
    end select
    if (t1 <= t0) return
    if (self%capabilities%generic_interval_advance) then
      error stop 'B1.10 transaction binding: generic advance flag set without implementation'
    end if
    ! Fail closed. The current legacy calendar seam cannot represent the full and
    ! half intervals required by execute_reference_interval without changing
    ! time semantics. No physical trial is executed here until that seam is qualified.
    outcome%solver_ok = .false.
  end subroutine b1_10_advance_not_admitted

  function b1_10_storage_not_admitted(self, state) result(value)
    class(b1_10_transaction_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value

    value = 0.0_real64
    select type (state)
    type is (b1_10_process_state_t)
      if (.not. allocated(state%h)) error stop 'B1.10 transaction binding: incomplete state for storage'
    class default
      error stop 'B1.10 transaction binding: unexpected state passed to storage'
    end select
    if (self%capabilities%mass_storage_contract) then
      error stop 'B1.10 transaction binding: mass storage flag set without implementation'
    end if
    error stop 'B1.10 transaction binding: mass storage contract not admitted'
  end function b1_10_storage_not_admitted

  function b1_10_temporal_error_not_admitted(self, full_state, half_state) result(value)
    class(b1_10_transaction_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state
    class(transaction_state_t), intent(in) :: half_state
    real(real64) :: value

    value = huge(0.0_real64)
    select type (full_state)
    type is (b1_10_process_state_t)
      if (.not. allocated(full_state%h)) error stop 'B1.10 transaction binding: incomplete full state'
    class default
      error stop 'B1.10 transaction binding: unexpected full state type'
    end select
    select type (half_state)
    type is (b1_10_process_state_t)
      if (.not. allocated(half_state%h)) error stop 'B1.10 transaction binding: incomplete half state'
    class default
      error stop 'B1.10 transaction binding: unexpected half state type'
    end select
    if (self%capabilities%temporal_error_contract) then
      error stop 'B1.10 transaction binding: temporal error flag set without implementation'
    end if
    error stop 'B1.10 transaction binding: temporal error contract not admitted'
  end function b1_10_temporal_error_not_admitted

  pure logical function b1_10_reference_execution_admitted(self) result(admitted)
    class(b1_10_transaction_model_t), intent(in) :: self
    admitted = self%capabilities%process_state_binding .and. &
               self%capabilities%attempt_context_binding .and. &
               self%capabilities%generic_interval_advance .and. &
               self%capabilities%trial_mass_flux_contract .and. &
               self%capabilities%mass_storage_contract .and. &
               self%capabilities%temporal_error_contract
  end function b1_10_reference_execution_admitted

end module mod_b1_10_transaction_binding
