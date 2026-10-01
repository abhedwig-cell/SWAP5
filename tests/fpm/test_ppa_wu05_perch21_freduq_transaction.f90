module ppa_wu05_perch21_freduq_tx_types
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, transaction_attempt_context_t, transaction_model_t, &
       trial_outcome_t, TX_MASS_MISSING_NONE
  use mod_fmr_macropore_reduction_continuation, only: macropore_reduction_continuation_t, &
       initialize_macropore_reduction_continuation, propose_macropore_reduction_escalation, &
       propose_macropore_reduction_acceptance
  implicit none
  private

  integer,parameter,public :: PERCH21_RETRY_REASON=1921

  type,extends(transaction_state_t),public :: perch21_state_t
    real(real64)::marker=42.0_real64
  contains
    procedure::clone=>clone_state
  end type perch21_state_t

  type,extends(transaction_attempt_context_t),public :: perch21_context_t
    type(macropore_reduction_continuation_t)::continuation
  end type perch21_context_t

  type,extends(transaction_model_t),public :: perch21_model_t
    type(macropore_reduction_continuation_t)::working
    integer::mode=0
    integer::calls=0
    integer::accepted_feedback_count=0
    real(real64)::dtmin=0.5_real64
    real(real64)::dtmax=1.0_real64
    real(real64)::durations(32)=0.0_real64
  contains
    procedure::advance=>advance_model
    procedure::storage=>storage_model
    procedure::temporal_error=>temporal_error_model
    procedure::storage_accounting_status=>storage_status
    procedure::attempt_context_required=>context_required
    procedure::capture_attempt_context=>capture_context
    procedure::restore_attempt_context=>restore_context
    procedure::apply_accepted_feedback=>accepted_feedback
  end type perch21_model_t

