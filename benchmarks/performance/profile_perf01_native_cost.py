"""Research-only timing relink; production sources and policies stay untouched.

Nested inclusive clocks: joint day, transaction, physical trial, HeadCalc.
Subtraction provides disjoint costs. Instrumented output must equal ordinary
native output byte-for-byte. Clocks add overhead; ordinary timings are separate.
"""
import argparse,csv,hashlib,json,os,re,statistics,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()

def main():
 ap=argparse.ArgumentParser(description=__doc__)
 ap.add_argument('--bundle',type=Path,required=True)
 ap.add_argument('--study',type=Path,required=True)
 ap.add_argument('--output',type=Path,required=True)
 a=ap.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 bundle=json.loads((a.bundle/'bundle.json').read_text());exe=Path(bundle['exe'])
 meta=json.loads((exe.parent/'build-complete.json').read_text())
 for p,h in meta['input_sha256'].items():assert sha(ROOT/p)==h,p
 for p,h in meta['reused_artifact_sha256'].items():assert sha(Path(p))==h,p
 assert sha(exe)==meta['executable_sha256']
 events=[]
 def execute(cmd,cwd,label):
  t=time.perf_counter();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=120)
  (out/(label+'.stdout')).write_bytes(r.stdout);(out/(label+'.stderr')).write_bytes(r.stderr)
  events.append(dict(command=list(map(str,cmd)),seconds=time.perf_counter()-t,returncode=r.returncode,label=label))
  r.check_returncode();return r
 timer=out/'perf_clock.f90';timer.write_text('''module perf_clock
 use iso_fortran_env,only:int64,real64
 implicit none
 integer(int64)::started(5)=0,total(5)=0,calls(5)=0,counts(12)=0
 contains
 subroutine perf_start(k)
 integer,intent(in)::k
 call system_clock(started(k))
 calls(k)=calls(k)+1
 end subroutine
 subroutine perf_stop(k)
 integer,intent(in)::k
 integer(int64)::now
 call system_clock(now)
 total(k)=total(k)+now-started(k)
 end subroutine
 subroutine perf_report()
 integer::u,k
 integer(int64)::rate
 call system_clock(count_rate=rate)
 open(newunit=u,file='profile.csv',status='new')
 write(u,'(A)')'category,seconds,calls'
 do k=1,5
 write(u,'(I0,A,ES25.17E3,A,I0)')k,',',real(total(k),real64)/real(rate,real64),',',calls(k)
 enddo
 close(u)
 open(newunit=u,file='counts.csv',status='new')
 write(u,'(12(I0,1X))')counts
 close(u)
 end subroutine
 end module
''')
 flags=[x for x in meta['flags']if not x.startswith('-J')]
 compiler=meta['compiler_command'];execute(compiler+flags+['-J'+str(out),'-c',timer,'-o',out/'perf_clock.o'],out,'timer-build')
 objects=[e['command'][-1]for e in meta['source_build']['events']if e['category']=='compile'and not e['command'][-3].endswith('/app/solute_crop/main.f90')]
 assert len(objects)==193
 def wrap(raw,pattern,k):
  lines=raw.splitlines(True);new=[];n=0;i=0
  while i<len(lines):
   line=lines[i]
   if re.match(r'\s*call '+pattern+r'\(',line,re.I):
    new.append(f'call perf_start({k})\n');n+=1
    while True:
     new.append(lines[i]);continuation=lines[i].rstrip().endswith('&');i+=1
     if not continuation:break
    new.append(f'call perf_stop({k})\n')
   else:new.append(line);i+=1
  assert n,pattern
  return ''.join(new),n
 generated={};wraps={}
 for path,pattern,k in [('src/transaction/mod_transaction_reference.f90','execute_reference_interval_body',2),
                        ('src/adapter/mod_reference_richards_legacy_binding.f90','headcalc',4)]:
  raw=(ROOT/path).read_text()
  names=['execute_reference_interval','execute_reference_interval_body','execute_model_certificate_interval']if k==2 else['reference_richards_legacy_solve']
  for name in names:
   raw,n=re.subn(r'(  subroutine '+name+r'\([^\n]+\)\n)',r'\1 use perf_clock,only:perf_start,perf_stop,counts\n',raw)
   assert n==1,name
  raw,n=wrap(raw,pattern,k);wraps[pattern]=n
  if k==2:
   raw,n=wrap(raw,r'model%advance',3);wraps['model%advance']=n
   raw,n=re.subn(r'(    do retry_index = 0, policy%max_retries\n)',r'\1 call perf_start(5)\n',raw)
   assert n==2
   raw,n=re.subn(r'(\s+)(call reject_and_retry\(result, retry_index, policy, attempt_dt\))',r'\1call perf_stop(5)\1\2',raw)
   assert n==7
   anchor='    call model%end_scratch_scope(scope)'
   assert raw.count(anchor)==1
   raw=raw.replace(anchor,anchor+'''
 counts=counts+int([result%attempts,result%full_trials,result%half_trials, &
 result%solver_rejections,result%temporal_rejections,result%mass_rejections, &
 result%nonlinear_iterations,result%headcalc_calls,result%backtracking_attempts, &
 result%accepted_nonlinear_iterations,result%accepted_headcalc_calls,result%accepted_backtracking_attempts],int64)
''')
  p=out/Path(path).name;p.write_text(raw);generated[path]=sha(p)
  old=next(e['command'][-1]for e in meta['source_build']['events']if e['category']=='compile'and e['command'][-3].endswith('/'+path))
  obj=out/(p.stem+'.o');execute(compiler+['-I'+str(out)]+flags+['-J'+str(out),'-c',p,'-o',obj],out,p.stem)
  objects[objects.index(old)]=str(obj)
 raw=(ROOT/'app/solute_project/main.f90').read_text()
 raw=raw.replace('  use iso_fortran_env,','  use perf_clock,only:perf_start,perf_stop,perf_report\n  use iso_fortran_env,',1)
 raw,n=wrap(raw,'run_pond_joint_interval',1);wraps['run_pond_joint_interval']=n
 anchor='  close(u)\n  call require';# report at successful terminal only
 marker="  print '(A)','SWAP5_SOLUTE_COLUMN_COMPLETED'"
 assert raw.count(marker)==1
 raw=raw.replace(marker,'  call perf_report()\n'+marker)
 driver=out/'main.f90';driver.write_text(raw);generated['app/solute_project/main.f90']=sha(driver)
 archive=next(p for p in meta['reused_artifact_sha256']if p.endswith('/libttutil.a'))
 instrumented=out/'profile_project'
 execute(compiler+['-I'+str(out)]+flags+['-J'+str(out),driver,*objects,out/'perf_clock.o',archive,'-o',instrumented],out,'link')
 core=min(os.sched_getaffinity(0));runs=[]
 for rain in [1,4]:
  previous=a.study/f'{rain}x-0-current'
  for repeat in range(3):
   for arm,binary in [('ordinary',exe),('profile',instrumented)]:
    label=f'{rain}x-{repeat}-{arm}';folder=out/label;folder.mkdir()
    for name in ['input.nml','input.swp']:(folder/name).write_bytes((previous/name).read_bytes())
    cmd=['taskset','-c',str(core),binary,'input.nml','-','2048','input.swp']
    r=execute(cmd,folder,label)
    assert b'SWAP5_SOLUTE_COLUMN_COMPLETED'in r.stdout
    for name in ['budget.csv','state.csv','endpoint.csv','restart.bin']:assert (folder/name).read_bytes()==(previous/name).read_bytes(),(label,name)
    row=dict(rain=rain,repeat=repeat,arm=arm,wall_seconds=events[-1]['seconds'],
      output_sha256={name:sha(folder/name)for name in ['budget.csv','state.csv','endpoint.csv','restart.bin']})
    if arm=='profile':
     row['inclusive']=list(csv.DictReader((folder/'profile.csv').open()))
     row['counts']=list(map(int,(folder/'counts.csv').read_text().split()))
    runs.append(row)
 report=dict(status='PROFILE_OUTPUT_BYTE_EXACT',baseline=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
  affected_invariants=[2,5,7,13,23,26],production_changed=False,policy_changed=False,
  timing_note='Research-only nested wall clocks add overhead; use ordinary runs for native total. Joint minus transaction includes chemistry and interval orchestration; transaction minus trial is controller/state overhead; trial minus HeadCalc is provider/adapter/state work.',
  core=core,wraps=wraps,input_sha256=meta['input_sha256'],generated_sha256=generated,events=events,runs=runs,cases={})
 for rain in [1,4]:
  selected=[r for r in runs if r['rain']==rain];profile=[r for r in selected if r['arm']=='profile']
  incl={k:statistics.median(float(r['inclusive'][k-1]['seconds'])for r in profile)for k in range(1,6)}
  ordinary=statistics.median(r['wall_seconds']for r in selected if r['arm']=='ordinary')
  report['cases'][rain]=dict(native_wall_seconds=ordinary,instrumented_wall_seconds=statistics.median(r['wall_seconds']for r in profile),
    joint_seconds=incl[1],transaction_state_controller_seconds=incl[2]-incl[3],
    provider_adapter_state_seconds=incl[3]-incl[4],headcalc_seconds=incl[4],
    chemistry_joint_orchestration_seconds=incl[1]-incl[2],
    native_setup_output_launch_seconds=statistics.median(r['wall_seconds']for r in profile)-incl[1],
    rejected_attempt_seconds=incl[5],counts=profile[0]['counts'])
 (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps(report['cases'],indent=2))
if __name__=='__main__':main()
