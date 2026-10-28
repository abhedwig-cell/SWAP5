"""Seal actual model output, failures, restarts and bounded source authority."""
import base64,collections,csv,hashlib,io,json,math,runpy,statistics,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];W=ROOT.parent;D=ROOT/'integration/dataqual05';BASE='5a0b0fcd4461d651c141919da09a8ddcb9ff25e2';sha=lambda b:hashlib.sha256(b).hexdigest();files={}
def add(name,path):files[name]=Path(path).read_bytes()
def js(path):return json.loads(Path(path).read_bytes())
def directory(name,path):
 for p in Path(path).rglob('*'):
  if p.is_file()and'__pycache__'not in p.parts and p.suffix not in ['.o','.mod']and not(p.stat().st_mode&0o111):add(name+'/'+str(p.relative_to(path)),p)
batches=['scale64-O2','wet-window64-O2','qualification-O2','qualification-O0','storms-O2','storms-fixed-O2','capped-storms-O2','capped-qualification-O0','serial-check-O2','wet-window64-v2-O2']
expected=[64,64,4,4,4,4,4,2,2,64];all_rows=[];native=[]
def signature(r):
 c=r['configuration'];keys=dict(mode='experimental',source_surface_demand=False,perched_jacobian=False,solver_max_iterations=64,anchored=True,entry_width_cm=1e-4,transformations=[])
 return json.dumps({k:c.get(k,v)for k,v in keys.items()},sort_keys=True)
for name,count in zip(batches,expected):
 folder=W/name;r=js(folder/'results.json');assert len(r)==count,(name,len(r));directory(name,folder);all_rows.extend(dict(batch=name,**x)for x in r)
 for m in folder.glob('*/**/manifest.json'):
  record=js(m)
  for event in record.get('events',[]):
   if event['label']=='native':native.append(dict(batch=name,case=m.parent.parent.name,**event))
# Main-source builds must genuinely match current science, including documented label refresh.
for opt in ['O0','O2']:
 for folder,label in [(W/('final-'+opt),'build/'+opt),(W/('candidate-'+opt),'cold-build/'+opt)]:
  for p in folder.rglob('*.json'):add(label+'/'+str(p.relative_to(folder)),p)
 build=js(W/('final-'+opt)/'column/build-complete.json')
 assert all(sha((ROOT/p).read_bytes())==h for p,h in build['input_sha256'].items())
 for name in ['build-'+opt,'candidate-'+opt,'refresh-'+opt,'final-'+opt]:
  p=W/(name+'.log')
  if p.exists():add('compile-logs/'+name+'.log',p)
for name,path in [('contract','runoff-contract-v2'),('controls','runoff-controls'),('fsi35','runoff-fsi35')]:directory(name,W/path)
for name in ['runoff-contract','runoff-contract-v2','runoff-controls','runoff-fsi35']:
 p=W/(name+'.log')
 if p.exists():add('logs/'+name+'.log',p)
# Retain the initial failed contract harness and all genuine model counterexamples.
directory('development/first-contract',W/'runoff-contract')
for folder in Path('/tmp').glob('swap5-fci93-fixed-k.*'):
 for p in folder.rglob('*'):
  if p.is_file()and p.suffix in ['.f90','.txt']:add('fsi35/materialized/'+str(p.relative_to(folder)),p)
parent=runpy.run_path(str(W/'SWAP5/integration/audits/verify_dataqual04_current.py'))['capsule']()
for p in ['state.csv','temperature.csv','budget.csv','progress.csv','cost.csv','diagnostics.csv','restart.bin']:files['parent/default-two/'+p]=parent['parent/default-two/'+p]
add('development/rank4-first-summary.json',W/'rank4-first-summary.json');add('parent-owner.json',W/'baseline-owner.json');files['parent-commit.raw']=subprocess.check_output(['git','cat-file','commit',BASE],cwd=ROOT)
# Matched same-platform recovery for a genuinely censored2day source configuration.
bundle=js(W/'final-O2/bundle.json');add('recovery/native-O2',bundle['exe']);folder=W/'scale64-O2/oa64-00/run'
for p in ['input.nml','input.swp','macro.nml','restart.bin','manifest.json']:add('recovery/'+p,folder/p)
command=next(x['command']for x in js(folder/'manifest.json')['events']if x['label']=='native');command[0]='./native-O2';command[2]='restart.bin';command[3]='2';command[7]='2'
recovery=dict(executable='recovery/native-O2',executable_sha256=sha(files['recovery/native-O2']),checkpoint='recovery/restart.bin',checkpoint_sha256=sha(files['recovery/restart.bin']),committed_time=1.,command=command,warning='Input-only directory; same GNU13.3/Linux platform. Restore executable permission. Target2days was censored at15s; continuation is not qualified. Never retag binding or reuse another executable.')
(D/'RECOVERY.json').write_text(json.dumps(recovery,indent=2)+'\n')
passes=[r for r in all_rows if r['status']=='PASS'];counters=collections.Counter(r['qualification_category']for r in all_rows)
primary_native=[]
for r in all_rows:
 p=W/r['batch']/r['id']/'run/manifest.json'
 if p.exists()and any(e['label']=='native'for e in js(p).get('events',[])):primary_native.append(r)
