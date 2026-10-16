"""Existing actual adaptive-root driver, with consecutive TCS6 weekly opportunities.

The producer/consumer, root, crop, thermal and mass assertions stay in place.
No native weather codec is synthesized here; this is explicitly opaque science.
"""
from pathlib import Path
import sys

def prepare(root,target,dcs=1,trigger=True):
 sys.path.insert(0,str(root/'tests/mc-irr01'))
 from material_root_cycle_driver import prepare as material
 material(root,target,6,dcs,True);s=target.read_text()
 def replace(a,b):
  nonlocal s
  assert s.count(a)==1,(s.count(a),a);s=s.replace(a,b)
 replace('      do d=0,6','      do d=0,10')
 replace('    real(real64)::delivered_amount,oracle_depth,oracle_before',
 '''    real(real64)::delivered_amount,oracle_depth,oracle_before,invalid_delivered
    type(fmr_allocated_irrigation_state_t)::prior_irrigation,restart_irrigation
    type(fmr_irrigation_allocation_t)::invalid_allocation
    integer::expected_week,invalid_selection,weekly_events
    real(real64)::expected_daily_amounts(0:10),day_amount
    integer::expected_daily_weeks(0:10)''')
 replace('    tc%file_weather_irrigation_field_capacity_head_cm=0._real64',f'''    tc%file_weather_irrigation_field_capacity_head_cm={0 if trigger else -500}._real64
    tc%file_weather_irrigation_depth%tcs6_threshold_mm={0 if trigger else 20}._real64''')
 replace('      maximum_residual=0;total_reduction=0;stress_cases=0','      maximum_residual=0;total_reduction=0;stress_cases=0;weekly_events=0')
 replace("            call require(oracle_trigger.eqv..true.,'independent trigger/nontrigger discriminator')",f"            call require(oracle_trigger.eqv.({'.true.'if trigger else'.false.'}.and.mod(d-2,7)==0),'independent weekly trigger/nontrigger discriminator')")
 replace("              call require(.not.irrigation%management%event%active_event.and..not.irrigation%receipt%present, &\n                'nontrigger neither starts event nor freezes provider')", """              call require(.not.irrigation%management%event%active_event, &
                'nontrigger neither starts event nor duplicates prior provider')""")
 # Independent source recurrence uses the already snapshot actual accepted
 # counter; the separate daily formula below checks that the caller advances it once.
 replace('    integer::i,st\n    logical::ok\n    trigger=.false.;depth=0;awlh=0;awmh=0;awah=0;cdef=0', '''    integer::i,st,selection
    type(fmr_allocated_irrigation_state_t)::weekly_state
    real(real64)::delivered
    logical::ok
    trigger=.false.;depth=0;awlh=0;awmh=0;awah=0;cdef=0''')
 replace('    select case(config%file_weather_irrigation_sensor%timing_criterion)\n    case(2)', '''    select case(config%file_weather_irrigation_sensor%timing_criterion)
    case(6)
      call app%snapshot_weather_irrigation(weekly_state,selection,delivered,st)
      call require(st==FMR_APP_BOOT_OK,'literal reads accepted existing week owner')
      if(weekly_state%management%policy%weekly_day_counter+1>=7) &
        trigger=10._real64*cdef>config%file_weather_irrigation_depth%tcs6_threshold_mm
    case(2)''')
 # First internally committed segment is the one daily consumption point.
 anchor='''        call literal_irrigation_selection(ta,cs,tc,wr,oracle_trigger,oracle_depth)
        do q=0,63'''
 replace(anchor,'''        call literal_irrigation_selection(ta,cs,tc,wr,oracle_trigger,oracle_depth)
        prior_irrigation=irrigation
        if(j==2.and.d==9)then
          call require(irrigation%management%policy%weekly_day_counter==6,'restart immediately before real week boundary')
          call ta%capture_weather_crop_continuation(cs,saved,st);call require(st==FMR_APP_BOOT_OK,'capture week boundary')
          call ta%close(st);cs=kernel_committed_state_t()
          call ta%restore_weather_crop_continuation(saved,cs,st);call require(st==FMR_APP_BOOT_OK,'restore week boundary')
        end if
        do q=0,63
          if(q==0.and.wo%crop_emerged)then
            invalid_allocation=allocation;invalid_allocation%fraction=ieee_value(0._real64,ieee_quiet_nan)
            call ta%run_weather_interval(wr,real(d,real64),real(d,real64)+1._real64/64._real64, &
              forcing_config,canopy,rr,st,cs,invalid_allocation)
            call require(st/=FMR_APP_BOOT_OK,'invalid trial before weekly selection rejected')
            call ta%snapshot_weather_irrigation(restart_irrigation,invalid_selection,invalid_delivered,st)
            call require(st==FMR_APP_BOOT_OK.and.invalid_delivered==oracle_before, 'rejection retains delivered water')
            call require(restart_irrigation%management%policy%weekly_day_counter== &
              prior_irrigation%management%policy%weekly_day_counter,'rejection cannot consume weekly opportunity')
          end if''')
 anchor="          call require(abs(rr(1)%mass%residual)<=HARD_MASS_GATE,'rooted hard physical water mass conservation')"
 replace(anchor,'''          expected_week=366
          if(wo%crop_emerged)expected_week=mod(d-2,7)
          call ta%snapshot_weather_irrigation(irrigation,selected_day,delivered_amount,st)
          call require(st==FMR_APP_BOOT_OK.and.irrigation%management%policy%weekly_day_counter==expected_week, &
            '64 actual segments consume exactly one eligible calendar day')
          call require(selected_day==tc%file_weather_epoch_day+d,'only real accepted day is marked consumed')
          if(q==0.and.j==2)then
            call ta%capture_weather_crop_continuation(cs,saved,st);call require(st==FMR_APP_BOOT_OK,'joint after daily selection')
            call ta%close(st);cs=kernel_committed_state_t()
            call ta%restore_weather_crop_continuation(saved,cs,st);call require(st==FMR_APP_BOOT_OK,'joint active/no-event daily restore')
            call ta%snapshot_weather_irrigation(restart_irrigation,invalid_selection,invalid_delivered,st)
            call require(st==FMR_APP_BOOT_OK.and.invalid_selection==selected_day.and.invalid_delivered==delivered_amount, &
              'joint restore preserves consumed day and cumulative water exactly')
            call require(restart_irrigation%management%policy%weekly_day_counter==expected_week.and. &
              (restart_irrigation%management%event%active_event.eqv.irrigation%management%event%active_event), &
              'joint restore preserves existing weekly/event owner')
          end if
'''+anchor)
 a=s.index('      if(wo%crop_emerged)then\n        call require(irrigation%receipt%present')
 b=s.index('      prior_uptake=uptake;prior_wr=wr',a)
 s=s[:a]+'''      if(oracle_trigger)weekly_events=weekly_events+1
      day_amount=delivered_amount-oracle_before
      if(j==1)then
        expected_daily_amounts(d)=day_amount;expected_daily_weeks(d)=irrigation%management%policy%weekly_day_counter
      else
        call require(day_amount==expected_daily_amounts(d).and. &
          irrigation%management%policy%weekly_day_counter==expected_daily_weeks(d),'continuous/opaque daily water/week exact identity')
      end if
      call require(.not.irrigation%management%event%active_event,'no carry past one-day event end')
      if(oracle_trigger)then
        call require(irrigation%receipt%present.and.irrigation%receipt%allocation%revision==int(d,int64),'weekly event frozen provider')
      else if(wo%crop_emerged)then
        call require(day_amount==0._real64,'nonopportunity or failed threshold delivers no water')
      end if
'''+s[b:]
 replace("      call require(depth_events>=4,'all accepted daily depth events checked')", f"      call require(weekly_events=={2 if trigger else 0},'two real week opportunities, no repeated events')\n      call require(depth_events>=4,'all accepted daily depth events checked')")
 # Exercise the original actual-failed-dispatch/retry probe under TCS6 using
 # this actual rooted configuration, preserving original assertions.
 replace('  subroutine managed_failure_probe()','  subroutine managed_failure_probe(tc0)\n    type(fmr_production_application_config_t),intent(in)::tc0')
 replace('    tc=config;tc%numerical%max_committed_substeps=1', '    tc=tc0;tc%numerical%max_committed_substeps=1')
 replace('    call configure_managed_sensor(tc,7,1)', '''    call configure_managed_sensor(tc,6,1)
    tc%file_weather_irrigation_depth%tcs6_threshold_mm=0._real64
    tc%file_weather_irrigation_field_capacity_head_cm=0._real64''')
 replace('    call managed_failure_probe()','    call managed_failure_probe(config)')
 anchor='    do j=1,2\n      maximum_residual=0;total_reduction=0;stress_cases=0;weekly_events=0'
 replace(anchor,'    call managed_failure_probe(tc)\n'+anchor)
 # Source probe checks initial counter after every rejected actual dispatcher.
 s=s.replace("'managed incomplete candidate consumes neither selection, allocation nor event')", "'managed incomplete candidate consumes neither selection, allocation nor event')\n      call require(ir%management%policy%weekly_day_counter==366,'actual failed trial retains TCS6 initial366')")
 replace("  print '(a)','MC_IRR01_MATERIAL_ROOT_POLICY_PHYSICAL_LITERAL_RESTART=PASS'", "  print '(a)','MC_IRR01_MATERIAL_ROOT_POLICY_PHYSICAL_LITERAL_RESTART=PASS'\n  print '(a)','TCS6_REAL_WEATHER_WEEK_ROOT_MASS_OPAQUE_RETRY=PASS'")
 target.write_text(s);return target
