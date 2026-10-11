program test_fci50_fgc17_admission
  use, intrinsic :: ieee_arithmetic, only: ieee_quiet_nan, ieee_value
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_head_datum_t, &
       groundwater_interface_state_t, groundwater_interface_residual_t, GW_INTERFACE_OK, &
       swap_bottom_pressure_head_cm_to_interface_head_m, interface_head_m_to_swap_bottom_pressure_head_cm, &
       swap_bottom_flux_cm_per_day_to_interface_flux_m_per_s, pair_groundwater_flux_from_swap, &
       evaluate_groundwater_interface_residual
  use mod_groundwater_coupling_policy, only: groundwater_head_convergence_policy_t, GW_HEAD_POLICY_OK, &
       GW_HEAD_POLICY_UNAVAILABLE, GW_HEAD_POLICY_INVALID_RESIDUAL, &
       GW_HEAD_TOLERANCE_PROVENANCE_GOVERNED_EXTERNAL
  implicit none

  type(groundwater_coupling_window_t) :: window
  type(groundwater_head_datum_t) :: datum
  type(groundwater_interface_state_t) :: state
  type(groundwater_interface_residual_t) :: residual
  type(groundwater_head_convergence_policy_t) :: policy
  real(real64) :: h, psi, qswap, qgw, nan_value
  logical :: converged
  integer :: status

  nan_value = ieee_value(0.0_real64, ieee_quiet_nan)

  window%t0 = 8123.375_real64
  window%t1 = 8123.625_real64
  call require(window%valid(), 'generic non-midnight window')

  datum%available = .true.
  datum%datum_id = 50001_int64
  datum%bottom_boundary_elevation_m = 100.0_real64
  call swap_bottom_pressure_head_cm_to_interface_head_m(-200.0_real64, datum, h, status)
  call require(status == GW_INTERFACE_OK, 'head forward status')
  call require(abs(h-98.0_real64) <= 1.0e-14_real64, 'H=z+psi')
  call interface_head_m_to_swap_bottom_pressure_head_cm(h, datum, psi, status)
  call require(status == GW_INTERFACE_OK, 'head inverse status')
  call require(abs(psi+200.0_real64) <= 1.0e-12_real64, 'head round trip')

  call swap_bottom_flux_cm_per_day_to_interface_flux_m_per_s(2.0_real64, qswap, status)
  call require(status == GW_INTERFACE_OK .and. qswap < 0.0_real64, 'native qbot sign and unit map')
  call pair_groundwater_flux_from_swap(qswap, qgw, status)
  call require(status == GW_INTERFACE_OK, 'paired groundwater flux')
  call require(transfer(qswap+qgw,0_int64) == transfer(0.0_real64,0_int64), 'exact flux residual')

  state%h_swap_m = 98.001_real64
  state%h_groundwater_m = 98.0_real64
  state%q_swap_m_per_s = qswap
  state%q_groundwater_m_per_s = qgw
  call evaluate_groundwater_interface_residual(state, residual, status)
  call require(status == GW_INTERFACE_OK, 'typed residual status')
  call require(abs(residual%head_residual_m-0.001_real64) <= 1.0e-13_real64, 'head residual')
  call require(transfer(residual%flux_residual_m_per_s,0_int64) == transfer(0.0_real64,0_int64), 'flux residual')

  call policy%evaluate(residual%head_residual_m, converged, status)
  call require(status == GW_HEAD_POLICY_UNAVAILABLE .and. .not. converged, 'default policy fails closed')
  policy%available = .true.
  policy%policy_id = 50001_int64
  policy%policy_version = 1
  policy%provenance_class = GW_HEAD_TOLERANCE_PROVENANCE_GOVERNED_EXTERNAL
  policy%provenance_id = 50002_int64
  policy%provenance_qualified = .true.
  policy%head_tolerance_m = 0.002_real64
  call policy%evaluate(residual%head_residual_m, converged, status)
  call require(status == GW_HEAD_POLICY_OK .and. converged, 'explicit governed tolerance accepts')
  call policy%evaluate(nan_value, converged, status)
  call require(status == GW_HEAD_POLICY_INVALID_RESIDUAL .and. .not. converged, 'nan residual fails closed')

  write(*,'(A)') 'FCI50_GENERIC_WINDOW=PASS'
  write(*,'(A)') 'FCI50_DATUM_HEAD_MAPPING=PASS'
  write(*,'(A)') 'FCI50_QBOT_INTERFACE_SIGN_UNITS=PASS'
  write(*,'(A)') 'FCI50_EXACT_FLUX_PAIRING=PASS'
  write(*,'(A)') 'FCI50_POLICY_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FCI50_FGC17_ADMISSION_REPLAY PASS'

contains

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FCI50_FAIL', trim(label)
      error stop 50
    end if
  end subroutine require

end program test_fci50_fgc17_admission
