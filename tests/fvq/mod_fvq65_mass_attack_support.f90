module fvq65_mass_attack_support
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference, only: transaction_state_t, transaction_model_t, trial_outcome_t, &
       TX_MASS_MISSING_NONE, TX_MASS_MISSING_ACTIVE_CONTRIBUTION
  implicit none
  private

  integer, parameter, public :: Q_ROUTE_EXTERNAL = 1
  integer, parameter, public :: Q_ROUTE_CERTIFICATE = 2

  integer, parameter, public :: SC_COMPLETE = 0
  integer, parameter, public :: SC_SMALL_COMPLETE_RESIDUAL = 1
  integer, parameter, public :: SC_LARGE_COMPLETE_RESIDUAL = 2
  integer, parameter, public :: SC_START_STORAGE_INCOMPLETE = 10
  integer, parameter, public :: SC_START_STORAGE_MASK = 11
  integer, parameter, public :: SC_EXT_FULL_STORAGE_INCOMPLETE = 20
  integer, parameter, public :: SC_EXT_END_STORAGE_INCOMPLETE = 21
  integer, parameter, public :: SC_EXT_END_STORAGE_MASK = 22
  integer, parameter, public :: SC_EXT_FULL_OUTCOME_INCOMPLETE = 30
  integer, parameter, public :: SC_EXT_HALF1_OUTCOME_INCOMPLETE = 31
  integer, parameter, public :: SC_EXT_HALF2_OUTCOME_INCOMPLETE = 32
  integer, parameter, public :: SC_EXT_FULL_OUTCOME_MASK = 33
  integer, parameter, public :: SC_EXT_HALF1_OUTCOME_MASK = 34
  integer, parameter, public :: SC_EXT_HALF2_OUTCOME_MASK = 35
  integer, parameter, public :: SC_EXT_NONFINITE_FULL_MASS = 36
  integer, parameter, public :: SC_EXT_NONFINITE_HALF2_MASS = 37
  integer, parameter, public :: SC_EXT_RETRY_RECOVERY = 38
  integer, parameter, public :: SC_CERT_END_STORAGE_INCOMPLETE = 50
  integer, parameter, public :: SC_CERT_END_STORAGE_MASK = 51
  integer, parameter, public :: SC_CERT_OUTCOME_INCOMPLETE = 52
  integer, parameter, public :: SC_CERT_OUTCOME_MASK = 53
  integer, parameter, public :: SC_CERT_NONFINITE_MASS = 54
  integer, parameter, public :: SC_CERT_RETRY_RECOVERY = 55
  integer, parameter, public :: SC_CERT_ALT_SOLVER_INCOMPLETE = 56

  real(real64), parameter, public :: Q_MASS_TOL = 1.0e-8_real64
  real(real64), parameter :: SMALL_RESIDUAL_PERTURBATION = 1.0e-10_real64
  real(real64), parameter :: LARGE_RESIDUAL_PERTURBATION = 1.0e-6_real64

  integer, parameter :: ROLE_FULL = 1
  integer, parameter :: ROLE_HALF1 = 2
  integer, parameter :: ROLE_HALF2 = 3

  type, extends(transaction_state_t), public :: qualification_state_t
    real(real64) :: water = 0.0_real64
    integer :: generation = 0
    integer :: last_role = 0
  contains
    procedure :: clone => qualification_clone
  end type qualification_state_t

  type, extends(transaction_model_t), public :: qualification_model_t
    integer :: scenario = SC_COMPLETE
    integer :: route_mode = Q_ROUTE_EXTERNAL
    integer :: advance_calls = 0
  contains
    procedure :: advance => qualification_advance
    procedure :: storage => qualification_storage
    procedure :: storage_accounting_status => qualification_storage_accounting_status
    procedure :: temporal_error => qualification_temporal_error
  end type qualification_model_t

  public :: make_state, state_water

