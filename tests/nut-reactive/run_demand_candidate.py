"""Unused exhausted demand trial: actual production, previous behavior and original WaterN."""
from pathlib import Path
import argparse,base64,hashlib,io,itertools,json,os,subprocess,tarfile,time
import numpy as np
from scipy.integrate import solve_ivp
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args()
OUT=a.output.resolve();OUT.mkdir(parents=True,exist_ok=False);events=[]
sha=lambda b:hashlib.sha256(b).hexdigest()
FC=os.environ.get('FC','gfortran')
def run(cmd,cwd,kind,payload=None):
 t=time.perf_counter();r=subprocess.run(list(map(str,cmd)),cwd=cwd,input=payload,capture_output=True,timeout=120)
 e=dict(category=kind,command=list(map(str,cmd)),seconds=time.perf_counter()-t,returncode=r.returncode)
 for k in ['stdout','stderr']:
  name=f'{len(events):04d}.{k}';(OUT/name).write_bytes(getattr(r,k));e[k]=name
 events.append(e);(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 assert r.returncode==0,(e,r.stderr.decode(),r.stdout.decode())
 return r.stdout
archive=ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
with tarfile.open(fileobj=io.BytesIO(base64.b64decode(archive.read_bytes())),mode='r:gz')as t:original=t.extractfile('SWAP/wofost_soil_watern.f90').read()
assert sha(original)=='b343fa9e485e60d76e2bd49067a20cd5ec328264af5d99d7cf1e4ddf07278722'
paths=['src/process/mod_b111_soil_n_transport.f90','src/process/mod_b111_soil_n_daily_exchange.f90','tests/nut-reactive/test_nondepleting_exchange.f90',str(Path(__file__).relative_to(ROOT))]
cases=[]
for h,K,juvenile,tcsf,nminer,demand in itertools.product([-.03,0.,.03],[0.,.0002],[False,True],[0.,.5],[-.001,0.,.001],[.001,.002]):
 cases.append([.3,1.,.3,.3+h,.002,.001,0.,-.01,0.,tcsf,60.,demand,.5 if juvenile else 1.2,.2 if juvenile else 3.,2.,1300.,K,.04,.03,nminer,.002,.005,.2,.3])
incumbent_count=len(cases)
for h,K,tcsf,nminer,demand,c0 in itertools.product([-.03,0.,.03],[0.,.0002],[.1,.5],[-.001,0.,.001],[.05,.1],[.02,.2]):
 cases.append([.3,1.,.3,.3+h,.002,.001,0.,-.01,0.,tcsf,60.,demand,1.2,3.,2.,1300.,K,.04,.03,nminer,.002,.005,c0,1.5*c0])
# Empty/insufficient NH4, NO3 and demand branches must reject, not partition sinks.
invalid=[]
for slot in [22,23]:
 x=list(cases[0]);x[slot]=0.
 if slot==23:x[17]=0. # Exclude ongoing nitrification supply in the exhaustion witness.
 invalid.append((x,1))
x=list(cases[0]);x[22]=1e-12;x[23]=1e-12;x[7]=-.1;invalid.append((x,1))
for mode in [0,2,3]:invalid.append((list(cases[0]),mode))
x=list(cases[0]);x[7]=.01;invalid.append((x,1))
x=list(cases[0]);x[7]=0.;invalid.append((x,1))
# Default inputs are exercised in current and exact preimage module, byte-exact.
default=[x[:7]+[abs(x[7])]+x[8:]for x in cases]
payload=lambda xs:(''.join(' '.join(format(v,'.17e')for v in x)+' '+str(m)+'\n'for x,m in xs)).encode()
(OUT/'input.json').write_text(json.dumps(dict(cases=cases,invalid=invalid,default=default),indent=2)+'\n')
outputs={};historical={};previous={}
for opt in ['O0','O2']:
 for kind in ['current','original','preimage']:
  b=OUT/(opt+'-'+kind);b.mkdir();objects=[]
  flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b)]
  exchange=(ROOT/paths[1]).read_text()
  if kind=='original':
   fixture=b/'density.f90';fixture.write_text('module MOD_texture_orgmat\n real(8)::bdens(1)=[1300d0]\nend module\nsubroutine swap_error(a,b)\n character(*),intent(in)::a,b\n print *,a,b\n error stop 1\nend subroutine\n')
   raw=b/'original.f90';raw.write_bytes(original)
   at=exchange.index('    if(f%nondepleting_top)then',exchange.index('  subroutine run_transport'))
   end=exchange.index('\n  end subroutine',at)
   exchange=exchange[:at]+'''    r=b111_soil_n_transport_result_t()
    call Wofost_SoilWaterN(f%depth_m,f%dt_day,f%wfrac_t,f%wfrac_t0,f%wflux_out, &
     f%wflux_transp,f%wflux_inbot,f%wflux_intop,f%wflux_inlat,tcsf,ratecon,producpot, &
     r%production_actual,sorpcoef,cseep,ctop,clat,c0,r%concentration_end,r%concentration_average)'''+exchange[end:]
   srcs=[fixture,raw,ROOT/paths[0]]
  else:
   srcs=[ROOT/paths[0]]
   if kind=='preimage':
    base=json.loads((ROOT/'integration/mc-nut01/demand_candidate/STATUS.json').read_text())['baseline']
    exchange=subprocess.check_output(['git','show',base+':'+paths[1]],cwd=ROOT).decode()
    # Driver's optional flag is absent in preimage; delete only those assignments.
  local=b/'exchange.f90';local.write_text(exchange);srcs.append(local)
  driver=(ROOT/paths[2]).read_text()
  # Previous admitted type already includes the explicit mode flag.
  d=b/'driver.f90';d.write_text(driver);srcs.append(d)
  for i,s in enumerate(srcs):
   obj=b/(str(i)+'.o');run([FC,*flags,'-c',s,'-o',obj],b,'compile');objects.append(obj)
  exe=b/'driver';run([FC,*flags,*objects,'-o',exe],b,'link')
  old=run([exe],b,'default',payload([(x,0)for x in default]))
  if kind=='preimage':
   assert old==default_output,'default byte drift'
   previous[opt]=run([exe],b,'previous_native',payload([(x,1)for x in cases]))
   assert previous[opt].splitlines()[:incumbent_count]==outputs[opt].splitlines()[:incumbent_count],'incumbent144 drift'
  if kind=='current':
   default_output=old
   outputs[opt]=run([exe],b,'native',payload([(x,1)for x in cases]))
   bad=run([exe],b,'invalid',payload(invalid));assert all(int(l.split()[0])!=0 for l in bad.splitlines()),bad
  if kind=='original':historical[opt]=run([exe],b,'historical_native',payload([(x,1)for x in cases]))
