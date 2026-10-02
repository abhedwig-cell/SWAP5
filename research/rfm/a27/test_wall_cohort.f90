program test_wall_cohort
 use iso_fortran_env,only:real64
 use mod_wall_cohort_research
 implicit none
 type(wall_cohort_t)::accepted,candidate,replay,restored
 real(real64)::p,d,expected
 logical::ok
 integer::n,j,ref
 real(real64)::seed_integral,old_uptake
 call prepare_wall_cohorts(accepted,5.5_real64,6._real64,2._real64,candidate,ok)
 call check(ok,'initial wet segment');call advance_wall_cohorts(candidate,1._real64);accepted=candidate
 call prepare_wall_cohorts(accepted,5._real64,6._real64,2._real64,candidate,ok)
 call check(ok.and.wall_count(candidate)==2,'new wet segment separate')
 call check(accepted%age(1)==1._real64.and.candidate%age(1)==0._real64,'trial immutable and first contact')
 call wall_potential(candidate,-5._real64,-10._real64,0._real64,.1_real64,10._real64,1._real64,p,d)
 expected=.8_real64*.5_real64*(sqrt(.1_real64)+sqrt(1.1_real64)-1._real64)
 call check(abs(p-expected)<1e-14_real64,'mixed-age analytic uptake')
 print '(a,es24.16)','A27_COHORT_MIXED_UPTAKE_CM=',p
 call prepare_wall_cohorts(accepted,5._real64,6._real64,2._real64,replay,ok)
 call check(all(candidate%age==replay%age).and.all(candidate%seed==replay%seed),'rejected replay')
 ! Explicit array reconstruction is research state replay, not production restart ABI.
 restored%lo=candidate%lo;restored%hi=candidate%hi;restored%age=candidate%age;restored%seed=candidate%seed
 call wall_potential(restored,-5._real64,-10._real64,0._real64,.1_real64,10._real64,1._real64,p,d)
 call check(abs(p-expected)<1e-14_real64,'explicit-array reconstruction')
 accepted=candidate
 call prepare_wall_cohorts(accepted,5.75_real64,6._real64,9._real64,candidate,ok)
 call check(ok.and.wall_count(candidate)==1.and.candidate%age(1)==1._real64,'dry clipping preserves old age')
 accepted=candidate
 call prepare_wall_cohorts(accepted,5._real64,6._real64,3._real64,candidate,ok)
 call check(ok.and.wall_count(candidate)==2.and.candidate%seed(1)==3._real64,'rewetting seeds only new area')
 call check(abs(sum(candidate%hi-candidate%lo)-1._real64)<1e-14_real64,'complete disjoint coverage')
 call prepare_wall_cohorts(candidate,6._real64,6._real64,0._real64,replay,ok)
 call check(ok.and.wall_count(replay)==0,'empty wall resets')
 call prepare_wall_cohorts(candidate,-1._real64,6._real64,0._real64,replay,ok)
 call check(.not.ok,'invalid geometry')
 print '(a)','exposure_steps,live_positive_S_cohorts,nominal_payload_bytes'
 do ref=0,2
  n=500*2**ref;accepted=wall_cohort_t()
  do j=1,n
   call prepare_wall_cohorts(accepted,6._real64-real(j,real64)/n,6._real64,2._real64,candidate,ok)
   call check(ok,'monotonic exposure valid')
   call advance_wall_cohorts(candidate,1._real64/n);accepted=candidate
  enddo
  call check(wall_count(accepted)==n,'uncompressed positive-history growth')
  print '(3(i0,:,","))',n,wall_count(accepted),32*wall_count(accepted)
 enddo
 seed_integral=sum((accepted%hi-accepted%lo)*accepted%seed)
 candidate=accepted
 call compress_wall_cohorts(candidate,8,.1_real64,ok)
 call check(ok.and.wall_count(candidate)<=8,'bounded interval count')
 call check(abs(sum((candidate%hi-candidate%lo)*candidate%seed)-seed_integral)<1e-12_real64,'seed integral preserved')
 call check(abs(sum(candidate%hi-candidate%lo)-1._real64)<1e-12_real64,'bounded coverage preserved')
 call check(wall_count(accepted)==2000,'compression isolated from accepted')
 call compress_wall_cohorts(candidate,0,.1_real64,ok);call check(.not.ok,'invalid history limit')
 print '(a)','A27_WALL_COHORT_ORACLES=PASS'
contains
 subroutine check(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then
   print *,label
   error stop 'wall cohort gate'
  endif
 end subroutine
end program
