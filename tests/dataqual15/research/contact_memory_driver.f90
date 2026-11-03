program contact_memory_driver
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_contact_action_memory
 use mod_macropore_continuation_state
 use mod_ppa_wu05a6_sorptivity_history
 use mod_ppa_wu05a6_unsat_absorption_rate
 implicit none
 type(macropore_continuation_state_t)::accepted,off,on,candidate,again,snapshot
 type(sorptivity_history_update_request_t)::r
 type(unsat_absorption_result_t)::a,b
 real(real64)::fraction,action,expected,clock,oldclock
 integer::i
 logical::ok
 call accepted%initialize(1,2,ok);if(.not.ok)error stop 'init'
 accepted%icp_bottom_domain=2;accepted%volume_domain_cp=1d0;accepted%water_domain_cp=.5d0
 accepted%absorption_time=.25d0;accepted%sorptivity=2d0;accepted%theta_sorption_ref=.1d0;snapshot=accepted
 r%num_domains=1;r%num_nodes=2;r%top_node=1;r%matrix_top_saturated_node=3;r%step_duration=.4d0
 r%bottom_domain=[2];r%top_water_node=[1];r%wall_correction=[1d0,1d0];r%diameter=[4d0,4d0]
 allocate(r%wet_fraction(1,2),r%domain_fraction(1,2));r%wet_fraction=1d0;r%domain_fraction=1d0
 a%valid=.true.;allocate(a%end_event(1,2),a%seed_sorptivity(1,2),a%seed_theta_ref(1,2))
 a%end_event=.false.;a%seed_sorptivity=2d0;a%seed_theta_ref=.1d0;b=a;b%end_event(1,1)=.true.
 off=accepted;on=accepted
 call apply_sorptivity_history_update(r,accepted,b,off,ok);if(.not.ok)error stop 'legacy off'
 call apply_sorptivity_history_update(r,accepted,a,on,ok);if(.not.ok)error stop 'legacy on'
 do i=0,100
  fraction=real(i,real64)/100d0
  call complete_contact_action_memory(r,accepted,a,off,on,1,fraction,candidate,ok)
  if(.not.ok)error stop 'completion'
  call complete_contact_action_memory(r,accepted,a,off,on,1,fraction,again,ok)
  if(.not.ok.or..not.candidate%same_values(again))error stop 'nonunique completion'
  if(i==0)then
   if(.not.candidate%same_values(off))error stop 'off endpoint'
  else if(i==100)then
   if(.not.candidate%same_values(on))error stop 'on endpoint'
  else
   action=fraction*(sqrt(.65d0)-.5d0);expected=.1d0+2d0*action
   if(abs(candidate%theta_sorption_ref(1,1)-expected)>1d-14)error stop 'action reference'
   if(abs(sqrt(candidate%absorption_time(1,1))-.5d0-action)>1d-14)error stop 'action clock'
  end if
 end do
 call complete_contact_action_memory(r,accepted,a,off,on,1,-.1d0,candidate,ok)
 if(ok.or.candidate%ready())error stop 'invalid fraction'
 call complete_contact_action_memory(r,accepted,a,off,on,1,ieee_value(0d0,ieee_quiet_nan),candidate,ok)
 if(ok.or.candidate%ready())error stop 'unknown fraction'
 on%absorption_time(1,2)=99d0
 call complete_contact_action_memory(r,accepted,a,off,on,1,.5d0,candidate,ok)
 if(ok.or.candidate%ready())error stop 'unhandled branch disagreement'
 if(.not.accepted%same_values(snapshot))error stop 'modified accepted state'
 write(*,'(a)')'ACTION_MEMORY_101_FRACTIONS_LEGACY_ENDPOINTS_UNIQUE_AND_REFUSAL_ROLLBACK_PASS'
end program
