"""Existing actual rooted weather driver with accepted sensor/DAYFIX state."""
from pathlib import Path
CASES=[('sensor7',7,1,0.,'winter'),('sensor8',8,2,0.,'single'),('sensor_multi',8,1,0.,'winter'),('sensor_off',8,2,0.,'off')]
def sensor_batch(root,target,criterion,dcs,rate,kind):
 from batch_activation_cycle_driver import rooted
 rooted(root,target,criterion,dcs,rate,kind);s=target.read_text()
 s=s.replace('sp%pressure_head(i)<config%','sp%pressure_head(i)<=config%').replace('sp%water_content(i)<config%','sp%water_content(i)<=config%')
 if target.stem=='sensor_multi':
  anchor=f'    call configure_managed_sensor(tc,{criterion},1)\n    ! Separate new compound-weather envelope:'
  assert s.count(anchor)==1
  s=s.replace(anchor,anchor.replace(f'tc,{criterion},1',f'tc,{criterion},3'))
  a='delivered_amount-oracle_before-1._real64*oracle_depth';assert s.count(a)==1;s=s.replace(a,'delivered_amount-oracle_before-3._real64*oracle_depth')
 if target.stem=='sensor7':
  # Depth-only policy timing metadata is not the selected sensor timing.
  a='    tc%file_weather_irrigation_depth%fixed_interval_days=3';assert s.count(a)==2
  s=s.replace(a,a+'\n    tc%file_weather_irrigation_depth%timing_criterion=6')
 if kind=='single':
  a='    tc%file_weather_irrigation_depth%tcs4_knot_count=1';assert s.count(a)==1
  s=s.replace(a,a+'\n    tc%file_weather_irrigation_sensor%tcs8_knot_count=1\n    tc%file_weather_irrigation_depth%dcs2_knot_count=1')
 # Source window of winter profile includes the original immediate emerged
 # failure/retry probe at Jan20. Other profiles retain their own changed counters
 # under production allocation rejection and opaque/native replay assertions.
 if kind=='winter':
  a='    ! Original failure/retry probe is executed separately at the incumbent profile.';assert s.count(a)==1
  s=s.replace(a,"    if(trim(continuation_mode)=='continuous')call managed_failure_probe(tc)")
 target.write_text(s.replace('BATCH_ROOT_FULL_ACTIVATION_SOURCE_MASS_NATIVE=PASS','SENSOR_BATCH_FULL_SOURCE_MASS_NATIVE=PASS'));return target
