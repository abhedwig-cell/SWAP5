"""Read-only independent constrained saturated exchange column inventory."""
from pathlib import Path
import sys,json,math
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01'
res=json.loads((R/'RESOURCE_PATHS.json').read_text());label=sys.argv[1];reports=[]
for opt in ['O0','O2']:
 base=Path(res[opt]['path'])/label/'original'
 s=list(map(float,(base/'macro_rank2_systems.txt').read_text().split()))
 p=list(map(float,(base/'macro_saturated_mass_base.txt').read_text().split()))
 si=pi=count=partial=0;worst=0.;branches={}
 while si<len(s):
  n=int(s[si]);ctx=s[si+1:si+4];si+=4
  assert int(p[pi])==n and p[pi+1:pi+4]==ctx;pi+=4
  dt=ctx[1];m=p[pi:pi+24];pi+=24
  local=[p[pi+k*n:pi+(k+1)*n] for k in range(2)];pi+=2*n
  v=[s[si+k*n:si+(k+1)*n] for k in range(9)];si+=9*n
  u=v[4:6];w=v[6:8];cell=int(m[0])-1;upper=cell-1
  den=m[2]-m[1];g0=(m[3]-m[4])*m[2]/den**2;g1=-(m[3]-m[4])*m[1]/den**2
  for k in range(2):
   f=m[6+k]
   if not 0<f<1:continue
   partial+=1;branch='V' if m[10+k]==1 else 'W';branches[branch]=branches.get(branch,0)+1
   su=math.fsum(u[k]);cg=m[12+k]/m[5];rho=m[8+k] if branch=='V' else 0.
   for j in range(n):
    geometry=cg*(g0 if j==upper else g1 if j==cell else 0.)
    expected=rho/dt*(g0 if j==upper else g1 if j==cell else 0.)
    terms=[local[k][j],geometry,su*w[k][j],-expected]
    err=abs(math.fsum(terms));worst=max(worst,err)
    assert err<=4096*math.ulp(1.)*max(1.,*(abs(x) for x in terms)),(opt,count,k,j,terms,err)
  count+=1
 assert si==len(s) and pi==len(p) and count and partial
 reports.append(dict(opt=opt,systems=count,partial_domain_constraints=partial,branches=branches,max_column_inventory_derivative_error=worst))
out=dict(label=label,scope='Actual retained partial D2/D3 saturated exchange derivative inventory; no nonlinear or full-period qualification',results=reports,models_launched=0)
(R/(label+'_SATURATED_MASS_ASSESSMENT.json')).write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
