program test_ppa_wu05a7_fmr_macropore_transaction
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY, FMR_OPTIONAL_STATE_LAYOUT_MACROPORE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_temporal_indicator_committed_state
  use mod_fmr_restart_state_contract, only: fmr_restart_state_matches_template
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_macropore_continuation_state, only: macropore_continuation_state_t
  use mod_ppa_wu05a5_multi_domain_process, only: macropore_geometry_result_t, evaluate_macropore_geometry
  use mod_macropore_single_column_runtime, only: MACRO_RUNTIME_CONVERGED
  implicit none

  real(real64),parameter::dt=1.0e-3_real64,mass_tol=1.0e-8_real64
  integer(int64),parameter::column_id=505707_int64
  type(fmr_b110_physical_parameters_t)::parameters
  type(fmr_b110_physical_forcing_t)::forcing
  type(fmr_b110_physical_state_t)::initial_state
  type(fmr_logical_column_t)::column
  type(fmr_template_t)::template
  type(canonical_numerical_config_t)::config
  type(kernel_committed_state_t)::committed
  type(kernel_checkpoint_t)::checkpoint
  type(kernel_result_t)::result1,result2
  type(kernel_candidate_state_t)::candidate1,candidate2
  type(kernel_diagnostics_t)::diag1,diag2
  type(fmr_serialized_reference_backend_t)::backend
  type(fmr_serialized_physical_observation_t)::obs
  type(fixed_flux_top_boundary_provider_t),target::top
  class(transaction_state_t),allocatable::committed_before,candidate_snapshot1,candidate_snapshot2,committed_after
  logical::ok,available,did_commit
  integer::commit_status

  call initialize_parameters(parameters)
  call initialize_state(parameters,initial_state)
  call initialize_forcing(forcing)
  call initialize_column_template(column,template)
  call initialize_config(config)
  call require(allocated(parameters%macropore),'macropore config allocated')
  call require(parameters%macropore%ready(parameters%active_nodes,require_zero_top_receipt=.true.), &
       'macropore config ready')
  call require(fmr_restart_state_matches_template(initial_state,template),'initial state matches macropore layout')

  call fmr_new_b110_temporal_indicator_committed_state(committed,column_id,initial_state,0.0_real64,ok, &
       initial_right_derivative=spread(0.0_real64,1,numnod))
  call require(ok,'committed initialized')
  call committed%snapshot(committed_before,available)
  call require(available,'initial snapshot')
  call fmr_capture_checkpoint(committed,checkpoint,ok)
  call require(ok,'checkpoint captured')

  call backend%initialize(top)
  call backend%run_trial(column,template,parameters,committed,forcing,config,0.0_real64,dt,checkpoint, &
       result1,candidate1,diag1)
  obs=backend%observation()
  write(*,'(*(g0))') 'PPA_WU05A7_FMR_DEBUG|STATUS=',result1%status,'|COMPLETED=',result1%completed, &
       '|ADMISSION_REJ=',diag1%admission_rejections,'|ATTEMPTS=',diag1%attempts,'|RETRIES=',diag1%retries, &
       '|TEMP_REJ=',diag1%temporal_rejections,'|TEMP_MAX=',diag1%max_temporal_indicator, &
       '|MASS_REJ=',diag1%mass_rejections,'|STEP_MASS_MAX=',diag1%max_abs_step_mass_residual, &
       '|MASS_COMPLETE=',result1%mass%complete,'|MASS_RES=',result1%mass%residual, &
       '|MACRO_EXEC=',obs%macropore_executed,'|MACRO_STATUS=',obs%macropore_status
  call require(result1%status==CANONICAL_STATUS_COMPLETED .and. result1%completed,'first FMR trial completed')
  call require(candidate1%ready(),'first candidate ready')
  call require(result1%mass%complete .and. abs(result1%mass%residual)<=mass_tol,'first mass closed')
  obs=backend%observation()
  call require(obs%macropore_active .and. obs%macropore_executed,'macropore observed active')
  call require(obs%macropore_status==MACRO_RUNTIME_CONVERGED,'macropore runtime converged')
  call require(abs(obs%macropore_returned_surface_cm)<=1.0e-15_real64,'zero top receipt returned surface zero')
  call require(abs(obs%macropore_internal_exchange_residual_cm)<=mass_tol,'internal exchange residual')

  call candidate1%snapshot(candidate_snapshot1,available)
  call require(available,'first candidate snapshot')
  call require_candidate_changed(committed_before,candidate_snapshot1)
  call committed%snapshot(committed_after,available)
  call require(available,'post-trial committed snapshot')
  call require_state_identity(committed_before,committed_after,'trial leaves committed unchanged')

  call backend%discard_trial_candidate(candidate1,diag1)
  call backend%run_trial(column,template,parameters,committed,forcing,config,0.0_real64,dt,checkpoint, &
       result2,candidate2,diag2)
  call require(result2%status==CANONICAL_STATUS_COMPLETED .and. result2%completed,'retry trial completed')
  call require(candidate2%ready(),'retry candidate ready')
  call candidate2%snapshot(candidate_snapshot2,available)
  call require(available,'retry candidate snapshot')
  call require_state_identity(candidate_snapshot1,candidate_snapshot2,'discard retry deterministic')

  call backend%commit_trial_candidate(committed,candidate2,diag2,did_commit,commit_status)
  call require(did_commit,'candidate committed')
  call committed%snapshot(committed_after,available)
  call require(available,'committed candidate snapshot')
  call require_state_identity(candidate_snapshot2,committed_after,'commit publishes exact candidate')
  call require(fmr_restart_state_matches_template(committed_after,template),'committed state matches macropore restart layout')

  write(*,'(A,I0)') 'PPA_WU05A7_FMR_ACCEPTED_SUBSTEPS=',diag2%accepted_substeps
  write(*,'(A,ES26.17E3)') 'PPA_WU05A7_FMR_MASS_RESIDUAL=',result2%mass%residual
  print '(A)' ,'PPA_WU05A7_FMR_MACROPORE_TRANSACTION=PASS'

