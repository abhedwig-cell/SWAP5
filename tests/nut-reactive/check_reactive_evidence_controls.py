#!/usr/bin/env python3
import copy,json
from unittest.mock import patch
import verify_reactive_successor as v

def rejected(fn,label):
 try:fn()
 except (ValueError,KeyError,AssertionError):return label
 raise AssertionError('accepted negative '+label)
v.verify_qualification();data=v.read_evidence();passed=[]
for label,mutate in [
 ('unfinished',lambda r:r.update(status='RUNNING')),
 ('wrong_source',lambda r:r.update(source_tree='0'*40)),
 ('different_reference',lambda r:r['reference_correction'].update(preimage_sha256='0'*64)),
 ('nonlocal_reference_transform',lambda r:r['reference_correction'].update(exact_preimage='unrelated')),
 ('reference_correction_missing',lambda r:r['reference_correction'].update(replacement_count=0)),
 ('legacy_witness_missing',lambda r:r['runs']['O0']['reference'].update(legacy='')),
 ('large_direct_closure',lambda r:r['runs']['O0'].update(direct_production_provider_count=400)),
 ('carrier_oracle_missing',lambda r:r['runs']['O0'].update(physical_stdout='')),
 ('incumbent_not_preserved',lambda r:r['runs']['O0'].update(incumbent_admitted_byte_identity=False)),
 ('missing_decoder_case',lambda r:r['runs']['O0']['corruption_negatives'].pop()),
 ('stale_input',lambda r:r['input_sha256'].update({'src/process/mod_b111_soil_n_mineral_owner.f90':'0'*64})),
 ('optimization_drift',lambda r:r.update(o0_o2_endpoint_identity=False)),
]:
 mutant=copy.deepcopy(data);r=json.loads(mutant['result.json']);mutate(r);mutant['result.json']=json.dumps(r).encode()
 with patch.object(v,'read_evidence',return_value=mutant):passed.append(rejected(v.verify_qualification,label))
for label,path in [('tampered_restart','O0/fresh.bin'),('tampered_incumbent','O0/mineral-fresh.bin'),('off_drift','O0/expected.bin.off-new'),('tampered_reference','O0/wofost_soil_orgmatn.f90')]:
 mutant=copy.deepcopy(data);mutant[path]+=b'x'
 with patch.object(v,'read_evidence',return_value=mutant):passed.append(rejected(v.verify_qualification,label))
for label,mutate in [('wrong_primary_binding',lambda r:r.update(primary_result_sha256='0'*64)),('missing_physics_config_control',lambda r:r['runs']['O0']['physics_configuration_negatives'].pop()),('edge_science_absent',lambda r:r['runs']['O0'].update(stdout=''))]:
 mutant=copy.deepcopy(data);r=json.loads(mutant['edges/result.json']);mutate(r);mutant['edges/result.json']=json.dumps(r).encode()
 with patch.object(v,'read_evidence',return_value=mutant):passed.append(rejected(v.verify_qualification,label))
for label,mutate in [('missing_native',lambda e:e.pop(next(i for i,r in enumerate(e)if r['category']=='physical_native'))),('missing_reference_native',lambda e:e.pop(next(i for i,r in enumerate(e)if r['category']=='reference_native'))),('failed_event',lambda e:e[0].update(returncode=1)),('false_raw_digest',lambda e:e[0].update(stdout_sha256='0'*64))]:
 mutant=copy.deepcopy(data);events=json.loads(mutant['events.json']);mutate(events);mutant['events.json']=json.dumps(events).encode()
 with patch.object(v,'read_evidence',return_value=mutant):passed.append(rejected(v.verify_qualification,label))
original=v.git
for label,extra in [('foreign_source','A\tsrc/process/foreign.f90'),('foreign_test','A\ttests/foreign.py'),('foreign_reference','M\treference/foreign')]:
 def altered(*args):
  r=original(*args);return r+'\n'+extra if args[:2]==('diff','--name-status')else r
 with patch.object(v,'git',side_effect=altered):passed.append(rejected(v.verify_source,label))
print(json.dumps({'status':'PASS','negative_count':len(passed),'controls':passed},indent=2))
