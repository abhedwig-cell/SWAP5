program test_scope_payload
 use iso_fortran_env,only:int64,real64
 use mod_transaction_reference,only:transaction_scratch_scope_t
 use mod_fmr_serialized_reference_backend,only:fmr_serialized_reference_model_t,fmr_water_flux_substep_trace_t
 implicit none
 type(fmr_serialized_reference_model_t)::model
 type(fmr_water_flux_substep_trace_t)::expected
 type(transaction_scratch_scope_t)::scope
 integer::j,k
 model%accepted_water_flux_trace_enabled=.true.
 model%trace_generation=7_int64
 allocate(model%trace_arena(64))
 do j=1,20
  call model%begin_scratch_scope(scope)
  k=model%trace_used
  call append(k+1,model%trace_tail,99d0)
  model%trace_tail=int(scope%token(2))
  model%trace_count=2*(j-1)
  call append(k+2,model%trace_tail,real(j,real64))
  call append(k+3,model%trace_tail,real(j,real64)+.5d0)
  expected=model%trace_arena(k+3)%payload
  call model%end_scratch_scope(scope)
  if(model%trace_used/=2*j.or.model%trace_count/=2*j)error stop 'retained extent'
  associate(p=>model%trace_arena(model%trace_tail)%payload)
   if(any(p%water_start/=expected%water_start))error stop 'water allocation changed'
   if(any(p%drainage_sink_by_level/=expected%drainage_sink_by_level))error stop 'rank2 allocation changed'
   if(any(p%salt_receipt%root_solute_uptake_mg_cm2/=expected%salt_receipt%root_solute_uptake_mg_cm2))error stop 'salt receipt changed'
   if(.not.allocated(p%macropore_water_start))error stop 'empty allocation lost'
   if(size(p%macropore_water_start)/=0)error stop 'empty allocation reshaped'
  end associate
  if(allocated(model%trace_arena(model%trace_used+1)%payload))error stop 'dead deep payload retained'
 enddo
 print '(A)','TRACE_SCOPE_DEEP_SALT_RANK2_EMPTY_PAYLOAD_EXACT=PASS'
contains
 subroutine append(index,previous,value)
  integer,intent(in)::index,previous
  real(real64),intent(in)::value
  integer::i
  allocate(model%trace_arena(index)%payload)
  associate(p=>model%trace_arena(index)%payload)
   p%t1=value
   p%water_start=[(value+real(i,real64)*.125d0,i=1,4)]
   p%drainage_sink_by_level=reshape([(value+real(i,real64)*.25d0,i=1,12)],[3,4])
   allocate(p%macropore_water_start(0,4))
   allocate(p%salt_receipt)
   p%salt_receipt%root_solute_uptake_mg_cm2=[(value+real(i,real64)*.5d0,i=1,4)]
  end associate
  model%trace_arena(index)%predecessor=previous
  model%trace_used=index;model%trace_tail=index;model%trace_count=model%trace_count+1
 end subroutine
end program
