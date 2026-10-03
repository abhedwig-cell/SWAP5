"""Frozen coupled comparison limits; no policy fitting."""
import json,re,sys
from pathlib import Path
x,y=map(Path,sys.argv[1:3])
if x.suffix=='.json':
 a,b=json.loads(x.read_text()),json.loads(y.read_text())
 assert a['windows']==b['windows'] and a['dt_day']==b['dt_day']
 limits={'head_m':1e-12,'q1':1e-15,'q2':1e-15,'qw':1e-15,'residual':1e-15,'ledger1':1e-12,'ledger2':1e-12}
 differences={k:max(abs(u[k]-v[k]) for u,v in zip(a['rows'],b['rows'],strict=True)) for k in limits}
 for field in ['matrix','rfm']:
  differences[field]=max(abs(q-r) for u,v in zip(a['rows'],b['rows'],strict=True) for q,r in zip(u[field],v[field],strict=True))
  limits[field]=1e-10
 differences['coupling_iterations']=max(v['iterations']-u['iterations'] for u,v in zip(a['rows'],b['rows'],strict=True))
 limits['coupling_iterations']=0
 output={'maximum_absolute_difference':differences,'limits':limits,'approximate_panels_active':sum(b['sorptivity_counts'][1:])>0,
 'qualification_execution_ratio_exact_over_a28':a['execution_seconds']/b['execution_seconds'],
 'performance_claim':'Qualification includes repeated FD sensitivity/replay; not a production speedup or scale claim.'}
else:
 def read(p):return {k:float(v) for k,v in re.findall(r'^(FGC45_(?:FINAL_\w+|LEDGER\d_M))=(.+)$',p.read_text(),re.M)}
 a,b=read(x),read(y);assert a.keys()==b.keys() and len(a)==8
 limits={k:(1e-12 if 'HEAD' in k or 'LEDGER' in k else 1e-15) for k in a}
 differences={k:abs(a[k]-b[k]) for k in a}
 output={'maximum_absolute_difference':differences,'limits':limits}
failed=[k for k in limits if differences[k]>limits[k]]
output['status']='PASS' if not failed else 'FAIL';output['failed']=failed
print(json.dumps(output,indent=2))
if failed:raise SystemExit(1)
