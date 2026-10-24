"""Discriminate allocation policies using the unchanged production finite donor."""
from pathlib import Path
import argparse,subprocess,os,itertools,json,hashlib,time
import numpy as np
from scipy.integrate import solve_ivp
ROOT=Path(__file__).resolve().parents[3]
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(exist_ok=False)
fc=os.environ.get('FC','gfortran');events=[];results={}
cases=list(itertools.product([0.,.001,.01],[0.,.001,.005],[.01,.02],[.01,.03],[-.03,0.,.03]))
sources=['src/process/mod_b111_soil_n_transport.f90','src/process/mod_n_constant_sink_partition.f90','integration/mc-nut01/competing_sinks/research.f90']
def run(cmd,kind,data=None):
 t=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=out,input=data,capture_output=True)
 e=dict(command=list(map(str,cmd)),kind=kind,seconds=time.monotonic()-t,returncode=r.returncode)
 for k in ['stdout','stderr']:
  name=f'{len(events):03d}.{k}';(out/name).write_bytes(getattr(r,k));e[k]=name
 events.append(e);(out/'events.json').write_text(json.dumps(events,indent=2)+'\n');assert r.returncode==0,(e,r.stderr.decode());return r.stdout
payload=''.join(' '.join(map(str,x))+'\n'for x in cases).encode();(out/'input.txt').write_bytes(payload)
for opt in ['O0','O2']:
 b=out/opt;b.mkdir();exe=b/'research'
 run([fc,'-'+opt,'-fcheck=all','-ffpe-trap=invalid,zero,overflow','-ffree-line-length-none','-J'+str(b),*[ROOT/s for s in sources],'-o',exe],'compile')
 raw=run([exe],'native',payload);results[opt]=np.array([list(map(float,l.split()))for l in raw.splitlines()])
 contract=b/'contract'
 run([fc,'-'+opt,'-fcheck=all','-ffpe-trap=invalid,zero,overflow','-ffree-line-length-none','-J'+str(b),ROOT/sources[1],ROOT/'integration/mc-nut01/competing_sinks/test_partition.f90','-o',contract],'contract_compile')
 assert b'PARTITION_CONTRACT_PASS' in run([contract],'contract_native')
assert np.max(abs(results['O0']-results['O2']))<1e-12
worst=0.;differences=0
for x,row in zip(cases,results['O0']):
 c0,loading,top,crop,h=x;ce,ca,tau,total,pt,pc,tt,tc,ct,cc,book=row
 def rhs(t,y):return [(loading-top-crop-(.3*h+.002+.04*.3*(.3+.5*h))*y[0])/(.3*(.3+h*t)),y[0]]
 def zero(t,y):return y[0]
 zero.terminal=True;zero.direction=-1
 if c0==0.:en=av=et=0.
 else:
  s=solve_ivp(rhs,[0.,1.],[c0,0.],events=zero,rtol=2.3e-14,atol=1e-17,method='DOP853',max_step=1/32)
  assert s.success and len(s.t_events[0])==1
  en=0.;av=s.y[1,-1];et=s.t[-1]
 err=max(abs(ce-en),abs(ca-av),abs(tau-et));worst=max(worst,err);assert err<2e-12
 assert tau<1. and abs(book)<1e-12
 assert abs(pt-(top*tau+loading*(1-tau)*top/(top+crop)))<1e-12
 assert abs(pc-(crop*tau+loading*(1-tau)*crop/(top+crop)))<1e-12
 for a,b in [(pt,pc),(tt,tc),(ct,cc)]:assert min(a,b)>=0. and a<=top+1e-12 and b<=crop+1e-12 and abs(a+b-total)<1e-12
 if max(pc,tc,cc)-min(pc,tc,cc)>1e-12:differences+=1
assert differences>0
sha=lambda b:hashlib.sha256(b).hexdigest()
r=dict(status='RESEARCH_ALLOCATION_NONUNIQUENESS_DEMONSTRATED',cases_per_optimization=len(cases),different_crop_receipts=differences,max_ode_error=worst,max_balance_residual=float(max(abs(results['O0'][:,-1]))),production_activated=False,canonically_admitted=False,source_sha256={s:sha((ROOT/s).read_bytes())for s in sources+[str(Path(__file__).relative_to(ROOT))]},compiler=subprocess.check_output([fc,'--version'],text=True).splitlines()[0])
(out/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
