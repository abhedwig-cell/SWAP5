"""Fresh actual two-day Richards/crop/N composition with the output observer.

Uses the existing HIST compile closure and every original default native assertion.
Long profile matrices are explicitly not selected for this additive observer.
"""
from pathlib import Path
import ast,argparse,hashlib,json,os,resource,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--resume',action='store_true');a=p.parse_args()
OUT=a.output.resolve();OUT.mkdir(exist_ok=a.resume)
stack_before=resource.getrlimit(resource.RLIMIT_STACK)
stack_soft=max(stack_before[0],64*1024*1024)
if stack_before[1]!=resource.RLIM_INFINITY:stack_soft=min(stack_soft,stack_before[1])
resource.setrlimit(resource.RLIMIT_STACK,(stack_soft,stack_before[1]))
prior=[]
if a.resume:
 prior=json.loads((OUT/'events.json').read_text())
 if prior[-1]['returncode']!=0:
  failed=prior.pop()
  for key in ['stdout','stderr']:(OUT/('failed-'+key)).write_bytes((OUT/failed[key]).read_bytes())
  (OUT/'PRIOR_FAILED_EVENT.json').write_text(json.dumps(failed,indent=2)+'\n')
 assert all(e['returncode']==0 for e in prior)
 (OUT/'RESUME_PREFIX.json').write_text(json.dumps(dict(events=len(prior),stack_before=stack_before,stack_after=resource.getrlimit(resource.RLIMIT_STACK),reason='same compiled postimages; prior native SIGSEGV with8MiB stack, same executable passes64MiB'),indent=2)+'\n')
prior_streams={e[k]:(OUT/e[k]).read_bytes()for e in prior for k in ['stdout','stderr']}
cursor=0
execution_namespace={}
def resume_run(args,b,category):
 global cursor
 cmd=list(map(str,args));index=cursor;cursor+=1
 if index<len(prior):
  e=prior[index];assert e['command']==cmd and e['category']==category,'nonidentical completed command prefix'
  execution_namespace['events'].append(e)
  return prior_streams[e['stdout']].decode()
 t=time.perf_counter();r=subprocess.run(cmd,cwd=b,capture_output=True)
 for key in ['stdout','stderr']:(OUT/f'{index:04d}.{key}').write_bytes(getattr(r,key))
 execution_namespace['events'].append(dict(command=cmd,category=category,returncode=r.returncode,seconds=time.perf_counter()-t,stdout=f'{index:04d}.stdout',stderr=f'{index:04d}.stderr'))
 (OUT/'events.json').write_text(json.dumps(execution_namespace['events'],indent=2)+'\n')
 if r.returncode:raise RuntimeError(r.stdout.decode()+r.stderr.decode())
 return r.stdout.decode()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
