module mod_groundwater_coupling_response
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_interface_lineage_t
  use mod_groundwater_response_sensitivity_contract, only: groundwater_response_sensitivity_t, GW_RESPONSE_OK
  use mod_accepted_trajectory_directional_publication, only: accepted_trajectory_direction_result_t
  use mod_soil_water_accepted_step_direction_contract, only: SW_STEP_CONTROL_BOTTOM_HEAD
  implicit none
  private

  real(real64), parameter :: DAY_TO_S = 86400.0_real64

  integer, parameter, public :: GW_COUPLING_RESPONSE_OK = 0
  integer, parameter, public :: GW_COUPLING_RESPONSE_INVALID_WINDOW = 1
  integer, parameter, public :: GW_COUPLING_RESPONSE_INVALID_LINEAGE = 2
  integer, parameter, public :: GW_COUPLING_RESPONSE_SWAP_TANGENT_UNAVAILABLE = 3
  integer, parameter, public :: GW_COUPLING_RESPONSE_SWAP_SCOPE_MISMATCH = 4
  integer, parameter, public :: GW_COUPLING_RESPONSE_SWAP_CONTROL_MISMATCH = 5
  integer, parameter, public :: GW_COUPLING_RESPONSE_GW_TANGENT_UNAVAILABLE = 6
  integer, parameter, public :: GW_COUPLING_RESPONSE_GW_PROVENANCE_MISMATCH = 7
  integer, parameter, public :: GW_COUPLING_RESPONSE_EXTRA_FULL_SOLVE = 8
  integer, parameter, public :: GW_COUPLING_RESPONSE_ILL_CONDITIONED = 9
  integer, parameter, public :: GW_COUPLING_RESPONSE_NONFINITE = 10

  type, public :: groundwater_coupling_response_t
    integer :: status = GW_COUPLING_RESPONSE_SWAP_TANGENT_UNAVAILABLE
    logical :: available = .false.
    type(groundwater_coupling_window_t) :: window
    integer(int64) :: swap_lineage_id = 0_int64
    integer(int64) :: swap_origin_revision = -1_int64
    integer(int64) :: groundwater_lineage_id = 0_int64
    integer(int64) :: groundwater_origin_revision = -1_int64
    integer(int64) :: groundwater_candidate_revision = -1_int64
    integer :: accepted_steps = 0
    integer :: additional_tridiagonal_backsolves = 0
    integer :: additional_jacobian_builds = 0
    integer :: additional_full_nonlinear_solves = 0
    real(real64) :: integrated_qbot_derivative_per_hbot_cm = 0.0_real64
    real(real64) :: dq_swap_dh_swap_per_s = 0.0_real64
    real(real64) :: dq_groundwater_dh_swap_per_s = 0.0_real64
    real(real64) :: dh_groundwater_dh_swap = 0.0_real64
    real(real64) :: head_residual_jacobian = 0.0_real64
    real(real64) :: predictor_h_swap_m = 0.0_real64
    real(real64) :: predictor_head_residual_m = 0.0_real64
    real(real64) :: corrector_h_swap_m = 0.0_real64
    character(len=48) :: swap_tangent_method = 'not-available'
    character(len=64) :: swap_tangent_route = 'not-available'
  end type groundwater_coupling_response_t

  public :: compose_groundwater_coupling_response

