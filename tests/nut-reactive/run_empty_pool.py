"""Exact empty mineral equilibrium, real daily exchange and original WaterN."""
from pathlib import Path
import argparse,base64,hashlib,io,itertools,json,os,subprocess,tarfile,time
import numpy as np
from scipy.integrate import solve_ivp
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--output',required=True,type=Path);a=p.parse_args();OUT=a.output.resolve();OUT.mkdir()
FC=os.environ.get('FC','gfortran');events=[];sha=lambda b:hashlib.sha256(b).hexdigest()
paths=['src/process/mod_b111_soil_n_transport.f90','src/process/mod_b111_soil_n_daily_exchange.f90','tests/nut-reactive/test_nondepleting_exchange.f90',str(Path(__file__).relative_to(ROOT))]
BASE=json.loads((ROOT/'integration/mc-nut01/empty_equilibrium/STATUS.json').read_text())['baseline']
with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/'integration/mc-nut01/demand_candidate/EVIDENCE.tar.xz.b64').read_bytes())))as t:common=json.load(t.extractfile('direct/input.json'))['cases']
cases=[]
for form,h,K,tcs,demand in itertools.product([0,1,2],[-.03,0.,.03],[0.,.0002],[.1,.5],[.01,.1]):
 x=[.3,1.,.3,.3+h,.002,.001,0.,-.01,0.,tcs,60.,demand,1.2,3.,2.,1300.,K,.04 if form==0 else 0.,.03,0.,.002,.005,.2,.3]
 if form in [0,2]:x[20]=0.;x[22]=0.
 if form in [1,2]:x[21]=0.;x[23]=0.
 cases.append(x)
for h,K,tcs,demand in itertools.product([-.03,0.,.03],[0.,.0002],[.1,.5],[.01,.1]):
 x=[.3,1.,.3,.3+h,.002,.001,0.,-.01,0.,tcs,60.,demand,.5,.2,2.,1300.,K,0.,.03,.9*demand/.3,0.,.005,0.,.3]
 cases.append(x)
invalid=[]
for slot,value in [(19,-.001),(20,.002),(11,.1)]:
 x=list(cases[71]);x[slot]=value
 if slot==11:x[12]=.5;x[13]=.2
 invalid.append((x,1))
for mode in [2,3]:invalid.append((list(cases[71]),mode))
x=list(cases[71]);x[7]=0.;invalid.append((x,1))
default=[x[:7]+[abs(x[7])]+x[8:]for x in common]
(OUT/'input.json').write_text(json.dumps(dict(cases=cases,common=common,invalid=invalid,default=default),indent=2)+'\n')
payload=lambda xs:(''.join(' '.join(format(v,'.17e')for v in x)+' '+str(m)+'\n'for x,m in xs)).encode()
def run(cmd,b,kind,data=None):
 t=time.perf_counter();r=subprocess.run(list(map(str,cmd)),cwd=b,input=data,capture_output=True,timeout=120);e=dict(command=list(map(str,cmd)),category=kind,seconds=time.perf_counter()-t,returncode=r.returncode)
 for k in ['stdout','stderr']:
  name=f'{len(events):04d}.{k}';(OUT/name).write_bytes(getattr(r,k));e[k]=name
 events.append(e);(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n');assert r.returncode==0,(e,r.stderr.decode());return r.stdout
outputs={};incumbent={};defaults={}
for opt in ['O0','O2']:
 for kind in ['current','previous']:
  b=OUT/(opt+'-'+kind);b.mkdir();flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b)];objects=[]
  for i,path in enumerate(paths[:3]):
   src=b/(str(i)+'.f90');src.write_bytes(subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT)if kind=='previous'else(ROOT/path).read_bytes());obj=b/(str(i)+'.o');run([FC,*flags,'-c',src,'-o',obj],b,'compile');objects.append(obj)
  exe=b/'driver';run([FC,*flags,*objects,'-o',exe],b,'link')
  c=run([exe],b,'common_'+kind,payload([(x,1)for x in common]));d=run([exe],b,'default_'+kind,payload([(x,0)for x in default]));z=run([exe],b,'zero_'+kind,payload([(x,1)for x in cases]))
  if kind=='current':
   incumbent[opt]=c;defaults[opt]=d;outputs[opt]=z
   bad=run([exe],b,'invalid',payload(invalid));assert all(int(l.split()[0])!=0 for l in bad.splitlines())
  else:
   assert c==incumbent[opt]and d==defaults[opt],'incumbent byte drift'
   assert all(int(l.split()[0])!=0 for l in z.splitlines()),'preimage accepted empty donor'
