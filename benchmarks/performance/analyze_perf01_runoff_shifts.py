"""Separate daily comparison failure from cumulative/event consequences."""
import csv,hashlib,itertools,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'benchmarks/performance/PERF01_RUNOFF_SHIFT_20261024_RESULT.json'
folders={'retained':'/tmp/perf01-historical-stages-v4/detailed','dry_head':'/tmp/perf01-historical-hybrid-stages-v1/detailed','incumbent_plus':'/tmp/perf01-historical-incumbent-stages-v1/detailed'}
r=dict(status='OBSERVATIONAL_ANALYSIS_NOT_ADMISSION',production_changed=False,daily_limit_mm=.01,cases={})
for label,path in folders.items():
 p=Path(path);read=lambda arm:list(csv.DictReader((p/arm/'budget.csv').open()));a,b=read('head'),read('flux');assert len(a)==len(b)==481
 case=dict(inputs={arm:hashlib.sha256((p/arm/'budget.csv').read_bytes()).hexdigest()for arm in ['head','flux']},metrics={})
 for k in ['runoff_cm','actual_transpiration_cm','soil_evaporation_cm','pond_evaporation_cm']:
  av=[10*float(v[k])for v in a];bv=[10*float(v[k])for v in b];d=[y-x for x,y in zip(av,bv)];c=list(itertools.accumulate(d))
  case['metrics'][k]=dict(reference_total_mm=sum(av),candidate_total_mm=sum(bv),final_cumulative_difference_mm=sum(d),max_abs_cumulative_difference_mm=max(map(abs,c)),max_abs_daily_difference_mm=max(map(abs,d)),days_over_limit=sum(abs(v)>.01 for v in d))
 runoff=lambda v:float(v['runoff_cm'])>0
 case['runoff_occurrence_change_days']=[i+1 for i,(x,y)in enumerate(zip(a,b))if runoff(x)!=runoff(y)]
 case['storage_final_difference_mm']=10*(float(b[-1]['water_end_cm'])-float(a[-1]['water_end_cm']))
 case['max_storage_difference_mm']=10*max(abs(float(y['water_end_cm'])-float(x['water_end_cm']))for x,y in zip(a,b))
 d=[10*(float(y['runoff_cm'])-float(x['runoff_cm']))for x,y in zip(a,b)]
 case['largest_daily_runoff_differences']=[dict(day=i+1,difference_mm=d[i],reference_mm=10*float(a[i]['runoff_cm']))for i in sorted(range(len(d)),key=lambda i:abs(d[i]),reverse=True)[:8]]
 # Independently reconstruct cumulative water closure from gross CSV terms.
 for arm,data in [('head',a),('flux',b)]:
  closure=float(data[-1]['water_end_cm'])-float(data[0]['water_start_cm'])-sum(float(v['water_in_cm'])-float(v['water_out_cm'])for v in data)
  assert abs(closure)<1e-10;case[arm+'_whole_period_water_closure_mm']=10*closure
 r['cases'][label]=case
OUT.write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({k:dict(runoff=v['metrics']['runoff_cm'],switch_days=v['runoff_occurrence_change_days'],storage_final_mm=v['storage_final_difference_mm'])for k,v in r['cases'].items()},indent=2))
