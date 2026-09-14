module mod_fmr_serialized_reference_backend
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t, kernel_committed_state_t, &
       kernel_checkpoint_t, kernel_executor_t, kernel_result_t, kernel_candidate_state_t, kernel_diagnostics_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_trial_from_checkpoint
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t
  use mod_soil_water_solver_contract, only: top_boundary_provider_t, soil_water_solver_diagnostics_t
  use mod_fmr_bottom_thermal_carrier, only: fmr_bottom_thermal_candidate_t
  implicit none
  private

  type, extends(canonical_state_t), public :: eb_r03_probe_state_t
    real(real64) :: storage_value = 1.0_real64
  contains
    procedure :: clone => probe_state_clone
  end type eb_r03_probe_state_t

  type, extends(kernel_parameters_t), public :: fmr_b110_physical_parameters_t
    logical :: admitted = .true.
    real(real64) :: transfer_rate = 0.1_real64
    integer :: active_nodes = 0
    logical :: root_extraction_active = .false.
  end type fmr_b110_physical_parameters_t

  type, extends(canonical_forcing_t), public :: fmr_b110_physical_forcing_t
    real(real64) :: scale = 1.0_real64
    real(real64), allocatable :: root_extraction_sink(:)
  end type fmr_b110_physical_forcing_t

  type, public :: fmr_serialized_physical_observation_t
    logical :: solver_executed = .false.
    integer :: solver_status = 0
    type(soil_water_solver_diagnostics_t) :: solver_diagnostics
  end type fmr_serialized_physical_observation_t

  type, extends(kernel_model_t) :: eb_r03_probe_model_t
    real(real64) :: transfer_rate = 0.1_real64
    real(real64) :: scale = 1.0_real64
  contains
    procedure :: configure_parameters => probe_configure_parameters
    procedure :: execution_admitted => probe_execution_admitted
    procedure :: prepare_interval => probe_prepare_interval
    procedure :: advance => probe_advance
    procedure :: storage => probe_storage
    procedure :: storage_accounting_status => probe_storage_accounting_status
    procedure :: temporal_error => probe_temporal_error
  end type eb_r03_probe_model_t

  type, public :: fmr_serialized_reference_backend_t
    type(eb_r03_probe_model_t) :: model
    type(kernel_executor_t) :: kernel
    type(fmr_serialized_physical_observation_t) :: last_observation
    logical :: thermal_enabled = .false.
  contains
    procedure :: initialize => probe_backend_initialize
    procedure :: run_trial => probe_backend_run_trial
    procedure :: observation => probe_backend_observation
    procedure :: set_bottom_thermal_carrier_enabled => probe_set_bottom_thermal_enabled
    procedure :: bottom_thermal_snapshot => probe_bottom_thermal_snapshot
  end type fmr_serialized_reference_backend_t

