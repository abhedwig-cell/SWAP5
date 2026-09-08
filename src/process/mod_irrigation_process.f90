module mod_irrigation_process
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  integer, parameter, public :: IRRIGATION_OK = 0
  integer, parameter, public :: IRRIGATION_INVALID_INTERVAL = 1
  integer, parameter, public :: IRRIGATION_INVALID_STATE = 2
  integer, parameter, public :: IRRIGATION_INVALID_EVENT = 3
  integer, parameter, public :: IRRIGATION_SPLIT_REQUIRED = 4

  real(real64), parameter, public :: IRRIGATION_FIXED_EVENT_MATCH_TOLERANCE = 1.0e-3_real64
  real(real64), parameter, public :: IRRIGATION_MAX_EVENT_DURATION = 1.0_real64
  real(real64), parameter :: IRRIGATION_TIME_EPSILON_SCALE = 64.0_real64

  integer, parameter, public :: IRRIGATION_APPLICATION_SPRINKLER = 0
  integer, parameter, public :: IRRIGATION_APPLICATION_SURFACE = 1
  integer, parameter, public :: IRRIGATION_APPLICATION_SSDI = 2

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

  type, public :: irrigation_state_t
    integer :: next_fixed_event_index = 1
    logical :: active_event = .false.
    integer :: active_event_index = 0
    real(real64) :: active_event_start = 0.0_real64
    real(real64) :: active_event_end = 0.0_real64
  end type irrigation_state_t

  type, public :: irrigation_management_request_t
    real(real64) :: t0 = 0.0_real64
    real(real64) :: t1 = 0.0_real64
  end type irrigation_management_request_t

  type, public :: irrigation_flux_result_t
    logical :: applied = .false.
    logical :: event_started = .false.
    logical :: event_finished = .false.
    logical :: event_remains_active = .false.
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
    logical :: external_inflow_is_reconciliation_only = .true.
  end type irrigation_diagnostics_t

  public :: evaluate_fixed_irrigation_interval

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

  pure logical function valid_state(state)
    type(irrigation_state_t), intent(in) :: state

    valid_state = state%next_fixed_event_index >= 1
    if (.not. valid_state) return
    if (state%active_event) then
      valid_state = state%active_event_index >= 1 .and. &
                    state%next_fixed_event_index == state%active_event_index + 1 .and. &
                    state%active_event_end > state%active_event_start
    else
      valid_state = state%active_event_index == 0
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

  pure subroutine apply_event(parameters, event, event_index, active_duration, event_duration, fluxes)
    type(irrigation_parameters_t), intent(in) :: parameters
    type(fixed_irrigation_event_t), intent(in) :: event
    integer, intent(in) :: event_index
    real(real64), intent(in) :: active_duration, event_duration
    type(irrigation_flux_result_t), intent(inout) :: fluxes

    fluxes%applied = .true.
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
    state%active_event_index = 0
    state%active_event_start = 0.0_real64
    state%active_event_end = 0.0_real64
  end subroutine clear_active_event

end module mod_irrigation_process
