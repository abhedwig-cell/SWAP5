module mod_modflow6_swap_prescribed_qbot_bottom_face
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t, &
       swap_bottom_pressure_head_cm_to_interface_head_m, GW_INTERFACE_OK
  implicit none
  private

  real(real64), parameter :: CM_TO_M = 0.01_real64

  integer, parameter, public :: MODFLOW6_BOTTOM_FACE_OK = 0
  integer, parameter, public :: MODFLOW6_BOTTOM_FACE_INVALID_INPUT = 1
  integer, parameter, public :: MODFLOW6_BOTTOM_FACE_INVALID_GEOMETRY = 2
  integer, parameter, public :: MODFLOW6_BOTTOM_FACE_INVALID_CONDUCTIVITY = 3
  integer, parameter, public :: MODFLOW6_BOTTOM_FACE_INVALID_DATUM = 4
  integer, parameter, public :: MODFLOW6_BOTTOM_FACE_NONFINITE = 5

  type, public :: modflow6_prescribed_qbot_bottom_face_t
    integer :: status = MODFLOW6_BOTTOM_FACE_INVALID_INPUT
    logical :: valid = .false.
    logical :: derivative_available = .false.
    real(real64) :: pressure_head_cm = 0.0_real64
    real(real64) :: hydraulic_head_m = 0.0_real64
    real(real64) :: dpressure_head_cm_per_qbot_cm_per_day = 0.0_real64
    real(real64) :: dhydraulic_head_m_per_qbot_cm_per_day = 0.0_real64
    character(len=64) :: route = 'not-available'
  end type modflow6_prescribed_qbot_bottom_face_t

  public :: materialize_modflow6_prescribed_qbot_bottom_face

contains

  subroutine materialize_modflow6_prescribed_qbot_bottom_face(bottom_node_pressure_head_cm, &
       bottom_conductivity_cm_per_day, qbot_cm_per_day, bottom_half_distance_cm, datum, &
       result, status, pressure_head_direction, conductivity_direction)
    real(real64), intent(in) :: bottom_node_pressure_head_cm
    real(real64), intent(in) :: bottom_conductivity_cm_per_day
    real(real64), intent(in) :: qbot_cm_per_day
    real(real64), intent(in) :: bottom_half_distance_cm
    type(groundwater_head_datum_t), intent(in) :: datum
    type(modflow6_prescribed_qbot_bottom_face_t), intent(out) :: result
    integer, intent(out) :: status
    real(real64), intent(in), optional :: pressure_head_direction
    real(real64), intent(in), optional :: conductivity_direction

    real(real64) :: pressure_head_cm, head_m, dpressure_head
    integer :: mapping_status

    result = modflow6_prescribed_qbot_bottom_face_t()

    status = MODFLOW6_BOTTOM_FACE_INVALID_INPUT
    if (.not. ieee_is_finite(bottom_node_pressure_head_cm) .or. &
        .not. ieee_is_finite(bottom_conductivity_cm_per_day) .or. &
        .not. ieee_is_finite(qbot_cm_per_day) .or. &
        .not. ieee_is_finite(bottom_half_distance_cm)) then
      result%status = status
      return
    end if

    status = MODFLOW6_BOTTOM_FACE_INVALID_GEOMETRY
    if (bottom_half_distance_cm <= 0.0_real64) then
      result%status = status
      return
    end if

    status = MODFLOW6_BOTTOM_FACE_INVALID_CONDUCTIVITY
    if (bottom_conductivity_cm_per_day <= 0.0_real64) then
      result%status = status
      return
    end if

    ! B1.10 bottom-face Darcy convention:
    !   grad_bottom = (h_n - h_bot)/d + 1
    !   q_bot       = -K_n * grad_bottom
    ! so for a prescribed native q_bot candidate the implied pressure head at
    ! the fixed lower face is
    !   h_bot = h_n + d * (1 + q_bot/K_n).
    ! This is the coupling-plane head. It is not the freatic groundwater level.
    pressure_head_cm = bottom_node_pressure_head_cm + bottom_half_distance_cm * &
         (1.0_real64 + qbot_cm_per_day / bottom_conductivity_cm_per_day)

    if (.not. ieee_is_finite(pressure_head_cm)) then
      status = MODFLOW6_BOTTOM_FACE_NONFINITE
      result%status = status
      return
    end if

    call swap_bottom_pressure_head_cm_to_interface_head_m(pressure_head_cm, datum, head_m, mapping_status)
    if (mapping_status /= GW_INTERFACE_OK) then
      status = MODFLOW6_BOTTOM_FACE_INVALID_DATUM
      result%status = status
      return
    end if

    result%pressure_head_cm = pressure_head_cm
    result%hydraulic_head_m = head_m
    result%route = 'b110-prescribed-qbot-bottom-face-darcy'

    if (present(pressure_head_direction) .neqv. present(conductivity_direction)) then
      status = MODFLOW6_BOTTOM_FACE_INVALID_INPUT
      result%status = status
      return
    end if

    if (present(pressure_head_direction)) then
      if (.not. ieee_is_finite(pressure_head_direction) .or. &
          .not. ieee_is_finite(conductivity_direction)) then
        status = MODFLOW6_BOTTOM_FACE_INVALID_INPUT
        result%status = status
        return
      end if

      ! Direction is with respect to the native prescribed-qbot control, whose
      ! direct derivative is one. K_n may itself vary through the terminal
      ! hydraulic state and must therefore be included in the quotient rule.
      dpressure_head = pressure_head_direction + bottom_half_distance_cm * &
           (1.0_real64 / bottom_conductivity_cm_per_day - &
            qbot_cm_per_day * conductivity_direction / bottom_conductivity_cm_per_day**2)
      if (.not. ieee_is_finite(dpressure_head)) then
        status = MODFLOW6_BOTTOM_FACE_NONFINITE
        result%status = status
        return
      end if
      result%dpressure_head_cm_per_qbot_cm_per_day = dpressure_head
      result%dhydraulic_head_m_per_qbot_cm_per_day = CM_TO_M * dpressure_head
      result%derivative_available = .true.
    end if

    result%status = MODFLOW6_BOTTOM_FACE_OK
    result%valid = .true.
    status = MODFLOW6_BOTTOM_FACE_OK
  end subroutine materialize_modflow6_prescribed_qbot_bottom_face

end module mod_modflow6_swap_prescribed_qbot_bottom_face
