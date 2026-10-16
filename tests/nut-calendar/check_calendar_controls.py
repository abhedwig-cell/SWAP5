#!/usr/bin/env python3
"""Independent raw/reference/native/source negatives, plus exact baseline gates."""
import copy,json
from unittest.mock import patch
import verify_calendar_successor as v
if (v.ROOT/'integration/audits/MC_NUT01_AMENDMENT_INPUT_STATUS.json').exists():
 import subprocess,sys
 subprocess.run([sys.executable,'-B',str(v.ROOT/'tests/nut-input/check_input_controls.py')],check=True)
 raise SystemExit(0)
v.verify_qualification();source=v.verify_source();data=v.read_evidence();passed=[]
old=v.baseline_command('tests/nut-senescence/check_senescence_controls.py')
assert old['status']=='PASS'and old['negative_count']==138
passed+=['baseline:'+name for name in old['controls']]
def reject(d,label):
 try:v.validate(d,source)
 except (ValueError,KeyError,AssertionError):passed.append(label);return
 raise AssertionError('accepted '+label)
for label,mutation in [
 ('unfinished',lambda r:r.update(status='RUNNING')),
 ('wrong_mode',lambda r:r.update(mode='day')),
 ('stale_source',lambda r:r.update(source_tree='0'*40)),
 ('compiler_drift',lambda r:r.update(compiler='foreign')),
 ('input_drift',lambda r:r['input_sha256'].update({'src/process/mod_soil_n_amendment_calendar.f90':'0'*64})),
 ('authority_drift',lambda r:r['authority'].update({'management_soil.f90':'0'*64})),
 ('authority_partial',lambda r:r['authority'].pop('wofost_soil_amendments.f90')),
 ('actual_joint_missing',lambda r:r['runs']['O0']['drivers'].pop('test_calendar_joint')),
 ('manual_missing',lambda r:r['runs']['O0']['drivers']['test_calendar_joint'].pop('manual')),
 ('calendar_missing',lambda r:r['runs']['O2']['drivers']['test_calendar_joint'].pop('calendar')),
 ('native_marker_missing',lambda r:r['runs']['O2']['drivers']['test_calendar_joint']['calendar'].update(stdout='')),
 ('fresh_marker_missing',lambda r:r['runs']['O0']['drivers']['test_calendar_joint']['calendar'].update(fresh_stdout='')),
 ('endpoint_drift',lambda r:r['runs']['O2']['drivers']['test_calendar_joint']['calendar'].update(endpoint_sha256='0'*64)),
 ('reference_selection_drift',lambda r:r['runs']['O0']['drivers']['test_calendar'].update(stdout='CALENDAR_R2_SOURCE_ORDER_UNITS_20_INVALID_EMPTY_ABA=PASS'))]:
 d=copy.deepcopy(data);r=json.loads(d['result.json']);mutation(r);d['result.json']=json.dumps(r).encode();reject(d,label)
for label,mutation in [
 ('native_missing',lambda e:e.pop(next(i for i,x in enumerate(e)if x['category']=='native'and 'joint'in x['command'][0]))),
 ('manual_profile_absent',lambda e:e.__setitem__(slice(None),[x for x in e if not(x['category']=='native'and x['command'][-1]=='manual')])),
 ('fresh_provider_absent',lambda e:e.pop(next(i for i,x in enumerate(e)if x['category']=='compile'and 'mod_soil_n_amendment_calendar.f90'in x['command'][x['command'].index('-c')+1]))),
 ('fresh_driver_absent',lambda e:e.pop(next(i for i,x in enumerate(e)if x['category']=='driver_compile'))),
 ('link_absent',lambda e:e.pop(next(i for i,x in enumerate(e)if x['category']=='link'))),
 ('failed_native',lambda e:e[-1].update(returncode=1)),
 ('unchecked_build',lambda e:e[0]['command'].remove('-fcheck=all')),
 ('raw_digest_false',lambda e:e[-1].update(stdout_sha256='0'*64))]:
 d=copy.deepcopy(data);e=json.loads(d['events.json']);mutation(e);d['events.json']=json.dumps(e).encode();reject(d,label)
for label,mutation in [
 ('reference_unfinished',lambda r:r.update(status='RUNNING')),
 ('reference_transform',lambda r:r['correction'].update(new='sorted')),
 ('reference_B0_missing',lambda r:r['runs'].pop('O0/B0')),
 ('reference_B1_missing',lambda r:r['runs'].pop('O2/B1_R2')),
 ('reference_source_digest',lambda r:r['runs']['O0/B1_R2'].update(source_sha256='0'*64))]:
 d=copy.deepcopy(data);r=json.loads(d['reference/result.json']);mutation(r);d['reference/result.json']=json.dumps(r).encode();reject(d,label)
for label,path in [
 ('direct_incomplete','direct/result.json'),('process_incomplete','process/result.json'),
 ('literal_material_changed','O0/wofost_soil_amendments.f90'),('literal_rates_changed','O2/wofost_soil_rateconstants.f90'),
 ('literal_uptake_changed','O0/literal_crop_exchange.f90'),('literal_wrapper_changed','O2/material_oracle.inc'),
 ('initial_native_changed','O0/calendar-restart.bin'),('opaque_changed','O2/calendar-expected.bin.opaque'),
 ('fresh_endpoint_changed','O0/calendar-fresh.bin'),('manual_endpoint_changed','O2/manual-expected.bin'),
 ('B0_literal_changed','reference/O0/B0.f90'),('B1_literal_changed','reference/O2/B1_R2.f90'),
 ('reference_archive_changed','reference/O0/management_soil.f90'),
 ('empty_probe_changed','empty/result.json'),('empty_build_hash_changed','empty/BUILD_ARTIFACTS.json')]:
 d=copy.deepcopy(data);d[path]=(b'foreign'if label=='literal_uptake_changed'else d[path]+b'x');reject(d,label)
original=v.git
for label,row in [('foreign_source','M\tsrc/crop/mod_wofost81_nitrogen.f90'),('foreign_test','A\ttests/foreign.py'),('foreign_reference','M\treference/foreign')]:
 def changed(*a):
  x=original(*a);return x+'\n'+row if a[:2]==('diff','--name-status')else x
 with patch.object(v,'git',side_effect=changed):
  try:v.verify_source()
  except (ValueError,KeyError,AssertionError):passed.append(label);continue
  raise AssertionError('accepted '+label)
print(json.dumps({'status':'PASS','negative_count':len(passed),'controls':passed},indent=2))
