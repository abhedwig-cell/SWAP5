program test_ppa_wu05a9_fmr_top_input_replay
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
       FMR_OPTIONAL_STATE_LAYOUT_MACROPORE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_serialized_reference_backend_t, &
       fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, fmr_b110_physical_state_t, &
       fmr_new_b110_committed_state, prepare_fmr_b110_default_mvg
  use mod_fmr_macropore_configuration, only: fmr_macropore_physical_config_t, prepare_fmr_macropore_rapid_reference
  use mod_fmr_macropore_top_input, only: fmr_macropore_top_input_forcing_t
  use mod_fmr_restart_state_contract, only: fmr_restart_state_matches_template
  use mod_macropore_single_column_runtime, only: macropore_single_column_runtime_t, &
       macropore_runtime_policy_t, macropore_runtime_result_t, MACRO_RUNTIME_INACTIVE, &
       MACRO_RUNTIME_CONVERGED
  implicit none
  character(len=1)::constitutive_flag,fit_flag

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
  real(real64)::heads(numnod),water(numnod),cond(numnod),cap(numnod),dkdh(numnod)
  integer::i
  logical::ok
  logical::dynamic_enabled
  character(len=1)::dynamic_flag

  fit_flag='0'
  call get_environment_variable('WU05_MIGMAC04_FIT',fit_flag)
  constitutive_flag='0'
  call get_environment_variable('WU05_MIGMAC03_LAW',constitutive_flag)
  dynamic_flag='0'
  call get_environment_variable('WU05_MIGMAC02_DYNAMIC',dynamic_flag)
  dynamic_enabled=dynamic_flag=='1'
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
  call canonicalize_macropore_standard_storage(macro,1,z,dz,initial_macro_view,ok)
  if(.not.ok)error stop 'A8 real initial macro canonicalization'
  macro_snapshot=macro

  call setup_rate_template(macro,geometry,rate_template)
  call setup_history(history_request)

  ! Disabled path: exactly direct Reference Richards.
  direct_request=request
  call solver%solve(direct_request,workspace,direct_result)
  if(direct_result%status/=SW_SOLVE_CONVERGED)error stop 'A7 real direct reference failed'
  policy%enabled=.false.
  call runtime%execute(solver,workspace,request,macro,geometry_config,rate_template,history_request,policy,result)
  if(result%status/=MACRO_RUNTIME_INACTIVE)error stop 'A7 real inactive runtime status'
  if(any(transfer(result%matrix_result%candidate_state%water_content,[0_int64],numnod) /= &
         transfer(direct_result%candidate_state%water_content,[0_int64],numnod))) &
       error stop 'A7 real inactive theta identity'
  if(any(transfer(result%matrix_result%candidate_state%pressure_head,[0_int64],numnod) /= &
         transfer(direct_result%candidate_state%pressure_head,[0_int64],numnod))) &
       error stop 'A7 real inactive head identity'
  if(.not.result%macropore_candidate%same_values(macro_snapshot))error stop 'A7 real inactive macro identity'

  ! Active strict sorptivity-only coupling.
  policy%enabled=.true.
  policy%max_correctors=80
  policy%exchange_relative_tolerance=1.0e-10_real64
  policy%exchange_floor=1.0e-12_real64
  policy%damping_previous_weight=0.5_real64
  policy%solver_mass_tolerance_cm=1.0e-9_real64
  policy%internal_exchange_tolerance_cm=1.0e-9_real64

  call runtime%execute(solver,workspace,request,macro,geometry_config,rate_template,history_request,policy,result)
  if(result%status/=MACRO_RUNTIME_CONVERGED)error stop 'A7 real active runtime failed'
  if(sum(result%exchange_rate_node)<=0.0_real64)error stop 'A7 real exchange missing'
  if(abs(result%internal_exchange_residual_cm)>1.0e-9_real64)error stop 'A7 real internal residual'
  if(abs(result%macro_balance_residual_cm)>1.0e-9_real64)error stop 'A7 real macro residual'
  if(result%vertical_flux%max_local_residual_rate>1.0e-10_real64)error stop 'A7 real vertical residual'
  if(.not.macro%same_values(macro_snapshot))error stop 'A7 real accepted macro mutated'

  call exercise_serialized_fmr()

  write(*,'(*(g0))') 'PPA_WU05A7_REAL_RICHARDS|OUTER_IT=',result%outer_iterations, &
       '|QEXC=',sum(result%exchange_rate_node), &
       '|MATRIX_RES=',result%matrix_result%integrated_mass_balance_residual_cm, &
       '|MACRO_RES=',result%macro_balance_residual_cm
  print '(a)', 'PPA_WU05A9_FMR_TOP_INPUT_REPLAY_GATE=PASS'

