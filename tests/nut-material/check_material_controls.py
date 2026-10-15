#!/usr/bin/env python3
import copy,json
from unittest.mock import patch
import verify_material_successor as v
v.verify_qualification();source=v.verify_source();data=v.read_evidence();passed=[]
def reject(fn,label):
 try:fn()
 except (ValueError,KeyError,AssertionError):passed.append(label);return
 raise AssertionError('accepted '+label)
for label,mutate in [
 ('unfinished',lambda r:r.update(status='RUNNING')),
 ('direct_only',lambda r:r.update(mode='day')),
 ('stale_source',lambda r:r.update(source_tree='0'*40)),
 ('wrong_authority',lambda r:r['authority'].update({'management_soil.f90':'0'*64})),
 ('input_drift',lambda r:r['input_sha256'].update({'src/process/mod_b111_soil_n_addition.f90':'0'*64})),
 ('missing_joint',lambda r:r['runs']['O0']['drivers'].pop('test_material_joint')),
 ('missing_real_science',lambda r:r['runs']['O0']['drivers']['test_material_joint'].update(stdout='')),
 ('decoder_incomplete',lambda r:r['runs']['O0']['drivers']['test_material_joint']['decoder_negatives'].pop()),
 ('empty_not_preserved',lambda r:r['runs']['O0']['drivers']['test_material_joint'].update(empty_batch_identity=False)),
 ('optimization_drift',lambda r:r['runs']['O2']['drivers']['test_material_joint'].update(endpoint_sha256='0'*64)),
 ('native_reused',lambda r:r['controlled_reuse'].update(native_results_reused=True)),
 ('wrong_reused_execution',lambda r:r['controlled_reuse'].update(prior_execution='0'*40)),
 ('provider_drift',lambda r:r['controlled_reuse']['artifacts_after'].update({'foreign.mod':'0'*64})),
]:
 mutant=copy.deepcopy(data);r=json.loads(mutant['result.json']);mutate(r);mutant['result.json']=json.dumps(r).encode()
 reject(lambda:v.validate(mutant,source),label)
for label,path in [('restart_corrupt','O0/fresh.bin'),('empty_endpoint_corrupt','O0/restart.bin.empty-material'),('literal_amendment_corrupt','O0/wofost_soil_amendments.f90'),('literal_residue_corrupt','O0/wofost_soil_cropresidues.f90'),('small_science_missing','small_day/result.json')]:
 mutant=copy.deepcopy(data);mutant[path]+=b'x'
 # A corrupt JSON proof is a structural failure, like a missing manifest entry.
 try:v.validate(mutant,source)
 except (ValueError,KeyError,AssertionError):passed.append(label);continue
 raise AssertionError('accepted '+label)
for label,mutate in [('native_missing',lambda e:e.pop(next(i for i,x in enumerate(e)if x['category']=='native'))),('native_failed',lambda e:e[-1].update(returncode=1)),('unchecked_compile',lambda e:e[next(i for i,x in enumerate(e)if x['category']=='compile')]['command'].remove('-fcheck=all')),('raw_digest_false',lambda e:e[-1].update(stdout_sha256='0'*64))]:
 mutant=copy.deepcopy(data);e=json.loads(mutant['events.json']);mutate(e);mutant['events.json']=json.dumps(e).encode()
 reject(lambda:v.validate(mutant,source),label)
for label,mutate in [('small_native_missing',lambda e:e.pop(next(i for i,x in enumerate(e)if x['category']=='native'))),('small_unchecked_compile',lambda e:e[0]['command'].remove('-fcheck=all'))]:
 mutant=copy.deepcopy(data);e=json.loads(mutant['small_day/events.json']);mutate(e);mutant['small_day/events.json']=json.dumps(e).encode()
 reject(lambda:v.validate(mutant,source),label)
old=json.loads(v.git('show',v.BASE+':integration/audits/MC_NUT01_CROP_SUPPLY_STATUS.json'));full=v.capsule(old['full_preservation']['evidence'])
for label,mutate in [('prior_unfinished',lambda r:r.update(status='RUNNING')),('prior_input_drift',lambda r:r.update(changed_inputs=['src/foreign.f90']))]:
 mutant=copy.deepcopy(full);r=json.loads(mutant['RESULT.json']);mutate(r);mutant['RESULT.json']=json.dumps(r).encode()
 reject(lambda:v.validate_prior(mutant),label)
original=v.git
for label,row in [('foreign_source','M\tsrc/crop/mod_wofost81_nitrogen.f90'),('foreign_test','A\ttests/foreign.py'),('foreign_reference','M\treference/foreign')]:
 def altered(*a):
  r=original(*a);return r+'\n'+row if a[:2]==('diff','--name-status')else r
 with patch.object(v,'git',side_effect=altered):reject(v.verify_source,label)
print(json.dumps(dict(status='PASS',negative_count=len(passed),controls=passed),indent=2))
