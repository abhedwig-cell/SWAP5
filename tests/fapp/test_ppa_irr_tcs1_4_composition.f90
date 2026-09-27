program test_composition
  use, intrinsic :: iso_fortran_env, only: real64,int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value,ieee_quiet_nan
  use mod_irrigation_process
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_ppa_irr_tcs1_4_composition
  use mod_ppa_irr_tcs1_4_dcs1
  use mod_ppa_irr_tcs6_composition
  use mod_ppa_irr_weekly_identity
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
  integer::i,j,next_day,day_counter
  type(ppa_weekly_identity_t)::weekly,proposal
  logical::daily,valid
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
  p%timing_criterion=6; p%depth_criterion=IRRIGATION_DEPTH_DCS2_FIXED
  r%t0=0.0_real64; r%t1=0.25_real64
  do i=0,366
    call evaluate_tcs6_scheduled(p,base,r,i,.true.,1.0_real64,5.0_real64,next_day,candidate,flux,d)
    if(d%status/=IRRIGATION_OK) error stop 'weekly composition status'
    if(i>=6) then
      if(next_day/=0.or..not.candidate%active_event) error stop 'weekly due day'
      if(candidate%active_event_end/=0.5_real64) error stop 'weekly gift duration'
    else
      if(next_day/=i+1.or.candidate%active_event) error stop 'weekly counter advance'
    end if
  end do
  call evaluate_tcs6_scheduled(p,base,r,6,.true.,0.5_real64,5.0_real64,next_day,candidate,flux,d)
  if(d%status/=IRRIGATION_OK.or.next_day/=0.or.candidate%active_event) error stop 'weekly no-gift reset'
  call evaluate_tcs6_scheduled(p,base,r,366,.false.,nan,nan,next_day,candidate,flux,d)
  if(d%status/=IRRIGATION_OK.or.next_day/=366.or.candidate%active_event) error stop 'weekly nondaily'
  r%t1=0.75_real64
  call evaluate_tcs6_scheduled(p,base,r,366,.true.,1.0_real64,5.0_real64,next_day,candidate,flux,d)
  if(d%status/=IRRIGATION_SPLIT_REQUIRED.or.next_day/=366) error stop 'weekly split advanced counter'
  r%t1=d%split_time
  call evaluate_tcs6_scheduled(p,base,r,366,.true.,1.0_real64,5.0_real64,next_day,candidate,flux,d)
  if(d%status/=IRRIGATION_OK.or.next_day/=0.or..not.flux%event_finished) error stop 'weekly retry'
  call evaluate_tcs6_scheduled(p,base,r,-1,.true.,1.0_real64,5.0_real64,next_day,candidate,flux,d)
  if(d%status/=IRRIGATION_INVALID_PARAMETERS.or.next_day/=-1) error stop 'weekly invalid counter'
  call evaluate_scheduled_irrigation_interval(p,base,r,hydraulic,candidate,flux,d)
  if(d%status/=IRRIGATION_INVALID_PARAMETERS) error stop 'weekly ordinary entry admitted'
  write(*,'(a)') 'PPA_IRR_TCS6_EXPLICIT_COUNTER_PROPOSAL=PASS'
  day_counter=0
  do i=1,14
    r%t0=real(i-1,real64); r%t1=r%t0+0.25_real64
    call evaluate_tcs6_scheduled(p,base,r,day_counter,.true.,0.0_real64,5.0_real64, &
         next_day,candidate,flux,d)
    if(d%status/=IRRIGATION_OK.or.candidate%active_event.or.next_day/=modulo(i,7)) &
         error stop 'weekly consecutive no-gift days'
    day_counter=next_day ! Test-only acceptance simulation, not a runtime owner.
  end do
  r%t0=0.0_real64; r%t1=0.25_real64
  call evaluate_tcs6_scheduled(p,base,r,6,.true.,1.0_real64,5.0_real64,next_day,candidate,flux,d)
  if(d%status/=IRRIGATION_OK.or..not.candidate%active_event) error stop 'weekly pending setup'
  pending=candidate
  r%t0=0.25_real64; r%t1=0.5_real64
  call evaluate_tcs6_scheduled(p,pending,r,0,.true.,nan,nan,next_day,candidate,flux,d)
  if(d%status/=IRRIGATION_OK.or.next_day/=0.or.candidate%active_event.or..not.flux%event_finished) &
       error stop 'weekly pending selector evaluated'
  if(.not.pending%active_event) error stop 'weekly pending input mutated'
  r%t0=0.0_real64; r%t1=0.25_real64
  r%fixed_event_already_selected=.true.
  call evaluate_tcs6_scheduled(p,base,r,6,.true.,nan,nan,next_day,candidate,flux,d)
  if(d%status/=IRRIGATION_OK.or.next_day/=6.or.candidate%active_event) error stop 'weekly fixed precedence'
  r%fixed_event_already_selected=.false.; r%selection_opportunity=.false.
  call evaluate_tcs6_scheduled(p,base,r,6,.true.,nan,nan,next_day,candidate,flux,d)
  if(d%status/=IRRIGATION_OK.or.next_day/=6.or.candidate%active_event) error stop 'weekly ineligible'
  r%selection_opportunity=.true.
  do i=1,4
    actual=5.0_real64; depth=1.0_real64; day_counter=6
    if(i==1) actual=nan
    if(i==2) depth=nan
    if(i==3) actual=21.0_real64
    if(i==4) day_counter=367
    call evaluate_tcs6_scheduled(p,base,r,day_counter,.true.,depth,actual,next_day,candidate,flux,d)
    if(d%status/=IRRIGATION_INVALID_PARAMETERS.or.next_day/=day_counter.or.candidate%active_event) &
         error stop 'weekly malformed selector input'
  end do
  write(*,'(a)') 'PPA_IRR_TCS6_SEQUENCE_PENDING_ELIGIBILITY_GUARDS=PASS'
  if(.not.valid_weekly_identity(weekly)) error stop 'weekly default metadata'
  call prepare_weekly_day(weekly,.true.,10_int64,proposal,daily,valid)
  if(valid.or.daily) error stop 'weekly disabled invocation'
  weekly%enabled=.true.
  call prepare_weekly_day(weekly,.true.,10_int64,proposal,daily,valid)
  if(.not.valid.or..not.daily.or.proposal%last_day/=10_int64.or.weekly%day_bound) &
       error stop 'weekly first detached proposal'
  weekly=proposal
  call prepare_weekly_day(weekly,.true.,10_int64,proposal,daily,valid)
  if(.not.valid.or.daily.or.proposal%dayfix/=366) error stop 'weekly duplicate identity'
  call prepare_weekly_day(weekly,.true.,11_int64,proposal,daily,valid)
  if(.not.valid.or..not.daily.or.proposal%last_day/=11_int64) error stop 'weekly consecutive identity'
  do i=8,13
    if(i==10.or.i==11) cycle
    call prepare_weekly_day(weekly,.true.,int(i,int64),proposal,daily,valid)
    if(valid.or.daily.or.proposal%last_day/=10_int64) error stop 'weekly gap/backward identity'
  end do
  call prepare_weekly_day(weekly,.false.,-1_int64,proposal,daily,valid)
  if(.not.valid.or.daily.or.proposal%last_day/=10_int64) error stop 'weekly non-daily identity'
  weekly%last_day=huge(0_int64)-1_int64
  call prepare_weekly_day(weekly,.true.,huge(0_int64),proposal,daily,valid)
  if(.not.valid.or..not.daily) error stop 'weekly ordinal upper bound'
  weekly=proposal
  call prepare_weekly_day(weekly,.true.,huge(0_int64),proposal,daily,valid)
  if(.not.valid.or.daily) error stop 'weekly ordinal terminal duplicate'
  weekly%dayfix=367
  if(valid_weekly_identity(weekly)) error stop 'weekly malformed metadata'
  write(*,'(a)') 'PPA_IRR_TCS6_DAILY_IDENTITY_PROPOSAL=PASS'
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
