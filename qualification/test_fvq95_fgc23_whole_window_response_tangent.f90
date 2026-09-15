program test_fvq95_fgc23_whole_window_response_tangent
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_accepted_step_direction_contract, only: &
       soil_water_accepted_step_direction_request_t, soil_water_accepted_step_direction_result_t, &
       SW_STEP_DIRECTION_AVAILABLE, SW_STEP_CONTROL_BOTTOM_HEAD, SW_STEP_CONTROL_BOTTOM_FLUX
  use mod_accepted_trajectory_directional_sensitivity, only: accepted_trajectory_direction_t, &
       trajectory_step_token_t, configure_trajectory_direction, begin_or_continue_trajectory, &
       build_trajectory_step_request, stage_trajectory_step_result, accept_trajectory_step, &
       discard_trajectory_step, finalize_trajectory_direction
  use mod_accepted_trajectory_directional_publication, only: accepted_trajectory_direction_result_t, &
       publish_accepted_trajectory_direction
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_interface_lineage_t
  use mod_groundwater_response_sensitivity_contract, only: groundwater_response_sensitivity_t, &
       GW_RESPONSE_OK, GW_RESPONSE_UNAVAILABLE, GW_RESPONSE_PROVIDER_AVAILABLE
  use mod_groundwater_coupling_response, only: groundwater_coupling_response_t, &
       compose_groundwater_coupling_response, GW_COUPLING_RESPONSE_OK, &
       GW_COUPLING_RESPONSE_SWAP_TANGENT_UNAVAILABLE, GW_COUPLING_RESPONSE_SWAP_SCOPE_MISMATCH, &
       GW_COUPLING_RESPONSE_SWAP_CONTROL_MISMATCH, GW_COUPLING_RESPONSE_GW_TANGENT_UNAVAILABLE, &
       GW_COUPLING_RESPONSE_GW_PROVENANCE_MISMATCH, GW_COUPLING_RESPONSE_EXTRA_FULL_SOLVE, &
       GW_COUPLING_RESPONSE_ILL_CONDITIONED, GW_COUPLING_RESPONSE_INVALID_LINEAGE
  implicit none

  real(real64), parameter :: DAY_TO_S = 86400.0_real64
  real(real64), parameter :: T0 = 7.125_real64, T1 = 8.625_real64
  real(real64), parameter :: H0 = 0.85_real64, R0 = 0.04_real64
  real(real64), parameter :: D_ACCEPTED = 0.50_real64
  real(real64), parameter :: GW_DERIVATIVE_S = 10000.0_real64
  integer(int64), parameter :: SWAP_LINEAGE = 501_int64, SWAP_REVISION = 12_int64
  integer(int64), parameter :: GW_LINEAGE = 701_int64, GW_REVISION = 9_int64, GW_CANDIDATE = 10_int64

  type(accepted_trajectory_direction_t) :: composer
  type(accepted_trajectory_direction_result_t) :: direction, direction_bad
  type(groundwater_response_sensitivity_t) :: groundwater, groundwater_bad
  type(groundwater_coupling_window_t) :: window
  type(groundwater_interface_lineage_t) :: lineage, lineage_bad
  type(groundwater_coupling_response_t) :: response, response2
  real(real64) :: d_before, g_before, expected_j, fd_j, h, r_after
  integer :: status
  logical :: ok

  window%t0 = T0
  window%t1 = T1

  lineage%coupling_id = 301_int64
  lineage%swap_lineage_id = SWAP_LINEAGE
  lineage%swap_origin_revision = SWAP_REVISION
  lineage%groundwater_lineage_id = GW_LINEAGE
  lineage%groundwater_origin_revision = GW_REVISION
  lineage%candidate_revision = GW_CANDIDATE

  call configure_trajectory_direction(composer, .true.)
  call begin_or_continue_trajectory(composer, 23, T0, T1, SW_STEP_CONTROL_BOTTOM_HEAD, 1, ok)
  call require(ok, 'independent composer begin failed')

  call add_step(composer, 7.125_real64, 7.625_real64, 0.80_real64, .true.)
  call add_step(composer, 7.625_real64, 8.125_real64, 50.0_real64, .false.)
  call add_step(composer, 7.625_real64, 8.125_real64, 0.40_real64, .true.)
  call add_step(composer, 8.125_real64, 8.625_real64, -0.20_real64, .true.)
  call finalize_trajectory_direction(composer, T0, T1, ok)
  call require(ok, 'independent composer finalization failed')
  call publish_accepted_trajectory_direction(composer, direction)
  call require(direction%available, 'accepted whole-window publication unavailable')
  call require_close(direction%accepted_bottom_exchange_derivative, D_ACCEPTED, 1.0e-14_real64, &
       'discarded retry derivative leaked into whole-window derivative')
  call require(direction%accepted_steps == 3, 'rejected step counted as accepted')

  groundwater = groundwater_response_sensitivity_t()
  groundwater%status = GW_RESPONSE_OK
  groundwater%provider_outcome = GW_RESPONSE_PROVIDER_AVAILABLE
  groundwater%available = .true.
  groundwater%dh_groundwater_dq_groundwater_s = GW_DERIVATIVE_S
  groundwater%q_groundwater_m_per_s = synthetic_qgroundwater(H0)
  groundwater%h_groundwater_m = H0 - R0
  groundwater%window = window
  groundwater%groundwater_service_id = 601_int64
  groundwater%groundwater_lineage_id = GW_LINEAGE
  groundwater%origin_revision = GW_REVISION
  groundwater%candidate_revision = GW_CANDIDATE

  d_before = direction%accepted_bottom_exchange_derivative
  g_before = groundwater%dh_groundwater_dq_groundwater_s

  call compose_groundwater_coupling_response(window, lineage, SWAP_LINEAGE, SWAP_REVISION, direction, groundwater, &
       H0, R0, response, status)
  call require(status == GW_COUPLING_RESPONSE_OK .and. response%available, 'valid independent composition rejected')

  expected_j = 1.0_real64 - GW_DERIVATIVE_S*D_ACCEPTED/((T1-T0)*DAY_TO_S)
  call require_close(response%head_residual_jacobian, expected_j, 2.0e-14_real64, &
       'independent analytic Jacobian mismatch')

  ! Independent nonlinear whole-window finite-difference reference.  The
  ! production helper is not used by these synthetic exchange/head functions.
  h = 2.0e-5_real64
  fd_j = (-synthetic_residual(H0+2.0_real64*h) + 8.0_real64*synthetic_residual(H0+h) - &
           8.0_real64*synthetic_residual(H0-h) + synthetic_residual(H0-2.0_real64*h)) / (12.0_real64*h)
  call require_close(response%head_residual_jacobian, fd_j, 2.0e-9_real64, &
       'production tangent disagrees with independent nonlinear five-point FD')

  r_after = synthetic_residual(response%corrector_h_swap_m)
  call require(abs(r_after) < abs(R0), 'one corrector failed to contract nonlinear residual')
  call require(abs(r_after) < 1.0e-3_real64*abs(R0), 'one corrector contraction weaker than independent oracle')

  call compose_groundwater_coupling_response(window, lineage, SWAP_LINEAGE, SWAP_REVISION, direction, groundwater, &
       H0, R0, response2, status)
  call require(status == GW_COUPLING_RESPONSE_OK, 'deterministic replay rejected')
  call require(response2%head_residual_jacobian == response%head_residual_jacobian .and. &
       response2%corrector_h_swap_m == response%corrector_h_swap_m, 'deterministic replay changed outputs')

  call require(direction%accepted_bottom_exchange_derivative == d_before, 'SWAP carrier mutated by composition')
  call require(groundwater%dh_groundwater_dq_groundwater_s == g_before, 'groundwater carrier mutated by composition')

  direction_bad = direction
  direction_bad%available = .false.
  call compose_groundwater_coupling_response(window, lineage, SWAP_LINEAGE, SWAP_REVISION, direction_bad, groundwater, &
       H0, R0, response2, status)
  call require(status == GW_COUPLING_RESPONSE_SWAP_TANGENT_UNAVAILABLE .and. .not. response2%available, &
       'unavailable SWAP tangent did not fail closed')

  direction_bad = direction
  direction_bad%accepted_t1 = T1 - 0.125_real64
  call compose_groundwater_coupling_response(window, lineage, SWAP_LINEAGE, SWAP_REVISION, direction_bad, groundwater, &
       H0, R0, response2, status)
  call require(status == GW_COUPLING_RESPONSE_SWAP_SCOPE_MISMATCH, 'shortened trajectory was relabelled whole-window')

  direction_bad = direction
  direction_bad%control_coordinate = SW_STEP_CONTROL_BOTTOM_FLUX
  call compose_groundwater_coupling_response(window, lineage, SWAP_LINEAGE, SWAP_REVISION, direction_bad, groundwater, &
       H0, R0, response2, status)
  call require(status == GW_COUPLING_RESPONSE_SWAP_CONTROL_MISMATCH, 'wrong/local control was accepted')

  direction_bad = direction
  direction_bad%additional_full_nonlinear_solves = 1
  call compose_groundwater_coupling_response(window, lineage, SWAP_LINEAGE, SWAP_REVISION, direction_bad, groundwater, &
       H0, R0, response2, status)
  call require(status == GW_COUPLING_RESPONSE_EXTRA_FULL_SOLVE, 'normal path accepted structural full solve')

  groundwater_bad = groundwater
  groundwater_bad%status = GW_RESPONSE_UNAVAILABLE
  groundwater_bad%available = .false.
  call compose_groundwater_coupling_response(window, lineage, SWAP_LINEAGE, SWAP_REVISION, direction, groundwater_bad, &
       H0, R0, response2, status)
  call require(status == GW_COUPLING_RESPONSE_GW_TANGENT_UNAVAILABLE .and. .not. response2%available, &
       'unavailable/nonsmooth groundwater tangent did not fail closed')

  groundwater_bad = groundwater
  groundwater_bad%candidate_revision = GW_CANDIDATE + 1_int64
  call compose_groundwater_coupling_response(window, lineage, SWAP_LINEAGE, SWAP_REVISION, direction, groundwater_bad, &
       H0, R0, response2, status)
  call require(status == GW_COUPLING_RESPONSE_GW_PROVENANCE_MISMATCH, 'stale groundwater candidate accepted')

  lineage_bad = lineage
  lineage_bad%swap_lineage_id = SWAP_LINEAGE + 1_int64
  call compose_groundwater_coupling_response(window, lineage_bad, SWAP_LINEAGE, SWAP_REVISION, direction, groundwater, &
       H0, R0, response2, status)
  call require(status == GW_COUPLING_RESPONSE_INVALID_LINEAGE, 'wrong committed SWAP origin accepted')

  groundwater_bad = groundwater
  groundwater_bad%dh_groundwater_dq_groundwater_s = (T1-T0)*DAY_TO_S/D_ACCEPTED
  call compose_groundwater_coupling_response(window, lineage, SWAP_LINEAGE, SWAP_REVISION, direction, groundwater_bad, &
       H0, R0, response2, status)
  call require(status == GW_COUPLING_RESPONSE_ILL_CONDITIONED .and. .not. response2%available, &
       'singular composite Jacobian did not fail closed')

  print '(a)', 'FVQ95_ACCEPTED_WHOLE_WINDOW_ONLY=PASS'
  print '(a)', 'FVQ95_REJECTED_RETRY_ZERO_CONTRIBUTION=PASS'
  print '(a)', 'FVQ95_GENERIC_WINDOW_PROVENANCE=PASS'
  print '(a)', 'FVQ95_BOTTOM_HEAD_CONTROL_SCOPE=PASS'
  print '(a)', 'FVQ95_NONLINEAR_FIVE_POINT_FD_REFERENCE=PASS'
  print '(a)', 'FVQ95_ONE_CORRECTOR_NONLINEAR_CONTRACTION=PASS'
  print '(a)', 'FVQ95_UNAVAILABLE_NONSMOOTH_FAIL_CLOSED=PASS'
  print '(a)', 'FVQ95_STALE_RESPONSE_FAIL_CLOSED=PASS'
  print '(a)', 'FVQ95_NO_STRUCTURAL_FULL_SOLVE=PASS'
  print '(a)', 'FVQ95_INPUTS_NOT_MUTATED=PASS'
  print '(a)', 'FVQ95_DETERMINISTIC=PASS'
  print '(a)', 'FVQ95_INDEPENDENT_ORACLE=PASS'

