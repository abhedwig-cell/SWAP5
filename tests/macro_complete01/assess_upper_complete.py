"""Independent D1 upper-projection column inventory from actual retained terms."""
from pathlib import Path
import json,math
R=Path('integration/macro-complete01');res=json.loads((R/'RESOURCE_PATHS.json').read_text());results=[]
for opt in ['O0','O2']:
 for label in ['UPPERCOMPLETE_V21_CONTEXT12TO13','UPPERCOMPLETE_V21_OWN13TO14']:
  p=Path(res[opt]['path'])/label/'original/macro_upper1_complete_inventory_terms.txt';a=list(map(float,p.read_text().split()));i=count=0;worst=0.
  while i<len(a):
   if len(a)-i<16:break
   h=a[i:i+16];n=int(h[0]);size=16+6*n
   if len(a)-i<size:break
   i+=16;v=[a[i+k*n:i+(k+1)*n] for k in range(6)];i+=6*n;dt=h[2];cell,upper,lower=[int(q)-1 for q in h[4:7]];f,I,O,W,M,rho,g0,g1,depth=h[7:]
   assert 0<f<1 and I>0 and M>0
   pin,base,u,w,qin,contact=v;su=math.fsum(u)
   for j in range(n):
    g=g0 if j==upper else g1 if j==lower else 0.;expected=rho*g/dt
    terms=[base[j],qin[cell]/depth*g,su*w[j],contact[j],-expected];err=abs(math.fsum(terms));worst=max(worst,err)
    assert err<=8192*math.ulp(1.)*max(1.,*(abs(q) for q in terms)),(opt,count,j,terms,err)
   count+=1
  assert count>0
  run=json.loads((p.parent.parent/'RESULT.json').read_text());assert run['status'] in ['COMPATIBLE_JACOBIAN_CONTEXT_WINDOW_COMPLETE','OWN_RESTART_WINDOW_COMPLETE']
  progress=max(float(l.split()[0]) for name in ['jac37_trace.txt','macro_complete_trace.txt'] if (p.parent/name).exists() for l in (p.parent/name).read_text().splitlines() if len(l.split())>3);assert progress>35807.612560747817
  results.append(dict(opt=opt,label=label,last_observed_model_time=progress,complete_retained_terms=count,censored_tail_tokens=len(a)-i,max_D1_upper_inventory_derivative_error=worst,old_refusal_time=35807.612560747817,trace_progress_beyond_old_refusal=True,whole_requested_day_pass=True))
out=dict(scope='Actual D1 full upper-inventory derivative including outgoing Darcy/contact and fixedrapidout; context13 and actualtarget-own14days complete, inheritedprefix not fixedtarget own qualification',results=results,models_launched=0)
(R/'BLOCK21_UPPER_COMPLETE_ASSESSMENT.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
