#!/usr/bin/env python3
"""Fail closed on incomplete native, physical, source and provenance evidence."""
import copy,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
if (ROOT/'integration/audits/MC_NUT01_ACCEPTED_THERMAL_STATUS.json').exists()and not (ROOT/'src/runtime/mod_fmr_biomass_root_uptake_input.f90').exists():
 import runpy
 runpy.run_path(str(ROOT/'tests/nut-thermal/check_thermal_successor_controls.py'),run_name='__main__')
 sys.exit(0)
from unittest.mock import patch
import verify_input_successor as v
v.verify_qualification();source=v.verify_source();data=v.read_evidence();passed=[]
old=v.baseline_command('tests/nut-calendar/check_calendar_controls.py')
assert old['status']=='PASS'and old['negative_count']==183
passed+=['baseline:'+p for p in old['controls']]
def reject(d,label):
 try:v.validate(d,source)
 except(ValueError,KeyError,AssertionError):passed.append(label);return
 raise AssertionError('accepted '+label)
for label,path,mutate in [
 ('process_running','process/result.json',lambda r:r.update(status='RUNNING')),
 ('process_stale','process/result.json',lambda r:r.update(source_tree='0'*40)),
 ('small_closure','process/result.json',lambda r:r.update(production_providers=3)),
 ('dates_missing','process/result.json',lambda r:r.update(date_cases=0)),
 ('invalid_paths_missing','process/result.json',lambda r:r.update(invalid_count=0)),
 ('fixture_binding','process/result.json',lambda r:r['fixture_sha256'].update({'literal.snm':'0'*64})),
 ('process_input','process/result.json',lambda r:r['input_sha256'].update({'src/process/mod_soil_n_amendment_input.f90':'0'*64})),
 ('process_native','process/result.json',lambda r:r['runs']['O0']['fixtures'].pop('literal')),
 ('process_marker','process/result.json',lambda r:r['runs']['O2'].update(dates='')),
 ('joint_running','joint/result.json',lambda r:r.update(status='RUNNING')),
 ('joint_stale','joint/result.json',lambda r:r.update(source_tree='0'*40)),
 ('joint_compiler','joint/result.json',lambda r:r.update(compiler='foreign')),
 ('joint_closure','joint/result.json',lambda r:r['runs']['O0'].update(production_providers=266)),
 ('file_profile','joint/result.json',lambda r:r['runs']['O0']['drivers']['test_calendar_joint'].pop('file')),
 ('typed_profile','joint/result.json',lambda r:r['runs']['O0']['drivers']['test_calendar_joint'].pop('calendar')),
 ('manual_profile','joint/result.json',lambda r:r['runs']['O2']['drivers']['test_calendar_joint'].pop('manual')),
 ('file_endpoint','joint/result.json',lambda r:r['runs']['O0']['drivers']['test_calendar_joint']['file'].update(endpoint_sha256='0'*64)),
 ('file_restart','joint/result.json',lambda r:r['runs']['O2']['drivers']['test_calendar_joint']['file'].update(restart_sha256='0'*64)),
 ('file_assertions','joint/result.json',lambda r:r['runs']['O2']['drivers']['test_calendar_joint']['file'].update(stdout='')),
 ('fresh_assertions','joint/result.json',lambda r:r['runs']['O2']['drivers']['test_calendar_joint']['file'].update(fresh_stdout='')),
 ('day_running','day/result.json',lambda r:r.update(status='RUNNING')),
 ('day_native','day/result.json',lambda r:r['runs']['O0']['drivers']['test_calendar_day'].update(stdout='')),
 ('generator_identity','joint/GENERATION.json',lambda r:r.update(executed_runner_sha256='0'*64)),
 ('generated_driver_digest','joint/GENERATION.json',lambda r:r['generated_driver_sha256'].update({'test_calendar_joint.f90':'0'*64}))]:
 d=copy.deepcopy(data);r=json.loads(d[path]);mutate(r);d[path]=json.dumps(r).encode();reject(d,label)
for label,prefix in [('process','process/'),('day','day/'),('joint','joint/')]:
 for kind in ['compile','driver_compile','link','native']:
  d=copy.deepcopy(data);p=prefix+'events.json';es=json.loads(d[p]);es.pop(next(i for i,e in enumerate(es)if e['category']==kind));d[p]=json.dumps(es).encode();reject(d,label+'_missing_'+kind)
 for fault in ['failed','unchecked','raw']:
  d=copy.deepcopy(data);p=prefix+'events.json';es=json.loads(d[p])
  if fault=='failed':es[-1]['returncode']=1
  if fault=='unchecked':next(e for e in es if e['category']=='compile')['command'].remove('-fcheck=all')
  if fault=='raw':es[-1]['stdout_sha256']='0'*64
  d[p]=json.dumps(es).encode();reject(d,label+'_'+fault)
for path in ['process/literal.snm','process/dates.txt','joint/drivers/test_calendar_joint.f90','day/drivers/test_calendar_day.f90','joint/executed_runner.py','joint/O0/file-restart.bin','joint/O0/file-expected.bin','joint/O2/file-fresh.bin','joint/O2/file-expected.bin.opaque','joint/O2/manual-expected.bin','joint/O0/calendar-expected.bin','joint/O0/wofost_soil_amendments.f90','joint/O2/wofost_soil_rateconstants.f90','joint/O2/material_oracle.inc']:
 d=copy.deepcopy(data);d[path]+=b'foreign';reject(d,'raw_changed:'+path)
original=v.git
for label,row in [('foreign_source','M\tsrc/crop/mod_wofost81_nitrogen.f90'),('foreign_test','A\ttests/foreign.py'),('foreign_reference','M\treference/foreign')]:
 def changed(*a):
  r=original(*a);return r+'\n'+row if a[:2]==('diff','--name-status')else r
 with patch.object(v,'git',side_effect=changed):
  try:v.verify_source()
  except(ValueError,KeyError,AssertionError):passed.append(label);continue
  raise AssertionError('accepted '+label)
print(json.dumps({'status':'PASS','negative_count':len(passed),'controls':passed},indent=2))
