program test_ppa_wu05a7_real_richards_runtime
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
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
       FMR_OPTIONAL_STATE_LAYOUT_BASE, FMR_OPTIONAL_STATE_LAYOUT_MACROPORE, FMR_NUMERICAL_CONTINUATION_NONE, &
       FMR_SOLUTE_STATE_LAYOUT_NONE, FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED, &
       FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED_MACROPORE
  use mod_fmr_serialized_reference_backend, only: fmr_serialized_reference_backend_t, &
       fmr_serialized_physical_observation_t, fmr_water_flux_substep_trace_t, &
       fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, fmr_b110_physical_state_t, &
       fmr_new_b110_committed_state, prepare_fmr_b110_default_mvg, &
       fmr_c_drain_salt_forcing_t, FMR_C_DRAIN_UNIT_MG_CM3, fmr_c_drain_salt_covers_interval, &
       fmr_c_drain_salt_matches_trial, fmr_soil_salt_boundary_forcing_t, &
       fmr_soil_salt_boundary_matches_trial
  use mod_fmr_macropore_configuration, only: fmr_macropore_physical_config_t
  use mod_fmr_restart_state_contract, only: fmr_restart_state_matches_template
  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t, fmr_export_committed_restart, &
       fmr_restore_committed_restart, FMR_RESTART_OK, FMR_RESTART_SCHEMA_VERSION, &
       FMR_RESTART_SCHEMA_PREVIOUS, FMR_RESTART_SCHEMA_LEGACY_DISABLED, FMR_RESTART_SCHEMA_MISMATCH, &
       FMR_RESTART_PARAMETER_MISMATCH, FMR_RESTART_FORCING_MISMATCH
  use mod_solute_water_face_flux_reconstruction, only: reconstruct_interval_water_face_flux, WATER_FACE_FLUX_OK
  use mod_solute_mobile_salt_state, only: mobile_salt_state_t, mobile_salt_substep_t, mobile_salt_fluxes_t, &
       initialize_mobile_salt_state, advance_mobile_salt_trace, SOLUTE_OK, SOLUTE_WATER_CLOSURE
  use mod_solute_macropore_exchange, only: mobile_macro_salt_state_t, mobile_macro_salt_transfer_t, &
       transfer_mobile_macro_salt_trace, EXCHANGE_OK, EXCHANGE_DONOR_UNAVAILABLE
  use mod_solute_mobile_macro_salt_transport, only: mobile_macro_salt_receipt_t, &
       mobile_macro_salt_substep_t, advance_mobile_macro_salt_trace, initialize_mobile_macro_salt_state, MACRO_SALT_OK
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
  call exercise_salt_state_layout()

  write(*,'(*(g0))') 'PPA_WU05A7_REAL_RICHARDS|OUTER_IT=',result%outer_iterations, &
       '|QEXC=',sum(result%exchange_rate_node), &
       '|MATRIX_RES=',result%matrix_result%integrated_mass_balance_residual_cm, &
       '|MACRO_RES=',result%macro_balance_residual_cm
  print '(a)', 'PPA_WU05A7_REAL_RICHARDS_RUNTIME=PASS'

