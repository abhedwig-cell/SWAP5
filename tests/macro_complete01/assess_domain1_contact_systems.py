"""Independent actual constrained-domain plus contact-row inventory."""
from pathlib import Path
import json,sys,math
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01';res=json.loads((R/'RESOURCE_PATHS.json').read_text());label=sys.argv[1];reports=[]
for opt in ['O0','O2']:
 b=Path(res[opt]['path'])/label/'original';s=list(map(float,(b/'macro_saturated_contact_systems.txt').read_text().split()));p=list(map(float,(b/'macro_saturated_contact_mass_base.txt').read_text().split()))
 si=pi=count=neg=0;worst=linear=0.;domains={};surface=0;contacts=0;branches={}
 while si<len(s):
  n,nr=map(int,s[si:si+2]);ctx=s[si+2:si+5];si+=5;assert p[pi:pi+5]==[n,nr,*ctx];pi+=5;dt=ctx[1];m=p[pi:pi+10];pi+=10
  v=[s[si+k*n:si+(k+1)*n] for k in range(5+2*nr)];si+=(5+2*nr)*n
  a,bv,c,r=v[:4];u=v[4:4+nr];w=v[4+nr:4+2*nr];x=v[-1];dots=[math.fsum(q*z for q,z in zip(wk,x)) for wk in w]
  for j in range(n):
   terms=[bv[j]*x[j],-r[j]]
   if j:terms.append(a[j]*x[j-1])
   if j+1<n:terms.append(c[j]*x[j+1])
   terms.extend(uk[j]*d for uk,d in zip(u,dots));err=abs(math.fsum(terms));linear=max(linear,err);assert err/(1+max(map(abs,r)))<=5e-12
  cell,upper,lower=[int(q)-1 for q in m[:3]];den=m[4]-m[3];g0=(m[5]-m[6])*m[4]/den**2;g1=-(m[5]-m[6])*m[3]/den**2
  neg+=int(upper==cell);contact0=[m[8]];contact1=[m[9]]
  for k in range(1,nr-1):
   f,rho,vbranch,qin,dlat,ct0,ct1=p[pi:pi+7];pi+=7;loc=p[pi:pi+n];pi+=n;contact0.append(ct0);contact1.append(ct1)
   contacts+=int(ct0!=0 or ct1!=0)
   if not 0<f<1:continue
   domains[k+1]=domains.get(k+1,0)+1;branch='V' if vbranch==1 else 'W';branches[branch]=branches.get(branch,0)+1;surface+=int(dlat!=0);su=math.fsum(u[k]);cg=qin/m[7]
   for j in range(n):
    g=g0 if j==upper else g1 if j==lower else 0.;ct=ct0 if j==upper else ct1 if j==lower else 0.
    expected=(rho*g if vbranch==1 else 0.)/dt-(dlat/dt if j==0 else 0.)
    terms=[loc[j],cg*g,su*w[k][j],ct,-expected];err=abs(math.fsum(terms));worst=max(worst,err)
    assert err<=8192*math.ulp(1.)*max(1.,*(abs(q) for q in terms)),(opt,count,k,j,terms,err)
  for j in range(n):
   expected=math.fsum(contact0) if j==upper else math.fsum(contact1) if j==lower else 0.
   assert abs(w[-1][j]-expected)<=1024*math.ulp(1.)*max(1.,abs(expected))
  count+=1
 assert count and pi==len(p) and si==len(s)
 reports.append(dict(opt=opt,systems=count,negative_contact_cell_systems=neg,active_contact_domain_rows=contacts,partial_domain_counts=domains,branches=branches,active_surface_derivatives=surface,max_linear_residual=linear,max_inventory_derivative_error=worst))
out=dict(label=label,scope='Actual retained constrained-domain plus contact-row linear systems and inventory derivative only; no independent contact-law finite-difference or full-period claim',results=reports,models_launched=0)
(R/(label+'_DOMAIN1_CONTACT_SYSTEMS_ASSESSMENT.json')).write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
