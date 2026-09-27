program test_composition
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value,ieee_quiet_nan
  use mod_irrigation_process
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_ppa_irr_tcs1_4_composition
  use mod_ppa_irr_tcs1_4_dcs1
  implicit none
  type(scheduled_irrigation_parameters_t)::p
  type(scheduled_irrigation_request_t)::r
  type(irrigation_state_t)::base,candidate,pending
  type(irrigation_flux_result_t)::flux
  type(irrigation_diagnostics_t)::d
  type(process_hydraulic_view_t)::hydraulic
  type(irrigation_timing_selection_t)::selection
  real(real64)::knots(7),values(7)
  real(real64)::actual,nan,correction,depth,rate,duration
  integer::i,j
  p%scheduled_irrigation_enabled=.true.; p%active_nodes=1; p%sensor_node=1; p%single_ssdi_node=1
  p%irr_rate_cm_per_day=1.0_real64; p%dcs2_knot_count=2
  p%dcs2_dvs(1:2)=[0.0_real64,2.0_real64]; p%dcs2_depth_cm=0.5_real64
  r%t0=0.0_real64; r%t1=0.25_real64
  r%selection_opportunity=.true.; r%irrigation_enabled=.true.; r%schedule_enabled=.true.
  r%crop_emerged=.true.; r%irrigation_window_open=.true.
  knots=0.0_real64; knots(2)=2.0_real64; values=0.5_real64
  nan=ieee_value(0.0_real64,ieee_quiet_nan)
  do i=1,4
    p%timing_criterion=i
    call evaluate_tcs1_4_scheduled(p,base,r,knots,values,2,1.0_real64,0.75_real64,0.0_real64, &
         1.0_real64,0.5_real64,0.1_real64,candidate,flux,d)
    if(d%status/=IRRIGATION_OK.or..not.flux%event_started.or..not.candidate%active_event) error stop 'selection'
    if(flux%external_inflow_amount/=0.25_real64.or.candidate%active_event_end/=0.5_real64) error stop 'amount'
    pending=candidate
    r%t0=0.25_real64; r%t1=0.75_real64
    call evaluate_tcs1_4_scheduled(p,pending,r,knots,values,0,0.0_real64,0.0_real64,0.0_real64, &
         0.0_real64,0.0_real64,0.0_real64,candidate,flux,d)
    if(d%status/=IRRIGATION_SPLIT_REQUIRED.or.d%split_time/=0.5_real64) error stop 'pending split'
    r%t1=d%split_time
    call evaluate_tcs1_4_scheduled(p,pending,r,knots,values,0,0.0_real64,0.0_real64,0.0_real64, &
         0.0_real64,0.0_real64,0.0_real64,candidate,flux,d)
    if(d%status/=IRRIGATION_OK.or.candidate%active_event.or..not.flux%event_finished) error stop 'pending finish'
    r%t0=0.0_real64; r%t1=0.25_real64
    call evaluate_tcs1_4_scheduled(p,base,r,knots,values,2,1.0_real64,0.0_real64,0.0_real64, &
         1.0_real64,0.5_real64,1.0_real64,candidate,flux,d)
    if(d%status/=IRRIGATION_OK.or.flux%event_started.or.candidate%active_event) error stop 'false trigger'
    call evaluate_tcs1_4_scheduled(p,base,r,knots,values,0,1.0_real64,0.75_real64,0.0_real64, &
         1.0_real64,0.5_real64,0.1_real64,candidate,flux,d)
    if(d%status/=IRRIGATION_INVALID_PARAMETERS.or.candidate%active_event) error stop 'invalid table'
    r%fixed_event_already_selected=.true.
    call evaluate_tcs1_4_scheduled(p,base,r,knots,values,0,1.0_real64,0.75_real64,0.0_real64, &
         1.0_real64,0.5_real64,0.1_real64,candidate,flux,d)
    if(d%status/=IRRIGATION_OK.or.flux%event_started) error stop 'fixed precedence'
    r%fixed_event_already_selected=.false.
    ! Ordinary entry must not implicitly admit supplied-observation selectors.
    call evaluate_scheduled_irrigation_interval(p,base,r,hydraulic,candidate,flux,d)
    if(d%status/=IRRIGATION_INVALID_PARAMETERS.or.candidate%active_event) error stop 'ordinary admission'
    selection%valid=.true.; selection%triggered=.true.; selection%criterion=i+1
    call evaluate_scheduled_irrigation_interval(p,base,r,hydraulic,candidate,flux,d,selection)
    if(d%status/=IRRIGATION_INVALID_PARAMETERS.or.candidate%active_event) error stop 'mismatched timing'
    call evaluate_tcs1_4_scheduled(p,base,r,knots,values,2,nan,nan,nan,nan,nan,nan,candidate,flux,d)
    if(d%status/=IRRIGATION_INVALID_PARAMETERS.or.candidate%active_event) error stop 'nonfinite observations'
    actual=0.5_real64
    if(i==2) actual=0.75_real64
    if(i==4) values=5.0_real64 ! exactly representable 0.5 cm threshold
    call evaluate_tcs1_4_scheduled(p,base,r,knots,values,2,1.0_real64,0.5_real64,0.0_real64, &
         1.0_real64,0.5_real64,actual,candidate,flux,d)
    if(d%status/=IRRIGATION_OK.or.flux%event_started) error stop 'strict equality triggered'
    values=0.5_real64
    p%depth_criterion=IRRIGATION_DEPTH_DCS1_FIELD_CAPACITY
    call evaluate_tcs1_4_scheduled(p,base,r,knots,values,2,1.0_real64,0.75_real64,0.0_real64, &
         1.0_real64,0.5_real64,0.1_real64,candidate,flux,d)
    if(d%status/=IRRIGATION_INVALID_PARAMETERS.or.candidate%active_event) error stop 'unqualified depth accepted'
    p%depth_criterion=IRRIGATION_DEPTH_DCS2_FIXED
  end do
  write(*,'(a)') 'PPA_IRR_TCS1_4_DCS2_COMPOSITION=PASS'
  write(*,'(a)') 'PPA_IRR_TCS1_4_COMPOSITION_STRICT_GUARDS=PASS'
  p%depth_criterion=IRRIGATION_DEPTH_DCS1_FIELD_CAPACITY
  p%dcs1_knot_count=2; p%dcs1_dvs(1:2)=[0.0_real64,2.0_real64]
  p%dcs1_correction_mm=0.0_real64
  hydraulic%active_nodes=1; allocate(hydraulic%water_content(1)); hydraulic%water_content=0.25_real64
  do i=1,4
    p%timing_criterion=i
    r%t0=0.0_real64; r%t1=0.25_real64
    call profile_call(base,1.0_real64,2)
    if(d%status/=IRRIGATION_OK.or..not.candidate%active_event) error stop 'DCS1 profile selection'
    ! Independent one-cell deficit: 0.75 - 0.25 = 0.5 cm; rate is 1 cm/day.
    if(candidate%active_event_end/=0.5_real64.or.flux%external_inflow_amount/=0.25_real64) &
         error stop 'DCS1 profile depth duration'
    pending=candidate
    r%t0=0.25_real64; r%t1=0.5_real64
    call profile_call(pending,-1.0_real64,0)
    if(d%status/=IRRIGATION_OK.or.candidate%active_event.or..not.flux%event_finished) &
         error stop 'DCS1 pending consumed unused invalid input'
    r%t0=0.0_real64; r%t1=0.25_real64
    call profile_call(base,-1.0_real64,2)
    if(d%status/=IRRIGATION_INVALID_PARAMETERS.or.candidate%active_event) error stop 'DCS1 bad profile'
    call profile_call(base,1.0_real64,0)
    if(d%status/=IRRIGATION_INVALID_PARAMETERS.or.candidate%active_event) error stop 'DCS1 invalid timing'
    r%fixed_event_already_selected=.true.
    call profile_call(base,-1.0_real64,0)
    if(d%status/=IRRIGATION_OK.or.flux%event_started) error stop 'DCS1 fixed precedence'
    r%fixed_event_already_selected=.false.
    values=0.0_real64
    hydraulic%water_content=0.75_real64
    if(i==4) values=10.0_real64
    call profile_call(base,1.0_real64,2)
    if(d%status/=IRRIGATION_OK.or.flux%event_started) error stop 'DCS1 false timing'
    values=0.5_real64
    hydraulic%water_content=0.25_real64
    r%t0=0.25_real64; r%t1=0.75_real64
    call profile_call(pending,-1.0_real64,0)
    if(d%status/=IRRIGATION_SPLIT_REQUIRED.or.d%split_time/=0.5_real64) error stop 'DCS1 pending split'
    if(.not.pending%active_event.or.pending%active_event_end/=0.5_real64) error stop 'DCS1 input mutated'
    r%t0=0.0_real64; r%t1=1.0_real64/4096.0_real64
    p%rain_threshold_cm=0.25_real64
    do j=1,1000
      r%dvs=real(modulo(j,9),real64)/4.0_real64
      r%rainfall_cm=real(modulo(j,5),real64)/4.0_real64
      p%dcs1_correction_mm(1)=real(modulo(j,21)-10,real64)
      p%dcs1_correction_mm(2)=real(modulo(3*j,21)-10,real64)
      correction=p%dcs1_correction_mm(1)+r%dvs* &
           ((p%dcs1_correction_mm(2)-p%dcs1_correction_mm(1))/2.0_real64)
      depth=0.5_real64+correction*0.1_real64
      if(r%rainfall_cm>0.25_real64) depth=depth-r%rainfall_cm
      depth=max(0.0_real64,depth)
      p%depth_limit_enabled=modulo(j,2)==0
      p%minimum_depth_mm=2.0_real64; p%maximum_depth_mm=8.0_real64
      if(p%depth_limit_enabled) depth=min(max(depth,0.2_real64),0.8_real64)
      rate=1.0_real64; duration=depth
      if(depth>rate) then
        rate=depth; duration=1.0_real64
      end if
      call profile_call(base,1.0_real64,2)
      if(depth<=0.0_real64) then
        if(d%status/=IRRIGATION_INVALID_EVENT.or.candidate%active_event) error stop 'DCS1 zero gift'
      else
        if(d%status/=IRRIGATION_OK.or..not.candidate%active_event) error stop 'DCS1 grid selection'
        if(candidate%active_event_end/=duration.or.flux%external_inflow_amount/=rate*r%t1) &
             error stop 'DCS1 independent correction rainfall clip grid'
      end if
    end do
    p%depth_limit_enabled=.false.; p%dcs1_correction_mm=0.0_real64
    r%dvs=0.0_real64; r%rainfall_cm=0.0_real64
  end do
  write(*,'(a)') 'PPA_IRR_TCS1_4_DCS1_PROFILE_INITIAL=PASS'
  write(*,'(a)') 'PPA_IRR_TCS1_4_DCS1_DEPTH_GRID_4000=PASS'
  write(*,'(a)') 'PPA_IRR_TCS1_4_DCS1_SELECTION_PENDING_GUARDS=PASS'
contains
  subroutine profile_call(state,thickness,count)
    type(irrigation_state_t),intent(in)::state
    real(real64),intent(in)::thickness
    integer,intent(in)::count
    call evaluate_tcs1_4_dcs1_profile(p,state,r,hydraulic,1,[1],[thickness],[0.0_real64],1.0_real64, &
         [0.75_real64],[0.5_real64],[0.0_real64],knots,values,count,1.0_real64,0.75_real64,0.0_real64, &
         candidate,flux,d)
  end subroutine
end program
