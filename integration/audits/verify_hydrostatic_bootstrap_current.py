"""Source-bound hydrostatic initialization and bounded coupled file execution."""
import base64,csv,hashlib,io,json,re,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='a44c346216b67a2b9db4acbcfa18c229442648a9'
STATUS='integration/mc-sol01/drainage/HYDROSTATIC_BOOTSTRAP_STATUS.json'
SELF='integration/audits/verify_hydrostatic_bootstrap_current.py'
PARENT='integration/audits/verify_native_heat_bootstrap_current.py'
SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits']
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def projection():
 t=subprocess.check_output(['git','show',BASE+':'+PARENT],cwd=ROOT,text=True)
 for name,args in [('source','reader,changed'),('verify',''),('self_test',''),('fsi35_successors','')]:
  start=re.search(r'^def '+name+r'\(',t,re.M).start();at=t.index(':',t.index(')',start))+1
  if t[at:at+1]!='\n':t=t[:at]+'\n '+t[at:]
  at=t.index('\n',start)+1
  t=t[:at]+" if (ROOT/'"+STATUS+"').is_file():return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+t[at:]
 return t.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 if (ROOT/'integration/mc-sol01/drainage/KSATEXM_INPUT_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_ksatexm_input_current.py'))['source'](reader,changed)
 s=json.loads(reader(STATUS));assert s['baseline']==BASE;git('merge-base','--is-ancestor',BASE,'HEAD')
 delta={line.split('\t')[1]:line.split('\t')[0]for line in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}
 assert delta==s['scientific_delta'],'foreign hydrostatic delta'
 assert not any(p.startswith('src/')for p in delta),'physical process/solver source changed'
 assert {p for p in delta if p.startswith('app/')}=={'app/solute_column/main.f90','app/solute_column/read_swp_water.f90'}
 assert not git('status','--porcelain','--',*SCIENCE),'unpersisted hydrostatic source'
 assert reader(PARENT)==projection(),'prior heat guard bodies changed'
 for p,h in s['postimages'].items():assert sha(reader(p))==h,('hydrostatic input',p)
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
 js=lambda p:json.loads(f[p]);parent=js('parent/proof.json');assert parent['owner']['qualified']and len(parent['controls'])==19
 raw=f['parent/commit.raw'];assert hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==BASE
 assert f['parent/owner.py']==subprocess.check_output(['git','show',BASE+':'+PARENT],cwd=ROOT)
 csvrows=lambda p:list(csv.DictReader(io.StringIO(f[p].decode())))
 for opt in ['O0','O2']:
  prefix='proof-'+opt+'/';r=js(prefix+'RESULT.json');assert r['status']=='HYDROSTATIC_SOURCE_HEAT_FILE_RESTART_AND_INCUMBENT_PASS'
  assert r['source_cases']==9 and r['source_negative_processes']==11 and r['file_cases']==r['fresh_process_restarts']==3 and r['file_negative_processes']==8
  assert len(r['events'])==43 and sum(e['returncode']!=0 for e in r['events'])==19
  assert all((e['returncode']==0)==e['expected_success']for e in r['events'])
  assert len(r['results']['source-original']['nodes'])==112
  assert r['results']['source-original']['pond']==0 and r['results']['source-pond']['pond']==.25 and r['results']['source-high']['pond']==1000
  assert sha(f[prefix+'original-soilwater.f90'])==r['original_soilwater_sha256']and sha(f[prefix+'literal.f90'])==r['literal_sha256']
  for p,h in r['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h and sha(f['executed/'+p])==h,('current executed input',p)
  if opt=='O2':assert r['results']==js('proof-O0/RESULT.json')['results'],'O0/O2 drift'
  for name in ['below','intersect','shallow']:
   c=prefix+'app-'+name+'/';result=r['results']['app-'+name]
   expected_gwl={'below':-4.,'intersect':-2.,'shallow':-.5}[name]
   for label in ['full','split','resumed']:
    match=re.search(rb'SWP_HYDROSTATIC_INITIAL_GROUNDWATER_CM=\s*([-+\d.Ee]+)',f[c+label+'/stdout']);assert match and float(match[1])==expected_gwl
   for p,h in result['files'].items():assert sha(f[c+'full/'+p])==h and f[c+'full/'+p]==f[c+'resumed/'+p]
   budget=csvrows(c+'full/budget.csv');assert len(budget)==3 and csvrows(c+'resumed/budget.csv')==budget[1:]
   assert abs(float(budget[0]['water_start_cm'])-result['water_initial_independent'])<2e-13
   assert abs(float(budget[0]['solute_start_mg_cm2'])-result['solute_initial_independent'])<2e-13
   for row in budget:
    assert abs(float(row['water_residual_cm']))<1e-10 and abs(float(row['solute_residual_mg_cm2']))<1e-10
   for forbidden in ['forbidden-restart','forbidden-pond']:assert not any(p.startswith(c+forbidden+'/')for p in f)
  for name in ['surface','pond']:assert not any(p.startswith(prefix+'app-reject-'+name+'/forbidden/')for p in f)
  for name in ['incumbent-0.5','incumbent-1.0','incumbent-2.0','incumbent-water','incumbent-explicit-heat']:
   for p,h in r['results'][name].items():assert sha(f[prefix+name+'/current/'+p])==h and f[prefix+name+'/current/'+p]==f['incumbent-'+opt+'/'+name+'/'+p]
 for name,p in [('hydrostatic_heat.nml','input.nml'),('hydrostatic_heat.swp','source.swp')]:assert(ROOT/'examples/solute_column'/name).read_bytes()==f['proof-O2/app-intersect/'+p]
 return dict(qualified=True,source_cases=18,original_hydrostatic_and_heat_component_nodes=112,source_negative_processes=22,coupled_cases=6,fresh_process_restarts=6,file_negative_processes=16,incumbent_artifacts_exact=True,all_process_solver_sources_unchanged=True,full_original_Andelst=False,fully_saturated_file_execution=False,canonically_admitted=False)
def verify():
 if (ROOT/'integration/mc-sol01/drainage/KSATEXM_INPUT_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_ksatexm_input_current.py'))['verify']()
 source();return validate(capsule())
