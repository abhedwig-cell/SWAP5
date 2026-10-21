"""Source-bound dynamic pond heat qualification and exact predecessor authority."""
import base64,csv,hashlib,io,json,os,re,subprocess,sys,tarfile,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='fda2a6de35ab60e8c836a6687482efa3774d95dc'
STATUS='integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'
SCIENCE=['src','tests','tools','reference','.github','app','examples','integration/performance','integration/audits/verify_nonlinear_pond.py','integration/audits/verify_pond_thermal.py','integration/audits/qualify_pond_thermal.py']
CASES=['1','0.5','0.8','1.0005','1.5','2']
def require(ok,why):
 if not ok:raise ValueError(why)
def sha(b):return hashlib.sha256(b).hexdigest()
def record():return json.loads((ROOT/STATUS).read_text())['thermal_pond_successor']
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 if 'evidence' in json.loads((ROOT/STATUS).read_text()).get('swp_reader_successor', {}):
  return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_swp_reader.py'))['source'](reader,changed)
 s=record();require(s['baseline']==BASE,'wrong predecessor');git('merge-base','--is-ancestor',BASE,'HEAD')
 require(not git('status','--porcelain','--',*SCIENCE),'dirty scientific source')
 actual=changed if changed is not None else {x.split('\t')[1]:x.split('\t')[0] for x in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}
 require(actual=={p:v['status'] for p,v in s['postimages'].items()},'unregistered scientific delta')
 require({p for p in actual if p.startswith('src/')}=={'src/runtime/mod_fmr_b111_pond_thermal_application.f90','src/adapter/mod_pond_thermal_restart_file.f90'},'incumbent physics changed')
 for p,v in s['postimages'].items():require(sha(reader(p))==v['sha256'],'source identity '+p)
 # Exact additive handoff; every original predecessor assertion remains present.
 p='integration/audits/verify_nonlinear_pond.py';expected=subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT,text=True)
 for fn in ['source','verify_qualification','self_test']:
  marker='def '+fn;start=expected.index(marker);end=expected.index('\n',start)+1
  hook="    if 'evidence' in json.loads((ROOT/STATUS).read_text()).get('thermal_pond_successor', {}):\n        return runpy.run_path(str(ROOT/'integration/audits/verify_pond_thermal.py'))['"+fn+"']("+('reader,changed' if fn=='source' else '')+")\n"
  expected=expected[:end]+hook+expected[end:]
 require(reader(p).decode()==expected,'predecessor body changed')
 return s
def capsule():
 e=record()['evidence'];raw=base64.b64decode(b''.join((ROOT/e['path']).read_bytes().split()),validate=True);require(sha(raw)==e['decoded_sha256'],'capsule bytes')
 with tarfile.open(fileobj=io.BytesIO(raw)) as t:
  members=t.getmembers();require(all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in members),'unsafe capsule');require(len(members)==len({m.name for m in members}),'duplicate members');files={m.name:t.extractfile(m).read() for m in members}
 manifest=json.loads(files.pop('MANIFEST.json'));require(set(files)==set(manifest),'member inventory');require(all(sha(files[p])==h for p,h in manifest.items()),'member corruption');return files
