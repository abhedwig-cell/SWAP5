module mod_fmr_serialized_reference_backend
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t, kernel_committed_state_t, &
       kernel_checkpoint_t, kernel_executor_t, kernel_result_t, kernel_candidate_state_t, kernel_diagnostics_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_trial_from_checkpoint
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t
  use mod_soil_water_solver_contract, only: top_boundary_provider_t, soil_water_solver_diagnostics_t
  implicit none
  private

  type, extends(canonical_state_t), public :: fmr31_test_physical_state_t
    real(real64) :: storage_value = 10.0_real64
  contains
    procedure :: clone => fmr31_state_clone
  end type fmr31_test_physical_state_t

  type, extends(kernel_parameters_t), public :: fmr_b110_physical_parameters_t
    logical :: admitted = .true.
    integer :: active_nodes = 0
    logical :: root_extraction_active = .false.
  end type fmr_b110_physical_parameters_t

  type, extends(canonical_forcing_t), public :: fmr_b110_physical_forcing_t
    real(real64), allocatable :: root_extraction_sink(:)
  end type fmr_b110_physical_forcing_t

  type, public :: fmr_serialized_physical_observation_t
    logical :: solver_executed = .false.
    integer :: solver_status = 0
    type(soil_water_solver_diagnostics_t) :: solver_diagnostics
  end type fmr_serialized_physical_observation_t

  type, extends(kernel_model_t) :: fmr31_test_model_t
    real(real64), allocatable :: qrot(:)
  contains
    procedure :: configure_parameters => fmr31_configure_parameters
    procedure :: execution_admitted => fmr31_execution_admitted
    procedure :: prepare_interval => fmr31_prepare_interval
    procedure :: advance => fmr31_advance
    procedure :: storage => fmr31_storage
    procedure :: storage_accounting_status => fmr31_storage_accounting_status
    procedure :: temporal_error => fmr31_temporal_error
  end type fmr31_test_model_t

  type, public :: fmr_serialized_reference_backend_t
    type(fmr31_test_model_t) :: model
    type(kernel_executor_t) :: kernel
    type(fmr_serialized_physical_observation_t) :: last_observation
  contains
    procedure :: initialize => fmr31_backend_initialize
    procedure :: run_trial => fmr31_backend_run_trial
    procedure :: observation => fmr31_backend_observation
  end type fmr_serialized_reference_backend_t

