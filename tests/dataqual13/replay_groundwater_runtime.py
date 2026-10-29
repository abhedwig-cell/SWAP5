"""Reuse source-verified current providers for stronger owner and default checks."""
import hashlib,json,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];base=ROOT.parent/'dq13-groundwater-runtime-verified';out=ROOT.parent/'dq13-groundwater-owner-checks';out.mkdir(exist_ok=False)
meta=json.loads((base/'RESULT.json').read_text());driver='tests/dataqual13/groundwater_runtime_driver.f90'
for p,h in meta['dependencies'].items():
 if p==driver:continue
 file=Path(p)if Path(p).is_absolute()else ROOT/p
 assert hashlib.sha256(file.read_bytes()).hexdigest()==h,p
events=[]
for opt in ['O0','O2']:
 f=base/opt;objects=sorted(f.glob('*.o'),key=lambda p:int(p.stem))[:-1]
 for name,source in [('groundwater',ROOT/driver),('default',ROOT/'tests/fapp/test_ppa_wu01_production_application_bootstrap.f90')]:
  exe=out/(opt+'-'+name);t=time.perf_counter();r=subprocess.run(['/usr/bin/x86_64-linux-gnu-gfortran-13','-'+opt,'-fcheck=all','-ffree-line-length-none','-fopenmp','-I'+str(f),'-J'+str(f),str(source),*map(str,objects),'-o',str(exe)],capture_output=True);(out/(opt+'-'+name+'.compile.stderr')).write_bytes(r.stderr);assert r.returncode==0,r.stderr.decode()
  r=subprocess.run([str(exe)],capture_output=True,timeout=30);(out/(opt+'-'+name+'.stdout')).write_bytes(r.stdout);(out/(opt+'-'+name+'.stderr')).write_bytes(r.stderr);events.append(dict(optimization=opt,case=name,returncode=r.returncode,seconds=time.perf_counter()-t,source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),providers_sha256={str(p):hashlib.sha256(p.read_bytes()).hexdigest()for p in objects}));assert r.returncode==0,r.stdout.decode()+r.stderr.decode();print(opt,name,'PASS',flush=True)
(out/'RESULT.json').write_text(json.dumps(dict(status='FMR_GROUNDWATER_OWNER_AND_DEFAULT_PASS',events=events),indent=2))
