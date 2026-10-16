"""Actual accepted weather owners with fresh provider fractions and native continuation."""
from pathlib import Path
import sys

def rooted(root,target,criterion=2,dcs=1,rate=.08):
 sys.path.insert(0,str(root/'tests/mc-irr01'))
 from tcs6_cycle_driver import prepare_native
 prepare_native(root,target,dcs,True);s=target.read_text()
 def replace(a,b):
  nonlocal s
  assert s.count(a)==1,(s.count(a),a);s=s.replace(a,b)
 assert s.count('    call configure_managed_sensor(tc,6,1)')==2
 s=s.replace('    call configure_managed_sensor(tc,6,1)',f'    call configure_managed_sensor(tc,{criterion},1)')
 # The failure probe remains a TCS6 probe with its original assertions.
 s=s.replace('tc%file_weather_irrigation_sensor%irr_rate_cm_per_day=0._real64',f'tc%file_weather_irrigation_sensor%irr_rate_cm_per_day={rate}_real64')
 replace('fraction=.5_real64)', 'fraction=availability_fraction(d))')
 replace("'independent weekly trigger/nontrigger discriminator')", "'independent availability trigger discriminator')")
 replace('(.true..and.mod(d-2,7)==0)', '.true.')
 replace("if(weekly_state%management%policy%weekly_day_counter+1>=7) &\n        trigger=10._real64*cdef>config%file_weather_irrigation_depth%tcs6_threshold_mm", "if(weekly_state%management%policy%weekly_day_counter+1>=7) &\n        trigger=10._real64*cdef>config%file_weather_irrigation_depth%tcs6_threshold_mm\n    case(7,8)\n      select type(sp)\n      type is(fmr_b110_temporal_indicator_state_t)\n        i=config%file_weather_irrigation_sensor%sensor_node\n        if(config%file_weather_irrigation_sensor%timing_criterion==7)then\n          trigger=sp%pressure_head(i)<config%file_weather_irrigation_sensor%tcs7_pressure_head(1)\n        else\n          trigger=sp%water_content(i)<config%file_weather_irrigation_sensor%tcs8_water_content(1)\n        end if\n      end select")
 replace('          if(wo%crop_emerged)expected_week=mod(d-2,7)', '          ! Nonweekly selectors preserve the existing unused weekly counter.')
 replace("irrigation%management%policy%weekly_day_counter==6,'restart immediately before real week boundary'", "irrigation%management%policy%weekly_day_counter==366,'restart before next availability selection'")
 replace('            if(oracle_trigger)then',f'            if(oracle_trigger.and.({str(rate==0).lower().replace("true",".true.").replace("false",".false.")}.or.availability_fraction(d)>0._real64))then')
 replace('irrigation%management%event%active_event_rate_cm_per_day-oracle_depth',f'irrigation%management%event%active_event_rate_cm_per_day-{rate}_real64' if rate>0 else 'irrigation%management%event%active_event_rate_cm_per_day-oracle_depth')
 replace('        \'full actual rooted day amount follows literal partial-root/material/rain depth, no repeated selection\')', "        'full actual rooted day amount follows TASK4 duration and no repeated selection')")
 replace('delivered_amount-oracle_before-1._real64*oracle_depth', 'delivered_amount-oracle_before-1._real64*oracle_depth'+('*availability_fraction(d)'if rate>0 else ''))
 replace('      if(oracle_trigger)then\n        call require(irrigation%receipt%present', '      if(oracle_trigger.and.day_amount>0._real64)then\n        call require(irrigation%receipt%present')
 replace("      call require(weekly_events==2,'two real week opportunities, no repeated events')", "      call require(weekly_events==9,'nine authentic accepted emerged-day opportunities')")
 replace('    if(index(trim(continuation_mode),\'native-\')/=1)call managed_failure_probe(tc)', '    ! Original failure/retry probe is executed separately at the incumbent profile.')
 replace("call require(irrigation%receipt%present.and.irrigation%receipt%allocation%revision==int(d,int64),'weekly event frozen provider')", "call require(irrigation%receipt%present.and.irrigation%receipt%allocation%revision==int(d,int64),'fresh event frozen provider')")
 # A provider valid only at selection expires before the first accepted segment.
 replace('valid_t1=real(d+1,real64),fraction=availability_fraction(d))', 'valid_t1=real(d,real64)+.001_real64,fraction=availability_fraction(d))')
 replace('\ncontains\n', '''\ncontains
  real(real64) function availability_fraction(day)result(f)
    integer,intent(in)::day
    real(real64),parameter::values(0:3)=[0._real64,.25_real64,.5_real64,1._real64]
    f=values(mod(day,4))
  end function
''')
 s=s.replace('TCS6_REAL_WEATHER_WEEK_ROOT_MASS_OPAQUE_RETRY=PASS','AVAIL_ROOTED_SOURCE_FRESH_PROVIDER_MASS_NATIVE=PASS')
 target.write_text(s);return target