contains

  subroutine add_step(state, step_t0, step_t1, derivative, accept_it)
    type(accepted_trajectory_direction_t), intent(inout) :: state
    real(real64), intent(in) :: step_t0, step_t1, derivative
    logical, intent(in) :: accept_it
    type(soil_water_accepted_step_direction_request_t) :: request
    type(soil_water_accepted_step_direction_result_t) :: step_result
    type(trajectory_step_token_t) :: token
    logical :: built, staged, accepted

    call build_trajectory_step_request(state, step_t0, step_t1, request, token, built)
    call require(built, 'step token issue failed')

    step_result = soil_water_accepted_step_direction_result_t()
    step_result%status = SW_STEP_DIRECTION_AVAILABLE
    step_result%available = .true.
    step_result%fixed_smooth_route = .true.
    step_result%control_coordinate = SW_STEP_CONTROL_BOTTOM_HEAD
    step_result%method = 'fvq95-smooth-step'
    step_result%route = 'fvq95-smooth-step'
    allocate(step_result%outgoing_pressure_head(1), step_result%outgoing_water_content(1))
    step_result%outgoing_pressure_head = 0.0_real64
    step_result%outgoing_water_content = 0.0_real64
    step_result%outgoing_ponding_depth = 0.0_real64
    step_result%bottom_flux_derivative = derivative
    step_result%additional_tridiagonal_backsolves = 1
    step_result%additional_jacobian_builds = 0
    step_result%additional_full_nonlinear_solves = 0

    call stage_trajectory_step_result(state, token, step_result, staged)
    call require(staged, 'step staging failed')
    if (accept_it) then
      call accept_trajectory_step(state, accepted)
      call require(accepted, 'step acceptance failed')
    else
      call discard_trajectory_step(state)
    end if
  end subroutine add_step

  pure real(real64) function synthetic_exchange_cm(h_swap_m) result(exchange_cm)
    real(real64), intent(in) :: h_swap_m
    real(real64) :: dh_cm
    dh_cm = 100.0_real64*(h_swap_m-H0)
    exchange_cm = 0.40_real64 + D_ACCEPTED*dh_cm + 0.002_real64*dh_cm*dh_cm
  end function synthetic_exchange_cm

  pure real(real64) function synthetic_qgroundwater(h_swap_m) result(q_groundwater)
    real(real64), intent(in) :: h_swap_m
    q_groundwater = synthetic_exchange_cm(h_swap_m)*0.01_real64/((T1-T0)*DAY_TO_S)
  end function synthetic_qgroundwater

  pure real(real64) function synthetic_groundwater_head(h_swap_m) result(h_groundwater)
    real(real64), intent(in) :: h_swap_m
    real(real64) :: q0, q
    q0 = synthetic_qgroundwater(H0)
    q = synthetic_qgroundwater(h_swap_m)
    h_groundwater = (H0-R0) + GW_DERIVATIVE_S*(q-q0)
  end function synthetic_groundwater_head

  pure real(real64) function synthetic_residual(h_swap_m) result(residual)
    real(real64), intent(in) :: h_swap_m
    residual = h_swap_m - synthetic_groundwater_head(h_swap_m)
  end function synthetic_residual

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a)') 'FVQ95_FAIL: '//trim(message)
      error stop 95
    end if
  end subroutine require

  subroutine require_close(actual, expected, tolerance, message)
    real(real64), intent(in) :: actual, expected, tolerance
    character(len=*), intent(in) :: message
    if (abs(actual-expected) > tolerance) then
      write(*,'(a,2(1x,es24.16))') 'FVQ95_FAIL: '//trim(message), actual, expected
      error stop 95
    end if
  end subroutine require_close

end program test_fvq95_fgc23_whole_window_response_tangent
