"""Fail-closed source/evidence controls for actual changing pond storage."""
from pathlib import Path
import copy,importlib,json,sys
from unittest.mock import patch
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(__file__).resolve().parent))
import verify_dynamic_pond_successor as v
count=0
def rejects(label,call):
    global count
    try:call()
    except (ValueError,AssertionError,KeyError,FileNotFoundError):
        count+=1;print('DYNAMIC_POND_CONTROL_'+label+'=PASS');return
    raise AssertionError('accepted invalid '+label)
positive=v.verify_qualification()
assert positive['qualified']and positive['dynamic_pond_successor']and not positive['admitted']
original=v.git
for path in ['src/foreign.f90','tests/foreign.py','reference/foreign.f90','.github/workflows/foreign.yml']:
    def foreign(*args,path=path):
        s=original(*args);return s+'\nA\t'+path if args[:2]==('diff','--name-status')else s
    rejects('FOREIGN_'+path.split('/')[0],lambda:v.verify_source(foreign))
def dirty(*args):return ' M src/runtime/mod_fmr_serialized_reference_backend.f90'if args[:2]==('status','--porcelain')else original(*args)
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
    ('WRONG_EXECUTION',lambda r:r.__setitem__('baseline','0'*40)),
    ('MISSING_DRAIN',lambda r:r['runs']['O0'].__setitem__('physical_stdout','')),
    ('MISSING_FILL',lambda r:r['runs']['O0'].__setitem__('fill_stdout','')),
    ('MISSING_DRY',lambda r:r['runs']['O2'].__setitem__('dry_stdout','')),
    ('MISSING_DECODER',lambda r:r['runs']['O0']['restart_negatives'].pop()),
    ('WRONG_OLD_ENDPOINT',lambda r:r['runs']['O2'].__setitem__('original_surface_endpoint','0'*64)),
    ('STALE_INPUT',lambda r:r['input_sha256'].__setitem__('src/runtime/mod_fmr_b111_pond_joint_application.f90','0'*64)),
]:
    d=copy.deepcopy(data);r=json.loads(d['final/result.json']);mutate(r);d['final/result.json']=json.dumps(r).encode()
    rejects(label,lambda d=d:v.validate_science(d))
for label,mutate in [
    ('FAILED_COMMAND',lambda es:es[0].__setitem__('returncode',1)),
    ('NO_TRAPS',lambda es:next(e for e in es if '-c'in e['command'])['command'].remove('-ffpe-trap=invalid,zero,overflow')),
    ('MISSING_NATIVE',lambda es:es.pop(next(i for i,e in enumerate(es)if e['category']=='physical_native'))),
    ('MISSING_PRESERVATION',lambda es:es.pop(next(i for i,e in enumerate(es)if e['category']=='preservation_native'))),
]:
    d=copy.deepcopy(data);es=json.loads(d['final/events.json']);mutate(es);d['final/events.json']=json.dumps(es).encode()
    rejects(label,lambda d=d:v.validate_science(d))
for path in ('final/O0/fill-fresh.bin','final/O2/dry-fresh.bin','final/O0/wet-incumbent.bin','final/O2/dry-incumbent-expected.bin','final/O0/old-restart.bin'):
    d=copy.deepcopy(data);d[path]+=b'corrupt';rejects('CORRUPT_'+Path(path).name,lambda d=d:v.validate_science(d))
d=copy.deepcopy(data);e=json.loads(d['final/events.json'])[0];d.pop('final/'+e['stderr']);rejects('MISSING_RAW',lambda:v.validate_science(d))
d=copy.deepcopy(data);review=json.loads(d['review/insertions.json']);review.pop(next(iter(review)));d['review/insertions.json']=json.dumps(review).encode();rejects('MISSING_DEFAULT_REVIEW',lambda:v.validate_science(d))
for folder,name in [('tests/mc-irr01','verify_material_root_successor'),('tests/nut-crop','verify_b111_request_successor'),('tests/fpm','verify_int12c_successor'),('tests/crop-harvest','verify_harvest_successor')]:
    sys.path.insert(0,str(v.ROOT/folder));m=importlib.import_module(name);assert m.verify_source()['dynamic_pond_successor'],name
print('DYNAMIC_POND_ADMISSION_CONTROLS='+str(count)+'|PASS')
