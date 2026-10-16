  subroutine test_managed_weather_application()
    type(fmr_production_application_config_t)::tc,bad
    type(fmr_production_application_bootstrap_t)::ta,other
    type(kernel_committed_state_t)::cs,origin,ss,none
    type(fmr_weather_crop_application_continuation_t)::saved
    type(fmr_application_crop_daystart_controls_t)::c
    type(wofost_crop_owner_state_t)::empty_owner
    type(wofost_rate_parameter_bundle_t)::bundle
    type(swap_daily_weather_record_t)::wr
    type(fmr_serialized_column_result_t),allocatable::rr(:)
    type(fmr_irrigation_allocation_t)::allocation,wrong
    type(fmr_allocated_irrigation_state_t)::ir,prior
    real(real64),allocatable::before(:),after(:),derivative(:)
    class(transaction_state_t),allocatable::physical
    real(real64)::start,mid,finish,delivered,previous,wd,tmn,tmx,wrain,wet,amount,dt,witness
    integer::criterion,nodes,day0,st,j,q,selection,old_selection,neg
    logical::ok
    call make_bundle(bundle)
    c%germ_mode=0;c%swprep=0;c%swsow=0
    c%zprep=-1._real64;c%zsow=-1._real64;c%ztempsow=-1._real64;c%zgerm=-1._real64
    do criterion=7,8
    do nodes=1,3,2
    do day0=20,21
      tc=config;start=real(day0-20,real64);mid=start+0.0625_real64;finish=start+1._real64
      tc%initial_time=start
      tc%tiles(1)%base_forcing%drainage_flux_by_level=0._real64
      tc%tiles(1)%base_forcing%subsurface_irrigation_source=0._real64
      call configure_managed_sensor(tc,criterion,nodes)
      allocation=fmr_irrigation_allocation_t(source_id=41_int64,revision=2_int64, &
        valid_t0=start,valid_t1=start+0.03_real64,fraction=0.5_real64)
      call read_swap_daily_weather_file(trim(path),1999,1,day0,wr,st)
      call require(st==SWAP_WEATHER_FILE_OK,'managed authentic full-day record')
      call wr%values(wd,tmn,tmx,wrain,wet,ok);call require(ok,'managed source weather values')
      bad=tc;bad%file_weather_irrigation_depth%depth_criterion=1
      call other%initialize(bad,st);call require(st/=FMR_APP_BOOT_OK,'unqualified DCS1 profile refused')
      bad=tc;bad%file_weather_irrigation_sensor%salinity_excess_enabled=.true.
      call other%initialize(bad,st);call require(st/=FMR_APP_BOOT_OK,'unqualified bottom7 salt profile refused')
      call ta%initialize(tc,st);call require(st==FMR_APP_BOOT_OK,'managed application actual initialization')
      call ta%initialize_weather_crop_daystart(wr,c,empty_owner,2_int64,932_int64,cs,st,100._real64,bundle)
      call require(st==FMR_APP_BOOT_OK,'managed uses authentic committed emerged owner')
      call ta%copy_committed_for_crop(1,origin,st);before=managed_soil_values(origin)
      call ta%run_weather_interval(wr,start,mid,forcing_config,canopy,rr,st)
      call require(st/=FMR_APP_BOOT_OK,'managed cannot use caller canopy instead of crop authority')
      call cs%snapshot(physical,ok);call require(ok,'managed foreign owner negative snapshot')
      call none%initialize(999_int64,physical,ok,start);call require(ok,'managed foreign same-time crop owner')
      call ta%run_weather_interval(wr,start,mid,forcing_config,canopy,rr,st,none,allocation)
      call require(st/=FMR_APP_BOOT_OK,'foreign crop lineage cannot select or publish irrigation')
      none=kernel_committed_state_t()
      do neg=1,6
        wrong=allocation
        select case(neg)
        case(1);wrong%source_id=0_int64
        case(2);wrong%revision=-1_int64
        case(3);wrong%fraction=-0.1_real64
        case(4);wrong%fraction=1.1_real64
        case(5);wrong%valid_t1=start
        case(6);wrong%fraction=ieee_value(0._real64,ieee_quiet_nan)
        end select
        call ta%run_weather_interval(wr,start,mid,forcing_config,canopy,rr,st,cs,wrong)
        call require(st/=FMR_APP_BOOT_OK,'invalid allocation refused before physical publication')
        call ta%copy_committed_for_crop(1,ss,st);after=managed_soil_values(ss)
        call require(all(transfer(before,[0_int64],size(before))==transfer(after,[0_int64],size(after))), &
          'invalid allocation preserves actual physical/history state')
        call ta%snapshot_weather_irrigation(ir,selection,delivered,st)
        call require(st==FMR_APP_BOOT_OK.and.selection==-1.and.delivered==0._real64.and..not.ir%receipt%present, &
          'invalid allocation preserves actual event/selection/supply state')
      end do
      call ta%run_weather_interval(wr,start,mid,forcing_config,canopy,rr,st,cs,allocation)
      if(st/=FMR_APP_BOOT_OK)then
        print *,'MANAGED_STATUS',st,criterion,nodes,day0
        if(allocated(rr))print *,'MANAGED_KERNEL',rr%kernel_status,rr%temporal_rejections,rr%accepted_substeps
      end if
      call require(st==FMR_APP_BOOT_OK.and.allocated(rr),'managed actual partial active-event physical execution')
      call require(size(rr)==1,'first segment no hidden execution')
      call ta%snapshot_weather_irrigation(ir,selection,delivered,st)
      call require(st==FMR_APP_BOOT_OK.and.ir%management%event%active_event.and.ir%receipt%present, &
        'active event and provider receipt published jointly')
      call require(ir%receipt%allocation%source_id==41_int64.and.ir%receipt%allocation%revision==2_int64, &
        'actual frozen provider identity')
      call require(abs(ir%management%event%active_event_end-start-0.125_real64)<1.e-14_real64, &
        'literal depth0.8 -> cap0.4 -> allocation0.5 -> duration0.125')
      call require(abs(delivered-real(nodes,real64)*1.6_real64*(mid-start))<1.e-14_real64, &
        'literal per-compartment SSDI mapping, no total-profile renormalization')
      call managed_mass(rr,wrain,wet,real(nodes,real64)*1.6_real64)
      call ta%capture_weather_crop_continuation(cs,saved,st)
      call require(st==FMR_APP_BOOT_OK,'actual active-event common physical/crop/weather/allocation restart')
      previous=delivered
      if(trim(continuation_mode)=='restart')then
        call ta%close(st);cs=kernel_committed_state_t()
        call ta%restore_weather_crop_continuation(saved,cs,st)
        call require(st==FMR_APP_BOOT_OK,'restore active event with expired external allocation')
        call ta%snapshot_weather_irrigation(ir,selection,delivered,st)
        call require(delivered==previous.and.ir%receipt%allocation%revision==2_int64,'restore frozen amount and provider')
      end if
      wrong=fmr_irrigation_allocation_t() ! expired/missing/changing external provider is irrelevant inside selected event.
      call ta%run_weather_interval(wr,mid,start+9._real64/64._real64,forcing_config,canopy,rr,st,cs,wrong)
      if(st/=FMR_APP_BOOT_OK)then
        print *,'MANAGED_TAIL_STATUS',st,criterion,nodes,day0
        if(allocated(rr))print *,'MANAGED_TAIL_KERNEL',rr%kernel_status,rr%temporal_rejections,rr%accepted_substeps
      end if
      call require(st==FMR_APP_BOOT_OK.and.allocated(rr),'managed split expiry then complete weather tail')
      call require(size(rr)==2,'request spanning event expiry produces two actual committed segments')
      call require(rr(1)%mass%interval_t1==start+0.125_real64.and.rr(2)%mass%interval_t0==start+0.125_real64, &
        'exact source event endpoint; tail preserved')
      call managed_mass(rr(1:1),wrain,wet,real(nodes,real64)*1.6_real64)
      call managed_mass(rr(2:2),wrain,wet,0._real64)
      call ta%snapshot_weather_irrigation(ir,selection,delivered,st)
      call require(abs(delivered-real(nodes,real64)*0.2_real64)<1.e-13_real64.and..not.ir%management%event%active_event, &
        'complete gift once; tail and repeat sensor cannot reselect today')
      call require(selection==swap_weather_calendar_day(1999,1,day0),'selection identity is authenticated weather day')
      ! Use the admitted weather owner's64-interval daily schedule for the
      ! remaining full day. A single0.875-day aggregate accumulated1608
      ! accepted substeps and2.535e-12cm residual; retained as failed evidence.
      ! Keep full authentic forcing, physical duration and1e-12 assertion.
      do q=9,63
        call ta%run_weather_interval(wr,start+real(q,real64)/64._real64, &
          start+real(q+1,real64)/64._real64,forcing_config,canopy,rr,st,cs,wrong)
        call require(st==FMR_APP_BOOT_OK,'managed full daily source-off continuation')
        call managed_mass(rr,wrain,wet,0._real64)
      end do
      call ta%copy_committed_for_crop(1,ss,st);after=managed_soil_values(ss)
      do j=1,size(after)
        write(*,'(a,4(i0,1x),z16.16)')'MANAGED_FINAL_BITS=',criterion,nodes,day0,j,transfer(after(j),0_int64)
      end do
      call ta%run_weather_interval(wr,start,mid,forcing_config,canopy,rr,st,cs,allocation)
      call require(st/=FMR_APP_BOOT_OK,'stale physical segment cannot replay selected event')
      call ta%snapshot_weather_irrigation(ir,selection,amount,st)
      call require(amount==delivered,'stale segment cannot duplicate water delivery')
      call ta%capture_weather_crop_continuation(cs,saved,st)
      call require(st==FMR_APP_BOOT_OK,'completed weather day common continuation')
      call ta%close(st);cs=kernel_committed_state_t()
    end do
    end do
    end do
    call managed_failure_probe()
    print '(a)','MC_IRR01_MANAGED_WEATHER_SENSOR_SSDI_ALLOCATION_MASS_RESTART=PASS'
  end subroutine

  subroutine managed_mass(rr,rain,et,source_rate)
    type(fmr_serialized_column_result_t),intent(in)::rr(:)
    real(real64),intent(in)::rain,et,source_rate
    real(real64)::dt,expected
    integer::i
    do i=1,size(rr)
      call require(rr(i)%completed.and.rr(i)%committed.and.rr(i)%mass%complete,'actual managed complete committed mass')
      call require(abs(rr(i)%mass%residual)<=HARD_MASS_GATE,'unchanged managed hard mass gate')
      dt=rr(i)%mass%interval_t1-rr(i)%mass%interval_t0
      expected=(max(0._real64,0.1_real64*(rain-et))+source_rate)*dt
      call require(abs(rr(i)%mass%total_in-expected)<=HARD_MASS_GATE,'independent surface rain/ET plus spatial source ledger')
      call require(abs(rr(i)%mass%storage_change-(rr(i)%mass%total_in-rr(i)%mass%total_out))<=HARD_MASS_GATE, &
        'independent accepted full storage balance')
    end do
  end subroutine

  function managed_soil_values(cs)result(values)
    type(kernel_committed_state_t),intent(in)::cs
    real(real64),allocatable::values(:),history(:)
    class(transaction_state_t),allocatable::physical
    logical::ok
    call cs%snapshot(physical,ok);call require(ok,'managed actual physical snapshot')
    select type(physical)
    type is(fmr_b110_temporal_indicator_state_t)
      call physical%temporal_history_snapshot(history,ok);call require(ok,'managed retained numerical history')
      values=[physical%pressure_head,physical%water_content,physical%ponding_depth,physical%groundwater_level,history]
    class default
      call require(.false.,'managed actual temporal Richards state')
    end select
  end function

  subroutine configure_managed_sensor(tc,criterion,nodes)
    type(fmr_production_application_config_t),intent(inout)::tc
    integer,intent(in)::criterion,nodes
      tc%file_weather_irrigation=.true.
      tc%file_weather_irrigation_sensor%scheduled_irrigation_enabled=.true.
      tc%file_weather_irrigation_sensor%active_nodes=numnod
      tc%file_weather_irrigation_sensor%sensor_node=2
      tc%file_weather_irrigation_sensor%single_ssdi_node=2
      if(nodes==3)then
        tc%file_weather_irrigation_sensor%ssdi_first_node=1
        tc%file_weather_irrigation_sensor%ssdi_last_node=3
      end if
      tc%file_weather_irrigation_sensor%timing_criterion=criterion
      tc%file_weather_irrigation_sensor%irr_rate_cm_per_day=1.6_real64
      tc%file_weather_irrigation_sensor%tcs7_knot_count=2
      tc%file_weather_irrigation_sensor%tcs7_dvs(1:2)=[0._real64,2._real64]
      tc%file_weather_irrigation_sensor%tcs7_pressure_head(1:2)=-1._real64
      tc%file_weather_irrigation_sensor%tcs8_knot_count=2
      tc%file_weather_irrigation_sensor%tcs8_dvs(1:2)=[0._real64,2._real64]
      tc%file_weather_irrigation_sensor%tcs8_water_content(1:2)=1._real64
      tc%file_weather_irrigation_depth%depth_criterion=2
      tc%file_weather_irrigation_depth%dcs2_knot_count=2
      tc%file_weather_irrigation_depth%dcs2_dvs(1:2)=[0._real64,2._real64]
      tc%file_weather_irrigation_depth%dcs2_depth_cm(1:2)=0.8_real64
      tc%file_weather_irrigation_depth%depth_limit_enabled=.true.
      tc%file_weather_irrigation_depth%maximum_depth_cm=0.4_real64
  end subroutine

  subroutine managed_failure_probe()
    type(fmr_production_application_bootstrap_t)::ta,clean
    type(fmr_production_application_config_t)::tc
    type(kernel_committed_state_t)::cs,ccs,ss,origin
    type(fmr_weather_crop_application_continuation_t)::saved
    type(fmr_application_crop_daystart_controls_t)::c
    type(wofost_crop_owner_state_t)::owner
    type(wofost_rate_parameter_bundle_t)::bundle
    type(swap_daily_weather_record_t)::wr
    type(fmr_irrigation_allocation_t)::allocation
    type(fmr_allocated_irrigation_state_t)::ir
    type(fmr_serialized_column_result_t),allocatable::rr(:),cr(:)
    real(real64),allocatable::before(:),after(:),expected(:)
    real(real64)::amount,initial_amount
    real(real64)::short_end
    integer::st,j,selection,initial_selection
    tc=config;tc%numerical%max_committed_substeps=1
    tc%tiles(1)%base_forcing%subsurface_irrigation_source=0._real64
    tc%tiles(1)%base_forcing%drainage_flux_by_level=0._real64
    call configure_managed_sensor(tc,7,1)
    allocation=fmr_irrigation_allocation_t(source_id=41_int64,revision=2_int64, &
      valid_t0=0._real64,valid_t1=1._real64,fraction=0.5_real64)
    call read_swap_daily_weather_file(trim(path),1999,1,20,wr,st)
    call require(st==SWAP_WEATHER_FILE_OK,'managed rejection authentic weather')
    call make_bundle(bundle)
    c%swprep=0;c%swsow=0;c%germ_mode=0
    c%zprep=-1._real64;c%zsow=-1._real64;c%zgerm=-1._real64;c%ztempsow=-1._real64
    call ta%initialize(tc,st);call require(st==FMR_APP_BOOT_OK,'managed limited application')
    call ta%initialize_weather_crop_daystart(wr,c,owner,2_int64,932_int64,cs,st,100._real64,bundle)
    call require(st==FMR_APP_BOOT_OK,'managed failure actual crop initialization')
    call ta%copy_committed_for_crop(1,origin,st);before=managed_soil_values(origin)
    call ta%capture_weather_crop_continuation(cs,saved,st)
    call require(st==FMR_APP_BOOT_OK,'managed failure common origin continuation')
    call clean%restore_weather_crop_continuation(saved,ccs,st)
    call require(st==FMR_APP_BOOT_OK,'managed failure clean comparison origin')
    do j=1,2
      call ta%run_weather_interval(wr,0._real64,0.5_real64,forcing_config,canopy,rr,st,cs,allocation)
      call require(st/=FMR_APP_BOOT_OK.and.allocated(rr),'managed real incomplete dispatcher candidate')
      call require(size(rr)==1,'managed failed first event segment')
      call require(rr(1)%accepted_substeps==1.and..not.rr(1)%completed.and..not.rr(1)%committed, &
        'managed internally accepted prefix discarded before event publication')
      call ta%copy_committed_for_crop(1,ss,st);after=managed_soil_values(ss)
      call require(all(transfer(before,[0_int64],size(before))==transfer(after,[0_int64],size(after))), &
        'managed incomplete candidate preserves exact committed soil/history')
      call ta%snapshot_weather_irrigation(ir,selection,amount,st)
      call require(selection==-1.and.amount==0._real64.and..not.ir%receipt%present.and..not.ir%management%event%active_event, &
        'managed incomplete candidate consumes neither selection, allocation nor event')
      call ta%capture_weather_crop_continuation(cs,saved,st)
      call require(st==FMR_APP_BOOT_OK,'managed repeated incomplete candidate joint continuation')
    end do
    if(trim(continuation_mode)=='restart')then
      call ta%close(st);cs=kernel_committed_state_t()
      call ta%restore_weather_crop_continuation(saved,cs,st)
      call require(st==FMR_APP_BOOT_OK,'managed restart after actual rejected internally progressed candidate')
    end if
    short_end=1.e-6_real64
    do j=1,21
      call ta%run_weather_interval(wr,0._real64,short_end,forcing_config,canopy,rr,st,cs,allocation)
      if(st==FMR_APP_BOOT_OK)exit
      call ta%copy_committed_for_crop(1,ss,st);after=managed_soil_values(ss)
      call require(all(transfer(before,[0_int64],size(before))==transfer(after,[0_int64],size(after))), &
        'each smaller failed retry preserves committed physical origin')
      call ta%snapshot_weather_irrigation(ir,selection,amount,st)
      call require(selection==-1.and.amount==0._real64.and..not.ir%receipt%present, &
        'each smaller failed retry preserves irrigation origin')
      short_end=short_end*.5_real64
    end do
    call require(j<=21.and.rr(1)%committed,'managed smaller retry commits')
    call clean%run_weather_interval(wr,0._real64,short_end,forcing_config,canopy,cr,st,ccs,allocation)
    call require(st==FMR_APP_BOOT_OK.and.cr(1)%committed,'managed clean small comparison')
    call ta%copy_committed_for_crop(1,ss,st);before=managed_soil_values(ss)
    call clean%copy_committed_for_crop(1,ss,st);expected=managed_soil_values(ss)
    call require(all(transfer(before,[0_int64],size(before))==transfer(expected,[0_int64],size(expected))), &
      'managed smaller retry equals clean origin bitwise')
    call ta%snapshot_weather_irrigation(ir,initial_selection,initial_amount,st)
    call require(initial_amount>0._real64.and.ir%management%event%active_event,'managed successful prefix owns event')
    call ta%run_weather_interval(wr,short_end,0.5_real64,forcing_config,canopy,rr,st,cs,allocation)
    call require(st/=FMR_APP_BOOT_OK.and.allocated(rr),'managed failed tail retains completed prefix')
    call ta%copy_committed_for_crop(1,ss,st);after=managed_soil_values(ss)
    call require(all(transfer(before,[0_int64],size(before))==transfer(after,[0_int64],size(after))), &
      'managed prior completed physical prefix never reset to daystart')
    call ta%snapshot_weather_irrigation(ir,selection,amount,st)
    call require(amount==initial_amount.and.selection==initial_selection.and.ir%management%event%active_event, &
      'managed failed tail retains common event and cumulative delivery prefix')
    call ta%capture_weather_crop_continuation(cs,saved,st)
    call require(st==FMR_APP_BOOT_OK,'managed accepted-prefix joint restart after failed tail')
    if(trim(continuation_mode)=='restart')then
      call ta%close(st);cs=kernel_committed_state_t()
      call ta%restore_weather_crop_continuation(saved,cs,st)
      call require(st==FMR_APP_BOOT_OK,'managed restore exact accepted prefix after failed tail')
    end if
    call ta%run_weather_interval(wr,short_end,2._real64*short_end,forcing_config,canopy,rr,st,cs,allocation)
    call require(st==FMR_APP_BOOT_OK.and.rr(1)%committed,'managed second small retry commits')
    call clean%run_weather_interval(wr,short_end,2._real64*short_end,forcing_config,canopy,cr,st,ccs,allocation)
    call require(st==FMR_APP_BOOT_OK.and.cr(1)%committed,'managed clean second comparison')
    call ta%copy_committed_for_crop(1,ss,st);after=managed_soil_values(ss)
    call clean%copy_committed_for_crop(1,ss,st);expected=managed_soil_values(ss)
    call require(all(transfer(after,[0_int64],size(after))==transfer(expected,[0_int64],size(expected))), &
      'managed common-prefix retry equals clean two-segment state bitwise')
    call ta%close(st);call clean%close(st)
    print '(a)','MC_IRR01_MANAGED_INCOMPLETE_PREFIX_ROLLBACK_RETRY_RESTART=PASS'
  end subroutine
