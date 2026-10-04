program test_ppa_wu05a7_real_richards_runtime
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
       fmr_serialized_physical_observation_t, &
       fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, fmr_b110_physical_state_t, &
       fmr_new_b110_committed_state, prepare_fmr_b110_default_mvg
  use mod_fmr_macropore_configuration, only: fmr_macropore_physical_config_t
  use mod_fmr_restart_state_contract, only: fmr_restart_state_matches_template
  use mod_solute_water_face_flux_reconstruction, only: reconstruct_interval_water_face_flux, WATER_FACE_FLUX_OK
  use mod_macropore_single_column_runtime, only: macropore_single_column_runtime_t, &
       macropore_runtime_policy_t, macropore_runtime_result_t, MACRO_RUNTIME_INACTIVE, &
       MACRO_RUNTIME_CONVERGED
  implicit none

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
  call exercise_serialized_fmr(.true.)

  write(*,'(*(g0))') 'PPA_WU05A7_REAL_RICHARDS|OUTER_IT=',result%outer_iterations, &
       '|QEXC=',sum(result%exchange_rate_node), &
       '|MATRIX_RES=',result%matrix_result%integrated_mass_balance_residual_cm, &
       '|MACRO_RES=',result%macro_balance_residual_cm
  print '(a)', 'PPA_WU05A7_REAL_RICHARDS_RUNTIME=PASS'

