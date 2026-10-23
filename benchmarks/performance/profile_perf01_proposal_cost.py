"""Generated research relink: current native OFF/ON costs, no policy changes.

All clocks and regime accounting live only in generated procedure bodies.
Ordinary and instrumented physical bytes must equal the admitted PR1394 oracle.
"""
import argparse,csv,hashlib,json,os,re,statistics,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
FILES=['budget.csv','state.csv','endpoint.csv','restart.bin']
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
TIMER='''module perf_clock
 use iso_fortran_env,only:int64,real64
 implicit none
 integer(int64)::started(10)=0,total(10)=0,calls(10)=0,counts(12,5)=0
 integer(int64)::regime_ticks(5)=0,reject_ticks(5)=0,before_tx,before_reject,abandoned=0
 integer::phase=0
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
 do k=1,10
 write(u,'(I0,A,ES25.17E3,A,I0)')k,',',real(total(k),real64)/real(rate,real64),',',calls(k)
 enddo
 close(u)
 open(newunit=u,file='regimes.txt',status='new')
 do k=1,5
 write(u,'(I0,2(1X,ES25.17E3),12(1X,I0))')k,real(regime_ticks(k),real64)/real(rate,real64), &
 real(reject_ticks(k),real64)/real(rate,real64),counts(:,k)
 enddo
 close(u)
 open(newunit=u,file='abandoned.txt',status='new')
 write(u,*)real(abandoned,real64)/real(rate,real64)
 close(u)
 end subroutine
 end module
'''
def replace(raw,old,new):
 assert raw.count(old)==1,old
 return raw.replace(old,new)
def wrap(raw,pattern,k):
 lines=raw.splitlines(True);new=[];n=0;i=0
 while i<len(lines):
  if re.match(r'\s*call '+pattern+r'\(',lines[i],re.I):
   new.append(f'call perf_start({k})\n');n+=1
   while True:
    new.append(lines[i]);continuation=lines[i].rstrip().endswith('&');i+=1
    if not continuation:break
   new.append(f'call perf_stop({k})\n')
  else:new.append(lines[i]);i+=1
 assert n,pattern
 return ''.join(new)
