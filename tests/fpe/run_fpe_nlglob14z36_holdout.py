import math,time,statistics,json
materials={
'B12':{'theta_r':0.01,'theta_s':0.529749,'alpha':0.016562,'n':1.090671,'ksat':2.245895,'lambda':-4.493581},
'O05':{'theta_r':0.01,'theta_s':0.336701,'alpha':0.030304,'n':2.887502,'ksat':17.418504,'lambda':0.0736},
'O14':{'theta_r':0.01,'theta_s':0.393878,'alpha':0.003288,'n':1.616573,'ksat':2.495984,'lambda':0.514012},
}
cases=[('O05_T13','O05',13),('O05_T12','O05',12),('O14_T13','O14',13),('B12_T13','B12',13)]
dz=10.;dt=6.25e-5;demand=0.01;qbot=0.;dtop=10.;hatm=-2.75e5

def make(m,tail_start):
 def theta(h):
  if h>=0:return m['theta_s']
  mm=1-1/m['n'];hcrit=-1e-2
  if h>hcrit:
   c26=m['theta_r']+(m['theta_s']-m['theta_r'])/((1+abs(m['alpha']*hcrit)**m['n'])**mm)
   c27=(m['theta_s']-c26)/(-hcrit)
   return min(c26+c27*(h-hcrit),m['theta_s'])
  return m['theta_r']+(m['theta_s']-m['theta_r'])/((1+abs(m['alpha']*h)**m['n'])**mm)
 def kval(h):
  th=theta(h); rel=(th-m['theta_r'])/(m['theta_s']-m['theta_r'])
  if rel>1-1e-6:return m['ksat']
  if rel<=0:return 0.
  mm=1-1/m['n'];term=(1-rel**(1/mm))**mm
  return min(m['ksat']*(rel**m['lambda'])*(1-term)**2,m['ksat'])
 def fluxes(h):
  k=[kval(x) for x in h];q=[None]*17
  for j in range(1,16): q[j+1]=-0.5*(k[j-1]+k[j])*((h[j-1]-h[j])/dz+1)
  return q
 def top_flux(h0):
  fixed=kval(h0);katm=kval(hatm);emax=-0.5*(katm+fixed)*((hatm-h0)/dtop+1)
  evap=min(demand,max(0.,emax))
  if evap>=0 and evap>emax:return emax,'atmospheric-head',emax
  return evap,'surface-flux',emax
 def gauss(a,b):
  n=len(b);a=[r[:] for r in a];b=b[:]
  for i in range(n):
   p=max(range(i,n),key=lambda r:abs(a[r][i]))
   if abs(a[p][i])<1e-18:raise ArithmeticError('singular')
   if p!=i:a[i],a[p]=a[p],a[i];b[i],b[p]=b[p],b[i]
   piv=a[i][i]
   for r in range(i+1,n):
    f=a[r][i]/piv
    if f==0:continue
    for c in range(i,n):a[r][c]-=f*a[i][c]
    b[r]-=f*b[i]
  x=[0.]*n
  for i in range(n-1,-1,-1):x[i]=(b[i]-sum(a[i][j]*x[j] for j in range(i+1,n)))/a[i][i]
  return x
 def sat_tail(h,th):
  sat=[h[i]>=0 and th[i]==m['theta_s'] for i in range(16)];first=16
  while first>0 and sat[first-1]:first-=1
  if any(sat[:first]):return None
  return list(range(first+1,17))
 h0=[10.0*((i+1)-tail_start) for i in range(16)];th0=[theta(x) for x in h0]
 assert sat_tail(h0,th0)==list(range(tail_start,17))
 upper_n=tail_start-1
 def solve_full():
  q0=fluxes(h0);qtop0,route0,_=top_flux(h0[0])
  def endpoint(x):
   th1=[theta(v) for v in x];q1=fluxes(x);qtop1,route1,_=top_flux(x[0]);return th1,q1,qtop1,route1
  td0=[]
  for node in range(1,17):
   v=(q0[2]-qtop0)/dz if node==1 else ((qbot-q0[16])/dz if node==16 else (q0[node+1]-q0[node])/dz);td0.append(v)
  h=h0[:]
  for i in range(upper_n):
   eps=max(1e-8,1e-5*max(1,abs(h0[i])));c=(theta(h0[i]+eps)-theta(h0[i]-eps))/(2*eps)
   if c>1e-14:h[i]+=dt*td0[i]/c
  iface=upper_n+1
  def residual(x):
   th1,q1,qtop1,route1=endpoint(x);td1=[]
   for node in range(1,17):
    v=(q1[2]-qtop1)/dz if node==1 else ((qbot-q1[16])/dz if node==16 else (q1[node+1]-q1[node])/dz);td1.append(v)
   r=[0.]*16
   for i in range(upper_n):r[i]=th1[i]-th0[i]-.5*dt*(td0[i]+td1[i])
   qbar=.5*(q0[iface]+q1[iface]);j=upper_n
   r[j]=th1[j]-th0[j]-dt*((q1[j+2]-qbar)/dz)
   for i in range(j+1,15):r[i]=th1[i]-th0[i]-dt*((q1[i+2]-q1[i+1])/dz)
   r[15]=th1[15]-th0[15]-dt*((qbot-q1[16])/dz)
   return r,th1,q1,qtop1,route1
  best=None
  for it in range(1,31):
   r,th1,q1,qtop1,route1=residual(h);norm=max(abs(v) for v in r);best=(h[:],th1,q1,qtop0,qtop1,route0,route1,it,norm)
   if norm<=1e-10:return best,True
   jac=[[0.]*16 for _ in range(16)]
   for j in range(16):
    eps=max(1e-7,1e-6*max(1,abs(h[j])));hp=h[:];hp[j]+=eps;rp=residual(hp)[0]
    for i in range(16):jac[i][j]=(rp[i]-r[i])/eps
   dx=gauss(jac,[-v for v in r]);base=norm;acc=False
   for bt in range(12):
    fac=.5**bt;trial=[h[i]+fac*dx[i] for i in range(16)]
    if not all(math.isfinite(v) and abs(v)<1e12 for v in trial):continue
    if max(abs(v) for v in residual(trial)[0])<base:h=trial;acc=True;break
   if not acc:break
  return best,False
 def solve_red():
  n=tail_start;q0=fluxes(h0);qtop0,route0,_=top_flux(h0[0])
  def reconstruct(x):
   h=x[:]+[0.]*(16-n);kg=kval(h[n-1]);km=.5*(kg+m['ksat']);h[n]=h[n-1]+dz*(1+qbot/km)
   for i in range(n+1,16):h[i]=h[i-1]+dz*(1+qbot/m['ksat'])
   return h
  def endpoint(x):
   hf=reconstruct(x);th1=[theta(v) for v in hf];q1=fluxes(hf);qtop1,route1,_=top_flux(hf[0]);return hf,th1,q1,qtop1,route1
  td0=[]
  for node in range(1,17):
   v=(q0[2]-qtop0)/dz if node==1 else ((qbot-q0[16])/dz if node==16 else (q0[node+1]-q0[node])/dz);td0.append(v)
  x=h0[:n]
  for i in range(n-1):
   eps=max(1e-8,1e-5*max(1,abs(h0[i])));c=(theta(h0[i]+eps)-theta(h0[i]-eps))/(2*eps)
   if c>1e-14:x[i]+=dt*td0[i]/c
  iface=n
  def residual(xv):
   hf,th1,q1,qtop1,route1=endpoint(xv);td1=[]
   for node in range(1,17):
    v=(q1[2]-qtop1)/dz if node==1 else ((qbot-q1[16])/dz if node==16 else (q1[node+1]-q1[node])/dz);td1.append(v)
   r=[0.]*n
   for i in range(n-1):r[i]=th1[i]-th0[i]-.5*dt*(td0[i]+td1[i])
   qbar=.5*(q0[iface]+q1[iface]);r[n-1]=th1[n-1]-th0[n-1]-dt*((qbot-qbar)/dz)
   return r,hf,th1,q1,qtop1,route1
  best=None
  for it in range(1,31):
   r,hf,th1,q1,qtop1,route1=residual(x);norm=max(abs(v) for v in r);best=(hf,th1,q1,qtop0,qtop1,route0,route1,it,norm,n)
   if norm<=1e-10:return best,True
   jac=[[0.]*n for _ in range(n)]
   for j in range(n):
    eps=max(1e-7,1e-6*max(1,abs(x[j])));xp=x[:];xp[j]+=eps;rp=residual(xp)[0]
    for i in range(n):jac[i][j]=(rp[i]-r[i])/eps
   dx=gauss(jac,[-v for v in r]);base=norm;acc=False
   for bt in range(12):
    fac=.5**bt;trial=[x[i]+fac*dx[i] for i in range(n)]
    if not all(math.isfinite(v) and abs(v)<1e12 for v in trial):continue
    if max(abs(v) for v in residual(trial)[0])<base:x=trial;acc=True;break
   if not acc:break
  return best,False
 return h0,th0,sat_tail,solve_full,solve_red