qualified_oa={r['id']:r for r in all_rows if r['status']=='PASS'and r['batch']=='wet-window64-v2-O2'};design=js(D/'design-v2.json');axes=design['factors'];pairs={}
import itertools
for a,b in itertools.combinations(axes,2):pairs[a+'|'+b]=sorted({(r['configuration']['factors'][a],r['configuration']['factors'][b])for r in qualified_oa.values()})
coverage=dict(design_configurations=64,design_factor_pairs=66,design_level_pairs=264,configured_level_pairs=design['covered_level_pairs'],water_qualified_distinct_design_rows=len(qualified_oa),water_qualified_level_pairs=sum(map(len,pairs.values())),water_qualified_pairs=pairs,qualification_extent='through1.054days only; not seasonal coverage',source_options=['112nodes,8source soil rows,5macro domains','SWSOLU0','SWMACRO1/SWDARCY1/SWSORP1/source initialization;constant1000cm/day surface conductivity only','SWINTER3 Rutter','SWREDU2 Boesten','SWDROUGHT1/substep Feddes;SWOXYGEN0 or1 experimental','SWDRA1/DRAMET3/tube/drainage-only','SWBBCFILE1/SWBOTB3','SWHEA1/SWCALT2 numeric heat','new RSROEXP0.5..2 experimental'],exclusions=['full season/year boundary','variable surface conductivity','native solute/N','SWCROP2/WOFOST dispatch','snow/frost/extended surface water compositions','full4.3.1 equivalence'])
physical_files=['state.csv','temperature.csv']
exactness={}
for name in ['oa64-00','oa64-08','default-two','original-corrected-two']:
 a=W/'qualification-O0'/name/'run';b=W/'qualification-O2'/name/'run';assert all((a/p).read_bytes()==(b/p).read_bytes()for p in physical_files);assert(a/'restart.bin').read_bytes()[72:-4]==(b/'restart.bin').read_bytes()[72:-4];exactness[name]=True
for name in ['cap-storm-e0p5-r4p0','cap-storm-e2p0-r4p0']:
 a=W/'capped-qualification-O0'/name/'run';b=W/'capped-storms-O2'/name/'run';assert all((a/p).read_bytes()==(b/p).read_bytes()for p in physical_files);assert(a/'restart.bin').read_bytes()[72:-4]==(b/'restart.bin').read_bytes()[72:-4];exactness[name]=True
for name in ['oa64-00','oa64-08']:
 for p in physical_files+['budget.csv','progress.csv','cost.csv','diagnostics.csv','restart.bin']:
  assert(W/'serial-check-O2'/name/'run'/p).read_bytes()==(W/'qualification-O2'/name/'run'/p).read_bytes()
report=dict(design_correction='First two64-row campaigns contain only16 unique factor vectors, repeated4times; V2 has64 unique vectors verified from actual input hashes. No historical result relabelled.',batches=batches,scenario_executions=len(all_rows),distinct_configurations=len({signature(r)for r in all_rows}),water_native_primary_executions=len(primary_native),distinct_water_native_configurations=len({signature(r)for r in primary_native}),native_process_executions_including_restarts=len(native),completed_native_processes=sum(e['returncode']==0 for e in native),physical_completions=len(passes),distinct_physically_completed_configurations=len({signature(r)for r in passes}),categories=dict(counters),restart_exact_executions=sum(r['restart']=='exact'for r in passes),restart_exact_distinct_configurations=len({signature(r)for r in passes if r['restart']=='exact'}),max_water_certificate_cm=max(r['water_max_independent_cm']for r in passes),longest_integral_days=max(r['completed_days']for r in passes),positive_runoff_completed_executions=sum(r['flux_totals_cm']['runoff_cm']>0 for r in passes),max_runoff_cm=max(r['flux_totals_cm']['runoff_cm']for r in passes),O0_O2_endpoint_payload_exact=exactness,serial_parallel_physical_exact=True,default_predecessor_exact=True,qualification_basis='finite112-node state/heat,theta0..1,4 independent water certificates<=1e-10cm,no mass rejections,exact target and committed restart; selected full/split/O0/O2; no full energy/solute/N/parity certification',counts_caveat='Scenario executions include repeated targets/builds and rejected readers. Distinct means normalized input transformations+execution/physical/numerical options, not independent historical projects. Native counts exclude input readers and6 direct negative controls; include real split/resumed processes.',coverage=coverage,reference_comparison=next(r['comparison']for r in all_rows if r['batch']=='qualification-O2'and r['id']=='original-corrected-two'),remaining_closure=['Coupled Richards/macropore residual/Jacobian: dry-start budget failures and separate admitted2.848675 stall; precise mechanism unproved','Variable surface conductivity below the1000cm/day cap: four correctly rejected low-macro storm inputs','Full-season original macro trajectory and year-boundary restart, beyond bounded source windows','Broader native process/input compositions, including original chemistry/N and WOFOST/snow/extended drainage','Full4.3.1 trajectory and flux equivalence; existing rounded GWL/drainage differences remain'])
files['FINAL_RESULT.json']=(json.dumps(report,indent=2)+'\n').encode();files['all-results.json']=(json.dumps(all_rows,indent=2)+'\n').encode();files['native-events.json']=(json.dumps(native,indent=2)+'\n').encode()
(D/'RESULT.json').write_bytes(files['FINAL_RESULT.json']);(D/'COVERAGE.json').write_text(json.dumps(coverage,indent=2)+'\n')
keys=['batch','id','mode','status','qualification_category','completed_days','simulated_days','seconds','seconds_per_day','attempts','solver_rejections','temporal_rejections','mass_rejections','solver_iterations','water_max_independent_cm','last_successful_time','last_restart_time','restart','failure_category','failure']
with(D/'summary.csv').open('w',newline='')as f:
 writer=csv.DictWriter(f,fieldnames=keys,extrasaction='ignore');writer.writeheader();writer.writerows(all_rows)
