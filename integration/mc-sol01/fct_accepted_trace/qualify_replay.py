"""Replay actual committed traces; compare to independent refined MOL carrier."""
import argparse,hashlib,importlib.util,itertools,json,os,subprocess,time
from pathlib import Path
import numpy as np
from scipy.integrate import solve_ivp
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
STORAGE='integration/mc-sol01/fct_water_sorption/mod_research_storage_fct.f90'
def storage_successor():
 text=(ROOT/STORAGE).read_text()
 # Explicitly selected EXISTING physical zero-pool limit, on both branches.
 # All frozen reconstruction, limiting, partition and acceptance code is exact.
 for tail in ['next,next_s,r);return','low,low_s,r)']:
  old='call advance_b111_reactive_solute_substep(m,s,f,'+tail
  new=old.replace('r)','r,exact_empty_pond_limit=.true.)')
  assert text.count(old)==1;text=text.replace(old,new)
 return text.encode()
def invert(m,theta,exponent):
 b=.26
 if exponent==.5:return (2*m/(b+np.sqrt(b*b+4*theta*m)))**2
 if exponent==1:return m/(theta+b)
 assert exponent==2
 return 2*m/(theta+np.sqrt(theta*theta+4*b*m))
def load_water(path):
 n=int(path.open().readline());a=np.loadtxt(path,skiprows=1);assert a.shape[1]==5+3*n
 assert np.isfinite(a).all() and (a[:,4:]>=0).all()
 t0,t1,top,bottom=a[:,:4].T;old=a[:,4:4+n];new=a[:,4+n:4+2*n];q=a[:,4+2*n:]
 assert t0[0]==0 and t1[-1]==2 and np.all(t0[1:]==t1[:-1]) and np.all(t1>t0)
 assert np.array_equal(old[1:],new[:-1])
 dt=t1-t0;h=40/n
 assert np.max(abs((new-old)*h-dt[:,None]*(q[:,:-1]-q[:,1:])))<2e-16
 assert np.array_equal(top,q[:,0]) and np.max(abs(dt*(bottom-q[:,-1])))<1e-10
 assert np.max(dt[:,None]*q[:,1:]/(np.minimum(old,new)*h))<=1
 assert np.max(abs(new-old))>1e-12
 return n,a
def reference(a,n,c0,exponent,subdivision):
 h=40/n;z=h/subdivision
 old=a[0,4:4+n];mass=np.repeat(old*c0+.26*c0**exponent,subdivision)*z
 evaluations=0;min_mass=float(np.min(mass))
 for row in a:
  t0,t1=row[:2];dt=t1-t0;old=row[4:4+n];new=row[4+n:4+2*n];q=row[4+2*n:]
  w0=np.repeat(old,subdivision);w1=np.repeat(new,subdivision)
  fine_q=np.interp(np.arange(n*subdivision+1)/subdivision,np.arange(n+1),q)
  def rhs(t,m):
   water=w0+(t-t0)/dt*(w1-w0)
   assert np.min(m)>=0,('negative reference stage',float(np.min(m)))
   c=invert(m/z,water,exponent);flux=fine_q*np.r_[.05,c]
   return flux[:-1]-flux[1:]
  result=solve_ivp(rhs,(t0,t1),mass,method='DOP853',rtol=1e-10,atol=1e-13, max_step=min(dt,.5*z*min(min(old),min(new))/max(q)))
  assert result.success and np.isfinite(result.y).all() and np.min(result.y)>=0
  mass=result.y[:,-1];evaluations+=result.nfev;min_mass=min(min_mass,float(np.min(result.y)))
 return dict(mass=mass.reshape(n,subdivision).sum(axis=1).tolist(),nfev=evaluations,min_mass=min_mass,subdivision=subdivision)
