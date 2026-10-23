"""Fresh real finite-donor limit driver, independent ODE and exact preimage checks."""
from pathlib import Path
import argparse, ast, hashlib, itertools, json, os, subprocess, time
import numpy as np
from scipy.integrate import solve_ivp

ROOT=Path(__file__).resolve().parents[2]
BASE='d6f52d935c0bee6039051fe4e4a7b810df507822'
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--output',required=True,type=Path)
a=p.parse_args();OUT=a.output.resolve();OUT.mkdir(parents=True,exist_ok=False)
FC=os.environ.get('FC','gfortran');events=[]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def run(cmd,cwd,category,payload=None):
 cmd=list(map(str,cmd));start=time.perf_counter()
 r=subprocess.run(cmd,cwd=cwd,input=payload,capture_output=True,timeout=120)
 e=dict(command=cmd,category=category,seconds=time.perf_counter()-start,returncode=r.returncode)
 for stream in ['stdout','stderr']:
  name=f'{len(events):04d}.{stream}';(OUT/name).write_bytes(getattr(r,stream));e[stream]=name
 events.append(e);(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if r.returncode:raise RuntimeError(str(e)+r.stderr.decode(errors='replace')+r.stdout.decode(errors='replace'))
 return r.stdout

def compile_driver(opt,old=False,default=False):
 b=OUT/(opt+('-old'if old else'')+('-default'if default else''));b.mkdir()
 path='src/process/mod_b111_soil_n_transport.f90'
 source=subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT)if old else(ROOT/path).read_bytes()
 (b/'transport.f90').write_bytes(source)
 driver=(ROOT/'tests/nut-mineral/test_negative_limits.f90').read_text()
 if default:
  driver=driver.replace('x(4),x(5),x(6),x(7),x(8), &\n   x(9),x(10),x(11),x(12),x(13),x(14),x(15),x(16),r)',
   'x(4),x(5),0d0,x(6),abs(x(7)),x(8),0d0, &\n   x(9),x(10),x(11),x(12),x(13),x(14),x(15),x(16),r)')
  driver=driver.replace('call evaluate_b111_soil_n_negative_boundary','call evaluate_b111_soil_n_transport')
 (b/'driver.f90').write_text(driver)
 flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow',
  '-Wall','-Wextra','-Werror','-J'+str(b),'-I'+str(b)]
 for name in ['transport','driver']:run([FC,*flags,'-c',b/(name+'.f90'),'-o',b/(name+'.o')],b,'compile')
 exe=b/'driver';run([FC,*flags,b/'transport.o',b/'driver.o','-o',exe],b,'link')
 return exe

def payload(cases):return ('\n'.join(' '.join(format(v,'.17e')for v in x)for x in cases)+'\n').encode()
# Existing independently qualified 80 valid + 4 invalid inputs, verbatim generator.
recipe=ROOT/'reference/swap-4.3.1/patches/SWAP-020/run.py'
node=next(n for n in ast.parse(recipe.read_text()).body if isinstance(n,ast.FunctionDef)and n.name=='matrix')
scope={};exec(compile(ast.Module(body=[node],type_ignores=[]),str(recipe),'exec'),scope)
incumbent=[[x[i]for i in [0,1,2,3,4,6,7,8,10,11,17,12,13,14,15,16]]for x in scope['matrix']()]
# Three formerly rejected limit surfaces, both water directions, NH4/NO3,
# empty/depleted/ample donors, continuing production and boundary sources.
cases=[]
for h,loss,K,c0,supply in itertools.product(
 [-1e-9,-1e-12,0.,1e-12,1e-9,1e-7],[0.,1e-12,1e-9,1e-7],
 [0.,.0002],[0.,1e-6,.002,.2],[False,True]):
 cases.append([.3,1.,.3+h,.3,.3*loss,.001 if supply else 0.,-.04,0.,0.,
  1e-5 if supply else 0.,1300.,K,.002,.005,0.,c0])
# Explicit tiny reaction coefficient and cancellation of h+loss.
for k in [1e-12,1e-9,3e-8]:
 for h in [-1e-7,-1e-9,0.,1e-9]:
  for c0 in [1e-6,.2]:cases.append([.3,1.,.3+h,.3,max(0.,-h)*.3,0.,-.04,0.,k,0.,1300.,.0002,0.,.005,0.,c0])
# Exercise the full dimensionless series interval, including both limiting
# branches with substantial drying/wetting and substantial first-order loss.
for h,loss,K,c0,supply in itertools.product(
 [1e-12,-.03,.03],[1e-12,.03,.03749],[0.,.0002],[0.,1e-6,.2],[False,True]):
 # Only formerly rejected or cancellation-prone cases select the new series.
 actual_loss=loss if h==1e-12 else (abs(h)+1e-12 if h<0. else 1e-12)
 cases.append([.3,1.,.3+h,.3,.3*actual_loss,.001 if supply else 0.,-.04,0.,0.,
  1e-5 if supply else 0.,1300.,K,.002,.005,0.,c0])
# A formally near-limit case outside the scaled series domain must still reject.
unsupported=[[.3,1.,.3,.3,.06,0.,-.04,0.,0.,0.,1300.,0.,0.,.005,0.,.2],
 [.3,1e8,.4,.3,.0001,0.,-.04,0.,0.,0.,1300.,0.,0.,.005,0.,.2],
 [.3,1.,.3+1e-12,.3,.3*.0376,0.,-.04,0.,0.,0.,1300.,0.,0.,.005,0.,.2]]