(D/'all-results.json').write_bytes(files['all-results.json'])
delta={r.split('\t')[1]:r.split('\t')[0]for r in subprocess.check_output(['git','diff','--name-status',BASE,'HEAD','--','src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance'],cwd=ROOT,text=True).splitlines()}
paths=set(delta)|{'integration/dataqual05/CONTRACT.md'}
paths|={p for p in subprocess.check_output(['git','ls-files','integration/dataqual05'],cwd=ROOT,text=True).splitlines()if Path(p).suffix in ['.py','.f90']or Path(p).name in ['scale64.json','wet-window64.json','storms.json','capped-storms.json','qualification.json','capped-qualification.json','serial-check.json','design.json','design-v2.json','scale64-v2.json','wet-window64-v2.json']}
posts={p:sha((ROOT/p).read_bytes())for p in sorted(paths)}
for p in posts:files['executed/'+p]=(ROOT/p).read_bytes()
files['executed-postimages.json']=(json.dumps(posts,indent=2)+'\n').encode();files['MANIFEST.json']=(json.dumps({p:sha(v)for p,v in files.items()},indent=2)+'\n').encode()
buf=io.BytesIO()
with tarfile.open(fileobj=buf,mode='w:xz',preset=6)as archive:
 for p,content in sorted(files.items()):
  info=tarfile.TarInfo(p);info.size=len(content);info.mode=0o644;archive.addfile(info,io.BytesIO(content))
raw=buf.getvalue();encoded=base64.b64encode(raw);parts=[]
for i,at in enumerate(range(0,len(encoded),60000)):
 p=D/f'evidence-{i:03d}.b64';p.write_bytes(encoded[at:at+60000]);parts.append(str(p.relative_to(ROOT)))
for p in D.glob('evidence-*.b64'):
 if str(p.relative_to(ROOT))not in parts:p.unlink()
status=dict(work_unit='DATAQUAL05',workstream='RT/HY/VQ',baseline=BASE,stage='TESTED_PENDING_SOURCE_RAW_QUALIFICATION',implemented=True,persisted=True,tested=True,qualified=False,canonically_admitted=False,production_admission_changed=False,full_historical_closure=False,contract='integration/dataqual05/CONTRACT.md',scientific_delta=delta,core_changes=[p for p in delta if p.startswith('src/')],postimages=posts,evidence=dict(parts=parts,sha256=sha(raw),bytes=len(raw),members=len(files)),result=report,recovery='integration/dataqual05/RECOVERY.json',test_selection=dict(selected=['current GNU13.3 checked O0/O2 real-provider nonlinear root/FD/real128 and exact linear predecessor','216 primary bounded scenario attempts, including corrected64 unique vectors and retained repeated-design attempts, plus actual source-bound full/split restarts','six direct native mode/range/CRC/binding atomic controls','six configuration O0/O2 endpoint/payload comparisons and serial/parallel exactness','affected FCI93 immutable native oracle O0/O2;26 unchanged dependencies,1changed','current source/raw/corruption and strict docs'],not_selected=['fresh481','unselected full numerical F-CI','highest low-air','RossFast','full chemistry/N','production nonlinear admission']),next_action='Run current source/raw/corruption/docs gates; publish one coherent PR, observe actual required checks, verify canonical merge tree and receipt.')
(D/'STATUS.json').write_text(json.dumps(status,indent=2)+'\n');print(json.dumps(dict(scenarios=len(all_rows),physical_completions=len(passes),distinct_native=report['distinct_water_native_configurations'],categories=dict(counters),evidence_bytes=len(raw),parts=len(parts))))
