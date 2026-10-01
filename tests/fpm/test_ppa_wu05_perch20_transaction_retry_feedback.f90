module mod_perch20_transaction_test
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference
  implicit none
  private

  type, extends(transaction_state_t), public :: perch20_state_t
    real(real64) :: water=1.0_real64
    real(real64) :: trial_dt=0.0_real64
  contains
    procedure :: clone => clone_state
  end type perch20_state_t

  type, extends(transaction_attempt_context_t) :: perch20_context_t
    integer :: numerical_level=0
  end type perch20_context_t

  type, extends(transaction_model_t), public :: perch20_model_t
    integer :: numerical_level=0
    integer :: advance_calls=0
    integer :: retry_feedback_calls=0
    integer :: accepted_feedback_calls=0
    logical :: fail_when_level_zero=.false.
    logical :: mutate_on_advance=.false.
    real(real64) :: retry_override=0.3_real64
    real(real64) :: seen_dt(16)=0.0_real64
    integer :: seen_level(16)=-1
  contains
    procedure :: advance => model_advance
    procedure :: storage => model_storage
    procedure :: temporal_error => model_temporal_error
    procedure :: storage_accounting_status => model_storage_status
    procedure :: capture_attempt_context => model_capture
    procedure :: restore_attempt_context => model_restore
    procedure :: apply_retry_feedback => model_retry_feedback
    procedure :: apply_accepted_feedback => model_accepted_feedback
  end type perch20_model_t

