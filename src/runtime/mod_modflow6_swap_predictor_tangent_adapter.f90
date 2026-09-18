module mod_modflow6_swap_predictor_tangent_adapter
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t
  use mod_soil_water_solver_contract, only: soil_water_physical_state_t, soil_water_parameter_set_t
  use mod_soil_water_accepted_step_direction_contract, only: SW_STEP_CONTROL_BOTTOM_FLUX
  use mod_accepted_trajectory_directional_publication, only: accepted_trajectory_direction_result_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t
  use mod_b110_default_mvg_directional_provider, only: evaluate_b110_default_mvg_state_direction
  use mod_modflow6_swap_predictor_response, only: modflow6_derivative_coverage_t
  use mod_modflow6_swap_prescribed_qbot_bottom_face, only: modflow6_prescribed_qbot_bottom_face_t, &
       materialize_modflow6_prescribed_qbot_bottom_face, MODFLOW6_BOTTOM_FACE_OK
  implicit none
  private

  integer, parameter, public :: MODFLOW6_TANGENT_ENDPOINT_OK = 0
  integer, parameter, public :: MODFLOW6_TANGENT_ENDPOINT_INVALID_STATE = 1
  integer, parameter, public :: MODFLOW6_TANGENT_ENDPOINT_UNAVAILABLE = 2
  integer, parameter, public :: MODFLOW6_TANGENT_ENDPOINT_CONTROL_MISMATCH = 3
  integer, parameter, public :: MODFLOW6_TANGENT_ENDPOINT_SHAPE_MISMATCH = 4
  integer, parameter, public :: MODFLOW6_TANGENT_ENDPOINT_CONSTITUTIVE_UNAVAILABLE = 5
  integer, parameter, public :: MODFLOW6_TANGENT_ENDPOINT_BOTTOM_FACE_FAILED = 6
  integer, parameter, public :: MODFLOW6_TANGENT_ENDPOINT_INCOMPLETE_COVERAGE = 7

  type, public :: modflow6_swap_predictor_tangent_endpoint_t
    integer :: status = MODFLOW6_TANGENT_ENDPOINT_UNAVAILABLE
    logical :: available = .false.
    logical :: authoritative = .false.
    integer :: worker_id = -1
    integer(int64) :: trajectory_generation = 0_int64
    integer :: accepted_steps = 0
    type(modflow6_prescribed_qbot_bottom_face_t) :: bottom_face
    type(modflow6_derivative_coverage_t) :: coverage
    character(len=48) :: derivative_method = 'not-available'
    character(len=64) :: derivative_route = 'not-available'
  end type modflow6_swap_predictor_tangent_endpoint_t

  public :: build_modflow6_swap_predictor_tangent_endpoint

