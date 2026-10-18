program leaf_trace
 use iso_fortran_env,only:real64,int64
 use mod_b111_persistent_pond
 use mod_b111_pond_solute_exchange
 implicit none
 type(persistent_pond_state_t)::current(2),next
 type(persistent_pond_receipt_t)::receipt
 type(b111_pond_solute_result_t)::mix
 type(pond_step_t)::step
 real(real64)::before(2),ctop(2),row(10),clock,depth,mass,stable
 integer(int64)::revision
 integer::u,n,i,j,code,failures
 character(1024)::path,mode
 call get_command_argument(1,path);call get_command_argument(2,mode)
 open(newunit=u,file=trim(path),status='old')
 read(u,*)before;read(u,*)ctop;read(u,*)n
 failures=0
 do i=1,n
  read(u,*)row
  step%t0=row(1);step%t1=row(2);step%depth_begin=row(3);step%depth_end=row(4);step%qtop=row(5)
  step%rain_rate=row(6);step%irrigation_rate=row(7);step%pond_evaporation_rate=row(8)
  step%runon_rate=row(9);step%runoff_depth=row(10)
  do j=1,2
   if(i==1)then
    call initialize_persistent_pond(step%t0,step%depth_begin,before(j)*100d0,current(j),code)
    call require(code==POND_OK,'initialization')
   endif
   step%rain_c=ctop(j);step%irrigation_c=ctop(j);step%runon_c=ctop(j)
   call advance_persistent_pond(current(j),step,next,receipt)
   if(receipt%status/=POND_OK)then
    call current(j)%snapshot(clock,depth,mass,revision)
    call evaluate_b111_pond_solute_exchange(mass,step%rain_rate,step%rain_c,step%irrigation_rate,step%irrigation_c, &
      step%qtop,0d0,step%depth_end,step%t1-step%t0,mix,step%runon_rate,step%runon_c,step%runoff_depth)
    stable=step%depth_end*mix%pond_concentration
    print *,'LEAF_FAILURE_INDEX_SPECIES_STATUS',i,j,receipt%status,mix%status
    print *,'LEAF_MASS_AFTER_STABLE',mix%mass_after,stable,mix%pond_concentration
    print *,'LEAF_EXACT_STEP',mass,ctop(j),row
    call require(trim(mode)=='expect-reject','unexpected rejected actual hydrology')
    call require(mix%mass_after<0d0.and.stable>=0d0,'not the cancellation witness')
    failures=failures+1;exit
   endif
   current(j)=next
  enddo
  if(failures>0)exit
 enddo
 close(u)
 if(trim(mode)=='expect-reject')then
  call require(failures==1,'original source must reject exact witness')
  print '(A)','ORIGINAL_POND_NEGATIVE_CANCELLATION_FROM_ACTUAL_TRACE=CONFIRMED'
 else
  call require(failures==0,'complete accepted trace')
  print '(A)','POND_COMPLETE_ACTUAL_TRACE_NONNEGATIVE_AND_MASS_GATES=PASS'
 endif
contains
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then
   print *,label;error stop 1
  endif
 end subroutine
end program
