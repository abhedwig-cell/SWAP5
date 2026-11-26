"""Independent actual linear and D3 column-sum derivative checks."""
from pathlib import Path
import sys,json,math
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01';res=json.loads((R/'RESOURCE_PATHS.json').read_text());label=sys.argv[1];out=[]
for opt in ['O0','O2']:
 d=Path(res[opt]['path'])/label/'original';tr=[list(map(float,l.split())) for l in (d/'macro_complete_trace.txt').read_text().splitlines()];active=[]
 for row in tr:
  mcount=len(row)-6
  if row[3+mcount]==1:active.append((row[:3],row[3:3+mcount]))
 path=d/'macro_complete_systems.txt'
 if not path.exists():out.append(dict(opt=opt,active=0));continue
 values=list(map(float,path.read_text().split()));pos=0;idx=0;masspos=0;massvals=list(map(float,(d/'macro_complete_mass_base.txt').read_text().split())) if (d/'macro_complete_mass_base.txt').exists() else []; worst=0.;massworst=0.;local=0;branches={}
 while pos<len(values):
  n=int(values[pos]);time,dt,it=values[pos+1:pos+4];pos+=4;v=[values[pos+k*n:pos+(k+1)*n] for k in range(9)];pos+=9*n
  a,b,c,r,u1,u2,v1,v2,x=v;header,m=active[idx];assert header==[time,dt,it];idx+=1
  dot1=math.fsum(p*q for p,q in zip(v1,x));dot2=math.fsum(p*q for p,q in zip(v2,x));error=[]
  for j in range(n):
   terms=[b[j]*x[j],-r[j],u1[j]*dot1,u2[j]*dot2]
   if j:terms.append(a[j]*x[j-1])
   if j<n-1:terms.append(c[j]*x[j+1])
   error.append(abs(math.fsum(terms)))
  worst=max(worst,max(error));assert max(error)/(1+max(map(abs,r)))<=5e-12
  base=[0.]*n;f=m[3];cell=int(m[44]) if len(m)>=48 else 50
  if massvals:
   assert massvals[masspos:masspos+4]==[n,time,dt,it];masspos+=4;base=massvals[masspos:masspos+n];masspos+=n
  else:
   for j,cd in zip(range(50,57),m[30:37]):base[j]=f*cd
   base[49]=m[29]
  local+=int(m[29]>0)
  h0,h1,z0,z1,rho=m[24:29];g0=(z0-z1)*h1/(h1-h0)**2;g1=-(z0-z1)*h0/(h1-h0)**2
  expected=[0.]*n
  if m[2]==2:expected[cell-1]=rho*g0/dt;expected[cell]=rho*g1/dt
  su1=math.fsum(u1);su2=math.fsum(u2);col=[math.fsum([p,su1*q,su2*z]) for p,q,z in zip(base,v1,v2)]
  err=max(abs(p-q) for p,q in zip(col,expected));massworst=max(massworst,err);scale=max(1.,max(map(abs,expected)),max(map(abs,col)))
  assert err<=4096*math.ulp(1.)*scale
  branches[str(int(m[2]))]=branches.get(str(int(m[2])),0)+1
 out.append(dict(opt=opt,active=len(active),retained_systems=idx,branch_counts=branches,active_existing_U_diagonal=local,max_independent_linear_residual=worst,max_D3_column_sum_derivative_error=massworst))
q=dict(label=label,scope='Actual corrected linear systems and independent D3 derivative inventory; does not alone qualify nonlinear convergence or a native period',results=out,models_launched=0)
(R/(label+'_COMPLETE_ASSESSMENT.json')).write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q))
