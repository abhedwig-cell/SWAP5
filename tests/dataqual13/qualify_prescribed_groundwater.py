"""Small real Reference solver closure, no replacement hydraulic calculation."""
import json,re,subprocess,time,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];out=ROOT.parent/'dq13-groundwater-e';out.mkdir(exist_ok=False)
driver=ROOT/'tests/dataqual13/prescribed_groundwater_driver.f90';stub=ROOT/'tests/fsi/fsi04_real_headcalc_stubs.f90'
# Trap legacy global hydraulic reads; active calculations must use the
# explicit production provider. Geometry and no-physics linker entries only.
original_stub=stub
stub=out/'context.f90'
stub.write_text(original_stub.read_text().replace('cofgen = 0.30d0',"error stop 'hidden global cofgen'").replace('watcon = 0.30d0',"error stop 'hidden global watcon'").replace('hconduc = 1.0d0',"error stop 'hidden global hconduc'"))
mapping={}
for p in list((ROOT/'src').rglob('*.f90'))+[stub]:
 for name in re.findall(r'^\s*module\s+(\w+)\s*$',p.read_text(),re.M|re.I):mapping[name.lower()]=p
ordered=[];seen=set()
def visit(p):
 if p in seen:return
 seen.add(p)
 for name in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',p.read_text(),re.M|re.I):
  if name.lower()in mapping and mapping[name.lower()]!=p:visit(mapping[name.lower()])
 ordered.append(p)
visit(driver);ordered.remove(driver);ordered+=[ROOT/'src/legacy/b1_10_port/headcalc.f90',driver];events=[]
for opt in ['O0','O2']:
 build=out/opt;build.mkdir();objects=[]
 for i,p in enumerate(ordered):
  obj=build/(str(i)+'.o');cmd=['/usr/bin/x86_64-linux-gnu-gfortran-13','-'+opt,'-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-I'+str(build),'-J'+str(build),'-c',str(p),'-o',str(obj)];t=time.perf_counter();r=subprocess.run(cmd,capture_output=True);events.append(dict(source=str(p.relative_to(ROOT))if p.is_relative_to(ROOT)else str(p),optimization=opt,seconds=time.perf_counter()-t,returncode=r.returncode));(build/(str(i)+'.stderr')).write_bytes(r.stderr)
  if r.returncode:raise RuntimeError(r.stderr.decode())
  objects.append(obj)
 r=subprocess.run(['/usr/bin/x86_64-linux-gnu-gfortran-13','-fopenmp',*map(str,objects),'-o',str(build/'test')],capture_output=True);(build/'link.stderr').write_bytes(r.stderr);assert r.returncode==0,r.stderr.decode()
 r=subprocess.run([str(build/'test')],capture_output=True,timeout=30);(build/'stdout').write_bytes(r.stdout);(build/'stderr').write_bytes(r.stderr);print(opt,r.returncode,r.stdout.decode(),flush=True)
 if r.returncode:raise RuntimeError(r.stderr.decode())
(out/'RESULT.json').write_text(json.dumps(dict(status='DIRECT_REFERENCE_GROUNDWATER_PASS',events=events,dependencies={str(p.relative_to(ROOT))if p.is_relative_to(ROOT)else str(p):hashlib.sha256(p.read_bytes()).hexdigest()for p in ordered}),indent=2))
