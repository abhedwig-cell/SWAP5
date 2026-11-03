program native_feedback_component
 use iso_fortran_env,only:real64
 use mod_restricted_soil_temperature
 use mod_native_coupled_transaction
 use mod_native_macro_heat_feedback
 use mod_process_hydraulic_view,only:process_hydraulic_view_t
 use mod_transaction_reference
 implicit none
 type(native_coupled_model_t)::model
 type(native_coupled_state_t)::origin,restored
 class(transaction_state_t),allocatable::accepted
 type(transaction_result_t)::tx
 type(native_heat_feedback_result_t)::heat
 type(soil_temperature_state_t)::initial,baseline
 type(soil_temperature_workspace_t)::workspace
 type(soil_temperature_result_t)::base_result
 type(soil_temperature_diagnostics_t)::diagnostic
 type(process_hydraulic_view_t)::h0,h1
 real(real64)::w0(1,2),w1(1,2),face(1,3),qx(1,2),outflow(1,2),temperature(1,2)
 integer::status,k,u
 integer(kind=1)::bad_byte
 logical::ok,manufactured_nonlinear=.false.,fail_after_leaf=.false.
 call initialize_soil_temperature_parameters([1d0,2d0],[.5d0,1.5d0], &
  [.45d0,.45d0],[.3d0,.3d0],[.2d0,.2d0],[.05d0,.05d0],model%heat_parameters,status)
 if(status/=SOIL_TEMP_OK)error stop 'parameters'
 model%heat_forcing%top_boundary_mode=SOIL_TEMP_TOP_PRESCRIBED_HEAT_FLUX
 model%heat_forcing%prescribed_top_heat_flux_j_cm2_day=0d0
 call initialize_soil_temperature_state([10d0,10d0],initial,status)
 h0%active_nodes=2;h1%active_nodes=2;h0%water_content=[.2d0,.2d0];h1%water_content=[.21d0,.2d0]
 w0=.1d0;w1=w0;w1(1,1)=.09d0;face=0d0;qx=0d0;qx(1,1)=10d0;outflow=0d0;temperature=20d0
 call trial_native_macro_heat_feedback(model%heat_parameters,model%heat_numerical,model%heat_forcing,h0,h1,initial, &
  w0,w1,face,qx,outflow,temperature,reshape([.true.,.true.],[1,2]),[0d0],[0d0],[.false.], &
  [0d0],[0d0],[.false.],0d0,.001d0,16,heat)
 if(.not.heat%produced)error stop 'feedback unavailable'
 if(heat%matrix_temperature_c(1)<=10d0)error stop 'no native heat feedback'
 if(abs(heat%joint_residual_j_cm2)>1d-9)error stop 'joint heat balance'
 print '(a,2es25.17e3)','FEEDBACK_PASS ',heat%matrix_temperature_c(1),heat%joint_residual_j_cm2
 ! With zero macro exchange the companion must reproduce the actual native matrix
 ! for both accepted top modes and both bottom modes.
 qx=0d0;w1=w0;h1=h0
 do k=1,4
  model%heat_forcing%top_boundary_mode=SOIL_TEMP_TOP_PRESCRIBED_HEAT_FLUX
  if(mod(k,2)==0)model%heat_forcing%top_boundary_mode=SOIL_TEMP_TOP_AIR_TEMPERATURE
  model%heat_forcing%air_temperature_c=8d0
  model%heat_forcing%bottom_boundary_mode=SOIL_TEMP_BOTTOM_ZERO_HEAT_FLUX
  if(k>2)model%heat_forcing%bottom_boundary_mode=SOIL_TEMP_BOTTOM_PRESCRIBED_TEMPERATURE
  model%heat_forcing%prescribed_bottom_temperature_c=12d0
  call trial_restricted_soil_temperature(model%heat_parameters,model%heat_numerical,model%heat_forcing,h0,h1,initial, &
   0d0,.001d0,workspace,baseline,base_result,diagnostic)
  call trial_native_macro_heat_feedback(model%heat_parameters,model%heat_numerical,model%heat_forcing,h0,h1,initial, &
   w0,w1,face,qx,outflow,temperature,reshape([.true.,.true.],[1,2]),[0d0],[0d0],[.false.], &
   [0d0],[0d0],[.false.],0d0,.001d0,16,heat)
  if(.not.heat%produced.or.base_result%status/=SOIL_TEMP_OK)error stop 'zero feedback baseline'
  if(maxval(abs(heat%matrix_temperature_c-workspace%solution))>1d-12)error stop 'native assembly differs'
 end do
 model%heat_forcing%top_boundary_mode=SOIL_TEMP_TOP_PRESCRIBED_HEAT_FLUX
 model%heat_forcing%bottom_boundary_mode=SOIL_TEMP_BOTTOM_ZERO_HEAT_FLUX
 origin%head=[-10d0,-10d0];origin%theta=[.2d0,.2d0];origin%area_dz=[1d0,1d0]
 origin%matrix_temperature=[10d0,10d0];allocate(origin%macro_temperature(1,2));origin%macro_temperature=20d0
 call origin%macro%initialize(1,2,ok)
 origin%macro%water_domain_cp=.1d0;origin%macro%volume_domain_cp=.2d0
 do k=0,3
  call origin%clone(accepted)
  model%water_trial=>water
  model%allow_source_proxies=k/=0;model%inject_feedback_failure=k==2
  model%rain_temperature=15d0;model%water_calls=0;model%feedback_calls=0;model%donor_refusals=0
  select type(accepted)
  type is(native_coupled_state_t)
   accepted%source_proxy_policy=model%allow_source_proxies
  end select
  if(k==3)then
   select type(accepted)
   type is(native_coupled_state_t)
    accepted%model_id='INVALID'
   end select
  end if
  call execute_native_coupled_transaction(model,accepted,0d0,1d-5,tx)
  print '(a,6i5,3es25.17e3)','TRANSACTION ',k,tx%status,tx%commits,tx%full_trials,tx%half_trials,model%water_calls, &
   tx%full_mass_residual,tx%half_mass_residual,tx%temporal_error
  select type(accepted)
  type is(native_coupled_state_t)
   if(k==1)then
    if(tx%status/=TX_STATUS_ACCEPTED.or.tx%commits/=1.or.tx%full_trials/=1.or.tx%half_trials/=2)error stop 'actual full-half acceptance'
    if(tx%temporal_error>1d-6)error stop 'temporal guard'
    if(accepted%revision/=1.or.accepted%time/=1d-5)error stop 'atomic revision'
    if(accepted%matrix_temperature(1)<=10d0)error stop 'heat omitted from commit'
    call write_native_coupled_restart('coupled.bin',repeat('a',64),accepted,status)
    if(status/=0)error stop 'durable new model restart'
    restored=origin
    call read_native_coupled_restart('coupled.bin',repeat('b',64),restored,status)
    if(status==0.or.restored%time/=origin%time)error stop 'restart binding rollback'
    call read_native_coupled_restart('coupled.bin',repeat('a',64),restored,status)
    if(status/=0.or.restored%revision/=accepted%revision.or.restored%time/=accepted%time)error stop 'typed restart header'
    if(any(restored%head/=accepted%head).or.any(restored%theta/=accepted%theta).or. &
     any(restored%area_dz/=accepted%area_dz).or.any(restored%matrix_temperature/=accepted%matrix_temperature).or. &
     any(restored%macro_temperature/=accepted%macro_temperature).or..not.restored%macro%same_values(accepted%macro))error stop 'restart payload'
    open(newunit=u,file='coupled.bin',access='stream',form='unformatted',status='old',action='readwrite')
    bad_byte=0;write(u,pos=1)bad_byte;close(u)
    call read_native_coupled_restart('coupled.bin',repeat('a',64),restored,status)
    if(status==0.or.restored%revision/=accepted%revision.or.restored%time/=accepted%time)error stop 'CRC rollback'
    print '(a)','TYPED_RESTART_BINDING_CRC_ROUNDTRIP_PASS'
   else
    if(tx%status==TX_STATUS_ACCEPTED.or.tx%commits/=0)error stop 'invalid acceptance'
    if(any(accepted%theta/=origin%theta).or.any(accepted%matrix_temperature/=origin%matrix_temperature).or. &
     any(accepted%macro_temperature/=origin%macro_temperature).or..not.accepted%macro%same_values(origin%macro).or. &
     accepted%time/=0d0.or.accepted%revision/=0)error stop 'rollback'
   end if
  end select
 end do
 ! Exercise real adaptive full/half trials and rollback after a provisional leaf.
 manufactured_nonlinear=.true.;origin%source_proxy_policy=.true.
 model%allow_source_proxies=.true.;model%inject_feedback_failure=.false.
 do k=0,1
  fail_after_leaf=k==1
  call origin%clone(accepted)
  call execute_native_coupled_transaction(model,accepted,0d0,1d-5,tx)
  if(tx%temporal_rejections<1.or.model%provisional_leaves<1)error stop 'adaptive path not exercised'
  select type(accepted)
  type is(native_coupled_state_t)
   if(k==0)then
    if(tx%status/=TX_STATUS_ACCEPTED.or.tx%commits/=1.or.accepted%revision/=1.or.accepted%time/=1d-5)error stop 'complete refined window'
   else
    if(tx%status==TX_STATUS_ACCEPTED.or.tx%commits/=0.or.accepted%revision/=0.or.accepted%time/=0d0.or. &
     any(accepted%head/=origin%head).or.any(accepted%theta/=origin%theta).or. &
     any(accepted%matrix_temperature/=origin%matrix_temperature).or.any(accepted%macro_temperature/=origin%macro_temperature).or. &
     .not.accepted%macro%same_values(origin%macro))error stop 'partial window leaked'
   end if
  end select
 end do
 print '(a)','ADAPTIVE_COMPLETE_WINDOW_AND_LATE_FAILURE_ROLLBACK_PASS'
 restored=origin;restored%macro%absorption_time=4d-12
 if(model%temporal_error(origin,restored)<=1d-6)error stop 'finite clock error not rejected'
 restored=origin;restored%macro%theta_sorption_ref=1d-5
 if(model%temporal_error(origin,restored)<=1d-6)error stop 'physical sorption error not rejected'
 restored=origin;restored%macro%sorptivity=1d-5
 if(model%temporal_error(origin,restored)<=1d-6)error stop 'sorptivity error not rejected'
 print '(a)','NATIVE_FEEDBACK_TRANSACTION_COMPONENT_PASS'
contains
 subroutine water(state,t0,t1,faces,exchange,external_out,mass_in,mass_out,has_bottom_in,valid)
  type(native_coupled_state_t),intent(inout)::state
  real(real64),intent(in)::t0,t1
  real(real64),allocatable,intent(out)::faces(:,:),exchange(:,:),external_out(:,:)
  real(real64),intent(out)::mass_in,mass_out
  logical,intent(out)::has_bottom_in,valid
  valid=.false.
  if(fail_after_leaf.and.model%provisional_leaves>0)return
  if(manufactured_nonlinear)state%head=state%head+1d6*(t1-t0)**2
  allocate(faces(1,3),exchange(1,2),external_out(1,2));faces=0d0;exchange=0d0;external_out=0d0
  faces(1,1)=.1d0;exchange(1,1)=.2d0
  state%macro%water_domain_cp(1,1)=state%macro%water_domain_cp(1,1)-.1d0*(t1-t0)
  state%theta(1)=state%theta(1)+.2d0*(t1-t0)
  mass_in=.1d0*(t1-t0);mass_out=0d0;has_bottom_in=.false.;valid=.true.
 end subroutine
end program
