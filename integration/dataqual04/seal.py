"""Authenticate executed data, cost counterexample, source identities and recovery."""
import base64,csv,hashlib,io,json,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];W=ROOT.parent;D=ROOT/'integration/dataqual04';BASE='872cf5aacdd87981206c9c1b6d05318d26fad3e1';files={};sha=lambda b:hashlib.sha256(b).hexdigest()
def add(n,p):files[n]=Path(p).read_bytes()
def directory(n,p):
 for q in Path(p).rglob('*'):
  if q.is_file()and'__pycache__'not in q.parts and q.suffix not in ['.o','.mod']and not(q.stat().st_mode&0o111):add(n+'/'+str(q.relative_to(p)),q)
def js(p):return json.loads(Path(p).read_bytes())
old=runpy.run_path(str(ROOT/'integration/audits/verify_dataqual03_current.py'))['capsule']()
for p in ['state.csv','temperature.csv','budget.csv','progress.csv','cost.csv','diagnostics.csv','restart.bin']:files['parent/default-two/'+p]=old['parent/default-two/'+p]
add('parent-owner.json',W/'dataqual04-parent-owner.json');files['parent-commit.raw']=subprocess.check_output(['git','cat-file','commit',BASE],cwd=ROOT)
results=[]
for opt in ['O0','O2']:
 for name in ['short','two']:
  label=name+'-'+opt;folder=W/('dataqual04-final-'+label);directory(label,folder)
  results.extend(dict(batch=label,**r)for r in js(folder/'results.json'))
 folder=W/('dataqual04-final-native-'+opt)
 for p in folder.rglob('*.json'):add('build/'+opt+'/'+str(p.relative_to(folder)),p)
for name in ['cost-O0','cost-O2','budget128','budget256','controls']:directory(name,W/('dataqual04-final-'+name))
directory('baseline',W/'dataqual04-baseline')
for name in ['short-O2','short2-O2','short2-O0','two-O0','two-O2','smallstep-O0','smallstep-O2','off-O2','reject-O0','reject-O2','budget128-origin','budget256-origin']:
 directory('development/'+name,W/('dataqual04-'+name))
for name in ['primary-three','checkpoint']:
 p=W/('dataqual04-'+name)
 if p.exists():directory(name,p)
for label in ['build','build-O0','reject-rebuild-O0','reject-rebuild-O2','cost-rebuild-O0','cost-rebuild-O2']:
 p=W/('dataqual04-'+label+'.log')
 if p.exists():add('compile-logs/'+label+'.log',p)
bundle=W/'dataqual04-development.bundle';subprocess.run(['git','update-ref','refs/dataqual04/development-source','07e1f07d6eda66693f265fce0cff94cff9e1071a'],cwd=ROOT,check=True);subprocess.run(['git','bundle','create',str(bundle),'refs/dataqual04/development-source','^'+BASE],cwd=ROOT,check=True);add('recovery/development.bundle',bundle)
physical=['state.csv','temperature.csv','budget.csv','progress.csv','cost.csv','diagnostics.csv']
for opt in ['O0','O2']:
 root=W/('dataqual04-final-two-'+opt)
 for p in physical:assert (root/'default-two/run'/p).read_bytes()==files['parent/default-two/'+p],(opt,p)
 assert (root/'default-two/run/restart.bin').read_bytes()[72:-4]==files['parent/default-two/restart.bin'][72:-4]
 for p in ['state.csv','temperature.csv','restart.bin']:assert(root/'budget128-two/run'/p).read_bytes()==(root/'budget128-two/resumed'/p).read_bytes(),(opt,p)
a=W/'dataqual04-final-two-O0/budget128-two/run';b=W/'dataqual04-final-two-O2/budget128-two/run'
for p in ['state.csv','temperature.csv']:assert(a/p).read_bytes()==(b/p).read_bytes()
assert(a/'restart.bin').read_bytes()[72:-4]==(b/'restart.bin').read_bytes()[72:-4]
base=list(csv.DictReader((W/'dataqual04-baseline/replay/cost.csv').open()))[-1];probes=[]
for name in ['cost-O0','cost-O2','budget128','budget256']:
 d=W/('dataqual04-final-'+name);m=js(d/'RESULT.json');assert m['rollback_exact']and not m['censored']and m['returncode']!=0
 rows=[x.split()for x in(d/'stderr').read_text().splitlines()if x.strip().startswith('MACRO_REJECT')];c=list(csv.DictReader((d/'cost.csv').open()))[-1]
 assert int(c['nonlinear_iterations'])==int(base['nonlinear_iterations'])+sum(int(x[9])for x in rows)
 assert int(c['headcalc_calls'])==int(base['headcalc_calls'])+len(rows)
 for p in ['budget.csv','progress.csv','diagnostics.csv']:assert(d/p).read_bytes()==(W/'dataqual04-baseline/replay'/p).read_bytes()
 probes.append(dict(name=name,budget=m['solver_max_iterations'],seconds=m['seconds'],recorded_rejected_inner_solves=len(rows),failed_nonlinear_iterations=sum(int(x[9])for x in rows),nonlinear_iterations=int(c['nonlinear_iterations']),headcalc_calls=int(c['headcalc_calls']),last_internal_time=float(rows[-1][1]),rollback_exact=True,origin_state_only=True))
