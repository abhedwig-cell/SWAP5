module mod_accepted_trajectory_directional_sensitivity
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_accepted_step_direction_contract, only: &
       soil_water_accepted_step_direction_request_t, soil_water_accepted_step_direction_result_t, &
       SW_STEP_DIRECTION_AVAILABLE
  implicit none
  private

  integer, parameter, public :: TRAJECTORY_DIRECTION_NOT_REQUESTED = 0
  integer, parameter, public :: TRAJECTORY_DIRECTION_ACTIVE = 1
  integer, parameter, public :: TRAJECTORY_DIRECTION_AVAILABLE = 2
  integer, parameter, public :: TRAJECTORY_DIRECTION_UNAVAILABLE = 3
  integer, parameter, public :: TRAJECTORY_DIRECTION_FAILED = 4

  type, public :: trajectory_step_token_t
    integer :: worker_id = -1
    integer(int64) :: generation = 0_int64
    integer :: step_sequence = 0
    real(real64) :: step_t0 = 0.0_real64
    real(real64) :: step_t1 = 0.0_real64
  end type trajectory_step_token_t

  type, public :: accepted_trajectory_direction_t
    logical :: requested = .false.
    integer :: status = TRAJECTORY_DIRECTION_NOT_REQUESTED
    integer :: worker_id = -1
    integer(int64) :: generation = 0_int64
    integer :: control_coordinate = 0
    integer :: accepted_steps = 0
    integer :: next_step_sequence = 1
    real(real64) :: origin_t0 = 0.0_real64
    real(real64) :: current_t1 = 0.0_real64
    real(real64) :: requested_t1 = 0.0_real64
    real(real64), allocatable :: pressure_head_direction(:)
    real(real64), allocatable :: water_content_direction(:)
    real(real64) :: ponding_direction = 0.0_real64
    real(real64) :: integrated_bottom_exchange_derivative = 0.0_real64
    character(len=48) :: method = 'not-requested'
    character(len=64) :: route = 'not-requested'
    integer :: additional_tridiagonal_backsolves = 0
    integer :: additional_jacobian_builds = 0
    integer :: additional_full_nonlinear_solves = 0
    logical :: pending = .false.
    logical :: pending_available = .false.
    integer :: pending_sequence = 0
    real(real64) :: pending_t0 = 0.0_real64
    real(real64) :: pending_t1 = 0.0_real64
    real(real64), allocatable :: pending_pressure_head_direction(:)
    real(real64), allocatable :: pending_water_content_direction(:)
    real(real64) :: pending_ponding_direction = 0.0_real64
    real(real64) :: pending_bottom_exchange_derivative = 0.0_real64
    character(len=48) :: pending_method = 'not-run'
    character(len=64) :: pending_route = 'not-run'
    integer :: pending_backsolves = 0
    integer :: pending_jacobians = 0
    integer :: pending_full_solves = 0
  end type accepted_trajectory_direction_t

  public :: configure_trajectory_direction
  public :: begin_or_continue_trajectory
  public :: build_trajectory_step_request
  public :: stage_trajectory_step_result
  public :: accept_trajectory_step
  public :: discard_trajectory_step
  public :: finalize_trajectory_direction