contains

  subroutine probe_state_clone(self, copy)
    class(eb_r03_probe_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(eb_r03_probe_state_t :: copy)
    select type (copy)
    type is (eb_r03_probe_state_t)
      copy%storage_value = self%storage_value
    end select
  end subroutine probe_state_clone

  subroutine probe_configure_parameters(self, parameters)
    class(eb_r03_probe_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    select type (parameters)
    type is (fmr_b110_physical_parameters_t)
      self%transfer_rate = parameters%transfer_rate
    class default
      error stop 'EB-R03 probe unexpected parameter type'
    end select
  end subroutine probe_configure_parameters

  logical function probe_execution_admitted(self, parameters, numerical_config)
    class(eb_r03_probe_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    if (self%scale < 0.0_real64) error stop 'EB-R03 invalid probe scale'
    select type (parameters)
    type is (fmr_b110_physical_parameters_t)
      probe_execution_admitted = parameters%admitted .and. parameters%transfer_rate >= 0.0_real64 .and. &
           numerical_config%max_committed_substeps > 0
    class default
      probe_execution_admitted = .false.
    end select
  end function probe_execution_admitted

  subroutine probe_prepare_interval(self, forcing, interval, config)
    class(eb_r03_probe_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    select type (forcing)
    type is (fmr_b110_physical_forcing_t)
      self%scale = forcing%scale
    class default
      error stop 'EB-R03 probe unexpected forcing type'
    end select
    if (interval%t1 <= interval%t0 .or. config%max_committed_substeps <= 0) &
         error stop 'EB-R03 probe invalid interval'
  end subroutine probe_prepare_interval

  subroutine probe_advance(self, state, t0, t1, outcome)
    class(eb_r03_probe_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: transfer

    outcome = trial_outcome_t()
    transfer = self%transfer_rate * self%scale * (t1 - t0)
    select type (state)
    type is (eb_r03_probe_state_t)
      state%storage_value = state%storage_value + transfer
    class default
      error stop 'EB-R03 probe unexpected state type'
    end select
    outcome%solver_ok = .true.
    outcome%mass_in = transfer
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    outcome%nonlinear_iterations = 1
  end subroutine probe_advance

  real(real64) function probe_storage(self, state) result(value)
    class(eb_r03_probe_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    if (self%scale < 0.0_real64) error stop 'EB-R03 invalid probe model state'
    select type (state)
    type is (eb_r03_probe_state_t)
      value = state%storage_value
    class default
      error stop 'EB-R03 probe unexpected storage state type'
    end select
  end function probe_storage

  subroutine probe_storage_accounting_status(self, state, complete, missing_mask)
    class(eb_r03_probe_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    if (self%scale < 0.0_real64 .or. .not. same_type_as(state, state)) &
         error stop 'EB-R03 invalid accounting state'
    complete = .true.
    missing_mask = TX_MASS_MISSING_NONE
  end subroutine probe_storage_accounting_status

  real(real64) function probe_temporal_error(self, full_state, half_state) result(value)
    class(eb_r03_probe_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    if (self%scale < 0.0_real64 .or. .not. same_type_as(full_state, half_state)) &
         error stop 'EB-R03 invalid temporal states'
    value = 0.0_real64
  end function probe_temporal_error

  subroutine probe_backend_initialize(self, top_boundary)
    class(fmr_serialized_reference_backend_t), target, intent(inout) :: self
    class(top_boundary_provider_t), target, intent(in) :: top_boundary
    if (.not. same_type_as(top_boundary, top_boundary)) error stop 'EB-R03 unreachable top boundary'
    call self%kernel%bind_model(self%model)
    self%last_observation = fmr_serialized_physical_observation_t()
    self%thermal_enabled = .false.
  end subroutine probe_backend_initialize

  subroutine probe_backend_run_trial(self, column, template, parameters, committed, forcing, numerical_config, &
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
         error stop 'EB-R03 probe invalid routing metadata'
    call fmr_trial_from_checkpoint(self%kernel, parameters, committed, forcing, numerical_config, &
         t0, t1, checkpoint, result, candidate, diagnostics)
    self%last_observation = fmr_serialized_physical_observation_t()
    self%last_observation%solver_executed = diagnostics%transaction_calls > 0
    self%last_observation%solver_status = result%status
    self%last_observation%solver_diagnostics%route = 'eb-r03-probe'
    self%last_observation%solver_diagnostics%nonlinear_iterations = diagnostics%nonlinear_iterations
  end subroutine probe_backend_run_trial

  function probe_backend_observation(self) result(observation)
    class(fmr_serialized_reference_backend_t), intent(in) :: self
    type(fmr_serialized_physical_observation_t) :: observation
    observation = self%last_observation
  end function probe_backend_observation

  subroutine probe_set_bottom_thermal_enabled(self, enabled)
    class(fmr_serialized_reference_backend_t), intent(inout) :: self
    logical, intent(in) :: enabled
    self%thermal_enabled = enabled
  end subroutine probe_set_bottom_thermal_enabled

  function probe_bottom_thermal_snapshot(self) result(candidate)
    class(fmr_serialized_reference_backend_t), intent(in) :: self
    type(fmr_bottom_thermal_candidate_t) :: candidate
    if (self%thermal_enabled .neqv. self%thermal_enabled) error stop 'EB-R03 unreachable thermal state'
    call candidate%clear()
  end function probe_bottom_thermal_snapshot

end module mod_fmr_serialized_reference_backend
