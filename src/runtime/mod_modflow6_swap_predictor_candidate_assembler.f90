module mod_modflow6_swap_predictor_candidate_assembler
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_kernel_transactions, only: kernel_candidate_state_t, kernel_result_t
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_soil_water_accepted_step_direction_contract, only: SW_STEP_CONTROL_BOTTOM_FLUX
  use mod_modflow6_swap_predictor_response, only: modflow6_swap_predictor_response_t, &
       compose_modflow6_swap_predictor_response, MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT, &
       MODFLOW6_PREDICTOR_OK
  use mod_modflow6_swap_predictor_origin, only: modflow6_swap_predictor_origin_t
  use mod_modflow6_swap_predictor_tangent_adapter, only: modflow6_swap_predictor_tangent_endpoint_t, &
       MODFLOW6_TANGENT_ENDPOINT_OK
  implicit none
  private

  integer, parameter, public :: MODFLOW6_PREDICTOR_ASSEMBLER_OK = 0
  integer, parameter, public :: MODFLOW6_PREDICTOR_ASSEMBLER_INVALID_ORIGIN = 1
  integer, parameter, public :: MODFLOW6_PREDICTOR_ASSEMBLER_INVALID_WINDOW = 2
  integer, parameter, public :: MODFLOW6_PREDICTOR_ASSEMBLER_INVALID_CANDIDATE = 3
  integer, parameter, public :: MODFLOW6_PREDICTOR_ASSEMBLER_LINEAGE_MISMATCH = 4
  integer, parameter, public :: MODFLOW6_PREDICTOR_ASSEMBLER_CANDIDATE_INTERVAL_MISMATCH = 5
  integer, parameter, public :: MODFLOW6_PREDICTOR_ASSEMBLER_RESULT_INTERVAL_MISMATCH = 6
  integer, parameter, public :: MODFLOW6_PREDICTOR_ASSEMBLER_TRAJECTORY_MISMATCH = 7
  integer, parameter, public :: MODFLOW6_PREDICTOR_ASSEMBLER_BOTTOM_EXCHANGE_UNAVAILABLE = 8
  integer, parameter, public :: MODFLOW6_PREDICTOR_ASSEMBLER_INVALID_ENDPOINT = 9
  integer, parameter, public :: MODFLOW6_PREDICTOR_ASSEMBLER_NONFINITE_TERMINAL_FLUX = 10
  integer, parameter, public :: MODFLOW6_PREDICTOR_ASSEMBLER_RESPONSE_FAILED = 11

  public :: assemble_modflow6_swap_predictor_response

