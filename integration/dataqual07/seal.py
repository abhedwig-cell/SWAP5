"""Retain final-source model output and honest physical-configuration increments."""
import base64,collections,csv,hashlib,io,json,statistics,subprocess,tarfile,runpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];D=ROOT/'integration/dataqual07';BASE='93d302d8c10850940b33aefd2ffd815f3d63b65a';files={};sha=lambda b:hashlib.sha256(b).hexdigest()
def js(p):return json.loads(Path(p).read_bytes())
def add(name,p):files[name]=Path(p).read_bytes()
def directory(name,path):
 for p in Path(path).rglob('*'):
  if p.is_file()and'__pycache__'not in p.parts and p.suffix not in ['.o','.mod']and not(p.stat().st_mode&0o111):add(name+'/'+str(p.relative_to(path)),p)
def signature(x):
 c=x['configuration'];defaults=dict(mode='experimental',source_surface_demand=False,perched_jacobian=False,solver_max_iterations=64,anchored=True,entry_width_cm=1e-4,transformations=[])
 return json.dumps({k:c.get(k,v)for k,v in defaults.items()},sort_keys=True)
batches={'stock24':'/tmp/dq07-final-stock24','wet13':'/tmp/dq07-final-wet13','restarts-O0':'/tmp/dq07-final-restarts-O0','restarts-O2':'/tmp/dq07-final-restarts-O2','preservation':'/tmp/dq07-final-integral','integral':'/tmp/dq07-final-integral-retry','paired-six':'/tmp/dq07-final-paired-six'}
rows=[]
for (name,path),count in zip(batches.items(),[24,13,2,2,4,2,6]):
 r=js(Path(path)/'results.json');assert len(r)==count;rows.extend(dict(batch=name,**x)for x in r);directory(name,path)
old=js('/tmp/dq07-baseline/baseline-rows.json')+js('/tmp/dq07-baseline/all-results.json');files['baseline-rows.json']=(json.dumps(old,indent=2)+'\n').encode();directory('baseline','/tmp/dq07-baseline')
# Preserve unchanged FSI35 raw evidence, explicitly inherited rather than rerun.
s6=js(ROOT/'integration/dataqual06/STATUS.json');raw=base64.b64decode(b''.join((ROOT/p).read_bytes()for p in s6['evidence']['parts']),validate=True);assert sha(raw)==s6['evidence']['sha256']
with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
 for p in ['fsi35/RESULT.json','fsi35/stdout']:
  files['baseline-'+Path(p).name if p.endswith('.json')else'baseline-fsi35-stdout']=t.extractfile(p).read()
