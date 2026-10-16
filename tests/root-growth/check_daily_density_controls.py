"""Falsify the current bounded proof; original controls run at their own base."""
from pathlib import Path
import copy,importlib,json,sys
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parent))
import verify_daily_density_successor as v
def rejects(label,call):
 try:call()
 except (ValueError,AssertionError,KeyError,FileNotFoundError):
  print('DAILY_DENSITY_CONTROL_'+label+'=PASS');return
 raise AssertionError('accepted invalid '+label)
positive=v.verify_qualification();assert positive['qualified']and not positive['admitted']
original=v.git
def foreign(*args):
 value=original(*args)
 if args[:2]==('diff','--name-status'):value+='\nA\tsrc/runtime/unknown_source.f90'
 return value
def dirty(*args):return ' M src/runtime/mod_fmr_wofost_crop_transaction.f90'if args[:2]==('status','--porcelain')else original(*args)
rejects('FOREIGN_SOURCE',lambda:v.verify_source(foreign))
rejects('DIRTY_SOURCE',lambda:v.verify_source(dirty))
r=copy.deepcopy(v.record());r['science_archive']['decoded_sha256']='0'*64
with patch.object(v,'record',return_value=r):rejects('ARCHIVE_CORRUPTION',v.evidence)
r=copy.deepcopy(v.record());r['phase']='DIRECT_ONLY'
with patch.object(v,'record',return_value=r):rejects('UNFINISHED_SCIENCE',v.verify_qualification)
for path in v.PRODUCTION:
 r=copy.deepcopy(v.record());r['postimages'][path]['blob']='0'*40
 with patch.object(v,'record',return_value=r):rejects('PROVIDER_'+Path(path).stem,v.verify_source)
data=v.evidence()
for prefix,key in [('direct','runs'),('physical','results'),('nodal','results')]:
 d=copy.deepcopy(data);name=prefix+('/result.json'if prefix=='direct'else'/RESULTS.json')
 result=json.loads(d[name]);result[key]=result[key][:-1];d[name]=json.dumps(result).encode()
 with patch.object(v,'evidence',return_value=d):rejects('INCOMPLETE_'+prefix.upper(),v.verify_qualification)
 d=copy.deepcopy(data);result=json.loads(d[name]);result['status']='FAIL';d[name]=json.dumps(result).encode()
 with patch.object(v,'evidence',return_value=d):rejects('FAILED_'+prefix.upper(),v.verify_qualification)
d=copy.deepcopy(data);rows=json.loads(d['owners/results.json']);rows[0]['returncode']=1;d['owners/results.json']=json.dumps(rows).encode()
with patch.object(v,'evidence',return_value=d):rejects('FAILED_INCUMBENT_OWNER',v.verify_qualification)
d=copy.deepcopy(data);key=next(p for p in d if p.startswith('nodal/')and p.endswith('.stderr'));d.pop(key)
with patch.object(v,'evidence',return_value=d):rejects('MISSING_RAW_EVENT_STREAM',v.verify_qualification)
d=copy.deepcopy(data);projection=json.loads(d['review/default_projections.json']);projection.pop(next(iter(projection)));d['review/default_projections.json']=json.dumps(projection).encode()
with patch.object(v,'evidence',return_value=d):rejects('INCOMPLETE_DEFAULT_PROJECTION',v.verify_qualification)
# Every public predecessor proof must reach the new source refusal, rather
# than accidentally returning an old green proof on the changed production.
routes=[('tests/fpm','verify_int12c_successor'),('tests/crop-harvest','verify_harvest_successor'),
 ('tests/nut-sol','verify_surface_successor'),('tests/root-growth','verify_swrd2_successor'),
 ('tests/root-growth','verify_swrd3_successor'),('tests/crop-co2','verify_co2_successor'),
 ('tests/nut-calendar','verify_calendar_successor'),('tests/nut-input','verify_input_successor')]
for path,name in routes:
 sys.path.insert(0,str(v.ROOT/path));module=importlib.import_module(name)
 result=module.verify_source();assert result['daily_density_successor'],name
 with patch.object(v,'git',side_effect=foreign):
  rejects('PUBLIC_SOURCE_'+name,lambda module=module:module.verify_source())
print('DAILY_DENSITY_CURRENT_ADMISSION_CONTROLS=PASS')
