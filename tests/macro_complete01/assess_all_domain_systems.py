"""Independent actual all-domain Woodbury and constrained exchange inventory."""
from pathlib import Path
import sys,json,math
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01'
res=json.loads((R/'RESOURCE_PATHS.json').read_text());label=sys.argv[1];reports=[]
for opt in ['O0','O2']:
 b=Path(res[opt]['path'])/label/'original';s=list(map(float,(b/'macro_saturated_all_systems.txt').read_text().split()));p=list(map(float,(b/'macro_saturated_all_mass_base.txt').read_text().split()))
 si=pi=count=0;worst=linear=0.;domains={};surface=0;branches={}
 while si<len(s):
  n,nr=map(int,s[si:si+2]);ctx=s[si+2:si+5];si+=5
  assert p[pi:pi+5]==[n,nr,*ctx];pi+=5;dt=ctx[1];m=p[pi:pi+6];pi+=6
  v=[s[si+k*n:si+(k+1)*n] for k in range(5+2*nr)];si+=(5+2*nr)*n
  a,bv,c,r=v[:4];u=v[4:4+nr];w=v[4+nr:4+2*nr];x=v[-1]
  dots=[math.fsum(q*z for q,z in zip(wk,x)) for wk in w]
  for j in range(n):
   terms=[bv[j]*x[j],-r[j]]
   if j:terms.append(a[j]*x[j-1])
   if j+1<n:terms.append(c[j]*x[j+1])
   terms.extend(uk[j]*d for uk,d in zip(u,dots));err=abs(math.fsum(terms));linear=max(linear,err)
   assert err/(1+max(map(abs,r)))<=5e-12
  cell=int(m[0])-1;upper=cell-1;den=m[2]-m[1];g0=(m[3]-m[4])*m[2]/den**2;g1=-(m[3]-m[4])*m[1]/den**2
  for k in range(nr):
   f,rho,vbranch,qin,dlat=p[pi:pi+5];pi+=5;loc=p[pi:pi+n];pi+=n
   if not 0<f<1:continue
   domains[k+2]=domains.get(k+2,0)+1;branch='V' if vbranch==1 else 'W';branches[branch]=branches.get(branch,0)+1
   if dlat!=0:surface+=1
   su=math.fsum(u[k]);cg=qin/m[5]
   for j in range(n):
    g=g0 if j==upper else g1 if j==cell else 0.
    expected=(rho*g if vbranch==1 else 0.)/dt-(dlat/dt if j==0 else 0.)
    terms=[loc[j],cg*g,su*w[k][j],-expected];err=abs(math.fsum(terms));worst=max(worst,err)
    assert err<=4096*math.ulp(1.)*max(1.,*(abs(q) for q in terms)),(opt,count,k,j,terms,err)
  count+=1
 assert count and pi==len(p) and si==len(s) and domains
 reports.append(dict(opt=opt,systems=count,partial_domain_counts=domains,branches=branches,active_surface_derivatives=surface,max_linear_residual=linear,max_inventory_derivative_error=worst))
out=dict(label=label,scope='Actual retained all-domain linear and constrained exchange derivative inventory only; no full nonlinear or period claim',results=reports,models_launched=0)
(R/(label+'_ALL_DOMAIN_ASSESSMENT.json')).write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
