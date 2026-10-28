"""Seal real model results; keep distinct configurations separate from executions."""
import base64,collections,csv,hashlib,io,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];D=ROOT/'integration/dataqual06';BASE='cba2117d679fe1165cc03c60e86e67943a777466';sha=lambda b:hashlib.sha256(b).hexdigest();files={}
def js(p):return json.loads(Path(p).read_bytes())
def add(name,p):files[name]=Path(p).read_bytes()
def directory(name,path):
 for p in Path(path).rglob('*'):
  if p.is_file()and'__pycache__'not in p.parts and p.suffix not in ['.o','.mod']and not(p.stat().st_mode&0o111):add(name+'/'+str(p.relative_to(path)),p)
def signature(r):
 c=r['configuration'];keys=dict(mode='experimental',source_surface_demand=False,perched_jacobian=False,solver_max_iterations=64,anchored=True,entry_width_cm=1e-4,transformations=[])
 return json.dumps({k:c.get(k,v)for k,v in keys.items()},sort_keys=True)
batches=['low24-O2','compose32-O2','storms-O0','restarts-O0','restarts-O2','preservation-O2'];rows=[]
for batch,count in zip(batches,[24,32,4,2,2,2]):
 p=Path('/tmp/dq06-'+batch);r=js(p/'results.json');assert len(r)==count;rows.extend(dict(batch=batch,**x)for x in r);directory(batch,p)
old=js('/tmp/dq06-baseline-rows.json');add('baseline-rows.json','/tmp/dq06-baseline-rows.json');oldnative=[x for x in old if x.get('native_returncode')is not None or x['status']=='CENSORED'];passes=[x for x in rows if x['status']=='PASS'];oldpasses=[x for x in old if x['status']=='PASS']
assert len({signature(x)for x in oldnative})==85 and len({signature(x)for x in oldpasses})==28
horizons={};before={}
for x in oldpasses:before[signature(x)]=max(before.get(signature(x),0),x['completed_days'])
horizons=dict(before)
for x in passes:horizons[signature(x)]=max(horizons.get(signature(x),0),x['completed_days'])
events=[]
for batch in batches:
 for p in Path('/tmp/dq06-'+batch).glob('*/**/manifest.json'):
  for e in js(p).get('events',[]):
   if e['label']=='native':events.append(dict(batch=batch,case=p.parent.parent.name,**e))
for label,path in [('contract','/tmp/dq06-contract'),('controls','/tmp/dq06-controls'),('fsi35','/tmp/dq06-fsi35-final'),('failed-fsi35','/tmp/dq06-fsi35'),('long5','/tmp/dq06-long5'),('reference','/tmp/dq06-reference')]:directory(label,path)
for opt in ['O0','O2']:
 for name in ['dq06-'+opt,'dq06-final-'+opt]:
  for p in Path('/tmp/'+name).rglob('*.json'):add('build/'+name+'/'+str(p.relative_to('/tmp/'+name)),p)
 for name in ['dq06-'+opt+'-build.log','dq06-resume-'+opt+'.log','dq06-final-'+opt+'.log']:
  p=Path('/tmp')/name
  if p.exists():add('logs/'+name,p)
 build=js('/tmp/dq06-final-'+opt+'/column/build-complete.json')
 assert all(sha((ROOT/p).read_bytes())==h for p,h in build['input_sha256'].items())
for name in ['default-two','original-corrected-two']:
 for p in (Path('/tmp/dq06-baseline-evidence/qualification-O2')/name/'run').iterdir():
  if p.is_file():add('baseline/'+name+'/'+p.name,p)
# The failed longer run keeps its own input-origin and exact current executable.
add('recovery/native-O2',js('/tmp/dq06-final-O2/bundle.json')['exe'])
add('recovery/origin.bin','/tmp/dq06-low24-O2/low-v0p001-r1-e2/run/restart.bin')
for name in ['input.nml','input.swp','macro.nml','manifest.json','restart.bin','diagnostic-rejected.bin']:
 p=Path('/tmp/dq06-long5')/name
 if p.exists():add('recovery/'+name,p)
