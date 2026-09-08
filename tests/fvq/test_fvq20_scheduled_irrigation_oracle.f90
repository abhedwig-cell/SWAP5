program test_fvq20_scheduled_irrigation_oracle
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_irrigation_process, only: scheduled_irrigation_parameters_t, scheduled_irrigation_request_t, &
       irrigation_state_t, irrigation_flux_result_t, irrigation_diagnostics_t, &
       evaluate_scheduled_irrigation_interval, IRRIGATION_OK, IRRIGATION_INVALID_PARAMETERS, &
       IRRIGATION_SPLIT_REQUIRED, IRRIGATION_EVENT_NONE, IRRIGATION_EVENT_SCHEDULED, &
       IRRIGATION_APPLICATION_SSDI
  implicit none

  call test_outer_selection_and_nonmidnight_time()
  call test_tcs7_dcs2_source_oracle()
  call test_afgen_boundary_oracle()
  call test_continuation_and_no_implicit_retrigger()
  call test_split_rollback_replay()
  call test_a_b_a()

  write(*,'(A)') 'FVQ20_EXPLICIT_SELECTION_NONMIDNIGHT=PASS'
  write(*,'(A)') 'FVQ20_TCS7_TRIGGER_ORACLE=PASS'
  write(*,'(A)') 'FVQ20_DCS2_TRANSLATED_DEPTH_ORACLE=PASS'
  write(*,'(A)') 'FVQ20_SINGLE_NODE_SSDI_ORACLE=PASS'
  write(*,'(A)') 'FVQ20_AFGEN_BOUNDARY_ORACLE=PASS'
  write(*,'(A)') 'FVQ20_PARTIAL_TABLE_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FVQ20_CONTINUATION_NO_SELECTION_REQUIRED=PASS'
  write(*,'(A)') 'FVQ20_COMPLETION_NO_IMPLICIT_RETRIGGER=PASS'
  write(*,'(A)') 'FVQ20_SPLIT_NO_MUTATION=PASS'
  write(*,'(A)') 'FVQ20_ROLLBACK_REPLAY=PASS'
  write(*,'(A)') 'FVQ20_A_B_A=PASS'
  write(*,'(A)') 'FVQ20_SCHEDULED_IRRIGATION_SCIENTIFIC_ORACLE PASS'

