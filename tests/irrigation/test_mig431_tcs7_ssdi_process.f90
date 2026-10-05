program test_mig431_tcs7_ssdi_process
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_irrigation_process, only: scheduled_irrigation_parameters_t, irrigation_state_t, &
       scheduled_irrigation_request_t, irrigation_flux_result_t, irrigation_diagnostics_t, &
       evaluate_scheduled_irrigation_interval, IRRIGATION_OK, IRRIGATION_SPLIT_REQUIRED, &
       IRRIGATION_EVENT_SCHEDULED, IRRIGATION_APPLICATION_SSDI
  implicit none

  type(scheduled_irrigation_parameters_t) :: parameters
  type(irrigation_state_t) :: committed, candidate, retry_candidate, final_state
  type(scheduled_irrigation_request_t) :: request
  type(irrigation_flux_result_t) :: fluxes, retry_fluxes, final_fluxes
  type(irrigation_diagnostics_t) :: diagnostics, retry_diagnostics, final_diagnostics
  type(process_hydraulic_view_t) :: hydraulic

  parameters%scheduled_irrigation_enabled = .true.
  parameters%active_nodes = 3
  parameters%sensor_node = 2
  parameters%single_ssdi_node = 2
  parameters%irr_rate_cm_per_day = 2.0_real64
  parameters%tcs7_knot_count = 2
  parameters%tcs7_dvs(1:2) = [0.0_real64, 1.0_real64]
  parameters%tcs7_pressure_head(1:2) = [-100.0_real64, -300.0_real64]
  parameters%dcs2_knot_count = 2
  parameters%dcs2_dvs(1:2) = [0.0_real64, 1.0_real64]
  parameters%dcs2_depth_cm(1:2) = [0.5_real64, 1.5_real64]

  hydraulic%active_nodes = 3
  allocate(hydraulic%pressure_head(3), hydraulic%water_content(3))
  hydraulic%pressure_head = [-50.0_real64, -200.0_real64, -400.0_real64]
  hydraulic%water_content = [0.30_real64, 0.25_real64, 0.20_real64]

  request%t0 = 10.0_real64
  request%t1 = 11.0_real64
  request%dvs = 0.5_real64
  request%selection_opportunity = .true.
  request%irrigation_enabled = .true.
  request%schedule_enabled = .true.
  request%crop_emerged = .true.
  request%irrigation_window_open = .true.

  call evaluate_scheduled_irrigation_interval(parameters, committed, request, hydraulic, &
                                               candidate, fluxes, diagnostics)
  call require(diagnostics%status == IRRIGATION_SPLIT_REQUIRED, 'source-derived event end requires split')
  call require(candidate%active_event .eqv. committed%active_event, 'split request leaves candidate at committed state')
  call require(abs(candidate%active_event_end - committed%active_event_end) < 1.0e-14_real64, &
       'split request does not publish event')
  call require(abs(diagnostics%interpolated_threshold - (-200.0_real64)) < 1.0e-14_real64, &
       'TCS7 threshold is independently interpolated')
  call require(abs(diagnostics%interpolated_depth - 1.0_real64) < 1.0e-14_real64, &
       'DCS2 depth is independently interpolated')
  call require(diagnostics%selection_evaluated .and. diagnostics%triggered, 'critical head triggers event selection')

  ! Retry the same source span after discarding the split candidate. This is the
  ! stateful reject/replay check at the process boundary.
  request%t1 = 10.25_real64
  call evaluate_scheduled_irrigation_interval(parameters, committed, request, hydraulic, &
                                               candidate, fluxes, diagnostics)
  call evaluate_scheduled_irrigation_interval(parameters, committed, request, hydraulic, &
                                               retry_candidate, retry_fluxes, retry_diagnostics)
  call require(diagnostics%status == IRRIGATION_OK .and. retry_diagnostics%status == IRRIGATION_OK, &
       'retry and replay succeed')
  call require(candidate%active_event .and. retry_candidate%active_event, 'accepted trial candidate holds active event')
  call require(abs(candidate%active_event_end - 10.5_real64) < 1.0e-14_real64, 'event ends at source-derived split')
  call require(fluxes%event_origin == IRRIGATION_EVENT_SCHEDULED, 'scheduled event identity')
  call require(fluxes%application_type == IRRIGATION_APPLICATION_SSDI, 'scheduled selector uses SSDI route')
  call require(size(fluxes%subsurface_source) == 3, 'SSDI source has active-node shape')
  call require(abs(fluxes%subsurface_source(2) - 2.0_real64) < 1.0e-14_real64 .and. &
       abs(sum(fluxes%subsurface_source) - 2.0_real64) < 1.0e-14_real64, &
       'SSDI source is applied at configured node')
  call require(abs(fluxes%external_inflow_amount - 0.5_real64) < 1.0e-14_real64, &
       'external inflow equals rate times accepted interval')
  call require(maxval(abs(fluxes%subsurface_source - retry_fluxes%subsurface_source)) < 1.0e-14_real64, &
       'replay source is deterministic')
  call require(abs(fluxes%external_inflow_amount - retry_fluxes%external_inflow_amount) < 1.0e-14_real64, &
       'replay mass is deterministic')

  ! Complete the event with the interval ending exactly at its boundary.
  request%t0 = 10.25_real64
  request%t1 = 10.5_real64
  call evaluate_scheduled_irrigation_interval(parameters, candidate, request, hydraulic, &
                                               final_state, final_fluxes, final_diagnostics)
  call require(final_diagnostics%status == IRRIGATION_OK, 'final event interval succeeds')
  call require(final_fluxes%event_finished .and. .not. final_state%active_event, 'event closes at exact end')
  call require(abs(fluxes%external_inflow_amount + final_fluxes%external_inflow_amount - 1.0_real64) < &
       1.0e-14_real64, 'integrated source mass equals prescribed DCS2 depth')

  ! At a wetter head the same TCS7 threshold must not create an event.
  hydraulic%pressure_head(2) = -199.0_real64
  committed = irrigation_state_t()
  request%t0 = 20.0_real64
  request%t1 = 20.25_real64
  call evaluate_scheduled_irrigation_interval(parameters, committed, request, hydraulic, &
                                               candidate, fluxes, diagnostics)
  call require(diagnostics%status == IRRIGATION_OK .and. .not. diagnostics%triggered, &
       'TCS7 does not trigger above critical pressure head')
  call require(.not. candidate%active_event .and. .not. fluxes%applied, 'nontrigger preserves state and flux')

  write(*,'(a)') 'F_MIG431_TCS7_SSDI_FORMULA=PASS'
  write(*,'(a)') 'F_MIG431_TCS7_SSDI_SPLIT_REPLAY=PASS'
  write(*,'(a)') 'F_MIG431_TCS7_SSDI_MASS_CLOSURE=PASS'

contains

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a)') 'FAIL: '//label
      error stop 1
    end if
  end subroutine require

end program test_mig431_tcs7_ssdi_process
