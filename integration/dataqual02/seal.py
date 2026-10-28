"""Seal the actual surface-demand experiment without copying unrelated evidence."""
import base64,csv,hashlib,io,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];W=ROOT.parent;D=ROOT/'integration/dataqual02';BASE='ad62053833bbd2a5f40a493db89ae4b02cd11a46';files={};sha=lambda b:hashlib.sha256(b).hexdigest()
def add(name,path):files[name]=Path(path).read_bytes()
def directory(name,path):
 for p in Path(path).rglob('*'):
  if p.is_file()and'__pycache__'not in p.parts:add(name+'/'+str(p.relative_to(path)),p)
def js(path):return json.loads(Path(path).read_bytes())
batches={'batch-O2':'dataqual02-runs-O2','batch-O0':'dataqual02-runs-O0','combined':'dataqual02-combined-O2','reporting':'dataqual02-reporting-final'};results=[]
for label,path in batches.items():
 directory(label,W/path)
 for r in js(W/path/'results.json'):results.append(dict(batch=label,**r))
directory('controls',W/'dataqual02-controls');directory('checkpoint',W/'dataqual02-checkpoint');directory('local-window',W/'dataqual02-local-window')
for opt in ['O0','O2']:
 folder=W/('dataqual02-build-'+opt)
 for path in folder.rglob('*.json'):add('build/'+opt+'/'+str(path.relative_to(folder)),path)
add('parent-owner.json',W/'final-canonical-owner.json');files['parent-commit.raw']=subprocess.check_output(['git','cat-file','commit',BASE],cwd=ROOT)
for p in ['ADMISSION.json','STATUS.json']:add('parent-'+p,ROOT/'integration/dataqual01'/p)
legacy=W/'dataqual02-runs-O2/literal-original-two/run';current=W/'dataqual02-runs-O2/source-demand-two/run';other=W/'dataqual02-runs-O0/source-demand-two/run';parent=W/'dataqual-final-results-O2/historical-comparison/run'
physical=['state.csv','temperature.csv','budget.csv','progress.csv','cost.csv','diagnostics.csv']
for p in physical:
 assert (current/p).read_bytes()==(other/p).read_bytes(),p
 assert (legacy/p).read_bytes()==(parent/p).read_bytes(),p
 add('parent-physical/'+p,parent/p)
assert (current/'restart.bin').read_bytes()[72:-4]==(other/'restart.bin').read_bytes()[72:-4]
assert (legacy/'restart.bin').read_bytes()[72:-4]==(parent/'restart.bin').read_bytes()[72:-4]
for p in ['state.csv','temperature.csv','restart.bin']:assert (current/p).read_bytes()==(current.parent/'resumed'/p).read_bytes()
import runpy
surface=runpy.run_path(str(D/'check_surface_demand.py'))['check'](current)
for label in ['paired-00-on','paired-01-on','paired-04-on','paired-05-on']:
 row=next(csv.DictReader((W/'dataqual02-runs-O2'/label/'run/budget.csv').open()))
 assert float(row['soil_evap_cm'])>0.
 # Rain variation may legitimately reset SPEV/SAEV at the endpoint.

passes=[r for r in results if r['status']=='PASS'];primary={r['id']:r for r in results if r['batch']=='batch-O2'}
assert all(primary[x]['status']=='FAILED'for x in ['production-variant-rejected','comparison-variant-rejected','negative-pond-rejected'])
assert primary['source-demand-continuation']['status']=='CENSORED'
reporting={r['id']:r for r in results if r['batch']=='reporting'}
assert reporting['censored-report']['status']=='CENSORED'and reporting['censored-report']['failure']and all(v is None for v in reporting['censored-report']['flux_totals_cm'].values())
assert 'requires --mode experimental'in reporting['invalid-mode-report']['failure']
cont=primary['source-demand-continuation'];assert cont['last_successful_time']==2.4950000000026193
checkpoint=js(W/'dataqual02-checkpoint/manifest.json');assert checkpoint['status']=='COMPLETE';cb=list(csv.DictReader((W/'dataqual02-checkpoint/budget.csv').open()));assert float(cb[-1]['t1'])==cont['last_successful_time']
local=js(W/'dataqual02-local-window/manifest.json');assert local['status']=='CENSORED'
result=dict(scenario_executions=len(results),physical_passes=len(passes),failed_or_rejected=sum(r['status']=='FAILED'for r in results),censored=sum(r['status']=='CENSORED'for r in results),
 physical_O0_O2_exact=True,default_preserved_exact=True,same_variant_restart_exact=True,surface_demand=surface,
 independent_water_max_cm=max(r['water_max_independent_cm']for r in passes),
 old_reference=primary['literal-original-two']['comparison'],corrected_reference=primary['source-demand-two']['comparison'],
 old_iterations=primary['literal-original-two']['solver_iterations'],corrected_iterations=primary['source-demand-two']['solver_iterations'],
 continuation={k:cont[k]for k in ['status','seconds','last_successful_time','attempts','solver_iterations','temporal_rejections','solver_rejections','mass_rejections']},
 checkpoint=dict(time=cont['last_successful_time'],status='COMPLETE',seconds=checkpoint['events'][-1]['seconds'],restart_sha256=sha((W/'dataqual02-checkpoint/restart.bin').read_bytes())),
 local_window=dict(status='CENSORED',seconds=local['events'][-1]['seconds'],environment={'SWAP5_DIAG_MACRO_TEMPORAL':'1'},last_complete_source_window=cont['last_successful_time'],inflight_progress_is_not_committed_source_window=True),
 production_admission_changed=False,full_historical_closure=False)