report=dict(default_preserved_exact=True,O0_O2_endpoint_exact=True,primary_restart_exact=True,failed_window_rollback_exact=True,iteration_budget_does_not_fix_stall=True,failed_work_counted=True,three_day_complete=False,scenario_executions=len(results),physical_passes=sum(r['status']=='PASS'for r in results),rejected=sum(r['status']=='FAILED'for r in results),probes=probes,old_reported_nonlinear_iterations=int(base['nonlinear_iterations']),old_reported_headcalc_calls=int(base['headcalc_calls']),new_physical_progress_claim=False,production_admission_changed=False,full_historical_closure=False)
(D/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');files['FINAL_RESULT.json']=(D/'RESULT.json').read_bytes()
keys=['batch','id','mode','status','completed_days','seconds','seconds_per_day','solver_iterations','solver_rejections','temporal_rejections','mass_rejections','water_max_independent_cm','restart','failure']
with(D/'summary.csv').open('w',newline='')as f:
 w=csv.DictWriter(f,fieldnames=keys,extrasaction='ignore',lineterminator='\n');w.writeheader();w.writerows(results)
add('recovery/native-O2',W/'dataqual04-final-native-O2/column/swap5_solute_project')
m=js(W/'dataqual04-final-cost-O2/RESULT.json');recovery=dict(executable='recovery/native-O2',executable_sha256=sha(files['recovery/native-O2']),cwd='replay',prepared_inputs={p:'cost-O2/'+('origin.bin'if p=='restart.bin'else p)for p in ['input.nml','input.swp','macro.nml','restart.bin']},command=['../recovery/native-O2',*m['command'][1:]],environment={'SWAP5_DIAG_MACRO_TEMPORAL':'1'},origin_state_only=True,new_restart_qualified=False,warning='Empty input-only cwd. Authentic DATAQUAL03 origin binding; never retag. Reproduces numerical rejection and corrected failed-work counts only, not a new-source historical restart qualification. Primary current-source two-day/full-split proof is separate. Same platform only.')
(D/'RECOVERY.json').write_text(json.dumps(recovery,indent=2)+'\n');files['RECOVERY.json']=(D/'RECOVERY.json').read_bytes()
paths=subprocess.check_output(['git','diff','--name-only',BASE,'HEAD'],cwd=ROOT,text=True).splitlines();posts={p:sha((ROOT/p).read_bytes())for p in paths if not p.startswith('integration/dataqual04/')or p.endswith('.py')or p in ['integration/dataqual04/short-batch.json','integration/dataqual04/two-day.json','integration/dataqual04/CONTRACT.md']}
for p in posts:add('executed/'+p,ROOT/p)
files['executed-postimages.json']=(json.dumps(posts,indent=2)+'\n').encode();files['MANIFEST.json']=(json.dumps({p:sha(b)for p,b in sorted(files.items())},indent=2)+'\n').encode();sink=io.BytesIO()
with tarfile.open(fileobj=sink,mode='w:xz')as t:
 for p,b in sorted(files.items()):i=tarfile.TarInfo(p);i.size=len(b);i.mtime=0;i.mode=0o755 if p=='recovery/native-O2'else 0o644;t.addfile(i,io.BytesIO(b))
raw=sink.getvalue();encoded=base64.b64encode(raw);parts=[]
for i,at in enumerate(range(0,len(encoded),60000)):
 p=D/f'evidence-{i:03d}.b64';p.write_bytes(encoded[at:at+60000]);parts.append(str(p.relative_to(ROOT)))
for p in D.glob('evidence-*.b64'):
 if str(p.relative_to(ROOT))not in parts:p.unlink()
delta={r.split('\t')[1]:r.split('\t')[0]for r in subprocess.check_output(['git','diff','--name-status',BASE,'HEAD','--','src','app','tools','tests','examples','reference','.github','integration/audits'],cwd=ROOT,text=True).splitlines()}
s=dict(work_unit='DATAQUAL04',workstream='RT/HY/MP/VQ',baseline=BASE,stage='QUALIFIED_BOUNDED_DIAGNOSTICS_PENDING_CANONICAL',implemented=True,persisted=True,tested=True,qualified=True,canonically_admitted=False,scope='Correct rejected inner-solver cost accounting and expose explicit bounded iteration-budget experiments; no physical progress or production promotion',contract='integration/dataqual04/CONTRACT.md',scientific_delta=delta,core_changes=[p for p in delta if p.startswith('src/')],postimages=posts,evidence=dict(parts=parts,sha256=sha(raw),bytes=len(raw),members=len(files)),result=report,test_selection=dict(selected=['current real GNU13.3 checked O0/O2 native short/two-day/full-split models','same-origin64/128/256 failure costs with per-rejection iteration accounting','native mode/range/CRC/binding atomic controls','predecessor-exact production and O0/O2 endpoint/payload','current source/raw/corruption/unchanged FSI35','source/strict docs'],not_selected=['fresh481','full numerical F-CI','highest low-air','RossFast','new physics qualification']),next_action='Verify exact canonical merge; then diagnose a concrete inner Richards/macropore residual/Jacobian failure at internal2.848675 without more budget increases.')
(D/'STATUS.json').write_text(json.dumps(s,indent=2)+'\n');print(json.dumps(dict(result=report,evidence_bytes=len(raw),parts=len(parts))))
