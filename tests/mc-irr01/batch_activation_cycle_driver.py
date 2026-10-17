"""Source calendar activation through real accepted weather/current roots/materials."""
from pathlib import Path
import sys
CASES=[('season2',2,1,0.,'winter'),('season3',3,1,0.,'annual'),('season4',4,1,0.,'single'),('schedule_off',2,1,0.,'off')]

def rooted(root,target,criterion,dcs=1,rate=0.,kind='annual'):
 sys.path.insert(0,str(root/'tests/mc-irr01'))
 from availability_cycle_driver import rooted as old
 old(root,target,criterion,dcs,rate);s=target.read_text()
 first,last=(2,5)if kind=='winter'else(3,8)if kind=='annual'else(2,10)
 if kind=='off':first,last=99,-1
 def replace(a,b):
  nonlocal s
  assert s.count(a)==1,(a,s.count(a));s=s.replace(a,b)
 replace('  implicit none\n','  use mod_crop_rotation_calendar,only:initialize_crop_calendar\n  implicit none\n')
 anchor='    tc%file_weather_irrigation_field_capacity_head_cm=0._real64'
 assert s.count(anchor)==2
 start='[1,10]'if kind=='winter'else f'[{20+first if first<90 else 1},1]'
 end=f'[{20+last if last>0 else 31},1]'
 assert end!='[1,2]' # The native rejection witness must actually change config.
 extra=f'''
    tc%file_weather_irrigation_depth%fixed_interval_enabled=.true.
    tc%file_weather_irrigation_depth%fixed_interval_days=3
    tc%file_weather_irrigation_historical_activation=.true.
    tc%file_weather_irrigation_schedule_enabled={'.false.'if kind=='off'else'.true.'}
    tc%file_weather_irrigation_startirr={start}
    tc%file_weather_irrigation_endirr={end}
    call initialize_crop_calendar([real(swap_weather_calendar_day({1998 if kind=='winter'else 1999},1,1),real64)], &
      [real(swap_weather_calendar_day(1999,12,31),real64)],tc%file_weather_irrigation_crop_calendar,st)
    call require(st==0,'existing immutable crop calendar bound to authentic weather epoch')'''
 s=s.replace(anchor,anchor+extra)
 if kind=='single':
  anchor='    tc%file_weather_irrigation_depth%tcs4_depletion_mm(1:2)=0._real64'
  assert s.count(anchor)==1
  s=s.replace(anchor,anchor+'\n    tc%file_weather_irrigation_depth%tcs4_knot_count=1\n    tc%file_weather_irrigation_depth%dcs1_knot_count=1')
 replace("      if(.not.owner%crop_emerged)return", "      if(.not.owner%crop_emerged)return\n      call weather%values(day,lo,hi,rain,et,ok)\n      call require(ok,'literal authentic accepted weather date')\n      if(.not.literal_day_window(int(day)-config%file_weather_epoch_day))return")
 replace('    if(.not.trigger)return', '''    call app%snapshot_weather_irrigation(weekly_state,selection,delivered,st)
    call require(st==FMR_APP_BOOT_OK,'literal existing DAYFIX state')
    if(weekly_state%management%policy%weekly_day_counter<3)trigger=.false.
    if(.not.trigger)return''')
 replace("call require(oracle_trigger.eqv..true.,'independent availability trigger discriminator')",f"call require(oracle_trigger.eqv.(literal_day_window(d).and.mod(d-{first},3)==0),'independent source calendar and interval discriminator')")
 replace("irrigation%management%policy%weekly_day_counter==366,'restart before next availability selection'", "irrigation%management%policy%weekly_day_counter==source_counter_after(8),'restart around source activation boundary'")
 replace('          ! Nonweekly selectors preserve the existing unused weekly counter.', '          if(wo%crop_emerged)expected_week=source_counter_after(d)')
 count=0 if kind=='off'else(last-first)//3+1
 replace("call require(weekly_events==9,'nine authentic accepted emerged-day opportunities')",f"call require(weekly_events=={count},'source calendar and interval accepted opportunity count')")
 # Only an eligible selection consumes external allocation. Off-window invalid
 # allocations are irrelevant and must not be mistaken for failed trials.
 s=s.replace('          if(q==0.and.wo%crop_emerged)then','          if(q==0.and.wo%crop_emerged.and.literal_day_window(d))then',1)
 replace("if(trim(continuation_mode)=='native-reject-config')tc%file_weather_irrigation_field_capacity_head_cm=-300._real64", "if(trim(continuation_mode)=='native-reject-config')tc%file_weather_irrigation_endirr=[1,2]\n      if(trim(continuation_mode)=='native-reject-schedule')tc%file_weather_irrigation_schedule_enabled=.false.\n      if(trim(continuation_mode)=='native-reject-calendar')call initialize_crop_calendar( &\n        [real(swap_weather_calendar_day(1997,1,1),real64)],[real(swap_weather_calendar_day(1999,12,31),real64)], &\n        tc%file_weather_irrigation_crop_calendar,st)")
 # An in-flight witness in season4: day8 is an actual gift. Default weekly and
 # AVAIL representatives retain their own original checkpoint generation.
 replace("merge(29,28,index(trim(continuation_mode),'active')>0)", '28')
 replace("merge(28,27,index(trim(continuation_mode),'active')>0)", '27')
 replace("        if(index(trim(continuation_mode),'active')>0)then\n          first_q=1;wr=native_record", "        if(index(trim(continuation_mode),'active')>0)then\n          first_day=8;first_q=1;wr=native_record")
 replace("trim(continuation_mode)=='native-write-active'.and.d==9.and.q==0", "trim(continuation_mode)=='native-write-active'.and.d==8.and.q==0")
 if kind=='single':
  anchor="            call ta%capture_weather_crop_continuation(cs,saved,st);call require(st==FMR_APP_BOOT_OK,'native active event capture')"
  replace(anchor,"            call require(irrigation%management%event%active_event,'new seasonal config fresh-native in-flight event witness')\n"+anchor)
 replace('\ncontains\n',f'''\ncontains
  logical function literal_day_window(day)result(opened)
    integer,intent(in)::day
    opened=day>={first}.and.day<={last}
  end function
  integer function source_counter_after(day)result(counter)
    integer,intent(in)::day
    counter=366
    if(day>={first}.and.{last}>={first})counter=mod(min(day,{last})-{first},3)+1
  end function
''')
 target.write_text(s.replace('AVAIL_ROOTED_SOURCE_FRESH_PROVIDER_MASS_NATIVE=PASS','BATCH_ROOT_FULL_ACTIVATION_SOURCE_MASS_NATIVE=PASS'));return target
