module mod_research_joint_fct
 use iso_fortran_env,only:real64
 use mod_transaction_reference,only:transaction_state_t
 use mod_canonical_contracts,only:canonical_numerical_config_t
 use mod_kernel_transactions
 use mod_fmr_runtime_core
 use mod_fmr_serialized_reference_backend
 use mod_solute_water_face_flux_reconstruction
 use mod_research_trace_replay
 use mod_solute_mobile_salt_state
 use mod_solute_compartment_state
 use mod_b111_reactive_solute_substep
 implicit none
 private
 integer,parameter,public::RESEARCH_JOINT_OK=0,RESEARCH_JOINT_INVALID=1, &
  RESEARCH_JOINT_WATER=2,RESEARCH_JOINT_CHEMICAL=3,RESEARCH_JOINT_COMMIT=4
 type,public::research_chemical_t
  type(mobile_salt_state_t)::mobile
  type(solute_compartment_state_t)::companion
  real(real64)::clock=0d0
  real(real64),allocatable::water(:)
 end type
 type,public::research_joint_result_t
  integer::status=RESEARCH_JOINT_INVALID,chemical_status=-1,completed=0,substeps=0
  real(real64)::ledger(4)=0d0
  type(kernel_result_t)::water
  type(kernel_diagnostics_t)::diagnostics
 end type
 public::run_research_joint_fct
contains
 subroutine run_research_joint_fct(backend,column,template,parameters,water,forcing,config,chemical,model,t1,r,models)
  type(fmr_serialized_reference_backend_t),intent(inout)::backend
  type(fmr_logical_column_t),intent(in)::column
  type(fmr_template_t),intent(in)::template
  type(fmr_b110_physical_parameters_t),target,intent(in)::parameters
  type(kernel_committed_state_t),intent(inout)::water
  type(fmr_b110_physical_forcing_t),intent(in)::forcing
  type(canonical_numerical_config_t),intent(in)::config
  type(research_chemical_t),intent(inout)::chemical
  type(b111_reactive_solute_substep_forcing_t),intent(in)::model
  real(real64),intent(in)::t1
  type(research_joint_result_t),intent(out)::r
  type(b111_reactive_solute_substep_forcing_t),optional,intent(in)::models(:)
  type(kernel_checkpoint_t)::cp
  type(kernel_candidate_state_t)::candidate
  type(fmr_serialized_physical_observation_t)::obs
  type(research_chemical_t)::next
  type(b111_reactive_solute_substep_forcing_t),allocatable::f(:)
  class(transaction_state_t),allocatable::physical
  real(real64),allocatable::t0s(:),t1s(:),faces(:)
  real(real64)::clock,closure,account(4)
  logical::ok,committed
  integer::j,code,n
  r=research_joint_result_t()
  if(.not.water%ready().or..not.allocated(chemical%water))return
  if(template%optional_state_layout_id/=FMR_OPTIONAL_STATE_LAYOUT_BASE.or. &
   template%solute_state_layout_id/=FMR_SOLUTE_STATE_LAYOUT_NONE)return
  call water%current_time(clock,ok)
  if(.not.ok)return
  if(clock/=chemical%clock.or..not.(t1>clock))return
  call water%snapshot(physical,ok);if(.not.ok)return
  select type(p=>physical)
  type is(fmr_b110_temporal_indicator_state_t)
   if(.not.allocated(p%water_content))return
   if(size(p%water_content)/=size(chemical%water))return
   if(any(p%water_content/=chemical%water))return
   if(allocated(p%salt).or.allocated(p%macropore).or.allocated(p%snow).or. &
    allocated(p%soil_temperature).or.allocated(p%rutter).or.allocated(p%hysteresis))return
  class default
   return
  end select
  call water%capture_checkpoint(cp,ok);if(.not.ok)return
  call backend%run_trial(column,template,parameters,water,forcing,config,clock,t1,cp, &
   r%water,candidate,r%diagnostics,trace_accepted_water_flux_substeps=.true.)
  r%status=RESEARCH_JOINT_WATER
  if(.not.r%water%completed.or..not.candidate%ready())then
   call backend%discard_trial_candidate(candidate,r%diagnostics);return
  end if
  obs=backend%observation()
  if(.not.obs%accepted_water_flux_trace_available.or..not.allocated(obs%accepted_water_flux_substeps))then
   call backend%discard_trial_candidate(candidate,r%diagnostics);return
  end if
  n=size(obs%accepted_water_flux_substeps);r%substeps=n;r%status=RESEARCH_JOINT_CHEMICAL
  if(present(models))then
   if(size(models)/=n)then
    call backend%discard_trial_candidate(candidate,r%diagnostics);return
   end if
  end if
  allocate(f(n),t0s(n),t1s(n))
  do j=1,n
   f(j)=model
   if(present(models))f(j)=models(j)
   associate(s=>obs%accepted_water_flux_substeps(j))
    t0s(j)=s%t0;t1s(j)=s%t1
    call reconstruct_interval_water_face_flux(parameters%dz,s%water_start,s%water_end,s%net_node_source, &
     -s%top_flux,-s%bottom_flux,s%t1-s%t0,1d-10/(s%t1-s%t0),faces,closure,code)
    if(code/=WATER_FACE_FLUX_OK.or.any(s%net_node_source/=0d0))then
     call backend%discard_trial_candidate(candidate,r%diagnostics);return
    end if
    f(j)%dt_day=s%t1-s%t0;f(j)%theta_previous=s%water_start;f(j)%theta=s%water_end
    f(j)%dz_cm=parameters%dz;f(j)%q_face_up_cm_day=-faces
    f(j)%root_sink_cm_day=s%root_sink;f(j)%qdra_cm_day=s%drainage_sink_by_level
    f(j)%rain_rate_cm_day=-s%top_flux
   end associate
  end do
  call consume_research_trace(chemical%mobile,chemical%companion,chemical%clock,chemical%water,t0s,t1s,f,.true., &
   next%mobile,next%companion,next%clock,next%water,r%chemical_status,r%completed,account)
  if(r%chemical_status/=0)then
   call backend%discard_trial_candidate(candidate,r%diagnostics);return
  end if
  r%status=RESEARCH_JOINT_COMMIT
  call backend%commit_trial_candidate(water,candidate,r%diagnostics,committed,code)
  if(.not.committed)return
  chemical=next;r%ledger=account;r%status=RESEARCH_JOINT_OK
 end subroutine
end module
