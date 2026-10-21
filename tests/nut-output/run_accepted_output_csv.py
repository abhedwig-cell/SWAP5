"""Render the actual accepted row through the real CSV exporter on pinned objects."""
from pathlib import Path
import argparse,hashlib,json,os,resource,subprocess,time
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--physical',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
physical=a.physical.resolve();OUT=a.output.resolve();OUT.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
proof=json.loads((physical/'result.json').read_text());assert proof['status']=='ACTUAL_TWO_DAY_ACCEPTED_OUTPUT_O0_O2_FRESH_CONTINUATION_PASS'
for name,h in proof['input_sha256'].items():assert sha(ROOT/name)==h,name
soft,hard=resource.getrlimit(resource.RLIMIT_STACK);resource.setrlimit(resource.RLIMIT_STACK,(64*1024*1024,hard))
s=(physical/'driver.f90').read_text().replace(' use mod_crop_soil_n_output_observation',' use mod_crop_ext_csv_file\n use mod_crop_soil_n_output_observation',1)
anchor="  call require(output_code==0,'accepted real formatted row')"
assert s.count(anchor)==1
s=s.replace(anchor,anchor+'''
  call write_crop_ext_csv_file(trim(endpoint)//'.csv',[character(10)::'1900-01-03'], &
    [output_row],diagnostic,output_code)
  call require(output_code==0,'actual accepted complete CSV generation')
''',1)
(OUT/'driver.f90').write_text(s)
events=[];results={};provider_objects={};prior=json.loads((physical/'events.json').read_text())
def run(cmd,b,category):
 cmd=list(map(str,cmd));t=time.perf_counter();r=subprocess.run(cmd,cwd=b,capture_output=True);i=len(events)
 for key in ['stdout','stderr']:(OUT/f'{i:04d}.{key}').write_bytes(getattr(r,key))
 events.append(dict(command=cmd,category=category,returncode=r.returncode,seconds=time.perf_counter()-t,stdout=f'{i:04d}.stdout',stderr=f'{i:04d}.stderr'))
 (OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if r.returncode:raise RuntimeError(r.stdout.decode()+r.stderr.decode())
 return r.stdout.decode()
for opt in ['O0','O2']:
 b=OUT/opt;b.mkdir();old=physical/opt
 cmd=next(e['command']for e in prior if e['category']=='link'and e['command'][-1]==str(old/'hist'))
 objects=[p for p in cmd if p.endswith('.o')][:-1]
 for name in objects:provider_objects[name]=sha(Path(name))
 flags=cmd[1:cmd.index(objects[0])]
 flags=[('-J'+str(b))if x.startswith('-J')else x for x in flags]
 flags+=['-I'+str(old)]
 compiler=os.environ.get('FC','gfortran')
 csv=b/'csv.o';driver=b/'driver.o';exe=b/'actual-csv'
 run([compiler,*flags,'-c',ROOT/'src/adapter/mod_crop_ext_csv_file.f90','-o',csv],b,'csv_compile')
 run([compiler,*flags,'-c',OUT/'driver.f90','-o',driver],b,'driver_compile')
 run([compiler,*flags,*objects,csv,driver,'-o',exe],b,'link')
 restart=b/'model.restart';endpoint=b/'model.endpoint';fresh=b/'model.fresh'
 run([exe,'write',restart,endpoint],b,'native')
 run([exe,'resume',restart,fresh],b,'fresh_native')
 for suffix in ['','.output','.csv']:assert Path(str(endpoint)+suffix).read_bytes()==Path(str(fresh)+suffix).read_bytes(),suffix
 assert sha(endpoint)==proof['results'][opt]['physical'],'physical endpoint changed by CSV observation'
 results[opt]=dict(physical_sha256=sha(endpoint),csv_sha256=sha(Path(str(endpoint)+'.csv')),diagnostic_sha256=sha(Path(str(endpoint)+'.output')))
assert results['O0']==results['O2']
assert all(sha(Path(p))==h for p,h in provider_objects.items()),'pinned object changed during relink'
paths=['src/adapter/mod_crop_ext_csv_file.f90','tests/nut-output/run_accepted_output_csv.py']
r=dict(status='ACTUAL_ACCEPTED_CSV_O0_O2_FRESH_PASS',results=results,physical_proof_sha256=sha(physical/'result.json'),pinned_object_sha256=provider_objects,input_sha256={p:sha(ROOT/p)for p in paths},generated_driver_sha256=sha(OUT/'driver.f90'))
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'])
