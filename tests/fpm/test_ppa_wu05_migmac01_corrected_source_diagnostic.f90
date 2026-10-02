program test_ppa_wu05_migmac01_corrected_source_diagnostic
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_swap_mp, only: frarmtrx,ictopmp
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, soil_water_physical_state_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_root_sink_provider, only: b110_root_sink_provider_t, bind_b110_root_sink_provider
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
       FMR_OPTIONAL_STATE_LAYOUT_MACROPORE, FMR_NUMERICAL_CONTINUATION_NONE, &
       FMR_NUMERICAL_CONTINUATION_MACROPORE_REDUCTION
  use mod_fmr_serialized_reference_backend, only: fmr_serialized_reference_backend_t, &
       fmr_serialized_physical_observation_t, fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_b110_macropore_reduction_state_t, &
       fmr_new_b110_committed_state, fmr_new_b110_macropore_reduction_committed_state, prepare_fmr_b110_default_mvg
  use mod_fmr_macropore_configuration, only: fmr_macropore_physical_config_t, initialize_fmr_macropore_standard_config
  use mod_fmr_restart_state_contract, only: fmr_restart_state_matches_template
  use mod_ppa_wu05_perch19_reduction_controller, only: macropore_reduction_continuation_t
  use mod_ppa_wu05a16_inner_macropore_provider, only: ppa_wu05a16_inner_macropore_provider_t
  use mod_macropore_covering_layer_input, only: covering_layer_input_request_t,evaluate_covering_layer_input
  use mod_macropore_standard_rate_adapter, only: matrix_saturated_zone_view_t,matrix_perched_zone_view_t, &
       derive_matrix_saturated_zone_view,derive_matrix_perched_zone_view
  use mod_macropore_single_column_runtime, only: macropore_single_column_runtime_t, &
       macropore_runtime_policy_t, macropore_runtime_result_t, MACRO_RUNTIME_INACTIVE, &
       MACRO_RUNTIME_CONVERGED
  implicit none

  real(real64),parameter::dt=3.70370352929630487e-05_real64,tol=1.0e-12_real64
  integer,parameter::nd=5

  type(soil_water_parameter_set_t),target::params
  type(b110_default_mvg_parameters_t),target::hp
  type(b110_default_mvg_provider_t),target::hyd
  type(b110_source_sink_provider_t),target::base_source
  type(b110_root_sink_provider_t),target::root_provider
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
  type(ppa_wu05a16_inner_macropore_provider_t)::probe
  type(covering_layer_input_request_t)::cover_probe
  real(real64)::source_end_h(numnod),source_end_theta(numnod),source_qexc(numnod),probe_exchange(numnod),probe_theta(numnod),end_node(7)
  real(real64),allocatable::covered_probe(:)
  logical::probe_active
  type(matrix_saturated_zone_view_t)::source_matrix_view
  type(matrix_perched_zone_view_t)::source_perched_view
  type(soil_water_physical_state_t)::source_rate_matrix
  real(real64)::source_rate_meta(13),source_rate_nodes(3,numnod)
  type(macropore_single_column_runtime_t)::runtime
  type(macropore_runtime_policy_t)::policy
  type(macropore_runtime_result_t)::result
  type(macropore_standard_storage_view_t)::initial_macro_view
  real(real64),allocatable,target::qdra(:,:),qssdi(:),qrot(:),qrot_zero(:)
  real(real64),allocatable::cofgen(:,:)
  real(real64)::heads(numnod),water(numnod),cond(numnod),cap(numnod),dkdh(numnod),storage_before,storage_after
  real(real64)::origin(77,numnod),node_cfg(7,numnod),domain_cfg(4,nd),source_scalars(12),end_scalars(7),levels(6),rapid_cfg(4)
  real(real64)::fraction(nd,numnod),diameter(numnod),cdarcy(nd,numnod)
  real(real64)::head_ratio_node, head_change_node, head_tolerance_node
  type(fmr_macropore_physical_config_t)::source_config
  integer::i,j,u,ios,ic,id,head_ratio_index
  character(len=20000)::line
  character(len=40)::label
  logical::ok

  allocate(params%z(numnod),params%dz(numnod),params%node_distance(numnod),cofgen(24,numnod))
  params%parameter_set_id=505701_int64
  params%active_nodes=numnod
  params%z=z; params%dz=dz; params%node_distance=disnod(1:numnod)

  open(newunit=u,file='tests/data/ppa_wu05_migmac01/corrected_b1_andelst_authority.csv',status='old')
  do
    read(u,'(a)',iostat=ios)line
    if(ios/=0)exit
    read(line,*)label
    select case(trim(label))
    case('ORIGIN_NODE')
      read(line,*)label,ic,origin(:,ic)
    case('END_NODE')
      read(line,*)label,ic,end_node
      source_end_h(ic)=end_node(1);source_end_theta(ic)=end_node(2);source_qexc(ic)=end_node(5)
    case('ORIGIN_NODE_CONFIG')
      read(line,*)label,ic,node_cfg(:,ic)
    case('ORIGIN_DOMAIN_CONFIG')
      read(line,*)label,id,domain_cfg(:,id)
    case('ORIGIN_SCALARS')
      read(line,*)label,source_scalars
    case('END_SCALARS')
      read(line,*)label,end_scalars
    case('ORIGIN_LEVELS')
      read(line,*)label,levels
    case('RAPID_CONFIG')
      read(line,*)label,rapid_cfg
    end select
  end do
  close(u)
  open(newunit=u,file='tests/data/ppa_wu05_migmac01/corrected_b1_andelst_last_rate.csv',status='old')
  read(u,'(a)')line
  read(line,*)label,source_rate_meta
  do ic=1,numnod
    read(u,'(a)')line
    read(line,*)label,id,source_rate_nodes(:,id)
  end do
  close(u)
  source_rate_matrix%active_nodes=numnod
  source_rate_matrix%pressure_head=source_rate_nodes(1,:)
  source_rate_matrix%water_content=source_rate_nodes(2,:)
  source_rate_matrix%groundwater_level=source_rate_meta(6)
  source_rate_matrix%ponding_depth=source_scalars(3)
  call derive_matrix_saturated_zone_view(source_rate_matrix,z,dz,source_matrix_view)
  call derive_matrix_perched_zone_view(source_rate_matrix,origin(14,:),z,dz,source_matrix_view, &
       source_rate_meta(13),source_perched_view)
  if(.not.source_matrix_view%valid.or..not.source_perched_view%valid)error stop 'source carrier probe invalid'
  write(*,'(*(g0))') 'SOURCE_CARRIER_AT_LAST_RATE|MAIN=',source_matrix_view%top_node, &
       '|PERCHED_ACTIVE=',source_perched_view%active,'|TOP=',source_perched_view%top_node, &
       '|BOTTOM=',source_perched_view%bottom_node,'|B111_MAIN=',int(source_rate_meta(10)), &
       '|B111_PERCHED_TOP=',int(source_rate_meta(11)),'|B111_PERCHED_BOTTOM=',int(source_rate_meta(12)), &
       '|MAX_HEAD_LAG=',maxval(abs(source_rate_nodes(1,:)-source_end_h))
  if(any(z/=origin(1,:)).or.any(dz/=origin(2,:)))error stop 'source grid mismatch'
  cofgen=origin(13:36,:)
  frarmtrx=origin(5,:)
  ictopmp=3
  call initialize_b110_default_mvg_parameters(hp,cofgen)
  call bind_b110_default_mvg_provider(hyd,hp,dt)

  heads=origin(3,:)
  water=origin(4,:)
  allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod))
  qdra(1,:)=origin(8,:);qssdi=origin(7,:);qrot=origin(6,:)
  allocate(qrot_zero(numnod));qrot_zero=0.0_real64
  call bind_b110_source_sink_provider(base_source,qdra,qssdi,qrot_zero)
  call bind_b110_root_sink_provider(root_provider,qrot)

  request%parameters=>params
  request%base_state%active_nodes=numnod
  allocate(request%base_state%pressure_head(numnod),request%base_state%water_content(numnod))
  request%base_state%pressure_head=heads
  request%base_state%water_content=water
  request%base_state%ponding_depth=source_scalars(3)
  request%base_state%groundwater_level=source_scalars(4)
  request%physical%matrix_area_fraction=origin(5,:)
  request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
  request%boundary%bottom_mode=2
  request%boundary%top_flux=end_scalars(3)
  request%boundary%bottom_flux=end_scalars(4)
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
  request%evaluation%root_sink=>root_provider
  request%evaluation%top_boundary=>top
  request%step_duration=dt

  call macro%initialize(nd,numnod,ok)
  if(.not.ok)error stop 'MIGMAC01 active macro init'
  macro%dynamic_volume_cp=origin(37,:)
  diameter=origin(12,:)
  diameter(1:2)=end_scalars(6) ! unused zero-volume covering geometry validity padding
  do id=1,nd
    j=37+8*(id-1)
    macro%sorptivity(id,:)=origin(j+1,:)
    macro%theta_sorption_ref(id,:)=origin(j+2,:)
    macro%absorption_time(id,:)=origin(j+3,:)
    macro%volume_domain_cp(id,:)=origin(j+4,:)
    macro%water_domain_cp(id,:)=origin(j+5,:)
    fraction(id,:)=origin(j+6,:)
    cdarcy(id,:)=levels(4)*8.0_real64*fraction(id,:)*dz*cofgen(3,:)/diameter**2
  end do
  macro%icp_bottom_domain=[92,64,54,42,26]
  call initialize_fmr_macropore_standard_config(source_config,3,origin(11,:),fraction, &
       int(domain_cfg(1,:)),z,dz,diameter,cofgen(2,:),cofgen(1,:),node_cfg(1,:),node_cfg(2,:), &
       node_cfg(3,:),origin(9,:),cofgen(9,:),node_cfg(4,:),cofgen(3,:),cdarcy,1.0_real64, &
       levels(4),int(levels(6)),ok,rapid_enabled=.true.,rapid_drain_type=2, &
       rapid_drain_level_cm=rapid_cfg(4),rapid_area_exponent=rapid_cfg(1), &
       rapid_kd_reference=rapid_cfg(2),rapid_resistance_reference_day=rapid_cfg(3),perched_enabled=.true., &
       critical_under_saturated_volume_cm=0.1_real64,matrix_area_fraction=origin(5,:), &
       covering_minimum_polygon_diameter_cm=10.0_real64,covering_ksat_cm_per_day=1.0_real64)
       ! exact official CRITUNDSATVOL plus captured covering physical parameters
  if(.not.ok)error stop 'source configuration invalid'
  geometry_config=source_config%geometry
  call evaluate_macropore_geometry(geometry_config,macro%dynamic_volume_cp,geometry)
  if(.not.geometry%valid)error stop 'source geometry invalid'
  if(any(geometry%bottom_domain/=macro%icp_bottom_domain))error stop 'source bottom mismatch'
  if(maxval(abs(geometry%volume_domain_cp-macro%volume_domain_cp))>tol)error stop 'source volume mismatch'
  macro_snapshot=macro
  call canonicalize_macropore_standard_storage(macro,3,z,dz,initial_macro_view,ok)
  if(.not.ok)error stop 'source storage invalid'
  if(maxval(abs(macro%water_domain_cp-macro_snapshot%water_domain_cp))>tol)error stop 'source canonical water mismatch'
  macro_snapshot=macro
  storage_before=sum(macro%water_domain_cp)
  rate_template=source_config%rate_template
  history_request=source_config%history_template

  call probe%configure(macro,geometry,rate_template,z,dz,dt,source_scalars(3),source_scalars(4),ok, &
       covering_minimum_polygon_diameter_cm=10.0_real64,covering_ksat_cm_per_day=1.0_real64)
  if(.not.ok)error stop 'probe configuration failed'
  call hyd%evaluate(source_end_h,probe_theta,cond,cap,dkdh)
  write(*,'(*(g0))') 'SOURCE_CONSTITUTIVE_PROBE|MAX_THETA_DIFF=',maxval(abs(probe_theta-source_end_theta))
  call probe%evaluate_rate(source_end_h,source_end_theta,probe_exchange,probe_active)
  write(*,'(*(g0))') 'SOURCE_PROVIDER_AT_REFERENCE|NODE2=',probe_exchange(2),'|OTHER=',sum(probe_exchange(3:)), &
       '|REFERENCE_NODE2=',source_qexc(2),'|REFERENCE_OTHER=',sum(source_qexc(3:)), &
       '|MAX_RATE_DIFF=',maxval(abs(probe_exchange-source_qexc)),'|NODE=',maxloc(abs(probe_exchange-source_qexc))
  do ic=3,numnod
    if(abs(probe_exchange(ic)-source_qexc(ic))>0.05_real64) &
      write(*,'(*(g0))') 'SOURCE_RATE_DIFF|NODE=',ic,'|SWAP5=',probe_exchange(ic),'|REFERENCE=',source_qexc(ic), &
        '|H=',source_end_h(ic),'|FRACTION=',origin(5,ic)
  end do
  call probe%configure(macro,geometry,rate_template,z,dz,dt,source_scalars(3),source_rate_meta(6),ok, &
       covering_minimum_polygon_diameter_cm=10.0_real64,covering_ksat_cm_per_day=1.0_real64)
  if(.not.ok)error stop 'corrected last-rate probe configure'
  call probe%evaluate_rate(source_rate_nodes(1,:),source_rate_nodes(2,:),probe_exchange,probe_active)
  write(*,'(*(g0))') 'CORRECTED_SOURCE_LAST_RATE|OTHER=',sum(probe_exchange(3:)), &
       '|REFERENCE_OTHER=',sum(source_rate_nodes(3,3:)), &
       '|MAX_DIFF=',maxval(abs(probe_exchange-source_rate_nodes(3,:)))
  call probe%evaluate_rate(source_end_h,source_end_theta,probe_exchange,probe_active)
  cover_probe%top_node=3;cover_probe%step_duration_day=dt
  cover_probe%matrix_head_above_cm=source_end_h(2);cover_probe%dz_above_cm=dz(2)
  cover_probe%minimum_polygon_diameter_cm=10.0_real64;cover_probe%covering_layer_ksat_cm_per_day=1.0_real64
  cover_probe%total_macropore_volume_top_cm=sum(geometry%volume_domain_cp(:,3))
  cover_probe%domain_top_volume_cm=geometry%volume_domain_cp(:,3)
  call evaluate_covering_layer_input(cover_probe,covered_probe,ok)
  if(.not.ok.or.sum(covered_probe)<=0.0_real64)error stop 'source operator probe failed'
  if(abs(probe_exchange(2)*dt+sum(covered_probe))>tol)error stop 'source operator sink mismatch'
  write(*,'(*(g0))') 'SOURCE_OPERATOR|H2=',source_end_h(2),'|COVERED=',sum(covered_probe),'|OWNERSHIP=EXACT'

  ! Disabled path: exactly direct Reference Richards.
  direct_request=request
  call solver%solve(direct_request,workspace,direct_result)
  if(direct_result%status/=SW_SOLVE_CONVERGED)then
    write(*,'(*(g0))') 'CORRECTED_SOURCE_DIRECT_REJECT|STATUS=',direct_result%status, &
         '|RETRY=',direct_result%retry_advised,'|MASS_AVAILABLE=',direct_result%integrated_mass_balance_residual_available,'|MASS=',direct_result%integrated_mass_balance_residual_cm, &
         '|NATIVE_AVAILABLE=',direct_result%native_balance_rate_residual_available, &
         '|NATIVE_RATE=',direct_result%native_balance_rate_residual_cm_per_day, &
         '|ITERATIONS=',direct_result%diagnostics%nonlinear_iterations, &
         '|MAX_LOCAL_RATE=',maxval(abs(workspace%richards%residual(1:numnod))), &
         '|LOCAL_NODE=',maxloc(abs(workspace%richards%residual(1:numnod))), &
         '|SCRATCH_RATE_SUM=',sum(workspace%richards%residual(1:numnod)), &
         '|SCRATCH_INTEGRATED_SUM=',dt*sum(workspace%richards%residual(1:numnod)), &
         '|LAST_TENTATIVE_H2=',workspace%richards%old_head(2), &
         '|THETA_QUANTUM_NODE36=',spacing(origin(4,36))*dz(36)/dt
    write(*,'(*(g0))') 'G6_NODE36_FINAL|RES=',workspace%richards%residual(36), &
         '|OLD_H=',workspace%richards%old_head(36), &
         '|HEAD_ULP=',spacing(workspace%richards%old_head(36)), &
         '|DELTA_H=',workspace%richards%delta_head(36), &
         '|JLOW=',workspace%richards%dfdh_lower(36), &
         '|JMAIN=',workspace%richards%dfdh_main(36), &
         '|JUP=',workspace%richards%dfdh_upper(36), &
         '|THETA=',workspace%richards%provider_theta(36), &
         '|THETA_ULP=',spacing(workspace%richards%provider_theta(36)), &
         '|CAP=',workspace%richards%provider_capacity(36), &
         '|FRARMTRX=',origin(5,36)
    write(*,'(*(g0))') 'G6_NODE36_REPRESENTABLE|RATE_UP=', &
         (nearest(workspace%richards%provider_theta(36),1.0_real64)-workspace%richards%provider_theta(36))* &
         origin(5,36)*dz(36)/dt, &
         '|RATE_DOWN=', &
         (nearest(workspace%richards%provider_theta(36),-1.0_real64)-workspace%richards%provider_theta(36))* &
         origin(5,36)*dz(36)/dt, &
         '|RES_IF_UP=',workspace%richards%residual(36)+ &
         (nearest(workspace%richards%provider_theta(36),1.0_real64)-workspace%richards%provider_theta(36))* &
         origin(5,36)*dz(36)/dt, &
         '|RES_IF_DOWN=',workspace%richards%residual(36)+ &
         (nearest(workspace%richards%provider_theta(36),-1.0_real64)-workspace%richards%provider_theta(36))* &
         origin(5,36)*dz(36)/dt, &
         '|THETA_ULP_HEAD_EQUIV=',spacing(workspace%richards%provider_theta(36))/ &
         max(abs(workspace%richards%provider_capacity(36)),tiny(1.0_real64))
    if(.not.macro%same_values(macro_snapshot))error stop 'direct diagnostic mutated accepted macro'
  end if
  if(direct_result%status==SW_SOLVE_CONVERGED)then
  write(*,'(*(g0))') 'SOURCE_DIRECT|H2=',direct_result%candidate_state%pressure_head(2), &
       '|MASS=',direct_result%integrated_mass_balance_residual_cm
  policy%enabled=.false.
  call runtime%execute(solver,workspace,request,macro,geometry_config,rate_template,history_request,policy,result, &
       covering_minimum_polygon_diameter_cm=10.0_real64,covering_ksat_cm_per_day=1.0_real64)
  if(result%status/=MACRO_RUNTIME_INACTIVE)error stop 'MIGMAC01 active inactive runtime status'
  if(any(transfer(result%matrix_result%candidate_state%water_content,[0_int64],numnod) /= &
         transfer(direct_result%candidate_state%water_content,[0_int64],numnod))) &
       error stop 'MIGMAC01 active inactive theta identity'
  if(any(transfer(result%matrix_result%candidate_state%pressure_head,[0_int64],numnod) /= &
         transfer(direct_result%candidate_state%pressure_head,[0_int64],numnod))) &
       error stop 'MIGMAC01 active inactive head identity'
  if(.not.result%macropore_candidate%same_values(macro_snapshot))error stop 'MIGMAC01 active inactive macro identity'

  end if

  ! Active strict source-backed standard macropore coupling.
  policy%enabled=.true.
  policy%inner_richards_exchange_enabled=.true.
  policy%max_correctors=80
  policy%exchange_relative_tolerance=1.0e-10_real64
  policy%exchange_floor=1.0e-12_real64
  policy%damping_previous_weight=0.5_real64
  policy%solver_mass_tolerance_cm=1.0e-9_real64
  policy%internal_exchange_tolerance_cm=1.0e-9_real64

  call runtime%execute(solver,workspace,request,macro,geometry_config,rate_template,history_request,policy,result, &
       covering_minimum_polygon_diameter_cm=10.0_real64,covering_ksat_cm_per_day=1.0_real64)
  if(result%status/=MACRO_RUNTIME_CONVERGED)then
    write(*,'(*(g0))') 'MIGMAC01_ACTIVE_DIAG|STATUS=',result%status,'|RETRY=',result%retry_advised, &
         '|OUTER=',result%outer_iterations,'|PRED=',result%predictor_solves,'|CORR=',result%corrector_solves, &
         '|REL=',result%final_relative_exchange_change,'|COVERED=',result%covered_internal_transfer_cm, &
         '|INNER_RES=',result%internal_exchange_residual_cm,'|MACRO_RES=',result%macro_balance_residual_cm, &
         '|MATRIX_STATUS=',result%matrix_result%status,'|MATRIX_RES=',result%matrix_result%integrated_mass_balance_residual_cm
    write(*,'(*(g0))') 'SOURCE_INNER_LAST_TRIAL|H2=',workspace%richards%old_head(2), &
         '|ITERATIONS=',workspace%legacy_worker%diagnostics%nonlinear_iterations
    write(*,'(*(g0))') 'ACTIVE_INNER_SCRATCH|MAX_RATE=',maxval(abs(workspace%richards%residual(1:numnod))), &
         '|NODE=',maxloc(abs(workspace%richards%residual(1:numnod)),dim=1), &
         '|RATE_SUM=',sum(workspace%richards%residual(1:numnod)), &
         '|INTEGRATED_SUM=',dt*sum(workspace%richards%residual(1:numnod))
    write(*,'(*(g0))') 'ACTIVE_INNER_GATES|FMAX=',workspace%richards%last_fmax_rate, &
         '|COMP_OK=',workspace%richards%last_compartment_gate_passed, &
         '|TOTAL=',workspace%richards%last_total_balance_rate, &
         '|TOTAL_OK=',workspace%richards%last_total_gate_passed, &
         '|HEAD_RATIO=',workspace%richards%last_head_criterion_ratio, &
         '|HEAD_OK=',workspace%richards%last_head_gate_passed
    head_ratio_index=1
    head_ratio_node=-1.0_real64
    head_change_node=0.0_real64
    head_tolerance_node=0.0_real64
    do ic=1,numnod
      head_change_node=abs(workspace%richards%delta_head(ic))
      if(abs(workspace%richards%old_head(ic))<1.0_real64)then
        head_tolerance_node=request%numerical%head_abs_tolerance
      else
        head_tolerance_node=request%numerical%head_rel_tolerance*abs(workspace%richards%old_head(ic))
      end if
      if(head_tolerance_node>0.0_real64 .and. head_change_node/head_tolerance_node>head_ratio_node)then
        head_ratio_node=head_change_node/head_tolerance_node
        head_ratio_index=ic
      end if
    end do
    head_change_node=abs(workspace%richards%delta_head(head_ratio_index))
    if(abs(workspace%richards%old_head(head_ratio_index))<1.0_real64)then
      head_tolerance_node=request%numerical%head_abs_tolerance
    else
      head_tolerance_node=request%numerical%head_rel_tolerance*abs(workspace%richards%old_head(head_ratio_index))
    end if
    write(*,'(*(g0))') 'ACTIVE_INNER_HEAD_LIMIT|NODE=',head_ratio_index, &
         '|RATIO=',head_ratio_node,'|OLD_H=',workspace%richards%old_head(head_ratio_index), &
         '|DELTA_H=',workspace%richards%delta_head(head_ratio_index),'|TOL_H=',head_tolerance_node, &
         '|H_ULP=',spacing(workspace%richards%old_head(head_ratio_index)), &
         '|RES=',workspace%richards%residual(head_ratio_index), &
         '|JMAIN=',workspace%richards%dfdh_main(head_ratio_index)
    write(*,'(*(g0))') 'ACTIVE_INNER_NODE|RES=', &
         workspace%richards%residual(maxloc(abs(workspace%richards%residual(1:numnod)),dim=1)), &
         '|OLD_H=',workspace%richards%old_head(maxloc(abs(workspace%richards%residual(1:numnod)),dim=1)), &
         '|DELTA_H=',workspace%richards%delta_head(maxloc(abs(workspace%richards%residual(1:numnod)),dim=1)), &
         '|THETA=',workspace%richards%provider_theta(maxloc(abs(workspace%richards%residual(1:numnod)),dim=1)), &
         '|DTHETA=',workspace%richards%provider_water_content_increment( &
              maxloc(abs(workspace%richards%residual(1:numnod)),dim=1)), &
         '|CAP=',workspace%richards%provider_capacity(maxloc(abs(workspace%richards%residual(1:numnod)),dim=1))
    if(.not.macro%same_values(macro_snapshot))error stop 'diagnostic mutated accepted macro'
    if(result%status/=3.or..not.result%retry_advised)error stop 'unexpected diagnostic outcome; reassess evidence'
    print '(a)', 'PPA_WU05_MIGMAC01_CORRECTED_SOURCE=BLOCKED_NOT_QUALIFIED'
    stop 0
  end if
  if(.not.result%inner_richards_exchange_used)error stop 'MIGMAC01 active direct route missing'
  write(*,'(*(g0))') 'MIGMAC01_ACTIVE_ACCEPTED|H2=',result%matrix_result%candidate_state%pressure_head(2), &
       '|COVERED=',result%covered_internal_transfer_cm,'|STATUS=',result%status
  if(result%covered_internal_transfer_cm<=0.0_real64)error stop 'MIGMAC01 active covered transfer missing'
  if(result%exchange_rate_node(2)>=0.0_real64)error stop 'MIGMAC01 active covered matrix sink missing'
  storage_after=sum(result%macropore_candidate%water_domain_cp)
  if(storage_after<=storage_before)error stop 'MIGMAC01 active macro storage did not increase'
  if(abs(result%internal_exchange_residual_cm)>1.0e-9_real64)error stop 'MIGMAC01 active internal residual'
  if(abs(result%macro_balance_residual_cm)>1.0e-9_real64)error stop 'MIGMAC01 active macro residual'
  if(result%vertical_flux%max_local_residual_rate>1.0e-10_real64)error stop 'MIGMAC01 active vertical residual'
  if(.not.macro%same_values(macro_snapshot))error stop 'MIGMAC01 active accepted macro mutated'

  call exercise_source_transaction()

  print '(a)', 'PPA_WU05_MIGMAC01_CORRECTED_SOURCE=SOURCE_TRANSACTION_QUALIFIED'

