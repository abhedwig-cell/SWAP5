"""Observe real nonlinear phases and test an early-rejection research relink."""
import argparse,csv,hashlib,json,os,statistics,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
HEAD='src/legacy/b1_10_port/headcalc.f90';APP='app/solute_project/main.f90'
FILES=['budget.csv','state.csv','endpoint.csv','restart.bin']
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def rows(p):return list(csv.DictReader(p.open()))
def once(s,a,b):
 assert s.count(a)==1,a
 return s.replace(a,b)
DIAG='''module perf_failure_diag
 use iso_fortran_env,only:int64,real64
 implicit none
 integer::diag_day=1,diag_app_phase=1,detail_unit=0
 integer(int64)::tally(6,97,2,3,2)=0
 real(real64)::seconds(97,2,3,2)=0d0
 contains
 subroutine failure_record(kind,phase,niter,nback,nfail,dt,initial,last,fmax,resid,h,cap,origin,started)
 integer,intent(in)::kind,phase,niter,nback,nfail
 real(real64),intent(in)::dt,initial,last,fmax,resid,h(:),cap(:),origin(:)
 integer(int64),intent(in)::started
 integer(int64)::now,rate
 integer::d,a
 call system_clock(now,count_rate=rate)
 d=diag_day;a=diag_app_phase
 tally(:,d,a,phase,kind)=tally(:,d,a,phase,kind)+int([1,niter,nback,nfail, &
 merge(1,0,all(origin>=0d0)),merge(1,0,nfail>0)],int64)
 seconds(d,a,phase,kind)=seconds(d,a,phase,kind)+real(now-started,real64)/real(rate,real64)
 if(detail_unit==0)then
 open(newunit=detail_unit,file='nonlinear.csv',status='new')
 write(detail_unit,'(A)')'day,app_phase,internal_phase,result,iterations,backtracks,failed_lines,dt,initial_norm,last_norm,max_residual,sum_residual,min_head,max_head,min_capacity,max_capacity,min_origin,max_origin'
 endif
 if(kind==2.or.nfail>0)write(detail_unit,'(I0,6(A,I0),11(A,ES25.17E3))')d,',',a,',',phase,',',kind,',',niter,',',nback,',',nfail, &
 ',',dt,',',initial,',',last,',',fmax,',',resid,',',minval(h),',',maxval(h),',',minval(cap),',',maxval(cap),',',minval(origin),',',maxval(origin)
 end subroutine
 subroutine failure_report()
 integer::u,d,a,p,k
 if(detail_unit/=0)close(detail_unit)
 open(newunit=u,file='nonlinear_summary.csv',status='new')
 write(u,'(A)')'day,app_phase,internal_phase,result,calls,iterations,backtracks,failed_lines,saturated_origins,phases_with_failed_lines,seconds'
 do k=1,2
 do p=1,3
 do a=1,2
 do d=1,97
 if(tally(1,d,a,p,k)>0)write(u,'(I0,9(A,I0),A,ES25.17E3)')d,',',a,',',p,',',k, &
 ',',tally(1,d,a,p,k),',',tally(2,d,a,p,k),',',tally(3,d,a,p,k),',',tally(4,d,a,p,k), &
 ',',tally(5,d,a,p,k),',',tally(6,d,a,p,k),',',seconds(d,a,p,k)
 enddo
 enddo
 enddo
 enddo
 close(u)
 end subroutine
 end module
'''
def observe(raw):
 raw=once(raw,'   implicit none','   use perf_failure_diag,only:failure_record\n   implicit none')
 raw=once(raw,'   integer                          :: numnod','   integer(8)::pd_started\n   integer::pd_n0,pd_b0,pd_failed\n   real(8)::pd_initial\n   integer                          :: numnod')
 raw=once(raw,'900 continue','''900 continue
   call system_clock(pd_started)
   pd_n0=ctx%diagnostics%nonlinear_iterations
   pd_b0=ctx%diagnostics%backtracking_attempts
   pd_failed=0''')
 raw=once(raw,'   ! Evaluate both initial residuals','   pd_initial=sqrt(2d0*sumold)\n   ! Evaluate both initial residuals')
 raw=once(raw,' 1    continue',' 1    continue\n      if(itry>MaxBackTr.and.sump>=sumold.and.Fmax>=CritDevBalCp)pd_failed=pd_failed+1')
 raw=once(raw,'         if (legacy_state_binding) call publish_legacy_state(state)\n         return\n      end if\n   ! end do solver_numbit', '         call pd_emit(1)\n         if (legacy_state_binding) call publish_legacy_state(state)\n         return\n      end if\n   ! end do solver_numbit')
 raw=once(raw,'!  Convergence could not been reached','   call pd_emit(2)\n!  Convergence could not been reached')
 raw=once(raw,'contains\n','''contains
subroutine pd_emit(kind)
 integer,intent(in)::kind
 integer::phase
 phase=1
 if(corner_retry_active)phase=2
 if(saturated_flux_active)phase=3
 call failure_record(kind,phase,ctx%diagnostics%nonlinear_iterations-pd_n0, &
 ctx%diagnostics%backtracking_attempts-pd_b0,pd_failed,dt,pd_initial,sqrt(2d0*sump), &
 maxval(abs(fsi_ws%residual(1:NN))),sum(fsi_ws%residual(1:NN)),state%h(1:NN), &
 state%dimoca(1:NN),state%hm1(1:NN),pd_started)
end subroutine
''')
 return raw
