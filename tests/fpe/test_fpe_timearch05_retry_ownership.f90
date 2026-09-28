module mod_fpe_timearch05_model
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference
  implicit none
  private

  integer, parameter, public :: CASE_LOCAL=1, CASE_SOLVER_ESCALATE=2, CASE_TEMPORAL=3

  type, extends(transaction_state_t), public :: retry_state_t
    real(real64) :: water=1.0_real64
  contains
    procedure :: clone => retry_clone
  end type

  type, extends(transaction_model_t), public :: retry_model_t
    integer :: scenario=CASE_LOCAL
    integer :: call_count=0
  contains
    procedure :: advance => retry_advance
    procedure :: storage => retry_storage
    procedure :: temporal_error => retry_temporal_error
    procedure :: storage_accounting_status => retry_storage_status
    procedure :: attempt_context_required => retry_context_not_required
  end type

contains

  subroutine retry_clone(self,copy)
    class(retry_state_t),intent(in)::self
    class(transaction_state_t),allocatable,intent(out)::copy
    allocate(retry_state_t::copy)
    select type(copy)
    type is(retry_state_t)
      copy%water=self%water
    end select
  end subroutine

  subroutine retry_advance(self,state,t0,t1,outcome)
    class(retry_model_t),intent(inout)::self
    class(transaction_state_t),intent(inout)::state
    real(real64),intent(in)::t0,t1
    type(trial_outcome_t),intent(out)::outcome
    real(real64)::dt
    self%call_count=self%call_count+1
    dt=t1-t0
    outcome=trial_outcome_t()
    outcome%mass_accounting_complete=.true.
    outcome%missing_mass_contribution_mask=TX_MASS_MISSING_NONE
    outcome%temporal_certificate_available=.true.
    outcome%temporal_indicator=0.5_real64
    outcome%nonlinear_iterations=5
    outcome%jacobian_builds=5
    outcome%linear_solves=5
    outcome%backtracking_attempts=1

    select case(self%scenario)
    case(CASE_LOCAL)
      outcome%solver_ok=.true.
      outcome%internal_retries=2
    case(CASE_SOLVER_ESCALATE)
      if(self%call_count==1)then
        outcome%solver_ok=.false.
        outcome%internal_retries=3
        outcome%nonlinear_iterations=12
        outcome%jacobian_builds=12
        outcome%linear_solves=12
        outcome%backtracking_attempts=6
        return
      end if
      outcome%solver_ok=.true.
      outcome%internal_retries=1
    case(CASE_TEMPORAL)
      outcome%solver_ok=.true.
      outcome%internal_retries=1
      if(dt>0.05_real64)then
        outcome%temporal_indicator=2.0_real64
      else
        outcome%temporal_indicator=0.5_real64
      end if
    end select

    select type(state)
    type is(retry_state_t)
      ! State deliberately unchanged: this study is ownership/accounting only.
      state%water=state%water
    class default
      error stop 'TIMEARCH05 unexpected state'
    end select
  end subroutine

  function retry_storage(self,state) result(value)
    class(retry_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::state
    real(real64)::value
    if(self%scenario<0) error stop 'unreachable'
    select type(state)
    type is(retry_state_t)
      value=state%water
    class default
      error stop 'TIMEARCH05 unexpected storage state'
    end select
  end function

  function retry_temporal_error(self,full_state,half_state) result(value)
    class(retry_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::full_state,half_state
    real(real64)::value
    if(self%scenario<0 .or. .not.same_type_as(full_state,half_state)) error stop 'unreachable'
    value=0.0_real64
  end function

  subroutine retry_storage_status(self,state,complete,missing_mask)
    class(retry_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::state
    logical,intent(out)::complete
    integer(int64),intent(out)::missing_mask
    if(self%scenario<0 .or. .not.same_type_as(state,state)) error stop 'unreachable'
    complete=.true.
    missing_mask=TX_MASS_MISSING_NONE
  end subroutine

  logical function retry_context_not_required(self) result(required)
    class(retry_model_t),intent(in)::self
    if(self%scenario<0) error stop 'unreachable'
    required=.false.
  end function

end module mod_fpe_timearch05_model

program test_fpe_timearch05_retry_ownership
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference
  use mod_fpe_timearch05_model
  implicit none
  integer::failures
  failures=0
  call test_local(failures)
  call test_solver_escalation(failures)
  call test_temporal(failures)
  if(failures/=0)then
    write(*,'(A,I0)')'F_PE_TIMEARCH05_FAILURES=',failures
    error stop 1
  end if
  write(*,'(A)')'F_PE_TIMEARCH05=PASS'
contains

  subroutine new_state(s)
    class(transaction_state_t),allocatable,intent(out)::s
    allocate(retry_state_t::s)
  end subroutine

  integer function total_work(r) result(w)
    type(transaction_result_t),intent(in)::r
    w=r%nonlinear_iterations+r%backtracking_attempts+r%jacobian_builds+r%linear_solves
  end function

  integer function accepted_work(r) result(w)
    type(transaction_result_t),intent(in)::r
    w=r%accepted_nonlinear_iterations+r%accepted_backtracking_attempts+ &
      r%accepted_jacobian_builds+r%accepted_linear_solves
  end function

  subroutine req(x,label,failures)
    logical,intent(in)::x
    character(len=*),intent(in)::label
    integer,intent(inout)::failures
    if(.not.x)then
      failures=failures+1
      write(*,'(A,A)')'F_PE_TIMEARCH05_FAIL ',trim(label)
    end if
  end subroutine

  subroutine base_policy(p)
    type(transaction_policy_t),intent(out)::p
    p=transaction_policy_t()
    p%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
    p%mass_tolerance=1.0e-12_real64
    p%temporal_tolerance=0.0_real64
    p%retry_scale=0.5_real64
    p%max_retries=2
  end subroutine

  subroutine test_local(failures)
    integer,intent(inout)::failures
    class(transaction_state_t),allocatable::s
    type(retry_model_t)::m
    type(transaction_policy_t)::p
    type(transaction_result_t)::r
    call new_state(s);call base_policy(p)
    m%scenario=CASE_LOCAL
    call execute_reference_interval(m,s,0.0_real64,0.04_real64,p,r)
    call req(r%status==TX_STATUS_ACCEPTED,'local accepted',failures)
    call req(r%attempts==1 .and. r%retries==0,'local no outer retry',failures)
    call req(r%solver_rejections==0 .and. r%temporal_rejections==0,'local no outer rejection',failures)
    call req(r%internal_retries==2 .and. r%accepted_internal_retries==2,'local internal ownership',failures)
    call req(total_work(r)==accepted_work(r),'local no discarded outer work',failures)
    write(*,'(*(g0))')'F_PE_TIMEARCH05_CASE=LOCAL|ATTEMPTS=',r%attempts,'|OUTER_RETRIES=',r%retries, &
      '|INTERNAL_RETRIES=',r%internal_retries,'|TOTAL_WORK=',total_work(r),'|ACCEPTED_WORK=',accepted_work(r)
  end subroutine

  subroutine test_solver_escalation(failures)
    integer,intent(inout)::failures
    class(transaction_state_t),allocatable::s
    type(retry_model_t)::m
    type(transaction_policy_t)::p
    type(transaction_result_t)::r
    call new_state(s);call base_policy(p)
    m%scenario=CASE_SOLVER_ESCALATE
    call execute_reference_interval(m,s,0.0_real64,0.08_real64,p,r)
    call req(r%status==TX_STATUS_ACCEPTED,'solver escalation accepted',failures)
    call req(r%attempts==2 .and. r%retries==1,'solver one outer retry',failures)
    call req(r%solver_rejections==1 .and. r%temporal_rejections==0,'solver rejection typed',failures)
    call req(r%internal_retries==4 .and. r%accepted_internal_retries==1,'solver nested internal work',failures)
    call req(total_work(r)>accepted_work(r),'solver discarded work visible',failures)
    write(*,'(*(g0))')'F_PE_TIMEARCH05_CASE=SOLVER_ESCALATION|ATTEMPTS=',r%attempts, &
      '|OUTER_RETRIES=',r%retries,'|SOLVER_REJECTIONS=',r%solver_rejections, &
      '|INTERNAL_RETRIES=',r%internal_retries,'|ACCEPTED_INTERNAL=',r%accepted_internal_retries, &
      '|TOTAL_WORK=',total_work(r),'|ACCEPTED_WORK=',accepted_work(r), &
      '|DISCARDED_WORK=',total_work(r)-accepted_work(r)
  end subroutine

  subroutine test_temporal(failures)
    integer,intent(inout)::failures
    class(transaction_state_t),allocatable::s
    type(retry_model_t)::m
    type(transaction_policy_t)::p
    type(transaction_result_t)::r
    call new_state(s);call base_policy(p)
    m%scenario=CASE_TEMPORAL
    call execute_reference_interval(m,s,0.0_real64,0.08_real64,p,r)
    call req(r%status==TX_STATUS_ACCEPTED,'temporal accepted after retry',failures)
    call req(r%attempts==2 .and. r%retries==1,'temporal one outer retry',failures)
    call req(r%solver_rejections==0 .and. r%temporal_rejections==1,'temporal rejection typed',failures)
    call req(r%internal_retries==2 .and. r%accepted_internal_retries==1,'temporal nested internal work',failures)
    call req(total_work(r)>accepted_work(r),'temporal discarded work visible',failures)
    write(*,'(*(g0))')'F_PE_TIMEARCH05_CASE=TEMPORAL|ATTEMPTS=',r%attempts, &
      '|OUTER_RETRIES=',r%retries,'|TEMPORAL_REJECTIONS=',r%temporal_rejections, &
      '|INTERNAL_RETRIES=',r%internal_retries,'|ACCEPTED_INTERNAL=',r%accepted_internal_retries, &
      '|TOTAL_WORK=',total_work(r),'|ACCEPTED_WORK=',accepted_work(r), &
      '|DISCARDED_WORK=',total_work(r)-accepted_work(r)
  end subroutine
end program test_fpe_timearch05_retry_ownership
