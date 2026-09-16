module mod_irrigation_process
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  implicit none
  private

  integer, parameter, public :: IRRIGATION_OK = 0
  integer, parameter, public :: IRRIGATION_INVALID_INTERVAL = 1
  integer, parameter, public :: IRRIGATION_INVALID_STATE = 2
  integer, parameter, public :: IRRIGATION_INVALID_EVENT = 3
  integer, parameter, public :: IRRIGATION_SPLIT_REQUIRED = 4
  integer, parameter, public :: IRRIGATION_INVALID_PARAMETERS = 5
  integer, parameter, public :: IRRIGATION_INVALID_HYDRAULIC_VIEW = 6

  real(real64), parameter, public :: IRRIGATION_FIXED_EVENT_MATCH_TOLERANCE = 1.0e-3_real64
  real(real64), parameter, public :: IRRIGATION_MAX_EVENT_DURATION = 1.0_real64
  real(real64), parameter :: IRRIGATION_TIME_EPSILON_SCALE = 64.0_real64
  integer, parameter, public :: IRRIGATION_MAX_SCHEDULED_KNOTS = 7

  integer, parameter, public :: IRRIGATION_APPLICATION_SPRINKLER = 0
  integer, parameter, public :: IRRIGATION_APPLICATION_SURFACE = 1
  integer, parameter, public :: IRRIGATION_APPLICATION_SSDI = 2

  integer, parameter, public :: IRRIGATION_EVENT_NONE = 0
  integer, parameter, public :: IRRIGATION_EVENT_FIXED = 1
  integer, parameter, public :: IRRIGATION_EVENT_SCHEDULED = 2

  type, public :: fixed_irrigation_event_t
    real(real64) :: event_time = 0.0_real64
    integer :: application_type = IRRIGATION_APPLICATION_SPRINKLER
    real(real64) :: depth = 0.0_real64
    real(real64) :: rate = 0.0_real64
    real(real64) :: concentration = 0.0_real64
  end type fixed_irrigation_event_t

  type, public :: irrigation_parameters_t
    logical :: fixed_irrigation_enabled = .false.
    integer :: active_nodes = 0
    integer :: ssdi_first_node = 0
    integer :: ssdi_last_node = 0
    type(fixed_irrigation_event_t), allocatable :: fixed_events(:)
  end type irrigation_parameters_t

  type, public :: scheduled_irrigation_parameters_t
    logical :: scheduled_irrigation_enabled = .false.
    integer :: active_nodes = 0
    integer :: sensor_node = 0
    integer :: single_ssdi_node = 0
    real(real64) :: irr_rate_cm_per_day = 0.0_real64
    integer :: tcs7_knot_count = 0
    real(real64) :: tcs7_dvs(IRRIGATION_MAX_SCHEDULED_KNOTS) = 0.0_real64
    real(real64) :: tcs7_pressure_head(IRRIGATION_MAX_SCHEDULED_KNOTS) = 0.0_real64
    integer :: dcs2_knot_count = 0
    real(real64) :: dcs2_dvs(IRRIGATION_MAX_SCHEDULED_KNOTS) = 0.0_real64
    real(real64) :: dcs2_depth_cm(IRRIGATION_MAX_SCHEDULED_KNOTS) = 0.0_real64
  end type scheduled_irrigation_parameters_t

  type, public :: irrigation_state_t
    integer :: next_fixed_event_index = 1
    logical :: active_event = .false.
    integer :: active_event_origin = IRRIGATION_EVENT_NONE
    integer :: active_event_index = 0
    real(real64) :: active_event_start = 0.0_real64
    real(real64) :: active_event_end = 0.0_real64
  end type irrigation_state_t

  type, public :: irrigation_management_request_t
    real(real64) :: t0 = 0.0_real64
    real(real64) :: t1 = 0.0_real64
  end type irrigation_management_request_t

  type, public :: scheduled_irrigation_request_t
    real(real64) :: t0 = 0.0_real64
    real(real64) :: t1 = 0.0_real64
    real(real64) :: dvs = 0.0_real64
    logical :: selection_opportunity = .false.
    logical :: irrigation_enabled = .false.
    logical :: schedule_enabled = .false.
    logical :: crop_emerged = .false.
    logical :: irrigation_window_open = .false.
    logical :: fixed_event_already_selected = .false.
  end type scheduled_irrigation_request_t

  type, public :: irrigation_flux_result_t
    logical :: applied = .false.
    logical :: event_started = .false.
    logical :: event_finished = .false.
    logical :: event_remains_active = .false.
    integer :: event_origin = IRRIGATION_EVENT_NONE
    integer :: event_index = 0
    integer :: application_type = IRRIGATION_APPLICATION_SPRINKLER
    real(real64) :: concentration = 0.0_real64
    real(real64) :: event_duration = 0.0_real64
    real(real64) :: active_duration = 0.0_real64
    real(real64) :: surface_gross_rate = 0.0_real64
    real(real64), allocatable :: subsurface_source(:)
    real(real64) :: external_inflow_amount = 0.0_real64
  end type irrigation_flux_result_t

  type, public :: irrigation_diagnostics_t
    integer :: status = IRRIGATION_OK
    logical :: event_match = .false.
    logical :: split_required = .false.
    real(real64) :: split_time = 0.0_real64
    logical :: selection_evaluated = .false.
    logical :: triggered = .false.
    real(real64) :: interpolated_threshold = 0.0_real64
    real(real64) :: interpolated_depth = 0.0_real64
    logical :: external_inflow_is_reconciliation_only = .true.
  end type irrigation_diagnostics_t

  public :: evaluate_fixed_irrigation_interval
  public :: evaluate_scheduled_irrigation_interval

