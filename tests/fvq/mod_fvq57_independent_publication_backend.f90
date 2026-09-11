module mod_fvq57_independent_publication_backend
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t
  implicit none
  private

  type, extends(canonical_state_t), public :: fvq57_state_t
    integer :: physical_case_id = 0
    real(real64) :: storage_value = 12.0_real64
  contains
    procedure :: clone => fvq57_state_clone
  end type fvq57_state_t

  type, extends(kernel_parameters_t), public :: fvq57_parameters_t
  end type fvq57_parameters_t

  type, extends(canonical_forcing_t), public :: fvq57_forcing_t
  end type fvq57_forcing_t

  type, extends(kernel_model_t), public :: fvq57_model_t
  contains
    procedure :: configure_parameters => fvq57_configure_parameters
    procedure :: execution_admitted => fvq57_execution_admitted
    procedure :: prepare_interval => fvq57_prepare_interval
    procedure :: advance => fvq57_advance
    procedure :: storage => fvq57_storage
    procedure :: storage_accounting_status => fvq57_storage_accounting_status
    procedure :: temporal_error => fvq57_temporal_error
  end type fvq57_model_t

contains

  subroutine fvq57_state_clone(self, copy)
    class(fvq57_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy

    allocate(fvq57_state_t :: copy)
    select type (copy)
    type is (fvq57_state_t)
      copy%physical_case_id = self%physical_case_id
      copy%storage_value = self%storage_value
    end select
  end subroutine fvq57_state_clone

  subroutine fvq57_configure_parameters(self, parameters)
    class(fvq57_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    if (.not. same_type_as(self,self) .or. .not. same_type_as(parameters,parameters)) error stop 'FVQ57 configure type'
  end subroutine fvq57_configure_parameters

  logical function fvq57_execution_admitted(self, parameters, numerical_config)
    class(fvq57_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    fvq57_execution_admitted = same_type_as(self,self) .and. same_type_as(parameters,parameters) .and. &
         numerical_config%max_committed_substeps > 0
  end function fvq57_execution_admitted

  subroutine fvq57_prepare_interval(self, forcing, interval, config)
    class(fvq57_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    if (.not. same_type_as(self,self) .or. .not. same_type_as(forcing,forcing)) error stop 'FVQ57 prepare type'
    if (interval%t1 <= interval%t0 .or. config%max_committed_substeps <= 0) error stop 'FVQ57 interval'
  end subroutine fvq57_prepare_interval

  subroutine fvq57_advance(self, state, t0, t1, outcome)
    class(fvq57_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome

    if (.not. same_type_as(self,self) .or. t1 <= t0) error stop 'FVQ57 advance'
    select type (state)
    type is (fvq57_state_t)
      if (state%physical_case_id <= 0) error stop 'FVQ57 invalid physical case'
    class default
      error stop 'FVQ57 unexpected state'
    end select
    outcome = trial_outcome_t()
    outcome%solver_ok = .true.
    outcome%mass_in = 0.0_real64
    outcome%mass_out = 0.0_real64
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    outcome%nonlinear_iterations = 1
  end subroutine fvq57_advance

  real(real64) function fvq57_storage(self, state) result(value)
    class(fvq57_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    if (.not. same_type_as(self,self)) error stop 'FVQ57 storage model'
    select type (state)
    type is (fvq57_state_t)
      value = state%storage_value
    class default
      error stop 'FVQ57 storage state'
    end select
  end function fvq57_storage

  subroutine fvq57_storage_accounting_status(self, state, complete, missing_mask)
    class(fvq57_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    if (.not. same_type_as(self,self) .or. .not. same_type_as(state,state)) error stop 'FVQ57 accounting type'
    complete = .true.
    missing_mask = TX_MASS_MISSING_NONE
  end subroutine fvq57_storage_accounting_status

  real(real64) function fvq57_temporal_error(self, full_state, half_state) result(value)
    class(fvq57_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    if (.not. same_type_as(self,self) .or. .not. same_type_as(full_state,half_state)) error stop 'FVQ57 temporal type'
    value = 0.0_real64
  end function fvq57_temporal_error

end module mod_fvq57_independent_publication_backend