def early(raw):
 return once(raw,' 1    continue',''' 1    continue
      ! GENERATED RESEARCH ONLY: fail the phase through existing restart/retry.
      if(.not.legacy_state_binding.and.provider_dynamic_top_active.and.swbotb==2.and. &
         swkimpl==0.and.swkmean==1.and..not.consistent_provider_conductivity.and. &
         .not.picard_conductivity_iteration.and..not.provider_macropore_active)then
        if(itry>MaxBackTr.and.sump>=sumold.and.Fmax>=CritDevBalCp)exit
      end if''')
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--bundle-prefix',type=Path,required=True)
 ap.add_argument('--inputs',type=Path,required=True);ap.add_argument('--compiler',required=True);ap.add_argument('--output',type=Path,required=True)
 a=ap.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 report=dict(status='RUNNING',candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
  script_sha256=sha(Path(__file__)),production_changed=False,events=[],builds={},cases={})
 def save():(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
 def run(cmd,cwd,label,required=True):
  cmd=list(map(str,cmd));t=time.perf_counter()
  try:r=subprocess.run(cmd,cwd=cwd,capture_output=True,timeout=60)
  except subprocess.TimeoutExpired as e:r=subprocess.CompletedProcess(cmd,124,e.stdout or b'',e.stderr or b'')
  for s in ['stdout','stderr']:(out/(label+'.'+s)).write_bytes(getattr(r,s))
  report['events'].append(dict(label=label,command=cmd,seconds=time.perf_counter()-t,returncode=r.returncode));save()
  if required:r.check_returncode()
  return r
 core=min(os.sched_getaffinity(0));report['core']=core
 for opt in ['O0','O2']:
  bundle=json.loads((Path(str(a.bundle_prefix)+'-'+opt)/'bundle.json').read_text());exe=Path(bundle['exe']);meta=json.loads((exe.parent/'build-complete.json').read_text())
  assert sha(exe)==meta['executable_sha256']
  for p,h in meta['input_sha256'].items():assert sha(ROOT/p)==h,p
  for p,h in meta['reused_artifact_sha256'].items():assert sha(Path(p))==h,p
  assert subprocess.check_output([a.compiler,'--version'],text=True).splitlines()[0]==meta['compiler']
  report['builds'][opt]=dict(input_sha256=meta['input_sha256'],reused_artifact_sha256=meta['reused_artifact_sha256'],ordinary_executable_sha256=sha(exe),flags=meta['flags'])
  folder=out/opt;folder.mkdir();flags=[f for f in meta['flags']if not f.startswith('-J')]
  objects=[e['command'][-1]for e in meta['source_build']['events']if e['category']=='compile'and not e['command'][-3].endswith('/app/solute_crop/main.f90')];assert len(objects)==193
  oldobj=next(e['command'][-1]for e in meta['source_build']['events']if e['category']=='compile'and e['command'][-3].endswith('/'+HEAD))
  archive=next(p for p in meta['reused_artifact_sha256']if p.endswith('/libttutil.a'))
  d=folder/'diag.f90';d.write_text(DIAG)
  run([a.compiler,*flags,'-J'+str(folder),'-c',d,'-o',folder/'diag.o'],folder,opt+'-diag-build')
  binaries={'ordinary':exe}
  for kind,source in [('observer',observe((ROOT/HEAD).read_text())),('early',early((ROOT/HEAD).read_text()))]:
   src=folder/(kind+'.f90');src.write_text(source);obj=folder/(kind+'.o')
   run([a.compiler,'-I'+str(folder),*flags,'-J'+str(folder),'-c',src,'-o',obj],folder,opt+'-'+kind+'-build')
   objs=[str(obj)if p==oldobj else p for p in objects];main=ROOT/APP;extra=[]
   if kind=='observer':
    raw=(ROOT/APP).read_text();raw=once(raw,'  use iso_fortran_env,','  use perf_failure_diag\n  use iso_fortran_env,')
    raw=once(raw,'  do j=first,stop_after','  do j=first,stop_after\n    diag_day=j;diag_app_phase=1')
    raw=once(raw,'      numerical%retain_accepted_step_proposal=.false.','      diag_app_phase=2\n      numerical%retain_accepted_step_proposal=.false.')
    raw=once(raw,"  print '(A)','SWAP5_SOLUTE_COLUMN_COMPLETED'","  call failure_report()\n  print '(A)','SWAP5_SOLUTE_COLUMN_COMPLETED'")
    main=folder/'main.f90';main.write_text(raw);extra=[folder/'diag.o']
   binary=folder/kind;run([a.compiler,'-I'+str(folder),*flags,'-J'+str(folder),main,*objs,*extra,archive,'-o',binary],folder,opt+'-'+kind+'-link');binaries[kind]=binary
  for rain in [1,4]:
   previous=a.inputs/f'O2-{rain}x-on-0';samples=[]
   for rep in range(3 if opt=='O2'else 1):
    for kind in (['ordinary','early','observer']if rep==0 else['ordinary','early']):
     label=f'{opt}-{rain}x-{kind}-{rep}';case=out/label;case.mkdir()
     for n in ['input.nml','input.swp']:(case/n).write_bytes((previous/n).read_bytes())
     r=run(['taskset','-c',core,binaries[kind],'input.nml','-','97','input.swp'],case,label,kind!='early')
     if r.returncode:
      report['status']='EARLY_REJECTION_RESEARCH_FAILED';report['failure']=label;save();return
     if kind in ['ordinary','observer']:
      target=out/f'{opt}-{rain}x-ordinary-0'
      for n in FILES:assert (case/n).read_bytes()==(target/n).read_bytes(),(label,n)
     else:
      target=out/f'{opt}-{rain}x-early-0'
      for n in FILES:assert (case/n).read_bytes()==(target/n).read_bytes(),(label,n)
     samples.append(dict(kind=kind,repeat=rep,seconds=report['events'][-1]['seconds']))
   data=rows(out/f'{opt}-{rain}x-early-0/budget.csv');reference=rows(out/f'{opt}-{rain}x-ordinary-0/budget.csv');assert len(data)==len(reference)==97
   assert max(abs(float(d['water_residual_cm']))for d in data)<1e-10
   diff={k:dict(max_mm=10*max(abs(float(d[k])-float(s[k]))for d,s in zip(data,reference)),sum_mm=10*sum(float(d[k])-float(s[k])for d,s in zip(data,reference)))for k in ['runoff_cm','water_end_cm','actual_transpiration_cm','soil_evaporation_cm','pond_evaporation_cm']}
   assert diff['runoff_cm']['max_mm']<.01 and abs(diff['runoff_cm']['sum_mm'])<.01 and diff['water_end_cm']['max_mm']<.01
   assert diff['actual_transpiration_cm']['max_mm']<1e-8
   assert 10*max(abs(float(d['soil_evaporation_cm'])+float(d['pond_evaporation_cm'])-float(s['soil_evaporation_cm'])-float(s['pond_evaporation_cm']))for d,s in zip(data,reference))<1e-8
   for kind in ['half','resume']:
    label=f'{opt}-{rain}x-{kind}';case=out/label;case.mkdir()
    for n in ['input.nml','input.swp']:(case/n).write_bytes((previous/n).read_bytes())
    run([binaries['early'],'input.nml',out/f'{opt}-{rain}x-half/restart.bin'if kind=='resume'else'-','48'if kind=='half'else'97','input.swp'],case,label)
    if kind=='resume':
     for n in FILES[1:]:assert (case/n).read_bytes()==(out/f'{opt}-{rain}x-early-0'/n).read_bytes()
     assert rows(case/'budget.csv')==data[48:]
   report['cases'][f'{opt}-{rain}x']=dict(samples=samples,differences=diff,native_median={k:statistics.median(s['seconds']for s in samples if s['kind']==k)for k in ['ordinary','early']});save()
 for rain in [1,4]:
  for n in FILES:assert (out/f'O0-{rain}x-early-0'/n).read_bytes()==(out/f'O2-{rain}x-early-0'/n).read_bytes(),(rain,n)
 report['status']='CURRENT_NONLINEAR_OBSERVER_EXACT_EARLY_RESEARCH_O0_O2_RESTART_PASS';save();print(json.dumps(report['cases'],indent=2))
if __name__=='__main__':main()
