"""Check unchanged historical project availability and actual option admission."""
import csv,hashlib,json,subprocess,sys,tarfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=Path('/tmp/perf01-practical-scope');OUT.mkdir()
project=OUT/'project';project.mkdir();prefix='native-boesten-O2/historical/'
with tarfile.open(ROOT/'benchmarks/performance/PERF01_TYPED_WATER_FLUX_20261023_OWNER_EVIDENCE.tar.xz')as t:
 for m in t.getmembers():
  if not m.name.startswith(prefix):continue
  name=m.name[len(prefix):]
  if name=='project.swp'or name.startswith(('crop data/','weather data/')):
   assert m.isfile()and '..'not in Path(name).parts;p=project/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(t.extractfile(m).read())
common=[sys.executable,'-B',ROOT/'tools/solute/run_project.py',project/'project.swp','--bundle','/tmp/perf01-complete-O2','--temporal-tolerance','.001','--solute-transport','implicit_upwind','--water-conductivity','picard_continuous','--surface-exfiltration','historical_zero']
r=dict(status='RUNNING',checkpoint=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),events=[])
for label,extra in [('reference',[]),('flux',['--retain-step-proposal','--water-flux-temporal'])]:
 cmd=[*common,'--output',OUT/label,*extra];start=time.perf_counter();p=subprocess.run(list(map(str,cmd)),cwd=ROOT,capture_output=True,timeout=60)
 for s in ['stdout','stderr']:(OUT/(label+'.'+s)).write_bytes(getattr(p,s))
 r['events'].append(dict(label=label,command=list(map(str,cmd)),seconds=time.perf_counter()-start,returncode=p.returncode))
 if label=='reference':
  assert p.returncode==0,p.stderr.decode();rows=list(csv.DictReader((OUT/label/'budget.csv').open()));assert len(rows)==481
  r['reference']=dict(days=len(rows),max_water_residual_cm=max(abs(float(d['water_residual_cm']))for d in rows),runoff_cm=sum(float(d['runoff_cm'])for d in rows))
 else:assert p.returncode!=0 and b'water/flux temporal metric requires frozen native Reference step proposals'in p.stderr and not(OUT/label).exists()
r.update(status='REFERENCE_481_PASS_FLUX_UNSUPPORTED_CONFIGURATION_REJECTED',practical_option_qualified=False,speed_ratio=None,
 blocker='Historical project uses implicit-upwind solute transport, continuous Picard conductivity and Boesten evaporation. Flux policy additionally restricts geometry to four cells totaling30cm. Qualification expansion required before practical use.')
(OUT/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r['reference']));print(r['status'])
