module mod_modflow6_swap_predictor_response
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_interface_lineage_t
  implicit none
  private

  real(real64), parameter :: CM_TO_M = 0.01_real64
  real(real64), parameter :: M_TO_CM = 100.0_real64
  real(real64), parameter :: DAY_TO_S = 86400.0_real64

  integer, parameter, public :: MODFLOW6_DERIVATIVE_NONE = 0
  integer, parameter, public :: MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT = 1
  integer, parameter, public :: MODFLOW6_DERIVATIVE_CENTERED_FD = 2

  integer, parameter, public :: MODFLOW6_PREDICTOR_OK = 0
  integer, parameter, public :: MODFLOW6_PREDICTOR_INVALID_WINDOW = 1
  integer, parameter, public :: MODFLOW6_PREDICTOR_INVALID_LINEAGE = 2
  integer, parameter, public :: MODFLOW6_PREDICTOR_INVALID_INPUT = 3
  integer, parameter, public :: MODFLOW6_PREDICTOR_INVALID_DERIVATIVE_METHOD = 4
  integer, parameter, public :: MODFLOW6_PREDICTOR_INCOMPLETE_DERIVATIVE_COVERAGE = 5
  integer, parameter, public :: MODFLOW6_PREDICTOR_ILL_CONDITIONED_DERIVATIVE = 6
  integer, parameter, public :: MODFLOW6_PREDICTOR_NONFINITE = 7

  ! Coverage is deliberately explicit rather than inferred from `available`.
  ! Active state-dependent owners must be covered before an analytic trajectory
  ! tangent may be authoritative for F-GC30. Centered finite difference samples
  ! the complete production trajectory and therefore remains admissible when
  ! analytic process coverage is incomplete.
  type, public :: modflow6_derivative_coverage_t
    logical :: lower_face_head_semantics_covered = .false.
    logical :: richards_hydraulic_response_covered = .false.
    logical :: constitutive_response_covered = .false.
    logical :: dynamic_top_boundary_active = .false.
    logical :: dynamic_top_boundary_covered = .false.
    logical :: root_uptake_active = .false.
    logical :: root_uptake_covered = .false.
    logical :: drainage_active = .false.
    logical :: drainage_covered = .false.
    logical :: other_state_dependent_source_sink_active = .false.
    logical :: other_state_dependent_source_sink_covered = .false.
  contains
    procedure :: tangent_complete => modflow6_tangent_coverage_complete
  end type modflow6_derivative_coverage_t

  type, public :: modflow6_swap_predictor_response_t
    integer :: status = MODFLOW6_PREDICTOR_INVALID_INPUT
    logical :: valid = .false.
    type(groundwater_coupling_window_t) :: window
    type(groundwater_interface_lineage_t) :: lineage
    real(real64) :: q_bot_predictor_cm_per_day = 0.0_real64
    real(real64) :: h_bot_start_m = 0.0_real64
    real(real64) :: h_bot_end_m = 0.0_real64
    ! Native derivative used by the historical SWAP coupling definition:
    ! d(H_bot[cm]) / d(q_bot[cm/day]), hence units day.
    real(real64) :: dh_bot_end_cm_per_qbot_cm_per_day = 0.0_real64
    real(real64) :: coupling_storage_coefficient_u = 0.0_real64
    ! q_u uses the public outward-from-SWAP sign while retaining native cm/day
    ! for transparent reproduction of the historical equation.
    real(real64) :: q_u_cm_per_day = 0.0_real64
    real(real64) :: q_u_m_per_s = 0.0_real64
    integer :: derivative_kind = MODFLOW6_DERIVATIVE_NONE
    character(len=48) :: derivative_method = 'not-available'
    character(len=64) :: derivative_route = 'not-available'
    type(modflow6_derivative_coverage_t) :: derivative_coverage
  end type modflow6_swap_predictor_response_t

  public :: compose_modflow6_swap_predictor_response

