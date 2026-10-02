program physical_mechanisms
 use iso_fortran_env,only:real64
 use mod_ppa_wu05a6_sorptivity_rate
 use mod_ppa_wu05a6_unsat_absorption_rate
 use mod_ppa_wu05a6_sorptivity_history
 use mod_macropore_continuation_state
 use mod_ppa_wu05a6_saturated_exchange_rate
 implicit none
 type(sorptivity_rate_request_t)::q
 type(sorptivity_rate_result_t)::r,rr
 type(sorptivity_history_update_request_t)::hq
 type(unsat_absorption_result_t)::a
 type(macropore_continuation_state_t)::accepted,candidate,snapshot
 type(saturated_exchange_request_t)::sq
 type(saturated_exchange_result_t)::sr
 real(real64)::dtheta,expected,frozen,dr,ref0,age0
 integer::i
 logical::ok
 q%num_domains=1;q%num_nodes=2;q%top_node=1;q%matrix_top_saturated_node=3
 q%step_duration=.1_real64;q%bottom_domain=[2];q%top_water_node=[1]
 q%theta=[.25_real64,.25_real64];q%theta_s=[.45_real64,.45_real64];q%theta_r=[.05_real64,.05_real64]
 q%dz=[10._real64,10._real64];q%diameter=[20._real64,20._real64];q%wall_correction=[1._real64,1._real64]
 q%sorptivity_max=[4._real64,4._real64];q%sorptivity_alpha=[1._real64,1._real64]
 allocate(q%domain_fraction(1,2),q%wet_fraction(1,2),q%history_sorptivity(1,2),q%history_theta_ref(1,2),q%history_absorption_time(1,2))
 q%domain_fraction=1.;q%wet_fraction=1.;q%history_sorptivity=2.;q%history_theta_ref=.45_real64;q%history_absorption_time=1.
 dr=sqrt(1.1_real64)-1._real64;frozen=2._real64*2._real64*dr
 print '(a)','external_delta_theta,standard_amount_cm,frozen_amount_cm,seed'
 do i=-2,3
  dtheta=i*.05_real64;q%theta=.25_real64+dtheta
  call evaluate_sorptivity_rate(q,r);call check(r%valid,'standard rate valid')
  expected=4._real64*max(0._real64,.45_real64-q%theta(1))/.4_real64*2._real64*dr
  call check(abs(r%amount_cm(1,1)-expected)<1e-12_real64,'independent moisture-correction oracle')
  call check(r%seed_sorptivity(1,1)==2._real64,'retained event seed')
  call evaluate_sorptivity_rate(q,rr);call check(all(r%amount_cm==rr%amount_cm),'replay')
  print '(4(es24.16,:,","))',dtheta,r%amount_cm(1,1),frozen,r%seed_sorptivity(1,1)
 enddo
 call accepted%initialize(1,2,ok);call check(ok,'history init')
 accepted%icp_bottom_domain=2;accepted%sorptivity=2.;accepted%theta_sorption_ref=.45_real64;accepted%absorption_time=1.
 candidate=accepted;snapshot=accepted
 hq%num_domains=1;hq%num_nodes=2;hq%top_node=1;hq%matrix_top_saturated_node=3;hq%step_duration=.1_real64
 hq%bottom_domain=[2];hq%top_water_node=[2];hq%wall_correction=q%wall_correction;hq%wet_fraction=q%wet_fraction
 hq%domain_fraction=q%domain_fraction;hq%diameter=q%diameter
 a%valid=.true.;allocate(a%end_event(1,2),a%seed_sorptivity(1,2),a%seed_theta_ref(1,2))
 a%end_event=.false.;a%seed_sorptivity=2.;a%seed_theta_ref=.45_real64
 call apply_sorptivity_history_update(hq,accepted,a,candidate,ok);call check(ok,'history update')
 call check(accepted%same_values(snapshot),'accepted origin unchanged')
 call check(candidate%absorption_time(1,1)==0..and.candidate%sorptivity(1,1)==0..and.candidate%theta_sorption_ref(1,1)==0.,'dry node reset')
 call check(abs(candidate%absorption_time(1,2)-1.1_real64)<1e-14_real64,'wet node age')
 call check(abs(candidate%theta_sorption_ref(1,2)-(.45_real64+.4_real64*dr))<1e-14_real64,'frozen theoretical increment')
 q%theta=.30_real64;q%history_absorption_time=candidate%absorption_time;q%history_theta_ref=candidate%theta_sorption_ref;q%history_sorptivity=candidate%sorptivity
 call evaluate_sorptivity_rate(q,r)
 expected=4._real64*(.45_real64-.30_real64)/.4_real64
 call check(abs(r%seed_sorptivity(1,1)-expected)<1e-12_real64,'new event reseed')
 print '(a,3(es24.16,:,","))','RESET_RESEED=',candidate%absorption_time(1,1),r%seed_sorptivity(1,1),candidate%theta_sorption_ref(1,2)
 sq%num_domains=1;sq%num_nodes=1;sq%matrix_top_saturated_node=1;sq%matrix_bottom_saturated_node=1
 sq%matrix_partial_top_active=.false.;sq%step_duration=.1_real64;sq%bottom_domain=[1];sq%top_macro_saturated_node=[1]
 sq%macro_saturated_fraction=[1._real64];sq%macro_reference_level=[-95._real64];sq%z=[-100._real64];sq%dz=[1._real64]
 sq%matrix_head=[3._real64];sq%ksat_horizontal=[1._real64];sq%diameter=[10._real64]
 allocate(sq%domain_fraction(1,1),sq%cdarcy(1,1));sq%domain_fraction=1.;sq%cdarcy=.08_real64
 print '(a)','matrix_head_cm,signed_matrix_to_macro_cm'
 do i=3,7
  sq%matrix_head=real(i,real64)
  call evaluate_saturated_exchange(sq,sr);call check(sr%valid,'signed Darcy valid')
  expected=.08_real64*(real(i,real64)-5._real64)*.1_real64
  call check(abs(sr%signed_matrix_to_macro_amount_cm(1,1)-expected)<1e-12_real64,'signed Darcy analytic oracle')
  print '(2(es24.16,:,","))',sq%matrix_head(1),sr%signed_matrix_to_macro_amount_cm(1,1)
 enddo
 print '(a)','A27_SOURCE_FEEDBACK_RESET_SIGNED_DARCY=PASS'
contains
 subroutine check(ok,label)
 logical,intent(in)::ok
 character(*),intent(in)::label
 if(.not.ok)then
 print *,label
 error stop 'physical mechanism source oracle'
 endif
 end subroutine
end program
