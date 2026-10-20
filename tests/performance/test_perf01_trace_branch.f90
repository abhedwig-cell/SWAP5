program test_perf01_trace_branch
  use iso_fortran_env,only:int64
  use mod_transaction_reference,only:transaction_attempt_context_t
  use mod_fmr_serialized_reference_backend,only:fmr_serialized_reference_model_t,fmr_serialized_attempt_context_t
  implicit none
  type(fmr_serialized_reference_model_t)::model
  class(transaction_attempt_context_t),allocatable::a,b,wrong
  character(16)::arg
  model%accepted_water_flux_trace_enabled=.true.
  model%trace_generation=1_int64
  allocate(model%trace_arena(8))
  call append_record(1,0,1)
  call model%capture_attempt_context(a)
  call append_record(2,1,2)
  call model%capture_attempt_context(b)
  call model%restore_attempt_context(a)
  call append_record(3,1,3)
  call model%restore_attempt_context(b)
  if(model%trace_tail/=2.or.model%trace_count/=2)error stop 'lost alternate branch'
  if(model%trace_arena(2)%payload%t1/=2d0.or.model%trace_arena(3)%payload%t1/=3d0) &
    error stop 'overwritten immutable payload'
  call model%restore_attempt_context(a)
  if(model%trace_tail/=1.or.model%trace_count/=1)error stop 'prefix restore'
  call model%restore_attempt_context(b)
  if(model%trace_arena(model%trace_tail)%predecessor/=1)error stop 'branch predecessor'
  call get_command_argument(1,arg)
  if(arg=='stale')then
    model%trace_generation=2_int64
    call model%restore_attempt_context(a)
    error stop 'stale context accepted'
  end if
  if(arg=='invalid')then
    select type(x=>a)
    type is(fmr_serialized_attempt_context_t)
      x%trace_tail=9
    end select
    call model%restore_attempt_context(a)
    error stop 'invalid context accepted'
  end if
  allocate(transaction_attempt_context_t::wrong)
  call model%restore_attempt_context(wrong)
  if(.not.model%accepted_water_flux_trace_failed.or.model%trace_tail/=0.or.model%trace_count/=0) &
    error stop 'foreign context did not fail closed'
  print '(A)','PERF01_TRACE_IMMUTABLE_BRANCH_RESTORE=PASS'
contains
  subroutine append_record(index,predecessor,endpoint)
    integer,intent(in)::index,predecessor,endpoint
    allocate(model%trace_arena(index)%payload)
    model%trace_arena(index)%predecessor=predecessor
    model%trace_arena(index)%payload%t1=real(endpoint,8)
    model%trace_used=index;model%trace_tail=index;model%trace_count=model%trace_count+1
  end subroutine
end program
