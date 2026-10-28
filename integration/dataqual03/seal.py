"""Seal real DATAQUAL03 runs, retaining failed/censored outcomes and origin labels."""
import base64,csv,hashlib,io,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];W=ROOT.parent;D=ROOT/'integration/dataqual03';BASE='4b61966e63bcb20d0688c919687a798147226114';files={};sha=lambda b:hashlib.sha256(b).hexdigest()
def add(name,path):files[name]=Path(path).read_bytes()
def directory(name,path):
 for p in Path(path).rglob('*'):
  if p.is_file()and'__pycache__'not in p.parts and p.suffix not in ['.o','.mod'] and not (p.stat().st_mode&0o111):add(name+'/'+str(p.relative_to(path)),p)
def js(path):return json.loads(Path(path).read_bytes())
results=[]
for label in ['primary-O2','primary-O0','smoke','dependency']:
 directory(label,W/('dataqual03-'+label))
 for r in js(W/('dataqual03-'+label)/'results.json'):results.append(dict(batch=label,**r))
for label in ['controls','resumed-O0','checkpoint2743','checkpoint2748','three','window2-O2','window60-O2','window-O2']:
 directory(label,W/('dataqual03-'+label))
for opt in ['O0','O2']:
 for label in ['leaf','preserve','rootless']:directory(label+'-'+opt,W/('dataqual03-'+label+'-'+opt))
 folder=W/('dataqual03-native-'+opt)
 for path in folder.rglob('*.json'):add('build/'+opt+'/'+str(path.relative_to(folder)),path)
add('parent-owner.json',W/'dataqual02-final-owner.json');files['parent-commit.raw']=subprocess.check_output(['git','cat-file','commit',BASE],cwd=ROOT)
physical=['state.csv','temperature.csv','budget.csv','progress.csv','cost.csv','diagnostics.csv']
for name,old in [('default-two','literal-original-two'),('surface-two-off','source-demand-two')]:
 parent=W/'dataqual02-runs-O2'/old/'run'
 for opt in ['O0','O2']:
  current=W/('dataqual03-primary-'+opt)/name/'run'
  for p in physical:assert (current/p).read_bytes()==(parent/p).read_bytes(),(opt,name,p)
  assert (current/'restart.bin').read_bytes()[72:-4]==(parent/'restart.bin').read_bytes()[72:-4]
 for p in physical+['restart.bin']:add('parent/'+name+'/'+p,parent/p)
primary=W/'dataqual03-primary-O2/jacobian-primary/run';other=W/'dataqual03-resumed-O0'
for p in ['state.csv','temperature.csv']:assert (primary/p).read_bytes()==(other/p).read_bytes()
assert (primary/'restart.bin').read_bytes()[72:-4]==(other/'restart.bin').read_bytes()[72:-4]
for p in ['state.csv','temperature.csv','restart.bin']:assert (primary/p).read_bytes()==(primary.parent/'resumed'/p).read_bytes()
assert (W/'dataqual03-checkpoint2748/restart.bin').read_bytes()==(W/'dataqual03-three/diagnostic-rejected.bin').read_bytes()
window=js(W/'dataqual03-window60-O2/RESULT.json');assert window[0]['censored']and window[1]['returncode']==0
cost=list(csv.DictReader((W/'dataqual03-three/cost.csv').open()));last=cost[-1]
result=dict(default_preserved_exact=True,O0_O2_endpoint_exact=True,primary_restart_exact=True,failed_window_rollback_exact=True,primary_end_day=2.5140000000028522,new_committed_checkpoint=2.7479999999995925,window_off_censored=True,window_on_complete=True,three_day_complete=False,
 scenario_executions=len(results),physical_passes=sum(r['status']=='PASS'for r in results),censored=sum(r['status']=='CENSORED'for r in results),failed_or_rejected=sum(r['status']=='FAILED'for r in results),skipped=sum(r['status']=='SKIPPED_DEPENDENCY'for r in results),
 O0_note='Initial full process censored at60s; own day2 restart continuation completes2.514 with exact O2 endpoint physical payload.',
 old_dependency_attempt='primary-O2/jacobian-five FAILED missing predecessor restart before collector fix; harness dependency failure, not a numerical result.',
 numerical_window=dict(origin_day=2.4950000000026193,target_day=2.5140000000028522,off_seconds=window[0]['seconds'],on_seconds=window[1]['seconds'],origin_state_only=True,restart_qualification=False,portable_speedup_claim=False),
 failed_window=last,production_admission_changed=False,full_historical_closure=False)
