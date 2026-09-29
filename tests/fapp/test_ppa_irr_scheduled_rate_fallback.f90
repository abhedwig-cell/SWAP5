program test_ppa_irr_scheduled_rate_fallback
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_irrigation_process
  implicit none

  integer, parameter :: vector_count = 100000, active_nodes = 5
  type(scheduled_irrigation_parameters_t) :: parameters
  type(scheduled_irrigation_request_t) :: request
  type(irrigation_state_t) :: committed, candidate
  type(irrigation_flux_result_t) :: split_fluxes, first_fluxes, final_fluxes
  type(irrigation_diagnostics_t) :: split_diagnostics, first_diagnostics, final_diagnostics
  type(process_hydraulic_view_t) :: hydraulic_view
  real(real64) :: unit_value, depth, requested_rate, expected_rate, duration
  real(real64) :: start_time, first_duration, total_amount, tolerance
  integer(int64) :: random_state
  integer :: i, scenario, selected_node

  parameters%scheduled_irrigation_enabled = .true.
  parameters%timing_criterion = IRRIGATION_TIMING_TCS7_PRESSURE_HEAD
  parameters%active_nodes = active_nodes
  parameters%sensor_node = 2
  parameters%single_ssdi_node = 1
  parameters%tcs7_knot_count = 2
  parameters%tcs7_dvs(1:2) = [0.0_real64, 2.0_real64]
  parameters%tcs7_pressure_head(1:2) = [0.5_real64, 0.5_real64]
  parameters%dcs2_knot_count = 2
  parameters%dcs2_dvs(1:2) = [0.0_real64, 2.0_real64]
  hydraulic_view%active_nodes = active_nodes
  allocate(hydraulic_view%pressure_head(active_nodes), hydraulic_view%water_content(active_nodes))
  hydraulic_view%pressure_head = -1.0_real64
  hydraulic_view%water_content = 0.2_real64
  committed = irrigation_state_t()

  random_state = 20260923_int64
  do i = 1, vector_count
    call random_unit(random_state, unit_value)
    depth = 0.05_real64+0.40_real64*unit_value
    scenario = modulo(i-1, 4)
    select case (scenario)
    case (0)
      requested_rate = 0.0_real64
    case (1)
      requested_rate = 0.5_real64*depth
    case (2)
      requested_rate = 2.0_real64*depth
    case default
      requested_rate = depth
    end select
    if (requested_rate <= 0.0_real64 .or. depth > requested_rate) then
      expected_rate = depth
      duration = 1.0_real64
    else
      expected_rate = requested_rate
      duration = depth/expected_rate
    end if
    call random_unit(random_state, unit_value)
    start_time = 100.0_real64*unit_value
    selected_node = 1+modulo(i-1, active_nodes)
    parameters%irr_rate_cm_per_day = requested_rate
    parameters%single_ssdi_node = selected_node
    parameters%dcs2_depth_cm(1:2) = [depth, depth]

    ! An oversized solver proposal must request the normalized event boundary
    ! without publishing the candidate event or its normalized source rate.
    call make_request(start_time, start_time+duration+0.125_real64, request)
    call evaluate_scheduled_irrigation_interval(parameters, committed, request, hydraulic_view, &
                                                candidate, split_fluxes, split_diagnostics)
    if (split_diagnostics%status /= IRRIGATION_SPLIT_REQUIRED) then
      write(*, '(A,3(I0,1X),4(ES24.16,1X))') 'RATE_SPLIT_DIAGNOSTIC=', i, scenario, split_diagnostics%status, &
        parameters%dcs2_depth_cm(1), parameters%irr_rate_cm_per_day, request%t0, request%t1
    end if
    call require(split_diagnostics%status == IRRIGATION_SPLIT_REQUIRED, 1)
    call require(abs(split_diagnostics%split_time-(start_time+duration)) <= &
                 8.0_real64*epsilon(start_time)*max(1.0_real64,abs(start_time+duration)), 2)
    call require(.not. candidate%active_event .and. &
                 transfer(candidate%active_event_rate,0_int64) == transfer(0.0_real64,0_int64), 3)
    call require(.not. split_fluxes%applied, 4)

    first_duration = 0.375_real64*duration
    call make_request(start_time, start_time+first_duration, request)
    call evaluate_scheduled_irrigation_interval(parameters, committed, request, hydraulic_view, &
                                                candidate, first_fluxes, first_diagnostics)
    call require(first_diagnostics%status == IRRIGATION_OK .and. first_fluxes%event_started .and. &
                 first_fluxes%event_remains_active, 5)
    call require(candidate%active_event .and. candidate%active_event_origin == IRRIGATION_EVENT_SCHEDULED, 6)
    call require(transfer(candidate%active_event_rate,0_int64) == transfer(expected_rate,0_int64), 7)
    call check_source(first_fluxes, selected_node, expected_rate, 8)

    committed = candidate
    call make_request(start_time+first_duration, start_time+duration, request)
    call evaluate_scheduled_irrigation_interval(parameters, committed, request, hydraulic_view, &
                                                candidate, final_fluxes, final_diagnostics)
    if (final_diagnostics%status /= IRRIGATION_OK .or. .not. final_fluxes%event_finished .or. &
        candidate%active_event) then
      write(*, '(A,3(I0,1X),5(ES24.16,1X),2(L1,1X))') 'RATE_RETRY_DIAGNOSTIC=', i, scenario, &
        final_diagnostics%status, request%t0, request%t1, committed%active_event_start, &
        committed%active_event_end, committed%active_event_rate, final_fluxes%event_finished, candidate%active_event
    end if
    call require(final_diagnostics%status == IRRIGATION_OK .and. final_fluxes%event_finished .and. &
                 .not. candidate%active_event, 9)
    call check_source(final_fluxes, selected_node, expected_rate, 10)
    call require(transfer(candidate%active_event_rate,0_int64) == transfer(0.0_real64,0_int64), 11)
    total_amount = first_fluxes%external_inflow_amount+final_fluxes%external_inflow_amount
    tolerance = 32.0_real64*epsilon(depth)*max(1.0_real64,depth)
    call require(abs(total_amount-depth) <= tolerance, 12)
    committed = candidate
  end do

  print '(A)', 'PPA_IRR_SCHEDULED_RATE_ZERO_AND_OVER_ONE_DAY_FALLBACK_100000=PASS'
  print '(A)', 'PPA_IRR_SCHEDULED_RATE_EQUAL_AND_UNDER_ONE_DAY_PRESERVED=PASS'
  print '(A)', 'PPA_IRR_SCHEDULED_NORMALIZED_RATE_SPLIT_RETRY_PERSISTENCE=PASS'
  print '(A)', 'PPA_IRR_SCHEDULED_RATE_FALLBACK_AMOUNT_CONSERVATION=PASS'

