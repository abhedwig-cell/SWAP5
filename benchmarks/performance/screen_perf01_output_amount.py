"""Explicit research: bound output difference in cm, retain uptake-rate budget."""
import csv,hashlib,json,os,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=Path(os.environ.get('PERF01_AMOUNT_OUT','/tmp/perf01-output-amount-v1'));OUT.mkdir();BASE=Path(os.environ.get('PERF01_AMOUNT_BASE','/tmp/perf01-historical-current-v2'));BUNDLE=Path(os.environ.get('PERF01_AMOUNT_BUNDLE','/tmp/perf01-historical-current-O2'));events=[]
def run(cmd,cwd,label,cap=30):
 t=time.perf_counter()
 try:p=subprocess.run(cmd,cwd=cwd,capture_output=True,timeout=cap);code=p.returncode;out=p.stdout;err=p.stderr
 except subprocess.TimeoutExpired as e:code='TIMEOUT';out=e.stdout or b'';err=e.stderr or b''
 (OUT/(label+'.stdout')).write_bytes(out);(OUT/(label+'.stderr')).write_bytes(err);events.append(dict(label=label,command=list(map(str,cmd)),returncode=code,seconds=time.perf_counter()-t));(OUT/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n');return code
src=ROOT/'src/process/mod_pond_water_temporal_difference.f90';text=src.read_text();assert text.count('output_error=abs(output(1)-output(2)-output(3))/dt')==1
text=text.replace('output_error=abs(output(1)-output(2)-output(3))/dt','output_error=abs(output(1)-output(2)-output(3))').replace('output_error/policy%output_rate_budget_cm_day','output_error/policy%state_budget_cm')
p=OUT/src.name;p.write_text(text);meta=json.loads((BUNDLE/'shared/build-complete.json').read_text());cmd=next(e['command']for e in meta['events']if str(src)in e['command']);oldobj=cmd[-1];obj=OUT/'metric.o';cmd=[str(p)if x==str(src)else str(obj)if x==oldobj else '-J'+str(OUT)if x.startswith('-J')else x for x in cmd];assert run(cmd,OUT,'compile')==0
assert(OUT/'mod_pond_water_temporal_difference.mod').read_bytes()==(BUNDLE/'shared/mod_pond_water_temporal_difference.mod').read_bytes()
link=next(e['command']for e in json.loads((BASE/'RESULT.json').read_text())['events']if e['label']=='project-build');cmd=[str(obj)if x==oldobj else str(OUT/'project')if x==str(BASE/'project')else '-J'+str(OUT)if x.startswith('-J')else x for x in link];assert run(cmd,OUT,'link')==0
cases={}
for label,stop,restart in [('first2',2,'-'),('day146',146,'/tmp/perf01-historical-4x-v1/head-stop145/restart.bin')]:
 d=OUT/label;d.mkdir()
 for n in ['input.nml','input.swp']:(d/n).write_bytes((Path('/tmp/perf01-historical-4x-v1/flux')/n).read_bytes())
 code=run([str(OUT/'project'),'input.nml',restart,str(stop),'input.swp'],d,label)
 rows=list(csv.DictReader((d/'budget.csv').open()));cases[label]=dict(returncode=code,published_days=len(rows))
 if code==0:
  cases[label]['max_water_residual_cm']=max(abs(float(v['water_residual_cm']))for v in rows);assert cases[label]['max_water_residual_cm']<1e-10
r=dict(status='OUTPUT_AMOUNT_RESEARCH_COMPLETED',production_qualified=False,contract='0.001cm external output amount difference instead of0.001cm/day output rate; retain existing uptake rate,water,GWL and Boesten history budgets',cases=cases,events=events)
(OUT/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(cases))
