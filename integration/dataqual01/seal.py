"""Seal executed DATAQUAL01 evidence, including failed/censored attempts."""
import base64,csv,hashlib,io,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];W=ROOT.parent;D=ROOT/'integration/dataqual01';sha=lambda b:hashlib.sha256(b).hexdigest();files={}
def add(name,path):files[name]=Path(path).read_bytes()
def directory(name,path):
 for p in Path(path).rglob('*'):
  if p.is_file()and'__pycache__'not in p.parts:add(name+'/'+str(p.relative_to(path)),p)
def js(p):return json.loads(Path(p).read_bytes())
batches={'main-O2':'dataqual-final-results-O2','boundaries-O2':'dataqual-boundaries-O2','corrections-O2':'dataqual-corrections-O2','preservation-O0':'dataqual-final-results-O0','exactness-O0':'dataqual-exactness-O0','resume-O2':'dataqual-resume-O2'}
all_results=[]
for name,path in batches.items():
 directory('batches/'+name,W/path)
 for r in js(W/path/'results.json'):all_results.append(dict(batch=name,**r))
for name in ['dataqual-results-O2','dataqual-pilot-O2']:directory('development/'+name,W/name)
for opt in ['O0','O2']:
 for name in ['preserve','rootless']:directory(name+'-'+opt,W/('dataqual-'+name+'-'+opt))
 for prefix in ['dataqual-build-','dataqual-final-']:
  build=W/(prefix+opt)
  for path in build.rglob('*.json'):add('build/'+prefix+opt+'/'+str(path.relative_to(build)),path)
 for f in ['build-'+opt+'.log','finalbuild-'+opt+'.log']:add('logs/'+f,W/f)
directory('restart-controls',W/'dataqual-restart-controls');directory('root-contracts',W/'dataqual-root-contracts');directory('continuation-O2',W/'dataqual-continuation-O2');add('parent-owner.json',W/'baseline-owner.json')
a=W/'dataqual-exactness-O0/historical-production/run';b=W/'dataqual-final-results-O2/historical-comparison/run';active0=W/'dataqual-exactness-O0/oxygen-active-experimental/run';active2=W/'dataqual-boundaries-O2/oxygen-active-experimental/run'
physical=['state.csv','temperature.csv','budget.csv','progress.csv','cost.csv','diagnostics.csv']
assert all((a/p).read_bytes()==(b/p).read_bytes()for p in physical)
assert all((active0/p).read_bytes()==(active2/p).read_bytes()for p in physical)
parent_raw=base64.b64decode((ROOT/'integration/mc-sol01/drainage/ENTRY_RAMP_EVIDENCE.tar.xz.b64').read_bytes())
with tarfile.open(fileobj=io.BytesIO(parent_raw))as t:
 for opt,folder in [('O0',a),('O2',b)]:
  for p in physical[:4]:assert t.extractfile('runs/two-'+opt+'/'+p).read()==(folder/p).read_bytes()
  assert t.extractfile('runs/two-'+opt+'/restart.bin').read()[72:-4]==(folder/'restart.bin').read_bytes()[72:-4]
  for name in ['joint','rootless']:
   for flag in ([1]if name=='joint'else[0,1]):
    fn='replay-rutter-static-'+str(flag)+'.stdout';current=W/('dataqual-'+('preserve'if name=='joint'else'rootless')+'-'+opt)/fn
    assert current.read_bytes()==t.extractfile('preserve/'+opt+'-'+name+'/'+fn).read()
passes=[r for r in all_results if r['status']=='PASS'];censors=[r for r in all_results if r['status']=='CENSORED'];active=next(r for r in all_results if r['batch']=='boundaries-O2'and r['id']=='oxygen-active-experimental')
cont=list(csv.DictReader((W/'dataqual-continuation-O2/progress.csv').open()))
result=dict(physical_passes=len(passes),scenario_executions=len(all_results),censored_runs=len(censors)+1,failed_or_rejected=sum(r['status']=='FAILED'for r in all_results),
 active_oxygen_reduction_cm=active['oxygen_reduction_cm'],production_oxygen_rejected=all(r['status']=='FAILED'for r in all_results if r['id']in ['oxygen-production-reject','oxygen-active-production']),
 invalid_input_rejected=all(r['status']=='FAILED'for r in all_results if r['id']=='invalid-negative-pond'),physical_exact_O0_O2=True,predecessor_two_days_exact=True,
 current_joint_rootless_stdout_exact=True,restart_exact=all(r['restart']=='exact'for r in all_results if r['configuration'].get('restart_check')and r['status']=='PASS'),
 water_max_independent_cm=max(r['water_max_independent_cm']for r in passes),
 continuation=dict(start_day=2.,last_complete_source_window=float(cont[-1]['t1']),seconds=js(W/'dataqual-continuation-O2/manifest.json')['events'][-1]['seconds'],
  attempts=sum(int(r['attempts'])for r in cont),solver_rejections=sum(int(r['solver_rejections'])for r in cont),temporal_rejections=sum(int(r['temporal_rejections'])for r in cont),mass_rejections=sum(int(r['mass_rejections'])for r in cont),
  nonlinear_iterations=sum(int(r['nonlinear_iterations'])for r in csv.DictReader((W/'dataqual-continuation-O2/cost.csv').open())),status='CENSORED',inflight_counts_available=False),
 comparison=next(r['comparison']for r in all_results if r['id']=='historical-comparison'),production_admission_changed=False,full_historical_closure=False)
