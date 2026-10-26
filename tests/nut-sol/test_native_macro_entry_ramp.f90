! Production rate/Jacobian feedback for the explicit corrected-source variant.
program native_macro_entry_ramp
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_column_swp_macro_configuration
 use mod_column_swp_macro_initial
 use mod_fmr_macropore_configuration
 use mod_ppa_wu05a6_unsat_absorption_rate
 use mod_ppa_wu05a6_rate_bundle
 use mod_ppa_wu05a15_exchange_derivative
 implicit none
 type(native_macro_initial_t)::initial
 type(fmr_macropore_physical_config_t)::config
 type(macropore_rate_bundle_request_t)::request
 type(macropore_rate_bundle_result_t)::rates
 type(unsat_absorption_result_t)::reference,current,plus,minus
 type(macropore_exchange_derivative_result_t)::derivative
 character(1024)::path
 real(real64)::threshold,h0,width,fd,step,q0,relative_error,worst
 real(real64),allocatable::capacity(:)
 integer::i,j,n,nd
 integer,parameter::node=44,domain=1
 call get_command_argument(1,path)
 call import_column_macro_configuration(trim(path),initial,config)
 request=config%rate_template;n=initial%geometry%num_nodes;nd=initial%geometry%num_domains
 allocate(capacity(n));capacity=0._real64
 request%unsaturated%sorptivity%matrix_top_saturated_node=n+1
 request%unsaturated%sorptivity%top_water_node=1
 request%unsaturated%sorptivity%wet_fraction=1._real64
 request%unsaturated%sorptivity%theta=initial%theta
 request%unsaturated%sorptivity%history_absorption_time=1.e8_real64
 request%unsaturated%sorptivity%history_theta_ref=spread(initial%theta,1,nd)
 request%unsaturated%sorptivity%history_sorptivity=0._real64
 request%unsaturated%groundwater_level_domain=0._real64
 request%unsaturated%sorptivity%theta(node)=0.44392771364547712_real64
 threshold=request%unsaturated%entry_head(node)-1.e-8_real64
 request%unsaturated%entry_transition_width_cm=-1._real64
 if(request%unsaturated%valid())error stop 'negative width admitted'
 request%unsaturated%entry_transition_width_cm=.002_real64
 if(request%unsaturated%valid())error stop 'overwide ramp admitted'
 request%unsaturated%entry_transition_width_cm=ieee_value(0._real64,ieee_quiet_nan)
 if(request%unsaturated%valid())error stop 'NaN width admitted'
 allocate(rates%qout_unsat_rate(nd,n),rates%qout_sat_rate(nd,n),rates%qin_matrix_sat_rate(nd,n))
 rates%qout_sat_rate=0._real64;rates%qin_matrix_sat_rate=0._real64;worst=0._real64
 do j=1,2
  width=1.e-4_real64
  if(j==2)width=1.e-5_real64
  do i=1,7
   h0=threshold-(real(i,real64)-1._real64)*width/4._real64
   request%unsaturated%pressure_head(node)=h0
   request%unsaturated%entry_transition_width_cm=0._real64
   call evaluate_unsat_absorption(request%unsaturated,reference)
   request%unsaturated%entry_transition_width_cm=width
   call evaluate_unsat_absorption(request%unsaturated,current)
   if(.not.reference%valid.or..not.current%valid)error stop 'invalid rate fixture'
   if(i==1.or.i>=5)then
    if(any(reference%selected_rate_cm_per_day/=current%selected_rate_cm_per_day)) &
      error stop 'exterior historical law changed'
   end if
   if(i>1.and.i<5)then
    step=width*1.e-4_real64
    request%unsaturated%pressure_head(node)=h0+step
    call evaluate_unsat_absorption(request%unsaturated,plus)
    request%unsaturated%pressure_head(node)=h0-step
    call evaluate_unsat_absorption(request%unsaturated,minus)
    request%unsaturated%pressure_head(node)=h0
    fd=(plus%selected_rate_cm_per_day(domain,node)-minus%selected_rate_cm_per_day(domain,node))/(2._real64*step)
    rates%valid=.true.;rates%unsaturated=current;rates%qout_unsat_rate=current%selected_rate_cm_per_day
    call evaluate_macropore_exchange_derivative(request,rates,capacity,derivative)
    if(.not.derivative%valid)error stop 'production Jacobian unavailable'
    q0=derivative%unsaturated_dqdh(domain,node)
    relative_error=abs(fd-q0)/max(1._real64,abs(fd));worst=max(worst,relative_error)
    if(relative_error>2.e-6_real64)error stop 'ramp Jacobian differs from actual production residual'
   end if
  end do
 end do
 print '(a,1x,es25.17e3)','NATIVE_ENTRY_RAMP_RATE_JACOBIAN_PASS',worst
end program
