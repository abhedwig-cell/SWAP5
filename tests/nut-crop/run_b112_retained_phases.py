"""Selected thermal phases using source- and artifact-bound stable providers."""
from pathlib import Path
import argparse,base64,hashlib,io,json,os,re,shlex,subprocess,tarfile,time
ROOT=Path(__file__).resolve().parents[2]
a=argparse.ArgumentParser();a.add_argument('--providers',type=Path,required=True);a.add_argument('--output',type=Path,required=True);args=a.parse_args()
BASE=args.providers.resolve();OUT=args.output.resolve();OUT.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
prior=json.loads((BASE/'result.json').read_text());events=json.loads((BASE/'events.json').read_text())
assert prior['status'] in ['B112_RETAINED_JOINT_PHYSICAL_PASS_NOT_ADMITTED','SURFACE_N_B1_ACTUAL_PHYSICAL_PASS_NOT_ADMITTED']
SURFACE_PROVIDERS=prior['status']=='SURFACE_N_B1_ACTUAL_PHYSICAL_PASS_NOT_ADMITTED'
if SURFACE_PROVIDERS:
 assert prior['days']==2 and prior['providers']==326
 assert all(e['returncode']==0 for e in events)
 assert sha(BASE/'generated_driver.f90')==prior['generated_driver_sha256']
inputs={}
for path,digest in prior['input_sha256'].items():
 p=ROOT/path
 assert p.is_file()and sha(p)==digest,path
 inputs[path]=digest
archive=ROOT/'integration/audits/evidence/MC_NUT01_ACCEPTED_THERMAL_20261015.tar.xz.b64';inputs[str(archive.relative_to(ROOT))]=sha(archive)
with tarfile.open(fileobj=io.BytesIO(base64.b64decode(archive.read_bytes())))as t:
 old={m.name:t.extractfile(m).read()for m in t if m.isfile()and m.name.startswith('joint/')}
(OUT/'original_thermal.f90').write_bytes(old['joint/drivers/test_thermal_joint.f90'])
for path,data in old.items():
 if path.startswith('joint/O0/')and path.endswith('.inc'):(OUT/Path(path).name).write_bytes(data)
records=[];artifacts={};result=dict(status='RUNNING',inputs=inputs,events=records,reused_artifacts=artifacts,runs={},provider_result_sha256=sha(BASE/'result.json'))
def save():(OUT/'result.json').write_text(json.dumps(result,indent=2)+'\n')
def run(command,b,kind):
 command=list(map(str,command));start=time.perf_counter();r=subprocess.run(command,cwd=b,capture_output=True);i=len(records)
 for stream in ['stdout','stderr']:(OUT/f'{i}.{stream}').write_bytes(getattr(r,stream))
 records.append(dict(category=kind,command=command,returncode=r.returncode,seconds=time.perf_counter()-start,stdout=f'{i}.stdout',stderr=f'{i}.stderr'));save()
 if r.returncode:raise RuntimeError(f'failed event {i}: '+r.stdout.decode()+r.stderr.decode())
 return r.stdout
providers={}
for p in (ROOT/'src').rglob('*.f90'):
 for name in re.findall(r'^\s*module\s+(\w+)\s*$',p.read_text(),re.M|re.I):
  assert name.lower()not in providers,name
  providers[name.lower()]=p
