module mod_fvq48_independent_root_mass_model
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_forcing_t
  implicit none
  private

  type, extends(canonical_state_t), public :: fvq48_independent_state_t
    real(real64) :: storage_value = 1000.0_real64
  contains
    procedure :: clone => fvq48_clone_state
  end type fvq48_independent_state_t

  type, extends(kernel_parameters_t), public :: fvq48_independent_parameters_t
    logical :: admitted = .true.
  end type fvq48_independent_parameters_t

  type, extends(kernel_model_t), public :: fvq48_independent_model_t
    logical :: parameter_admitted = .false.
    logical :: forcing_ready = .false.
    real(real64), allocatable :: qrot(:)
  contains
    procedure :: configure_parameters => fvq48_configure_parameters
    procedure :: execution_admitted => fvq48_execution_admitted
    procedure :: prepare_interval => fvq48_prepare_interval
    procedure :: advance => fvq48_advance
    procedure :: storage => fvq48_storage
    procedure :: storage_accounting_status => fvq48_storage_accounting_status
    procedure :: temporal_error => fvq48_temporal_error
  end type fvq48_independent_model_t

contains

  subroutine fvq48_clone_state(self, copy)
    class(fvq48_independent_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy

    allocate(fvq48_independent_state_t :: copy)
    select type (typed_copy => copy)
    type is (fvq48_independent_state_t)
      typed_copy%storage_value = self%storage_value
    end select
  end subroutine fvq48_clone_state

  subroutine fvq48_configure_parameters(self, parameters)
    class(fvq48_independent_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters

    self%parameter_admitted = .false.
    select type (parameters)
    type is (fvq48_independent_parameters_t)
      self%parameter_admitted = parameters%admitted
    class default
      self%parameter_admitted = .false.
    end select
  end subroutine fvq48_configure_parameters

  logical function fvq48_execution_admitted(self, parameters, numerical_config) result(admitted)
    class(fvq48_independent_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config

    admitted = .false.
    select type (parameters)
    type is (fvq48_independent_parameters_t)
      admitted = self%parameter_admitted .and. parameters%admitted .and. numerical_config%max_committed_substeps > 0
    class default
      admitted = .false.
    end select
  end function fvq48_execution_admitted

  subroutine fvq48_prepare_interval(self, forcing, interval, config)
    class(fvq48_independent_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config

    self%forcing_ready = .false.
    if (allocated(self%qrot)) deallocate(self%qrot)
    if (interval%t1 <= interval%t0 .or. config%max_committed_substeps <= 0) return

    select type (forcing)
    type is (fmr_b110_physical_forcing_t)
      if (.not. allocated(forcing%root_extraction_sink)) return
      if (any(.not. ieee_is_finite(forcing%root_extraction_sink))) return
      self%qrot = forcing%root_extraction_sink
      self%forcing_ready = .true.
    class default
      self%forcing_ready = .false.
    end select
  end subroutine fvq48_prepare_interval

  subroutine fvq48_advance(self, state, t0, t1, outcome)
    class(fvq48_independent_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: amount

    outcome = trial_outcome_t()
    if (.not. self%forcing_ready .or. t1 <= t0) return
    if (any(self%qrot < 0.0_real64)) return

    amount = sum(self%qrot) * (t1 - t0)
    if (.not. ieee_is_finite(amount) .or. amount < 0.0_real64) return

    select type (state)
    type is (fvq48_independent_state_t)
      state%storage_value = state%storage_value - amount
    class default
      return
    end select

    outcome%solver_ok = .true.
    outcome%mass_out = amount
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    outcome%nonlinear_iterations = 3
  end subroutine fvq48_advance

  real(real64) function fvq48_storage(self, state) result(value)
    class(fvq48_independent_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state

    if (self%parameter_admitted .neqv. self%parameter_admitted) error stop 'FVQ48 unreachable model state'
    select type (state)
    type is (fvq48_independent_state_t)
      value = state%storage_value
    class default
      value = huge(0.0_real64)
    end select
  end function fvq48_storage

  subroutine fvq48_storage_accounting_status(self, state, complete, missing_mask)
    class(fvq48_independent_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask

    complete = self%parameter_admitted .or. .not. self%parameter_admitted
    if (.not. same_type_as(state, state)) error stop 'FVQ48 unreachable accounting state'
    missing_mask = TX_MASS_MISSING_NONE
  end subroutine fvq48_storage_accounting_status

  real(real64) function fvq48_temporal_error(self, full_state, half_state) result(value)
    class(fvq48_independent_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state

    value = abs(self%storage(full_state) - self%storage(half_state))
  end function fvq48_temporal_error

end module mod_fvq48_independent_root_mass_model
