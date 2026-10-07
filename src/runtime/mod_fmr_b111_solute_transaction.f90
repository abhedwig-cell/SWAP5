module mod_fmr_b111_solute_transaction
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t, transaction_model_t, trial_outcome_t, &
       TX_MASS_MISSING_NONE, TX_MASS_MISSING_UNSPECIFIED
  use mod_solute_mobile_salt_state, only: mobile_salt_state_t
  use mod_solute_compartment_state, only: solute_compartment_state_t
  implicit none
  private

  integer, parameter, public :: FMR_SOLCOMP_OK=0
  integer, parameter, public :: FMR_SOLCOMP_INVALID=1
  integer, parameter, public :: FMR_SOLCOMP_NEGATIVE=2
  integer, parameter, public :: FMR_SOLCOMP_BALANCE=3
  integer, parameter, public :: FMR_SOLCOMP_AQUIFER_UNAPPROVED=4

  type, public :: fmr_b111_solute_transfer_rate_t
    real(real64), allocatable :: mobile_delta_per_day(:)
    real(real64), allocatable :: sorbed_delta_per_day(:)
    real(real64) :: pond_delta_per_day=0.0_real64
    real(real64) :: aquifer_delta_per_day=0.0_real64
    real(real64), allocatable :: age_delta_per_day(:)
    real(real64) :: external_input_per_day=0.0_real64
    real(real64) :: external_output_per_day=0.0_real64
  end type

  type, extends(transaction_state_t), public :: fmr_b111_solute_state_t
    private
    type(mobile_salt_state_t) :: mobile
    type(solute_compartment_state_t) :: companion
    logical :: initialized=.false.
  contains
    procedure :: clone => solcomp_clone
    procedure, public :: ready => solcomp_ready
    procedure, public :: snapshot => solcomp_snapshot
  end type

  type, extends(transaction_model_t), public :: fmr_b111_solute_model_t
    private
    real(real64), allocatable :: node_thickness_cm(:)
    real(real64), allocatable :: water_content(:)
    type(fmr_b111_solute_transfer_rate_t) :: rate
    logical :: configured=.false.
    integer :: last_status=FMR_SOLCOMP_INVALID
  contains
    procedure :: advance => solcomp_advance
    procedure :: storage => solcomp_storage
    procedure :: temporal_error => solcomp_temporal_error
    procedure :: storage_accounting_status => solcomp_storage_accounting_status
    procedure :: attempt_context_required => solcomp_attempt_context_required
    procedure, public :: last_status_code => solcomp_last_status
  end type

  public :: initialize_fmr_b111_solute_state, configure_fmr_b111_solute_model

