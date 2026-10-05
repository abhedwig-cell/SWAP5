program test_mig431_tcs7_ssdi_process
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_irrigation_process, only: scheduled_irrigation_parameters_t, irrigation_parameters_t, &
       fixed_irrigation_event_t, irrigation_management_request_t, irrigation_state_t, &
       scheduled_irrigation_request_t, irrigation_flux_result_t, irrigation_diagnostics_t, &
       evaluate_scheduled_irrigation_interval, evaluate_fixed_irrigation_interval, &
       IRRIGATION_OK, IRRIGATION_SPLIT_REQUIRED, IRRIGATION_INVALID_EVENT, &
       IRRIGATION_EVENT_SCHEDULED, IRRIGATION_APPLICATION_SSDI, IRRIGATION_APPLICATION_SPRINKLER, &
       IRRIGATION_APPLICATION_SURFACE
  use mod_fmr_irrigation_restart, only: irrigation_restart_record_t, export_irrigation_restart, &
       restore_irrigation_restart, IRRIGATION_RESTART_OK, IRRIGATION_RESTART_INVALID
  use mod_fmr_irrigation_source_binding, only: fmr_irrigation_source_diagnostics_t, &
       fmr_bind_irrigation_to_subsurface_source, FMR_IRR_SOURCE_OK, FMR_IRR_SOURCE_INVALID_SHAPE
  implicit none

  type(scheduled_irrigation_parameters_t) :: parameters
  type(irrigation_state_t) :: committed, candidate, retry_candidate, final_state
  type(irrigation_parameters_t) :: fixed_parameters
  type(irrigation_management_request_t) :: fixed_request
  type(scheduled_irrigation_request_t) :: request
  type(irrigation_flux_result_t) :: fluxes, retry_fluxes, final_fluxes
  type(irrigation_diagnostics_t) :: diagnostics, retry_diagnostics, final_diagnostics
  type(irrigation_diagnostics_t) :: fixed_diagnostics
  type(process_hydraulic_view_t) :: hydraulic
  type(irrigation_restart_record_t) :: restart_record, invalid_restart_record
  type(irrigation_state_t) :: restored_state
  integer :: restart_status
  integer :: weekly_day
  type(irrigation_state_t) :: fixed_state, fixed_candidate
  type(irrigation_flux_result_t) :: fixed_flux
  type(fmr_irrigation_source_diagnostics_t) :: source_diagnostics
  real(real64), allocatable :: bound_source(:)
  real(real64) :: existing_source(3)

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
  existing_source = [0.1_real64, 0.0_real64, 0.05_real64]
  call fmr_bind_irrigation_to_subsurface_source(existing_source, fluxes, diagnostics, &
                                                bound_source, source_diagnostics)
  call require(source_diagnostics%status == FMR_IRR_SOURCE_OK .and. source_diagnostics%source_added, &
       'accepted SSDI irrigation binds to runtime subsurface source')
  call require(maxval(abs(bound_source - [0.1_real64, 2.0_real64, 0.05_real64])) < 1.0e-14_real64, &
       'runtime binding preserves existing source and adds irrigation at selected node')
  call require(abs(sum(bound_source-existing_source) - 2.0_real64) < 1.0e-14_real64, &
       'runtime source bridge closes irrigation rate')
  call fmr_bind_irrigation_to_subsurface_source(existing_source(1:2), fluxes, diagnostics, &
                                                bound_source, source_diagnostics)
  call require(source_diagnostics%status == FMR_IRR_SOURCE_INVALID_SHAPE .and. .not. allocated(bound_source), &
       'runtime binding rejects node-shape mismatch without publication')

  ! A committed partial event survives serialization and resumes with the same
  ! remaining event span and source amount.
  call export_irrigation_restart(candidate, restart_record, restart_status)
  call require(restart_status == IRRIGATION_RESTART_OK, 'active irrigation event exports to restart')
  call restore_irrigation_restart(restart_record, restored_state, restart_status)
  call require(restart_status == IRRIGATION_RESTART_OK, 'active irrigation event restores from restart')
  call require(restored_state%active_event .and. restored_state%active_event_origin == IRRIGATION_EVENT_SCHEDULED, &
       'restart preserves scheduled event identity')

  ! Complete the event with the interval ending exactly at its boundary.
  request%t0 = 10.25_real64
  request%t1 = 10.5_real64
  call evaluate_scheduled_irrigation_interval(parameters, restored_state, request, hydraulic, &
                                               final_state, final_fluxes, final_diagnostics)
  call require(final_diagnostics%status == IRRIGATION_OK, 'final event interval succeeds')
  call require(final_fluxes%event_finished .and. .not. final_state%active_event, 'event closes at exact end')
  call require(abs(fluxes%external_inflow_amount + final_fluxes%external_inflow_amount - 1.0_real64) < &
       1.0e-14_real64, 'integrated source mass equals prescribed DCS2 depth')
  call require(abs(final_fluxes%external_inflow_amount - 0.5_real64) < 1.0e-14_real64, &
       'restart continuation reproduces remaining SSDI source mass')

  invalid_restart_record = restart_record
  invalid_restart_record%schema = 999
  call restore_irrigation_restart(invalid_restart_record, restored_state, restart_status)
  call require(restart_status == IRRIGATION_RESTART_INVALID .and. .not. restored_state%active_event, &
       'unsupported restart schema fails closed')

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

  ! TCS8 uses the same crop-stage AFGEN timing but compares theta at the
  ! configured sensor node with the source-defined <= threshold direction.
  parameters%timing_criterion = 8
  parameters%tcs8_knot_count = 2
  parameters%tcs8_dvs(1:2) = [0.0_real64, 1.0_real64]
  parameters%tcs8_water_content(1:2) = [0.2_real64, 0.4_real64]
  hydraulic%water_content(2) = 0.25_real64
  committed = irrigation_state_t()
  request%t0 = 30.0_real64
  request%t1 = 30.25_real64
  call evaluate_scheduled_irrigation_interval(parameters, committed, request, hydraulic, &
                                               candidate, fluxes, diagnostics)
  call require(diagnostics%status == IRRIGATION_OK .and. diagnostics%triggered, &
       'TCS8 triggers at or below independently interpolated critical theta')
  call require(abs(diagnostics%interpolated_threshold - 0.3_real64) < 1.0e-14_real64, &
       'TCS8 threshold is independently interpolated')
  hydraulic%water_content(2) = 0.31_real64
  call evaluate_scheduled_irrigation_interval(parameters, committed, request, hydraulic, &
                                               candidate, fluxes, diagnostics)
  call require(diagnostics%status == IRRIGATION_OK .and. .not. diagnostics%triggered, &
       'TCS8 does not trigger above critical theta')

  allocate(parameters%root_zone_thickness_cm(3), parameters%theta_wilting(3), &
           parameters%theta_middle(3), parameters%theta_field_capacity(3))
  parameters%root_zone_thickness_cm = 10.0_real64
  parameters%theta_wilting = 0.1_real64
  parameters%theta_middle = 0.3_real64
  parameters%theta_field_capacity = 0.4_real64
  hydraulic%water_content = [0.25_real64, 0.2_real64, 0.15_real64]
  parameters%tcs2_knot_count = 2
  parameters%tcs2_dvs(1:2) = [0.0_real64, 1.0_real64]
  parameters%tcs2_raw_fraction(1:2) = 0.5_real64
  parameters%timing_criterion = 2
  call evaluate_scheduled_irrigation_interval(parameters, committed, request, hydraulic, &
                                               candidate, fluxes, diagnostics)
  call require(diagnostics%status == IRRIGATION_OK .and. diagnostics%triggered, &
       'TCS2 uses root-zone readily-available depletion formula')

  parameters%tcs3_knot_count = 2
  parameters%tcs3_dvs(1:2) = [0.0_real64, 1.0_real64]
  parameters%tcs3_taw_fraction(1:2) = 0.5_real64
  parameters%timing_criterion = 3
  call evaluate_scheduled_irrigation_interval(parameters, committed, request, hydraulic, &
                                               candidate, fluxes, diagnostics)
  call require(diagnostics%status == IRRIGATION_OK .and. diagnostics%triggered, &
       'TCS3 uses root-zone total-available depletion formula')

  parameters%tcs4_knot_count = 2
  parameters%tcs4_dvs(1:2) = [0.0_real64, 1.0_real64]
  parameters%tcs4_depletion_mm(1:2) = 40.0_real64
  parameters%timing_criterion = 4
  call evaluate_scheduled_irrigation_interval(parameters, committed, request, hydraulic, &
                                               candidate, fluxes, diagnostics)
  call require(diagnostics%status == IRRIGATION_OK .and. diagnostics%triggered, &
       'TCS4 uses millimetre depletion threshold converted to centimetres')
  parameters%tcs4_depletion_mm(1:2) = 70.0_real64
  call evaluate_scheduled_irrigation_interval(parameters, committed, request, hydraulic, &
                                               candidate, fluxes, diagnostics)
  call require(diagnostics%status == IRRIGATION_OK .and. .not. diagnostics%triggered, &
       'TCS4 remains inactive below its crop-stage depletion threshold')

  ! TCS6 advances a transactional weekly counter, persists it, and only
  ! evaluates its mm deficit threshold on the seventh eligible day.
  parameters%timing_criterion = 6
  parameters%tcs6_weekly_deficit_threshold_mm = 50.0_real64
  committed = irrigation_state_t()
  do weekly_day = 1, 5
    request%t0 = 40.0_real64 + real(weekly_day,real64)
    request%t1 = request%t0 + 0.1_real64
    call evaluate_scheduled_irrigation_interval(parameters, committed, request, hydraulic, &
                                                 candidate, fluxes, diagnostics)
    call require(diagnostics%status == IRRIGATION_OK .and. .not. diagnostics%triggered .and. &
         candidate%tcs6_weekly_day_counter == weekly_day, 'TCS6 accumulates eligible daily counter')
    committed = candidate
  end do
  call export_irrigation_restart(committed, restart_record, restart_status)
  call require(restart_status == IRRIGATION_RESTART_OK, 'TCS6 counter exports to restart')
  call restore_irrigation_restart(restart_record, restored_state, restart_status)
  call require(restart_status == IRRIGATION_RESTART_OK .and. &
       restored_state%tcs6_weekly_day_counter == 5, 'TCS6 counter restores across restart')
  request%t0 = 46.0_real64
  request%t1 = 46.1_real64
  call evaluate_scheduled_irrigation_interval(parameters, restored_state, request, hydraulic, &
                                               candidate, fluxes, diagnostics)
  call require(diagnostics%status == IRRIGATION_OK .and. .not. diagnostics%triggered .and. &
       candidate%tcs6_weekly_day_counter == 6, 'TCS6 waits for seventh eligible day')
  committed = candidate
  request%t0 = 47.0_real64
  request%t1 = 48.0_real64
  call evaluate_scheduled_irrigation_interval(parameters, committed, request, hydraulic, &
                                               candidate, fluxes, diagnostics)
  call require(diagnostics%status == IRRIGATION_SPLIT_REQUIRED .and. diagnostics%triggered .and. &
       candidate%tcs6_weekly_day_counter == 6, 'TCS6 split rejection rolls weekly counter back')
  request%t1 = 47.1_real64
  call evaluate_scheduled_irrigation_interval(parameters, committed, request, hydraulic, &
                                               candidate, fluxes, diagnostics)
  call require(diagnostics%status == IRRIGATION_OK .and. diagnostics%triggered .and. &
       candidate%tcs6_weekly_day_counter == 0 .and. candidate%active_event, &
       'TCS6 triggers after seven days and commits reset with irrigation event')

  ! DCS1 adds the crop-stage millimetre correction, subtracts gross rain only
  ! above its threshold, and applies optional min/max depth limits.
  parameters%timing_criterion = 7
  parameters%depth_criterion = 1
  parameters%irr_rate_cm_per_day = 10.0_real64
  parameters%dcs1_knot_count = 2
  parameters%dcs1_dvs(1:2) = [0.0_real64, 1.0_real64]
  parameters%dcs1_adjustment_mm(1:2) = 10.0_real64
  parameters%rain_reduction_threshold_cm = 0.3_real64
  parameters%depth_limits_enabled = .false.
  hydraulic%pressure_head(2) = -200.0_real64
  committed = irrigation_state_t()
  request%t0 = 60.0_real64
  request%t1 = 60.1_real64
  request%gross_rain_cm_per_day = 0.2_real64
  call evaluate_scheduled_irrigation_interval(parameters, committed, request, hydraulic, &
                                               candidate, fluxes, diagnostics)
  call require(diagnostics%status == IRRIGATION_OK .and. diagnostics%triggered .and. &
       abs(diagnostics%interpolated_depth-7.0_real64) < 1.0e-14_real64, &
       'DCS1 does not subtract rain at or below the legacy rain threshold')
  request%t0 = 61.0_real64
  request%t1 = 61.1_real64
  request%gross_rain_cm_per_day = 0.5_real64
  call evaluate_scheduled_irrigation_interval(parameters, committed, request, hydraulic, &
                                               candidate, fluxes, diagnostics)
  call require(diagnostics%status == IRRIGATION_OK .and. &
       abs(diagnostics%interpolated_depth-6.5_real64) < 1.0e-14_real64, &
       'DCS1 subtracts rain above threshold from root-zone FC deficit')
  parameters%depth_limits_enabled = .true.
  parameters%minimum_depth_mm = 50.0_real64
  parameters%maximum_depth_mm = 60.0_real64
  request%t0 = 62.0_real64
  request%t1 = 62.1_real64
  call evaluate_scheduled_irrigation_interval(parameters, committed, request, hydraulic, &
                                               candidate, fluxes, diagnostics)
  call require(diagnostics%status == IRRIGATION_OK .and. &
       abs(diagnostics%interpolated_depth-6.0_real64) < 1.0e-14_real64, &
       'DCSLIM clamps DCS1 depth in legacy millimetre input units')
  parameters%application_type = IRRIGATION_APPLICATION_SPRINKLER
  call evaluate_scheduled_irrigation_interval(parameters, committed, request, hydraulic, &
                                               candidate, fluxes, diagnostics)
  call require(diagnostics%status == IRRIGATION_OK .and. &
       fluxes%application_type == IRRIGATION_APPLICATION_SPRINKLER .and. &
       abs(fluxes%surface_gross_rate-10.0_real64) < 1.0e-14_real64 .and. &
       .not. allocated(fluxes%subsurface_source), 'scheduled sprinkler emits gross surface flux for Rutter')
  parameters%application_type = IRRIGATION_APPLICATION_SURFACE
  call evaluate_scheduled_irrigation_interval(parameters, committed, request, hydraulic, &
                                               candidate, fluxes, diagnostics)
  call require(diagnostics%status == IRRIGATION_OK .and. &
       fluxes%application_type == IRRIGATION_APPLICATION_SURFACE .and. &
       abs(fluxes%surface_gross_rate-10.0_real64) < 1.0e-14_real64 .and. &
       .not. allocated(fluxes%subsurface_source), 'scheduled surface mode emits direct surface flux')

  ! Fixed-date route preserves event ordering, split rollback, surface
  ! sprinkling selection and subsurface node distribution.
  fixed_parameters%fixed_irrigation_enabled = .true.
  fixed_parameters%active_nodes = 3
  fixed_parameters%ssdi_first_node = 1
  fixed_parameters%ssdi_last_node = 2
  allocate(fixed_parameters%fixed_events(3))
  fixed_parameters%fixed_events(1) = fixed_irrigation_event_t(1.0_real64, &
       IRRIGATION_APPLICATION_SPRINKLER, 0.5_real64, 2.0_real64, 0.15_real64)
  fixed_parameters%fixed_events(2) = fixed_irrigation_event_t(2.0_real64, &
       IRRIGATION_APPLICATION_SURFACE, 0.25_real64, 1.0_real64, 0.0_real64)
  fixed_parameters%fixed_events(3) = fixed_irrigation_event_t(3.0_real64, &
       IRRIGATION_APPLICATION_SSDI, 0.5_real64, 2.0_real64, 0.0_real64)
  fixed_parameters%fixed_events(1)%concentration = -1.0_real64
  fixed_request%t0 = 1.0_real64
  fixed_request%t1 = 1.125_real64
  call evaluate_fixed_irrigation_interval(fixed_parameters, fixed_state, fixed_request, &
                                           fixed_candidate, fixed_flux, fixed_diagnostics)
  call require(fixed_diagnostics%status == IRRIGATION_INVALID_EVENT .and. &
       fixed_candidate%next_fixed_event_index == 1, 'invalid fixed solute concentration rejects atomically')
  fixed_parameters%fixed_events(1)%concentration = 0.15_real64
  fixed_request%t0 = 1.0_real64
  fixed_request%t1 = 2.0_real64
  call evaluate_fixed_irrigation_interval(fixed_parameters, fixed_state, fixed_request, &
                                           fixed_candidate, fixed_flux, fixed_diagnostics)
  call require(fixed_diagnostics%status == IRRIGATION_SPLIT_REQUIRED .and. &
       .not. fixed_candidate%active_event .and. fixed_candidate%next_fixed_event_index == 1, &
       'fixed event split request does not advance event index')
  fixed_request%t1 = 1.125_real64
  call evaluate_fixed_irrigation_interval(fixed_parameters, fixed_state, fixed_request, &
                                           fixed_candidate, fixed_flux, fixed_diagnostics)
  call require(fixed_diagnostics%status == IRRIGATION_OK .and. fixed_flux%event_started .and. &
       fixed_flux%application_type == IRRIGATION_APPLICATION_SPRINKLER .and. &
       abs(fixed_flux%external_inflow_amount-0.25_real64) < 1.0e-14_real64, &
       'fixed sprinkler event emits correct rate and partial mass')
  call export_irrigation_restart(fixed_candidate, restart_record, restart_status)
  call require(restart_status == IRRIGATION_RESTART_OK, 'fixed irrigation event exports active state')
  call restore_irrigation_restart(restart_record, restored_state, restart_status)
  fixed_request%t0 = 1.125_real64
  fixed_request%t1 = 1.25_real64
  call evaluate_fixed_irrigation_interval(fixed_parameters, restored_state, fixed_request, &
                                           fixed_candidate, fixed_flux, fixed_diagnostics)
  call require(fixed_diagnostics%status == IRRIGATION_OK .and. fixed_flux%event_finished .and. &
       abs(fixed_flux%external_inflow_amount-0.25_real64) < 1.0e-14_real64 .and. &
       fixed_candidate%next_fixed_event_index == 2, 'fixed event resumes after restart and advances once')
  fixed_request%t0 = 2.0_real64
  fixed_request%t1 = 2.25_real64
  call evaluate_fixed_irrigation_interval(fixed_parameters, fixed_candidate, fixed_request, &
                                           fixed_state, fixed_flux, fixed_diagnostics)
  call require(fixed_diagnostics%status == IRRIGATION_OK .and. &
       fixed_flux%application_type == IRRIGATION_APPLICATION_SURFACE .and. &
       abs(fixed_flux%external_inflow_amount-0.25_real64) < 1.0e-14_real64, &
       'fixed surface event preserves direct surface application')
  fixed_request%t0 = 3.0_real64
  fixed_request%t1 = 3.25_real64
  call evaluate_fixed_irrigation_interval(fixed_parameters, fixed_state, fixed_request, &
                                           fixed_candidate, fixed_flux, fixed_diagnostics)
  call require(fixed_diagnostics%status == IRRIGATION_OK .and. &
       fixed_flux%application_type == IRRIGATION_APPLICATION_SSDI .and. &
       maxval(abs(fixed_flux%subsurface_source-[2.0_real64,2.0_real64,0.0_real64])) < 1.0e-14_real64 .and. &
       abs(fixed_flux%external_inflow_amount-1.0_real64) < 1.0e-14_real64, &
       'fixed SSDI event distributes rate and closes nodal source mass')

  write(*,'(a)') 'F_MIG431_TCS7_SSDI_FORMULA=PASS'
  write(*,'(a)') 'F_MIG431_TCS8_THETA_FORMULA=PASS'
  write(*,'(a)') 'F_MIG431_TCS2_TCS3_TCS4_ROOT_DEPLETION=PASS'
  write(*,'(a)') 'F_MIG431_TCS6_WEEKLY_DEFICIT=PASS'
  write(*,'(a)') 'F_MIG431_DCS1_DCSLIM_RAIN=PASS'
  write(*,'(a)') 'F_MIG431_SCHEDULED_APPLICATION_ROUTE_TYPES=PASS'
  write(*,'(a)') 'F_MIG431_FIXED_IRRIGATION_EVENTS=PASS'
  write(*,'(a)') 'F_MIG431_TCS7_SSDI_SPLIT_REPLAY=PASS'
  write(*,'(a)') 'F_MIG431_TCS7_SSDI_MASS_CLOSURE=PASS'
  write(*,'(a)') 'F_MIG431_TCS7_SSDI_RESTART=PASS'
  write(*,'(a)') 'F_MIG431_SSDI_RUNTIME_SOURCE_BINDING=PASS'

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
