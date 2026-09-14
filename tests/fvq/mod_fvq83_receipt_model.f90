module mod_fvq83_receipt_model
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t
  implicit none
  private

  type, extends(canonical_state_t), public :: fvq83_state_t
    real(real64) :: water_store = 3.0_real64
  contains
    procedure :: clone => fvq83_clone
  end type fvq83_state_t

  type, extends(kernel_parameters_t), public :: fvq83_parameters_t
    real(real64) :: inflow_rate = 0.2_real64
  end type fvq83_parameters_t

  type, extends(canonical_forcing_t), public :: fvq83_forcing_t
    real(real64) :: multiplier = 1.0_real64
  end type fvq83_forcing_t

  type, extends(kernel_model_t), public :: fvq83_model_t
    real(real64) :: inflow_rate = 0.2_real64
    real(real64) :: multiplier = 1.0_real64
  contains
    procedure :: configure_parameters => fvq83_configure
    procedure :: execution_admitted => fvq83_admitted
    procedure :: prepare_interval => fvq83_prepare
    procedure :: advance => fvq83_advance
    procedure :: storage => fvq83_storage
    procedure :: temporal_error => fvq83_temporal_error
    procedure :: storage_accounting_status => fvq83_storage_status
  end type fvq83_model_t

contains

  subroutine fvq83_clone(self, copy)
    class(fvq83_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fvq83_state_t :: copy)
    select type (copy)
    type is (fvq83_state_t)
      copy%water_store = self%water_store
    end select
  end subroutine fvq83_clone

  subroutine fvq83_configure(self, parameters)
    class(fvq83_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    select type (parameters)
    type is (fvq83_parameters_t)
      self%inflow_rate = parameters%inflow_rate
    class default
      self%inflow_rate = -1.0_real64
    end select
  end subroutine fvq83_configure

  logical function fvq83_admitted(self, parameters, numerical_config)
    class(fvq83_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    logical :: parameter_ok
    parameter_ok = .false.
    select type (parameters)
    type is (fvq83_parameters_t)
      parameter_ok = parameters%inflow_rate >= 0.0_real64
    end select
    fvq83_admitted = parameter_ok .and. self%multiplier >= 0.0_real64 .and. numerical_config%max_committed_substeps > 0
  end function fvq83_admitted

  subroutine fvq83_prepare(self, forcing, interval, config)
    class(fvq83_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    select type (forcing)
    type is (fvq83_forcing_t)
      self%multiplier = forcing%multiplier
    class default
      self%multiplier = -1.0_real64
    end select
    if (interval%t1 <= interval%t0 .or. config%max_committed_substeps <= 0) self%multiplier = -1.0_real64
  end subroutine fvq83_prepare

  subroutine fvq83_advance(self, state, t0, t1, outcome)
    class(fvq83_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: amount
    outcome = trial_outcome_t()
    amount = self%inflow_rate * self%multiplier * (t1 - t0)
    select type (state)
    type is (fvq83_state_t)
      state%water_store = state%water_store + amount
      outcome%solver_ok = .true.
      outcome%mass_in = amount
      outcome%mass_accounting_complete = .true.
      outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
      outcome%nonlinear_iterations = 1
    class default
      outcome%solver_ok = .false.
    end select
  end subroutine fvq83_advance

  real(real64) function fvq83_storage(self, state) result(value)
    class(fvq83_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    value = huge(0.0_real64)
    if (self%multiplier < 0.0_real64) return
    select type (state)
    type is (fvq83_state_t)
      value = state%water_store
    end select
  end function fvq83_storage

  real(real64) function fvq83_temporal_error(self, full_state, half_state) result(value)
    class(fvq83_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    value = huge(0.0_real64)
    if (self%multiplier < 0.0_real64) return
    if (.not. same_type_as(full_state, half_state)) return
    value = 0.0_real64
  end function fvq83_temporal_error

  subroutine fvq83_storage_status(self, state, complete, missing_mask)
    class(fvq83_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    complete = .false.
    missing_mask = TX_MASS_MISSING_NONE
    if (self%multiplier < 0.0_real64) return
    select type (state)
    type is (fvq83_state_t)
      complete = .true.
    end select
  end subroutine fvq83_storage_status

end module mod_fvq83_receipt_model
