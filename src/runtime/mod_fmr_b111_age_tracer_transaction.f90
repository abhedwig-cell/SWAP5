module mod_fmr_b111_age_tracer_transaction
  use, intrinsic :: iso_fortran_env, only: real64,int64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t,transaction_model_t,trial_outcome_t, &
       TX_MASS_MISSING_NONE,TX_MASS_MISSING_UNSPECIFIED
  use mod_solute_mobile_salt_state, only: mobile_salt_state_t
  use mod_solute_compartment_state, only: solute_compartment_state_t
  use mod_b111_age_tracer_matrix_substep, only: b111_age_matrix_physics_t
  use mod_b111_age_tracer_interval, only: b111_age_interval_receipt_t,advance_b111_age_tracer_matrix_interval, &
       B111_AGE_INTERVAL_OK
  use mod_fmr_b111_solute_transaction, only: fmr_b111_solute_state_t,FMR_SOLCOMP_OK
  implicit none
  private

  integer,parameter,public::FMR_B111_AGE_OK=0
  integer,parameter,public::FMR_B111_AGE_INVALID=1
  integer,parameter,public::FMR_B111_AGE_PROCESS_FAILED=2
  integer,parameter,public::FMR_B111_AGE_STATE_FAILED=3

  type,public::fmr_b111_age_forcing_t
    real(real64),allocatable::dz(:)
    real(real64),allocatable::theta_start(:)
    real(real64),allocatable::theta_end(:)
    real(real64),allocatable::q(:)
    real(real64),allocatable::root(:)
    real(real64),allocatable::qdra(:,:)
    real(real64)::rain_rate=0.0_real64
    real(real64)::rain_age=0.0_real64
    real(real64)::irrigation_rate=0.0_real64
    real(real64)::irrigation_age=0.0_real64
    real(real64)::pond_end=0.0_real64
    real(real64)::bottom_age=0.0_real64
    real(real64)::drain_age=0.0_real64
    real(real64)::dt=0.0_real64
    type(b111_age_matrix_physics_t)::physics
  end type

  type,extends(transaction_model_t),public::fmr_b111_age_model_t
    private
    type(fmr_b111_age_forcing_t)::forcing
    type(b111_age_interval_receipt_t)::last_receipt
    logical::configured=.false.
    integer::last_status=FMR_B111_AGE_INVALID
  contains
    procedure::advance=>age_advance
    procedure::storage=>age_storage
    procedure::temporal_error=>age_temporal_error
    procedure::storage_accounting_status=>age_storage_accounting_status
    procedure::attempt_context_required=>age_attempt_context_required
    procedure,public::last_status_code=>age_last_status
    procedure,public::snapshot_receipt=>age_snapshot_receipt
  end type

  public::configure_fmr_b111_age_model

