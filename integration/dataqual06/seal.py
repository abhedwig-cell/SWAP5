"""Seal all real DATAQUAL06 processes, source identities and censored checkpoints."""
import base64,collections,csv,hashlib,io,json,re,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];W=ROOT.parent;D=ROOT/'integration/dataqual06';BASE='cba2117d679fe1165cc03c60e86e67943a777466';sha=lambda b:hashlib.sha256(b).hexdigest();files={}
def js(p):return json.loads(Path(p).read_bytes())
def add(n,p):files[n]=Path(p).read_bytes()
def directory(n,path):
 for p in Path(path).rglob('*'):
  if p.is_file()and'__pycache__'not in p.parts and p.suffix not in ['.o','.mod']and not(p.stat().st_mode&0o111):add(n+'/'+str(p.relative_to(path)),p)
batches=['dq06-wet32-O2','dq06-storms-O0','dq06-storms-O2','dq06-static8-O2','dq06-qualification-O0','dq06-qualification-O2','dq06-static-qualification-O0'];expected=[32,4,4,8,4,4,2];allrows=[];native=[]
for name,count in zip(batches,expected):
 folder=W/name;r=js(folder/'results.json');assert len(r)==count;directory(name,folder);allrows.extend(dict(batch=name,**x)for x in r)
 for p in folder.glob('*/**/manifest.json'):
  for event in js(p).get('events',[]):
   if event['label']=='native':native.append(dict(batch=name,case=p.parent.parent.name,**event))
for opt in ['O0','O2']:
 build=W/('dq06-final-'+opt)
 for p in build.rglob('*.json'):add('build/'+opt+'/'+str(p.relative_to(build)),p)
 meta=js(build/'column/build-complete.json');assert all(sha((ROOT/p).read_bytes())==h for p,h in meta['input_sha256'].items())
 assert sha(Path(js(build/'bundle.json')['exe']).read_bytes())==meta['executable_sha256']
 physical=W/('dq06-'+opt)/'shared'
 for p in physical.glob('*.json'):add('cold-build/'+opt+'/'+p.name,p)
for label,name in [('contract','dq06-contract-v3'),('controls','dq06-controls'),('fsi35','dq06-fsi35-v2')]:directory(label,W/name)
for name in ['dq06-contract','dq06-contract-v2','dq06-fsi35']:
 directory('development/'+name,W/name)
for p in W.glob('dq06-*.log'):add('logs/'+p.name,p)
# Literal predecessor raw evidence and qualified production trajectories remain immutable.
old=runpy.run_path(str(ROOT/'integration/audits/verify_dataqual05_current.py'))['capsule']()
for name in ['default-two','original-corrected-two']:
 for f in ['state.csv','temperature.csv','budget.csv','progress.csv','cost.csv','diagnostics.csv','restart.bin']:files['parent/'+name+'/'+f]=old['qualification-O2/'+name+'/run/'+f]
# Same-platform matched executable/checkpoint for one genuinely censored low-area storm.
folder=W/'dq06-storms-O2/low-storm-e0p5-r4p0/run';bundle=js(W/'dq06-final-O2/bundle.json');add('recovery/native-O2',bundle['exe'])
for f in ['input.nml','input.swp','macro.nml','restart.bin','manifest.json']:add('recovery/'+f,folder/f)
cmd=next(x['command']for x in js(folder/'manifest.json')['events']if x['label']=='native');cmd[0]='./native-O2';cmd[2]='restart.bin'
recovery=dict(executable_sha256=sha(files['recovery/native-O2']),restart_sha256=sha(files['recovery/restart.bin']),last_committed_time=1.,command=cmd,warning='GNU13.3/Linux matched input/executable only; target1.054 censored at90s, continuation unqualified; never retag binding')
(D/'RECOVERY.json').write_text(json.dumps(recovery,indent=2)+'\n');files['recovery/RECOVERY.json']=(D/'RECOVERY.json').read_bytes()
passes=[x for x in allrows if x['status']=='PASS'];uncapped=[]
for x in passes:
 if x['id'].startswith('static-'):
  t=files[x['batch']+'/'+x['id']+'/run/macro.nml'].decode();k=float(re.search(r'source_surface_conductivity=\s*([^\n]+)',t)[1]);assert 1e-14<=k<1000;uncapped.append(dict(batch=x['batch'],id=x['id'],initial_conductivity_cm_day=k))
