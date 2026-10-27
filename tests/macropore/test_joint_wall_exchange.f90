program test_joint_wall_exchange
  use iso_fortran_env,only:real64
  use mod_ppa_wu05a6_saturated_exchange_rate
  use mod_ppa_wu05a6_unsat_absorption_rate
  use mod_ppa_wu05a6_saturated_sources
  use mod_ppa_wu05a6_rate_bundle
  use mod_ppa_wu05a15_exchange_derivative
  use mod_macropore_standard_rate_adapter,only:unsaturated_wall_multiplier
  implicit none
  type(saturated_exchange_request_t)::s,inactive
  type(saturated_exchange_result_t)::minus,plus,old,reference
  type(saturated_sources_result_t)::sources
  type(macropore_rate_bundle_request_t)::request
  type(macropore_rate_bundle_result_t)::rates
  type(macropore_exchange_derivative_result_t)::jac
  type(unsat_absorption_result_t)::absorption,absplus,absminus
  real(real64)::fd,overlap,unsat,theta_plus,theta_minus
  s%num_domains=1;s%num_nodes=1;s%matrix_top_saturated_node=1;s%matrix_bottom_saturated_node=1
  s%step_duration=0.01_real64;s%matrix_level=-1.25_real64
  s%bottom_domain=[1];s%top_macro_saturated_node=[1]
  s%macro_saturated_fraction=[0.6_real64];s%macro_reference_level=[0.0_real64]
  s%z=[-1.0_real64];s%dz=[1.0_real64];s%matrix_head=[-1e-9_real64]
  s%ksat_horizontal=[1.0_real64];s%diameter=[10.0_real64]
  allocate(s%domain_fraction(1,1),s%cdarcy(1,1));s%domain_fraction=1;s%cdarcy=2
  call evaluate_saturated_exchange(s,old)
  call check(old%valid.and.old%qexc_to_matrix_rate_cm_per_day(1,1)==0,'legacy negative-head gate')
  call evaluate_saturated_exchange(s,minus,.true.)
  call check(minus%valid.and.abs(minus%qexc_to_matrix_rate_cm_per_day(1,1)-0.5_real64*(1+1e-9_real64))<1e-14_real64,'lower wet wall')
  s%matrix_head=1e-9_real64
  call evaluate_saturated_exchange(s,plus,.true.)
  fd=(plus%qexc_to_matrix_rate_cm_per_day(1,1)-minus%qexc_to_matrix_rate_cm_per_day(1,1))/2e-9_real64
  call check(abs(fd+0.5_real64)<1e-7_real64,'continuous h=0 derivative')
  call evaluate_saturated_exchange(s,reference)
  call evaluate_saturated_exchange(s,old,.false.)
  call check(all(old%qexc_to_matrix_rate_cm_per_day==reference%qexc_to_matrix_rate_cm_per_day),'default source exact')
  overlap=min(0.6_real64,0.25_real64)
  unsat=0.6_real64*unsaturated_wall_multiplier(0.6_real64,0.25_real64)
  call check(abs(overlap+unsat-0.6_real64)<1e-15_real64,'complementary wet wall areas')
  call check(unsaturated_wall_multiplier(0.2_real64,0.8_real64)==0,'macro water entirely under matrix water')
  call check(unsaturated_wall_multiplier(0.0_real64,0.8_real64)==0,'dry macro wall')
  inactive=s;inactive%matrix_bottom_saturated_node=0
  call evaluate_saturated_sources(s,inactive,sources,.true.)
  call check(sources%valid.and.abs(sources%qout_matrix_sat_rate(1,1)-plus%qexc_to_matrix_rate_cm_per_day(1,1))<1e-14_real64,'perched absorption booked')
  call check(all(sources%qexc_sat_to_matrix_rate==sources%qout_matrix_sat_rate-sources%qin_interflow_rate-sources%qin_matrix_sat_rate),'signed source conservation')
  ! Real production derivative, with the ordinary partial-top geometry fixed.
  request%matrix_sat=s;request%unsaturated%continuous_sorption=.true.
  associate(u=>request%unsaturated,r=>request%unsaturated%sorptivity)
    r%num_domains=1;r%num_nodes=1;r%top_node=1;r%matrix_top_saturated_node=1
    r%step_duration=0.01_real64;r%bottom_domain=[1];r%top_water_node=[1]
    r%theta=[0.5_real64];r%theta_s=[0.5_real64];r%theta_r=[0.1_real64]
    r%dz=[1.0_real64];r%diameter=[10.0_real64];r%wall_correction=[1.0_real64]
    r%sorptivity_max=[1.0_real64];r%sorptivity_alpha=[0.5_real64]
    allocate(r%domain_fraction(1,1),r%wet_fraction(1,1),r%history_sorptivity(1,1),r%history_theta_ref(1,1),r%history_absorption_time(1,1))
    r%domain_fraction=1;r%wet_fraction=1;r%history_sorptivity=0;r%history_theta_ref=0;r%history_absorption_time=0
    u%pressure_head=s%matrix_head;u%elevation=s%z;u%conductivity=[1.0_real64]
    u%entry_head=[-10.0_real64];u%groundwater_level_domain=[0.0_real64];u%sorp_fac_parallel=[1.0_real64]
  end associate
  rates%valid=.true.;allocate(rates%qout_unsat_rate(1,1),rates%qout_sat_rate(1,1),rates%qin_matrix_sat_rate(1,1))
  rates%qout_unsat_rate=0;rates%qin_matrix_sat_rate=0
  rates%qout_sat_rate=plus%qexc_to_matrix_rate_cm_per_day
  request%matrix_sat%matrix_head=-1e-9_real64
  call evaluate_macropore_exchange_derivative(request,rates,[0.0_real64],jac)
  call check(jac%valid.and.abs(jac%total_dqdh_node(1)+0.5_real64)<1e-8_real64,'partial-top production Jacobian')
  ! The historical saturation cutoff is now a bounded C1 source gate;
  ! verify its chain derivative against actual production absorption rates.
  request%matrix_sat%matrix_bottom_saturated_node=0
  request%unsaturated%sorptivity%matrix_top_saturated_node=2
  request%unsaturated%sorptivity%theta=0.5_real64-5e-9_real64
  request%unsaturated%sorptivity%history_absorption_time=1
  request%unsaturated%sorptivity%history_theta_ref=0.5001_real64
  call evaluate_unsat_absorption(request%unsaturated,absorption)
  call check(absorption%valid,'saturation centre rate')
  rates%unsaturated=absorption;rates%qout_unsat_rate=absorption%selected_rate_cm_per_day
  rates%qout_sat_rate=0
  call evaluate_macropore_exchange_derivative(request,rates,[0.001_real64],jac)
  call check(jac%valid,'saturation production derivative')
  theta_plus=request%unsaturated%sorptivity%theta(1)+1e-11_real64
  theta_minus=request%unsaturated%sorptivity%theta(1)-1e-11_real64
  request%unsaturated%sorptivity%theta=theta_plus
  call evaluate_unsat_absorption(request%unsaturated,absplus)
  request%unsaturated%sorptivity%theta=theta_minus
  call evaluate_unsat_absorption(request%unsaturated,absminus)
  fd=0.001_real64*(absplus%selected_rate_cm_per_day(1,1)-absminus%selected_rate_cm_per_day(1,1))/(theta_plus-theta_minus)
  call check(abs(jac%total_dqdh_node(1)-fd)<1e-5_real64*abs(fd),'saturation gate real-rate finite difference')
  print *,'JOINT_WALL_EXCHANGE_PASS' 
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
