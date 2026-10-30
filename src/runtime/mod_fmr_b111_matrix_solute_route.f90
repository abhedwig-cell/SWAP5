! Bounded chemical companion to an already accepted matrix water trajectory.
! Water is read-only and retains its existing owner; no global layout is repurposed.
module mod_fmr_b111_matrix_solute_route
  use iso_fortran_env, only: real64,int64
  use ieee_arithmetic, only: ieee_is_finite
  use mod_fmr_water_flux_trace_contract, only: fmr_water_flux_substep_trace_t
  use mod_root_salinity_response,only:evaluate_mobile_root_salinity_sink,SALINITY_INVALID
  use mod_solute_water_face_flux_reconstruction, only: reconstruct_interval_water_face_flux,WATER_FACE_FLUX_OK
  use mod_solute_mobile_salt_state, only: mobile_salt_state_t,initialize_mobile_salt_state,SOLUTE_OK
  use mod_solute_compartment_state, only: solute_compartment_state_t,initialize_solute_compartment_state,SOLCOMP_OK
  use mod_b111_solute_sorption, only: b111_sorption_result_t,b111_sorption_storage_from_concentration,B111_SORP_OK
  use mod_b111_reactive_solute_substep, only: b111_reactive_solute_substep_forcing_t, &
       b111_reactive_solute_substep_receipt_t,advance_b111_reactive_solute_substep,B111_REACTIVE_OK,b111_reactive_forcing_valid
  implicit none
  private
  integer,parameter,public::MATRIX_OK=0,MATRIX_INVALID=1,MATRIX_CARRIER=2,MATRIX_PROCESS=3
  type,public::matrix_solute_state_t
    private
    type(mobile_salt_state_t)::mobile
    type(solute_compartment_state_t)::companion
    type(b111_reactive_solute_substep_forcing_t)::parameters
    real(real64),allocatable::water(:)
    real(real64)::time=0.0_real64
    integer(int64)::parameter_id=0_int64,revision=0_int64
    logical::initialized=.false.
  contains
    procedure::snapshot=>matrix_snapshot
    procedure::ready=>matrix_ready
    procedure::configuration=>matrix_configuration
    procedure::root_salinity_view=>matrix_root_salinity_view
    procedure::same_state=>matrix_same_state
  end type
  type,public::matrix_solute_restart_t
    private
    integer::schema_version=1
    type(matrix_solute_state_t)::state
  end type
  type,public::matrix_solute_receipt_t
    integer::status=MATRIX_INVALID,completed_substeps=0,process_status=0
    real(real64)::mass_before=0.0_real64,mass_after=0.0_real64,external_in=0.0_real64,external_out=0.0_real64
    real(real64)::decay_out=0.0_real64,residual=0.0_real64,max_water_residual=0.0_real64
  end type
  public::initialize_matrix_solute,consume_accepted_matrix_trace,export_matrix_solute_restart,restore_matrix_solute_restart
  public::matrix_parameter_vector,reconstruct_matrix_solute_trusted
