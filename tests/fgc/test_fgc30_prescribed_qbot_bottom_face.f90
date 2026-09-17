program test_fgc30_prescribed_qbot_bottom_face
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t
  use mod_modflow6_swap_prescribed_qbot_bottom_face, only: &
       modflow6_prescribed_qbot_bottom_face_t, materialize_modflow6_prescribed_qbot_bottom_face, &
       MODFLOW6_BOTTOM_FACE_OK, MODFLOW6_BOTTOM_FACE_INVALID_INPUT, &
       MODFLOW6_BOTTOM_FACE_INVALID_CONDUCTIVITY
  implicit none

  real(real64), parameter :: HNODE = -20.0_real64
  real(real64), parameter :: KFACE = 2.0_real64
  real(real64), parameter :: QBOT = -1.0_real64
  real(real64), parameter :: DIST = 5.0_real64
  real(real64), parameter :: DHDQ = 1.5_real64
  real(real64), parameter :: DKDQ = 0.2_real64
  real(real64), parameter :: EPSQ = 1.0e-6_real64

  type(groundwater_head_datum_t) :: datum
  type(modflow6_prescribed_qbot_bottom_face_t) :: result, free_drainage, invalid
  real(real64) :: plus_head, minus_head, fd_direction, expected_direction
  integer :: status

  datum%available = .true.
  datum%datum_id = 301_int64
  datum%bottom_boundary_elevation_m = 10.0_real64

  call materialize_modflow6_prescribed_qbot_bottom_face(HNODE, KFACE, QBOT, DIST, datum, result, status, &
       pressure_head_direction=DHDQ, conductivity_direction=DKDQ)
  call require(status == MODFLOW6_BOTTOM_FACE_OK .and. result%valid, 'smooth lower-face materialization rejected')
  call require(result%derivative_available, 'smooth lower-face derivative unavailable')
  call require_close(result%pressure_head_cm, -17.5_real64, 1.0e-14_real64, 'lower-face pressure head mismatch')
  call require_close(result%hydraulic_head_m, 9.825_real64, 1.0e-14_real64, 'datum-aware hydraulic head mismatch')

  expected_direction = DHDQ + DIST*(1.0_real64/KFACE - QBOT*DKDQ/KFACE**2)
  call require_close(result%dpressure_head_cm_per_qbot_cm_per_day, expected_direction, 1.0e-14_real64, &
       'analytic lower-face pressure-head direction mismatch')
  call require_close(result%dhydraulic_head_m_per_qbot_cm_per_day, 0.01_real64*expected_direction, &
       1.0e-15_real64, 'hydraulic-head direction unit translation mismatch')

  plus_head = synthetic_bottom_face(QBOT+EPSQ)
  minus_head = synthetic_bottom_face(QBOT-EPSQ)
  fd_direction = (plus_head-minus_head)/(2.0_real64*EPSQ)
  call require_close(result%dpressure_head_cm_per_qbot_cm_per_day, fd_direction, 2.0e-9_real64, &
       'analytic lower-face direction disagrees with centered FD')

  ! qbot=-K is the B1.10 free-drainage gradient. The reconstructed lower-face
  ! pressure head must then equal the terminal node pressure head exactly.
  call materialize_modflow6_prescribed_qbot_bottom_face(HNODE, KFACE, -KFACE, DIST, datum, free_drainage, status)
  call require(status == MODFLOW6_BOTTOM_FACE_OK .and. free_drainage%valid, 'free-drainage identity rejected')
  call require_close(free_drainage%pressure_head_cm, HNODE, 1.0e-14_real64, 'free-drainage lower-face identity mismatch')

  call materialize_modflow6_prescribed_qbot_bottom_face(HNODE, 0.0_real64, QBOT, DIST, datum, invalid, status)
  call require(status == MODFLOW6_BOTTOM_FACE_INVALID_CONDUCTIVITY .and. .not. invalid%valid, &
       'zero bottom conductivity did not fail closed')

  call materialize_modflow6_prescribed_qbot_bottom_face(HNODE, KFACE, QBOT, DIST, datum, invalid, status, &
       pressure_head_direction=DHDQ)
  call require(status == MODFLOW6_BOTTOM_FACE_INVALID_INPUT .and. .not. invalid%valid, &
       'partial derivative provenance did not fail closed')

  print '(a)', 'FGC30_QBOT_BOTTOM_FACE_DARCY_IDENTITY=PASS'
  print '(a)', 'FGC30_QBOT_BOTTOM_FACE_DATUM_TRANSLATION=PASS'
  print '(a)', 'FGC30_QBOT_BOTTOM_FACE_DIRECTIONAL_CHAIN_RULE=PASS'
  print '(a)', 'FGC30_QBOT_BOTTOM_FACE_CENTERED_FD_ORACLE=PASS'
  print '(a)', 'FGC30_QBOT_BOTTOM_FACE_FREE_DRAINAGE_IDENTITY=PASS'
  print '(a)', 'FGC30_QBOT_BOTTOM_FACE_FAIL_CLOSED=PASS'
  print '(a)', 'FGC30_QBOT_BOTTOM_FACE_GATE=PASS'

contains

  pure real(real64) function synthetic_bottom_face(q) result(hbot)
    real(real64), intent(in) :: q
    real(real64) :: hnode_q, k_q
    hnode_q = HNODE + DHDQ*(q-QBOT)
    k_q = KFACE + DKDQ*(q-QBOT)
    hbot = hnode_q + DIST*(1.0_real64 + q/k_q)
  end function synthetic_bottom_face

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a)') 'FGC30_BOTTOM_FACE_FAIL: '//trim(message)
      error stop 1
    end if
  end subroutine require

  subroutine require_close(actual, expected, tolerance, message)
    real(real64), intent(in) :: actual, expected, tolerance
    character(len=*), intent(in) :: message
    call require(abs(actual-expected) <= tolerance, message)
  end subroutine require_close

end program test_fgc30_prescribed_qbot_bottom_face
