program test_fgc23_whole_window_response_tangent
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_accepted_step_direction_contract, only: &
       soil_water_accepted_step_direction_result_t, SW_STEP_DIRECTION_AVAILABLE, &
       SW_STEP_CONTROL_BOTTOM_HEAD, SW_STEP_CONTROL_BOTTOM_FLUX
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
       GW_COUPLING_RESPONSE_SWAP_SCOPE_MISMATCH, GW_COUPLING_RESPONSE_SWAP_CONTROL_MISMATCH, &
       GW_COUPLING_RESPONSE_GW_TANGENT_UNAVAILABLE, GW_COUPLING_RESPONSE_GW_PROVENANCE_MISMATCH, &
       GW_COUPLING_RESPONSE_EXTRA_FULL_SOLVE, GW_COUPLING_RESPONSE_ILL_CONDITIONED
  implicit none

  real(real64), parameter :: DAY_TO_S = 86400.0_real64
  real(real64), parameter :: T0 = 2.25_real64, T1 = 3.0_real64
  real(real64), parameter :: HPRED = 1.20_real64, RPRED = 0.05_real64
  integer(int64), parameter :: SWAP_LINEAGE = 11_int64, SWAP_REVISION = 2_int64
  integer(int64), parameter :: GW_LINEAGE = 22_int64, GW_REVISION = 3_int64, GW_CANDIDATE = 4_int64

  type(accepted_trajectory_direction_t) :: composer
  type(accepted_trajectory_direction_result_t) :: direction, direction_bad
  type(groundwater_response_sensitivity_t) :: gw, gw_bad
  type(groundwater_coupling_window_t) :: window
  type(groundwater_interface_lineage_t) :: lineage
  type(groundwater_coupling_response_t) :: response, response_repeat
  real(real64) :: expected_d, expected_j, expected_corrector, fd_j, fd_step
  real(real64) :: direction_d_before, gw_g_before, residual_after
  integer :: status
  logical :: ok

  window%t0 = T0
  window%t1 = T1

  lineage%coupling_id = 91_int64
  lineage%swap_lineage_id = SWAP_LINEAGE
  lineage%swap_origin_revision = SWAP_REVISION
  lineage%groundwater_lineage_id = GW_LINEAGE
  lineage%groundwater_origin_revision = GW_REVISION
  lineage%candidate_revision = GW_CANDIDATE

  call configure_trajectory_direction(composer, .true.)
  call begin_or_continue_trajectory(composer, 7, T0, T1, SW_STEP_CONTROL_BOTTOM_HEAD, 1, ok)
  call require(ok, 'composer begin failed')

  call stage_step(composer, 2.25_real64, 2.50_real64, 1.20_real64, .true.)
  ! This large derivative is a rejected trial. It must contribute exactly zero.
  call stage_step(composer, 2.50_real64, 2.75_real64, 99.0_real64, .false.)
  ! Retry replacement from the same accepted origin.
  call stage_step(composer, 2.50_real64, 2.75_real64, 0.80_real64, .true.)
  call stage_step(composer, 2.75_real64, 3.00_real64, -0.40_real64, .true.)
  call finalize_trajectory_direction(composer, T0, T1, ok)
  call require(ok, 'composer finalize failed')
  call publish_accepted_trajectory_direction(composer, direction)
  call require(direction%available, 'published accepted trajectory unavailable')

  expected_d = 0.25_real64*(1.20_real64 + 0.80_real64 - 0.40_real64)
  call require_close(direction%accepted_bottom_exchange_derivative, expected_d, 1.0e-14_real64, &
       'rejected retry derivative leaked into accepted trajectory')
  call require(direction%accepted_steps == 3, 'accepted step count includes rejected trial')

  gw = groundwater_response_sensitivity_t()
  gw%status = GW_RESPONSE_OK
  gw%provider_outcome = GW_RESPONSE_PROVIDER_AVAILABLE
  gw%available = .true.
  gw%dh_groundwater_dq_groundwater_s = 2000.0_real64
  gw%q_groundwater_m_per_s = synthetic_qgroundwater(HPRED, expected_d)
  gw%h_groundwater_m = HPRED - RPRED
  gw%window = window
  gw%groundwater_service_id = 41_int64
  gw%groundwater_lineage_id = GW_LINEAGE
  gw%origin_revision = GW_REVISION
  gw%candidate_revision = GW_CANDIDATE

  direction_d_before = direction%accepted_bottom_exchange_derivative
  gw_g_before = gw%dh_groundwater_dq_groundwater_s

  call compose_groundwater_coupling_response(window, lineage, SWAP_LINEAGE, SWAP_REVISION, direction, gw, &
       HPRED, RPRED, response, status)
  call require(status == GW_COUPLING_RESPONSE_OK .and. response%available, 'valid composition rejected')

  expected_j = 1.0_real64 - gw%dh_groundwater_dq_groundwater_s*expected_d/((T1-T0)*DAY_TO_S)
  expected_corrector = HPRED - RPRED/expected_j
  call require_close(response%head_residual_jacobian, expected_j, 2.0e-14_real64, 'analytic Jacobian mismatch')
  call require_close(response%corrector_h_swap_m, expected_corrector, 2.0e-14_real64, 'corrector mismatch')
  call require_close(response%dq_swap_dh_swap_per_s, -expected_d/((T1-T0)*DAY_TO_S), 1.0e-18_real64, &
       'SWAP sign/unit derivative mismatch')
  call require_close(response%dq_groundwater_dh_swap_per_s, expected_d/((T1-T0)*DAY_TO_S), 1.0e-18_real64, &
       'groundwater sign/unit derivative mismatch')

  ! Independent five-point whole-window finite-difference reference. This oracle
  ! reconstructs native qbot integral -> groundwater interface flux -> groundwater
  ! head -> r_H without calling the production composition formula.
  fd_step = 1.0e-4_real64
  fd_j = (-synthetic_residual(HPRED+2.0_real64*fd_step, expected_d, gw%dh_groundwater_dq_groundwater_s) + &
            8.0_real64*synthetic_residual(HPRED+fd_step, expected_d, gw%dh_groundwater_dq_groundwater_s) - &
            8.0_real64*synthetic_residual(HPRED-fd_step, expected_d, gw%dh_groundwater_dq_groundwater_s) + &
             synthetic_residual(HPRED-2.0_real64*fd_step, expected_d, gw%dh_groundwater_dq_groundwater_s)) / &
           (12.0_real64*fd_step)
  call require_close(response%head_residual_jacobian, fd_j, 5.0e-11_real64, &
       'whole-window analytic tangent disagrees with independent five-point FD')

  residual_after = synthetic_residual(response%corrector_h_swap_m, expected_d, &
       gw%dh_groundwater_dq_groundwater_s)
  call require(abs(residual_after) < 1.0e-12_real64, 'one corrector did not contract smooth linear residual')
  call require(abs(residual_after) < abs(RPRED), 'one corrector residual did not contract')

  call compose_groundwater_coupling_response(window, lineage, SWAP_LINEAGE, SWAP_REVISION, direction, gw, &
       HPRED, RPRED, response_repeat, status)
  call require(status == GW_COUPLING_RESPONSE_OK, 'deterministic replay rejected')
  call require(response_repeat%head_residual_jacobian == response%head_residual_jacobian .and. &
       response_repeat%corrector_h_swap_m == response%corrector_h_swap_m, 'deterministic replay changed response')

  call require(direction%accepted_bottom_exchange_derivative == direction_d_before, 'SWAP carrier mutated')
  call require(gw%dh_groundwater_dq_groundwater_s == gw_g_before, 'groundwater carrier mutated')

  direction_bad = direction
  direction_bad%origin_t0 = T0 + 0.01_real64
  call compose_groundwater_coupling_response(window, lineage, SWAP_LINEAGE, SWAP_REVISION, direction_bad, gw, &
       HPRED, RPRED, response_repeat, status)
  call require(status == GW_COUPLING_RESPONSE_SWAP_SCOPE_MISMATCH .and. .not. response_repeat%available, &
       'stale/non-window SWAP tangent did not fail closed')

  direction_bad = direction
  direction_bad%control_coordinate = SW_STEP_CONTROL_BOTTOM_FLUX
  call compose_groundwater_coupling_response(window, lineage, SWAP_LINEAGE, SWAP_REVISION, direction_bad, gw, &
       HPRED, RPRED, response_repeat, status)
  call require(status == GW_COUPLING_RESPONSE_SWAP_CONTROL_MISMATCH, 'LOCAL/wrong control relabel was accepted')

  direction_bad = direction
  direction_bad%additional_full_nonlinear_solves = 1
  call compose_groundwater_coupling_response(window, lineage, SWAP_LINEAGE, SWAP_REVISION, direction_bad, gw, &
       HPRED, RPRED, response_repeat, status)
  call require(status == GW_COUPLING_RESPONSE_EXTRA_FULL_SOLVE, 'native path accepted extra full nonlinear solve')

  gw_bad = gw
  gw_bad%status = GW_RESPONSE_UNAVAILABLE
  gw_bad%available = .false.
  call compose_groundwater_coupling_response(window, lineage, SWAP_LINEAGE, SWAP_REVISION, direction, gw_bad, &
       HPRED, RPRED, response_repeat, status)
  call require(status == GW_COUPLING_RESPONSE_GW_TANGENT_UNAVAILABLE .and. .not. response_repeat%available, &
       'unavailable/nonsmooth groundwater tangent did not fail closed')

  gw_bad = gw
  gw_bad%candidate_revision = GW_CANDIDATE + 1_int64
  call compose_groundwater_coupling_response(window, lineage, SWAP_LINEAGE, SWAP_REVISION, direction, gw_bad, &
       HPRED, RPRED, response_repeat, status)
  call require(status == GW_COUPLING_RESPONSE_GW_PROVENANCE_MISMATCH, 'stale groundwater response accepted')

  gw_bad = gw
  gw_bad%dh_groundwater_dq_groundwater_s = (T1-T0)*DAY_TO_S/expected_d
  call compose_groundwater_coupling_response(window, lineage, SWAP_LINEAGE, SWAP_REVISION, direction, gw_bad, &
       HPRED, RPRED, response_repeat, status)
  call require(status == GW_COUPLING_RESPONSE_ILL_CONDITIONED .and. .not. response_repeat%available, &
       'singular response Jacobian did not fail closed')

  call compose_groundwater_coupling_response(window, lineage, SWAP_LINEAGE+1_int64, SWAP_REVISION, direction, gw, &
       HPRED, RPRED, response_repeat, status)
  call require(.not. response_repeat%available, 'wrong SWAP committed origin accepted')

  print '(a)', 'FGC23_ACCEPTED_ONLY_COMPOSITION=PASS'
  print '(a)', 'FGC23_REJECTED_RETRY_ZERO_CONTRIBUTION=PASS'
  print '(a)', 'FGC23_EXACT_WINDOW_AND_ORIGIN_PROVENANCE=PASS'
  print '(a)', 'FGC23_BOTTOM_HEAD_CONTROL_ONLY=PASS'
  print '(a)', 'FGC23_WHOLE_WINDOW_FIVE_POINT_FD_REFERENCE=PASS'
  print '(a)', 'FGC23_ONE_CORRECTOR_RESIDUAL_CONTRACTION=PASS'
  print '(a)', 'FGC23_NO_EXTRA_FULL_NONLINEAR_SOLVE=PASS'
  print '(a)', 'FGC23_UNAVAILABLE_NONSMOOTH_FAIL_CLOSED=PASS'
  print '(a)', 'FGC23_STALE_GROUNDWATER_RESPONSE_FAIL_CLOSED=PASS'
  print '(a)', 'FGC23_ILL_CONDITIONED_FAIL_CLOSED=PASS'
  print '(a)', 'FGC23_INPUT_CARRIERS_UNCHANGED=PASS'
  print '(a)', 'FGC23_DETERMINISTIC_RESPONSE=PASS'
  print '(a)', 'FGC23_OWNER_ORACLE=PASS'

