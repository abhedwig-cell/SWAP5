program test_fgc17_typed_groundwater_interface
  use, intrinsic :: ieee_arithmetic, only: ieee_quiet_nan, ieee_value
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_head_datum_t, &
       groundwater_interface_lineage_t, groundwater_interface_state_t, groundwater_interface_residual_t, &
       GW_INTERFACE_OK, GW_INTERFACE_INVALID_WINDOW, GW_INTERFACE_INVALID_DATUM, GW_INTERFACE_INVALID_HEAD, &
       GW_INTERFACE_INVALID_FLUX, swap_bottom_pressure_head_cm_to_interface_head_m, &
       interface_head_m_to_swap_bottom_pressure_head_cm, &
       swap_bottom_flux_cm_per_day_to_interface_flux_m_per_s, &
       interface_flux_m_per_s_to_swap_bottom_flux_cm_per_day, pair_groundwater_flux_from_swap, &
       evaluate_groundwater_interface_residual
  use mod_groundwater_coupling_policy, only: groundwater_head_convergence_policy_t, &
       GW_HEAD_POLICY_OK, GW_HEAD_POLICY_UNAVAILABLE, GW_HEAD_POLICY_INVALID_TOLERANCE, &
       GW_HEAD_POLICY_INVALID_PROVENANCE, GW_HEAD_POLICY_INVALID_RESIDUAL, &
       GW_HEAD_TOLERANCE_PROVENANCE_GOVERNED_EXTERNAL
  implicit none

  type(groundwater_coupling_window_t) :: window
  type(groundwater_head_datum_t) :: datum
  type(groundwater_interface_lineage_t) :: lineage
  type(groundwater_interface_state_t) :: state
  type(groundwater_interface_residual_t) :: residual
  type(groundwater_head_convergence_policy_t) :: policy
  real(real64) :: h_interface_m, pressure_head_cm
  real(real64) :: q_swap, q_groundwater, qbot_roundtrip
  real(real64) :: nan_value
  logical :: converged
  integer :: status

  nan_value = ieee_value(0.0_real64, ieee_quiet_nan)

  window%t0 = 4100.125_real64
  window%t1 = 4100.375_real64
  call require(window%valid(), 'generic non-midnight coupling window')
  window%t1 = window%t0
  call require(.not. window%valid(), 'zero coupling window rejected')
  window%t1 = nan_value
  call require(.not. window%valid(), 'non-finite coupling window rejected')
  window%t1 = 4100.375_real64

  datum%available = .true.
  datum%datum_id = 17001_int64
  datum%bottom_boundary_elevation_m = 10.0_real64
  call require(datum%valid(), 'explicit groundwater datum valid')

  call swap_bottom_pressure_head_cm_to_interface_head_m(-75.0_real64, datum, h_interface_m, status)
  call require(status == GW_INTERFACE_OK, 'pressure-head to hydraulic-head conversion status')
  call require(close(h_interface_m, 9.25_real64, 1.0e-14_real64), 'H equals z plus psi')
  call require(.not. close(h_interface_m, -0.75_real64, 1.0e-14_real64), &
       'pressure head is not silently hydraulic head')

  call interface_head_m_to_swap_bottom_pressure_head_cm(h_interface_m, datum, pressure_head_cm, status)
  call require(status == GW_INTERFACE_OK, 'hydraulic-head to pressure-head conversion status')
  call require(close(pressure_head_cm, -75.0_real64, 1.0e-12_real64), 'head conversion round trip')

  datum%available = .false.
  call interface_head_m_to_swap_bottom_pressure_head_cm(9.25_real64, datum, pressure_head_cm, status)
  call require(status == GW_INTERFACE_INVALID_DATUM, 'missing datum fails closed')
  datum%available = .true.
  call interface_head_m_to_swap_bottom_pressure_head_cm(nan_value, datum, pressure_head_cm, status)
  call require(status == GW_INTERFACE_INVALID_HEAD, 'non-finite head fails closed')

  call swap_bottom_flux_cm_per_day_to_interface_flux_m_per_s(1.25_real64, q_swap, status)
  call require(status == GW_INTERFACE_OK, 'qbot conversion status')
  call require(q_swap < 0.0_real64, 'positive native qbot becomes negative outward q_swap')
  call interface_flux_m_per_s_to_swap_bottom_flux_cm_per_day(q_swap, qbot_roundtrip, status)
  call require(status == GW_INTERFACE_OK, 'q_swap inverse conversion status')
  call require(close(qbot_roundtrip, 1.25_real64, 1.0e-14_real64), 'flux conversion round trip')

  call pair_groundwater_flux_from_swap(q_swap, q_groundwater, status)
  call require(status == GW_INTERFACE_OK, 'exact action reaction pairing status')
  call require(same_bits(q_groundwater, -q_swap), 'q_groundwater exact negative q_swap')
  call require(same_bits(q_swap + q_groundwater, 0.0_real64), 'flux residual bit-exact zero')
  call swap_bottom_flux_cm_per_day_to_interface_flux_m_per_s(nan_value, q_swap, status)
  call require(status == GW_INTERFACE_INVALID_FLUX, 'non-finite native flux fails closed')

  lineage%coupling_id = 17_int64
  lineage%swap_lineage_id = 1701_int64
  lineage%swap_origin_revision = 4_int64
  lineage%groundwater_lineage_id = 1702_int64
  lineage%groundwater_origin_revision = 9_int64
  lineage%candidate_revision = 10_int64
  call require(lineage%valid(), 'lineage and revision contract valid')
  lineage%candidate_revision = -1_int64
  call require(.not. lineage%valid(), 'negative candidate revision rejected')

  call swap_bottom_flux_cm_per_day_to_interface_flux_m_per_s(1.25_real64, q_swap, status)
  call pair_groundwater_flux_from_swap(q_swap, q_groundwater, status)
  state%h_swap_m = 9.251_real64
  state%h_groundwater_m = 9.250_real64
  state%q_swap_m_per_s = q_swap
  state%q_groundwater_m_per_s = q_groundwater
  call evaluate_groundwater_interface_residual(state, residual, status)
  call require(status == GW_INTERFACE_OK, 'interface residual evaluation')
  call require(close(residual%head_residual_m, 0.001_real64, 1.0e-14_real64), 'typed head residual')
  call require(same_bits(residual%flux_residual_m_per_s, 0.0_real64), 'typed flux residual exact')

  call require(.not. policy%valid(), 'default policy fails closed')
  call policy%evaluate(residual%head_residual_m, converged, status)
  call require(status == GW_HEAD_POLICY_UNAVAILABLE .and. .not. converged, 'unavailable policy rejected')

  policy%available = .true.
  policy%policy_id = 17001_int64
  policy%policy_version = 1
  policy%provenance_class = GW_HEAD_TOLERANCE_PROVENANCE_GOVERNED_EXTERNAL
  policy%provenance_id = 17002_int64
  policy%provenance_qualified = .true.
  policy%head_tolerance_m = 0.002_real64
  call require(policy%valid(), 'explicit provenance-bound head policy valid')
  call policy%evaluate(residual%head_residual_m, converged, status)
  call require(status == GW_HEAD_POLICY_OK .and. converged, 'head residual within explicit tolerance')
  call policy%evaluate(0.003_real64, converged, status)
  call require(status == GW_HEAD_POLICY_OK .and. .not. converged, 'head residual outside explicit tolerance')

  policy%head_tolerance_m = 0.0_real64
  call policy%evaluate(0.0_real64, converged, status)
  call require(status == GW_HEAD_POLICY_INVALID_TOLERANCE .and. .not. converged, 'zero tolerance not a default')
  policy%head_tolerance_m = 0.002_real64
  policy%provenance_qualified = .false.
  call policy%evaluate(0.0_real64, converged, status)
  call require(status == GW_HEAD_POLICY_INVALID_PROVENANCE .and. .not. converged, 'unqualified provenance rejected')
  policy%provenance_qualified = .true.
  call policy%evaluate(nan_value, converged, status)
  call require(status == GW_HEAD_POLICY_INVALID_RESIDUAL .and. .not. converged, 'non-finite residual rejected')
  policy%head_tolerance_m = nan_value
  call policy%evaluate(0.0_real64, converged, status)
  call require(status == GW_HEAD_POLICY_INVALID_TOLERANCE .and. .not. converged, 'non-finite tolerance rejected')

  write(*,'(A)') 'FGC17_GENERIC_WINDOW=PASS'
  write(*,'(A)') 'FGC17_DATUM_REQUIRED=PASS'
  write(*,'(A)') 'FGC17_H_EQUALS_Z_PLUS_PSI=PASS'
  write(*,'(A)') 'FGC17_HEAD_UNIT_ROUNDTRIP=PASS'
  write(*,'(A)') 'FGC17_QBOT_SIGN_UNIT_MAPPING=PASS'
  write(*,'(A)') 'FGC17_QSWAP_EQUALS_NEGATIVE_QGW=PASS'
  write(*,'(A)') 'FGC17_RESIDUAL_TYPE_SEPARATION=PASS'
  write(*,'(A)') 'FGC17_NO_DEFAULT_HEAD_TOLERANCE=PASS'
  write(*,'(A)') 'FGC17_PROVENANCE_BOUND_POLICY=PASS'
  write(*,'(A)') 'FGC17_FAIL_CLOSED_NONFINITE=PASS'
  write(*,'(A)') 'FGC17_TYPED_INTERFACE PASS'

contains

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FGC17_FAIL', trim(label)
      error stop 17
    end if
  end subroutine require

  pure logical function close(a, b, tolerance)
    real(real64), intent(in) :: a, b, tolerance
    close = abs(a-b) <= tolerance
  end function close

  pure logical function same_bits(a, b)
    real(real64), intent(in) :: a, b
    same_bits = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function same_bits

end program test_fgc17_typed_groundwater_interface
