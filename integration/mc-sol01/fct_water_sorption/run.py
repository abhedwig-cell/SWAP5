"""Small real-provider O0/O2 qualification, with independent storage/flux oracles."""
import argparse,hashlib,importlib.util,itertools,json,math,os,subprocess,time
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
def inverse(amount,theta,kf,exponent):
 if amount==0:return 0.
 b=1.3*kf
 if b==0:return amount/theta
 # Exact stable positive quadratic roots for the three tested exponents.
 # Unlike a generic root search, these also resolve near-zero sharp tails.
 if exponent==.5:return (2*amount/(b+math.sqrt(b*b+4*theta*amount)))**2
 if exponent==1:return amount/(theta+b)
 assert exponent==2
 return 2*amount/(theta+math.sqrt(theta*theta+4*b*amount))
def assess(out):
 r=json.loads((out/'execution.json').read_text());assert r['status']=='EXECUTED'
 for p,h in r['inputs'].items():assert sha((ROOT/p).read_bytes())==h,('source',p)
 assert r['provider_count']==7 and len(r['events'])==195 and all(e['returncode']==0 for e in r['events'])
 for e in r['events']:
  for stream in ['stdout','stderr']:assert sha((out/e[stream]).read_bytes())==e[stream+'_sha256']
 for opt in ['O0','O2']:
  build=[e for e in r['events'] if '-'+opt in e['command']];assert len(build)==1
  assert '-fcheck=all' in build[0]['command'] and '-ffpe-trap=invalid,zero,overflow' in build[0]['command']
 expected=set(itertools.product(['O0','O2'],[.5,1.,2.],[0.,.2],[-1,1],range(4),[.01,.2]))
 profiles={};max_low=max_high=max_bal=max_eq=max_const=0.;changed=0
 for case in r['cases']:
  event={k:v for k,v in case.items() if k not in ['optimization','exponent','kf','direction','shape','dt']}
  assert event in r['events'] and list(map(float,event['command'][1:]))==[case[k] for k in ['exponent','kf','direction','shape','dt']]
  key=tuple(case[k] for k in ['optimization','exponent','kf','direction','shape','dt']);assert key in expected and key not in profiles
  lines=(out/case['stdout']).read_text().splitlines();assert lines[-1]=='FIFTEEN_ATOMIC_REJECTIONS_AND_OFF_DELEGATION_PASS'
  head=lines[0].split();assert head[0]=='SUMMARY' and int(head[1])==24
  exponent,kf,direction,dt,before,after,residual,change=map(float,head[2:])
  assert [exponent,kf,direction,dt]==[case[k] for k in ['exponent','kf','direction','dt']]
  boundary=np.array(list(map(float,lines[1].split()[1:])));assert lines[1].startswith('BOUNDARY ')
  p=np.array([[float(v) for v in l.split()[2:]] for l in lines[2:-1]]);assert p.shape==(24,12)
  assert np.isfinite(p).all() and np.min(p)>=0 and np.isfinite(boundary).all()
  old,new,qin,qout,c,lc,lm,ls,hc,hm,hs,h=p.T
  assert np.max(abs((new-old)*h-dt*(qin-qout)))<1e-15
  assert np.max(abs(lm-new*h*lc))<1e-14 and np.max(abs(hm-new*h*hc))<1e-14
  eq=max(np.max(abs(ls-1.3*kf*lc**exponent*h)),np.max(abs(hs-1.3*kf*hc**exponent*h)));assert eq<4.6e-13
  initial=h*(old*c+1.3*kf*c**exponent);low=[];previous=boundary[2]
  for i in range(24):
   amount=(initial[i]+dt*qin[i]*previous)/h[i]
   previous=inverse(amount,new[i]+dt*qout[i]/h[i],kf,exponent);low.append(previous)
  low=np.array(low);err_low=np.max(abs(low-lc));assert err_low<2e-12
  slope=np.zeros(24)
  for i in range(1,23):
   v=np.array([2*(c[i]-c[i-1]),.5*(c[i+1]-c[i-1]),2*(c[i+1]-c[i])])
   slope[i]=min(v) if min(v)>0 else max(v) if max(v)<0 else 0
  face=np.r_[qin[0]*boundary[2],qout*(c+.5*slope)]
  amount=initial+.5*dt*(face[:-1]-face[1:]);assert np.min(amount)>=0
  half=np.array([inverse(a/z,t,kf,exponent) for a,z,t in zip(amount,h,.5*(old+new))])
  anti=dt*qout[:-1]*(half[:-1]+.5*slope[:-1]-low[:-1]);mass=h*(new*low+1.3*kf*low**exponent)
  upper=h*(new*max(max(c),boundary[2])+1.3*kf*max(max(c),boundary[2])**exponent)
  incoming=np.r_[0,np.maximum(anti,0)]+np.r_[np.maximum(-anti,0),0]
  outgoing=np.r_[np.maximum(anti,0),0]+np.r_[0,np.maximum(-anti,0)]
  rp=np.ones(24);rm=np.ones(24)
  for i in range(24):
   if outgoing[i]>mass[i]:rm[i]=mass[i]/outgoing[i]
   if incoming[i]>max(0,upper[i]-mass[i]):rp[i]=max(0,upper[i]-mass[i])/incoming[i]
  for i,a in enumerate(anti):
   factor=min(rm[i],rp[i+1]) if a>=0 else min(rp[i],rm[i+1])
   transfer=a*factor*(1-16*np.finfo(float).eps);mass[i]-=transfer;mass[i+1]+=transfer
  err_high=np.max(abs(mass-hm-hs));assert err_high<2e-12
  assert np.max(hc)<=max(max(c),boundary[2])+1e-12
  assert abs(sum(initial)-before)<1e-12 and abs(sum(hm+hs)-after)<1e-12
  assert abs(boundary[0]-dt*qin[0]*boundary[2])<1e-14
  assert abs(boundary[1]-dt*qout[-1]*lc[-1])<1e-14
  bal=max(abs(after-before-boundary[0]+boundary[1]),abs(residual));assert bal<1e-12
  assert abs(change-sum(abs(hm+hs-lm-ls)))<1e-12
  if case['shape']>=2:
   constant=np.max(abs(hc-c));assert constant<1e-12;max_const=max(max_const,constant)
  else:assert change>1e-10;changed+=1
  max_low=max(max_low,err_low);max_high=max(max_high,err_high);max_bal=max(max_bal,bal);max_eq=max(max_eq,eq)
  profiles[key]=p
 assert set(profiles)==expected
 optdiff=max(float(np.max(abs(p-profiles[('O2',*key[1:])]))) for key,p in profiles.items() if key[0]=='O0');assert optdiff<1e-12
 return dict(status='WATER_BALANCED_NONLINEAR_SINGLE_STEP_RESEARCH_O0_O2_PASS',cases=len(profiles),nontrivial_corrections=changed,
  atomic_rejections=15*len(profiles),off_delegations=2*len(profiles),max_low_oracle_error=float(max_low),max_corrected_mass_oracle_error=float(max_high),
  max_mass_residual=float(max_bal),max_equilibrium_error=float(max_eq),max_constant_solution_error=float(max_const),max_optimization_difference=optdiff,
  production_activated=False,native_qualified=False,actual_water_trace_qualified=False,time_series_accuracy_qualified=False,full_mc_sol01_closed=False)
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);ap.add_argument('--verify-only',action='store_true');a=ap.parse_args();out=a.output.resolve()
 if not a.verify_only:
  out.mkdir(parents=True,exist_ok=False);p=ROOT/'tests/support/augment_bartholomeus_backend_sources.py'
  spec=importlib.util.spec_from_file_location('deps',p);deps=importlib.util.module_from_spec(spec);spec.loader.exec_module(deps)
  sources,_=deps.strict_closure(ROOT,[str(HERE/'driver.f90')],[str(HERE/'mod_research_storage_fct.f90')])
  report=dict(status='BUILDING',baseline=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),inputs={str(q.relative_to(ROOT)):sha(q.read_bytes()) for q in [*sources,p,Path(__file__)]},provider_count=len(sources)-1,events=[],cases=[])
  def save():(out/'execution.json').write_text(json.dumps(report,indent=2)+'\n')
  def run(cmd,cwd):
   start=time.monotonic();cp=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=120);i=len(report['events']);e=dict(command=list(map(str,cmd)),returncode=cp.returncode,seconds=time.monotonic()-start)
   for stream in ['stdout','stderr']:
    raw=getattr(cp,stream);e[stream]=f'{i:03d}.{stream}';e[stream+'_sha256']=sha(raw);(out/e[stream]).write_bytes(raw)
   report['events'].append(e)
   if cp.returncode:report['status']='FAILED'
   save();assert cp.returncode==0,(e,cp.stdout[-1000:],cp.stderr[-1000:]);return e
  save();run([os.environ.get('FC','gfortran'),'--version'],out)
  for opt in ['O0','O2']:
   folder=out/opt;folder.mkdir();exe=folder/'storage-fct'
   run([os.environ.get('FC','gfortran'),'-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(folder),*sources,'-o',exe],folder)
   for exponent,kf,direction,shape,dt in itertools.product([.5,1.,2.],[0.,.2],[-1,1],range(4),[.01,.2]):
    e=run([exe,exponent,kf,direction,shape,dt],folder);report['cases'].append(dict(**e,optimization=opt,exponent=exponent,kf=kf,direction=direction,shape=shape,dt=dt));save()
  report['status']='EXECUTED';save()
 result=assess(out);(out/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
