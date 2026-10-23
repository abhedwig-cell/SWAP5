"""Actual immutable-calendar/accepted-heat composition, without a new physical route."""
from pathlib import Path
import argparse,hashlib,json,os,resource,signal,subprocess,time
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--build-root',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
a=p.parse_args();W=a.build_root.resolve();OUT=a.output.resolve();OUT.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
resource.setrlimit(resource.RLIMIT_STACK,(64*1024*1024,resource.getrlimit(resource.RLIMIT_STACK)[1]))
proofs={k:json.loads((W/k/'result.json').read_text())for k in ['cold','thermal']};inputs={}
for k,r in proofs.items():
 for name in ['input_sha256','cold_input_sha256']:
  for path,h in r.get(name,{}).items():assert sha(ROOT/path)==h,(k,path);inputs[path]=h
 assert sha(W/k/'driver.f90')==r['generated_driver_sha256']
s=(W/'thermal/driver.f90').read_text().replace(' implicit none',
 ' use mod_crop_soil_n_calendar_output_day\n use mod_crop_soil_n_calendar_day\n use mod_soil_n_amendment_calendar\n implicit none',1)
s=s.replace('\ncontains\n',"\ncontains\n include 'thermal_calendar_proof.inc'\n",1)
anchor=" if(trim(mode)=='generation-read'";at=s.index(anchor)
s=s[:at]+" if(trim(mode)=='calendar-resume'.or.trim(mode)=='calendar-roundtrip')then\n  call thermal_calendar_proof()\n  stop\n end if\n"+s[at:]
anchor=' initial_water=water;initial_state=state;initial_soil=soil;old_crop=pack_crop_n_owner(crop)';assert s.count(anchor)==1
s=s.replace(anchor,anchor+"\n if(trim(mode)=='calendar-new')then\n  call thermal_calendar_proof()\n  stop\n end if",1)
(OUT/'driver.f90').write_text(s)
events=[];results={};pinned={}
def run(cmd,cwd,category):
 cmd=list(map(str,cmd));t=time.perf_counter();r=subprocess.run(cmd,cwd=cwd,capture_output=True);i=len(events)
 for stream in ['stdout','stderr']:(OUT/f'{i:04d}.{stream}').write_bytes(getattr(r,stream))
 events.append(dict(command=cmd,category=category,returncode=r.returncode,seconds=time.perf_counter()-t,stdout=f'{i:04d}.stdout',stderr=f'{i:04d}.stderr'))
 (OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if r.returncode:raise RuntimeError(str(i)+' '+r.stdout.decode()+r.stderr.decode())
for opt in ['O0','O2']:
 b=OUT/opt;b.mkdir();old=W/'cold'/opt
 es=json.loads((W/'cold/events.json').read_text());link=next(e['command']for e in es if e['category']=='link'and e['command'][-1]==str(old/'hist'))
 objects=[v for v in link if v.endswith('.o')][:-1]
 flags=[('-J'+str(b))if v.startswith('-J')else v for v in link[1:link.index(objects[0])]]
 flags+=['-I'+str(old),'-I'+str(W/'thermal/profile'),'-I'+str(ROOT/'tests/nut-output')]
 for obj in objects:pinned[obj]=sha(Path(obj))
 for mod in old.glob('*.mod'):pinned[str(mod)]=sha(mod)
 fc=os.environ.get('FC','gfortran');obj=b/'calendar.o';driver=b/'driver.o';exe=b/'calendar'
 run([fc,*flags,'-c',ROOT/'src/adapter/mod_crop_soil_n_calendar_output_day.f90','-o',obj],b,'provider_compile')
 run([fc,*flags,'-c',OUT/'driver.f90','-o',driver],b,'driver_compile')
 run([fc,*flags,*objects,obj,driver,'-o',exe],b,'link')
 schedules={}
 for schedule in [1,2]:
  case=b/str(schedule);case.mkdir();end=case/'endpoint'
  run([exe,'calendar-new',case/'unused',end,'source-profile',schedule],case,'calendar_native')
  for day in range(3):
   assert Path(str(end)+'.before-'+str(day)).read_bytes()==Path(str(end)+'.after-'+str(day)).read_bytes(),'rejected calendar leaks'
   actual=Path(str(end)+'.day-'+str(day))
   assert actual.read_bytes()==Path(str(end)+'.manual-'+str(day)).read_bytes()==Path(str(end)+'.replay-'+str(day)).read_bytes(),'calendar manual/replay drift'
   copy=case/('roundtrip-'+str(day));run([exe,'calendar-roundtrip',actual,copy,'source-profile',schedule],case,'calendar_roundtrip');assert copy.read_bytes()==actual.read_bytes()
   if day<2:
    fresh=case/('fresh-'+str(day));run([exe,'calendar-resume',actual,fresh,'source-profile',schedule],case,'calendar_fresh')
    for suffix in ['', '.csv','.physical']:assert Path(str(fresh)+suffix).read_bytes()==Path(str(end)+suffix).read_bytes(),'fresh calendar drift '+suffix
    for d in range(day+1,3):
     assert Path(str(fresh)+'.before-'+str(d)).read_bytes()==Path(str(fresh)+'.after-'+str(d)).read_bytes()
     assert Path(str(fresh)+'.day-'+str(d)).read_bytes()==Path(str(fresh)+'.manual-'+str(d)).read_bytes()==Path(str(fresh)+'.replay-'+str(d)).read_bytes()
  schedules[str(schedule)]={suffix:sha(Path(str(end)+suffix))for suffix in ['', '.csv','.physical']}
 assert schedules['1']['.physical']==schedules['2']['.physical'],'report schedule affects calendar physics'
 crashes={}
 for phase in ['before','after']:
  case=b/('crash-'+phase);case.mkdir();target=case/'generation';prior=b/'1/endpoint.day-0';wanted=b/('1/endpoint.day-'+('0'if phase=='before'else'1'))
  target.write_bytes(prior.read_bytes())
  env={**os.environ,'LD_PRELOAD':str(W/'thermal/rename-stop.so'),'OUTPUT_TEST_TARGET':str(target),'OUTPUT_TEST_PHASE':phase,'OUTPUT_TEST_RENAME_COUNT':'1'}
  with(case/'stdout').open('wb')as out,(case/'stderr').open('wb')as err:
   child=subprocess.Popen([str(exe),'calendar-resume',str(prior),str(target),'source-profile','1'],cwd=case,env=env,stdout=out,stderr=err)
   _,state=os.waitpid(child.pid,os.WUNTRACED);assert os.WIFSTOPPED(state)and os.WSTOPSIG(state)==signal.SIGSTOP
   child.kill();child.wait();assert child.returncode==-signal.SIGKILL
  assert target.read_bytes()==wanted.read_bytes()
  recovered=case/'recovered';run([exe,'calendar-resume',target,recovered,'source-profile',1],case,'crash_fresh')
  for suffix in ['', '.csv','.physical']:assert Path(str(recovered)+suffix).read_bytes()==Path(str(b/'1/endpoint')+suffix).read_bytes()
  crashes[phase]=dict(returncode=-9,complete=True,sha256=sha(target));(case/'result.json').write_text(json.dumps(crashes[phase])+'\n')
 results[opt]=dict(schedules=schedules,crashes=crashes)
assert results['O0']==results['O2'],'calendar optimization drift'
assert all(sha(Path(path))==h for path,h in pinned.items()),'reused artifacts drift'
for path in ['tests/nut-output/run_thermal_calendar_output.py','tests/nut-output/thermal_calendar_proof.inc','src/adapter/mod_crop_soil_n_calendar_output_day.f90','src/crop/mod_crop_soil_n_calendar_day.f90','src/process/mod_soil_n_amendment_calendar.f90']:inputs[path]=sha(ROOT/path)
r=dict(status='THERMAL_CALENDAR_OUTPUT_O0_O2_FRESH_ATOMIC_PASS',results=results,events=events,input_sha256=inputs,pinned_artifacts=pinned,generated={'driver.f90':sha(OUT/'driver.f90')},shared_base_provider_count=len(objects),rejection_trials=5*len(list(OUT.glob('O*/**/*.after-[012]'))),replay_trials=len(list(OUT.glob('O*/**/*.replay-[012]'))),full_mc_nut01_closed=False,cost_seconds={k:sum(e['seconds']for e in events if e['category']==k)for k in sorted({e['category']for e in events})})
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'])