contains

  pure subroutine evaluate_fixed_irrigation_interval(parameters, committed_state, request, &
                                                       candidate_state, fluxes, diagnostics)
    type(irrigation_parameters_t), intent(in) :: parameters
    type(irrigation_state_t), intent(in) :: committed_state
    type(irrigation_management_request_t), intent(in) :: request
    type(irrigation_state_t), intent(out) :: candidate_state
    type(irrigation_flux_result_t), intent(out) :: fluxes
    type(irrigation_diagnostics_t), intent(out) :: diagnostics
    type(fixed_irrigation_event_t) :: event
    real(real64) :: duration, event_end, effective_t0, effective_t1
    integer :: event_index
    logical :: finishes_at_event_end

    candidate_state = committed_state
    fluxes = irrigation_flux_result_t()
    diagnostics = irrigation_diagnostics_t()

    if (request%t1 <= request%t0) then
      diagnostics%status = IRRIGATION_INVALID_INTERVAL
      return
    end if

    if (.not. valid_state(committed_state)) then
      diagnostics%status = IRRIGATION_INVALID_STATE
      return
    end if

    if (.not. parameters%fixed_irrigation_enabled) then
      if (committed_state%active_event) diagnostics%status = IRRIGATION_INVALID_STATE
      return
    end if

    if (committed_state%active_event) then
      if (committed_state%active_event_origin /= IRRIGATION_EVENT_FIXED) then
        diagnostics%status = IRRIGATION_INVALID_STATE
        return
      end if
      event_index = committed_state%active_event_index
      if (.not. event_index_available(parameters, event_index)) then
        diagnostics%status = IRRIGATION_INVALID_STATE
        return
      end if
      event = parameters%fixed_events(event_index)
      if (.not. valid_event(parameters, event)) then
        diagnostics%status = IRRIGATION_INVALID_EVENT
        return
      end if
      duration = event%depth / event%rate
      event_end = committed_state%active_event_start + duration
      if (.not. same_time(committed_state%active_event_end, event_end)) then
        diagnostics%status = IRRIGATION_INVALID_STATE
        return
      end if
      if ((request%t0 < committed_state%active_event_start .and. &
           .not. same_time(request%t0, committed_state%active_event_start)) .or. &
          (request%t0 > event_end .and. .not. same_time(request%t0, event_end))) then
        diagnostics%status = IRRIGATION_INVALID_STATE
        return
      end if
      if (same_time(request%t0, event_end)) then
        call clear_active_event(candidate_state)
        return
      end if

      finishes_at_event_end = same_time(request%t1, event_end)
      if (request%t1 > event_end .and. .not. finishes_at_event_end) then
        candidate_state = committed_state
        diagnostics%status = IRRIGATION_SPLIT_REQUIRED
        diagnostics%split_required = .true.
        diagnostics%split_time = event_end
        return
      end if

      effective_t0 = request%t0
      if (same_time(effective_t0, committed_state%active_event_start)) &
        effective_t0 = committed_state%active_event_start
      effective_t1 = request%t1
      if (finishes_at_event_end) effective_t1 = event_end

      call apply_event(parameters, event, event_index, effective_t1-effective_t0, duration, fluxes)
      fluxes%event_remains_active = .not. finishes_at_event_end
      if (finishes_at_event_end) then
        fluxes%event_finished = .true.
        call clear_active_event(candidate_state)
      end if
      return
    end if

    event_index = committed_state%next_fixed_event_index
    if (.not. event_index_available(parameters, event_index)) return
    event = parameters%fixed_events(event_index)

    if (abs(event%event_time - request%t0) >= IRRIGATION_FIXED_EVENT_MATCH_TOLERANCE) return
    diagnostics%event_match = .true.

    if (.not. valid_event(parameters, event)) then
      diagnostics%status = IRRIGATION_INVALID_EVENT
      return
    end if

    duration = event%depth / event%rate
    event_end = request%t0 + duration
    finishes_at_event_end = same_time(request%t1, event_end)
    if (request%t1 > event_end .and. .not. finishes_at_event_end) then
      candidate_state = committed_state
      diagnostics%status = IRRIGATION_SPLIT_REQUIRED
      diagnostics%split_required = .true.
      diagnostics%split_time = event_end
      return
    end if

    candidate_state%next_fixed_event_index = event_index + 1
    candidate_state%active_event = .true.
    candidate_state%active_event_origin = IRRIGATION_EVENT_FIXED
    candidate_state%active_event_index = event_index
    candidate_state%active_event_start = request%t0
    candidate_state%active_event_end = event_end

    effective_t1 = request%t1
    if (finishes_at_event_end) effective_t1 = event_end
    call apply_event(parameters, event, event_index, effective_t1-request%t0, duration, fluxes)
    fluxes%event_started = .true.
    fluxes%event_remains_active = .not. finishes_at_event_end
    if (finishes_at_event_end) then
      fluxes%event_finished = .true.
      call clear_active_event(candidate_state)
    end if
  end subroutine evaluate_fixed_irrigation_interval

  pure subroutine evaluate_scheduled_irrigation_interval(parameters, committed_state, request, hydraulic_view, &
                                                           candidate_state, fluxes, diagnostics)
    type(scheduled_irrigation_parameters_t), intent(in) :: parameters
    type(irrigation_state_t), intent(in) :: committed_state
    type(scheduled_irrigation_request_t), intent(in) :: request
    type(process_hydraulic_view_t), intent(in) :: hydraulic_view
    type(irrigation_state_t), intent(out) :: candidate_state
    type(irrigation_flux_result_t), intent(out) :: fluxes
    type(irrigation_diagnostics_t), intent(out) :: diagnostics
    real(real64) :: threshold, depth, duration, event_end, effective_t0, effective_t1
    logical :: ok, finishes_at_event_end

    candidate_state = committed_state
    fluxes = irrigation_flux_result_t()
    diagnostics = irrigation_diagnostics_t()

    if (request%t1 <= request%t0) then
      diagnostics%status = IRRIGATION_INVALID_INTERVAL
      return
    end if
    if (.not. valid_state(committed_state)) then
      diagnostics%status = IRRIGATION_INVALID_STATE
      return
    end if

    if (committed_state%active_event) then
      if (committed_state%active_event_origin /= IRRIGATION_EVENT_SCHEDULED) then
        diagnostics%status = IRRIGATION_INVALID_STATE
        return
      end if
      if (.not. valid_scheduled_parameters(parameters)) then
        diagnostics%status = IRRIGATION_INVALID_PARAMETERS
        return
      end if
      duration = committed_state%active_event_end - committed_state%active_event_start
      if (duration > IRRIGATION_MAX_EVENT_DURATION) then
        diagnostics%status = IRRIGATION_INVALID_STATE
        return
      end if
      event_end = committed_state%active_event_end
      if ((request%t0 < committed_state%active_event_start .and. &
           .not. same_time(request%t0, committed_state%active_event_start)) .or. &
          (request%t0 > event_end .and. .not. same_time(request%t0, event_end))) then
        diagnostics%status = IRRIGATION_INVALID_STATE
        return
      end if
      if (same_time(request%t0, event_end)) then
        call clear_active_event(candidate_state)
        return
      end if

      finishes_at_event_end = same_time(request%t1, event_end)
      if (request%t1 > event_end .and. .not. finishes_at_event_end) then
        candidate_state = committed_state
        diagnostics%status = IRRIGATION_SPLIT_REQUIRED
        diagnostics%split_required = .true.
        diagnostics%split_time = event_end
        return
      end if

      effective_t0 = request%t0
      if (same_time(effective_t0, committed_state%active_event_start)) &
        effective_t0 = committed_state%active_event_start
      effective_t1 = request%t1
      if (finishes_at_event_end) effective_t1 = event_end
      call apply_scheduled_event(parameters, effective_t1-effective_t0, duration, fluxes)
      fluxes%event_remains_active = .not. finishes_at_event_end
      if (finishes_at_event_end) then
        fluxes%event_finished = .true.
        call clear_active_event(candidate_state)
      end if
      return
    end if

    if (.not. parameters%scheduled_irrigation_enabled) return
    if (.not. request%selection_opportunity) return
    if (.not. request%irrigation_enabled) return
    if (.not. request%schedule_enabled) return
    if (.not. request%crop_emerged) return
    if (.not. request%irrigation_window_open) return
    if (request%fixed_event_already_selected) return
    diagnostics%selection_evaluated = .true.

    if (.not. ieee_is_finite(request%dvs)) then
      diagnostics%status = IRRIGATION_INVALID_PARAMETERS
      return
    end if
    if (.not. valid_scheduled_parameters(parameters)) then
      diagnostics%status = IRRIGATION_INVALID_PARAMETERS
      return
    end if
    if (.not. valid_scheduled_hydraulic_view(parameters, hydraulic_view)) then
      diagnostics%status = IRRIGATION_INVALID_HYDRAULIC_VIEW
      return
    end if

    call restricted_afgen(parameters%tcs7_dvs, parameters%tcs7_pressure_head, parameters%tcs7_knot_count, &
                          request%dvs, threshold, ok)
    if (.not. ok) then
      diagnostics%status = IRRIGATION_INVALID_PARAMETERS
      return
    end if
    diagnostics%interpolated_threshold = threshold
    if (hydraulic_view%pressure_head(parameters%sensor_node) > threshold) return
    diagnostics%triggered = .true.

    call restricted_afgen(parameters%dcs2_dvs, parameters%dcs2_depth_cm, parameters%dcs2_knot_count, &
                          request%dvs, depth, ok)
    if (.not. ok) then
      diagnostics%status = IRRIGATION_INVALID_PARAMETERS
      return
    end if
    diagnostics%interpolated_depth = depth
    if (depth <= 0.0_real64) then
      diagnostics%status = IRRIGATION_INVALID_EVENT
      return
    end if

    duration = depth / parameters%irr_rate_cm_per_day
    if (.not. ieee_is_finite(duration) .or. duration <= 0.0_real64 .or. &
        duration > IRRIGATION_MAX_EVENT_DURATION) then
      diagnostics%status = IRRIGATION_INVALID_EVENT
      return
    end if
    event_end = request%t0 + duration
    finishes_at_event_end = same_time(request%t1, event_end)
    if (request%t1 > event_end .and. .not. finishes_at_event_end) then
      candidate_state = committed_state
      diagnostics%status = IRRIGATION_SPLIT_REQUIRED
      diagnostics%split_required = .true.
      diagnostics%split_time = event_end
      return
    end if

    candidate_state%active_event = .true.
    candidate_state%active_event_origin = IRRIGATION_EVENT_SCHEDULED
    candidate_state%active_event_index = 0
    candidate_state%active_event_start = request%t0
    candidate_state%active_event_end = event_end

    effective_t1 = request%t1
    if (finishes_at_event_end) effective_t1 = event_end
    call apply_scheduled_event(parameters, effective_t1-request%t0, duration, fluxes)
    fluxes%event_started = .true.
    fluxes%event_remains_active = .not. finishes_at_event_end
    if (finishes_at_event_end) then
      fluxes%event_finished = .true.
      call clear_active_event(candidate_state)
    end if
  end subroutine evaluate_scheduled_irrigation_interval

  pure logical function valid_state(state)
    type(irrigation_state_t), intent(in) :: state

    valid_state = state%next_fixed_event_index >= 1
    if (.not. valid_state) return
    if (state%active_event) then
      valid_state = state%active_event_end > state%active_event_start
      if (.not. valid_state) return
      select case (state%active_event_origin)
      case (IRRIGATION_EVENT_FIXED)
        valid_state = state%active_event_index >= 1 .and. &
                      state%next_fixed_event_index == state%active_event_index + 1
      case (IRRIGATION_EVENT_SCHEDULED)
        valid_state = state%active_event_index == 0
      case default
        valid_state = .false.
      end select
    else
      valid_state = state%active_event_origin == IRRIGATION_EVENT_NONE .and. state%active_event_index == 0
    end if
  end function valid_state

  pure logical function event_index_available(parameters, event_index)
    type(irrigation_parameters_t), intent(in) :: parameters
    integer, intent(in) :: event_index

    event_index_available = .false.
    if (.not. allocated(parameters%fixed_events)) return
    if (event_index < 1 .or. event_index > size(parameters%fixed_events)) return
    event_index_available = .true.
  end function event_index_available

  pure logical function valid_event(parameters, event)
    type(irrigation_parameters_t), intent(in) :: parameters
    type(fixed_irrigation_event_t), intent(in) :: event
    real(real64) :: duration

    valid_event = .false.
    if (event%application_type < IRRIGATION_APPLICATION_SPRINKLER .or. &
        event%application_type > IRRIGATION_APPLICATION_SSDI) return
    if (event%depth <= 0.0_real64 .or. event%rate <= 0.0_real64) return
    duration = event%depth / event%rate
    if (duration > IRRIGATION_MAX_EVENT_DURATION) return
    if (event%application_type == IRRIGATION_APPLICATION_SSDI) then
      if (parameters%active_nodes <= 0) return
      if (parameters%ssdi_first_node < 1 .or. parameters%ssdi_last_node < parameters%ssdi_first_node) return
      if (parameters%ssdi_last_node > parameters%active_nodes) return
    end if
    valid_event = .true.
  end function valid_event

  pure logical function valid_scheduled_parameters(parameters)
    type(scheduled_irrigation_parameters_t), intent(in) :: parameters

    valid_scheduled_parameters = .false.
    if (.not. parameters%scheduled_irrigation_enabled) return
    if (parameters%active_nodes <= 0) return
    if (parameters%sensor_node < 1 .or. parameters%sensor_node > parameters%active_nodes) return
    if (parameters%single_ssdi_node < 1 .or. parameters%single_ssdi_node > parameters%active_nodes) return
    if (.not. ieee_is_finite(parameters%irr_rate_cm_per_day)) return
    if (parameters%irr_rate_cm_per_day <= 0.0_real64) return
    if (.not. valid_table(parameters%tcs7_dvs, parameters%tcs7_pressure_head, parameters%tcs7_knot_count)) return
    if (.not. valid_table(parameters%dcs2_dvs, parameters%dcs2_depth_cm, parameters%dcs2_knot_count)) return
    if (any(parameters%dcs2_depth_cm(1:parameters%dcs2_knot_count) < 0.0_real64)) return
    valid_scheduled_parameters = .true.
  end function valid_scheduled_parameters

  pure logical function valid_table(knots, values, knot_count)
    real(real64), intent(in) :: knots(IRRIGATION_MAX_SCHEDULED_KNOTS)
    real(real64), intent(in) :: values(IRRIGATION_MAX_SCHEDULED_KNOTS)
    integer, intent(in) :: knot_count
    integer :: i

    valid_table = .false.
    if (knot_count < 2 .or. knot_count > IRRIGATION_MAX_SCHEDULED_KNOTS) return
    do i = 1, knot_count
      if (.not. ieee_is_finite(knots(i)) .or. .not. ieee_is_finite(values(i))) return
      if (knots(i) < 0.0_real64 .or. knots(i) > 2.0_real64) return
    end do
    do i = 2, knot_count
      if (knots(i) <= knots(i-1)) return
    end do
    valid_table = .true.
  end function valid_table

  pure logical function valid_scheduled_hydraulic_view(parameters, hydraulic_view)
    type(scheduled_irrigation_parameters_t), intent(in) :: parameters
    type(process_hydraulic_view_t), intent(in) :: hydraulic_view

    valid_scheduled_hydraulic_view = .false.
    if (hydraulic_view%active_nodes /= parameters%active_nodes) return
    if (.not. allocated(hydraulic_view%pressure_head)) return
    if (.not. allocated(hydraulic_view%water_content)) return
    if (size(hydraulic_view%pressure_head) /= hydraulic_view%active_nodes) return
    if (size(hydraulic_view%water_content) /= hydraulic_view%active_nodes) return
    if (.not. ieee_is_finite(hydraulic_view%pressure_head(parameters%sensor_node))) return
    valid_scheduled_hydraulic_view = .true.
  end function valid_scheduled_hydraulic_view

  pure subroutine restricted_afgen(knots, values, knot_count, x, value, ok)
    real(real64), intent(in) :: knots(IRRIGATION_MAX_SCHEDULED_KNOTS)
    real(real64), intent(in) :: values(IRRIGATION_MAX_SCHEDULED_KNOTS)
    integer, intent(in) :: knot_count
    real(real64), intent(in) :: x
    real(real64), intent(out) :: value
    logical, intent(out) :: ok
    real(real64) :: fraction
    integer :: i

    value = 0.0_real64
    ok = .false.
    if (.not. ieee_is_finite(x)) return
    if (.not. valid_table(knots, values, knot_count)) return

    if (x <= knots(1)) then
      value = values(1)
      ok = .true.
      return
    end if
    if (x > knots(knot_count)) then
      if (knot_count < IRRIGATION_MAX_SCHEDULED_KNOTS) return
      value = values(knot_count)
      ok = .true.
      return
    end if

    do i = 2, knot_count
      if (x <= knots(i)) then
        fraction = (x-knots(i-1)) / (knots(i)-knots(i-1))
        value = values(i-1) + fraction * (values(i)-values(i-1))
        ok = ieee_is_finite(value)
        return
      end if
    end do
  end subroutine restricted_afgen

  pure subroutine apply_event(parameters, event, event_index, active_duration, event_duration, fluxes)
    type(irrigation_parameters_t), intent(in) :: parameters
    type(fixed_irrigation_event_t), intent(in) :: event
    integer, intent(in) :: event_index
    real(real64), intent(in) :: active_duration, event_duration
    type(irrigation_flux_result_t), intent(inout) :: fluxes

    fluxes%applied = .true.
    fluxes%event_origin = IRRIGATION_EVENT_FIXED
    fluxes%event_index = event_index
    fluxes%application_type = event%application_type
    fluxes%event_duration = event_duration
    fluxes%active_duration = active_duration

    if (event%application_type < IRRIGATION_APPLICATION_SSDI) then
      fluxes%concentration = event%concentration
      fluxes%surface_gross_rate = event%rate
      fluxes%external_inflow_amount = event%rate * active_duration
    else
      allocate(fluxes%subsurface_source(parameters%active_nodes))
      fluxes%subsurface_source = 0.0_real64
      fluxes%subsurface_source(parameters%ssdi_first_node:parameters%ssdi_last_node) = event%rate
      fluxes%external_inflow_amount = sum(fluxes%subsurface_source) * active_duration
    end if
  end subroutine apply_event

  pure subroutine apply_scheduled_event(parameters, active_duration, event_duration, fluxes)
    type(scheduled_irrigation_parameters_t), intent(in) :: parameters
    real(real64), intent(in) :: active_duration, event_duration
    type(irrigation_flux_result_t), intent(inout) :: fluxes

    fluxes%applied = .true.
    fluxes%event_origin = IRRIGATION_EVENT_SCHEDULED
    fluxes%event_index = 0
    fluxes%application_type = IRRIGATION_APPLICATION_SSDI
    fluxes%event_duration = event_duration
    fluxes%active_duration = active_duration
    allocate(fluxes%subsurface_source(parameters%active_nodes))
    fluxes%subsurface_source = 0.0_real64
    fluxes%subsurface_source(parameters%single_ssdi_node) = parameters%irr_rate_cm_per_day
    fluxes%external_inflow_amount = parameters%irr_rate_cm_per_day * active_duration
  end subroutine apply_scheduled_event

  pure logical function same_time(a, b)
    real(real64), intent(in) :: a, b
    real(real64) :: tolerance

    tolerance = IRRIGATION_TIME_EPSILON_SCALE * epsilon(1.0_real64) * &
                max(1.0_real64, abs(a), abs(b))
    same_time = abs(a-b) <= tolerance
  end function same_time

  pure subroutine clear_active_event(state)
    type(irrigation_state_t), intent(inout) :: state

    state%active_event = .false.
    state%active_event_origin = IRRIGATION_EVENT_NONE
    state%active_event_index = 0
    state%active_event_start = 0.0_real64
    state%active_event_end = 0.0_real64
  end subroutine clear_active_event

end module mod_irrigation_process
