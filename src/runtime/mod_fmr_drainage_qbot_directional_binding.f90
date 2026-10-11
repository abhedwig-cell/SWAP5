module mod_fmr_drainage_qbot_directional_binding
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t
  use mod_b110_smooth_freatic_projection, only: b110_smooth_freatic_projection_diagnostics_t, &
       evaluate_b110_smooth_freatic_projection, B110_GWL_PROJECTION_OK
  use mod_fmr_drainage_response_binding, only: fmr_drainage_response_diagnostics_t, FMR_DRAIN_BIND_OK
  implicit none
  private

  integer, parameter, public :: FMR_QBOT_DRAIN_DIRECTION_OK = 0
  integer, parameter, public :: FMR_QBOT_DRAIN_DIRECTION_INVALID_STATE = 1
  integer, parameter, public :: FMR_QBOT_DRAIN_DIRECTION_GWL_UNAVAILABLE = 2
  integer, parameter, public :: FMR_QBOT_DRAIN_DIRECTION_RESPONSE_UNAVAILABLE = 3
  integer, parameter, public :: FMR_QBOT_DRAIN_DIRECTION_TANGENT_UNAVAILABLE = 4
  integer, parameter, public :: FMR_QBOT_DRAIN_DIRECTION_NONFINITE = 5

  public :: project_fmr_qbot_smooth_groundwater_level
  public :: compose_fmr_qbot_drainage_sink_direction

