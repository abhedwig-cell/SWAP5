"""One cold O0/O2 private16-versus-current4 heat-contract discriminator.

The existing six-boundary/state/refusal driver is reused. No production file,
native checkpoint or application numerical profile is changed.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time

ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--compiler',type=Path,required=True)
a=p.parse_args();out=a.output.resolve();out.mkdir()
sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
body=ROOT/'src/process/mod_restricted_soil_temperature.f90'
text=body.read_text()
needle='nsteps/=4.or.parameters%solution_mode'
assert text.count(needle)==1
text=text.replace(needle,'(nsteps/=4.and.nsteps/=16).or.parameters%solution_mode')
text=text.replace('mod_restricted_soil_temperature','mod_restricted_soil_temperature_sixteen')
private=out/'private_sixteen.f90';private.write_text(text,newline='\n')
old=ROOT/'research/hybrid-water01/test_thermal_subcycle.f90'
driver=old.read_text()
driver=driver.replace(' use mod_restricted_soil_temperature,only:',
                      ' use mod_restricted_soil_temperature_sixteen,only:')
driver=driver.replace('mod_restricted_soil_temperature_control,only:',
                      'mod_restricted_soil_temperature,only:')
driver=driver.replace('type(soil_temperature_numerical_config_t)::num',
                      'type(soil_temperature_numerical_config_t)::num,single_num')
driver=driver.replace('real(real64)::faces(3),a,b,dt,cell(2),defect',
                      'real(real64)::faces(3),a,b,dt,cell(2),defect,error4,error16,cpu4,cpu16,limit4,limit16')
driver=driver.replace('dt=.04d0;cases=0','dt=.04d0;cases=0;num%internal_heat_substeps=16')
driver=driver.replace('d%tridiagonal_solves/=4.or.d%constitutive_evaluations/=4',
                      'd%tridiagonal_solves/=16.or.d%constitutive_evaluations/=16')
driver=driver.replace('do k=1,4','do k=1,16').replace('/4d0','/16d0').replace('if(k==4)','if(k==16)')
driver=driver.replace('call original_trial(p,num,','call original_trial(p,single_num,')
driver=driver.replace('  cases=cases+1', '''  call indicator(4,error4)
  call indicator(16,error16)
  write(*,'(a,2(i0,a),3(es25.17,a))')'THERMAL_INDICATOR,',top,',',bottom,',', &
       error4,',',error16,',',error16/max(error4,tiny(1d0)),','
  cases=cases+1''')
driver=driver.replace(' ! A rejected call', ''' f%bottom_boundary_mode=SOIL_TEMP_BOTTOM_ZERO_HEAT_FLUX
 call calibrate(4,limit4,error4)
 call calibrate(16,limit16,error16)
 write(*,'(a,5(es25.17,a))')'THERMAL_ACCEPTED_DT,',limit4,',',limit16,',',limit16/limit4,',',error4,',',error16,','
 call cost(4,cpu4)
 call cost(16,cpu16)
 write(*,'(a,3(es25.17,a))')'THERMAL_KERNEL_SECONDS,',cpu4,',',cpu16,',',cpu16/max(cpu4,tiny(1d0)),','
 ! A rejected call''')
helpers='''contains
 subroutine step(count,source,t0,t1,target,work)
  integer,intent(in)::count
  type(soil_temperature_state_t),intent(in)::source
  type(soil_temperature_state_t),intent(out)::target
  type(soil_temperature_workspace_t),intent(inout)::work
  real(real64),intent(in)::t0,t1
  type(soil_temperature_numerical_config_t)::policy
  type(soil_temperature_result_t)::result
  type(soil_temperature_diagnostics_t)::diag
  policy%internal_heat_substeps=count
  if(count==4)then
   call original_trial(p,policy,f,h,h,source,t0,t1,work,target,result,diag)
  else
   call trial_restricted_soil_temperature(p,policy,f,h,h,source,t0,t1,work,target,result,diag)
  end if
  if(result%status/=SOIL_TEMP_OK.or..not.result%produced)error stop 'discriminator trial'
 end subroutine
 subroutine indicator(count,error,interval)
  integer,intent(in)::count
  real(real64),intent(out)::error
  real(real64),intent(in),optional::interval
  type(soil_temperature_state_t)::full,half,finish
  type(soil_temperature_workspace_t)::work
  real(real64),allocatable::vf(:),vh(:)
  integer::s
  real(real64)::span
  span=dt
  if(present(interval))span=interval
  call step(count,initial,0d0,span,full,work)
  call step(count,initial,0d0,span/2d0,half,work)
  call step(count,half,span/2d0,span,finish,work)
  call copy_soil_temperature_profile(full,vf,s)
  if(s/=SOIL_TEMP_OK)error stop 'full profile'
  call copy_soil_temperature_profile(finish,vh,s)
  if(s/=SOIL_TEMP_OK)error stop 'half profile'
  error=maxval(abs(vf-vh))
 end subroutine
 subroutine calibrate(count,limit,error)
  integer,intent(in)::count
  real(real64),intent(out)::limit,error
  real(real64)::lo,hi,mid,e
  integer::j
  lo=0d0;hi=dt
  do j=1,40
   mid=0.5d0*(lo+hi)
   call indicator(count,e,mid)
   if(e<=1d-5)then
    lo=mid
   else
    hi=mid
   end if
  end do
  limit=lo
  call indicator(count,error,limit)
  if(error>1d-5)error stop 'unchanged thermal gate'
 end subroutine
 subroutine cost(count,seconds)
  integer,intent(in)::count
  real(real64),intent(out)::seconds
  type(soil_temperature_state_t)::target
  type(soil_temperature_workspace_t)::work
  real(real64)::start,finish
  integer::j,k
  call cpu_time(start)
  j=0
  do
   do k=1,1000
    call step(count,initial,0d0,dt,target,work)
   end do
   j=j+1000
   call cpu_time(finish)
   if(finish-start>=0.5d0.or.j>=2000000)exit
  end do
  seconds=(finish-start)/real(j,real64)
  write(*,'(a,2(i0,a),2(es25.17,a))')'THERMAL_COST_OBSERVATION,',count,',',j,',',finish-start,',',seconds,','
 end subroutine
'''
driver=driver.replace('end program',helpers+'end program')
generated=out/'driver.f90';generated.write_text(driver,newline='\n')
sources=[ROOT/x for x in ['src/transaction/mod_transaction_reference.f90',
 'src/solver/mod_soil_water_solver_contract.f90','src/solver/mod_process_hydraulic_view.f90',
 'src/process/mod_soil_temperature_contract.f90','src/process/mod_restricted_soil_temperature.f90',
 'src/runtime/mod_fmr_thermal_substep_receipt.f90']]+[private,generated]
events=[];results={}
def run(cmd,folder,label,limit=60):
 start=time.perf_counter()
 try:
  r=subprocess.run(list(map(str,cmd)),cwd=folder,capture_output=True,timeout=limit);rc=r.returncode
 except subprocess.TimeoutExpired as e:r=e;rc=None
 (folder/(label+'.stdout')).write_bytes(r.stdout or b'')
 (folder/(label+'.stderr')).write_bytes(r.stderr or b'')
 events.append(dict(label=label,optimization=folder.name,command=list(map(str,cmd)),seconds=time.perf_counter()-start,returncode=rc))
 (out/'events.json').write_text(json.dumps(events,indent=2)+'\n',newline='\n')
 assert rc==0,(label,rc)
 return r.stdout.decode()
for opt in ['O0','O2']:
 folder=out/opt;folder.mkdir()
 flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-fbacktrace',
        '-ffpe-trap=invalid,zero,overflow','-I'+str(folder),'-J'+str(folder)]
 objects=[]
 for i,source in enumerate(sources):
  obj=folder/f'{i}.o';run([a.compiler,*flags,'-c',source,'-o',obj],folder,f'compile-{i}');objects.append(obj)
 exe=folder/'probe.exe';run([a.compiler,*objects,'-o',exe],folder,'link')
 stdout=run([exe],folder,'native',120)
 assert 'THERMAL_SUBCYCLE_ORIGINAL_SOLVES_FACES_AND_REFUSAL=PASS' in stdout
 cases=[];timing=None;cost_samples=[];accepted=None
 for line in stdout.splitlines():
  parts=line.split(',')
  if parts[0]=='THERMAL_INDICATOR':cases.append(dict(top=int(parts[1]),bottom=int(parts[2]),error4=float(parts[3]),error16=float(parts[4]),ratio=float(parts[5])))
  if parts[0]=='THERMAL_KERNEL_SECONDS':timing=dict(four=float(parts[1]),sixteen=float(parts[2]),ratio=float(parts[3]))
  if parts[0]=='THERMAL_COST_OBSERVATION':cost_samples.append(dict(count=int(parts[1]),calls=int(parts[2]),cpu_seconds=float(parts[3]),seconds_per_call=float(parts[4])))
  if parts[0]=='THERMAL_ACCEPTED_DT':accepted=dict(four=float(parts[1]),sixteen=float(parts[2]),ratio=float(parts[3]),error4=float(parts[4]),error16=float(parts[5]))
 assert len(cases)==6 and timing and timing['four']>0 and timing['sixteen']>0
 assert accepted and accepted['error4']<=1e-5 and accepted['error16']<=1e-5
 assert len(cost_samples)==2 and min(x['cpu_seconds'] for x in cost_samples)>=.5
 results[opt]=dict(cases=cases,kernel_cpu_seconds_per_call=timing,cost_samples=cost_samples,
                  unchanged_budget_dt=accepted,executable_sha256=sha(exe))
record=dict(status='COLD_O0_O2_PRIVATE_SIXTEEN_CONTRACT_AND_INDICATOR_COST_PASS',
 original_driver_sha256=sha(old),source_sha256={str(s):sha(s) for s in sources},
 compiler=subprocess.check_output([str(a.compiler),'--version']).decode().splitlines()[0],
 results=results,events=events,scope=__doc__,external_temperature_budget_c=1e-5,
 production_admission=False,application_speedup='NOT_MEASURED',whole_science='NOT_GRANTED')
(out/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n',newline='\n')
print(json.dumps({'status':record['status'],'results':results}))
