"""Real joint generation, automatic days and pre/post-rename SIGKILL proof."""
from pathlib import Path
import argparse,hashlib,json,os,resource,signal,struct,subprocess,time,zlib
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--physical',type=Path,required=True);p.add_argument('--csv',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
physical=a.physical.resolve();csv=a.csv.resolve();OUT=a.output.resolve();OUT.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
proof=json.loads((physical/'result.json').read_text());csv_proof=json.loads((csv/'result.json').read_text())
assert proof['status']=='ACTUAL_TWO_DAY_ACCEPTED_OUTPUT_O0_O2_FRESH_CONTINUATION_PASS'
assert csv_proof['status']=='ACTUAL_ACCEPTED_CSV_O0_O2_FRESH_PASS'
for report in [proof,csv_proof]:
 for path,h in report['input_sha256'].items():assert sha(ROOT/path)==h,path
resource.setrlimit(resource.RLIMIT_STACK,(64*1024*1024,resource.getrlimit(resource.RLIMIT_STACK)[1]))
s=(csv/'driver.f90').read_text().replace(' use mod_crop_ext_csv_file',' use mod_crop_n_output_generation\n use mod_crop_soil_n_output_day\n use mod_crop_ext_csv_file',1)
s=s.replace(" include 'accepted_output.inc'"," include 'accepted_output.inc'\n include 'joint_generation_proof.inc'",1)
s=s.replace(' call observe_first_day()',' call observe_first_day()\n call generation_first_day()',1)
anchor=" if(trim(mode)=='reject')then"
assert s.count(anchor)==1
s=s.replace(anchor," if(trim(mode)=='generation-read'.or.trim(mode)=='generation-reject')then\n  call generation_special_mode()\n  stop\n end if\n"+anchor,1)
# Fresh physical restart is reconstructed from the combined generation alone.
start=s.index(" if(trim(mode)=='resume')then");end=s.index("  call second_day(backend,water,state)",start)
s=s[:start]+''' if(trim(mode)=='resume')then
  block
   type(crop_ext_state_t)::generation_output
   type(crop_ext_row_t),allocatable::generation_rows(:)
   character(10),allocatable::generation_dates(:)
   call read_crop_n_output_generation(trim(path)//'.generation',column,cfg%tiles(1)%template, &
    670001_int64,9001_int64,9101_int64,sp,cp,water,state,generation_output,generation_dates,generation_rows,status)
   call require(status==0.and.size(generation_rows)==0,'fresh combined first-day generation')
  end block
'''+s[end:]
# Read the actual first-day generation, never a detached value sidecar.
anchor="  open(newunit=output_unit,file=trim(path)//'.diagnostic',access='stream',form='unformatted',status='old')"
a0=s.index(anchor);a1=s.index('  prior_diagnostic=diagnostic;output_prior=output_values',a0)
s=s[:a0]+'''  call read_crop_n_output_generation(trim(path)//'.generation',column,cfg%tiles(1)%template, &
    670001_int64,9001_int64,9101_int64,sp,cp,output_before_water,output_before_soil, &
    diagnostic,output_dates,output_rows,output_code)
  if(output_code/=0)print *,'GENERATION_READ_CODE',output_code
  call require(output_code==0,'second day combined diagnostic reconstruction')
  call require(size(output_rows)==0,'second day binds combined diagnostic history')
  call diagnostic%snapshot(output_values(1),output_values(2:9),output_values(10:17),output_ready)
'''+s[a1:]
s=s.replace('  type(crop_ext_state_t)::diagnostic,prior_diagnostic','''  type(crop_ext_state_t)::diagnostic,prior_diagnostic,automatic_output
  type(kernel_committed_state_t)::automatic_water
  type(crop_soil_state_t)::automatic_soil
  type(crop_ext_row_t),allocatable::output_rows(:)
  character(10),allocatable::output_dates(:)
  type(senescence_joint_result_t)::automatic_result''',1)
