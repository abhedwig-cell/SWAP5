"""Discriminate source drift, unfinished/missing science and false restart proof."""
from pathlib import Path
import copy,json,sys
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parent))
import verify_b111_request_successor as v
if (v.ROOT/'tests/mc-irr01/check_root_material_controls.py').exists():
 import runpy
 runpy.run_path(str(v.ROOT/'tests/mc-irr01/check_root_material_controls.py'),run_name='__main__')
 raise SystemExit(0)
positive=v.verify_qualification();assert positive['qualified']and not positive['admitted']
count=0
def rejects(label,call):
 global count
 try:call()
 except(ValueError,AssertionError,KeyError,FileNotFoundError):
  count+=1;print('B111_REQUEST_CONTROL_'+label+'=PASS');return
 raise AssertionError('accepted invalid '+label)
original=v.git
for path in ['src/runtime/foreign.f90','tests/foreign.py','reference/foreign.f90']:
 def foreign(*args):
  value=original(*args)
  if args[:2]==('diff','--name-status'):value+='\nA\t'+path
  return value
 rejects('FOREIGN_'+path.split('/')[0],lambda:v.verify_source(foreign))
def dirty(*args):return ' M src/crop/mod_crop_soil_n_day.f90'if args[:2]==('status','--porcelain')else original(*args)
rejects('DIRTY_SOURCE',lambda:v.verify_source(dirty))
for path in sorted(v.PRODUCTION):
 r=copy.deepcopy(v.record());r['postimages'][path]['blob']='0'*40
 with patch.object(v,'record',return_value=r):rejects('STALE_'+Path(path).stem,v.verify_source)
r=copy.deepcopy(v.record());r['production_source_tree']='0'*40
with patch.object(v,'record',return_value=r):rejects('SOURCE_TREE',v.verify_source)
r=copy.deepcopy(v.record());r['science_archive']['decoded_sha256']='0'*64
with patch.object(v,'record',return_value=r):rejects('CORRUPT_CAPSULE',v.evidence)
r=copy.deepcopy(v.record());r['phase']='IMPLEMENTED'
with patch.object(v,'record',return_value=r):rejects('UNFINISHED',v.verify_qualification)
data=v.evidence()
for label,change in [
 ('SCIENCE_FAILED',lambda r:r.__setitem__('status','FAILED')),
 ('OPTIMIZATION_MISSING',lambda r:r['b111_request'].pop('O2')),
 ('DIRECT_MISSING',lambda r:r['b111_request']['O0'].__setitem__('direct_stdout','ABSENT')),
 ('SECOND_FIXATION',lambda r:r['b111_request']['O0'].__setitem__('direct_stdout',r['b111_request']['O0']['direct_stdout'].replace('B111_REQUEST_SINGLE_FIXATION_BALANCE_GATES_REPLAY=PASS','ABSENT'))),
 ('RESTART_DIGEST',lambda r:r['b111_request']['O0'].__setitem__('endpoint_sha256','0'*64)),
 ('POLICY_IDENTITY_NEGATIVES',lambda r:r['b111_request']['O0'].__setitem__('policy_identity_negatives',0)),
 ('DEFAULT_DRIVER_MISSING',lambda r:r['runs']['O0']['drivers'].pop('test_crop_soil_day')),
 ('DEFAULT_DECODERS_MISSING',lambda r:r['runs']['O0']['drivers']['test_crop_soil_joint'].__setitem__('decoder_negatives',[])),
 ('EXECUTED_INPUT_DRIFT',lambda r:r['input_sha256'].__setitem__('src/crop/mod_crop_soil_n_day.f90','0'*64))]:
 d=copy.deepcopy(data);r=json.loads(d['science/result.json']);change(r);d['science/result.json']=json.dumps(r).encode()
 rejects(label,lambda:v.validate_science(d))
for label,change in [
 ('FAILED_EVENT',lambda es:es[0].__setitem__('returncode',1)),
 ('UNCHECKED_COMPILER',lambda es:es[0]['command'].remove('-fcheck=all')),
 ('JOINT_COMMAND_MISSING',lambda es:es.__setitem__(slice(None),[e for e in es if not(e['category']=='native'and e['command'][-1]=='b111'and e['command'][1]=='write')]))]:
 d=copy.deepcopy(data);es=json.loads(d['science/events.json']);change(es);d['science/events.json']=json.dumps(es).encode()
 rejects(label,lambda:v.validate_science(d))
for label,name in [('RAW_MISSING','science/0000.stdout'),('OPAQUE_ENDPOINT','science/O0/b111-expected.bin.opaque'),('DEFAULT_ENDPOINT','science/O0/test_crop_soil_joint-expected.bin'),('COMPONENT_MISSING','component.log'),('LITERAL_MISSING','literal/O2.stdout')]:
 d=copy.deepcopy(data);d[name]=b'corrupt';rejects(label,lambda:v.validate_science(d))
print('B111_REQUEST_NEGATIVE_CONTROLS='+str(count))
