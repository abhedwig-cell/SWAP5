program test_trace_scope
 use iso_fortran_env,only:int64
 use mod_transaction_reference,only:transaction_attempt_context_t,transaction_scratch_scope_t
 use mod_fmr_serialized_reference_backend,only:fmr_serialized_reference_model_t
 implicit none
 type(fmr_serialized_reference_model_t)::model
 type(transaction_scratch_scope_t)::scope,inner
 class(transaction_attempt_context_t),allocatable::a,b,temporary
 character(16)::mode
 integer::i
 model%accepted_water_flux_trace_enabled=.true.
 model%trace_generation=11_int64
 allocate(model%trace_arena(32))
 call append(1,0,1)
 call model%capture_attempt_context(a)
 call append(2,1,2)
 call model%capture_attempt_context(b)
 call model%restore_attempt_context(a)
 call model%begin_scratch_scope(scope)
 call append(3,1,99)
 call model%capture_attempt_context(temporary)
 call model%restore_attempt_context(a)
 call append(4,1,4)
 call append(5,4,5)
 deallocate(temporary)
 call get_command_argument(1,mode)
 if(mode=='generation')scope%token(1)=12_int64
 if(mode=='watermark')scope%token(2)=100_int64
 call model%end_scratch_scope(scope)
 if(model%trace_used/=4.or.model%trace_tail/=4.or.model%trace_count/=3)error stop 'suffix size'
 if(model%trace_arena(3)%payload%t1/=4d0.or.model%trace_arena(4)%payload%t1/=5d0)error stop 'payload not moved exactly'
 if(model%trace_arena(3)%predecessor/=1.or.model%trace_arena(4)%predecessor/=3)error stop 'suffix remap'
 do i=5,32
  if(allocated(model%trace_arena(i)%payload))error stop 'abandoned payload retained'
 enddo
 call model%restore_attempt_context(b)
 if(model%trace_tail/=2.or.model%trace_arena(2)%payload%t1/=2d0)error stop 'pinned sibling lost'
 call model%restore_attempt_context(a)
 call model%begin_scratch_scope(scope)
 call append(5,1,99)
 call model%restore_attempt_context(a)
 call model%end_scratch_scope(scope)
 if(model%trace_used/=4.or.model%trace_tail/=1.or.model%trace_count/=1)error stop 'failed scope rollback'
 call model%begin_scratch_scope(scope)
 call append(5,1,5)
 call model%begin_scratch_scope(inner)
 call append(6,5,99)
 model%trace_tail=5;model%trace_count=2
 call append(7,5,7)
 call model%end_scratch_scope(inner)
 if(model%trace_used/=6.or.model%trace_arena(6)%predecessor/=5)error stop 'nested inner'
 call model%end_scratch_scope(scope)
 if(model%trace_used/=6.or.model%trace_tail/=6.or.model%trace_count/=3)error stop 'nested outer'
 call model%restore_attempt_context(b)
 if(model%trace_arena(2)%payload%t1/=2d0)error stop 'nested pinned sibling'
 model%accepted_water_flux_trace_enabled=.false.
 call model%begin_scratch_scope(scope)
 call model%end_scratch_scope(scope)
 if(model%trace_used/=6)error stop 'inactive scope'
 print '(A)','TRACE_SCOPE_RECLAIM_PINNED_BRANCH_NESTED_ROLLBACK=PASS'
contains
 subroutine append(index,predecessor,endpoint)
  integer,intent(in)::index,predecessor,endpoint
  allocate(model%trace_arena(index)%payload)
  model%trace_arena(index)%predecessor=predecessor
  model%trace_arena(index)%payload%t1=real(endpoint,8)
  model%trace_used=index;model%trace_tail=index;model%trace_count=model%trace_count+1
 end subroutine
end program
