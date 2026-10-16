"""Real existing accepted root/material/weather driver with source DAYFIX gate."""
from pathlib import Path
import sys

def rooted(root,target,criterion,dcs=1,rate=0.,kind='interval'):
 sys.path.insert(0,str(root/'tests/mc-irr01'))
 from availability_cycle_driver import rooted as old
 old(root,target,criterion,dcs,rate);s=target.read_text()
 def replace(a,b):
  nonlocal s
  assert s.count(a)==1,(a,s.count(a));s=s.replace(a,b)
 anchor='    tc%file_weather_irrigation_field_capacity_head_cm=0._real64'
 replace(anchor,anchor+'\n    tc%file_weather_irrigation_depth%fixed_interval_enabled=.true.\n    tc%file_weather_irrigation_depth%fixed_interval_days=3')
 replace('    if(.not.trigger)return', '''    call app%snapshot_weather_irrigation(weekly_state,selection,delivered,st)
    call require(st==FMR_APP_BOOT_OK,'literal reads committed interval owner')
    if(weekly_state%management%policy%weekly_day_counter<3)trigger=.false.
    if(.not.trigger)return''')
 replace("call require(oracle_trigger.eqv..true.,'independent availability trigger discriminator')", "call require(oracle_trigger.eqv.(mod(d-2,3)==0),'literal three-day source interval discriminator')")
 replace("irrigation%management%policy%weekly_day_counter==366,'restart before next availability selection'", "irrigation%management%policy%weekly_day_counter==2,'restart immediately before next source interval boundary'")
 replace('          ! Nonweekly selectors preserve the existing unused weekly counter.', '          if(wo%crop_emerged)expected_week=mod(d-2,3)+1')
 replace("call require(weekly_events==9,'nine authentic accepted emerged-day opportunities')", "call require(weekly_events==3,'three source interval opportunities across nine accepted emerged days')")
 target.write_text(s.replace('AVAIL_ROOTED_SOURCE_FRESH_PROVIDER_MASS_NATIVE=PASS','BATCH_TCS234_DCS1_INTERVAL_REAL_MASS_NATIVE=PASS'));return target
