module scratch_lifecycle_fixture
 use iso_fortran_env,only:real64
 use mod_transaction_reference
 use mod_low_air_policy_oracle
 implicit none
 integer :: live_contexts=0
 type,extends(transaction_attempt_context_t)::tracked_context_t
 contains
  final::destroy_context
 end type
 type,extends(fci04_model_t)::tracked_model_t
  integer::opened=0,closed=0
  logical::fail_solver=.false.,certificate=.true.
 contains
  procedure::begin_scratch_scope=>open_scope
  procedure::end_scratch_scope=>close_scope
  procedure::capture_attempt_context=>capture
  procedure::advance=>advance
 end type
contains
 subroutine destroy_context(context)
  type(tracked_context_t),intent(inout)::context
  if(.not.same_type_as(context,context))error stop 'context type'
  live_contexts=live_contexts-1
 end subroutine
 subroutine capture(self,context)
  class(tracked_model_t),intent(inout)::self
  class(transaction_attempt_context_t),allocatable,intent(out)::context
  if(self%opened/=self%closed+1)error stop 'capture outside scope'
  allocate(tracked_context_t::context)
  live_contexts=live_contexts+1
 end subroutine
 subroutine open_scope(self,scope)
  class(tracked_model_t),intent(inout)::self
  type(transaction_scratch_scope_t),intent(out)::scope
  if(live_contexts/=0)error stop 'leaked prior context'
  self%opened=self%opened+1
  scope%token=[int(self%opened,8),0_8]
 end subroutine
 subroutine close_scope(self,scope)
  class(tracked_model_t),intent(inout)::self
  type(transaction_scratch_scope_t),intent(in)::scope
  if(live_contexts/=0)error stop 'collection before context destruction'
  if(scope%token(1)/=self%opened)error stop 'wrong scope'
  self%closed=self%closed+1
 end subroutine
 subroutine advance(self,state,t0,t1,outcome)
  class(tracked_model_t),intent(inout)::self
  class(transaction_state_t),intent(inout)::state
  real(real64),intent(in)::t0,t1
  type(trial_outcome_t),intent(out)::outcome
  call self%fci04_model_t%advance(state,t0,t1,outcome)
  if(self%fail_solver)outcome%solver_ok=.false.
  outcome%temporal_certificate_available=self%certificate
  outcome%temporal_indicator=0d0
 end subroutine
end module

program test_scratch_lifecycle
 use scratch_lifecycle_fixture
 implicit none
 type(tracked_model_t)::model
 class(transaction_state_t),allocatable::state
 type(transaction_policy_t)::policy
 type(transaction_result_t)::result
 policy%temporal_tolerance=1d0
 policy%max_retries=2
 call initial()
 call execute_reference_interval(model,state,0d0,.1d0,policy,result)
 if(result%status/=TX_STATUS_ACCEPTED)error stop 'success route'
 call execute_reference_interval(model,state,0d0,0d0,policy,result)
 if(result%status/=TX_STATUS_INVALID_INTERVAL)error stop 'invalid route'
 call initial();model%inject_mass_defect=.true.;model%mass_defect=1d-3
 call execute_reference_interval(model,state,0d0,.1d0,policy,result)
 if(result%status/=TX_STATUS_RETRY_EXHAUSTED.or.result%mass_rejections==0)error stop 'mass route'
 call initial();model%inject_mass_defect=.false.;model%fail_solver=.true.
 call execute_reference_interval(model,state,0d0,.1d0,policy,result)
 if(result%status/=TX_STATUS_RETRY_EXHAUSTED.or.result%solver_rejections==0)error stop 'solver route'
 call initial();model%fail_solver=.false.;policy%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
 call execute_reference_interval(model,state,0d0,.1d0,policy,result)
 if(result%status/=TX_STATUS_ACCEPTED)error stop 'certificate success'
 call initial();model%certificate=.false.
 call execute_reference_interval(model,state,0d0,.1d0,policy,result)
 if(result%status/=TX_STATUS_RETRY_EXHAUSTED.or.result%temporal_certificate_unavailable_rejections==0)error stop 'certificate failure'
 call initial();policy%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF;policy%temporal_tolerance=0d0
 call execute_reference_interval(model,state,0d0,.1d0,policy,result)
 if(result%status/=TX_STATUS_RETRY_EXHAUSTED.or.result%temporal_rejections==0)error stop 'temporal route'
 if(model%opened/=7.or.model%closed/=7.or.live_contexts/=0)error stop 'unclosed scratch scope'
 print '(A)','SCRATCH_SCOPE_ALL_RETURNS_AFTER_CONTEXT_DESTRUCTION=PASS'
contains
 subroutine initial()
  if(allocated(state))deallocate(state)
  allocate(fci04_state_t::state)
  select type(s=>state)
  type is(fci04_state_t)
   s%water=1d0
  end select
 end subroutine
end program
