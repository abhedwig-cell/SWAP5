module mod_fmr_soil_n_accepted_temperature
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_transaction_reference,only:transaction_state_t
 use mod_kernel_transactions,only:kernel_committed_state_t,kernel_parameter_identity_t
 use mod_fmr_serialized_reference_backend,only:fmr_b110_physical_state_t,fmr_b110_temporal_indicator_state_t
 use mod_soil_temperature_contract,only:soil_temperature_field_view_t,build_soil_temperature_field_view,SOIL_TEMP_OK
 use mod_soil_n_profile_temperature
 use mod_soil_n_day_environment
 implicit none
 private
 public::sample_accepted_soil_n_environment
contains
 subroutine sample_accepted_soil_n_environment(water,lineage,revision,t0,t1,depth_m,environment,selected_depth,status)
  type(kernel_committed_state_t),intent(in)::water
  integer(int64),intent(in)::lineage,revision
  real(real64),intent(in)::t0,t1,depth_m
  type(soil_n_day_environment_t),intent(out)::environment
  real(real64),intent(out)::selected_depth
  integer,intent(out)::status
  type(kernel_parameter_identity_t)::identity
  class(transaction_state_t),allocatable::physical
  type(soil_temperature_field_view_t)::heat
  real(real64)::clock,temperature,depth
  integer::code
  logical::ok
  environment=soil_n_day_environment_t();selected_depth=0d0;status=1
  if(.not.ieee_is_finite(t0).or..not.ieee_is_finite(t1))return
  if(max(abs(t0),abs(t1))>1d9)return
  if(t1-t0/=1d0.or.lineage<=0.or.revision<0)return
  if(.not.water%ready().or..not.water%time_is_bound())return
  if(water%current_lineage_id()/=lineage.or.water%current_revision()/=revision)return
  call water%current_time(clock,ok);if(.not.ok)return
  if(transfer(clock,0_int64)/=transfer(t1,0_int64))return
  call water%certified_parameter_identity(identity,ok)
  if(.not.ok.or..not.identity%heat_enabled)return
  if(.not.allocated(identity%dz))return
  call water%snapshot(physical,ok);if(.not.ok)return
  select type(physical)
  type is(fmr_b110_physical_state_t);call extract(physical)
  type is(fmr_b110_temporal_indicator_state_t);call extract(physical)
  end select
 contains
  subroutine extract(p)
   class(fmr_b110_physical_state_t),intent(in)::p
   if(p%active_nodes/=identity%active_nodes.or.size(identity%dz)/=p%active_nodes)return
   if(.not.allocated(p%soil_temperature))return
   call build_soil_temperature_field_view(p%soil_temperature,heat,code)
   if(code/=SOIL_TEMP_OK.or.heat%active_nodes/=p%active_nodes)return
   call soil_n_profile_temperature(identity%dz,heat%temperature_c,depth_m,temperature,depth,code)
   if(code/=N_PROFILE_OK)return
   if(.not.soil_n_day_environment_valid(soil_n_day_environment_t(t0,t1,temperature),t0,t1))return
   environment=soil_n_day_environment_t(t0,t1,temperature);selected_depth=depth;status=0
  end subroutine
 end subroutine
end module
