#!/usr/bin/env python3
"""Corrupt complete proofs, source scope and fresh native coverage independently."""
import copy,json
from unittest.mock import patch
import verify_senescence_successor as v
if (v.ROOT/'src/runtime/mod_fmr_biomass_root_uptake_input.f90').exists():
 import subprocess,sys
 subprocess.run([sys.executable,'-B',str(v.ROOT/'tests/root-growth/check_swrd3_controls.py')],check=True)
if (v.ROOT/'integration/audits/MC_NUT01_MANAGEMENT_CALENDAR_STATUS.json').exists():
 import subprocess,sys
 subprocess.run([sys.executable,'-B',str(v.ROOT/'tests/nut-calendar/check_calendar_controls.py')],check=True)
 raise SystemExit(0)
v.verify_qualification();source=v.verify_source();data=v.read_evidence();passed=[]
old=v.baseline_command('tests/nut-material-environment/check_material_environment_controls.py')
assert old['status']=='PASS'and old['negative_count']==65
passed+=['baseline:'+name for name in old['controls']]
env=v.baseline_command('tests/nut-environment/check_environment_controls.py');assert env['status']=='PASS'and env['negative_count']==22
passed+=['baseline-environment:'+name for name in env['controls']]
def reject(d,label):
 try:v.validate(d,source)
 except (ValueError,KeyError,AssertionError):passed.append(label);return
 raise AssertionError('accepted '+label)
for label,mutation in [
 ('unfinished',lambda r:r.update(status='RUNNING')),
 ('wrong_mode',lambda r:r.update(mode='day')),
 ('stale_source',lambda r:r.update(source_tree='0'*40)),
 ('input_drift',lambda r:r['input_sha256'].update({'src/crop/mod_crop_soil_n_material_day.f90':'0'*64})),
 ('authority_drift',lambda r:r['authority'].update({'management_soil.f90':'0'*64})),
 ('explicit_day_missing',lambda r:r['runs']['O0']['drivers'].pop('test_senescence_day')),
 ('explicit_joint_missing',lambda r:r['runs']['O0']['drivers'].pop('test_senescence_joint')),
 ('literal_marker_missing',lambda r:r['runs']['O0']['drivers']['test_senescence_joint'].update(stdout='')),
 ('decoder_incomplete',lambda r:r['runs']['O2']['drivers']['test_senescence_joint']['decoder_negatives'].pop()),
 ('absent_not_preserved',lambda r:r.update(incumbent_endpoints_identical=False)),
 ('unexpected_reuse',lambda r:r.update(controlled_reuse={'native_results_reused':True})),
 ('optimization_drift',lambda r:r['runs']['O2']['drivers']['test_senescence_joint'].update(endpoint_sha256='0'*64))]:
 d=copy.deepcopy(data);r=json.loads(d['result.json']);mutation(r);d['result.json']=json.dumps(r).encode();reject(d,label)
for label,mutation in [
 ('native_missing',lambda e:e.pop(next(i for i,x in enumerate(e)if x['category']=='native'and 'senescence_joint'in x['command'][0]))),
 ('fresh_ABI_build_missing',lambda e:e.__setitem__(slice(None),[x for x in e if not(x['category']=='compile'and '-O0'in x['command'])])),
 ('changed_provider_compile_missing',lambda e:e.pop(next(i for i,x in enumerate(e)if x['category']=='compile'and 'mod_crop_soil_n_day.f90'in x['command'][x['command'].index('-c')+1]))),
 ('native_failed',lambda e:e[-1].update(returncode=1)),
 ('unchecked_build',lambda e:e[0]['command'].remove('-fcheck=all')),
 ('raw_digest_false',lambda e:e[-1].update(stdout_sha256='0'*64))]:
 d=copy.deepcopy(data);e=json.loads(d['events.json']);mutation(e);d['events.json']=json.dumps(e).encode();reject(d,label)