files['baseline-fsi35-RESULT.json']=files.pop('baseline-RESULT.json')
for opt in ['O0','O2']:
 directory('contract/'+opt,'/tmp/dq07-small-'+opt)
 for p in Path('/tmp/dq07-final-'+opt).rglob('*.json'):add('build/'+opt+'/'+str(p.relative_to('/tmp/dq07-final-'+opt)),p)
 add('recovery/native-'+opt,'/tmp/dq07-final-'+opt+'/column/swap5_solute_project')
 bundle=js('/tmp/dq07-final-'+opt+'/bundle.json')
 for p,h in bundle['physical_build']['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,p
 directory('controls','/tmp/dq07-final-controls')
for name,path in [('cell-rejection','/tmp/dq07-balance-run'),('trace-rejection','/tmp/dq07-trace-run'),('prototype24','/tmp/dq07-stock24'),('prototype-prefix','/tmp/dq07-fixed-one'),('prototype-prefix-O0','/tmp/dq07-fixed-one-O0'),('prototype-five-censored','/tmp/dq07-fixed-five')]:directory('diagnostic/'+name,path)
for name,path in [('diagnostic/native','/tmp/dq07-balance-native'),('diagnostic/backend.f90','/tmp/dq07-balance-backend.f90'),('diagnostic/bundle.json','/tmp/dq07-balance-bundle.json'),('diagnostic/instrumentation.patch','/tmp/dq07-full-instrumentation.patch')]:add(name,path)
passes=[x for x in rows if x['status']=='PASS'];oldpasses=[x for x in old if x['status']=='PASS'];before={};after={}
for x in oldpasses:before[signature(x)]=max(before.get(signature(x),0),x['completed_days'])
after=dict(before)
for x in passes:after[signature(x)]=max(after.get(signature(x),0),x['completed_days'])
assert len(before)==77
native=[]
for b,p in batches.items():
 for m in Path(p).glob('*/**/manifest.json'):
  for e in js(m).get('events',[]):
   if e['label']=='native':native.append(dict(batch=b,case=m.parent.parent.name,**e))
o2=[x['seconds']for x in rows if x['batch']=='stock24'and x['status']=='PASS']
r=dict(work_unit='DATAQUAL07',baseline=BASE,batches=list(batches),scenario_executions=len(rows),native_process_executions_including_restarts=len(native),water_qualified_executions=len(passes),categories=dict(collections.Counter(x['qualification_category']for x in rows)),baseline_started=151,combined_started=len({signature(x)for x in old if x.get('native_returncode')is not None or x['status']=='CENSORED'}|{signature(x)for x in rows if x.get('native_returncode')is not None or x['status']=='CENSORED'}),baseline_water_qualified=len(before),combined_water_qualified=len(after),extra_water_qualified_configurations=len(set(after)-set(before)),baseline_deduplicated_configuration_days=sum(before.values()),combined_deduplicated_configuration_days=sum(after.values()),additional_deduplicated_configuration_days=sum(after.values())-sum(before.values()),longest_fresh_integral_days=2.7479999999995925,max_water_certificate_cm=max(x['water_max_independent_cm']for x in passes),native_seconds_total=sum(x['seconds']for x in native),stock24_success_seconds=dict(median=statistics.median(o2),minimum=min(o2),maximum=max(o2)),production_admission_changed=False,full_historical_closure=False,qualification='water only,112-node finite state/temperature and theta bounds,4 independent certificates<=1e-10cm,no mass rejection;2 O0/O2 and full/split physical identities;not full energy/chemistry/N/model parity',count_definition='same normalized physical transformations/options as DATAQUAL05/06; conservative numerical flag excluded to avoid inflating configurations;one original Andelst project;01..04 not silently unioned',causal_attribution='All6 new wet completions also pass paired legacy policy with same60s budget. Count gain is expanded execution, not attributable to limiter fix. Fix causally removes reproduced1.33 post-solve stock/trace rejection.',unresolved_integral='same2.848675 internal stall; actual2.748 rollback exact;29878 Newton,2523 HeadCalc,102 solver/402 temporal rejections,min accepted dt8.88e-16day',paired_policy_cases=[dict(id=x['id'],status=x['status'],seconds=x['seconds'])for x in rows if x['batch']=='paired-six'],remaining_closure=['coupled solver temporal collapse at original internal2.848675','high-rain configurations remain budget-censored or solver-rejected','full5/30/481day integral plus year-boundary restart','native chemistry/N/WOFOST/snow and extended compositions','matched431 pressure/moisture/ET/drainage/runoff trajectories and justified quantity-specific parity tolerances'])
assert r['extra_water_qualified_configurations']==6 and r['combined_water_qualified']==83
files['RESULT.json']=(json.dumps(r,indent=2)+'\n').encode();(D/'RESULT.json').write_bytes(files['RESULT.json']);files['all-results.json']=(json.dumps(rows,indent=2)+'\n').encode();files['native-events.json']=(json.dumps(native,indent=2)+'\n').encode()
with(D/'summary.csv').open('w',newline='')as f:
 keys=['batch','id','status','qualification_category','completed_days','simulated_days','seconds','solver_iterations','water_max_independent_cm','restart','failure'];w=csv.DictWriter(f,fieldnames=keys,extrasaction='ignore');w.writeheader();w.writerows(rows)
delta={line.split('\t')[1]:line.split('\t')[0]for line in subprocess.check_output(['git','diff','--name-status',BASE,'HEAD','--','src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance'],cwd=ROOT,text=True).splitlines()}
paths=set(delta)|{str(p.relative_to(ROOT))for p in D.iterdir()if p.suffix in ['.py','.f90']or p.name in ['stock24.json','wet13.json','paired-six.json','restarts.json','integral.json','IMPLEMENTATION.json']};posts={p:sha((ROOT/p).read_bytes())for p in sorted(paths)}
for p in posts:files['executed/'+p]=(ROOT/p).read_bytes()
files['executed-postimages.json']=(json.dumps(posts,indent=2)+'\n').encode();files['MANIFEST.json']=(json.dumps({p:sha(v)for p,v in files.items()},indent=2)+'\n').encode();buf=io.BytesIO()
with tarfile.open(fileobj=buf,mode='w:xz',preset=6)as t:
 for p,v in sorted(files.items()):m=tarfile.TarInfo(p);m.size=len(v);m.mtime=0;t.addfile(m,io.BytesIO(v))
raw=buf.getvalue();encoded=base64.b64encode(raw);parts=[]
for i,start in enumerate(range(0,len(encoded),60000)):
 p=D/f'qualified-evidence-{i:03d}.b64';p.write_bytes(encoded[start:start+60000]);parts.append(str(p.relative_to(ROOT)))
s=dict(work_unit='DATAQUAL07',workstream='RT/HY/VQ',baseline=BASE,stage='EXECUTED_EXPERIMENTAL_CANDIDATE',implemented=True,persisted=True,tested=True,qualified=True,canonically_admitted=False,production_admission_changed=False,full_historical_closure=False,scientific_delta=delta,postimages=posts,evidence=dict(parts=parts,sha256=sha(raw),bytes=len(raw),members=len(files)),result=r,test_selection=dict(owner='RT/HY/VQ',changed_dependency='experimental limiter policy,request copy,native policy/runner and runtime admission',selected='1919 real limiter cases plus receiving-capacity case O0/O2,53 primary rows,8 full/split native processes,5 direct guards,production predecessor exact,actual integral rejection rollback',fsi35='27 dependencies and retained O0/O2 native oracle unchanged;inherited with exact hash proof,not rerun',full_fci='NOT_SELECTED_IMPACT',highest_low_air='NOT_SELECTED_POLICY',authority='integration/dataqual07/IMPLEMENTATION.json'))
(D/'STATUS.json').write_text(json.dumps(s,indent=2)+'\n');print(json.dumps(dict(bytes=len(raw),members=len(files),parts=len(parts),result=r),indent=2))
