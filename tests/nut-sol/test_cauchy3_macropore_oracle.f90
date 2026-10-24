program test_cauchy3_macropore_oracle
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_macropore_continuation_state, only: macropore_continuation_state_t
  use mod_macropore_dynamic_shrinkage, only: prepare_clay_kim_option1, map_surface_crack_depth_to_node, &
       SHRINK_PEAT_DIRECT, SHRINK_PEAT_SEGMENTS, SHRINK_RIGID, SHRINK_KIM, &
       prepare_clay_kim_option2, prepare_peat_characteristic_points, &
       derive_dynamic_minimum_subsidence
  use mod_ppa_wu05a5_multi_domain_process, only: macropore_geometry_config_t, &
       macropore_geometry_result_t, evaluate_macropore_geometry
  use mod_ppa_wu05a6_rate_bundle, only: macropore_rate_bundle_request_t
  use mod_ppa_wu05a6_sorptivity_history, only: sorptivity_history_update_request_t
  use mod_macropore_standard_storage, only: macropore_standard_storage_view_t, &
       canonicalize_macropore_standard_storage
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t
  use mod_kernel_committed_persistence, only: kernel_persistence_snapshot_t, export_kernel_committed_state, &
       restore_kernel_committed_state, KERNEL_PERSISTENCE_OK
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_OPTIONAL_STATE_LAYOUT_MACROPORE, FMR_OPTIONAL_STATE_LAYOUT_BOESTEN_MACROPORE, &
       FMR_OPTIONAL_STATE_LAYOUT_RUTTER_BOESTEN_MACROPORE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_serialized_reference_backend_t, &
       fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, fmr_b110_physical_state_t, &
       fmr_new_b110_committed_state, prepare_fmr_b110_default_mvg, &
       fmr_new_b110_boesten_macropore_committed_state, fmr_b110_boesten_macropore_state_t
  use mod_restricted_surface_evaporation, only: boesten_evaporation_state_t
  use mod_interception_source_window_runtime, only: interception_source_window_t, initialize_interception_window
  use mod_rutter_source_window_processor, only: initialize_rutter_canopy_state, RUTTER_WINDOW_OK
  use mod_fmr_macropore_configuration, only: fmr_macropore_physical_config_t, prepare_fmr_macropore_rapid_reference
  use mod_fmr_macropore_top_input, only: fmr_macropore_top_input_forcing_t
  use mod_fmr_restart_state_contract, only: fmr_restart_state_matches_template
  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t, fmr_export_committed_restart, &
       fmr_restore_committed_restart, FMR_RESTART_OK
  use mod_macropore_single_column_runtime, only: macropore_single_column_runtime_t, &
       macropore_runtime_policy_t, macropore_runtime_result_t, MACRO_RUNTIME_INACTIVE, &
       MACRO_RUNTIME_CONVERGED
  use variables,only:context_qrot=>qrot
  implicit none
  character(len=1)::constitutive_flag,fit_flag,cover_flag
  integer::macro_top=1
  logical::migmac10=.false.
  logical::migmac10_rutter=.false.
  logical::migmac11=.false.
  logical::inner_route=.false.

  real(real64),parameter::dt=1.0e-3_real64,tol=1.0e-12_real64
  integer,parameter::nd=1

  type(soil_water_parameter_set_t),target::params
  type(b110_default_mvg_parameters_t),target::hp
  type(b110_default_mvg_provider_t),target::hyd
  type(b110_source_sink_provider_t),target::base_source
  type(fixed_flux_top_boundary_provider_t),target::top
  type(reference_richards_legacy_solver_t)::solver
  type(reference_richards_legacy_workspace_t)::workspace
  type(soil_water_solve_request_t)::request,direct_request
  type(soil_water_solve_result_t)::direct_result
  type(macropore_continuation_state_t)::macro,macro_snapshot
  type(macropore_geometry_config_t)::geometry_config
  type(macropore_geometry_result_t)::geometry
  type(macropore_rate_bundle_request_t)::rate_template
  type(sorptivity_history_update_request_t)::history_request
  type(macropore_single_column_runtime_t)::runtime
  type(macropore_runtime_policy_t)::policy
  type(macropore_runtime_result_t)::result
  type(macropore_standard_storage_view_t)::initial_macro_view
  real(real64),allocatable,target::qdra(:,:),qssdi(:),qrot(:)
  real(real64),allocatable::cofgen(:,:)
  real(real64),allocatable::heads(:),water(:),cond(:),cap(:),dkdh(:)
  integer::i
  logical::ok
  logical::dynamic_enabled
  character(len=1)::dynamic_flag

  integer::ia,ir,ih,ix,half,case_count,j
  real(real64)::area,aq,resistance,extra,expected,half_r,conductance
  real(real64)::faces(5),cell(4),matrix_delta,macro_delta,matrix_res,macro_res,gross
  real(real64)::worst_cell=0d0,worst_robin=0d0,worst_matrix=0d0,worst_macro=0d0,worst_gross=0d0
  real(real64),parameter::areas(3)=[.55d0,.75d0,.95d0]
  numnod=4
  allocate(z(4),dz(4),disnod(5),heads(4),water(4),cond(4),cap(4),dkdh(4),context_qrot(4))
  z=[-.25d0,-.75d0,-1.5d0,-2.5d0];dz=[.5d0,.5d0,1d0,1d0]
  disnod=[.25d0,.5d0,.75d0,1d0,.5d0];context_qrot=0d0
  call get_environment_variable('WU05_MIGMAC08_COVER',cover_flag)
  if(cover_flag=='1' .or. cover_flag=='2')macro_top=3
  fit_flag='0'
  call get_environment_variable('WU05_MIGMAC04_FIT',fit_flag)
  constitutive_flag='0'
  call get_environment_variable('WU05_MIGMAC03_LAW',constitutive_flag)
  dynamic_flag='0'
  call get_environment_variable('WU05_MIGMAC02_DYNAMIC',dynamic_flag)
  dynamic_enabled=dynamic_flag=='1'
  block
    character(len=1)::m10_flag
    character(len=1)::rutter_flag
    m10_flag='0'
    rutter_flag='0'
    call get_environment_variable('WU05_MIGMAC10',m10_flag)
    migmac10=m10_flag=='1'
    call get_environment_variable('WU05_MIGMAC10_RUTTER',rutter_flag)
    migmac10_rutter=rutter_flag=='1'
    if(migmac10_rutter)migmac10=.true.
    block
      character(len=1)::m11_flag
      m11_flag='0'
      call get_environment_variable('WU05_MIGMAC11',m11_flag)
      migmac11=m11_flag=='1'
      if(migmac11)migmac10=.true.
    end block
  end block
  inner_route=dynamic_enabled .or. dynamic_flag=='3'
  allocate(params%z(numnod),params%dz(numnod),params%node_distance(numnod),cofgen(24,numnod))
  params%parameter_set_id=505701_int64
  params%active_nodes=numnod
  params%z=z; params%dz=dz; params%node_distance=disnod(1:numnod)

  cofgen=0.0_real64
  do i=1,numnod
    cofgen(1,i)=0.02_real64; cofgen(2,i)=0.427494_real64; cofgen(3,i)=31.225016_real64
    cofgen(4,i)=0.021659_real64; cofgen(5,i)=0.98087_real64; cofgen(6,i)=1.734737_real64
    cofgen(7,i)=1.0_real64-1.0_real64/cofgen(6,i); cofgen(8,i)=cofgen(4,i)
    cofgen(10,i)=cofgen(3,i); cofgen(11,i)=0.999_real64; cofgen(12,i)=0.99_real64*cofgen(3,i)
    cofgen(22,i)=-1.0e6_real64; cofgen(23,i)=1.0e-12_real64
  end do
  call initialize_b110_default_mvg_parameters(hp,cofgen)
  call bind_b110_default_mvg_provider(hyd,hp,dt)

  heads=-100.0_real64
  call hyd%evaluate(heads,water,cond,cap,dkdh)

  allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod))
  qdra=0.0_real64; qssdi=0.0_real64; qrot=0.0_real64
  call bind_b110_source_sink_provider(base_source,qdra,qssdi,qrot)

  request%parameters=>params
  request%base_state%active_nodes=numnod
  allocate(request%base_state%pressure_head(numnod),request%base_state%water_content(numnod))
  request%base_state%pressure_head=heads
  request%base_state%water_content=water
  request%base_state%ponding_depth=0.0_real64
  request%base_state%groundwater_level=-200.0_real64
  request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
  request%boundary%bottom_mode=7
  request%boundary%top_flux=0.0_real64
  request%boundary%bottom_head=-100.0_real64
  request%physical%macropore_active=.false.
  request%numerical%max_iterations=64
  request%numerical%max_backtracking=24
  request%numerical%conductivity_implicit_mode=0
  request%numerical%conductivity_mean_method=1
  request%numerical%min_step_duration=1.0e-12_real64
  request%numerical%compartment_balance_tolerance=tol
  request%numerical%total_balance_tolerance=tol
  request%numerical%head_abs_tolerance=tol
  request%numerical%head_rel_tolerance=tol
  request%numerical%ponding_tolerance=tol
  request%evaluation%constitutive=>hyd
  request%evaluation%source_sink=>base_source
  request%evaluation%top_boundary=>top
  request%step_duration=dt

  call macro%initialize(nd,numnod,ok)
  if(.not.ok)error stop 'A7 real macro init'
  macro%dynamic_volume_cp=0.0_real64

  call setup_geometry(geometry_config)
  call evaluate_macropore_geometry(geometry_config,macro%dynamic_volume_cp,geometry)
  if(.not.geometry%valid)error stop 'A7 real geometry'
  macro%icp_bottom_domain=geometry%bottom_domain
  macro%volume_domain_cp=geometry%volume_domain_cp
  macro%water_domain_cp=0.35_real64*geometry%volume_domain_cp
  call canonicalize_macropore_standard_storage(macro,macro_top,z,dz,initial_macro_view,ok)
  if(.not.ok)error stop 'A8 real initial macro canonicalization'
  macro_snapshot=macro

  call setup_rate_template(macro,geometry,rate_template)
  call setup_history(history_request)

  ! Real residual-synchronous macro provider; frozen matrix conductivity.
  policy%enabled=.true.;policy%inner_richards_exchange_enabled=.true.
  policy%max_correctors=80;policy%exchange_relative_tolerance=1d-10
  policy%exchange_floor=1d-12;policy%solver_mass_tolerance_cm=1d-10
  policy%internal_exchange_tolerance_cm=1d-10
  request%boundary%bottom_mode=3
  allocate(request%physical%matrix_area_fraction(4))
  case_count=0
  do ia=1,3
    area=areas(ia)
    request%physical%matrix_area_fraction=area
    call setup_geometry(geometry_config)
    geometry_config%static_volume_cp=(1d0-area)*dz
    call evaluate_macropore_geometry(geometry_config,macro%dynamic_volume_cp,geometry)
    if(.not.geometry%valid)error stop 'oracle geometry'
    macro%icp_bottom_domain=geometry%bottom_domain
    macro%volume_domain_cp=geometry%volume_domain_cp
    macro%water_domain_cp=.35d0*geometry%volume_domain_cp
    call canonicalize_macropore_standard_storage(macro,macro_top,z,dz,initial_macro_view,ok)
    if(.not.ok)error stop 'oracle macro canonicalization'
    macro_snapshot=macro
    call setup_rate_template(macro,geometry,rate_template)
    do ir=0,1
    do half=0,1
      if(ir==0.and.half==0)cycle
      resistance=10d0*ir
      request%boundary%bottom_external_resistance_days=resistance
      request%boundary%bottom_include_half_cell=half==1
      do ih=-1,1,2
      do ix=-1,1
        aq=-100d0+10d0*ih;extra=.01d0*ix
        request%boundary%bottom_head=aq;request%boundary%bottom_flux=extra
        call runtime%execute(solver,workspace,request,macro,geometry_config,rate_template,history_request,policy,result, &
          matrix_area_fraction=request%physical%matrix_area_fraction)
        if(result%status/=MACRO_RUNTIME_CONVERGED)then
          print *,ia,ir,half,ih,ix,result%status,result%matrix_result%status,trim(result%matrix_result%diagnostics%route)
          error stop 'oracle real macro Cauchy solve'
        end if
        ! Independent Robin law uses the declared frozen K and matrix area,
        ! not the production bottom evaluator, workspace Kmean or residual.
        half_r=0d0
        if(half==1)half_r=.5d0*dz(4)/(area*cond(4))
        conductance=1d0/(resistance+half_r)
        expected=(aq-result%matrix_result%candidate_state%pressure_head(4)-z(4))*conductance+extra
        worst_robin=max(worst_robin,abs(expected-result%matrix_result%bottom_flux))
        if(abs(expected-result%matrix_result%bottom_flux)>1d-12)error stop 'independent Robin area law'
        faces(1)=result%matrix_result%top_flux;faces(5)=expected
        do j=2,4
          faces(j)=-.5d0*area*(cond(j-1)+cond(j))* &
            ((result%matrix_result%candidate_state%pressure_head(j-1)- &
              result%matrix_result%candidate_state%pressure_head(j))/disnod(j)+1d0)
        end do
        cell=area*dz*(result%matrix_result%candidate_state%water_content-water)- &
          dt*(faces(2:5)-faces(1:4)+result%exchange_rate_node)
        worst_cell=max(worst_cell,maxval(abs(cell)))
        if(maxval(abs(cell))>1d-10)error stop 'independent matrix cell balance'
        matrix_delta=sum(area*dz*(result%matrix_result%candidate_state%water_content-water))
        macro_delta=sum(result%macropore_candidate%water_domain_cp)-sum(macro%water_domain_cp)
        matrix_res=matrix_delta-dt*(expected-faces(1)+sum(result%exchange_rate_node))
        macro_res=macro_delta-result%accepted_top_input_cm+result%rapid_external_outflow_cm+ &
          dt*sum(result%exchange_rate_node)
        gross=matrix_delta+macro_delta-dt*(expected-faces(1))- &
          result%accepted_top_input_cm+result%rapid_external_outflow_cm
        worst_matrix=max(worst_matrix,abs(matrix_res));worst_macro=max(worst_macro,abs(macro_res))
        worst_gross=max(worst_gross,abs(gross))
        if(max(abs(matrix_res),abs(macro_res),abs(gross))>1d-10)error stop 'separate gross balances'
        if(.not.macro%same_values(macro_snapshot))error stop 'macro accepted state mutated'
        if(any(request%base_state%pressure_head/=heads).or.any(request%base_state%water_content/=water)) &
          error stop 'matrix accepted state mutated'
        case_count=case_count+1
      end do
      end do
    end do
    end do
  end do
  if(case_count/=54)error stop 'oracle case count'
  write(*,'(A,I0,5(1X,ES25.17E3))')'CAUCHY_MACRO_INDEPENDENT_PASS ',case_count, &
    worst_robin,worst_cell,worst_matrix,worst_macro,worst_gross
