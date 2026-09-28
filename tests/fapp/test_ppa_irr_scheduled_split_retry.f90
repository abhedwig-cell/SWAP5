program test_ppa_irr_scheduled_split_retry
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_irrigation_process
  implicit none

  integer, parameter :: vector_count = 100000
  type(scheduled_irrigation_parameters_t) :: parameters
  type(scheduled_irrigation_request_t) :: request
  type(irrigation_state_t) :: committed, split_candidate, retry_candidate, direct_candidate
  type(irrigation_flux_result_t) :: split_fluxes, retry_fluxes, direct_fluxes
  type(irrigation_diagnostics_t) :: split_diagnostics, retry_diagnostics, direct_diagnostics
  type(process_hydraulic_view_t) :: hydraulic_view
  real(real64) :: rate, depth, start_time, unit_value, event_end
  integer(int64) :: random_state
  integer :: i

  parameters%scheduled_irrigation_enabled = .true.
  parameters%timing_criterion = IRRIGATION_TIMING_TCS7_PRESSURE_HEAD
  parameters%active_nodes = 1
  parameters%sensor_node = 1
  parameters%single_ssdi_node = 1
  parameters%tcs7_knot_count = 2
  parameters%tcs7_dvs(1:2) = [0.0_real64, 2.0_real64]
  parameters%tcs7_pressure_head(1:2) = [0.5_real64, 0.5_real64]
  parameters%dcs2_knot_count = 2
  parameters%dcs2_dvs(1:2) = [0.0_real64, 2.0_real64]
  hydraulic_view%active_nodes = 1
  allocate(hydraulic_view%pressure_head(1), hydraulic_view%water_content(1))
  hydraulic_view%pressure_head = -1.0_real64
  hydraulic_view%water_content = 0.2_real64
  committed = irrigation_state_t()

  random_state = 20260923_int64
  do i = 1, vector_count
    call random_unit(random_state, unit_value)
    start_time = 4000.0_real64*unit_value
    call random_unit(random_state, unit_value)
    depth = 0.001_real64+0.5_real64*unit_value
    parameters%irr_rate_cm_per_day = 0.75_real64+0.75_real64*unit_value
    parameters%dcs2_depth_cm(1:2) = [depth, depth]
    rate = parameters%irr_rate_cm_per_day
    request%t0 = start_time
    request%t1 = start_time+depth/rate+0.025_real64
    request%dvs = 0.9_real64
    request%selection_opportunity = .true.
    request%irrigation_enabled = .true.
    request%schedule_enabled = .true.
    request%crop_emerged = .true.
    request%irrigation_window_open = .true.
    request%fixed_event_already_selected = .false.
    event_end = start_time+depth/rate

    call evaluate_scheduled_irrigation_interval(parameters, committed, request, hydraulic_view, &
                                                split_candidate, split_fluxes, split_diagnostics)
    call require(split_diagnostics%status == IRRIGATION_SPLIT_REQUIRED, 1)
    call require(split_diagnostics%selection_evaluated .and. split_diagnostics%triggered, 2)
    call require(split_diagnostics%split_required .and. same_bits(split_diagnostics%split_time, event_end), 3)
    call require(split_candidate%next_fixed_event_index == committed%next_fixed_event_index .and. &
                 .not. split_candidate%active_event, 4)
    call require(.not. split_fluxes%applied .and. abs(split_fluxes%external_inflow_amount) <= 0.0_real64, 5)

    request%t1 = event_end
    call evaluate_scheduled_irrigation_interval(parameters, committed, request, hydraulic_view, &
                                                retry_candidate, retry_fluxes, retry_diagnostics)
    call require(retry_diagnostics%status == IRRIGATION_OK .and. retry_fluxes%event_started .and. &
                 retry_fluxes%event_finished .and. .not. retry_candidate%active_event, 6)
    call evaluate_scheduled_irrigation_interval(parameters, committed, request, hydraulic_view, &
                                                direct_candidate, direct_fluxes, direct_diagnostics)
    call require(direct_diagnostics%status == IRRIGATION_OK, 7)
    call require(retry_candidate%next_fixed_event_index == direct_candidate%next_fixed_event_index, 8)
    call require(same_bits(retry_fluxes%event_duration, direct_fluxes%event_duration), 9)
    call require(same_bits(retry_fluxes%active_duration, direct_fluxes%active_duration), 10)
    call require(same_bits(retry_fluxes%external_inflow_amount, direct_fluxes%external_inflow_amount), 11)
    call require(size(retry_fluxes%subsurface_source) == size(direct_fluxes%subsurface_source), 12)
    call require(same_bits(retry_fluxes%subsurface_source(1), direct_fluxes%subsurface_source(1)), 13)
  end do

  print '(A)', 'PPA_IRR_SCHEDULED_OVERSIZED_INTERVAL_SPLIT_100000=PASS'
  print '(A)', 'PPA_IRR_SCHEDULED_TCS7_DCS2_RETRY_EQUALS_DIRECT=PASS'
  print '(A)', 'PPA_IRR_SCHEDULED_SPLIT_PRESERVES_CANDIDATE_ON_REQUEST=PASS'
  print '(A)', 'PPA_IRR_SCHEDULED_SPLIT_RETRY=PASS'

contains

  subroutine random_unit(state, value)
    integer(int64), intent(inout) :: state
    real(real64), intent(out) :: value
    state = modulo(state*48271_int64, 2147483647_int64)
    value = real(modulo(state, 1000001_int64), real64)/1000000.0_real64
  end subroutine random_unit

  logical function same_bits(left, right)
    real(real64), intent(in) :: left, right
    same_bits = transfer(left, 0_int64) == transfer(right, 0_int64)
  end function same_bits

  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (.not. condition) then
      write(*, '(A,I0)') 'PPA_IRR_SCHEDULED_SPLIT_FAILURE=', code
      error stop 1
    end if
  end subroutine require

end program test_ppa_irr_scheduled_split_retry
