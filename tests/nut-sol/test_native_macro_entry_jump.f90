! Diagnostic counterexample, not a replacement physical law or admission test.
! Keep original 112-node coefficients; isolate the Darcy gate at source node44.
program native_macro_entry_jump
 use iso_fortran_env,only:real64
 use mod_column_swp_macro_configuration
 use mod_column_swp_macro_initial
 use mod_fmr_macropore_configuration
 use mod_ppa_wu05a6_unsat_absorption_rate
 implicit none
 type(native_macro_initial_t)::initial
 type(fmr_macropore_physical_config_t)::config
 type(unsat_absorption_request_t)::request
 type(unsat_absorption_result_t)::below,above
 character(1024)::path
 real(real64)::threshold,qbelow,qabove
 integer,parameter::node=44,domain=1
 call get_command_argument(1,path)
 call import_column_macro_configuration(trim(path),initial,config)
 if(initial%geometry%num_nodes/=112)error stop 'requires original source grid'
 request=config%rate_template%unsaturated
 request%sorptivity%matrix_top_saturated_node=113
 request%sorptivity%top_water_node=1
 request%sorptivity%wet_fraction=1._real64
 request%sorptivity%theta=initial%theta
 ! An aged, valid absorption history isolates Darcy from a new sorptivity pulse.
 request%sorptivity%history_absorption_time=1.e8_real64
 request%sorptivity%history_theta_ref=spread(initial%theta,1,initial%geometry%num_domains)
 request%sorptivity%history_sorptivity=0._real64
 request%groundwater_level_domain=0._real64
 request%sorptivity%theta(node)=0.44392771364547712_real64
 threshold=request%entry_head(node)-1.e-8_real64
 request%pressure_head(node)=threshold-1.e-8_real64
 call evaluate_unsat_absorption(request,below)
 request%pressure_head(node)=threshold+1.e-8_real64
 call evaluate_unsat_absorption(request,above)
 if(.not.below%valid.or..not.above%valid)error stop 'invalid production request'
 qbelow=below%selected_rate_cm_per_day(domain,node)
 qabove=above%selected_rate_cm_per_day(domain,node)
 if(qbelow<=0._real64.or.qabove/=0._real64)error stop 'source entry jump not reproduced'
 if(below%selected_by_sorptivity(domain,node))error stop 'Darcy branch not isolated'
 print '(a,3(1x,es25.17e3))','NATIVE_ENTRY_DARCY_JUMP',threshold,qbelow,qabove
 print '(a)','DIAGNOSTIC_ONLY_NOT_A_PHYSICAL_REPAIR'
end program
