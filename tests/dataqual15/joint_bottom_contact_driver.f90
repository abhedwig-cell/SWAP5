! Real lower-pocket operator, two Newton sides, action history and refusals.
program joint_bottom_contact_driver
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_ppa_wu05a6_unsat_absorption_rate
 use mod_ppa_wu05a6_sorptivity_history
 use mod_macropore_continuation_state
 implicit none
 type(unsat_absorption_request_t)::r,bad
 type(unsat_absorption_result_t)::closed,opened,graph,normal
 type(sorptivity_history_update_request_t)::h
 type(macropore_continuation_state_t)::accepted,candidate
 real(real64)::weight,action,expected
 logical::ok
 integer::i,side
 r%sorptivity%num_domains=1;r%sorptivity%num_nodes=2
 r%sorptivity%matrix_top_saturated_node=3;r%sorptivity%step_duration=.001d0
 r%sorptivity%bottom_domain=[2];r%sorptivity%top_water_node=[1]
 r%sorptivity%theta=[.3d0,.3d0];r%sorptivity%theta_s=[.45d0,.45d0];r%sorptivity%theta_r=[.05d0,.05d0]
 r%sorptivity%dz=[1d0,1d0];r%sorptivity%diameter=[.2d0,.2d0];r%sorptivity%wall_correction=[1d0,1d0]
 r%sorptivity%sorptivity_max=[.001d0,.001d0];r%sorptivity%sorptivity_alpha=[1d0,1d0]
 r%sorptivity%domain_fraction=reshape([.01d0,.01d0],[1,2]);r%sorptivity%wet_fraction=reshape([1d0,1d0],[1,2])
 r%sorptivity%history_sorptivity=reshape([.001d0,.001d0],[1,2])
 r%sorptivity%history_theta_ref=reshape([.45d0,.45d0],[1,2])
 r%sorptivity%history_absorption_time=reshape([.5d0,.5d0],[1,2])
 r%pressure_head=[.4d0,-.4d0];r%elevation=[-1d0,-2d0]
 r%conductivity=[.1d0,.1d0];r%entry_head=[-10d0,-10d0]
 r%groundwater_level_domain=[-1.8d0];r%sorp_fac_parallel=[1d0,1d0]
 r%sorptivity%perched_active=.true.;r%sorptivity%perched_top_node=1;r%sorptivity%perched_bottom_node=2
 call evaluate_unsat_absorption(r,closed)
 r%sorptivity%perched_bottom_node=1;call evaluate_unsat_absorption(r,opened)
 if(.not.closed%valid.or..not.opened%valid)error stop 'lower contact endpoints invalid'
 if(closed%selected_amount_cm(1,2)/=0d0.or.opened%selected_amount_cm(1,2)<=0d0)error stop 'lower contact jump missing'
 h%num_domains=1;h%num_nodes=2;h%matrix_top_saturated_node=3;h%step_duration=.001d0
 h%bottom_domain=[2];h%top_water_node=[1];h%wall_correction=[1d0,1d0]
 h%wet_fraction=reshape([1d0,1d0],[1,2]);h%domain_fraction=reshape([.01d0,.01d0],[1,2]);h%diameter=[.2d0,.2d0]
 call accepted%initialize(1,2,ok);if(.not.ok)error stop 'history state'
 accepted%icp_bottom_domain=2;accepted%volume_domain_cp=.1d0;accepted%water_domain_cp=.05d0
 accepted%absorption_time=.5d0;accepted%sorptivity=.001d0;accepted%theta_sorption_ref=.45d0
 r%perched_bottom_graph_fraction=[-1d0,0d0]
 do i=0,4
  weight=real(i,real64)/4d0;r%perched_bottom_graph_fraction(2)=weight
  do side=1,2
   r%sorptivity%perched_bottom_node=side
   call evaluate_unsat_absorption(r,graph)
   if(.not.graph%valid)error stop 'lower graph invalid'
   if(abs(graph%selected_amount_cm(1,2)-weight*opened%selected_amount_cm(1,2))>1d-15)error stop 'lower graph side-dependent'
   if(graph%selected_amount_cm(1,1)/=0d0)error stop 'other pocket cell exposed'
   if(abs(graph%selected_amount_cm(1,2)-h%step_duration*graph%selected_rate_cm_per_day(1,2))>1d-15)error stop 'lower amount/rate'
   candidate=accepted;call apply_sorptivity_history_update(h,accepted,graph,candidate,ok)
   if(.not.ok.or.any(candidate%water_domain_cp/=accepted%water_domain_cp))error stop 'lower history water'
   if(weight==0d0)then
    if(candidate%absorption_time(1,2)/=0d0)error stop 'closed lower action'
   else
    action=weight*h%step_duration/(sqrt(.5d0+h%step_duration)+sqrt(.5d0))
    expected=.5d0+action*(2d0*sqrt(.5d0)+action)
    if(abs(candidate%absorption_time(1,2)-expected)>1d-15)error stop 'lower action history'
    expected=graph%seed_theta_ref(1,2)+.01d0*(4d0/.2d0)*graph%seed_sorptivity(1,2)*action
    if(abs(candidate%theta_sorption_ref(1,2)-expected)>1d-15)error stop 'lower action reference'
   end if
  end do
 end do
 r%perched_bottom_graph_fraction=-1d0;r%sorptivity%perched_bottom_node=2
 call evaluate_unsat_absorption(r,normal)
 if(any(normal%selected_amount_cm/=closed%selected_amount_cm))error stop 'unselected lower route changed'
 bad=r;bad%perched_bottom_graph_fraction=[-1d0,ieee_value(0d0,ieee_quiet_nan)]
 call evaluate_unsat_absorption(bad,graph);if(graph%valid)error stop 'nonfinite lower graph admitted'
 bad=r;bad%perched_bottom_graph_fraction=[-1d0,1.01d0]
 call evaluate_unsat_absorption(bad,graph);if(graph%valid)error stop 'out-of-range lower graph admitted'
 bad=r;bad%perched_bottom_graph_fraction=[0d0]
 call evaluate_unsat_absorption(bad,graph);if(graph%valid)error stop 'wrong lower shape admitted'
 bad=r;bad%perched_bottom_graph_fraction(2)=.5d0;bad%entry_transition_width_cm=.1d0
 call evaluate_unsat_absorption(bad,graph);if(graph%valid)error stop 'smooth lower graph admitted'
 bad=r;bad%perched_bottom_graph_fraction(2)=.5d0;bad%perched_graph_fraction=[-1d0,.5d0]
 call evaluate_unsat_absorption(bad,graph);if(graph%valid)error stop 'overlapping unqualified contact actions admitted'
 print '(a)','LOWER_PERCHED_BOTH_NEWTON_SIDES_ACTION_AND_REFUSAL_PASS'
end program
