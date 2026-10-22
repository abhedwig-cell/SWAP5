"""Actual accepted thermal output; identical current providers are hashed/reused.

The cold proof builds current production first. Both original retained-thermal
and augmented drivers compile freshly and execute all their physical assertions.
"""
from pathlib import Path
import argparse,base64,hashlib,io,json,os,resource,signal,struct,subprocess,tarfile,time,zlib
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--cold',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
COLD=a.cold.resolve();OUT=a.output.resolve();OUT.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
prior=json.loads((COLD/'result.json').read_text());old_events=json.loads((COLD/'events.json').read_text())
assert prior['status']=='NATIVE_TRUE_OUTPUT_PROJECT_O0_O2_FRESH_PASS'
for name,h in prior['input_sha256'].items():assert sha(ROOT/name)==h,name
resource.setrlimit(resource.RLIMIT_STACK,(64*1024*1024,resource.getrlimit(resource.RLIMIT_STACK)[1]))
# Reuse the original small profile runner's literal extraction, without running
# or rewriting its scientific tests.
recipe=ROOT/'tests/nut-thermal/run_profile.py';ns={'__file__':str(recipe),'__name__':'literal_profile_preparation'}
os.environ['N_THERMAL_PROFILE_DIR']=str(OUT/'profile')
exec(compile(recipe.read_text().split('events=[]')[0],str(recipe),'exec'),ns)
original=ROOT/'tests/nut-crop/test_b112_retained_thermal.f90'
s=original.read_text().replace(' implicit none',' use mod_crop_soil_n_output_day\n use mod_crop_n_output_generation\n use mod_crop_soil_n_output_observation\n use mod_soil_n_crop_extended_output\n implicit none',1)
s=s.replace('\ncontains\n',"\ncontains\n include 'thermal_output_proof.inc'\n",1)
s=s.replace(' call literal_actual()',' call literal_actual()\n call first_output_day()',1)
anchor=" if(trim(mode)=='reject')then";assert s.count(anchor)==1
s=s.replace(anchor," if(trim(mode)=='generation-read'.or.trim(mode)=='generation-reject')then\n  call output_generation_mode()\n  stop\n end if\n"+anchor,1)
start=s.index(" if(trim(mode)=='resume')then");end=s.index('  call second_day(backend,water,state)',start)
s=s[:start]+''' if(trim(mode)=='resume')then
  block
   type(crop_ext_state_t)::d
   type(crop_ext_row_t),allocatable::rows(:)
   character(10),allocatable::dates(:)
   call read_crop_n_output_generation(trim(path)//'.generation',column,cfg%tiles(1)%template, &
    670001_int64,9001_int64,9101_int64,sp,cp,water,state,d,dates,rows,status,cfg%tiles(1)%parameters)
   call require(status==0,'fresh thermal output-only joint reconstruction')
  end block
'''+s[end:]
anchor='  next_env=soil_n_day_environment_t(1d0,2d0,30d0)';assert s.count(anchor)==1
s=s.replace(anchor,'''  type(kernel_committed_state_t)::automatic_water,before_water
  type(crop_soil_state_t)::automatic_soil,before_soil
  type(crop_ext_state_t)::diagnostic,manual
  type(crop_ext_row_t)::manual_row
  type(crop_ext_row_t),allocatable::output_rows(:)
  character(10),allocatable::output_dates(:)
  type(senescence_joint_result_t)::automatic_result
  integer::output_code
  call read_crop_n_output_generation(trim(path)//'.generation',column,cfg%tiles(1)%template, &
   670001_int64,9001_int64,9101_int64,sp,cp,automatic_water,automatic_soil,diagnostic,output_dates,output_rows, &
   output_code,cfg%tiles(1)%parameters)
  call require(output_code==0,'thermal first-day diagnostic reconstruction')
  before_water=automatic_water;before_soil=automatic_soil;manual=diagnostic
'''+anchor,1)
anchor="  call require(r%status==0,'actual inflow plus material crop N continuation')";assert s.count(anchor)==1
s=s.replace(anchor,anchor+'''
  call run_crop_soil_n_output_day(trim(endpoint)//'.generation','1900-01-03',.true.,670001_int64,b,column, &
   cfg%tiles(1)%template,cfg%tiles(1)%parameters,automatic_water,forcing,cfg%numerical,automatic_soil,weather, &
   1d0,2d0,items,split,policy,diagnostic,output_dates,output_rows,automatic_result,output_code, &
   csv_path=trim(endpoint)//'.csv')
  call require(output_code==OUTPUT_DAY_OK.and.size(output_rows)==1,'actual second thermal output generation')
  call observe_accepted_crop_soil_n_day(manual,before_water,before_soil,w,n,r,1d0,2d0,.true.,manual_row, &
   output_code,thermal=.true.)
  call require(output_code==0.and.diagnostic_equal(manual,diagnostic),'automatic thermal second report exact')
  call require(output_rows(1)%values(3)==old_pending%dry_matter_kg_ha(2)+old_pending%dry_matter_kg_ha(3), &
   'thermal output uses saved previous surface residues')
  call require(output_rows(1)%values(6)==old_pending%dry_matter_kg_ha(1),'thermal output uses saved root residues')
  call write_crop_soil_n_joint_restart_file(trim(endpoint)//'.automatic-inner',column,cfg%tiles(1)%template, &
   670001_int64,automatic_water,automatic_soil,output_code);call require(output_code==0,'automatic thermal second state')
  call write_crop_soil_n_joint_restart_file(trim(endpoint)//'.ordinary-inner',column,cfg%tiles(1)%template, &
   670001_int64,w,n,output_code);call require(output_code==0,'ordinary thermal second state')
''',1)
(OUT/'driver.f90').write_text(s)
events=[];results={};pinned={}
def run(cmd,b,kind,env=None):
 cmd=list(map(str,cmd));t=time.perf_counter();r=subprocess.run(cmd,cwd=b,capture_output=True,env=env);i=len(events)
 for stream in ['stdout','stderr']:(OUT/f'{i:04d}.{stream}').write_bytes(getattr(r,stream))
 events.append(dict(command=cmd,category=kind,returncode=r.returncode,seconds=time.perf_counter()-t,stdout=f'{i:04d}.stdout',stderr=f'{i:04d}.stderr'))
 (OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if r.returncode:raise RuntimeError(r.stdout.decode()+r.stderr.decode())
 return r.stdout.decode()
preload=OUT/'rename-stop.so';run(['cc','-shared','-fPIC',ROOT/'tests/nut-output/rename_stop.c','-ldl','-o',preload],OUT,'test_hook_build')
for opt in ['O0','O2']:
 b=OUT/opt;b.mkdir();old=COLD/opt
 link=next(e['command']for e in old_events if e['category']=='link'and e['command'][-1]==str(old/'hist'))
 objects=[v for v in link if v.endswith('.o')][:-1]
 for obj in objects:pinned[obj]=sha(Path(obj))
 for mod in old.glob('*.mod'):pinned[str(mod)]=sha(mod)
 flags=[('-J'+str(b))if v.startswith('-J')else v for v in link[1:link.index(objects[0])]]
 flags+=['-I'+str(old),'-I'+str(OUT/'profile'),'-I'+str(ROOT/'tests/nut-output')]
 fc=os.environ.get('FC','gfortran')
 for name,driver in [('original',original),('output',OUT/'driver.f90')]:
  obj=b/(name+'.o');exe=b/name
  run([fc,*flags,'-c',driver,'-o',obj],b,'driver_compile');run([fc,*flags,*objects,obj,'-o',exe],b,'link')
  restart=b/(name+'.restart');endpoint=b/(name+'.endpoint');fresh=b/(name+'.fresh')
  run([exe,'write',restart,endpoint],b,name+'_native')
  if name=='output':restart.unlink() # combined generation is the sole authority
  run([exe,'resume',restart,fresh],b,name+'_fresh')
  assert endpoint.read_bytes()==fresh.read_bytes()==Path(str(endpoint)+'.opaque').read_bytes()
  if name=='original':continue
  assert endpoint.read_bytes()==(b/'original.endpoint').read_bytes(),'output changes original thermal physics'
  for suffix in ['.generation','.csv','.automatic-inner','.ordinary-inner']:
   assert Path(str(endpoint)+suffix).read_bytes()==Path(str(fresh)+suffix).read_bytes(),'thermal fresh drift '+suffix
  for prefix in [restart,endpoint]:
   assert Path(str(prefix)+'.automatic-inner').read_bytes()==Path(str(prefix)+'.ordinary-inner').read_bytes(),'automatic science drift'
  zero=Path(str(restart)+'.generation.zero');good=Path(str(restart)+'.generation')
  for suffix in ['.environment-after','.material-after','.save-failed-after']:
   assert Path(str(restart)+suffix).read_bytes()==zero.read_bytes(),'failed thermal day leaks '+suffix
  for suffix in ['.replay-after','.view-failed','.view-failed-memory']:
   assert Path(str(restart)+suffix).read_bytes()==good.read_bytes(),'thermal committed state drift '+suffix
  def seal(data):return data[:-4]+struct.pack('<I',zlib.crc32(data[:-4]))
  raw=good.read_bytes();report=Path(str(endpoint)+'.generation').read_bytes();np=struct.unpack_from('<i',report,8)[0];offset=152+np
  negatives={'crc':raw[:160]+bytes([raw[160]^1])+raw[161:],'truncated':raw[:-3],
   'magic':seal(b'INVALID!'+raw[8:]),'negative_length':seal(raw[:8]+struct.pack('<i',-1)+raw[12:]),
   'rows':seal(raw[:12]+struct.pack('<i',100001)+raw[16:]),'clock':seal(raw[:16]+struct.pack('<d',99.)+raw[24:]),
   'nan':seal(raw[:24]+struct.pack('<d',float('nan'))+raw[32:]),'total':seal(raw[:24]+struct.pack('<d',-1.)+raw[32:]),
   'extrema':seal(raw[:88]+struct.pack('<d',2.)+raw[96:]),'trailing':seal(raw[:-4]+b'X'+raw[-4:]),
   'row_date':seal(report[:offset]+b'bad-date!!'+report[offset+10:]),
   'row_value':seal(report[:offset+10]+struct.pack('<d',-1.)+report[offset+18:]),
   'history':seal(report[:12]+struct.pack('<i',0)+report[16:offset]+report[-4:])}
  for key,data in negatives.items():
   bad=b/(key+'.generation');bad.write_bytes(data);prefix=b/('reject-'+key)
   run([exe,'generation-reject',bad,prefix,'',good],b,'invalid_generation')
   assert Path(str(prefix)+'.before').read_bytes()==Path(str(prefix)+'.after').read_bytes(),key
  for option in ['missing-heat','wrong-heat','wrong-crop','wrong-template']:
   prefix=b/option;run([exe,'generation-reject',good,prefix,'',good,option],b,'invalid_identity')
   assert Path(str(prefix)+'.before').read_bytes()==Path(str(prefix)+'.after').read_bytes(),option
  for path in [good,Path(str(endpoint)+'.generation')]:
   copy=b/(path.name+'.copy');run([exe,'generation-read',path,copy],b,'reconstruction');assert copy.read_bytes()==path.read_bytes()
  crashes={}
  for phase in ['before','after']:
   case=b/('crash-'+phase);case.mkdir();prefix=case/'model.restart';end=case/'model.endpoint';target=Path(str(prefix)+'.generation')
   env={**os.environ,'LD_PRELOAD':str(preload),'OUTPUT_TEST_TARGET':str(target),'OUTPUT_TEST_PHASE':phase,'OUTPUT_TEST_RENAME_COUNT':'2'}
   t=time.perf_counter()
   with (case/'stdout').open('wb')as out,(case/'stderr').open('wb')as err:
    child=subprocess.Popen([str(exe),'write',str(prefix),str(end)],cwd=case,stdout=out,stderr=err,env=env)
    _,state=os.waitpid(child.pid,os.WUNTRACED)
    assert os.WIFSTOPPED(state)and os.WSTOPSIG(state)==signal.SIGSTOP,(phase,state,(case/'stderr').read_text())
    child.kill();child.wait();assert child.returncode==-signal.SIGKILL
   want=Path(str(prefix)+'.generation.zero')if phase=='before'else good
   assert target.read_bytes()==want.read_bytes()
   recovered=case/'recovered';run([exe,'generation-read',target,recovered],case,'crash_reconstruction');assert recovered.read_bytes()==target.read_bytes()
   crashes[phase]=dict(returncode=child.returncode,complete=True,sha256=sha(target),seconds=time.perf_counter()-t)
  results[opt]=dict(physical=sha(endpoint),generation=sha(Path(str(endpoint)+'.generation')),csv=sha(Path(str(endpoint)+'.csv')),invalids=17,crashes={k:{x:y for x,y in v.items()if x!='seconds'}for k,v in crashes.items()})
assert results['O0']==results['O2'],'thermal O0/O2 drift'
assert all(sha(Path(p))==h for p,h in pinned.items()),'reused providers changed'
inputs=['src/adapter/mod_crop_n_output_generation.f90','src/adapter/mod_crop_soil_n_output_day.f90','src/adapter/mod_crop_soil_n_output_observation.f90','tests/nut-crop/test_b112_retained_thermal.f90','tests/nut-thermal/run_profile.py','tests/nut-output/thermal_output_proof.inc','tests/nut-output/run_thermal_output.py','tests/nut-output/rename_stop.c']
r=dict(status='THERMAL_OUTPUT_ACTUAL_O0_O2_RESTART_ATOMIC_PASS',results=results,input_sha256={p:sha(ROOT/p)for p in inputs},cold_input_sha256=prior['input_sha256'],cold_proof_sha256=sha(COLD/'result.json'),generated_driver_sha256=sha(OUT/'driver.f90'),pinned_artifacts=pinned,cost_seconds={k:sum(e['seconds']for e in events if e['category']==k)for k in sorted({e['category']for e in events})})
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'])