(D/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');files['FINAL_RESULT.json']=(D/'RESULT.json').read_bytes()
keys=['batch','id','mode','status','completed_days','last_successful_time','seconds','solver_iterations','temporal_rejections','water_max_independent_cm','restart','failure']
with(D/'summary.csv').open('w',newline='')as f:
 w=csv.DictWriter(f,fieldnames=keys,extrasaction='ignore');w.writeheader();w.writerows(results)
add('recovery/native-O2',W/'dataqual03-native-O2/column/swap5_solute_project')
m=js(W/'dataqual03-checkpoint2748/manifest.json')
recovery=dict(executable='recovery/native-O2',executable_sha256=sha(files['recovery/native-O2']),same_platform_only=True,cwd='replay',prepared_inputs={p:'checkpoint2748/'+p for p in ['input.nml','input.swp','macro.nml','restart.bin']},command=['../recovery/native-O2','input.nml','origin.bin','3','input.swp','macro.nml',m['binding_sha256'],'3','anchored-cauchy','0.0001','experimental','source-surface-demand','perched-jacobian'],warning='Extract verified capsule, create empty replay directory, copy only prepared_inputs there and name the input restart origin.bin. This next source window is expected to reject near2.748; use external timeout. Never retag bindings. Prior origin-state window diagnostics do not qualify new restart histories.')
(D/'RECOVERY.json').write_text(json.dumps(recovery,indent=2)+'\n');files['RECOVERY.json']=(D/'RECOVERY.json').read_bytes()
paths=subprocess.check_output(['git','diff','--name-only',BASE,'HEAD'],cwd=ROOT,text=True).splitlines();posts={p:sha((ROOT/p).read_bytes())for p in paths if not p.startswith('integration/dataqual03/')or p.endswith('.py')or p.endswith('.f90')}
for p in posts:add('executed/'+p,ROOT/p)
files['executed-postimages.json']=(json.dumps(posts,indent=2)+'\n').encode();files['MANIFEST.json']=(json.dumps({p:sha(b)for p,b in sorted(files.items())},indent=2)+'\n').encode()
sink=io.BytesIO()
with tarfile.open(fileobj=sink,mode='w:xz')as t:
 for p,b in sorted(files.items()):
  info=tarfile.TarInfo(p);info.size=len(b);info.mtime=0;info.mode=0o755 if p=='recovery/native-O2'else 0o644;t.addfile(info,io.BytesIO(b))
raw=sink.getvalue();encoded=base64.b64encode(raw);parts=[]
for i,at in enumerate(range(0,len(encoded),60000)):
 p=D/f'evidence-{i:03d}.b64';p.write_bytes(encoded[at:at+60000]);parts.append(str(p.relative_to(ROOT)))
delta={r.split('\t')[1]:r.split('\t')[0]for r in subprocess.check_output(['git','diff','--name-status',BASE,'HEAD','--','src','app','tools','tests','examples','reference','.github','integration/audits'],cwd=ROOT,text=True).splitlines()}
status=dict(workstream='RT/HY/MP/VQ',work_unit='DATAQUAL03',baseline=BASE,stage='QUALIFIED_BOUNDED_EXPERIMENTAL_PENDING_CANONICAL',implemented=True,persisted=True,tested=True,qualified=True,canonically_admitted=False,scope='Default-off perched seepage diagonal numerical policy, source-bound primary endpoint2.514, accepted checkpoint2.748; day3 fails',contract='integration/dataqual03/CONTRACT.md',scientific_delta=delta,core_changes=[p for p in delta if p.startswith('src/')],postimages=posts,evidence=dict(parts=parts,sha256=sha(raw),bytes=len(raw),members=len(files)),result=result,next_action='Verify exact merge and retain default production admission. Diagnose moving boundary and temporal rejection collapse after2.748 without relaxing tolerances.')
(D/'STATUS.json').write_text(json.dumps(status,indent=2)+'\n');print(json.dumps(dict(result=result,evidence_bytes=len(raw),parts=len(parts))))