contains

  subroutine compose_groundwater_coupling_response(window, lineage, swap_lineage_id, swap_origin_revision, &
       swap_direction, groundwater_response, predictor_h_swap_m, predictor_head_residual_m, response, status)
    type(groundwater_coupling_window_t), intent(in) :: window
    type(groundwater_interface_lineage_t), intent(in) :: lineage
    integer(int64), intent(in) :: swap_lineage_id, swap_origin_revision
    type(accepted_trajectory_direction_result_t), intent(in) :: swap_direction
    type(groundwater_response_sensitivity_t), intent(in) :: groundwater_response
    real(real64), intent(in) :: predictor_h_swap_m, predictor_head_residual_m
    type(groundwater_coupling_response_t), intent(out) :: response
    integer, intent(out) :: status

    real(real64) :: duration_day, native_integrated_derivative
    real(real64) :: dq_groundwater_dh_swap, dh_groundwater_dh_swap
    real(real64) :: jacobian, jacobian_scale, jacobian_floor, corrector_h

    response = groundwater_coupling_response_t()
    status = GW_COUPLING_RESPONSE_INVALID_WINDOW
    if (.not. window%valid()) then
      response%status = status
      return
    end if
    duration_day = window%t1 - window%t0
    if (.not. ieee_is_finite(duration_day) .or. duration_day <= 0.0_real64) then
      response%status = status
      return
    end if

    status = GW_COUPLING_RESPONSE_INVALID_LINEAGE
    if (.not. lineage%valid()) then
      response%status = status
      return
    end if
    if (swap_lineage_id /= lineage%swap_lineage_id .or. &
        swap_origin_revision /= lineage%swap_origin_revision) then
      response%status = status
      return
    end if

    status = GW_COUPLING_RESPONSE_SWAP_TANGENT_UNAVAILABLE
    if (.not. swap_direction%requested .or. .not. swap_direction%available .or. &
        swap_direction%accepted_steps <= 0) then
      response%status = status
      return
    end if
    if (.not. ieee_is_finite(swap_direction%accepted_bottom_exchange_derivative) .or. &
        .not. ieee_is_finite(swap_direction%origin_t0) .or. &
        .not. ieee_is_finite(swap_direction%accepted_t1)) then
      status = GW_COUPLING_RESPONSE_NONFINITE
      response%status = status
      return
    end if

    status = GW_COUPLING_RESPONSE_SWAP_SCOPE_MISMATCH
    if (.not. same_time(swap_direction%origin_t0, window%t0) .or. &
        .not. same_time(swap_direction%accepted_t1, window%t1)) then
      response%status = status
      return
    end if

    status = GW_COUPLING_RESPONSE_SWAP_CONTROL_MISMATCH
    if (swap_direction%control_coordinate /= SW_STEP_CONTROL_BOTTOM_HEAD) then
      response%status = status
      return
    end if

    status = GW_COUPLING_RESPONSE_EXTRA_FULL_SOLVE
    if (swap_direction%additional_full_nonlinear_solves /= 0 .or. &
        swap_direction%additional_jacobian_builds < 0 .or. &
        swap_direction%additional_tridiagonal_backsolves < 0) then
      response%status = status
      return
    end if

    status = GW_COUPLING_RESPONSE_GW_TANGENT_UNAVAILABLE
    if (groundwater_response%status /= GW_RESPONSE_OK .or. .not. groundwater_response%available) then
      response%status = status
      return
    end if
    if (.not. ieee_is_finite(groundwater_response%dh_groundwater_dq_groundwater_s)) then
      status = GW_COUPLING_RESPONSE_NONFINITE
      response%status = status
      return
    end if

    status = GW_COUPLING_RESPONSE_GW_PROVENANCE_MISMATCH
    if (.not. groundwater_response%window%valid()) then
      response%status = status
      return
    end if
    if (.not. same_time(groundwater_response%window%t0, window%t0) .or. &
        .not. same_time(groundwater_response%window%t1, window%t1)) then
      response%status = status
      return
    end if
    if (groundwater_response%groundwater_lineage_id /= lineage%groundwater_lineage_id .or. &
        groundwater_response%origin_revision /= lineage%groundwater_origin_revision .or. &
        groundwater_response%candidate_revision /= lineage%candidate_revision) then
      response%status = status
      return
    end if

    if (.not. ieee_is_finite(predictor_h_swap_m) .or. .not. ieee_is_finite(predictor_head_residual_m)) then
      status = GW_COUPLING_RESPONSE_NONFINITE
      response%status = status
      return
    end if

    ! F-KT21 integrates the native SWAP qbot derivative over accepted steps:
    !   D = d(int qbot dt_day) / d(hbot_cm).
    ! q_swap is outward from SWAP and q_groundwater = -q_swap. Because
    ! H_swap[m] changes 0.01 m per hbot[cm], the cm-to-m factors cancel and
    ! the exact whole-window mean-flux derivatives become
    !   dq_swap/dH_swap = -D/(duration_day*86400)
    !   dq_groundwater/dH_swap = +D/(duration_day*86400).
    native_integrated_derivative = swap_direction%accepted_bottom_exchange_derivative
    dq_groundwater_dh_swap = native_integrated_derivative / (duration_day * DAY_TO_S)
    dh_groundwater_dh_swap = groundwater_response%dh_groundwater_dq_groundwater_s * &
         dq_groundwater_dh_swap
    jacobian = 1.0_real64 - dh_groundwater_dh_swap

    if (.not. ieee_is_finite(dq_groundwater_dh_swap) .or. &
        .not. ieee_is_finite(dh_groundwater_dh_swap) .or. .not. ieee_is_finite(jacobian)) then
      status = GW_COUPLING_RESPONSE_NONFINITE
      response%status = status
      return
    end if

    ! Numerical conditioning safeguard only. This is not a coupling tolerance,
    ! application-accuracy value or project-specific physical default.
    jacobian_scale = max(1.0_real64, abs(dh_groundwater_dh_swap), abs(jacobian))
    jacobian_floor = 128.0_real64 * epsilon(1.0_real64) * jacobian_scale
    if (abs(jacobian) <= jacobian_floor) then
      status = GW_COUPLING_RESPONSE_ILL_CONDITIONED
      response%status = status
      return
    end if

    corrector_h = predictor_h_swap_m - predictor_head_residual_m / jacobian
    if (.not. ieee_is_finite(corrector_h)) then
      status = GW_COUPLING_RESPONSE_NONFINITE
      response%status = status
      return
    end if

    response%status = GW_COUPLING_RESPONSE_OK
    response%available = .true.
    response%window = window
    response%swap_lineage_id = swap_lineage_id
    response%swap_origin_revision = swap_origin_revision
    response%groundwater_lineage_id = groundwater_response%groundwater_lineage_id
    response%groundwater_origin_revision = groundwater_response%origin_revision
    response%groundwater_candidate_revision = groundwater_response%candidate_revision
    response%accepted_steps = swap_direction%accepted_steps
    response%additional_tridiagonal_backsolves = swap_direction%additional_tridiagonal_backsolves
    response%additional_jacobian_builds = swap_direction%additional_jacobian_builds
    response%additional_full_nonlinear_solves = swap_direction%additional_full_nonlinear_solves
    response%integrated_qbot_derivative_per_hbot_cm = native_integrated_derivative
    response%dq_swap_dh_swap_per_s = -dq_groundwater_dh_swap
    response%dq_groundwater_dh_swap_per_s = dq_groundwater_dh_swap
    response%dh_groundwater_dh_swap = dh_groundwater_dh_swap
    response%head_residual_jacobian = jacobian
    response%predictor_h_swap_m = predictor_h_swap_m
    response%predictor_head_residual_m = predictor_head_residual_m
    response%corrector_h_swap_m = corrector_h
    response%swap_tangent_method = swap_direction%method
    response%swap_tangent_route = swap_direction%route
    status = GW_COUPLING_RESPONSE_OK
  end subroutine compose_groundwater_coupling_response

  pure logical function same_time(a, b) result(matches)
    real(real64), intent(in) :: a, b
    real(real64) :: scale

    matches = .false.
    if (.not. ieee_is_finite(a) .or. .not. ieee_is_finite(b)) return
    scale = max(1.0_real64, abs(a), abs(b))
    matches = abs(a-b) <= 64.0_real64 * epsilon(1.0_real64) * scale
  end function same_time

end module mod_groundwater_coupling_response
