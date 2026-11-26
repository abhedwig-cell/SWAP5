"""Read-only actual operator reconstruction and dtmin cycle diagnosis."""
from pathlib import Path
import json,math,csv
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01';res=json.loads((R/'RESOURCE_PATHS.json').read_text());reports=[]
for opt in ['O0','O2']:
 p=Path(res[opt]['path'])/'OBSERVER06_OWN2TO3/original/coupled_refusal_observer.txt';lines=p.read_text().splitlines();assert len(lines)%9==0;records=[];maxerr=0.
 for i in range(0,len(lines),9):
  h=lines[i].split();v=list(map(float,lines[i+1].split()));m=list(map(float,lines[i+2].split()));b=list(map(float,lines[i+3].split()));dom=[list(map(float,x.split())) for x in lines[i+4:i+9]]
  n=int(h[4]);node=int(h[9]);k=node-1;assert len(v)==5*n and len(m)==131 and len(b)==10
  head=v[:n];theta=v[n:2*n];f=v[2*n:3*n];exc=v[3*n:4*n]
  dt=float(h[2]);storage=(theta[k]-b[3])*b[4]*b[5]/dt;vertical=-b[6]*b[7]+b[8]*b[9]
  reconstructed=math.fsum([storage,b[0],-b[1],b[2],vertical,-exc[k]]);err=abs(reconstructed-f[k]);maxerr=max(maxerr,err)
  qdom=math.fsum(d[0]+d[1]-d[2]-d[3] for d in dom);assert abs(qdom-exc[k])<=1e-12
  records.append(dict(stage=int(h[0]),time=float(h[1]),dt=dt,iteration=int(h[3]),gwl_cell=int(h[5]),gwl=float(h[6]),sumF=float(h[7]),Fmax=float(h[8]),node=node,head=head[k],storage=storage,vertical=vertical,sink=b[0],source=b[1],root=b[2],macro=exc[k],reconstructed=reconstructed,model=f[k],reconstruction_error=err))
 assert maxerr<1e-10
 last=[r for r in records if r['stage']==2 and r['dt']<1.1e-5 and r['iteration']>=50]
 reports.append(dict(opt=opt,operator_records=len(records),max_independent_operator_error=maxerr,last_dtmin_iterations=last))
 with (R/('OBSERVER06_'+opt+'_ITERATIONS.csv')).open('w',newline='') as f:
  w=csv.DictWriter(f,fieldnames=records[0].keys());w.writeheader();w.writerows(records)
assert reports[0]['last_dtmin_iterations']==reports[1]['last_dtmin_iterations']
q=dict(decision='ACTUAL_NODE35_DTMIN_TWO_CYCLE_BACKTRACKING_FACTOR_OMISSION_CANDIDATE',reports=reports,physical_law_change_proven=False,next='Reuse DTMIN57/58 one-expression product contract; no tolerance or step-floor change',whole_day3_qualified=False)
(R/'OBSERVER06_DIAGNOSIS.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(dict(decision=q['decision'],records=reports[0]['operator_records'],max_error=reports[0]['max_independent_operator_error'],last=reports[0]['last_dtmin_iterations'][-2:])))
