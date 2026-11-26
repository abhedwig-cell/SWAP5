"""Actual dtmin product-update and remaining native classification diagnosis."""
from pathlib import Path
import json,math,csv
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01';res=json.loads((R/'RESOURCE_PATHS.json').read_text());out=[]
for opt in ['O0','O2']:
 b=Path(res[opt]['path']);lines=(b/'OBSERVER07_OWN2TO3/original/coupled_refusal_observer.txt').read_text().splitlines();assert len(lines)%9==0
 trials=[];maxerr=0.;extended=0
 for i in range(0,len(lines),9):
  hd=lines[i].split();n=int(hd[4]);v=list(map(float,lines[i+1].split()));assert len(v)==7*n
  if hd[0]!='3':continue
  factor=float(hd[14]);cap=float(hd[15]);h=v[:n];hold=v[5*n:6*n];dh=v[6*n:7*n]
  err=max(abs(x-(a-(d*cap)*factor)) for x,a,d in zip(h,hold,dh));maxerr=max(maxerr,err)
  if int(hd[3])>30 and float(hd[2])<1.1e-5:extended+=1
  trials.append(dict(time=float(hd[1]),dt=float(hd[2]),iteration=int(hd[3]),trial=int(hd[13]),factor=factor,cap=cap,Fmax=float(hd[8]),GWL=float(hd[6]),formula_error=err))
 assert maxerr<1e-12 and extended>0
 geom=(b/'OBSERVER08_OWN2TO3/original/coupled_refusal_observer.txt').read_bytes();other=(Path(res['O2' if opt=='O0' else 'O0']['path'])/'OBSERVER08_OWN2TO3/original/coupled_refusal_observer.txt').read_bytes();assert geom==other
 q=json.loads((b/'DTMIN_V6_OWN2TO3/RESULT.json').read_text());assert q['status']=='FAILED' and not q['rows']
 out.append(dict(opt=opt,total_actual_line_trials=len(trials),extended_dtmin_line_trials=extended,max_update_formula_error_cm=maxerr,remaining_refusal='35797.505000000005',native_seconds=q['elapsed_seconds']))
 with (R/('OBSERVER07_'+opt+'_LINE_TRIALS.csv')).open('w',newline='') as f:w=csv.DictWriter(f,fieldnames=trials[0]);w.writeheader();w.writerows(trials)
q=dict(decision='DTMIN58_PRODUCT_ACTUALLY_CORRECT_BUT_NOT_SUFFICIENT',results=out,next_cause='Native CALCGWL includes a positive MAIN groundwater centre as a perched bottom; old recognition jumps24..28 to24..47 acrossh47=0 while real gapair~0.0302cm remains below original0.1 criterion. Primary manual requires independent gap>=critical.',scientific_next='Qualify corrected classification with real CALCGWL frozen contexts before any full-window postimage; main GWL and CRIT unchanged',full_day3_pass=False)
(R/'BLOCK05_RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q))
