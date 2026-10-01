module ppa_wu05_perch20_test_types
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, transaction_attempt_context_t, &
       transaction_model_t, trial_outcome_t, TX_MASS_MISSING_NONE
  implicit none
  private

  integer, parameter, public :: TEST_RETRY_REASON = 77

  type, extends(transaction_state_t), public :: test_state_t
    real(real64) :: marker = 42.0_real64
  contains
    procedure :: clone => clone_test_state
  end type test_state_t

  type, extends(transaction_attempt_context_t), public :: test_context_t
    integer :: reduction_level = 0
  end type test_context_t

  type, extends(transaction_model_t), public :: test_model_t
    integer :: mode = 0
    integer :: working_level = 0
    integer :: calls = 0
    real(real64) :: durations(32) = 0.0_real64
  contains
    procedure :: advance => test_advance
    procedure :: storage => test_storage
    procedure :: temporal_error => test_temporal_error
    procedure :: storage_accounting_status => test_storage_status
    procedure :: attempt_context_required => test_context_required
    procedure :: capture_attempt_context => test_capture_context
    procedure :: restore_attempt_context => test_restore_context
  end type test_model_t

contains

  subroutine clone_test_state(self,copy)
    class(test_state_t),intent(in)::self
    class(transaction_state_t),allocatable,intent(out)::copy
    allocate(test_state_t::copy)
    select type(typed=>copy)
    type is(test_state_t)
      typed%marker=self%marker
    end select
  end subroutine clone_test_state

  subroutine test_advance(self,state,t0,t1,outcome)
    class(test_model_t),intent(inout)::self
    class(transaction_state_t),intent(inout)::state
    real(real64),intent(in)::t0,t1
    type(trial_outcome_t),intent(out)::outcome
    real(real64)::dt

    outcome=trial_outcome_t()
    dt=t1-t0
    self%calls=self%calls+1
    if(self%calls<=size(self%durations))self%durations(self%calls)=dt

    select type(typed=>state)
    type is(test_state_t)
      if(abs(typed%marker-42.0_real64)>1.0e-15_real64)error stop 'PERCH20 physical checkpoint changed'
    class default
      error stop 'PERCH20 unexpected state type'
    end select

    select case(self%mode)
    case(1)
      ! Legacy/no-directive path: first 1.0-d attempt fails; 0.5 succeeds.
      if(dt>0.5000000001_real64)then
        outcome%solver_ok=.false.
        return
      end if
    case(2)
      ! 1.0 fails normally -> generic retry_scale produces 0.5.
      if(dt>0.7500000001_real64 .and. self%working_level==0)then
        outcome%solver_ok=.false.
        return
      end if
      ! At 0.5 the model changes only trial-local context and requests an
      ! upward retry to 0.8. The next attempt succeeds only if that context
      ! survived transaction rollback.
      if(abs(dt-0.5_real64)<1.0e-12_real64 .and. self%working_level==0)then
        self%working_level=1
        outcome%solver_ok=.false.
        outcome%retry_duration_proposal_available=.true.
        outcome%retry_duration_proposal=0.8_real64
        outcome%retry_duration_reason=TEST_RETRY_REASON
        return
      end if
      if(self%working_level/=1)then
        outcome%solver_ok=.false.
        return
      end if
    case(3)
      outcome%solver_ok=.false.
      outcome%retry_duration_proposal_available=.true.
      outcome%retry_duration_proposal=2.0_real64
      outcome%retry_duration_reason=TEST_RETRY_REASON
      return
    case(4)
      ! Existing attempt-context rollback path, no model retry directive.
      if(dt>0.5000000001_real64)then
        self%working_level=9
        outcome%solver_ok=.false.
        return
      end if
      if(self%working_level/=0)then
        outcome%solver_ok=.false.
        return
      end if
    case default
      error stop 'PERCH20 invalid test mode'
    end select

    outcome%solver_ok=.true.
    outcome%mass_in=0.0_real64
    outcome%mass_out=0.0_real64
    outcome%mass_accounting_complete=.true.
    outcome%missing_mass_contribution_mask=TX_MASS_MISSING_NONE
  end subroutine test_advance

  real(real64) function test_storage(self,state) result(value)
    class(test_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::state
    if(self%mode<0)error stop 'PERCH20 impossible model mode'
    select type(typed=>state)
    type is(test_state_t)
      value=0.0_real64*typed%marker
    class default
      value=huge(0.0_real64)
    end select
  end function test_storage

  real(real64) function test_temporal_error(self,full_state,half_state) result(value)
    class(test_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::full_state,half_state
    if(self%mode<0 .or. .not.same_type_as(full_state,half_state))error stop 'PERCH20 temporal type'
    value=0.0_real64
  end function test_temporal_error

  subroutine test_storage_status(self,state,complete,missing_mask)
    class(test_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::state
    logical,intent(out)::complete
    integer(int64),intent(out)::missing_mask
    if(self%mode<0 .or. .not.same_type_as(state,state))error stop 'PERCH20 storage status'
    complete=.true.
    missing_mask=TX_MASS_MISSING_NONE
  end subroutine test_storage_status

  logical function test_context_required(self) result(required)
    class(test_model_t),intent(in)::self
    required=self%mode==2 .or. self%mode==4
  end function test_context_required

  subroutine test_capture_context(self,context)
    class(test_model_t),intent(inout)::self
    class(transaction_attempt_context_t),allocatable,intent(out)::context
    allocate(test_context_t::context)
    select type(typed=>context)
    type is(test_context_t)
      typed%reduction_level=self%working_level
    end select
  end subroutine test_capture_context

  subroutine test_restore_context(self,context)
    class(test_model_t),intent(inout)::self
    class(transaction_attempt_context_t),intent(in)::context
    select type(typed=>context)
    type is(test_context_t)
      self%working_level=typed%reduction_level
    class default
      error stop 'PERCH20 context type'
    end select
  end subroutine test_restore_context

end module ppa_wu05_perch20_test_types

program test_ppa_wu05_perch20_model_retry_directive
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, transaction_policy_t, transaction_result_t, &
       execute_reference_interval, TX_STATUS_ACCEPTED, TX_STATUS_INVALID_MODEL_RETRY_DIRECTIVE
  use ppa_wu05_perch20_test_types
  implicit none

  class(transaction_state_t),allocatable::committed
  type(test_model_t)::model
  type(transaction_policy_t)::policy
  type(transaction_result_t)::result

  policy%temporal_tolerance=1.0e-12_real64
  policy%mass_tolerance=1.0e-12_real64
  policy%retry_scale=0.5_real64
  policy%max_retries=4

  allocate(test_state_t::committed)
  model%mode=1
  call execute_reference_interval(model,committed,0.0_real64,1.0_real64,policy,result)
  call require(result%status==TX_STATUS_ACCEPTED,'legacy retry accepted')
  call require(result%model_retry_directives==0,'legacy no model directives')
  call require(abs(result%accepted_dt-0.5_real64)<1.0e-15_real64,'legacy accepted dt')
  call require(model%calls>=4,'legacy full half trajectory')
  call require(abs(model%durations(1)-1.0_real64)<1.0e-15_real64,'legacy first duration')
  call require(abs(model%durations(2)-0.5_real64)<1.0e-15_real64,'legacy scaled retry duration')
  call require_committed_marker(committed,42.0_real64,'legacy committed marker')

  deallocate(committed)
  allocate(test_state_t::committed)
  model=test_model_t()
  model%mode=2
  call execute_reference_interval(model,committed,0.0_real64,1.0_real64,policy,result)
  call require(result%status==TX_STATUS_ACCEPTED,'model retry accepted')
  call require(result%model_retry_directives==1,'one model retry directive')
  call require(result%last_model_retry_reason==TEST_RETRY_REASON,'model retry reason')
  call require(abs(result%last_model_retry_duration-0.8_real64)<1.0e-15_real64,'model retry duration')
  call require(abs(result%accepted_dt-0.8_real64)<1.0e-15_real64,'accepted proposed duration')
  call require(model%calls>=5,'model retry full half trajectory')
  call require(abs(model%durations(1)-1.0_real64)<1.0e-15_real64,'model first duration')
  call require(abs(model%durations(2)-0.5_real64)<1.0e-15_real64,'model fixed fallback duration')
  call require(abs(model%durations(3)-0.8_real64)<1.0e-15_real64,'model upward proposed duration')
  call require(model%working_level==1,'model retry context carried')
  call require_committed_marker(committed,42.0_real64,'model committed marker')

  deallocate(committed)
  allocate(test_state_t::committed)
  model=test_model_t()
  model%mode=4
  call execute_reference_interval(model,committed,0.0_real64,1.0_real64,policy,result)
  call require(result%status==TX_STATUS_ACCEPTED,'legacy context rollback accepted')
  call require(result%model_retry_directives==0,'legacy context no model directive')
  call require(abs(result%accepted_dt-0.5_real64)<1.0e-15_real64,'legacy context fixed retry dt')
  call require(model%working_level==0,'legacy failed context restored')
  call require_committed_marker(committed,42.0_real64,'legacy context committed marker')

  deallocate(committed)
  allocate(test_state_t::committed)
  model=test_model_t()
  model%mode=3
  call execute_reference_interval(model,committed,0.0_real64,1.0_real64,policy,result)
  call require(result%status==TX_STATUS_INVALID_MODEL_RETRY_DIRECTIVE,'invalid directive status')
  call require(result%invalid_model_retry_directives==1,'invalid directive counted')
  call require(result%retries==0,'invalid directive no fallback retry')
  call require_committed_marker(committed,42.0_real64,'invalid committed marker')

  print '(a)', 'PPA_WU05_PERCH20_LEGACY_RETRY_PRESERVATION=PASS'
  print '(a)', 'PPA_WU05_PERCH20_UPWARD_MODEL_RETRY=PASS'
  print '(a)', 'PPA_WU05_PERCH20_ATTEMPT_CONTEXT_CARRY=PASS'
  print '(a)', 'PPA_WU05_PERCH20_LEGACY_CONTEXT_ROLLBACK=PASS'
  print '(a)', 'PPA_WU05_PERCH20_INVALID_DIRECTIVE_FAIL_CLOSED=PASS'
  print '(a)', 'PPA_WU05_PERCH20_COMMITTED_ISOLATION=PASS'
  print '(a)', 'PPA_WU05_PERCH20_GATE=PASS'

contains
  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(a,1x,a)') 'PPA_WU05_PERCH20_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

  subroutine require_committed_marker(state,expected,label)
    class(transaction_state_t),allocatable,intent(in)::state
    real(real64),intent(in)::expected
    character(len=*),intent(in)::label
    select type(typed=>state)
    type is(test_state_t)
      call require(abs(typed%marker-expected)<1.0e-15_real64,label)
    class default
      call require(.false.,label)
    end select
  end subroutine require_committed_marker
end program test_ppa_wu05_perch20_model_retry_directive