contains
  subroutine setup_geometry(config)
    type(macropore_geometry_config_t),intent(out)::config
    config%num_domains=nd
    config%num_nodes=numnod
    config%top_node=macro_top
    allocate(config%static_volume_cp(numnod),config%domain_fraction(nd,numnod), &
         config%potential_bottom_domain(nd),config%dz(numnod),config%characteristic_diameter(numnod))
    config%static_volume_cp=0.25_real64
    if(macro_top>1)config%static_volume_cp(1:macro_top-1)=0.0_real64
    config%domain_fraction=1.0_real64
    if(macro_top>1)config%domain_fraction(:,1:macro_top-1)=0.0_real64
    config%potential_bottom_domain=numnod
    config%dz=dz
    if(macro_top>1)config%domain_fraction(:,1:macro_top-1)=0.0_real64
    config%characteristic_diameter=4.0_real64
  end subroutine setup_geometry

  subroutine setup_rate_template(state,geom,bundle)
    type(macropore_continuation_state_t),intent(in)::state
    type(macropore_geometry_result_t),intent(in)::geom
    type(macropore_rate_bundle_request_t),intent(out)::bundle

    allocate(bundle%unsaturated%sorptivity%bottom_domain(nd),bundle%unsaturated%sorptivity%top_water_node(nd), &
         bundle%unsaturated%sorptivity%theta(numnod),bundle%unsaturated%sorptivity%theta_s(numnod), &
         bundle%unsaturated%sorptivity%theta_r(numnod),bundle%unsaturated%sorptivity%dz(numnod), &
         bundle%unsaturated%sorptivity%diameter(numnod),bundle%unsaturated%sorptivity%wall_correction(numnod), &
         bundle%unsaturated%sorptivity%sorptivity_max(numnod), &
         bundle%unsaturated%sorptivity%sorptivity_alpha(numnod), &
         bundle%unsaturated%sorptivity%domain_fraction(nd,numnod), &
         bundle%unsaturated%sorptivity%wet_fraction(nd,numnod), &
         bundle%unsaturated%sorptivity%history_sorptivity(nd,numnod), &
         bundle%unsaturated%sorptivity%history_theta_ref(nd,numnod), &
         bundle%unsaturated%sorptivity%history_absorption_time(nd,numnod), &
         bundle%unsaturated%pressure_head(numnod),bundle%unsaturated%elevation(numnod), &
         bundle%unsaturated%conductivity(numnod),bundle%unsaturated%entry_head(numnod), &
         bundle%unsaturated%groundwater_level_domain(nd),bundle%unsaturated%sorp_fac_parallel(numnod))
    bundle%unsaturated%sorptivity%num_domains=nd
    bundle%unsaturated%sorptivity%num_nodes=numnod
    bundle%unsaturated%sorptivity%top_node=macro_top
    bundle%unsaturated%sorptivity%swmbf=1
    bundle%unsaturated%sorptivity%matrix_top_saturated_node=numnod+1
    bundle%unsaturated%sorptivity%step_duration=dt
    bundle%unsaturated%sorptivity%flow_reduction=1.0_real64
    bundle%unsaturated%sorptivity%bottom_domain=numnod
    bundle%unsaturated%sorptivity%top_water_node=macro_top
    bundle%unsaturated%sorptivity%theta=water
    bundle%unsaturated%sorptivity%theta_s=0.427494_real64
    bundle%unsaturated%sorptivity%theta_r=0.02_real64
    bundle%unsaturated%sorptivity%dz=dz
    bundle%unsaturated%sorptivity%diameter=4.0_real64
    bundle%unsaturated%sorptivity%wall_correction=0.95_real64
    bundle%unsaturated%sorptivity%sorptivity_max=0.001_real64
    bundle%unsaturated%sorptivity%sorptivity_alpha=0.5_real64
    bundle%unsaturated%sorptivity%domain_fraction=1.0_real64
    bundle%unsaturated%sorptivity%wet_fraction=1.0_real64
    bundle%unsaturated%sorptivity%history_sorptivity=state%sorptivity
    bundle%unsaturated%sorptivity%history_theta_ref=state%theta_sorption_ref
    bundle%unsaturated%sorptivity%history_absorption_time=state%absorption_time
    bundle%unsaturated%shape_factor=1.0_real64
    bundle%unsaturated%pressure_head=heads
    bundle%unsaturated%elevation=z
    bundle%unsaturated%conductivity=0.0_real64
    bundle%unsaturated%entry_head=-1.0_real64
    bundle%unsaturated%groundwater_level_domain=-200.0_real64
    bundle%unsaturated%sorp_fac_parallel=0.5_real64

    call setup_sat(bundle%interflow_sat)
    call setup_sat(bundle%matrix_sat)

    bundle%rapid%num_nodes=numnod
    bundle%rapid%top_water_node=1
    bundle%rapid%bottom_domain_node=numnod
    bundle%rapid%drain_type=2
    bundle%rapid%enabled=.false.
    bundle%rapid%saturated_top_fraction=1.0_real64
    bundle%rapid%water_level_cm=-200.0_real64
    bundle%rapid%domain_bottom_cm=minval(z)-0.5_real64*dz(numnod)
    bundle%rapid%drain_level_cm=-50.0_real64
    bundle%rapid%ponding_cm=0.0_real64
    bundle%rapid%step_duration=dt
    bundle%rapid%area_exponent=3.0_real64
    bundle%rapid%kd_reference=0.001_real64
    bundle%rapid%resistance_reference_day=20.0_real64
    bundle%rapid%flow_reduction=1.0_real64
    bundle%rapid%water_storage_cm=sum(state%water_domain_cp)
    bundle%rapid%volume_under_drain_cm=0.0_real64
    allocate(bundle%rapid%diameter(numnod),bundle%rapid%dz(numnod),bundle%rapid%volume_main_domain_cp(numnod))
    bundle%rapid%diameter=4.0_real64
    bundle%rapid%dz=dz
    bundle%rapid%volume_main_domain_cp=geom%volume_domain_cp(1,:)

    bundle%limiter%num_domains=nd
    allocate(bundle%limiter%accepted_storage_cm(nd),bundle%limiter%maximum_storage_cm(nd), &
         bundle%limiter%minimum_storage_cm(nd),bundle%limiter%potential_top_vertical_cm(nd), &
         bundle%limiter%potential_top_lateral_cm(nd),bundle%limiter%potential_interflow_sat_cm(nd), &
         bundle%limiter%potential_matrix_sat_cm(nd),bundle%limiter%potential_outflow_cm(nd), &
         bundle%limiter%redistribution_capacity_cm(nd),bundle%limiter%top_domain_fraction(nd))
    bundle%limiter%accepted_storage_cm=sum(state%water_domain_cp,dim=2)
    bundle%limiter%maximum_storage_cm=sum(geom%volume_domain_cp,dim=2)
    bundle%limiter%minimum_storage_cm=0.0_real64
    bundle%limiter%potential_top_vertical_cm=0.0_real64
    bundle%limiter%potential_top_lateral_cm=0.0_real64
    bundle%limiter%potential_interflow_sat_cm=0.0_real64
    bundle%limiter%potential_matrix_sat_cm=0.0_real64
    bundle%limiter%potential_outflow_cm=0.0_real64
    bundle%limiter%redistribution_capacity_cm=max(0.0_real64, &
         bundle%limiter%maximum_storage_cm-bundle%limiter%accepted_storage_cm)
    bundle%limiter%top_domain_fraction=1.0_real64
    bundle%top_node=macro_top
  end subroutine setup_rate_template

  subroutine setup_sat(sat)
    use mod_ppa_wu05a6_saturated_exchange_rate, only: saturated_exchange_request_t
    type(saturated_exchange_request_t),intent(out)::sat
    sat%num_domains=nd
    sat%num_nodes=numnod
    sat%matrix_top_saturated_node=1
    sat%matrix_bottom_saturated_node=0
    sat%swsep=0
    sat%matrix_level=-200.0_real64
    sat%step_duration=dt
    sat%flow_reduction=1.0_real64
    sat%shape_factor=1.0_real64
    allocate(sat%bottom_domain(nd),sat%top_macro_saturated_node(nd),sat%macro_saturated_fraction(nd), &
         sat%macro_reference_level(nd),sat%z(numnod),sat%dz(numnod),sat%matrix_head(numnod), &
         sat%ksat_horizontal(numnod),sat%diameter(numnod),sat%domain_fraction(nd,numnod),sat%cdarcy(nd,numnod))
    sat%bottom_domain=numnod
    sat%top_macro_saturated_node=1
    sat%macro_saturated_fraction=1.0_real64
    sat%macro_reference_level=-200.0_real64
    sat%z=z
    sat%dz=dz
    sat%matrix_head=heads
    sat%ksat_horizontal=0.0_real64
    sat%diameter=4.0_real64
    sat%domain_fraction=1.0_real64
    sat%cdarcy=0.0_real64
  end subroutine setup_sat

  subroutine setup_history(history)
    type(sorptivity_history_update_request_t),intent(out)::history
    history%num_domains=nd
    history%num_nodes=numnod
    history%top_node=macro_top
    history%matrix_top_saturated_node=numnod+1
    history%step_duration=dt
    allocate(history%bottom_domain(nd),history%top_water_node(nd),history%wall_correction(numnod), &
         history%wet_fraction(nd,numnod),history%domain_fraction(nd,numnod),history%diameter(numnod))
    history%bottom_domain=numnod
    history%top_water_node=macro_top
    history%wall_correction=0.95_real64
    history%wet_fraction=1.0_real64
    history%domain_fraction=1.0_real64
    history%diameter=4.0_real64
  end subroutine setup_history

end program test_cauchy3_macropore_oracle
