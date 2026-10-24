"""Seal current scientific failures, observational counters and bounded PASS."""
import csv,hashlib,io,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];HERE=ROOT/'benchmarks/performance';sha=lambda b:hashlib.sha256(b).hexdigest();js=lambda p:json.loads(Path(p).read_text())
canonical='aba91da43';canonical=subprocess.check_output(['git','rev-parse',canonical],cwd=ROOT,text=True).strip()
assert not subprocess.check_output(['git','diff',canonical,'--','src','app','tools','tests'],cwd=ROOT).strip(),'production drift'
continuous=js('/tmp/perf01-continuous-current-v1/RESULT.json');o0=js('/tmp/perf01-continuous-current-O0/O0_O2_IDENTITY.json');restart97=js('/tmp/perf01-continuous-current-v1/RESTART_CHECK.json')
assert all(c['physical_screen_pass']for c in continuous['cases'].values())
assert all(v for case in o0.values()for arm in case.values()for v in arm.values())
assert all(c['restart_exact']and c['max_total_evaporation_difference_mm']<.01 for c in restart97.values())
stages={label:js('/tmp/'+folder+'/RESULT.json')for label,folder in [('initial','perf01-historical-stages-v1'),('ordinary_fallback','perf01-historical-stages-v3'),('retained','perf01-historical-stages-v4'),('dry_head','perf01-historical-hybrid-stages-v1'),('incumbent_plus','perf01-historical-incumbent-stages-v1')]}
assert all(r['original_positive_rejection_pass']for r in stages.values())
assert all(not c['physical_screen_pass']for label,r in stages.items()if label!='initial'for c in r['cases'].values())
assert stages['initial']['cases']['detailed']['flux']['returncode']=='TIMEOUT120'
restart481=js('/tmp/perf01-historical-restart-v1/RESULT.json');assert restart481['status']=='ACTUAL_DAY240_RESTART_EXACT'
work={a:js('/tmp/'+p+'/RESULT.json')for a,p in [('head','perf01-historical-head-work-v1'),('flux','perf01-historical-work-v2')]}
assert all(r['status']=='OBSERVATIONAL_COUNTERS_PHYSICAL_BYTES_EXACT'for r in work.values())
# Earlier Picard/continuous cases hit an explicit zero-work preflight then retried.
fallbacks={}
for label,folder in [('published_combined','perf01-combined-screen-v7'),('current_continuous','perf01-continuous-current-v1')]:
 fallbacks[label]={}
 for case in js('/tmp/'+folder+'/RESULT.json')['cases']:
  fallbacks[label][case]={}
  for arm in ['head','flux']:
   folderpath=Path('/tmp')/folder;events=js(folderpath/'RESULT.json')['events'];ev=next(e for e in events if e['label']==case+'-'+arm);i=events.index(ev)
   stdout=(folderpath/(str(i)+'.stdout')).read_text();count=stdout.count('SWAP5_PROJECT_STEP_PROPOSAL_FALLBACK');assert count==97
   fallbacks[label][case][arm]=count
rows=lambda p:list(csv.DictReader(Path(p).open()))
def totals(folder):
 r={}
 for arm in ['head','flux']:
  data=rows(Path(folder)/arm/'budget.csv');r[arm]=dict(days=len(data),accepted_substeps=sum(int(v['accepted_substeps'])for v in data),runoff_cm=sum(float(v['runoff_cm'])for v in data),max_water_residual_cm=max(abs(float(v['water_residual_cm']))for v in data))
 return r
result=dict(status='RESEARCH_HISTORICAL_DAILY_ACCURACY_FAIL_NO_PRODUCTION_ADMISSION',canonical_baseline=canonical,production_changed=False,production_qualified=False,
 continuous_97=continuous['cases'],O0_O2_identity=o0,restart97=restart97,restart481=restart481,
 historical={k:dict(status=v['status'],cases=v['cases'])for k,v in stages.items()},
 work={k:dict(segments=v['segments'],totals=v['totals'],top_days_by_headcalc=v['top_days_by_headcalc'])for k,v in work.items()},
 detailed_work_totals=totals('/tmp/perf01-historical-stages-v4/detailed'),fallback_correction=fallbacks,
 limitation='Historical input has positive chemistry; all historical comparison runs explicitly zero CPRE/CDRAIN/CMLTB. Daily acceptance limit0.01mm remains unmet. Native times single observations, some overlapping build/research processes; not portable speed estimates.',
 next_safe_step='Preserve bounded production use. Investigate accumulated surface evaporation/runoff and local-to-daily error propagation before any general numerical option expansion; positive chemistry remains excluded.')
files={}
folders=['perf01-continuous-current-v1','perf01-continuous-current-O0','perf01-historical-current-v1','perf01-historical-current-v2','perf01-historical-hybrid-v1','perf01-historical-hybrid-v2','perf01-historical-incumbent-v1','perf01-historical-stages-v1','perf01-historical-stages-v2','perf01-historical-stages-v3','perf01-historical-stages-v4','perf01-historical-hybrid-stages-v1','perf01-historical-incumbent-stages-v1','perf01-historical-work-v1','perf01-historical-work-v2','perf01-historical-head-work-v1','perf01-historical-restart-v1']
for label in folders:
 folder=Path('/tmp')/label
 for p in folder.rglob('*'):
  if not p.is_file()or p.suffix in ['.o','.mod','.a']:continue
  b=p.read_bytes()
  if not b.startswith(b'\x7fELF'):files['raw/'+label+'/'+str(p.relative_to(folder))]=b
for optimization in ['O0','O2']:
 base=Path('/tmp/perf01-historical-current-'+optimization)
 for p in base.rglob('*.json'):files['build/'+optimization+'/'+str(p.relative_to(base))]=p.read_bytes()
 for p in base.rglob('*.stderr'):files['build/'+optimization+'/'+str(p.relative_to(base))]=p.read_bytes()
for p in Path('/tmp').glob('perf01-historical*.log'):
 if 'seal'not in p.name:files['logs/'+p.name]=p.read_bytes()
for name in ['screen_perf01_geometry.py','screen_perf01_historical.py','measure_perf01_historical_work.py','check_perf01_historical_restart.py','check_perf01_geometry_restart.py','PERF01_HISTORICAL_RESEARCH_20261024.md','seal_perf01_historical_research.py']:files['reproduction/'+name]=(HERE/name).read_bytes()
files['RESULT.json']=json.dumps(result,indent=2).encode();files['MANIFEST.json']=json.dumps({p:sha(b)for p,b in sorted(files.items())},indent=2).encode()
target=HERE/'PERF01_HISTORICAL_20261024_EVIDENCE.tar.xz'
with tarfile.open(target,'w:xz')as t:
 for p,b in sorted(files.items()):m=tarfile.TarInfo(p);m.size=len(b);t.addfile(m,io.BytesIO(b))
with tarfile.open(target)as t:
 members=t.getmembers();assert len(members)==len(files)
 for m in members:assert t.extractfile(m).read()==files[m.name]
result['evidence']=dict(path=str(target.relative_to(ROOT)),sha256=sha(target.read_bytes()),members=len(files),bytes=target.stat().st_size)
(HERE/'PERF01_HISTORICAL_20261024_RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result['evidence']))