anchor="  call require(output_code==0,'actual accepted complete CSV generation')"
assert s.count(anchor)==1
s=s.replace(anchor,anchor+'''
  automatic_water=output_before_water;automatic_soil=output_before_soil;automatic_output=prior_diagnostic
  call run_crop_soil_n_output_day(trim(endpoint)//'.generation','1900-01-03',.true.,670001_int64,b,column, &
    cfg%tiles(1)%template,cfg%tiles(1)%parameters,automatic_water,forcing,cfg%numerical,automatic_soil,weather, &
    1d0,2d0,items,split,policy,automatic_output,output_dates,output_rows,automatic_result,output_code,next_env, &
    trim(endpoint)//'.automatic.csv')
  call require(output_code==OUTPUT_DAY_OK.and.size(output_rows)==1,'automatic second report and saved history')
  call require(output_identical(diagnostic,automatic_output),'automatic second diagnostic exact')
  call write_crop_soil_n_joint_restart_file(trim(endpoint)//'.automatic-inner',column,cfg%tiles(1)%template, &
    670001_int64,automatic_water,automatic_soil,output_code)
  call require(output_code==0,'automatic second physical state export')
  call write_crop_soil_n_joint_restart_file(trim(endpoint)//'.ordinary-inner',column,cfg%tiles(1)%template, &
    670001_int64,w,n,output_code);call require(output_code==0,'ordinary second physical state export')
''',1)
(OUT/'driver.f90').write_text(s)
events=[];results={};objects_pinned={};old_events=json.loads((physical/'events.json').read_text())
def run(cmd,b,category,env=None):
 cmd=list(map(str,cmd));t=time.perf_counter();r=subprocess.run(cmd,cwd=b,capture_output=True,env=env);i=len(events)
 for key in ['stdout','stderr']:(OUT/f'{i:04d}.{key}').write_bytes(getattr(r,key))
 events.append(dict(command=cmd,category=category,returncode=r.returncode,seconds=time.perf_counter()-t,stdout=f'{i:04d}.stdout',stderr=f'{i:04d}.stderr'))
 (OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if r.returncode:raise RuntimeError(r.stdout.decode()+r.stderr.decode())
 return r.stdout.decode()
preload=OUT/'rename_stop.so'
run(['cc','-shared','-fPIC',ROOT/'tests/nut-output/rename_stop.c','-ldl','-o',preload],OUT,'crash_hook_build')
inputs=['src/adapter/mod_crop_n_output_generation.f90','src/adapter/mod_crop_soil_n_output_day.f90','tests/nut-output/joint_generation_proof.inc','tests/nut-output/rename_stop.c','tests/nut-output/run_joint_output_generation.py']
for opt in ['O0','O2']:
 b=OUT/opt;b.mkdir();old=physical/opt
 cmd=next(e['command']for e in old_events if e['category']=='link'and e['command'][-1]==str(old/'hist'))
 objects=[x for x in cmd if x.endswith('.o')][:-1]
 for path in objects:objects_pinned[path]=sha(Path(path))
 flags=cmd[1:cmd.index(objects[0])];flags=[('-J'+str(b))if x.startswith('-J')else x for x in flags]
 flags+=['-I'+str(old),'-I'+str(b),'-I'+str(ROOT/'tests/nut-output')]
 compiler=os.environ.get('FC','gfortran');new_objects=[]
 for i,path in enumerate(['src/adapter/mod_crop_ext_csv_file.f90','src/adapter/mod_crop_n_output_generation.f90','src/adapter/mod_crop_soil_n_output_day.f90']):
  obj=b/f'new-{i}.o';run([compiler,*flags,'-c',ROOT/path,'-o',obj],b,'compile');new_objects.append(obj)
 obj=b/'driver.o';exe=b/'joint-output'
 run([compiler,*flags,'-c',OUT/'driver.f90','-o',obj],b,'driver_compile')
 run([compiler,*flags,*objects,*new_objects,obj,'-o',exe],b,'link')
 restart=b/'model.restart';endpoint=b/'model.endpoint';fresh=b/'model.fresh'
 run([exe,'write',restart,endpoint],b,'native')
 assert Path(str(restart)+'.generation.zero').read_bytes()==Path(str(restart)+'.failed-save-after').read_bytes()
 assert Path(str(restart)+'.automatic-inner').read_bytes()==Path(str(restart)+'.ordinary-inner').read_bytes()
 assert Path(str(restart)+'.view-failed.generation').read_bytes()==Path(str(restart)+'.view-failed.memory').read_bytes()==Path(str(restart)+'.generation').read_bytes()
 assert Path(str(endpoint)+'.automatic-inner').read_bytes()==Path(str(endpoint)+'.ordinary-inner').read_bytes()
 assert Path(str(endpoint)+'.automatic.csv').read_bytes()==Path(str(endpoint)+'.csv').read_bytes()
 # Physically remove both old separate first-day files before new-process resume.
 restart.unlink();Path(str(restart)+'.diagnostic').unlink()
 run([exe,'resume',restart,fresh],b,'fresh_native')
 for suffix in ['', '.output','.csv','.generation','.automatic.csv']:
  assert Path(str(endpoint)+suffix).read_bytes()==Path(str(fresh)+suffix).read_bytes(),suffix
 assert sha(endpoint)==proof['results'][opt]['physical']
 good=Path(str(restart)+'.generation');report=Path(str(endpoint)+'.generation')
 for value in [good,report]:
  copy=b/(value.name+'.copy');run([exe,'generation-read',value,copy],b,'generation_reconstruction');assert value.read_bytes()==copy.read_bytes()
 def seal(data):return data[:-4]+struct.pack('<I',zlib.crc32(data[:-4]))
 raw=good.read_bytes();badcases={
  'crc':raw[:160]+bytes([raw[160]^1])+raw[161:],
  'truncated':raw[:-3],
  'magic':seal(b'INVALID!'+raw[8:]),
  'negative_length':seal(raw[:8]+struct.pack('<i',-1)+raw[12:]),
  'oversize_rows':seal(raw[:12]+struct.pack('<i',100001)+raw[16:]),
  'clock':seal(raw[:16]+struct.pack('<d',99.)+raw[24:]),
  'nan':seal(raw[:24]+struct.pack('<d',float('nan'))+raw[32:]),
  'negative_total':seal(raw[:24]+struct.pack('<d',-1.)+raw[32:]),
  'extrema':seal(raw[:88]+struct.pack('<d',2.)+raw[96:]),
  'trailing':seal(raw[:-4]+b'X'+raw[-4:])}
 report_raw=report.read_bytes();np=struct.unpack_from('<i',report_raw,8)[0];offset=152+np
 badcases['row_date']=seal(report_raw[:offset]+b'bad-date!!'+report_raw[offset+10:])
 badcases['row_value']=seal(report_raw[:offset+10]+struct.pack('<d',-1.)+report_raw[offset+18:])
 # Remove the report while keeping its extrema. Semantic consistency must reject
 # even though the envelope length and CRC have been repaired deliberately.
 dropped=report_raw[:12]+struct.pack('<i',0)+report_raw[16:offset]+report_raw[-4:]
 badcases['history_extrema']=seal(dropped)
 for name,data in badcases.items():
  invalid=b/(name+'.generation');invalid.write_bytes(data);prefix=b/('negative-'+name)
  run([exe,'generation-reject',invalid,prefix,'',good],b,'invalid_generation')
  assert Path(str(prefix)+'.before').read_bytes()==Path(str(prefix)+'.after').read_bytes(),name
 prefix=b/'wrong-id';run([exe,'generation-reject',good,prefix,'',good,'wrong-id'],b,'invalid_identity')
 assert Path(str(prefix)+'.before').read_bytes()==Path(str(prefix)+'.after').read_bytes()
 # Test-only preload pauses precisely at the second rename of the authoritative
 # first-day path; kill the owned child and reconstruct in a new process.
 crashes={}
 for phase in ['before','after']:
  case=b/('crash-'+phase);case.mkdir();base=case/'model.restart';end=case/'model.endpoint';target=Path(str(base)+'.generation')
  env={**os.environ,'LD_PRELOAD':str(preload),'OUTPUT_TEST_TARGET':str(target),'OUTPUT_TEST_PHASE':phase,'OUTPUT_TEST_RENAME_COUNT':'2'}
  stdout=case/'stdout';stderr=case/'stderr'
  with stdout.open('wb')as out,stderr.open('wb')as err:
   child=subprocess.Popen([str(exe),'write',str(base),str(end)],cwd=case,stdout=out,stderr=err,env=env)
   pid,state=os.waitpid(child.pid,os.WUNTRACED)
   assert os.WIFSTOPPED(state)and os.WSTOPSIG(state)==signal.SIGSTOP,(phase,state,stderr.read_text())
   child.kill();child.wait();assert child.returncode==-signal.SIGKILL
  want=Path(str(base)+'.generation.zero')if phase=='before'else good
  assert target.read_bytes()==want.read_bytes(),phase
  recovered=case/'recovered';run([exe,'generation-read',target,recovered],case,'crash_reconstruction')
  assert recovered.read_bytes()==target.read_bytes()
  crashes[phase]=dict(returncode=child.returncode,sha256=sha(target),complete=True)
 results[opt]=dict(physical=sha(endpoint),generation=sha(report),csv=sha(Path(str(endpoint)+'.csv')),invalids=14,crashes=crashes)
assert results['O0']==results['O2'],'O0/O2 generation or crash behavior differs'
assert all(sha(Path(path))==h for path,h in objects_pinned.items())
r=dict(status='JOINT_OUTPUT_AUTOMATIC_ATOMIC_GENERATION_O0_O2_PASS',results=results,input_sha256={p:sha(ROOT/p)for p in inputs},physical_input_sha256=proof['input_sha256'],pinned_object_sha256=objects_pinned,physical_proof_sha256=sha(physical/'result.json'),csv_proof_sha256=sha(csv/'result.json'),generated_driver_sha256=sha(OUT/'driver.f90'),cost_seconds={c:sum(e['seconds']for e in events if e['category']==c)for c in sorted({e['category']for e in events})})
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'])
