"""Independent lower-D1 inventory from retained physical primitives; no model run."""
from pathlib import Path
import json,math,sys
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01';res=json.loads((R/'RESOURCE_PATHS.json').read_text());reports=[]
for opt in ['O0','O2']:
 for label in sys.argv[1:]:
  path=Path(res[opt]['path'])/label/'original/macro_lower1_inventory_terms.txt'
  a=list(map(float,path.read_text().split()));i=count=0;worst=0.;drain=volume=0
  while i<len(a):
   h=a[i:i+18];assert len(h)==18;n=int(h[0]);i+=18
   v=[a[i+k*n:i+(k+1)*n] for k in range(7)];i+=7*n;assert all(len(x)==n for x in v)
   dt=h[2];cell,upper,lower=[int(q)-1 for q in h[4:7]];f,I,O,W,L,V,rho,g0,g1,rapid,depth=h[7:]
   pin,pout,base,u,w,qin,contact=v;assert 0<f<1 and O>0
   isV=L==V and V<=W+128*math.ulp(1.)*max(abs(V),abs(W));volume+=int(isV);drain+=int(not isV and L!=W)
   # Original V-versus-W/drain-floor limit: external rapid loss is fixed raw
   # potential, so it contributes rapid*df, never to the matrix u column.
   for j in range(n):
    g=g0 if j==upper else g1 if j==lower else 0.
    expected=(rho*g if isV else 0.)/dt+rapid*w[j]/dt
    terms=[base[j],qin[cell]/depth*g,math.fsum(u)*w[j],contact[j],-expected]
    err=abs(math.fsum(terms));worst=max(worst,err)
    assert err<=8192*math.ulp(1.)*max(1.,*(abs(x) for x in terms)),(opt,label,count,j,terms)
   count+=1
  assert count and i==len(a)
  reports.append(dict(opt=opt,label=label,systems=count,V=volume,drain_floor=drain,max_inventory_derivative_error=worst))
out=dict(scope='Independent actual D1 lower projection inventory; input surface derivative absent in selected original intervals',models_launched=0,results=reports)
(R/'BLOCK27_LOWER_INVENTORY_ASSESSMENT.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
