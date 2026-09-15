program test_fvq92_fkt21_independent
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_accepted_step_direction_contract, only: &
       soil_water_accepted_step_direction_request_t, soil_water_accepted_step_direction_result_t, &
       SW_STEP_DIRECTION_AVAILABLE, SW_STEP_CONTROL_BOTTOM_HEAD
  use mod_accepted_trajectory_directional_sensitivity, only: &
       accepted_trajectory_direction_t, trajectory_step_token_t, &
       TRAJECTORY_DIRECTION_FAILED, configure_trajectory_direction, begin_or_continue_trajectory, &
       build_trajectory_step_request, stage_trajectory_step_result, accept_trajectory_step, &
       discard_trajectory_step, finalize_trajectory_direction
  use mod_accepted_trajectory_directional_publication, only: accepted_trajectory_direction_result_t
  use mod_accepted_trajectory_transaction_binding, only: bind_accepted_trajectory_to_transaction
  use mod_transaction_reference, only: transaction_result_t, TX_STATUS_ACCEPTED, TX_STATUS_RETRY_EXHAUSTED
  implicit none

  call test_whole_window_centered_fd()
  call test_rejected_step_cannot_leak()
  call test_retry_aba_token_rejected()
  call test_transaction_publication_guards()
  call test_shortened_interval_keeps_actual_endpoint()

  print '(A)', 'FVQ92_WHOLE_WINDOW_CENTERED_FD=PASS'
  print '(A)', 'FVQ92_REJECTED_STEP_NO_LEAK=PASS'
  print '(A)', 'FVQ92_RETRY_ABA_REJECTED=PASS'
  print '(A)', 'FVQ92_TRANSACTION_PUBLICATION_GUARDS=PASS'
  print '(A)', 'FVQ92_SHORTENED_INTERVAL_PROVENANCE=PASS'
  print '(A)', 'F_VQ92_INDEPENDENT_ORACLE=PASS'

