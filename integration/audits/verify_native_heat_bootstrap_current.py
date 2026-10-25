"""Source-bound original heat bootstrap; old procedure/type bytes stay unchanged."""
import base64,csv,hashlib,io,json,re,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='de6299171e3b13d8f444993e9bf8893ad15fec72'
STATUS='integration/mc-sol01/drainage/NATIVE_HEAT_BOOTSTRAP_STATUS.json'
SELF='integration/audits/verify_native_heat_bootstrap_current.py'
PARENT='integration/audits/verify_macro_trace_current.py'
HEAT='src/process/mod_restricted_soil_temperature.f90'
SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits']
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def projection():
 text=subprocess.check_output(['git','show',BASE+':'+PARENT],cwd=ROOT,text=True)
 for name,args in [('source','reader,changed'),('verify',''),('fsi35_successors',''),('self_test','')]:
  start=re.search(r'^def '+name+r'\(',text,re.M).start();at=text.index(':',text.index(')',start))+1
  if text[at:at+1]!='\n':text=text[:at]+'\n '+text[at:]
  at=text.index('\n',start)+1
  text=text[:at]+" if (ROOT/'"+STATUS+"').is_file():return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+text[at:]
 return text.encode()
def preserved_heat(reader):
 text=reader(HEAT).decode();a=text.index('  ! Original SWAP4.3.1 temperature.f90 task1');z=text.index('  subroutine trial_restricted_soil_temperature',a)
 rest=(text[:a]+text[z:]).replace('  public :: initialize_soil_temperature_from_texture\n','',1)
 assert rest==subprocess.check_output(['git','show',BASE+':'+HEAT],cwd=ROOT,text=True),'pre-existing heat procedure/type changed'
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 if (ROOT/'integration/mc-sol01/drainage/HYDROSTATIC_BOOTSTRAP_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_hydrostatic_bootstrap_current.py'))['source'](reader,changed)
 r=json.loads(reader(STATUS));assert r['baseline']==BASE;git('merge-base','--is-ancestor',BASE,'HEAD')
 delta={x.split('\t')[1]:x.split('\t')[0]for x in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}
 assert delta==r['scientific_delta'],'foreign native heat delta'
 assert {p for p in delta if p.startswith('src/')}=={HEAT}
 assert {p for p in delta if p.startswith('app/')}=={'app/solute_column/main.f90','app/solute_column/read_swp_heat.f90'}
 assert not git('status','--porcelain','--',*SCIENCE),'unpersisted native heat input'
 assert reader(PARENT)==projection(),'prior macro assertion bodies changed';preserved_heat(reader)
 for p,h in r['postimages'].items():assert sha(reader(p))==h,('native heat input',p)
 if changed is not None:
  for p in changed:assert p in delta or subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'foreign caller'
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def capsule():
 e=json.loads((ROOT/STATUS).read_bytes())['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes(),validate=True);assert sha(raw)==e['sha256']and len(raw)==e['bytes']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==e['members']==len({m.name for m in ms});assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms)
  f={m.name:t.extractfile(m).read()for m in ms}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(b)for p,b in f.items()};return f
