program test_gc_low01a_below_profile_equivalence
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t, &
       interface_head_m_to_swap_bottom_pressure_head_cm, &
       swap_bottom_pressure_head_cm_to_interface_head_m, GW_INTERFACE_OK
  implicit none

  real(real64), parameter :: node_z_bottom_m = -2.5_real64
  real(real64), parameter :: node_dz_bottom_m = 1.0_real64
  real(real64), parameter :: bottom_face_m = node_z_bottom_m - 0.5_real64 * node_dz_bottom_m
  real(real64), parameter :: levels_m(4) = [-3.1_real64, -3.5_real64, -5.0_real64, -10.0_real64]
  real(real64), parameter :: hbot_tol_cm = 1.0e-12_real64
  real(real64), parameter :: head_tol_m = 1.0e-14_real64

  type(groundwater_head_datum_t) :: datum
  real(real64) :: legacy_hbot_cm, typed_hbot_cm, roundtrip_head_m
  integer :: i, status

  datum%available = .true.
  datum%datum_id = 1_int64
  datum%bottom_boundary_elevation_m = bottom_face_m

  if (abs(bottom_face_m + 3.0_real64) > 1.0e-15_real64) error stop 'LOW01-A frozen bottom-face geometry'

  do i = 1, size(levels_m)
    if (levels_m(i) >= bottom_face_m) error stop 'LOW01-A level not below profile'

    legacy_hbot_cm = (levels_m(i) - node_z_bottom_m + 0.5_real64 * node_dz_bottom_m) * 100.0_real64

    call interface_head_m_to_swap_bottom_pressure_head_cm(levels_m(i), datum, typed_hbot_cm, status)
    if (status /= GW_INTERFACE_OK) error stop 'LOW01-A typed head->hbot conversion failed'
    if (abs(typed_hbot_cm - legacy_hbot_cm) > hbot_tol_cm) error stop 'LOW01-A hbot equivalence failed'

    call swap_bottom_pressure_head_cm_to_interface_head_m(typed_hbot_cm, datum, roundtrip_head_m, status)
    if (status /= GW_INTERFACE_OK) error stop 'LOW01-A typed hbot->head conversion failed'
    if (abs(roundtrip_head_m - levels_m(i)) > head_tol_m) error stop 'LOW01-A roundtrip failed'

    write(*,'(A,F0.16)') 'GC_LOW01A_GWL_M=', levels_m(i)
    write(*,'(A,F0.16)') 'GC_LOW01A_LEGACY_HBOT_CM=', legacy_hbot_cm
    write(*,'(A,F0.16)') 'GC_LOW01A_TYPED_HBOT_CM=', typed_hbot_cm
    write(*,'(A,ES24.16)') 'GC_LOW01A_HBOT_ERROR_CM=', typed_hbot_cm - legacy_hbot_cm
    write(*,'(A,ES24.16)') 'GC_LOW01A_ROUNDTRIP_ERROR_M=', roundtrip_head_m - levels_m(i)
  end do

  write(*,'(A)') 'GC_LOW01A_BELOW_PROFILE_LEVELS=PASS'
  write(*,'(A)') 'GC_LOW01A_LEGACY_TYPED_HBOT_EQUIVALENCE=PASS'
  write(*,'(A)') 'GC_LOW01A_HEAD_ROUNDTRIP=PASS'
  write(*,'(A)') 'GC_LOW01A_NUMERIC_GATE=PASS'
end program test_gc_low01a_below_profile_equivalence
