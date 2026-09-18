module mod_tcs1_dcs2_sprinkling_irrigation_process
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: TCS1_DCS2_OK = 0
  integer, parameter, public :: TCS1_DCS2_INVALID_INTERVAL = 1
  integer, parameter, public :: TCS1_DCS2_INVALID_STATE = 2
  integer, parameter, public :: TCS1_DCS2_INVALID_PARAMETERS = 3
  integer, parameter, public :: TCS1_DCS2_INVALID_REQUEST = 4
  integer, parameter, public :: TCS1_DCS2_SPLIT_REQUIRED = 5
  integer, parameter, public :: TCS1_DCS2_MAX_KNOTS = 7

  real(real64), parameter :: TCS1_DCS2_TIME_EPSILON_SCALE = 64.0_real64
  real(real64), parameter :: TCS1_DCS2_PTRA_SMALL = 1.0e-10_real64

  type, public :: tcs1_dcs2_sprinkling_parameters_t
    logical :: enabled = .false.
    real(real64) :: rate_cm_per_day = 0.0_real64
    integer :: threshold_knot_count = 0
    real(real64) :: threshold_dvs(TCS1_DCS2_MAX_KNOTS) = 0.0_real64
    real(real64) :: threshold_trel(TCS1_DCS2_MAX_KNOTS) = 0.0_real64
    integer :: depth_knot_count = 0
    real(real64) :: depth_dvs(TCS1_DCS2_MAX_KNOTS) = 0.0_real64
    real(real64) :: depth_cm(TCS1_DCS2_MAX_KNOTS) = 0.0_real64
    integer :: minimum_interval_days = 0
  end type tcs1_dcs2_sprinkling_parameters_t

  type, public :: tcs1_dcs2_sprinkling_state_t
    integer :: dayfix = 366
    logical :: active_event = .false.
    real(real64) :: active_event_start = 0.0_real64
    real(real64) :: active_event_end = 0.0_real64
  end type tcs1_dcs2_sprinkling_state_t

  type, public :: tcs1_dcs2_sprinkling_request_t
    real(real64) :: t0 = 0.0_real64
    real(real64) :: t1 = 0.0_real64
    real(real64) :: dvs = 0.0_real64
    real(real64) :: potential_transpiration_day_cm = 0.0_real64
    real(real64) :: dry_reduction_day_cm = 0.0_real64
    real(real64) :: salinity_reduction_day_cm = 0.0_real64
    logical :: selection_opportunity = .false.
    logical :: irrigation_enabled = .false.
    logical :: schedule_enabled = .false.
    logical :: crop_emerged = .false.
    logical :: irrigation_window_open = .false.
    logical :: fixed_event_already_selected = .false.
  end type tcs1_dcs2_sprinkling_request_t

  type, public :: tcs1_dcs2_sprinkling_result_t
    logical :: applied = .false.
    logical :: event_started = .false.
    logical :: event_finished = .false.
    logical :: event_remains_active = .false.
    real(real64) :: event_depth_cm = 0.0_real64
    real(real64) :: event_duration_day = 0.0_real64
    real(real64) :: active_duration_day = 0.0_real64
    real(real64) :: gross_surface_rate_cm_per_day = 0.0_real64
    real(real64) :: external_inflow_amount_cm = 0.0_real64
  end type tcs1_dcs2_sprinkling_result_t

  type, public :: tcs1_dcs2_sprinkling_diagnostics_t
    integer :: status = TCS1_DCS2_OK
    logical :: selection_evaluated = .false.
    logical :: stress_triggered = .false.
    logical :: interval_gate_passed = .false.
    logical :: split_required = .false.
    real(real64) :: split_time = 0.0_real64
    real(real64) :: interpolated_trel = 0.0_real64
    real(real64) :: transpiration_ratio = 1.0_real64
    real(real64) :: interpolated_depth_cm = 0.0_real64
  end type tcs1_dcs2_sprinkling_diagnostics_t

  public :: evaluate_tcs1_dcs2_sprinkling_interval