contains

  subroutine exercise_serialized_fmr(trace_mode)
    logical, intent(in), optional :: trace_mode
    type(fmr_serialized_reference_backend_t) :: backend, restored_backend
    type(fmr_serialized_physical_observation_t) :: fmr_observation
    type(fmr_serialized_physical_observation_t) :: replay_observation, next_observation, restored_next_observation
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
    type(kernel_result_t) :: kres, replay_result, next_result, restored_next_result
    type(kernel_diagnostics_t) :: kdiag, replay_diag, next_diag, restored_next_diag
    type(kernel_persistence_snapshot_t) :: persisted
    class(transaction_state_t), allocatable :: before_state, after_trial_state, candidate_state, replay_state, &
         restored_state, next_state, restored_next_state
    logical :: prepared, state_ok, available, did_commit, persisted_ok, restored_ok, policy_ok
    logical :: trace_requested
    integer :: commit_status, persistence_status, trace_i, trace_status
    real(real64), allocatable :: trace_faces(:)
    real(real64) :: trace_closure, max_trace_closure
    integer(int64), parameter :: lineage=505801_int64, layout_id=505001_int64
    real(real64) :: fmr_dt

    trace_requested=.false.
    if(present(trace_mode)) trace_requested=trace_mode
    fmr_dt=1.0e-3_real64

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
    fparams%root_extraction_active=.true.
    fparams%macropore_active=.true.
    call prepare_fmr_b110_default_mvg(fparams,prepared)
    if(.not.prepared)error stop 'A8 FMR prepared MVG'

    mcfg%geometry=geometry_config
    mcfg%rate_template=rate_template
    mcfg%history_template=history_request
    if(.not.mcfg%valid_for_nodes(numnod))error stop 'A8 FMR config validity'
    allocate(fparams%macropore)
    fparams%macropore=mcfg
    allocate(fparams%macropore%matrix_area_fraction(numnod))
    fparams%macropore%matrix_area_fraction=1.0_real64

    initial%active_nodes=numnod
    allocate(initial%pressure_head(numnod),initial%water_content(numnod),initial%macropore)
    initial%pressure_head=heads
    initial%water_content=water
    initial%ponding_depth=0.0_real64
    initial%groundwater_level=-200.0_real64
    initial%macropore=macro

    call fmr_new_b110_committed_state(committed,lineage,initial,0.0_real64,state_ok)
    if(.not.state_ok)error stop 'A8 FMR committed init'

    allocate(forcing%drainage_flux_by_level(1,numnod),forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    forcing%top_flux=0.0_real64
    forcing%top_head=0.0_real64
    forcing%bottom_flux=0.0_real64
    forcing%bottom_head=-100.0_real64
    forcing%drainage_flux_by_level=0.0_real64
    forcing%subsurface_irrigation_source=0.0_real64
    forcing%root_extraction_sink=0.0_real64
    forcing%root_extraction_sink(numnod)=2.0e-4_real64

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
    call backend%configure_macropore_policy(policy,policy_ok)
    if(.not.policy_ok)error stop 'A8 FMR policy configure'

    call committed%capture_checkpoint(checkpoint,available)
    if(.not.available)error stop 'A8 FMR checkpoint capture'
    call committed%snapshot(before_state,available)
    if(.not.available)error stop 'A8 FMR before snapshot'

    if(trace_requested) then
      fparams%snow_active=.true.
      call backend%run_trial(column,template,fparams,committed,forcing,numerical,0.0_real64,fmr_dt,checkpoint, &
           kres,candidate,kdiag,trusted_prepared_parameters=.true.,trace_accepted_water_flux_substeps=.true.)
      if(kres%completed.or.candidate%ready()) error stop 'unsupported FMR trace route did not fail closed'
      call committed%snapshot(after_trial_state,available)
      if(.not.available.or..not.same_fmr_state(before_state,after_trial_state)) &
           error stop 'unsupported FMR trace mutated committed state'
      fparams%snow_active=.false.
      print '(a)','PPA_WU05E_FMR_UNSUPPORTED_TRACE_ROUTE=FAIL_CLOSED'
    end if

    call backend%run_trial(column,template,fparams,committed,forcing,numerical,0.0_real64,fmr_dt,checkpoint, &
         kres,candidate,kdiag,trusted_prepared_parameters=.true., &
         trace_accepted_water_flux_substeps=trace_requested)
    fmr_observation=backend%observation()
    write(*,'(*(g0))') 'PPA_WU05A8_FMR_TRIAL_DIAG|STATUS=',kres%status,'|COMPLETED=',kres%completed, &
         '|TEMP_SOURCE=',kdiag%temporal_acceptance_source,'|TEMP_REJ=',kdiag%temporal_rejections, &
         '|MASS_REJ=',kdiag%mass_rejections,'|STEP_MASS_MAX=',kdiag%max_abs_step_mass_residual, &
         '|SOLVER_REJ=',kdiag%solver_rejections,'|HEADCALC=',kdiag%headcalc_calls, &
         '|SW_STATUS=',fmr_observation%solver_status,'|SW_EQUATION_RES=',fmr_observation%solver_equation_residual, &
         '|SW_TOP=',fmr_observation%top_flux,'|SW_BOTTOM=',fmr_observation%bottom_flux, &
         '|MACRO_EXCHANGE=',fmr_observation%macropore_inner_final_exchange_rate_cm_per_day, &
         '|MASS=',kres%mass%residual
    if(.not.kres%completed .or. .not.candidate%ready())error stop 'A8 FMR active serialized trial'
    if(.not.kres%mass%complete .or. abs(kres%mass%residual)>1.0e-8_real64)error stop 'A8 FMR mass receipt'
    if(kdiag%temporal_acceptance_source/=TX_TEMPORAL_EXTERNAL_FULL_HALF) &
         error stop 'A8 FMR temporal acceptance source'
    if(trace_requested) then
      if(.not.fmr_observation%accepted_water_flux_trace_available .or. &
          .not.allocated(fmr_observation%accepted_water_flux_substeps)) error stop 'FMR accepted flux trace missing'
      if(size(fmr_observation%accepted_water_flux_substeps)<2) error stop 'FMR trace omitted accepted half steps'
      max_trace_closure=0.0_real64
      do trace_i=1,size(fmr_observation%accepted_water_flux_substeps)
        if(abs(sum(fmr_observation%accepted_water_flux_substeps(trace_i)%root_sink)- &
             sum(forcing%root_extraction_sink))>1.0e-16_real64) error stop 'FMR trace lost final qrot'
        call reconstruct_interval_water_face_flux(dz(1:numnod), &
             fmr_observation%accepted_water_flux_substeps(trace_i)%water_start, &
             fmr_observation%accepted_water_flux_substeps(trace_i)%water_end, &
             fmr_observation%accepted_water_flux_substeps(trace_i)%net_node_source, &
             -fmr_observation%accepted_water_flux_substeps(trace_i)%top_flux, &
             -fmr_observation%accepted_water_flux_substeps(trace_i)%bottom_flux, &
             fmr_observation%accepted_water_flux_substeps(trace_i)%t1- &
             fmr_observation%accepted_water_flux_substeps(trace_i)%t0,1.0e-8_real64, &
             trace_faces,trace_closure,trace_status)
        if(trace_status/=WATER_FACE_FLUX_OK) error stop 'FMR accepted physical-substep face closure'
        max_trace_closure=max(max_trace_closure,abs(trace_closure))
      end do
      if(max_trace_closure>1.0e-8_real64) error stop 'FMR accepted trace closure tolerance'
      write(*,'(*(g0))') 'PPA_WU05E_FMR_ACCEPTED_SUBSTEP_TRACE=PASS|COUNT=', &
           size(fmr_observation%accepted_water_flux_substeps),'|MAX_CLOSURE=',max_trace_closure
    end if

    call committed%snapshot(after_trial_state,available)
    if(.not.available .or. .not.same_fmr_state(before_state,after_trial_state)) &
         error stop 'A8 FMR candidate leaked into committed state'
    call candidate%snapshot(candidate_state,available)
    if(.not.available)error stop 'A8 FMR candidate snapshot'
    call backend%discard_trial_candidate(candidate,kdiag)
    if(candidate%ready())error stop 'A8 FMR discard retained candidate'
    call committed%snapshot(after_trial_state,available)
    if(.not.available .or. .not.same_fmr_state(before_state,after_trial_state)) &
         error stop 'A8 FMR discard mutated committed state'

    call backend%run_trial(column,template,fparams,committed,forcing,numerical,0.0_real64,fmr_dt,checkpoint, &
         replay_result,replay_candidate,replay_diag,trusted_prepared_parameters=.true., &
         trace_accepted_water_flux_substeps=trace_requested)
    if(trace_requested) then
      replay_observation=backend%observation()
      if(.not.same_accepted_water_flux_trace(fmr_observation,replay_observation)) &
           error stop 'FMR accepted flux trace replay identity'
    end if
    if(.not.replay_result%completed .or. .not.replay_candidate%ready())error stop 'A8 FMR checkpoint replay'
    call replay_candidate%snapshot(replay_state,available)
    if(.not.available .or. .not.same_fmr_state(candidate_state,replay_state))error stop 'A8 FMR replay identity'

    call backend%commit_trial_candidate(committed,replay_candidate,replay_diag,did_commit,commit_status)
    if(.not.did_commit .or. commit_status/=0)error stop 'A8 FMR candidate commit'
    if(committed%current_revision()/=1_int64)error stop 'A8 FMR committed revision'
    call committed%snapshot(after_trial_state,available)
    if(.not.available .or. .not.same_fmr_state(replay_state,after_trial_state))error stop 'A8 FMR commit publication'
    write(*,'(*(g0))') 'PPA_WU05E_FMR_ROOT_SINK_TRANSACTION=PASS|QROT_TOTAL=', &
         sum(forcing%root_extraction_sink),'|MASS_RESID=',kres%mass%residual

    call export_kernel_committed_state(committed,layout_id,persisted,persisted_ok,persistence_status)
    if(.not.persisted_ok .or. persistence_status/=KERNEL_PERSISTENCE_OK)error stop 'A8 FMR persistence export'
    call persisted%snapshot_physical(restored_state,available)
    if(.not.available .or. .not.fmr_restart_state_matches_template(restored_state,template)) &
         error stop 'A8 FMR persisted restart layout'
    if(.not.same_fmr_state(after_trial_state,restored_state))error stop 'A8 FMR seven-field persistence'

    call restore_kernel_committed_state(persisted,layout_id,restored,restored_ok,persistence_status)
    if(.not.restored_ok .or. persistence_status/=KERNEL_PERSISTENCE_OK)error stop 'A8 FMR persistence restore'
    call restored%snapshot(restored_state,available)
    if(.not.available .or. .not.same_fmr_state(after_trial_state,restored_state))error stop 'A8 FMR restored state'

    call committed%capture_checkpoint(checkpoint,available)
    if(.not.available)error stop 'A8 FMR next checkpoint'
    call restored%capture_checkpoint(restored_checkpoint,available)
    if(.not.available)error stop 'A8 FMR restored checkpoint'
    call restored_backend%initialize(top)
    call restored_backend%configure_macropore_policy(policy,policy_ok)
    if(.not.policy_ok)error stop 'A8 FMR restored policy'

    if(trace_requested) forcing%root_extraction_sink(numnod)=1.5e-4_real64

    call backend%run_trial(column,template,fparams,committed,forcing,numerical,fmr_dt,2.0_real64*fmr_dt,checkpoint, &
         next_result,next_candidate,next_diag,trusted_prepared_parameters=.true., &
         trace_accepted_water_flux_substeps=trace_requested)
    next_observation=backend%observation()
    call restored_backend%run_trial(column,template,fparams,restored,forcing,numerical,fmr_dt,2.0_real64*fmr_dt, &
         restored_checkpoint,restored_next_result,restored_next_candidate,restored_next_diag, &
         trusted_prepared_parameters=.true.,trace_accepted_water_flux_substeps=trace_requested)
    restored_next_observation=restored_backend%observation()
    if(.not.next_result%completed .or. .not.restored_next_result%completed)error stop 'A8 FMR restart continuation'
    call next_candidate%snapshot(next_state,available)
    if(.not.available)error stop 'A8 FMR next candidate'
    call restored_next_candidate%snapshot(restored_next_state,available)
    if(.not.available .or. .not.same_fmr_state(next_state,restored_next_state)) &
         error stop 'A8 FMR restart next-candidate replay'
    if(trace_requested) then
      if(.not.same_accepted_water_flux_trace(next_observation,restored_next_observation)) &
           error stop 'FMR changed-forcing restart trace identity'
    end if

    print '(a)', 'PPA_WU05A8_FMR_SERIALIZED_RUNTIME=PASS'
    print '(a)', 'PPA_WU05A8_FMR_REJECT_REPLAY=PASS'
    print '(a)', 'PPA_WU05A8_FMR_RESTART=PASS'
  end subroutine exercise_serialized_fmr

  logical function same_accepted_water_flux_trace(a,b) result(same)
    type(fmr_serialized_physical_observation_t), intent(in) :: a,b
    integer :: i
    same=.false.
    if(a%accepted_water_flux_trace_available .neqv. b%accepted_water_flux_trace_available) return
    if(.not.a%accepted_water_flux_trace_available) return
    if(.not.allocated(a%accepted_water_flux_substeps) .or. .not.allocated(b%accepted_water_flux_substeps)) return
    if(size(a%accepted_water_flux_substeps)/=size(b%accepted_water_flux_substeps)) return
    do i=1,size(a%accepted_water_flux_substeps)
      if(transfer(a%accepted_water_flux_substeps(i)%t0,0_int64)/= &
         transfer(b%accepted_water_flux_substeps(i)%t0,0_int64)) return
      if(transfer(a%accepted_water_flux_substeps(i)%t1,0_int64)/= &
         transfer(b%accepted_water_flux_substeps(i)%t1,0_int64)) return
      if(transfer(a%accepted_water_flux_substeps(i)%top_flux,0_int64)/= &
         transfer(b%accepted_water_flux_substeps(i)%top_flux,0_int64)) return
      if(transfer(a%accepted_water_flux_substeps(i)%bottom_flux,0_int64)/= &
         transfer(b%accepted_water_flux_substeps(i)%bottom_flux,0_int64)) return
      if(any(transfer(a%accepted_water_flux_substeps(i)%water_start,[0_int64],numnod)/= &
             transfer(b%accepted_water_flux_substeps(i)%water_start,[0_int64],numnod))) return
      if(any(transfer(a%accepted_water_flux_substeps(i)%water_end,[0_int64],numnod)/= &
             transfer(b%accepted_water_flux_substeps(i)%water_end,[0_int64],numnod))) return
      if(any(transfer(a%accepted_water_flux_substeps(i)%subsurface_source,[0_int64],numnod)/= &
             transfer(b%accepted_water_flux_substeps(i)%subsurface_source,[0_int64],numnod))) return
      if(any(transfer(a%accepted_water_flux_substeps(i)%drainage_sink,[0_int64],numnod)/= &
             transfer(b%accepted_water_flux_substeps(i)%drainage_sink,[0_int64],numnod))) return
      if(any(transfer(a%accepted_water_flux_substeps(i)%root_sink,[0_int64],numnod)/= &
             transfer(b%accepted_water_flux_substeps(i)%root_sink,[0_int64],numnod))) return
      if(any(transfer(a%accepted_water_flux_substeps(i)%net_node_source,[0_int64],numnod)/= &
             transfer(b%accepted_water_flux_substeps(i)%net_node_source,[0_int64],numnod))) return
      if(any(transfer(a%accepted_water_flux_substeps(i)%macropore_matrix_exchange,[0_int64],numnod)/= &
             transfer(b%accepted_water_flux_substeps(i)%macropore_matrix_exchange,[0_int64],numnod))) return
    end do
    same=.true.
  end function same_accepted_water_flux_trace

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
    config%static_volume_cp=0.50_real64
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
      