"""Reject stale sources, incomplete science and forged replay in the existing proof."""
from pathlib import Path
import copy,json,sys
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parent))
import verify_root_material_successor as v
positive=v.verify_qualification();assert positive['qualified']and not positive['admitted']
count=0
def rejects(label,call):
 global count
 try:call()
 except(ValueError,AssertionError,KeyError,FileNotFoundError):
  count+=1;print('ROOT_MATERIAL_CONTROL_'+label+'=PASS');return
 raise AssertionError('accepted invalid '+label)
original=v.git
def foreign(*args):
 value=original(*args)
 if args[:2]==('diff','--name-status'):value+='\nA\tsrc/runtime/foreign.f90'
 return value
def dirty(*args):return ' M src/process/mod_irrigation_root_zone_summary.f90'if args[:2]==('status','--porcelain')else original(*args)
rejects('FOREIGN_SOURCE',lambda:v.verify_source(foreign))
rejects('DIRTY_SOURCE',lambda:v.verify_source(dirty))
for path in sorted(v.PRODUCTION):
 r=copy.deepcopy(v.record());r['postimages'][path]['blob']='0'*40
 with patch.object(v,'record',return_value=r):rejects('STALE_'+Path(path).stem,v.verify_source)
for label,field,value in [('SOURCE_TREE','production_source_tree','0'*40),('UNFINISHED','phase','IMPLEMENTED')]:
 r=copy.deepcopy(v.record());r[field]=value
 with patch.object(v,'record',return_value=r):rejects(label,v.verify_qualification)
r=copy.deepcopy(v.record());r['science_archive']['decoded_sha256']='0'*64
with patch.object(v,'record',return_value=r):rejects('CORRUPT_CAPSULE',v.evidence)
data=v.evidence()
for label,change in [
 ('SCIENCE_FAILED',lambda r:r.__setitem__('status','FAILED')),
 ('MISSING_NATIVE',lambda r:r['results'].pop()),
 ('DUPLICATE_NATIVE',lambda r:r['results'].__setitem__(-1,r['results'][0])),
 ('FAILED_NATIVE',lambda r:r['results'][0].__setitem__('returncode',1)),
 ('NATIVE_DIGEST',lambda r:r['results'][0].__setitem__('stdout_sha256','0'*64)),
 ('EXECUTED_INPUT',lambda r:r['source_inputs'].__setitem__('src/process/mod_irrigation_root_zone_summary.f90','0'*64)),
 ('UNEXECUTED_GENERATOR',lambda r:r['generated_inputs'].__setitem__('material_rooted7.f90','0'*64)),
 ('FAILED_EVENT',lambda r:r['events'][0].__setitem__('returncode',1)),
 ('UNCHECKED_COMPILER',lambda r:next(e for e in r['events']if '-c'in e['command'])['command'].remove('-fcheck=all'))]:
 d=copy.deepcopy(data);r=json.loads(d['physical/RESULTS.json']);change(r);d['physical/RESULTS.json']=json.dumps(r).encode()
 rejects(label,lambda:v.validate_science(d))
for label,change in [
 ('LEAF_FAILED',lambda r:r.__setitem__('status','FAILED')),
 ('LEAF_OPTIMIZATION',lambda r:r['records'].pop()),
 ('LEAF_INPUT_DRIFT',lambda r:r['records'][0]['inputs'].__setitem__('src/process/mod_irrigation_root_zone_summary.f90','0'*64))]:
 d=copy.deepcopy(data);r=json.loads(d['leaf/RESULTS.json']);change(r);d['leaf/RESULTS.json']=json.dumps(r).encode()
 rejects(label,lambda:v.validate_science(d))
d=copy.deepcopy(data);d['physical/material_rooted7.f90']+=b'\n! unexecuted discriminator\n'
rejects('CURRENT_DRIVER_NOT_EXECUTED',lambda:v.validate_science(d))
d=copy.deepcopy(data);name=next(p for p in d if p.startswith('physical/')and p.endswith('.stderr'));d.pop(name)
rejects('RAW_EVENT_MISSING',lambda:v.validate_science(d))
d=copy.deepcopy(data);r=json.loads(d['review/default_projections.json']);r.pop(next(iter(r)));d['review/default_projections.json']=json.dumps(r).encode()
with patch.object(v,'evidence',return_value=d):rejects('DEFAULT_BODY_MISSING',v.verify_source)
sys.path.insert(0,str(v.ROOT/'tests/nut-crop'));import verify_b111_request_successor as request
assert request.verify_source()['root_material_irrigation_successor']
rejects('PUBLIC_REQUEST_FOREIGN',lambda:request.verify_source(foreign))
print('ROOT_MATERIAL_NEGATIVE_CONTROLS='+str(count))