contains

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::hyd
    real(real64)::heads(numnod),water(numnod),cond(numnod),cap(numnod),dkdh(numnod)
    type(macropore_geometry_result_t)::geom
    type(macropore_continuation_state_t)::macro
    integer::i

    p%parameter_set_id=505707_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod); p%cofgen=0.0_real64
    do i=1,numnod
      p%cofgen(1,i)=0.02_real64; p%cofgen(2,i)=0.427494_real64; p%cofgen(3,i)=31.225016_real64
      p%cofgen(4,i)=0.021659_real64; p%cofgen(5,i)=0.98087_real64; p%cofgen(6,i)=1.734737_real64
      p%cofgen(7,i)=1.0_real64-1.0_real64/p%cofgen(6,i); p%cofgen(8,i)=p%cofgen(4,i)
      p%cofgen(10,i)=p%cofgen(3,i); p%cofgen(11,i)=0.999_real64; p%cofgen(12,i)=0.99_real64*p%cofgen(3,i)
      p%cofgen(22,i)=-1.0e6_real64; p%cofgen(23,i)=1.0e-12_real64
    end do
    p%bottom_mode=7; p%swkimpl=0; p%swkmean=1; p%swsophy=0
    p%max_iterations=64; p%max_backtracking=24; p%min_step_duration=1.0e-12_real64
    p%compartment_balance_tolerance=1.0e-12_real64; p%total_balance_tolerance=1.0e-12_real64
    p%head_abs_tolerance=1.0e-12_real64; p%head_rel_tolerance=1.0e-12_real64
    p%ponding_tolerance=1.0e-12_real64
    p%macropore_active=.true.
    allocate(p%macropore)

    p%macropore%geometry%num_domains=1
    p%macropore%geometry%num_nodes=numnod
    p%macropore%geometry%top_node=1
    allocate(p%macropore%geometry%static_volume_cp(numnod),p%macropore%geometry%domain_fraction(1,numnod), &
         p%macropore%geometry%potential_bottom_domain(1),p%macropore%geometry%dz(numnod), &
         p%macropore%geometry%characteristic_diameter(numnod))
    p%macropore%geometry%static_volume_cp=0.50_real64
    p%macropore%geometry%domain_fraction=1.0_real64
    p%macropore%geometry%potential_bottom_domain=numnod
    p%macropore%geometry%dz=dz
    p%macropore%geometry%characteristic_diameter=4.0_real64

    call macro%initialize(1,numnod,ok)
    call require(ok,'macro scratch init')
    macro%dynamic_volume_cp=0.0_real64
    call evaluate_macropore_geometry(p%macropore%geometry,macro%dynamic_volume_cp,geom)
    call require(geom%valid,'macro geometry config')

    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(hyd,hp,dt)
    heads=-100.0_real64
    call hyd%evaluate(heads,water,cond,cap,dkdh)
    call setup_rate_template(p%macropore%rate_template,macro,geom,heads,water)
    call setup_history(p%macropore%history)
    p%macropore%policy%enabled=.true.
    p%macropore%policy%max_correctors=80
    p%macropore%policy%exchange_relative_tolerance=1.0e-10_real64
    p%macropore%policy%exchange_floor=1.0e-12_real64
    p%macropore%policy%damping_previous_weight=0.5_real64
    p%macropore%policy%solver_mass_tolerance_cm=1.0e-8_real64
    p%macropore%policy%internal_exchange_tolerance_cm=1.0e-8_real64
  end subroutine initialize_parameters

  subroutine initialize_state(p,state)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    type(fmr_b110_physical_state_t),intent(out)::state
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::hyd
    type(macropore_geometry_result_t)::geom
    real(real64)::heads(numnod),water(numnod),cond(numnod),cap(numnod),dkdh(numnod)

    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(hyd,hp,dt)
    heads=-100.0_real64
    call hyd%evaluate(heads,water,cond,cap,dkdh)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod),state%macropore)
    state%pressure_head=heads; state%water_content=water
    state%ponding_depth=0.0_real64; state%groundwater_level=-200.0_real64
    call state%macropore%initialize(1,numnod,ok)
    call require(ok,'state macro init')
    state%macropore%dynamic_volume_cp=0.0_real64
    call evaluate_macropore_geometry(p%macropore%geometry,state%macropore%dynamic_volume_cp,geom)
    call require(geom%valid,'state geometry')
    state%macropore%icp_bottom_domain=geom%bottom_domain
    state%macropore%volume_domain_cp=geom%volume_domain_cp
    state%macropore%water_domain_cp=0.35_real64*geom%volume_domain_cp
  end subroutine initialize_state

  subroutine setup_rate_template(bundle,state,geom,heads,water)
    use mod_ppa_wu05a6_rate_bundle, only: macropore_rate_bundle_request_t
    use mod_macropore_continuation_state, only: macropore_continuation_state_t
    type(macropore_rate_bundle_request_t),intent(out)::bundle
    type(macropore_continuation_state_t),intent(in)::state
    type(macropore_geometry_result_t),intent(in)::geom
    real(real64),intent(in)::heads(:),water(:)
    allocate(bundle%unsaturated%sorptivity%bottom_domain(1),bundle%unsaturated%sorptivity%top_water_node(1), &
         bundle%unsaturated%sorptivity%theta(numnod),bundle%unsaturated%sorptivity%theta_s(numnod), &
         bundle%unsaturated%sorptivity%theta_r(numnod),bundle%unsaturated%sorptivity%dz(numnod), &
         bundle%unsaturated%sorptivity%diameter(numnod),bundle%unsaturated%sorptivity%wall_correction(numnod), &
         bundle%unsaturated%sorptivity%sorptivity_max(numnod),bundle%unsaturated%sorptivity%sorptivity_alpha(numnod), &
         bundle%unsaturated%sorptivity%domain_fraction(1,numnod),bundle%unsaturated%sorptivity%wet_fraction(1,numnod), &
         bundle%unsaturated%sorptivity%history_sorptivity(1,numnod),bundle%unsaturated%sorptivity%history_theta_ref(1,numnod), &
         bundle%unsaturated%sorptivity%history_absorption_time(1,numnod),bundle%unsaturated%pressure_head(numnod), &
         bundle%unsaturated%elevation(numnod),bundle%unsaturated%conductivity(numnod),bundle%unsaturated%entry_head(numnod), &
         bundle%unsaturated%groundwater_level_domain(1),bundle%unsaturated%sorp_fac_parallel(numnod))
    bundle%unsaturated%sorptivity%num_domains=1; bundle%unsaturated%sorptivity%num_nodes=numnod
    bundle%unsaturated%sorptivity%top_node=1; bundle%unsaturated%sorptivity%swmbf=1
    bundle%unsaturated%sorptivity%matrix_top_saturated_node=numnod+1; bundle%unsaturated%sorptivity%step_duration=dt
    bundle%unsaturated%sorptivity%flow_reduction=1.0_real64; bundle%unsaturated%sorptivity%bottom_domain=numnod
    bundle%unsaturated%sorptivity%top_water_node=1; bundle%unsaturated%sorptivity%theta=water
    bundle%unsaturated%sorptivity%theta_s=0.427494_real64; bundle%unsaturated%sorptivity%theta_r=0.02_real64
    bundle%unsaturated%sorptivity%dz=dz; bundle%unsaturated%sorptivity%diameter=4.0_real64
    bundle%unsaturated%sorptivity%wall_correction=0.95_real64; bundle%unsaturated%sorptivity%sorptivity_max=0.0_real64
    bundle%unsaturated%sorptivity%sorptivity_alpha=0.5_real64; bundle%unsaturated%sorptivity%domain_fraction=1.0_real64
    bundle%unsaturated%sorptivity%wet_fraction=1.0_real64; bundle%unsaturated%sorptivity%history_sorptivity=state%sorptivity
    bundle%unsaturated%sorptivity%history_theta_ref=state%theta_sorption_ref
    bundle%unsaturated%sorptivity%history_absorption_time=state%absorption_time
    bundle%unsaturated%shape_factor=1.0_real64; bundle%unsaturated%pressure_head=heads
    bundle%unsaturated%elevation=z; bundle%unsaturated%conductivity=0.0_real64
    bundle%unsaturated%entry_head=-1.0_real64; bundle%unsaturated%groundwater_level_domain=-200.0_real64
    bundle%unsaturated%sorp_fac_parallel=0.5_real64
    call setup_sat(bundle%interflow_sat,heads)
    call setup_sat(bundle%matrix_sat,heads)
    bundle%rapid%num_nodes=numnod; bundle%rapid%top_water_node=1; bundle%rapid%bottom_domain_node=numnod
    bundle%rapid%drain_type=2; bundle%rapid%enabled=.true.; bundle%rapid%saturated_top_fraction=1.0_real64
    bundle%rapid%water_level_cm=-60.0_real64; bundle%rapid%domain_bottom_cm=-100.0_real64
    bundle%rapid%drain_level_cm=-80.0_real64; bundle%rapid%ponding_cm=0.0_real64; bundle%rapid%step_duration=dt
    bundle%rapid%area_exponent=3.0_real64; bundle%rapid%kd_reference=0.001_real64
    bundle%rapid%resistance_reference_day=20.0_real64; bundle%rapid%flow_reduction=1.0_real64
    bundle%rapid%water_storage_cm=sum(state%water_domain_cp); bundle%rapid%volume_under_drain_cm=0.0_real64
    allocate(bundle%rapid%diameter(numnod),bundle%rapid%dz(numnod),bundle%rapid%volume_main_domain_cp(numnod))
    bundle%rapid%diameter=4.0_real64; bundle%rapid%dz=dz; bundle%rapid%volume_main_domain_cp=geom%volume_domain_cp(1,:)
    bundle%limiter%num_domains=1
    allocate(bundle%limiter%accepted_storage_cm(1),bundle%limiter%maximum_storage_cm(1),bundle%limiter%minimum_storage_cm(1), &
         bundle%limiter%potential_top_vertical_cm(1),bundle%limiter%potential_top_lateral_cm(1), &
         bundle%limiter%potential_interflow_sat_cm(1),bundle%limiter%potential_matrix_sat_cm(1), &
         bundle%limiter%potential_outflow_cm(1),bundle%limiter%redistribution_capacity_cm(1),bundle%limiter%top_domain_fraction(1))
    bundle%limiter%accepted_storage_cm=sum(state%water_domain_cp,dim=2)
    bundle%limiter%maximum_storage_cm=sum(geom%volume_domain_cp,dim=2); bundle%limiter%minimum_storage_cm=0.0_real64
    bundle%limiter%potential_top_vertical_cm=0.0_real64; bundle%limiter%potential_top_lateral_cm=0.0_real64
    bundle%limiter%potential_interflow_sat_cm=0.0_real64; bundle%limiter%potential_matrix_sat_cm=0.0_real64
    bundle%limiter%potential_outflow_cm=0.0_real64
    bundle%limiter%redistribution_capacity_cm=max(0.0_real64,bundle%limiter%maximum_storage_cm-bundle%limiter%accepted_storage_cm)
    bundle%limiter%top_domain_fraction=1.0_real64; bundle%top_node=1
  end subroutine setup_rate_template

  subroutine setup_sat(sat,heads)
    use mod_ppa_wu05a6_saturated_exchange_rate, only: saturated_exchange_request_t
    type(saturated_exchange_request_t),intent(out)::sat
    real(real64),intent(in)::heads(:)
    sat%num_domains=1; sat%num_nodes=numnod; sat%matrix_top_saturated_node=1; sat%matrix_bottom_saturated_node=0
    sat%swsep=0; sat%matrix_level=-200.0_real64; sat%step_duration=dt; sat%flow_reduction=1.0_real64; sat%shape_factor=1.0_real64
    allocate(sat%bottom_domain(1),sat%top_macro_saturated_node(1),sat%macro_saturated_fraction(1), &
         sat%macro_reference_level(1),sat%z(numnod),sat%dz(numnod),sat%matrix_head(numnod), &
         sat%ksat_horizontal(numnod),sat%diameter(numnod),sat%domain_fraction(1,numnod),sat%cdarcy(1,numnod))
    sat%bottom_domain=numnod; sat%top_macro_saturated_node=1; sat%macro_saturated_fraction=1.0_real64
    sat%macro_reference_level=-200.0_real64; sat%z=z; sat%dz=dz; sat%matrix_head=heads
    sat%ksat_horizontal=0.0_real64; sat%diameter=4.0_real64; sat%domain_fraction=1.0_real64; sat%cdarcy=0.0_real64
  end subroutine setup_sat

  subroutine setup_history(h)
    use mod_ppa_wu05a6_sorptivity_history, only: sorptivity_history_update_request_t
    type(sorptivity_history_update_request_t),intent(out)::h
    h%num_domains=1; h%num_nodes=numnod; h%top_node=1; h%matrix_top_saturated_node=numnod+1; h%step_duration=dt
    allocate(h%bottom_domain(1),h%top_water_node(1),h%wall_correction(numnod),h%wet_fraction(1,numnod), &
         h%domain_fraction(1,numnod),h%diameter(numnod))
    h%bottom_domain=numnod; h%top_water_node=1; h%wall_correction=0.95_real64
    h%wet_fraction=1.0_real64; h%domain_fraction=1.0_real64; h%diameter=4.0_real64
  end subroutine setup_history

  subroutine initialize_forcing(f)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    f%top_flux=0.0_real64; f%top_head=-100.0_real64; f%bottom_flux=0.0_real64; f%bottom_head=-100.0_real64
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64; f%subsurface_irrigation_source=0.0_real64; f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_column_template(col,tpl)
    type(fmr_logical_column_t),intent(out)::col
    type(fmr_template_t),intent(out)::tpl
    tpl%template_id=505701_int64; tpl%physics_topology_id=505702_int64; tpl%vertical_layout_id=505703_int64
    tpl%state_layout_id=505704_int64; tpl%solver_interface_id=505705_int64
    tpl%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_MACROPORE
    tpl%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    tpl%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    col%column_id=column_id; col%template_id=tpl%template_id; col%parameter_ref=1_int64
    col%state_handle=1_int64; col%forcing_handle=1_int64; col%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_template

  subroutine initialize_config(cfg)
    type(canonical_numerical_config_t),intent(out)::cfg
    cfg%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
    cfg%transaction%temporal_tolerance=0.0_real64
    cfg%transaction%mass_tolerance=mass_tol
    cfg%transaction%retry_scale=0.5_real64
    cfg%transaction%max_retries=4
    cfg%max_committed_substeps=16
    cfg%progress_tolerance=0.0_real64
    cfg%model_temporal_indicator_budget_available=.true.
    cfg%model_temporal_indicator_budget=10.0_real64
  end subroutine initialize_config

  subroutine require_candidate_changed(base,cand)
    class(transaction_state_t),intent(in)::base,cand
    select type(b=>base)
    type is(fmr_b110_physical_state_t)
      select type(q=>cand)
      type is(fmr_b110_physical_state_t)
        call require(allocated(b%macropore).and.allocated(q%macropore),'macro state allocated')
        call require(.not.q%macropore%same_values(b%macropore),'candidate macropore changed')
      class default; call require(.false.,'candidate type')
      end select
    class default; call require(.false.,'base type')
    end select
  end subroutine require_candidate_changed

  subroutine require_state_identity(a,b,label)
    class(transaction_state_t),intent(in)::a,b
    character(len=*),intent(in)::label
    select type(x=>a)
    type is(fmr_b110_physical_state_t)
      select type(y=>b)
      type is(fmr_b110_physical_state_t)
        call require(x%active_nodes==y%active_nodes,label//' nodes')
        call require(all(transfer(x%pressure_head,[0_int64],size(x%pressure_head))== &
                         transfer(y%pressure_head,[0_int64],size(y%pressure_head))),label//' head')
        call require(all(transfer(x%water_content,[0_int64],size(x%water_content))== &
                         transfer(y%water_content,[0_int64],size(y%water_content))),label//' theta')
        call require(x%macropore%same_values(y%macropore),label//' macro')
      class default; call require(.false.,label//' type2')
      end select
    class default; call require(.false.,label//' type1')
    end select
  end subroutine require_state_identity

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'PPA_WU05A7_FMR_FAIL',trim(label)
      error stop 77
    end if
  end subroutine require
end program test_ppa_wu05a7_fmr_macropore_transaction