contains

  subroutine make_request(t0, t1, result)
    real(real64), intent(in) :: t0, t1
    type(scheduled_irrigation_request_t), intent(out) :: result
    result = scheduled_irrigation_request_t()
    result%t0 = t0
    result%t1 = t1
    result%dvs = 0.5_real64
    result%selection_opportunity = .true.
    result%irrigation_enabled = .true.
    result%schedule_enabled = .true.
    result%crop_emerged = .true.
    result%irrigation_window_open = .true.
    result%fixed_event_already_selected = .false.
  end subroutine make_request

  subroutine check_source(source_fluxes, node_index, rate, code)
    type(irrigation_flux_result_t), intent(in) :: source_fluxes
    integer, intent(in) :: node_index, code
    real(real64), intent(in) :: rate
    integer :: j
    call require(allocated(source_fluxes%subsurface_source), code)
    do j = 1, active_nodes
      if (j == node_index) then
        call require(transfer(source_fluxes%subsurface_source(j),0_int64) == transfer(rate,0_int64), code+1)
      else
        call require(transfer(source_fluxes%subsurface_source(j),0_int64) == &
                     transfer(0.0_real64,0_int64), code+2)
      end if
    end do
  end subroutine check_source

  subroutine random_unit(state, value)
    integer(int64), intent(inout) :: state
    real(real64), intent(out) :: value
    state = modulo(state*48271_int64, 2147483647_int64)
    value = real(modulo(state, 1000001_int64), real64)/1000000.0_real64
  end subroutine random_unit

  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (.not. condition) then
      write(*, '(A,I0)') 'PPA_IRR_SCHEDULED_RATE_FALLBACK_FAILURE=', code
      error stop 1
    end if
  end subroutine require

end program test_ppa_irr_scheduled_rate_fallback
