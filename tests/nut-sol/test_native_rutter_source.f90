program test_native_rutter_source
 use iso_fortran_env,only:real64,int64
 use mod_interception_source_window_runtime
 use mod_rutter_interception_process
 use mod_rutter_source_window_processor
 implicit none
 type(interception_source_window_t)::window,restored_window
 type(rutter_source_state_t)::state,candidate,half,twice,restored
 type(rutter_source_trial_t)::trial,half_trial
 type(rutter_source_restart_t)::record
 type(rutter_interval_input_t)::f,bad
 type(rutter_interval_result_t)::r,r1,r2
 type(rutter_diagnostics_t)::d
 real(real64)::t0,t1,amount,cover,cap,dry,wet,evap,dt,before,mid,residual,maxres,totalrain,throughfall,evaporated, &
  rstart,refinement,maxref
 integer::u,ios,status,n
 integer(int64)::id
 logical::restart
 character(1024)::input,mode
 call get_command_argument(1,input);call get_command_argument(2,mode);restart=trim(mode)=='restart'
 open(newunit=u,file=trim(input),status='old',action='read')
 n=0;maxres=0._real64;totalrain=0._real64;throughfall=0._real64;evaporated=0._real64;maxref=0._real64
 do
  read(u,*,iostat=ios)id,t0,t1,amount,cover,cap,dry,wet,evap
  if(ios<0)exit
  if(ios/=0)error stop 'source record'
  call initialize_interception_window(id,t0,t1,amount,window,status)
  if(status/=0)error stop 'source window'
  if(n==0)then
   call initialize_rutter_source_state(window,0._real64,state,status)
   if(status/=0)error stop 'source initial state'
  end if
  before=state%canopy_storage();rstart=state%accepted_until();dt=t1-t0
  f=rutter_interval_input_t();f%vegetation_cover_fraction=cover;f%canopy_storage_capacity_cm=cap
  f%potential_transpiration_dry_cm_per_day=dry;f%potential_transpiration_wet_cm_per_day=wet
  f%interception_evaporation_capacity_cm_per_day=evap
  bad=f;bad%vegetation_cover_fraction=1.5_real64
  call prepare_rutter_source_trial(window,state,t1,bad,r,trial,d,status)
  if(status==0)error stop 'invalid source accepted'
  if(state%canopy_storage()/=before.or.state%accepted_until()/=rstart)error stop 'invalid source leaked'
  call prepare_rutter_source_trial(window,state,t1,f,r,trial,d,status)
  if(status/=0.or..not.d%result_produced)error stop 'source trial'
  if(state%canopy_storage()/=before.or.state%accepted_until()/=rstart)error stop 'source trial mutated input'
  call accept_rutter_source_trial(window,state,trial,candidate,status)
  if(status/=0)error stop 'source commit'
  residual=amount-r%net_rain_cm_per_day*dt-r%reservoir_outflow_cm_per_day*dt-(candidate%canopy_storage()-before)
  if(abs(residual)>1e-12_real64)error stop 'source mass closure'
  mid=t0+.5_real64*dt
  call prepare_rutter_source_trial(window,state,mid,f,r1,half_trial,d,status)
  if(status/=0)error stop 'half source trial'
  call accept_rutter_source_trial(window,state,half_trial,half,status)
  if(status/=0)error stop 'half source commit'
  call prepare_rutter_source_trial(window,half,t1,f,r2,half_trial,d,status)
  if(status/=0)error stop 'second source half'
  call accept_rutter_source_trial(window,half,half_trial,twice,status)
  if(status/=0)error stop 'second source half commit'
  refinement=max(abs(twice%canopy_storage()-candidate%canopy_storage()), &
   abs(r%net_rain_cm_per_day*dt-r1%net_rain_cm_per_day*(mid-t0)-r2%net_rain_cm_per_day*(t1-mid)), &
   abs(r%reservoir_outflow_cm_per_day*dt-r1%reservoir_outflow_cm_per_day*(mid-t0)-r2%reservoir_outflow_cm_per_day*(t1-mid)))
  if(refinement>1e-12_real64)error stop 'source refinement'
  state=candidate
  if(restart)then
   call export_rutter_source_restart(window,state,record,status)
   if(status/=0)error stop 'source restart export'
   call restore_rutter_source_restart(record,restored_window,restored,status)
   if(status/=0.or.restored%canopy_storage()/=state%canopy_storage().or. &
      restored%accepted_until()/=state%accepted_until())error stop 'source restart restore'
   state=restored
  end if
  maxres=max(maxres,abs(residual));maxref=max(maxref,refinement)
  totalrain=totalrain+amount;throughfall=throughfall+r%net_rain_cm_per_day*dt
  evaporated=evaporated+r%reservoir_outflow_cm_per_day*dt;n=n+1
 end do
 close(u)
 if(n<481.or.totalrain<=0._real64.or.evaporated<=0._real64)error stop 'inactive original source composition'
 if(abs(totalrain-throughfall-evaporated-state%canopy_storage())>1e-10_real64)error stop 'integral source budget'
 write(*,'(a,i0)')'ORIGINAL_NATIVE_RUTTER_SOURCE_RECORDS=',n
 write(*,'(a,*(es25.17e3,1x))')'ORIGINAL_NATIVE_RUTTER_SOURCE_BALANCES=', &
  totalrain,throughfall,evaporated,state%canopy_storage(),maxres,maxref
 print '(a)','ORIGINAL_NATIVE_RUTTER_SOURCE481_REJECT_REFINEMENT_TYPED_RESTART_PASS'
end program