contains

  subroutine configure_fmr_b111_age_model(forcing,model,status)
    type(fmr_b111_age_forcing_t),intent(in)::forcing
    type(fmr_b111_age_model_t),intent(out)::model
    integer,intent(out)::status
    integer::n

    model=fmr_b111_age_model_t();status=FMR_B111_AGE_INVALID
    if(.not.allocated(forcing%dz).or..not.allocated(forcing%theta_start).or..not.allocated(forcing%theta_end).or. &
       .not.allocated(forcing%q).or..not.allocated(forcing%root).or..not.allocated(forcing%qdra))return
    n=size(forcing%dz)
    if(n<1.or.size(forcing%theta_start)/=n.or.size(forcing%theta_end)/=n.or.size(forcing%q)/=n+1.or. &
       size(forcing%root)/=n.or.size(forcing%qdra,2)/=n)return
    if(.not.all(ieee_is_finite(forcing%dz)).or..not.all(ieee_is_finite(forcing%theta_start)).or. &
       .not.all(ieee_is_finite(forcing%theta_end)).or..not.all(ieee_is_finite(forcing%q)).or. &
       .not.all(ieee_is_finite(forcing%root)).or..not.all(ieee_is_finite(forcing%qdra)).or. &
       .not.all(ieee_is_finite([forcing%rain_rate,forcing%rain_age,forcing%irrigation_rate,forcing%irrigation_age, &
       forcing%pond_end,forcing%bottom_age,forcing%drain_age,forcing%dt])))return
    if(forcing%dt<=0.0_real64)return
    model%forcing=forcing;model%configured=.true.;model%last_status=FMR_B111_AGE_OK;status=FMR_B111_AGE_OK
  end subroutine

  subroutine age_advance(self,state,t0,t1,outcome)
    class(fmr_b111_age_model_t),intent(inout)::self
    class(transaction_state_t),intent(inout)::state
    real(real64),intent(in)::t0,t1
    type(trial_outcome_t),intent(out)::outcome
    type(mobile_salt_state_t)::mobile
    type(solute_compartment_state_t)::companion,candidate
    logical::available
    integer::status
    real(real64)::tol

    outcome=trial_outcome_t();self%last_receipt=b111_age_interval_receipt_t();self%last_status=FMR_B111_AGE_INVALID
    if(.not.self%configured.or..not.all(ieee_is_finite([t0,t1])))return
    tol=64.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(self%forcing%dt),abs(t1-t0))
    if(abs((t1-t0)-self%forcing%dt)>tol)return

    select type(state)
    type is(fmr_b111_solute_state_t)
      call state%snapshot(mobile,companion,available)
      if(.not.available)return
      call advance_b111_age_tracer_matrix_interval(companion,self%forcing%dz,self%forcing%theta_start, &
           self%forcing%theta_end,self%forcing%q,self%forcing%root,self%forcing%qdra, &
           self%forcing%rain_rate,self%forcing%rain_age,self%forcing%irrigation_rate,self%forcing%irrigation_age, &
           self%forcing%pond_end,self%forcing%bottom_age,self%forcing%drain_age,self%forcing%dt, &
           self%forcing%physics,candidate,self%last_receipt)
      if(self%last_receipt%status/=B111_AGE_INTERVAL_OK)then
        self%last_status=FMR_B111_AGE_PROCESS_FAILED
        return
      end if
      call state%replace_companion_candidate(candidate,status)
      if(status/=FMR_SOLCOMP_OK)then
        self%last_status=FMR_B111_AGE_STATE_FAILED
        return
      end if
      outcome%solver_ok=.true.
      outcome%mass_in=self%last_receipt%external_age_input+self%last_receipt%age_production
      outcome%mass_out=self%last_receipt%external_age_output
      outcome%mass_accounting_complete=.true.
      outcome%missing_mass_contribution_mask=TX_MASS_MISSING_NONE
      outcome%temporal_certificate_available=.true.
      outcome%temporal_indicator=0.0_real64
      self%last_status=FMR_B111_AGE_OK
    end select
  end subroutine

  real(real64) function age_storage(self,state) result(value)
    class(fmr_b111_age_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::state
    value=0.0_real64
    if(.not.self%configured)return
    select type(state)
    type is(fmr_b111_solute_state_t)
      value=state%age_total()
    end select
  end function

  real(real64) function age_temporal_error(self,full_state,half_state) result(value)
    class(fmr_b111_age_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::full_state,half_state
    value=0.0_real64
    if(.not.self%configured.or..not.same_type_as(full_state,half_state))value=huge(0.0_real64)
  end function

  subroutine age_storage_accounting_status(self,state,complete,missing_mask)
    class(fmr_b111_age_model_t),intent(in)::self
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

  logical function age_attempt_context_required(self) result(required)
    class(fmr_b111_age_model_t),intent(in)::self
    required=.false.
    if(.not.same_type_as(self,self))required=.true.
  end function

  integer function age_last_status(self) result(status)
    class(fmr_b111_age_model_t),intent(in)::self
    status=self%last_status
  end function

  subroutine age_snapshot_receipt(self,receipt,available)
    class(fmr_b111_age_model_t),intent(in)::self
    type(b111_age_interval_receipt_t),intent(out)::receipt
    logical,intent(out)::available
    receipt=self%last_receipt
    available=self%last_status==FMR_B111_AGE_OK.and.receipt%status==B111_AGE_INTERVAL_OK
  end subroutine
end module
