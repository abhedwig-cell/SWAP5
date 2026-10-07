module mod_fmr_b111_reactive_solute_transaction
  use, intrinsic :: iso_fortran_env, only: real64,int64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t,transaction_model_t,trial_outcome_t, &
       TX_MASS_MISSING_NONE,TX_MASS_MISSING_UNSPECIFIED
  use mod_solute_mobile_salt_state, only: mobile_salt_state_t
  use mod_solute_compartment_state, only: solute_compartment_state_t
  use mod_b111_reactive_solute_substep, only: b111_reactive_solute_substep_forcing_t, &
       b111_reactive_solute_substep_receipt_t,advance_b111_reactive_solute_substep,B111_REACTIVE_OK
  use mod_b111_age_tracer_substep, only: b111_age_tracer_substep_forcing_t, &
       b111_age_tracer_substep_receipt_t,advance_b111_age_tracer_substep,B111_AGE_SUBSTEP_OK
  use mod_fmr_b111_solute_transaction, only: fmr_b111_solute_state_t,FMR_SOLCOMP_OK
  implicit none
  private

  integer,parameter,public::FMR_B111_REACTIVE_OK=0
  integer,parameter,public::FMR_B111_REACTIVE_INVALID=1
  integer,parameter,public::FMR_B111_REACTIVE_CHEM_FAILED=2
  integer,parameter,public::FMR_B111_REACTIVE_AGE_FAILED=3
  integer,parameter,public::FMR_B111_REACTIVE_STATE_FAILED=4

  type,public::fmr_b111_reactive_solute_receipt_t
    integer::status=FMR_B111_REACTIVE_INVALID
    type(b111_reactive_solute_substep_receipt_t)::chemical
    type(b111_age_tracer_substep_receipt_t)::age
  end type

  type,extends(transaction_model_t),public::fmr_b111_reactive_solute_model_t
    private
    type(b111_reactive_solute_substep_forcing_t)::chemical_forcing
    type(b111_age_tracer_substep_forcing_t)::age_forcing
    type(fmr_b111_reactive_solute_receipt_t)::last_receipt
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

  public::configure_fmr_b111_reactive_solute_model

contains

  subroutine configure_fmr_b111_reactive_solute_model(chemical_forcing,age_forcing,model,status)
    type(b111_reactive_solute_substep_forcing_t),intent(in)::chemical_forcing
    type(b111_age_tracer_substep_forcing_t),intent(in)::age_forcing
    type(fmr_b111_reactive_solute_model_t),intent(out)::model
    integer,intent(out)::status
    model=fmr_b111_reactive_solute_model_t();status=FMR_B111_REACTIVE_INVALID
    if(.not.ieee_is_finite(chemical_forcing%dt_day).or..not.ieee_is_finite(age_forcing%dt_day))return
    if(chemical_forcing%dt_day<=0.0_real64.or.age_forcing%dt_day<=0.0_real64)return
    if(abs(chemical_forcing%dt_day-age_forcing%dt_day)> &
       64.0_real64*epsilon(1.0_real64)*max(1.0_real64,chemical_forcing%dt_day,age_forcing%dt_day))return
    model%chemical_forcing=chemical_forcing
    model%age_forcing=age_forcing
    model%configured=.true.
    model%last_status=FMR_B111_REACTIVE_OK
    status=FMR_B111_REACTIVE_OK
  end subroutine

  subroutine reactive_advance(self,state,t0,t1,outcome)
    class(fmr_b111_reactive_solute_model_t),intent(inout)::self
    class(transaction_state_t),intent(inout)::state
    real(real64),intent(in)::t0,t1
    type(trial_outcome_t),intent(out)::outcome
    type(mobile_salt_state_t)::mobile0,mobile1
    type(solute_compartment_state_t)::comp0,comp1,comp2
    logical::available
    integer::status
    real(real64)::dt,tol

    outcome=trial_outcome_t()
    self%last_receipt=fmr_b111_reactive_solute_receipt_t()
    self%last_status=FMR_B111_REACTIVE_INVALID
    if(.not.self%configured.or..not.all(ieee_is_finite([t0,t1])).or.t1<=t0)return
    dt=t1-t0
    tol=64.0_real64*epsilon(1.0_real64)*max(1.0_real64,dt,self%chemical_forcing%dt_day)
    if(abs(dt-self%chemical_forcing%dt_day)>tol)return

    select type(state)
    type is(fmr_b111_solute_state_t)
      call state%snapshot(mobile0,comp0,available)
      if(.not.available)return
      call advance_b111_reactive_solute_substep(mobile0,comp0,self%chemical_forcing,mobile1,comp1, &
           self%last_receipt%chemical)
      if(self%last_receipt%chemical%status/=B111_REACTIVE_OK)then
        self%last_status=FMR_B111_REACTIVE_CHEM_FAILED
        return
      end if
      call advance_b111_age_tracer_substep(comp1,self%age_forcing,comp2,self%last_receipt%age)
      if(self%last_receipt%age%status/=B111_AGE_SUBSTEP_OK)then
        self%last_status=FMR_B111_REACTIVE_AGE_FAILED
        return
      end if
      call state%replace_candidate(mobile1,comp2,status)
      if(status/=FMR_SOLCOMP_OK)then
        self%last_status=FMR_B111_REACTIVE_STATE_FAILED
        return
      end if

      outcome%solver_ok=.true.
      outcome%mass_in=self%last_receipt%chemical%external_input_mg_cm2
      outcome%mass_out=self%last_receipt%chemical%external_output_mg_cm2
      outcome%mass_accounting_complete=.true.
      outcome%missing_mass_contribution_mask=TX_MASS_MISSING_NONE
      outcome%temporal_certificate_available=.true.
      outcome%temporal_indicator=0.0_real64
      self%last_receipt%status=FMR_B111_REACTIVE_OK
      self%last_status=FMR_B111_REACTIVE_OK
    end select
  end subroutine

  real(real64) function reactive_storage(self,state) result(value)
    class(fmr_b111_reactive_solute_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::state
    type(mobile_salt_state_t)::mobile
    type(solute_compartment_state_t)::comp
    logical::available
    value=0.0_real64
    if(.not.self%configured)return
    select type(state)
    type is(fmr_b111_solute_state_t)
      call state%snapshot(mobile,comp,available)
      if(available)value=sum(mobile%mass_mg_cm2)+comp%solute_total()
    end select
  end function

  real(real64) function reactive_temporal_error(self,full_state,half_state) result(value)
    class(fmr_b111_reactive_solute_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::full_state,half_state
    value=0.0_real64
    if(.not.self%configured.or..not.same_type_as(full_state,half_state))value=huge(0.0_real64)
  end function

  subroutine reactive_storage_accounting_status(self,state,complete,missing_mask)
    class(fmr_b111_reactive_solute_model_t),intent(in)::self
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
    class(fmr_b111_reactive_solute_model_t),intent(in)::self
    required=.false.
    if(.not.same_type_as(self,self))required=.true.
  end function

  integer function reactive_last_status(self) result(status)
    class(fmr_b111_reactive_solute_model_t),intent(in)::self
    status=self%last_status
  end function

  subroutine reactive_snapshot_receipt(self,receipt,available)
    class(fmr_b111_reactive_solute_model_t),intent(in)::self
    type(fmr_b111_reactive_solute_receipt_t),intent(out)::receipt
    logical,intent(out)::available
    receipt=self%last_receipt
    available=self%last_status==FMR_B111_REACTIVE_OK.and.receipt%status==FMR_B111_REACTIVE_OK
  end subroutine
end module
