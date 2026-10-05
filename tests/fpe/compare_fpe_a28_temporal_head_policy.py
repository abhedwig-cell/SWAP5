"""Prospective head-policy gates; no edits to A28 practical qualification."""
import json,sys
from pathlib import Path
ref=json.loads(Path(sys.argv[1]).read_text());trial=json.loads(Path(sys.argv[2]).read_text())
n=min(len(ref['rows']),len(trial['rows']))
assert n>=19,'strict19-window overlap required'
assert ref['dt_day']==trial['dt_day']
metrics={'head_difference_cm':0.,'matrix_pond_difference_cm':0.,'flux_floored_relative_difference':0.,
         'cumulative_weighted_exchange_difference_cm':0.,'cumulative_nonmatrix_output_difference_cm':0.}
cumulative_ref=[0.,0.];cumulative_trial=[0.,0.];rain_ref=0.;rain_trial=0.
for a,b in zip(ref['rows'][:n],trial['rows'][:n]):
 assert a['window']==b['window'] and a['rain_cm_day']==b['rain_cm_day']
 dt=ref['dt_day'];rain_ref+=a['rain_cm_day']*dt;rain_trial+=b['rain_cm_day']*dt
 metrics['head_difference_cm']=max(metrics['head_difference_cm'],abs(a['head_m']-b['head_m'])*100.)
 for i in range(2):
  metrics['matrix_pond_difference_cm']=max(metrics['matrix_pond_difference_cm'],abs(a['matrix'][i]-b['matrix'][i]))
  qa=a['q'+str(i+1)];qb=b['q'+str(i+1)]
  metrics['flux_floored_relative_difference']=max(metrics['flux_floored_relative_difference'],abs(qa-qb)/max(abs(qa),1e-9))
  cumulative_ref[i]+=qa*dt*86400.*100.;cumulative_trial[i]+=qb*dt*86400.*100.
  out_a=rain_ref-(a['matrix'][i]+a['rfm'][i]-ref['initial_matrix_cm'][i]-ref['initial_rfm_cm'][i])-cumulative_ref[i]
  out_b=rain_trial-(b['matrix'][i]+b['rfm'][i]-trial['initial_matrix_cm'][i]-trial['initial_rfm_cm'][i])-cumulative_trial[i]
  metrics['cumulative_nonmatrix_output_difference_cm']=max(metrics['cumulative_nonmatrix_output_difference_cm'],abs(out_a-out_b))
 weighted=.35*(cumulative_ref[0]-cumulative_trial[0])+.65*(cumulative_ref[1]-cumulative_trial[1])
 metrics['cumulative_weighted_exchange_difference_cm']=max(metrics['cumulative_weighted_exchange_difference_cm'],abs(weighted))
limits={k:(.01 if k=='flux_floored_relative_difference' else .001) for k in metrics}
passed=all(metrics[k]<=limits[k] for k in metrics)
result={'status':'PASS_PREFIX_ONLY' if passed else 'FAIL','overlap_windows':n,'metrics':metrics,'limits':limits,
        'accuracy_beyond_strict_overlap_qualified':False,'production_admitted':False}
Path(sys.argv[3]).write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
assert passed,'head-policy comparison exceeds preregistered gates'