for label,path in [('restart_corrupt','O0/environment-fresh.bin'),('empty_forced_corrupt','O0/environment-restart.bin.empty-material'),('original_corrupt','O2/expected.bin'),('literal_material_corrupt','O0/wofost_soil_amendments.f90'),('literal_rates_corrupt','O2/wofost_soil_rateconstants.f90'),('literal_uptake_replaced','O0/literal_crop_exchange.f90'),('literal_wrapper_replaced','O2/material_oracle.inc'),('direct_corrupt','direct/result.json'),('process_corrupt','process/result.json'),('pending_restart_corrupt','O0/senescence-restart.bin'),('pending_endpoint_corrupt','O2/senescence-fresh.bin'),('source_order_corrupt','authority/swap.f90'),('pending_probe_corrupt','pending_probe/result.json'),('pending_native_artifact_corrupt','native/ARTIFACTS.json'),('pending_native_case_corrupt','pending_probe/O2-invalid-source-mixture.bin')]:
 d=copy.deepcopy(data);d[path]=(b'foreign oracle'if label=='literal_uptake_replaced'else d[path]+b'x');reject(d,label)
for label,mutation in [
 ('incumbent_unfinished',lambda r:r.update(status='RUNNING')),
 ('incumbent_stale_source',lambda r:r.update(source_tree='0'*40)),
 ('incumbent_missing_driver',lambda r:r['runs']['O0']['drivers'].pop('test_environment_joint')),
 ('incumbent_native_reused',lambda r:r['controlled_reuse'].update(native_results_reused=True)),
 ('incumbent_unbound_reuse',lambda r:r['controlled_reuse'].update(primary_result_sha256='0'*64)),
 ('incumbent_partial_reuse',lambda r:r['controlled_reuse']['providers']['O2'].pop(next(iter(r['controlled_reuse']['providers']['O2'])))),
 ('incumbent_endpoint_drift',lambda r:r['runs']['O0']['drivers']['test_crop_soil_joint'].update(endpoint_sha256='0'*64)),
 ('incumbent_no_identity',lambda r:r.update(all_incumbent_endpoints_identical=False))]:
 d=copy.deepcopy(data);r=json.loads(d['incumbent/result.json']);mutation(r);d['incumbent/result.json']=json.dumps(r).encode();reject(d,label)
for label,mutation in [
 ('incumbent_native_missing',lambda e:e.pop(next(i for i,x in enumerate(e)if x['category']=='native'))),
 ('incumbent_link_missing',lambda e:e.pop(next(i for i,x in enumerate(e)if x['category']=='link'))),
 ('incumbent_unchecked_build',lambda e:e[0]['command'].remove('-fcheck=all'))]:
 d=copy.deepcopy(data);e=json.loads(d['incumbent/events.json']);mutation(e);d['incumbent/events.json']=json.dumps(e).encode();reject(d,label)
for label,path in [('incumbent_object_drift','incumbent/BUILD_ARTIFACTS.json'),('incumbent_restart_drift','incumbent/O0/test_crop_soil_joint-restart.bin'),('incumbent_physical_drift','incumbent/O2/test_environment_joint-fresh.bin'),('incumbent_oracle_drift','incumbent/O2/literal_crop_exchange.f90')]:
 d=copy.deepcopy(data);d[path]+=b'x';reject(d,label)
original=v.git
for label,row in [('foreign_source','M\tsrc/crop/mod_wofost81_nitrogen.f90'),('foreign_test','A\ttests/foreign.py'),('foreign_reference','M\treference/foreign')]:
 def changed(*a):
  x=original(*a);return x+'\n'+row if a[:2]==('diff','--name-status')else x
 with patch.object(v,'git',side_effect=changed):
  try:v.verify_source()
  except (ValueError,KeyError,AssertionError):passed.append(label);continue
  raise AssertionError('accepted '+label)
print(json.dumps(dict(status='PASS',negative_count=len(passed),controls=passed),indent=2))