assert outputs['O0']==outputs['O2']and incumbent['O0']==incumbent['O2']
checks=[]
for index,(x,line)in enumerate(zip(cases,outputs['O0'].splitlines())):
 code,*v=map(float,line.split());assert code==0,(index,line)
 dz,dt,w0,wt,qo,qr,qb,qt,ql,tcs,rd,demand,dvs,lai,crit,rho,K,kn,kd,nminer,ctn,ctd,cn,cd=x
 wavg=.5*(w0+wt);h=(wt-w0)/dt;rf=max(1.,rd*.01/dz)
 def ode(c0,prod,root,k,sorp,ctop):
  sol=solve_ivp(lambda t,y:[(prod+qt*ctop/dz-(h+qo/dz+root*qr/dz+k*wavg)*y[0])/(w0+rho*sorp+h*t),y[0]],[0.,dt],[c0,0.],method='DOP853',rtol=2.3e-14,atol=1e-17,max_step=dt/8);assert sol.success;return sol.y[0,-1],sol.y[1,-1]/dt
 def select(c0,prod,sorp,k,ctop,d):
  r=tcs*(wavg+rho*sorp)/wavg*rf
  if dvs<1. and lai<crit:
   j=(crit-lai)/crit;ce,ca=ode(c0,prod-j*d,r*(1.-j),k,sorp,ctop)
   return ce,ca,r*(1.-j)*qr*ca/dz+j*d
  ce,ca=ode(c0,prod,r,k,sorp,ctop)
  if c0==prod==ctop==0.:assert ce==ca==0.;return ce,ca,0.
  de,da=ode(c0,prod-d,0.,k,sorp,ctop)
  return (ce,ca,r*qr*ca/dz)if de<ce else(de,da,d)
 en,an,un=select(cn,nminer/dt,K,kn,ctn,demand/dz);ed,ad,ud=select(cd,wavg*kn*an,0.,kd,ctd,demand/dz-un)
 err=max(abs(np.array(v[:8])-np.array([en,an,ed,ad,un*dz,ud*dz,wavg*kn*an*dz,wavg*kd*ad*dz])));assert err<2e-12,(index,err)
 if cn==ctn==0. and nminer==0.:assert v[0]==v[1]==v[4]==v[6]==0.
 if cn==ctn==0. and nminer>0.:assert v[0]==v[1]==v[6]==0. and abs(v[4]-nminer*dz)<1e-16
 if cd==ctd==kn==0.:assert v[2]==v[3]==v[5]==v[7]==0.
 residual=dz*((w0+rho*K)*cn+w0*cd+nminer)-dz*((wt+rho*K)*v[0]+wt*v[2])-v[4]-v[5]-v[7]-v[14]-v[15]+qt*(ctn+ctd)
 assert abs(residual)<1e-12 and min(v[:8])>=0. and v[10:12]==[0.,0.];checks.append(dict(case=index,ode_error=float(err),residual=residual))
# Run the unmodified original WaterN on every homogeneous branch directly.
with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64').read_bytes())))as t:original=t.extractfile('SWAP/wofost_soil_watern.f90').read()
assert sha(original)=='b343fa9e485e60d76e2bd49067a20cd5ec328264af5d99d7cf1e4ddf07278722'
for opt in ['O0','O2']:
 b=OUT/(opt+'-original');b.mkdir();(b/'original.f90').write_bytes(original)
 (b/'fixture.f90').write_text('module MOD_texture_orgmat\n real(8)::bdens(1)=[1300d0]\nend module\nsubroutine swap_error(a,b)\n character(*)::a,b\n error stop 1\nend subroutine\n')
 (b/'driver.f90').write_text('program original_zero\n real(8)::x(24),p,c,a\n integer::s\n do\n read(*,*,iostat=s)x\n if(s/=0)exit\n call Wofost_SoilWaterN(x(1),x(2),x(3),x(4),x(5),x(6),x(7),x(8),x(9),x(10),x(18),0d0,p,x(17),0d0,0d0,0d0,0d0,c,a)\n if(c/=0d0.or.a/=0d0.or.p/=0d0)error stop 2\n print *,c,a,p\n end do\nend program\n')
 flags=['-'+opt,'-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow'];exe=b/'original';run([FC,*flags,b/'fixture.f90',b/'original.f90',b/'driver.f90','-o',exe],b,'original_compile_link');run([exe],b,'original_native',payload([(x,1)for x in cases]).replace(b' 1\n',b'\n'))
(OUT/'checks.json').write_text(json.dumps(checks,indent=2)+'\n')
r=dict(status='EMPTY_POOL_O0_O2_ODE_ORIGINAL_PASS',cases=len(cases),incumbent_cases=len(common),default_byte_exact=True,invalid=len(invalid),max_ode_error=max(c['ode_error']for c in checks),max_residual=max(abs(c['residual'])for c in checks),input_sha256={p:sha((ROOT/p).read_bytes())for p in paths},original_sha256=sha(original),compiler=subprocess.check_output([FC,'--version'],text=True).splitlines()[0]);(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