contains

  pure subroutine evaluate_tcs1_dcs2_sprinkling_interval(parameters, committed_state, request, &
                                                           candidate_state, result, diagnostics)
    type(tcs1_dcs2_sprinkling_parameters_t), intent(in) :: parameters
    type(tcs1_dcs2_sprinkling_state_t), intent(in) :: committed_state
    type(tcs1_dcs2_sprinkling_request_t), intent(in) :: request
    type(tcs1_dcs2_sprinkling_state_t), intent(out) :: candidate_state
    type(tcs1_dcs2_sprinkling_result_t), intent(out) :: result
    type(tcs1_dcs2_sprinkling_diagnostics_t), intent(out) :: diagnostics
    real(real64) :: threshold, depth, duration, event_end, effective_t1
    logical :: ok, finishes_at_event_end

    candidate_state = committed_state
    result = tcs1_dcs2_sprinkling_result_t()
    diagnostics = tcs1_dcs2_sprinkling_diagnostics_t()

    if (request%t1 <= request%t0) then
      diagnostics%status = TCS1_DCS2_INVALID_INTERVAL
      return
    end if
    if (.not. valid_state(committed_state)) then
      diagnostics%status = TCS1_DCS2_INVALID_STATE
      return
    end if
    if (.not. valid_request(request)) then
      diagnostics%status = TCS1_DCS2_INVALID_REQUEST
      return
    end if

    if (committed_state%active_event) then
      if (.not. valid_parameters(parameters)) then
        diagnostics%status = TCS1_DCS2_INVALID_PARAMETERS
        return
      end if
      event_end = committed_state%active_event_end
      if ((request%t0 < committed_state%active_event_start .and. &
           .not. same_time(request%t0, committed_state%active_event_start)) .or. &
          (request%t0 > event_end .and. .not. same_time(request%t0, event_end))) then
        diagnostics%status = TCS1_DCS2_INVALID_STATE
        return
      end if
      if (same_time(request%t0, event_end)) then
        call clear_active_event(candidate_state)
        return
      end if

      duration = committed_state%active_event_end - committed_state%active_event_start
      finishes_at_event_end = same_time(request%t1, event_end)
      if (request%t1 > event_end .and. .not. finishes_at_event_end) then
        candidate_state = committed_state
        diagnostics%status = TCS1_DCS2_SPLIT_REQUIRED
        diagnostics%split_required = .true.
        diagnostics%split_time = event_end
        return
      end if

      effective_t1 = request%t1
      if (finishes_at_event_end) effective_t1 = event_end
      call apply_event(parameters%rate_cm_per_day, duration, effective_t1-request%t0, result)
      result%event_remains_active = .not. finishes_at_event_end
      if (finishes_at_event_end) then
        result%event_finished = .true.
        call clear_active_event(candidate_state)
      end if
      return
    end if

    if (.not. parameters%enabled) return
    if (.not. request%selection_opportunity) return
    if (.not. request%irrigation_enabled) return
    if (.not. request%schedule_enabled) return
    if (.not. request%crop_emerged) return
    if (.not. request%irrigation_window_open) return
    if (request%fixed_event_already_selected) return
    diagnostics%selection_evaluated = .true.

    if (.not. valid_parameters(parameters)) then
      diagnostics%status = TCS1_DCS2_INVALID_PARAMETERS
      return
    end if

    call restricted_afgen(parameters%threshold_dvs, parameters%threshold_trel, &
                          parameters%threshold_knot_count, request%dvs, threshold, ok)
    if (.not. ok) then
      diagnostics%status = TCS1_DCS2_INVALID_PARAMETERS
      return
    end if
    diagnostics%interpolated_trel = threshold

    if (request%potential_transpiration_day_cm > TCS1_DCS2_PTRA_SMALL) then
      diagnostics%transpiration_ratio = 1.0_real64 - &
        (request%dry_reduction_day_cm + request%salinity_reduction_day_cm) / &
        request%potential_transpiration_day_cm
    else
      diagnostics%transpiration_ratio = 1.0_real64
    end if
    if (.not. ieee_is_finite(diagnostics%transpiration_ratio)) then
      diagnostics%status = TCS1_DCS2_INVALID_REQUEST
      return
    end if

    diagnostics%stress_triggered = diagnostics%transpiration_ratio < threshold
    if (.not. diagnostics%stress_triggered) then
      call advance_dayfix_without_event(parameters, candidate_state)
      return
    end if

    if (committed_state%dayfix < parameters%minimum_interval_days) then
      call advance_dayfix_without_event(parameters, candidate_state)
      return
    end if
    diagnostics%interval_gate_passed = .true.

    call restricted_afgen(parameters%depth_dvs, parameters%depth_cm, parameters%depth_knot_count, &
                          request%dvs, depth, ok)
    if (.not. ok .or. depth <= 0.0_real64) then
      diagnostics%status = TCS1_DCS2_INVALID_PARAMETERS
      return
    end if
    diagnostics%interpolated_depth_cm = depth

    duration = depth / parameters%rate_cm_per_day
    if (.not. ieee_is_finite(duration) .or. duration <= 0.0_real64 .or. duration > 1.0_real64) then
      diagnostics%status = TCS1_DCS2_INVALID_PARAMETERS
      return
    end if
    event_end = request%t0 + duration
    finishes_at_event_end = same_time(request%t1, event_end)
    if (request%t1 > event_end .and. .not. finishes_at_event_end) then
      candidate_state = committed_state
      diagnostics%status = TCS1_DCS2_SPLIT_REQUIRED
      diagnostics%split_required = .true.
      diagnostics%split_time = event_end
      return
    end if

    candidate_state%dayfix = 1
    candidate_state%active_event = .true.
    candidate_state%active_event_start = request%t0
    candidate_state%active_event_end = event_end

    effective_t1 = request%t1
    if (finishes_at_event_end) effective_t1 = event_end
    call apply_event(parameters%rate_cm_per_day, duration, effective_t1-request%t0, result)
    result%event_depth_cm = depth
    result%event_started = .true.
    result%event_remains_active = .not. finishes_at_event_end
    if (finishes_at_event_end) then
      result%event_finished = .true.
      call clear_active_event(candidate_state)
    end if
  end subroutine evaluate_tcs1_dcs2_sprinkling_interval

  pure subroutine advance_dayfix_without_event(parameters, state)
    type(tcs1_dcs2_sprinkling_parameters_t), intent(in) :: parameters
    type(tcs1_dcs2_sprinkling_state_t), intent(inout) :: state
    if (state%dayfix < parameters%minimum_interval_days) state%dayfix = state%dayfix + 1
  end subroutine advance_dayfix_without_event

  pure subroutine apply_event(rate, event_duration, active_duration, result)
    real(real64), intent(in) :: rate, event_duration, active_duration
    type(tcs1_dcs2_sprinkling_result_t), intent(inout) :: result

    result%applied = .true.
    result%event_duration_day = event_duration
    result%active_duration_day = active_duration
    result%gross_surface_rate_cm_per_day = rate
    result%external_inflow_amount_cm = rate * active_duration
  end subroutine apply_event

  pure logical function valid_state(state)
    type(tcs1_dcs2_sprinkling_state_t), intent(in) :: state

    valid_state = state%dayfix >= 0
    if (.not. valid_state) return
    if (state%active_event) then
      valid_state = ieee_is_finite(state%active_event_start) .and. ieee_is_finite(state%active_event_end) .and. &
                    state%active_event_end > state%active_event_start
    else
      valid_state = abs(state%active_event_start) <= epsilon(1.0_real64) .and. &
                    abs(state%active_event_end) <= epsilon(1.0_real64)
    end if
  end function valid_state

  pure logical function valid_parameters(parameters)
    type(tcs1_dcs2_sprinkling_parameters_t), intent(in) :: parameters

    valid_parameters = .false.
    if (.not. parameters%enabled) return
    if (.not. ieee_is_finite(parameters%rate_cm_per_day) .or. parameters%rate_cm_per_day <= 0.0_real64) return
    if (parameters%minimum_interval_days < 1) return
    if (.not. valid_table(parameters%threshold_dvs, parameters%threshold_trel, parameters%threshold_knot_count)) return
    if (.not. valid_table(parameters%depth_dvs, parameters%depth_cm, parameters%depth_knot_count)) return
    if (any(parameters%threshold_trel(1:parameters%threshold_knot_count) < 0.0_real64) .or. &
        any(parameters%threshold_trel(1:parameters%threshold_knot_count) > 1.0_real64)) return
    if (any(parameters%depth_cm(1:parameters%depth_knot_count) <= 0.0_real64)) return
    valid_parameters = .true.
  end function valid_parameters

  pure logical function valid_request(request)
    type(tcs1_dcs2_sprinkling_request_t), intent(in) :: request

    valid_request = ieee_is_finite(request%t0) .and. ieee_is_finite(request%t1) .and. &
                    ieee_is_finite(request%dvs) .and. ieee_is_finite(request%potential_transpiration_day_cm) .and. &
                    ieee_is_finite(request%dry_reduction_day_cm) .and. &
                    ieee_is_finite(request%salinity_reduction_day_cm)
    if (.not. valid_request) return
    valid_request = request%potential_transpiration_day_cm >= 0.0_real64 .and. &
                    request%dry_reduction_day_cm >= 0.0_real64 .and. &
                    request%salinity_reduction_day_cm >= 0.0_real64
  end function valid_request

  pure logical function valid_table(knots, values, knot_count)
    real(real64), intent(in) :: knots(TCS1_DCS2_MAX_KNOTS), values(TCS1_DCS2_MAX_KNOTS)
    integer, intent(in) :: knot_count
    integer :: i

    valid_table = .false.
    if (knot_count < 2 .or. knot_count > TCS1_DCS2_MAX_KNOTS) return
    do i = 1, knot_count
      if (.not. ieee_is_finite(knots(i)) .or. .not. ieee_is_finite(values(i))) return
      if (knots(i) < 0.0_real64 .or. knots(i) > 2.0_real64) return
    end do
    do i = 2, knot_count
      if (knots(i) <= knots(i-1)) return
    end do
    valid_table = .true.
  end function valid_table

  pure subroutine restricted_afgen(knots, values, knot_count, x, value, ok)
    real(real64), intent(in) :: knots(TCS1_DCS2_MAX_KNOTS), values(TCS1_DCS2_MAX_KNOTS)
    integer, intent(in) :: knot_count
    real(real64), intent(in) :: x
    real(real64), intent(out) :: value
    logical, intent(out) :: ok
    integer :: i
    real(real64) :: fraction

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
      if (knot_count < TCS1_DCS2_MAX_KNOTS) return
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

  pure logical function same_time(a, b)
    real(real64), intent(in) :: a, b
    real(real64) :: tolerance

    tolerance = TCS1_DCS2_TIME_EPSILON_SCALE * epsilon(1.0_real64) * max(1.0_real64, abs(a), abs(b))
    same_time = abs(a-b) <= tolerance
  end function same_time

  pure subroutine clear_active_event(state)
    type(tcs1_dcs2_sprinkling_state_t), intent(inout) :: state

    state%active_event = .false.
    state%active_event_start = 0.0_real64
    state%active_event_end = 0.0_real64
  end subroutine clear_active_event
end module mod_tcs1_dcs2_sprinkling_irrigation_process
