program native_feedback_component
 use iso_fortran_env,only:real64
 use mod_restricted_soil_temperature
 use mod_native_coupled_transaction
 use mod_native_macro_heat_feedback
 use mod_process_hydraulic_view,only:process_hydraulic_view_t
 use mod_transaction_reference
 implicit none
 type(native_coupled_model_t)::model
 type(native_coupled_state_t)::origin
 class(transaction_state_t),allocatable::accepted
 type(transaction_result_t)::tx
 type(native_heat_feedback_result_t)::heat
 type(soil_temperature_state_t)::initial
 type(process_hydraulic_view_t)::h0,h1
 real(real64)::w0(1,2),w1(1,2),face(1,3),qx(1,2),outflow(1,2),temperature(1,2)
 integer::status,k
 logical::ok
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
 origin%head=[-10d0,-10d0];origin%theta=[.2d0,.2d0];origin%area_dz=[1d0,1d0]
 origin%matrix_temperature=[10d0,10d0];allocate(origin%macro_temperature(1,2));origin%macro_temperature=20d0
 call origin%macro%initialize(1,2,ok)
 origin%macro%water_domain_cp=.1d0;origin%macro%volume_domain_cp=.2d0
 do k=0,3
  call origin%clone(accepted)
  model%water_trial=>water
  model%allow_source_proxies=k/=0;model%inject_feedback_failure=k==2
  model%rain_temperature=15d0;model%water_calls=0;model%feedback_calls=0;model%donor_refusals=0
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
   else
    if(tx%status==TX_STATUS_ACCEPTED.or.tx%commits/=0)error stop 'invalid acceptance'
    if(any(accepted%theta/=origin%theta).or.any(accepted%matrix_temperature/=origin%matrix_temperature).or. &
     any(accepted%macro_temperature/=origin%macro_temperature).or..not.accepted%macro%same_values(origin%macro).or. &
     accepted%time/=0d0.or.accepted%revision/=0)error stop 'rollback'
   end if
  end select
 end do
 print '(a)','NATIVE_FEEDBACK_TRANSACTION_COMPONENT_PASS'
contains
 subroutine water(state,t0,t1,faces,exchange,external_out,mass_in,mass_out,has_bottom_in,valid)
  type(native_coupled_state_t),intent(inout)::state
  real(real64),intent(in)::t0,t1
  real(real64),allocatable,intent(out)::faces(:,:),exchange(:,:),external_out(:,:)
  real(real64),intent(out)::mass_in,mass_out
  logical,intent(out)::has_bottom_in,valid
  allocate(faces(1,3),exchange(1,2),external_out(1,2));faces=0d0;exchange=0d0;external_out=0d0
  faces(1,1)=.1d0;exchange(1,1)=.2d0
  state%macro%water_domain_cp(1,1)=state%macro%water_domain_cp(1,1)-.1d0*(t1-t0)
  state%theta(1)=state%theta(1)+.2d0*(t1-t0)
  mass_in=.1d0*(t1-t0);mass_out=0d0;has_bottom_in=.false.;valid=.true.
 end subroutine
end program
