program test_capillary_budget
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_rfm_signed_contact_research
 implicit none
 type(signed_contact_request_t)::q,snapshot
 type(signed_contact_result_t)::r,replay
 real(real64)::sat,eps,expected,mixture,homogeneous,u,darcy
 integer::i
 q%finite_contact=.true.;q%dt=.1_real64;q%storage=.5_real64;q%capacity=1._real64
 q%area=.1_real64;q%bottom_depth=10._real64;q%length=10._real64;q%chi=1._real64;q%age=.2_real64
 q%depth=[8._real64];q%thickness=[1._real64];q%conductivity=[1._real64];q%sorptivity=[2._real64]
 q%matrix_head=[0._real64];q%donor_water=[1._real64];q%receiver_space=[1._real64]
 q%capillary_budget=[0._real64];q%contact_age=[.2_real64]
 call evaluate_signed_contact(q,r);call check(r%valid,'saturated valid');sat=sum(r%matrix_gain)
 call check(abs(sat-.024_real64)<1e-14_real64,'zero budget preserves saturated Darcy')
 print '(a)','epsilon_head_cm,capillary_budget_cm,transfer_minus_saturated_cm'
 do i=1,6
  eps=10._real64**(-2*i);q%matrix_head=-eps;q%capillary_budget=eps
  call evaluate_signed_contact(q,r);call check(r%valid,'budget sweep valid')
  darcy=.008_real64*(3._real64+eps)
  call check(sum(r%matrix_gain)-darcy<=eps+1e-14_real64,'enhancement bounded')
  call check(abs(sum(r%matrix_gain)-sat)<=1.009_real64*eps+1e-14_real64,'saturation continuity')
  print '(3(es24.16,:,","))',eps,eps,sum(r%matrix_gain)-sat
 enddo
 q%matrix_head=5.;q%capillary_budget=0.;call evaluate_signed_contact(q,r)
 call check(abs(sum(r%matrix_loss)-.016_real64)<1e-14_real64,'reverse Darcy preserved')
 ! Genuine sufficient-state falsifier: identical average age and S, unequal uptake.
 ! Two equal wall areas aged 0 and 1 versus both aged 0.5; neither budget is active.
 mixture=.4_real64*2._real64*.5_real64*(sqrt(.1_real64)+sqrt(1.1_real64)-1._real64)
 homogeneous=.4_real64*2._real64*(sqrt(.6_real64)-sqrt(.5_real64))
 call check(abs(mixture-homogeneous)>1e-3_real64,'mean age is not closed memory')
 print '(a,es24.16)','A27_MIXED_AGE_UPTAKE_CM=',mixture
 print '(a,es24.16)','A27_HOMOGENEOUS_MEAN_AGE_UPTAKE_CM=',homogeneous
 print '(a,es24.16)','A27_MEAN_AGE_CLOSURE_ERROR_CM=',mixture-homogeneous
 homogeneous=.4_real64*2._real64*(sqrt(1.1_real64)-1._real64)
 call check(mixture-homogeneous>1e-3_real64,'endpoint first-contact age is not closed memory')
 print '(a,es24.16)','A27_ENDPOINT_FIRST_CLOCK_UPTAKE_CM=',homogeneous
 print '(a,es24.16)','A27_ENDPOINT_FIRST_CLOCK_CLOSURE_ERROR_CM=',mixture-homogeneous
 do i=1,20000
  u=real(mod(i*7919,20003),real64)/20003._real64
  q%dt=1e-5_real64+u;q%storage=u;q%conductivity=10*u;q%matrix_head=40*u-20
  q%sorptivity=2*u;q%contact_age=u;q%donor_water=.2;q%receiver_space=.2;q%capillary_budget=.01*u
  snapshot=q;call evaluate_signed_contact(q,r);call evaluate_signed_contact(q,replay)
  call check(r%valid,'screen valid')
  call check(q%storage==snapshot%storage.and.all(q%contact_age==snapshot%contact_age),'accepted immutable')
  call check(r%storage_candidate==replay%storage_candidate,'deterministic replay')
  call check(all(r%matrix_gain<=q%receiver_space+1e-12_real64).and.all(r%matrix_loss<=q%donor_water+1e-12_real64),'screen budgets')
 enddo
 q%contact_age=ieee_value(0._real64,ieee_quiet_nan);call evaluate_signed_contact(q,r);call check(.not.r%valid,'nan age')
 q%contact_age=0.;q%capillary_budget=[0._real64,0._real64];call evaluate_signed_contact(q,r);call check(.not.r%valid,'budget shape')
 print '(a)','A27_CAPILLARY_BOUNDARY_ORACLES=PASS'
 print '(a)','A27_CAPILLARY_SCREEN_20000=PASS'
 print '(a)','A27_SCALAR_MEAN_AGE_ROUTE=FALSIFIED'
contains
 subroutine check(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then
   print *,label
   error stop 'capillary budget gate'
  endif
 end subroutine
end program