contains

  subroutine project_fmr_qbot_smooth_groundwater_level(parameters, state, groundwater_level, status, diagnostics)
    type(soil_water_parameter_set_t), intent(in) :: parameters
    type(soil_water_physical_state_t), intent(in) :: state
    real(real64), intent(out) :: groundwater_level
    integer, intent(out) :: status
    type(b110_smooth_freatic_projection_diagnostics_t), intent(out) :: diagnostics

    real(real64), allocatable :: zero_direction(:)
    real(real64) :: ignored_direction
    integer :: n

    groundwater_level = 0.0_real64
    ignored_direction = 0.0_real64
    diagnostics = b110_smooth_freatic_projection_diagnostics_t()
    status = FMR_QBOT_DRAIN_DIRECTION_INVALID_STATE

    n = state%active_nodes
    if (n < 2 .or. parameters%active_nodes /= n) return
    if (.not. allocated(state%pressure_head) .or. .not. allocated(parameters%z) .or. &
        .not. allocated(parameters%node_distance)) return
    if (size(state%pressure_head) /= n .or. size(parameters%z) /= n .or. &
        size(parameters%node_distance) /= n) return

    allocate(zero_direction(n))
    zero_direction = 0.0_real64
    call evaluate_b110_smooth_freatic_projection(2, .false., parameters%z, parameters%node_distance, &
         state%pressure_head, zero_direction, groundwater_level, ignored_direction, diagnostics)
    if (diagnostics%status /= B110_GWL_PROJECTION_OK .or. .not. diagnostics%value_defined) then
      status = FMR_QBOT_DRAIN_DIRECTION_GWL_UNAVAILABLE
      groundwater_level = 0.0_real64
      return
    end if
    if (.not. ieee_is_finite(groundwater_level)) then
      status = FMR_QBOT_DRAIN_DIRECTION_NONFINITE
      groundwater_level = 0.0_real64
      return
    end if
    status = FMR_QBOT_DRAIN_DIRECTION_OK
  end subroutine project_fmr_qbot_smooth_groundwater_level

  subroutine compose_fmr_qbot_drainage_sink_direction(parameters, state, pressure_head_direction, &
       drainage_diagnostics, sink_direction, groundwater_level_direction, status, route)
    type(soil_water_parameter_set_t), intent(in) :: parameters
    type(soil_water_physical_state_t), intent(in) :: state
    real(real64), intent(in) :: pressure_head_direction(:)
    type(fmr_drainage_response_diagnostics_t), intent(in) :: drainage_diagnostics
    real(real64), allocatable, intent(out) :: sink_direction(:)
    real(real64), intent(out) :: groundwater_level_direction
    integer, intent(out) :: status
    character(len=*), intent(out) :: route

    type(b110_smooth_freatic_projection_diagnostics_t) :: projection_diagnostics
    real(real64) :: projected_groundwater_level, aggregate_sink_direction
    integer :: i, n

    groundwater_level_direction = 0.0_real64
    status = FMR_QBOT_DRAIN_DIRECTION_INVALID_STATE
    route = 'invalid-state'
    n = state%active_nodes

    if (n < 2 .or. parameters%active_nodes /= n) return
    if (.not. allocated(state%pressure_head) .or. .not. allocated(parameters%z) .or. &
        .not. allocated(parameters%node_distance)) return
    if (size(state%pressure_head) /= n .or. size(pressure_head_direction) /= n .or. &
        size(parameters%z) /= n .or. size(parameters%node_distance) /= n) return
    if (any(.not. ieee_is_finite(pressure_head_direction))) then
      status = FMR_QBOT_DRAIN_DIRECTION_NONFINITE
      route = 'pressure-head-direction-nonfinite'
      return
    end if

    call evaluate_b110_smooth_freatic_projection(2, .false., parameters%z, parameters%node_distance, &
         state%pressure_head, pressure_head_direction, projected_groundwater_level, groundwater_level_direction, &
         projection_diagnostics)
    if (projection_diagnostics%status /= B110_GWL_PROJECTION_OK .or. &
        .not. projection_diagnostics%value_defined .or. .not. projection_diagnostics%direction_defined) then
      status = FMR_QBOT_DRAIN_DIRECTION_GWL_UNAVAILABLE
      route = 'smooth-gwl-direction-unavailable'
      groundwater_level_direction = 0.0_real64
      return
    end if
    if (.not. ieee_is_finite(projected_groundwater_level) .or. .not. ieee_is_finite(groundwater_level_direction)) then
      status = FMR_QBOT_DRAIN_DIRECTION_NONFINITE
      route = 'smooth-gwl-direction-nonfinite'
      groundwater_level_direction = 0.0_real64
      return
    end if

    if (drainage_diagnostics%status /= FMR_DRAIN_BIND_OK .or. .not. drainage_diagnostics%evaluated .or. &
        .not. drainage_diagnostics%bottom_node_lumping .or. .not. allocated(drainage_diagnostics%level)) then
      status = FMR_QBOT_DRAIN_DIRECTION_RESPONSE_UNAVAILABLE
      route = 'drainage-response-unavailable'
      return
    end if
    if (size(drainage_diagnostics%level) <= 0) then
      status = FMR_QBOT_DRAIN_DIRECTION_RESPONSE_UNAVAILABLE
      route = 'drainage-response-empty'
      return
    end if

    aggregate_sink_direction = 0.0_real64
    do i = 1, size(drainage_diagnostics%level)
      if (.not. drainage_diagnostics%level(i)%derivative_defined .or. &
          drainage_diagnostics%level(i)%branch_or_nonsmooth_point) then
        status = FMR_QBOT_DRAIN_DIRECTION_TANGENT_UNAVAILABLE
        route = 'drainage-level-tangent-unavailable'
        groundwater_level_direction = 0.0_real64
        return
      end if
      if (.not. ieee_is_finite(drainage_diagnostics%level(i)%dq_dgroundwater_level)) then
        status = FMR_QBOT_DRAIN_DIRECTION_NONFINITE
        route = 'drainage-level-tangent-nonfinite'
        groundwater_level_direction = 0.0_real64
        return
      end if
      aggregate_sink_direction = aggregate_sink_direction + &
           drainage_diagnostics%level(i)%dq_dgroundwater_level * groundwater_level_direction
    end do

    if (.not. ieee_is_finite(aggregate_sink_direction)) then
      status = FMR_QBOT_DRAIN_DIRECTION_NONFINITE
      route = 'aggregate-drainage-direction-nonfinite'
      groundwater_level_direction = 0.0_real64
      return
    end if

    allocate(sink_direction(n))
    sink_direction = 0.0_real64
    sink_direction(n) = aggregate_sink_direction
    status = FMR_QBOT_DRAIN_DIRECTION_OK
    route = 'lagged-start-gwl-to-bottom-lumped-drainage-direction'
  end subroutine compose_fmr_qbot_drainage_sink_direction

end module mod_fmr_drainage_qbot_directional_binding