for label in ['preservation-exact','selection']:
 p=Path('/tmp/dq06-'+label+'.json')
 if p.exists():add(label+'.json',p)
# Compare only daily records actually produced on both sides. Censored wet
# continuations are never upgraded by the already valid dry-day comparison.
def csvrows(raw):
 lines=[s for s in raw.decode().splitlines()if s and not s.startswith('*')];return list(csv.DictReader(lines))
comparisons=[]
for name,run in [('original',Path('/tmp/dq06-preservation-O2/original-corrected-two/run')),('storm-e0p5-r4p0',Path('/tmp/dq06-storms-O0/storm-e0p5-r4p0/run')),('storm-e2p0-r4p0',Path('/tmp/dq06-storms-O0/storm-e2p0-r4p0/run'))]:
 donor=csvrows((Path('/tmp/dq06-reference')/name/'result_output.csv').read_bytes());gwl={int(x['day']):float(x['groundwater_cm'])for x in csvrows((run/'diagnostics.csv').read_bytes())}
 for b in csvrows((run/'budget.csv').read_bytes()):
  day=int(b['day']);date='1998-01-'+str(day).zfill(2);ref=next((r for r in donor if r['DATE']==date),None)
  if ref and day in gwl:comparisons.append(dict(case=name,day=day,gwl_delta_cm=gwl[day]-float(ref['GWL']),matrix_plus_rapid_drainage_delta_cm=float(b['drainage_cm'])+float(b['rapid_cm'])-float(ref['DRN'])))
report=dict(work_unit='DATAQUAL06',baseline=BASE,batches=batches,scenario_executions=len(rows),native_process_executions_including_restarts=len(events),distinct_started_configurations=len({signature(x)for x in rows}),water_qualified_executions=len(passes),distinct_water_qualified_configurations=len({signature(x)for x in passes}),extra_started_configurations=len({signature(x)for x in rows}-{signature(x)for x in oldnative}),extra_water_qualified_configurations=len({signature(x)for x in passes}-{signature(x)for x in oldpasses}),baseline_started=85,baseline_water_qualified=28,combined_started=len({signature(x)for x in oldnative+rows}),combined_water_qualified=len(horizons),categories=dict(collections.Counter(x['qualification_category']for x in rows)),primary_completed_configuration_days=sum(x['simulated_days']for x in passes),baseline_deduplicated_configuration_days=sum(before.values()),combined_deduplicated_configuration_days=sum(horizons.values()),additional_deduplicated_configuration_days=sum(horizons.values())-sum(before.values()),max_water_certificate_cm=max(x['water_max_independent_cm']for x in passes),longest_fresh_integral_days=max(x['completed_days']for x in passes),historical_checkpoint_days=2.748,historical_checkpoint_authority='integration/dataqual03/RECOVERY.json; retained prior evidence, not re-executed with new executable',new_options='original MPVOLUME variable KsMpSs from candidate area; low VLMPSTSS source inputs with existing roots/Rutter/heat/drainage, experimental only',production_admission_changed=False,full_historical_closure=False,qualification='water only: finite112-node state/temperature,theta0..1,4 independent certificates<=1e-10cm,zero mass rejections,exact target and restart; selected exact full/split and O0/O2; no full energy/solute/N/parity',count_definition='same normalized source transformations and execution options as DATAQUAL05 seal; parameter variants of one historical Andelst project, not independent projects; combined counts cover DATAQUAL05+06, not a full01..04 union',reference_comparison=dict(reference='fresh exact B1.12 first2days,3 input variants; historical end date shortened only',comparisons=comparisons,tolerances='daily GWL/DRN are rounded source outputs; descriptive deltas only, no scientifically validated general trajectory tolerance. Hard water certificates1e-10cm, local surface2e-13cm, head partial FD5e-10; no model parity admission'),remaining_closure=['coupled Richards/macropore residual/Jacobian, including high-rain low-volume censors and prior2.848675 stall','longer low-volume continuation rejected at source1.33 after previous accepted windows; no5/30/481days','native historical chemistry/N,WOFOST,snow and extended drainage composition','full original season and year-boundary restart','complete matched431 pressure/moisture/ET/runoff/heat/chemical trajectory and justified variable-specific parity tolerances'])
assert report['extra_water_qualified_configurations']==43 and report['combined_water_qualified']==71
files['RESULT.json']=(json.dumps(report,indent=2)+'\n').encode();(D/'RESULT.json').write_bytes(files['RESULT.json'])
files['all-results.json']=(json.dumps(rows,indent=2)+'\n').encode();(D/'all-results.json').write_bytes(files['all-results.json'])
files['native-events.json']=(json.dumps(events,indent=2)+'\n').encode()
with(D/'summary.csv').open('w',newline='')as f:
 keys=['batch','id','status','qualification_category','completed_days','simulated_days','seconds','solver_iterations','water_max_independent_cm','restart','failure'];w=csv.DictWriter(f,fieldnames=keys,extrasaction='ignore');w.writeheader();w.writerows(rows)
