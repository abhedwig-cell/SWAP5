"""Sole constant crop sink: real production versus an independent zero event."""
from pathlib import Path
import argparse,base64,hashlib,io,itertools,json,os,subprocess,tarfile,time
import numpy as np
from scipy.integrate import solve_ivp
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();OUT=a.output.resolve();OUT.mkdir()
FC=os.environ.get('FC','gfortran');events=[];sha=lambda b:hashlib.sha256(b).hexdigest()
paths=['src/process/mod_b111_soil_n_transport.f90','src/process/mod_b111_soil_n_daily_exchange.f90','tests/nut-reactive/test_crop_depletion.f90',str(Path(__file__).relative_to(ROOT))]
BASE=json.loads((ROOT/'integration/mc-nut01/crop_only_depletion/STATUS.json').read_text())['baseline']
with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/'integration/mc-nut01/empty_equilibrium/EVIDENCE.tar.xz.b64').read_bytes())))as t:
 previous=json.load(t.extractfile('direct/input.json'));common=[x+[0.,0.,0.,0.]for x in previous['common']+previous['cases']]
cases=[]
for form,h,K,tcs,seed,miner,loading,demand in itertools.product([0,1,2],[-.03,0.,.03],[0.,.0002],[0.,.5],[0.,1e-4],[0.,.002],[False,True],[.05,.1]):
 x=[.3,1.,.3,.3+h,.002,.001,.001 if loading else 0.,-.01,.001 if loading else 0.,tcs,60.,demand,.5,.2,2.,1300.,K,.04,.03,miner,0.,0.,1. if form==1 else seed,1. if form==0 else 1.5*seed,.01,.02,.02,.01]
 cases.append(x)
invalid=[]
for slot,value in [(20,.002),(19,-.002)]:
 x=list(cases[0]);x[slot]=value;invalid.append((x,1))
