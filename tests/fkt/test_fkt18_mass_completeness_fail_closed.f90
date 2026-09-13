module fkt18_mass_test_support
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference, only: transaction_state_t, transaction_model_t, trial_outcome_t, &
       TX_MASS_MISSING_NONE
  implicit none

  type, extends(transaction_state_t) :: scalar_state_t
    real(real64) :: value = 0.0_real64
    logical :: storage_complete = .true.
    integer(int64) :: storage_missing_mask = TX_MASS_MISSING_NONE
  contains
    procedure :: clone => scalar_clone
  end type scalar_state_t

  type, extends(transaction_model_t) :: controlled_model_t
    logical :: trial_mass_complete = .true.
    integer(int64) :: trial_missing_mask = TX_MASS_MISSING_NONE
    logical :: inject_mass_error = .false.
    logical :: inject_nonfinite_mass = .false.
    integer :: alternative_solver_calls = 0
    integer :: advance_calls = 0
  contains
    procedure :: advance => controlled_advance
    procedure :: storage => controlled_storage
    procedure :: storage_accounting_status => controlled_storage_accounting_status
    procedure :: temporal_error => controlled_temporal_error
  end type controlled_model_t

contains

  subroutine scalar_clone(self, copy)
    class(scalar_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(scalar_state_t :: copy)
    select type (copy)
    type is (scalar_state_t)
      copy = self
    class default
      error stop 'FKT18 clone type failure'
    end select
  end subroutine scalar_clone

  subroutine controlled_advance(self, state, t0, t1, outcome)
    class(controlled_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: delta

    self%advance_calls = self%advance_calls + 1
    delta = t1 - t0
    select type (state)
    type is (scalar_state_t)
      state%value = state%value + delta
    class default
      error stop 'FKT18 advance state type failure'
    end select

    outcome = trial_outcome_t()
    outcome%solver_ok = .true.
    outcome%mass_in = delta
    outcome%mass_out = 0.0_real64
    if (self%inject_mass_error) outcome%mass_in = outcome%mass_in + 1.0e-3_real64
    if (self%inject_nonfinite_mass) outcome%mass_in = ieee_value(0.0_real64, ieee_quiet_nan)
    outcome%mass_accounting_complete = self%trial_mass_complete
    outcome%missing_mass_contribution_mask = self%trial_missing_mask
    outcome%temporal_certificate_available = .true.
    outcome%temporal_indicator = 0.0_real64
    outcome%alternative_solver_calls = self%alternative_solver_calls
  end subroutine controlled_advance

  real(real64) function controlled_storage(self, state) result(value)
    class(controlled_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    if (self%advance_calls < 0) error stop 'unreachable FKT18 model state'
    select type (state)
    type is (scalar_state_t)
      value = state%value
    class default
      error stop 'FKT18 storage state type failure'
    end select
  end function controlled_storage

  subroutine controlled_storage_accounting_status(self, state, complete, missing_mask)
    class(controlled_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    if (self%advance_calls < 0) error stop 'unreachable FKT18 storage status'
    select type (state)
    type is (scalar_state_t)
      complete = state%storage_complete
      missing_mask = state%storage_missing_mask
    class default
      error stop 'FKT18 storage accounting state type failure'
    end select
  end subroutine controlled_storage_accounting_status

  real(real64) function controlled_temporal_error(self, full_state, half_state) result(value)
    class(controlled_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    if (self%advance_calls < 0 .or. .not. same_type_as(full_state, half_state)) then
      error stop 'unreachable FKT18 temporal state'
    end if
    value = 0.0_real64
  end function controlled_temporal_error

end module fkt18_mass_test_support

program test_fkt18_mass_completeness_fail_closed
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, transaction_policy_t, transaction_result_t, &
       execute_reference_interval, TX_STATUS_ACCEPTED, TX_STATUS_RETRY_EXHAUSTED, TX_ROUTE_NONE, &
       TX_TEMPORAL_EXTERNAL_FULL_HALF, TX_TEMPORAL_MODEL_CERTIFICATE, TX_MASS_MISSING_NONE, &
       TX_MASS_MISSING_ACTIVE_CONTRIBUTION
  use fkt18_mass_test_support, only: scalar_state_t, controlled_model_t
  implicit none

  call case_incomplete_zero_residual_external()
  call case_nonzero_mask_model_certificate()
  call case_complete_external_accepts()
  call case_complete_residual_outside_tolerance_rejects()
  call case_alternative_solver_incomplete_rejects()
  call case_complete_model_certificate_accepts()
  call case_nonfinite_mass_rejects()
  print '(a)', 'FKT18_MASS_COMPLETENESS_FAIL_CLOSED_ORACLE=PASS'

contains

  subroutine init_state(committed, value)
    class(transaction_state_t), allocatable, intent(out) :: committed
    real(real64), intent(in) :: value
    allocate(scalar_state_t :: committed)
    select type (committed)
    type is (scalar_state_t)
      committed%value = value
      committed%storage_complete = .true.
      committed%storage_missing_mask = TX_MASS_MISSING_NONE
    class default
      error stop 'FKT18 init type failure'
    end select
  end subroutine init_state

  real(real64) function state_value(committed) result(value)
    class(transaction_state_t), allocatable, intent(in) :: committed
    select type (committed)
    type is (scalar_state_t)
      value = committed%value
    class default
      error stop 'FKT18 state value type failure'
    end select
  end function state_value

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write (*, '(a)') 'FKT18_FAIL:' // trim(message)
      error stop 1
    end if
  end subroutine require

  function base_policy(mode, max_retries) result(policy)
    integer, intent(in) :: mode, max_retries
    type(transaction_policy_t) :: policy
    policy%temporal_mode = mode
    policy%temporal_tolerance = 1.0e-12_real64
    policy%mass_tolerance = 1.0e-12_real64
    policy%retry_scale = 0.5_real64
    policy%max_retries = max_retries
  end function base_policy

  subroutine case_incomplete_zero_residual_external()
    class(transaction_state_t), allocatable :: committed
    type(controlled_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result

    call init_state(committed, 7.0_real64)
    model%trial_mass_complete = .false.
    model%trial_missing_mask = TX_MASS_MISSING_NONE
    policy = base_policy(TX_TEMPORAL_EXTERNAL_FULL_HALF, 2)
    call execute_reference_interval(model, committed, 10.0_real64, 12.0_real64, policy, result)

    call require(result%status == TX_STATUS_RETRY_EXHAUSTED, 'incomplete zero residual accepted')
    call require(result%mass_rejections == 3, 'incomplete zero residual not classified as mass rejection')
    call require(result%retries == 2 .and. result%rollbacks == 3, 'bounded retry accounting wrong')
    call require(result%commits == 0 .and. result%accepted_route == TX_ROUTE_NONE, 'commit reachable after incomplete rejection')
    call require(state_value(committed) == 7.0_real64, 'committed state changed across incomplete retries')
    call require(model%advance_calls == 9, 'unexpected full-half retry call count')
    print '(a)', 'FKT18_INCOMPLETE_ZERO_RESIDUAL_FAIL_CLOSED=PASS'
    print '(a)', 'FKT18_RETRY_EXHAUSTION_AND_STATE_IMMUTABILITY=PASS'
  end subroutine case_incomplete_zero_residual_external

  subroutine case_nonzero_mask_model_certificate()
    class(transaction_state_t), allocatable :: committed
    type(controlled_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result

    call init_state(committed, 3.0_real64)
    model%trial_mass_complete = .true.
    model%trial_missing_mask = TX_MASS_MISSING_ACTIVE_CONTRIBUTION
    policy = base_policy(TX_TEMPORAL_MODEL_CERTIFICATE, 1)
    call execute_reference_interval(model, committed, 0.25_real64, 1.25_real64, policy, result)

    call require(result%status == TX_STATUS_RETRY_EXHAUSTED, 'nonzero missing mask accepted')
    call require(result%mass_rejections == 2, 'missing mask not classified as mass rejection')
    call require(result%commits == 0, 'certificate route committed missing mask')
    call require(state_value(committed) == 3.0_real64, 'certificate rejection changed committed state')
    print '(a)', 'FKT18_NONZERO_MISSING_MASK_FAIL_CLOSED=PASS'
  end subroutine case_nonzero_mask_model_certificate

  subroutine case_complete_external_accepts()
    class(transaction_state_t), allocatable :: committed
    type(controlled_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result

    call init_state(committed, 1.5_real64)
    policy = base_policy(TX_TEMPORAL_EXTERNAL_FULL_HALF, 1)
    call execute_reference_interval(model, committed, 2.0_real64, 4.0_real64, policy, result)

    call require(result%status == TX_STATUS_ACCEPTED, 'complete external ledger rejected')
    call require(result%commits == 1 .and. result%mass_rejections == 0, 'complete external acceptance counters wrong')
    call require(result%accepted_mass_complete, 'accepted external ledger not marked complete')
    call require(result%accepted_missing_contribution_mask == TX_MASS_MISSING_NONE, 'accepted external mask nonzero')
    call require(abs(result%accepted_mass_residual) <= policy%mass_tolerance, 'accepted external residual outside tolerance')
    call require(state_value(committed) == 3.5_real64, 'complete external state not committed')
    print '(a)', 'FKT18_COMPLETE_LEDGER_WITHIN_TOLERANCE_ACCEPTS=PASS'
  end subroutine case_complete_external_accepts

  subroutine case_complete_residual_outside_tolerance_rejects()
    class(transaction_state_t), allocatable :: committed
    type(controlled_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result

    call init_state(committed, 5.0_real64)
    model%inject_mass_error = .true.
    policy = base_policy(TX_TEMPORAL_MODEL_CERTIFICATE, 1)
    call execute_reference_interval(model, committed, 0.0_real64, 1.0_real64, policy, result)

    call require(result%status == TX_STATUS_RETRY_EXHAUSTED, 'out-of-tolerance residual accepted')
    call require(result%mass_rejections == 2 .and. result%commits == 0, 'residual rejection counters wrong')
    call require(state_value(committed) == 5.0_real64, 'residual rejection changed committed state')
    print '(a)', 'FKT18_COMPLETE_LEDGER_OUTSIDE_TOLERANCE_REJECTS=PASS'
  end subroutine case_complete_residual_outside_tolerance_rejects

  subroutine case_alternative_solver_incomplete_rejects()
    class(transaction_state_t), allocatable :: committed
    type(controlled_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result

    call init_state(committed, 11.0_real64)
    model%trial_mass_complete = .false.
    model%alternative_solver_calls = 1
    policy = base_policy(TX_TEMPORAL_MODEL_CERTIFICATE, 0)
    call execute_reference_interval(model, committed, 4.0_real64, 4.5_real64, policy, result)

    call require(result%status == TX_STATUS_RETRY_EXHAUSTED, 'alternative solver incomplete ledger accepted')
    call require(result%alternative_solver_calls == 1, 'alternative solver path not exercised')
    call require(result%mass_rejections == 1 .and. result%commits == 0, 'alternative incomplete rejection wrong')
    call require(state_value(committed) == 11.0_real64, 'alternative incomplete rejection changed state')
    print '(a)', 'FKT18_ALTERNATIVE_SOLVER_INCOMPLETE_LEDGER_FAIL_CLOSED=PASS'
  end subroutine case_alternative_solver_incomplete_rejects

  subroutine case_complete_model_certificate_accepts()
    class(transaction_state_t), allocatable :: committed
    type(controlled_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result

    call init_state(committed, -2.0_real64)
    policy = base_policy(TX_TEMPORAL_MODEL_CERTIFICATE, 1)
    call execute_reference_interval(model, committed, 1.0_real64, 1.75_real64, policy, result)

    call require(result%status == TX_STATUS_ACCEPTED, 'complete certificate ledger rejected')
    call require(result%commits == 1 .and. result%mass_rejections == 0, 'certificate acceptance counters wrong')
    call require(result%accepted_mass_complete, 'accepted certificate ledger not complete')
    call require(result%accepted_missing_contribution_mask == TX_MASS_MISSING_NONE, 'accepted certificate mask nonzero')
    call require(state_value(committed) == -1.25_real64, 'certificate state not committed')
    print '(a)', 'FKT18_COMPLETE_MODEL_CERTIFICATE_ACCEPTS=PASS'
  end subroutine case_complete_model_certificate_accepts

  subroutine case_nonfinite_mass_rejects()
    class(transaction_state_t), allocatable :: committed
    type(controlled_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result

    call init_state(committed, 13.0_real64)
    model%inject_nonfinite_mass = .true.
    policy = base_policy(TX_TEMPORAL_MODEL_CERTIFICATE, 0)
    call execute_reference_interval(model, committed, 0.0_real64, 0.5_real64, policy, result)

    call require(result%status == TX_STATUS_RETRY_EXHAUSTED, 'nonfinite mass term accepted')
    call require(result%mass_rejections == 1 .and. result%commits == 0, 'nonfinite mass rejection counters wrong')
    call require(state_value(committed) == 13.0_real64, 'nonfinite mass rejection changed committed state')
    print '(a)', 'FKT18_NONFINITE_MASS_FAIL_CLOSED=PASS'
  end subroutine case_nonfinite_mass_rejects

end program test_fkt18_mass_completeness_fail_closed
