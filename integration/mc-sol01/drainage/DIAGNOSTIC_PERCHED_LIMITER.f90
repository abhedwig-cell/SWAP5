program native_perched_jacobian
 use iso_fortran_env,only:real64
 use mod_column_swp_macro_configuration
 use mod_column_swp_macro_initial
 use mod_fmr_macropore_configuration
 use mod_ppa_wu05a6_rate_bundle
 use mod_ppa_wu05a6_saturated_exchange_rate
 use mod_ppa_wu05a15_exchange_derivative
 implicit none
 type(native_macro_initial_t)::initial
 type(fmr_macropore_physical_config_t)::config
 type(macropore_rate_bundle_request_t)::request
 type(macropore_rate_bundle_result_t)::rates, limited,limited_plus,limited_minus
 type(macropore_exchange_derivative_result_t)::derivative
 type(saturated_exchange_result_t)::center,plus,minus
 real(real64),allocatable::capacity(:)
 real(real64)::dh,fd,err
 integer::n,nd,k
 character(1024)::path
 call get_command_argument(1,path)
 call import_column_macro_configuration(trim(path),initial,config)
 request=config%rate_template;n=initial%geometry%num_nodes;nd=initial%geometry%num_domains;k=24
 allocate(capacity(n));capacity=0._real64
 request%interflow_sat%matrix_top_saturated_node=k-1
 request%interflow_sat%matrix_bottom_saturated_node=k+1
 request%interflow_sat%matrix_partial_top_active=.false.
 request%interflow_sat%matrix_head(k)=0.35_real64
 request%interflow_sat%macro_reference_level=-1000._real64
 request%unsaturated%sorptivity%perched_active=.true.
 request%unsaturated%sorptivity%perched_top_node=k-1
 request%unsaturated%sorptivity%perched_bottom_node=k+1
 request%unsaturated%entry_transition_width_cm=1.e-4_real64
 call evaluate_saturated_exchange(request%interflow_sat,center)
 if(.not.center%valid)error stop 'invalid production saturated exchange'
 allocate(rates%qout_unsat_rate(nd,n),rates%qout_sat_rate(nd,n),rates%qin_matrix_sat_rate(nd,n), &
          rates%qin_interflow_rate(nd,n))
 rates%valid=.true.;rates%qout_unsat_rate=0._real64;rates%qout_sat_rate=0._real64
 rates%qin_matrix_sat_rate=0._real64
 rates%qin_interflow_rate=center%matrix_to_macro_amount_cm/request%interflow_sat%step_duration
 call evaluate_macropore_exchange_derivative(request,rates,capacity,derivative,.true.)
 if(.not.derivative%valid.or..not.derivative%perched_derivative_included)error stop 'missing perched derivative'
 dh=1.e-6_real64
 request%interflow_sat%matrix_head(k)=0.35_real64+dh
 call evaluate_saturated_exchange(request%interflow_sat,plus)
 request%interflow_sat%matrix_head(k)=0.35_real64-dh
 call evaluate_saturated_exchange(request%interflow_sat,minus)
 fd=sum(plus%qexc_to_matrix_rate_cm_per_day(:,k)-minus%qexc_to_matrix_rate_cm_per_day(:,k))/(2._real64*dh)
 err=abs(fd-derivative%total_dqdh_node(k))
 if(err>1.e-7_real64)error stop 'perched derivative mismatch'
 request%interflow_sat%matrix_head(k)=0.35_real64
 call evaluate_macropore_exchange_derivative(request,rates,capacity,derivative)
 if(.not.derivative%valid.or.derivative%perched_derivative_included)error stop 'width enabled numerical option'
 if(derivative%total_dqdh_node(k)/=0._real64)error stop 'default derivative changed'
 request%unsaturated%entry_transition_width_cm=0._real64
 call evaluate_macropore_exchange_derivative(request,rates,capacity,derivative,.true.)
 if(.not.derivative%valid.or..not.derivative%perched_derivative_included)error stop 'option depends on width'
 if(abs(fd-derivative%total_dqdh_node(k))>1.e-7_real64)error stop 'zero-width option mismatch'
 request%unsaturated%entry_transition_width_cm=1.e-4_real64
 request%unsaturated%sorptivity%matrix_top_saturated_node=1
 request%interflow_sat%matrix_head=0._real64
 request%interflow_sat%matrix_head(k)=0.35_real64
 request%rapid%enabled=.false.
 request%limiter%accepted_storage_cm=0._real64
 request%limiter%minimum_storage_cm=0._real64
 request%limiter%potential_top_vertical_cm=0._real64
 request%limiter%potential_top_lateral_cm=0._real64
 request%limiter%redistribution_capacity_cm=0._real64
 call evaluate_saturated_exchange(request%interflow_sat,center)
 request%limiter%maximum_storage_cm=0.5_real64*center%matrix_to_macro_amount_cm(:,k)
 call evaluate_macropore_rate_bundle(request,limited)
 if(.not.limited%valid)error stop 'limited bundle invalid'
 call evaluate_macropore_exchange_derivative(request,limited,capacity,derivative,.true.)
 request%interflow_sat%matrix_head(k)=0.35_real64+dh
 call evaluate_macropore_rate_bundle(request,limited_plus)
 request%interflow_sat%matrix_head(k)=0.35_real64-dh
 call evaluate_macropore_rate_bundle(request,limited_minus)
 if(.not.limited_plus%valid.or..not.limited_minus%valid)error stop 'limited perturbed bundle invalid'
 fd=sum(limited_plus%qexc_to_matrix_rate(:,k)-limited_minus%qexc_to_matrix_rate(:,k))/(2._real64*dh)
 print *, 'LIMITER_PROBE',minval(limited%limiter%inflow_fraction),fd,derivative%total_dqdh_node(k)
 print '(a)','LIMITER_DIAGNOSTIC_COMPLETED'
end program
