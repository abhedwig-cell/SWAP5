program test_ppa_wu05a6_sorptivity_history
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_macropore_continuation_state, only: macropore_continuation_state_t
  use mod_ppa_wu05a6_unsat_absorption_rate, only: unsat_absorption_result_t
  use mod_ppa_wu05a6_sorptivity_history, only: sorptivity_history_update_request_t, &
       apply_sorptivity_history_update
  implicit none

  type(macropore_continuation_state_t)::accepted,candidate
  type(unsat_absorption_result_t)::absorption
  type(sorptivity_history_update_request_t)::request
  logical::ok
  real(real64)::expected

  call accepted%initialize(1,3,ok)
  if(.not.ok)error stop 'A6 history init'
  candidate=accepted
  accepted%absorption_time(1,1)=0.0_real64
  accepted%sorptivity(1,1)=0.0_real64
  accepted%theta_sorption_ref(1,1)=0.0_real64
  candidate=accepted

  absorption%valid=.true.
  allocate(absorption%end_event(1,3),absorption%seed_sorptivity(1,3),absorption%seed_theta_ref(1,3))
  absorption%end_event=.true.
  absorption%seed_sorptivity=0.0_real64
  absorption%seed_theta_ref=0.0_real64
  absorption%end_event(1,1)=.false.
  absorption%seed_sorptivity(1,1)=0.4_real64
  absorption%seed_theta_ref(1,1)=0.45_real64

  request%num_domains=1
  request%num_nodes=3
  request%top_node=1
  request%matrix_top_saturated_node=4
  request%step_duration=0.1_real64
  allocate(request%bottom_domain(1),request%top_water_node(1),request%wall_correction(3), &
       request%wet_fraction(1,3),request%domain_fraction(1,3),request%diameter(3))
  request%bottom_domain=3
  request%top_water_node=1
  request%wall_correction=0.95_real64
  request%wet_fraction=1.0_real64
  request%domain_fraction=0.2_real64
  request%diameter=4.0_real64

  call apply_sorptivity_history_update(request,accepted,absorption,candidate,ok)
  if(.not.ok)error stop 'A6 history update'
  expected=0.45_real64 + 0.95_real64*0.2_real64*(4.0_real64/4.0_real64)*0.4_real64*sqrt(0.1_real64)
  if(abs(candidate%theta_sorption_ref(1,1)-expected)>1.0e-12_real64) &
       error stop 'A6 history theta ref'
  if(abs(candidate%absorption_time(1,1)-0.1_real64)>1.0e-12_real64) &
       error stop 'A6 history time'
  if(abs(candidate%sorptivity(1,1)-0.4_real64)>1.0e-12_real64) &
       error stop 'A6 history sorptivity'

  absorption%end_event(1,1)=.true.
  candidate=accepted
  call apply_sorptivity_history_update(request,accepted,absorption,candidate,ok)
  if(abs(candidate%absorption_time(1,1))+abs(candidate%sorptivity(1,1))+ &
     abs(candidate%theta_sorption_ref(1,1))>1.0e-15_real64) &
       error stop 'A6 history event reset'

  print '(a)', 'PPA_WU05A6_SORPTIVITY_HISTORY=PASS'
end program test_ppa_wu05a6_sorptivity_history
