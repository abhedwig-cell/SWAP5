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
  implicit none
  private

  type, extends(canonical_state_t), public :: fvq50_physical_state_t
    real(real64) :: storage = 50.0_real64
  contains
    procedure :: clone => fvq50_state_clone
  end type fvq50_physical_state_t

  type, extends(kernel_parameters_t), public :: fmr_b110_physical_parameters_t
    logical :: admitted = .true.
    integer :: active_nodes = 0
    logical :: root_extraction_active = .false.
    real(real64) :: independent_background_out_rate = 0.0_real64
  end type fmr_b110_physical_parameters_t

  type, extends(canonical_forcing_t), public :: fmr_b110_physical_forcing_t
    real(real64), allocatable :: root_extraction_sink(:)
  end type fmr_b110_physical_forcing_t

  type, public :: fmr_serialized_physical_observation_t
    logical :: solver_executed = .false.
    integer :: solver_status = 0
    type(soil_water_solver_diagnostics_t) :: solver_diagnostics
  end type fmr_serialized_physical_observation_t

  type, extends(kernel_model_t) :: fvq50_model_t
    integer :: active_nodes = 0
    logical :: root_active = .false.
    real(real64) :: background_out_rate = 0.0_real64
    real(real64), allocatable :: qrot(:)
  contains
    procedure :: configure_parameters => fvq50_configure_parameters
    procedure :: execution_admitted => fvq50_execution_admitted
    procedure :: prepare_interval => fvq50_prepare_interval
    procedure :: advance => fvq50_advance
    procedure :: storage => fvq50_storage
    procedure :: storage_accounting_status => fvq50_storage_accounting_status
    procedure :: temporal_error => fvq50_temporal_error
  end type fvq50_model_t

  type, public :: fmr_serialized_reference_backend_t
    type(fvq50_model_t) :: model
    type(kernel_executor_t) :: kernel
    type(fmr_serialized_physical_observation_t) :: last_observation
  contains
    procedure :: initialize => fvq50_backend_initialize
    procedure :: run_trial => fvq50_backend_run_trial
    procedure :: observation => fvq50_backend_observation
  end type fmr_serialized_reference_backend_t