contains

  subroutine clone_state(self,copy)
    class(perch21_state_t),intent(in)::self
    class(transaction_state_t),allocatable,intent(out)::copy
    allocate(perch21_state_t::copy)
    select type(typed=>copy)
    type is(perch21_state_t)
      typed%marker=self%marker
    end select
  end subroutine clone_state

  subroutine advance_model(self,state,t0,t1,outcome)
    class(perch21_model_t),intent(inout)::self
    class(transaction_state_t),intent(inout)::state
    real(real64),intent(in)::t0,t1
    type(trial_outcome_t),intent(out)::outcome
    real(real64)::dt,retry_dt
    logical::available
    type(macropore_reduction_continuation_t)::candidate

    outcome=trial_outcome_t()
    dt=t1-t0
    self%calls=self%calls+1
    if(self%calls<=size(self%durations))self%durations(self%calls)=dt

    select type(typed=>state)
    type is(perch21_state_t)
      if(abs(typed%marker-42.0_real64)>1.0e-15_real64)error stop 'PERCH21 physical checkpoint changed'
    class default
      error stop 'PERCH21 state type'
    end select

    select case(self%mode)
    case(1)
      ! Exact source ordering:
      ! 1) ordinary retry from 1.0 to dtmin=0.5;
      ! 2) only at dtmin escalate FrReduQ and propose sqrt(dtmin*dtmax);
      ! 3) level-1 route succeeds.
      if(self%working%reduction_level==0)then
        if(dt>self%dtmin+1.0e-12_real64)then
          outcome%solver_ok=.false.
          return
        end if
        if(abs(dt-self%dtmin)<=1.0e-12_real64)then
          call propose_macropore_reduction_escalation(self%working,dt,self%dtmin,self%dtmax, &
               candidate,retry_dt,available)
          if(.not.available)error stop 'PERCH21 escalation unavailable'
          self%working=candidate
          outcome%solver_ok=.false.
          outcome%retry_duration_proposal_available=.true.
          outcome%retry_duration_proposal=retry_dt
          outcome%retry_duration_reason=PERCH21_RETRY_REASON
          return
        end if
      end if
      if(self%working%reduction_level/=1)then
        outcome%solver_ok=.false.
        return
      end if

    case(2)
      ! First full trial succeeds. First half trial deliberately mutates
      ! numerical continuation and fails. Transaction rollback must erase it.
      if(self%calls==2)then
        self%working%reduction_level=3
        outcome%solver_ok=.false.
        return
      end if
      if(self%calls>=3 .and. self%working%reduction_level/=0)then
        outcome%solver_ok=.false.
        return
      end if

    case(3)
      ! Every physically successful attempt injects a hard mass defect after
      ! mutating trial-local numerical continuation. No mutation may survive
      ! exhausted mass rejection.
      self%working%reduction_level=2
      outcome%solver_ok=.true.
      outcome%mass_in=1.0_real64
      outcome%mass_out=0.0_real64
      outcome%mass_accounting_complete=.true.
      outcome%missing_mass_contribution_mask=TX_MASS_MISSING_NONE
      return

    case default
      error stop 'PERCH21 invalid mode'
    end select

    outcome%solver_ok=.true.
    outcome%mass_in=0.0_real64
    outcome%mass_out=0.0_real64
    outcome%mass_accounting_complete=.true.
    outcome%missing_mass_contribution_mask=TX_MASS_MISSING_NONE
  end subroutine advance_model

  real(real64) function storage_model(self,state) result(value)
    class(perch21_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::state
    if(self%mode<0)error stop 'PERCH21 mode'
    select type(typed=>state)
    type is(perch21_state_t)
      value=0.0_real64*typed%marker
    class default
      value=huge(0.0_real64)
    end select
  end function storage_model

  real(real64) function temporal_error_model(self,full_state,half_state) result(value)
    class(perch21_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::full_state,half_state
    if(.not.same_type_as(full_state,half_state) .or. self%mode<0)error stop 'PERCH21 temporal'
    value=0.0_real64
  end function temporal_error_model

  subroutine storage_status(self,state,complete,missing_mask)
    class(perch21_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::state
    logical,intent(out)::complete
    integer(int64),intent(out)::missing_mask
    if(.not.same_type_as(state,state) .or. self%mode<0)error stop 'PERCH21 storage status'
    complete=.true.
    missing_mask=TX_MASS_MISSING_NONE
  end subroutine storage_status

  logical function context_required(self) result(required)
    class(perch21_model_t),intent(in)::self
    required=self%mode>0
  end function context_required

  subroutine capture_context(self,context)
    class(perch21_model_t),intent(inout)::self
    class(transaction_attempt_context_t),allocatable,intent(out)::context
    allocate(perch21_context_t::context)
    select type(typed=>context)
    type is(perch21_context_t)
      typed%continuation=self%working
    end select
  end subroutine capture_context

  subroutine restore_context(self,context)
    class(perch21_model_t),intent(inout)::self
    class(transaction_attempt_context_t),intent(in)::context
    select type(typed=>context)
    type is(perch21_context_t)
      self%working=typed%continuation
    class default
      error stop 'PERCH21 context type'
    end select
  end subroutine restore_context

  subroutine accepted_feedback(self,accepted_dt,ok)
    class(perch21_model_t),intent(inout)::self
    real(real64),intent(in)::accepted_dt
    logical,intent(out)::ok
    type(macropore_reduction_continuation_t)::candidate
    logical::recovered

    self%accepted_feedback_count=self%accepted_feedback_count+1
    call propose_macropore_reduction_acceptance(self%working,accepted_dt,candidate,recovered,ok)
    if(ok)self%working=candidate
  end subroutine accepted_feedback

end module ppa_wu05_perch21_freduq_tx_types

program test_ppa_wu05_perch21_freduq_transaction
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t,transaction_policy_t,transaction_result_t, &
       execute_reference_interval,TX_STATUS_ACCEPTED,TX_STATUS_RETRY_EXHAUSTED,TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_fmr_macropore_reduction_continuation, only: initialize_macropore_reduction_continuation
  use ppa_wu05_perch21_freduq_tx_types
  implicit none

  class(transaction_state_t),allocatable::committed
  type(perch21_model_t)::model
  type(transaction_policy_t)::policy
  type(transaction_result_t)::result
  real(real64)::expected_retry
  logical::ok

  policy%temporal_tolerance=1.0e-12_real64
  policy%mass_tolerance=1.0e-12_real64
  policy%retry_scale=0.5_real64
  policy%max_retries=4
  policy%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF

  allocate(perch21_state_t::committed)
  model=perch21_model_t(); model%mode=1
  call initialize_macropore_reduction_continuation(model%working,1.0_real64,ok)
  call require(ok,'source continuation initialize')
  call execute_reference_interval(model,committed,0.0_real64,1.0_real64,policy,result)

  expected_retry=sqrt(0.5_real64)
  call require(result%status==TX_STATUS_ACCEPTED,'source sequence accepted')
  call require(result%solver_rejections==2,'ordinary plus FrReduQ rejections')
  call require(result%model_retry_directives==1,'one FrReduQ retry directive')
  call require(abs(result%last_model_retry_duration-expected_retry)<1.0e-15_real64,'geometric retry duration')
  call require(abs(model%durations(1)-1.0_real64)<1.0e-15_real64,'first source dt')
  call require(abs(model%durations(2)-0.5_real64)<1.0e-15_real64,'ordinary reduced dt')
  call require(abs(model%durations(3)-expected_retry)<1.0e-15_real64,'FrReduQ reset dt')
  call require(model%accepted_feedback_count==1,'accepted recovery exactly once')
  call require(model%working%reduction_level==0,'larger-dt accepted recovery')
  call require(model%working%accepted_step_count==0,'recovery counter reset')
  call require(abs(model%working%recovery_dt-expected_retry)<1.0e-15_real64,'recovery dt updated')
  call require_committed(committed,42.0_real64,'source sequence committed isolation')

  ! Half-step failure may mutate numerical state, but rollback must restore it.
  deallocate(committed); allocate(perch21_state_t::committed)
  model=perch21_model_t(); model%mode=2
  call initialize_macropore_reduction_continuation(model%working,1.0_real64,ok)
  call execute_reference_interval(model,committed,0.0_real64,1.0_real64,policy,result)
  call require(result%status==TX_STATUS_ACCEPTED,'half failure recovered')
  call require(result%solver_rejections>=1,'half failure observed')
  call require(model%working%reduction_level==0,'half failure continuation isolated')
  call require(model%accepted_feedback_count==1,'half route accepted feedback once')
  call require_committed(committed,42.0_real64,'half failure committed isolation')

  ! Hard mass rejection cannot leak reduction memory even when retries exhaust.
  deallocate(committed); allocate(perch21_state_t::committed)
  model=perch21_model_t(); model%mode=3
  call initialize_macropore_reduction_continuation(model%working,1.0_real64,ok)
  policy%max_retries=2
  call execute_reference_interval(model,committed,0.0_real64,1.0_real64,policy,result)
  call require(result%status==TX_STATUS_RETRY_EXHAUSTED,'mass retries exhausted')
  call require(result%mass_rejections==3,'mass rejection count')
  call require(model%working%reduction_level==0,'mass rejected continuation isolated')
  call require(model%accepted_feedback_count==0,'mass rejected no accepted feedback')
  call require_committed(committed,42.0_real64,'mass rejection committed isolation')

  print '(a)', 'PPA_WU05_PERCH21_SOURCE_ORDERING=PASS'
  print '(a)', 'PPA_WU05_PERCH21_GEOMETRIC_RETRY=PASS'
  print '(a)', 'PPA_WU05_PERCH21_ACCEPTED_RECOVERY=PASS'
  print '(a)', 'PPA_WU05_PERCH21_HALF_SPECULATIVE_ISOLATION=PASS'
  print '(a)', 'PPA_WU05_PERCH21_MASS_SPECULATIVE_ISOLATION=PASS'
  print '(a)', 'PPA_WU05_PERCH21_FREDUQ_TRANSACTION_GATE=PASS'

contains
  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(a,1x,a)') 'PPA_WU05_PERCH21_FREDUQ_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

  subroutine require_committed(state,expected,label)
    class(transaction_state_t),allocatable,intent(in)::state
    real(real64),intent(in)::expected
    character(len=*),intent(in)::label
    select type(typed=>state)
    type is(perch21_state_t)
      call require(abs(typed%marker-expected)<1.0e-15_real64,label)
    class default
      call require(.false.,label)
    end select
  end subroutine require_committed
end program test_ppa_wu05_perch21_freduq_transaction
