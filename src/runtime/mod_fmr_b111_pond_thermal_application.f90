! Endpoint operator split: actual staged Reference heat, never configured heat.
module mod_fmr_b111_pond_thermal_application
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_transaction_reference,only:transaction_state_t
 use mod_canonical_contracts,only:canonical_numerical_config_t
 use mod_kernel_transactions
 use mod_fmr_runtime_core
 use mod_fmr_serialized_reference_backend
 use mod_soil_temperature_contract,only:soil_temperature_field_view_t,build_soil_temperature_field_view, &
  SOIL_TEMP_OK,SOIL_TEMP_SOLUTION_NUMERIC
 use mod_b111_reactive_solute_substep,only:b111_reactive_solute_substep_forcing_t
 use mod_fmr_b111_matrix_solute_route
 use mod_fmr_b111_matrix_joint_application,only:matrix_joint_result_t,JOINT_OK,JOINT_INVALID, &
  JOINT_WATER_REJECTED,JOINT_CHEMICAL_REJECTED,JOINT_COMMIT_REJECTED
 use mod_b111_persistent_pond,only:pond_step_t
 use mod_fmr_b111_pond_solute_route,only:consume_accepted_pond_trace
 use mod_solute_mobile_salt_state,only:mobile_salt_state_t
 use mod_solute_compartment_state,only:solute_compartment_state_t
 implicit none
 private
 public::run_pond_thermal_interval,pond_thermal_states_match,matrix_thermal_template