def fsi35_successors():
 if (ROOT/'integration/mc-sol01/drainage/KSATEXM_INPUT_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_ksatexm_input_current.py'))['fsi35_successors']()
 source();deps=json.loads((ROOT/'integration/audits/FCI93_NON_M1_COMPILE_DEPENDENCIES_20261011.json').read_bytes())['dependencies']
 for d in deps:assert git('rev-parse','HEAD:'+d['path'])==git('rev-parse',BASE+':'+d['path'])
 return json.loads(capsule()['parent/proof.json'])['fsi35']
def self_test():
 if (ROOT/'integration/mc-sol01/drainage/KSATEXM_INPUT_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_ksatexm_input_current.py'))['self_test']()
 source();f=capsule();validate(f);passed=[]
 def reject(label,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError,TypeError,UnicodeError):passed.append(label);return
  raise AssertionError('accepted hydrostatic corruption '+label)
 for p in json.loads((ROOT/STATUS).read_bytes())['postimages']:reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if p==q else b'')))
 reject('foreign caller',lambda:source(changed={'src/foreign_hydrostatic.f90':'A'}))
 for p in ['proof-O0/RESULT.json','proof-O2/literal.f90','proof-O0/app-below/full/budget.csv','proof-O2/app-shallow/resumed/restart.bin','proof-O0/incumbent-water/current/state.csv','incumbent-O2/incumbent-explicit-heat/temperature.csv']:
  bad=dict(f);bad[p]+=b'!';reject('raw '+p,lambda bad=bad:validate(bad))
 return passed
if __name__=='__main__':print(json.dumps(verify(),indent=2))
