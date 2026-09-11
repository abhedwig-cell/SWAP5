module mod_b1_10_process_checkpoint
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t
  implicit none
  type, extends(transaction_state_t), public :: b1_10_process_state_t
    real(real64), allocatable :: h(:)
  contains
    procedure :: clone => clone_process_state
  end type
contains
  subroutine clone_process_state(self,copy)
    class(b1_10_process_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(b1_10_process_state_t :: copy)
    select type (p => copy)
    type is (b1_10_process_state_t)
      p%h = self%h
    end select
  end subroutine
  subroutine capture_b1_10_process_state(state)
    type(b1_10_process_state_t), intent(inout) :: state
    if (.not. allocated(state%h)) allocate(state%h(1), source=0.0_real64)
  end subroutine
  subroutine restore_b1_10_process_state(state)
    type(b1_10_process_state_t), intent(in) :: state
    if (.not. allocated(state%h)) error stop 'stub incomplete process state'
  end subroutine
end module mod_b1_10_process_checkpoint

module mod_b1_10_transaction_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_model_t, transaction_state_t, trial_outcome_t
  implicit none
  type, public :: b1_10_transaction_binding_capabilities_t
    logical :: process_state_binding = .true.
    logical :: attempt_context_binding = .true.
    logical :: whole_day_restore_rerun_qualified = .true.
    logical :: generic_interval_advance = .false.
    logical :: trial_mass_flux_contract = .false.
    logical :: mass_storage_contract = .false.
    logical :: temporal_error_contract = .false.
  end type
  type, extends(transaction_model_t), public :: b1_10_transaction_model_t
    type(b1_10_transaction_binding_capabilities_t) :: capabilities
  contains
    procedure :: advance => stub_advance
    procedure :: storage => stub_storage
    procedure :: temporal_error => stub_temporal_error
    procedure :: reference_execution_admitted => stub_reference_execution_admitted
  end type
contains
  subroutine stub_advance(self,state,t0,t1,outcome)
    class(b1_10_transaction_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0,t1
    type(trial_outcome_t), intent(out) :: outcome
    if (.not. same_type_as(self,self) .or. .not. same_type_as(state,state) .or. t1 < t0) error stop 'stub advance'
    outcome = trial_outcome_t()
  end subroutine
  function stub_storage(self,state) result(value)
    class(b1_10_transaction_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value
    if (.not. same_type_as(self,self) .or. .not. same_type_as(state,state)) error stop 'stub storage'
    value = 0.0_real64
  end function
  function stub_temporal_error(self,full_state,half_state) result(value)
    class(b1_10_transaction_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state,half_state
    real(real64) :: value
    if (.not. same_type_as(self,self) .or. .not. same_type_as(full_state,full_state) .or. &
        .not. same_type_as(half_state,half_state)) error stop 'stub temporal'
    value = 0.0_real64
  end function
  pure logical function stub_reference_execution_admitted(self) result(admitted)
    class(b1_10_transaction_model_t), intent(in) :: self
    admitted = self%capabilities%generic_interval_advance
  end function
end module mod_b1_10_transaction_binding

module mod_b1_10_mass_seam
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b1_10_process_checkpoint, only: b1_10_process_state_t
  implicit none
contains
  subroutine b1_10_qualified_profile_storage(state,value,complete)
    type(b1_10_process_state_t), intent(in) :: state
    real(real64), intent(out) :: value
    logical, intent(out) :: complete
    value = 0.0_real64
    complete = allocated(state%h)
  end subroutine
end module mod_b1_10_mass_seam

module mod_b1_10_trial_mass
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  type, public :: b1_10_trial_mass_t
    real(real64) :: total_in = 0.0_real64
    real(real64) :: total_out = 0.0_real64
  end type
end module mod_b1_10_trial_mass

module mod_b1_10_physical_interval_executor
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_soil_water_trial_result_t
  use mod_b1_10_trial_mass, only: b1_10_trial_mass_t
  implicit none
  integer, public :: fkt15_stub_mode = 1
contains
  subroutine run_b1_10_physical_interval(t0,t1,worker,trial_mass,normal_return)
    real(real64), intent(in) :: t0,t1
    type(a23bu_worker_context_t), intent(inout) :: worker
    type(b1_10_trial_mass_t), intent(out) :: trial_mass
    logical, intent(out) :: normal_return
    if (t1 <= t0) error stop 'stub invalid interval'
    trial_mass = b1_10_trial_mass_t()
    worker%soil_water_trial = a23bu_soil_water_trial_result_t()
    select case (fkt15_stub_mode)
    case (1)
      normal_return = .true.
      worker%soil_water_trial%typed_attempted = .true.
      worker%soil_water_trial%typed_accepted = .true.
      worker%soil_water_trial%sensitivity_available = .true.
      worker%soil_water_trial%dh_bottom_dq_bottom = 12.5_real64
      worker%soil_water_trial%sensitivity_method = 'same-tridag-factor'
      worker%soil_water_trial%route = 'stub-accepted'
    case (2)
      normal_return = .false.
      worker%soil_water_trial%typed_attempted = .true.
      worker%soil_water_trial%typed_accepted = .false.
      ! Deliberately malicious stale-looking metadata: the reference model must
      ! return before mapping it because the physical interval was rejected.
      worker%soil_water_trial%sensitivity_available = .true.
      worker%soil_water_trial%dh_bottom_dq_bottom = -999.0_real64
      worker%soil_water_trial%sensitivity_method = 'stale-must-not-map'
    case (3)
      normal_return = .true.
      worker%soil_water_trial%typed_attempted = .false.
      worker%soil_water_trial%typed_accepted = .false.
    case default
      error stop 'stub invalid mode'
    end select
  end subroutine
end module mod_b1_10_physical_interval_executor

module mod_b1_10_temporal_characterization
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b1_10_process_checkpoint, only: b1_10_process_state_t
  implicit none
  type, public :: b1_10_temporal_characterization_t
    logical :: compatible = .true.
  end type
contains
  subroutine characterize_b1_10_temporal_difference(full_state,half_state,delta)
    type(b1_10_process_state_t), intent(in) :: full_state,half_state
    type(b1_10_temporal_characterization_t), intent(out) :: delta
    delta%compatible = allocated(full_state%h) .and. allocated(half_state%h)
  end subroutine
end module mod_b1_10_temporal_characterization
