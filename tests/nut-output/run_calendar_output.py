"""Native immutable calendar/output composition using current cold provider objects.

No scientific assertion from the incumbent driver is removed. The new native
route runs three days, includes the actual simultaneous Jan1 amendments, and
compares ordinary calendar physics and independent diagnostic observation.
"""
from pathlib import Path
import argparse,hashlib,json,os,resource,subprocess,time
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--cold',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
COLD=a.cold.resolve();OUT=a.output.resolve();OUT.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
prior=json.loads((COLD/'result.json').read_text());old_events=json.loads((COLD/'events.json').read_text())
assert prior['status']=='NATIVE_TRUE_OUTPUT_PROJECT_O0_O2_FRESH_PASS'
for name,h in prior['input_sha256'].items():assert sha(ROOT/name)==h,name
resource.setrlimit(resource.RLIMIT_STACK,(64*1024*1024,resource.getrlimit(resource.RLIMIT_STACK)[1]))
s=(ROOT/'tests/nut-output/native_output_project.inc').read_text()
s=s.replace('type(crop_ext_state_t)::diagnostic,guard','type(crop_ext_state_t)::diagnostic,guard,manual_d\n  type(crop_ext_row_t)::manual_row\n  type(kernel_committed_state_t)::before_water\n  type(crop_soil_state_t)::before_soil\n  type(soil_n_amendment_calendar_t)::invalid_plan\n  type(soil_n_day_environment_t)::invalid_environment\n  integer::schedule\n  logical::report_now')
s=s.replace('  selection%swcropsnm=1;',"  call get_command_argument(5,line);read(line,*)schedule\n  selection%swcropsnm=1;",1)
s=s.replace('  first_day=0','  first_day=0;manual_d=diagnostic',1)
s=s.replace('   first_day=1','   first_day=1;manual_d=diagnostic',1)
s=s.replace('  do day=first_day,1','  do day=first_day,2',1)
s=s.replace("   call require(code==0,'native material calendar batch')","   call require(code==0,'native material calendar batch')\n   if(day==0)call require(size(batch)==1,'first-day gift')\n   if(day==1)call require(size(batch)==0,'empty day')\n   if(day==2)call require(size(batch)==2,'simultaneous native Jan1 gifts')",1)
s=s.replace("   date='1900-12-31';if(day==1)date='1901-01-01'","   date='1900-12-31';if(day==1)date='1901-01-01'\n   if(day==2)date='1901-01-02'\n   report_now=day==2.or.(day==1.and.schedule==1)\n   before_water=ow;before_soil=ordinary",1)
start=s.index('   call run_crop_soil_n_output_day(');end=s.index("   if(code/=0)print",start)
valid=s[start:end].replace('run_crop_soil_n_output_day','run_crop_soil_n_calendar_output_day').replace('date,day==1,','date,report_now,').replace(',batch,split,policy1',',plan1,split,policy1')
save="""   call write_crop_n_output_generation(trim(endpoint)//'.before-'//achar(48+day),column, &
    cfg%tiles(1)%template,670001_int64,aw,actual,diagnostic,dates,rows,code)
   call require(code==0,'complete pretrial calendar authority')
"""
invalid=valid.replace(',plan1,split,policy1',',invalid_plan,split,policy1')+"   call require(code==OUTPUT_DAY_INVALID,'invalid plan rejects before output publication')\n"
invalid+=valid.replace('base_day+real(day,real64),base_day+real(day+1,real64),','base_day+real(day,real64)+.5d0,base_day+real(day+1,real64)+.5d0,')+"   call require(code==OUTPUT_DAY_INVALID,'off-grid day rejects before output publication')\n"
invalid+="   invalid_environment=environment;invalid_environment%temperature_c=-999d0\n"+valid.replace("    environment,trim(endpoint)//'.csv')","    invalid_environment,trim(endpoint)//'.csv')")+"   call require(code/=OUTPUT_DAY_OK,'late environment rejection')\n"
invalid+=valid.replace('trim(path),date,',"'missing-calendar-output/generation',date,")+"   call require(code==OUTPUT_DAY_SAVE_FAILED,'calendar late save failure')\n"
invalid+=save.replace("'.before-'","'.after-'",1)
s=s[:start]+save+invalid+valid+s[end:]
anchor="   call require(ordinary_result%status==JOINT_OK,'ordinary FALSE physical day')"
s=s.replace(anchor,anchor+"""
   call observe_accepted_crop_soil_n_day(manual_d,before_water,before_soil,ow,ordinary,ordinary_result, &
    base_day+real(day,real64),base_day+real(day+1,real64),report_now,manual_row,code)
   call require(code==0,'manual independent calendar diagnostic')
   call diagnostic%snapshot(v(1),v(2:9),v(10:17),ready)
   call manual_d%snapshot(g(1),g(2:9),g(10:17),guard_ready)
   call require(ready.and.guard_ready.and.all(v==g),'automatic calendar diagnostics exact')
   if(report_now)call require(all(rows(size(rows))%values==manual_row%values),'calendar report row exact')
""",1)
s=s.replace("  call require(size(rows)==1.and.dates(1)=='1901-01-01','native year-boundary report history')","  call require(size(rows)==merge(2,1,schedule==1),'calendar report schedule')\n  call require(dates(size(dates))=='1901-01-02','calendar includes actual Jan1 gift day')")
# Replay the final accepted day. No gift or output may be published twice.
anchor="  call initialize_historical_crop_soil_output_owner(selection,sp,cp,crop,9001_int64,9101_int64, &\n   base_day,water_fraction,'native-output.snm','1900-12-30',plan1,actual,policy1,diagnostic,dates,rows,code,error_line)"
replay=valid.replace('day,real64','2,real64').replace('day+1,real64','3,real64')
s=s.replace(anchor,replay+"   call require(code==OUTPUT_DAY_INVALID,'calendar replay rejects duplicate gift and report')\n"+anchor,1)
(OUT/'calendar_output_project.inc').write_text(s)
driver=(COLD/'driver.f90').read_text().replace(' implicit none',' use mod_crop_soil_n_calendar_output_day\n use mod_crop_soil_n_output_observation\n implicit none',1).replace("include 'native_output_project.inc'","include 'calendar_output_project.inc'")
(OUT/'driver.f90').write_text(driver)
events=[];results={};pinned={}
def run(cmd,b,category):
 cmd=list(map(str,cmd));t=time.perf_counter();r=subprocess.run(cmd,cwd=b,capture_output=True);i=len(events)
 for stream in ['stdout','stderr']:(OUT/f'{i:04d}.{stream}').write_bytes(getattr(r,stream))
 events.append(dict(command=cmd,category=category,returncode=r.returncode,seconds=time.perf_counter()-t,stdout=f'{i:04d}.stdout',stderr=f'{i:04d}.stderr'))
 (OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if r.returncode:raise RuntimeError(r.stdout.decode()+r.stderr.decode())
 return r.stdout.decode()
for opt in ['O0','O2']:
 b=OUT/opt;b.mkdir();old=COLD/opt
 link=next(e['command']for e in old_events if e['category']=='link'and e['command'][-1]==str(old/'hist'))
 objects=[v for v in link if v.endswith('.o')][:-1]
 for obj in objects:pinned[obj]=sha(Path(obj))
 for mod in old.glob('*.mod'):pinned[str(mod)]=sha(mod)
 flags=[('-J'+str(b))if v.startswith('-J')else v for v in link[1:link.index(objects[0])]]
 flags=['-I'+str(OUT),*flags,'-I'+str(old)]
 fc=os.environ.get('FC','gfortran')
 provider=ROOT/'src/adapter/mod_crop_soil_n_calendar_output_day.f90';obj=b/'calendar.o'
 run([fc,*flags,'-c',provider,'-o',obj],b,'provider_compile')
 driver_obj=b/'driver.o';exe=b/'calendar'
 run([fc,*flags,'-c',OUT/'driver.f90','-o',driver_obj],b,'driver_compile')
 run([fc,*flags,*objects,obj,driver_obj,'-o',exe],b,'link')
 results[opt]={}
 for schedule in [1,2]:
  case=b/str(schedule);case.mkdir();restart=case/'model.generation';endpoint=case/'endpoint';fresh=case/'fresh'
  run([exe,'native-output',restart,endpoint,'source-profile',schedule],case,'calendar_native')
  run([exe,'native-output-resume',str(restart)+'.day1',fresh,'source-profile',schedule],case,'calendar_fresh')
  for end in [endpoint,fresh]:
   assert Path(str(end)+'.true').read_bytes()==Path(str(end)+'.false').read_bytes(),'calendar physics drift'
   assert end.read_bytes()==Path(str(end)+'.after-rejected-start').read_bytes(),'calendar replay/start drift'
  for suffix in ['', '.csv','.true','.false']:
   assert Path(str(endpoint)+suffix).read_bytes()==Path(str(fresh)+suffix).read_bytes(),'calendar fresh drift '+suffix
  for end,start_day in [(endpoint,0),(fresh,1)]:
   for day in range(start_day,3):assert Path(str(end)+'.before-'+str(day)).read_bytes()==Path(str(end)+'.after-'+str(day)).read_bytes(),'calendar rejection leaks'
  results[opt][str(schedule)]={k:sha(Path(str(endpoint)+suffix))for k,suffix in [('physical','.true'),('generation',''),('csv','.csv')]}
 assert results[opt]['1']['physical']==results[opt]['2']['physical'],'report schedule alters physics'
assert results['O0']==results['O2'],'calendar optimization drift'
assert all(sha(Path(p))==h for p,h in pinned.items()),'current reused providers changed'
inputs=['src/adapter/mod_crop_soil_n_calendar_output_day.f90','src/crop/mod_crop_soil_n_calendar_day.f90','src/process/mod_soil_n_amendment_calendar.f90','tests/nut-output/run_calendar_output.py']
r=dict(status='NATIVE_CALENDAR_OUTPUT_ACTUAL_O0_O2_FRESH_PASS',results=results,input_sha256={p:sha(ROOT/p)for p in inputs},cold_input_sha256=prior['input_sha256'],cold_proof_sha256=sha(COLD/'result.json'),generated_driver_sha256=sha(OUT/'driver.f90'),generated_include_sha256=sha(OUT/'calendar_output_project.inc'),pinned_artifacts=pinned,days_per_execution=3,processes=8,rejection_trials=80,cost_seconds={k:sum(e['seconds']for e in events if e['category']==k)for k in sorted({e['category']for e in events})})
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'])