report=dict(batches=batches,scenario_executions=len(allrows),distinct_configurations=len({x['configuration_sha256']for x in allrows}),native_process_executions_including_restarts=len(native),completed_native_processes=sum(x['returncode']==0 for x in native),water_qualified_executions=len(passes),distinct_water_qualified_configurations=len({x['configuration_sha256']for x in passes}),categories=dict(collections.Counter(x['qualification_category']for x in allrows)),max_water_certificate_cm=max(x['water_max_independent_cm']for x in passes),longest_integral_days=max(x['completed_days']for x in passes),restart_exact_executions=sum(x['restart']=='exact'for x in passes),restart_exact_distinct_configurations=len({x['configuration_sha256']for x in passes if x['restart']=='exact'}),uncapped_model_completions=uncapped,source_options=['SWSOLU0,112nodes,8soil layers,5macro domains','SWMACRO1/SWDARCY1/SWSORP1 with original shrinkage/current candidate geometry','SWINTER3,Rutter;SWREDU2,Boesten;SWDROUGHT1,Feddes;experimental empirical oxygen0/1','SWDRA1/DRAMET3/tube,SWBBCFILE1/SWBOTB3','SWHEA1/SWCALT2 numeric heat','experimental RSROEXP0.5..2 and source surface conductivity1e-14..1000cm/day'],counts_caveat='58 attempts include repeats across target/build and restarts;46 distinct input/policy configurations, variants of one historical project, not46 historical projects. All primary native processes started. Censors retain committed checkpoints; in-flight solver work after last returned source window is UNKNOWN.',qualification_basis='finite112-node state/heat,theta0..1,four independent water certificates<=1e-10cm,no mass rejections,exact target and committed restart; selected O0/O2/full-split. No whole-energy,chemical/N or431-equivalence qualification.',resources='Per-driver2or4workers; overlapped campaigns peak configured concurrency8 within8CPU/8GiB cgroup, OMP1 and inherited1GiB per launcher/native address-space limit. No speedup comparison.',remaining_closure=['Coupled Richards/macropore residual/Jacobian:26 budget censors including all8 low-area storm attempts; separate2.848675 remains unresolved','Full original season/year restart and wider independent historical project population','Broader native chem/N,WOFOST,snow,extended drainage compositions','Full SWAP431 trajectory/flux equivalence; only retained rounded reference deltas inherited','Stronger nonlinear head/flux/geometry Jacobian validation over active shrinking below-cap trajectories; bounded tested capability only'])
files['FINAL_RESULT.json']=(json.dumps(report,indent=2)+'\n').encode();files['all-results.json']=(json.dumps(allrows,indent=2)+'\n').encode();files['native-events.json']=(json.dumps(native,indent=2)+'\n').encode();(D/'RESULT.json').write_bytes(files['FINAL_RESULT.json']);(D/'all-results.json').write_bytes(files['all-results.json'])
keys=['batch','id','status','qualification_category','completed_days','seconds','seconds_per_day','solver_iterations','attempts','solver_rejections','temporal_rejections','mass_rejections','water_max_independent_cm','last_successful_time','restart','failure']
with(D/'summary.csv').open('w',newline='')as f:
 w=csv.DictWriter(f,fieldnames=keys,extrasaction='ignore');w.writeheader();w.writerows(allrows)
delta={r.split('\t')[1]:r.split('\t')[0]for r in subprocess.check_output(['git','diff','--name-status',BASE,'HEAD','--','src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance'],cwd=ROOT,text=True).splitlines()}
aux=[str(p.relative_to(ROOT))for p in sorted(D.iterdir())if p.suffix in ['.py','.f90']or p.name in ['CONTRACT.md','wet32.json','storms.json','static8.json','qualification.json','static-qualification.json']]
posts={p:sha((ROOT/p).read_bytes())for p in sorted(set(delta)|set(aux))}
for p in posts:files['executed/'+p]=(ROOT/p).read_bytes()
files['executed-postimages.json']=(json.dumps(posts,indent=2)+'\n').encode();files['MANIFEST.json']=(json.dumps({p:sha(v)for p,v in files.items()},indent=2)+'\n').encode()
buf=io.BytesIO()
with tarfile.open(fileobj=buf,mode='w:xz',preset=6)as archive:
 for name,content in sorted(files.items()):
  i=tarfile.TarInfo(name);i.size=len(content);i.mode=0o644;archive.addfile(i,io.BytesIO(content))
raw=buf.getvalue();encoded=base64.b64encode(raw);parts=[]
for n,at in enumerate(range(0,len(encoded),60000)):
 p=D/f'evidence-{n:03d}.b64';p.write_bytes(encoded[at:at+60000]);parts.append(str(p.relative_to(ROOT)))
for p in D.glob('evidence-*.b64'):
 if str(p.relative_to(ROOT))not in parts:p.unlink()
status=dict(work_unit='DATAQUAL06',workstream='RT/HY/VQ',baseline=BASE,stage='TESTED_PENDING_SOURCE_RAW_QUALIFICATION',implemented=True,persisted=True,tested=True,qualified=False,canonically_admitted=False,production_admission_changed=False,full_historical_closure=False,scientific_delta=delta,auxiliary_sources=aux,postimages=posts,evidence=dict(parts=parts,sha256=sha(raw),bytes=len(raw),members=len(files)),result=report,test_selection=dict(selected=['real adapter5provider162caseO0/O2 with independent real128 conductivity and exact literal disabled predecessor','58 actual bounded model attempts,32 unique wet low-area variants,8 initially uncapped source inputs and8 genuine storm censors','native atomic mode/reader/CRC/binding controls','production/current versus predecessor streams and physical restart payload, four O0/O2 configurations, selected full-split','affected FCI93 native immutable O0/O2 oracle:26 unchanged dependencies,one changed adapter','current source/raw/corruption and inherited literal predecessor raw assertions','strict docs'],not_selected=['unselected full numerical FCI','highest low-air','RossFast','fullseason/chemN/wholeenergy/full431equivalence']),next_action='Run current owner/raw controls and strict docs; publish coherent PR and inspect hosted checks through terminal, then exact canonical merge/admission receipt.')
(D/'STATUS.json').write_text(json.dumps(status,indent=2)+'\n');print(json.dumps(dict(report=report,bytes=len(raw),parts=len(parts))))