# First is an ordinary accepted case; second is the intended new-domain rejection.
(OUT/'input.json').write_text(json.dumps(dict(cases=cases,incumbent=incumbent,unsupported=unsupported),indent=2)+'\n')
outputs={};baseline={};old_status=[];changed_accepted=0
for opt in ['O0','O2']:
 current=compile_driver(opt);old=compile_driver(opt,True)
 out=run([current],OUT,'native',payload(cases));outputs[opt]=out
 oldout=run([old],OUT,'preimage_native',payload(cases))
 old_status=[int(line.split()[0])for line in oldout.splitlines()]
 before=run([old],OUT,'incumbent_preimage',payload(incumbent));after=run([current],OUT,'incumbent_current',payload(incumbent))
 assert before==after,'incumbent byte drift'
 baseline[opt]=hashlib.sha256(after).hexdigest()
 changed_accepted=sum(int(prev.split()[0])==0 and prev!=new
  for prev,new in zip(oldout.splitlines(),out.splitlines()))
 for default in [True]:
  old_default=compile_driver(opt,True,True);new_default=compile_driver(opt,False,True)
  assert run([old_default],OUT,'default_preimage',payload(cases))==run([new_default],OUT,'default_current',payload(cases)),'default drift'
 outside=run([current],OUT,'bounds',payload(unsupported)).splitlines()
 assert int(outside[1].split()[0])!=0,'series domain widened without qualification'
 assert int(outside[2].split()[0])!=0,'series upper bound not enforced'
assert outputs['O0']==outputs['O2'],'limit O0/O2 bytes differ'
assert baseline['O0']==baseline['O2'],'incumbent optimization drift'
checks=[]
for index,(x,line)in enumerate(zip(cases,outputs['O0'].splitlines())):
 code,kind,*r=map(float,line.split());assert code==0,(index,x,line)
 dz,dt,wt,w0,qout,qbot,qtop,qlat,k,prod,rho,K,cb,ct,cl,c0=x
 h=(wt-w0)/dt;s0=w0+rho*K;h1=h+qout/dz+k*.5*(wt+w0)
 positive=(qbot*cb+qlat*cl)/dz+prod;extraction=-qtop*ct/dz
 def rhs(t,y):return [(positive-extraction-h1*y[0])/(s0+h*t),y[0]]
 def zero(t,y):return y[0]
 zero.terminal=True;zero.direction=-1
 if c0==0. and positive<=extraction:ce=ca=tau=0.
 else:
  sol=solve_ivp(rhs,[0.,dt],[c0,0.],method='DOP853',rtol=2.3e-14,atol=1e-17,events=zero,max_step=dt/8)
  assert sol.success;ce=max(0.,sol.y[0,-1]);ca=sol.y[1,-1]/dt;tau=sol.t[-1]
 actual=-dz*(extraction*tau+positive*(dt-tau))/dt;unmet=dz*(extraction-positive)*(dt-tau)
 error=max(abs(np.array(r)-[ce,ca,actual,unmet,tau]));assert error<2e-11,(index,error,x,r)
 end,average,top,unmet_f,tau_f=r
 residual=dz*s0*c0+dz*positive*dt+top*dt-(qout+k*.5*(wt+w0)*dz)*average*dt-dz*(wt+rho*K)*end
 assert abs(residual)<1e-12,(index,residual)
 assert min(end,average,unmet_f)>=0. and qtop*ct<=top<=0.
 assert abs(top*dt-qtop*ct*dt-unmet_f)<1e-14
 checks.append(dict(case=index,class_id=int(kind),preimage_rejected=old_status[index]!=0,oracle_error=error,residual=residual))
(OUT/'checks.json').write_text(json.dumps(checks,indent=2)+'\n')
owner_outputs={}
for opt in ['O0','O2']:
 b=OUT/(opt+'-owner');b.mkdir()
 flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all',
  '-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b)]
 providers=['src/process/mod_soil_n_pool_state.f90',
  'src/process/mod_b111_soil_n_storage_conversion.f90',
  'src/process/mod_b111_soil_n_transport.f90',
  'src/process/mod_b111_soil_n_mineral_owner.f90',
  'tests/nut-mineral/test_negative_limits_owner.f90']
 objects=[]
 for path in providers:
  obj=b/(Path(path).stem+'.o')
  run([FC,*flags,'-c',ROOT/path,'-o',obj],b,'owner_compile');objects.append(obj)
 exe=b/'owner';run([FC,*flags,*objects,'-o',exe],b,'owner_link')
 owner_outputs[opt]=run([exe],b,'owner_native')
 assert b'FINITE_DONOR_LIMIT_OWNER_RESTART_ROLLBACK_BALANCE=PASS' in owner_outputs[opt]
assert owner_outputs['O0']==owner_outputs['O2'],'owner optimization drift'
inputs={path:sha(ROOT/path)for path in ['src/process/mod_b111_soil_n_transport.f90',
 'tests/nut-mineral/test_negative_limits.f90','tests/nut-mineral/run_negative_limits.py',
 'tests/nut-mineral/test_negative_limits_owner.f90',*providers]}
r=dict(status='FINITE_DONOR_LIMITS_DIRECT_O0_O2_PASS',baseline=BASE,
 execution_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
 compiler=run([FC,'--version'],OUT,'compiler').decode().splitlines()[0],input_sha256=inputs,
 cases=len(cases),newly_accepted=sum(c['preimage_rejected']for c in checks),
 corrected_accepted_limit_cases=changed_accepted,
 incumbent_cases=len(incumbent),incumbent_bytes_exact=True,default_bytes_exact=True,
 o0_o2_bytes_exact=True,max_abs_residual=max(abs(c['residual'])for c in checks),
 owner_intervals_per_optimization=12,owner_restart_and_rollback=True,
 max_oracle_error=max(c['oracle_error']for c in checks),
 cost_seconds={cat:sum(e['seconds']for e in events if e['category']==cat)for cat in {e['category']for e in events}},
 canonical_admitted=False,full_mc_nut01_closed=False)
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))
