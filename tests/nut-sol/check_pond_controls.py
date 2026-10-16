"""Negative controls for pond provenance, science completeness and owner dispatch."""
from pathlib import Path
import copy
import importlib
import json
import sys
from unittest.mock import patch

sys.dont_write_bytecode = True
sys.path.insert(0,str(Path(__file__).resolve().parent))
import verify_pond_successor as v

count = 0
def rejects(label, call):
    global count
    try:
        call()
    except (ValueError, AssertionError, KeyError, FileNotFoundError):
        count += 1
        print('POND_CONTROL_'+label+'=PASS')
        return
    raise AssertionError('accepted invalid '+label)

positive = v.verify_qualification()
assert positive['qualified'] and positive['pond_successor'] and not positive['admitted']
original = v.git
for path in ['src/foreign.f90','tests/foreign.py','reference/foreign.f90','.github/workflows/foreign.yml']:
    def foreign(*args,path=path):
        s = original(*args)
        return s+'\nA\t'+path if args[:2]==('diff','--name-status') else s
    rejects('FOREIGN_'+path.split('/')[0], lambda:v.verify_source(foreign))
def dirty(*args):
    return ' M src/process/mod_b111_persistent_pond.f90' if args[:2]==('status','--porcelain') else original(*args)
rejects('DIRTY',lambda:v.verify_source(dirty))
for path in v.PRODUCTION:
    r = copy.deepcopy(v.record())
    r['postimages'][path]['blob'] = '0'*40
    with patch.object(v,'record',return_value=r):
        rejects('STALE_'+Path(path).stem,v.verify_source)
r = copy.deepcopy(v.record())
r['science_archive']['decoded_sha256'] = '0'*64
with patch.object(v,'record',return_value=r):
    rejects('CORRUPT_ARCHIVE',v.evidence)
r = copy.deepcopy(v.record())
r['stage'] = 'IMPLEMENTED'
with patch.object(v,'record',return_value=r):
    rejects('UNFINISHED',v.verify_qualification)
data = v.evidence()
for label, mutate in [
    ('WRONG_EXECUTION', lambda r:r.__setitem__('baseline','0'*40)),
    ('MISSING_DRY', lambda r:r['runs']['O0'].__setitem__('dry_stdout','')),
    ('MISSING_PHYSICAL', lambda r:r['runs']['O2'].__setitem__('physical_stdout','')),
    ('MISSING_NEGATIVE', lambda r:r['runs']['O0']['restart_negatives'].pop()),
    ('WRONG_INCUMBENT_ENDPOINT', lambda r:r['runs']['O2'].__setitem__('original_surface_endpoint','0'*64)),
    ('STALE_INPUT', lambda r:r['input_sha256'].__setitem__('src/process/mod_b111_persistent_pond.f90','0'*64)),
]:
    d = copy.deepcopy(data)
    r = json.loads(d['final/result.json'])
    mutate(r)
    d['final/result.json'] = json.dumps(r).encode()
    rejects(label,lambda d=d:v.validate_science(d))
for label, mutate in [
    ('FAILED_COMMAND',lambda events:events[0].__setitem__('returncode',1)),
    ('NO_TRAPS',lambda events:next(e for e in events if '-c' in e['command'])['command'].remove('-ffpe-trap=invalid,zero,overflow')),
    ('MISSING_NATIVE_COMMAND',lambda events:events.pop(next(i for i,e in enumerate(events) if e['category']=='physical_native'))),
]:
    d=copy.deepcopy(data)
    events=json.loads(d['final/events.json'])
    mutate(events)
    d['final/events.json']=json.dumps(events).encode()
    rejects(label,lambda d=d:v.validate_science(d))
d=copy.deepcopy(data)
d['final/O0/dry-fresh.bin']+=b'corrupt'
rejects('WRONG_DRY_RESTART',lambda:v.validate_science(d))
d=copy.deepcopy(data)
e=json.loads(d['final/events.json'])[0]
d.pop('final/'+e['stderr'])
rejects('MISSING_RAW',lambda:v.validate_science(d))
d=copy.deepcopy(data)
review=json.loads(d['review/modified_patches.json'])
review.pop(next(iter(review)))
d['review/modified_patches.json']=json.dumps(review).encode()
rejects('MISSING_SHARED_REVIEW',lambda:v.validate_science(d))
for folder,name in [('tests/mc-irr01','verify_material_root_successor'),('tests/nut-crop','verify_b111_request_successor'),
                    ('tests/fpm','verify_int12c_successor'),('tests/crop-harvest','verify_harvest_successor')]:
    sys.path.insert(0,str(v.ROOT/folder))
    m=importlib.import_module(name)
    assert m.verify_source()['pond_successor'],name
print('POND_ADMISSION_CONTROLS='+str(count)+'|PASS')