add('recovery/native-O2',W/'dataqual02-build-O2/column/swap5_solute_project')
recovery=dict(executable='recovery/native-O2',executable_sha256=sha(files['recovery/native-O2']),same_platform_only=True,
 cwd='checkpoint',command=['../recovery/native-O2','input.nml','restart.bin','3','input.swp','macro.nml',checkpoint['binding_sha256'],'2.5140000000028522','anchored-cauchy','0.0001','experimental','source-surface-demand'],
 warning='Use a fresh copied checkpoint directory and an external timeout. Complete source-window2.495 is preserved; local-window is censored and not accepted output.')
(D/'RECOVERY.json').write_text(json.dumps(recovery,indent=2)+'\n');files['RECOVERY.json']=(D/'RECOVERY.json').read_bytes()
(D/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');files['FINAL_RESULT.json']=(D/'RESULT.json').read_bytes()
keys=['batch','id','mode','status','completed_days','last_successful_time','seconds','solver_iterations','temporal_rejections','water_max_independent_cm','restart','failure']
with(D/'summary.csv').open('w',newline='')as f:
 w=csv.DictWriter(f,fieldnames=keys,extrasaction='ignore');w.writeheader();w.writerows(results)
paths=subprocess.check_output(['git','diff','--name-only',BASE,'HEAD'],cwd=ROOT,text=True).splitlines();posts={p:sha((ROOT/p).read_bytes())for p in paths if not p.startswith('integration/dataqual02/')or p.endswith('.py')}
for p in posts:add('executed/'+p,ROOT/p)
files['executed-postimages.json']=(json.dumps(posts,indent=2)+'\n').encode();files['MANIFEST.json']=(json.dumps({p:sha(b)for p,b in sorted(files.items())},indent=2)+'\n').encode()
sink=io.BytesIO()
with tarfile.open(fileobj=sink,mode='w:xz')as t:
 for p,b in sorted(files.items()):info=tarfile.TarInfo(p);info.size=len(b);info.mtime=0;info.mode=0o755 if p=='recovery/native-O2'else 0o644;t.addfile(info,io.BytesIO(b))
raw=sink.getvalue();encoded=base64.b64encode(raw);parts=[]
for i,at in enumerate(range(0,len(encoded),60000)):
 p=D/f'evidence-{i:03d}.b64';p.write_bytes(encoded[at:at+60000]);parts.append(str(p.relative_to(ROOT)))
delta={r.split('\t')[1]:r.split('\t')[0]for r in subprocess.check_output(['git','diff','--name-status',BASE,'HEAD','--','src','app','tools','tests','examples','reference','.github','integration/audits'],cwd=ROOT,text=True).splitlines()}
status=dict(workstream='RT/VQ',work_unit='DATAQUAL02',baseline=BASE,stage='QUALIFIED_EXPERIMENTAL_SOURCE_MAPPING_PENDING_CANONICAL',implemented=True,persisted=True,tested=True,qualified=True,canonically_admitted=False,scope='Explicit default-off original positive surface demand into existing Boesten owner; no production promotion',contract='integration/dataqual02/CONTRACT.md',scientific_delta=delta,postimages=posts,
 evidence=dict(parts=parts,sha256=sha(raw),bytes=len(raw),members=len(files)),result=result,
 source_provenance=dict(pr1457_head='51439058f58cc1c8ca7f3cf803a851b768bb4bff',imported='Only original soil/pond potential-demand assignments, under a new experimental gate',not_imported=['continuous wall law','perched Jacobian','coupled hydraulics','141day evidence']),
 test_selection=dict(selected=['Adapter rebuild with verified unchanged194-provider physical build O0/O2','Actual original day1/days1-2 and independent positive-demand history','Paired forcing cases and active empirical-oxygen composition','Exact default and O0/O2 endpoint/payload preservation','Same-variant restart and six direct native negative controls','Own corrected2.495 source-event checkpoint and bounded local diagnostic','Owner source/raw and unchanged FSI35','Docs source/strict'],not_selected=['fresh481','broad F-CI','low-air','RossFast','unchanged physical process requalification']),
 next_action='Verify current owner/source and actual canonical merge; then prioritize remaining local hydraulic transient cost using the exact corrected2.495 restart.')
(D/'STATUS.json').write_text(json.dumps(status,indent=2)+'\n');print(json.dumps(dict(result=result,evidence_bytes=len(raw),parts=len(parts))))