x=next(list(x)for x in cases if x[22]==1. and x[23]==0.);x[21]=.005;invalid.append((x,1))
for mode in [2,3]:invalid.append((list(cases[0]),mode))
x=list(cases[0]);x[7]=0.;invalid.append((x,1))
default=[x[:7]+[abs(x[7])]+x[8:]for x in common]
(OUT/'input.json').write_text(json.dumps(dict(cases=cases,common=common,default=default,invalid=invalid),indent=2)+'\n')
payload=lambda rows:(''.join(' '.join(format(v,'.17e')for v in x)+' '+str(m)+'\n'for x,m in rows)).encode()
def run(cmd,b,kind,data=None):
 t=time.perf_counter();r=subprocess.run(list(map(str,cmd)),cwd=b,input=data,capture_output=True,timeout=120);e=dict(command=list(map(str,cmd)),category=kind,seconds=time.perf_counter()-t,returncode=r.returncode)
 for k in ['stdout','stderr']:
  name=f'{len(events):04d}.{k}';(OUT/name).write_bytes(getattr(r,k));e[k]=name
 events.append(e);(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n');assert r.returncode==0,(e,r.stdout.decode(),r.stderr.decode());return r.stdout
with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64').read_bytes())))as t:original=t.extractfile('SWAP/wofost_soil_watern.f90').read()
assert sha(original)=='b343fa9e485e60d76e2bd49067a20cd5ec328264af5d99d7cf1e4ddf07278722'
outputs={};legacy={};corrected={};incumbent={};defaults={}
B1='reference/swap-4.3.1/patches/SWAP-020/negative_boundary.f90'
assert(ROOT/B1).read_bytes()==subprocess.check_output(['git','show',BASE+':'+B1],cwd=ROOT)
for opt in ['O0','O2']:
 for kind in ['corrected','current','previous','original']:
  b=OUT/(opt+'-'+kind);b.mkdir();flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b)];objects=[]
  exchange=(ROOT/paths[1]).read_text();srcs=[]
  if kind=='previous':exchange=subprocess.check_output(['git','show',BASE+':'+paths[1]],cwd=ROOT).decode()
  if kind in ['original','corrected']:
   (b/'fixture.f90').write_text('module MOD_texture_orgmat\n real(8)::bdens(1)=[1300d0]\nend module\nsubroutine swap_error(a,b)\n character(*)::a,b\n error stop 1\nend subroutine\n');(b/'original.f90').write_bytes(original);srcs=[b/'fixture.f90',b/'original.f90']
   if kind=='corrected':
    srcs.append(ROOT/B1)
    begin=exchange.index('      call evaluate_b111_soil_n_negative_boundary',exchange.index('  subroutine run_transport'));finish=exchange.index('\n      if(r%status',begin)
    exchange=exchange[:begin]+'''      call Wofost_SoilWaterN_Negative(f%depth_m,f%dt_day,f%wfrac_t,f%wfrac_t0, &
      f%wflux_out+tcsf*f%wflux_transp,0d0,f%wflux_inbot,f%wflux_intop,f%wflux_inlat, &
      0d0,ratecon,max(0d0,producpot),sorpcoef,cseep, &
      ctop+min(0d0,producpot)*f%depth_m/f%wflux_intop,clat,c0, &
      r%concentration_end,r%concentration_average,r%top_actual_rate,r%top_unmet,r%depletion_time,r%status)'''+exchange[finish:]
   else:
    at=exchange.index('    if(f%nondepleting_top)then',exchange.index('  subroutine run_transport'));end=exchange.index('\n  end subroutine',at)
    exchange=exchange[:at]+'''    r=b111_soil_n_transport_result_t()
    call Wofost_SoilWaterN(f%depth_m,f%dt_day,f%wfrac_t,f%wfrac_t0,f%wflux_out, &
      f%wflux_transp,f%wflux_inbot,f%wflux_intop,f%wflux_inlat,tcsf,ratecon,producpot, &
      r%production_actual,sorpcoef,cseep,ctop,clat,c0,r%concentration_end,r%concentration_average)'''+exchange[end:]
  (b/'exchange.f90').write_text(exchange);srcs +=[ROOT/paths[0],b/'exchange.f90',ROOT/paths[2]]
  for i,src in enumerate(srcs):
   obj=b/(str(i)+'.o');run([FC,*flags,'-c',src,'-o',obj],b,'compile');objects.append(obj)
  exe=b/'driver';run([FC,*flags,*objects,'-o',exe],b,'link')
  z=run([exe],b,'new_'+kind,payload([(x,1)for x in cases]))
  if kind=='original':legacy[opt]=z;continue
  if kind=='corrected':corrected[opt]=z;continue
  c=run([exe],b,'common_'+kind,payload([(x,1)for x in common]));d=run([exe],b,'default_'+kind,payload([(x,0)for x in default]))
  if kind=='current':
   outputs[opt]=z;incumbent[opt]=c;defaults[opt]=d;bad=run([exe],b,'invalid',payload(invalid));assert all(int(l.split()[0])!=0 for l in bad.splitlines())
  else:
   assert c==incumbent[opt]and d==defaults[opt],'incumbent byte drift'
   assert all(int(l.split()[0])!=0 for l in z.splitlines()),'previous production accepted depletion'
