module mod_fgc21p1_exact_bottom_interface_test_support
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t, canonical_physical_model_t
  implicit none

  type, extends(canonical_state_t) :: test_state_t
    real(real64) :: storage_value = 0.0_real64
  contains
    procedure :: clone => test_state_clone
  end type test_state_t

  type, extends(canonical_forcing_t) :: test_forcing_t
  end type test_forcing_t

  type, extends(canonical_physical_model_t) :: test_model_t
    logical :: temporal_difference = .false.
    logical :: publish_bottom = .true.
  contains
    procedure :: advance => test_advance
    procedure :: storage => test_storage
    procedure :: temporal_error => test_temporal_error
    procedure :: storage_accounting_status => test_storage_accounting_status
    procedure :: prepare_interval => test_prepare_interval
  end type test_model_t

contains

  subroutine new_state(state, value)
    class(transaction_state_t), allocatable, intent(out) :: state
    real(real64), intent(in) :: value
    allocate(test_state_t :: state)
    select type (s => state)
    type is (test_state_t)
      s%storage_value = value
    end select
  end subroutine new_state

  subroutine test_state_clone(self, copy)
    class(test_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(test_state_t :: copy)
    select type (s => copy)
    type is (test_state_t)
      s%storage_value = self%storage_value
    end select
  end subroutine test_state_clone

  subroutine test_prepare_interval(self, forcing, interval, config)
    class(test_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    if (.not. same_type_as(self, self) .or. .not. same_type_as(forcing, forcing) .or. &
        interval%t1 <= interval%t0 .or. config%max_committed_substeps <= 0) then
      error stop 'invalid synthetic canonical preparation'
    end if
  end subroutine test_prepare_interval

  subroutine test_advance(self, state, t0, t1, outcome)
    class(test_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: dt, exchange
    outcome = trial_outcome_t()
    dt = t1 - t0
    if (dt <= 0.0_real64) return
    exchange = dt * dt
    select type (s => state)
    type is (test_state_t)
      s%storage_value = s%storage_value - exchange
    class default
      return
    end select
    outcome%mass_in = 0.0_real64
    outcome%mass_out = exchange
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    if (self%publish_bottom) then
      outcome%bottom_interface_exchange_available = .true.
      outcome%bottom_outward_exchange_native = exchange
      outcome%terminal_bottom_outward_flux_native = 100.0_real64 + t1
    end if
    outcome%temporal_certificate_available = .true.
    outcome%temporal_indicator = 0.0_real64
    outcome%solver_ok = .true.
  end subroutine test_advance

  real(real64) function test_storage(self, state) result(value)
    class(test_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    if (.not. same_type_as(self, self)) error stop 'unreachable synthetic model'
    value = huge(0.0_real64)
    select type (s => state)
    type is (test_state_t)
      value = s%storage_value
    end select
  end function test_storage

  real(real64) function test_temporal_error(self, full_state, half_state) result(value)
    class(test_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state
    class(transaction_state_t), intent(in) :: half_state
    real(real64) :: full_value, half_value
    if (.not. self%temporal_difference) then
      value = 0.0_real64
      return
    end if
    full_value = huge(0.0_real64)
    half_value = huge(0.0_real64)
    select type (s => full_state)
    type is (test_state_t)
      full_value = s%storage_value
    end select
    select type (s => half_state)
    type is (test_state_t)
      half_value = s%storage_value
    end select
    value = abs(full_value - half_value)
  end function test_temporal_error

  subroutine test_storage_accounting_status(self, state, complete, missing_mask)
    class(test_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    complete = .false.
    missing_mask = 1_int64
    if (.not. same_type_as(self, self)) return
    select type (s => state)
    type is (test_state_t)
      if (s%storage_value > -huge(0.0_real64)) then
        complete = .true.
        missing_mask = TX_MASS_MISSING_NONE
      end if
    end select
  end subroutine test_storage_accounting_status

  subroutine fail(message)
    character(len=*), intent(in) :: message
    write(*,'(A)') 'FGC21P1_TEST_FAILURE: '//trim(message)
    error stop 1
  end subroutine fail

  subroutine state_close(state, expected, message)
    class(transaction_state_t), allocatable, intent(in) :: state
    real(real64), intent(in) :: expected
    character(len=*), intent(in) :: message
    select type (s => state)
    type is (test_state_t)
      call close_to(s%storage_value, expected, message)
    class default
      call fail(message)
    end select
  end subroutine state_close

  subroutine close_to(actual, expected, message)
    real(real64), intent(in) :: actual, expected
    character(len=*), intent(in) :: message
    if (abs(actual - expected) > 1.0e-12_real64) then
      write(*,*) 'actual=', actual, ' expected=', expected
      call fail(message)
    end if
  end subroutine close_to

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) call fail(message)
  end subroutine require

end module mod_fgc21p1_exact_bottom_interface_test_support

program test_fgc21p1_exact_bottom_interface_result
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, transaction_policy_t, transaction_result_t, &
       execute_reference_interval, TX_ROUTE_TWO_HALF, TX_ROUTE_MODEL_CERTIFIED, &
       TX_TEMPORAL_EXTERNAL_FULL_HALF, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t, canonical_interval_t, canonical_result_t, &
       CANONICAL_STATUS_COMPLETED, CANONICAL_STATUS_SUBSTEP_LIMIT
  use mod_canonical_interval_runtime, only: run_canonical_interval
  use mod_fgc21p1_exact_bottom_interface_test_support, only: test_model_t, test_forcing_t, new_state, &
       require, close_to, state_close
  implicit none

  type(test_model_t) :: model
  type(transaction_policy_t) :: policy
  type(transaction_result_t) :: tx
  type(canonical_numerical_config_t) :: config
  type(canonical_interval_t) :: interval
  type(canonical_result_t) :: result
  type(test_forcing_t) :: forcing
  class(transaction_state_t), allocatable :: committed

  call new_state(committed, 10.0_real64)
  model%temporal_difference = .false.
  model%publish_bottom = .true.
  policy = transaction_policy_t()
  policy%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
  policy%temporal_tolerance = 0.0_real64
  policy%mass_tolerance = 1.0e-12_real64
  call execute_reference_interval(model, committed, 0.0_real64, 2.0_real64, policy, tx)
  call require(tx%accepted_route == TX_ROUTE_TWO_HALF, 'two-half route not accepted')
  call require(tx%bottom_interface_exchange_available, 'two-half bottom exchange unavailable')
  call close_to(tx%accepted_bottom_outward_exchange_native, 2.0_real64, 'rejected full trial leaked into accepted exchange')
  call close_to(tx%terminal_bottom_outward_flux_native, 102.0_real64, 'wrong accepted terminal bottom flux')
  call close_to(tx%accepted_total_out, 2.0_real64, 'accepted mass route changed')
  call state_close(committed, 8.0_real64, 'two-half committed state mismatch')
  print *, 'FGC21P1_TWO_HALF_REJECTED_FULL_EXCLUDED=PASS'

  call new_state(committed, 10.0_real64)
  model%temporal_difference = .true.
  model%publish_bottom = .true.
  policy = transaction_policy_t()
  policy%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
  policy%temporal_tolerance = 0.75_real64
  policy%mass_tolerance = 1.0e-12_real64
  policy%retry_scale = 0.5_real64
  policy%max_retries = 2
  call execute_reference_interval(model, committed, 0.0_real64, 2.0_real64, policy, tx)
  call require(tx%accepted_route == TX_ROUTE_TWO_HALF, 'retry route not accepted')
  call require(tx%attempts == 2 .and. tx%retries == 1 .and. tx%rollbacks == 1, 'retry provenance mismatch')
  call close_to(tx%accepted_t1, 1.0_real64, 'retry accepted interval mismatch')
  call require(tx%bottom_interface_exchange_available, 'retry bottom exchange unavailable')
  call close_to(tx%accepted_bottom_outward_exchange_native, 0.5_real64, 'rejected retry exchange leaked')
  call close_to(tx%terminal_bottom_outward_flux_native, 101.0_real64, 'retry terminal flux mismatch')
  call state_close(committed, 9.5_real64, 'retry committed state mismatch')
  print *, 'FGC21P1_RETRY_REJECTED_EXCHANGE_EXCLUDED=PASS'

  call new_state(committed, 10.0_real64)
  model%temporal_difference = .false.
  model%publish_bottom = .true.
  policy = transaction_policy_t()
  policy%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
  policy%mass_tolerance = 1.0e-12_real64
  call execute_reference_interval(model, committed, 0.0_real64, 2.0_real64, policy, tx)
  call require(tx%accepted_route == TX_ROUTE_MODEL_CERTIFIED, 'model-certificate route not accepted')
  call require(tx%bottom_interface_exchange_available, 'model-certificate bottom exchange unavailable')
  call close_to(tx%accepted_bottom_outward_exchange_native, 4.0_real64, 'model-certificate exchange mismatch')
  call close_to(tx%terminal_bottom_outward_flux_native, 102.0_real64, 'model-certificate terminal flux mismatch')
  print *, 'FGC21P1_MODEL_CERTIFICATE_ACCEPTED_ONLY=PASS'

  call new_state(committed, 10.0_real64)
  model%temporal_difference = .false.
  model%publish_bottom = .false.
  policy = transaction_policy_t()
  policy%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
  policy%temporal_tolerance = 0.0_real64
  policy%mass_tolerance = 1.0e-12_real64
  call execute_reference_interval(model, committed, 0.0_real64, 1.0_real64, policy, tx)
  call require(.not. tx%bottom_interface_exchange_available, 'missing bottom exchange did not fail closed')
  call close_to(tx%accepted_bottom_outward_exchange_native, 0.0_real64, 'missing bottom exchange published value')
  print *, 'FGC21P1_MISSING_INTERFACE_RESULT_FAILS_CLOSED=PASS'

  call new_state(committed, 10.0_real64)
  model%temporal_difference = .true.
  model%publish_bottom = .true.
  config = canonical_numerical_config_t()
  config%transaction%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
  config%transaction%temporal_tolerance = 0.75_real64
  config%transaction%mass_tolerance = 1.0e-12_real64
  config%transaction%retry_scale = 0.5_real64
  config%transaction%max_retries = 2
  config%max_committed_substeps = 4
  interval%t0 = 0.0_real64
  interval%t1 = 2.0_real64
  call run_canonical_interval(model, committed, forcing, interval, config, result)
  call require(result%status == CANONICAL_STATUS_COMPLETED .and. result%completed, 'canonical interval did not complete')
  call require(result%mass%accepted_transaction_count == 2, 'canonical accepted-substep count mismatch')
  call require(result%bottom_interface_exchange_available, 'canonical whole-window exchange unavailable')
  call close_to(result%bottom_outward_exchange_native, 1.0_real64, 'canonical accepted exchange aggregation mismatch')
  call close_to(result%terminal_bottom_outward_flux_native, 102.0_real64, 'canonical terminal flux mismatch')
  call close_to(result%mass%total_out, 1.0_real64, 'canonical mass total changed')
  call state_close(committed, 9.0_real64, 'canonical committed state mismatch')
  print *, 'FGC21P1_CANONICAL_ACCEPTED_SUBSTEP_AGGREGATION=PASS'

  call new_state(committed, 10.0_real64)
  config%max_committed_substeps = 1
  call run_canonical_interval(model, committed, forcing, interval, config, result)
  call require(result%status == CANONICAL_STATUS_SUBSTEP_LIMIT .and. .not. result%completed, &
       'substep-limit failure not reproduced')
  call require(.not. result%bottom_interface_exchange_available, 'partial canonical exchange leaked on failed interval')
  call close_to(result%bottom_outward_exchange_native, 0.0_real64, 'failed canonical interval published exchange')
  call state_close(committed, 10.0_real64, 'failed canonical interval mutated external committed state')
  print *, 'FGC21P1_INCOMPLETE_CANONICAL_INTERVAL_NO_PUBLICATION=PASS'

  print *, 'FGC21P1_EXACT_BOTTOM_INTERFACE_RESULT_TEST PASS'

end program test_fgc21p1_exact_bottom_interface_result
