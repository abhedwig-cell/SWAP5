program test_signed_contact
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_rfm_signed_contact_research
 implicit none
 type(signed_contact_request_t)::q,snapshot
 type(signed_contact_result_t)::r,replay
 integer::i
 real(real64)::old,expect,u,wet0,wet1,sat0,sat1
 q%dt=.1_real64;q%storage=.5_real64;q%capacity=1._real64;q%area=.1_real64;q%bottom_depth=10._real64
 q%length=10.;q%chi=1.;q%age=0.
 q%depth=[8._real64];q%thickness=[1._real64];q%conductivity=[1._real64];q%sorptivity=[0._real64]
 q%matrix_head=[5._real64];q%donor_water=[1._real64];q%receiver_space=[1._real64]
 call evaluate_signed_contact(q,r);call check(r%valid,'signed fill');call check(abs(sum(r%matrix_loss)-.016_real64)<1e-14_real64,'Darcy fill oracle')
 q%matrix_head=1.;call evaluate_signed_contact(q,r);call check(abs(sum(r%matrix_gain)-.016_real64)<1e-14_real64,'Darcy release oracle')
 q%matrix_head=3.;call evaluate_signed_contact(q,r);call check(sum(r%matrix_gain)+sum(r%matrix_loss)==0.,'equilibrium')
 q%dt=100.;q%matrix_head=100.;q%storage=.99_real64;call evaluate_signed_contact(q,r);call check(abs(r%storage_candidate-1._real64)<1e-14_real64,'full capacity')
 q%matrix_head=0.;q%storage=.01_real64;q%depth=10.;q%conductivity=1000.;call evaluate_signed_contact(q,r);call check(abs(r%storage_candidate)<1e-14_real64,'empty donor')
 q%storage=0.;q%matrix_head=-10.;q%sorptivity=10.;call evaluate_signed_contact(q,r);call check(r%storage_candidate==0.,'dry contact no water')
 q%storage=.5;q%depth=8.;q%dt=.1;q%conductivity=1.;q%matrix_head=-10.;q%sorptivity=2.
 call evaluate_signed_contact(q,r)
 expect=max(.4_real64*2._real64*sqrt(.1_real64),8._real64*13._real64*.1_real64/100._real64)
 call check(abs(sum(r%matrix_gain)-expect)<1e-8_real64,'unsaturated max not sum')
 q%receiver_space=0.;call evaluate_signed_contact(q,r);call check(sum(r%matrix_gain)==0.,'matrix full')
 q%receiver_space=1.;q%matrix_head=100.;q%donor_water=0.;call evaluate_signed_contact(q,r);call check(sum(r%matrix_loss)==0.,'matrix donor empty')
 ! Deterministic 20000-point screen, reproducible without compiler RNG.
 do i=1,20000
  u=real(mod(i*7919,20003),real64)/20003._real64
  q%dt=1e-5_real64+u;q%storage=u;q%conductivity=10*u;q%matrix_head=40*u-20
  q%sorptivity=2*u;q%age=u;q%donor_water=.2;q%receiver_space=.2
  snapshot=q;old=q%storage
  call evaluate_signed_contact(q,r);call evaluate_signed_contact(q,replay)
  call check(r%valid,'screen valid')
  call check(q%storage==old.and.all(q%matrix_head==snapshot%matrix_head),'accepted immutable')
  call check(r%storage_candidate==replay%storage_candidate,'deterministic retry')
  call check(all(r%matrix_gain<=q%receiver_space+1e-12_real64).and.all(r%matrix_loss<=q%donor_water+1e-12_real64),'matrix bounds')
 enddo
 ! Falsification: representative-point wetting and frozen sorptivity history.
 q%dt=.1_real64;q%storage=.5_real64;q%capacity=1._real64;q%area=.1_real64;q%bottom_depth=10._real64
 q%length=10._real64;q%chi=1._real64;q%age=.2_real64;q%thickness=1._real64
 q%conductivity=1._real64;q%sorptivity=2._real64;q%donor_water=1._real64;q%receiver_space=1._real64
 q%matrix_head=-10._real64;q%depth=5._real64
 call evaluate_signed_contact(q,r);wet0=sum(r%matrix_gain)
 q%depth=5._real64+1e-9_real64
 call evaluate_signed_contact(q,r);wet1=sum(r%matrix_gain)
 call check(wet1-wet0>1e-3_real64,'wetting boundary falsification')
 q%depth=8._real64;q%matrix_head=-1e-9_real64
 call evaluate_signed_contact(q,r);sat0=sum(r%matrix_gain)
 q%matrix_head=0._real64
 call evaluate_signed_contact(q,r);sat1=sum(r%matrix_gain)
 call check(sat0-sat1>1e-3_real64,'history saturation falsification')
 print '(a,es24.16)','A27_POINT_WETTING_JUMP_CM=',wet1-wet0
 print '(a,es24.16)','A27_FROZEN_HISTORY_SATURATION_JUMP_CM=',sat0-sat1
 ! Finite geometry: first wetting occurs at the lower segment face.
 q%finite_contact=.true.;q%depth=4.5_real64;q%matrix_head=-10._real64
 call evaluate_signed_contact(q,r);wet0=sum(r%matrix_gain)
 q%depth=4.5_real64+1e-9_real64
 call evaluate_signed_contact(q,r);wet1=sum(r%matrix_gain)
 call check(wet0==0._real64.and.wet1>=0._real64.and.wet1<1e-9_real64,'finite first-contact continuity')
 print '(a,es24.16)','A27_FINITE_FIRST_CONTACT_DELTA_CM=',wet1-wet0
 q%depth=5._real64;call evaluate_signed_contact(q,r)
 expect=.5_real64*.4_real64*2._real64*(sqrt(.3_real64)-sqrt(.2_real64))
 call check(abs(sum(r%matrix_gain)-expect)<1e-14_real64,'half wet Philip integral')
 q%depth=8._real64;q%sorptivity=0.;q%matrix_head=1._real64
 call evaluate_signed_contact(q,r);call check(abs(sum(r%matrix_gain)-.016_real64)<1e-14_real64,'fully wet integrated Darcy')
 q%sorptivity=2._real64;q%matrix_head=-1e-9_real64
 call evaluate_signed_contact(q,r);sat0=sum(r%matrix_gain)
 q%matrix_head=0._real64
 call evaluate_signed_contact(q,r);sat1=sum(r%matrix_gain)
 call check(sat0-sat1>1e-3_real64,'geometry does not fix frozen history')
 print '(a,es24.16)','A27_FINITE_FROZEN_HISTORY_SATURATION_JUMP_CM=',sat0-sat1
 print '(a)','A27_FINITE_CONTACT_ORACLES=PASS'
 q%dt=ieee_value(0._real64,ieee_quiet_nan);call evaluate_signed_contact(q,r);call check(.not.r%valid,'nan fail closed')
 print '(a)','A27_SIGNED_CONTACT_ORACLES=PASS'
 print '(a)','A27_SIGNED_CONTACT_SCREEN_20000=PASS'
contains
 subroutine check(ok,label)
 logical,intent(in)::ok
 character(*),intent(in)::label
 if(.not.ok)then
 print *,label
 error stop 'signed contact gate'
 endif
 end subroutine
end program