def sensor(root,target,criterion=7,nodes=1,day=20):
 base=(root/'tests/fmig431/test_crop_file_weather_production.f90').read_text()
 first=base.index('  call test_rooted_weather_production()');boundary=base.index('\ncontains\n')
 base=base[:first]+'  call test_managed_weather_application()\n'+base[boundary:]
 base=base.replace('  implicit none\n','  use mod_fmr_irrigation_allocation_binding\n  use, intrinsic :: ieee_arithmetic\n  use mod_crop_soil_n_joint_restart_file,only:write_weather_irrigation_joint_restart_file,read_weather_irrigation_joint_restart_file\n  implicit none\n',1)
 base=base.replace("trim(continuation_mode)=='restart','explicit replay mode'", "trim(continuation_mode)=='restart'.or.index(trim(continuation_mode),'native-')==1,'explicit replay mode'")
 s=(root/'tests/mc-irr01/test_managed_weather_application.inc').read_text()
 def replace(a,b):
  nonlocal s
  assert s.count(a)==1,(s.count(a),a);s=s.replace(a,b)
 replace('    integer::criterion,nodes,day0,st,j,q,selection,old_selection,neg', '    integer::criterion,nodes,day0,st,j,q,selection,old_selection,neg\n    character(2048)::checkpoint,final_path\n    type(swap_daily_weather_record_t)::no_previous')
 replace('    do criterion=7,8',f'    do criterion={criterion},{criterion}')
 replace('    do nodes=1,3,2',f'    do nodes={nodes},{nodes},2')
 replace('    do day0=20,21',f'    do day0={day},{day}')
 anchor="      call ta%initialize(tc,st);call require(st==FMR_APP_BOOT_OK,'managed application actual initialization')"
 replace(anchor,'''      call get_command_argument(0,checkpoint)
      final_path=trim(checkpoint)//'.'//trim(continuation_mode)//'.final'
      checkpoint=trim(checkpoint)//'.checkpoint'
      if(index(trim(continuation_mode),'native-reject')==1)then
        call get_command_argument(7,checkpoint)
        if(trim(continuation_mode)=='native-reject-config')tc%file_weather_irrigation_depth%maximum_depth_cm=.3_real64
        call read_weather_irrigation_joint_restart_file(trim(checkpoint),tc,wr,no_previous,saved,st)
        call require(st/=0,'invalid native provider/source/profile fails closed')
        call other%restore_weather_crop_continuation(saved,none,st)
        call require(st/=FMR_APP_BOOT_OK.and..not.other%ready().and..not.none%ready(),'invalid native publishes no owner')
        print '(a)','AVAIL_NATIVE_INVALID_ATOMIC=PASS'
        stop
      end if
      if(trim(continuation_mode)=='native-resume')then
        call read_weather_irrigation_joint_restart_file(trim(checkpoint),tc,wr,no_previous,saved,st)
        call require(st==0,'root-free fresh native existing adapter decode')
        call ta%restore_weather_crop_continuation(saved,cs,st)
        call require(st==FMR_APP_BOOT_OK,'root-free fresh native restore')
        call ta%snapshot_weather_irrigation(ir,selection,delivered,st)
        call require(st==FMR_APP_BOOT_OK.and.ir%receipt%allocation%revision==2_int64,'native retains original frozen provider')
        previous=delivered
        goto901
      end if
'''+anchor)
 anchor="      previous=delivered\n      if(trim(continuation_mode)=='restart')then"
 replace(anchor,"""      if(trim(continuation_mode)=='native-write')then
        call write_weather_irrigation_joint_restart_file(trim(checkpoint),saved,st)
        call require(st==0,'root-free existing native active-event writer')
        print '(a)','AVAIL_NATIVE_PREFIX_EXIT=PASS'
        stop
      end if
"""+anchor)
 replace('      wrong=fmr_irrigation_allocation_t() ! expired/missing/changing', '901   wrong=fmr_irrigation_allocation_t() ! expired/missing/changing')
 anchor="      call require(st==FMR_APP_BOOT_OK,'completed weather day common continuation')"
 replace(anchor,anchor+"\n      call write_weather_irrigation_joint_restart_file(trim(final_path),saved,st)\n      call require(st==0,'root-free completed native endpoint')")
 replace('    call managed_failure_probe()', '    if(trim(continuation_mode)==\'continuous\')call managed_failure_probe()')
 s=s.replace('MC_IRR01_MANAGED_WEATHER_SENSOR_SSDI_ALLOCATION_MASS_RESTART=PASS','AVAIL_SENSOR_SOURCE_EXPIRED_PROVIDER_MASS_NATIVE=PASS')
 target.write_text(base.replace('\ncontains\n','\ncontains\n'+s,1));return target