contains
 logical function matrix_thermal_template(t)result(ok)
  type(fmr_template_t),intent(in)::t
  ok=t%optional_state_layout_id==FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE.and. &
   t%solute_state_layout_id==FMR_SOLUTE_STATE_LAYOUT_NONE.and. &
   (t%numerical_continuation_layout_id==FMR_NUMERICAL_CONTINUATION_NONE.or. &
    t%numerical_continuation_layout_id==FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY)
 end function

 logical function pond_thermal_states_match(water,chemical)result(ok)
  type(kernel_committed_state_t),intent(in)::water
  type(matrix_solute_state_t),intent(in)::chemical
  type(kernel_parameter_identity_t)::identity
  class(transaction_state_t),allocatable::physical
  type(b111_reactive_solute_substep_forcing_t)::p
  type(mobile_salt_state_t)::m
  type(solute_compartment_state_t)::s
  type(soil_temperature_field_view_t)::heat
  real(real64),allocatable::theta(:)
  real(real64)::t,wt
  integer(int64)::id,revision
  integer::code
  logical::available
  ok=.false.
  if(.not.water%ready().or..not.chemical%ready())return
  if(.not.water%time_is_bound())return
  call water%current_time(wt,available);if(.not.available)return
  call chemical%snapshot(t,theta,m,s,revision)
  if(t/=wt)return
  call chemical%configuration(p,id)
  if(p%frexp<.5d0.or.p%frexp>2d0)return
  call water%certified_parameter_identity(identity,available)
  if(.not.available.or..not.identity%heat_enabled)return
  if(.not.allocated(identity%dz).or..not.allocated(p%dz_cm))return
  if(size(identity%dz)/=size(p%dz_cm))return
  if(any(identity%dz/=p%dz_cm))return
  if(s%aquifer_mass/=0d0.or.any(s%age_amount/=0d0))return
  call water%snapshot(physical,available);if(.not.available)return
  select type(q=>physical)
  type is(fmr_b110_physical_state_t);call inspect(q)
  type is(fmr_b110_temporal_indicator_state_t);call inspect(q)
  end select
 contains
  subroutine inspect(q)
   class(fmr_b110_physical_state_t),intent(in)::q
   if(allocated(q%salt).or.allocated(q%macropore).or.allocated(q%snow).or.allocated(q%rutter))return
   if(.not.allocated(q%soil_temperature))return
   if(.not.allocated(q%water_content).or..not.allocated(q%pressure_head))return
   if(q%active_nodes/=size(theta).or.size(q%water_content)/=size(theta))return
   if(size(q%pressure_head)/=size(theta))return
   if(.not.all(ieee_is_finite(q%pressure_head)).or..not.all(ieee_is_finite(q%water_content)))return
   if(.not.all(ieee_is_finite([q%ponding_depth,q%groundwater_level])))return
   if(q%ponding_depth<0d0)return
   if(any(abs(q%water_content-theta)>1024d0*epsilon(1d0)*max(1d0,maxval(abs(theta)))))return
   call build_soil_temperature_field_view(q%soil_temperature,heat,code)
   if(code/=SOIL_TEMP_OK.or.heat%active_nodes/=size(theta))return
   ok=all(ieee_is_finite(heat%temperature_c))
  end subroutine
 end function

 subroutine run_pond_thermal_interval(backend,column,template,parameters,water,forcing,config,chemical,supply,t0,t1,result)
  type(fmr_serialized_reference_backend_t),intent(inout)::backend
  type(fmr_logical_column_t),intent(in)::column
  type(fmr_template_t),intent(in)::template
  type(fmr_b110_physical_parameters_t),target,intent(in)::parameters
  type(kernel_committed_state_t),intent(inout)::water
  type(fmr_b110_physical_forcing_t),intent(in)::forcing
  type(canonical_numerical_config_t),intent(in)::config
  type(matrix_solute_state_t),intent(inout)::chemical
  type(pond_step_t),intent(in)::supply
  real(real64),intent(in)::t0,t1
  type(matrix_joint_result_t),intent(out)::result
  type(kernel_committed_state_t)::w
  type(kernel_checkpoint_t)::checkpoint
  type(kernel_candidate_state_t)::candidate
  type(fmr_serialized_physical_observation_t)::obs
  class(transaction_state_t),allocatable::physical
  type(soil_temperature_field_view_t)::heat
  type(matrix_solute_state_t)::n,temporary
  type(b111_reactive_solute_substep_forcing_t)::p,dynamic
  type(mobile_salt_state_t)::m
  type(solute_compartment_state_t)::s
  real(real64),allocatable::theta(:)
  real(real64)::clock
  integer(int64)::id,revision
  integer::code
  logical::ok,committed
  result=matrix_joint_result_t()
    if(.not.all(ieee_is_finite([supply%t0,supply%t1,supply%rain_rate,supply%rain_c, &
      supply%irrigation_rate,supply%irrigation_c,supply%dry_deposition_rate, &
      supply%runon_rate,supply%runon_c])))return
    if(supply%t0/=t0.or.supply%t1/=t1)return
    if(.not.ieee_is_finite(forcing%top_flux))return
    if(allocated(forcing%black_evaporation).or.allocated(forcing%boesten_evaporation).or. &
      allocated(forcing%snow).or.allocated(forcing%rfm_surface).or. &
      allocated(forcing%macropore_top_input))return
    ! The existing Reference Rutter dynamic top provider supplies accepted
    ! gross water provenance. Never infer chemical runon from net qtop.
    if(allocated(forcing%rutter))then
      if(.not.forcing%rutter%prepared)return
      if(.not.ieee_is_finite(forcing%rutter%runon_rate_cm_per_day))return
      if(forcing%rutter%runon_rate_cm_per_day<0d0.or. &
          forcing%rutter%runon_rate_cm_per_day/=supply%runon_rate)return
      if(forcing%rutter%result%net_rain_cm_per_day/=supply%rain_rate.or. &
          forcing%rutter%result%net_surface_irrigation_cm_per_day/=supply%irrigation_rate)return
    else
      if(supply%runon_rate/=0d0.and..not.allocated(forcing%pond_input))return
    end if
    if(allocated(forcing%pond_input))then
      if(template%numerical_continuation_layout_id/=FMR_NUMERICAL_CONTINUATION_NONE)return
      if(.not.all(ieee_is_finite([forcing%pond_input%rain_rate_cm_day, &
          forcing%pond_input%irrigation_rate_cm_day, &
          forcing%pond_input%runon_rate_cm_day])))return
      if(forcing%pond_input%rain_rate_cm_day/=supply%rain_rate.or. &
          forcing%pond_input%irrigation_rate_cm_day/=supply%irrigation_rate.or. &
          forcing%pond_input%runon_rate_cm_day/=supply%runon_rate)return
    end if
  if(.not.matrix_thermal_template(template))return
  if(.not.pond_thermal_states_match(water,chemical))return
  if(.not.all(ieee_is_finite([t0,t1])))return
  if(t1<=t0)return
  call water%current_time(clock,ok);if(.not.ok.or.clock/=t0)return
  call chemical%configuration(p,id)
  if(.not.parameters%soil_temperature_active.or.parameters%frost_active)return
  if(.not.allocated(parameters%soil_temperature))return
  if(parameters%soil_temperature%solution_mode/=SOIL_TEMP_SOLUTION_NUMERIC)return
  if(.not.allocated(parameters%dz))return
  if(size(parameters%dz)/=size(p%dz_cm))return
  if(any(parameters%dz/=p%dz_cm))return
  w=water
  call w%capture_checkpoint(checkpoint,ok);if(.not.ok)return
  call backend%run_trial(column,template,parameters,w,forcing,config,t0,t1,checkpoint, &
   result%water,candidate,result%diagnostics,trace_accepted_water_flux_substeps=.true.,trace_accepted_soil_n_heat=.true.)
  result%status=JOINT_WATER_REJECTED
  if(.not.result%water%completed.or..not.candidate%ready())return
  obs=backend%observation()
  if(.not.obs%accepted_water_flux_trace_available.or..not.allocated(obs%accepted_water_flux_substeps))then
   call backend%discard_trial_candidate(candidate,result%diagnostics);return
  end if
  result%status=JOINT_COMMIT_REJECTED
  call backend%commit_trial_candidate(w,candidate,result%diagnostics,committed,code)
  if(.not.committed)return
  result%status=JOINT_CHEMICAL_REJECTED
  call w%snapshot(physical,ok);if(.not.ok)return
  select type(q=>physical)
  class is(fmr_b110_physical_state_t)
   if(.not.allocated(q%soil_temperature))return
   call build_soil_temperature_field_view(q%soil_temperature,heat,code)
  class default
   return
  end select
  if(code/=SOIL_TEMP_OK)return
  dynamic=p;dynamic%temperature_c=heat%temperature_c
  call chemical%snapshot(clock,theta,m,s,revision)
  call reconstruct_matrix_solute_trusted(dynamic,id,revision,clock,theta,m%concentration_mg_cm3, &
   m%mass_mg_cm2,s%sorbed_matrix_mass,temporary,code,surface_mass=s%pond_mass)
  if(code/=MATRIX_OK)return
  call consume_accepted_pond_trace(temporary,obs%accepted_water_flux_substeps,supply,result%chemical)
  if(result%chemical%status/=MATRIX_OK)return
  call temporary%snapshot(clock,theta,m,s,revision)
  ! Restore the original immutable configuration, retaining exact accepted bits.
  call reconstruct_matrix_solute_trusted(p,id,revision,clock,theta,m%concentration_mg_cm3, &
   m%mass_mg_cm2,s%sorbed_matrix_mass,n,code,surface_mass=s%pond_mass)
  if(code/=MATRIX_OK)return
  if(.not.pond_thermal_states_match(w,n))return
  water=w;chemical=n;result%status=JOINT_OK
 end subroutine
end module
