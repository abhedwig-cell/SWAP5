"""Fresh original thermal native assertions using this live qualification build.

No inherited PASS: source/compiler/flags/artifacts are bound, only providers
are reused, and original archived drivers execute afresh at O0/O2.
"""
from pathlib import Path
import argparse,base64,hashlib,io,json,os,re,shlex,shutil,subprocess,tarfile,time
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--providers',required=True,type=Path);p.add_argument('--output',required=True,type=Path);p.add_argument('--pin',required=True);a=p.parse_args()
BASE=a.providers.resolve();OUT=a.output.resolve();OUT.mkdir(parents=True,exist_ok=False)
assert subprocess.check_output(['git','diff',a.pin,'--','src'],cwd=ROOT)==b''
prior=json.loads((BASE/'result.json').read_text());assert prior['status']=='PASS'
events=json.loads((BASE/'events.json').read_text());record=[]
sha=lambda b:hashlib.sha256(b).hexdigest()
inputs={str(Path(__file__).relative_to(ROOT)):sha(Path(__file__).read_bytes())}
for path,digest in prior['input_sha256'].items():
 q=ROOT/path
 if q.is_file():assert sha(q.read_bytes())==digest,path
archive=ROOT/'integration/audits/evidence/MC_NUT01_ACCEPTED_THERMAL_20261015.tar.xz.b64'
inputs[str(archive.relative_to(ROOT))]=sha(archive.read_bytes())
with tarfile.open(fileobj=io.BytesIO(base64.b64decode(archive.read_bytes())))as t:
 archived={m.name:t.extractfile(m).read()for m in t if m.isfile()and m.name.startswith('joint/')}
driver=OUT/'test_thermal_joint.f90';driver.write_bytes(archived['joint/drivers/test_thermal_joint.f90'])
for path,data in archived.items():
 if path.startswith('joint/O0/')and path.endswith('.inc'):(OUT/Path(path).name).write_bytes(data)
for path in ['tests/nut-crop/crop_fixture.inc','tests/nut-material/material_fixture.inc']:
 inputs[path]=sha((ROOT/path).read_bytes());shutil.copyfile(ROOT/path,OUT/Path(path).name)
modules={}
for q in (ROOT/'src').rglob('*.f90'):
 for name in re.findall(r'^\s*module\s+(\w+)\s*$',q.read_text(),re.I|re.M):modules[name.lower()]=q
result=dict(status='RUNNING',provider_pin=a.pin,provider_execution_commit=prior['execution_commit'],inputs=inputs,events=record,runs={},artifacts={})
def save():(OUT/'result.json').write_text(json.dumps(result,indent=2)+'\n')
def run(cmd,cwd,kind):
 cmd=list(map(str,cmd));start=time.perf_counter()
 if kind=='native':Path(cmd[0]).chmod(Path(cmd[0]).stat().st_mode|0o111)
 r=subprocess.run(cmd,cwd=cwd,capture_output=True);i=len(record)
 for stream in ['stdout','stderr']:(OUT/f'{i}.{stream}').write_bytes(getattr(r,stream))
 record.append(dict(command=cmd,category=kind,exit=r.returncode,seconds=time.perf_counter()-start,stdout=f'{i}.stdout',stderr=f'{i}.stderr'));save()
 if r.returncode:raise RuntimeError('retained failed thermal preservation event'+str(i))
 return r.stdout
try:
 for opt in ['O0','O2']:
  b=BASE/opt;work=OUT/opt;work.mkdir()
  compile_events=[e for e in events if e['category']=='compile'and e['returncode']==0 and '-'+opt in e['command']]
  objects=[]
  for e in compile_events:
   q=Path(e['command'][e['command'].index('-c')+1]);obj=Path(e['command'][e['command'].index('-o')+1])
   assert q.is_file()and obj.is_file()
   if q.is_relative_to(ROOT):
    path=str(q.relative_to(ROOT));assert q.read_bytes()==subprocess.check_output(['git','show',a.pin+':'+path],cwd=ROOT)
    inputs[path]=sha(q.read_bytes())
   result['artifacts'][str(obj)]=sha(obj.read_bytes());objects.append(obj)
  for q in b.glob('*.mod'):result['artifacts'][str(q)]=sha(q.read_bytes())
  first=compile_events[0]['command'];fc=first[:first.index('-'+opt)]
  flags=first[first.index('-'+opt):first.index('-c')]
  flags=[('-J'+str(work)if x.startswith('-J')else x)for x in flags]+['-I'+str(work),'-I'+str(OUT)]
  seen=set();extra=[]
  def visit(name):
   if name in seen or (b/(name+'.mod')).exists():return
   if name in ['iso_fortran_env','iso_c_binding','ieee_arithmetic','ieee_exceptions','omp_lib']:return
   seen.add(name);q=modules[name]
   for child in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',q.read_text(),re.I|re.M):visit(child.lower())
   if q not in extra:extra.append(q)
  for name in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',driver.read_text(),re.I|re.M):visit(name.lower())
  for i,q in enumerate(extra):
   inputs[str(q.relative_to(ROOT))]=sha(q.read_bytes());obj=work/f'extra-{i}.o'
   run(fc+flags+['-c',q,'-o',obj],work,'extra_provider_compile');objects.append(obj)
  obj=work/'driver.o';exe=work/'thermal'
  run(fc+flags+['-c',driver,'-o',obj],work,'driver_compile');run(fc+['-'+opt,'-fopenmp']+objects+[obj,'-o',exe],work,'link')
  row={}
  for profile in ['manual','calendar']:
   first=work/(profile+'-restart.bin');end=work/(profile+'-expected.bin');fresh=work/(profile+'-fresh.bin')
   run([exe,'write',first,end,profile],work,'native');run([exe,'resume',first,fresh,profile],work,'native')
   assert end.read_bytes()==fresh.read_bytes()==Path(str(end)+'.opaque').read_bytes()
   for suffix in ['restart.bin','expected.bin','fresh.bin','expected.bin.opaque']:
    q=work/(profile+'-'+suffix)
    assert q.read_bytes()==archived['joint/'+opt+'/thermal-'+profile+'-'+suffix],q
   row[profile]=dict(restart_sha256=sha(first.read_bytes()),endpoint_sha256=sha(end.read_bytes()))
  result['runs'][opt]=row
 for opt in ['O0','O2']:
  for profile in ['manual','calendar']:assert result['runs'][opt][profile]==result['runs']['O0']['manual']
 for path,digest in result['artifacts'].items():assert sha(Path(path).read_bytes())==digest,path
 result['status']='ORIGINAL_THERMAL_NATIVE_FRESH_EXECUTION_BYTE_PRESERVED'
 result['cost_seconds']={c:sum(e['seconds']for e in record if e['category']==c)for c in {e['category']for e in record}}
except Exception:
 result['status']='FAILED';save();raise
save();print(json.dumps(dict(status=result['status'],cost_seconds=result['cost_seconds']),indent=2))