delta={r.split('\t')[1]:r.split('\t')[0]for r in subprocess.check_output(['git','diff','--name-status',BASE,'HEAD','--','src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance'],cwd=ROOT,text=True).splitlines()}
paths=set(delta)|{str(p.relative_to(ROOT))for p in D.iterdir()if p.suffix in ['.py','.f90']or p.name in ['CONTRACT.md','low24.json','compose32.json','storms.json','preservation.json','restarts.json']}
posts={p:sha((ROOT/p).read_bytes())for p in sorted(paths)}
for p in posts:files['executed/'+p]=(ROOT/p).read_bytes()
files['executed-postimages.json']=(json.dumps(posts,indent=2)+'\n').encode();files['MANIFEST.json']=(json.dumps({p:sha(v)for p,v in files.items()},indent=2)+'\n').encode()
buf=io.BytesIO()
with tarfile.open(fileobj=buf,mode='w:xz',preset=6)as t:
 for p,v in sorted(files.items()):m=tarfile.TarInfo(p);m.size=len(v);m.mtime=0;t.addfile(m,io.BytesIO(v))
raw=buf.getvalue();encoded=base64.b64encode(raw);parts=[]
for i,start in enumerate(range(0,len(encoded),60000)):
 p=D/f'evidence-{i:03d}.b64';p.write_bytes(encoded[start:start+60000]);parts.append(str(p.relative_to(ROOT)))
s=dict(work_unit='DATAQUAL06',workstream='RT/HY/VQ',baseline=BASE,stage='EXECUTED_EXPERIMENTAL_CANDIDATE',implemented=True,persisted=True,tested=True,qualified=True,canonically_admitted=False,production_admission_changed=False,full_historical_closure=False,scientific_delta=delta,postimages=posts,evidence=dict(parts=parts,sha256=sha(raw),bytes=len(raw),members=len(files)),result=report,test_selection=dict(owner='RT/HY/VQ',changed_dependency='source surface conductivity, native input/configuration, dynamic top provider and adapter',selected='945 real top/adapter cases O0/O2,66 primary model executions,12 split/restarts,8 native negative controls,affected FCI93 O0/O2 oracles,source/raw owner',full_fci='NOT_SELECTED_IMPACT',highest_low_air='NOT_SELECTED_POLICY',authority='integration/dataqual06/CONTRACT.md'))
(D/'STATUS.json').write_text(json.dumps(s,indent=2)+'\n');print(json.dumps(dict(bytes=len(raw),members=len(files),parts=len(parts),result=report),indent=2))
