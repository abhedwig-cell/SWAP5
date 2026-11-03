module mod_contact_action_memory
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_macropore_continuation_state,only:macropore_continuation_state_t,copy_macropore_continuation_state
 use mod_ppa_wu05a6_sorptivity_history,only:sorptivity_history_update_request_t
 use mod_ppa_wu05a6_unsat_absorption_rate,only:unsat_absorption_result_t
 implicit none
 private
 public::complete_contact_action_memory
contains
 subroutine complete_contact_action_memory(request,accepted,active,off,on,node,fraction,candidate,ok)
  type(sorptivity_history_update_request_t),intent(in)::request
  type(macropore_continuation_state_t),intent(in)::accepted,off,on
  type(unsat_absorption_result_t),intent(in)::active
  integer,intent(in)::node
  real(real64),intent(in)::fraction
  type(macropore_continuation_state_t),intent(out)::candidate
  logical,intent(out)::ok
  real(real64)::tau,r,action,increment,coefficient
  integer::id,n,nd,ic
  ok=.false.
  if(.not.ieee_is_finite(request%step_duration))return
  if(.not.request%valid().or..not.accepted%ready().or..not.off%ready().or..not.on%ready())return
  if(.not.ieee_is_finite(fraction))return
  if(fraction<0d0.or.fraction>1d0)return
  n=request%num_nodes;nd=request%num_domains
  if(node<request%top_node.or.node>n)return
  if(accepted%num_nodes/=n.or.off%num_nodes/=n.or.on%num_nodes/=n.or.accepted%num_domains/=nd)return
  if(off%num_domains/=nd.or.on%num_domains/=nd)return
  if(.not.active%valid.or..not.allocated(active%end_event).or..not.allocated(active%seed_sorptivity).or. &
     .not.allocated(active%seed_theta_ref))return
  if(any(shape(active%end_event)/=[nd,n]).or.any(shape(active%seed_sorptivity)/=[nd,n]).or. &
     any(shape(active%seed_theta_ref)/=[nd,n]))return
  ! Off/on differ only in contact history, never in the shared water candidate.
  if(any(off%water_domain_cp/=on%water_domain_cp).or.any(off%volume_domain_cp/=on%volume_domain_cp))return
  if(fraction==0d0)then
   call copy_macropore_continuation_state(off,candidate,ok);return
  else if(fraction==1d0)then
   call copy_macropore_continuation_state(on,candidate,ok);return
  end if
  do ic=1,n
   if(ic==node)cycle
   if(any(off%absorption_time(:,ic)/=on%absorption_time(:,ic)).or. &
      any(off%sorptivity(:,ic)/=on%sorptivity(:,ic)).or.any(off%theta_sorption_ref(:,ic)/=on%theta_sorption_ref(:,ic)))return
  end do
  if(.not.all(ieee_is_finite([request%wall_correction(node),request%diameter(node)])))return
  if(any(.not.ieee_is_finite(request%wet_fraction(:,node))).or.any(.not.ieee_is_finite(request%domain_fraction(:,node))))return
  do id=1,nd
   if(active%end_event(id,node))cycle
   tau=accepted%absorption_time(id,node)
   if(.not.ieee_is_finite(tau))return
   if(tau<0d0)return
   if(tau>huge(1d0)-request%step_duration)return
   if(.not.ieee_is_finite(active%seed_sorptivity(id,node)))return
   if(active%seed_sorptivity(id,node)<0d0)return
   if(.not.ieee_is_finite(active%seed_theta_ref(id,node)))return
  end do
  call copy_macropore_continuation_state(off,candidate,ok)
  if(.not.ok)return
  do id=1,nd
   candidate%absorption_time(id,node)=on%absorption_time(id,node)
   candidate%sorptivity(id,node)=on%sorptivity(id,node)
   candidate%theta_sorption_ref(id,node)=on%theta_sorption_ref(id,node)
   if(active%end_event(id,node))cycle
   tau=accepted%absorption_time(id,node);r=sqrt(tau)
   ! Stable sqrt difference: lambda scales sorptivity action, not elapsed time.
   action=fraction*request%step_duration/(sqrt(tau+request%step_duration)+r)
   increment=action*(2d0*r+action)
   coefficient=request%wall_correction(node)*request%wet_fraction(id,node)* &
      request%domain_fraction(id,node)*(4d0/request%diameter(node))*active%seed_sorptivity(id,node)
   candidate%absorption_time(id,node)=tau+increment
   candidate%sorptivity(id,node)=active%seed_sorptivity(id,node)
   candidate%theta_sorption_ref(id,node)=active%seed_theta_ref(id,node)+coefficient*action
  end do
  if(any(.not.ieee_is_finite(candidate%absorption_time)).or.any(.not.ieee_is_finite(candidate%theta_sorption_ref)))then
   call candidate%clear();ok=.false.
  end if
 end subroutine
end module
