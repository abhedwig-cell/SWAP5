module mod_fmr_serialized_reference_backend
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t
  implicit none
  private

  type, extends(canonical_state_t), public :: fvq48_physical_state_t
    real(real64) :: storage = 100.0_real64
  contains
    procedure :: clone => fvq48_state_clone
  end type fvq48_physical_state_t

  type, extends(kernel_parameters_t), public :: fvq48_parameters_t
  end type fvq48_parameters_t

  ! Qualification-local stand-in exposing only the production field consumed by
  ! the pinned F-MR30 candidate.  It is intentionally not the owner test model.
  type, extends(canonical_forcing_t), public :: fmr_b110_physical_forcing_t
    real(real64), allocatable :: root_extraction_sink(:)
  end type fmr_b110_physical_forcing_t

  type, extends(kernel_model_t), public :: fvq48_model_t
    real(real64), allocatable :: solver_qrot(:)
  contains
    procedure :: configure_parameters => fvq48_configure_parameters
    procedure :: execution_admitted => fvq48_execution_admitted
    procedure :: prepare_interval => fvq48_prepare_interval
    procedure :: advance => fvq48_advance
    procedure :: storage => fvq48_storage
    procedure :: storage_accounting_status => fvq48_storage_accounting_status
    procedure :: temporal_error => fvq48_temporal_error
  end type fvq48_model_t

contains

  subroutine fvq48_state_clone(self, copy)
    class(fvq48_physical_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fvq48_physical_state_t :: copy)
    select type (copy)
    type is (fvq48_physical_state_t)
      copy%storage = self%storage
    end select
  end subroutine fvq48_state_clone

  subroutine fvq48_configure_parameters(self, parameters)
    class(fvq48_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    if (.not. same_type_as(self, self) .or. .not. same_type_as(parameters, parameters)) &
         error stop 'FVQ48 unreachable configure type'
  end subroutine fvq48_configure_parameters

  logical function fvq48_execution_admitted(self, parameters, numerical_config)
    class(fvq48_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    fvq48_execution_admitted = same_type_as(self, self) .and. same_type_as(parameters, parameters) .and. &
         numerical_config%max_committed_substeps > 0
  end function fvq48_execution_admitted

  subroutine fvq48_prepare_interval(self, forcing, interval, config)
    class(fvq48_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config

    if (interval%t1 <= interval%t0 .or. config%max_committed_substeps <= 0) &
         error stop 'FVQ48 invalid interval'
    select type (forcing)
    type is (fmr_b110_physical_forcing_t)
      if (.not. allocated(forcing%root_extraction_sink)) error stop 'FVQ48 missing solver qrot'
      if (allocated(self%solver_qrot)) deallocate(self%solver_qrot)
      allocate(self%solver_qrot(size(forcing%root_extraction_sink)))
      self%solver_qrot = forcing%root_extraction_sink
    class default
      error stop 'FVQ48 unexpected forcing type'
    end select
  end subroutine fvq48_prepare_interval

  subroutine fvq48_advance(self, state, t0, t1, outcome)
    class(fvq48_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: amount

    outcome = trial_outcome_t()
    if (.not. allocated(self%solver_qrot) .or. t1 <= t0) return
    amount = sum(self%solver_qrot) * (t1 - t0)
    select type (state)
    type is (fvq48_physical_state_t)
      state%storage = state%storage - amount
    class default
      error stop 'FVQ48 unexpected state type'
    end select
    outcome%solver_ok = .true.
    outcome%mass_out = amount
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    outcome%temporal_certificate_available = .true.
    outcome%temporal_indicator = 0.0_real64
  end subroutine fvq48_advance

  real(real64) function fvq48_storage(self, state) result(value)
    class(fvq48_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    if (.not. same_type_as(self, self)) error stop 'FVQ48 unreachable storage type'
    select type (state)
    type is (fvq48_physical_state_t)
      value = state%storage
    class default
      error stop 'FVQ48 unexpected storage state'
    end select
  end function fvq48_storage

  subroutine fvq48_storage_accounting_status(self, state, complete, missing_mask)
    class(fvq48_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    if (.not. same_type_as(self, self) .or. .not. same_type_as(state, state)) &
         error stop 'FVQ48 unreachable accounting type'
    complete = .true.
    missing_mask = TX_MASS_MISSING_NONE
  end subroutine fvq48_storage_accounting_status

  real(real64) function fvq48_temporal_error(self, full_state, half_state) result(value)
    class(fvq48_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    if (.not. same_type_as(self, self) .or. .not. same_type_as(full_state, half_state)) &
         error stop 'FVQ48 unreachable temporal type'
    value = 0.0_real64
  end function fvq48_temporal_error

end module mod_fmr_serialized_reference_backend
