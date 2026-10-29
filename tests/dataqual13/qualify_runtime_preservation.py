"""Source-verified incremental real Reference owner preservation, O0/O2.

The original static geometry fixture and unchanged production test assertions
are retained. Changed WOFOST owner imports/vtables and their dependent providers
are rebuilt; unrelated unchanged providers reuse their verified objects.
"""
import argparse,hashlib,json,re,shutil,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True)
a=p.parse_args();out=a.output.resolve();out.mkdir(exist_ok=False)
base=ROOT.parent/'dq13-groundwater-runtime-verified';old=json.loads((base/'RESULT.json').read_text());context=base/'context.f90'
programs=[ROOT/s for s in ['tests/dataqual13/groundwater_runtime_driver.f90','tests/fapp/test_ppa_wu01_production_application_bootstrap.f90','tests/physics/test_bartholomeus_application.f90']]
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
oldpaths={str(Path(k)if Path(k).is_absolute()else ROOT/k):(i,h)for i,(k,h)in enumerate(old['dependencies'].items())}
hashes={str(s):sha(s)for s in order+programs};events=[];artifacts={};changed_by_opt={}
def run(cmd,label,folder,timeout=120):
 t=time.perf_counter();r=subprocess.run(list(map(str,cmd)),capture_output=True,timeout=timeout);i=len(events)
 (folder/(str(i)+'.stdout')).write_bytes(r.stdout);(folder/(str(i)+'.stderr')).write_bytes(r.stderr)
 events.append(dict(label=label,command=list(map(str,cmd)),seconds=time.perf_counter()-t,returncode=r.returncode))
 (out/'EVENTS.json').write_text(json.dumps(events,indent=2));assert r.returncode==0,r.stderr.decode()+r.stdout.decode()
 return r.stdout
fc='/usr/bin/x86_64-linux-gnu-gfortran-13'
for opt in ['O0','O2']:
 f=out/opt;f.mkdir();oldbuild=base/opt
 for mod in oldbuild.glob('*.mod'):shutil.copyfile(mod,f/mod.name)
 flags=['-'+opt,'-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-I'+str(f),'-J'+str(f)]
 objects=[];changed=set()
 for i,s in enumerate(order):
  row=oldpaths.get(str(s))
  if row and row[1]==hashes[str(s)]and not(set(imports[s])&changed):
   obj=oldbuild/(str(row[0])+'.o');assert obj.is_file()and obj.stat().st_size>0
   artifacts[str(obj)]=sha(obj)
  else:
   changed.add(s);obj=f/(str(i)+'.o');run([fc,*flags,'-c',s,'-o',obj],'compile_changed',f)
   if obj.stat().st_size==0:run([fc,*flags,'-c',s,'-o',obj],'retry_empty_compiler_artifact',f)
   assert obj.stat().st_size>0
  objects.append(obj)
 changed_by_opt[opt]=[str(s)for s in order if s in changed]
 for driver in programs:
  exe=f/driver.stem;run([fc,*flags,driver,*objects,'-o',exe],'compile_link_existing_contract',f)
  raw=run([exe],'native_existing_contract',f,30);(f/(driver.stem+'.stdout')).write_bytes(raw)
  assert b'PASS'in raw or b'GATE PASS'in raw
  print(opt,driver.name,'PASS',flush=True)
assert all(sha(Path(s))==h for s,h in hashes.items())
assert all(sha(Path(s))==h for s,h in artifacts.items())
(out/'RESULT.json').write_text(json.dumps(dict(status='CURRENT_REFERENCE_GROUNDWATER_DEFAULT_AND_OXYGEN_PASS',source_sha256=hashes,events=events,changed_providers=changed_by_opt,reused_artifacts_sha256=artifacts),indent=2))