contains

  subroutine test_outer_selection_and_nonmidnight_time()
    type(scheduled_irrigation_parameters_t) :: p
    type(scheduled_irrigation_request_t) :: req
    type(process_hydraulic_view_t) :: view
    type(irrigation_state_t) :: committed, candidate
    type(irrigation_flux_result_t) :: flux
    type(irrigation_diagnostics_t) :: diag

    call configure_three_knot_parameters(p)
    call configure_view(view,p%active_nodes,p%sensor_node,-90.0_real64)
    call configure_request(req,1234.375_real64,1234.500_real64,0.5_real64)

    req%selection_opportunity = .false.
    call evaluate_scheduled_irrigation_interval(p,committed,req,view,candidate,flux,diag)
    call require(diag%status == IRRIGATION_OK .and. .not. diag%selection_evaluated,'no opportunity no evaluation')
    call require(.not. flux%applied .and. state_equal(committed,candidate),'no opportunity no mutation')

    req%selection_opportunity = .true.
    req%fixed_event_already_selected = .true.
    call evaluate_scheduled_irrigation_interval(p,committed,req,view,candidate,flux,diag)
    call require(diag%status == IRRIGATION_OK .and. .not. diag%selection_evaluated,'fixed precedence blocks selection')
    call require(.not. flux%applied .and. state_equal(committed,candidate),'fixed precedence no mutation')

    req%fixed_event_already_selected = .false.
    call evaluate_scheduled_irrigation_interval(p,committed,req,view,candidate,flux,diag)
    call require(diag%status == IRRIGATION_OK .and. diag%selection_evaluated .and. diag%triggered,'explicit nonmidnight selection')
    call require(flux%applied .and. flux%event_finished,'nonmidnight event applied')
    call require(flux%event_origin == IRRIGATION_EVENT_SCHEDULED,'scheduled origin')
    call require(flux%application_type == IRRIGATION_APPLICATION_SSDI,'single-node SSDI application')
    call require(.not. candidate%active_event .and. candidate%active_event_origin == IRRIGATION_EVENT_NONE,'full event clears state')
  end subroutine test_outer_selection_and_nonmidnight_time

  subroutine test_tcs7_dcs2_source_oracle()
    type(scheduled_irrigation_parameters_t) :: p
    type(scheduled_irrigation_request_t) :: req
    type(process_hydraulic_view_t) :: view
    type(irrigation_state_t) :: committed, candidate
    type(irrigation_flux_result_t) :: flux
    type(irrigation_diagnostics_t) :: diag
    real(real64), parameter :: expected_threshold=-90.0_real64
    real(real64), parameter :: expected_depth=0.30_real64
    real(real64), parameter :: expected_rate=2.40_real64
    real(real64), parameter :: expected_duration=expected_depth/expected_rate

    call configure_three_knot_parameters(p)
    call configure_request(req,1400.375_real64,1400.375_real64+expected_duration,0.5_real64)
    call configure_view(view,p%active_nodes,p%sensor_node,expected_threshold)
    call evaluate_scheduled_irrigation_interval(p,committed,req,view,candidate,flux,diag)

    call require(diag%status == IRRIGATION_OK .and. diag%selection_evaluated .and. diag%triggered,'TCS7 equality triggers')
    call require(close_real(diag%interpolated_threshold,expected_threshold),'TCS7 linear interpolation')
    call require(close_real(diag%interpolated_depth,expected_depth),'DCS2 translated-cm interpolation')
    call require(close_real(flux%event_duration,expected_duration),'legacy duration depth/rate')
    call require(close_real(flux%active_duration,expected_duration),'full active duration')
    call require(close_real(flux%external_inflow_amount,expected_depth),'single-node full-event mass')
    call require(allocated(flux%subsurface_source) .and. size(flux%subsurface_source)==p%active_nodes,'SSDI source shape')
    call require(close_real(flux%subsurface_source(p%single_ssdi_node),expected_rate),'qssdi node equals rate')
    call require(close_real(sum_nonselected_abs(flux%subsurface_source,p%single_ssdi_node),0.0_real64),'only one SSDI node active')

    call configure_view(view,p%active_nodes,p%sensor_node,expected_threshold+1.0_real64)
    call evaluate_scheduled_irrigation_interval(p,committed,req,view,candidate,flux,diag)
    call require(diag%status == IRRIGATION_OK .and. diag%selection_evaluated .and. .not. diag%triggered,'head above threshold no trigger')
    call require(.not. flux%applied .and. state_equal(committed,candidate),'no-trigger no state/water')
  end subroutine test_tcs7_dcs2_source_oracle

  subroutine test_afgen_boundary_oracle()
    type(scheduled_irrigation_parameters_t) :: p
    type(scheduled_irrigation_request_t) :: req
    type(process_hydraulic_view_t) :: view
    type(irrigation_state_t) :: committed, candidate
    type(irrigation_flux_result_t) :: flux
    type(irrigation_diagnostics_t) :: diag
    integer :: i

    call configure_three_knot_parameters(p)
    call configure_request(req,1500.375_real64,1500.400_real64,-0.25_real64)
    call configure_view(view,p%active_nodes,p%sensor_node,-100.0_real64)
    call evaluate_scheduled_irrigation_interval(p,committed,req,view,candidate,flux,diag)
    call require(diag%status == IRRIGATION_OK .and. diag%triggered,'below-first clamp trigger')
    call require(close_real(diag%interpolated_threshold,-100.0_real64),'AFGEN below-first threshold')
    call require(close_real(diag%interpolated_depth,0.20_real64),'AFGEN below-first depth')

    call configure_request(req,1501.375_real64,1501.400_real64,2.25_real64)
    call configure_view(view,p%active_nodes,p%sensor_node,-60.0_real64)
    call evaluate_scheduled_irrigation_interval(p,committed,req,view,candidate,flux,diag)
    call require(diag%status == IRRIGATION_INVALID_PARAMETERS,'partial table above last fail closed')
    call require(.not. flux%applied .and. state_equal(committed,candidate),'partial above-last no water/state')

    p%tcs7_knot_count=7; p%dcs2_knot_count=7
    p%tcs7_dvs=0.0_real64; p%tcs7_pressure_head=0.0_real64
    p%dcs2_dvs=0.0_real64; p%dcs2_depth_cm=0.0_real64
    do i=1,7
      p%tcs7_dvs(i)=real(i-1,real64)/3.0_real64
      p%dcs2_dvs(i)=p%tcs7_dvs(i)
      p%tcs7_pressure_head(i)=-110.0_real64+10.0_real64*real(i-1,real64)
      p%dcs2_depth_cm(i)=0.10_real64*real(i,real64)
    end do
    call configure_request(req,1502.375_real64,1502.400_real64,2.25_real64)
    call configure_view(view,p%active_nodes,p%sensor_node,-50.0_real64)
    call evaluate_scheduled_irrigation_interval(p,committed,req,view,candidate,flux,diag)
    call require(diag%status == IRRIGATION_OK .and. diag%triggered,'full table above-last clamp accepted')
    call require(close_real(diag%interpolated_threshold,-50.0_real64),'full table final threshold clamp')
    call require(close_real(diag%interpolated_depth,0.70_real64),'full table final depth clamp')
  end subroutine test_afgen_boundary_oracle

  subroutine test_continuation_and_no_implicit_retrigger()
    type(scheduled_irrigation_parameters_t) :: p
    type(scheduled_irrigation_request_t) :: req
    type(process_hydraulic_view_t) :: view, unused_view
    type(irrigation_state_t) :: committed, active, finished, quiet, retriggered
    type(irrigation_flux_result_t) :: flux
    type(irrigation_diagnostics_t) :: diag
    real(real64), parameter :: t0=1700.375_real64, duration=0.25_real64

    call configure_three_knot_parameters(p)
    p%irr_rate_cm_per_day=1.20_real64
    p%dcs2_depth_cm(1:3)=0.30_real64
    call configure_view(view,p%active_nodes,p%sensor_node,-100.0_real64)
    call configure_request(req,t0,t0+0.10_real64,0.5_real64)
    call evaluate_scheduled_irrigation_interval(p,committed,req,view,active,flux,diag)
    call require(diag%status == IRRIGATION_OK .and. flux%event_started .and. active%active_event,'start active event')
    call require(active%active_event_origin == IRRIGATION_EVENT_SCHEDULED,'persist scheduled origin')
    call require(close_real(active%active_event_end,t0+duration),'persist event end')

    req=scheduled_irrigation_request_t()
    req%t0=t0+0.10_real64; req%t1=t0+duration; req%dvs=999.0_real64
    call evaluate_scheduled_irrigation_interval(p,active,req,unused_view,finished,flux,diag)
    call require(diag%status == IRRIGATION_OK .and. flux%event_finished,'continuation without new selection/view')
    call require(.not. finished%active_event,'completion clears event')
    call require(close_time_delta(flux%active_duration,0.15_real64,req%t0,req%t1),'continuation persisted duration')

    req=scheduled_irrigation_request_t()
    req%t0=t0+duration; req%t1=t0+duration+0.10_real64; req%dvs=0.5_real64
    req%irrigation_enabled=.true.; req%schedule_enabled=.true.; req%crop_emerged=.true.; req%irrigation_window_open=.true.
    call evaluate_scheduled_irrigation_interval(p,finished,req,view,quiet,flux,diag)
    call require(diag%status == IRRIGATION_OK .and. .not. diag%selection_evaluated,'no post-completion implicit selection')
    call require(.not. flux%applied .and. state_equal(finished,quiet),'no post-completion implicit water/state')

    req%selection_opportunity=.true.
    call evaluate_scheduled_irrigation_interval(p,quiet,req,view,retriggered,flux,diag)
    call require(diag%status == IRRIGATION_OK .and. diag%selection_evaluated .and. diag%triggered,'later explicit opportunity can retrigger')
  end subroutine test_continuation_and_no_implicit_retrigger

  subroutine test_split_rollback_replay()
    type(scheduled_irrigation_parameters_t) :: p
    type(scheduled_irrigation_request_t) :: req
    type(process_hydraulic_view_t) :: view
    type(irrigation_state_t) :: committed, ca, cb
    type(irrigation_flux_result_t) :: fa, fb
    type(irrigation_diagnostics_t) :: da, db
    real(real64), parameter :: t0=1800.375_real64

    call configure_three_knot_parameters(p)
    p%irr_rate_cm_per_day=1.20_real64; p%dcs2_depth_cm(1:3)=0.30_real64
    call configure_view(view,p%active_nodes,p%sensor_node,-100.0_real64)
    call configure_request(req,t0,t0+0.40_real64,0.5_real64)
    call evaluate_scheduled_irrigation_interval(p,committed,req,view,ca,fa,da)
    call evaluate_scheduled_irrigation_interval(p,committed,req,view,cb,fb,db)
    call require(da%status == IRRIGATION_SPLIT_REQUIRED .and. da%split_required,'cross-end split required')
    call require(close_real(da%split_time,t0+0.25_real64),'split at event end')
    call require(state_equal(committed,ca) .and. state_equal(committed,cb),'split no state mutation')
    call require(.not. fa%applied .and. .not. allocated(fa%subsurface_source),'split no water')
    call require(state_equal(ca,cb) .and. flux_equal(fa,fb) .and. diag_equal(da,db),'rollback replay exact')
  end subroutine test_split_rollback_replay

  subroutine test_a_b_a()
    type(scheduled_irrigation_parameters_t) :: pa,pb
    type(scheduled_irrigation_request_t) :: req
    type(process_hydraulic_view_t) :: view
    type(irrigation_state_t) :: committed,ca1,cb,ca2
    type(irrigation_flux_result_t) :: fa1,fb,fa2
    type(irrigation_diagnostics_t) :: da1,db,da2

    call configure_three_knot_parameters(pa)
    pb=pa; pb%tcs7_pressure_head(1:pb%tcs7_knot_count)=-120.0_real64
    call configure_view(view,pa%active_nodes,pa%sensor_node,-90.0_real64)
    call configure_request(req,1900.375_real64,1900.500_real64,0.5_real64)
    call evaluate_scheduled_irrigation_interval(pa,committed,req,view,ca1,fa1,da1)
    call evaluate_scheduled_irrigation_interval(pb,committed,req,view,cb,fb,db)
    call evaluate_scheduled_irrigation_interval(pa,committed,req,view,ca2,fa2,da2)
    call require(fa1%applied .and. .not. fb%applied .and. fa2%applied,'A/B/A threshold distinction')
    call require(state_equal(ca1,ca2) .and. flux_equal(fa1,fa2) .and. diag_equal(da1,da2),'A replay bitwise exact after B')
  end subroutine test_a_b_a

  subroutine configure_three_knot_parameters(p)
    type(scheduled_irrigation_parameters_t), intent(out) :: p
    p%scheduled_irrigation_enabled=.true.; p%active_nodes=4; p%sensor_node=2; p%single_ssdi_node=3
    p%irr_rate_cm_per_day=2.40_real64
    p%tcs7_knot_count=3
    p%tcs7_dvs(1:3)=[0.0_real64,1.0_real64,2.0_real64]
    p%tcs7_pressure_head(1:3)=[-100.0_real64,-80.0_real64,-60.0_real64]
    p%dcs2_knot_count=3
    p%dcs2_dvs(1:3)=[0.0_real64,1.0_real64,2.0_real64]
    p%dcs2_depth_cm(1:3)=[0.20_real64,0.40_real64,0.60_real64]
  end subroutine configure_three_knot_parameters

  subroutine configure_request(req,t0,t1,dvs)
    type(scheduled_irrigation_request_t), intent(out) :: req
    real(real64), intent(in) :: t0,t1,dvs
    req%t0=t0; req%t1=t1; req%dvs=dvs
    req%selection_opportunity=.true.; req%irrigation_enabled=.true.; req%schedule_enabled=.true.
    req%crop_emerged=.true.; req%irrigation_window_open=.true.; req%fixed_event_already_selected=.false.
  end subroutine configure_request

  subroutine configure_view(view,n,sensor,head_sensor)
    type(process_hydraulic_view_t), intent(out) :: view
    integer, intent(in) :: n,sensor
    real(real64), intent(in) :: head_sensor
    view%active_nodes=n
    allocate(view%pressure_head(n),view%water_content(n))
    view%pressure_head=-75.0_real64; view%pressure_head(sensor)=head_sensor
    view%water_content=0.25_real64; view%ponding_depth=0.0_real64; view%groundwater_level=-2.0_real64
  end subroutine configure_view

  logical function state_equal(a,b)
    type(irrigation_state_t), intent(in) :: a,b
    state_equal=a%next_fixed_event_index==b%next_fixed_event_index .and. (a%active_event .eqv. b%active_event) .and. &
      a%active_event_origin==b%active_event_origin .and. a%active_event_index==b%active_event_index .and. &
      same_bits(a%active_event_start,b%active_event_start) .and. same_bits(a%active_event_end,b%active_event_end)
  end function state_equal

  logical function flux_equal(a,b)
    type(irrigation_flux_result_t), intent(in) :: a,b
    flux_equal=(a%applied .eqv. b%applied) .and. (a%event_started .eqv. b%event_started) .and. &
      (a%event_finished .eqv. b%event_finished) .and. (a%event_remains_active .eqv. b%event_remains_active) .and. &
      a%event_origin==b%event_origin .and. a%event_index==b%event_index .and. a%application_type==b%application_type .and. &
      same_bits(a%event_duration,b%event_duration) .and. same_bits(a%active_duration,b%active_duration) .and. &
      same_bits(a%surface_gross_rate,b%surface_gross_rate) .and. same_bits(a%external_inflow_amount,b%external_inflow_amount)
    if (allocated(a%subsurface_source) .neqv. allocated(b%subsurface_source)) then
      flux_equal=.false.
    else if (allocated(a%subsurface_source)) then
      flux_equal=flux_equal .and. real_array_same_bits(a%subsurface_source,b%subsurface_source)
    end if
  end function flux_equal

  logical function diag_equal(a,b)
    type(irrigation_diagnostics_t), intent(in) :: a,b
    diag_equal=a%status==b%status .and. (a%event_match .eqv. b%event_match) .and. &
      (a%split_required .eqv. b%split_required) .and. same_bits(a%split_time,b%split_time) .and. &
      (a%selection_evaluated .eqv. b%selection_evaluated) .and. (a%triggered .eqv. b%triggered) .and. &
      same_bits(a%interpolated_threshold,b%interpolated_threshold) .and. same_bits(a%interpolated_depth,b%interpolated_depth)
  end function diag_equal

  logical function real_array_same_bits(a,b)
    real(real64), intent(in) :: a(:),b(:)
    integer :: i
    real_array_same_bits=size(a)==size(b)
    if (.not. real_array_same_bits) return
    do i=1,size(a)
      if (.not. same_bits(a(i),b(i))) then
        real_array_same_bits=.false.; return
      end if
    end do
  end function real_array_same_bits

  real(real64) function sum_nonselected_abs(values,selected)
    real(real64), intent(in) :: values(:)
    integer, intent(in) :: selected
    integer :: i
    sum_nonselected_abs=0.0_real64
    do i=1,size(values)
      if (i/=selected) sum_nonselected_abs=sum_nonselected_abs+abs(values(i))
    end do
  end function sum_nonselected_abs

  logical function close_real(a,b)
    real(real64), intent(in) :: a,b
    real(real64) :: tol
    tol=256.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(a),abs(b))
    close_real=abs(a-b)<=tol
  end function close_real

  logical function close_time_delta(a,b,t_left,t_right)
    real(real64), intent(in) :: a,b,t_left,t_right
    real(real64) :: tol
    tol=256.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(t_left),abs(t_right))
    close_time_delta=abs(a-b)<=tol
  end function close_time_delta

  logical function same_bits(a,b)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia); ib=transfer(b,ib); same_bits=ia==ib
  end function same_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FVQ20_SCHEDULED_ORACLE_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fvq20_scheduled_irrigation_oracle