contains

  subroutine configure_trajectory_direction(state, requested)
    type(accepted_trajectory_direction_t), intent(inout) :: state
    logical, intent(in) :: requested
    integer(int64) :: generation
    generation = state%generation
    state = accepted_trajectory_direction_t()
    state%generation = generation
    state%requested = requested
    if (requested) then
      state%status = TRAJECTORY_DIRECTION_ACTIVE
      state%method = 'pending-first-step'
      state%route = 'configured'
    end if
  end subroutine configure_trajectory_direction

  subroutine begin_or_continue_trajectory(state, worker_id, t0, t1, control_coordinate, active_nodes, ok)
    type(accepted_trajectory_direction_t), intent(inout) :: state
    integer, intent(in) :: worker_id, control_coordinate, active_nodes
    real(real64), intent(in) :: t0, t1
    logical, intent(out) :: ok
    real(real64), parameter :: time_guard = 64.0_real64*epsilon(1.0_real64)

    ok = .false.
    if (.not. state%requested) return
    if (active_nodes <= 0 .or. t1 <= t0) then
      call fail_closed(state, 'invalid-trajectory-interval')
      return
    end if

    if (.not. allocated(state%pressure_head_direction)) then
      state%generation = state%generation + 1_int64
      state%worker_id = worker_id
      state%control_coordinate = control_coordinate
      state%origin_t0 = t0
      state%current_t1 = t0
      state%requested_t1 = t1
      state%accepted_steps = 0
      state%next_step_sequence = 1
      state%integrated_bottom_exchange_derivative = 0.0_real64
      allocate(state%pressure_head_direction(active_nodes), state%water_content_direction(active_nodes))
      state%pressure_head_direction = 0.0_real64
      state%water_content_direction = 0.0_real64
      state%ponding_direction = 0.0_real64
      state%status = TRAJECTORY_DIRECTION_ACTIVE
      state%method = 'accepted-step-composition'
      state%route = 'active'
      ok = .true.
      return
    end if

    if (state%worker_id /= worker_id .or. state%control_coordinate /= control_coordinate .or. &
        size(state%pressure_head_direction) /= active_nodes) then
      call fail_closed(state, 'cross-candidate-trajectory-mismatch')
      return
    end if
    if (abs(state%current_t1-t0) > time_guard*max(1.0_real64,abs(t0),abs(state%current_t1))) then
      call fail_closed(state, 'trajectory-time-origin-mismatch')
      return
    end if
    if (state%pending) then
      call fail_closed(state, 'pending-step-not-resolved')
      return
    end if
    state%requested_t1 = t1
    ok = .true.
  end subroutine begin_or_continue_trajectory

  subroutine build_trajectory_step_request(state, step_t0, step_t1, request, token, ok)
    type(accepted_trajectory_direction_t), intent(inout) :: state
    real(real64), intent(in) :: step_t0, step_t1
    type(soil_water_accepted_step_direction_request_t), intent(out) :: request
    type(trajectory_step_token_t), intent(out) :: token
    logical, intent(out) :: ok

    request = soil_water_accepted_step_direction_request_t()
    token = trajectory_step_token_t()
    ok = .false.
    if (.not. state%requested .or. .not. allocated(state%pressure_head_direction)) return
    if (state%pending .or. step_t1 <= step_t0) then
      call fail_closed(state, 'invalid-step-stage-state')
      return
    end if
    if (step_t0 /= state%current_t1) then
      call fail_closed(state, 'stale-step-origin')
      return
    end if

    token%worker_id = state%worker_id
    token%generation = state%generation
    token%step_sequence = state%next_step_sequence
    token%step_t0 = step_t0
    token%step_t1 = step_t1

    request%requested = (state%status /= TRAJECTORY_DIRECTION_UNAVAILABLE .and. &
                         state%status /= TRAJECTORY_DIRECTION_FAILED)
    request%control_coordinate = state%control_coordinate
    request%direct_control_derivative = 1.0_real64
    allocate(request%incoming_pressure_head(size(state%pressure_head_direction)))
    allocate(request%incoming_water_content(size(state%water_content_direction)))
    request%incoming_pressure_head = state%pressure_head_direction
    request%incoming_water_content = state%water_content_direction
    request%incoming_ponding_depth = state%ponding_direction
    ok = .true.
  end subroutine build_trajectory_step_request

  subroutine stage_trajectory_step_result(state, token, result, ok)
    type(accepted_trajectory_direction_t), intent(inout) :: state
    type(trajectory_step_token_t), intent(in) :: token
    type(soil_water_accepted_step_direction_result_t), intent(in) :: result
    logical, intent(out) :: ok
    real(real64) :: dt

    ok = .false.
    if (.not. token_matches(state, token) .or. state%pending) then
      call fail_closed(state, 'stale-or-cross-candidate-step-result')
      return
    end if
    dt = token%step_t1-token%step_t0
    if (dt <= 0.0_real64) then
      call fail_closed(state, 'invalid-step-duration')
      return
    end if

    state%pending = .true.
    state%pending_sequence = token%step_sequence
    state%pending_t0 = token%step_t0
    state%pending_t1 = token%step_t1
    state%pending_backsolves = result%additional_tridiagonal_backsolves
    state%pending_jacobians = result%additional_jacobian_builds
    state%pending_full_solves = result%additional_full_nonlinear_solves
    state%pending_method = result%method
    state%pending_route = result%route
    state%pending_available = result%status == SW_STEP_DIRECTION_AVAILABLE .and. result%available

    if (state%pending_available) then
      if (.not. allocated(result%outgoing_pressure_head) .or. .not. allocated(result%outgoing_water_content)) then
        call fail_closed(state, 'available-step-result-missing-vectors')
        return
      end if
      if (size(result%outgoing_pressure_head) /= size(state%pressure_head_direction) .or. &
          size(result%outgoing_water_content) /= size(state%water_content_direction)) then
        call fail_closed(state, 'available-step-result-shape-mismatch')
        return
      end if
      if (any(.not. ieee_is_finite(result%outgoing_pressure_head)) .or. &
          any(.not. ieee_is_finite(result%outgoing_water_content)) .or. &
          .not. ieee_is_finite(result%outgoing_ponding_depth) .or. &
          .not. ieee_is_finite(result%bottom_flux_derivative)) then
        call fail_closed(state, 'available-step-result-nonfinite')
        return
      end if
      state%pending_pressure_head_direction = result%outgoing_pressure_head
      state%pending_water_content_direction = result%outgoing_water_content
      state%pending_ponding_direction = result%outgoing_ponding_depth
      state%pending_bottom_exchange_derivative = dt*result%bottom_flux_derivative
    end if
    ok = .true.
  end subroutine stage_trajectory_step_result

  subroutine accept_trajectory_step(state, ok)
    type(accepted_trajectory_direction_t), intent(inout) :: state
    logical, intent(out) :: ok

    ok = .false.
    if (.not. state%pending) then
      call fail_closed(state, 'accept-without-pending-step')
      return
    end if
    state%accepted_steps = state%accepted_steps + 1
    state%current_t1 = state%pending_t1
    state%next_step_sequence = state%next_step_sequence + 1
    state%additional_tridiagonal_backsolves = state%additional_tridiagonal_backsolves + state%pending_backsolves
    state%additional_jacobian_builds = state%additional_jacobian_builds + state%pending_jacobians
    state%additional_full_nonlinear_solves = state%additional_full_nonlinear_solves + state%pending_full_solves

    if (state%pending_available .and. state%status /= TRAJECTORY_DIRECTION_UNAVAILABLE .and. &
        state%status /= TRAJECTORY_DIRECTION_FAILED) then
      state%pressure_head_direction = state%pending_pressure_head_direction
      state%water_content_direction = state%pending_water_content_direction
      state%ponding_direction = state%pending_ponding_direction
      state%integrated_bottom_exchange_derivative = state%integrated_bottom_exchange_derivative + &
           state%pending_bottom_exchange_derivative
      state%method = state%pending_method
      state%route = state%pending_route
      state%status = TRAJECTORY_DIRECTION_ACTIVE
    else
      state%status = TRAJECTORY_DIRECTION_UNAVAILABLE
      state%method = 'unavailable'
      state%route = state%pending_route
    end if
    call clear_pending(state)
    ok = .true.
  end subroutine accept_trajectory_step

  subroutine discard_trajectory_step(state)
    type(accepted_trajectory_direction_t), intent(inout) :: state
    call clear_pending(state)
  end subroutine discard_trajectory_step

  subroutine finalize_trajectory_direction(state, requested_t0, requested_t1, ok)
    type(accepted_trajectory_direction_t), intent(inout) :: state
    real(real64), intent(in) :: requested_t0, requested_t1
    logical, intent(out) :: ok
    real(real64), parameter :: time_guard = 64.0_real64*epsilon(1.0_real64)

    ok = .false.
    if (.not. state%requested .or. state%pending .or. state%accepted_steps <= 0) return
    if (abs(state%origin_t0-requested_t0) > time_guard*max(1.0_real64,abs(requested_t0)) .or. &
        abs(state%current_t1-requested_t1) > time_guard*max(1.0_real64,abs(requested_t1))) then
      call fail_closed(state, 'trajectory-finalization-origin-mismatch')
      return
    end if
    if (state%status == TRAJECTORY_DIRECTION_ACTIVE) then
      state%status = TRAJECTORY_DIRECTION_AVAILABLE
      state%route = 'accepted-trajectory'
    end if
    ok = state%status == TRAJECTORY_DIRECTION_AVAILABLE
  end subroutine finalize_trajectory_direction

  logical function token_matches(state, token) result(matches)
    type(accepted_trajectory_direction_t), intent(in) :: state
    type(trajectory_step_token_t), intent(in) :: token
    matches = token%worker_id == state%worker_id .and. token%generation == state%generation .and. &
              token%step_sequence == state%next_step_sequence .and. token%step_t0 == state%current_t1
  end function token_matches

  subroutine clear_pending(state)
    type(accepted_trajectory_direction_t), intent(inout) :: state
    state%pending = .false.
    state%pending_available = .false.
    state%pending_sequence = 0
    state%pending_t0 = 0.0_real64
    state%pending_t1 = 0.0_real64
    if (allocated(state%pending_pressure_head_direction)) deallocate(state%pending_pressure_head_direction)
    if (allocated(state%pending_water_content_direction)) deallocate(state%pending_water_content_direction)
    state%pending_ponding_direction = 0.0_real64
    state%pending_bottom_exchange_derivative = 0.0_real64
    state%pending_method = 'not-run'
    state%pending_route = 'not-run'
    state%pending_backsolves = 0
    state%pending_jacobians = 0
    state%pending_full_solves = 0
  end subroutine clear_pending

  subroutine fail_closed(state, route)
    type(accepted_trajectory_direction_t), intent(inout) :: state
    character(len=*), intent(in) :: route
    state%status = TRAJECTORY_DIRECTION_FAILED
    state%method = 'failed-closed'
    state%route = route
    call clear_pending(state)
  end subroutine fail_closed

end module mod_accepted_trajectory_directional_sensitivity