def validate(files,reader=lambda p:(ROOT/p).read_bytes()):
 def js(p):return json.loads(files[p])
 def values(s,label):return [float(x) for x in re.search('^'+label+'=(.*)$',s,re.M)[1].split()]
 def current(inputs):
  for p,h in inputs.items():require(sha(reader(p))==h,'stale executed source '+p)
 semantic=0
 for e in CASES:
  prefix='physical/'+e+'/';p=js(prefix+'result.json');q=js('qualified/'+e+'/result.json')
  require(p['exponent']==float(e) and p['status']=='FOCUSED_PHYSICAL_PASS_REFINEMENT_ASSESSMENT_PENDING_NOT_ADMITTED','unfinished physical case')
  require(q['status']=='DYNAMIC_ACCEPTED_ENDPOINT_DECAY_O0_O2_RESTART_REFINEMENT_CRASH_PASS_NOT_ADMITTED','unfinished refinement/crash case')
  require(q['physical_sha256']==sha(files[prefix+'result.json']),'qualification binding');current(p['inputs']);current(q['inputs'])
  require(p['results']['O0']==p['results']['O2'],'optimization difference')
  require(p['authority_sha256']=='2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2','literal authority')
  for opt in ['O0','O2']:
   masses=[];decays=[]
   for n in [2,4,8,16,32,64,128,256]:
    case=p['results'][opt][str(n)];text=case['stdout'][0];require('THERMAL_PHYSICAL_LITERAL_RESTART=PASS' in text,'literal native marker')
    masses.append(values(text,'MASS_VECTOR'));decays.append(values(text,'DECAY')[0]);require(values(text,'MAX_SOLUTE_RESIDUAL')[0]<1e-11,'chemical balance')
    require(files[f'{prefix}{opt}/{n}/full.bin']==files[f'{prefix}{opt}/{n}/resumed.bin'],'fresh native restart')
    require(sha(files[f'{prefix}{opt}/{n}/full.bin'])==case['endpoint_sha256'],'endpoint binding')
   md=[max(abs(a-b) for a,b in zip(x,y)) for x,y in zip(masses,masses[1:])];dd=[abs(a-b) for a,b in zip(decays,decays[1:])]
   require(all(a>b>0 for a,b in zip(md,md[1:])) and all(a>b>0 for a,b in zip(dd,dd[1:])),'short-horizon refinement not monotone')
   require(dd[-1]/decays[-1]<1e-3 and md[-1]/max(masses[-1])<1e-6,'unresolved split refinement')
   require(q['results'][opt]['mass_delta']==md and q['results'][opt]['decay_delta']==dd,'reported refinement mismatch')
   require(files[f'{prefix}{opt}/controls/control.before']==files[f'{prefix}{opt}/controls/control.after'],'chemical rejection mutates heat/water/pond')
   require(files[f'{prefix}{opt}/controls/control.initial']==files[f'{prefix}{opt}/controls/control.hydraulic'],'water rejection mutates joint owner')
   semantic+=len(q['results'][opt]['semantic_negatives'])
  for i,event in enumerate(p['events']):
   require(event['returncode']==0,'failed physical observation relabelled')
   stdout=files[prefix+f'{i:04d}.stdout']
   if event['category']=='native':require(b'=PASS' in stdout,'native physical stdout missing')
  for i,event in enumerate(q['events']):
   require(event['returncode']==event['expected_returncode'],'failed qualification event')
   require('qualified/'+e+'/'+event['stdout'] in files and 'qualified/'+e+'/'+event['stderr'] in files,'missing native evidence')
   if event['category']=='semantic_negative':require(b'THERMAL_INVALID_RESTART=PASS' in files['qualified/'+e+'/'+event['stdout']],'semantic rejection marker')
  require(all(q['results'][o]['kill_before_after_generation_exact'] for o in ['O0','O2']),'missing native crash recovery')
 # Current application, every provider and all original assertions.
 c=js('column/qualification/result.json');require(c['status']=='PASS' and len(c['events'])==86,'original file application failed');require(c['test_sha256']==sha(reader('tests/nut-sol/test_column_input.py')) and c['runner_sha256']==sha(reader('tools/solute/run_column.py')),'changed column assertions')
 for opt in ['O0','O2']:current(js('column/'+opt+'/build-complete.json')['input_sha256'])
 comparisons=js('incumbent-comparison.json');require(comparisons['count']==160 and comparisons['all_exact'],'old application bytes changed')
 import runpy
 old_owner=runpy.run_path(str(ROOT/'integration/audits/verify_nonlinear_pond.py'))
 old=old_owner['unpack'](json.loads((ROOT/STATUS).read_text())['nonlinear_pond_successor']['evidence'])

 for p,h in comparisons['artifacts'].items():
  require(sha(files['column/qualification/'+p])==h,'old application raw mismatch')
  require(files['column/qualification/'+p]==old['column/qualification/'+p],'prior admitted application bytes drift')
 for duration in ['month','season']:
  r=js(duration+'/result.json');require(r['status']=='PHYSICAL_LONG_FILE_RUNS_PASS_ACCURACY_ASSESSMENT_REQUIRED','unfinished long application');current(r['inputs'])
  require(r['days']==(30 if duration=='month' else 365),'wrong long horizon')
  for b in r['builds'].values():current(b['input_sha256'])
  for key,v in r['runs'].items():
   require(v['max_water']<=1e-10 and v['max_solute']<=1e-11,'long-run balance');require(v['endpoint']['time_day']==r['days'],'shortened seasonal run')
   raw=files[duration+'/'+key+'/full/budget.csv'];rows=list(csv.DictReader(io.StringIO(raw.decode())))
   require(len(rows)==r['days']*int(key.rsplit('-',1)[1]),'long raw window inventory')
   require(max(abs(float(x['water_residual_cm'])) for x in rows)<=1e-10 and max(abs(float(x['solute_residual_mg_cm2'])) for x in rows)<=1e-11,'raw long-run balance')
   require(all(sum(float(x[field]) for x in rows)>0 for field in ['runon_cm','runoff_cm','pond_evaporation_cm']),'gross long forcing absent')
   require(sha(files[duration+'/'+key+'/input.nml'])==v['input_sha256'],'long input drift')
   if key.endswith('-4'):
    for name in ['restart.bin','state.csv','endpoint.csv','temperature.csv']:require(files[duration+'/'+key+'/full/'+name]==files[duration+'/'+key+'/resumed/'+name],'long fresh restart')
  for exponent in [.5,1.,2.]:
   for mesh in [1,2,4]:require(r['runs'][f'O0-{exponent}-{mesh}']==r['runs'][f'O2-{exponent}-{mesh}'],'long optimization mismatch')
 return {'qualified':True,'thermal_pond':True,'six_exponents':True,'semantic_native_controls':semantic,'original_application_artifacts_exact':160,'month_and_year_runs':True,'full_capability':False,'seasonal_accuracy_claim':'measured time-grid spread only; annual mass differences not strictly monotone'}
