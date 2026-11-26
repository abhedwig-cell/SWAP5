"""Independent read-only actual tridiagonal-plus-rank system reconstruction."""
from pathlib import Path
import sys,json,math
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01';res=json.loads((R/'RESOURCE_PATHS.json').read_text())
label=sys.argv[1];report=[]
for opt in ['O0','O2']:
 base=Path(res[opt]['path'])/label/'original'
 for name,rank in [('macro_stock_systems.txt',1),('macro_rank2_systems.txt',2)]:
  p=base/name
  if not p.exists():continue
  tokens=list(map(float,p.read_text().split()));i=0;worst=0.;worst_scaled=0.;systems=0
  while i<len(tokens):
   n=int(tokens[i]);context=tokens[i+1:i+4];i+=4;count=5+2*rank
   v=[tokens[i+k*n:i+(k+1)*n] for k in range(count)];i+=count*n
   assert all(len(a)==n for a in v)
   a,b,c,r=v[:4];u=v[4:4+rank];w=v[4+rank:4+2*rank];x=v[-1]
   dots=[math.fsum(y*z for y,z in zip(wk,x)) for wk in w]
   errors=[]
   for j in range(n):
    terms=[b[j]*x[j],-r[j]]
    if j:terms.append(a[j]*x[j-1])
    if j<n-1:terms.append(c[j]*x[j+1])
    terms.extend(uk[j]*dot for uk,dot in zip(u,dots));errors.append(abs(math.fsum(terms)))
   err=max(errors);scaled=err/(1+max(map(abs,r)));worst=max(worst,err);worst_scaled=max(worst_scaled,scaled);systems+=1
   assert scaled<=5e-12
  assert i==len(tokens)
  report.append(dict(opt=opt,file=name,systems=systems,max_linear_residual=worst,max_scaled_residual=worst_scaled))
assert report
out=dict(label=label,scope='Actual retained corrected linear systems only; no nonlinear convergence, inventory or rollback claim',checks=report,models_launched=0)
(R/(label+'_LINEAR_ASSESSMENT.json')).write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
