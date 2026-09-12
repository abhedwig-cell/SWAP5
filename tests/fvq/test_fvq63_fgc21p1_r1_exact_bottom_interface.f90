module mod_fvq63_bottom_exchange_support
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_positive_inf
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t, canonical_physical_model_t
  implicit none

  type, extends(canonical_state_t) :: fvq63_state_t
    real(real64) :: storage_value = 0.0_real64
  contains
    procedure :: clone => fvq63_clone
  end type fvq63_state_t

  type, extends(canonical_forcing_t) :: fvq63_forcing_t
  end type fvq63_forcing_t

  type, extends(canonical_physical_model_t) :: fvq63_model_t
    logical :: temporal_from_state_difference = .false.
    integer :: bottom_mode = 1 ! 0=absent, 1=finite, 2=positive infinity
  contains
    procedure :: advance => fvq63_advance
    procedure :: storage => fvq63_storage
    procedure :: temporal_error => fvq63_temporal_error
    procedure :: storage_accounting_status => fvq63_storage_status
    procedure :: prepare_interval => fvq63_prepare
  end type fvq63_model_t

contains

  subroutine fvq63_new_state(state, value)
    class(transaction_state_t), allocatable, intent(out) :: state
    real(real64), intent(in) :: value
    allocate(fvq63_state_t :: state)
    select type (s => state)
    type is (fvq63_state_t)
      s%storage_value = value
    end select
  end subroutine fvq63_new_state

  subroutine fvq63_clone(self, copy)
    class(fvq63_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fvq63_state_t :: copy)
    select type (s => copy)
    type is (fvq63_state_t)
      s%storage_value = self%storage_value
    end select
  end subroutine fvq63_clone

  subroutine fvq63_prepare(self, forcing, interval, config)
    class(fvq63_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    if (.not. same_type_as(self,self) .or. .not. same_type_as(forcing,forcing)) error stop 'FVQ63 prepare type'
    if (interval%t1 <= interval%t0 .or. config%max_committed_substeps <= 0) error stop 'FVQ63 prepare interval'
  end subroutine fvq63_prepare

  pure real(real64) function exchange_for_dt(dt) result(exchange)
    real(real64), intent(in) :: dt
    exchange = dt * dt * dt + 0.5_real64 * dt
  end function exchange_for_dt

  subroutine fvq63_advance(self, state, t0, t1, outcome)
    class(fvq63_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: dt, exchange

    outcome = trial_outcome_t()
    dt = t1 - t0
    if (dt <= 0.0_real64) return
    exchange = exchange_for_dt(dt)
    select type (s => state)
    type is (fvq63_state_t)
      s%storage_value = s%storage_value - exchange
    class default
      return
    end select
    outcome%solver_ok = .true.
    outcome%mass_in = 0.0_real64
    outcome%mass_out = exchange
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    outcome%temporal_certificate_available = .true.
    outcome%temporal_indicator = 0.0_real64
    if (self%bottom_mode /= 0) then
      outcome%bottom_interface_exchange_available = .true.
      if (self%bottom_mode == 2) then
        outcome%bottom_outward_exchange_native = ieee_value(0.0_real64, ieee_positive_inf)
      else
        outcome%bottom_outward_exchange_native = exchange
      end if
      outcome%terminal_bottom_outward_flux_native = 1000.0_real64 + t0 + 10.0_real64 * dt
    end if
  end subroutine fvq63_advance

  real(real64) function fvq63_storage(self, state) result(value)
    class(fvq63_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    if (.not. same_type_as(self,self)) error stop 'FVQ63 storage type'
    value = huge(0.0_real64)
    select type (s => state)
    type is (fvq63_state_t)
      value = s%storage_value
    end select
  end function fvq63_storage

  real(real64) function fvq63_temporal_error(self, full_state, half_state) result(value)
    class(fvq63_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    real(real64) :: full_storage, half_storage
    if (.not. self%temporal_from_state_difference) then
      value = 0.0_real64
      return
    end if
    full_storage = huge(0.0_real64)
    half_storage = huge(0.0_real64)
    select type (s => full_state)
    type is (fvq63_state_t)
      full_storage = s%storage_value
    end select
    select type (s => half_state)
    type is (fvq63_state_t)
      half_storage = s%storage_value
    end select
    value = abs(full_storage - half_storage)
  end function fvq63_temporal_error

  subroutine fvq63_storage_status(self, state, complete, missing_mask)
    class(fvq63_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    complete = .false.
    missing_mask = 1_int64
    if (.not. same_type_as(self,self)) return
    select type (s => state)
    type is (fvq63_state_t)
      if (abs(s%storage_value) < huge(0.0_real64)) then
        complete = .true.
        missing_mask = TX_MASS_MISSING_NONE
      end if
    end select
  end subroutine fvq63_storage_status

  subroutine require_true(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(A)') 'FVQ63_FAILURE: '//trim(message)
      error stop 1
    end if
  end subroutine require_true

  subroutine require_close(actual, expected, message)
    real(real64), intent(in) :: actual, expected
    character(len=*), intent(in) :: message
    if (abs(actual - expected) > 1.0e-12_real64) then
      write(*,*) 'FVQ63 actual=',actual,' expected=',expected
      call require_true(.false., message)
    end if
  end subroutine require_close

  subroutine require_state(state, expected, message)
    class(transaction_state_t), allocatable, intent(in) :: state
    real(real64), intent(in) :: expected
    character(len=*), intent(in) :: message
    select type (s => state)
    type is (fvq63_state_t)
      call require_close(s%storage_value, expected, message)
    class default
      call require_true(.false., message)
    end select
  end subroutine require_state

end module mod_fvq63_bottom_exchange_support

program test_fvq63_fgc21p1_r1_exact_bottom_interface
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, transaction_policy_t, transaction_result_t, &
       execute_reference_interval, TX_ROUTE_TWO_HALF, TX_ROUTE_MODEL_CERTIFIED, &
       TX_TEMPORAL_EXTERNAL_FULL_HALF, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t, canonical_interval_t, canonical_result_t, &
       CANONICAL_STATUS_COMPLETED, CANONICAL_STATUS_SUBSTEP_LIMIT
  use mod_canonical_interval_runtime, only: run_canonical_interval
  use mod_fvq63_bottom_exchange_support, only: fvq63_model_t, fvq63_forcing_t, fvq63_new_state, &
       require_true, require_close, require_state
  implicit none

  type(fvq63_model_t) :: model
  type(fvq63_forcing_t) :: forcing
  type(transaction_policy_t) :: policy
  type(transaction_result_t) :: tx
  type(canonical_numerical_config_t) :: config
  type(canonical_interval_t) :: interval
  type(canonical_result_t) :: result
  class(transaction_state_t), allocatable :: committed

  ! Independent case A: full trial exchange is 28.5, accepted halves sum to 8.25.
  ! A leaked rejected-full contribution therefore cannot accidentally match the expected value.
  call fvq63_new_state(committed, 100.0_real64)
  model%temporal_from_state_difference = .false.
  model%bottom_mode = 1
  policy = transaction_policy_t()
  policy%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
  policy%temporal_tolerance = 0.0_real64
  policy%mass_tolerance = 1.0e-12_real64
  call execute_reference_interval(model, committed, 1.0_real64, 4.0_real64, policy, tx)
  call require_true(tx%accepted_route == TX_ROUTE_TWO_HALF, 'case A route')
  call require_true(tx%bottom_interface_exchange_available, 'case A exchange availability')
  call require_close(tx%accepted_bottom_outward_exchange_native, 8.25_real64, 'case A rejected full exchange leaked')
  call require_close(tx%accepted_total_out, 8.25_real64, 'case A mass total')
  call require_close(tx%terminal_bottom_outward_flux_native, 1017.5_real64, 'case A terminal accepted-half flux')
  call require_state(committed, 91.75_real64, 'case A committed state')
  print *, 'FVQ63_REJECTED_FULL_EXCHANGE_EXCLUDED=PASS'

  ! Independent case B: first 4-unit attempt has temporal error 48 and is rejected;
  ! retry at 2 units has error 6 and accepts two 1-unit halves, exchange 3.
  call fvq63_new_state(committed, 100.0_real64)
  model%temporal_from_state_difference = .true.
  model%bottom_mode = 1
  policy = transaction_policy_t()
  policy%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
  policy%temporal_tolerance = 10.0_real64
  policy%mass_tolerance = 1.0e-12_real64
  policy%retry_scale = 0.5_real64
  policy%max_retries = 2
  call execute_reference_interval(model, committed, 5.0_real64, 9.0_real64, policy, tx)
  call require_true(tx%accepted_route == TX_ROUTE_TWO_HALF, 'case B route')
  call require_true(tx%attempts == 2 .and. tx%retries == 1 .and. tx%rollbacks == 1, 'case B retry provenance')
  call require_close(tx%accepted_t1, 7.0_real64, 'case B accepted endpoint')
  call require_close(tx%accepted_bottom_outward_exchange_native, 3.0_real64, 'case B rejected retry exchange leaked')
  call require_close(tx%terminal_bottom_outward_flux_native, 1016.0_real64, 'case B terminal flux')
  call require_state(committed, 97.0_real64, 'case B committed state')
  print *, 'FVQ63_RETRY_EXCHANGE_EXCLUDED=PASS'

  ! Independent case C: direct model-certificate acceptance must expose the one accepted trial only.
  call fvq63_new_state(committed, 100.0_real64)
  model%temporal_from_state_difference = .false.
  model%bottom_mode = 1
  policy = transaction_policy_t()
  policy%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
  policy%mass_tolerance = 1.0e-12_real64
  call execute_reference_interval(model, committed, 2.0_real64, 5.0_real64, policy, tx)
  call require_true(tx%accepted_route == TX_ROUTE_MODEL_CERTIFIED, 'case C model certificate route')
  call require_true(tx%bottom_interface_exchange_available, 'case C exchange availability')
  call require_close(tx%accepted_bottom_outward_exchange_native, 28.5_real64, 'case C exchange')
  call require_close(tx%terminal_bottom_outward_flux_native, 1032.0_real64, 'case C terminal flux')
  call require_state(committed, 71.5_real64, 'case C committed state')
  print *, 'FVQ63_MODEL_CERTIFICATE_EXCHANGE=PASS'

  ! Independent case D: missing and nonfinite interface exchange both fail closed while mass still commits.
  call fvq63_new_state(committed, 100.0_real64)
  model%bottom_mode = 0
  policy = transaction_policy_t()
  policy%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
  policy%temporal_tolerance = 0.0_real64
  policy%mass_tolerance = 1.0e-12_real64
  call execute_reference_interval(model, committed, 0.0_real64, 2.0_real64, policy, tx)
  call require_true(.not. tx%bottom_interface_exchange_available, 'case D missing exchange availability')
  call require_close(tx%accepted_bottom_outward_exchange_native, 0.0_real64, 'case D missing exchange value')
  call require_state(committed, 97.0_real64, 'case D missing exchange state')

  call fvq63_new_state(committed, 100.0_real64)
  model%bottom_mode = 2
  call execute_reference_interval(model, committed, 0.0_real64, 2.0_real64, policy, tx)
  call require_true(.not. tx%bottom_interface_exchange_available, 'case D nonfinite exchange did not fail closed')
  call require_close(tx%accepted_bottom_outward_exchange_native, 0.0_real64, 'case D nonfinite exchange value')
  call require_close(tx%terminal_bottom_outward_flux_native, 0.0_real64, 'case D nonfinite terminal reset')
  call require_state(committed, 97.0_real64, 'case D nonfinite exchange state')
  print *, 'FVQ63_MISSING_AND_NONFINITE_EXCHANGE_FAIL_CLOSED=PASS'

  ! Independent case E: canonical interval composes two accepted retry-limited substeps.
  call fvq63_new_state(committed, 100.0_real64)
  model%temporal_from_state_difference = .true.
  model%bottom_mode = 1
  config = canonical_numerical_config_t()
  config%transaction%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
  config%transaction%temporal_tolerance = 10.0_real64
  config%transaction%mass_tolerance = 1.0e-12_real64
  config%transaction%retry_scale = 0.5_real64
  config%transaction%max_retries = 2
  config%max_committed_substeps = 4
  interval%t0 = 5.0_real64
  interval%t1 = 9.0_real64
  call run_canonical_interval(model, committed, forcing, interval, config, result)
  call require_true(result%status == CANONICAL_STATUS_COMPLETED .and. result%completed, 'case E completion')
  call require_true(result%mass%accepted_transaction_count == 2, 'case E accepted transaction count')
  call require_true(result%bottom_interface_exchange_available, 'case E exchange availability')
  call require_close(result%bottom_outward_exchange_native, 6.0_real64, 'case E canonical aggregate')
  call require_close(result%terminal_bottom_outward_flux_native, 1018.0_real64, 'case E terminal flux')
  call require_close(result%mass%total_out, 6.0_real64, 'case E mass total')
  call require_close(result%mass%residual, 0.0_real64, 'case E exact mass residual')
  call require_state(committed, 94.0_real64, 'case E committed state')
  print *, 'FVQ63_CANONICAL_ACCEPTED_AGGREGATE_AND_MASS=PASS'

  ! Independent case F: partial canonical progress must not escape the private working state.
  call fvq63_new_state(committed, 100.0_real64)
  config%max_committed_substeps = 1
  call run_canonical_interval(model, committed, forcing, interval, config, result)
  call require_true(result%status == CANONICAL_STATUS_SUBSTEP_LIMIT .and. .not. result%completed, 'case F substep limit')
  call require_true(.not. result%bottom_interface_exchange_available, 'case F partial exchange publication')
  call require_close(result%bottom_outward_exchange_native, 0.0_real64, 'case F partial exchange value')
  call require_state(committed, 100.0_real64, 'case F external committed state changed')
  print *, 'FVQ63_PARTIAL_CANONICAL_ROLLBACK_NO_PUBLICATION=PASS'

  print *, 'FVQ63_INDEPENDENT_EXACT_BOTTOM_INTERFACE_QUALIFICATION PASS'
end program test_fvq63_fgc21p1_r1_exact_bottom_interface
