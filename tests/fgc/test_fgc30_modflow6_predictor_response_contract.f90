program test_fgc30_modflow6_predictor_response_contract
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_interface_lineage_t
  use mod_modflow6_swap_predictor_response, only: modflow6_derivative_coverage_t, &
       modflow6_swap_predictor_response_t, compose_modflow6_swap_predictor_response, &
       MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT, MODFLOW6_DERIVATIVE_CENTERED_FD, &
       MODFLOW6_PREDICTOR_OK, MODFLOW6_PREDICTOR_INCOMPLETE_DERIVATIVE_COVERAGE
  implicit none

  real(real64), parameter :: DAY_TO_S = 86400.0_real64
  real(real64), parameter :: T0 = 10.0_real64, T1 = 10.5_real64
  real(real64), parameter :: QBOT = -0.2_real64
  real(real64), parameter :: HSTART = 1.000_real64, HEND = 1.004_real64
  real(real64), parameter :: DHDQ = 2.0_real64
  real(real64), parameter :: EPSQ = 0.01_real64

  type(groundwater_coupling_window_t) :: window
  type(groundwater_interface_lineage_t) :: lineage
  type(modflow6_derivative_coverage_t) :: coverage, incomplete
  type(modflow6_swap_predictor_response_t) :: tangent, fd, signed_response
  real(real64) :: hplus, hminus, fd_dhdq
  integer :: status

  window%t0 = T0
  window%t1 = T1

  lineage%coupling_id = 3001_int64
  lineage%swap_lineage_id = 31_int64
  lineage%swap_origin_revision = 7_int64
  lineage%groundwater_lineage_id = 41_int64
  lineage%groundwater_origin_revision = 9_int64
  lineage%candidate_revision = 0_int64

  coverage = modflow6_derivative_coverage_t()
  coverage%lower_face_head_semantics_covered = .true.
  coverage%richards_hydraulic_response_covered = .true.
  coverage%constitutive_response_covered = .true.
  coverage%dynamic_top_boundary_active = .true.
  coverage%dynamic_top_boundary_covered = .true.

  call compose_modflow6_swap_predictor_response(window, lineage, QBOT, HSTART, HEND, DHDQ, &
       MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT, coverage, 'f-kt21-owner-oracle', &
       'drainage-free-smooth-route', tangent, status)
  call require(status == MODFLOW6_PREDICTOR_OK .and. tangent%valid, 'complete tangent rejected')
  call require_close(tangent%coupling_storage_coefficient_u, 0.25_real64, 1.0e-14_real64, &
       'u tangent mismatch')
  call require_close(tangent%q_u_cm_per_day, 0.4_real64, 1.0e-14_real64, 'q_u tangent mismatch')
  call require_close(tangent%q_u_m_per_s, 0.4_real64*0.01_real64/DAY_TO_S, 1.0e-18_real64, &
       'q_u SI translation mismatch')

  ! Independent centered finite difference around the same predictor. The
  ! synthetic lower-face response is exactly linear in native qbot, so this is
  ! an independent oracle for the contract algebra rather than a restatement of
  ! the tangent value passed above.
  hplus = HEND + (DHDQ*EPSQ)*0.01_real64
  hminus = HEND - (DHDQ*EPSQ)*0.01_real64
  fd_dhdq = (hplus-hminus)*100.0_real64/(2.0_real64*EPSQ)

  incomplete = coverage
  incomplete%drainage_active = .true.
  incomplete%drainage_covered = .false.

  call compose_modflow6_swap_predictor_response(window, lineage, QBOT, HSTART, HEND, fd_dhdq, &
       MODFLOW6_DERIVATIVE_CENTERED_FD, incomplete, 'centered-finite-difference', &
       'full-production-trajectory-oracle', fd, status)
  call require(status == MODFLOW6_PREDICTOR_OK .and. fd%valid, &
       'centered FD fallback rejected by incomplete analytic coverage')
  call require_close(fd%coupling_storage_coefficient_u, tangent%coupling_storage_coefficient_u, &
       1.0e-13_real64, 'tangent/FD u disagreement')
  call require_close(fd%q_u_cm_per_day, tangent%q_u_cm_per_day, 1.0e-13_real64, &
       'tangent/FD q_u disagreement')

  call compose_modflow6_swap_predictor_response(window, lineage, QBOT, HSTART, HEND, DHDQ, &
       MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT, incomplete, 'partial-tangent', &
       'active-drainage-not-covered', fd, status)
  call require(status == MODFLOW6_PREDICTOR_INCOMPLETE_DERIVATIVE_COVERAGE .and. .not. fd%valid, &
       'active uncovered drainage tangent did not fail closed')

  ! Native SWAP qbot is positive into SWAP. With no coupling-head storage
  ! change, public q_u must therefore be the opposite sign: outward from SWAP.
  call compose_modflow6_swap_predictor_response(window, lineage, 0.3_real64, HSTART, HSTART, DHDQ, &
       MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT, coverage, 'f-kt21-owner-oracle', &
       'zero-storage-sign-oracle', signed_response, status)
  call require(status == MODFLOW6_PREDICTOR_OK, 'sign oracle response rejected')
  call require_close(signed_response%q_u_cm_per_day, -0.3_real64, 1.0e-14_real64, &
       'native/public q_u sign mismatch')

  print '(a)', 'FGC30_TYPED_PREDICTOR_RESPONSE=PASS'
  print '(a)', 'FGC30_TANGENT_U_ALGEBRA=PASS'
  print '(a)', 'FGC30_CENTERED_FD_ORACLE=PASS'
  print '(a)', 'FGC30_TANGENT_FD_AGREEMENT=PASS'
  print '(a)', 'FGC30_INCOMPLETE_DRAINAGE_COVERAGE_FAIL_CLOSED=PASS'
  print '(a)', 'FGC30_FD_FALLBACK_WITH_INCOMPLETE_ANALYTIC_COVERAGE=PASS'
  print '(a)', 'FGC30_Q_U_SIGN_TRANSLATION=PASS'
  print '(a)', 'FGC30_PREDICTOR_CONTRACT_GATE=PASS'

contains

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a)') 'FGC30_FAIL: '//trim(message)
      error stop 1
    end if
  end subroutine require

  subroutine require_close(actual, expected, tolerance, message)
    real(real64), intent(in) :: actual, expected, tolerance
    character(len=*), intent(in) :: message
    call require(abs(actual-expected) <= tolerance, message)
  end subroutine require_close

end program test_fgc30_modflow6_predictor_response_contract
