"""Actual organic zero-pool-rate limit versus independent seven-state ODE."""
from pathlib import Path
import argparse,hashlib,itertools,json,os,subprocess,time
import numpy as np
from scipy.integrate import quad
import math
from scipy.integrate import solve_ivp
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();OUT=a.output.resolve();OUT.mkdir(parents=True,exist_ok=False)
FC=os.environ.get('FC','gfortran');events=[];sha=lambda b:hashlib.sha256(b).hexdigest()
paths=['src/process/mod_b111_soil_organic_turnover.f90','src/process/mod_b111_soil_organic_dissimilation.f90','tests/nut-reactive/test_zero_pool_rates.f90',str(Path(__file__).relative_to(ROOT))]
BASE=json.loads((ROOT/'integration/mc-nut01/zero_pool_rates/STATUS.json').read_text())['baseline']
def run(cmd,b,kind,payload=None):
 t=time.perf_counter();r=subprocess.run(list(map(str,cmd)),cwd=b,input=payload,capture_output=True,timeout=120);e=dict(command=list(map(str,cmd)),category=kind,seconds=time.perf_counter()-t,returncode=r.returncode)
 for k in ['stdout','stderr']:
  name=f'{len(events):04d}.{k}';(OUT/name).write_bytes(getattr(r,k));e[k]=name
 events.append(e);(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n');assert r.returncode==0,(e,r.stderr.decode(),r.stdout.decode());return r.stdout
zero=[]
for k1,k2,dt,material,pools in itertools.product([0.,1e-12,1e-6,.008,.1,1.,100.],[0.,.015],[.01,1.,10.],[False,True],[False,True]):
 zero.append([k1,k2,0.,0.,10. if material else 0.,20. if material else 0.,.1 if pools else 0.,.2 if pools else 0.,dt,.3])
common=[]
for kb,kh,dt,material in itertools.product([.008,.02],[.0008,.001],[.5,1.,2.],[False,True]):common.append([.04,.015,kb,kh,10. if material else 0.,20. if material else 0.,.1,.2,dt,.3])
invalid=[]
for slot,value in [(0,-1.),(8,0.),(4,-1.),(9,-1.)]:
 x=list(zero[0]);x[slot]=value;invalid.append(x)
(OUT/'input.json').write_text(json.dumps(dict(zero=zero,common=common,invalid=invalid),indent=2)+'\n')
payload=lambda xs:(''.join(' '.join(format(v,'.17e')for v in x)+'\n'for x in xs)).encode()
outputs={};common_outputs={};fraction_checks=[]
for opt in ['O0','O2']:
 for mode in ['current','previous']:
  b=OUT/(opt+'-'+mode);b.mkdir();flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b)];objects=[]
  for i,p in enumerate(paths[:3]):
   src=b/(str(i)+'.f90');src.write_bytes(subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT)if mode=='previous'and i<2 else(ROOT/p).read_bytes())
   obj=b/(str(i)+'.o');run([FC,*flags,'-c',src,'-o',obj],b,'compile');objects.append(obj)
  exe=b/'driver';run([FC,*flags,*objects,'-o',exe],b,'link')
  regular=run([exe],b,'common_'+mode,payload(common));z=run([exe],b,'zero_'+mode,payload(zero))
  if mode=='current':
   common_outputs[opt]=regular;outputs[opt]=z
   helper=ROOT/'tests/nut-reactive/test_decay_fractions.f90';hobj=b/'fraction.o';hexe=b/'fractions'
   run([FC,*flags,'-c',helper,'-o',hobj],b,'fraction_compile');run([FC,*flags,objects[0],hobj,'-o',hexe],b,'fraction_link')
   xs=[0.,1e-30,1e-12,1e-6,.125,.125000001,.5,1.,100.,1000.,-1.,float('nan'),float('inf')]
   hs=run([hexe],b,'fraction_native',('\n'.join(str(x)for x in xs)+'\n').encode()).splitlines()
   for x,line in zip(xs,hs):
    code,loss,avg=map(float,line.split())
    if not math.isfinite(x)or x<0.:assert code!=0;continue
    expected_loss=-math.expm1(-x);expected_avg=quad(lambda u:-math.expm1(-x*u),0.,1.,epsabs=1e-30,epsrel=1e-13)[0]
    assert code==0 and abs(loss-expected_loss)<5e-15*max(abs(expected_loss),1e-30)
    assert abs(avg-expected_avg)<5e-15*max(abs(expected_avg),1.)
    fraction_checks.append(dict(opt=opt,x=x,loss_error=abs(loss-expected_loss),average_error=abs(avg-expected_avg)))
   bad=run([exe],b,'invalid',payload(invalid));assert all(any(int(v)!=0 for v in l.split()[:2])for l in bad.splitlines())
  else:
   assert regular==common_outputs[opt],'nonzero production byte drift'
   assert all(int(l.split()[0])!=0 for l in z.splitlines()),'preimage domain witness not singular'
assert outputs['O0']==outputs['O2']and common_outputs['O0']==common_outputs['O2'],'optimization drift'
checks=[]
for index,(x,line)in enumerate(zip(zero,outputs['O0'].splitlines())):
 code1,code2,*v=map(float,line.split());assert code1==code2==0,(index,line)
 k1,k2,kb,kh,f1,f2,b,h,dt,dz=x
 def rhs(t,y):
  a,c,B,H,_,_,_=y
  toB=.2*k1*a+.25*k2*c;toH=.15*k1*a+.1*k2*c
  return [-k1*a,-k2*c,toB-.7*kb*B+.3*kh*H,toH+.2*kb*B-.8*kh*H,B,H,.45*.65*(k1*a+k2*c)+.45*.5*(kb*B+kh*H)]
 sol=solve_ivp(rhs,[0.,dt],[f1,f2,b,h,0.,0.,0.],method='DOP853',rtol=2.3e-14,atol=1e-15,max_step=dt/16);assert sol.success
 y=sol.y[:,-1];expected=[*y[:4],y[4]/dt,y[5]/dt,y[6]*dz];error=max(abs(np.array(v)-expected))
 assert error<2e-11,(index,error,x,v,expected)
 residual=.45*dz*(f1+f2+b+h-sum(v[:4]))-v[6];assert abs(residual)<1e-12,(index,residual)
 assert min(v)>=0 and all(np.isfinite(v))
 if k1==k2==0:assert v==[f1,f2,b,h,b,h,0.],'zero-rate exact identity'
 checks.append(dict(case=index,ode_error=float(error),carbon_residual=residual))
(OUT/'fraction-checks.json').write_text(json.dumps(fraction_checks,indent=2)+'\n')
(OUT/'checks.json').write_text(json.dumps(checks,indent=2)+'\n')
r=dict(status='ZERO_RECEIVING_POOL_RATES_O0_O2_ODE_AND_CARBON_PASS',zero_cases=len(zero),formerly_rejected=len(zero),nonzero_cases=len(common),nonzero_byte_exact=True,invalid=len(invalid),max_ode_error=max(c['ode_error']for c in checks),max_carbon_residual=max(abs(c['carbon_residual'])for c in checks),fraction_cases_per_optimization=13,input_sha256={p:sha((ROOT/p).read_bytes())for p in paths+['tests/nut-reactive/test_decay_fractions.f90']},compiler=subprocess.check_output([FC,'--version'],text=True).splitlines()[0])
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