contains

  subroutine clone_state(self,copy)
    class(perch20_state_t),intent(in)::self
    class(transaction_state_t),allocatable,intent(out)::copy
    allocate(perch20_state_t::copy)
    select type(copy)
    type is(perch20_state_t)
      copy%water=self%water
      copy%trial_dt=self%trial_dt
    end select
  end subroutine clone_state

  subroutine model_capture(self,context)
    class(perch20_model_t),intent(inout)::self
    class(transaction_attempt_context_t),allocatable,intent(out)::context
    allocate(perch20_context_t::context)
    select type(context)
    type is(perch20_context_t)
      context%numerical_level=self%numerical_level
    class default
      error stop 'PERCH20 context allocation'
    end select
  end subroutine model_capture

  subroutine model_restore(self,context)
    class(perch20_model_t),intent(inout)::self
    class(transaction_attempt_context_t),intent(in)::context
    select type(context)
    type is(perch20_context_t)
      self%numerical_level=context%numerical_level
    class default
      error stop 'PERCH20 context restore'
    end select
  end subroutine model_restore

  subroutine model_advance(self,state,t0,t1,outcome)
    class(perch20_model_t),intent(inout)::self
    class(transaction_state_t),intent(inout)::state
    real(real64),intent(in)::t0,t1
    type(trial_outcome_t),intent(out)::outcome
    real(real64)::dt

    outcome=trial_outcome_t()
    dt=t1-t0
    self%advance_calls=self%advance_calls+1
    if(self%advance_calls<=size(self%seen_dt))then
      self%seen_dt(self%advance_calls)=dt
      self%seen_level(self%advance_calls)=self%numerical_level
    end if

    select type(state)
    type is(perch20_state_t)
      state%trial_dt=dt
    class default
      error stop 'PERCH20 state type'
    end select

    if(self%mutate_on_advance)self%numerical_level=self%numerical_level+1
    if(self%fail_when_level_zero .and. self%numerical_level==0)then
      outcome%solver_ok=.false.
      outcome%nonlinear_iterations=7
      return
    end if

    outcome%solver_ok=.true.
    outcome%mass_in=0.0_real64
    outcome%mass_out=0.0_real64
    outcome%mass_accounting_complete=.true.
    outcome%missing_mass_contribution_mask=TX_MASS_MISSING_NONE
    outcome%temporal_certificate_available=.true.
    outcome%temporal_indicator=0.0_real64
    outcome%nonlinear_iterations=1
  end subroutine model_advance

  function model_storage(self,state) result(value)
    class(perch20_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::state
    real(real64)::value
    if(self%advance_calls<0)error stop 'PERCH20 impossible calls'
    select type(state)
    type is(perch20_state_t)
      value=state%water
    class default
      error stop 'PERCH20 storage type'
    end select
  end function model_storage

  subroutine model_storage_status(self,state,complete,missing_mask)
    class(perch20_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::state
    logical,intent(out)::complete
    integer(int64),intent(out)::missing_mask
    if(self%advance_calls<0)error stop 'PERCH20 impossible status'
    select type(state)
    type is(perch20_state_t)
      complete=.true.
      missing_mask=TX_MASS_MISSING_NONE
    class default
      complete=.false.
      missing_mask=TX_MASS_MISSING_UNSPECIFIED
    end select
  end subroutine model_storage_status

  function model_temporal_error(self,full_state,half_state) result(value)
    class(perch20_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::full_state,half_state
    real(real64)::value
    real(real64)::full_dt
    if(self%advance_calls<0)error stop 'PERCH20 impossible temporal'
    select type(full_state)
    type is(perch20_state_t)
      full_dt=full_state%trial_dt
    class default
      error stop 'PERCH20 full state'
    end select
    select type(half_state)
    type is(perch20_state_t)
      if(half_state%trial_dt<0.0_real64)error stop 'PERCH20 half dt'
    class default
      error stop 'PERCH20 half state'
    end select
    value=full_dt
  end function model_temporal_error

  subroutine model_retry_feedback(self,outcome,attempted_dt,override_available,override_dt,ok)
    class(perch20_model_t),intent(inout)::self
    type(trial_outcome_t),intent(in)::outcome
    real(real64),intent(in)::attempted_dt
    logical,intent(out)::override_available
    real(real64),intent(out)::override_dt
    logical,intent(out)::ok

    self%retry_feedback_calls=self%retry_feedback_calls+1
    ! Rollback must already have restored level zero.
    ok=self%numerical_level==0 .and. .not.outcome%solver_ok .and. attempted_dt>0.0_real64
    if(.not.ok)then
      override_available=.false.
      override_dt=attempted_dt
      return
    end if
    self%numerical_level=1
    override_available=.true.
    override_dt=self%retry_override
  end subroutine model_retry_feedback

  subroutine model_accepted_feedback(self,accepted_dt,ok)
    class(perch20_model_t),intent(inout)::self
    real(real64),intent(in)::accepted_dt
    logical,intent(out)::ok
    self%accepted_feedback_calls=self%accepted_feedback_calls+1
    ok=accepted_dt>0.0_real64
    if(ok)self%numerical_level=self%numerical_level+10
  end subroutine model_accepted_feedback

end module mod_perch20_transaction_test

program test_ppa_wu05_perch20_transaction_retry_feedback
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference
  use mod_perch20_transaction_test
  implicit none

  call test_external_solver_retry()
  call test_external_temporal_isolation()
  call test_certificate_solver_retry()

  print '(a)', 'PPA_WU05_PERCH20_POST_ROLLBACK_FEEDBACK=PASS'
  print '(a)', 'PPA_WU05_PERCH20_RETRY_DT_OVERRIDE=PASS'
  print '(a)', 'PPA_WU05_PERCH20_SPECULATIVE_ISOLATION=PASS'
  print '(a)', 'PPA_WU05_PERCH20_ACCEPTED_FEEDBACK=PASS'
  print '(a)', 'PPA_WU05_PERCH20_BOTH_ROUTES=PASS'
  print '(a)', 'PPA_WU05_PERCH20_TRANSACTION_PROTOCOL_GATE=PASS'

contains

  subroutine new_state(state)
    class(transaction_state_t),allocatable,intent(out)::state
    allocate(perch20_state_t::state)
  end subroutine new_state

  subroutine test_external_solver_retry()
    class(transaction_state_t),allocatable::state
    type(perch20_model_t)::model
    type(transaction_policy_t)::policy
    type(transaction_result_t)::result

    call new_state(state)
    model%fail_when_level_zero=.true.
    policy%temporal_tolerance=2.0_real64
    policy%mass_tolerance=1.0e-12_real64
    policy%max_retries=3
    policy%retry_scale=0.5_real64
    policy%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF

    call execute_reference_interval(model,state,0.0_real64,1.0_real64,policy,result)
    call require(result%status==TX_STATUS_ACCEPTED,'external retry accepted')
    call require(result%solver_rejections==1 .and. result%retries==1,'external one solver retry')
    call require(model%retry_feedback_calls==1,'external feedback once')
    call require(abs(model%seen_dt(1)-1.0_real64)<1.0e-15_real64,'external first dt')
    call require(model%seen_level(1)==0,'external first level')
    call require(abs(model%seen_dt(2)-0.3_real64)<1.0e-15_real64,'external override full dt')
    call require(model%seen_level(2)==1,'external retry sees feedback level')
    call require(model%accepted_feedback_calls==1,'external accepted feedback once')
    call require(model%numerical_level==11,'external accepted feedback persisted')
  end subroutine test_external_solver_retry

  subroutine test_external_temporal_isolation()
    class(transaction_state_t),allocatable::state
    type(perch20_model_t)::model
    type(transaction_policy_t)::policy
    type(transaction_result_t)::result

    call new_state(state)
    model%mutate_on_advance=.true.
    policy%temporal_tolerance=0.6_real64
    policy%mass_tolerance=1.0e-12_real64
    policy%max_retries=2
    policy%retry_scale=0.5_real64
    policy%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF

    call execute_reference_interval(model,state,0.0_real64,1.0_real64,policy,result)
    call require(result%status==TX_STATUS_ACCEPTED,'temporal isolation accepted')
    call require(result%temporal_rejections==1,'one temporal rejection')
    call require(model%retry_feedback_calls==0,'temporal rejection no solver feedback')
    ! Accepted half route contains exactly two advance mutations after rollback.
    call require(model%numerical_level==12,'temporal rejected mutations rolled back')
    call require(model%accepted_feedback_calls==1,'temporal accepted feedback once')
  end subroutine test_external_temporal_isolation

  subroutine test_certificate_solver_retry()
    class(transaction_state_t),allocatable::state
    type(perch20_model_t)::model
    type(transaction_policy_t)::policy
    type(transaction_result_t)::result

    call new_state(state)
    model%fail_when_level_zero=.true.
    model%retry_override=0.4_real64
    policy%temporal_tolerance=1.0_real64
    policy%mass_tolerance=1.0e-12_real64
    policy%max_retries=3
    policy%retry_scale=0.5_real64
    policy%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE

    call execute_reference_interval(model,state,2.0_real64,3.0_real64,policy,result)
    call require(result%status==TX_STATUS_ACCEPTED,'certificate retry accepted')
    call require(result%accepted_route==TX_ROUTE_MODEL_CERTIFIED,'certificate route')
    call require(model%retry_feedback_calls==1,'certificate feedback once')
    call require(abs(model%seen_dt(2)-0.4_real64)<1.0e-15_real64,'certificate override dt')
    call require(model%seen_level(2)==1,'certificate retry sees level')
    call require(model%accepted_feedback_calls==1,'certificate accepted feedback once')
    call require(model%numerical_level==11,'certificate accepted level persisted')
  end subroutine test_certificate_solver_retry

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(a,1x,a)') 'PPA_WU05_PERCH20_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_ppa_wu05_perch20_transaction_retry_feedback