contains

  subroutine exercise_source_transaction()
    type(fmr_serialized_reference_backend_t) :: backend
    type(fmr_b110_physical_parameters_t), target :: fparams
    type(fmr_b110_physical_forcing_t) :: forcing
    type(fmr_b110_physical_state_t) :: initial
    type(macropore_reduction_continuation_t) :: reduction_initial
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(canonical_numerical_config_t) :: numerical
    type(kernel_committed_state_t) :: committed, restored
    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_candidate_state_t) :: candidate, replay_candidate
    type(kernel_result_t) :: kres, replay_result
    type(kernel_diagnostics_t) :: kdiag, replay_diag
    type(kernel_persistence_snapshot_t) :: persisted
    class(transaction_state_t), allocatable :: before_state, after_state, candidate_state, replay_state, restored_state
    logical :: prepared, state_ok, available, did_commit, persisted_ok, restored_ok, policy_ok
    integer :: commit_status, persistence_status
    integer(int64), parameter :: lineage=505901_int64, layout_id=505001_int64

    fparams%parameter_set_id=lineage
    fparams%active_nodes=numnod
    allocate(fparams%z(numnod),fparams%dz(numnod),fparams%node_distance(numnod),fparams%cofgen(24,numnod))
    fparams%z=z
    fparams%dz=dz
    fparams%node_distance=disnod(1:numnod)
    fparams%cofgen=cofgen
    fparams%bottom_mode=2
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
    if(.not.prepared)error stop 'MIGMAC01 source transaction MVG'
    allocate(fparams%macropore)
    fparams%macropore=source_config
    if(.not.fparams%macropore%valid_for_nodes(numnod))error stop 'MIGMAC01 source transaction config'

    initial%active_nodes=numnod
    allocate(initial%pressure_head(numnod),initial%water_content(numnod),initial%macropore)
    initial%pressure_head=heads
    initial%water_content=water
    initial%ponding_depth=source_scalars(3)
    initial%groundwater_level=source_scalars(4)
    initial%macropore=macro

    reduction_initial=macropore_reduction_continuation_t(level=0,stable_steps=0,previous_dt=dt)
    call fmr_new_b110_macropore_reduction_committed_state(committed,lineage,initial,reduction_initial, &
         source_scalars(1),state_ok)
    if(.not.state_ok)error stop 'MIGMAC01 source transaction committed init'

    allocate(forcing%drainage_flux_by_level(1,numnod),forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    forcing%top_flux=end_scalars(3)
    forcing%top_head=0.0_real64
    forcing%bottom_flux=end_scalars(4)
    forcing%bottom_head=-100.0_real64
    forcing%drainage_flux_by_level=qdra
    forcing%subsurface_irrigation_source=qssdi
    forcing%root_extraction_sink=qrot

    column%column_id=lineage
    column%template_id=lineage
    column%parameter_ref=lineage
    column%state_handle=1_int64
    column%forcing_handle=1_int64
    column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    template%template_id=lineage
    template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_MACROPORE
    template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_MACROPORE_REDUCTION
    template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE

    numerical%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
    numerical%transaction%temporal_tolerance=1.0e-2_real64
    numerical%transaction%mass_tolerance=1.0e-8_real64
    numerical%transaction%retry_scale=0.5_real64
    numerical%transaction%max_retries=40
    numerical%max_committed_substeps=64

    policy%source_reduction_retry_enabled=.true.
    call backend%initialize(top)
    call backend%configure_macropore_policy(policy,policy_ok)
    if(.not.policy_ok)error stop 'MIGMAC01 source transaction policy'

    call committed%capture_checkpoint(checkpoint,available)
    if(.not.available)error stop 'MIGMAC01 source transaction checkpoint'
    call committed%snapshot(before_state,available)
    if(.not.available)error stop 'MIGMAC01 source transaction before state'

    call backend%run_trial(column,template,fparams,committed,forcing,numerical,source_scalars(1), &
         source_scalars(1)+dt,checkpoint,kres,candidate,kdiag,trusted_prepared_parameters=.true.)
    write(*,'(*(g0))') 'MIGMAC01_SOURCE_TRANSACTION|STATUS=',kres%status,'|COMPLETED=',kres%completed, &
         '|MASS=',kres%mass%residual,'|SOLVER_REJ=',kdiag%solver_rejections, &
         '|TEMP_REJ=',kdiag%temporal_rejections,'|MASS_REJ=',kdiag%mass_rejections
    if(.not.kres%completed .or. .not.candidate%ready())error stop 'MIGMAC01 source transaction trial'
    if(.not.kres%mass%complete .or. abs(kres%mass%residual)>1.0e-8_real64) &
         error stop 'MIGMAC01 source transaction mass'

    call committed%snapshot(after_state,available)
    if(.not.available .or. .not.same_source_state(before_state,after_state)) &
         error stop 'MIGMAC01 source transaction candidate leaked'
    call candidate%snapshot(candidate_state,available)
    if(.not.available)error stop 'MIGMAC01 source transaction candidate snapshot'

    call backend%discard_trial_candidate(candidate,kdiag)
    if(candidate%ready())error stop 'MIGMAC01 source transaction discard'
    call committed%snapshot(after_state,available)
    if(.not.available .or. .not.same_source_state(before_state,after_state)) &
         error stop 'MIGMAC01 source transaction discard mutated committed'

    call backend%run_trial(column,template,fparams,committed,forcing,numerical,source_scalars(1), &
         source_scalars(1)+dt,checkpoint,replay_result,replay_candidate,replay_diag,trusted_prepared_parameters=.true.)
    if(.not.replay_result%completed .or. .not.replay_candidate%ready())error stop 'MIGMAC01 source transaction replay'
    call replay_candidate%snapshot(replay_state,available)
    if(.not.available .or. .not.same_source_state(candidate_state,replay_state)) &
         error stop 'MIGMAC01 source transaction replay identity'

    call backend%commit_trial_candidate(committed,replay_candidate,replay_diag,did_commit,commit_status)
    if(.not.did_commit .or. commit_status/=0)error stop 'MIGMAC01 source transaction commit'
    call committed%snapshot(after_state,available)
    if(.not.available .or. .not.same_source_state(replay_state,after_state)) &
         error stop 'MIGMAC01 source transaction commit publication'

    call export_kernel_committed_state(committed,layout_id,persisted,persisted_ok,persistence_status)
    if(.not.persisted_ok .or. persistence_status/=KERNEL_PERSISTENCE_OK) &
         error stop 'MIGMAC01 source transaction persistence export'
    call restore_kernel_committed_state(persisted,layout_id,restored,restored_ok,persistence_status)
    if(.not.restored_ok .or. persistence_status/=KERNEL_PERSISTENCE_OK) &
         error stop 'MIGMAC01 source transaction persistence restore'
    call restored%snapshot(restored_state,available)
    if(.not.available .or. .not.fmr_restart_state_matches_template(restored_state,template)) &
         error stop 'MIGMAC01 source transaction restart layout'
    if(.not.same_source_state(after_state,restored_state))error stop 'MIGMAC01 source transaction restart identity'

    print '(a)', 'PPA_WU05_MIGMAC01_SOURCE_REJECT_REPLAY=PASS'
    print '(a)', 'PPA_WU05_MIGMAC01_SOURCE_COMMIT=PASS'
    print '(a)', 'PPA_WU05_MIGMAC01_SOURCE_RESTART=PASS'
  end subroutine exercise_source_transaction

  logical function same_source_state(a,b) result(same)
    class(transaction_state_t),intent(in)::a,b
    same=.false.
    select type(x=>a)
    class is(fmr_b110_physical_state_t)
      select type(y=>b)
      class is(fmr_b110_physical_state_t)
        if(x%active_nodes/=y%active_nodes)return
        if(.not.allocated(x%pressure_head).or..not.allocated(y%pressure_head))return
        if(.not.allocated(x%water_content).or..not.allocated(y%water_content))return
        if(.not.allocated(x%macropore).or..not.allocated(y%macropore))return
        same=all(x%pressure_head==y%pressure_head).and.all(x%water_content==y%water_content).and. &
             x%ponding_depth==y%ponding_depth.and.x%groundwater_level==y%groundwater_level.and. &
             x%macropore%same_values(y%macropore)
      end select
    end select
  end function same_source_state

end program test_ppa_wu05_migmac01_corrected_source_diagnostic
