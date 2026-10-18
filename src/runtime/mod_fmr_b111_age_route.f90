! Optional age amount owner. It never owns or reconstructs a hydraulic trial.
module mod_fmr_b111_age_route
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_fmr_serialized_reference_backend,only:fmr_water_flux_substep_trace_t
 use mod_solute_water_face_flux_reconstruction,only:reconstruct_interval_water_face_flux,WATER_FACE_FLUX_OK
 use mod_solute_compartment_state,only:solute_compartment_state_t,initialize_solute_compartment_state,SOLCOMP_OK
 use mod_b111_age_tracer_substep
 use mod_b111_surface_age_owner, only: surface_age_owner_t
 use mod_b111_surface_age_budget, only: surface_age_receipt_t
 use mod_b111_surface_age_trace_bridge, only: surface_age_source_ages_t, &
      trial_surface_age_from_accepted_trace, AGE_BRIDGE_OK
 implicit none
 private
 integer,parameter,public::AGE_OK=0,AGE_INVALID=1,AGE_CARRIER=2,AGE_PROCESS=3
 type,public::age_state_t
  private
  type(solute_compartment_state_t)::amount
  type(b111_age_tracer_substep_forcing_t)::p
  real(real64),allocatable::water(:)
  real(real64)::time=0d0
  integer(int64)::id=0,revision=0
  logical::initialized=.false.
 contains
  procedure::ready=>age_ready
  procedure::snapshot=>age_snapshot
  procedure::configuration=>age_configuration
 end type
 type,public::age_restart_t
  private
  integer::schema=1
  type(age_state_t)::state
 end type
 type,public::age_receipt_t
  integer::status=AGE_INVALID,completed_substeps=0,process_status=0
  real(real64)::amount_before=0d0,amount_after=0d0,production=0d0,external_in=0d0,external_out=0d0
  real(real64)::residual=0d0,max_water_residual=0d0
 end type
 public::initialize_age,consume_accepted_age_trace,export_age_restart,restore_age_restart
 public::age_parameter_vector,reconstruct_age_trusted