# Execute only the immutable reproductive-oracle preparation, never its test loop.
recipe=ROOT/'tests/nut-crop/run_reproductive_process.py'
text=recipe.read_text();text=text[:text.index("for opt in ('O0','O2'):")].replace('exist_ok=False','exist_ok=True')
ns={'__file__':str(recipe),'__name__':'literal_preparation'}
os.environ['REPRODUCTIVE_PROCESS_RESULT_DIR']=str(OUT/'literal')
exec(compile(text,str(recipe),'exec'),ns)
literal=OUT/'literal/literal.f90'
driver=ROOT/'tests/nut-crop/test_b112_retained_joint.f90'
s=driver.read_text().replace(' implicit none',' use mod_soil_n_crop_extended_output\n use mod_crop_soil_n_output_observation\n implicit none',1)
s=s.replace(' call literal_actual()',' call literal_actual()\n call observe_first_day()',1)
s=s.replace('\ncontains\n',"\ncontains\n include 'accepted_output.inc'\n",1)
# Add a local output continuation to the existing real second day, preserving
# every original physical assertion and every production call unchanged.
needle='  next_env=soil_n_day_environment_t(1d0,2d0,30d0)'
s=s.replace(needle,'''  type(crop_ext_state_t)::diagnostic,prior_diagnostic
  type(crop_ext_row_t)::output_row
  type(kernel_committed_state_t)::output_before_water
  type(crop_soil_state_t)::output_before_soil
  real(real64)::output_values(17),output_prior(17)
  integer::output_unit,output_code
  logical::output_ready
  character(128)::output_line
  output_before_water=w;output_before_soil=n
  open(newunit=output_unit,file=trim(path)//'.diagnostic',access='stream',form='unformatted',status='old')
  read(output_unit)output_values;close(output_unit)
  call restore_crop_ext(output_values,diagnostic,output_code)
  call require(output_code==0,'fresh diagnostic value reconstruction')
  prior_diagnostic=diagnostic;output_prior=output_values
'''+needle,1)
needle="  call require(r%status==0,'actual inflow plus material crop N continuation')"
s=s.replace(needle,needle+'''
  call observe_accepted_crop_soil_n_day(diagnostic,output_before_water,output_before_soil,w,n,r, &
    1d0,2d0,.true.,output_row,output_code)
  call require(output_code==0.and.output_row%emitted,'real second accepted diagnostic publication')
  call require(output_row%values(3)==old_pending%dry_matter_kg_ha(2)+old_pending%dry_matter_kg_ha(3), &
    'original saved surface residues rather than new mortality')
  call require(output_row%values(6)==old_pending%dry_matter_kg_ha(1).and. &
    output_row%values(7)==old_pending%nitrogen_kg_ha(1),'original saved root DM and N')
  call require(output_row%values(1)>output_prior(2),'actual second soil uptake added to nonreport first day')
  call format_crop_ext_row('1900-01-03',output_row,output_line,output_code)
  call require(output_code==0,'accepted real formatted row')
  call diagnostic%snapshot(output_values(1),output_values(2:9),output_values(10:17),output_ready)
  open(newunit=output_unit,file=trim(endpoint)//'.output',access='stream',form='unformatted',status='replace')
  write(output_unit)output_values,output_line;close(output_unit)
  prior_diagnostic=diagnostic
  call observe_accepted_crop_soil_n_day(diagnostic,output_before_water,output_before_soil,w,n,r, &
    1d0,2d0,.true.,output_row,output_code)
  call require(output_code/=0.and.output_identical(diagnostic,prior_diagnostic),'real repeated report no leak')
''',1)
needle="   call require(r%status/=0,'stale second-day forcing rejects')"
# Preserve a distinct observer rejection witness even if the incumbent label changes.
anchor="  call require(r%status==0,'actual inflow plus material crop N continuation')"
assert 'real second accepted diagnostic publication'in s
if a.resume:assert (OUT/'driver.f90').read_text()==s,'generated driver changed before prefix recovery'
(OUT/'driver.f90').write_text(s)
body=''' subroutine observe_first_day()
  type(crop_ext_state_t)::d,before,restored
  type(crop_ext_row_t)::row
  type(senescence_joint_result_t)::rejected
  real(real64)::v(17),bad(17)
  integer::code,u
  logical::ready
  call initialize_crop_ext(0d0,d,code);call require(code==0,'output initialized')
  before=d;rejected=result;rejected%status=1
  call observe_accepted_crop_soil_n_day(d,initial_water,initial_state,water,state,rejected,0d0,1d0,.true.,row,code)
  call require(code/=0.and.output_identical(d,before).and..not.row%emitted,'rejected physical receipt no output leak')
  call observe_accepted_crop_soil_n_day(d,initial_water,initial_state,initial_water,initial_state,result,0d0,1d0,.true.,row,code)
  call require(code/=0.and.output_identical(d,before),'successful receipt without advanced committed state rejected')
  call observe_accepted_crop_soil_n_day(d,initial_water,initial_state,water,state,result,0d0,.5d0,.true.,row,code)
  call require(code/=0.and.output_identical(d,before),'partial day observer rejected')
  call observe_accepted_crop_soil_n_day(d,initial_water,initial_state,water,state,result,0d0,1d0,.false.,row,code)
  call require(code==0.and..not.row%emitted,'actual first accepted nonreport day')
  call d%snapshot(v(1),v(2:9),v(10:17),ready)
  call require(all(v(4:9)==0d0).and.v(2)>0d0,'first day contains soil uptake without previous residues')
  call require(abs(v(2)*1d-4-result%joint%joint%chemical%internal_supply_kg_m2)<1d-15, &
    'output is actual soil debit and excludes biological fixation')
  call restore_crop_ext(v,restored,code)
  call require(code==0.and.output_identical(d,restored),'complete17-value continuation')
  bad=v;bad(1)=ieee_value(0d0,ieee_quiet_nan)
  call restore_crop_ext(bad,restored,code)
  call require(code/=0.and.output_identical(d,restored),'invalid continuation atomic')
  bad=v;bad(2)=-1d0;call restore_crop_ext(bad,restored,code)
  call require(code/=0.and.output_identical(d,restored),'negative continuation atomic')
  bad=v;bad(10)=.9d0;bad(11)=.1d0;call restore_crop_ext(bad,restored,code)
  call require(code/=0.and.output_identical(d,restored),'inverted diagnostic extrema atomic')
  open(newunit=u,file=trim(path)//'.diagnostic',access='stream',form='unformatted',status='replace')
  write(u)v;close(u)
  print '(A)','ACCEPTED_SOIL_N_OUTPUT_FIRST_DAY_ATOMIC_CONTINUATION=PASS'
 end subroutine
 logical function output_identical(a,b)result(ok)
  type(crop_ext_state_t),intent(in)::a,b
  real(real64)::x(17),y(17)
  logical::ra,rb
  call a%snapshot(x(1),x(2:9),x(10:17),ra)
  call b%snapshot(y(1),y(2:9),y(10:17),rb)
  ok=(ra.eqv.rb).and.all(transfer(x,[0_int64],17)==transfer(y,[0_int64],17))
 end function
'''
(OUT/'accepted_output.inc').write_text(body)
# Reuse the existing source-extracted literal chemistry, real bootstrap closure
# and complete two-day restart/harvest driver. No physical test assertion is removed.
recipe=ROOT/'tests/nut-crop/run_hist_complete.py'
src=recipe.read_text();src=src[:src.index(' # Original composition and its fresh-process endpoint stay selected.')]
src=src.replace('OUT.mkdir(exist_ok=False)','OUT.mkdir(exist_ok=True)',1)
if a.resume:src=src.replace('b=OUT/opt;b.mkdir()','b=OUT/opt;b.mkdir(exist_ok=True)',1)
src=src.replace("driver=ROOT/'tests/nut-crop/test_b112_retained_joint.f90';visit(driver)","driver=OUT/'driver.f90';visit(driver)",1)
src=src.replace("'-I'+str(b)]","'-I'+str(b),'-I'+str(OUT)]",1)
# Every command still executes through the original event ledger.
src=src.replace("['gfortran',", "[os.environ.get('FC','gfortran'),")
src+=''' results[opt]=dict(physical=sha(default_endpoint),output=sha(Path(str(default_endpoint)+'.output')),providers=len(ordered)-1)
 assert Path(str(default_endpoint)+'.output').read_bytes()==Path(str(default_fresh)+'.output').read_bytes(),'fresh diagnostic continuation drift'
assert results['O0']==results['O2'],'actual coupled O0/O2 physical or diagnostic drift'
inputs['tests/nut-output/run_accepted_output.py']=sha(ROOT/'tests/nut-output/run_accepted_output.py')
inputs['tests/nut-crop/test_b112_retained_joint.f90']=sha(ROOT/'tests/nut-crop/test_b112_retained_joint.f90')
inputs['tests/nut-crop/run_hist_complete.py']=sha(ROOT/'tests/nut-crop/run_hist_complete.py')
report=dict(status='ACTUAL_TWO_DAY_ACCEPTED_OUTPUT_O0_O2_FRESH_CONTINUATION_PASS',results=results,input_sha256=inputs,generated_driver_sha256=sha(OUT/'driver.f90'),generated_include_sha256=sha(OUT/'accepted_output.inc'),cost_seconds={c:sum(e['seconds']for e in events if e['category']==c)for c in sorted({e['category']for e in events})},atomic_joint_file_publication=False,native_true_enabled=False)
(OUT/'result.json').write_text(json.dumps(report,indent=2)+'\\n');print(report['status'])
'''
os.environ['N_HIST_RESULT_DIR']=str(OUT)
os.environ['REPRODUCTIVE_LITERAL_FILE']=str(literal)
sys.path.insert(0,str(ROOT/'tests/nut-crop'))
if a.resume:
 node=next(n for n in ast.parse(src).body if isinstance(n,ast.FunctionDef)and n.name=='run')
 lines=src.splitlines(True);lines[node.lineno-1:node.end_lineno]=['run=resume_run\n'];src=''.join(lines)
execution_namespace.update({'__file__':str(recipe),'__name__':'accepted_output_qualification','resume_run':resume_run})
exec(compile(src,str(recipe),'exec'),execution_namespace)