assert outputs['O0']==outputs['O2'],'current optimization drift'
checks=[]
for index,(x,line,legacy)in enumerate(zip(cases,outputs['O0'].splitlines(),historical['O0'].splitlines())):
 status,*v=map(float,line.split());assert status==0,(index,line)
 dz,dt,w0,wt,qo,qr,qb,qt,ql,tcs,rd,demand,dvs,lai,crit,rho,K,kn,kd,nminer,ctn,ctd,cn,cd=x
 wavg=.5*(w0+wt);h=(wt-w0)/dt;rf=max(1.,rd*.01/dz)
 juvenile=(crit-lai)/crit if dvs<1. and crit>.01 and lai<crit else 0.
 def ode(c0,prod,root,k,sorp,ctop):
  s0=w0+rho*sorp;loss=h+qo/dz+root*qr/dz+k*wavg
  sol=solve_ivp(lambda t,y:[(prod+qt*ctop/dz-loss*y[0])/(s0+h*t),y[0]],[0.,dt],[c0,0.],method='DOP853',rtol=2.3e-14,atol=1e-17,max_step=dt/8)
  assert sol.success;return sol.y[0,-1],sol.y[1,-1]/dt
 def select(c0,prod,sorp,k,ctop,d):
  root=tcs*(wavg+rho*sorp)/wavg*rf
  if juvenile:
   ce,ca=ode(c0,prod-juvenile*d,root*(1.-juvenile),k,sorp,ctop)
   return ce,ca,root*(1.-juvenile)*qr*ca/dz+juvenile*d
  ce1,ca1=ode(c0,prod-d,0.,k,sorp,ctop)
  ce2,ca2=ode(c0,prod,root,k,sorp,ctop)
  return (ce2,ca2,root*qr*ca2/dz)if ce1<ce2 else(ce1,ca1,d)
 en,an,un=select(cn,nminer/dt,K,kn,ctn,demand/dz)
 ed,ad,ud=select(cd,wavg*kn*an,0.,kd,ctd,demand/dz-un)
 actual=np.array(v[:8]);expected=np.array([en,an,ed,ad,un*dz,ud*dz,wavg*kn*an*dz,wavg*kd*ad*dz])
 err=max(abs(actual-expected));assert err<2e-12,(index,err,v,expected)
 old=np.array(list(map(float,legacy.split()[1:9])));original_error=max(abs(actual-old));assert original_error<2e-12,(index,original_error)
 residual=dz*((w0+rho*K)*cn+w0*cd+nminer)-dz*((wt+rho*K)*v[0]+wt*v[2])-v[4]-v[5]-v[7]-v[14]-v[15]+qt*(ctn+ctd)
 assert abs(residual)<1e-12,(index,residual)
 assert v[8:10]==[qt*ctn,qt*ctd]and v[10:12]==[0.,0.]
 checks.append(dict(case=index,ode_error=float(err),original_error=float(original_error),residual=residual))
(OUT/'checks.json').write_text(json.dumps(checks,indent=2)+'\n')
newly_accepted=sum(int(p.split()[0])!=0 and int(n.split()[0])==0 for p,n in zip(previous['O0'].splitlines(),outputs['O0'].splitlines()))
assert newly_accepted==len(cases)-incumbent_count,(newly_accepted,len(cases))
r=dict(status='UNUSED_DEMAND_EXHAUSTION_O0_O2_ODE_AND_ORIGINAL_PASS',newly_accepted=newly_accepted,incumbent_cases=incumbent_count,cases=len(cases),invalid=len(invalid),default_byte_exact=True,max_ode_error=max(c['ode_error']for c in checks),max_original_error=max(c['original_error']for c in checks),max_residual=max(abs(c['residual'])for c in checks),input_sha256={p:sha((ROOT/p).read_bytes())for p in paths},original_sha256=sha(original),compiler=subprocess.check_output([FC,'--version'],text=True).splitlines()[0])
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
