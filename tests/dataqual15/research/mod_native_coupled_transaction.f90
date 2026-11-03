module mod_native_coupled_transaction
 use iso_fortran_env,only:real64,int64,int32,int8
 use iso_c_binding,only:c_int,c_int32_t,c_int8_t,c_char,c_size_t,c_null_char
 use ieee_arithmetic,only:ieee_is_finite
 use mod_transaction_reference
 use mod_macropore_continuation_state,only:macropore_continuation_state_t
 use mod_soil_temperature_contract
 use mod_process_hydraulic_view,only:process_hydraulic_view_t
 use mod_native_macro_heat_feedback
 implicit none
 private
 character(len=*),parameter,public::NATIVE_COUPLED_MODEL_ID='ANDELST_ACTION_NATIVE_FEEDBACK_V1'
 type,extends(transaction_state_t),public::native_coupled_state_t
  character(len=64)::model_id=NATIVE_COUPLED_MODEL_ID
  integer(int64)::revision=0
  real(real64)::time=0d0
  real(real64),allocatable::head(:),theta(:),area_dz(:),matrix_temperature(:),macro_temperature(:,:)
  type(macropore_continuation_state_t)::macro
 contains
  procedure::clone=>clone_native_coupled
 end type
 abstract interface
  subroutine native_water_callback(state,t0,t1,face,exchange,external_out,mass_in,mass_out,has_bottom_in,ok)
   import native_coupled_state_t,real64
   type(native_coupled_state_t),intent(inout)::state
   real(real64),intent(in)::t0,t1
   real(real64),allocatable,intent(out)::face(:,:),exchange(:,:),external_out(:,:)
   real(real64),intent(out)::mass_in,mass_out
   logical,intent(out)::has_bottom_in,ok
  end subroutine
 end interface
 type,extends(transaction_model_t),public::native_coupled_model_t
  procedure(native_water_callback),pointer,nopass::water_trial=>null()
  type(soil_temperature_parameters_t)::heat_parameters
  type(soil_temperature_forcing_t)::heat_forcing
  type(soil_temperature_numerical_config_t)::heat_numerical
  logical::allow_source_proxies=.false.,rain_donor_measured=.false.,groundwater_donor_measured=.false.
  logical::inject_feedback_failure=.false.
  real(real64)::rain_temperature=0d0,groundwater_temperature=0d0
  real(real64)::max_joint_residual=0d0,max_feedback=0d0,max_temperature_change=0d0,last_indicator=huge(1d0)
  integer::water_calls=0,feedback_calls=0,donor_refusals=0
 contains
  procedure::advance=>advance_native_coupled
  procedure::storage=>storage_native_coupled
  procedure::storage_accounting_status=>storage_status_native_coupled
  procedure::temporal_error=>temporal_native_coupled
 end type
 public::execute_native_coupled_transaction,write_native_coupled_restart,read_native_coupled_restart
 interface
  integer(c_int) function native_publish(pending,target)bind(C,name='swap5_restart_publish')
   import c_int,c_char
   character(c_char),intent(in)::pending(*),target(*)
  end function
  integer(c_int32_t) function native_crc(bytes,count)bind(C,name='swap5_restart_crc32')
   import c_int32_t,c_int8_t,c_size_t
   integer(c_int8_t),intent(in)::bytes(*)
   integer(c_size_t),value::count
  end function
 end interface
