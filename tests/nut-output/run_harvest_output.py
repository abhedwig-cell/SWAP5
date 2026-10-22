"""Existing real thermal output plus atomically persisted harvest phase boundaries."""
from pathlib import Path
import argparse,hashlib,json,os,resource,struct,subprocess,time
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--cold',type=Path,required=True);p.add_argument('--thermal',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
COLD=a.cold.resolve();THERMAL=a.thermal.resolve();OUT=a.output.resolve();OUT.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
c=json.loads((COLD/'result.json').read_text());t=json.loads((THERMAL/'result.json').read_text())
assert c['status']=='NATIVE_TRUE_OUTPUT_PROJECT_O0_O2_FRESH_PASS'and t['status']=='THERMAL_OUTPUT_ACTUAL_O0_O2_RESTART_ATOMIC_PASS'
assert t['cold_proof_sha256']==sha(COLD/'result.json')
for name,h in {**c['input_sha256'],**t['input_sha256']}.items():assert sha(ROOT/name)==h,name
resource.setrlimit(resource.RLIMIT_STACK,(64*1024*1024,resource.getrlimit(resource.RLIMIT_STACK)[1]))
s=(THERMAL/'driver.f90').read_text().replace(' implicit none',' use mod_crop_soil_n_output_harvest\n implicit none',1)
s=s.replace('\ncontains\n',"\ncontains\n include 'harvest_output_proof.inc'\n",1)
anchor=" if(trim(mode)=='reject')then";assert s.count(anchor)==1
s=s.replace(anchor," if(trim(mode)=='harvest-resume')then\n  call harvest_resume_mode()\n  stop\n end if\n"+anchor,1)
anchor="  call require(r%joint%joint%chemical%soil%external_in>0d0.and.abs(r%joint%joint%chemical%whole_n_residual)<=1d-12,'inflow whole soil crop N')"
assert s.count(anchor)==1
s=s.replace(anchor,anchor+"\n  call harvest_output_proof(trim(endpoint)//'.harvest',automatic_water,automatic_soil, &\n   diagnostic,output_dates,output_rows)",1)
(OUT/'driver.f90').write_text(s)
events=[];results={};pinned={};old_events=json.loads((COLD/'events.json').read_text())
def run(cmd,b,category):
 cmd=list(map(str,cmd));start=time.perf_counter();r=subprocess.run(cmd,cwd=b,capture_output=True);i=len(events)
 for stream in ['stdout','stderr']:(OUT/f'{i:04d}.{stream}').write_bytes(getattr(r,stream))
 events.append(dict(command=cmd,category=category,returncode=r.returncode,seconds=time.perf_counter()-start,stdout=f'{i:04d}.stdout',stderr=f'{i:04d}.stderr'))
 (OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if r.returncode:raise RuntimeError(r.stdout.decode()+r.stderr.decode())
 return r.stdout.decode()
def diagnostic_payload(path):
 raw=path.read_bytes();length=struct.unpack_from('<i',raw,8)[0]
 return raw[:8]+raw[12:16]+raw[16:152]+raw[152+length:-4]
for opt in ['O0','O2']:
 b=OUT/opt;b.mkdir();old=COLD/opt
 link=next(e['command']for e in old_events if e['category']=='link'and e['command'][-1]==str(old/'hist'))
 objects=[v for v in link if v.endswith('.o')][:-1]
 for obj in objects:pinned[obj]=sha(Path(obj))
 for mod in old.glob('*.mod'):pinned[str(mod)]=sha(mod)
 flags=[('-J'+str(b))if v.startswith('-J')else v for v in link[1:link.index(objects[0])]]
 flags+=['-I'+str(old),'-I'+str(THERMAL/'profile'),'-I'+str(ROOT/'tests/nut-output')]
 fc=os.environ.get('FC','gfortran');provider=ROOT/'src/adapter/mod_crop_soil_n_output_harvest.f90';obj=b/'harvest.o'
 run([fc,*flags,'-c',provider,'-o',obj],b,'provider_compile')
 driver_obj=b/'driver.o';exe=b/'harvest'
 run([fc,*flags,'-c',OUT/'driver.f90','-o',driver_obj],b,'driver_compile');run([fc,*flags,*objects,obj,driver_obj,'-o',exe],b,'link')
 restart=b/'model.restart';end=b/'endpoint';fresh=b/'fresh'
 run([exe,'write',restart,end],b,'harvest_native');restart.unlink()
 run([exe,'resume',restart,fresh],b,'harvest_native_fresh')
 for suffix in ['', '.generation','.csv','.automatic-inner','.ordinary-inner']:
  assert Path(str(end)+suffix).read_bytes()==Path(str(fresh)+suffix).read_bytes(),'original thermal continuation drift'
 assert end.read_bytes()==(THERMAL/opt/'output.endpoint').read_bytes(),'harvest adapter alters original physical execution'
 for prefix in [str(end)+'.harvest',str(fresh)+'.harvest']:
  active=Path(prefix+'.active');diag=diagnostic_payload(active)
  assert active.read_bytes()==Path(prefix+'.failed-before-stage').read_bytes()==Path(prefix+'.before-1').read_bytes()
  assert not Path(prefix+'.invalid').exists(),'rejected phase wrote a generation'
  for phase in [1,2,3]:
   stage=Path(prefix+'.phase-'+str(phase))
   for name in ['memory','view','view-memory','replay']:assert stage.read_bytes()==Path(prefix+'.'+name+'-'+str(phase)).read_bytes(),'phase authority leak '+name
   assert Path(prefix+'.manual-'+str(phase)).read_bytes()==Path(prefix+'.automatic-'+str(phase)).read_bytes(),'phase changes original harvest physics'
   assert diagnostic_payload(stage)==diag,'phase advances diagnostics/history'
   if phase>1:assert Path(prefix+'.before-'+str(phase)).read_bytes()==Path(prefix+'.phase-'+str(phase-1)).read_bytes(),'failed phase leaks'
  assert Path(prefix+'.unbound-observation-after').read_bytes()==Path(prefix+'.phase-2').read_bytes()
 for phase in [1,2,3]:
  p=Path(str(end)+'.harvest.phase-'+str(phase));q=Path(str(fresh)+'.harvest.phase-'+str(phase));assert p.read_bytes()==q.read_bytes()
  roundtrip=b/('roundtrip-'+str(phase));run([exe,'harvest-resume',p,roundtrip,'',0],b,'phase_roundtrip');assert p.read_bytes()==roundtrip.read_bytes()
  if phase<3:
   next_phase=b/('fresh-phase-'+str(phase+1));run([exe,'harvest-resume',p,next_phase,'',phase+1],b,'phase_continuation')
   assert next_phase.read_bytes()==Path(str(end)+'.harvest.phase-'+str(phase+1)).read_bytes(),'independent phase continuation drift'
 results[opt]={str(phase):dict(generation=sha(Path(str(end)+'.harvest.phase-'+str(phase))),physical=sha(Path(str(end)+'.harvest.automatic-'+str(phase))))for phase in [1,2,3]}
assert results['O0']==results['O2'],'harvest optimization drift'
assert all(sha(Path(p))==h for p,h in pinned.items()),'reused current objects changed'
inputs=['src/adapter/mod_crop_soil_n_output_harvest.f90','tests/nut-output/harvest_output_proof.inc','tests/nut-output/run_harvest_output.py']
r=dict(status='HARVEST_OUTPUT_PHASE_O0_O2_ATOMIC_FRESH_PASS',results=results,input_sha256={p:sha(ROOT/p)for p in inputs},cold_input_sha256=c['input_sha256'],thermal_input_sha256=t['input_sha256'],cold_proof_sha256=sha(COLD/'result.json'),thermal_proof_sha256=sha(THERMAL/'result.json'),generated_driver_sha256=sha(OUT/'driver.f90'),pinned_artifacts=pinned,actual_programs=14,phase_roundtrips=6,independent_phase_continuations=4,cost_seconds={k:sum(e['seconds']for e in events if e['category']==k)for k in sorted({e['category']for e in events})})
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'])