contains

  subroutine exercise_serialized_fmr()
    type(fmr_serialized_reference_backend_t) :: backend, restored_backend, fresh_backend
    type(fmr_b110_physical_parameters_t), target :: fparams
    type(fmr_b110_physical_forcing_t) :: forcing
    type(fmr_b110_physical_state_t) :: initial
    type(fmr_macropore_physical_config_t) :: mcfg
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(canonical_numerical_config_t) :: numerical
    type(kernel_committed_state_t) :: committed, restored
    type(kernel_checkpoint_t) :: checkpoint, restored_checkpoint
    type(kernel_candidate_state_t) :: candidate, replay_candidate, next_candidate, restored_next_candidate
    type(kernel_candidate_state_t) :: retry_candidate, fresh_retry_candidate
    type(kernel_result_t) :: kres, replay_result, next_result, restored_next_result
    type(kernel_result_t) :: retry_result, fresh_retry_result
    type(kernel_diagnostics_t) :: kdiag, replay_diag, next_diag, restored_next_diag
    type(kernel_diagnostics_t) :: retry_diag, fresh_retry_diag
    type(kernel_persistence_snapshot_t) :: persisted
    class(transaction_state_t), allocatable :: before_state, after_trial_state, candidate_state, replay_state, &
         restored_state, next_state, restored_next_state, retry_state, fresh_retry_state
    logical :: prepared, state_ok, available, did_commit, persisted_ok, restored_ok, policy_ok
    character(len=1)::reference_flag
    real(real64)::ref_theta(numnod),ref_cond(numnod),ref_cap(numnod),ref_dk(numnod)
    integer :: commit_status, persistence_status, k, crack_node
    integer(int64), parameter :: lineage=505801_int64, layout_id=505001_int64
    real(real64), parameter :: fmr_dt=1.0e-3_real64

    fparams%parameter_set_id=lineage
    fparams%active_nodes=numnod
    allocate(fparams%z(numnod),fparams%dz(numnod),fparams%node_distance(numnod),fparams%cofgen(24,numnod))
    fparams%z=z
    fparams%dz=dz
    fparams%node_distance=disnod(1:numnod)
    fparams%cofgen=cofgen
    fparams%bottom_mode=7
    fparams%swkimpl=0
    fparams%swkmean=1
    fparams%swsophy=0
    fparams%max_iterations=64
    fparams%max_backtracking=24
    fparams%min_step_duration=1.0e-12_real64
    fparams%compartment_balance_tolerance=tol
    fparams%total_balance_tolerance=tol
    fparams%head_abs_tolerance=tol
    fparams%head_rel_tolerance=tol
    fparams%ponding_tolerance=tol
    fparams%macropore_active=.true.
    call prepare_fmr_b110_default_mvg(fparams,prepared)
    if(.not.prepared)error stop 'A9 FMR top-input prepared MVG'

    mcfg%geometry=geometry_config
    mcfg%rate_template=rate_template
    mcfg%history_template=history_request
    mcfg%matrix_area_fraction=1.0_real64-geometry_config%static_volume_cp/dz
    mcfg%shrinkage%enabled=dynamic_enabled
    call map_surface_crack_depth_to_node(-0.75_real64,z,dz,1,crack_node,state_ok)
    if(.not.state_ok)error stop 'MIGMAC02 replay crack depth'
    mcfg%shrinkage%surface_crack_area_node=crack_node
    mcfg%shrinkage%surface_crack_area_node_supplied=.true.
    allocate(mcfg%shrinkage%theta_s(numnod),mcfg%shrinkage%theta_crack(numnod), &
         mcfg%shrinkage%geometry_factor(numnod),mcfg%shrinkage%minimum_subsidence_cm(numnod),mcfg%shrinkage%kim(numnod))
    mcfg%shrinkage%theta_s=0.427494_real64
    mcfg%shrinkage%theta_crack=0.40_real64
    mcfg%shrinkage%geometry_factor=3.0_real64
    do k=1,numnod
      call prepare_clay_kim_option1(0.427494_real64,0.20_real64,2.0_real64,1.20_real64,mcfg%shrinkage%kim(k),state_ok)
      if(.not.state_ok)error stop 'MIGMAC02 replay Kim parameters'
    end do
    if(constitutive_flag/='0')then
      allocate(mcfg%shrinkage%law(numnod),mcfg%shrinkage%peat(numnod))
      mcfg%shrinkage%law=SHRINK_PEAT_DIRECT
      if(constitutive_flag=='3' .or. constitutive_flag=='4')mcfg%shrinkage%law=SHRINK_PEAT_SEGMENTS
      if(constitutive_flag=='2' .or. constitutive_flag=='4')mcfg%shrinkage%law(2::2)=SHRINK_RIGID
      mcfg%shrinkage%peat%void_ratio_zero=0.2_real64
      mcfg%shrinkage%peat%transition_moisture_ratio=0.5_real64
      mcfg%shrinkage%peat%alpha=1.2_real64
      mcfg%shrinkage%peat%beta=3.0_real64
      mcfg%shrinkage%peat%p=0.1_real64
      mcfg%shrinkage%peat%intermediate_moisture_ratio=0.2_real64
      mcfg%shrinkage%peat%intermediate_void_ratio=0.4_real64
      if(constitutive_flag=='5' .or. constitutive_flag=='6' .or. constitutive_flag=='7')then
        if(constitutive_flag=='6')mcfg%shrinkage%law=SHRINK_PEAT_SEGMENTS
        mcfg%shrinkage%law(2::2)=SHRINK_KIM
        if(constitutive_flag=='7')mcfg%shrinkage%law(3::3)=SHRINK_RIGID
      end if
    end if

    if(fit_flag=='1')then
      do k=1,numnod
        call prepare_clay_kim_option2(0.427494_real64,0.2_real64,0.35_real64,mcfg%shrinkage%kim(k),state_ok)
        if(.not.state_ok)error stop 'MIGMAC04 clay points prepare'
      end do
    else if(fit_flag=='2' .or. fit_flag=='3')then
      if(.not.allocated(mcfg%shrinkage%peat))error stop 'MIGMAC04 peat carrier present'
      do k=1,numnod
        if(fit_flag=='2')then
          call prepare_peat_characteristic_points(0.427494_real64,0.2_real64,0.5_real64,0.1_real64, &
               0.25_real64,0.1_real64,mcfg%shrinkage%peat(k),state_ok)
        else
          call prepare_peat_characteristic_points(0.427494_real64,0.2_real64,0.5_real64,0.1_real64, &
               0.25_real64,-0.3_real64,mcfg%shrinkage%peat(k),state_ok)
        end if
        if(.not.state_ok)error stop 'MIGMAC04 peat points prepare'
      end do
    end if
    call derive_dynamic_minimum_subsidence(mcfg%shrinkage,dz,state_ok)
    if(.not.state_ok)error stop 'MIGMAC02 replay source minimum subsidence'
    if(.not.mcfg%valid_for_nodes(numnod))error stop 'A9 FMR top-input config validity'
    call get_environment_variable('WU05_MIGMAC06_KD',reference_flag)
    if(reference_flag=='1')then
      mcfg%rate_template%rapid%enabled=.true.
      mcfg%rate_template%rapid%drain_level_cm=-2.0_real64
      call hyd%evaluate(-2.0_real64-z,ref_theta,ref_cond,ref_cap,ref_dk)
      call prepare_fmr_macropore_rapid_reference(mcfg,z,ref_theta,-sum(dz),state_ok)
      if(.not.state_ok)error stop 'MIGMAC06 derived replay reference'
      print '(a,es24.16)','PPA_WU05_MIGMAC06_REFERENCE_KD=',mcfg%rate_template%rapid%kd_reference
    end if
    allocate(fparams%macropore)
    fparams%macropore=mcfg

    initial%active_nodes=numnod
    allocate(initial%pressure_head(numnod),initial%water_content(numnod),initial%macropore)
    initial%pressure_head=heads
    initial%water_content=water
    initial%ponding_depth=0.0_real64
    initial%groundwater_level=-200.0_real64
    initial%macropore=macro

    call fmr_new_b110_committed_state(committed,lineage,initial,0.0_real64,state_ok)
    if(.not.state_ok)error stop 'A9 FMR top-input committed init'

    allocate(forcing%drainage_flux_by_level(1,numnod),forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    forcing%top_flux=0.0_real64
    forcing%top_head=0.0_real64
    forcing%bottom_flux=0.0_real64
    forcing%bottom_head=-100.0_real64
    forcing%drainage_flux_by_level=0.0_real64
    forcing%subsurface_irrigation_source=0.0_real64
    forcing%root_extraction_sink=0.0_real64
    allocate(forcing%macropore_top_input)
    forcing%macropore_top_input=fmr_macropore_top_input_forcing_t()
    forcing%macropore_top_input%supplied=.true.
    forcing%macropore_top_input%net_rain_rate_cm_per_day=1.0_real64
    forcing%macropore_top_input%net_irrigation_rate_cm_per_day=0.25_real64
    forcing%macropore_top_input%melt_rate_cm_per_day=0.0_real64
    forcing%macropore_top_input%lateral_overland_rate_cm_per_day=0.10_real64

    column%column_id=lineage
    column%template_id=505801_int64
    column%parameter_ref=lineage
    column%state_handle=1_int64
    column%forcing_handle=1_int64
    column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    template%template_id=column%template_id
    template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_MACROPORE
    template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE

    numerical%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
    numerical%transaction%temporal_tolerance=1.0e-2_real64
    numerical%transaction%mass_tolerance=1.0e-8_real64
    numerical%transaction%retry_scale=0.5_real64
    numerical%transaction%max_retries=40
    numerical%max_committed_substeps=64

    call backend%initialize(top)
    policy%inner_richards_exchange_enabled=dynamic_enabled
    call backend%configure_macropore_policy(policy,policy_ok)
    if(.not.policy_ok)error stop 'A9 FMR top-input policy configure'

    call committed%capture_checkpoint(checkpoint,available)
    if(.not.available)error stop 'A9 FMR top-input checkpoint capture'
    call committed%snapshot(before_state,available)
    if(.not.available)error stop 'A9 FMR top-input before snapshot'

    call backend%run_trial(column,template,fparams,committed,forcing,numerical,0.0_real64,fmr_dt,checkpoint, &
         kres,candidate,kdiag,trusted_prepared_parameters=.true.)
    write(*,'(*(g0))') 'PPA_WU05A9_REPLAY_TRIAL_DIAG|STATUS=',kres%status,'|COMPLETED=',kres%completed, &
         '|TEMP_SOURCE=',kdiag%temporal_acceptance_source,'|TEMP_REJ=',kdiag%temporal_rejections, &
         '|MASS_REJ=',kdiag%mass_rejections,'|SOLVER_REJ=',kdiag%solver_rejections, &
         '|MASS=',kres%mass%residual
    if(.not.kres%completed .or. .not.candidate%ready())error stop 'A9 FMR top-input active serialized trial'
    if(.not.kres%mass%complete .or. abs(kres%mass%residual)>1.0e-8_real64)error stop 'A9 FMR top-input mass receipt'
    if(kdiag%temporal_acceptance_source/=TX_TEMPORAL_EXTERNAL_FULL_HALF) &
         error stop 'A9 FMR top-input temporal acceptance source'

    call committed%snapshot(after_trial_state,available)
    if(.not.available .or. .not.same_fmr_state(before_state,after_trial_state)) &
         error stop 'A9 FMR top-input candidate leaked into committed state'
    call candidate%snapshot(candidate_state,available)
    if(.not.available)error stop 'A9 FMR top-input candidate snapshot'
    select type(s=>candidate_state)
    type is(fmr_b110_physical_state_t)
      if(dynamic_enabled .and. .not.any(s%macropore%dynamic_volume_cp>1.0e-12_real64)) &
           error stop 'MIGMAC02 replay geometry inactive'
    end select

    call backend%discard_trial_candidate(candidate,kdiag)
    if(candidate%ready())error stop 'A9 FMR top-input discard retained candidate'
    call committed%snapshot(after_trial_state,available)
    if(.not.available .or. .not.same_fmr_state(before_state,after_trial_state)) &
         error stop 'A9 FMR top-input discard mutated committed state'

    ! Rejected A, then smaller B: a fresh backend must produce identical B.
    call backend%run_trial(column,template,fparams,committed,forcing,numerical,0.0_real64,0.5_real64*fmr_dt, &
         checkpoint,retry_result,retry_candidate,retry_diag,trusted_prepared_parameters=.true.)
    call fresh_backend%initialize(top)
    call fresh_backend%configure_macropore_policy(policy,policy_ok)
    if(.not.policy_ok)error stop 'MIGMAC02 fresh retry policy'
    call fresh_backend%run_trial(column,template,fparams,committed,forcing,numerical,0.0_real64,0.5_real64*fmr_dt, &
         checkpoint,fresh_retry_result,fresh_retry_candidate,fresh_retry_diag,trusted_prepared_parameters=.true.)
    if(.not.retry_result%completed .or. .not.fresh_retry_result%completed)error stop 'MIGMAC02 smaller retry failed'
    if(.not.retry_result%mass%complete .or. abs(retry_result%mass%residual)>1.0e-8_real64) &
         error stop 'MIGMAC02 smaller retry mass closure'
    call retry_candidate%snapshot(retry_state,available)
    if(.not.available)error stop 'MIGMAC02 smaller retry snapshot'
    call fresh_retry_candidate%snapshot(fresh_retry_state,available)
    if(.not.available .or. .not.same_fmr_state(retry_state,fresh_retry_state)) &
         error stop 'MIGMAC02 rejected A smaller B identity'
    call backend%discard_trial_candidate(retry_candidate,retry_diag)
    call fresh_backend%discard_trial_candidate(fresh_retry_candidate,fresh_retry_diag)

    call backend%run_trial(column,template,fparams,committed,forcing,numerical,0.0_real64,fmr_dt,checkpoint, &
         replay_result,replay_candidate,replay_diag,trusted_prepared_parameters=.true.)
    if(.not.replay_result%completed .or. .not.replay_candidate%ready())error stop 'A9 FMR top-input checkpoint replay'
    call replay_candidate%snapshot(replay_state,available)
    if(.not.available .or. .not.same_fmr_state(candidate_state,replay_state))error stop 'A9 FMR top-input replay identity'

    call backend%commit_trial_candidate(committed,replay_candidate,replay_diag,did_commit,commit_status)
    if(.not.did_commit .or. commit_status/=0)error stop 'A9 FMR top-input candidate commit'
    if(committed%current_revision()/=1_int64)error stop 'A9 FMR top-input committed revision'
    call committed%snapshot(after_trial_state,available)
    if(.not.available .or. .not.same_fmr_state(replay_state,after_trial_state))error stop 'A9 FMR top-input commit publication'

    call export_kernel_committed_state(committed,layout_id,persisted,persisted_ok,persistence_status)
    if(.not.persisted_ok .or. persistence_status/=KERNEL_PERSISTENCE_OK)error stop 'A9 FMR top-input persistence export'
    call persisted%snapshot_physical(restored_state,available)
    if(.not.available .or. .not.fmr_restart_state_matches_template(restored_state,template)) &
         error stop 'A9 FMR top-input persisted restart layout'
    if(.not.same_fmr_state(after_trial_state,restored_state))error stop 'A9 FMR top-input seven-field persistence'

    call restore_kernel_committed_state(persisted,layout_id,restored,restored_ok,persistence_status)
    if(.not.restored_ok .or. persistence_status/=KERNEL_PERSISTENCE_OK)error stop 'A9 FMR top-input persistence restore'
    call restored%snapshot(restored_state,available)
    if(.not.available .or. .not.same_fmr_state(after_trial_state,restored_state))error stop 'A9 FMR top-input restored state'

    call committed%capture_checkpoint(checkpoint,available)
    if(.not.available)error stop 'A9 FMR top-input next checkpoint'
    call restored%capture_checkpoint(restored_checkpoint,available)
    if(.not.available)error stop 'A9 FMR top-input restored checkpoint'
    call restored_backend%initialize(top)
    call restored_backend%configure_macropore_policy(policy,policy_ok)
    if(.not.policy_ok)error stop 'A9 FMR top-input restored policy'

    call backend%run_trial(column,template,fparams,committed,forcing,numerical,fmr_dt,2.0_real64*fmr_dt,checkpoint, &
         next_result,next_candidate,next_diag,trusted_prepared_parameters=.true.)
    call restored_backend%run_trial(column,template,fparams,restored,forcing,numerical,fmr_dt,2.0_real64*fmr_dt, &
         restored_checkpoint,restored_next_result,restored_next_candidate,restored_next_diag, &
         trusted_prepared_parameters=.true.)
    if(.not.next_result%completed .or. .not.restored_next_result%completed)error stop 'A9 FMR top-input restart continuation'
    call next_candidate%snapshot(next_state,available)
    if(.not.available)error stop 'A9 FMR top-input next candidate'
    call restored_next_candidate%snapshot(restored_next_state,available)
    if(.not.available .or. .not.same_fmr_state(next_state,restored_next_state)) &
         error stop 'A9 FMR top-input restart next-candidate replay'

    print '(a)', 'PPA_WU05A9_FMR_TOP_INPUT_SERIALIZED=PASS'
    print '(a)', 'PPA_WU05A9_FMR_TOP_INPUT_REJECT_REPLAY=PASS'
    print '(a)', 'PPA_WU05A9_FMR_TOP_INPUT_RESTART=PASS'
    if(dynamic_enabled)then
      print '(a)', 'PPA_WU05_MIGMAC02_DYNAMIC_REJECT_SMALLER_RETRY=PASS'
      print '(a)', 'PPA_WU05_MIGMAC02_DYNAMIC_ABA=PASS'
      print '(a)', 'PPA_WU05_MIGMAC02_DYNAMIC_ACCEPTED_RESTART=PASS'
    end if
  end subroutine exercise_serialized_fmr

  logical function same_fmr_state(a,b) result(same)
    class(transaction_state_t), intent(in) :: a,b
    same=.false.
    select type (aa=>a)
    type is (fmr_b110_physical_state_t)
      select type (bb=>b)
      type is (fmr_b110_physical_state_t)
        same=aa%active_nodes==bb%active_nodes
        if(same)same=allocated(aa%pressure_head).eqv.allocated(bb%pressure_head)
        if(same)same=allocated(aa%water_content).eqv.allocated(bb%water_content)
        if(same.and.allocated(aa%pressure_head))same=all(transfer(aa%pressure_head,[0_int64],size(aa%pressure_head)) == &
             transfer(bb%pressure_head,[0_int64],size(bb%pressure_head)))
        if(same.and.allocated(aa%water_content))same=all(transfer(aa%water_content,[0_int64],size(aa%water_content)) == &
             transfer(bb%water_content,[0_int64],size(bb%water_content)))
        if(same)same=transfer(aa%ponding_depth,0_int64)==transfer(bb%ponding_depth,0_int64)
        if(same)same=transfer(aa%groundwater_level,0_int64)==transfer(bb%groundwater_level,0_int64)
        if(same)same=allocated(aa%macropore).eqv.allocated(bb%macropore)
        if(same.and.allocated(aa%macropore))same=aa%macropore%same_values(bb%macropore)
      class default
        same=.false.
      end select
    class default
      same=.false.
    end select
  end function same_fmr_state

  subroutine setup_geometry(config)
    type(macropore_geometry_config_t),intent(out)::config
    config%num_domains=nd
    config%num_nodes=numnod
    config%top_node=1
    allocate(config%static_volume_cp(numnod),config%domain_fraction(nd,numnod), &
         config%potential_bottom_domain(nd),config%dz(numnod),config%characteristic_diameter(numnod))
    config%static_volume_cp=0.25_real64
    config%domain_fraction=1.0_real64
    config%potential_bottom_domain=numnod
    config%dz=dz
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
    bundle%unsaturated%sorptivity%top_node=1
    bundle%unsaturated%sorptivity%swmbf=1
    bundle%unsaturated%sorptivity%matrix_top_saturated_node=numnod+1
    bundle%unsaturated%sorptivity%step_duration=dt
    bundle%unsaturated%sorptivity%flow_reduction=1.0_real64
    bundle%unsaturated%sorptivity%bottom_domain=numnod
    bundle%unsaturated%sorptivity%top_water_node=1
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
    bundle%top_node=1
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
    history%top_node=1
    history%matrix_top_saturated_node=numnod+1
    history%step_duration=dt
    allocate(history%bottom_domain(nd),history%top_water_node(nd),history%wall_correction(numnod), &
         history%wet_fraction(nd,numnod),history%domain_fraction(nd,numnod),history%diameter(numnod))
    history%bottom_domain=numnod
    history%top_water_node=1
    history%wall_correction=0.95_real64
    history%wet_fraction=1.0_real64
    history%domain_fraction=1.0_real64
    history%diameter=4.0_real64
  end subroutine setup_history

end program test_ppa_wu05a9_fmr_top_input_replay
