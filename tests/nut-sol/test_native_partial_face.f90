program native_partial_face
 use iso_fortran_env,only:real64
 use mod_column_swp_macro_configuration
 use mod_column_swp_macro_initial
 use mod_fmr_macropore_configuration
 use mod_ppa_wu05a5_multi_domain_process,only:macropore_geometry_result_t,evaluate_macropore_geometry
 use mod_soil_water_solver_contract,only:soil_water_physical_state_t
 use mod_macropore_standard_rate_adapter,only:matrix_saturated_zone_view_t,prepare_standard_macropore_rate_request
 use mod_ppa_wu05a6_rate_bundle,only:macropore_rate_bundle_request_t,macropore_rate_bundle_result_t, &
  evaluate_macropore_rate_bundle
 implicit none
 type(native_macro_initial_t)::initial
 type(fmr_macropore_physical_config_t)::config
 type(macropore_geometry_result_t)::geometry
 type(soil_water_physical_state_t)::matrix
 type(matrix_saturated_zone_view_t)::v1,v2
 type(macropore_rate_bundle_request_t)::r1,r2
 type(macropore_rate_bundle_result_t)::q1,q2
 character(1024)::path
 real(real64)::delta
 integer::n
 logical::ok
 call get_command_argument(1,path)
 call import_column_macro_configuration(trim(path),initial,config)
 n=initial%geometry%num_nodes
 call evaluate_macropore_geometry(initial%geometry,initial%state%dynamic_volume_cp,geometry)
 if(.not.geometry%valid)error stop 'invalid geometry'
 matrix%active_nodes=n
 allocate(matrix%pressure_head(n),matrix%water_content(n))
 matrix%pressure_head=-44._real64-initial%z
 matrix%pressure_head(39)=-0.74_real64
 matrix%water_content=initial%theta;matrix%ponding_depth=0._real64
 config%rate_template%unsaturated%entry_transition_width_cm=1.e-4_real64
 matrix%groundwater_level=-44._real64-1.e-6_real64
 call prepare_standard_macropore_rate_request(config%rate_template,initial%state,geometry,initial%storage, &
  matrix,initial%z,initial%geometry%dz,1.e-4_real64,r1,v1,ok)
 if(.not.ok)error stop 'lower face request invalid'
 matrix%groundwater_level=-44._real64+1.e-6_real64
 call prepare_standard_macropore_rate_request(config%rate_template,initial%state,geometry,initial%storage, &
  matrix,initial%z,initial%geometry%dz,1.e-4_real64,r2,v2,ok)
 if(.not.ok)error stop 'upper face request invalid'
 if(v1%top_node/=40.or.v2%top_node/=39)error stop 'not testing source face'
 if(r1%unsaturated%sorptivity%matrix_top_saturated_node/=40.or. &
    r2%unsaturated%sorptivity%matrix_top_saturated_node/=40)error stop 'partial top not included'
 delta=maxval(abs(r1%unsaturated%sorptivity%domain_fraction(:,39)- &
   r2%unsaturated%sorptivity%domain_fraction(:,39)))
 if(delta>1.e-6_real64)error stop 'partial area discontinuity'
 call evaluate_macropore_rate_bundle(r1,q1);call evaluate_macropore_rate_bundle(r2,q2)
 if(.not.q1%valid.or..not.q2%valid)error stop 'source evaluation invalid'
 delta=maxval(abs(sum(q1%qexc_to_matrix_rate-q2%qexc_to_matrix_rate,dim=1)))
 if(delta>1.e-5_real64)error stop 'source discontinuity'
 config%rate_template%unsaturated%entry_transition_width_cm=0._real64
 call prepare_standard_macropore_rate_request(config%rate_template,initial%state,geometry,initial%storage, &
  matrix,initial%z,initial%geometry%dz,1.e-4_real64,r2,v2,ok)
 if(.not.ok.or.r2%unsaturated%sorptivity%matrix_top_saturated_node/=39)error stop 'literal default changed'
 print '(a,1x,es24.16e3)','PARTIAL_FACE_RATE_PASS',delta
end program
