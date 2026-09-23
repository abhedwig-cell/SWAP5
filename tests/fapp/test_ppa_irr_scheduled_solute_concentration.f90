program test_ppa_irr_scheduled_solute_concentration
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_irrigation_process
  implicit none

  integer, parameter :: vector_count = 100000, active_nodes = 7
  type(scheduled_irrigation_parameters_t) :: parameters
  type(scheduled_irrigation_request_t) :: request
  type(irrigation_state_t) :: committed, candidate
  type(irrigation_flux_result_t) :: fluxes
  type(irrigation_diagnostics_t) :: diagnostics
  type(process_hydraulic_view_t) :: hydraulic_view
  real(real64) :: unit_value, concentration, depth, rate, duration, tolerance
  integer(int64) :: random_state
  integer :: i, node, selected_node

  parameters%scheduled_irrigation_enabled = .true.
  parameters%timing_criterion = IRRIGATION_TIMING_TCS7_PRESSURE_HEAD
  parameters%active_nodes = active_nodes
  parameters%sensor_node = 3
  parameters%tcs7_knot_count = 2
  parameters%tcs7_dvs(1:2) = [0.0_real64, 2.0_real64]
  parameters%tcs7_pressure_head(1:2) = [0.5_real64, 0.5_real64]
  parameters%dcs2_knot_count = 2
  parameters%dcs2_dvs(1:2) = [0.0_real64, 2.0_real64]
  parameters%irr_rate_cm_per_day = 1.0_real64
  parameters%irr_rate_cm_per_day = 1.0_real64
  hydraulic_view%active_nodes = active_nodes
  allocate(hydraulic_view%pressure_head(active_nodes), hydraulic_view%water_content(active_nodes))
  hydraulic_view%pressure_head = -1.0_real64
  hydraulic_view%water_content = 0.2_real64
  committed = irrigation_state_t()

  ! The default retains the previous zero-concentration behavior.
  parameters%single_ssdi_node = 1
  parameters%dcs2_depth_cm(1:2) = [0.25_real64, 0.25_real64]
  call make_request(0.25_real64, request)
  call evaluate_scheduled_irrigation_interval(parameters, committed, request, hydraulic_view, &
                                              candidate, fluxes, diagnostics)
  call require(diagnostics%status == IRRIGATION_OK .and. fluxes%applied, 1)
  call require(transfer(fluxes%concentration, 0_int64) == transfer(0.0_real64, 0_int64), 2)

  random_state = 20260923_int64
  do i = 1, vector_count
    call random_unit(random_state, unit_value)
    concentration = 100.0_real64*unit_value
    call random_unit(random_state, unit_value)
    depth = 0.001_real64+0.499_real64*unit_value
    call random_unit(random_state, unit_value)
    rate = 0.75_real64+0.75_real64*unit_value
    duration = depth/rate
    selected_node = 1+modulo(i-1, active_nodes)

    parameters%concentration = concentration
    parameters%irr_rate_cm_per_day = rate
    parameters%single_ssdi_node = selected_node
    parameters%dcs2_depth_cm(1:2) = [depth, depth]
    call make_request(duration, request)
    call evaluate_scheduled_irrigation_interval(parameters, committed, request, hydraulic_view, &
                                                candidate, fluxes, diagnostics)
    call require(diagnostics%status == IRRIGATION_OK .and. diagnostics%triggered .and. fluxes%applied, 3)
    call require(transfer(fluxes%concentration, 0_int64) == transfer(concentration, 0_int64), 4)
    call require(fluxes%application_type == IRRIGATION_APPLICATION_SSDI, 5)
    call require(size(fluxes%subsurface_source) == active_nodes, 6)
    do node = 1, active_nodes
      if (node == selected_node) then
        call require(transfer(fluxes%subsurface_source(node), 0_int64) == transfer(rate, 0_int64), 7)
      else
        call require(transfer(fluxes%subsurface_source(node), 0_int64) == transfer(0.0_real64, 0_int64), 8)
      end if
    end do
    tolerance = 16.0_real64*epsilon(depth)*max(1.0_real64, depth)
    call require(abs(fluxes%external_inflow_amount-depth) <= tolerance, 9)
    call require(.not. candidate%active_event .and. fluxes%event_finished, 10)
  end do

  parameters%concentration = -epsilon(1.0_real64)
  call evaluate_scheduled_irrigation_interval(parameters, committed, request, hydraulic_view, &
                                              candidate, fluxes, diagnostics)
  call require(diagnostics%status == IRRIGATION_INVALID_PARAMETERS .and. .not. fluxes%applied, 11)
  parameters%concentration = 100.000001_real64
  call evaluate_scheduled_irrigation_interval(parameters, committed, request, hydraulic_view, &
                                              candidate, fluxes, diagnostics)
  call require(diagnostics%status == IRRIGATION_INVALID_PARAMETERS .and. .not. fluxes%applied, 12)
  parameters%concentration = ieee_value(0.0_real64, ieee_quiet_nan)
  call evaluate_scheduled_irrigation_interval(parameters, committed, request, hydraulic_view, &
                                              candidate, fluxes, diagnostics)
  call require(diagnostics%status == IRRIGATION_INVALID_PARAMETERS .and. .not. fluxes%applied, 13)

  print '(A)', 'PPA_IRR_SCHEDULED_SOLUTE_CARRIER_100000=PASS'
  print '(A)', 'PPA_IRR_SCHEDULED_CONCENTRATION_BOUNDS=PASS'
  print '(A)', 'PPA_IRR_SCHEDULED_WATER_SOURCE_UNCHANGED=PASS'
  print '(A)', 'PPA_IRR_SCHEDULED_SOLUTE_CONCENTRATION_SOURCE_ORACLE=PASS'

contains

  subroutine make_request(event_duration, result)
    real(real64), intent(in) :: event_duration
    type(scheduled_irrigation_request_t), intent(out) :: result
    result = scheduled_irrigation_request_t()
    result%t0 = 0.0_real64
    result%t1 = event_duration
    result%dvs = 0.5_real64
    result%selection_opportunity = .true.
    result%irrigation_enabled = .true.
    result%schedule_enabled = .true.
    result%crop_emerged = .true.
    result%irrigation_window_open = .true.
    result%fixed_event_already_selected = .false.
  end subroutine make_request

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
      write(*, '(A,I0)') 'PPA_IRR_SCHEDULED_SOLUTE_CONCENTRATION_FAILURE=', code
      error stop 1
    end if
  end subroutine require

end program test_ppa_irr_scheduled_solute_concentration