contains

  subroutine assemble_modflow6_swap_predictor_response(origin, window, candidate, kernel_result, endpoint, &
       response, status)
    type(modflow6_swap_predictor_origin_t), intent(in) :: origin
    type(groundwater_coupling_window_t), intent(in) :: window
    type(kernel_candidate_state_t), intent(in) :: candidate
    type(kernel_result_t), intent(in) :: kernel_result
    type(modflow6_swap_predictor_tangent_endpoint_t), intent(in) :: endpoint
    type(modflow6_swap_predictor_response_t), intent(out) :: response
    integer, intent(out) :: status

    real(real64) :: candidate_t0, candidate_t1, qbot_cm_per_day
    logical :: candidate_interval_available
    integer :: compose_status

    response = modflow6_swap_predictor_response_t()

    status = MODFLOW6_PREDICTOR_ASSEMBLER_INVALID_ORIGIN
    if (.not. origin%structurally_valid()) return

    status = MODFLOW6_PREDICTOR_ASSEMBLER_INVALID_WINDOW
    if (.not. window%valid()) return
    if (.not. same_time_value(origin%accepted_time, window%t0)) return

    status = MODFLOW6_PREDICTOR_ASSEMBLER_INVALID_CANDIDATE
    if (.not. candidate%ready()) return

    status = MODFLOW6_PREDICTOR_ASSEMBLER_LINEAGE_MISMATCH
    if (candidate%current_lineage_id() /= origin%lineage%swap_lineage_id) return
    if (candidate%origin_revision() /= origin%lineage%swap_origin_revision) return

    call candidate%origin_interval(candidate_t0, candidate_t1, candidate_interval_available)
    status = MODFLOW6_PREDICTOR_ASSEMBLER_CANDIDATE_INTERVAL_MISMATCH
    if (.not. candidate_interval_available) return
    if (.not. same_time_value(candidate_t0, window%t0)) return
    if (.not. same_time_value(candidate_t1, window%t1)) return

    status = MODFLOW6_PREDICTOR_ASSEMBLER_RESULT_INTERVAL_MISMATCH
    if (.not. kernel_result%completed) return
    if (.not. same_time_value(kernel_result%requested_t0, window%t0)) return
    if (.not. same_time_value(kernel_result%requested_t1, window%t1)) return
    if (.not. same_time_value(kernel_result%completed_t, window%t1)) return

    status = MODFLOW6_PREDICTOR_ASSEMBLER_TRAJECTORY_MISMATCH
    if (.not. kernel_result%accepted_trajectory_direction%requested) return
    if (.not. kernel_result%accepted_trajectory_direction%available) return
    if (kernel_result%accepted_trajectory_direction%control_coordinate /= SW_STEP_CONTROL_BOTTOM_FLUX) return
    if (kernel_result%accepted_trajectory_direction%additional_full_nonlinear_solves /= 0) return
    if (endpoint%worker_id /= kernel_result%accepted_trajectory_direction%worker_id) return
    if (endpoint%trajectory_generation /= kernel_result%accepted_trajectory_direction%generation) return
    if (endpoint%accepted_steps /= kernel_result%accepted_trajectory_direction%accepted_steps) return
    if (trim(endpoint%derivative_method) /= trim(kernel_result%accepted_trajectory_direction%method)) return

    status = MODFLOW6_PREDICTOR_ASSEMBLER_BOTTOM_EXCHANGE_UNAVAILABLE
    if (.not. kernel_result%bottom_interface_exchange_available) return

    status = MODFLOW6_PREDICTOR_ASSEMBLER_NONFINITE_TERMINAL_FLUX
    if (.not. ieee_is_finite(kernel_result%terminal_bottom_outward_flux_native)) return
    qbot_cm_per_day = -kernel_result%terminal_bottom_outward_flux_native

    status = MODFLOW6_PREDICTOR_ASSEMBLER_INVALID_ENDPOINT
    if (endpoint%status /= MODFLOW6_TANGENT_ENDPOINT_OK) return
    if (.not. endpoint%available .or. .not. endpoint%authoritative) return
    if (.not. endpoint%bottom_face%valid .or. .not. endpoint%bottom_face%derivative_available) return
    if (.not. endpoint%coverage%tangent_complete()) return

    call compose_modflow6_swap_predictor_response(window, origin%lineage, qbot_cm_per_day, &
         origin%h_bot_start_m, endpoint%bottom_face%hydraulic_head_m, &
         endpoint%bottom_face%dpressure_head_cm_per_qbot_cm_per_day, &
         MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT, endpoint%coverage, endpoint%derivative_method, &
         endpoint%derivative_route, response, compose_status)
    if (compose_status /= MODFLOW6_PREDICTOR_OK .or. .not. response%valid) then
      status = MODFLOW6_PREDICTOR_ASSEMBLER_RESPONSE_FAILED
      return
    end if

    status = MODFLOW6_PREDICTOR_ASSEMBLER_OK
  end subroutine assemble_modflow6_swap_predictor_response

  pure logical function same_time_value(a, b) result(matches)
    real(real64), intent(in) :: a, b
    real(real64) :: scale

    if (.not. ieee_is_finite(a) .or. .not. ieee_is_finite(b)) then
      matches = .false.
      return
    end if
    scale = max(1.0_real64, abs(a), abs(b))
    matches = abs(a-b) <= 64.0_real64*epsilon(1.0_real64)*scale
  end function same_time_value

end module mod_modflow6_swap_predictor_candidate_assembler