contains

  subroutine fmr31_state_clone(self, copy)
    class(fmr31_test_physical_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fmr31_test_physical_state_t :: copy)
    select type (copy)
    type is (fmr31_test_physical_state_t)
      copy%storage_value = self%storage_value
    end select
  end subroutine fmr31_state_clone

  subroutine fmr31_configure_parameters(self, parameters)
    class(fmr31_test_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    if (.not. same_type_as(parameters, parameters)) error stop 'F-MR31 unreachable parameter type'
  end subroutine fmr31_configure_parameters

  logical function fmr31_execution_admitted(self, parameters, numerical_config) result(admitted)
    class(fmr31_test_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    if (allocated(self%qrot)) continue
    select type (parameters)
    type is (fmr_b110_physical_parameters_t)
      admitted = parameters%admitted .and. parameters%active_nodes > 0 .and. &
           numerical_config%max_committed_substeps > 0
    class default
      admitted = .false.
    end select
  end function fmr31_execution_admitted

  subroutine fmr31_prepare_interval(self, forcing, interval, config)
    class(fmr31_test_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    if (allocated(self%qrot)) deallocate(self%qrot)
    if (interval%t1 <= interval%t0 .or. config%max_committed_substeps <= 0) &
         error stop 'F-MR31 test backend invalid interval'
    select type (forcing)
    type is (fmr_b110_physical_forcing_t)
      if (.not. allocated(forcing%root_extraction_sink)) error stop 'F-MR31 missing qrot'
      if (any(.not. ieee_is_finite(forcing%root_extraction_sink))) error stop 'F-MR31 nonfinite qrot'
      if (any(forcing%root_extraction_sink < 0.0_real64)) error stop 'F-MR31 negative qrot'
      self%qrot = forcing%root_extraction_sink
    class default
      error stop 'F-MR31 unexpected forcing type'
    end select
  end subroutine fmr31_prepare_interval

  subroutine fmr31_advance(self, state, t0, t1, outcome)
    class(fmr31_test_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: amount

    outcome = trial_outcome_t()
    if (.not. allocated(self%qrot)) error stop 'F-MR31 qrot not prepared'
    amount = sum(self%qrot) * (t1 - t0)
    select type (state)
    type is (fmr31_test_physical_state_t)
      state%storage_value = state%storage_value - amount
    class default
      error stop 'F-MR31 unexpected state type'
    end select
    outcome%solver_ok = .true.
    outcome%mass_out = amount
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    outcome%nonlinear_iterations = 2
  end subroutine fmr31_advance

  real(real64) function fmr31_storage(self, state) result(value)
    class(fmr31_test_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    if (allocated(self%qrot)) continue
    select type (state)
    type is (fmr31_test_physical_state_t)
      value = state%storage_value
    class default
      error stop 'F-MR31 unexpected storage state type'
    end select
  end function fmr31_storage

  subroutine fmr31_storage_accounting_status(self, state, complete, missing_mask)
    class(fmr31_test_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    if (allocated(self%qrot)) continue
    if (.not. same_type_as(state, state)) error stop 'F-MR31 unreachable accounting state'
    complete = .true.
    missing_mask = TX_MASS_MISSING_NONE
  end subroutine fmr31_storage_accounting_status

  real(real64) function fmr31_temporal_error(self, full_state, half_state) result(value)
    class(fmr31_test_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    if (allocated(self%qrot)) continue
    if (.not. same_type_as(full_state, half_state)) error stop 'F-MR31 temporal state mismatch'
    value = 0.0_real64
  end function fmr31_temporal_error

  subroutine fmr31_backend_initialize(self, top_boundary)
    class(fmr_serialized_reference_backend_t), target, intent(inout) :: self
    class(top_boundary_provider_t), target, intent(in) :: top_boundary
    if (.not. same_type_as(top_boundary, top_boundary)) error stop 'F-MR31 unreachable top boundary'
    call self%kernel%bind_model(self%model)
    self%last_observation = fmr_serialized_physical_observation_t()
  end subroutine fmr31_backend_initialize

  subroutine fmr31_backend_run_trial(self, column, template, parameters, committed, forcing, numerical_config, &
                                     t0, t1, checkpoint, result, candidate, diagnostics)
    class(fmr_serialized_reference_backend_t), target, intent(inout) :: self
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: template
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(kernel_committed_state_t), intent(in) :: committed
    type(fmr_b110_physical_forcing_t), intent(in) :: forcing
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    real(real64), intent(in) :: t0, t1
    type(kernel_checkpoint_t), intent(in) :: checkpoint
    type(kernel_result_t), intent(out) :: result
    type(kernel_candidate_state_t), intent(out) :: candidate
    type(kernel_diagnostics_t), intent(out) :: diagnostics

    if (column%column_id <= 0_int64 .or. template%template_id <= 0_int64) &
         error stop 'F-MR31 invalid routing metadata'
    call fmr_trial_from_checkpoint(self%kernel, parameters, committed, forcing, numerical_config, &
         t0, t1, checkpoint, result, candidate, diagnostics)
    self%last_observation = fmr_serialized_physical_observation_t()
    self%last_observation%solver_executed = diagnostics%transaction_calls > 0
    self%last_observation%solver_status = result%status
    self%last_observation%solver_diagnostics%route = 'fmr31-binding-test'
    self%last_observation%solver_diagnostics%nonlinear_iterations = diagnostics%nonlinear_iterations
  end subroutine fmr31_backend_run_trial

  function fmr31_backend_observation(self) result(observation)
    class(fmr_serialized_reference_backend_t), intent(in) :: self
    type(fmr_serialized_physical_observation_t) :: observation
    observation = self%last_observation
  end function fmr31_backend_observation

end module mod_fmr_serialized_reference_backend
