module ppa_wu05_perch21_test_types
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, transaction_attempt_context_t, transaction_model_t, &
       trial_outcome_t, TX_MASS_MISSING_NONE
  implicit none
  private

  integer, parameter, public :: TEST_RETRY_REASON=91

  type, extends(transaction_state_t), public :: test_state_t
    real(real64) :: marker=42.0_real64
  contains
    procedure :: clone => clone_state
  end type test_state_t

  type, extends(transaction_attempt_context_t), public :: test_context_t
    integer :: numerical_level=0
  end type test_context_t

  type, extends(transaction_model_t), public :: test_model_t
    integer :: mode=0
    integer :: calls=0
    integer :: numerical_level=0
    integer :: accepted_feedback_count=0
    integer :: accepted_feedback_failures=0
    real(real64) :: last_accepted_dt=0.0_real64
    real(real64) :: durations(64)=0.0_real64
  contains
    procedure :: advance => test_advance
    procedure :: storage => test_storage
    procedure :: temporal_error => test_temporal_error
    procedure :: storage_accounting_status => test_storage_status
    procedure :: attempt_context_required => test_context_required
    procedure :: capture_attempt_context => test_capture_context
    procedure :: restore_attempt_context => test_restore_context
    procedure :: apply_accepted_feedback => test_accepted_feedback
  end type test_model_t

