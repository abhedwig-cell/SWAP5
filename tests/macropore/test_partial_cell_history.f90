program test_partial_cell_history
  use iso_fortran_env,only:real64
  use mod_macropore_continuation_state
  use mod_ppa_wu05a5_multi_domain_process,only:macropore_geometry_result_t
  use mod_macropore_standard_storage,only:macropore_standard_storage_view_t
  use mod_macropore_standard_rate_adapter
  use mod_ppa_wu05a6_rate_bundle,only:macropore_rate_bundle_request_t
  use mod_ppa_wu05a6_sorptivity_history
  use mod_ppa_wu05a6_unsat_absorption_rate,only:unsat_absorption_result_t
  implicit none
  type(macropore_continuation_state_t)::a,c,legacy
  type(macropore_geometry_result_t)::g
  type(macropore_standard_storage_view_t)::v
  type(matrix_saturated_zone_view_t)::m
  type(macropore_rate_bundle_request_t)::rates
  type(sorptivity_history_update_request_t)::template,r,old
  type(unsat_absorption_result_t)::absorption
  logical::ok
  call a%initialize(1,3,ok);call check(ok,'initial state')
  call copy_macropore_continuation_state(a,c,ok);call check(ok,'copy')
  call copy_macropore_continuation_state(a,legacy,ok)
  a%absorption_time=1;a%theta_sorption_ref=0.5_real64;a%sorptivity=1
  g%valid=.true.;g%num_nodes=3;g%bottom_domain=[3]
  v%valid=.true.;v%top_water_node=[1];allocate(v%wet_fraction(1,3));v%wet_fraction=1
  m%valid=.true.;m%active=.true.;m%top_node=2;m%bottom_node=3
  template%num_nodes=3;template%num_domains=1;template%top_node=1
  template%wall_correction=[1.0_real64,1.0_real64,1.0_real64]
  template%diameter=[10.0_real64,10.0_real64,10.0_real64]
  allocate(template%domain_fraction(1,3));template%domain_fraction=1
  rates%unsaturated%entry_transition_width_cm=1e-4_real64
  rates%unsaturated%continuous_sorption=.true.
  rates%unsaturated%sorptivity%matrix_top_saturated_node=3
  allocate(rates%unsaturated%sorptivity%domain_fraction(1,3))
  rates%unsaturated%sorptivity%domain_fraction=1
  rates%unsaturated%sorptivity%domain_fraction(1,2)=0.25_real64
  call prepare_standard_sorptivity_history_request(template,g,v,m,0.01_real64,old,ok)
  call check(ok.and.old%matrix_top_saturated_node==2,'legacy geometric cutoff')
  call prepare_standard_sorptivity_history_request(template,g,v,m,0.01_real64,r,ok,rates)
  call check(ok.and.r%matrix_top_saturated_node==3,'partial top retained')
  call check(r%domain_fraction(1,2)==0.25_real64,'same wall fraction')
  absorption%valid=.true.
  allocate(absorption%end_event(1,3),absorption%seed_sorptivity(1,3),absorption%seed_theta_ref(1,3))
  absorption%end_event=.false.;absorption%seed_sorptivity=1;absorption%seed_theta_ref=0.5_real64
  call apply_sorptivity_history_update(old,a,absorption,legacy,ok)
  call check(ok.and.legacy%absorption_time(1,2)==0,'old cutoff resets partial top')
  call apply_sorptivity_history_update(r,a,absorption,c,ok,.true.)
  call check(ok.and.c%absorption_time(1,2)==1.01_real64,'partial history advances')
  call check(c%theta_sorption_ref(1,2)>0.5_real64,'partial history seed advances')
  call check(c%absorption_time(1,3)==0,'saturated history resets')
  call check(all(a%absorption_time==1),'immutable accepted origin')
  r%step_duration=0
  call apply_sorptivity_history_update(r,a,absorption,c,ok,.true.)
  call check(.not.ok.and.c%absorption_time(1,2)==1.01_real64,'invalid trial atomic')
  rates%unsaturated%continuous_sorption=.false.
  call prepare_standard_sorptivity_history_request(template,g,v,m,0.01_real64,r,ok,rates)
  call check(ok.and.r%matrix_top_saturated_node==old%matrix_top_saturated_node,'zero width legacy exact')
  call check(all(r%domain_fraction==old%domain_fraction),'zero width fractions exact')
  print *,'PARTIAL_CELL_HISTORY_PASS'
contains
  subroutine check(ok,msg)
    logical,intent(in)::ok
    character(*),intent(in)::msg
    if(.not.ok)then
      print *,msg
      error stop 1
    end if
  end subroutine
end program
