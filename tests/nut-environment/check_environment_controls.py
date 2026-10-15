#!/usr/bin/env python3
"""Ensure unfinished, stale, corrupted and foreign successors fail closed."""
import copy,json
import os,sys
from pathlib import Path
_new=Path(__file__).resolve().parents[1]/'nut-senescence/check_senescence_controls.py'
if _new.exists():os.execv(sys.executable,[sys.executable,'-B',str(_new)])
from unittest.mock import patch
import verify_environment_successor as v
source=v.verify_source();data=v.read_evidence();v.validate(data,source);passed=[]
def rejected(fn,label):
 try:fn()
 except (ValueError,KeyError,AssertionError):passed.append(label);return
 raise AssertionError('accepted invalid evidence '+label)
for label,mutate in [
 ('unfinished',lambda r:r.update(status='RUNNING')),
 ('direct_only',lambda r:r.update(direct_only=True)),
 ('wrong_source',lambda r:r.update(source_tree='0'*40)),
 ('changed_input',lambda r:r['input_sha256'].update({'src/process/mod_soil_n_day_environment.f90':'0'*64})),
 ('missing_environment_driver',lambda r:r['runs']['O0']['drivers'].pop('test_environment_joint')),
 ('missing_literal_temperature',lambda r:r['runs']['O0']['drivers']['test_environment_day'].update(stdout='')),
 ('missing_joint_science',lambda r:r['runs']['O2']['drivers']['test_environment_joint'].update(stdout='')),
 ('missing_decoder',lambda r:r['runs']['O0']['drivers']['test_environment_joint']['decoder_negatives'].pop()),
 ('wrong_restart_endpoint',lambda r:r['runs']['O0']['drivers']['test_environment_joint'].update(endpoint_sha256='0'*64)),
 ('incumbent_unproven',lambda r:r['runs']['O0']['drivers']['test_crop_soil_joint'].update(admitted_endpoint_identity=False)),
 ('optimization_drift',lambda r:r['runs']['O2']['drivers']['test_environment_joint'].update(endpoint_sha256='0'*64)),
 ('literal_replaced',lambda r:r['literal_uptake_extraction'].update(block_sha256='0'*64)),
]:
 d=copy.deepcopy(data);r=json.loads(d['result.json']);mutate(r);d['result.json']=json.dumps(r).encode()
 rejected(lambda:v.validate(d,source),label)
for label,p in [('raw_restart','O0/test_environment_joint-fresh.bin'),('raw_oracle','O2/literal_crop_exchange.f90'),('raw_incumbent','O0/test_crop_soil_joint-expected.bin')]:
 d=copy.deepcopy(data)
 if label=='raw_oracle':d[p]=d[p].replace(b'! Mineralisation',b'! Xineralisation',1)
 else:d[p]+=b'x'
 rejected(lambda:v.validate(d,source),label)
for label,mutate in [('native_missing',lambda e:e.pop(next(i for i,x in enumerate(e)if x['category']=='native'))),('native_failed',lambda e:e[-1].update(returncode=1)),('unchecked_compile',lambda e:e[next(i for i,x in enumerate(e)if x['category']=='compile')]['command'].remove('-fcheck=all')),('raw_digest',lambda e:e[-1].update(stdout_sha256='0'*64))]:
 d=copy.deepcopy(data);e=json.loads(d['events.json']);mutate(e);d['events.json']=json.dumps(e).encode()
 rejected(lambda:v.validate(d,source),label)
original=v.git
for label,row in [('foreign_source','M\tsrc/crop/mod_wofost81_nitrogen.f90'),('foreign_test','A\ttests/foreign.py'),('foreign_reference','M\treference/foreign')]:
 def altered(*args):
  result=original(*args)
  return result+'\n'+row if args[:2]==('diff','--name-status')else result
 with patch.object(v,'git',side_effect=altered):rejected(v.verify_source,label)
print(json.dumps(dict(status='PASS',negative_count=len(passed),controls=passed),indent=2))