contains
 function age_parameter_vector(p) result(v)
  type(b111_age_tracer_substep_forcing_t),intent(in)::p
  real(real64),allocatable::v(:)
  if(.not.allocated(p%dz_cm).or..not.allocated(p%face_left_weight).or. &
    .not.allocated(p%face_right_weight).or..not.allocated(p%face_distance_cm).or. &
    .not.allocated(p%theta_sat_left).or..not.allocated(p%dispersivity_cm))return
  v=[p%dz_cm,p%face_left_weight,p%face_right_weight,p%face_distance_cm,p%theta_sat_left, &
    p%dispersivity_cm,p%molecular_diffusion_cm2_day,p%drain_age_day]
 end function
 subroutine initialize_age(p,id,time,water,age_days,state,status)
  type(b111_age_tracer_substep_forcing_t),intent(in)::p
  integer(int64),intent(in)::id
  real(real64),intent(in)::time,water(:),age_days(:)
  type(age_state_t),intent(out)::state
  integer,intent(out)::status
  type(b111_age_tracer_substep_forcing_t)::f
  type(solute_compartment_state_t)::s,candidate
  type(b111_age_tracer_substep_receipt_t)::r
  real(real64),allocatable::v(:)
  integer::n,code
  state=age_state_t();status=AGE_INVALID;n=size(water)
  if(id<=0.or..not.ieee_is_finite(time))return
  if(abs(time)>1d8.or.n<1.or.n>4096.or.size(age_days)/=n)return
  if(.not.all(ieee_is_finite(water)).or..not.all(ieee_is_finite(age_days)))return
  if(any(water<1d-8).or.any(water>1d0).or.any(age_days<0d0).or.any(age_days>1d6))return
  v=age_parameter_vector(p)
  if(.not.allocated(v))return
  if(.not.all(ieee_is_finite(v)))return
  if(size(p%dz_cm)/=n)return
  if(any(abs([p%rain_rate_cm_day,p%rain_age_day,p%irrigation_rate_cm_day,p%irrigation_age_day, &
     p%pond_previous_cm,p%pond_end_cm,p%macropore_area_fraction])>0d0))return
  ! Validate the actual process contract on zero age, without committing production.
  call initialize_solute_compartment_state(spread(0d0,1,n),0d0,0d0,spread(0d0,1,n),s,code)
  if(code/=SOLCOMP_OK)return
  f=p;f%dt_day=1d0;f%theta=water;f%theta_previous=water
  f%q_face_up_cm_day=spread(0d0,1,n+1);f%root_sink_cm_day=spread(0d0,1,n)
  if(allocated(f%qdra_cm_day))deallocate(f%qdra_cm_day)
  allocate(f%qdra_cm_day(0,n))
  call advance_b111_age_tracer_substep(s,f,candidate,r)
  if(r%status/=B111_AGE_SUBSTEP_OK)return
  s%age_amount=water*p%dz_cm*age_days
  state%amount=s;state%p=p;state%water=water;state%time=time;state%id=id;state%initialized=.true.
  status=AGE_OK
 end subroutine
 logical function age_ready(self) result(ok)
  class(age_state_t),intent(in)::self
  ok=self%initialized
 end function
 subroutine age_snapshot(self,time,water,amount,revision)
  class(age_state_t),intent(in)::self
  real(real64),intent(out)::time
  real(real64),allocatable,intent(out)::water(:)
  type(solute_compartment_state_t),intent(out)::amount
  integer(int64),intent(out)::revision
  time=self%time;water=self%water;amount=self%amount;revision=self%revision
 end subroutine
 subroutine age_configuration(self,p,id)
  class(age_state_t),intent(in)::self
  type(b111_age_tracer_substep_forcing_t),intent(out)::p
  integer(int64),intent(out)::id
  p=self%p;id=self%id
 end subroutine
 subroutine consume_accepted_age_trace(committed,steps,receipt,surface_owner,source_ages)
  type(age_state_t),intent(inout)::committed
  type(fmr_water_flux_substep_trace_t),intent(in)::steps(:)
  type(age_receipt_t),intent(out)::receipt
  type(surface_age_owner_t),intent(inout),optional::surface_owner
  type(surface_age_source_ages_t),intent(in),optional::source_ages
  type(surface_age_owner_t)::surface_trial,surface_next
  type(surface_age_receipt_t)::surface_receipt
  type(age_state_t)::trial
  type(b111_age_tracer_substep_forcing_t)::f
  type(b111_age_tracer_substep_receipt_t)::r
  type(solute_compartment_state_t)::amount
  real(real64),allocatable::faces(:)
  real(real64)::dt,closure,scale
  integer::n,k,code
  receipt=age_receipt_t()
  if(.not.committed%ready().or.size(steps)<1)return
  if(present(surface_owner).neqv.present(source_ages))return
  if(present(surface_owner))surface_trial=surface_owner
  trial=committed;n=size(trial%water)
  receipt%amount_before=sum(trial%amount%age_amount)
  do k=1,size(steps)
   receipt%status=AGE_CARRIER
   associate(t=>steps(k))
    if(.not.all(ieee_is_finite([t%t0,t%t1,t%top_flux,t%bottom_flux])))return
    if(abs(t%t0-trial%time)>0d0.or.t%t1<=t%t0.or.abs(t%t1)>1d8)return
    if(.not.allocated(t%water_start).or..not.allocated(t%water_end).or. &
       .not.allocated(t%root_sink).or..not.allocated(t%net_node_source).or. &
       .not.allocated(t%drainage_sink_by_level))return
    if(size(t%water_start)/=n.or.size(t%water_end)/=n.or.size(t%root_sink)/=n.or. &
       size(t%net_node_source)/=n.or.size(t%drainage_sink_by_level,2)/=n)return
    if(.not.all(ieee_is_finite(t%water_start)).or..not.all(ieee_is_finite(t%water_end)).or. &
       .not.all(ieee_is_finite(t%root_sink)).or..not.all(ieee_is_finite(t%net_node_source)).or. &
       .not.all(ieee_is_finite(t%drainage_sink_by_level)))return
    if(any(t%water_start<1d-8).or.any(t%water_start>1d0).or.any(t%water_end<1d-8).or. &
       any(t%water_end>1d0).or.any(t%root_sink<0d0).or.any(t%root_sink>1d6))return
    ! Bound finite inputs before summing source terms or dividing by dt.
    ! This is a carrier domain check, not a relaxed balance or retry policy.
    if(size(t%drainage_sink_by_level,1)>4096)return
    if(any(abs(t%drainage_sink_by_level)>1d6).or.any(abs(t%net_node_source)>1d10))return
    if(abs(t%bottom_flux)>1d6)return
    dt=t%t1-t%t0
    if(dt<1d-100.or.dt>1d3)return
    scale=max(1d0,maxval(abs(t%net_node_source)))
    if(any(abs(t%net_node_source+sum(t%drainage_sink_by_level,dim=1)+t%root_sink)> &
       1024d0*epsilon(1d0)*scale))return
    if(any(abs(t%water_start-trial%water)>1024d0*epsilon(1d0)))return
    if(allocated(t%macropore_matrix_exchange))then
     if(.not.all(ieee_is_finite(t%macropore_matrix_exchange)))return
     if(any(abs(t%macropore_matrix_exchange)>0d0))return
    end if
    if(allocated(t%macropore_matrix_exchange_domain))then
     if(size(t%macropore_matrix_exchange_domain,1)>0)return
    end if
    if(allocated(t%subsurface_source))then
     if(.not.all(ieee_is_finite(t%subsurface_source)))return
     if(any(abs(t%subsurface_source)>0d0))return
    end if
    if(.not.present(surface_owner))then
      if(abs(t%top_flux)>0d0)return
    end if
    call reconstruct_interval_water_face_flux(trial%p%dz_cm,t%water_start,t%water_end, &
       t%net_node_source,-t%top_flux,-t%bottom_flux,dt,1d-10/dt,faces,closure,code)
    receipt%max_water_residual=max(receipt%max_water_residual,abs(closure)*dt)
    if(code/=WATER_FACE_FLUX_OK)return
    f=trial%p;f%dt_day=dt;f%theta_previous=t%water_start;f%theta=t%water_end
    f%q_face_up_cm_day=-faces;f%root_sink_cm_day=t%root_sink;f%qdra_cm_day=t%drainage_sink_by_level
    if(present(surface_owner))then
      call trial_surface_age_from_accepted_trace(surface_trial,t,source_ages,surface_next,surface_receipt,code)
      if(code/=AGE_BRIDGE_OK)return
      f%accepted_surface_age_available=.true.
      f%accepted_surface_age_input_cm_day=surface_receipt%infiltration_age_export_cm_day
    end if
    call advance_b111_age_tracer_substep(trial%amount,f,amount,r)
    receipt%status=AGE_PROCESS;receipt%process_status=r%status
    if(r%status/=B111_AGE_SUBSTEP_OK)return
    if(present(surface_owner))then
      scale=max(1d0,abs(r%pond_to_soil_cm_day),abs(surface_receipt%infiltration_age_export_cm_day))
      if(abs(r%pond_to_soil_cm_day-surface_receipt%infiltration_age_export_cm_day)> &
         8192d0*epsilon(1d0)*scale)return
      surface_trial=surface_next
    end if
    trial%amount=amount;trial%water=t%water_end;trial%time=t%t1
    receipt%production=receipt%production+r%production_amount_cm_day
    receipt%external_in=receipt%external_in+r%drain_input_cm_day+r%bottom_input_cm_day
    if(present(surface_owner))receipt%external_in=receipt%external_in+r%pond_to_soil_cm_day
    receipt%external_out=receipt%external_out+r%root_export_cm_day+r%drain_export_cm_day+r%bottom_export_cm_day
    receipt%completed_substeps=k
   end associate
  end do
  receipt%amount_after=sum(trial%amount%age_amount)
  receipt%residual=receipt%amount_after-receipt%amount_before-receipt%production-receipt%external_in+receipt%external_out
  scale=max(1d0,receipt%amount_before,receipt%amount_after,receipt%production,receipt%external_in,receipt%external_out)
  if(abs(receipt%residual)>8192d0*epsilon(1d0)*scale)return
  if(trial%revision>=100000000_int64)return
  trial%revision=trial%revision+1;committed=trial
  if(present(surface_owner))surface_owner=surface_trial
  receipt%status=AGE_OK
 end subroutine
 subroutine export_age_restart(state,payload,status)
  type(age_state_t),intent(in)::state
  type(age_restart_t),intent(out)::payload
  integer,intent(out)::status
  payload=age_restart_t();status=AGE_INVALID
  if(.not.state%ready())return
  payload%state=state;status=AGE_OK
 end subroutine
 subroutine restore_age_restart(payload,id,state,status)
  type(age_restart_t),intent(in)::payload
  integer(int64),intent(in)::id
  type(age_state_t),intent(out)::state
  integer,intent(out)::status
  state=age_state_t();status=AGE_INVALID
  if(payload%schema/=1.or.id/=payload%state%id.or..not.payload%state%ready())return
  state=payload%state;status=AGE_OK
 end subroutine
 subroutine reconstruct_age_trusted(p,id,revision,time,water,amount,state,status)
  type(b111_age_tracer_substep_forcing_t),intent(in)::p
  integer(int64),intent(in)::id,revision
  real(real64),intent(in)::time,water(:),amount(:)
  type(age_state_t),intent(out)::state
  integer,intent(out)::status
  type(age_state_t)::trial
  state=age_state_t();status=AGE_INVALID
  if(.not.allocated(p%dz_cm))return
  if(size(p%dz_cm)/=size(water).or.size(amount)/=size(water))return
  if(.not.all(ieee_is_finite(amount)).or..not.all(ieee_is_finite(water)))return
  if(any(water<1d-8).or.any(p%dz_cm<1d-4))return
  if(any(amount<0d0).or.any(amount>1d12).or.revision<0.or.revision>100000000_int64)return
  ! Initialization concentration bounds do not constrain a subsequently aged
  ! trajectory. Restore bounded accepted amounts directly after validating all
  ! configuration and water fields through the same constructor.
  call initialize_age(p,id,time,water,spread(0d0,1,size(water)),trial,status)
  if(status/=AGE_OK)return
  trial%amount%age_amount=amount;trial%revision=revision;state=trial
 end subroutine
end module
