module mod_fmr_b111_reactive_solute_transaction
  use, intrinsic :: iso_fortran_env, only: real64,int64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t,transaction_model_t,trial_outcome_t, &
       TX_MASS_MISSING_NONE,TX_MASS_MISSING_UNSPECIFIED
  use mod_solute_mobile_salt_state, only: mobile_salt_state_t
  use mod_solute_compartment_state, only: solute_compartment_state_t
  use mod_b111_reactive_solute_substep, only: b111_reactive_dispersion_t,b111_reactive_substep_receipt_t, &
       advance_b111_reactive_solute_substep,B111_REACTIVE_OK
  use mod_fmr_b111_solute_transaction, only: fmr_b111_solute_state_t,FMR_SOLCOMP_OK
  implicit none
  private

  integer,parameter,public::FMR_B111_REACTIVE_OK=0
  integer,parameter,public::FMR_B111_REACTIVE_INVALID=1
  integer,parameter,public::FMR_B111_REACTIVE_PROCESS_FAILED=2
  integer,parameter,public::FMR_B111_REACTIVE_STATE_FAILED=3

  type,public::fmr_b111_reactive_forcing_t
    real(real64),allocatable::dz(:)
    real(real64),allocatable::theta(:)
    real(real64),allocatable::q(:)
    real(real64),allocatable::root(:)
    real(real64),allocatable::qdra(:,:)
    real(real64)::rain_rate=0.0_real64
    real(real64)::rain_c=0.0_real64
    real(real64)::irrigation_rate=0.0_real64
    real(real64)::irrigation_c=0.0_real64
    real(real64)::pond_end=0.0_real64
    real(real64)::bottom_c=0.0_real64
    real(real64)::drain_c=0.0_real64
    real(real64)::tscf=0.0_real64
    logical::temperature_active=.false.
    real(real64),allocatable::tsoil(:)
    real(real64),allocatable::gampar(:)
    real(real64),allocatable::rtheta(:)
    real(real64),allocatable::bexp(:)
    real(real64),allocatable::decpot(:)
    real(real64),allocatable::fdepth(:)
    real(real64),allocatable::bdens(:)
    real(real64),allocatable::kf(:)
    real(real64)::cref=1.0_real64
    real(real64)::frexp=1.0_real64
    real(real64)::dt=0.0_real64
    type(b111_reactive_dispersion_t)::physics
  end type

  type,extends(transaction_model_t),public::fmr_b111_reactive_model_t
    private
    type(fmr_b111_reactive_forcing_t)::forcing
    type(b111_reactive_substep_receipt_t)::last_receipt
    logical::configured=.false.
    integer::last_status=FMR_B111_REACTIVE_INVALID
  contains
    procedure::advance=>reactive_advance
    procedure::storage=>reactive_storage
    procedure::temporal_error=>reactive_temporal_error
    procedure::storage_accounting_status=>reactive_storage_accounting_status
    procedure::attempt_context_required=>reactive_attempt_context_required
    procedure,public::last_status_code=>reactive_last_status
    procedure,public::snapshot_receipt=>reactive_snapshot_receipt
  end type

  public::configure_fmr_b111_reactive_model