assert outputs['O0']==outputs['O2']and incumbent['O0']==incumbent['O2']
checks=[]
for index,(x,line,oldline,b1line)in enumerate(zip(cases,outputs['O0'].splitlines(),legacy['O0'].splitlines(),corrected['O0'].splitlines())):
 code,*v=map(float,line.split());assert code==0,(index,line)
 dz,dt,w0,wt,qo,qr,qb,qt,ql,tcs,rd,D,dvs,lai,crit,rho,K,kn,kd,R,ctn,ctd,cn,cd=x[:24];ln,ld,bn,bd=x[24:]
 h=(wt-w0)/dt;wavg=.5*(w0+wt);rf=max(1.,rd*.01/dz);j=(crit-lai)/crit
 def ode(c0,P,root,k,sorp,bound):
  load=(qb*bound[1]+ql*bound[0])/dz
  if c0==0. and P+load<0.:return 0.,0.,-load,0.
  def rhs(t,y):return [(P+load-(h+qo/dz+root*qr/dz+k*wavg)*y[0])/(w0+rho*sorp+h*t),y[0]]
  def zero(t,y):return y[0]
  zero.terminal=True;zero.direction=-1
  sol=solve_ivp(rhs,[0.,dt],[c0,0.],events=zero,method='DOP853',rtol=2.3e-14,atol=1e-17,max_step=dt/16);assert sol.success
  tau=float(sol.t[-1]);depleted=bool(len(sol.t_events[0]));ce=0. if depleted else float(sol.y[0,-1]);ca=float(sol.y[1,-1])/dt
  return ce,ca,P*tau/dt-load*(dt-tau)/dt,tau
 rn=tcs*(wavg+rho*K)/wavg*(1.-j)*rf;rdn=tcs*(1.-j)*rf
 en,an,pn,tn=ode(cn,R/dt-j*D/dz,rn,kn,K,(ln,bn));un=rn*qr*an/dz+R/dt-pn
 nit=wavg*kn*an;ed,ad,pd,td=ode(cd,nit-j*(D/dz-un),rdn,kd,0.,(ld,bd));ud=rdn*qr*ad/dz+nit-pd
 expected=[en,an,ed,ad,un*dz,ud*dz,nit*dz,wavg*kd*ad*dz];err=max(abs(np.array(v[:8])-expected));assert err<2e-12,(index,err,v,expected)
 assert tn<dt or td<dt,'no selected depletion exercised'
 assert min(v[:8])>=0. and v[8:12]==[0.,0.,0.,0.]
 residual=dz*((w0+rho*K)*cn+w0*cd+R)-dz*((wt+rho*K)*v[0]+wt*v[2])-v[4]-v[5]-v[7]-v[14]-v[15]+qb*(bn+bd)+ql*(ln+ld)
 assert abs(residual)<1e-12,(index,residual)
 bc,*bv=map(float,b1line.split());b1_error=max(abs(np.array(v)-bv));assert bc==0 and b1_error<2e-12,(index,b1_error,bc)
 oc,*ov=map(float,oldline.split());legacy_error=max(abs(np.array(v[:8])-ov[:8]));legacy_residual=None
 if oc==0:
  legacy_residual=dz*((w0+rho*K)*cn+w0*cd+R)-dz*((wt+rho*K)*ov[0]+wt*ov[2])-ov[4]-ov[5]-ov[7]-ov[14]-ov[15]+qb*(bn+bd)+ql*(ln+ld)
 if h==0. and qb==ql==0. and min(cn,cd)>0.:assert oc==0 and legacy_error<3e-12,(index,legacy_error,oc)
 checks.append(dict(case=index,ode_error=float(err),corrected_reference_error=float(b1_error),residual=residual,nh4_depletion_time=tn,no3_depletion_time=td,legacy_status=oc,legacy_error=float(legacy_error),legacy_residual=legacy_residual))
(OUT/'checks.json').write_text(json.dumps(checks,indent=2)+'\n')
r=dict(status='CROP_ONLY_DEPLETION_O0_O2_EVENT_ODE_PASS',cases=len(cases),incumbent_cases=len(common),default_byte_exact=True,invalid=len(invalid),max_ode_error=max(c['ode_error']for c in checks),max_corrected_reference_error=max(c['corrected_reference_error']for c in checks),max_residual=max(abs(c['residual'])for c in checks),legacy_rejected=sum(c['legacy_status']!=0 for c in checks),max_valid_legacy_mass_residual=max(abs(c['legacy_residual'])for c in checks if c['legacy_residual']is not None),input_sha256={p:sha((ROOT/p).read_bytes())for p in paths+[B1]},original_sha256=sha(original),corrected_reference_base=BASE,compiler=subprocess.check_output([FC,'--version'],text=True).splitlines()[0]);(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
