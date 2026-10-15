#!/usr/bin/env python3
"""Negative controls retain complete source/native/persistence proof requirements."""
import copy,json
from unittest.mock import patch
import verify_calendar_successor as v
v.verify_qualification();source=v.verify_source();data=v.read_evidence();passed=[]
def reject(fn,label):
 try:fn()
 except (ValueError,KeyError,AssertionError):passed.append(label);return
 raise AssertionError('accepted '+label)
for label,mutate in [
 ('unfinished',lambda r:r.update(status='RUNNING')),
 ('direct_only',lambda r:r.update(mode='day')),
 ('stale_source',lambda r:r.update(source_tree='0'*40)),
 ('input_drift',lambda r:r['input_sha256'].update({'src/process/mod_b111_amendment_calendar.f90':'0'*64})),
 ('untested_runtime',lambda r:r['input_sha256'].pop('src/runtime/mod_fmr_crop_soil_n_calendar_application.f90')),
 ('wrong_authority',lambda r:r['authority'].update({'management_soil.f90':'0'*64})),
 ('copied_native',lambda r:r.update(controlled_reuse={})),
 ('missing_joint',lambda r:r['runs']['O0']['drivers'].pop('test_calendar_joint')),
 ('missing_literal',lambda r:r['runs']['O0']['drivers']['test_calendar_joint'].update(stdout='')),
 ('decoder_incomplete',lambda r:r['runs']['O0']['drivers']['test_calendar_joint']['decoder_negatives'].pop()),
 ('empty_missing',lambda r:r['runs']['O0']['drivers']['test_calendar_joint'].update(empty_batch_identity=False)),
 ('optimization_drift',lambda r:r['runs']['O2']['drivers']['test_calendar_joint'].update(endpoint_sha256='0'*64))]:
 d=copy.deepcopy(data);r=json.loads(d['result.json']);mutate(r);d['result.json']=json.dumps(r).encode();reject(lambda:v.validate(d,source),label)
for label,path in [
 ('fresh_drift','O0/fresh.bin'),('opaque_drift','O0/expected.bin.opaque'),('restart_drift','O0/restart.bin'),
 ('empty_drift','O0/restart.bin.empty-material'),('noevent_drift','O0/restart.bin.noevent-calendar'),
 ('rollback_drift','O0/restart.bin.rejected'),('original_material_drift','O0/wofost_soil_amendments.f90'),
 ('original_rates_drift','O0/wofost_soil_rateconstants.f90'),('small_missing','small_day/result.json'),
 ('tiny_missing','contract/result.json'),('tiny_literal_drift','contract/O0/literal_calendar.f90')]:
 d=copy.deepcopy(data);d[path]+=b'x';reject(lambda:v.validate(d,source),label)
for label,mutate in [
 ('ABI_missing',lambda e:e.__setitem__(slice(None),[x for x in e if not(x['category']=='compile'and '-O0'in x['command'])])),
 ('native_missing',lambda e:e.pop(next(i for i,x in enumerate(e)if x['category']=='native'))),
 ('native_failed',lambda e:e[-1].update(returncode=1)),
 ('unchecked_compile',lambda e:e[0]['command'].remove('-fcheck=all')),
 ('raw_log_drift',lambda e:e[-1].update(stdout_sha256='0'*64))]:
 d=copy.deepcopy(data);r=json.loads(d['events.json']);mutate(r);d['events.json']=json.dumps(r).encode();reject(lambda:v.validate(d,source),label)
d=copy.deepcopy(data);ev=json.loads(d['contract/events.json']);ev=[e for e in ev if e['category']!='reference_reject'];d['contract/events.json']=json.dumps(ev).encode();reject(lambda:v.validate(d,source),'original_order_rejection_missing')
original=v.git
for label,row in [('foreign_source','M\tsrc/crop/mod_wofost81_nitrogen.f90'),('foreign_test','A\ttests/foreign.py'),('foreign_reference','M\treference/foreign')]:
 def altered(*a):
  r=original(*a);return r+'\n'+row if a[:2]==('diff','--name-status')else r
 with patch.object(v,'git',side_effect=altered):reject(v.verify_source,label)
print(json.dumps(dict(status='PASS',negative_count=len(passed),controls=passed),indent=2))
