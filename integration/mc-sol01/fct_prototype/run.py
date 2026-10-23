"""Measured research comparison; the production transport interface is unchanged."""
import argparse,hashlib,importlib.util,json,math,os,subprocess,time
from pathlib import Path
import numpy as np
from scipy.special import erf
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def exact(n,kf,shape):
 h=40/n;shift=.25/(.25+1.3*kf)*2;edges=np.arange(n+1)*h
 if shape==0:return math.sqrt(math.pi/2)*np.diff(erf((edges-15-shift)/math.sqrt(2)))/h
 return np.maximum(0,np.minimum(edges[1:],17+shift)-np.maximum(edges[:-1],15+shift))/h
def assess(out):
 r=json.loads((out/'execution.json').read_text());assert r['status']=='EXECUTED'
 for p,h in r['inputs'].items():assert sha(ROOT/p)==h,('source',p)
 assert r['provider_count']==7 and len(r['cases'])==64
 assert len(r['events'])==67 and all(e['returncode']==0 for e in r['events'])
 for opt in ['O0','O2']:
  builds=[e for e in r['events'] if '-'+opt in e['command']];assert len(builds)==1
  assert '-fcheck=all' in builds[0]['command'] and '-ffpe-trap=invalid,zero,overflow' in builds[0]['command']
 profiles={};measurements={};maxbal=0.;maxcumul=0.
 for c in r['cases']:
  raw=(out/c['stdout']).read_bytes();assert hashlib.sha256(raw).hexdigest()==c['sha256']
  lines=raw.decode().splitlines();head=lines[0].split();assert head[0]=='SUMMARY' and len(head)==14
  case,n,steps=map(int,head[1:4]);v=list(map(float,head[4:]));dt,kf,alpha,start,total,decay,bottom,bal,residual,expected=v
  assert case==c['case'] and n==c['n'] and dt==.002 and steps==1000 and alpha==decay==0
  assert kf==(0 if case==1 else .2) and all(math.isfinite(x) for x in v)
  p=np.array([[float(x) for x in line.split()[2:]] for line in lines if line.startswith('PROFILE')]);assert p.shape==(n,4)
  assert np.isfinite(p).all() and (p[:,1:]>=0).all()
  h=40/n;C=p[:,1];assert np.max(np.abs(p[:,2]-.25*h*C))<1e-12
  assert np.max(np.abs(p[:,3]-1.3*kf*h*C))<1e-12
  assert abs(np.sum(p[:,2:])-total)<1e-12
  assert max(abs(total+bottom-start),abs(total-expected),abs(residual),bal)<1e-10
  if c['mode']==1:assert lines[-1]=='NINE_UNSUPPORTED_ATOMIC_REJECTIONS_PASS'
  truth=exact(n,kf,c['shape']);key=(c['optimization'],case,c['shape'],n,c['mode']);assert key not in profiles
  profiles[key]=C;measurements['/'.join(map(str,key))]=dict(l1=float(h*np.sum(np.abs(C-truth))),peak=float(np.max(C)),analytic_peak=float(np.max(truth)),peak_relative_deficit=float(1-np.max(C)/np.max(truth)))
  maxbal=max(maxbal,bal);maxcumul=max(maxcumul,abs(residual))
 ratios=[]
 for opt,case,shape,n,mode in profiles:
  key=(opt,case,shape,n,mode)
  if opt=='O0':assert np.max(np.abs(profiles[key]-profiles[('O2',case,shape,n,mode)]))<1e-12
  if mode==1:
   on=measurements['/'.join(map(str,key))];off=measurements['/'.join(map(str,(opt,case,shape,n,0)))];assert on['l1']<off['l1'],(key,on,off)
   ratios.append(on['l1']/off['l1'])
 return dict(status='BOUNDED_LINEAR_UNIFORM_ADVECTION_FCT_PROTOTYPE_O0_O2_PASS',profiles=64,unsupported_rejections=32*9,
             maximum_corrected_to_baseline_l1_ratio=max(ratios),max_step_mass_residual=maxbal,max_cumulative_mass_residual=maxcumul,measurements=measurements,
             production_activated=False,native_qualified=False,nonlinear_Freundlich_qualified=False,full_mc_sol01_closed=False)
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);ap.add_argument('--verify-only',action='store_true');a=ap.parse_args();out=a.output.resolve()
 if not a.verify_only:
  out.mkdir(parents=True,exist_ok=False);p=ROOT/'tests/support/augment_bartholomeus_backend_sources.py'
  spec=importlib.util.spec_from_file_location('deps',p);deps=importlib.util.module_from_spec(spec);spec.loader.exec_module(deps)
  sources,_=deps.strict_closure(ROOT,[str(HERE/'driver.f90')],[str(HERE/'mod_research_fct.f90')])
  report=dict(status='BUILDING',baseline=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),inputs={str(q.relative_to(ROOT)):sha(q) for q in [*sources,p,Path(__file__)]},provider_count=len(sources)-1,events=[],cases=[])
  def save():(out/'execution.json').write_text(json.dumps(report,indent=2)+'\n')
  def run(cmd,cwd):
   start=time.monotonic();cp=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=120);i=len(report['events'])
   for stream in ['stdout','stderr']:(out/f'{i:03d}.{stream}').write_bytes(getattr(cp,stream))
   e=dict(command=list(map(str,cmd)),returncode=cp.returncode,seconds=time.monotonic()-start,stdout=f'{i:03d}.stdout',stderr=f'{i:03d}.stderr');report['events'].append(e)
   if cp.returncode:report['status']='FAILED'
   save();assert cp.returncode==0,(e,cp.stdout[-1000:],cp.stderr[-1000:]);return e,cp.stdout
  save();fc=os.environ.get('FC','gfortran');run([fc,'--version'],out)
  for opt in ['O0','O2']:
   folder=out/opt;folder.mkdir();exe=folder/'fct'
   run([fc,'-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(folder),*sources,'-o',exe],folder)
   for case in [1,2]:
    for shape in [0,1]:
     for n in [40,80,160,320]:
      for mode in [0,1]:
       e,raw=run([exe,n,.002,case,mode,shape],folder);report['cases'].append(dict(**e,optimization=opt,case=case,shape=shape,n=n,mode=mode,sha256=hashlib.sha256(raw).hexdigest()));save()
  report['status']='EXECUTED';save()
 result=assess(out);(out/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='measurements'},indent=2))
if __name__=='__main__':main()