assert result['physical_passes']>=20 and result['active_oxygen_reduction_cm']>0 and result['restart_exact']
(D/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');files['FINAL_RESULT.json']=(D/'RESULT.json').read_bytes()
keys=['batch','id','mode','status','completed_days','last_successful_time','seconds','seconds_per_day','attempts','solver_iterations','solver_rejections','temporal_rejections','mass_rejections','water_max_independent_cm','oxygen_reduction_cm','restart','failure_category','failure']
with(D/'summary.csv').open('w',newline='')as f:
 writer=csv.DictWriter(f,fieldnames=keys,extrasaction='ignore');writer.writeheader();writer.writerows(all_results)
files['aggregate-results.json']=(json.dumps(all_results,indent=2)+'\n').encode()
base='e47e98c6b8e614c75284c831925a34d7756cd4b0'
paths=subprocess.check_output(['git','diff','--name-only',base,'HEAD'],cwd=ROOT,text=True).splitlines();executed={p:sha((ROOT/p).read_bytes())for p in paths if not p.startswith('integration/dataqual01/')or p.endswith('.py')}
for p in executed:add('executed/'+p,ROOT/p)
files['executed-postimages.json']=(json.dumps(executed,indent=2)+'\n').encode();files['MANIFEST.json']=(json.dumps({p:sha(b)for p,b in sorted(files.items())},indent=2)+'\n').encode()
sink=io.BytesIO()
with tarfile.open(fileobj=sink,mode='w:xz')as t:
 for p,b in sorted(files.items()):info=tarfile.TarInfo(p);info.size=len(b);info.mtime=0;t.addfile(info,io.BytesIO(b))
raw=sink.getvalue();encoded=base64.b64encode(raw);parts=[]
for i,at in enumerate(range(0,len(encoded),60000)):
 p=D/('evidence-'+str(i).zfill(3)+'.b64');p.write_bytes(encoded[at:at+60000]);parts.append(str(p.relative_to(ROOT)))
delta={x.split('\t')[1]:x.split('\t')[0]for x in subprocess.check_output(['git','diff','--name-status',base,'HEAD','--','src','app','tools','tests','examples','reference','.github','integration/audits'],cwd=ROOT,text=True).splitlines()}
s=dict(workstream='RT/MP/VQ',work_unit='SWAP5-DATAQUAL01',baseline=base,stage='QUALIFIED_INFRASTRUCTURE_PENDING_CANONICAL_MERGE',implemented=True,persisted=True,tested=True,qualified=True,canonically_admitted=False,
 scope='Explicit experimental empirical-root oxygen admission and bounded independent historical batches; no production physics promotion',contract='integration/dataqual01/CONTRACT.md',scientific_delta=delta,postimages=executed,
 evidence=dict(parts=parts,sha256=sha(raw),bytes=len(raw),members=len(files)),result=result,
 interfaces_changed=['default-false forcing evidence flag','native CLI execution mode','additive read-only application diagnostic files'],invariants=[3,7,13,21,23,26],
 test_selection=dict(selected=['checked GNU13.3 O0/O2 actual historical native source','same-platform restart and six corruption controls','current root component/contracts','current incumbent joint/rootless trace rollback and restart bodies','predecessor exact physical preservation','unchanged FSI35 executable dependency identities','docs source and strict build'],not_selected=['fresh481','broad F-CI','highest low-air','RossFast']),
 exclusions=['No generic permission for unimplemented process combinations','No full4.3.1 scientific equivalence','No empirical oxygen production promotion','No portable speed claim','No in-flight counters after timeout','Native variable crack surface conductivity and saturated startup remain unavailable'],
 next_action='Verify successor owner and strict docs on persisted exact postimage, reconcile live PR1457/canonical, then integrate infrastructure only; retain production guard.')
(D/'STATUS.json').write_text(json.dumps(s,indent=2)+'\n');print(json.dumps(dict(result=result,evidence_bytes=len(raw),parts=len(parts))))
