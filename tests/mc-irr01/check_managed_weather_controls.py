"""Falsify the current managed-weather source/science proof through owning routes."""
from pathlib import Path
import copy,importlib,inspect,json,sys
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parent))
import verify_managed_weather_successor as v
if (v.ROOT/'tests/nut-crop/check_b111_request_controls.py').exists():
 import runpy
 runpy.run_path(str(v.ROOT/'tests/nut-crop/check_b111_request_controls.py'),run_name='__main__')
 raise SystemExit(0)

def rejects(label,call):
 try:call()
 except (ValueError,AssertionError,KeyError,FileNotFoundError):
  print('MANAGED_WEATHER_CONTROL_'+label+'=PASS');return
 raise AssertionError('accepted invalid '+label)
positive=v.verify_qualification();assert positive['qualified']and not positive['admitted']
original=v.git

def foreign(*args):
 value=original(*args)
 if args[:2]==('diff','--name-status'):value+='\nA\tsrc/runtime/unknown_source.f90'
 return value

def dirty(*args):return ' M src/runtime/mod_fmr_production_application_bootstrap.f90'if args[:2]==('status','--porcelain')else original(*args)
rejects('FOREIGN_SOURCE',lambda:v.verify_source(foreign))
rejects('DIRTY_SOURCE',lambda:v.verify_source(dirty))
r=copy.deepcopy(v.record());r['science_archive']['decoded_sha256']='0'*64
with patch.object(v,'record',return_value=r):rejects('CORRUPT_CAPSULE',v.evidence)
r=copy.deepcopy(v.record());r['phase']='IMPLEMENTED'
with patch.object(v,'record',return_value=r):rejects('UNFINISHED_SCIENCE',v.verify_qualification)
for path in v.PRODUCTION:
 r=copy.deepcopy(v.record());r['postimages'][path]['blob']='0'*40
 with patch.object(v,'record',return_value=r):rejects('STALE_'+Path(path).stem,v.verify_source)
data=v.evidence()
for label,change in [
 ('MISSING_NATIVE',lambda x:x['results'].pop()),
 ('DUPLICATE_NATIVE',lambda x:x['results'].__setitem__(-1,x['results'][0])),
 ('FAILED_NATIVE',lambda x:x['results'][0].__setitem__('returncode',1)),
 ('INCOMPLETE_PHYSICAL',lambda x:x.__setitem__('status','FAIL'))]:
 d=copy.deepcopy(data);x=json.loads(d['physical/RESULTS.json']);change(x);d['physical/RESULTS.json']=json.dumps(x).encode()
 with patch.object(v,'evidence',return_value=d):rejects(label,v.verify_qualification)
for label,change in [
 ('MISSING_OWNER',lambda x:x.pop()),
 ('DUPLICATE_OWNER',lambda x:x.__setitem__(-1,x[0])),
 ('FAILED_OWNER',lambda x:x[0].__setitem__('returncode',1))]:
 d=copy.deepcopy(data);x=json.loads(d['owners/results.json']);change(x);d['owners/results.json']=json.dumps(x).encode()
 with patch.object(v,'evidence',return_value=d):rejects(label,v.verify_qualification)
d=copy.deepcopy(data);key=next(p for p in d if p.startswith('physical/')and p.endswith('.stderr'));d.pop(key)
with patch.object(v,'evidence',return_value=d):rejects('MISSING_RAW_EVENT',v.verify_qualification)
d=copy.deepcopy(data);d['physical/managed_driver.f90']+=b'\n! unexecuted discriminator\n'
with patch.object(v,'evidence',return_value=d):rejects('UNEXECUTED_MANAGED_DRIVER',v.verify_qualification)
d=copy.deepcopy(data);x=json.loads(d['review/incumbent_projections.json']);x.pop(next(iter(x)));d['review/incumbent_projections.json']=json.dumps(x).encode()
with patch.object(v,'evidence',return_value=d):rejects('MISSING_DEFAULT_REVIEW',v.verify_qualification)
for path,name in [('tests/fwof/pp02','verify_b111_nfixation_successor'),('tests/fpm','verify_hyd_successor'),('tests/root-growth','verify_daily_density_successor'),('tests/fpm','verify_int12c_successor'),
 ('tests/crop-harvest','verify_harvest_successor'),('tests/nut-sol','verify_surface_successor'),
 ('tests/root-growth','verify_swrd2_successor'),('tests/root-growth','verify_swrd3_successor'),
 ('tests/crop-co2','verify_co2_successor'),('tests/nut-calendar','verify_calendar_successor'),('tests/nut-input','verify_input_successor')]:
 sys.path.insert(0,str(v.ROOT/path));module=importlib.import_module(name)
 assert module.verify_source()['managed_irrigation_successor'],name
 if 'git_reader'in inspect.signature(module.verify_source).parameters:
  rejects('PUBLIC_'+name,lambda module=module:module.verify_source(foreign))
 else:
  with patch.object(v,'git',side_effect=foreign):rejects('PUBLIC_'+name,lambda module=module:module.verify_source())
print('MANAGED_WEATHER_CURRENT_ADMISSION_CONTROLS=PASS')
