"""Independent non-temporally-certified Richards trajectory refinement panel."""
import argparse,ctypes,json,subprocess,sys
from pathlib import Path
import numpy as np
from component import Swap

def one(a):
 s=Swap(a.library);assert s.initialize(.1,-5,a.elastic_per_cm)==0
 if a.depth_budget_rate:
  s.lib.strip_set_rate_budget.argtypes=[ctypes.c_int];assert s.lib.strip_set_rate_budget(1)==0
 if a.newton_budget:
  s.lib.strip_set_newton_budget.argtypes=[ctypes.c_int];assert s.lib.strip_set_newton_budget(1)==0
 before=s.state();f=s.lib.strip_floor;f.restype=ctypes.c_int
 ptr=ctypes.POINTER(ctypes.c_double);f.argtypes=[ctypes.c_double,ctypes.c_double,ctypes.c_int,ptr,ptr,ptr]
 heads=np.zeros(30);water=np.zeros(30);stats=np.zeros(8)
 rc=f(a.dt,a.head,a.subdivisions,*[v.ctypes.data_as(ptr) for v in [heads,water,stats]])
 assert all(np.array_equal(v,w) for v,w in zip(before,s.state())), 'diagnostic mutated coupling origin'
 reported=s.lib.strip_floor_reported_gwl;reported.restype=ctypes.c_double;reported.argtypes=[]
 derived=None
 if rc==0:
  z=-10-20*np.arange(30);positive=np.flatnonzero(heads>=0)
  if len(positive) and positive[0]>0:
   j=positive[0];derived=.01*(z[j-1]-heads[j-1]*(z[j]-z[j-1])/(heads[j]-heads[j-1]))
 row=dict(reported_gwl_m=reported() if rc==0 else None,pressure_zero_gwl_m=derived,status=rc,complete=rc==0,dt_day=a.dt,head_m=a.head,subdivisions=a.subdivisions,elastic_per_cm=a.elastic_per_cm,pressure_cm=heads.tolist(),water_content=water.tolist(),stats=stats.tolist(),origin_unchanged=True,temporal_acceptance_claim=False,depth_budget_rate=a.depth_budget_rate,newton_budget=a.newton_budget)
 if a.newton_budget and rc==0:assert max(abs(heads))<=500
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(row,indent=2)+'\n')
 print('REFINEMENT_SAMPLE',a.dt,a.head,a.subdivisions,rc,stats[:4],flush=True)

def main():
 p=argparse.ArgumentParser();p.add_argument('--library',required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--one',action='store_true');p.add_argument('--newton-budget',action='store_true');p.add_argument('--depth-budget-rate',action='store_true');p.add_argument('--dt',type=float);p.add_argument('--head',type=float,default=-5);p.add_argument('--subdivisions',type=int,default=1);p.add_argument('--elastic-per-cm',type=float,default=1e-7);a=p.parse_args()
 if a.one:return one(a)
 a.output.mkdir(parents=True,exist_ok=True);rows=[]
 for elastic,dts,heads in [(1e-7,[3e-6,1e-4,1e-3],[-5,-5.000001,-5.05]),(0,[3e-6,1e-4],[-5])]:
  for dt in dts:
   for head in heads:
    group=[]
    for n in [1,2,4,16]:
     file=a.output/f'elastic{elastic}_dt{dt}_head{head}_n{n}.json';cmd=[sys.executable,__file__,'--one','--library',a.library,'--dt',str(dt),'--head',str(head),'--subdivisions',str(n),'--elastic-per-cm',str(elastic),'--output',str(file)]
     if a.depth_budget_rate:cmd+=['--depth-budget-rate']
     if a.newton_budget:cmd+=['--newton-budget']
     r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True);file.with_suffix('.log').write_text(r.stdout);assert r.returncode==0,r.stdout
     row=json.loads(file.read_text());group.append(row);rows.append(row)
    fine=group[-1]
    for row in group:
     if row['complete'] and fine['complete']:
      row['head_difference_to_n16_cm']=float(np.max(abs(np.array(row['pressure_cm'])-fine['pressure_cm'])))
      row['water_difference_to_n16']=float(np.max(abs(np.array(row['water_content'])-fine['water_content'])))
      row['exchange_difference_to_n16_cm']=abs(row['stats'][5]-fine['stats'][5])
 summary=dict(status='DIAGNOSTIC_ONLY_NO_TEMPORAL_ADMISSION',rows=rows)
 (a.output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
 print('COMPLETE',sum(r['complete'] for r in rows),'OF',len(rows))
 for r in rows:
  if r['subdivisions']==1:print({k:r.get(k) for k in ['dt_day','head_m','elastic_per_cm','status','head_difference_to_n16_cm']})
if __name__=='__main__':main()
