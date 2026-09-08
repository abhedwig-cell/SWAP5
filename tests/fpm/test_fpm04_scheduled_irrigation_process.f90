program test_fpm04_scheduled_irrigation_process
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_irrigation_process, only: scheduled_irrigation_parameters_t, scheduled_irrigation_request_t, &
       irrigation_state_t, irrigation_flux_result_t, irrigation_diagnostics_t, &
       evaluate_scheduled_irrigation_interval, IRRIGATION_OK, IRRIGATION_INVALID_PARAMETERS, &
       IRRIGATION_INVALID_HYDRAULIC_VIEW, IRRIGATION_SPLIT_REQUIRED, IRRIGATION_EVENT_NONE, &
       IRRIGATION_EVENT_SCHEDULED, IRRIGATION_APPLICATION_SSDI
  implicit none

  call case_inactive_and_selection_gate()
  call case_trigger_and_interpolation()
  call case_afgen_boundaries()
  call case_fail_closed_tables_and_view()
  call case_continuation_and_no_implicit_retrigger()
  call case_split_no_mutation()
  call case_replay_and_aba()

  write(*,'(A)') 'FPM04_SCHEDULED_INACTIVE=PASS'
  write(*,'(A)') 'FPM04_SELECTION_OPPORTUNITY=PASS'
  write(*,'(A)') 'FPM04_TCS7_TRIGGER=PASS'
  write(*,'(A)') 'FPM04_DCS2_INTERPOLATION=PASS'
  write(*,'(A)') 'FPM04_AFGEN_RESTRICTED=PASS'
  write(*,'(A)') 'FPM04_FAIL_CLOSED_INPUTS=PASS'
  write(*,'(A)') 'FPM04_SINGLE_NODE_SSDI_MASS=PASS'
  write(*,'(A)') 'FPM04_CONTINUATION_NO_RETRIGGER=PASS'
  write(*,'(A)') 'FPM04_SPLIT_NO_MUTATION=PASS'
  write(*,'(A)') 'FPM04_ROLLBACK_REPLAY=PASS'
  write(*,'(A)') 'FPM04_A_B_A=PASS'
  write(*,'(A)') 'FPM04_SCHEDULED_PROCESS_TEST PASS'