def predecessor():
 with tempfile.TemporaryDirectory(prefix='swap5-thermal-pond-predecessor-') as tmp:
  path=Path(tmp)/'base';subprocess.run(['git','worktree','add','--detach',path,BASE],cwd=ROOT,check=True,capture_output=True)
  try:
   r=subprocess.run([sys.executable,'-B','integration/audits/verify_nonlinear_pond.py'],cwd=path,capture_output=True,text=True,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'});require(r.returncode==0,'exact predecessor '+r.stderr[-1000:]);require(json.loads(r.stdout)['qualified'],'predecessor unqualified')
  finally:subprocess.run(['git','worktree','remove','--force',path],cwd=ROOT,check=True,capture_output=True)
 return True
def verify_qualification():
 if 'evidence' in json.loads((ROOT/STATUS).read_text()).get('swp_reader_successor', {}):
  return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_swp_reader.py'))['verify_qualification']()
 source();r=validate(capsule());r.update(predecessor_qualified=predecessor(),source_tree=git('rev-parse','HEAD:src'),current_source_tree=git('rev-parse','HEAD:src'));return r
def self_test():
 if 'evidence' in json.loads((ROOT/STATUS).read_text()).get('swp_reader_successor', {}):
  return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_swp_reader.py'))['self_test']()
 files=capsule();validate(files);controls=[]
 for name in ['physical/0.5/result.json','physical/2/O2/256/resumed.bin','qualified/1/result.json','season/O0-0.5-4/full/budget.csv','column/qualification/result.json','incumbent-comparison.json']:
  bad=dict(files);del bad[name]
  try:validate(bad)
  except (ValueError,KeyError):controls.append(name)
  else:raise ValueError('missing evidence accepted '+name)
 for path in ['src/runtime/mod_fmr_b111_pond_thermal_application.f90','app/solute_column/main.f90']:
  try:validate(files,lambda p:(ROOT/p).read_bytes()+(b'!' if p==path else b''))
  except ValueError:controls.append('stale '+path)
  else:raise ValueError('stale input accepted')
 for path in ['src/adapter/mod_pond_thermal_restart_file.f90','integration/audits/verify_nonlinear_pond.py']:
  try:source(lambda p:(ROOT/p).read_bytes()+(b'!' if p==path else b''))
  except ValueError:controls.append('source '+path)
  else:raise ValueError('source mutation accepted')
 changes={p:v['status'] for p,v in record()['postimages'].items()}
 try:source(changed={**changes,'src/foreign.f90':'A'})
 except ValueError:controls.append('foreign production')
 else:raise ValueError('foreign source accepted')
 return {'count':len(controls),'negative_controls':controls}
if __name__=='__main__':print(json.dumps(self_test() if '--self-test' in sys.argv else verify_qualification(),indent=2))
