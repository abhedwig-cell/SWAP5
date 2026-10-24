"""Real daily juvenile NH4/NO3 opt-in partition and default preservation."""
from pathlib import Path
import base64,hashlib,io,json,os,subprocess,tarfile,argparse,time
import numpy as np
from scipy.integrate import solve_ivp
ROOT=Path(__file__).resolve().parents[3];p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);out=p.parse_args().output.resolve();out.mkdir(exist_ok=False)
fc=os.environ.get('FC','gfortran');events=[];sha=lambda b:hashlib.sha256(b).hexdigest()
with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/'integration/mc-nut01/crop_only_depletion/EVIDENCE.tar.xz.b64').read_bytes())))as t:old=json.load(t.extractfile('direct/input.json'))
cases=[]
for x in old['cases']:
 for top in [.001,.01]:
  y=list(x);y[20]=top;y[21]=top;cases.append(y)
payload=lambda rows:''.join(' '.join(map(str,x))+' '+str(mode)+'\n'for x,mode in rows).encode()
def run(cmd,kind,data=None):
 start=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=out,input=data,capture_output=True);e=dict(command=list(map(str,cmd)),category=kind,seconds=time.monotonic()-start,returncode=r.returncode)
 for k in ['stdout','stderr']:
  name=f'{len(events):03d}.{k}';(out/name).write_bytes(getattr(r,k));e[k]=name
 events.append(e);(out/'events.json').write_text(json.dumps(events,indent=2));assert r.returncode==0,(e,r.stderr.decode());return r.stdout
paths=['src/process/mod_n_constant_sink_partition.f90','src/process/mod_b111_soil_n_transport.f90','src/process/mod_b111_soil_n_daily_exchange.f90','tests/nut-reactive/test_crop_depletion.f90']
outputs={}
for opt in ['O0','O2']:
 for version in ['current','baseline']:
  b=out/(opt+'-'+version);b.mkdir();driver=(ROOT/paths[3]).read_text()
  if version=='current':driver=driver.replace('f%nondepleting_top=mode==1.or.mode==2','f%proportional_constant_sinks=mode==4\n  f%nondepleting_top=mode==1.or.mode==2.or.mode==4')
  (b/'driver.f90').write_text(driver)
  source=(ROOT/paths[2]).read_bytes()if version=='current'else subprocess.check_output(['git','show','d13ef5288c4df8f96f675dd6e5df8ef04062367e:'+paths[2]],cwd=ROOT)
  (b/'exchange.f90').write_bytes(source);exe=b/'daily'
  run([fc,'-'+opt,'-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(b),ROOT/paths[0],ROOT/paths[1],b/'exchange.f90',b/'driver.f90','-o',exe],'compile')
  rows=[(x,1)for x in old['cases']+old['common']]+[(x,0)for x in old['default']]
  preserved=run([exe],'incumbent_'+version,payload(rows))
  if version=='current':
   incumbent=preserved;raw=run([exe],'opt_in',payload([(x,4)for x in cases]));outputs[opt]=np.array([list(map(float,l.split()))for l in raw.splitlines()]);(out/'input.json').write_text(json.dumps(cases))
   invalid=[]
   for slot,value in [(19,-.001),(13,2.),(12,1.),(7,0.),(1,0.)]:
    x=list(cases[0]);x[slot]=value;invalid.append((x,4))
   assert all(int(l.split()[0])!=0 for l in run([exe],'invalid_opt_in',payload(invalid)).splitlines())
  else:assert preserved==incumbent,'default or old signed result changed'
assert np.max(abs(outputs['O0']-outputs['O2']))<1e-12
worst=balance=0.
for x,row in zip(cases,outputs['O0']):
 assert row[0]==0;v=row[1:];dz,dt,w0,wt,qo,qr,qb,qt,ql,tcs,rd,D,dvs,lai,crit,rho,K,kn,kd,R,ctn,ctd,cn,cd=x[:24];ln,ld,bn,bd=x[24:];h=wt-w0;wa=.5*(wt+w0);j=(crit-lai)/crit;rf=max(1.,rd*.01/dz)
 def form(c0,source,crop,root,k,sorp,lat,bot,ctop):
  top=-qt*ctop;positive=dz*source+qb*bot+ql*lat
  def rhs(t,y):return [(positive-top-crop-(dz*h+qo+root*qr+k*wa*dz)*y[0])/(dz*(w0+rho*sorp+h*t)),y[0]]
  def zero(t,y):return y[0]
  zero.terminal=True;zero.direction=-1
  if c0==0 and positive<top+crop:ce=ca=tau=0.
  else:
   s=solve_ivp(rhs,[0.,1.],[c0,0.],events=zero,method='DOP853',rtol=2.3e-14,atol=1e-17,max_step=1/32);assert s.success;tau=s.t[-1];ca=s.y[1,-1];ce=0. if len(s.t_events[0])else s.y[0,-1]
  factor=tau+positive*(1-tau)/(top+crop)if top+crop else 1.
  return ce,ca,root*qr*ca+crop*factor,top*factor,k*wa*dz*ca
 rn=tcs*(wa+rho*K)/wa*(1-j)*rf;rdn=tcs*(1-j)*rf
 en,an,un,tn,nit=form(cn,R,j*D,rn,kn,K,ln,bn,ctn)
 ed,ad,ud,td,den=form(cd,nit/dz,j*(D-un),rdn,kd,0.,ld,bd,ctd)
 expected=[en,an,ed,ad,un,ud,nit,den,-tn,-td,-qt*ctn-tn,-qt*ctd-td]
 error=max(abs(v[:12]-expected));worst=max(worst,error);assert error<2e-12,(error,x,v,expected)
 residual=dz*((w0+rho*K)*cn+w0*cd+R)-dz*((wt+rho*K)*v[0]+wt*v[2])+v[12]-v[13];balance=max(balance,abs(residual));assert abs(residual)<1e-12
r=dict(status='JUVENILE_DAILY_PROPORTIONAL_O0_O2_PASS',cases_per_optimization=len(cases),incumbent_byte_exact=len(rows),max_ode_error=worst,max_mass_residual=balance,production_activated_by_default=False,canonically_admitted=False,input_sha256={p:sha((ROOT/p).read_bytes())for p in paths+[str(Path(__file__).relative_to(ROOT))]});(out/'result.json').write_text(json.dumps(r,indent=2));print(json.dumps(r))