contains

  subroutine exercise_salt_state_layout()
    type(fmr_b110_physical_state_t) :: physical
    type(fmr_template_t) :: template, templates(1)
    type(fmr_logical_column_t) :: columns(1)
    type(kernel_committed_state_t) :: committed(1), restored_registry(1), macro_restored_registry(1), &
         rejected_registry(1), disabled_registry(1)
    type(fmr_committed_restart_bundle_t) :: bundle
    class(transaction_state_t), allocatable :: cloned, restored_state
    logical :: ok, exported, restored, available
    integer :: restart_status

    physical%active_nodes=3
    allocate(physical%pressure_head(3),physical%water_content(3),physical%salt)
    physical%pressure_head=[-10.0_real64,-20.0_real64,-30.0_real64]
    physical%water_content=[0.31_real64,0.29_real64,0.27_real64]
    allocate(physical%salt%mass_mg_cm2(3))
    physical%salt%mass_mg_cm2=[0.1_real64,0.2_real64,0.3_real64]
    physical%salt%cdrain_source_id=77_int64
    physical%salt%cdrain_revision=4_int64
    template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    template%template_id=7105_int64
    template%physics_topology_id=1_int64
    template%vertical_layout_id=1_int64
    template%state_layout_id=1_int64
    template%solver_interface_id=1_int64
    template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
    template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    template%solute_state_layout_id=FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED

    call physical%clone(cloned)
    select type (copy=>cloned)
    type is (fmr_b110_physical_state_t)
      if(.not.allocated(copy%salt))error stop 'salt component clone allocation'
      if(any(copy%salt%mass_mg_cm2/=physical%salt%mass_mg_cm2))error stop 'salt component clone mass'
      if(copy%salt%cdrain_source_id/=77_int64.or.copy%salt%cdrain_revision/=4_int64) &
           error stop 'salt component clone Cdrain provenance'
      if(.not.fmr_restart_state_matches_template(copy,template))error stop 'salt layout valid clone'
    class default
      error stop 'salt component clone family'
    end select

    if(.not.fmr_restart_state_matches_template(physical,template))error stop 'salt layout valid state'
    templates(1)=template
    columns(1)%column_id=7105_int64
    columns(1)%template_id=template%template_id
    columns(1)%parameter_ref=1_int64
    columns(1)%state_handle=1_int64
    columns(1)%forcing_handle=1_int64
    columns(1)%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    call fmr_new_b110_committed_state(committed(1),7105_int64,physical,0.0_real64,ok)
    if(.not.ok)error stop 'salt state committed initialization'
    call fmr_export_committed_restart(columns,templates,committed,99_int64,bundle,exported,restart_status)
    if(.not.exported .or. restart_status/=FMR_RESTART_OK)error stop 'salt Restart v3 export'
    if(bundle%schema_version/=FMR_RESTART_SCHEMA_VERSION)error stop 'salt Restart v4 schema'
    if(bundle%records(1)%forcing_handle/=columns(1)%forcing_handle)error stop 'restart forcing handle export'
    call fmr_restore_committed_restart(bundle,99_int64,columns,templates,restored_registry,restored,restart_status)
    if(.not.restored .or. restart_status/=FMR_RESTART_OK)error stop 'salt Restart v4 restore'
    call restored_registry(1)%snapshot(restored_state,available)
    if(.not.available .or. .not.allocated(restored_state))error stop 'salt restored state snapshot'
    select type (restored_physical=>restored_state)
    type is (fmr_b110_physical_state_t)
      if(.not.allocated(restored_physical%salt))error stop 'salt Restart v4 component missing'
      if(any(restored_physical%salt%mass_mg_cm2/=physical%salt%mass_mg_cm2)) &
           error stop 'salt Restart v4 mass identity'
      if(restored_physical%salt%cdrain_source_id/=77_int64.or. &
         restored_physical%salt%cdrain_revision/=4_int64)error stop 'salt Restart Cdrain provenance'
    class default
      error stop 'salt Restart v3 state family'
    end select
    columns(1)%forcing_handle=2_int64
    call fmr_restore_committed_restart(bundle,99_int64,columns,templates,rejected_registry,restored,restart_status)
    if(restored .or. restart_status/=FMR_RESTART_FORCING_MISMATCH) &
         error stop 'restart accepted mismatched forcing identity'
    if(rejected_registry(1)%ready())error stop 'forcing identity rejection mutated registry'
    columns(1)%forcing_handle=1_int64

    bundle%schema_version=FMR_RESTART_SCHEMA_PREVIOUS
    bundle%records(1)%schema_version=FMR_RESTART_SCHEMA_PREVIOUS
    call fmr_restore_committed_restart(bundle,99_int64,columns,templates,rejected_registry,restored,restart_status)
    if(restored .or. restart_status/=FMR_RESTART_SCHEMA_MISMATCH)error stop 'v3 active-salt restart accepted'
    if(rejected_registry(1)%ready())error stop 'v3 active-salt rejection mutated registry'
    bundle%schema_version=FMR_RESTART_SCHEMA_VERSION
    bundle%records(1)%schema_version=FMR_RESTART_SCHEMA_VERSION
    template%solute_state_layout_id=FMR_SOLUTE_STATE_LAYOUT_NONE
    if(fmr_restart_state_matches_template(physical,template))error stop 'salt layout disabled mismatch'

    deallocate(physical%salt)
    template%solute_state_layout_id=FMR_SOLUTE_STATE_LAYOUT_NONE
    templates(1)=template
    call fmr_new_b110_committed_state(committed(1),7105_int64,physical,0.0_real64,ok)
    if(.not.ok)error stop 'disabled-salt committed initialization'
    call fmr_export_committed_restart(columns,templates,committed,99_int64,bundle,exported,restart_status)
    if(.not.exported .or. restart_status/=FMR_RESTART_OK)error stop 'disabled-salt Restart v3 export'
    bundle%schema_version=FMR_RESTART_SCHEMA_PREVIOUS
    bundle%records(1)%schema_version=FMR_RESTART_SCHEMA_PREVIOUS
    call fmr_restore_committed_restart(bundle,99_int64,columns,templates,disabled_registry,restored,restart_status)
    if(.not.restored .or. restart_status/=FMR_RESTART_OK)error stop 'v3 disabled-salt restart rejected'
    call disabled_registry(1)%snapshot(restored_state,available)
    if(.not.available .or. .not.allocated(restored_state))error stop 'disabled-salt restored snapshot'
    select type (restored_physical=>restored_state)
    type is (fmr_b110_physical_state_t)
      if(allocated(restored_physical%salt))error stop 'v2 disabled restart added salt state'
    class default
      error stop 'v3 disabled restart state family'
    end select
    bundle%schema_version=FMR_RESTART_SCHEMA_LEGACY_DISABLED
    bundle%records(1)%schema_version=FMR_RESTART_SCHEMA_LEGACY_DISABLED
    call fmr_restore_committed_restart(bundle,99_int64,columns,templates,rejected_registry,restored,restart_status)
    if(.not.restored .or. restart_status/=FMR_RESTART_OK)error stop 'legacy disabled restart rejected'

    allocate(physical%salt)
    allocate(physical%salt%mass_mg_cm2(3))
    physical%salt%mass_mg_cm2=[0.1_real64,0.2_real64,0.3_real64]
    template%solute_state_layout_id=FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED
    physical%salt%mass_mg_cm2(2)=-1.0_real64
    if(fmr_restart_state_matches_template(physical,template))error stop 'negative salt mass accepted'
    physical%salt%mass_mg_cm2(2)=0.2_real64
    deallocate(physical%salt%mass_mg_cm2)
    allocate(physical%salt%mass_mg_cm2(2))
    physical%salt%mass_mg_cm2=0.1_real64
    if(fmr_restart_state_matches_template(physical,template))error stop 'salt node-count mismatch accepted'

    deallocate(physical%salt%mass_mg_cm2)
    allocate(physical%salt%mass_mg_cm2(3),physical%macropore)
    physical%salt%mass_mg_cm2=[0.1_real64,0.2_real64,0.3_real64]
    physical%salt%cdrain_source_id=77_int64
    physical%salt%cdrain_revision=5_int64
    call physical%macropore%initialize(2,3,ok)
    if(.not.ok)error stop 'macro-salt continuation initialization'
    physical%macropore%water_domain_cp=reshape([0.15_real64,0.12_real64,0.14_real64, &
         0.11_real64,0.09_real64,0.08_real64],[2,3])
    allocate(physical%salt%macro_mass_mg_cm2(2,3))
    physical%salt%macro_mass_mg_cm2=reshape([0.04_real64,0.03_real64,0.02_real64, &
         0.05_real64,0.06_real64,0.07_real64],[2,3])
    template%solute_state_layout_id=FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED_MACROPORE
    template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_MACROPORE
    if(.not.physical%salt%ready(3,2))error stop 'macro-salt typed state invalid'
    if(.not.fmr_restart_state_matches_template(physical,template))error stop 'macro-salt layout rejected'
    template%solute_state_layout_id=FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED
    if(fmr_restart_state_matches_template(physical,template))error stop 'matrix-only layout accepted macro mass'
    template%solute_state_layout_id=FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED_MACROPORE
    template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
    if(fmr_restart_state_matches_template(physical,template))error stop 'macro-salt accepted without macro layout'
    template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_MACROPORE
    physical%salt%macro_mass_mg_cm2(1,1)=-1.0_real64
    if(fmr_restart_state_matches_template(physical,template))error stop 'negative macro salt mass accepted'
    physical%salt%macro_mass_mg_cm2(1,1)=0.04_real64

    call physical%clone(cloned)
    select type (copy=>cloned)
    type is (fmr_b110_physical_state_t)
      if(.not.allocated(copy%macropore))error stop 'macro-salt clone lost water state'
      if(.not.allocated(copy%salt%macro_mass_mg_cm2))error stop 'macro-salt clone lost salt state'
      if(any(copy%salt%macro_mass_mg_cm2/=physical%salt%macro_mass_mg_cm2)) &
           error stop 'macro-salt clone mass mismatch'
    class default
      error stop 'macro-salt clone family'
    end select

    templates(1)=template
    call fmr_new_b110_committed_state(committed(1),7105_int64,physical,0.0_real64,ok)
    if(.not.ok)error stop 'macro-salt committed initialization'
    call fmr_export_committed_restart(columns,templates,committed,99_int64,bundle,exported,restart_status)
    if(.not.exported .or. restart_status/=FMR_RESTART_OK)error stop 'macro-salt Restart v3 export'
    call fmr_restore_committed_restart(bundle,99_int64,columns,templates,macro_restored_registry,restored,restart_status)
    if(.not.restored .or. restart_status/=FMR_RESTART_OK)error stop 'macro-salt Restart v3 restore'
    call macro_restored_registry(1)%snapshot(restored_state,available)
    if(.not.available .or. .not.allocated(restored_state))error stop 'macro-salt restored snapshot'
    select type (restored_physical=>restored_state)
    type is (fmr_b110_physical_state_t)
      if(.not.allocated(restored_physical%macropore))error stop 'macro-salt Restart lost water state'
      if(.not.allocated(restored_physical%salt%macro_mass_mg_cm2))error stop 'macro-salt Restart lost salt state'
      if(any(restored_physical%salt%macro_mass_mg_cm2/=physical%salt%macro_mass_mg_cm2)) &
           error stop 'macro-salt Restart mass mismatch'
      if(restored_physical%salt%cdrain_source_id/=77_int64.or. &
         restored_physical%salt%cdrain_revision/=5_int64)error stop 'macro-salt Restart provenance mismatch'
    class default
      error stop 'macro-salt Restart state family'
    end select
    print '(a)','PPA_WU05E_SALT_STATE_LAYOUT=PASS'
  end subroutine exercise_salt_state_layout

  subroutine exercise_salt_candidate_rejects_unowned_exchange(water_trace,node_thickness)
    type(fmr_water_flux_substep_trace_t), intent(in) :: water_trace(:)
    real(real64), intent(in) :: node_thickness(:)
    type(mobile_salt_substep_t), allocatable :: salt_trace(:)
    type(mobile_salt_state_t) :: committed_salt,candidate_salt
    type(mobile_salt_fluxes_t) :: salt_receipt
    real(real64), allocatable :: faces(:)
    real(real64) :: closure,other_water_source
    integer :: i,status,face_status

    if(size(water_trace)<2)error stop 'salt paired trace lacks accepted halfsteps'
    allocate(salt_trace(size(water_trace)))
    call initialize_mobile_salt_state(node_thickness,water_trace(1)%water_start, &
         spread(0.4_real64,1,size(node_thickness)),committed_salt,status)
    if(status/=SOLUTE_OK)error stop 'salt paired trace initialization'
    other_water_source=0.0_real64
    do i=1,size(water_trace)
      other_water_source=max(other_water_source,maxval(abs(water_trace(i)%net_node_source+ &
           water_trace(i)%root_sink)))
      call reconstruct_interval_water_face_flux(node_thickness,water_trace(i)%water_start, &
           water_trace(i)%water_end,water_trace(i)%net_node_source,-water_trace(i)%top_flux, &
           -water_trace(i)%bottom_flux,water_trace(i)%t1-water_trace(i)%t0,1.0e-8_real64, &
           faces,closure,face_status)
      if(face_status/=WATER_FACE_FLUX_OK)error stop 'salt paired trace face reconstruction'
      salt_trace(i)%water_start=water_trace(i)%water_start
      salt_trace(i)%water_trial=water_trace(i)%water_end
      salt_trace(i)%face_flux_cm_day=faces
      salt_trace(i)%root_water_sink_cm_day=water_trace(i)%root_sink
      salt_trace(i)%top_boundary_concentration=0.4_real64
      salt_trace(i)%bottom_boundary_concentration=0.4_real64
      salt_trace(i)%duration_day=water_trace(i)%t1-water_trace(i)%t0
    end do
    call advance_mobile_salt_trace(committed_salt,node_thickness,salt_trace,0.25_real64, &
         candidate_salt,salt_receipt,status)
    if(other_water_source<=1.0e-8_real64)error stop 'FMR trace did not exercise additional matrix water source'
    if(status/=SOLUTE_WATER_CLOSURE)error stop 'salt candidate accepted unowned matrix water exchange'
    if(allocated(candidate_salt%mass_mg_cm2).or.allocated(candidate_salt%concentration_mg_cm3)) &
         error stop 'failed paired salt candidate leaked state'
    if(salt_receipt%top_input_mg_cm2/=0.0_real64.or.salt_receipt%top_output_mg_cm2/=0.0_real64.or. &
       salt_receipt%bottom_input_mg_cm2/=0.0_real64.or.salt_receipt%bottom_output_mg_cm2/=0.0_real64.or. &
       salt_receipt%root_uptake_mg_cm2/=0.0_real64.or.salt_receipt%closure_error_mg_cm2/=0.0_real64) &
         error stop 'failed paired salt candidate published a partial receipt'
    if(any(committed_salt%mass_mg_cm2/=0.4_real64*water_trace(1)%water_start*node_thickness).or. &
       any(committed_salt%concentration_mg_cm3/=0.4_real64))error stop 'failed salt candidate mutated committed state'
    print '(a)','PPA_WU05E_FMR_SALT_CANDIDATE=FAIL_CLOSED_UNOWNED_MATRIX_EXCHANGE'
  end subroutine exercise_salt_candidate_rejects_unowned_exchange

  subroutine exercise_macro_salt_exchange_trace(water_trace,node_thickness)
    type(fmr_water_flux_substep_trace_t),intent(in)::water_trace(:)
    real(real64),intent(in)::node_thickness(:)
    type(mobile_macro_salt_state_t)::committed_macro,candidate_macro,replay_macro,rejected_macro
    type(mobile_macro_salt_transfer_t)::receipt,replay_receipt,rejected_receipt
    real(real64),allocatable::matrix_start(:,:),matrix_end(:,:),macro_start(:,:,:),macro_end(:,:,:)
    real(real64),allocatable::exchange(:,:,:),bad_exchange(:,:,:),duration(:),times0(:),times1(:)
    real(real64),allocatable::matrix_before(:),macro_before(:,:)
    real(real64)::inventory_before,inventory_after
    integer::n,nd,ns,k,status

    ns=size(water_trace);n=size(node_thickness)
    if(ns<2.or.n<=0)error stop 'macro salt trace lacks accepted sequence'
    if(.not.allocated(water_trace(1)%macropore_matrix_exchange_domain))error stop 'macro salt trace lacks domain exchange'
    nd=size(water_trace(1)%macropore_matrix_exchange_domain,1)
    if(nd<=0)error stop 'macro salt trace has no exchange domains'
    allocate(matrix_start(n,ns),matrix_end(n,ns),macro_start(nd,n,ns),macro_end(nd,n,ns), &
         exchange(nd,n,ns),duration(ns),times0(ns),times1(ns))
    do k=1,ns
      if(.not.allocated(water_trace(k)%macropore_matrix_exchange_domain).or. &
         .not.allocated(water_trace(k)%macropore_water_start).or. &
         .not.allocated(water_trace(k)%macropore_water_end))error stop 'macro salt trace incomplete'
      if(any(shape(water_trace(k)%macropore_matrix_exchange_domain)/=[nd,n])) &
           error stop 'macro salt trace exchange shape'
      matrix_start(:,k)=water_trace(k)%water_start*node_thickness
      matrix_end(:,k)=water_trace(k)%water_end*node_thickness
      macro_start(:,:,k)=water_trace(k)%macropore_water_start
      macro_end(:,:,k)=water_trace(k)%macropore_water_end
      exchange(:,:,k)=water_trace(k)%macropore_matrix_exchange_domain
      duration(k)=water_trace(k)%t1-water_trace(k)%t0
      times0(k)=water_trace(k)%t0
      times1(k)=water_trace(k)%t1
    end do

    allocate(committed_macro%matrix_mass_mg_cm2(n),committed_macro%macro_mass_mg_cm2(nd,n))
    committed_macro%matrix_mass_mg_cm2=0.4_real64*matrix_start(:,1)
    committed_macro%macro_mass_mg_cm2=0.35_real64*macro_start(:,:,1)
    matrix_before=committed_macro%matrix_mass_mg_cm2
    macro_before=committed_macro%macro_mass_mg_cm2
    inventory_before=sum(matrix_before)+sum(macro_before)
    call transfer_mobile_macro_salt_trace(committed_macro,matrix_start,matrix_end,macro_start,macro_end, &
         exchange,duration,times0,times1,candidate_macro,receipt,status)
    if(status/=EXCHANGE_OK)error stop 'accepted FMR internal macro-salt exchange trace rejected'
    if(.not.allocated(candidate_macro%matrix_mass_mg_cm2).or. &
       .not.allocated(candidate_macro%macro_mass_mg_cm2))error stop 'macro-salt trace candidate missing'
    if(.not.allocated(receipt%macro_to_matrix_mg_cm2).or. &
       .not.allocated(receipt%matrix_to_macro_mg_cm2))error stop 'macro-salt trace receipt missing'
    inventory_after=sum(candidate_macro%matrix_mass_mg_cm2)+sum(candidate_macro%macro_mass_mg_cm2)
    if(abs(inventory_after-inventory_before)>1.0e-12_real64)error stop 'macro-salt trace inventory changed'
    if(abs(receipt%closure_error_mg_cm2)>1.0e-12_real64)error stop 'macro-salt trace closure'
    if(maxval(abs(receipt%macro_to_matrix_mg_cm2))+maxval(abs(receipt%matrix_to_macro_mg_cm2))<= &
       1.0e-14_real64)error stop 'macro-salt trace carried no internal transfer'
    call transfer_mobile_macro_salt_trace(committed_macro,matrix_start,matrix_end,macro_start,macro_end, &
         exchange,duration,times0,times1,replay_macro,replay_receipt,status)
    if(status/=EXCHANGE_OK)error stop 'macro-salt trace replay rejected'
    if(any(candidate_macro%matrix_mass_mg_cm2/=replay_macro%matrix_mass_mg_cm2).or. &
       any(candidate_macro%macro_mass_mg_cm2/=replay_macro%macro_mass_mg_cm2).or. &
       any(receipt%macro_to_matrix_mg_cm2/=replay_receipt%macro_to_matrix_mg_cm2).or. &
       any(receipt%matrix_to_macro_mg_cm2/=replay_receipt%matrix_to_macro_mg_cm2)) &
         error stop 'macro-salt trace replay identity'

    bad_exchange=exchange
    bad_exchange(1,1,ns)=-2.0_real64*max(matrix_start(1,ns),1.0e-6_real64)/duration(ns)
    call transfer_mobile_macro_salt_trace(committed_macro,matrix_start,matrix_end,macro_start,macro_end, &
         bad_exchange,duration,times0,times1,rejected_macro,rejected_receipt,status)
    if(status/=EXCHANGE_DONOR_UNAVAILABLE)error stop 'late macro-salt donor failure accepted'
    if(allocated(rejected_macro%matrix_mass_mg_cm2).or.allocated(rejected_macro%macro_mass_mg_cm2).or. &
       allocated(rejected_receipt%macro_to_matrix_mg_cm2).or.allocated(rejected_receipt%matrix_to_macro_mg_cm2)) &
         error stop 'late macro-salt failure leaked partial candidate'
    if(any(committed_macro%matrix_mass_mg_cm2/=matrix_before).or. &
       any(committed_macro%macro_mass_mg_cm2/=macro_before))error stop 'macro-salt trace mutated committed state'
    print '(a)','PPA_WU05E_TRACE_DRIVEN_INTERNAL_EXCHANGE=PASS_TEST_ONLY'
  end subroutine exercise_macro_salt_exchange_trace

  subroutine exercise_macro_salt_process_from_fmr_trace(water_trace,node_thickness)
    type(fmr_water_flux_substep_trace_t),intent(in)::water_trace(:)
    real(real64),intent(in)::node_thickness(:)
    type(mobile_macro_salt_substep_t),allocatable::salt_trace(:)
    type(mobile_macro_salt_state_t)::committed,candidate
    type(mobile_macro_salt_receipt_t)::receipt
    type(fmr_c_drain_salt_forcing_t)::cdrain
    type(fmr_soil_salt_boundary_forcing_t)::soil_boundary
    real(real64),allocatable::matrix_c(:),macro_c(:,:),faces(:)
    real(real64)::closure,max_qssdi
    integer::n,nd,nlev,i,status,face_status

    n=size(node_thickness)
    if(size(water_trace)<2.or.n<=0)error stop 'FMR salt process trace shape'
    if(.not.allocated(water_trace(1)%macropore_matrix_exchange_domain).or. &
       .not.allocated(water_trace(1)%drainage_sink_by_level))error stop 'FMR salt process trace missing routes'
    nd=size(water_trace(1)%macropore_matrix_exchange_domain,1)
    nlev=size(water_trace(1)%drainage_sink_by_level,1)
    if(nd<=0.or.nlev<=0)error stop 'FMR salt process trace empty routes'
    allocate(salt_trace(size(water_trace)),matrix_c(n),macro_c(nd,n))
    cdrain%available=.true.;cdrain%concentration_mg_cm3=0.25_real64
    cdrain%valid_t0=water_trace(1)%t0;cdrain%valid_t1=water_trace(size(water_trace))%t1
    cdrain%source_id=1_int64;cdrain%revision=0_int64;cdrain%unit_id=FMR_C_DRAIN_UNIT_MG_CM3
    if(.not.fmr_c_drain_salt_covers_interval(cdrain,cdrain%valid_t0,cdrain%valid_t1)) &
         error stop 'FMR Cdrain declared interval rejected'
    if(.not.fmr_c_drain_salt_matches_trial(cdrain,cdrain%source_id,cdrain%valid_t0,cdrain%valid_t1)) &
         error stop 'FMR Cdrain trial identity rejected'
    if(fmr_c_drain_salt_matches_trial(cdrain,cdrain%source_id+1_int64,cdrain%valid_t0,cdrain%valid_t1)) &
         error stop 'FMR Cdrain mismatched source identity accepted'
    if(fmr_c_drain_salt_covers_interval(cdrain,cdrain%valid_t0,cdrain%valid_t1+1.0e-9_real64)) &
         error stop 'FMR Cdrain incomplete interval accepted'
    cdrain%unit_id=0
    if(fmr_c_drain_salt_covers_interval(cdrain,cdrain%valid_t0,cdrain%valid_t1)) &
         error stop 'FMR Cdrain unknown unit accepted'
    cdrain%unit_id=FMR_C_DRAIN_UNIT_MG_CM3
    soil_boundary%available=.true.;soil_boundary%matrix_top_mg_cm3=.3_real64
    soil_boundary%matrix_bottom_mg_cm3=.5_real64
    soil_boundary%valid_t0=cdrain%valid_t0;soil_boundary%valid_t1=cdrain%valid_t1
    soil_boundary%source_id=cdrain%source_id;soil_boundary%revision=4_int64
    soil_boundary%unit_id=FMR_C_DRAIN_UNIT_MG_CM3
    allocate(soil_boundary%macropore_top_mg_cm3(2),soil_boundary%macropore_bottom_mg_cm3(2))
    soil_boundary%macropore_top_mg_cm3=[.2_real64,.4_real64]
    soil_boundary%macropore_bottom_mg_cm3=[.6_real64,.8_real64]
    if(.not.fmr_soil_salt_boundary_matches_trial(soil_boundary,cdrain%source_id,cdrain%valid_t0,cdrain%valid_t1,2)) &
         error stop 'typed soil salt boundary rejected'
    if(fmr_soil_salt_boundary_matches_trial(soil_boundary,cdrain%source_id+1_int64,cdrain%valid_t0,cdrain%valid_t1,2)) &
         error stop 'mismatched soil salt boundary source accepted'
    if(fmr_soil_salt_boundary_matches_trial(soil_boundary,cdrain%source_id,cdrain%valid_t0, &
         cdrain%valid_t1+1.0e-9_real64,2)) &
         error stop 'incomplete soil salt boundary interval accepted'
    if(fmr_soil_salt_boundary_matches_trial(soil_boundary,cdrain%source_id,cdrain%valid_t0,cdrain%valid_t1,3)) &
         error stop 'soil salt boundary domain mismatch accepted'
    soil_boundary%unit_id=0
    if(fmr_soil_salt_boundary_matches_trial(soil_boundary,cdrain%source_id,cdrain%valid_t0,cdrain%valid_t1,2)) &
         error stop 'unknown soil salt boundary unit accepted'
    soil_boundary%unit_id=FMR_C_DRAIN_UNIT_MG_CM3
    deallocate(soil_boundary%macropore_top_mg_cm3,soil_boundary%macropore_bottom_mg_cm3)
    allocate(soil_boundary%macropore_top_mg_cm3(2))
    if(fmr_soil_salt_boundary_matches_trial(soil_boundary,cdrain%source_id,cdrain%valid_t0,cdrain%valid_t1)) &
         error stop 'unpaired macropore boundary concentrations accepted'
    deallocate(soil_boundary%macropore_top_mg_cm3)
    matrix_c=0.4_real64;macro_c=0.3_real64
    call initialize_mobile_macro_salt_state(node_thickness,water_trace(1)%water_start, &
         water_trace(1)%macropore_water_start,matrix_c,macro_c,committed,status)
    if(status/=MACRO_SALT_OK)error stop 'FMR salt process profile initialization'
    max_qssdi=0.0_real64
    do i=1,size(water_trace)
      if(.not.allocated(water_trace(i)%drainage_sink_by_level).or. &
         .not.allocated(water_trace(i)%macropore_matrix_exchange_domain).or. &
         .not.allocated(water_trace(i)%macropore_vertical_face_rate).or. &
         .not.allocated(water_trace(i)%macropore_water_start).or. &
         .not.allocated(water_trace(i)%macropore_water_end))error stop 'FMR salt process incomplete observation'
      if(any(shape(water_trace(i)%drainage_sink_by_level)/=[nlev,n]).or. &
         any(shape(water_trace(i)%macropore_matrix_exchange_domain)/=[nd,n]).or. &
         any(shape(water_trace(i)%macropore_vertical_face_rate)/=[nd,n+1])) &
           error stop 'FMR salt process observation shape'
      salt_trace(i)%t0=water_trace(i)%t0;salt_trace(i)%t1=water_trace(i)%t1
      salt_trace(i)%matrix_water_start=water_trace(i)%water_start
      salt_trace(i)%matrix_water_end=water_trace(i)%water_end
      salt_trace(i)%macro_water_start=water_trace(i)%macropore_water_start
      salt_trace(i)%macro_water_end=water_trace(i)%macropore_water_end
      call reconstruct_interval_water_face_flux(node_thickness,water_trace(i)%water_start, &
           water_trace(i)%water_end,water_trace(i)%net_node_source,-water_trace(i)%top_flux, &
           -water_trace(i)%bottom_flux,water_trace(i)%t1-water_trace(i)%t0,1.0e-8_real64, &
           faces,closure,face_status)
      if(face_status/=WATER_FACE_FLUX_OK)error stop 'FMR salt process matrix faces'
      salt_trace(i)%matrix_face_rate=faces
      salt_trace(i)%macro_face_rate=water_trace(i)%macropore_vertical_face_rate
      salt_trace(i)%exchange_rate=water_trace(i)%macropore_matrix_exchange_domain
      salt_trace(i)%root_water_sink=water_trace(i)%root_sink
      salt_trace(i)%qdra_rate=water_trace(i)%drainage_sink_by_level
      salt_trace(i)%qssdi_rate=water_trace(i)%subsurface_source
      if(.not.fmr_c_drain_salt_covers_interval(cdrain,water_trace(i)%t0,water_trace(i)%t1)) &
           error stop 'FMR Cdrain trace interval coverage'
      salt_trace(i)%cdrain_mg_cm3=cdrain%concentration_mg_cm3
      salt_trace(i)%cdrain_available=.true.
      salt_trace(i)%matrix_top_concentration_mg_cm3=0.4_real64
      salt_trace(i)%matrix_bottom_concentration_mg_cm3=0.4_real64
      allocate(salt_trace(i)%macro_top_concentration_mg_cm3(nd), &
           salt_trace(i)%macro_bottom_concentration_mg_cm3(nd))
      salt_trace(i)%macro_top_concentration_mg_cm3=0.3_real64
      salt_trace(i)%macro_bottom_concentration_mg_cm3=0.3_real64
      max_qssdi=max(max_qssdi,maxval(abs(salt_trace(i)%qssdi_rate)))
    end do
    if(max_qssdi<=0.0_real64)error stop 'FMR salt process trace omitted qssdi water-only source'
    call advance_mobile_macro_salt_trace(committed,node_thickness,salt_trace,cdrain%concentration_mg_cm3,candidate,receipt,status)
    if(status/=MACRO_SALT_OK)error stop 'FMR trace mapped process salt candidate rejected'
    if(.not.allocated(candidate%matrix_mass_mg_cm2).or..not.allocated(candidate%macro_mass_mg_cm2)) &
         error stop 'FMR trace mapped process salt candidate missing'
    if(.not.allocated(receipt%qdra_signed_out_mg_cm2))error stop 'FMR trace mapped drainage receipt missing'
    if(size(receipt%qdra_signed_out_mg_cm2)/=nlev)error stop 'FMR trace mapped drainage receipt shape'
    if(sum(abs(receipt%qdra_signed_out_mg_cm2))<=0.0_real64)error stop 'FMR trace mapped drainage receipt empty'
    if(abs(receipt%closure_error_mg_cm2)>1.0e-10_real64)error stop 'FMR trace mapped salt ledger closure'
    if(any(candidate%matrix_mass_mg_cm2<0.0_real64).or.any(candidate%macro_mass_mg_cm2<0.0_real64)) &
         error stop 'FMR trace mapped negative salt inventory'
    print '(a)','PPA_WU05E_FMR_TRACE_MAPPED_SALT_PROCESS=PASS_TEST_ONLY'
  end subroutine exercise_macro_salt_process_from_fmr_trace

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
    real(real64) :: trace_closure, max_trace_closure, max_trace_macro_exchange, max_trace_macro_water_change
    real(real64) :: max_trace_macro_vertical_face
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

    allocate(forcing%drainage_flux_by_level(2,numnod),forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    forcing%top_flux=0.0_real64
    forcing%top_head=0.0_real64
    forcing%bottom_flux=0.0_real64
    forcing%bottom_head=-100.0_real64
    forcing%drainage_flux_by_level=0.0_real64
    forcing%subsurface_irrigation_source=0.0_real64
    forcing%root_extraction_sink=0.0_real64
    ! Exercise nonzero source plus opposing level-specific drainage signs.
    forcing%subsurface_irrigation_source(max(1,numnod-1))=2.0e-6_real64
    forcing%drainage_flux_by_level(1,max(1,numnod-1))=2.0e-6_real64
    forcing%drainage_flux_by_level(2,max(1,numnod-1))=-1.0e-6_real64
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
      template%solute_state_layout_id=FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED_MACROPORE
      call backend%run_trial(column,template,fparams,committed,forcing,numerical,0.0_real64,fmr_dt,checkpoint, &
           kres,candidate,kdiag)
      if(kres%completed.or.candidate%ready())error stop 'active salt trial accepted missing Cdrain'
      allocate(forcing%c_drain_salt)
      forcing%c_drain_salt%available=.true.
      forcing%c_drain_salt%concentration_mg_cm3=0.25_real64
      forcing%c_drain_salt%valid_t0=0.0_real64
      forcing%c_drain_salt%valid_t1=fmr_dt
      forcing%c_drain_salt%source_id=2_int64
      forcing%c_drain_salt%revision=0_int64
      forcing%c_drain_salt%unit_id=FMR_C_DRAIN_UNIT_MG_CM3
      call backend%run_trial(column,template,fparams,committed,forcing,numerical,0.0_real64,fmr_dt,checkpoint, &
           kres,candidate,kdiag)
      if(kres%completed.or.candidate%ready())error stop 'active salt trial accepted mismatched Cdrain handle'
      forcing%c_drain_salt%source_id=column%forcing_handle
      call backend%run_trial(column,template,fparams,committed,forcing,numerical,0.0_real64,fmr_dt,checkpoint, &
           kres,candidate,kdiag)
      if(kres%completed.or.candidate%ready())error stop 'active salt trial accepted missing soil boundary'
      allocate(forcing%soil_salt_boundary)
      forcing%soil_salt_boundary%available=.true.
      forcing%soil_salt_boundary%matrix_top_mg_cm3=.4_real64
      forcing%soil_salt_boundary%matrix_bottom_mg_cm3=.4_real64
      forcing%soil_salt_boundary%valid_t0=0.0_real64
      forcing%soil_salt_boundary%valid_t1=fmr_dt
      forcing%soil_salt_boundary%source_id=column%forcing_handle
      forcing%soil_salt_boundary%revision=0_int64
      forcing%soil_salt_boundary%unit_id=FMR_C_DRAIN_UNIT_MG_CM3
      allocate(forcing%soil_salt_boundary%macropore_top_mg_cm3(fparams%macropore%geometry%num_domains), &
           forcing%soil_salt_boundary%macropore_bottom_mg_cm3(fparams%macropore%geometry%num_domains))
      forcing%soil_salt_boundary%macropore_top_mg_cm3=.3_real64
      forcing%soil_salt_boundary%macropore_bottom_mg_cm3=.3_real64
      call backend%run_trial(column,template,fparams,committed,forcing,numerical,0.0_real64,fmr_dt,checkpoint, &
           kres,candidate,kdiag)
      if(kres%completed.or.candidate%ready())error stop 'unqualified active salt trial opened'
      deallocate(forcing%soil_salt_boundary)
      deallocate(forcing%c_drain_salt)
      template%solute_state_layout_id=FMR_SOLUTE_STATE_LAYOUT_NONE
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
      max_trace_macro_exchange=0.0_real64
      max_trace_macro_water_change=0.0_real64
      max_trace_macro_vertical_face=0.0_real64
      do trace_i=1,size(fmr_observation%accepted_water_flux_substeps)
        if(.not.allocated(fmr_observation%accepted_water_flux_substeps(trace_i)%drainage_sink_by_level)) &
             error stop 'FMR trace omitted level-resolved drainage rates'
        if(any(shape(fmr_observation%accepted_water_flux_substeps(trace_i)%drainage_sink_by_level)/= &
             shape(forcing%drainage_flux_by_level))) error stop 'FMR trace drainage level shape mismatch'
        if(maxval(abs(fmr_observation%accepted_water_flux_substeps(trace_i)%drainage_sink_by_level- &
             forcing%drainage_flux_by_level))>0.0_real64) error stop 'FMR trace changed level-resolved drainage rates'
        if(maxval(abs(sum(fmr_observation%accepted_water_flux_substeps(trace_i)%drainage_sink_by_level,dim=1)- &
             fmr_observation%accepted_water_flux_substeps(trace_i)%drainage_sink))>1.0e-15_real64) &
             error stop 'FMR trace drainage level sum mismatch'
        if(.not.any(fmr_observation%accepted_water_flux_substeps(trace_i)%drainage_sink_by_level>0.0_real64) .or. &
           .not.any(fmr_observation%accepted_water_flux_substeps(trace_i)%drainage_sink_by_level<0.0_real64)) &
             error stop 'FMR trace lost signed drainage routes'
        if(maxval(abs(fmr_observation%accepted_water_flux_substeps(trace_i)%subsurface_source- &
             forcing%subsurface_irrigation_source))>0.0_real64) error stop 'FMR trace changed subsurface drip source'
        if(.not.allocated(fmr_observation%accepted_water_flux_substeps(trace_i)%macropore_matrix_exchange_domain)) &
             error stop 'FMR trace omitted per-domain macropore exchange'
        if(size(fmr_observation%accepted_water_flux_substeps(trace_i)%macropore_matrix_exchange_domain,1)<=0) &
             error stop 'FMR macro trace lost exchange domains'
        if(.not.allocated(fmr_observation%accepted_water_flux_substeps(trace_i)%macropore_water_start) .or. &
           .not.allocated(fmr_observation%accepted_water_flux_substeps(trace_i)%macropore_water_end)) &
             error stop 'FMR trace omitted domain water state'
        if(any(shape(fmr_observation%accepted_water_flux_substeps(trace_i)%macropore_water_start)/= &
             shape(fmr_observation%accepted_water_flux_substeps(trace_i)%macropore_matrix_exchange_domain)) .or. &
           any(shape(fmr_observation%accepted_water_flux_substeps(trace_i)%macropore_water_end)/= &
             shape(fmr_observation%accepted_water_flux_substeps(trace_i)%macropore_matrix_exchange_domain))) &
             error stop 'FMR trace domain water shape mismatch'
        if(any(fmr_observation%accepted_water_flux_substeps(trace_i)%macropore_water_start<0.0_real64) .or. &
           any(fmr_observation%accepted_water_flux_substeps(trace_i)%macropore_water_end<0.0_real64)) &
             error stop 'FMR trace invalid domain water state'
        if(.not.allocated(fmr_observation%accepted_water_flux_substeps(trace_i)%macropore_vertical_face_rate)) &
             error stop 'FMR trace omitted macro vertical faces'
        if(any(shape(fmr_observation%accepted_water_flux_substeps(trace_i)%macropore_vertical_face_rate)/= &
             [size(fmr_observation%accepted_water_flux_substeps(trace_i)%macropore_matrix_exchange_domain,1),numnod+1])) &
             error stop 'FMR macro vertical-face shape mismatch'
        if(any(.not.ieee_is_finite(fmr_observation%accepted_water_flux_substeps(trace_i)%macropore_vertical_face_rate))) &
             error stop 'FMR trace has nonfinite macro vertical face'
        if(maxval(abs((fmr_observation%accepted_water_flux_substeps(trace_i)%macropore_water_end- &
             fmr_observation%accepted_water_flux_substeps(trace_i)%macropore_water_start)/ &
             (fmr_observation%accepted_water_flux_substeps(trace_i)%t1- &
             fmr_observation%accepted_water_flux_substeps(trace_i)%t0) - &
             (fmr_observation%accepted_water_flux_substeps(trace_i)%macropore_vertical_face_rate(:,1:numnod)- &
             fmr_observation%accepted_water_flux_substeps(trace_i)%macropore_vertical_face_rate(:,2:numnod+1)- &
             fmr_observation%accepted_water_flux_substeps(trace_i)%macropore_matrix_exchange_domain)))> &
             1.0e-12_real64)error stop 'FMR macro domain water/face continuity'
        if(maxval(abs(sum(fmr_observation%accepted_water_flux_substeps(trace_i)%macropore_matrix_exchange_domain,dim=1)- &
             fmr_observation%accepted_water_flux_substeps(trace_i)%macropore_matrix_exchange))>1.0e-12_real64) &
             error stop 'FMR trace domain exchange sum mismatch'
        max_trace_macro_exchange=max(max_trace_macro_exchange, &
             maxval(abs(fmr_observation%accepted_water_flux_substeps(trace_i)%macropore_matrix_exchange_domain)))
        max_trace_macro_water_change=max(max_trace_macro_water_change, &
             maxval(abs(fmr_observation%accepted_water_flux_substeps(trace_i)%macropore_water_end- &
             fmr_observation%accepted_water_flux_substeps(trace_i)%macropore_water_start)))
        max_trace_macro_vertical_face=max(max_trace_macro_vertical_face, &
             maxval(abs(fmr_observation%accepted_water_flux_substeps(trace_i)%macropore_vertical_face_rate)))
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
      if(max_trace_macro_exchange<=1.0e-14_real64)error stop 'FMR trace did not carry nonzero domain exchange'
      if(max_trace_macro_water_change<=1.0e-14_real64)error stop 'FMR trace did not carry domain water change'
      if(max_trace_macro_vertical_face<=1.0e-14_real64)error stop 'FMR trace did not carry nonzero macro vertical face'
      call exercise_salt_candidate_rejects_unowned_exchange( &
           fmr_observation%accepted_water_flux_substeps,dz(1:numnod))
      call exercise_macro_salt_exchange_trace(fmr_observation%accepted_water_flux_substeps,dz(1:numnod))
      call exercise_macro_salt_process_from_fmr_trace( &
           fmr_observation%accepted_water_flux_substeps,dz(1:numnod))
      write(*,'(*(g0))') 'PPA_WU05E_FMR_ACCEPTED_SUBSTEP_TRACE=PASS|COUNT=', &
           size(fmr_observation%accepted_water_flux_substeps),'|MAX_CLOSURE=',max_trace_closure, &
           '|MAX_DOMAIN_EXCHANGE=',max_trace_macro_exchange,'|MAX_DOMAIN_WATER_CHANGE=',max_trace_macro_water_change, &
           '|MAX_MACRO_VERTICAL_FACE=',max_trace_macro_vertical_face
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
      if(.not.allocated(a%accepted_water_flux_substeps(i)%drainage_sink_by_level) .or. &
         .not.allocated(b%accepted_water_flux_substeps(i)%drainage_sink_by_level))return
      if(any(shape(a%accepted_water_flux_substeps(i)%drainage_sink_by_level)/= &
             shape(b%accepted_water_flux_substeps(i)%drainage_sink_by_level)))return
      if(any(transfer(a%accepted_water_flux_substeps(i)%drainage_sink_by_level,[0_int64], &
           size(a%accepted_water_flux_substeps(i)%drainage_sink_by_level))/= &
           transfer(b%accepted_water_flux_substeps(i)%drainage_sink_by_level,[0_int64], &
           size(b%accepted_water_flux_substeps(i)%drainage_sink_by_level))))return
      if(any(transfer(a%accepted_water_flux_substeps(i)%root_sink,[0_int64],numnod)/= &
             transfer(b%accepted_water_flux_substeps(i)%root_sink,[0_int64],numnod))) return
      if(any(transfer(a%accepted_water_flux_substeps(i)%net_node_source,[0_int64],numnod)/= &
             transfer(b%accepted_water_flux_substeps(i)%net_node_source,[0_int64],numnod))) return
      if(any(transfer(a%accepted_water_flux_substeps(i)%macropore_matrix_exchange,[0_int64],numnod)/= &
             transfer(b%accepted_water_flux_substeps(i)%macropore_matrix_exchange,[0_int64],numnod))) return
      if(.not.allocated(a%accepted_water_flux_substeps(i)%macropore_matrix_exchange_domain) .or. &
         .not.allocated(b%accepted_water_flux_substeps(i)%macropore_matrix_exchange_domain))return
      if(any(shape(a%accepted_water_flux_substeps(i)%macropore_matrix_exchange_domain)/= &
             shape(b%accepted_water_flux_substeps(i)%macropore_matrix_exchange_domain)))return
      if(size(a%accepted_water_flux_substeps(i)%macropore_matrix_exchange_domain)>0)then
        if(any(transfer(a%accepted_water_flux_substeps(i)%macropore_matrix_exchange_domain,[0_int64], &
             size(a%accepted_water_flux_substeps(i)%macropore_matrix_exchange_domain))/= &
             transfer(b%accepted_water_flux_substeps(i)%macropore_matrix_exchange_domain,[0_int64], &
             size(b%accepted_water_flux_substeps(i)%macropore_matrix_exchange_domain))))return
      end if
      if(any(transfer(a%accepted_water_flux_substeps(i)%macropore_water_start,[0_int64], &
           size(a%accepted_water_flux_substeps(i)%macropore_water_start))/= &
           transfer(b%accepted_water_flux_substeps(i)%macropore_water_start,[0_int64], &
           size(b%accepted_water_flux_substeps(i)%macropore_water_start))))return
      if(any(transfer(a%accepted_water_flux_substeps(i)%macropore_water_end,[0_int64], &
           size(a%accepted_water_flux_substeps(i)%macropore_water_end))/= &
           transfer(b%accepted_water_flux_substeps(i)%macropore_water_end,[0_int64], &
           size(b%accepted_water_flux_substeps(i)%macropore_water_end))))return
      if(.not.allocated(a%accepted_water_flux_substeps(i)%macropore_vertical_face_rate) .or. &
         .not.allocated(b%accepted_water_flux_substeps(i)%macropore_vertical_face_rate))return
      if(any(shape(a%accepted_water_flux_substeps(i)%macropore_vertical_face_rate)/= &
             shape(b%accepted_water_flux_substeps(i)%macropore_vertical_face_rate)))return
      if(size(a%accepted_water_flux_substeps(i)%macropore_vertical_face_rate)>0)then
        if(any(transfer(a%accepted_water_flux_substeps(i)%macropore_vertical_face_rate,[0_int64], &
             size(a%accepted_water_flux_substeps(i)%macropore_vertical_face_rate))/= &
             transfer(b%accepted_water_flux_substeps(i)%macropore_vertical_face_rate,[0_int64], &
             size(b%accepted_water_flux_substeps(i)%macropore_vertical_face_rate))))return
      end if
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

end program test_ppa_wu05a7_real_richards_runtime
