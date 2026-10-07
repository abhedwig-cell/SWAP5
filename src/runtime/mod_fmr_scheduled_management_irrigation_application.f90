module mod_fmr_scheduled_management_irrigation_application
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_irrigation_root_zone_summary, only: irrigation_root_zone_parameters_t, irrigation_root_zone_summary_t, &
       evaluate_irrigation_root_zone_summary, IRR_ROOT_ZONE_OK
  use mod_scheduled_irrigation_management_policy, only: irrigation_management_policy_parameters_t, &
       irrigation_management_policy_state_t, irrigation_management_policy_request_t, &
       irrigation_management_policy_result_t, evaluate_irrigation_management_policy, IRR_MGMT_OK
  use mod_irrigation_process, only: irrigation_state_t, irrigation_flux_result_t, &
       IRRIGATION_APPLICATION_SPRINKLER, IRRIGATION_APPLICATION_SURFACE, IRRIGATION_APPLICATION_SSDI, &
       IRRIGATION_EVENT_SCHEDULED
  implicit none
  private

  integer, parameter, public :: FMR_IRR_MGMT_APP_OK = 0
  integer, parameter, public :: FMR_IRR_MGMT_APP_INVALID_INTERVAL = 1
  integer, parameter, public :: FMR_IRR_MGMT_APP_INVALID_PARAMETERS = 2
  integer, parameter, public :: FMR_IRR_MGMT_APP_ROOT_ZONE_REJECTED = 3
  integer, parameter, public :: FMR_IRR_MGMT_APP_POLICY_REJECTED = 4
  integer, parameter, public :: FMR_IRR_MGMT_APP_INVALID_STATE = 5
  integer, parameter, public :: FMR_IRR_MGMT_APP_SPLIT_REQUIRED = 6

  real(real64), parameter :: TIME_EPSILON_SCALE = 64.0_real64

  type, public :: fmr_irrigation_management_parameters_t
    type(irrigation_root_zone_parameters_t) :: root_zone
    type(irrigation_management_policy_parameters_t) :: policy
    integer :: application_type = IRRIGATION_APPLICATION_SPRINKLER
    integer :: active_nodes = 0
    integer :: single_ssdi_node = 0
    real(real64) :: rate_cm_per_day = 0.0_real64
  end type fmr_irrigation_management_parameters_t

  type, public :: fmr_irrigation_management_state_t
    type(irrigation_state_t) :: event
    type(irrigation_management_policy_state_t) :: policy
  end type fmr_irrigation_management_state_t

  type, public :: fmr_irrigation_management_request_t
    real(real64) :: t0 = 0.0_real64
    real(real64) :: t1 = 0.0_real64
    real(real64) :: dvs = 0.0_real64
    real(real64) :: rainfall_cm = 0.0_real64
    logical :: selection_opportunity = .false.
    logical :: irrigation_enabled = .false.
    logical :: schedule_enabled = .false.
    logical :: crop_emerged = .false.
    logical :: irrigation_window_open = .false.
    logical :: fixed_event_already_selected = .false.
  end type fmr_irrigation_management_request_t

  type, public :: fmr_irrigation_management_diagnostics_t
    integer :: status = FMR_IRR_MGMT_APP_OK
    integer :: root_zone_status = IRR_ROOT_ZONE_OK
    integer :: policy_status = IRR_MGMT_OK
    logical :: selection_evaluated = .false.
    logical :: split_required = .false.
    real(real64) :: split_time = 0.0_real64
    real(real64) :: selected_depth_cm = 0.0_real64
    real(real64) :: effective_rate_cm_per_day = 0.0_real64
  end type fmr_irrigation_management_diagnostics_t

  public :: fmr_evaluate_scheduled_management_irrigation

