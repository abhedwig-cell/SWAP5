module mod_fpm06g_publication_test_backend
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t
  implicit none
  private

  type, extends(canonical_state_t), public :: fpm06g_test_state_t
    real(real64) :: storage_value = 10.0_real64
  contains
    procedure :: clone => test_state_clone
  end type fpm06g_test_state_t

  type, extends(kernel_parameters_t), public :: fpm06g_test_parameters_t
    logical :: admitted = .true.
  end type fpm06g_test_parameters_t

  type, extends(canonical_forcing_t), public :: fpm06g_test_forcing_t
  end type fpm06g_test_forcing_t

  type, extends(kernel_model_t), public :: fpm06g_test_model_t
  contains
    procedure :: configure_parameters => test_configure_parameters
    procedure :: execution_admitted => test_execution_admitted
    procedure :: prepare_interval => test_prepare_interval
    procedure :: advance => test_advance
    procedure :: storage => test_storage
    procedure :: storage_accounting_status => test_storage_accounting_status
    procedure :: temporal_error => test_temporal_error
  end type fpm06g_test_model_t

contains

  subroutine test_state_clone(self, copy)
    class(fpm06g_test_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy

    allocate(fpm06g_test_state_t :: copy)
    select type (copy)
    type is (fpm06g_test_state_t)
      copy%storage_value = self%storage_value
    end select
  end subroutine test_state_clone

  subroutine test_configure_parameters(self, parameters)
    class(fpm06g_test_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters

    if (.not. same_type_as(self, self)) error stop 'F-PM06G unreachable model type'
    select type (parameters)
    type is (fpm06g_test_parameters_t)
      if (.not. parameters%admitted) error stop 'F-PM06G configure called for rejected parameters'
    class default
      error stop 'F-PM06G unexpected parameter type'
    end select
  end subroutine test_configure_parameters

  logical function test_execution_admitted(self, parameters, numerical_config)
    class(fpm06g_test_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config

    test_execution_admitted = .false.
    if (.not. same_type_as(self, self)) return
    select type (parameters)
    type is (fpm06g_test_parameters_t)
      test_execution_admitted = parameters%admitted .and. numerical_config%max_committed_substeps > 0
    class default
      test_execution_admitted = .false.
    end select
  end function test_execution_admitted

  subroutine test_prepare_interval(self, forcing, interval, config)
    class(fpm06g_test_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config

    if (.not. same_type_as(self, self) .or. .not. same_type_as(forcing, forcing)) &
         error stop 'F-PM06G unreachable prepare type'
    if (interval%t1 <= interval%t0 .or. config%max_committed_substeps <= 0) &
         error stop 'F-PM06G invalid interval'
  end subroutine test_prepare_interval

  subroutine test_advance(self, state, t0, t1, outcome)
    class(fpm06g_test_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome

    if (.not. same_type_as(self, self) .or. t1 <= t0) error stop 'F-PM06G invalid trial'
    select type (state)
    type is (fpm06g_test_state_t)
      state%storage_value = state%storage_value
    class default
      error stop 'F-PM06G unexpected state type'
    end select
    outcome = trial_outcome_t()
    outcome%solver_ok = .true.
    outcome%mass_in = 0.0_real64
    outcome%mass_out = 0.0_real64
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    outcome%nonlinear_iterations = 1
  end subroutine test_advance

  real(real64) function test_storage(self, state) result(value)
    class(fpm06g_test_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state

    if (.not. same_type_as(self, self)) error stop 'F-PM06G unreachable storage model'
    select type (state)
    type is (fpm06g_test_state_t)
      value = state%storage_value
    class default
      error stop 'F-PM06G unexpected storage state type'
    end select
  end function test_storage

  subroutine test_storage_accounting_status(self, state, complete, missing_mask)
    class(fpm06g_test_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask

    if (.not. same_type_as(self, self) .or. .not. same_type_as(state, state)) &
         error stop 'F-PM06G unreachable accounting type'
    complete = .true.
    missing_mask = TX_MASS_MISSING_NONE
  end subroutine test_storage_accounting_status

  real(real64) function test_temporal_error(self, full_state, half_state) result(value)
    class(fpm06g_test_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state

    if (.not. same_type_as(self, self) .or. .not. same_type_as(full_state, half_state)) &
         error stop 'F-PM06G unreachable temporal type'
    value = 0.0_real64
  end function test_temporal_error

end module mod_fpm06g_publication_test_backend
