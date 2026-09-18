module mod_accepted_trajectory_directional_publication
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_accepted_trajectory_directional_sensitivity, only: &
       accepted_trajectory_direction_t, TRAJECTORY_DIRECTION_AVAILABLE
  implicit none
  private

  ! Immutable/publication-side result.  The mutable trajectory composer remains
  ! worker/job-local scratch; callers must never publish that scratch object
  ! directly as an accepted coupling result.
  type, public :: accepted_trajectory_direction_result_t
    logical :: requested = .false.
    logical :: available = .false.
    integer :: worker_id = -1
    integer(int64) :: generation = 0_int64
    integer :: control_coordinate = 0
    integer :: accepted_steps = 0
    real(real64) :: origin_t0 = 0.0_real64
    real(real64) :: accepted_t1 = 0.0_real64
    real(real64), allocatable :: final_pressure_head_direction(:)
    real(real64), allocatable :: final_water_content_direction(:)
    real(real64) :: final_ponding_direction = 0.0_real64
    real(real64) :: accepted_bottom_exchange_derivative = 0.0_real64
    logical :: source_sink_direction_coverage_complete = .false.
    character(len=48) :: method = 'not-available'
    character(len=64) :: route = 'not-available'
    integer :: additional_tridiagonal_backsolves = 0
    integer :: additional_jacobian_builds = 0
    integer :: additional_full_nonlinear_solves = 0
  end type accepted_trajectory_direction_result_t

  public :: publish_accepted_trajectory_direction

contains

  subroutine publish_accepted_trajectory_direction(state, result)
    type(accepted_trajectory_direction_t), intent(in) :: state
    type(accepted_trajectory_direction_result_t), intent(out) :: result

    result = accepted_trajectory_direction_result_t()
    result%requested = state%requested
    result%worker_id = state%worker_id
    result%generation = state%generation
    result%control_coordinate = state%control_coordinate
    result%accepted_steps = state%accepted_steps
    result%origin_t0 = state%origin_t0
    result%accepted_t1 = state%current_t1
    result%source_sink_direction_coverage_complete = state%source_sink_direction_coverage_complete
    result%method = state%method
    result%route = state%route
    result%additional_tridiagonal_backsolves = state%additional_tridiagonal_backsolves
    result%additional_jacobian_builds = state%additional_jacobian_builds
    result%additional_full_nonlinear_solves = state%additional_full_nonlinear_solves

    if (state%status /= TRAJECTORY_DIRECTION_AVAILABLE) return
    if (.not. state%requested .or. state%accepted_steps <= 0) then
      result%route = 'publication-invalid-availability'
      return
    end if
    if (.not. allocated(state%pressure_head_direction) .or. &
        .not. allocated(state%water_content_direction)) then
      result%route = 'publication-missing-direction-vectors'
      return
    end if
    if (size(state%pressure_head_direction) /= size(state%water_content_direction) .or. &
        size(state%pressure_head_direction) <= 0) then
      result%route = 'publication-direction-shape-invalid'
      return
    end if
    if (any(.not. ieee_is_finite(state%pressure_head_direction)) .or. &
        any(.not. ieee_is_finite(state%water_content_direction)) .or. &
        .not. ieee_is_finite(state%ponding_direction) .or. &
        .not. ieee_is_finite(state%integrated_bottom_exchange_derivative) .or. &
        .not. ieee_is_finite(state%origin_t0) .or. .not. ieee_is_finite(state%current_t1)) then
      result%route = 'publication-nonfinite'
      return
    end if
    if (state%current_t1 <= state%origin_t0) then
      result%route = 'publication-invalid-interval'
      return
    end if

    allocate(result%final_pressure_head_direction(size(state%pressure_head_direction)))
    allocate(result%final_water_content_direction(size(state%water_content_direction)))
    result%final_pressure_head_direction = state%pressure_head_direction
    result%final_water_content_direction = state%water_content_direction
    result%final_ponding_direction = state%ponding_direction
    result%accepted_bottom_exchange_derivative = state%integrated_bottom_exchange_derivative
    result%available = .true.
  end subroutine publish_accepted_trajectory_direction

end module mod_accepted_trajectory_directional_publication