contains

  subroutine build_modflow6_swap_predictor_tangent_endpoint(candidate_state, parameters, constitutive, &
       trajectory, qbot_cm_per_day, datum, dynamic_top_boundary_active, root_uptake_active, drainage_active, &
       other_state_dependent_source_sink_active, endpoint, status)
    type(soil_water_physical_state_t), intent(in) :: candidate_state
    type(soil_water_parameter_set_t), intent(in) :: parameters
    type(b110_default_mvg_provider_t), intent(in) :: constitutive
    type(accepted_trajectory_direction_result_t), intent(in) :: trajectory
    real(real64), intent(in) :: qbot_cm_per_day
    type(groundwater_head_datum_t), intent(in) :: datum
    logical, intent(in) :: dynamic_top_boundary_active
    logical, intent(in) :: root_uptake_active
    logical, intent(in) :: drainage_active
    logical, intent(in) :: other_state_dependent_source_sink_active
    type(modflow6_swap_predictor_tangent_endpoint_t), intent(out) :: endpoint
    integer, intent(out) :: status

    integer :: n, face_status
    logical :: constitutive_direction_available
    character(len=64) :: constitutive_direction_route
    real(real64), allocatable :: theta(:), conductivity(:), capacity(:), reserved_dkdh(:)
    real(real64), allocatable :: theta_direction(:), conductivity_direction(:)

    endpoint = modflow6_swap_predictor_tangent_endpoint_t()

    status = MODFLOW6_TANGENT_ENDPOINT_INVALID_STATE
    n = candidate_state%active_nodes
    if (n <= 0 .or. parameters%active_nodes /= n) then
      endpoint%status = status
      return
    end if
    if (.not. allocated(candidate_state%pressure_head) .or. .not. allocated(candidate_state%water_content) .or. &
        .not. allocated(parameters%dz)) then
      endpoint%status = status
      return
    end if
    if (size(candidate_state%pressure_head) /= n .or. size(candidate_state%water_content) /= n .or. &
        size(parameters%dz) /= n .or. any(parameters%dz <= 0.0_real64) .or. &
        any(.not. ieee_is_finite(candidate_state%pressure_head)) .or. &
        any(.not. ieee_is_finite(candidate_state%water_content)) .or. .not. ieee_is_finite(qbot_cm_per_day)) then
      endpoint%status = status
      return
    end if

    status = MODFLOW6_TANGENT_ENDPOINT_UNAVAILABLE
    if (.not. trajectory%requested .or. .not. trajectory%available .or. trajectory%accepted_steps <= 0) then
      endpoint%status = status
      return
    end if
    if (trajectory%additional_full_nonlinear_solves /= 0) then
      endpoint%status = status
      return
    end if

    status = MODFLOW6_TANGENT_ENDPOINT_CONTROL_MISMATCH
    if (trajectory%control_coordinate /= SW_STEP_CONTROL_BOTTOM_FLUX) then
      endpoint%status = status
      return
    end if

    status = MODFLOW6_TANGENT_ENDPOINT_SHAPE_MISMATCH
    if (.not. allocated(trajectory%final_pressure_head_direction) .or. &
        .not. allocated(trajectory%final_water_content_direction)) then
      endpoint%status = status
      return
    end if
    if (size(trajectory%final_pressure_head_direction) /= n .or. &
        size(trajectory%final_water_content_direction) /= n .or. &
        any(.not. ieee_is_finite(trajectory%final_pressure_head_direction)) .or. &
        any(.not. ieee_is_finite(trajectory%final_water_content_direction))) then
      endpoint%status = status
      return
    end if

    allocate(theta(n), conductivity(n), capacity(n), reserved_dkdh(n), &
         theta_direction(n), conductivity_direction(n))
    call constitutive%evaluate(candidate_state%pressure_head, theta, conductivity, capacity, reserved_dkdh)
    if (any(.not. ieee_is_finite(conductivity)) .or. conductivity(n) <= 0.0_real64) then
      status = MODFLOW6_TANGENT_ENDPOINT_CONSTITUTIVE_UNAVAILABLE
      endpoint%status = status
      return
    end if

    call evaluate_b110_default_mvg_state_direction(constitutive, candidate_state%pressure_head, &
         trajectory%final_pressure_head_direction, theta_direction, conductivity_direction, &
         constitutive_direction_available, constitutive_direction_route)
    if (.not. constitutive_direction_available .or. any(.not. ieee_is_finite(conductivity_direction))) then
      status = MODFLOW6_TANGENT_ENDPOINT_CONSTITUTIVE_UNAVAILABLE
      endpoint%status = status
      endpoint%derivative_route = constitutive_direction_route
      return
    end if

    call materialize_modflow6_prescribed_qbot_bottom_face(candidate_state%pressure_head(n), conductivity(n), &
         qbot_cm_per_day, 0.5_real64*parameters%dz(n), datum, endpoint%bottom_face, face_status, &
         pressure_head_direction=trajectory%final_pressure_head_direction(n), &
         conductivity_direction=conductivity_direction(n))
    if (face_status /= MODFLOW6_BOTTOM_FACE_OK .or. .not. endpoint%bottom_face%valid .or. &
        .not. endpoint%bottom_face%derivative_available) then
      status = MODFLOW6_TANGENT_ENDPOINT_BOTTOM_FACE_FAILED
      endpoint%status = status
      return
    end if

    endpoint%worker_id = trajectory%worker_id
    endpoint%trajectory_generation = trajectory%generation
    endpoint%accepted_steps = trajectory%accepted_steps
    endpoint%derivative_method = trajectory%method
    endpoint%derivative_route = 'accepted-qbot-trajectory-to-fixed-bottom-face'

    endpoint%coverage%lower_face_head_semantics_covered = .true.
    endpoint%coverage%richards_hydraulic_response_covered = .true.
    endpoint%coverage%constitutive_response_covered = .true.
    endpoint%coverage%dynamic_top_boundary_active = dynamic_top_boundary_active
    endpoint%coverage%dynamic_top_boundary_covered = dynamic_top_boundary_active
    endpoint%coverage%root_uptake_active = root_uptake_active
    endpoint%coverage%root_uptake_covered = .false.
    endpoint%coverage%drainage_active = drainage_active
    endpoint%coverage%drainage_covered = drainage_active .and. &
         trajectory%source_sink_direction_coverage_complete
    endpoint%coverage%other_state_dependent_source_sink_active = other_state_dependent_source_sink_active
    endpoint%coverage%other_state_dependent_source_sink_covered = .false.

    endpoint%available = .true.
    if (.not. endpoint%coverage%tangent_complete()) then
      status = MODFLOW6_TANGENT_ENDPOINT_INCOMPLETE_COVERAGE
      endpoint%status = status
      endpoint%authoritative = .false.
      return
    end if

    endpoint%authoritative = .true.
    endpoint%status = MODFLOW6_TANGENT_ENDPOINT_OK
    status = MODFLOW6_TANGENT_ENDPOINT_OK
  end subroutine build_modflow6_swap_predictor_tangent_endpoint

end module mod_modflow6_swap_predictor_tangent_adapter