try:
 for opt in ('O0','O2'):
  b=OUT/opt;b.mkdir();base=BASE/opt
  for p in base.glob('*.mod'):artifacts[str(p)]=sha(p)
  ce=[e for e in events if e['category']=='compile'and e['returncode']==0 and '-'+opt in e['command']]
  objects=[]
  for obj in sorted(base.glob('*.o')):
   if obj.name.startswith('test_'):continue
   if SURFACE_PROVIDERS and any(Path(e['command'][-1])==obj and Path(e['command'][e['command'].index('-c')+1]).name=='test_surface_n_rotation.f90'for e in ce):continue
   artifacts[str(obj)]=sha(obj);objects.append(obj)
  for e in ce:
   p=Path(e['command'][e['command'].index('-c')+1])
   if p.is_relative_to(ROOT):assert sha(p)==inputs[str(p.relative_to(ROOT))]
  first=ce[0]['command'];fc=first[:first.index('-'+opt)];flags=first[first.index('-'+opt):first.index('-c')]
  flags=[('-J'+str(b)if x.startswith('-J')else x)for x in flags]+['-I'+str(b),'-I'+str(OUT),'-I'+str(ROOT/'tests/nut-material')]
  for name in ('matrix_fixture.inc','crop_oracle.inc','material_oracle.inc'):
   (b/name).write_bytes((base/name).read_bytes())
  seen=set();extra=[]
  def visit(p):
   for name in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',p.read_text(),re.M|re.I):
    name=name.lower()
    if name in seen or name in ('iso_fortran_env','iso_c_binding','ieee_arithmetic','ieee_exceptions','omp_lib')or(base/(name+'.mod')).exists():continue
    seen.add(name);q=providers[name];visit(q)
    if q not in extra:extra.append(q)
  drivers=[OUT/'original_thermal.f90',ROOT/'tests/nut-crop/test_b112_retained_thermal.f90',ROOT/'tests/nut-crop/test_b112_retained_empty.f90']
  for d in drivers:visit(d)
  for i,p in enumerate(extra):
   obj=b/f'extra-{i}.o';inputs[str(p.relative_to(ROOT))]=sha(p);run(fc+flags+['-c',p,'-o',obj],b,'provider_compile');objects.append(obj)
  row={}
  for driver in drivers:
   if driver.is_relative_to(ROOT):inputs[str(driver.relative_to(ROOT))]=sha(driver)
   obj=b/(driver.stem+'.o');exe=b/driver.stem
   run(fc+flags+['-c',driver,'-o',obj],b,'driver_compile');run(fc+flags+objects+[obj,'-o',exe],b,'link')
   if driver.stem=='test_b112_retained_empty':
    output=run([exe],b,'native');assert (b/'empty.bin').read_bytes()[:8]==b'S5NC0009'
    row[driver.stem]={'stdout':output.decode(),'sha256':sha(b/'empty.bin')};continue
   profiles=['manual','calendar']if driver.stem=='original_thermal'else['selected']
   for profile in profiles:
    name=driver.stem+'-'+profile;restart=b/(name+'-restart.bin');end=b/(name+'-expected.bin');fresh=b/(name+'-fresh.bin')
    output=run([exe,'write',restart,end,profile],b,'native');run([exe,'resume',restart,fresh,profile],b,'native')
    assert end.read_bytes()==fresh.read_bytes()==Path(str(end)+'.opaque').read_bytes()
    if driver.stem=='original_thermal':
     for suffix in ['restart.bin','expected.bin','fresh.bin','expected.bin.opaque']:
      assert(b/(name+'-'+suffix)).read_bytes()==old['joint/'+opt+'/thermal-'+profile+'-'+suffix],suffix
    else:
     for p,tag in [(Path(str(end)+'.initial'),11),(restart,12),(Path(str(end)+'.stages.harvest-pending'),16),(Path(str(end)+'.stages.consumed'),15)]:assert p.read_bytes()[:8]==f'S5NC{tag:04d}'.encode()
    row[name]=dict(stdout=output.decode(),restart_sha256=sha(restart),endpoint_sha256=sha(end))
  result['runs'][opt]=row
 assert result['runs']['O0']==result['runs']['O2']
 for path,digest in artifacts.items():assert sha(Path(path))==digest,path
 inputs[str(Path(__file__).relative_to(ROOT))]=sha(Path(__file__))
 result['cost_seconds']={c:sum(e['seconds']for e in records if e['category']==c)for c in {e['category']for e in records}}
 result['status']='B112_THERMAL_PHASES_AND_ORIGINAL_BYTES_PASS'
except Exception:
 result['status']='FAILED';save();raise
save();print(result['status'])