contains

  pure logical function modflow6_tangent_coverage_complete(self) result(complete)
    class(modflow6_derivative_coverage_t), intent(in) :: self

    complete = self%lower_face_head_semantics_covered .and. &
               self%richards_hydraulic_response_covered .and. &
               self%constitutive_response_covered
    if (self%dynamic_top_boundary_active) complete = complete .and. self%dynamic_top_boundary_covered
    if (self%root_uptake_active) complete = complete .and. self%root_uptake_covered
    if (self%drainage_active) complete = complete .and. self%drainage_covered
    if (self%other_state_dependent_source_sink_active) &
      complete = complete .and. self%other_state_dependent_source_sink_covered
  end function modflow6_tangent_coverage_complete

  subroutine compose_modflow6_swap_predictor_response(window, lineage, q_bot_predictor_cm_per_day, &
       h_bot_start_m, h_bot_end_m, dh_bot_end_cm_per_qbot_cm_per_day, derivative_kind, coverage, &
       derivative_method, derivative_route, response, status)
    type(groundwater_coupling_window_t), intent(in) :: window
    type(groundwater_interface_lineage_t), intent(in) :: lineage
    real(real64), intent(in) :: q_bot_predictor_cm_per_day
    real(real64), intent(in) :: h_bot_start_m, h_bot_end_m
    real(real64), intent(in) :: dh_bot_end_cm_per_qbot_cm_per_day
    integer, intent(in) :: derivative_kind
    type(modflow6_derivative_coverage_t), intent(in) :: coverage
    character(len=*), intent(in), optional :: derivative_method, derivative_route
    type(modflow6_swap_predictor_response_t), intent(out) :: response
    integer, intent(out) :: status

    real(real64) :: duration_day, derivative_scale, derivative_floor
    real(real64) :: delta_h_bot_cm, u, q_u_cm_per_day, q_u_m_per_s

    response = modflow6_swap_predictor_response_t()

    status = MODFLOW6_PREDICTOR_INVALID_WINDOW
    if (.not. window%valid()) then
      response%status = status
      return
    end if
    duration_day = window%t1 - window%t0

    status = MODFLOW6_PREDICTOR_INVALID_LINEAGE
    if (.not. lineage%valid()) then
      response%status = status
      return
    end if

    status = MODFLOW6_PREDICTOR_INVALID_INPUT
    if (.not. ieee_is_finite(q_bot_predictor_cm_per_day) .or. &
        .not. ieee_is_finite(h_bot_start_m) .or. .not. ieee_is_finite(h_bot_end_m) .or. &
        .not. ieee_is_finite(dh_bot_end_cm_per_qbot_cm_per_day)) then
      response%status = status
      return
    end if
    if (.not. coverage%lower_face_head_semantics_covered) then
      response%status = status
      return
    end if

    status = MODFLOW6_PREDICTOR_INVALID_DERIVATIVE_METHOD
    select case (derivative_kind)
    case (MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT)
      if (.not. coverage%tangent_complete()) then
        status = MODFLOW6_PREDICTOR_INCOMPLETE_DERIVATIVE_COVERAGE
        response%status = status
        response%derivative_coverage = coverage
        response%derivative_kind = derivative_kind
        return
      end if
    case (MODFLOW6_DERIVATIVE_CENTERED_FD)
      continue
    case default
      response%status = status
      return
    end select

    derivative_scale = max(1.0_real64, abs(dh_bot_end_cm_per_qbot_cm_per_day))
    derivative_floor = 128.0_real64 * epsilon(1.0_real64) * derivative_scale
    if (abs(dh_bot_end_cm_per_qbot_cm_per_day) <= derivative_floor) then
      status = MODFLOW6_PREDICTOR_ILL_CONDITIONED_DERIVATIVE
      response%status = status
      response%derivative_coverage = coverage
      response%derivative_kind = derivative_kind
      return
    end if

    ! Historical SWAP4 coupling equation in native SWAP units and sign:
    !   u   = dt_day / (dH_bot_cm / dq_bot_cm_per_day)
    !   q_u = u * (H_end_cm-H_start_cm) / dt_day - q_bot
    ! Native q_bot is positive into SWAP. Therefore q_u is positive outward
    ! from SWAP, consistent with Groundwater Coupling v1's public direction.
    delta_h_bot_cm = (h_bot_end_m - h_bot_start_m) * M_TO_CM
    u = duration_day / dh_bot_end_cm_per_qbot_cm_per_day
    q_u_cm_per_day = u * delta_h_bot_cm / duration_day - q_bot_predictor_cm_per_day
    q_u_m_per_s = q_u_cm_per_day * CM_TO_M / DAY_TO_S

    if (.not. ieee_is_finite(u) .or. .not. ieee_is_finite(q_u_cm_per_day) .or. &
        .not. ieee_is_finite(q_u_m_per_s)) then
      status = MODFLOW6_PREDICTOR_NONFINITE
      response%status = status
      return
    end if

    response%status = MODFLOW6_PREDICTOR_OK
    response%valid = .true.
    response%window = window
    response%lineage = lineage
    response%q_bot_predictor_cm_per_day = q_bot_predictor_cm_per_day
    response%h_bot_start_m = h_bot_start_m
    response%h_bot_end_m = h_bot_end_m
    response%dh_bot_end_cm_per_qbot_cm_per_day = dh_bot_end_cm_per_qbot_cm_per_day
    response%coupling_storage_coefficient_u = u
    response%q_u_cm_per_day = q_u_cm_per_day
    response%q_u_m_per_s = q_u_m_per_s
    response%derivative_kind = derivative_kind
    response%derivative_coverage = coverage
    if (present(derivative_method)) then
      response%derivative_method = derivative_method
    else if (derivative_kind == MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT) then
      response%derivative_method = 'accepted-trajectory-tangent'
    else
      response%derivative_method = 'centered-finite-difference'
    end if
    if (present(derivative_route)) response%derivative_route = derivative_route
    status = MODFLOW6_PREDICTOR_OK
  end subroutine compose_modflow6_swap_predictor_response

end module mod_modflow6_swap_predictor_response
