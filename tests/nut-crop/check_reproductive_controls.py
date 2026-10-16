"""Fail-closed controls for bounded source science and unchanged incumbent bodies."""
from pathlib import Path
import copy,importlib,json,sys
from unittest.mock import patch
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(__file__).resolve().parent))
import verify_reproductive_successor as v
count=0
def rejects(label,call):
 global count
 try:call()
 except (ValueError,AssertionError,KeyError,FileNotFoundError):
  count+=1;print('REPRODUCTIVE_CONTROL_'+label+'=PASS');return
 raise AssertionError('accepted invalid '+label)
positive=v.verify_qualification()
assert positive['qualified']and positive['reproductive_successor']and not positive['admitted']
original=v.git
for path in ['src/foreign.f90','tests/foreign.py','reference/foreign.f90','.github/workflows/foreign.yml']:
 def foreign(*args,path=path):
  s=original(*args);return s+'\nA\t'+path if args[:2]==('diff','--name-status')else s
 rejects('FOREIGN_'+path.split('/')[0],lambda:v.verify_source(foreign))
def dirty(*args):return ' M src/crop/mod_crop_soil_n_day.f90'if args[:2]==('status','--porcelain')else original(*args)
rejects('DIRTY',lambda:v.verify_source(dirty))
for path in v.PRODUCTION:
 r=copy.deepcopy(v.record());r['postimages'][path]['blob']='0'*40
 with patch.object(v,'record',return_value=r):rejects('STALE_'+Path(path).stem,v.verify_source)
r=copy.deepcopy(v.record());r['science_archive']['decoded_sha256']='0'*64
with patch.object(v,'record',return_value=r):rejects('CORRUPT_ARCHIVE',v.evidence)
r=copy.deepcopy(v.record());r['stage']='IMPLEMENTED'
with patch.object(v,'record',return_value=r):rejects('UNFINISHED',v.verify_qualification)
data=v.evidence()
for label,mutate in [
 ('WRONG_EXECUTION',lambda r:r.__setitem__('execution_commit','0'*40)),
 ('WRONG_SOURCE',lambda r:r.__setitem__('source_tree','0'*40)),
 ('DIRECT_ONLY',lambda r:r.__setitem__('direct_only',True)),
 ('MISSING_DAILY',lambda r:r['reproductive']['O0'].__setitem__('daily_stdout','')),
 ('MISSING_PENDING',lambda r:r['reproductive']['O0'].__setitem__('joint_stdout','')),
 ('MISSING_POLICY_IDENTITY',lambda r:r['reproductive']['O2']['policy_identity_negatives'].pop()),
 ('MISSING_1253',lambda r:r['b111_request']['O0'].__setitem__('direct_stdout','')),
 ('MISSING_DECODER',lambda r:r['runs']['O0']['drivers']['test_crop_soil_joint']['decoder_negatives'].pop()),
 ('STALE_INPUT',lambda r:r['input_sha256'].__setitem__('src/crop/mod_crop_soil_n_day.f90','0'*64)),
]:
 d=copy.deepcopy(data);r=json.loads(d['final/result.json']);mutate(r);d['final/result.json']=json.dumps(r).encode()
 rejects(label,lambda d=d:v.validate_science(d))
for label,mutate in [
 ('FAILED_COMMAND',lambda es:es[0].__setitem__('returncode',1)),
 ('NO_TRAPS',lambda es:next(e for e in es if '-c'in e['command'])['command'].remove('-ffpe-trap=invalid,zero,overflow')),
 ('MISSING_NATIVE',lambda es:es.pop(next(i for i,e in enumerate(es)if e['category']=='native'and Path(e['command'][0]).stem=='test_reproductive_joint'))),
 ('MISSING_PROVIDER',lambda es:es.pop(next(i for i,e in enumerate(es)if '-c'in e['command']and str(e['command'][e['command'].index('-c')+1]).endswith('/src/crop/mod_b111_reproductive_n_process.f90')))),
]:
 d=copy.deepcopy(data);es=json.loads(d['final/events.json']);mutate(es);d['final/events.json']=json.dumps(es).encode()
 rejects(label,lambda d=d:v.validate_science(d))
for label,mutate in [
 ('MISSING_LITERAL',lambda r:r.__setitem__('authority_sha256','0'*64)),
 ('WRONG_LITERAL_LINES',lambda r:r.__setitem__('literal_lines',[[1,2]])),
 ('MISSING_PROCESS_GUARDS',lambda r:r.__setitem__('stdout','')),
]:
 d=copy.deepcopy(data);r=json.loads(d['process/result.json']);mutate(r);d['process/result.json']=json.dumps(r).encode()
 rejects(label,lambda d=d:v.validate_science(d))
for path in ('final/O0/reproductive-fresh.bin','final/O2/reproductive-expected.bin.opaque','final/O0/b111-restart.bin','final/O2/test_crop_soil_joint-expected.bin','process/literal.f90'):
 d=copy.deepcopy(data);d[path]+=b'corrupt';rejects('CORRUPT_'+Path(path).name,lambda d=d:v.validate_science(d))
d=copy.deepcopy(data);e=json.loads(d['final/events.json'])[0];d.pop('final/'+e['stderr_file']);rejects('MISSING_RAW',lambda:v.validate_science(d))
d=copy.deepcopy(data);review=json.loads(d['review/insertions.json']);review.pop(next(iter(review)));d['review/insertions.json']=json.dumps(review).encode();rejects('MISSING_DEFAULT_REVIEW',lambda:v.validate_science(d))
for folder,name in [('tests/nut-sol','verify_dynamic_pond_successor'),('tests/mc-irr01','verify_material_root_successor'),('tests/nut-crop','verify_b111_request_successor'),('tests/fpm','verify_int12c_successor'),('tests/crop-harvest','verify_harvest_successor')]:
 sys.path.insert(0,str(v.ROOT/folder));m=importlib.import_module(name);assert m.verify_source()['reproductive_successor'],name
print('REPRODUCTIVE_ADMISSION_CONTROLS='+str(count)+'|PASS')