contains

  subroutine test_whole_window_centered_fd()
    type(accepted_trajectory_direction_t) :: state
    type(soil_water_accepted_step_direction_request_t) :: request
    type(soil_water_accepted_step_direction_result_t) :: step_result
    type(trajectory_step_token_t) :: token
    type(transaction_result_t) :: tx
    type(accepted_trajectory_direction_result_t) :: published
    real(real64), parameter :: p = 0.37_real64, eps = 1.0e-6_real64
    real(real64), parameter :: times(4) = [0.125_real64, 0.375_real64, 0.625_real64, 0.875_real64]
    real(real64) :: h(2), hnext(2), dh(2), dhnext(2), q, dq
    real(real64) :: hp(2), hm(2), qp, qm, fd_h(2), fd_q
    integer :: k
    logical :: ok

    h = [-0.6_real64, 0.9_real64]
    dh = 0.0_real64
    call configure_trajectory_direction(state, .true.)
    call begin_or_continue_trajectory(state, 17, times(1), times(4), SW_STEP_CONTROL_BOTTOM_HEAD, 2, ok, 41_int64)
    call require(ok, 'whole-window begin failed')

    do k = 1, 3
      call build_trajectory_step_request(state, times(k), times(k+1), request, token, ok)
      call require(ok, 'whole-window request failed')
      call require_close_vec(request%incoming_pressure_head, dh, 0.0_real64, 'request did not carry accepted incoming direction')
      call require_close(request%direct_control_derivative, 1.0_real64, 0.0_real64, 'control direction is not unit')

      call synthetic_step(h, p, times(k+1)-times(k), hnext, q)
      call synthetic_step_tangent(h, dh, p, times(k+1)-times(k), dhnext, dq)
      call make_available_result(step_result, dhnext, 0.25_real64*dhnext, 0.1_real64*sum(dhnext), dq, 'fvq92-synthetic-smooth')
      call stage_trajectory_step_result(state, token, step_result, ok)
      call require(ok, 'whole-window stage failed')
      call accept_trajectory_step(state, ok)
      call require(ok, 'whole-window accept failed')
      h = hnext
      dh = dhnext
    end do

    call finalize_trajectory_direction(state, times(1), times(4), ok)
    call require(ok, 'whole-window finalize failed')
    call simulate_window(p+eps, hp, qp)
    call simulate_window(p-eps, hm, qm)
    fd_h = (hp-hm)/(2.0_real64*eps)
    fd_q = (qp-qm)/(2.0_real64*eps)
    call require_close_vec(state%pressure_head_direction, fd_h, 5.0e-8_real64, 'whole-window state direction disagrees with independent FD')
    call require_close(state%integrated_bottom_exchange_derivative, fd_q, 5.0e-8_real64, &
         'whole-window exchange direction disagrees with independent FD')
    call require(state%accepted_steps == 3, 'wrong accepted-step count')

    tx = transaction_result_t()
    tx%status = TX_STATUS_ACCEPTED
    tx%commits = 1
    tx%requested_t0 = times(1)
    tx%requested_t1 = times(4)
    tx%accepted_t1 = times(4)
    call bind_accepted_trajectory_to_transaction(tx, state, published)
    call require(published%available, 'accepted transaction did not publish')
    call require(published%accepted_steps == 3, 'published accepted-step count wrong')
    call require_close_vec(published%final_pressure_head_direction, fd_h, 5.0e-8_real64, &
         'published state direction disagrees with FD')
    call require_close(published%accepted_bottom_exchange_derivative, fd_q, 5.0e-8_real64, &
         'published exchange direction disagrees with FD')
  end subroutine test_whole_window_centered_fd

  subroutine test_rejected_step_cannot_leak()
    type(accepted_trajectory_direction_t) :: state
    type(soil_water_accepted_step_direction_request_t) :: request
    type(soil_water_accepted_step_direction_result_t) :: result
    type(trajectory_step_token_t) :: token1, token2
    logical :: ok

    call configure_trajectory_direction(state, .true.)
    call begin_or_continue_trajectory(state, 9, 0.1_real64, 0.6_real64, SW_STEP_CONTROL_BOTTOM_HEAD, 2, ok, 77_int64)
    call require(ok, 'reject-leak begin failed')
    call build_trajectory_step_request(state, 0.1_real64, 0.3_real64, request, token1, ok)
    call require(ok, 'reject-leak first issue failed')
    call make_available_result(result, [9.0_real64, -9.0_real64], [4.0_real64, -4.0_real64], 3.0_real64, &
         100.0_real64, 'must-be-discarded')
    call stage_trajectory_step_result(state, token1, result, ok)
    call require(ok, 'reject-leak first stage failed')
    call discard_trajectory_step(state)
    call require(state%accepted_steps == 0, 'discarded step incremented accepted count')
    call require_close(state%current_t1, 0.1_real64, 0.0_real64, 'discarded step advanced time')
    call require_close(state%integrated_bottom_exchange_derivative, 0.0_real64, 0.0_real64, 'discarded exchange leaked')
    call require_close_vec(state%pressure_head_direction, [0.0_real64, 0.0_real64], 0.0_real64, 'discarded vector leaked')

    call build_trajectory_step_request(state, 0.1_real64, 0.3_real64, request, token2, ok)
    call require(ok, 'reject-leak retry issue failed')
    call require(token2%step_sequence > token1%step_sequence, 'retry token sequence did not advance')
    call make_available_result(result, [1.0_real64, 2.0_real64], [0.1_real64, 0.2_real64], 0.3_real64, &
         4.0_real64, 'accepted-retry')
    call stage_trajectory_step_result(state, token2, result, ok)
    call require(ok, 'reject-leak retry stage failed')
    call accept_trajectory_step(state, ok)
    call require(ok, 'reject-leak retry accept failed')
    call require(state%accepted_steps == 1, 'accepted retry count wrong')
    call require_close_vec(state%pressure_head_direction, [1.0_real64, 2.0_real64], 0.0_real64, 'accepted retry vector wrong')
    call require_close(state%integrated_bottom_exchange_derivative, 0.8_real64, 5.0e-15_real64, 'accepted retry exchange wrong')
  end subroutine test_rejected_step_cannot_leak

  subroutine test_retry_aba_token_rejected()
    type(accepted_trajectory_direction_t) :: state
    type(soil_water_accepted_step_direction_request_t) :: request
    type(soil_water_accepted_step_direction_result_t) :: result
    type(trajectory_step_token_t) :: stale, current
    logical :: ok

    call configure_trajectory_direction(state, .true.)
    call begin_or_continue_trajectory(state, 23, 1.0_real64, 2.0_real64, SW_STEP_CONTROL_BOTTOM_HEAD, 2, ok, 88_int64)
    call require(ok, 'ABA begin failed')
    call build_trajectory_step_request(state, 1.0_real64, 1.4_real64, request, stale, ok)
    call require(ok, 'ABA stale issue failed')
    call discard_trajectory_step(state)
    call build_trajectory_step_request(state, 1.0_real64, 1.4_real64, request, current, ok)
    call require(ok, 'ABA current issue failed')
    call require(current%step_sequence /= stale%step_sequence, 'ABA retry reused token sequence')
    call make_available_result(result, [2.0_real64, 3.0_real64], [0.2_real64, 0.3_real64], 0.0_real64, &
         1.0_real64, 'stale-result')
    call stage_trajectory_step_result(state, stale, result, ok)
    call require(.not. ok, 'stale ABA result was accepted')
    call require(state%status == TRAJECTORY_DIRECTION_FAILED, 'stale ABA result did not fail closed')
    call require(trim(state%route) == 'stale-or-cross-candidate-step-result', 'unexpected stale ABA failure route')
  end subroutine test_retry_aba_token_rejected

  subroutine test_transaction_publication_guards()
    type(accepted_trajectory_direction_t) :: state
    type(transaction_result_t) :: tx
    type(accepted_trajectory_direction_result_t) :: result
    logical :: ok

    call make_one_step_finalized_state(state, 0.2_real64, 0.7_real64, 123_int64, ok)
    call require(ok, 'transaction fixture failed')

    tx = transaction_result_t()
    tx%status = TX_STATUS_RETRY_EXHAUSTED
    tx%commits = 0
    tx%requested_t0 = 0.2_real64
    tx%requested_t1 = 0.7_real64
    tx%accepted_t1 = 0.7_real64
    call bind_accepted_trajectory_to_transaction(tx, state, result)
    call require(.not. result%available, 'rejected transaction published derivative')
    call require(trim(result%route) == 'transaction-not-accepted', 'wrong rejected-transaction route')

    tx%status = TX_STATUS_ACCEPTED
    tx%commits = 2
    call bind_accepted_trajectory_to_transaction(tx, state, result)
    call require(.not. result%available, 'multi-commit transaction published derivative')
    call require(trim(result%route) == 'transaction-commit-count-invalid', 'wrong commit-count route')

    tx%commits = 1
    tx%accepted_t1 = 0.65_real64
    call bind_accepted_trajectory_to_transaction(tx, state, result)
    call require(.not. result%available, 'provenance mismatch published derivative')
    call require(trim(result%route) == 'accepted-transaction-provenance-mismatch', 'wrong provenance-mismatch route')
  end subroutine test_transaction_publication_guards

  subroutine test_shortened_interval_keeps_actual_endpoint()
    type(accepted_trajectory_direction_t) :: state
    type(transaction_result_t) :: tx
    type(accepted_trajectory_direction_result_t) :: result
    logical :: ok

    call make_one_step_finalized_state(state, 0.125_real64, 0.625_real64, 141_int64, ok)
    call require(ok, 'shortened fixture failed')
    tx = transaction_result_t()
    tx%status = TX_STATUS_ACCEPTED
    tx%commits = 1
    tx%requested_t0 = 0.125_real64
    tx%requested_t1 = 0.875_real64
    tx%accepted_t1 = 0.625_real64
    call bind_accepted_trajectory_to_transaction(tx, state, result)
    call require(result%available, 'valid shortened accepted interval did not publish')
    call require_close(result%origin_t0, 0.125_real64, 0.0_real64, 'shortened origin changed')
    call require_close(result%accepted_t1, 0.625_real64, 0.0_real64, 'shortened endpoint relabelled')
    call require(abs(result%accepted_t1-tx%requested_t1) > 0.1_real64, 'shortened interval was presented as full requested window')
  end subroutine test_shortened_interval_keeps_actual_endpoint

  subroutine make_one_step_finalized_state(state, t0, t1, generation, ok)
    type(accepted_trajectory_direction_t), intent(out) :: state
    real(real64), intent(in) :: t0, t1
    integer(int64), intent(in) :: generation
    logical, intent(out) :: ok
    type(soil_water_accepted_step_direction_request_t) :: request
    type(soil_water_accepted_step_direction_result_t) :: result
    type(trajectory_step_token_t) :: token

    call configure_trajectory_direction(state, .true.)
    call begin_or_continue_trajectory(state, 31, t0, t1, SW_STEP_CONTROL_BOTTOM_HEAD, 2, ok, generation)
    if (.not. ok) return
    call build_trajectory_step_request(state, t0, t1, request, token, ok)
    if (.not. ok) return
    call make_available_result(result, [0.7_real64, -0.4_real64], [0.07_real64, -0.04_real64], 0.02_real64, &
         -0.6_real64, 'fvq92-one-step')
    call stage_trajectory_step_result(state, token, result, ok)
    if (.not. ok) return
    call accept_trajectory_step(state, ok)
    if (.not. ok) return
    call finalize_trajectory_direction(state, t0, t1, ok)
  end subroutine make_one_step_finalized_state

  subroutine make_available_result(result, hdir, wdir, pdir, qdir, route)
    type(soil_water_accepted_step_direction_result_t), intent(out) :: result
    real(real64), intent(in) :: hdir(:), wdir(:), pdir, qdir
    character(len=*), intent(in) :: route

    result = soil_water_accepted_step_direction_result_t()
    result%status = SW_STEP_DIRECTION_AVAILABLE
    result%available = .true.
    result%fixed_smooth_route = .true.
    result%control_coordinate = SW_STEP_CONTROL_BOTTOM_HEAD
    result%method = 'fvq92-independent-analytic'
    result%route = route
    allocate(result%outgoing_pressure_head(size(hdir)), result%outgoing_water_content(size(wdir)))
    result%outgoing_pressure_head = hdir
    result%outgoing_water_content = wdir
    result%outgoing_ponding_depth = pdir
    result%bottom_flux_derivative = qdir
    result%additional_tridiagonal_backsolves = 1
    result%additional_jacobian_builds = 0
    result%additional_full_nonlinear_solves = 0
  end subroutine make_available_result

  subroutine synthetic_step(h, p, dt, hout, q)
    real(real64), intent(in) :: h(2), p, dt
    real(real64), intent(out) :: hout(2), q
    hout(1) = h(1) + dt*(p + 0.2_real64*h(1)*h(1) + 0.1_real64*h(2))
    hout(2) = h(2) + dt*(0.5_real64*h(1) - 0.1_real64*h(2) + p*p)
    q = 0.3_real64*h(1)*h(2) + p*h(1) - 0.2_real64*p
  end subroutine synthetic_step

  subroutine synthetic_step_tangent(h, dh, p, dt, dhout, dq)
    real(real64), intent(in) :: h(2), dh(2), p, dt
    real(real64), intent(out) :: dhout(2), dq
    dhout(1) = dh(1) + dt*(1.0_real64 + 0.4_real64*h(1)*dh(1) + 0.1_real64*dh(2))
    dhout(2) = dh(2) + dt*(0.5_real64*dh(1) - 0.1_real64*dh(2) + 2.0_real64*p)
    dq = 0.3_real64*(dh(1)*h(2) + h(1)*dh(2)) + h(1) + p*dh(1) - 0.2_real64
  end subroutine synthetic_step_tangent

  subroutine simulate_window(p, final_h, integrated_q)
    real(real64), intent(in) :: p
    real(real64), intent(out) :: final_h(2), integrated_q
    real(real64), parameter :: times(4) = [0.125_real64, 0.375_real64, 0.625_real64, 0.875_real64]
    real(real64) :: h(2), hnext(2), q, dt
    integer :: k
    h = [-0.6_real64, 0.9_real64]
    integrated_q = 0.0_real64
    do k = 1, 3
      dt = times(k+1)-times(k)
      call synthetic_step(h, p, dt, hnext, q)
      integrated_q = integrated_q + dt*q
      h = hnext
    end do
    final_h = h
  end subroutine simulate_window

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FVQ92_FAIL', trim(message)
      error stop 1
    end if
  end subroutine require

  subroutine require_close(actual, expected, tol, message)
    real(real64), intent(in) :: actual, expected, tol
    character(len=*), intent(in) :: message
    call require(abs(actual-expected) <= tol, message)
  end subroutine require_close

  subroutine require_close_vec(actual, expected, tol, message)
    real(real64), intent(in) :: actual(:), expected(:), tol
    character(len=*), intent(in) :: message
    call require(size(actual) == size(expected), trim(message)//' (shape)')
    call require(all(abs(actual-expected) <= tol), message)
  end subroutine require_close_vec

end program test_fvq92_fkt21_independent