def validate(f):
 js=lambda p:json.loads(f[p]);parent=js('parent/proof.json');assert parent['owner']['qualified']and len(parent['controls'])==17
 raw=f['parent/commit.raw'];assert hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==BASE
 assert f['parent/owner.py']==subprocess.check_output(['git','show',BASE+':'+PARENT],cwd=ROOT)
 rows=lambda p:list(csv.DictReader(io.StringIO(f[p].decode())))
 for opt in ['O0','O2']:
  s=js('source-'+opt+'/RESULT.json');assert s['status']=='ORIGINAL_NATIVE_NUMERIC_HEAT_BOOTSTRAP_AND_NEGATIVES_PASS'
  assert s['negative_processes']==11 and s['constructor_controls']==14
  assert len(s['results']['original'])==112 and len(s['results']['nonuniform'])==112
  assert sum(e['returncode']!=0 for e in s['events'])==11
  assert sha(f['source-'+opt+'/original-temperature.f90'])==s['original_temperature_sha256']
  assert sha(f['source-'+opt+'/literal.f90'])==s['literal_sha256']
  if opt=='O2':assert s['results']==js('source-O0/RESULT.json')['results']
  for p,h in s['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,('current component input',p)
  a=js('app-'+opt+'/RESULT.json');assert a['status']=='NATIVE_HEAT_FILE_COUPLING_RESTART_AND_INCUMBENT_PASS'and a['phase']=='full'
  assert len(a['events'])==23 and sum(e['returncode']!=0 for e in a['events'])==9
  for p,h in a['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,('current file input',p)
  if opt=='O2':assert a['results']==js('app-O0/RESULT.json')['results'],'cross-optimization physical drift'
  for exponent in ['0.5','1.0','2.0']:
   prefix='app-'+opt+'/bootstrap-'+exponent+'/';record=a['results'][exponent]
   for name in ['restart.bin','state.csv','temperature.csv','endpoint.csv']:
    assert f[prefix+'full/'+name]==f[prefix+'resumed/'+name]
    assert sha(f[prefix+'full/'+name])==record['files'][name]
   data=rows(prefix+'full/budget.csv');assert len(data)==3 and rows(prefix+'resumed/budget.csv')==data[1:]
   for row in data:assert abs(float(row['water_residual_cm']))<1e-10 and abs(float(row['solute_residual_mg_cm2']))<1e-10
   for name in ['forbidden-source-restart','forbidden-temperature-override','forbidden-conflicting-top']:assert not any(p.startswith(prefix+name+'/')for p in f)
  for case in ['incumbent-water','incumbent-explicit-heat']:
   for name,h in a['results'][case].items():assert f['app-'+opt+'/'+case+'/current/'+name]==f['app-'+opt+'/'+case+'/preimage/'+name]and sha(f['app-'+opt+'/'+case+'/current/'+name])==h
 for target,member in [('examples/solute_column/native_heat.nml','app-O2/bootstrap-0.5/input.nml'),('examples/solute_column/layered_heat.swp','app-O2/bootstrap-0.5/source.swp')]:assert(ROOT/target).read_bytes()==f[member],'example differs from executed input'
 return dict(qualified=True,status='SOURCE_NATIVE_NUMERIC_HEAT_BOOTSTRAP_AND_FILE_RESTART_QUALIFIED',original_Andelst_heat_nodes=112,source_O0_O2_exact=True,source_negative_processes=22,constructor_negative_assertions=28,coupled_cases=6,fresh_process_restarts=6,file_negative_processes=18,incumbent_water_and_explicit_heat_exact=True,old_heat_procedures_types_exact=True,full_original_native_Andelst=False,macropore_or_drainage_heat_composition=False,full_historical_migration=False,canonically_admitted=False)
def verify():
 if (ROOT/'integration/mc-sol01/drainage/HYDROSTATIC_BOOTSTRAP_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_hydrostatic_bootstrap_current.py'))['verify']()
 source();return validate(capsule())
def fsi35_successors():
 if (ROOT/'integration/mc-sol01/drainage/HYDROSTATIC_BOOTSTRAP_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_hydrostatic_bootstrap_current.py'))['fsi35_successors']()
 source();r=json.loads(capsule()['parent/proof.json'])['fsi35'];deps=json.loads((ROOT/'integration/audits/FCI93_NON_M1_COMPILE_DEPENDENCIES_20261011.json').read_bytes())['dependencies']
 for d in deps:assert git('rev-parse','HEAD:'+d['path'])==git('rev-parse',BASE+':'+d['path']),'changed FSI35 executable source'
 return r
def self_test():
 if (ROOT/'integration/mc-sol01/drainage/HYDROSTATIC_BOOTSTRAP_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_hydrostatic_bootstrap_current.py'))['self_test']()
 source();f=capsule();validate(f);passed=[]
 def reject(label,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError,TypeError,UnicodeError):passed.append(label);return
  raise AssertionError('accepted native heat corruption '+label)
 for p in json.loads((ROOT/STATUS).read_bytes())['postimages']:reject('input '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if p==q else b'')))
 reject('foreign caller',lambda:source(changed={'src/foreign_native_heat.f90':'A'}))
 for p in ['source-O0/RESULT.json','source-O2/literal.f90','app-O0/bootstrap-0.5/full/budget.csv','app-O2/bootstrap-2.0/resumed/restart.bin','app-O0/incumbent-water/current/state.csv','app-O2/incumbent-explicit-heat/preimage/temperature.csv']:
  bad=dict(f);bad[p]+=b'!';reject('raw '+p,lambda bad=bad:validate(bad))
 return passed
if __name__=='__main__':print(json.dumps(verify(),indent=2))
