#!/usr/bin/env python3
"""Discriminating negatives for the new admission validator (no production edits)."""
import copy,json,sys
from unittest.mock import patch
import verify_mineral_successor as v

def rejected(fn,label):
 try:fn()
 except (ValueError,KeyError,AssertionError):return label
 raise AssertionError('accepted negative '+label)

v.verify_qualification();data=v.read_evidence();passed=[]
for name,mutate in [
 ('unfinished_status',lambda r:r.update(status='RUNNING')),
 ('wrong_source',lambda r:r.update(source_tree='0'*40)),
 ('wrong_oracle',lambda r:r.update(authority_sha256='0'*64)),
 ('large_process_closure',lambda r:r['runs']['O0'].update(direct_production_provider_count=40)),
 ('missing_carrier_assertions',lambda r:r['runs']['O0'].update(physical_stdout='MINERAL_ACTUAL_RICHARDS_DAILY_ATOMIC_OPAQUE_DISK=PASS')),
 ('missing_decoder_negative',lambda r:r['runs']['O0']['corruption_negatives'].pop()),
 ('stale_input',lambda r:r['input_sha256'].update({'src/process/mod_soil_n_pool_state.f90':'0'*64})),
 ('o0_o2_drift',lambda r:r.update(o0_o2_endpoint_identity=False)),
]:
 mutant=copy.deepcopy(data);r=json.loads(mutant['result.json']);mutate(r);mutant['result.json']=json.dumps(r).encode()
 with patch.object(v,'read_evidence',return_value=mutant):passed.append(rejected(v.verify_qualification,name))
for name,path in [('tampered_endpoint','O0/fresh.bin'),('tampered_oracle','O0/wofost_soil_watern.f90'),('tampered_grid','O0/mineral_grid_stubs.f90')]:
 mutant=copy.deepcopy(data);mutant[path]+=b'x'
 with patch.object(v,'read_evidence',return_value=mutant):passed.append(rejected(v.verify_qualification,name))
events=json.loads(data['events.json'])
for name,mutate in [('missing_native',lambda es:es.pop(next(i for i,e in enumerate(es)if e['category']=='physical_native'))),('failed_event',lambda es:es[0].update(returncode=1)),('wrong_stdout_digest',lambda es:es[0].update(stdout_sha256='0'*64))]:
 mutant=copy.deepcopy(data);es=copy.deepcopy(events);mutate(es);mutant['events.json']=json.dumps(es).encode()
 with patch.object(v,'read_evidence',return_value=mutant):passed.append(rejected(v.verify_qualification,name))
original=v.git
for name,extra in [('foreign_source','A\tsrc/process/foreign.f90'),('foreign_test','A\ttests/foreign.py'),('foreign_reference','M\treference/foreign')]:
 def altered(*args):
  value=original(*args)
  return value+'\n'+extra if args[:2]==('diff','--name-status')else value
 with patch.object(v,'git',side_effect=altered):passed.append(rejected(v.verify_source,name))
print(json.dumps({'status':'PASS','negative_count':len(passed),'controls':passed,'positive':'exact production and terminal raw evidence accepted'},indent=2))