contains

  subroutine qualification_clone(self, copy)
    class(qualification_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy

    allocate(qualification_state_t :: copy)
    select type (copy)
    type is (qualification_state_t)
      copy = self
    class default
      error stop 'F-VQ65 clone type failure'
    end select
  end subroutine qualification_clone

  subroutine make_state(committed, water)
    class(transaction_state_t), allocatable, intent(out) :: committed
    real(real64), intent(in) :: water

    allocate(qualification_state_t :: committed)
    select type (committed)
    type is (qualification_state_t)
      committed%water = water
      committed%generation = 0
      committed%last_role = 0
    class default
      error stop 'F-VQ65 state allocation failure'
    end select
  end subroutine make_state

  real(real64) function state_water(committed) result(value)
    class(transaction_state_t), allocatable, intent(in) :: committed

    select type (committed)
    type is (qualification_state_t)
      value = committed%water
    class default
      error stop 'F-VQ65 state inspection failure'
    end select
  end function state_water

  subroutine qualification_advance(self, state, t0, t1, outcome)
    class(qualification_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: delta
    integer :: role, attempt

    self%advance_calls = self%advance_calls + 1
    if (self%route_mode == Q_ROUTE_EXTERNAL) then
      role = mod(self%advance_calls - 1, 3) + 1
      attempt = (self%advance_calls - 1) / 3 + 1
    else
      role = ROLE_FULL
      attempt = self%advance_calls
    end if

    delta = t1 - t0
    select type (state)
    type is (qualification_state_t)
      state%water = state%water + delta
      state%generation = state%generation + 1
      state%last_role = role
    class default
      error stop 'F-VQ65 advance state type failure'
    end select

    outcome = trial_outcome_t()
    outcome%solver_ok = .true.
    outcome%mass_in = delta
    outcome%mass_out = 0.0_real64
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    outcome%temporal_certificate_available = .true.
    outcome%temporal_indicator = 0.0_real64

    select case (self%scenario)
    case (SC_SMALL_COMPLETE_RESIDUAL)
      outcome%mass_in = outcome%mass_in + SMALL_RESIDUAL_PERTURBATION
    case (SC_LARGE_COMPLETE_RESIDUAL)
      outcome%mass_in = outcome%mass_in + LARGE_RESIDUAL_PERTURBATION

    case (SC_EXT_FULL_OUTCOME_INCOMPLETE)
      if (self%route_mode == Q_ROUTE_EXTERNAL .and. role == ROLE_FULL) outcome%mass_accounting_complete = .false.
    case (SC_EXT_HALF1_OUTCOME_INCOMPLETE)
      if (self%route_mode == Q_ROUTE_EXTERNAL .and. role == ROLE_HALF1) outcome%mass_accounting_complete = .false.
    case (SC_EXT_HALF2_OUTCOME_INCOMPLETE)
      if (self%route_mode == Q_ROUTE_EXTERNAL .and. role == ROLE_HALF2) outcome%mass_accounting_complete = .false.
    case (SC_EXT_FULL_OUTCOME_MASK)
      if (self%route_mode == Q_ROUTE_EXTERNAL .and. role == ROLE_FULL) &
        outcome%missing_mass_contribution_mask = TX_MASS_MISSING_ACTIVE_CONTRIBUTION
    case (SC_EXT_HALF1_OUTCOME_MASK)
      if (self%route_mode == Q_ROUTE_EXTERNAL .and. role == ROLE_HALF1) &
        outcome%missing_mass_contribution_mask = TX_MASS_MISSING_ACTIVE_CONTRIBUTION
    case (SC_EXT_HALF2_OUTCOME_MASK)
      if (self%route_mode == Q_ROUTE_EXTERNAL .and. role == ROLE_HALF2) &
        outcome%missing_mass_contribution_mask = TX_MASS_MISSING_ACTIVE_CONTRIBUTION
    case (SC_EXT_NONFINITE_FULL_MASS)
      if (self%route_mode == Q_ROUTE_EXTERNAL .and. role == ROLE_FULL) &
        outcome%mass_in = ieee_value(0.0_real64, ieee_quiet_nan)
    case (SC_EXT_NONFINITE_HALF2_MASS)
      if (self%route_mode == Q_ROUTE_EXTERNAL .and. role == ROLE_HALF2) &
        outcome%mass_out = ieee_value(0.0_real64, ieee_quiet_nan)
    case (SC_EXT_RETRY_RECOVERY)
      if (self%route_mode == Q_ROUTE_EXTERNAL .and. attempt == 1) outcome%mass_accounting_complete = .false.

    case (SC_CERT_OUTCOME_INCOMPLETE)
      if (self%route_mode == Q_ROUTE_CERTIFICATE) outcome%mass_accounting_complete = .false.
    case (SC_CERT_OUTCOME_MASK)
      if (self%route_mode == Q_ROUTE_CERTIFICATE) &
        outcome%missing_mass_contribution_mask = TX_MASS_MISSING_ACTIVE_CONTRIBUTION
    case (SC_CERT_NONFINITE_MASS)
      if (self%route_mode == Q_ROUTE_CERTIFICATE) outcome%mass_in = ieee_value(0.0_real64, ieee_quiet_nan)
    case (SC_CERT_RETRY_RECOVERY)
      if (self%route_mode == Q_ROUTE_CERTIFICATE .and. attempt == 1) outcome%mass_accounting_complete = .false.
    case (SC_CERT_ALT_SOLVER_INCOMPLETE)
      if (self%route_mode == Q_ROUTE_CERTIFICATE) then
        outcome%mass_accounting_complete = .false.
        outcome%alternative_solver_calls = 1
      end if
    case default
      continue
    end select
  end subroutine qualification_advance

  real(real64) function qualification_storage(self, state) result(value)
    class(qualification_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state

    if (self%advance_calls < 0) error stop 'F-VQ65 unreachable model counter'
    select type (state)
    type is (qualification_state_t)
      value = state%water
    class default
      error stop 'F-VQ65 storage state type failure'
    end select
  end function qualification_storage

  subroutine qualification_storage_accounting_status(self, state, complete, missing_mask)
    class(qualification_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask

    complete = .true.
    missing_mask = TX_MASS_MISSING_NONE

    select type (state)
    type is (qualification_state_t)
      select case (self%scenario)
      case (SC_START_STORAGE_INCOMPLETE)
        if (state%generation == 0) complete = .false.
      case (SC_START_STORAGE_MASK)
        if (state%generation == 0) missing_mask = TX_MASS_MISSING_ACTIVE_CONTRIBUTION
      case (SC_EXT_FULL_STORAGE_INCOMPLETE)
        if (self%route_mode == Q_ROUTE_EXTERNAL .and. state%last_role == ROLE_FULL) complete = .false.
      case (SC_EXT_END_STORAGE_INCOMPLETE)
        if (self%route_mode == Q_ROUTE_EXTERNAL .and. state%last_role == ROLE_HALF2) complete = .false.
      case (SC_EXT_END_STORAGE_MASK)
        if (self%route_mode == Q_ROUTE_EXTERNAL .and. state%last_role == ROLE_HALF2) &
          missing_mask = TX_MASS_MISSING_ACTIVE_CONTRIBUTION
      case (SC_CERT_END_STORAGE_INCOMPLETE)
        if (self%route_mode == Q_ROUTE_CERTIFICATE .and. state%generation > 0) complete = .false.
      case (SC_CERT_END_STORAGE_MASK)
        if (self%route_mode == Q_ROUTE_CERTIFICATE .and. state%generation > 0) &
          missing_mask = TX_MASS_MISSING_ACTIVE_CONTRIBUTION
      case default
        continue
      end select
    class default
      error stop 'F-VQ65 storage accounting state type failure'
    end select
  end subroutine qualification_storage_accounting_status

  real(real64) function qualification_temporal_error(self, full_state, half_state) result(value)
    class(qualification_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state

    if (self%advance_calls < 0 .or. .not. same_type_as(full_state, half_state)) then
      error stop 'F-VQ65 temporal state mismatch'
    end if
    value = 0.0_real64
  end function qualification_temporal_error

end module fvq65_mass_attack_support