contains

  subroutine fvq50_state_clone(self, copy)
    class(fvq50_physical_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fvq50_physical_state_t :: copy)
    select type (copy)
    type is (fvq50_physical_state_t)
      copy%storage = self%storage
    end select
  end subroutine fvq50_state_clone

  subroutine fvq50_configure_parameters(self, parameters)
    class(fvq50_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    select type (parameters)
    type is (fmr_b110_physical_parameters_t)
      self%active_nodes = parameters%active_nodes
      self%root_active = parameters%root_extraction_active
      self%background_out_rate = parameters%independent_background_out_rate
    class default
      error stop 'F-VQ50 unexpected parameter type'
    end select
  end subroutine fvq50_configure_parameters

  logical function fvq50_execution_admitted(self, parameters, numerical_config)
    class(fvq50_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    if (.not. same_type_as(self,self)) error stop 'F-VQ50 unreachable model type'
    select type (parameters)
    type is (fmr_b110_physical_parameters_t)
      fvq50_execution_admitted = parameters%admitted .and. parameters%active_nodes > 0 .and. &
           parameters%independent_background_out_rate >= 0.0_real64 .and. numerical_config%max_committed_substeps > 0
    class default
      fvq50_execution_admitted = .false.
    end select
  end function fvq50_execution_admitted

  subroutine fvq50_prepare_interval(self, forcing, interval, config)
    class(fvq50_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config

    if (interval%t1 <= interval%t0 .or. config%max_committed_substeps <= 0) &
         error stop 'F-VQ50 invalid interval'
    select type (forcing)
    type is (fmr_b110_physical_forcing_t)
      if (.not. allocated(forcing%root_extraction_sink)) error stop 'F-VQ50 missing qrot'
      if (size(forcing%root_extraction_sink) /= self%active_nodes) error stop 'F-VQ50 qrot shape mismatch'
      if (allocated(self%qrot)) deallocate(self%qrot)
      allocate(self%qrot(size(forcing%root_extraction_sink)))
      self%qrot = forcing%root_extraction_sink
    class default
      error stop 'F-VQ50 unexpected forcing type'
    end select
  end subroutine fvq50_prepare_interval

  subroutine fvq50_advance(self, state, t0, t1, outcome)
    class(fvq50_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: root_amount, background_amount, total_amount

    outcome = trial_outcome_t()
    if (.not. allocated(self%qrot) .or. t1 <= t0) return
    root_amount = 0.0_real64
    if (self%root_active) root_amount = sum(self%qrot) * (t1 - t0)
    background_amount = self%background_out_rate * (t1 - t0)
    total_amount = root_amount + background_amount

    select type (state)
    type is (fvq50_physical_state_t)
      state%storage = state%storage - total_amount
    class default
      error stop 'F-VQ50 unexpected state type'
    end select

    outcome%solver_ok = .true.
    outcome%mass_out = total_amount
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    outcome%temporal_certificate_available = .true.
    outcome%temporal_indicator = 0.0_real64
    outcome%nonlinear_iterations = 2
  end subroutine fvq50_advance

  real(real64) function fvq50_storage(self, state) result(value)
    class(fvq50_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    if (.not. same_type_as(self,self)) error stop 'F-VQ50 unreachable storage type'
    select type (state)
    type is (fvq50_physical_state_t)
      value = state%storage
    class default
      error stop 'F-VQ50 unexpected storage state'
    end select
  end function fvq50_storage

  subroutine fvq50_storage_accounting_status(self, state, complete, missing_mask)
    class(fvq50_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    if (.not. same_type_as(self,self) .or. .not. same_type_as(state,state)) &
         error stop 'F-VQ50 unreachable accounting type'
    complete = .true.
    missing_mask = TX_MASS_MISSING_NONE
  end subroutine fvq50_storage_accounting_status

  real(real64) function fvq50_temporal_error(self, full_state, half_state) result(value)
    class(fvq50_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    if (.not. same_type_as(self,self) .or. .not. same_type_as(full_state,half_state)) &
         error stop 'F-VQ50 unreachable temporal type'
    value = 0.0_real64
  end function fvq50_temporal_error

  subroutine fvq50_backend_initialize(self, top_boundary)
    class(fmr_serialized_reference_backend_t), target, intent(inout) :: self
    class(top_boundary_provider_t), target, intent(in) :: top_boundary
    if (.not. same_type_as(top_boundary,top_boundary)) error stop 'F-VQ50 unreachable top boundary'
    call self%kernel%bind_model(self%model)
    self%last_observation = fmr_serialized_physical_observation_t()
  end subroutine fvq50_backend_initialize

  subroutine fvq50_backend_run_trial(self, column, template, parameters, committed, forcing, numerical_config, &
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
         error stop 'F-VQ50 invalid runtime routing metadata'
    call fmr_trial_from_checkpoint(self%kernel, parameters, committed, forcing, numerical_config, &
         t0, t1, checkpoint, result, candidate, diagnostics)
    self%last_observation = fmr_serialized_physical_observation_t()
    self%last_observation%solver_executed = diagnostics%transaction_calls > 0
    self%last_observation%solver_status = result%status
    self%last_observation%solver_diagnostics%route = 'fvq50-independent'
    self%last_observation%solver_diagnostics%nonlinear_iterations = diagnostics%nonlinear_iterations
  end subroutine fvq50_backend_run_trial

  function fvq50_backend_observation(self) result(observation)
    class(fmr_serialized_reference_backend_t), intent(in) :: self
    type(fmr_serialized_physical_observation_t) :: observation
    observation = self%last_observation
  end function fvq50_backend_observation

end module mod_fmr_serialized_reference_backend
