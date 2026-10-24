"""Pinned full481-day amount-budget refinement; retain previous reference bytes."""
import csv,hashlib,itertools,json,os,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=Path(os.environ.get('PERF01_REFINE_OUT','/tmp/perf01-amount-refinement'));OUT.mkdir();exe=Path(os.environ.get('PERF01_REFINE_EXE','/tmp/perf01-output-tight-O2/project'));r=dict(status='RUNNING',production_qualified=False,build_result=json.loads((exe.parent/'RESULT.json').read_text()),events=[],cases={})
def save():(OUT/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n')
for rain,ref in [(1,'perf01-endpoint-1x-v1'),(4,'perf01-endpoint-check-v1')]:
 source=Path('/tmp')/ref;d=OUT/str(rain);d.mkdir()
 for n in ['input.nml','input.swp']:(d/n).write_bytes((source/'full481-flux'/n).read_bytes())
 cmd=[str(exe),'input.nml','-','481','input.swp'];t=time.perf_counter()
 try:p=subprocess.run(cmd,cwd=d,capture_output=True,timeout=120);code=p.returncode;out=p.stdout;err=p.stderr
 except subprocess.TimeoutExpired as e:code='TIMEOUT120';out=e.stdout or b'';err=e.stderr or b''
 (d/'stdout').write_bytes(out);(d/'stderr').write_bytes(err);ev=dict(command=cmd,seconds=time.perf_counter()-t,returncode=code);r['events'].append(ev);save()
 if code!=0:continue
 a=list(csv.DictReader((source/'full481-head/budget.csv').open()));b=list(csv.DictReader((d/'budget.csv').open()));assert len(a)==len(b)==481
 c=dict(metrics={},native_seconds=ev['seconds'],reference_sha256=hashlib.sha256((source/'full481-head/budget.csv').read_bytes()).hexdigest())
 for k in ['runoff_cm','actual_transpiration_cm','soil_evaporation_cm','pond_evaporation_cm']:
  diff=[10*(float(y[k])-float(x[k]))for x,y in zip(a,b)];c['metrics'][k]=dict(max_daily_mm=max(map(abs,diff)),total_mm=sum(diff),max_cumulative_mm=max(map(abs,itertools.accumulate(diff))))
 c['max_storage_mm']=10*max(abs(float(y['water_end_cm'])-float(x['water_end_cm']))for x,y in zip(a,b));c['max_water_residual_cm']=max(abs(float(x['water_residual_cm']))for x in b);assert c['max_water_residual_cm']<1e-10
 c['runoff_occurrence_changes']=[dict(day=i+1,head_mm=10*float(x['runoff_cm']),flux_mm=10*float(y['runoff_cm']))for i,(x,y)in enumerate(zip(a,b))if(float(x['runoff_cm'])>0)!=(float(y['runoff_cm'])>0)]
 c['largest_runoff_differences']=[dict(day=i+1,head_mm=10*float(a[i]['runoff_cm']),flux_mm=10*float(b[i]['runoff_cm']))for i in sorted(range(481),key=lambda i:abs(float(a[i]['runoff_cm'])-float(b[i]['runoff_cm'])),reverse=True)[:5]]
 r['cases'][str(rain)]=c;save()
r['status']='REFINEMENT_COMPLETED';save();print(json.dumps(r['cases'],indent=2))