outs=[]
for cid,mid,ts in cases:
 m=materials[mid];h0,th0,sat_tail,fullfn,redfn=make(m,ts)
 full,fok=fullfn();red,rok=redfn()
 if not (fok and rok and full and red):
  outs.append({'case':cid,'converged':False});continue
 fh,fth,fq,fqt0,fqt1,fr0,fr1,fit,fn=full
 rh,rth,rq,rqt0,rqt1,rr0,rr1,rit,rn,n=red
 fl=sum((fth[i]-th0[i])*dz for i in range(16))+.5*dt*(fqt0+fqt1)
 rl=sum((rth[i]-th0[i])*dz for i in range(16))+.5*dt*(rqt0+rqt1)
 hd=max(abs(a-b) for a,b in zip(fh,rh));td=max(abs(a-b) for a,b in zip(fth,rth));top=abs(fqt1-rqt1);ld=abs(fl-rl)
 tailok=sat_tail(fh,fth)==sat_tail(rh,rth);routeok=(fr0,fr1)==(rr0,rr1)
 wr=rit*n/(fit*16.)
 ft=[];rt=[]
 for rep in range(200):
  t=time.perf_counter_ns(); fullfn(); ft.append(time.perf_counter_ns()-t)
  t=time.perf_counter_ns(); redfn(); rt.append(time.perf_counter_ns()-t)
 fmed=statistics.median(ft[20:]);rmed=statistics.median(rt[20:])
 outs.append({'case':cid,'material':mid,'tail_start':ts,'active_n':n,'converged':True,'max_h_diff':hd,'max_theta_diff':td,'top_flux_diff':top,'ledger_diff':ld,'tail_equal':tailok,'route_equal':routeok,'full_it':fit,'red_it':rit,'work_ratio':wr,'full_time_ns_median':fmed,'red_time_ns_median':rmed,'timing_ratio':rmed/fmed})
print(json.dumps(outs,indent=2))
