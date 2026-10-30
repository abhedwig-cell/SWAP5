"""Source-verified clean real Reference owner preservation, O0/O2.

The original static geometry fixture and unchanged production test assertions
are retained. All providers are rebuilt from repository sources; no vanished scratch artifacts
or objects from a different compiler are reused.
"""
import argparse,hashlib,json,re,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--compiler',type=Path,default=Path('/usr/bin/x86_64-linux-gnu-gfortran-13'))
a=p.parse_args();out=a.output.resolve();out.mkdir(exist_ok=False)
context=out/'context.f90'
fixture=ROOT/'tests/fsi/fsi04_real_headcalc_stubs.f90'
context.write_text(fixture.read_text().replace('real(8), parameter :: disnod(numnod+1) = 1.0d0','real(8), parameter :: disnod(numnod+1) = [0.25d0,0.5d0,0.75d0,1d0,0.5d0]').replace('cofgen = 0.30d0',"error stop 'hidden global cofgen'").replace('watcon = 0.30d0',"error stop 'hidden global watcon'").replace('hconduc = 1.0d0',"error stop 'hidden global hconduc'"),newline='\n')
programs=[ROOT/s for s in ['tests/dataqual13/groundwater_runtime_driver.f90','tests/dataqual15/groundwater_table_runtime_driver.f90','tests/fapp/test_ppa_wu01_production_application_bootstrap.f90','tests/physics/test_bartholomeus_application.f90']]
providers={}
for s in list((ROOT/'src').rglob('*.f90'))+[context]:
 for name in re.findall(r'^\s*module\s+(\w+)\s*$',s.read_text(),re.M|re.I):
  assert name.lower()not in providers,(name,s)
  providers[name.lower()]=s
order=[];seen=set();imports={}
def visit(s):
 if s in seen:return
 seen.add(s);children=[]
 for name in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',s.read_text(),re.M|re.I):
  key=name.lower()
  if key in ['iso_fortran_env','iso_c_binding','ieee_arithmetic','ieee_exceptions','omp_lib']:continue
  assert key in providers,(key,s)
  if providers[key]!=s:children.append(providers[key]);visit(providers[key])
 imports[s]=children;order.append(s)
for s in programs:visit(s)
visit(ROOT/'src/legacy/b1_10_port/headcalc.f90');order=[s for s in order if s not in programs]
hashes={str(s):sha(s)for s in order+programs+[fixture]};events=[];artifacts={};changed_by_opt={}
def run(cmd,label,folder,timeout=120):
 t=time.perf_counter();r=subprocess.run(list(map(str,cmd)),capture_output=True,timeout=timeout);i=len(events)
 (folder/(str(i)+'.stdout')).write_bytes(r.stdout);(folder/(str(i)+'.stderr')).write_bytes(r.stderr)
 events.append(dict(label=label,command=list(map(str,cmd)),seconds=time.perf_counter()-t,returncode=r.returncode))
 (out/'EVENTS.json').write_text(json.dumps(events,indent=2));assert r.returncode==0,r.stderr.decode()+r.stdout.decode()
 return r.stdout
fc=str(a.compiler.resolve())
for opt in ['O0','O2']:
 f=out/opt;f.mkdir()
 flags=['-'+opt,'-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-I'+str(f),'-J'+str(f)]
 objects=[];changed=set()
 for i,s in enumerate(order):
  changed.add(s);obj=f/(str(i)+'.o');run([fc,*flags,'-c',s,'-o',obj],'compile',f)
  if obj.stat().st_size==0:run([fc,*flags,'-c',s,'-o',obj],'retry_empty_compiler_artifact',f)
  assert obj.stat().st_size>0
  objects.append(obj)
 changed_by_opt[opt]=[str(s)for s in order if s in changed]
 for driver in programs:
  exe=f/driver.stem
  response=f/(driver.stem+'.args');response.write_text('\n'.join(chr(34)+str(x).replace(chr(92),'/')+chr(34)for x in [*flags,driver,*objects,'-o',exe]),newline='\n')
  run([fc,'@'+str(response)],'compile_link_existing_contract',f)
  raw=run([exe],'native_existing_contract',f,30);(f/(driver.stem+'.stdout')).write_bytes(raw)
  assert b'PASS'in raw or b'GATE PASS'in raw
  print(opt,driver.name,'PASS',flush=True)
assert all(sha(Path(s))==h for s,h in hashes.items())
assert all(sha(Path(s))==h for s,h in artifacts.items())
(out/'RESULT.json').write_text(json.dumps(dict(status='CURRENT_REFERENCE_GROUNDWATER_DEFAULT_AND_OXYGEN_PASS',source_sha256=hashes,events=events,changed_providers=changed_by_opt,reused_artifacts_sha256=artifacts),indent=2))
