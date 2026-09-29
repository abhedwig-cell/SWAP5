program test_ppa_irr_dcs2_limit
  use, intrinsic :: iso_fortran_env, only: real64,int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value,ieee_quiet_nan
  use mod_irrigation_process
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  implicit none
  type(scheduled_irrigation_parameters_t)::p
  type(scheduled_irrigation_request_t)::r
  type(irrigation_state_t)::base,candidate,first
  type(irrigation_flux_result_t)::f
  type(irrigation_diagnostics_t)::d
  type(process_hydraulic_view_t)::h
  real(real64)::raw,expected,amount,minimum,maximum,nan
  integer::i
  p%scheduled_irrigation_enabled=.true.
  p%active_nodes=1; p%sensor_node=1; p%single_ssdi_node=1
  p%tcs7_knot_count=2; p%tcs7_dvs(1:2)=[0.0_real64,2.0_real64]
  p%tcs7_pressure_head(1:2)=-1.0_real64
  p%dcs2_knot_count=2; p%dcs2_dvs(1:2)=[0.0_real64,2.0_real64]
  p%irr_rate_cm_per_day=0.0_real64
  h%active_nodes=1; allocate(h%pressure_head(1),h%water_content(1))
  h%pressure_head=-10.0_real64; h%water_content=0.2_real64
  r%t0=0.0_real64; r%t1=1.0_real64; r%dvs=1.0_real64
  r%selection_opportunity=.true.; r%irrigation_enabled=.true.; r%schedule_enabled=.true.
  r%crop_emerged=.true.; r%irrigation_window_open=.true.
  p%solute_enabled=.true.; p%solute_overirrigation_enabled=.true.
  p%solute_concentration_threshold=1.0_real64; p%solute_overirrigation_percent=50.0_real64
  do i=1,100000
    raw=real(modulo(i,257),real64)/128.0_real64
    minimum=real(modulo(i,101),real64)/16.0_real64
    maximum=minimum+real(modulo(3*i,127),real64)/8.0_real64
    p%dcs2_depth_cm(1:2)=raw
    p%depth_limit_enabled=modulo(i,3)/=0
    p%minimum_depth_mm=minimum; p%maximum_depth_mm=maximum
    r%sensor_solute_concentration=real(modulo(i,3),real64)
    expected=raw
    if(p%depth_limit_enabled) then
      expected=max(expected,minimum*0.1_real64)
      expected=min(expected,maximum*0.1_real64)
    end if
    if(r%sensor_solute_concentration>1.0_real64) expected=expected+0.01_real64*50.0_real64*expected
    call evaluate_scheduled_irrigation_interval(p,base,r,h,candidate,f,d)
    if(expected<=0.0_real64) then
      call require(d%status==IRRIGATION_INVALID_EVENT.and..not.f%applied,'zero final gift remains invalid')
    else
      call require(d%status==IRRIGATION_OK.and.f%applied,'source-limit candidate succeeds')
      call require(transfer(f%external_inflow_amount,0_int64)==transfer(expected,0_int64),'source order exact')
      call require(transfer(d%interpolated_depth,0_int64)==transfer(raw,0_int64),'raw table diagnostic preserved')
    end if
    call require(.not.base%active_event,'evaluation leaves committed state unchanged')
  end do
  write(*,'(a)') 'PPA_IRR_DCS2_LIMIT_100000_SOURCE_ORDER=PASS'

  ! A positive minimum raises a zero table gift, before rate/duration selection.
  p%depth_limit_enabled=.true.; p%minimum_depth_mm=5.0_real64; p%maximum_depth_mm=5.0_real64
  p%dcs2_depth_cm=0.0_real64; r%sensor_solute_concentration=2.0_real64
  p%irr_rate_cm_per_day=1.5_real64
  r%t1=0.25_real64
  call evaluate_scheduled_irrigation_interval(p,base,r,h,candidate,f,d)
  call require(d%status==IRRIGATION_OK.and.f%event_remains_active,'limited gift split begins')
  call require(abs(f%event_duration-0.5_real64)<epsilon(1.0_real64),'solute bump occurs after cap')
  amount=f%external_inflow_amount; first=candidate
  ! A retry from the same accepted input must be identical.
  call evaluate_scheduled_irrigation_interval(p,base,r,h,candidate,f,d)
  call require(abs(f%external_inflow_amount-amount)<epsilon(1.0_real64),'split retry amount exact')
  r%t0=0.25_real64; r%t1=0.5_real64
  p%minimum_depth_mm=0.0_real64; p%maximum_depth_mm=1.0_real64
  call evaluate_scheduled_irrigation_interval(p,first,r,h,candidate,f,d)
  call require(d%status==IRRIGATION_OK.and.f%event_finished,'active event retains selected rate')
  call require(abs(amount+f%external_inflow_amount-0.75_real64)<epsilon(1.0_real64),'split amount conserved')
  write(*,'(a)') 'PPA_IRR_DCS2_LIMIT_MIN_SOLUTE_RATE_SPLIT_RETRY=PASS'

  r%t0=0.0_real64; r%t1=1.0_real64; p%irr_rate_cm_per_day=0.0_real64
  p%dcs2_depth_cm=0.5_real64; p%solute_enabled=.false.
  nan=ieee_value(0.0_real64,ieee_quiet_nan)
  do i=1,6
    p%minimum_depth_mm=1.0_real64; p%maximum_depth_mm=2.0_real64
    select case(i)
    case(1); p%minimum_depth_mm=-1.0_real64
    case(2); p%minimum_depth_mm=101.0_real64
    case(3); p%maximum_depth_mm=0.5_real64
    case(4); p%maximum_depth_mm=1.0e7_real64+1.0_real64
    case(5); p%minimum_depth_mm=nan
    case(6); p%maximum_depth_mm=nan
    end select
    call evaluate_scheduled_irrigation_interval(p,base,r,h,candidate,f,d)
    call require(d%status==IRRIGATION_INVALID_PARAMETERS.and..not.f%applied,'invalid bounds fail closed')
    call require(.not.candidate%active_event,'invalid bounds publish no candidate event')
  end do
  p%depth_limit_enabled=.false.; p%minimum_depth_mm=nan; p%maximum_depth_mm=nan
  call evaluate_scheduled_irrigation_interval(p,base,r,h,candidate,f,d)
  call require(d%status==IRRIGATION_OK.and.abs(f%external_inflow_amount-0.5_real64)<epsilon(1.0_real64), &
       'disabled limits ignore inactive fields')
  write(*,'(a)') 'PPA_IRR_DCS2_LIMIT_GUARDS_DEFAULT_PRESERVATION=PASS'
contains
  subroutine require(ok,message)
    logical,intent(in)::ok
    character(*),intent(in)::message
    if(ok)return
    write(*,'(a)') message
    error stop 1
  end subroutine
end program
