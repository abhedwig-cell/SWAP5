program test_fkt21_transaction_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_result_t, TX_STATUS_ACCEPTED, TX_STATUS_RETRY_EXHAUSTED
  use mod_soil_water_accepted_step_direction_contract, only: &
       soil_water_accepted_step_direction_request_t, soil_water_accepted_step_direction_result_t, &
       SW_STEP_DIRECTION_AVAILABLE, SW_STEP_CONTROL_BOTTOM_HEAD
  use mod_accepted_trajectory_directional_sensitivity, only: accepted_trajectory_direction_t, trajectory_step_token_t, &
       configure_trajectory_direction, begin_or_continue_trajectory, build_trajectory_step_request, &
       stage_trajectory_step_result, accept_trajectory_step, finalize_trajectory_direction
  use mod_accepted_trajectory_directional_publication, only: accepted_trajectory_direction_result_t
  use mod_accepted_trajectory_transaction_binding, only: bind_accepted_trajectory_to_transaction
  implicit none

  type(accepted_trajectory_direction_t) :: state
  type(trajectory_step_token_t) :: token
  type(soil_water_accepted_step_direction_request_t) :: request
  type(soil_water_accepted_step_direction_result_t) :: step_result
  type(transaction_result_t) :: tx
  type(accepted_trajectory_direction_result_t) :: publication
  logical :: ok
  real(real64), parameter :: tol = 1.0e-13_real64

  call configure_trajectory_direction(state, .true.)
  call begin_or_continue_trajectory(state, 9, 3.25_real64, 3.75_real64, SW_STEP_CONTROL_BOTTOM_HEAD, 2, ok, &
       generation_seed=7001_int64)
  call require(ok, 'trajectory begin')
  call build_trajectory_step_request(state, 3.25_real64, 3.75_real64, request, token, ok)
  call require(ok, 'step request')
  call make_step_result(step_result)
  call stage_trajectory_step_result(state, token, step_result, ok)
  call require(ok, 'stage')
  call accept_trajectory_step(state, ok)
  call require(ok, 'accept')
  call finalize_trajectory_direction(state, 3.25_real64, 3.75_real64, ok)
  call require(ok, 'finalize')

  ! A shortened outer retry interval is a valid accepted trajectory segment.
  ! Its accepted_t1 remains explicit and must not be silently relabelled as the
  ! original requested_t1=4.0 whole window.
  tx = transaction_result_t()
  tx%status = TX_STATUS_ACCEPTED
  tx%commits = 1
  tx%requested_t0 = 3.25_real64
  tx%requested_t1 = 4.0_real64
  tx%accepted_t1 = 3.75_real64
  tx%accepted_dt = 0.5_real64
  call bind_accepted_trajectory_to_transaction(tx, state, publication)
  call require(publication%available, 'accepted shortened segment publication')
  call require(abs(publication%origin_t0-3.25_real64) <= tol, 'accepted origin')
  call require(abs(publication%accepted_t1-3.75_real64) <= tol, 'accepted endpoint')
  call require(abs(publication%accepted_bottom_exchange_derivative-2.0_real64) <= tol, 'accepted derivative')
  write(*,'(a)') 'FKT21_ACCEPTED_TRANSACTION_BINDING=PASS'
  write(*,'(a)') 'FKT21_SHORTENED_INTERVAL_NOT_RELABELLED=PASS'

  tx%status = TX_STATUS_RETRY_EXHAUSTED
  tx%commits = 0
  call bind_accepted_trajectory_to_transaction(tx, state, publication)
  call require(.not. publication%available, 'retry exhaustion unavailable')
  call require(trim(publication%route) == 'transaction-not-accepted', 'retry exhaustion route')
  write(*,'(a)') 'FKT21_RETRY_EXHAUSTION_TRANSACTION_NO_PUBLICATION=PASS'

  tx%status = TX_STATUS_ACCEPTED
  tx%commits = 1
  tx%requested_t0 = 3.20_real64
  tx%requested_t1 = 4.0_real64
  tx%accepted_t1 = 3.75_real64
  call bind_accepted_trajectory_to_transaction(tx, state, publication)
  call require(.not. publication%available, 'provenance mismatch unavailable')
  call require(trim(publication%route) == 'accepted-transaction-provenance-mismatch', 'provenance mismatch route')
  write(*,'(a)') 'FKT21_TRANSACTION_PROVENANCE_MISMATCH_REJECTED=PASS'

  tx%requested_t0 = 3.25_real64
  tx%accepted_t1 = 4.25_real64
  call bind_accepted_trajectory_to_transaction(tx, state, publication)
  call require(.not. publication%available, 'invalid accepted interval unavailable')
  write(*,'(a)') 'FKT21_TRANSACTION_INTERVAL_GUARD=PASS'

  write(*,'(a)') 'FKT21_TRANSACTION_BINDING PASS'

contains

  subroutine make_step_result(value)
    type(soil_water_accepted_step_direction_result_t), intent(out) :: value
    value = soil_water_accepted_step_direction_result_t()
    value%status = SW_STEP_DIRECTION_AVAILABLE
    value%available = .true.
    value%fixed_smooth_route = .true.
    value%control_coordinate = SW_STEP_CONTROL_BOTTOM_HEAD
    value%method = 'test-step'
    value%route = 'test-smooth-route'
    allocate(value%outgoing_pressure_head(2), value%outgoing_water_content(2))
    value%outgoing_pressure_head = [1.5_real64, 2.5_real64]
    value%outgoing_water_content = [0.15_real64, 0.25_real64]
    value%outgoing_ponding_depth = 0.05_real64
    value%bottom_flux_derivative = 4.0_real64
    value%additional_tridiagonal_backsolves = 1
  end subroutine make_step_result

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a,1x,a)') 'FKT21_TRANSACTION_BINDING FAIL', trim(message)
      error stop 1
    end if
  end subroutine require

end program test_fkt21_transaction_binding