contains

  subroutine initialize_fmr_b111_solute_state(mobile,companion,state,status)
    type(mobile_salt_state_t),intent(in)::mobile
    type(solute_compartment_state_t),intent(in)::companion
    type(fmr_b111_solute_state_t),intent(out)::state
    integer,intent(out)::status
    state=fmr_b111_solute_state_t();status=FMR_SOLCOMP_INVALID
    if(.not.mobile_valid(mobile).or..not.companion%valid())return
    if(size(mobile%mass_mg_cm2)/=size(companion%sorbed_matrix_mass))return
    if(size(companion%age_amount)/=size(mobile%mass_mg_cm2))return
    state%mobile=mobile;state%companion=companion;state%initialized=.true.;status=FMR_SOLCOMP_OK
  end subroutine

  subroutine configure_fmr_b111_solute_model(node_thickness_cm,water_content,rate,model,status)
    real(real64),intent(in)::node_thickness_cm(:),water_content(:)
    type(fmr_b111_solute_transfer_rate_t),intent(in)::rate
    type(fmr_b111_solute_model_t),intent(out)::model
    integer,intent(out)::status
    integer::n
    model=fmr_b111_solute_model_t();status=FMR_SOLCOMP_INVALID
    n=size(node_thickness_cm)
    if(n<1.or.size(water_content)/=n)return
    if(.not.all(ieee_is_finite(node_thickness_cm)).or..not.all(ieee_is_finite(water_content)))return
    if(any(node_thickness_cm<=0d0).or.any(water_content<=0d0))return
    if(.not.rate_valid(rate,n))return
    if(abs(rate%aquifer_delta_per_day)>0d0)then
      status=FMR_SOLCOMP_AQUIFER_UNAPPROVED
      return
    end if
    model%node_thickness_cm=node_thickness_cm
    model%water_content=water_content
    model%rate=rate
    model%configured=.true.
    model%last_status=FMR_SOLCOMP_OK
    status=FMR_SOLCOMP_OK
  end subroutine

  subroutine solcomp_clone(self,copy)
    class(fmr_b111_solute_state_t),intent(in)::self
    class(transaction_state_t),allocatable,intent(out)::copy
    allocate(fmr_b111_solute_state_t::copy)
    select type(copy)
    type is(fmr_b111_solute_state_t)
      copy%mobile=self%mobile;copy%companion=self%companion;copy%initialized=self%initialized
    end select
  end subroutine

  logical function solcomp_ready(self) result(ok)
    class(fmr_b111_solute_state_t),intent(in)::self
    ok=self%initialized.and.mobile_valid(self%mobile).and.self%companion%valid()
    if(ok)ok=size(self%mobile%mass_mg_cm2)==size(self%companion%sorbed_matrix_mass).and. &
       size(self%companion%age_amount)==size(self%mobile%mass_mg_cm2)
  end function

  subroutine solcomp_snapshot(self,mobile,companion,available)
    class(fmr_b111_solute_state_t),intent(in)::self
    type(mobile_salt_state_t),intent(out)::mobile
    type(solute_compartment_state_t),intent(out)::companion
    logical,intent(out)::available
    mobile=mobile_salt_state_t();companion=solute_compartment_state_t()
    available=self%ready()
    if(available)then;mobile=self%mobile;companion=self%companion;end if
  end subroutine

  subroutine solcomp_advance(self,state,t0,t1,outcome)
    class(fmr_b111_solute_model_t),intent(inout)::self
    class(transaction_state_t),intent(inout)::state
    real(real64),intent(in)::t0,t1
    type(trial_outcome_t),intent(out)::outcome
    real(real64)::dt,before,after,expected,tol,scale
    outcome=trial_outcome_t();self%last_status=FMR_SOLCOMP_INVALID
    if(.not.self%configured.or..not.ieee_is_finite(t0).or..not.ieee_is_finite(t1).or.t1<=t0)return
    dt=t1-t0
    select type(state)
    type is(fmr_b111_solute_state_t)
      if(.not.state%ready())return
      if(size(state%mobile%mass_mg_cm2)/=size(self%node_thickness_cm))return
      scale=max(1d0,maxval(abs(state%mobile%concentration_mg_cm3)), &
           maxval(abs(state%mobile%mass_mg_cm2/(self%water_content*self%node_thickness_cm))))
      tol=1024d0*epsilon(1d0)*scale
      if(any(abs(state%mobile%concentration_mg_cm3- &
           state%mobile%mass_mg_cm2/(self%water_content*self%node_thickness_cm))>tol))return
      before=sum(state%mobile%mass_mg_cm2)+state%companion%solute_total()
      state%mobile%mass_mg_cm2=state%mobile%mass_mg_cm2+self%rate%mobile_delta_per_day*dt
      state%companion%sorbed_matrix_mass=state%companion%sorbed_matrix_mass+self%rate%sorbed_delta_per_day*dt
      state%companion%pond_mass=state%companion%pond_mass+self%rate%pond_delta_per_day*dt
      state%companion%aquifer_mass=state%companion%aquifer_mass+self%rate%aquifer_delta_per_day*dt
      state%companion%age_amount=state%companion%age_amount+self%rate%age_delta_per_day*dt
      if(any(state%mobile%mass_mg_cm2<0d0).or..not.state%companion%valid())then
        self%last_status=FMR_SOLCOMP_NEGATIVE
        return
      end if
      state%mobile%concentration_mg_cm3=state%mobile%mass_mg_cm2/(self%water_content*self%node_thickness_cm)
      if(.not.all(ieee_is_finite(state%mobile%concentration_mg_cm3)))return
      after=sum(state%mobile%mass_mg_cm2)+state%companion%solute_total()
      expected=before+(self%rate%external_input_per_day-self%rate%external_output_per_day)*dt
      scale=max(1d0,abs(before),abs(after),abs(expected))
      tol=1024d0*epsilon(1d0)*scale
      if(abs(after-expected)>tol)then
        self%last_status=FMR_SOLCOMP_BALANCE
        return
      end if
      outcome%solver_ok=.true.
      outcome%mass_in=self%rate%external_input_per_day*dt
      outcome%mass_out=self%rate%external_output_per_day*dt
      outcome%mass_accounting_complete=.true.
      outcome%missing_mass_contribution_mask=TX_MASS_MISSING_NONE
      outcome%temporal_certificate_available=.true.
      outcome%temporal_indicator=0d0
      self%last_status=FMR_SOLCOMP_OK
    end select
  end subroutine

  real(real64) function solcomp_storage(self,state) result(value)
    class(fmr_b111_solute_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::state
    value=0d0
    if(.not.self%configured)return
    select type(state)
    type is(fmr_b111_solute_state_t)
      if(state%ready())value=sum(state%mobile%mass_mg_cm2)+state%companion%solute_total()
    end select
  end function

  real(real64) function solcomp_temporal_error(self,full_state,half_state) result(value)
    class(fmr_b111_solute_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::full_state,half_state
    value=0d0
    if(.not.self%configured.or..not.same_type_as(full_state,half_state))value=huge(0d0)
  end function

  subroutine solcomp_storage_accounting_status(self,state,complete,missing_mask)
    class(fmr_b111_solute_model_t),intent(in)::self
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

  logical function solcomp_attempt_context_required(self) result(required)
    class(fmr_b111_solute_model_t),intent(in)::self
    required=.false.
    if(.not.same_type_as(self,self))required=.true.
  end function

  integer function solcomp_last_status(self) result(status)
    class(fmr_b111_solute_model_t),intent(in)::self
    status=self%last_status
  end function

  logical function mobile_valid(mobile) result(ok)
    type(mobile_salt_state_t),intent(in)::mobile
    ok=.false.
    if(.not.allocated(mobile%mass_mg_cm2).or..not.allocated(mobile%concentration_mg_cm3))return
    if(size(mobile%mass_mg_cm2)<1.or.size(mobile%concentration_mg_cm3)/=size(mobile%mass_mg_cm2))return
    if(.not.all(ieee_is_finite(mobile%mass_mg_cm2)).or..not.all(ieee_is_finite(mobile%concentration_mg_cm3)))return
    if(any(mobile%mass_mg_cm2<0d0).or.any(mobile%concentration_mg_cm3<0d0))return
    ok=.true.
  end function

  logical function rate_valid(rate,n) result(ok)
    type(fmr_b111_solute_transfer_rate_t),intent(in)::rate
    integer,intent(in)::n
    ok=.false.
    if(.not.allocated(rate%mobile_delta_per_day).or..not.allocated(rate%sorbed_delta_per_day).or. &
       .not.allocated(rate%age_delta_per_day))return
    if(size(rate%mobile_delta_per_day)/=n.or.size(rate%sorbed_delta_per_day)/=n.or.size(rate%age_delta_per_day)/=n)return
    if(.not.all(ieee_is_finite(rate%mobile_delta_per_day)).or..not.all(ieee_is_finite(rate%sorbed_delta_per_day)).or. &
       .not.all(ieee_is_finite(rate%age_delta_per_day)))return
    if(.not.all(ieee_is_finite([rate%pond_delta_per_day,rate%aquifer_delta_per_day, &
       rate%external_input_per_day,rate%external_output_per_day])))return
    if(rate%external_input_per_day<0d0.or.rate%external_output_per_day<0d0)return
    ok=.true.
  end function
end module
