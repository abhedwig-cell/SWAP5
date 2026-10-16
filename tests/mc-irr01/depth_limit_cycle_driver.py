"""Discriminating DCSLIM profiles in the existing real weather/current-root driver."""
from pathlib import Path
import sys
CASES=[('root2_lower',2,1,.08,'lower'),('root3_zero_input',3,2,.08,'zero_input'),('root4_upper',4,1,0.,'upper'),('root7_inactive',7,2,.08,'inactive'),('root8_equal',8,1,.08,'equal'),('root8_zero_max',8,1,0.,'zero_max')]

def rooted(root,target,criterion,dcs,rate,kind):
 sys.path.insert(0,str(root/'tests/mc-irr01'))
 from availability_cycle_driver import rooted as prior
 prior(root,target,criterion,dcs,rate);s=target.read_text()
 def replace(a,b):
  nonlocal s
  assert s.count(a)==1,(a,s.count(a));s=s.replace(a,b)
 if kind=='lower':
  extra='''
    tc%file_weather_irrigation_depth%minimum_depth_cm=.04_real64
    tc%file_weather_irrigation_depth%maximum_depth_cm=.08_real64
    tc%file_weather_irrigation_depth%dcs1_adjustment_mm(1:2)=-100._real64'''
 elif kind=='zero_input':
  extra='''
    tc%file_weather_irrigation_depth%minimum_depth_cm=.04_real64
    tc%file_weather_irrigation_depth%maximum_depth_cm=.08_real64
    tc%file_weather_irrigation_depth%dcs2_depth_cm(1:2)=0._real64'''
 elif kind=='inactive':
  extra='''
    tc%file_weather_irrigation_depth%depth_limit_enabled=.false.
    tc%file_weather_irrigation_depth%dcs2_depth_cm(1:2)=.04_real64'''
 elif kind=='equal':
  extra='''
    tc%file_weather_irrigation_depth%minimum_depth_cm=.04_real64
    tc%file_weather_irrigation_depth%maximum_depth_cm=.04_real64'''
 elif kind=='zero_max':
  extra='''
    tc%file_weather_irrigation_depth%minimum_depth_cm=0._real64
    tc%file_weather_irrigation_depth%maximum_depth_cm=0._real64'''
 elif kind=='upper':extra=''
 else:raise ValueError(kind)
 anchor='    tc%file_weather_irrigation_depth%rainfall_threshold_cm=.05_real64'
 replace(anchor,anchor+extra)
 # Original source oracle derives raw depth from actual accepted roots/materials,
 # then applies the configured bounds. Fixed oracle depths discriminate each new profile.
 if kind in('lower','zero_input','inactive','equal'):
  anchor='        prior_irrigation=irrigation'
  replace(anchor,"        if(oracle_trigger)call require(abs(oracle_depth-.04_real64)<1.e-14_real64,'source limit profile selects expected0.04cm')\n"+anchor)
 if kind=='zero_max':
  replace('if(oracle_trigger.and.(.true..or.availability_fraction(d)>0._real64))then', 'if(oracle_trigger.and.oracle_depth>0._real64)then')
  anchor='        prior_irrigation=irrigation'
  replace(anchor,"        call require(oracle_depth==0._real64,'source zero maximum consumes day with no water')\n"+anchor)
 s=s.replace('AVAIL_ROOTED_SOURCE_FRESH_PROVIDER_MASS_NATIVE=PASS','LIMIT_CURRENT_ROOT_MATERIAL_WEATHER_NATIVE_MASS=PASS')
 target.write_text(s);return target
