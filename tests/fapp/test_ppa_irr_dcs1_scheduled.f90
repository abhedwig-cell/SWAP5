program test_ppa_irr_dcs1_scheduled
  use, intrinsic :: iso_fortran_env, only: real64,int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value,ieee_quiet_nan
  use mod_irrigation_process
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_ppa_irr_dcs1_depth, only: evaluate_dcs1_depth,IRR_DCS1_OK
  use mod_ppa_irr_water_deficit, only: evaluate_root_zone_water_deficit_checked,IRR_DEFICIT_OK
  use mod_ppa_irr_dcs1_composition, only: evaluate_profile_scheduled_irrigation
  implicit none
  type(scheduled_irrigation_parameters_t)::p,saved
  type(scheduled_irrigation_request_t)::r
  type(irrigation_state_t)::base,candidate,first
  type(irrigation_flux_result_t)::f
  type(irrigation_diagnostics_t)::d
  type(process_hydraulic_view_t)::h
  real(real64)::correction,raw,expected,oracle,oracle_correction,rate,duration,amount,nan
  real(real64)::fraction,root_depth,awlh,awmh,awah,expected_deficit
  integer::i,code,timing,demand_mode
  p%scheduled_irrigation_enabled=.true.; p%depth_criterion=IRRIGATION_DEPTH_DCS1_FIELD_CAPACITY
  p%active_nodes=2; p%sensor_node=1; p%single_ssdi_node=2
  p%tcs7_knot_count=2; p%tcs7_dvs(1:2)=[0.0_real64,2.0_real64]
  p%tcs7_pressure_head(1:2)=-1.0_real64
  p%tcs8_knot_count=2; p%tcs8_dvs(1:2)=[0.0_real64,2.0_real64]
  p%tcs8_water_content(1:2)=0.25_real64
  p%dcs1_knot_count=2; p%dcs1_dvs(1:2)=[0.0_real64,2.0_real64]
  p%rain_threshold_cm=0.5_real64
  p%solute_enabled=.true.; p%solute_overirrigation_enabled=.true.
  p%solute_concentration_threshold=1.0_real64; p%solute_overirrigation_percent=25.0_real64
  p%minimum_depth_mm=2.0_real64; p%maximum_depth_mm=8.0_real64
  h%active_nodes=2; allocate(h%pressure_head(2),h%water_content(2))
  h%pressure_head=-10.0_real64; h%water_content=0.2_real64
  r%t0=0.0_real64
  r%selection_opportunity=.true.; r%irrigation_enabled=.true.; r%schedule_enabled=.true.
  r%crop_emerged=.true.; r%irrigation_window_open=.true.
  do demand_mode=1,2
  do timing=IRRIGATION_TIMING_TCS7_PRESSURE_HEAD,IRRIGATION_TIMING_TCS8_WATER_CONTENT
  p%timing_criterion=timing
  do i=1,100000
    r%dvs=real(modulo(i,129),real64)/64.0_real64
    r%deficit_cm=real(modulo(3*i,257),real64)/64.0_real64-1.0_real64
    if(demand_mode==2) then
      fraction=real(modulo(i,65),real64)/64.0_real64
      root_depth=8.0_real64+16.0_real64*fraction
      h%water_content(1)=real(modulo(i,17),real64)/64.0_real64
      h%water_content(2)=real(modulo(7*i,65),real64)/64.0_real64
      call evaluate_root_zone_water_deficit_checked(2,[1,1],[8.0_real64,16.0_real64], &
           [0.0_real64,-8.0_real64],root_depth,[0.5_real64],[0.3_real64],[0.1_real64], &
           h%water_content,awlh,awmh,awah,r%deficit_cm,code)
      call require(code==IRR_DEFICIT_OK,'hydraulic-view deficit accepted')
      expected_deficit=(0.5_real64*8.0_real64-h%water_content(1)*8.0_real64)+ &
           (0.5_real64*16.0_real64*fraction-h%water_content(2)*16.0_real64*fraction)
      call require(transfer(r%deficit_cm,0_int64)==transfer(expected_deficit,0_int64), &
           'root-zone source-order deficit exact before DCS1')
    end if
    r%rainfall_cm=real(modulo(i,5),real64)/4.0_real64
    r%sensor_solute_concentration=real(modulo(i,3),real64)
    p%dcs1_correction_mm(1)=real(modulo(i,201)-100,real64)
    p%dcs1_correction_mm(2)=real(modulo(7*i,201)-100,real64)
    p%depth_limit_enabled=modulo(i,2)==0
    p%single_ssdi_node=modulo(i,2)+1
    p%irr_rate_cm_per_day=real(modulo(i,4),real64)/2.0_real64
    correction=p%dcs1_correction_mm(1)+r%dvs* &
         ((p%dcs1_correction_mm(2)-p%dcs1_correction_mm(1))/2.0_real64)
    raw=r%deficit_cm+correction*0.1_real64
    if(r%rainfall_cm>p%rain_threshold_cm) raw=raw-r%rainfall_cm
    raw=max(0.0_real64,raw)
    expected=raw
    if(p%depth_limit_enabled) then
      expected=max(expected,p%minimum_depth_mm*0.1_real64)
      expected=min(expected,p%maximum_depth_mm*0.1_real64)
    end if
    if(r%sensor_solute_concentration>1.0_real64) expected=expected+0.01_real64*25.0_real64*expected
    call evaluate_dcs1_depth(r%dvs,p%dcs1_dvs,p%dcs1_correction_mm,2,r%deficit_cm,r%rainfall_cm, &
         p%rain_threshold_cm,p%depth_limit_enabled,p%minimum_depth_mm,p%maximum_depth_mm, &
         .true.,r%sensor_solute_concentration,1.0_real64,25.0_real64,oracle,oracle_correction,code)
    call require(code==IRR_DCS1_OK.and.transfer(oracle,0_int64)==transfer(expected,0_int64), &
         'independent DCS1 helper matches source formula')
    duration=1.0_real64; rate=expected
    if(p%irr_rate_cm_per_day>0.0_real64.and.expected<=p%irr_rate_cm_per_day) then
      rate=p%irr_rate_cm_per_day; duration=expected/rate
    end if
    r%t1=max(duration,0.125_real64)
    if(expected>0.0_real64) r%t1=duration
    call evaluate_scheduled_irrigation_interval(p,base,r,h,candidate,f,d)
    if(demand_mode==2) then
      amount=f%external_inflow_amount
      code=d%status
      r%deficit_cm=ieee_value(0.0_real64,ieee_quiet_nan)
      call evaluate_profile_scheduled_irrigation(p,base,r,h,2,[1,1],[8.0_real64,16.0_real64], &
           [0.0_real64,-8.0_real64],root_depth,[0.5_real64],[0.3_real64],[0.1_real64],candidate,f,d)
      call require(d%status==code,'profile composition status matches supplied-deficit route')
      call require(transfer(f%external_inflow_amount,0_int64)==transfer(amount,0_int64), &
           'profile composition amount matches supplied-deficit route')
    end if
    if(expected<=0.0_real64) then
      call require(d%status==IRRIGATION_INVALID_EVENT.and..not.f%applied,'zero depth rejects without event')
    else
      call require(d%status==IRRIGATION_OK.and.f%applied.and.f%event_finished,'DCS1 complete event')
      call require(transfer(d%interpolated_depth,0_int64)==transfer(raw,0_int64),'raw DCS1 amount exact')
      call require(transfer(f%event_duration,0_int64)==transfer(duration,0_int64),'duration exact')
      call require(transfer(f%subsurface_source(p%single_ssdi_node),0_int64)==transfer(rate,0_int64), &
           'source rate exact')
      call require(abs(f%external_inflow_amount-expected)<=8.0_real64*epsilon(expected)*max(1.0_real64,expected), &
           'DCS1 source amount conserved')
    end if
    call require(.not.base%active_event,'committed input unchanged')
  end do
  end do
  write(*,'(a)') 'PPA_IRR_DCS1_SCHEDULED_SOURCE_ORACLE_100000=PASS'
  write(*,'(a)') 'PPA_IRR_DCS1_TCS7_TCS8_200000=PASS'
  end do
  write(*,'(a)') 'PPA_IRR_CHECKED_DEFICIT_DCS1_COMPOSITION_200000=PASS'
  h%water_content=0.2_real64

  p%dcs1_correction_mm=0.0_real64; p%depth_limit_enabled=.false.; p%solute_enabled=.false.
  p%irr_rate_cm_per_day=0.0_real64; r%deficit_cm=1.0_real64; r%rainfall_cm=0.5_real64
  r%dvs=1.0_real64; r%t1=0.25_real64
  call evaluate_scheduled_irrigation_interval(p,base,r,h,candidate,f,d)
  call require(d%status==IRRIGATION_OK.and.abs(d%interpolated_depth-1.0_real64)<epsilon(1.0_real64), &
       'rain threshold equality subtracts no rainfall')
  first=candidate; amount=f%external_inflow_amount
  call evaluate_scheduled_irrigation_interval(p,base,r,h,candidate,f,d)
  call require(transfer(amount,0_int64)==transfer(f%external_inflow_amount,0_int64),'same-boundary retry exact')
  nan=ieee_value(0.0_real64,ieee_quiet_nan)
  r%deficit_cm=nan; r%rainfall_cm=nan; r%dvs=nan; r%t0=0.25_real64; r%t1=1.0_real64
  call evaluate_scheduled_irrigation_interval(p,first,r,h,candidate,f,d)
  call require(d%status==IRRIGATION_OK.and.f%event_finished,'active event ignores new demand inputs')
  call require(abs(amount+f%external_inflow_amount-1.0_real64)<epsilon(1.0_real64),'copied-state continuation total')
  write(*,'(a)') 'PPA_IRR_DCS1_SCHEDULED_RAIN_RETRY_CONTINUATION=PASS'

  r%t0=0.0_real64; r%t1=1.0_real64; r%dvs=1.0_real64
  r%deficit_cm=1.0_real64; r%rainfall_cm=0.0_real64
  h%water_content=0.25_real64
  call evaluate_scheduled_irrigation_interval(p,base,r,h,candidate,f,d)
  call require(d%status==IRRIGATION_OK.and.d%triggered.and.f%applied,'TCS8 equality selects DCS1')
  h%water_content=nearest(0.25_real64,1.0_real64)
  r%deficit_cm=nan; r%rainfall_cm=nan
  call evaluate_scheduled_irrigation_interval(p,base,r,h,candidate,f,d)
  call require(d%status==IRRIGATION_OK.and..not.d%triggered.and..not.f%applied, &
       'TCS8 above threshold skips invalid inactive demand')
  h%water_content=0.2_real64
  write(*,'(a)') 'PPA_IRR_DCS1_TCS8_THRESHOLD_CONTINUATION=PASS'
  do i=1,7
    p%scheduled_irrigation_enabled=.true.; r%selection_opportunity=.true.
    r%irrigation_enabled=.true.; r%schedule_enabled=.true.; r%crop_emerged=.true.
    r%irrigation_window_open=.true.; r%fixed_event_already_selected=.false.
    select case(i)
    case(1); p%scheduled_irrigation_enabled=.false.
    case(2); r%selection_opportunity=.false.
    case(3); r%irrigation_enabled=.false.
    case(4); r%schedule_enabled=.false.
    case(5); r%crop_emerged=.false.
    case(6); r%irrigation_window_open=.false.
    case(7); r%fixed_event_already_selected=.true.
    end select
    call evaluate_scheduled_irrigation_interval(p,base,r,h,candidate,f,d)
    call require(d%status==IRRIGATION_OK.and..not.d%selection_evaluated.and..not.f%applied.and. &
         .not.candidate%active_event,'DCS1 eligibility suppresses invalid demand and candidate event')
    call evaluate_profile_scheduled_irrigation(p,base,r,h,0,[0],[0.0_real64],[nan], &
         nan,[nan],[nan],[nan],candidate,f,d)
    call require(d%status==IRRIGATION_OK.and..not.d%selection_evaluated.and..not.f%applied.and. &
         .not.candidate%active_event,'profile composition preserves every eligibility gate')
  end do
  r%fixed_event_already_selected=.false.
  write(*,'(a)') 'PPA_IRR_DCS1_ELIGIBILITY_FIXED_PRECEDENCE=PASS'
  p%timing_criterion=IRRIGATION_TIMING_TCS7_PRESSURE_HEAD
  saved=p
  do i=1,10
    p=saved; r%deficit_cm=1.0_real64; r%rainfall_cm=0.0_real64
    select case(i)
    case(1); r%deficit_cm=nan
    case(2); r%rainfall_cm=-1.0_real64
    case(3); r%deficit_cm=1.0e6_real64+1.0_real64
    case(4); r%rainfall_cm=1.0e6_real64+1.0_real64
    case(5); p%rain_threshold_cm=1001.0_real64
    case(6); p%dcs1_correction_mm(1)=101.0_real64
    case(7); p%dcs1_knot_count=0
    case(8); p%depth_criterion=3
    case(9); p%dcs1_dvs(2)=1.0e-310_real64; p%dcs1_correction_mm(2)=100.0_real64
    case(10); p%dcs1_correction_mm(1)=nan
    end select
    call evaluate_scheduled_irrigation_interval(p,base,r,h,candidate,f,d)
    call require(d%status==IRRIGATION_INVALID_PARAMETERS.and..not.f%applied.and..not.candidate%active_event, &
         'invalid DCS1 input publishes nothing')
  end do
  p=saved; r%deficit_cm=nan; r%rainfall_cm=nan; h%pressure_head=0.0_real64
  call evaluate_scheduled_irrigation_interval(p,base,r,h,candidate,f,d)
  call require(d%status==IRRIGATION_OK.and..not.d%triggered,'untriggered demand inputs ignored')
  h%pressure_head=-10.0_real64
  p%depth_criterion=IRRIGATION_DEPTH_DCS2_FIXED
  p%dcs2_knot_count=2; p%dcs2_dvs(1:2)=[0.0_real64,2.0_real64]; p%dcs2_depth_cm=0.5_real64
  p%dcs1_knot_count=0; p%rain_threshold_cm=nan
  call evaluate_scheduled_irrigation_interval(p,base,r,h,candidate,f,d)
  call require(d%status==IRRIGATION_OK.and.abs(f%external_inflow_amount-0.5_real64)<epsilon(1.0_real64), &
       'DCS2 ignores inactive DCS1 fields')
  write(*,'(a)') 'PPA_IRR_DCS1_SCHEDULED_GUARDS_DCS2_PRESERVATION=PASS'
  call evaluate_profile_scheduled_irrigation(p,base,r,h,0,[0],[0.0_real64],[nan], &
       nan,[nan],[nan],[nan],candidate,f,d)
  call require(d%status==IRRIGATION_OK.and.abs(f%external_inflow_amount-0.5_real64)<epsilon(1.0_real64), &
       'profile composition DCS2 ignores invalid unused profile')
  p=saved
  call evaluate_profile_scheduled_irrigation(p,base,r,h,0,[1],[1.0_real64],[0.0_real64], &
       0.5_real64,[0.5_real64],[0.3_real64],[0.1_real64],candidate,f,d)
  call require(d%status==IRRIGATION_INVALID_PARAMETERS.and..not.f%applied.and..not.candidate%active_event, &
       'invalid profile publishes no candidate')
  h%active_nodes=1
  call evaluate_profile_scheduled_irrigation(p,base,r,h,1,[1],[1.0_real64],[0.0_real64], &
       0.5_real64,[0.5_real64],[0.3_real64],[0.1_real64],candidate,f,d)
  call require(d%status==IRRIGATION_INVALID_HYDRAULIC_VIEW.and..not.f%applied, &
       'profile view node mismatch rejected')
  h%active_nodes=2
  r%t0=0.25_real64; r%t1=1.0_real64
  call evaluate_profile_scheduled_irrigation(p,first,r,h,0,[0],[0.0_real64],[nan], &
       nan,[nan],[nan],[nan],candidate,f,d)
  call require(d%status==IRRIGATION_OK.and.f%event_finished,'active composition ignores unused invalid profile')
  call require(abs(f%external_inflow_amount-0.75_real64)<epsilon(1.0_real64),'active composition stored gift')
  r%t0=0.0_real64; r%t1=1.0_real64
  deallocate(h%water_content)
  call evaluate_profile_scheduled_irrigation(p,base,r,h,1,[1],[1.0_real64],[0.0_real64], &
       0.5_real64,[0.5_real64],[0.3_real64],[0.1_real64],candidate,f,d)
  call require(d%status==IRRIGATION_INVALID_HYDRAULIC_VIEW.and..not.f%applied, &
       'profile composition rejects missing water content without indexing')
  allocate(h%water_content(1)); h%water_content=0.2_real64
  call evaluate_profile_scheduled_irrigation(p,base,r,h,1,[1],[1.0_real64],[0.0_real64], &
       0.5_real64,[0.5_real64],[0.3_real64],[0.1_real64],candidate,f,d)
  call require(d%status==IRRIGATION_INVALID_HYDRAULIC_VIEW.and..not.f%applied, &
       'profile composition rejects short water-content array')
  deallocate(h%water_content)
  allocate(h%water_content(2)); h%water_content=0.2_real64
  call evaluate_profile_scheduled_irrigation(p,base,r,h,3,[1],[1.0_real64],[0.0_real64], &
       0.5_real64,[0.5_real64],[0.3_real64],[0.1_real64],candidate,f,d)
  call require(d%status==IRRIGATION_INVALID_PARAMETERS.and..not.f%applied, &
       'profile composition rejects rooted-node count beyond hydraulic view')
  write(*,'(a)') 'PPA_IRR_PROFILE_BYPASS_AND_ARRAY_GUARDS=PASS'
  write(*,'(a)') 'PPA_IRR_PROFILE_COMPOSITION_GUARDS_CONTINUATION=PASS'
contains
  subroutine require(ok,message)
    logical,intent(in)::ok
    character(*),intent(in)::message
    if(ok)return
    write(*,'(a)') message
    error stop 1
  end subroutine
end program