contains

  subroutine case_inactive_and_selection_gate()
    type(scheduled_irrigation_parameters_t) :: p
    type(scheduled_irrigation_request_t) :: req
    type(process_hydraulic_view_t) :: view
    type(irrigation_state_t) :: committed, candidate
    type(irrigation_flux_result_t) :: flux
    type(irrigation_diagnostics_t) :: diag

    req%t0 = 1.0_real64; req%t1 = 1.25_real64
    call evaluate_scheduled_irrigation_interval(p, committed, req, view, candidate, flux, diag)
    call require(diag%status == IRRIGATION_OK, 'inactive status')
    call require(.not. flux%applied .and. .not. allocated(flux%subsurface_source), 'inactive allocation')
    call require(state_identical(committed,candidate), 'inactive state')

    call base_parameters(p)
    call open_request(req, 2.0_real64, 2.25_real64, 1.0_real64)
    req%selection_opportunity = .false.
    call evaluate_scheduled_irrigation_interval(p, committed, req, view, candidate, flux, diag)
    call require(diag%status == IRRIGATION_OK .and. .not. diag%selection_evaluated, 'no selection opportunity')
    call require(.not. flux%applied .and. .not. allocated(flux%subsurface_source), 'no selection allocation')

    req%selection_opportunity = .true.
    req%fixed_event_already_selected = .true.
    call evaluate_scheduled_irrigation_interval(p, committed, req, view, candidate, flux, diag)
    call require(diag%status == IRRIGATION_OK .and. .not. diag%selection_evaluated, 'fixed precedence')
    call require(.not. flux%applied, 'fixed precedence no scheduled flux')
  end subroutine case_inactive_and_selection_gate

  subroutine case_trigger_and_interpolation()
    type(scheduled_irrigation_parameters_t) :: p
    type(scheduled_irrigation_request_t) :: req
    type(process_hydraulic_view_t) :: view
    type(irrigation_state_t) :: committed, candidate
    type(irrigation_flux_result_t) :: flux
    type(irrigation_diagnostics_t) :: diag

    call base_parameters(p)
    call valid_view(view,p%active_nodes,p%sensor_node,-199.0_real64)
    call open_request(req, 10.0_real64, 10.25_real64, 1.0_real64)
    call evaluate_scheduled_irrigation_interval(p, committed, req, view, candidate, flux, diag)
    call require(diag%status == IRRIGATION_OK .and. diag%selection_evaluated, 'no-trigger selection evaluated')
    call require(.not. diag%triggered .and. .not. flux%applied, 'TCS7 no trigger')

    view%pressure_head(p%sensor_node) = -200.0_real64
    req%t1 = 10.5_real64
    call evaluate_scheduled_irrigation_interval(p, committed, req, view, candidate, flux, diag)
    call require(diag%status == IRRIGATION_OK .and. diag%triggered, 'TCS7 equality trigger')
    call require(close_value(diag%interpolated_threshold,-200.0_real64), 'threshold identity')
    call require(close_value(diag%interpolated_depth,0.5_real64), 'DCS2 depth identity')
    call require(flux%applied .and. flux%event_started .and. flux%event_finished, 'full event flags')
    call require(flux%event_origin == IRRIGATION_EVENT_SCHEDULED, 'scheduled result origin')
    call require(flux%application_type == IRRIGATION_APPLICATION_SSDI, 'scheduled SSDI application')
    call require(allocated(flux%subsurface_source) .and. size(flux%subsurface_source) == p%active_nodes, 'source allocation')
    call require(count_nonzero(flux%subsurface_source) == 1, 'single-node source cardinality')
    call require(close_value(flux%subsurface_source(p%single_ssdi_node),1.0_real64), 'single-node rate')
    call require(close_value(flux%external_inflow_amount,0.5_real64), 'full event mass equals depth')
    call require(.not. candidate%active_event .and. candidate%active_event_origin == IRRIGATION_EVENT_NONE, 'full event clears state')
  end subroutine case_trigger_and_interpolation

  subroutine case_afgen_boundaries()
    type(scheduled_irrigation_parameters_t) :: p
    type(scheduled_irrigation_request_t) :: req
    type(process_hydraulic_view_t) :: view
    type(irrigation_state_t) :: committed, candidate
    type(irrigation_flux_result_t) :: flux
    type(irrigation_diagnostics_t) :: diag
    integer :: i

    call base_parameters(p)
    call valid_view(view,p%active_nodes,p%sensor_node,-1000.0_real64)
    call open_request(req, 20.0_real64, 20.2_real64, -0.5_real64)
    call evaluate_scheduled_irrigation_interval(p, committed, req, view, candidate, flux, diag)
    call require(diag%status == IRRIGATION_OK .and. close_value(diag%interpolated_threshold,-100.0_real64), 'below-first threshold clamp')
    call require(close_value(diag%interpolated_depth,0.2_real64), 'below-first depth clamp')

    call base_parameters(p)
    call valid_view(view,p%active_nodes,p%sensor_node,-1000.0_real64)
    call open_request(req, 21.0_real64, 21.35_real64, 0.5_real64)
    call evaluate_scheduled_irrigation_interval(p, committed, req, view, candidate, flux, diag)
    call require(diag%status == IRRIGATION_OK .and. close_value(diag%interpolated_threshold,-150.0_real64), 'interior threshold interpolation')
    call require(close_value(diag%interpolated_depth,0.35_real64), 'interior depth interpolation')

    call base_parameters(p)
    p%tcs7_knot_count = 7; p%dcs2_knot_count = 7
    do i = 1, 7
      p%tcs7_dvs(i) = real(i-1,real64) / 3.0_real64
      p%dcs2_dvs(i) = p%tcs7_dvs(i)
      p%tcs7_pressure_head(i) = -100.0_real64 - 10.0_real64*real(i-1,real64)
      p%dcs2_depth_cm(i) = 0.1_real64 + 0.05_real64*real(i-1,real64)
    end do
    call valid_view(view,p%active_nodes,p%sensor_node,-1000.0_real64)
    call open_request(req, 22.0_real64, 22.4_real64, 2.5_real64)
    call evaluate_scheduled_irrigation_interval(p, committed, req, view, candidate, flux, diag)
    call require(diag%status == IRRIGATION_OK, 'full-table above-last admitted')
    call require(close_value(diag%interpolated_threshold,p%tcs7_pressure_head(7)), 'full-table last threshold clamp')
    call require(close_value(diag%interpolated_depth,p%dcs2_depth_cm(7)), 'full-table last depth clamp')
  end subroutine case_afgen_boundaries

  subroutine case_fail_closed_tables_and_view()
    type(scheduled_irrigation_parameters_t) :: p
    type(scheduled_irrigation_request_t) :: req
    type(process_hydraulic_view_t) :: view
    type(irrigation_state_t) :: committed, candidate
    type(irrigation_flux_result_t) :: flux
    type(irrigation_diagnostics_t) :: diag

    call base_parameters(p)
    call valid_view(view,p%active_nodes,p%sensor_node,-1000.0_real64)
    call open_request(req, 30.0_real64, 30.25_real64, 2.5_real64)
    call evaluate_scheduled_irrigation_interval(p, committed, req, view, candidate, flux, diag)
    call require(diag%status == IRRIGATION_INVALID_PARAMETERS .and. .not. flux%applied, 'partial above-last fail closed')
    call require(state_identical(committed,candidate), 'partial above-last no mutation')

    call base_parameters(p)
    p%tcs7_dvs(2) = p%tcs7_dvs(1)
    call open_request(req, 31.0_real64, 31.25_real64, 1.0_real64)
    call evaluate_scheduled_irrigation_interval(p, committed, req, view, candidate, flux, diag)
    call require(diag%status == IRRIGATION_INVALID_PARAMETERS, 'duplicate knot fail closed')

    call base_parameters(p)
    req%dvs = ieee_value(0.0_real64,ieee_quiet_nan)
    call evaluate_scheduled_irrigation_interval(p, committed, req, view, candidate, flux, diag)
    call require(diag%status == IRRIGATION_INVALID_PARAMETERS, 'nonfinite DVS fail closed')

    call base_parameters(p)
    call open_request(req, 32.0_real64, 32.25_real64, 1.0_real64)
    if (allocated(view%pressure_head)) deallocate(view%pressure_head)
    if (allocated(view%water_content)) deallocate(view%water_content)
    view%active_nodes = 0
    call evaluate_scheduled_irrigation_interval(p, committed, req, view, candidate, flux, diag)
    call require(diag%status == IRRIGATION_INVALID_HYDRAULIC_VIEW, 'missing view fail closed')

    call valid_view(view,p%active_nodes+1,p%sensor_node,-1000.0_real64)
    call evaluate_scheduled_irrigation_interval(p, committed, req, view, candidate, flux, diag)
    call require(diag%status == IRRIGATION_INVALID_HYDRAULIC_VIEW, 'topology mismatch fail closed')
  end subroutine case_fail_closed_tables_and_view

  subroutine case_continuation_and_no_implicit_retrigger()
    type(scheduled_irrigation_parameters_t) :: p
    type(scheduled_irrigation_request_t) :: req
    type(process_hydraulic_view_t) :: view
    type(irrigation_state_t) :: committed, half_state, finished_state, no_retrigger_state, future_state
    type(irrigation_flux_result_t) :: first, second, none_flux, future_flux
    type(irrigation_diagnostics_t) :: diag

    call base_parameters(p)
    call valid_view(view,p%active_nodes,p%sensor_node,-300.0_real64)
    call open_request(req, 40.0_real64, 40.25_real64, 1.0_real64)
    call evaluate_scheduled_irrigation_interval(p, committed, req, view, half_state, first, diag)
    call require(diag%status == IRRIGATION_OK .and. first%event_started .and. first%event_remains_active, 'scheduled start')
    call require(half_state%active_event .and. half_state%active_event_origin == IRRIGATION_EVENT_SCHEDULED, 'scheduled active origin')
    call require(half_state%active_event_index == 0 .and. half_state%next_fixed_event_index == 1, 'fixed cursor untouched')
    call require(close_value(first%external_inflow_amount,0.25_real64), 'first half mass')

    req%t0 = 40.25_real64; req%t1 = 40.5_real64
    req%selection_opportunity = .false.; req%irrigation_enabled = .false.; req%schedule_enabled = .false.
    req%crop_emerged = .false.; req%irrigation_window_open = .false.
    call evaluate_scheduled_irrigation_interval(p, half_state, req, view, finished_state, second, diag)
    call require(diag%status == IRRIGATION_OK .and. second%event_finished, 'continuation ignores new-selection gates')
    call require(close_value(second%external_inflow_amount,0.25_real64), 'second half mass')
    call require(.not. finished_state%active_event, 'completion clears active state')
    call require(close_value(first%external_inflow_amount+second%external_inflow_amount,0.5_real64), 'accepted interval mass sums to depth')

    call open_request(req, 40.5_real64, 40.75_real64, 1.0_real64)
    req%selection_opportunity = .false.
    call evaluate_scheduled_irrigation_interval(p, finished_state, req, view, no_retrigger_state, none_flux, diag)
    call require(diag%status == IRRIGATION_OK .and. .not. none_flux%applied, 'no implicit retrigger')
    call require(.not. allocated(none_flux%subsurface_source), 'no retrigger allocation')

    req%t0 = 41.0_real64; req%t1 = 41.25_real64; req%selection_opportunity = .true.
    call evaluate_scheduled_irrigation_interval(p, no_retrigger_state, req, view, future_state, future_flux, diag)
    call require(diag%status == IRRIGATION_OK .and. future_flux%applied, 'future explicit opportunity may retrigger')
  end subroutine case_continuation_and_no_implicit_retrigger

  subroutine case_split_no_mutation()
    type(scheduled_irrigation_parameters_t) :: p
    type(scheduled_irrigation_request_t) :: req
    type(process_hydraulic_view_t) :: view
    type(irrigation_state_t) :: committed, candidate
    type(irrigation_flux_result_t) :: flux
    type(irrigation_diagnostics_t) :: diag

    call base_parameters(p)
    call valid_view(view,p%active_nodes,p%sensor_node,-300.0_real64)
    call open_request(req, 50.0_real64, 50.75_real64, 1.0_real64)
    call evaluate_scheduled_irrigation_interval(p, committed, req, view, candidate, flux, diag)
    call require(diag%status == IRRIGATION_SPLIT_REQUIRED .and. diag%split_required, 'initial split')
    call require(close_value(diag%split_time,50.5_real64), 'split time')
    call require(state_identical(committed,candidate), 'split candidate unchanged')
    call require(.not. flux%applied .and. .not. allocated(flux%subsurface_source), 'split no source')
  end subroutine case_split_no_mutation

  subroutine case_replay_and_aba()
    type(scheduled_irrigation_parameters_t) :: pa, pb
    type(scheduled_irrigation_request_t) :: req
    type(process_hydraulic_view_t) :: view
    type(irrigation_state_t) :: committed, ca1, ca2, ca3, cb
    type(irrigation_flux_result_t) :: fa1, fa2, fa3, fb
    type(irrigation_diagnostics_t) :: da1, da2, da3, db

    call base_parameters(pa)
    pb = pa; pb%irr_rate_cm_per_day = 2.0_real64
    call valid_view(view,pa%active_nodes,pa%sensor_node,-300.0_real64)
    call open_request(req, 60.0_real64, 60.25_real64, 1.0_real64)
    call evaluate_scheduled_irrigation_interval(pa, committed, req, view, ca1, fa1, da1)
    call evaluate_scheduled_irrigation_interval(pa, committed, req, view, ca2, fa2, da2)
    call require(state_identical(ca1,ca2) .and. flux_identical(fa1,fa2) .and. diagnostics_identical(da1,da2), 'rollback replay identity')
    call require(.not. committed%active_event .and. committed%next_fixed_event_index == 1, 'committed protected')

    call evaluate_scheduled_irrigation_interval(pb, committed, req, view, cb, fb, db)
    call require(db%status == IRRIGATION_OK .and. fb%applied, 'B candidate')
    call evaluate_scheduled_irrigation_interval(pa, committed, req, view, ca3, fa3, da3)
    call require(state_identical(ca1,ca3) .and. flux_identical(fa1,fa3) .and. diagnostics_identical(da1,da3), 'A B A identity')
  end subroutine case_replay_and_aba

  subroutine base_parameters(p)
    type(scheduled_irrigation_parameters_t), intent(out) :: p
    p%scheduled_irrigation_enabled = .true.
    p%active_nodes = 4
    p%sensor_node = 2
    p%single_ssdi_node = 3
    p%irr_rate_cm_per_day = 1.0_real64
    p%tcs7_knot_count = 3
    p%tcs7_dvs(1:3) = [0.0_real64,1.0_real64,2.0_real64]
    p%tcs7_pressure_head(1:3) = [-100.0_real64,-200.0_real64,-300.0_real64]
    p%dcs2_knot_count = 3
    p%dcs2_dvs(1:3) = [0.0_real64,1.0_real64,2.0_real64]
    p%dcs2_depth_cm(1:3) = [0.2_real64,0.5_real64,0.8_real64]
  end subroutine base_parameters

  subroutine open_request(req,t0,t1,dvs)
    type(scheduled_irrigation_request_t), intent(out) :: req
    real(real64), intent(in) :: t0,t1,dvs
    req%t0=t0; req%t1=t1; req%dvs=dvs
    req%selection_opportunity=.true.
    req%irrigation_enabled=.true.
    req%schedule_enabled=.true.
    req%crop_emerged=.true.
    req%irrigation_window_open=.true.
    req%fixed_event_already_selected=.false.
  end subroutine open_request

  subroutine valid_view(view,n,sensor,head)
    type(process_hydraulic_view_t), intent(out) :: view
    integer, intent(in) :: n,sensor
    real(real64), intent(in) :: head
    allocate(view%pressure_head(n),view%water_content(n))
    view%active_nodes=n
    view%pressure_head=-50.0_real64
    view%water_content=0.25_real64
    if (sensor >= 1 .and. sensor <= n) view%pressure_head(sensor)=head
  end subroutine valid_view

  logical function state_identical(a,b)
    type(irrigation_state_t), intent(in) :: a,b
    state_identical = a%next_fixed_event_index == b%next_fixed_event_index .and. &
      (a%active_event .eqv. b%active_event) .and. a%active_event_origin == b%active_event_origin .and. &
      a%active_event_index == b%active_event_index .and. same_bits(a%active_event_start,b%active_event_start) .and. &
      same_bits(a%active_event_end,b%active_event_end)
  end function state_identical

  logical function flux_identical(a,b)
    type(irrigation_flux_result_t), intent(in) :: a,b
    flux_identical = (a%applied .eqv. b%applied) .and. (a%event_started .eqv. b%event_started) .and. &
      (a%event_finished .eqv. b%event_finished) .and. (a%event_remains_active .eqv. b%event_remains_active) .and. &
      a%event_origin == b%event_origin .and. a%event_index == b%event_index .and. &
      a%application_type == b%application_type .and. same_bits(a%concentration,b%concentration) .and. &
      same_bits(a%event_duration,b%event_duration) .and. same_bits(a%active_duration,b%active_duration) .and. &
      same_bits(a%surface_gross_rate,b%surface_gross_rate) .and. &
      same_bits(a%external_inflow_amount,b%external_inflow_amount) .and. &
      (allocated(a%subsurface_source) .eqv. allocated(b%subsurface_source))
    if (.not. flux_identical) return
    if (allocated(a%subsurface_source)) then
      flux_identical = size(a%subsurface_source) == size(b%subsurface_source)
      if (flux_identical) flux_identical = all(transfer(a%subsurface_source,[0_int64],size(a%subsurface_source)) == &
                                                transfer(b%subsurface_source,[0_int64],size(b%subsurface_source)))
    end if
  end function flux_identical

  logical function diagnostics_identical(a,b)
    type(irrigation_diagnostics_t), intent(in) :: a,b
    diagnostics_identical = a%status == b%status .and. (a%event_match .eqv. b%event_match) .and. &
      (a%split_required .eqv. b%split_required) .and. same_bits(a%split_time,b%split_time) .and. &
      (a%selection_evaluated .eqv. b%selection_evaluated) .and. (a%triggered .eqv. b%triggered) .and. &
      same_bits(a%interpolated_threshold,b%interpolated_threshold) .and. &
      same_bits(a%interpolated_depth,b%interpolated_depth) .and. &
      (a%external_inflow_is_reconciliation_only .eqv. b%external_inflow_is_reconciliation_only)
  end function diagnostics_identical

  integer function count_nonzero(values)
    real(real64), intent(in) :: values(:)
    integer :: i
    count_nonzero=0
    do i=1,size(values)
      if (abs(values(i)) > tiny(1.0_real64)) count_nonzero=count_nonzero+1
    end do
  end function count_nonzero

  logical function close_value(a,b)
    real(real64), intent(in) :: a,b
    close_value = abs(a-b) <= 1.0e-12_real64*max(1.0_real64,abs(a),abs(b))
  end function close_value

  logical function same_bits(a,b)
    real(real64), intent(in) :: a,b
    same_bits = transfer(a,0_int64) == transfer(b,0_int64)
  end function same_bits

  subroutine require(condition,message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(A)') 'FPM04_TEST_FAIL '//trim(message)
      error stop 1
    end if
  end subroutine require

end program test_fpm04_scheduled_irrigation_process