def assess(out,water):
 report=json.loads((out/'execution.json').read_text());wr=json.loads((water/'execution.json').read_text())
 assert report['status']=='EXECUTED' and wr['status']=='WATER_EXPORTED' and len(wr['water_cases'])==12
 assert report['water_execution_sha256']==sha((water/'execution.json').read_bytes())
 assert (out/'storage_successor.f90').read_bytes()==storage_successor()
 assert report['storage_successor_sha256']==sha(storage_successor())
 assert report['exact_empty_pond_limit'] is True
 for record in [report,wr]:
  for p,h in record['inputs'].items():assert sha((ROOT/p).read_bytes())==h,('source',p)
  folder=water if record is wr else out
  assert all(e['returncode']==0 for e in record['events'])
  for e in record['events']:
   for s in ['stdout','stderr']:assert sha((folder/e[s]).read_bytes())==e[s+'_sha256']
 assert wr['water_provider_count']==163 and report['replay_provider_count']==8
 assert len(report['cases'])==72 and len(report['references'])==36
 traces={};water_drift=0.
 for case in wr['water_cases']:
  path=water/case['path'];assert sha(path.read_bytes())==case['sha256']
  n,a=load_water(path);assert n==case['n'];key=(case['optimization'],n,case['factor']);assert key not in traces
  traces[key]=a
 for opt,n,factor in traces:
  if opt=='O0':
   assert traces[(opt,n,factor)].shape==traces[('O2',n,factor)].shape
   drift=float(np.max(abs(traces[(opt,n,factor)]-traces[('O2',n,factor)])));assert drift<1e-12;water_drift=max(water_drift,drift)
 results={};profiles={};max_balance=max_eq=max_constant=0.
 for case in report['cases']:
  opt,n,factor,exponent,shape=[case[k] for k in ['optimization','n','factor','exponent','shape']]
  key=(opt,n,factor,exponent,shape);assert key not in profiles
  raw=(out/case['stdout']).read_text().splitlines();assert raw[-1]=='FIVE_LATE_BATCH_REJECTIONS_EXACT_SPLIT_CONTINUATION_PASS'
  assert raw[0].split()[0]=='REPLAY';head=list(map(float,raw[0].split()[1:]));a=traces[(opt,n,factor)]
  assert head==[n,len(a),shape,exponent]
  lowledger=np.array(list(map(float,raw[1].split()[1:])));ledger=np.array(list(map(float,raw[2].split()[1:])))
  assert raw[1].startswith('LOW_LEDGER ') and raw[2].startswith('CORRECTED_LEDGER ')
  p=np.array([[float(v) for v in l.split()[2:]] for l in raw[3:-1]]);assert p.shape==(n,7)
  assert np.isfinite(p).all() and np.min(p)>=0 and np.isfinite(ledger).all() and np.isfinite(lowledger).all()
  initial,lc,lm,ls,hc,hm,hs=p.T;h=40/n;end=a[-1,4+n:4+2*n];begin=a[0,4:4+n]
  assert np.max(abs(hm-end*h*hc))<1e-13 and np.max(abs(lm-end*h*lc))<1e-13
  eq=max(float(np.max(abs(hs-.26*h*hc**exponent))),float(np.max(abs(ls-.26*h*lc**exponent))));assert eq<4.6e-13
  before=sum(h*(begin*initial+.26*initial**exponent))
  bal=max(abs(sum(hm+hs)-before-ledger[0]+ledger[1]),abs(sum(lm+ls)-before-lowledger[0]+lowledger[1]),max(abs(ledger[2:])),max(abs(lowledger[2:])));assert bal<1e-10
  assert max(hc)<=max(initial)+1e-10
  if shape==1:
   error=float(np.max(abs(hc-initial)));assert error<1e-10;max_constant=max(max_constant,error)
  elif opt=='O2':
   refs=[r for r in report['references'] if (r['n'],r['factor'],r['exponent'])==(n,factor,exponent)];assert len(refs)==2
   fine={r['subdivision']:np.array(r['mass']) for r in refs};assert set(fine)=={8,16}
   low_error=float(sum(abs(lm+ls-fine[16])));high_error=float(sum(abs(hm+hs-fine[16])));uncertainty=float(sum(abs(fine[16]-fine[8])))
   results[f'{n}/{factor}/{exponent}']=dict(low_mass_l1=low_error,corrected_mass_l1=high_error,reference_refinement_l1=uncertainty,ratio=high_error/low_error)
  profiles[key]=p;max_balance=max(max_balance,bal);max_eq=max(max_eq,eq)
 expected=set(itertools.product(['O0','O2'],[40,80,160],[.8,1.2],[.5,1.,2.],[0,1]));assert set(profiles)==expected
 optdiff=max(float(np.max(abs(p-profiles[('O2',*key[1:])]))) for key,p in profiles.items() if key[0]=='O0');assert optdiff<1e-11
 return dict(status='ACTUAL_ACCEPTED_TRACE_REPLAY_O0_O2_EXECUTED',water_cases=12,replays=72,late_atomic_rejections=360,exact_split_continuations=72,
  max_mass_residual=float(max_balance),max_equilibrium_error=max_eq,max_constant_error=max_constant,max_water_optimization_difference=water_drift,max_solute_optimization_difference=optdiff,
  accuracy=results,production_activated=False,native_qualified=False,actual_water_trace_qualified=True,time_series_accuracy_qualified=False,full_mc_sol01_closed=False)
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--water',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);ap.add_argument('--verify-only',action='store_true');a=ap.parse_args();water=a.water.resolve();out=a.output.resolve()
 if not a.verify_only:
  out.mkdir(parents=True,exist_ok=False);wr=json.loads((water/'execution.json').read_text());assert wr['status']=='WATER_EXPORTED'
  for p,h in wr['inputs'].items():assert sha((ROOT/p).read_bytes())==h
  dependency=ROOT/'tests/support/augment_bartholomeus_backend_sources.py';spec=importlib.util.spec_from_file_location('deps',dependency);deps=importlib.util.module_from_spec(spec);spec.loader.exec_module(deps)
  sources,_=deps.strict_closure(ROOT,[str(HERE/'replay_driver.f90')],[str(HERE/'mod_research_trace_replay.f90'),'integration/mc-sol01/fct_water_sorption/mod_research_storage_fct.f90'])
  generated=out/'storage_successor.f90';generated.write_bytes(storage_successor())
  report=dict(status='BUILDING',baseline=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),inputs={str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in [*sources,dependency,Path(__file__)]},water_execution_sha256=sha((water/'execution.json').read_bytes()),replay_provider_count=len(sources)-1,storage_successor_sha256=sha(generated.read_bytes()),exact_empty_pond_limit=True,events=[],cases=[],references=[])
  def save():(out/'execution.json').write_text(json.dumps(report,indent=2)+'\n')
  def run(cmd,cwd):
   start=time.monotonic();cp=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=120);e=dict(command=list(map(str,cmd)),returncode=cp.returncode,seconds=time.monotonic()-start)
   for stream in ['stdout','stderr']:
    raw=getattr(cp,stream);e[stream]=f'{len(report["events"]):03d}.{stream}';e[stream+'_sha256']=sha(raw);(out/e[stream]).write_bytes(raw)
   report['events'].append(e)
   if cp.returncode:report['status']='FAILED'
   save();assert cp.returncode==0,(e,cp.stdout[-1000:],cp.stderr[-2000:]);return e
  save();fc=os.environ.get('FC','gfortran');run([fc,'--version'],out)
  for opt in ['O0','O2']:
   folder=out/opt;folder.mkdir();exe=folder/'replay'
   compiled=[generated if p==ROOT/STORAGE else p for p in sources]
   run([fc,'-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(folder),*compiled,'-o',exe],folder)
   for wc in wr['water_cases']:
    if wc['optimization']!=opt:continue
    n,tr=load_water(water/wc['path'])
    for exponent,shape in itertools.product([.5,1.,2.],[0,1]):
     e=run([exe,water/wc['path'],exponent,shape],folder);report['cases'].append(dict(**e,optimization=opt,n=n,factor=wc['factor'],exponent=exponent,shape=shape));save()
     if opt=='O2' and shape==0:
      lines=(out/e['stdout']).read_text().splitlines();initial=np.array([float(l.split()[2]) for l in lines if l.startswith('CELL ')])
      for sub in [8,16]:
       start=time.monotonic();ref=reference(tr,n,initial,exponent,sub);report['references'].append(dict(**ref,n=n,factor=wc['factor'],exponent=exponent,seconds=time.monotonic()-start));save()
  report['status']='EXECUTED';save()
 result=assess(out,water);(out/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