contains

  subroutine fmr_evaluate_scheduled_management_irrigation(parameters, committed_state, request, hydraulic_view, &
                                                            candidate_state, flux, policy_result, root_summary, diagnostics)
    type(fmr_irrigation_management_parameters_t), intent(in) :: parameters
    type(fmr_irrigation_management_state_t), intent(in) :: committed_state
    type(fmr_irrigation_management_request_t), intent(in) :: request
    type(process_hydraulic_view_t), intent(in) :: hydraulic_view
    type(fmr_irrigation_management_state_t), intent(out) :: candidate_state
    type(irrigation_flux_result_t), intent(out) :: flux
    type(irrigation_management_policy_result_t), intent(out) :: policy_result
    type(irrigation_root_zone_summary_t), intent(out) :: root_summary
    type(fmr_irrigation_management_diagnostics_t), intent(out) :: diagnostics
    type(irrigation_management_policy_request_t) :: policy_request
    real(real64) :: duration, event_end, effective_t1, effective_rate
    logical :: ok, finishes

    candidate_state = committed_state
    flux = irrigation_flux_result_t()
    policy_result = irrigation_management_policy_result_t()
    root_summary = irrigation_root_zone_summary_t()
    diagnostics = fmr_irrigation_management_diagnostics_t()

    if (.not. ieee_is_finite(request%t0) .or. .not. ieee_is_finite(request%t1) .or. request%t1 <= request%t0) then
      diagnostics%status = FMR_IRR_MGMT_APP_INVALID_INTERVAL
      return
    end if
    if (.not. valid_parameters(parameters)) then
      diagnostics%status = FMR_IRR_MGMT_APP_INVALID_PARAMETERS
      return
    end if

    if (committed_state%event%active_event) then
      if (committed_state%event%active_event_origin /= IRRIGATION_EVENT_SCHEDULED .or. &
          committed_state%event%active_event_rate_cm_per_day <= 0.0_real64) then
        diagnostics%status = FMR_IRR_MGMT_APP_INVALID_STATE
        return
      end if
      event_end = committed_state%event%active_event_end
      if ((request%t0 < committed_state%event%active_event_start .and. &
           .not. same_time(request%t0, committed_state%event%active_event_start)) .or. &
          (request%t0 > event_end .and. .not. same_time(request%t0,event_end))) then
        diagnostics%status = FMR_IRR_MGMT_APP_INVALID_STATE
        return
      end if
      if (same_time(request%t0,event_end)) then
        call clear_event(candidate_state%event)
        return
      end if
      finishes = same_time(request%t1,event_end)
      if (request%t1 > event_end .and. .not. finishes) then
        candidate_state = committed_state
        diagnostics%status = FMR_IRR_MGMT_APP_SPLIT_REQUIRED
        diagnostics%split_required = .true.
        diagnostics%split_time = event_end
        return
      end if
      duration = committed_state%event%active_event_end - committed_state%event%active_event_start
      effective_t1 = request%t1
      if (finishes) effective_t1 = event_end
      call apply_flux(parameters, committed_state%event%active_event_rate_cm_per_day, &
                      effective_t1-request%t0, duration, flux, ok)
      if (.not. ok) then
        candidate_state = committed_state
        diagnostics%status = FMR_IRR_MGMT_APP_INVALID_PARAMETERS
        return
      end if
      diagnostics%effective_rate_cm_per_day = committed_state%event%active_event_rate_cm_per_day
      flux%event_remains_active = .not. finishes
      if (finishes) then
        flux%event_finished = .true.
        call clear_event(candidate_state%event)
      end if
      return
    end if

    if (.not. request%selection_opportunity .or. .not. request%irrigation_enabled .or. &
        .not. request%schedule_enabled .or. .not. request%crop_emerged .or. &
        .not. request%irrigation_window_open .or. request%fixed_event_already_selected) return
    diagnostics%selection_evaluated = .true.

    call evaluate_irrigation_root_zone_summary(parameters%root_zone, hydraulic_view, root_summary, diagnostics%root_zone_status)
    if (diagnostics%root_zone_status /= IRR_ROOT_ZONE_OK) then
      diagnostics%status = FMR_IRR_MGMT_APP_ROOT_ZONE_REJECTED
      return
    end if

    policy_request = irrigation_management_policy_request_t()
    policy_request%dvs = request%dvs
    policy_request%total_available_water_cm = root_summary%total_available_water_cm
    policy_request%stress_to_wilting_available_cm = root_summary%stress_to_wilting_available_cm
    policy_request%actual_available_water_cm = root_summary%actual_available_water_cm
    policy_request%field_capacity_deficit_cm = root_summary%field_capacity_deficit_cm
    policy_request%rainfall_cm = request%rainfall_cm
    call evaluate_irrigation_management_policy(parameters%policy, committed_state%policy, policy_request, &
                                                candidate_state%policy, policy_result, diagnostics%policy_status)
    if (diagnostics%policy_status /= IRR_MGMT_OK) then
      candidate_state = committed_state
      diagnostics%status = FMR_IRR_MGMT_APP_POLICY_REJECTED
      return
    end if
    if (.not. policy_result%trigger) return

    diagnostics%selected_depth_cm = policy_result%selected_depth_cm
    call normalize_rate(policy_result%selected_depth_cm, parameters%rate_cm_per_day, effective_rate, duration, ok)
    if (.not. ok) then
      candidate_state = committed_state
      diagnostics%status = FMR_IRR_MGMT_APP_INVALID_PARAMETERS
      return
    end if
    diagnostics%effective_rate_cm_per_day = effective_rate
    event_end = request%t0 + duration
    finishes = same_time(request%t1,event_end)
    if (request%t1 > event_end .and. .not. finishes) then
      candidate_state = committed_state
      diagnostics%status = FMR_IRR_MGMT_APP_SPLIT_REQUIRED
      diagnostics%split_required = .true.
      diagnostics%split_time = event_end
      return
    end if

    candidate_state%event%active_event = .true.
    candidate_state%event%active_event_origin = IRRIGATION_EVENT_SCHEDULED
    candidate_state%event%active_event_index = 0
    candidate_state%event%active_event_start = request%t0
    candidate_state%event%active_event_end = event_end
    candidate_state%event%active_event_rate_cm_per_day = effective_rate

    effective_t1 = request%t1
    if (finishes) effective_t1 = event_end
    call apply_flux(parameters, effective_rate, effective_t1-request%t0, duration, flux, ok)
    if (.not. ok) then
      candidate_state = committed_state
      flux = irrigation_flux_result_t()
      diagnostics%status = FMR_IRR_MGMT_APP_INVALID_PARAMETERS
      return
    end if
    flux%event_started = .true.
    flux%event_remains_active = .not. finishes
    if (finishes) then
      flux%event_finished = .true.
      call clear_event(candidate_state%event)
    end if
  end subroutine fmr_evaluate_scheduled_management_irrigation

  pure logical function valid_parameters(parameters)
    type(fmr_irrigation_management_parameters_t), intent(in) :: parameters
    valid_parameters = .false.
    if (parameters%active_nodes <= 0 .or. parameters%root_zone%active_nodes /= parameters%active_nodes) return
    if (.not. ieee_is_finite(parameters%rate_cm_per_day) .or. parameters%rate_cm_per_day < 0.0_real64) return
    select case(parameters%application_type)
    case(IRRIGATION_APPLICATION_SPRINKLER,IRRIGATION_APPLICATION_SURFACE)
    case(IRRIGATION_APPLICATION_SSDI)
      if (parameters%single_ssdi_node < 1 .or. parameters%single_ssdi_node > parameters%active_nodes) return
    case default
      return
    end select
    valid_parameters = .true.
  end function valid_parameters

  pure subroutine normalize_rate(depth, configured_rate, effective_rate, duration, ok)
    real(real64), intent(in) :: depth, configured_rate
    real(real64), intent(out) :: effective_rate, duration
    logical, intent(out) :: ok
    effective_rate = 0.0_real64
    duration = 0.0_real64
    ok = .false.
    if (.not. ieee_is_finite(depth) .or. depth <= 0.0_real64) return
    if (.not. ieee_is_finite(configured_rate) .or. configured_rate < 0.0_real64) return
    if (configured_rate <= epsilon(1.0_real64)) then
      effective_rate = depth
      duration = 1.0_real64
    else
      effective_rate = configured_rate
      duration = depth/effective_rate
      if (.not. ieee_is_finite(duration) .or. duration <= 0.0_real64) return
      if (duration > 1.0_real64) then
        effective_rate = depth
        duration = 1.0_real64
      end if
    end if
    ok = ieee_is_finite(effective_rate) .and. effective_rate > 0.0_real64 .and. &
         ieee_is_finite(duration) .and. duration > 0.0_real64 .and. duration <= 1.0_real64
  end subroutine normalize_rate

  pure subroutine apply_flux(parameters, rate, active_duration, event_duration, flux, ok)
    type(fmr_irrigation_management_parameters_t), intent(in) :: parameters
    real(real64), intent(in) :: rate, active_duration, event_duration
    type(irrigation_flux_result_t), intent(out) :: flux
    logical, intent(out) :: ok
    flux = irrigation_flux_result_t()
    ok = .false.
    if (.not. ieee_is_finite(rate) .or. rate <= 0.0_real64 .or. active_duration < 0.0_real64) return
    flux%applied = .true.
    flux%event_origin = IRRIGATION_EVENT_SCHEDULED
    flux%application_type = parameters%application_type
    flux%event_duration = event_duration
    flux%active_duration = active_duration
    select case(parameters%application_type)
    case(IRRIGATION_APPLICATION_SPRINKLER,IRRIGATION_APPLICATION_SURFACE)
      flux%surface_gross_rate = rate
    case(IRRIGATION_APPLICATION_SSDI)
      allocate(flux%subsurface_source(parameters%active_nodes))
      flux%subsurface_source = 0.0_real64
      flux%subsurface_source(parameters%single_ssdi_node) = rate
    case default
      return
    end select
    flux%external_inflow_amount = rate*active_duration
    ok = ieee_is_finite(flux%external_inflow_amount) .and. flux%external_inflow_amount >= 0.0_real64
  end subroutine apply_flux

  pure logical function same_time(a,b)
    real(real64), intent(in) :: a,b
    real(real64) :: tolerance
    tolerance = TIME_EPSILON_SCALE*epsilon(1.0_real64)*max(1.0_real64,abs(a),abs(b))
    same_time = abs(a-b) <= tolerance
  end function same_time

  pure subroutine clear_event(state)
    type(irrigation_state_t), intent(inout) :: state
    state%active_event = .false.
    state%active_event_origin = 0
    state%active_event_index = 0
    state%active_event_start = 0.0_real64
    state%active_event_end = 0.0_real64
    state%active_event_rate_cm_per_day = 0.0_real64
  end subroutine clear_event
end module mod_fmr_scheduled_management_irrigation_application
