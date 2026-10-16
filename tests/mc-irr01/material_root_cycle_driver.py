"""Existing adaptive rooted weather physics with independent irrigation source oracle."""
from pathlib import Path
import sys

def prepare(root,target,criterion=2,dcs=1,trigger=True):
 sys.path.insert(0,str(root/'tests/mc-irr01'))
 from managed_root_cycle_driver import prepare as managed
 nodes=3 if criterion==3 else 1
 managed(root,target,criterion,nodes);s=target.read_text()
 def replace(a,b):
  nonlocal s
  assert s.count(a)==1,(s.count(a),a);s=s.replace(a,b)
 anchor='    tc%file_weather_irrigation_depth%maximum_depth_cm=.04_real64'
 config=f'''
    tc%file_weather_irrigation_field_capacity_head_cm=0._real64
    tc%file_weather_irrigation_depth%depth_criterion={dcs}
    tc%file_weather_irrigation_depth%dcs1_knot_count=2
    tc%file_weather_irrigation_depth%dcs1_dvs(1:2)=[0._real64,2._real64]
    tc%file_weather_irrigation_depth%dcs1_adjustment_mm(1:2)=0._real64
    tc%file_weather_irrigation_depth%rainfall_threshold_cm=.05_real64
    tc%file_weather_irrigation_depth%tcs2_knot_count=2
    tc%file_weather_irrigation_depth%tcs2_dvs(1:2)=[0._real64,2._real64]
    tc%file_weather_irrigation_depth%tcs2_fraction(1:2)={0 if trigger else 1}._real64
    tc%file_weather_irrigation_depth%tcs3_knot_count=2
    tc%file_weather_irrigation_depth%tcs3_dvs(1:2)=[0._real64,2._real64]
    tc%file_weather_irrigation_depth%tcs3_fraction(1:2)={0 if trigger else 1}._real64
    tc%file_weather_irrigation_depth%tcs4_knot_count=2
    tc%file_weather_irrigation_depth%tcs4_dvs(1:2)=[0._real64,2._real64]
    tc%file_weather_irrigation_depth%tcs4_depletion_mm(1:2)={0 if trigger else 500}._real64
'''
 replace(anchor,anchor+config)
 replace('    real(real64)::delivered_amount','    real(real64)::delivered_amount,oracle_depth,oracle_before\n    logical::oracle_trigger')
 replace('        do q=0,63','''        call ta%snapshot_weather_irrigation(irrigation,selected_day,oracle_before,st)
        call require(st==FMR_APP_BOOT_OK,'existing rooted irrigation snapshot')
        call literal_irrigation_selection(ta,cs,tc,wr,oracle_trigger,oracle_depth)
        do q=0,63
          if(q>0)allocation%source_id=0_int64 ! Active event freezes original valid receipt.''')
 anchor="          call require(st==FMR_APP_BOOT_OK.and.rr(1)%committed.and.rr(1)%solver_executed,'rooted real accepted Richards transaction')"
 replace(anchor,anchor+f'''
          if(q==0.and.wo%crop_emerged)then
            call ta%snapshot_weather_irrigation(irrigation,selected_day,delivered_amount,st)
            call require(st==FMR_APP_BOOT_OK,'actual accepted root-policy event')
            call require(oracle_trigger.eqv.{'.true.' if trigger else '.false.'},'independent trigger/nontrigger discriminator')
            if(oracle_trigger)then
              call require(irrigation%management%event%active_event,'root policy event active after first segment')
              ! Literal TASK4 leaves SSDI rate unchanged. With configured rate0,
              ! its normalized one-day duration is unchanged as well.
              call require(abs(irrigation%management%event%active_event_rate_cm_per_day-oracle_depth)<1.e-13_real64, &
                'actual root-policy DCS and cap then literal SSDI availability')
            else
              call require(.not.irrigation%management%event%active_event.and..not.irrigation%receipt%present, &
                'nontrigger neither starts event nor freezes provider')
            end if
          end if''')
 anchor="      call require(st==FMR_APP_BOOT_OK,'actual rooted joint management owner')"
 replace(anchor,anchor+f'''
      call require(abs(delivered_amount-oracle_before-{nodes}._real64*oracle_depth)<2.e-13_real64, &
        'full actual rooted day amount follows literal partial-root/material/rain depth, no repeated selection')''')
 if not trigger:
  a=s.index('      if(wo%crop_emerged)then\n        call require(irrigation%receipt%present')
  b=s.index('      prior_uptake=uptake;prior_wr=wr',a)
  s=s[:a]+'''      call require(.not.irrigation%receipt%present.and.delivered_amount==0._real64,'nontrigger full-day zero input')
'''+s[b:]
 replace("  print '(a)','MC_IRR01_MANAGED_ADAPTIVE_ROOTED_DAILY_SOURCE_RESTART=PASS'", "  print '(a)','MC_IRR01_MANAGED_ADAPTIVE_ROOTED_DAILY_SOURCE_RESTART=PASS'\n  print '(a)','MC_IRR01_MATERIAL_ROOT_POLICY_PHYSICAL_LITERAL_RESTART=PASS'")
 replace('\ncontains\n','\ncontains\n'+(root/'tests/mc-irr01/material_root_selection_oracle.inc').read_text())
 target.write_text(s);return target
