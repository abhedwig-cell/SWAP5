module mod_fvq84_receipt_model
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t
  implicit none
  private

  type, extends(canonical_state_t), public :: fvq84_state_t
    real(real64) :: water_store = 4.0_real64
  contains
    procedure :: clone => fvq84_clone
  end type fvq84_state_t

  type, extends(kernel_parameters_t), public :: fvq84_parameters_t
    real(real64) :: inflow_rate = 0.125_real64
  end type fvq84_parameters_t

  type, extends(canonical_forcing_t), public :: fvq84_forcing_t
    real(real64) :: multiplier = 1.0_real64
  end type fvq84_forcing_t

  type, extends(kernel_model_t), public :: fvq84_model_t
    real(real64) :: inflow_rate = 0.125_real64
    real(real64) :: multiplier = 1.0_real64
  contains
    procedure :: configure_parameters => fvq84_configure
    procedure :: execution_admitted => fvq84_admitted
    procedure :: prepare_interval => fvq84_prepare
    procedure :: advance => fvq84_advance
    procedure :: storage => fvq84_storage
    procedure :: temporal_error => fvq84_temporal_error
    procedure :: storage_accounting_status => fvq84_storage_status
  end type fvq84_model_t

contains

  subroutine fvq84_clone(self, copy)
    class(fvq84_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fvq84_state_t :: copy)
    select type (copy)
    type is (fvq84_state_t)
      copy%water_store = self%water_store
    end select
  end subroutine fvq84_clone

  subroutine fvq84_configure(self, parameters)
    class(fvq84_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    select type (parameters)
    type is (fvq84_parameters_t)
      self%inflow_rate = parameters%inflow_rate
    class default
      self%inflow_rate = -1.0_real64
    end select
  end subroutine fvq84_configure

  logical function fvq84_admitted(self, parameters, numerical_config)
    class(fvq84_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    logical :: parameter_ok
    parameter_ok = .false.
    select type (parameters)
    type is (fvq84_parameters_t)
      parameter_ok = parameters%inflow_rate >= 0.0_real64
    end select
    fvq84_admitted = parameter_ok .and. self%multiplier >= 0.0_real64 .and. numerical_config%max_committed_substeps > 0
  end function fvq84_admitted

  subroutine fvq84_prepare(self, forcing, interval, config)
    class(fvq84_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    select type (forcing)
    type is (fvq84_forcing_t)
      self%multiplier = forcing%multiplier
    class default
      self%multiplier = -1.0_real64
    end select
    if (interval%t1 <= interval%t0 .or. config%max_committed_substeps <= 0) self%multiplier = -1.0_real64
  end subroutine fvq84_prepare

  subroutine fvq84_advance(self, state, t0, t1, outcome)
    class(fvq84_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: amount
    outcome = trial_outcome_t()
    amount = self%inflow_rate * self%multiplier * (t1 - t0)
    select type (state)
    type is (fvq84_state_t)
      state%water_store = state%water_store + amount
      outcome%solver_ok = .true.
      outcome%mass_in = amount
      outcome%mass_accounting_complete = .true.
      outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
      outcome%nonlinear_iterations = 1
    class default
      outcome%solver_ok = .false.
    end select
  end subroutine fvq84_advance

  real(real64) function fvq84_storage(self, state) result(value)
    class(fvq84_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    value = huge(0.0_real64)
    if (self%multiplier < 0.0_real64) return
    select type (state)
    type is (fvq84_state_t)
      value = state%water_store
    end select
  end function fvq84_storage

  real(real64) function fvq84_temporal_error(self, full_state, half_state) result(value)
    class(fvq84_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    value = huge(0.0_real64)
    if (self%multiplier < 0.0_real64) return
    if (.not. same_type_as(full_state, half_state)) return
    value = 0.0_real64
  end function fvq84_temporal_error

  subroutine fvq84_storage_status(self, state, complete, missing_mask)
    class(fvq84_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    complete = .false.
    missing_mask = TX_MASS_MISSING_NONE
    if (self%multiplier < 0.0_real64) return
    select type (state)
    type is (fvq84_state_t)
      complete = .true.
    end select
  end subroutine fvq84_storage_status

end module mod_fvq84_receipt_model