contains
 subroutine clone_native_coupled(self,copy)
  class(native_coupled_state_t),intent(in)::self
  class(transaction_state_t),allocatable,intent(out)::copy
  allocate(native_coupled_state_t::copy)
  select type(copy)
  type is(native_coupled_state_t)
   copy%model_id=self%model_id;copy%revision=self%revision;copy%time=self%time
   copy%head=self%head;copy%theta=self%theta;copy%area_dz=self%area_dz
   copy%matrix_temperature=self%matrix_temperature;copy%macro_temperature=self%macro_temperature;copy%macro=self%macro
  end select
 end subroutine
 subroutine advance_native_coupled(self,state,t0,t1,outcome)
  class(native_coupled_model_t),intent(inout)::self
  class(transaction_state_t),intent(inout)::state
  real(real64),intent(in)::t0,t1
  type(trial_outcome_t),intent(out)::outcome
  type(process_hydraulic_view_t)::h0,h1
  type(soil_temperature_state_t)::initial_heat
  type(native_heat_feedback_result_t)::heat
  real(real64),allocatable::w0(:,:),face(:,:),exchange(:,:),external_out(:,:),matrix0(:),macro0(:,:),top(:),bottom(:)
  logical,allocatable::initial_available(:,:),top_available(:),bottom_available(:)
  real(real64)::mass_in,mass_out
  logical::ok,has_bottom_in
  integer::n,nd,status
  outcome=trial_outcome_t()
  if(.not.associated(self%water_trial))return
  select type(state)
  type is(native_coupled_state_t)
   if(state%model_id/=NATIVE_COUPLED_MODEL_ID.or.state%time/=t0)return
   n=size(state%head);nd=state%macro%num_domains
   h0%active_nodes=n;h0%pressure_head=state%head;h0%water_content=state%theta
   matrix0=state%matrix_temperature;macro0=state%macro_temperature;w0=state%macro%water_domain_cp
   self%water_calls=self%water_calls+1
   call self%water_trial(state,t0,t1,face,exchange,external_out,mass_in,mass_out,has_bottom_in,ok)
   if(.not.ok)return
   if(any(face(:,1)>0d0).and..not.(self%rain_donor_measured.or.self%allow_source_proxies))then
    self%donor_refusals=self%donor_refusals+1;return
   end if
   if(has_bottom_in.and..not.(self%groundwater_donor_measured.or.self%allow_source_proxies))then
    self%donor_refusals=self%donor_refusals+1;return
   end if
   h1%active_nodes=n;h1%pressure_head=state%head;h1%water_content=state%theta
   call initialize_soil_temperature_state(matrix0,initial_heat,status)
   if(status/=SOIL_TEMP_OK)return
   allocate(top(nd),bottom(nd),initial_available(nd,n),top_available(nd),bottom_available(nd))
   top=self%rain_temperature;bottom=self%groundwater_temperature
   initial_available=.true.;top_available=self%rain_donor_measured.or.self%allow_source_proxies
   bottom_available=self%groundwater_donor_measured.or.self%allow_source_proxies
   self%feedback_calls=self%feedback_calls+1
   if(self%inject_feedback_failure)return
   call trial_native_macro_heat_feedback(self%heat_parameters,self%heat_numerical,self%heat_forcing,h0,h1,initial_heat, &
        w0,state%macro%water_domain_cp,face,exchange,external_out,macro0,initial_available,top,top,top_available, &
        bottom,bottom,bottom_available,t0,t1,16,heat)
   if(.not.heat%produced)return
   self%max_joint_residual=max(self%max_joint_residual,abs(heat%joint_residual_j_cm2))
   self%max_feedback=max(self%max_feedback,maxval(abs(sum(heat%macro_energy_to_matrix_j_cm2,dim=1))))
   self%max_temperature_change=max(self%max_temperature_change,maxval(abs(heat%matrix_temperature_c-matrix0)))
   state%matrix_temperature=heat%matrix_temperature_c;state%macro_temperature=heat%macro_temperature_c;state%time=t1
   outcome%mass_in=mass_in;outcome%mass_out=mass_out;outcome%mass_accounting_complete=.true.
   outcome%missing_mass_contribution_mask=TX_MASS_MISSING_NONE;outcome%solver_ok=.true.
  end select
 end subroutine
 function storage_native_coupled(self,state)result(value)
  class(native_coupled_model_t),intent(in)::self
  class(transaction_state_t),intent(in)::state
  real(real64)::value
  value=huge(1d0)
  select type(state)
  type is(native_coupled_state_t)
   value=sum(state%theta*state%area_dz)+sum(state%macro%water_domain_cp)
  end select
 end function
 subroutine storage_status_native_coupled(self,state,complete,missing_mask)
  class(native_coupled_model_t),intent(in)::self
  class(transaction_state_t),intent(in)::state
  logical,intent(out)::complete
  integer(int64),intent(out)::missing_mask
  complete=.false.;missing_mask=TX_MASS_MISSING_UNSPECIFIED
  select type(state)
  type is(native_coupled_state_t)
   complete=allocated(state%theta).and.allocated(state%area_dz).and.state%macro%ready()
   if(complete)complete=all(ieee_is_finite(state%theta)).and.all(ieee_is_finite(state%macro%water_domain_cp))
  end select
  if(complete)missing_mask=TX_MASS_MISSING_NONE
 end subroutine
 function temporal_native_coupled(self,full_state,half_state)result(value)
  class(native_coupled_model_t),intent(in)::self
  class(transaction_state_t),intent(in)::full_state,half_state
  real(real64)::value,errors(9),raw_relative_clock
  value=huge(1d0)
  select type(full_state)
  type is(native_coupled_state_t)
   select type(half_state)
   type is(native_coupled_state_t)
    if(any(full_state%macro%absorption_time<0d0).or.any(half_state%macro%absorption_time<0d0))return
    ! Fixed physical scales: cm, water fraction, cm water, C, cm*C,
    ! sqrt(day), water fraction, cm/sqrt(day), cm pore volume.
    ! Near-zero action clocks need an absolute tolerance, like other states.
    errors(1)=maxval(abs(full_state%head-half_state%head)/max(1d0,abs(half_state%head)))
    errors(2)=maxval(abs(full_state%theta-half_state%theta))
    errors(3)=maxval(abs(full_state%macro%water_domain_cp-half_state%macro%water_domain_cp))
    errors(4)=maxval(abs(full_state%matrix_temperature-half_state%matrix_temperature)/max(1d0,abs(half_state%matrix_temperature)))
    errors(5)=maxval(abs(full_state%macro%water_domain_cp*full_state%macro_temperature-half_state%macro%water_domain_cp*half_state%macro_temperature)/ &
       max(1d0,abs(half_state%macro%water_domain_cp*half_state%macro_temperature)))
    errors(6)=maxval(abs(sqrt(full_state%macro%absorption_time)-sqrt(half_state%macro%absorption_time))/ &
      max(1d0,sqrt(half_state%macro%absorption_time)))
    errors(7)=maxval(abs(full_state%macro%theta_sorption_ref-half_state%macro%theta_sorption_ref))
    errors(8)=maxval(abs(full_state%macro%sorptivity-half_state%macro%sorptivity)/max(1d0,abs(half_state%macro%sorptivity)))
    errors(9)=max(maxval(abs(full_state%macro%volume_domain_cp-half_state%macro%volume_domain_cp)), &
      maxval(abs(full_state%macro%dynamic_volume_cp-half_state%macro%dynamic_volume_cp)))
    raw_relative_clock=maxval(abs(sqrt(full_state%macro%absorption_time)-sqrt(half_state%macro%absorption_time))/ &
      max(1d-12,sqrt(half_state%macro%absorption_time)))
    write(*,'(a,10(a,es25.17e3))')'NATIVE_TEMPORAL_COMPONENTS',',',errors(1),',',errors(2),',',errors(3), &
      ',',errors(4),',',errors(5),',',errors(6),',',errors(7),',',errors(8),',',errors(9),',',raw_relative_clock
    if(all(ieee_is_finite(errors)))value=maxval(errors)
   end select
  end select
 end function
 subroutine execute_native_coupled_transaction(model,committed,t0,t1,result)
  type(native_coupled_model_t),intent(inout)::model
  class(transaction_state_t),allocatable,intent(inout)::committed
  real(real64),intent(in)::t0,t1
  type(transaction_result_t),intent(out)::result
  type(transaction_policy_t)::policy
  policy%max_retries=0;policy%mass_tolerance=1d-10;policy%temporal_tolerance=1d-6
  call execute_reference_interval(model,committed,t0,t1,policy,result)
  if(result%status==TX_STATUS_ACCEPTED)then
   select type(committed)
   type is(native_coupled_state_t)
    committed%revision=committed%revision+1
   end select
  end if
 end subroutine
 include 'native_coupled_restart.inc'
end module
