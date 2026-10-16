"""Reject weakened provenance, missing native science and stale physical oracles."""
from pathlib import Path
import copy,importlib,json,sys
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parent))
import verify_material_root_successor as v
if (v.ROOT/'tests/nut-sol/verify_pond_successor.py').exists():
 import subprocess,sys
 subprocess.run([sys.executable,'-B',str(v.ROOT/'tests/nut-sol/check_pond_controls.py')],check=True);raise SystemExit(0)
if (v.ROOT/'docs/science/MC_SOL01_SURFACE_MASS_RESTART_CONTRACT_20261016.md').exists():
 import subprocess
 subprocess.run([sys.executable,'-B',str(v.ROOT/'tests/nut-sol/check_surface_evidence_controls.py')],check=True)
 raise SystemExit(0)
count=0
def rejects(label,call):
 global count
 try:call()
 except(ValueError,AssertionError,KeyError,FileNotFoundError):
  count+=1;print('MATERIAL_ROOT_CONTROL_'+label+'=PASS');return
 raise AssertionError('accepted invalid '+label)
positive=v.verify_qualification();assert positive['qualified']and not positive['admitted']
original=v.git
for path in ['src/runtime/unknown.f90','tests/unknown.py','reference/unknown.f90']:
 def foreign(*args,path=path):
  s=original(*args)
  return s+'\nA\t'+path if args[:2]==('diff','--name-status')else s
 rejects('FOREIGN_'+path.split('/')[0],lambda:v.verify_source(foreign))
def dirty(*args):return ' M src/runtime/mod_fmr_production_application_bootstrap.f90'if args[:2]==('status','--porcelain')else original(*args)
rejects('DIRTY_SOURCE',lambda:v.verify_source(dirty))
for path in v.PRODUCTION:
 r=copy.deepcopy(v.record());r['postimages'][path]['blob']='0'*40
 with patch.object(v,'record',return_value=r):rejects('STALE_'+Path(path).stem,v.verify_source)
r=copy.deepcopy(v.record());r['science_archive']['decoded_sha256']='0'*64
with patch.object(v,'record',return_value=r):rejects('CORRUPT_CAPSULE',v.evidence)
r=copy.deepcopy(v.record());r['phase']='IMPLEMENTED'
with patch.object(v,'record',return_value=r):rejects('UNFINISHED_SCIENCE',v.verify_qualification)
data=v.evidence()
for label,mutate in [
 ('MISSING_NATIVE',lambda x:x['results'].pop()),
 ('DUPLICATE_NATIVE',lambda x:x['results'].__setitem__(-1,x['results'][0])),
 ('FAILED_NATIVE',lambda x:x['results'][0].__setitem__('returncode',1)),
 ('MISSING_NATIVE_COMMAND',lambda x:x['events'].__setitem__(next(i for i,e in enumerate(x['events'])if '/test-'in e['command'][0]),{'command':['false'],'returncode':0})),
 ('MISSING_TRAPS',lambda x:next(e for e in x['events']if '-c'in e['command'])['command'].remove('-ffpe-trap=invalid,zero,overflow'))]:
 d=copy.deepcopy(data);r=json.loads(d['physical/RESULTS.json']);mutate(r);d['physical/RESULTS.json']=json.dumps(r).encode()
 rejects(label,lambda d=d:v.validate_science(d))
d=copy.deepcopy(data);r=json.loads(d['rain/RESULTS.json']);r['results'].pop();d['rain/RESULTS.json']=json.dumps(r).encode()
rejects('MISSING_UNCAPPED_RAIN_NATIVE',lambda:v.validate_science(d))
for label,mutate in [('MISSING_OWNER',lambda x:x.pop()),('DUPLICATE_OWNER',lambda x:x.__setitem__(-1,x[0])),('FAILED_OWNER',lambda x:x[0].__setitem__('returncode',1))]:
 d=copy.deepcopy(data);r=json.loads(d['owners/results.json']);mutate(r);d['owners/results.json']=json.dumps(r).encode()
 rejects(label,lambda d=d:v.validate_science(d))
d=copy.deepcopy(data);d['physical/material_2_1.f90']+=b'\n! stale unexecuted scientific generator\n'
rejects('UNEXECUTED_DRIVER',lambda:v.validate_science(d))
d=copy.deepcopy(data);r=json.loads(d['review/default_projections.json']);r.pop(next(iter(r)));d['review/default_projections.json']=json.dumps(r).encode()
rejects('MISSING_ORIGINAL_BODY_REVIEW',lambda:v.validate_science(d))
d=copy.deepcopy(data);d.pop(next(p for p in d if p.startswith('physical/')and p.endswith('.stderr')))
rejects('MISSING_RAW_EVENT',lambda:v.validate_science(d))
for folder,name in [('tests/nut-crop','verify_b111_request_successor'),('tests/mc-irr01','verify_managed_weather_successor'),
 ('tests/fwof/pp02','verify_b111_nfixation_successor'),('tests/fpm','verify_hyd_successor'),
 ('tests/root-growth','verify_daily_density_successor'),('tests/fpm','verify_int12c_successor')]:
 sys.path.insert(0,str(v.ROOT/folder));module=importlib.import_module(name)
 assert module.verify_source()['material_root_irrigation_successor'],name
print('MATERIAL_ROOT_ADMISSION_CONTROLS='+str(count)+'|PASS')
