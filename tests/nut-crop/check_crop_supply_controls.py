#!/usr/bin/env python3
import copy,json
from unittest.mock import patch
import verify_crop_supply_successor as v
v.verify_qualification();data=v.read_evidence();passed=[]
def rejected(fn,label):
 try:fn()
 except (ValueError,KeyError,AssertionError):passed.append(label);return
 raise AssertionError('accepted negative '+label)
for label,mutate in [
 ('unfinished',lambda r:r.update(status='RUNNING')),
 ('stale_source',lambda r:r.update(source_tree='0'*40)),
 ('direct_only',lambda r:r.update(direct_only=True)),
 ('different_literal_authority',lambda r:r['authority'].update({'management_soil.f90':'0'*64})),
 ('wrong_input',lambda r:r['input_sha256'].update({'src/crop/mod_crop_soil_n_day.f90':'0'*64})),
 ('native_result_reused',lambda r:r['controlled_reuse'].update(unchanged_native_results_reused=True)),
 ('wrong_reused_execution',lambda r:r['controlled_reuse'].update(prior_execution='0'*40)),
 ('module_interface_drift',lambda r:r['controlled_reuse']['artifacts_after'].update({next(p for p in r['controlled_reuse']['artifacts_before']if p.endswith('.mod')):'0'*64})),
 ('missing_new_driver',lambda r:r['runs']['O0']['drivers'].pop('test_crop_soil_joint')),
 ('missing_direct_science',lambda r:r['runs']['O0']['drivers']['test_crop_soil_day'].update(stdout='')),
 ('missing_physical_science',lambda r:r['runs']['O0']['drivers']['test_crop_soil_joint'].update(stdout='')),
 ('incomplete_decoder',lambda r:r['runs']['O0']['drivers']['test_crop_soil_joint']['decoder_negatives'].pop()),
 ('incumbent_not_preserved',lambda r:r['runs']['O0']['drivers']['test_reactive_joint'].update(admitted_endpoint_identity=False)),
 ('optimization_drift',lambda r:r['runs']['O2']['drivers']['test_crop_soil_joint'].update(endpoint_sha256='0'*64)),
 ('translated_literal',lambda r:r['literal_uptake_extraction'].update(block_sha256='0'*64)),
]:
 mutant=copy.deepcopy(data);r=json.loads(mutant['result.json']);mutate(r);mutant['result.json']=json.dumps(r).encode()
 with patch.object(v,'read_evidence',return_value=mutant):rejected(v.verify_qualification,label)
for label,path in [('crop_restart_corruption','O0/test_crop_soil_joint-fresh.bin'),('incumbent_corruption','O0/test_reactive_joint-expected.bin'),('source_block_corruption','O0/literal_crop_exchange.f90'),('reference_corruption','O0/wofost_soil_orgmatn.f90')]:
 mutant=copy.deepcopy(data);mutant[path]+=b'x'
 with patch.object(v,'read_evidence',return_value=mutant):rejected(v.verify_qualification,label)
for label,mutate in [('native_missing',lambda e:e.pop(next(i for i,x in enumerate(e)if x['category']=='native'))),('native_failed',lambda e:e[-1].update(returncode=1)),('unchecked_compile',lambda e:e[next(i for i,x in enumerate(e)if x['category']=='compile')]['command'].remove('-fcheck=all')),('raw_digest_false',lambda e:e[-1].update(stdout_sha256='0'*64))]:
 mutant=copy.deepcopy(data);e=json.loads(mutant['events.json']);mutate(e);mutant['events.json']=json.dumps(e).encode()
 with patch.object(v,'read_evidence',return_value=mutant):rejected(v.verify_qualification,label)
original=v.git
for label,row in [('foreign_source','M\tsrc/crop/mod_wofost81_nitrogen.f90'),('foreign_test','A\ttests/foreign.py'),('foreign_reference','M\treference/foreign')]:
 def altered(*args):
  r=original(*args);return r+'\n'+row if args[:2]==('diff','--name-status')else r
 with patch.object(v,'git',side_effect=altered):rejected(v.verify_source,label)
print(json.dumps(dict(status='PASS',negative_count=len(passed),controls=passed),indent=2))