def main():
 ap=argparse.ArgumentParser(description=__doc__)
 ap.add_argument('--bundle',type=Path,required=True)
 ap.add_argument('--oracle',type=Path,required=True)
 ap.add_argument('--compiler',required=True)
 ap.add_argument('--output',type=Path,required=True)
 ap.add_argument('--repeats',type=int,default=3)
 a=ap.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 bundle=json.loads((a.bundle/'bundle.json').read_text());old=Path(bundle['exe'])
 meta=json.loads((old.parent/'build-complete.json').read_text())
 assert sha(old)==meta['executable_sha256']
 for p,h in meta['input_sha256'].items():
  if p!='app/solute_project/main.f90':assert sha(ROOT/p)==h,p
 for p,h in meta['reused_artifact_sha256'].items():assert sha(Path(p))==h,p
 assert subprocess.check_output([a.compiler,'--version'],text=True).splitlines()[0]==meta['compiler']
 report=dict(status='RUNNING',baseline=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
  production_changed=False,policy_changed=False,events=[],runs=[],cases={},compiler=a.compiler,
  script_sha256=sha(Path(__file__)),input_sha256={p:sha(ROOT/p)for p in meta['input_sha256']},
  reused_artifact_sha256=meta['reused_artifact_sha256'],generated_sha256={},flags=meta['flags'])
 def save():(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
 def execute(cmd,cwd,label):
  cmd=list(map(str,cmd));t=time.perf_counter();r=subprocess.run(cmd,cwd=cwd,capture_output=True,timeout=60)
  for stream in ['stdout','stderr']:(out/(label+'.'+stream)).write_bytes(getattr(r,stream))
  report['events'].append(dict(command=cmd,label=label,seconds=time.perf_counter()-t,returncode=r.returncode));save()
  r.check_returncode();return r
 flags=[x for x in meta['flags']if not x.startswith('-J')]
 objects=[e['command'][-1]for e in meta['source_build']['events']if e['category']=='compile'and not e['command'][-3].endswith('/app/solute_crop/main.f90')]
 assert len(objects)==193
 archive=next(p for p in meta['reused_artifact_sha256']if p.endswith('/libttutil.a'))
 ordinary=out/'ordinary'
 execute([a.compiler,*flags,'-J'+str(out),ROOT/'app/solute_project/main.f90',*objects,archive,'-o',ordinary],out,'ordinary-build')
 timer=out/'perf_clock.f90';timer.write_text(TIMER)
 execute([a.compiler,*flags,'-J'+str(out),'-c',timer,'-o',out/'perf_clock.o'],out,'timer-build')
 for path,k in [('src/transaction/mod_transaction_reference.f90',2),('src/adapter/mod_reference_richards_legacy_binding.f90',4),('src/runtime/mod_canonical_interval_runtime.f90',7)]:
  raw=(ROOT/path).read_text()
  names={2:['execute_reference_interval','execute_reference_interval_body','execute_model_certificate_interval'],4:['reference_richards_legacy_solve'],7:['run_canonical_interval']}[k]
  for name in names:
   raw,n=re.subn(r'(  subroutine '+name+r'\([^\n]+\)\n)',r'\1 use perf_clock\n',raw);assert n==1,name
  if k==2:
   raw=wrap(raw,'execute_reference_interval_body',2);raw=wrap(raw,r'model%advance',3)
   raw,n=re.subn(r'(    do retry_index = 0, policy%max_retries\n)',r'\1 call perf_start(5)\n',raw);assert n==2
   raw,n=re.subn(r'(\s+)(call reject_and_retry\(result, retry_index, policy, attempt_dt\))',r'\1call perf_stop(5)\1\2',raw);assert n==7
  elif k==4:raw=wrap(raw,'headcalc',4)
  else:
   raw=replace(raw,'    integer :: isub, max_retries_cap','    integer :: isub, max_retries_cap, perf_regime')
   anchor='      call execute_reference_interval(model, working, cursor, transaction_t1, transaction_policy, tx)'
   raw=replace(raw,anchor,'''      perf_regime=1
      if(config%retain_accepted_step_proposal)then
        perf_regime=2
        if(proposal_active)perf_regime=3
        if(solver_limited)perf_regime=4
      end if
      if(phase==1)perf_regime=5
      before_tx=total(7);before_reject=total(5)
      call perf_start(7)
'''+anchor+'''
      call perf_stop(7)
      regime_ticks(perf_regime)=regime_ticks(perf_regime)+total(7)-before_tx
      reject_ticks(perf_regime)=reject_ticks(perf_regime)+total(5)-before_reject
      counts(:,perf_regime)=counts(:,perf_regime)+int([tx%attempts,tx%full_trials,tx%half_trials, &
        tx%solver_rejections,tx%temporal_rejections,tx%mass_rejections,tx%nonlinear_iterations, &
        tx%headcalc_calls,tx%backtracking_attempts,tx%accepted_nonlinear_iterations, &
        tx%accepted_headcalc_calls,tx%accepted_backtracking_attempts],int64)
''')
  p=out/Path(path).name;p.write_text(raw);obj=out/(p.stem+'.o')
  oldobj=next(e['command'][-1]for e in meta['source_build']['events']if e['category']=='compile'and e['command'][-3].endswith('/'+path))
  execute([a.compiler,'-I'+str(out),*flags,'-J'+str(out),'-c',p,'-o',obj],out,p.stem)
  objects[objects.index(oldobj)]=str(obj);report['generated_sha256'][p.name]=sha(p)
 raw=(ROOT/'app/solute_project/main.f90').read_text()
 raw=replace(raw,'  use iso_fortran_env,','  use perf_clock\n  use iso_fortran_env,')
 raw=replace(raw,'  call get_command_argument(1,path)','  call perf_start(10)\n  call get_command_argument(1,path)')
 raw=replace(raw,"  open(newunit=u,file='budget.csv'", "  call perf_stop(10)\n  call perf_start(6)\n  open(newunit=u,file='budget.csv'")
 raw=replace(raw,'  do j=first,stop_after','  call perf_stop(6)\n  do j=first,stop_after\n    phase=0')
 raw=wrap(raw,'run_pond_joint_interval',1)
 raw=replace(raw,'      numerical%retain_accepted_step_proposal=.false.','      abandoned=abandoned+total(1)-before_tx_day\n      phase=1\n      numerical%retain_accepted_step_proposal=.false.')
 # A day total is read before the initial call, independent of transaction timers.
 raw=replace(raw,'  integer :: nodes=4','  integer(int64)::before_tx_day\n  integer :: nodes=4')
 raw=replace(raw,'    phase=0','    phase=0\n    before_tx_day=total(1)')
 raw=replace(raw,"    write(u,'(I0,16(","    call perf_start(6)\n    write(u,'(I0,16(")
 raw=replace(raw,'    clock=t1','    call perf_stop(6)\n    clock=t1')
 raw=replace(raw,'  close(u)\n  if(dynamic_temperature)then','  call perf_start(6)\n  close(u)\n  if(dynamic_temperature)then')
 raw=replace(raw,"  print '(A)','SWAP5_SOLUTE_COLUMN_COMPLETED'","  call perf_stop(6)\n  call perf_report()\n  print '(A)','SWAP5_SOLUTE_COLUMN_COMPLETED'")
 driver=out/'main.f90';driver.write_text(raw);report['generated_sha256'][driver.name]=sha(driver)
 instrumented=out/'profile'
 execute([a.compiler,'-I'+str(out),*flags,'-J'+str(out),driver,*objects,out/'perf_clock.o',archive,'-o',instrumented],out,'profile-build')
 core=min(os.sched_getaffinity(0));report['core']=core
 opt=bundle['optimization'];report['optimization']=opt
 for rain in [1,4]:
  for repeat in range(a.repeats):
   for arm in ['off','on']:
    previous=a.oracle/f'{opt}-{rain}x-{arm}-0'
    for kind,binary in [('ordinary',ordinary),('profile',instrumented)]:
     label=f'{rain}x-{arm}-{repeat}-{kind}';folder=out/label;folder.mkdir()
     for name in ['input.nml','input.swp']:(folder/name).write_bytes((previous/name).read_bytes())
     execute(['taskset','-c',core,binary,'input.nml','-','97','input.swp'],folder,label)
     for name in FILES:assert (folder/name).read_bytes()==(previous/name).read_bytes(),(label,name)
     row=dict(rain=rain,repeat=repeat,arm=arm,kind=kind,seconds=report['events'][-1]['seconds'],output_sha256={n:sha(folder/n)for n in FILES})
     if kind=='profile':
      row['timers']=list(csv.DictReader((folder/'profile.csv').open()))
      row['regimes']=[dict(regime=int(v[0]),seconds=float(v[1]),rejected_seconds=float(v[2]),counts=list(map(int,v[3:])))for v in [l.split()for l in (folder/'regimes.txt').read_text().splitlines()]]
      row['abandoned_day_seconds']=float((folder/'abandoned.txt').read_text())
      assert sum(x['counts'][5]for x in row['regimes'])==0
     report['runs'].append(row);save()
 for rain in [1,4]:
  for arm in ['off','on']:
   selected=[r for r in report['runs']if r['rain']==rain and r['arm']==arm];pr=[r for r in selected if r['kind']=='profile']
   incl={k:statistics.median(float(r['timers'][k-1]['seconds'])for r in pr)for k in range(1,11)}
   assert all([g['counts']for g in r['regimes']]==[g['counts']for g in pr[0]['regimes']]for r in pr)
   report['cases'][f'{rain}x-{arm}']=dict(native_seconds=statistics.median(r['seconds']for r in selected if r['kind']=='ordinary'),profile_seconds=statistics.median(r['seconds']for r in pr),
    headcalc_seconds=incl[4],provider_seconds=incl[3]-incl[4],transaction_controller_seconds=incl[2]-incl[3],
    joint_orchestration_seconds=incl[1]-incl[2],rejected_seconds=incl[5],output_serialization_seconds=incl[6],input_setup_seconds=incl[10],
    abandoned_day_seconds=statistics.median(r['abandoned_day_seconds']for r in pr),
    regimes=[dict(regime=k,seconds=statistics.median(r['regimes'][k-1]['seconds']for r in pr),rejected_seconds=statistics.median(r['regimes'][k-1]['rejected_seconds']for r in pr),counts=pr[0]['regimes'][k-1]['counts'])for k in range(1,6)])
 report['status']='CURRENT_NATIVE_OFF_ON_PROFILE_PHYSICAL_BYTES_EXACT';save()
 print(json.dumps(report['cases'],indent=2))
if __name__=='__main__':main()