contains
  logical function matrix_same_state(self,other)result(ok)
    class(matrix_solute_state_t),intent(in)::self
    type(matrix_solute_state_t),intent(in)::other
    real(real64),allocatable::a(:),b(:)
    ok=.false.
    if(.not.self%ready().or..not.other%ready())return
    if(self%time/=other%time.or.self%revision/=other%revision.or.self%parameter_id/=other%parameter_id)return
    if(size(self%water)/=size(other%water))return
    if(any(self%water/=other%water))return
    if(any(self%mobile%mass_mg_cm2/=other%mobile%mass_mg_cm2))return
    if(any(self%mobile%concentration_mg_cm3/=other%mobile%concentration_mg_cm3))return
    if(any(self%companion%sorbed_matrix_mass/=other%companion%sorbed_matrix_mass))return
    if(self%companion%pond_mass/=other%companion%pond_mass)return
    if(self%companion%aquifer_mass/=other%companion%aquifer_mass)return
    if(any(self%companion%age_amount/=other%companion%age_amount))return
    a=matrix_parameter_vector(self%parameters);b=matrix_parameter_vector(other%parameters)
    if(size(a)/=size(b))return
    ok=all(a==b)
  end function matrix_same_state

  ! A read-only view of this incumbent reactive chemical owner, matched to
  ! the exact water sibling and clock. This does not convert reactive sorbed
  ! mass into mobile salt or introduce a second chemical state owner.
  subroutine matrix_root_salinity_view(self,time,water,dz,potential,saltmax,saltslope, &
       concentration,alpha,sink,node_loss,total_loss,status)
    class(matrix_solute_state_t),intent(in)::self
    real(real64),intent(in)::time,water(:),dz(:),potential(:),saltmax,saltslope
    real(real64),allocatable,intent(out)::concentration(:),alpha(:),sink(:),node_loss(:)
    real(real64),intent(out)::total_loss
    integer,intent(out)::status
    real(real64)::scale
    integer::n
    status=SALINITY_INVALID;total_loss=0.0_real64
    if(.not.self%ready())return
    if(.not.ieee_is_finite(time))return
    if(time/=self%time)return
    n=size(self%water)
    if(size(water)/=n.or.size(dz)/=n.or.size(potential)/=n)return
    if(.not.all(ieee_is_finite(water)).or..not.all(ieee_is_finite(dz)))return
    if(.not.allocated(self%parameters%dz_cm))return
    if(size(self%parameters%dz_cm)/=n)return
    if(any(dz/=self%parameters%dz_cm))return
    scale=max(1.0_real64,maxval(abs(self%water)))
    if(any(abs(water-self%water)>1024.0_real64*epsilon(1.0_real64)*scale))return
    call evaluate_mobile_root_salinity_sink(self%mobile%mass_mg_cm2,water,dz,saltmax,saltslope, &
         potential,concentration,alpha,sink,node_loss,total_loss,status)
  end subroutine matrix_root_salinity_view

  subroutine initialize_matrix_solute(p,parameter_id,time,water,concentration,state,status)
    type(b111_reactive_solute_substep_forcing_t),intent(in)::p
    integer(int64),intent(in)::parameter_id
    real(real64),intent(in)::time,water(:),concentration(:)
    type(matrix_solute_state_t),intent(out)::state
    integer,intent(out)::status
    type(b111_sorption_result_t)::s
    type(matrix_solute_state_t)::trial
    type(b111_reactive_solute_substep_forcing_t)::validation
    real(real64),allocatable::sorbed(:)
    integer::i,n,code
    state=matrix_solute_state_t();status=MATRIX_INVALID
    if(parameter_id<=0.or..not.ieee_is_finite(time))return
    n=size(water)
    if(n<1.or.size(concentration)/=n)return
    if(.not.allocated(p%dz_cm).or..not.allocated(p%bulk_density).or..not.allocated(p%kf))return
    if(size(p%dz_cm)/=n.or.size(p%bulk_density)/=n.or.size(p%kf)/=n)return
    ! Bounded nonlinear successor; no surface chemical input, aquifer or age
    ! owner. The existing partition operator owns the equilibrium inversion.
    ! Fortran logical expressions need not short circuit under O0/FPE traps.
    if(.not.ieee_is_finite(p%frexp))return
    if(p%frexp<0.5_real64.or.p%frexp>2.0_real64)return
    if(.not.all(ieee_is_finite([p%rain_rate_cm_day,p%irrigation_rate_cm_day,p%macropore_area_fraction])))return
    ! Individual zero comparisons also avoid overflow in a sum of invalid rates.
    if(abs(p%rain_rate_cm_day)>0.0_real64.or.abs(p%irrigation_rate_cm_day)>0.0_real64.or. &
         abs(p%macropore_area_fraction)>0.0_real64)return
    validation=p;validation%dt_day=1.0_real64;validation%theta=water;validation%theta_previous=water
    validation%q_face_up_cm_day=spread(0.0_real64,1,n+1)
    validation%root_sink_cm_day=spread(0.0_real64,1,n)
    if(allocated(validation%qdra_cm_day))deallocate(validation%qdra_cm_day)
    allocate(validation%qdra_cm_day(0,n))
    if(.not.b111_reactive_forcing_valid(validation))return
    if(n>1)then
      if(any(abs(p%face_left_weight+p%face_right_weight-1.0_real64)> &
           1024.0_real64*epsilon(1.0_real64)))return
    end if
    call initialize_mobile_salt_state(p%dz_cm,water,concentration,trial%mobile,code)
    if(code/=SOLUTE_OK)return
    allocate(sorbed(n))
    do i=1,n
      call b111_sorption_storage_from_concentration(water(i),p%bulk_density(i),p%kf(i), &
           p%cref_mg_cm3,p%frexp,concentration(i),s)
      if(s%status/=B111_SORP_OK)return
      sorbed(i)=s%sorbed_density*p%dz_cm(i)
    end do
    call initialize_solute_compartment_state(sorbed,0.0_real64,0.0_real64,spread(0.0_real64,1,n),trial%companion,code)
    if(code/=SOLCOMP_OK)return
    trial%parameters=p;trial%water=water;trial%time=time;trial%parameter_id=parameter_id;trial%initialized=.true.
    state=trial;status=MATRIX_OK
  end subroutine

  subroutine matrix_configuration(self,p,parameter_id)
    class(matrix_solute_state_t),intent(in)::self
    type(b111_reactive_solute_substep_forcing_t),intent(out)::p
    integer(int64),intent(out)::parameter_id
    p=self%parameters;parameter_id=self%parameter_id
  end subroutine

  logical function matrix_ready(self) result(ok)
    class(matrix_solute_state_t),intent(in)::self
    ok=self%initialized.and.self%parameter_id>0.and.allocated(self%water)
    if(.not.ok)return
    ok=ieee_is_finite(self%time).and.all(ieee_is_finite(self%water)).and.all(self%water>0.0_real64)
    if(.not.ok)return
    ok=self%companion%valid().and.allocated(self%mobile%mass_mg_cm2)
  end function

  subroutine matrix_snapshot(self,time,water,mobile,companion,revision)
    class(matrix_solute_state_t),intent(in)::self
    real(real64),intent(out)::time
    real(real64),allocatable,intent(out)::water(:)
    type(mobile_salt_state_t),intent(out)::mobile
    type(solute_compartment_state_t),intent(out)::companion
    integer(int64),intent(out)::revision
    time=0.0_real64;revision=0_int64
    mobile=mobile_salt_state_t();companion=solute_compartment_state_t()
    if(.not.self%ready())return
    time=self%time;water=self%water;mobile=self%mobile;companion=self%companion;revision=self%revision
  end subroutine

  subroutine consume_accepted_matrix_trace(committed,steps,receipt,water_tolerance)
    type(matrix_solute_state_t),intent(inout)::committed
    type(fmr_water_flux_substep_trace_t),intent(in)::steps(:)
    type(matrix_solute_receipt_t),intent(out)::receipt
    real(real64),intent(in),optional::water_tolerance
    type(matrix_solute_state_t)::trial
    type(b111_reactive_solute_substep_forcing_t)::f
    type(b111_reactive_solute_substep_receipt_t)::r
    type(mobile_salt_state_t)::mobile
    type(solute_compartment_state_t)::companion
    real(real64),allocatable::faces(:)
    real(real64)::tol,closure,scale,dt
    integer::k,n,code
    receipt=matrix_solute_receipt_t()
    if(.not.committed%ready().or.size(steps)<1)return
    tol=1.0e-10_real64
    if(present(water_tolerance))tol=water_tolerance
    if(.not.ieee_is_finite(tol).or.tol<0.0_real64)return
    trial=committed;n=size(trial%water)
    receipt%mass_before=sum(trial%mobile%mass_mg_cm2)+trial%companion%solute_total()
    do k=1,size(steps)
      receipt%status=MATRIX_CARRIER
      associate(t=>steps(k))
        if(.not.all(ieee_is_finite([t%t0,t%t1,t%top_flux,t%bottom_flux])))return
        ! Exact consumed clock is persistent. No gaps, overlaps or replays.
        if(abs(t%t0-trial%time)>0.0_real64.or.t%t1<=t%t0)return
        if(.not.allocated(t%water_start).or..not.allocated(t%water_end).or. &
             .not.allocated(t%root_sink).or..not.allocated(t%net_node_source).or. &
             .not.allocated(t%drainage_sink_by_level))return
        if(size(t%water_start)/=n.or.size(t%water_end)/=n.or.size(t%root_sink)/=n.or. &
             size(t%net_node_source)/=n.or.size(t%drainage_sink_by_level,2)/=n)return
        if(.not.all(ieee_is_finite(t%water_start)).or..not.all(ieee_is_finite(t%root_sink)).or. &
             .not.all(ieee_is_finite(t%drainage_sink_by_level)).or..not.all(ieee_is_finite(t%net_node_source)))return
        if(any(t%root_sink<0.0_real64))return
        scale=max(1.0_real64,maxval(abs(t%net_node_source)))
        if(any(abs(t%net_node_source+sum(t%drainage_sink_by_level,dim=1)+t%root_sink)> &
             1024.0_real64*epsilon(1.0_real64)*scale))return
        scale=max(1.0_real64,maxval(abs(trial%water)))
        if(any(abs(t%water_start-trial%water)>1024.0_real64*epsilon(1.0_real64)*scale))return
        if(allocated(t%macropore_matrix_exchange))then
          if(.not.all(ieee_is_finite(t%macropore_matrix_exchange)))return
          if(any(abs(t%macropore_matrix_exchange)>0.0_real64))return
        end if
        if(allocated(t%macropore_matrix_exchange_domain))then
          if(size(t%macropore_matrix_exchange_domain,1)>0)return
        end if
        ! A matrix chemical trace cannot silently omit SSDI chemical input.
        if(allocated(t%subsurface_source))then
          if(.not.all(ieee_is_finite(t%subsurface_source)))return
          if(any(abs(t%subsurface_source)>0.0_real64))return
        end if
        if(abs(t%top_flux)>0.0_real64)return
        dt=t%t1-t%t0
        call reconstruct_interval_water_face_flux(trial%parameters%dz_cm,t%water_start,t%water_end, &
             t%net_node_source,-t%top_flux,-t%bottom_flux,dt,tol/dt,faces,closure,code)
        receipt%max_water_residual=max(receipt%max_water_residual,abs(closure)*dt)
        if(code/=WATER_FACE_FLUX_OK)return
        f=trial%parameters;f%dt_day=dt;f%theta_previous=t%water_start;f%theta=t%water_end
        f%q_face_up_cm_day=-faces;f%root_sink_cm_day=t%root_sink;f%qdra_cm_day=t%drainage_sink_by_level
        f%pond_end_cm=0.0_real64
        call advance_b111_reactive_solute_substep(trial%mobile,trial%companion,f,mobile,companion,r)
        receipt%status=MATRIX_PROCESS;receipt%process_status=r%status
        if(r%status/=B111_REACTIVE_OK)return
        trial%mobile=mobile;trial%companion=companion;trial%water=t%water_end;trial%time=t%t1
        receipt%external_in=receipt%external_in+r%external_input_mg_cm2
        receipt%external_out=receipt%external_out+r%external_output_mg_cm2
        receipt%decay_out=receipt%decay_out+r%decay_output_mg_cm2
        receipt%completed_substeps=k
      end associate
    end do
    receipt%mass_after=sum(trial%mobile%mass_mg_cm2)+trial%companion%solute_total()
    receipt%residual=receipt%mass_after-receipt%mass_before-receipt%external_in+receipt%external_out
    scale=max(1.0_real64,receipt%mass_before,receipt%mass_after,receipt%external_in,receipt%external_out)
    if(abs(receipt%residual)>4096.0_real64*epsilon(1.0_real64)*scale)return
    trial%revision=trial%revision+1_int64
    committed=trial;receipt%status=MATRIX_OK
  end subroutine

  subroutine export_matrix_solute_restart(state,payload,status)
    type(matrix_solute_state_t),intent(in)::state
    type(matrix_solute_restart_t),intent(out)::payload
    integer,intent(out)::status
    payload=matrix_solute_restart_t();status=MATRIX_INVALID
    if(.not.state%ready())return
    payload%state=state;status=MATRIX_OK
  end subroutine

  subroutine restore_matrix_solute_restart(payload,parameter_id,state,status)
    type(matrix_solute_restart_t),intent(in)::payload
    integer(int64),intent(in)::parameter_id
    type(matrix_solute_state_t),intent(out)::state
    integer,intent(out)::status
    state=matrix_solute_state_t();status=MATRIX_INVALID
    if(payload%schema_version/=1.or.parameter_id/=payload%state%parameter_id)return
    if(.not.payload%state%ready())return
    state=payload%state;status=MATRIX_OK
  end subroutine

  function matrix_parameter_vector(p) result(v)
    type(b111_reactive_solute_substep_forcing_t),intent(in)::p
    real(real64),allocatable::v(:)
    ! Exact bounded immutable configuration fingerprint. Transient carrier
    ! arrays/time are deliberately excluded; these come only from water owner.
    if(.not.allocated(p%dz_cm).or..not.allocated(p%bulk_density).or..not.allocated(p%kf).or. &
         .not.allocated(p%temperature_c).or..not.allocated(p%gampar).or..not.allocated(p%rtheta).or. &
         .not.allocated(p%bexp).or..not.allocated(p%decpot).or..not.allocated(p%fdepth).or. &
         .not.allocated(p%face_left_weight).or..not.allocated(p%face_right_weight).or. &
         .not.allocated(p%face_distance_cm).or..not.allocated(p%theta_sat_left).or. &
         .not.allocated(p%dispersivity_cm))return
    v=[p%dz_cm,p%bulk_density,p%kf,p%temperature_c,p%gampar,p%rtheta,p%bexp,p%decpot,p%fdepth, &
         p%face_left_weight,p%face_right_weight,p%face_distance_cm,p%theta_sat_left,p%dispersivity_cm, &
         p%molecular_diffusion_cm2_day,p%cdrain_mg_cm3,p%cseep_mg_cm3,p%tscf,p%cref_mg_cm3,p%frexp, &
         p%rain_rate_cm_day,p%rain_c_mg_cm3,p%irrigation_rate_cm_day,p%irrigation_c_mg_cm3, &
         p%macropore_area_fraction,merge(1.0_real64,0.0_real64,p%temperature_active)]
    ! Preserve the exact Reference restart vector; a tagged opt-in policy must
    ! nevertheless reject cross-policy restore rather than silently changing it.
    if(p%transport_scheme/=0)v=[v,-11101.0_real64,real(p%transport_scheme,real64)]
  end function

  subroutine reconstruct_matrix_solute_trusted(p,parameter_id,revision,time,water,concentration, &
       dissolved,sorbed,state,status,surface_mass)
    type(b111_reactive_solute_substep_forcing_t),intent(in)::p
    integer(int64),intent(in)::parameter_id,revision
    real(real64),intent(in)::time,water(:),concentration(:),dissolved(:),sorbed(:)
    type(matrix_solute_state_t),intent(out)::state
    integer,intent(out)::status
    real(real64),intent(in),optional::surface_mass
    type(matrix_solute_state_t)::trial
    real(real64)::tol,scale
    state=matrix_solute_state_t();status=MATRIX_INVALID
    if(revision<0.or.size(dissolved)/=size(water).or.size(sorbed)/=size(water))return
    if(present(surface_mass))then
      if(.not.ieee_is_finite(surface_mass))return
      if(surface_mass<0.0_real64.or.surface_mass>1.0e12_real64)return
    end if
    if(.not.all(ieee_is_finite(dissolved)).or..not.all(ieee_is_finite(sorbed)))return
    if(any(dissolved<0.0_real64).or.any(sorbed<0.0_real64))return
    call initialize_matrix_solute(p,parameter_id,time,water,concentration,trial,status)
    if(status/=MATRIX_OK)return
    status=MATRIX_INVALID
    scale=max(1.0_real64,maxval(abs(dissolved)),maxval(abs(sorbed)))
    tol=2048.0_real64*epsilon(1.0_real64)*scale
    if(any(abs(trial%mobile%mass_mg_cm2-dissolved)>tol).or. &
         any(abs(trial%companion%sorbed_matrix_mass-sorbed)>tol))return
    ! Keep exact accepted bits after physical validation, rather than
    ! recomputing and rounding concentration/storage during every restart.
    trial%mobile%mass_mg_cm2=dissolved;trial%companion%sorbed_matrix_mass=sorbed
    if(present(surface_mass))trial%companion%pond_mass=surface_mass
    trial%revision=revision
    state=trial;status=MATRIX_OK
  end subroutine
end module
