module mod_fmr_serialized_reference_backend
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t
  implicit none
  private

  type, extends(canonical_state_t), public :: fmr30_test_physical_state_t
    real(real64) :: storage_value = 10.0_real64
  contains
    procedure :: clone => fmr30_state_clone
  end type fmr30_test_physical_state_t

  type, extends(kernel_parameters_t), public :: fmr30_test_parameters_t
    logical :: admitted = .true.
  end type fmr30_test_parameters_t

  ! Exact field required by the production attribution module. The test model
  ! also uses this same array as its only external sink, so the attribution can
  ! be reconciled directly against transaction mass_out.
  type, extends(canonical_forcing_t), public :: fmr_b110_physical_forcing_t
    real(real64), allocatable :: root_extraction_sink(:)
  end type fmr_b110_physical_forcing_t

  type, extends(kernel_model_t), public :: fmr30_test_model_t
    real(real64), allocatable :: qrot(:)
  contains
    procedure :: configure_parameters => fmr30_configure_parameters
    procedure :: execution_admitted => fmr30_execution_admitted
    procedure :: prepare_interval => fmr30_prepare_interval
    procedure :: advance => fmr30_advance
    procedure :: storage => fmr30_storage
    procedure :: storage_accounting_status => fmr30_storage_accounting_status
    procedure :: temporal_error => fmr30_temporal_error
  end type fmr30_test_model_t

contains

  subroutine fmr30_state_clone(self, copy)
    class(fmr30_test_physical_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy

    allocate(fmr30_test_physical_state_t :: copy)
    select type (copy)
    type is (fmr30_test_physical_state_t)
      copy%storage_value = self%storage_value
    end select
  end subroutine fmr30_state_clone

  subroutine fmr30_configure_parameters(self, parameters)
    class(fmr30_test_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters

    if (.not. same_type_as(self, self)) error stop 'F-MR30 unreachable model type'
    select type (parameters)
    type is (fmr30_test_parameters_t)
      if (.not. parameters%admitted) error stop 'F-MR30 configure called for rejected parameters'
    class default
      error stop 'F-MR30 unexpected parameter type'
    end select
  end subroutine fmr30_configure_parameters

  logical function fmr30_execution_admitted(self, parameters, numerical_config)
    class(fmr30_test_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config

    fmr30_execution_admitted = .false.
    if (.not. same_type_as(self, self)) return
    select type (parameters)
    type is (fmr30_test_parameters_t)
      fmr30_execution_admitted = parameters%admitted .and. numerical_config%max_committed_substeps > 0
    class default
      fmr30_execution_admitted = .false.
    end select
  end function fmr30_execution_admitted

  subroutine fmr30_prepare_interval(self, forcing, interval, config)
    class(fmr30_test_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config

    if (interval%t1 <= interval%t0 .or. config%max_committed_substeps <= 0) &
         error stop 'F-MR30 invalid interval'
    select type (forcing)
    type is (fmr_b110_physical_forcing_t)
      if (.not. allocated(forcing%root_extraction_sink)) error stop 'F-MR30 missing qrot forcing'
      if (allocated(self%qrot)) deallocate(self%qrot)
      allocate(self%qrot(size(forcing%root_extraction_sink)))
      self%qrot = forcing%root_extraction_sink
    class default
      error stop 'F-MR30 unexpected forcing type'
    end select
  end subroutine fmr30_prepare_interval

  subroutine fmr30_advance(self, state, t0, t1, outcome)
    class(fmr30_test_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: amount

    outcome = trial_outcome_t()
    if (.not. allocated(self%qrot)) return
    amount = sum(self%qrot) * (t1 - t0)
    select type (state)
    type is (fmr30_test_physical_state_t)
      state%storage_value = state%storage_value - amount
    class default
      error stop 'F-MR30 unexpected state type'
    end select
    outcome%solver_ok = .true.
    outcome%mass_out = amount
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    outcome%nonlinear_iterations = 1
  end subroutine fmr30_advance

  real(real64) function fmr30_storage(self, state) result(value)
    class(fmr30_test_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state

    if (.not. same_type_as(self, self)) error stop 'F-MR30 unreachable storage model'
    select type (state)
    type is (fmr30_test_physical_state_t)
      value = state%storage_value
    class default
      error stop 'F-MR30 unexpected storage state type'
    end select
  end function fmr30_storage

  subroutine fmr30_storage_accounting_status(self, state, complete, missing_mask)
    class(fmr30_test_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask

    if (.not. same_type_as(self, self) .or. .not. same_type_as(state, state)) &
         error stop 'F-MR30 unreachable accounting type'
    complete = .true.
    missing_mask = TX_MASS_MISSING_NONE
  end subroutine fmr30_storage_accounting_status

  real(real64) function fmr30_temporal_error(self, full_state, half_state) result(value)
    class(fmr30_test_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state

    if (.not. same_type_as(self, self) .or. .not. same_type_as(full_state, half_state)) &
         error stop 'F-MR30 unreachable temporal type'
    value = 0.0_real64
  end function fmr30_temporal_error

end module mod_fmr_serialized_reference_backend
