program test_fgc30_predictor_origin
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_interface_state_t
  use mod_modflow6_swap_predictor_response, only: modflow6_swap_predictor_lineage_t
  use mod_modflow6_swap_predictor_origin, only: modflow6_swap_predictor_origin_t, &
       capture_modflow6_swap_predictor_origin, MODFLOW6_PREDICTOR_ORIGIN_OK, &
       MODFLOW6_PREDICTOR_ORIGIN_NOT_COMMITTED, MODFLOW6_PREDICTOR_ORIGIN_NONCONSERVATIVE_INTERFACE
  implicit none

  type(groundwater_interface_state_t) :: accepted_interface, bad_interface
  type(modflow6_swap_predictor_lineage_t) :: lineage
  type(modflow6_swap_predictor_origin_t) :: origin
  integer :: status

  lineage%coupling_id = 4101_int64
  lineage%swap_lineage_id = 4102_int64
  lineage%swap_origin_revision = 12_int64
  lineage%groundwater_service_id = 4103_int64
  lineage%groundwater_lineage_id = 4104_int64
  lineage%groundwater_origin_revision = 19_int64

  accepted_interface%h_swap_m = 1.2500_real64
  accepted_interface%h_groundwater_m = 1.2498_real64
  accepted_interface%q_swap_m_per_s = 2.0e-8_real64
  accepted_interface%q_groundwater_m_per_s = -2.0e-8_real64

  call capture_modflow6_swap_predictor_origin(accepted_interface, 20.0_real64, lineage, .true., origin, status)
  call require(status == MODFLOW6_PREDICTOR_ORIGIN_OK .and. origin%structurally_valid(), &
       'committed accepted interface origin rejected')
  call require_close(origin%h_bot_start_m, accepted_interface%h_swap_m, 0.0_real64, &
       'H_bot_start did not retain accepted SWAP interface head')
  call require_close(origin%accepted_h_groundwater_m, accepted_interface%h_groundwater_m, 0.0_real64, &
       'groundwater provenance head not retained')
  call require_close(origin%accepted_head_residual_m, 2.0e-4_real64, 1.0e-15_real64, &
       'accepted nonzero head residual provenance mismatch')
  call require(origin%h_bot_start_m /= origin%accepted_h_groundwater_m, &
       'SWAP and groundwater heads were silently collapsed')

  call capture_modflow6_swap_predictor_origin(accepted_interface, 20.0_real64, lineage, .false., origin, status)
  call require(status == MODFLOW6_PREDICTOR_ORIGIN_NOT_COMMITTED .and. .not. origin%valid, &
       'uncommitted interface was accepted as next predictor origin')

  bad_interface = accepted_interface
  bad_interface%q_groundwater_m_per_s = -1.5e-8_real64
  call capture_modflow6_swap_predictor_origin(bad_interface, 20.0_real64, lineage, .true., origin, status)
  call require(status == MODFLOW6_PREDICTOR_ORIGIN_NONCONSERVATIVE_INTERFACE .and. .not. origin%valid, &
       'nonconservative interface was accepted as predictor origin')

  print '(a)', 'FGC30_HBOT_START_USES_ACCEPTED_SWAP_HEAD=PASS'
  print '(a)', 'FGC30_ACCEPTED_HEAD_RESIDUAL_PROVENANCE=PASS'
  print '(a)', 'FGC30_UNCOMMITTED_ORIGIN_FAIL_CLOSED=PASS'
  print '(a)', 'FGC30_NONCONSERVATIVE_ORIGIN_FAIL_CLOSED=PASS'
  print '(a)', 'FGC30_PREDICTOR_ORIGIN_GATE=PASS'

contains

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a)') 'FGC30_ORIGIN_FAIL: '//trim(message)
      error stop 1
    end if
  end subroutine require

  subroutine require_close(actual, expected, tolerance, message)
    real(real64), intent(in) :: actual, expected, tolerance
    character(len=*), intent(in) :: message
    call require(abs(actual-expected) <= tolerance, message)
  end subroutine require_close

end program test_fgc30_predictor_origin
