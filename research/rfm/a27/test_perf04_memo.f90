program test_a27_perf04_memo
 use,intrinsic::iso_fortran_env,only:real64
 use MOD_grid,only:numnod,z,dz
 use mod_a27_counting_mvg
 use mod_b110_default_mvg_provider,only:b110_default_mvg_parameters_t,b110_default_mvg_provider_t,initialize_b110_default_mvg_parameters,bind_b110_default_mvg_provider
 use mod_process_hydraulic_view,only:process_hydraulic_view_t
 use mod_rfm_physical_state,only:rfm_physical_state_t
 use mod_rfm_runtime_configuration,only:rfm_runtime_configuration_t
 use mod_rfm_surface_forcing,only:rfm_surface_forcing_t
 use mod_rfm_live_trial_preparer,only:rfm_live_trial_prepare_result_t,rfm_surface_hydraulic_memo_t,prepare_rfm_live_trial
 use mod_soil_water_solver_contract,only:soil_water_top_boundary_result_t,SW_TOP_BOUNDARY_AVAILABLE,SW_TOP_BOUNDARY_REGIME_FLUX
 implicit none
 type(b110_default_mvg_parameters_t),target::hp
 type(b110_default_mvg_provider_t),target::inner
 type(counting_mvg_t)::counted
 type(process_hydraulic_view_t)::view
 type(rfm_physical_state_t)::state
 type(rfm_runtime_configuration_t)::cfg
 type(rfm_surface_forcing_t)::wet
 type(soil_water_top_boundary_result_t)::top
 type(rfm_live_trial_prepare_result_t)::r
 type(rfm_surface_hydraulic_memo_t)::memo
 real(real64)::cof(24,numnod),h(numnod),t(numnod),k(numnod),c(numnod),d(numnod),depth(numnod)
 logical::ok
 call init_cof(cof);call initialize_b110_default_mvg_parameters(hp,cof);call bind_b110_default_mvg_provider(inner,hp,.01_real64);counted%inner=>inner
 h=-150._real64-z;call inner%evaluate(h,t,k,c,d)
 view%active_nodes=numnod;allocate(view%pressure_head(numnod),view%water_content(numnod));view%pressure_head=h;view%water_content=t
 view%ponding_depth=0._real64;view%groundwater_level=-150._real64;depth=abs(z)
 call state%initialize(1,ok);if(.not.ok)error stop 'state'
 ! Isolate surface memo semantics: endpoint hydraulics are already accepted/cached.
 state%endpoint_water_cm=.02_real64
 state%wall_age_day=.03_real64
 state%wall_sorptivity_cm_sqrt_day=14._real64
 call init_cfg(cfg);wet%supplied=.true.;wet%event_active=.true.;wet%precipitation_rate_cm_per_day=8._real64;wet%runoff_exponent=1._real64
 top%status=SW_TOP_BOUNDARY_AVAILABLE;top%regime=SW_TOP_BOUNDARY_REGIME_FLUX;top%carries_surface_mass_terms=.true.;top%runoff_resolved=.true.
 top%net_potential_surface_flux=8._real64
 call reset_counts();call prepare_rfm_live_trial(state,cfg,wet,view,counted,top,depth,dz,.01_real64,1e-8_real64,r,memo)
 if(.not.r%valid.or.demand_calls/=130)error stop 'first memo fill'
 write(*,'(*(g0,:,","))')'MEMO_FIRST',demand_calls,point_calls,memo%valid
 call reset_counts();call prepare_rfm_live_trial(state,cfg,wet,view,counted,top,depth,dz,.005_real64,1e-8_real64,r,memo)
 if(.not.r%valid.or.demand_calls/=65)error stop 'identical memo hit'
 write(*,'(*(g0,:,","))')'MEMO_HIT',demand_calls,point_calls
 view%pressure_head(1)=view%pressure_head(1)+1e-12_real64
 call reset_counts();call prepare_rfm_live_trial(state,cfg,wet,view,counted,top,depth,dz,.005_real64,1e-8_real64,r,memo)
 if(.not.r%valid.or.demand_calls/=130)error stop 'changed head miss'
 write(*,'(*(g0,:,","))')'MEMO_CHANGED_HEAD',demand_calls,point_calls
 memo=rfm_surface_hydraulic_memo_t()
 call reset_counts();call prepare_rfm_live_trial(state,cfg,wet,view,counted,top,depth,dz,.005_real64,1e-8_real64,r,memo)
 if(.not.r%valid.or.demand_calls/=130)error stop 'memo clear miss'
 write(*,'(*(g0,:,","))')'MEMO_AFTER_CLEAR',demand_calls,point_calls
 print '(a)','A27_PERF04_MEMO=PASS'
contains
 subroutine init_cfg(x)
  type(rfm_runtime_configuration_t),intent(out)::x
  x%enabled=.true.;x%sigma_b=.65_real64;x%f_mb=.25_real64;x%connectivity_p=1._real64;x%z_ah_cm=20._real64;x%z_ic_cm=60._real64
  x%chi_wall=1._real64;x%exchange_length_cm=20._real64;x%mb_contact_length_cm=80._real64;x%sorptivity_panels=64;x%mb_wall_node_index=10
  x%endpoint_depth_cm=[60._real64];x%endpoint_contact_thickness_cm=[20._real64];x%endpoint_area_fraction=[.0375_real64];x%endpoint_node_index=[6]
 end subroutine
 subroutine init_cof(x)
  real(real64),intent(out)::x(:,:);integer::j
  x=0._real64
  do j=1,size(x,2)
   x(1,j)=.02_real64;x(2,j)=.42749391_real64;x(3,j)=31.22501566_real64;x(4,j)=.02165898_real64;x(5,j)=.98087016_real64;x(6,j)=1.73473668_real64
   x(7,j)=1._real64-1._real64/x(6,j);x(8,j)=x(4,j);x(10,j)=x(3,j);x(11,j)=.999_real64;x(12,j)=.99_real64*x(3,j);x(22,j)=-1e6_real64;x(23,j)=1e-12_real64
  enddo
 end subroutine
end program
