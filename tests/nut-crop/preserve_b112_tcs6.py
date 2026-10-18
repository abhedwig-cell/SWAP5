"""Execute incumbent TCS6 native trajectories with current source-bound providers."""
from pathlib import Path
import argparse,base64,hashlib,io,json,os,shlex,subprocess,tarfile,time
ROOT=Path(__file__).resolve().parents[2];a=argparse.ArgumentParser();a.add_argument('--providers',type=Path,required=True);a.add_argument('--output',type=Path,required=True);args=a.parse_args();BASE=args.providers.resolve();OUT=args.output.resolve();OUT.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();prior=json.loads((BASE/'result.json').read_text());assert prior['status'] in ['B112_RETAINED_JOINT_PHYSICAL_PASS_NOT_ADMITTED','SURFACE_N_B1_ACTUAL_PHYSICAL_PASS_NOT_ADMITTED']
SURFACE_PROVIDERS=prior['status']=='SURFACE_N_B1_ACTUAL_PHYSICAL_PASS_NOT_ADMITTED'
if SURFACE_PROVIDERS:
 assert prior['days']==2 and prior['providers']==326
 assert all(e['returncode']==0 for e in json.loads((BASE/'events.json').read_text()))
 assert sha(BASE/'generated_driver.f90')==prior['generated_driver_sha256']
for path,h in prior['input_sha256'].items():assert sha(ROOT/path)==h,path
archive=ROOT/'integration/audits/evidence/MC_IRR01_TCS6_SCIENCE_20261016.tar.xz.b64'
with tarfile.open(fileobj=io.BytesIO(base64.b64decode(archive.read_bytes())))as t:old={m.name:t.extractfile(m).read()for m in t if m.isfile()and m.name.startswith('physical/')}
for path,raw in old.items():
 if path.startswith('physical/fixture/')or path in ['physical/weekly_dcs1.f90','physical/weekly_dcs2.f90','physical/weekly_nontrigger.f90']:
  q=OUT/path.removeprefix('physical/');q.parent.mkdir(exist_ok=True);q.write_bytes(raw)
record=json.loads(old['physical/RESULTS.json']);inp=json.loads(old['physical/INPUTS.json']);origin=json.loads((BASE/'events.json').read_text());mapping={}
for e in origin:
 if e['category']=='compile'and'-O0'in e['command']:
  p=Path(e['command'][e['command'].index('-c')+1])
  if p.is_relative_to(ROOT):mapping[str(p.relative_to(ROOT))]=Path(e['command'][-1]).name
fixture_order=[]
for e in record['events']:
 if '-c'in e['command']:
  p=Path(e['command'][e['command'].index('-c')+1])
  if p.parent.name=='fixture'and p.name not in fixture_order:fixture_order.append(p.name)
events=[];result={'status':'RUNNING','input_sha256':dict(prior['input_sha256']),'archive_sha256':sha(archive),'events':events,'runs':[],'artifacts':{}}
def save():(OUT/'result.json').write_text(json.dumps(result,indent=2)+'\n')
def run(command,b,category):
 command=list(map(str,command));start=time.perf_counter();r=subprocess.run(command,cwd=b,capture_output=True);i=len(events)
 for stream in ['stdout','stderr']:(OUT/f'{i}.{stream}').write_bytes(getattr(r,stream))
 events.append(dict(category=category,command=command,returncode=r.returncode,seconds=time.perf_counter()-start,stdout=f'{i}.stdout',stderr=f'{i}.stderr'));save()
 if r.returncode:raise RuntimeError(str(i)+r.stdout.decode()+r.stderr.decode())
 return r.stdout
for opt in [0,2]:
 b=OUT/f'o{opt}';b.mkdir();base=BASE/f'O{opt}'
 for module in base.glob('*.mod'):result['artifacts'][str(module)]=sha(module)
 fc=shlex.split(os.environ['FC']);flags=inp['flags']+[f'-O{opt}','-J'+str(b),'-I'+str(b),'-I'+str(base)];objects=[]
 for path in inp['providers']:
  if path=='tests/fsi/fsi04_real_headcalc_stubs.f90':continue
  q=base/mapping[path];assert q.exists();objects.append(q);result['artifacts'][str(q)]=sha(q)
 # Current canonical added calendar, DRAMET3 and frost providers to the
 # shared native adapter/backend closure. Reuse their checked joint objects
 # too; the historical TCS6 provider list alone is no longer link-complete.
 for path,objname in mapping.items():
  if path.startswith('src/'):
   q=base/objname
   if q not in objects:objects.append(q);result['artifacts'][str(q)]=sha(q)
 for i,name in enumerate(fixture_order):
  q=OUT/'fixture'/name;obj=b/f'oracle-{i}.o';run(fc+flags+['-c',q,'-o',obj],b,'fixture_compile');objects.append(obj)
 for name in ['weekly_dcs1','weekly_dcs2','weekly_nontrigger']:
  q=OUT/(name+'.f90');obj=b/(name+'.o');exe=b/('test-'+name);run(fc+flags+['-c',q,'-o',obj],b,'driver_compile');run(fc+flags+[obj]+objects+['-o',exe],b,'link')
  fixture=OUT/'fixture'
  for mode,phase in [('continuous','neutral')]+[(m,p)for p in ['neutral','hydraulic']for m in ['native-write','native-resume','native-write-active','native-resume-active']]:
   raw=run([exe,*[fixture/p for p in ['weather.999','altered.999','bad.999','backup.999']],mode,phase],b,'native')
   expected=next(x for x in record['results']if(x['opt'],x['driver'],x['mode'],x['moisture'])==(opt,name,mode,phase));assert hashlib.sha256(raw).hexdigest()==expected['stdout_sha256']
   result['runs'].append(dict(opt=opt,driver=name,mode=mode,phase=phase,stdout_sha256=hashlib.sha256(raw).hexdigest()))
  for phase in ['morning','dayend']:
   paths=[Path(str(exe)+'.'+phase+'.'+s)for s in ['full','opaque','resumed','active.resumed']];assert all(p.read_bytes()==paths[0].read_bytes()for p in paths)
   assert paths[0].read_bytes()==old[f'physical/o{opt}/'+paths[0].name]
for path,h in result['artifacts'].items():assert sha(Path(path))==h,path
result['input_sha256'][str(Path(__file__).relative_to(ROOT))]=sha(Path(__file__));result['status']='B112_CURRENT_TCS6_54_NATIVE_AND_ENDPOINT_BYTES_PASS';result['cost_seconds']={c:sum(e['seconds']for e in events if e['category']==c)for c in {e['category']for e in events}};save();print(result['status'])