contains

  subroutine stage_step(state, step_t0, step_t1, derivative, accept_step)
    type(accepted_trajectory_direction_t), intent(inout) :: state
    real(real64), intent(in) :: step_t0, step_t1, derivative
    logical, intent(in) :: accept_step
    type(soil_water_accepted_step_direction_result_t) :: step_result
    type(trajectory_step_token_t) :: token
    type(soil_water_accepted_step_direction_request_t_local) :: unused_local
    logical :: built, staged, accepted

    ! The local wrapper exists only to keep the public request object out of the
    ! oracle calculations; build_request still exercises real token provenance.
    call build_step_request(state, step_t0, step_t1, token, built)
    call require(built, 'trajectory step request failed')

    step_result = soil_water_accepted_step_direction_result_t()
    step_result%status = SW_STEP_DIRECTION_AVAILABLE
    step_result%available = .true.
    step_result%fixed_smooth_route = .true.
    step_result%control_coordinate = SW_STEP_CONTROL_BOTTOM_HEAD
    step_result%method = 'owner-synthetic-smooth'
    step_result%route = 'owner-synthetic-smooth'
    allocate(step_result%outgoing_pressure_head(1), step_result%outgoing_water_content(1))
    step_result%outgoing_pressure_head = 0.0_real64
    step_result%outgoing_water_content = 0.0_real64
    step_result%outgoing_ponding_depth = 0.0_real64
    step_result%bottom_flux_derivative = derivative
    step_result%additional_tridiagonal_backsolves = 1
    step_result%additional_jacobian_builds = 0
    step_result%additional_full_nonlinear_solves = 0

    call stage_trajectory_step_result(state, token, step_result, staged)
    call require(staged, 'trajectory step staging failed')
    if (accept_step) then
      call accept_trajectory_step(state, accepted)
      call require(accepted, 'trajectory step acceptance failed')
    else
      call discard_trajectory_step(state)
    end if
  end subroutine stage_step

  ! Fortran requires the real public request type when exercising token issue.
  subroutine build_step_request(state, step_t0, step_t1, token, ok)
    use mod_soil_water_accepted_step_direction_contract, only: soil_water_accepted_step_direction_request_t
    type(accepted_trajectory_direction_t), intent(inout) :: state
    real(real64), intent(in) :: step_t0, step_t1
    type(trajectory_step_token_t), intent(out) :: token
    logical, intent(out) :: ok
    type(soil_water_accepted_step_direction_request_t) :: request
    call build_trajectory_step_request(state, step_t0, step_t1, request, token, ok)
  end subroutine build_step_request

  pure real(real64) function synthetic_qgroundwater(h_swap_m, integrated_d) result(qgw)
    real(real64), intent(in) :: h_swap_m, integrated_d
    real(real64) :: hbot_delta_cm, qbot_integral_cm
    hbot_delta_cm = 100.0_real64*(h_swap_m-HPRED)
    qbot_integral_cm = 0.30_real64 + integrated_d*hbot_delta_cm
    qgw = qbot_integral_cm*0.01_real64/((T1-T0)*DAY_TO_S)
  end function synthetic_qgroundwater

  pure real(real64) function synthetic_residual(h_swap_m, integrated_d, gw_derivative_s) result(r)
    real(real64), intent(in) :: h_swap_m, integrated_d, gw_derivative_s
    real(real64) :: q0, q, hgw
    q0 = synthetic_qgroundwater(HPRED, integrated_d)
    q = synthetic_qgroundwater(h_swap_m, integrated_d)
    hgw = (HPRED-RPRED) + gw_derivative_s*(q-q0)
    r = h_swap_m - hgw
  end function synthetic_residual

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a)') 'FGC23_FAIL: '//trim(message)
      error stop 1
    end if
  end subroutine require

  subroutine require_close(actual, expected, tolerance, message)
    real(real64), intent(in) :: actual, expected, tolerance
    character(len=*), intent(in) :: message
    call require(abs(actual-expected) <= tolerance, message)
  end subroutine require_close

  type :: soil_water_accepted_step_direction_request_t_local
    integer :: unused = 0
  end type soil_water_accepted_step_direction_request_t_local

end program test_fgc23_whole_window_response_tangent