contains

  subroutine configure_fmr_b111_reactive_model(forcing,model,status)
    type(fmr_b111_reactive_forcing_t),intent(in)::forcing
    type(fmr_b111_reactive_model_t),intent(out)::model
    integer,intent(out)::status
    integer::n

    model=fmr_b111_reactive_model_t();status=FMR_B111_REACTIVE_INVALID
    if(.not.allocated(forcing%dz).or..not.allocated(forcing%theta).or..not.allocated(forcing%q).or. &
       .not.allocated(forcing%root).or..not.allocated(forcing%qdra).or..not.allocated(forcing%tsoil).or. &
       .not.allocated(forcing%gampar).or..not.allocated(forcing%rtheta).or..not.allocated(forcing%bexp).or. &
       .not.allocated(forcing%decpot).or..not.allocated(forcing%fdepth).or..not.allocated(forcing%bdens).or. &
       .not.allocated(forcing%kf))return
    n=size(forcing%dz)
    if(n<1.or.size(forcing%theta)/=n.or.size(forcing%q)/=n+1.or.size(forcing%root)/=n.or. &
       size(forcing%qdra,2)/=n.or.size(forcing%tsoil)/=n.or.size(forcing%gampar)/=n.or. &
       size(forcing%rtheta)/=n.or.size(forcing%bexp)/=n.or.size(forcing%decpot)/=n.or. &
       size(forcing%fdepth)/=n.or.size(forcing%bdens)/=n.or.size(forcing%kf)/=n)return
    if(.not.all(ieee_is_finite(forcing%dz)).or..not.all(ieee_is_finite(forcing%theta)).or. &
       .not.all(ieee_is_finite(forcing%q)).or..not.all(ieee_is_finite(forcing%root)).or. &
       .not.all(ieee_is_finite(forcing%qdra)).or..not.all(ieee_is_finite([forcing%rain_rate,forcing%rain_c, &
       forcing%irrigation_rate,forcing%irrigation_c,forcing%pond_end,forcing%bottom_c,forcing%drain_c, &
       forcing%tscf,forcing%cref,forcing%frexp,forcing%dt])))return
    if(forcing%dt<=0.0_real64)return
    model%forcing=forcing;model%configured=.true.;model%last_status=FMR_B111_REACTIVE_OK
    status=FMR_B111_REACTIVE_OK
  end subroutine

  subroutine reactive_advance(self,state,t0,t1,outcome)
    class(fmr_b111_reactive_model_t),intent(inout)::self
    class(transaction_state_t),intent(inout)::state
    real(real64),intent(in)::t0,t1
    type(trial_outcome_t),intent(out)::outcome
    type(mobile_salt_state_t)::mobile,candidate_mobile
    type(solute_compartment_state_t)::companion,candidate_companion
    logical::available
    integer::status
    real(real64)::tol

    outcome=trial_outcome_t();self%last_receipt=b111_reactive_substep_receipt_t()
    self%last_status=FMR_B111_REACTIVE_INVALID
    if(.not.self%configured.or..not.all(ieee_is_finite([t0,t1])))return
    tol=64.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(self%forcing%dt),abs(t1-t0))
    if(abs((t1-t0)-self%forcing%dt)>tol)return

    select type(state)
    type is(fmr_b111_solute_state_t)
      call state%snapshot(mobile,companion,available)
      if(.not.available)return
      call advance_b111_reactive_solute_substep(mobile,companion,self%forcing%dz,self%forcing%theta, &
           self%forcing%q,self%forcing%root,self%forcing%qdra,self%forcing%rain_rate,self%forcing%rain_c, &
           self%forcing%irrigation_rate,self%forcing%irrigation_c,self%forcing%pond_end,self%forcing%bottom_c, &
           self%forcing%drain_c,self%forcing%tscf,self%forcing%temperature_active,self%forcing%tsoil, &
           self%forcing%gampar,self%forcing%rtheta,self%forcing%bexp,self%forcing%decpot,self%forcing%fdepth, &
           self%forcing%bdens,self%forcing%kf,self%forcing%cref,self%forcing%frexp,self%forcing%dt,self%forcing%physics, &
           candidate_mobile,candidate_companion,self%last_receipt)
      if(self%last_receipt%status/=B111_REACTIVE_OK)then
        self%last_status=FMR_B111_REACTIVE_PROCESS_FAILED
        return
      end if
      call state%replace_reactive_candidate(candidate_mobile,candidate_companion,status)
      if(status/=FMR_SOLCOMP_OK)then
        self%last_status=FMR_B111_REACTIVE_STATE_FAILED
        return
      end if
      outcome%solver_ok=.true.
      outcome%mass_in=self%last_receipt%external_input
      outcome%mass_out=self%last_receipt%external_output
      outcome%mass_accounting_complete=.true.
      outcome%missing_mass_contribution_mask=TX_MASS_MISSING_NONE
      outcome%temporal_certificate_available=.true.
      outcome%temporal_indicator=0.0_real64
      self%last_status=FMR_B111_REACTIVE_OK
    end select
  end subroutine

  real(real64) function reactive_storage(self,state) result(value)
    class(fmr_b111_reactive_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::state
    type(mobile_salt_state_t)::mobile
    type(solute_compartment_state_t)::companion
    logical::available
    value=0.0_real64
    if(.not.self%configured)return
    select type(state)
    type is(fmr_b111_solute_state_t)
      call state%snapshot(mobile,companion,available)
      if(available)value=sum(mobile%mass_mg_cm2)+companion%solute_total()
    end select
  end function

  real(real64) function reactive_temporal_error(self,full_state,half_state) result(value)
    class(fmr_b111_reactive_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::full_state,half_state
    value=0.0_real64
    if(.not.self%configured.or..not.same_type_as(full_state,half_state))value=huge(0.0_real64)
  end function

  subroutine reactive_storage_accounting_status(self,state,complete,missing_mask)
    class(fmr_b111_reactive_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::state
    logical,intent(out)::complete
    integer(int64),intent(out)::missing_mask
    complete=.false.;missing_mask=TX_MASS_MISSING_UNSPECIFIED
    if(.not.self%configured)return
    select type(state)
    type is(fmr_b111_solute_state_t)
      complete=state%ready()
      if(complete)missing_mask=TX_MASS_MISSING_NONE
    end select
  end subroutine

  logical function reactive_attempt_context_required(self) result(required)
    class(fmr_b111_reactive_model_t),intent(in)::self
    required=.false.
    if(.not.same_type_as(self,self))required=.true.
  end function

  integer function reactive_last_status(self) result(status)
    class(fmr_b111_reactive_model_t),intent(in)::self
    status=self%last_status
  end function

  subroutine reactive_snapshot_receipt(self,receipt,available)
    class(fmr_b111_reactive_model_t),intent(in)::self
    type(b111_reactive_substep_receipt_t),intent(out)::receipt
    logical,intent(out)::available
    receipt=self%last_receipt
    available=self%last_status==FMR_B111_REACTIVE_OK.and.receipt%status==B111_REACTIVE_OK
  end subroutine
end module