contains

  subroutine clone_state(self,copy)
    class(test_state_t),intent(in)::self
    class(transaction_state_t),allocatable,intent(out)::copy
    allocate(test_state_t::copy)
    select type(typed=>copy)
    type is(test_state_t)
      typed%marker=self%marker
    end select
  end subroutine clone_state

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
      if(abs(typed%marker-42.0_real64)>1.0e-15_real64)error stop 'PERCH21 physical checkpoint changed'
    class default
      error stop 'PERCH21 unexpected state'
    end select

    select case(self%mode)
    case(1)
      if(dt>0.5000000001_real64)then
        outcome%solver_ok=.false.
        return
      end if
    case(2)
      if(dt>0.7500000001_real64 .and. self%numerical_level==0)then
        outcome%solver_ok=.false.
        return
      end if
      if(abs(dt-0.5_real64)<1.0e-12_real64 .and. self%numerical_level==0)then
        self%numerical_level=1
        outcome%solver_ok=.false.
        outcome%retry_duration_proposal_available=.true.
        outcome%retry_duration_proposal=0.8_real64
        outcome%retry_duration_reason=TEST_RETRY_REASON
        return
      end if
      if(self%numerical_level/=1)then
        outcome%solver_ok=.false.
        return
      end if
    case(3)
      ! First full route is mass-invalid; retry route is clean.
      outcome%solver_ok=.true.
      outcome%mass_accounting_complete=.true.
      outcome%missing_mass_contribution_mask=TX_MASS_MISSING_NONE
      if(dt>0.7500000001_real64)then
        outcome%mass_in=1.0_real64
        outcome%mass_out=0.0_real64
        return
      end if
    case(4)
      ! Model-certificate temporal reject at dt=1, then accept at dt=0.5.
      outcome%solver_ok=.true.
      outcome%mass_accounting_complete=.true.
      outcome%missing_mass_contribution_mask=TX_MASS_MISSING_NONE
      outcome%temporal_certificate_available=.true.
      outcome%temporal_indicator=merge(2.0_real64,0.0_real64,dt>0.7500000001_real64)
      return
    case(5)
      outcome%solver_ok=.true.
      outcome%mass_accounting_complete=.true.
      outcome%missing_mass_contribution_mask=TX_MASS_MISSING_NONE
    case default
      error stop 'PERCH21 invalid mode'
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
    if(self%mode<0)error stop 'PERCH21 impossible mode'
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
    if(.not.same_type_as(full_state,half_state))error stop 'PERCH21 temporal state type'
    value=0.0_real64
    if(self%mode<0)value=huge(0.0_real64)
  end function test_temporal_error

  subroutine test_storage_status(self,state,complete,missing_mask)
    class(test_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::state
    logical,intent(out)::complete
    integer(int64),intent(out)::missing_mask
    if(self%mode<0 .or. .not.same_type_as(state,state))error stop 'PERCH21 storage status'
    complete=.true.
    missing_mask=TX_MASS_MISSING_NONE
  end subroutine test_storage_status

  logical function test_context_required(self) result(required)
    class(test_model_t),intent(in)::self
    required=self%mode==2
  end function test_context_required

  subroutine test_capture_context(self,context)
    class(test_model_t),intent(inout)::self
    class(transaction_attempt_context_t),allocatable,intent(out)::context
    allocate(test_context_t::context)
    select type(typed=>context)
    type is(test_context_t)
      typed%numerical_level=self%numerical_level
    end select
  end subroutine test_capture_context

  subroutine test_restore_context(self,context)
    class(test_model_t),intent(inout)::self
    class(transaction_attempt_context_t),intent(in)::context
    select type(typed=>context)
    type is(test_context_t)
      self%numerical_level=typed%numerical_level
    class default
      error stop 'PERCH21 context type'
    end select
  end subroutine test_restore_context

  subroutine test_accepted_feedback(self,accepted_dt,ok)
    class(test_model_t),intent(inout)::self
    real(real64),intent(in)::accepted_dt
    logical,intent(out)::ok
    self%accepted_feedback_count=self%accepted_feedback_count+1
    self%last_accepted_dt=accepted_dt
    if(self%mode==5)then
      self%accepted_feedback_failures=self%accepted_feedback_failures+1
      ok=.false.
      return
    end if
    self%numerical_level=self%numerical_level+10
    ok=.true.
  end subroutine test_accepted_feedback

end module ppa_wu05_perch21_test_types

program test_ppa_wu05_perch21_transaction_lifecycle
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t,transaction_policy_t,transaction_result_t, &
       execute_reference_interval,TX_STATUS_ACCEPTED,TX_STATUS_ACCEPTED_FEEDBACK_FAILED, &
       TX_TEMPORAL_EXTERNAL_FULL_HALF,TX_TEMPORAL_MODEL_CERTIFICATE
  use ppa_wu05_perch21_test_types
  implicit none

  class(transaction_state_t),allocatable::committed
  type(test_model_t)::model
  type(transaction_policy_t)::policy
  type(transaction_result_t)::result

  policy%temporal_tolerance=1.0e-12_real64
  policy%mass_tolerance=1.0e-12_real64
  policy%retry_scale=0.5_real64
  policy%max_retries=4
  policy%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF

  ! G1: ordinary retry remains fixed-scale when no directive exists.
  allocate(test_state_t::committed)
  model=test_model_t(); model%mode=1
  call execute_reference_interval(model,committed,0.0_real64,1.0_real64,policy,result)
  call require(result%status==TX_STATUS_ACCEPTED,'legacy accepted')
  call require(result%model_retry_directives==0,'legacy no directive')
  call require(abs(result%accepted_dt-0.5_real64)<1.0e-15_real64,'legacy retry dt')
  call require(result%accepted_feedback_calls==1,'legacy accepted feedback once')
  call require(model%accepted_feedback_count==1,'legacy model feedback once')
  call require_committed(committed,42.0_real64,'legacy committed')

  ! G2/G3: post-failure context survives only through explicit model directive.
  deallocate(committed); allocate(test_state_t::committed)
  model=test_model_t(); model%mode=2
  call execute_reference_interval(model,committed,0.0_real64,1.0_real64,policy,result)
  call require(result%status==TX_STATUS_ACCEPTED,'directive accepted')
  call require(result%model_retry_directives==1,'one directive')
  call require(abs(result%last_model_retry_duration-0.8_real64)<1.0e-15_real64,'directive duration')
  call require(abs(result%accepted_dt-0.8_real64)<1.0e-15_real64,'accepted proposed dt')
  call require(model%numerical_level==11,'directive context plus accepted feedback')
  call require(result%accepted_feedback_calls==1,'directive accepted feedback once')
  call require_committed(committed,42.0_real64,'directive committed')

  ! G4: mass rejection never triggers accepted feedback.
  deallocate(committed); allocate(test_state_t::committed)
  model=test_model_t(); model%mode=3
  call execute_reference_interval(model,committed,0.0_real64,1.0_real64,policy,result)
  call require(result%status==TX_STATUS_ACCEPTED,'mass retry accepted')
  call require(result%mass_rejections>=1,'mass rejection observed')
  call require(model%accepted_feedback_count==1,'mass rejected route no accepted feedback leak')
  call require(result%accepted_feedback_calls==1,'mass accepted feedback once')
  call require_committed(committed,42.0_real64,'mass committed')

  ! G4/G3: model-certificate temporal rejection also cannot leak accepted feedback.
  deallocate(committed); allocate(test_state_t::committed)
  model=test_model_t(); model%mode=4
  policy%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
  call execute_reference_interval(model,committed,0.0_real64,1.0_real64,policy,result)
  call require(result%status==TX_STATUS_ACCEPTED,'certificate retry accepted')
  call require(result%temporal_rejections>=1,'certificate temporal rejection')
  call require(abs(result%accepted_dt-0.5_real64)<1.0e-15_real64,'certificate scaled retry')
  call require(model%accepted_feedback_count==1,'certificate accepted feedback once')
  call require(result%accepted_feedback_calls==1,'certificate result feedback once')
  call require_committed(committed,42.0_real64,'certificate committed')

  ! Accepted feedback failure must fail closed and not publish physical state.
  deallocate(committed); allocate(test_state_t::committed)
  model=test_model_t(); model%mode=5
  policy%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
  call execute_reference_interval(model,committed,0.0_real64,1.0_real64,policy,result)
  call require(result%status==TX_STATUS_ACCEPTED_FEEDBACK_FAILED,'feedback failure status')
  call require(result%accepted_feedback_failures==1,'feedback failure counted')
  call require(model%accepted_feedback_count==1,'feedback attempted once')
  call require_committed(committed,42.0_real64,'feedback failure committed isolation')

  print '(a)', 'PPA_WU05_PERCH21_LEGACY_RETRY=PASS'
  print '(a)', 'PPA_WU05_PERCH21_MODEL_RETRY_CONTEXT=PASS'
  print '(a)', 'PPA_WU05_PERCH21_MASS_REJECTION_ISOLATION=PASS'
  print '(a)', 'PPA_WU05_PERCH21_TEMPORAL_REJECTION_ISOLATION=PASS'
  print '(a)', 'PPA_WU05_PERCH21_ACCEPTED_FEEDBACK=PASS'
  print '(a)', 'PPA_WU05_PERCH21_FEEDBACK_FAIL_CLOSED=PASS'
  print '(a)', 'PPA_WU05_PERCH21_TRANSACTION_LIFECYCLE_GATE=PASS'

contains
  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(a,1x,a)') 'PPA_WU05_PERCH21_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

  subroutine require_committed(state,expected,label)
    class(transaction_state_t),allocatable,intent(in)::state
    real(real64),intent(in)::expected
    character(len=*),intent(in)::label
    select type(typed=>state)
    type is(test_state_t)
      call require(abs(typed%marker-expected)<1.0e-15_real64,label)
    class default
      call require(.false.,label)
    end select
  end subroutine require_committed
end program test_ppa_wu05_perch21_transaction_lifecycle
