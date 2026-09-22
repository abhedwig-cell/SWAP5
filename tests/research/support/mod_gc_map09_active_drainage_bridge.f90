module mod_pub_gc_e6_active_drainage_bridge
  use, intrinsic :: iso_c_binding, only: c_double, c_int
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_forcing_t, canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_temporal_indicator_committed_state
  use mod_fmr_groundwater_head_forcing_adapter, only: fmr_groundwater_head_forcing_materializer_t
  use mod_fmr_groundwater_swap_participant, only: fmr_groundwater_swap_participant_t
  use mod_fmr_drainage_response_binding, only: FMR_DRAIN_VARIANT_TABULATED
  use mod_groundwater_swap_transaction_participant, only: groundwater_swap_trial_t, GW_SWAP_PARTICIPANT_OK, &
       GW_SWAP_PARTICIPANT_TRIAL_FAILED, GW_SWAP_PARTICIPANT_EXCHANGE_FAILED
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t, groundwater_coupling_window_t, &
       groundwater_interface_state_t, groundwater_interface_lineage_t, &
       swap_bottom_flux_cm_per_day_to_interface_flux_m_per_s, pair_groundwater_flux_from_swap, GW_INTERFACE_OK
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t, &
       groundwater_interface_mass_prepared_t, groundwater_interface_mass_snapshot_t, GW_MASS_LEDGER_OK
  use mod_groundwater_multiswap_types, only: groundwater_direct_tile_binding_t
  use mod_modflow6_swap_prescribed_qbot_bottom_face, only: modflow6_prescribed_qbot_bottom_face_t, &
       materialize_modflow6_prescribed_qbot_bottom_face, MODFLOW6_BOTTOM_FACE_OK
  use mod_modflow6_swap_predictor_response, only: modflow6_swap_predictor_lineage_t, modflow6_swap_predictor_response_t
  use mod_modflow6_swap_predictor_origin, only: modflow6_swap_predictor_origin_t, &
       capture_modflow6_swap_predictor_origin, MODFLOW6_PREDICTOR_ORIGIN_OK
  use mod_modflow6_swap_predictor_tangent_adapter, only: modflow6_swap_predictor_tangent_endpoint_t, &
       build_modflow6_swap_predictor_tangent_endpoint, MODFLOW6_TANGENT_ENDPOINT_OK
  use mod_modflow6_swap_predictor_candidate_assembler, only: assemble_modflow6_swap_predictor_response, &
       MODFLOW6_PREDICTOR_ASSEMBLER_OK
  use mod_modflow6_multiswap_cell_response, only: modflow6_multiswap_cell_response_t, &
       compose_modflow6_multiswap_cell_response, MODFLOW6_MULTI_CELL_OK
  use mod_modflow6_linear_response_backend, only: modflow6_linear_boundary_term_t, &
       compose_modflow6_linear_boundary_term, MODFLOW6_LINEAR_BACKEND_OK
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_soil_water_solver_contract, only: soil_water_physical_state_t, soil_water_parameter_set_t
  use mod_soil_water_accepted_step_direction_contract, only: SW_STEP_CONTROL_BOTTOM_FLUX
  implicit none
  private

  real(real64), parameter :: DEFAULT_DURATION_DAY=1.0e-2_real64
  real(real64), parameter :: MASS_TOL=1.0e-10_real64
  real(real64), parameter :: HEAD_TOL=1.0e-12_real64
  real(real64), parameter :: DEFAULT_PREDICTOR_QBOT=2.0e-3_real64
  real(real64), parameter :: HEAD_BUDGET=1.0_real64
  integer(int64), parameter :: COLUMN_ID=560061_int64
  integer(int64), parameter :: COUPLING_ID=460061_int64
  integer(int64), parameter :: GW_CELL_ID=7001_int64
  integer(int64), parameter :: GW_SERVICE_ID=660061_int64
  integer(int64), parameter :: GW_LINEAGE_ID=660062_int64
  integer(int64), parameter :: LEDGER_ID=760061_int64
  real(real64), parameter :: AREA_M2=1.0_real64

  type(fmr_b110_physical_parameters_t), save :: predictor_parameters, corrector_parameters
  type(fmr_b110_physical_forcing_t), save :: base_forcing
  type(fmr_logical_column_t), save :: column
  type(fmr_template_t), save :: template
  type(canonical_numerical_config_t), save :: predictor_config, corrector_config
  type(kernel_committed_state_t), save :: committed
  type(fmr_serialized_reference_backend_t), save :: predictor_backend, corrector_backend
  type(fmr_groundwater_head_forcing_materializer_t), save :: materializer
  type(fmr_groundwater_swap_participant_t), save :: participant
  type(groundwater_swap_trial_t), save :: last_trial
  type(groundwater_head_datum_t), save :: datum
  type(groundwater_coupling_window_t), save :: window
  type(groundwater_interface_mass_ledger_t), save :: ledger
  type(groundwater_interface_mass_prepared_t), save :: prepared_ledger
  type(fixed_flux_top_boundary_provider_t), target, save :: top
  logical, save :: initialized=.false.
  logical, save :: ledger_prepared=.false.
  logical, save :: drainage_tangent_covered=.false.
  real(real64), save :: active_duration_day=DEFAULT_DURATION_DAY
  real(real64), save :: active_predictor_qbot=DEFAULT_PREDICTOR_QBOT
  integer(int64), save :: g14_fused_corrector_runs=0_int64

  ! PUB-GC E1 publication diagnostics. These values are captured from the same
  ! real predictor trial used by PUB-GC E6. They are test/qualification evidence,
  ! not a production coupling API.
  logical, save :: e1_ready=.false.
  logical, save :: e1_mass_complete=.false.
  real(real64), save :: e1_q_bot_predictor_cm_per_day=0.0_real64
  real(real64), save :: e1_q_u_cm_per_day=0.0_real64
  real(real64), save :: e1_u=0.0_real64
  real(real64), save :: e1_h_start_m=0.0_real64
  real(real64), save :: e1_h_end_m=0.0_real64
  real(real64), save :: e1_bottom_outward_exchange_native=0.0_real64
  real(real64), save :: e1_terminal_bottom_outward_flux_native=0.0_real64
  real(real64), save :: e1_storage_start=0.0_real64
  real(real64), save :: e1_storage_end=0.0_real64
  real(real64), save :: e1_storage_change=0.0_real64
  real(real64), save :: e1_total_in=0.0_real64
  real(real64), save :: e1_total_out=0.0_real64
  real(real64), save :: e1_mass_residual=0.0_real64

  ! PUB-GC E3-D2: retain the real predictor kernel result/diagnostics even
  ! when configured initialization fails before response construction.
  logical, save :: e3d2_predictor_diagnostics_ready=.false.
  type(kernel_result_t), save :: e3d2_predictor_result
  type(kernel_diagnostics_t), save :: e3d2_predictor_diagnostics

  public :: pub_gc_e6_swap_initialize_c, pub_gc_e6_swap_initialize_configured_c, pub_gc_e6_swap_trial_c, pub_gc_e6_swap_discard_c
  public :: pub_gc_e6_swap_preflight_c, pub_gc_e6_ledger_prepare_c, pub_gc_e6_ledger_preflight_c
  public :: pub_gc_e6_swap_commit_c, pub_gc_e6_ledger_commit_c, pub_gc_e6_abort_prepublication_c
  public :: pub_gc_e6_state_c
  public :: pub_gc_e6_e1_diagnostics_c, pub_gc_e6_last_trial_diagnostics_c
  public :: pub_gc_e6_predictor_run_diagnostics_c, pub_gc_e6_corrector_diagnostics_c, pub_gc_e6_drainage_coverage_c
  public :: pub_gc_e6_g14_fused_observation_c, pub_gc_e6_g14_fused_run_count_c

contains

  integer(c_int) function pub_gc_e6_swap_initialize_c(hcof, rhs, reference_head) bind(C,name="pub_gc_e6_swap_initialize_c")
    real(c_double), intent(out) :: hcof, rhs, reference_head
    call pub_gc_e6_initialize_impl(DEFAULT_DURATION_DAY,DEFAULT_PREDICTOR_QBOT,hcof,rhs,reference_head,pub_gc_e6_swap_initialize_c)
  end function pub_gc_e6_swap_initialize_c

  integer(c_int) function pub_gc_e6_swap_initialize_configured_c(duration_day,predictor_qbot,hcof,rhs,reference_head) &
       bind(C,name="pub_gc_e6_swap_initialize_configured_c")
    real(c_double), value, intent(in) :: duration_day,predictor_qbot
    real(c_double), intent(out) :: hcof,rhs,reference_head
    call pub_gc_e6_initialize_impl(real(duration_day,real64),real(predictor_qbot,real64),hcof,rhs,reference_head, &
         pub_gc_e6_swap_initialize_configured_c)
  end function pub_gc_e6_swap_initialize_configured_c

  subroutine pub_gc_e6_initialize_impl(duration_day,predictor_qbot,hcof,rhs,reference_head,c_status)
    real(real64), intent(in) :: duration_day,predictor_qbot
    real(c_double), intent(out) :: hcof,rhs,reference_head
    integer(c_int), intent(out) :: c_status
    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    type(fmr_b110_physical_forcing_t) :: predictor_forcing
    type(soil_water_physical_state_t) :: predictor_state
    type(soil_water_parameter_set_t) :: solver_parameters
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: constitutive
    type(modflow6_swap_predictor_tangent_endpoint_t) :: endpoint
    type(modflow6_swap_predictor_origin_t) :: origin
    type(modflow6_swap_predictor_lineage_t) :: predictor_lineage
    type(modflow6_swap_predictor_response_t) :: response(1)
    type(modflow6_prescribed_qbot_bottom_face_t) :: start_face
    type(groundwater_interface_state_t) :: accepted_interface
    type(groundwater_direct_tile_binding_t) :: binding(1)
    type(modflow6_multiswap_cell_response_t) :: cell
    type(modflow6_linear_boundary_term_t) :: term
    real(real64) :: qeq,q_swap,q_groundwater
    integer :: status,flux_status
    logical :: ok

    c_status=101_c_int; hcof=0.0_c_double; rhs=0.0_c_double; reference_head=0.0_c_double
    initialized=.false.; ledger_prepared=.false.; e1_ready=.false.; e1_mass_complete=.false.; drainage_tangent_covered=.false.
    g14_fused_corrector_runs=0_int64
    e3d2_predictor_diagnostics_ready=.false.
    e3d2_predictor_result=kernel_result_t()
    e3d2_predictor_diagnostics=kernel_diagnostics_t()
    if(.not.ieee_is_finite(duration_day) .or. duration_day<=0.0_real64)return
    if(.not.ieee_is_finite(predictor_qbot))return
    active_duration_day=duration_day
    active_predictor_qbot=predictor_qbot

    call initialize_parameters(predictor_parameters,SW_STEP_CONTROL_BOTTOM_FLUX)
    call initialize_parameters(corrector_parameters,5)
    ! GC-REAL-SWAP-MAP09 research-only delta: prescribed-head corrector
    ! keeps lagged active drainage but removes the qbot-only smooth-freatic projection.
    corrector_parameters%drainage_qbot_smooth_freatic_projection=.false.
    qeq=active_predictor_qbot
    call initialize_forcing(base_forcing,qeq)
    call initialize_column_template(column,template)
    call initialize_configs(predictor_config,corrector_config)
    c_status=102_c_int
    call initialize_committed_state(committed,predictor_parameters,ok)
    if(.not.ok)return

    datum%available=.true.; datum%datum_id=560061_int64; datum%bottom_boundary_elevation_m=0.0_real64
    window%t0=0.0_real64; window%t1=active_duration_day
    call predictor_backend%initialize(top)
    call corrector_backend%initialize(top)
    call materializer%initialize(base_forcing)

    c_status=103_c_int
    call fmr_capture_checkpoint(committed,checkpoint,ok); if(.not.ok)return
    predictor_forcing=base_forcing; predictor_forcing%bottom_flux=qeq
    c_status=104_c_int
    call predictor_backend%run_trial(column,template,predictor_parameters,committed,predictor_forcing,predictor_config, &
         window%t0,window%t1,checkpoint,result,candidate,diagnostics)
    e3d2_predictor_result=result
    e3d2_predictor_diagnostics=diagnostics
    e3d2_predictor_diagnostics_ready=.true.
    if(.not.result%completed)return
    c_status=105_c_int
    if(.not.candidate%ready())return
    c_status=106_c_int
    if(.not.result%accepted_trajectory_direction%available)return

    c_status=107_c_int
    call initialize_b110_default_mvg_parameters(hp,predictor_parameters%cofgen)
    call bind_b110_default_mvg_provider(constitutive,hp,active_duration_day)
    call materialize_solver_view(candidate,predictor_state,solver_parameters,ok); if(.not.ok)return
    call build_modflow6_swap_predictor_tangent_endpoint(predictor_state,solver_parameters,constitutive, &
         result%accepted_trajectory_direction,qeq,datum,.false.,.false.,.true.,.false.,endpoint,status)
    if(status/=MODFLOW6_TANGENT_ENDPOINT_OK .or. .not.endpoint%authoritative)return
    drainage_tangent_covered=endpoint%coverage%drainage_active .and. endpoint%coverage%drainage_covered
    if(.not.drainage_tangent_covered)return
    c_status=108_c_int
    call materialize_origin_face(predictor_parameters,hp,qeq,start_face,status)
    if(status/=MODFLOW6_BOTTOM_FACE_OK .or. .not.start_face%valid)return

    predictor_lineage%coupling_id=COUPLING_ID
    predictor_lineage%swap_lineage_id=COLUMN_ID
    predictor_lineage%swap_origin_revision=0_int64
    predictor_lineage%groundwater_service_id=GW_SERVICE_ID
    predictor_lineage%groundwater_lineage_id=GW_LINEAGE_ID
    predictor_lineage%groundwater_origin_revision=0_int64
    c_status=109_c_int
    call swap_bottom_flux_cm_per_day_to_interface_flux_m_per_s(qeq,q_swap,flux_status); if(flux_status/=GW_INTERFACE_OK)return
    c_status=110_c_int
    call pair_groundwater_flux_from_swap(q_swap,q_groundwater,flux_status); if(flux_status/=GW_INTERFACE_OK)return
    accepted_interface%h_swap_m=start_face%hydraulic_head_m
    accepted_interface%h_groundwater_m=start_face%hydraulic_head_m
    accepted_interface%q_swap_m_per_s=q_swap
    accepted_interface%q_groundwater_m_per_s=q_groundwater
    c_status=111_c_int
    call capture_modflow6_swap_predictor_origin(accepted_interface,window%t0,predictor_lineage,.true.,origin,status)
    if(status/=MODFLOW6_PREDICTOR_ORIGIN_OK)return
    c_status=112_c_int
    call assemble_modflow6_swap_predictor_response(origin,window,candidate,result,endpoint,response(1),status)
    if(status/=MODFLOW6_PREDICTOR_ASSEMBLER_OK .or. .not.response(1)%valid)return

    e1_q_bot_predictor_cm_per_day=response(1)%q_bot_predictor_cm_per_day
    e1_q_u_cm_per_day=response(1)%q_u_cm_per_day
    e1_u=response(1)%coupling_storage_coefficient_u
    e1_h_start_m=response(1)%h_bot_start_m
    e1_h_end_m=response(1)%h_bot_end_m
    e1_bottom_outward_exchange_native=result%bottom_outward_exchange_native
    e1_terminal_bottom_outward_flux_native=result%terminal_bottom_outward_flux_native
    e1_mass_complete=result%mass%complete
    e1_storage_start=result%mass%storage_start
    e1_storage_end=result%mass%storage_end
    e1_storage_change=result%mass%storage_change
    e1_total_in=result%mass%total_in
    e1_total_out=result%mass%total_out
    e1_mass_residual=result%mass%residual
    e1_ready=.true.

    binding(1)%groundwater_cell_id=GW_CELL_ID; binding(1)%tile_id=COLUMN_ID; binding(1)%area_fraction=1.0_real64
    c_status=113_c_int
    call compose_modflow6_multiswap_cell_response(binding,response,response(1)%h_bot_end_m,cell,status)
    if(status/=MODFLOW6_MULTI_CELL_OK .or. .not.cell%valid)return
    c_status=114_c_int
    call compose_modflow6_linear_boundary_term(cell,AREA_M2,term,status)
    if(status/=MODFLOW6_LINEAR_BACKEND_OK .or. .not.term%valid)return
    hcof=term%hcof_m2_per_day; rhs=term%rhs_m3_per_day; reference_head=term%reference_head_m

    call predictor_backend%discard_trial_candidate(candidate,diagnostics)
    c_status=115_c_int
    call participant%capture_origin(committed,status); if(status/=GW_SWAP_PARTICIPANT_OK)return
    c_status=116_c_int
    call ledger%bind_identity(LEDGER_ID,status); if(status/=GW_MASS_LEDGER_OK)return
    initialized=.true.; c_status=0_c_int
  end subroutine pub_gc_e6_initialize_impl

  integer(c_int) function pub_gc_e6_swap_trial_c(head_m,q_swap_m_per_s) bind(C,name="pub_gc_e6_swap_trial_c")
    real(c_double), value, intent(in) :: head_m
    real(c_double), intent(out) :: q_swap_m_per_s
    integer :: status
    pub_gc_e6_swap_trial_c=1_c_int; q_swap_m_per_s=0.0_c_double
    if(.not.initialized)return
    call participant%trial_from_origin(corrector_backend,column,template,corrector_parameters,committed,materializer, &
         corrector_config,datum,window,real(head_m,real64),last_trial,status)
    if(status/=GW_SWAP_PARTICIPANT_OK .or. .not.last_trial%valid)then
      pub_gc_e6_swap_trial_c=int(status,c_int)
      return
    end if
    q_swap_m_per_s=last_trial%q_swap_m_per_s
    pub_gc_e6_swap_trial_c=0_c_int
  end function pub_gc_e6_swap_trial_c

  integer(c_int) function pub_gc_e6_corrector_diagnostics_c(head_m,result_status,completed,candidate_ready, &
       transaction_calls,accepted_substeps,attempts,retries,trial_rollbacks,solver_rejections,temporal_rejections, &
       temporal_unavailable_rejections,mass_rejections,internal_retries,mass_complete,mass_residual,max_temporal_indicator, &
       min_substep,max_substep) bind(C,name="pub_gc_e6_corrector_diagnostics_c")
    real(c_double), value, intent(in) :: head_m
    integer(c_int), intent(out) :: result_status,completed,candidate_ready,transaction_calls,accepted_substeps,attempts,retries
    integer(c_int), intent(out) :: trial_rollbacks,solver_rejections,temporal_rejections,temporal_unavailable_rejections
    integer(c_int), intent(out) :: mass_rejections,internal_retries,mass_complete
    real(c_double), intent(out) :: mass_residual,max_temporal_indicator,min_substep,max_substep
    class(canonical_forcing_t), allocatable :: forcing
    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    logical :: ok
    integer :: forcing_status

    pub_gc_e6_corrector_diagnostics_c=1_c_int
    result_status=-1_c_int; completed=0_c_int; candidate_ready=0_c_int
    transaction_calls=0_c_int; accepted_substeps=0_c_int; attempts=0_c_int; retries=0_c_int; trial_rollbacks=0_c_int
    solver_rejections=0_c_int; temporal_rejections=0_c_int; temporal_unavailable_rejections=0_c_int
    mass_rejections=0_c_int; internal_retries=0_c_int; mass_complete=0_c_int
    mass_residual=0.0_c_double; max_temporal_indicator=0.0_c_double; min_substep=0.0_c_double; max_substep=0.0_c_double
    if(.not.initialized)return
    call fmr_capture_checkpoint(committed,checkpoint,ok); if(.not.ok)return
    call materializer%materialize(real(head_m,real64),datum,forcing,forcing_status)
    if(forcing_status/=0 .or. .not.allocated(forcing))return
    select type(typed_forcing=>forcing)
    type is(fmr_b110_physical_forcing_t)
      call corrector_backend%run_trial(column,template,corrector_parameters,committed,typed_forcing,corrector_config, &
           window%t0,window%t1,checkpoint,result,candidate,diagnostics)
    class default
      return
    end select
    result_status=int(result%status,c_int)
    if(result%completed)completed=1_c_int
    if(candidate%ready())candidate_ready=1_c_int
    transaction_calls=int(diagnostics%transaction_calls,c_int)
    accepted_substeps=int(diagnostics%accepted_substeps,c_int)
    attempts=int(diagnostics%attempts,c_int)
    retries=int(diagnostics%retries,c_int)
    trial_rollbacks=int(diagnostics%trial_rollbacks,c_int)
    solver_rejections=int(diagnostics%solver_rejections,c_int)
    temporal_rejections=int(diagnostics%temporal_rejections,c_int)
    temporal_unavailable_rejections=int(diagnostics%temporal_certificate_unavailable_rejections,c_int)
    mass_rejections=int(diagnostics%mass_rejections,c_int)
    internal_retries=int(diagnostics%internal_retries,c_int)
    if(result%mass%complete)mass_complete=1_c_int
    mass_residual=result%mass%residual
    max_temporal_indicator=diagnostics%max_temporal_indicator
    min_substep=diagnostics%min_accepted_substep_duration
    max_substep=diagnostics%max_accepted_substep_duration
    if(candidate%ready())call corrector_backend%discard_trial_candidate(candidate,diagnostics)
    pub_gc_e6_corrector_diagnostics_c=0_c_int
  end function pub_gc_e6_corrector_diagnostics_c


  integer(c_int) function pub_gc_e6_g14_fused_observation_c(head_m,participant_status,q_swap_m_per_s, &
       result_status,completed,candidate_ready,transaction_calls,accepted_substeps,attempts,retries,trial_rollbacks, &
       solver_rejections,temporal_rejections,temporal_unavailable_rejections,mass_rejections,internal_retries, &
       min_substep,max_substep) bind(C,name="pub_gc_e6_g14_fused_observation_c")
    real(c_double), value, intent(in) :: head_m
    integer(c_int), intent(out) :: participant_status,result_status,completed,candidate_ready,transaction_calls
    integer(c_int), intent(out) :: accepted_substeps,attempts,retries,trial_rollbacks,solver_rejections
    integer(c_int), intent(out) :: temporal_rejections,temporal_unavailable_rejections,mass_rejections,internal_retries
    real(c_double), intent(out) :: q_swap_m_per_s,min_substep,max_substep
    class(canonical_forcing_t), allocatable :: forcing
    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    real(real64) :: duration_day,qbot_mean_cm_per_day
    integer :: forcing_status,interface_status
    logical :: ok

    pub_gc_e6_g14_fused_observation_c=1_c_int
    participant_status=GW_SWAP_PARTICIPANT_TRIAL_FAILED
    q_swap_m_per_s=0.0_c_double
    result_status=-1_c_int; completed=0_c_int; candidate_ready=0_c_int
    transaction_calls=0_c_int; accepted_substeps=0_c_int; attempts=0_c_int; retries=0_c_int
    trial_rollbacks=0_c_int; solver_rejections=0_c_int; temporal_rejections=0_c_int
    temporal_unavailable_rejections=0_c_int; mass_rejections=0_c_int; internal_retries=0_c_int
    min_substep=0.0_c_double; max_substep=0.0_c_double
    if(.not.initialized)return

    call materializer%materialize(real(head_m,real64),datum,forcing,forcing_status)
    if(forcing_status/=0 .or. .not.allocated(forcing))then
      pub_gc_e6_g14_fused_observation_c=2_c_int
      return
    end if
    call fmr_capture_checkpoint(committed,checkpoint,ok)
    if(.not.ok .or. .not.checkpoint%ready())then
      pub_gc_e6_g14_fused_observation_c=3_c_int
      return
    end if

    select type(typed_forcing=>forcing)
    type is(fmr_b110_physical_forcing_t)
      g14_fused_corrector_runs=g14_fused_corrector_runs+1_int64
      call corrector_backend%run_trial(column,template,corrector_parameters,committed,typed_forcing,corrector_config, &
           window%t0,window%t1,checkpoint,result,candidate,diagnostics)
    class default
      pub_gc_e6_g14_fused_observation_c=4_c_int
      return
    end select

    result_status=int(result%status,c_int)
    if(result%completed)completed=1_c_int
    if(candidate%ready())candidate_ready=1_c_int
    transaction_calls=int(diagnostics%transaction_calls,c_int)
    accepted_substeps=int(diagnostics%accepted_substeps,c_int)
    attempts=int(diagnostics%attempts,c_int)
    retries=int(diagnostics%retries,c_int)
    trial_rollbacks=int(diagnostics%trial_rollbacks,c_int)
    solver_rejections=int(diagnostics%solver_rejections,c_int)
    temporal_rejections=int(diagnostics%temporal_rejections,c_int)
    temporal_unavailable_rejections=int(diagnostics%temporal_certificate_unavailable_rejections,c_int)
    mass_rejections=int(diagnostics%mass_rejections,c_int)
    internal_retries=int(diagnostics%internal_retries,c_int)
    min_substep=diagnostics%min_accepted_substep_duration
    max_substep=diagnostics%max_accepted_substep_duration

    if(g14_whole_window_ok(result,candidate))then
      duration_day=window%t1-window%t0
      qbot_mean_cm_per_day=-result%bottom_outward_exchange_native/duration_day
      call swap_bottom_flux_cm_per_day_to_interface_flux_m_per_s(qbot_mean_cm_per_day,q_swap_m_per_s,interface_status)
      if(interface_status==GW_INTERFACE_OK .and. ieee_is_finite(real(q_swap_m_per_s,real64)))then
        participant_status=GW_SWAP_PARTICIPANT_OK
      else
        participant_status=GW_SWAP_PARTICIPANT_EXCHANGE_FAILED
        q_swap_m_per_s=0.0_c_double
      end if
    else
      participant_status=GW_SWAP_PARTICIPANT_TRIAL_FAILED
    end if

    if(candidate%ready())call corrector_backend%discard_trial_candidate(candidate,diagnostics)
    pub_gc_e6_g14_fused_observation_c=0_c_int
  end function pub_gc_e6_g14_fused_observation_c

  integer(c_int) function pub_gc_e6_g14_fused_run_count_c(value) bind(C,name="pub_gc_e6_g14_fused_run_count_c")
    integer(c_int), intent(out) :: value
    value=int(g14_fused_corrector_runs,c_int)
    pub_gc_e6_g14_fused_run_count_c=0_c_int
  end function pub_gc_e6_g14_fused_run_count_c

  logical function g14_whole_window_ok(result,candidate) result(valid)
    type(kernel_result_t), intent(in) :: result
    type(kernel_candidate_state_t), intent(in) :: candidate
    real(real64) :: ct0,ct1
    logical :: available
    valid=.false.
    if(.not.result%completed)return
    if(.not.candidate%ready())return
    if(.not.result%bottom_interface_exchange_available)return
    if(.not.ieee_is_finite(result%bottom_outward_exchange_native))return
    if(.not.ieee_is_finite(result%terminal_bottom_outward_flux_native))return
    if(.not.g14_same_time(result%requested_t0,window%t0))return
    if(.not.g14_same_time(result%requested_t1,window%t1))return
    if(.not.g14_same_time(result%completed_t,window%t1))return
    call candidate%origin_interval(ct0,ct1,available)
    if(.not.available)return
    if(.not.g14_same_time(ct0,window%t0) .or. .not.g14_same_time(ct1,window%t1))return
    valid=.true.
  end function g14_whole_window_ok

  pure logical function g14_same_time(a,b) result(matches)
    real(real64), intent(in) :: a,b
    real(real64) :: scale
    matches=.false.
    if(.not.ieee_is_finite(a) .or. .not.ieee_is_finite(b))return
    scale=max(1.0_real64,abs(a),abs(b))
    matches=abs(a-b)<=64.0_real64*epsilon(1.0_real64)*scale
  end function g14_same_time

  integer(c_int) function pub_gc_e6_corrector_mass_diagnostics_c(head_m,result_status,completed,candidate_ready, &
       mass_complete,storage_change,total_in,total_out,bottom_outward_exchange,mass_residual) &
       bind(C,name="pub_gc_e6_corrector_mass_diagnostics_c")
    real(c_double), value, intent(in) :: head_m
    integer(c_int), intent(out) :: result_status,completed,candidate_ready,mass_complete
    real(c_double), intent(out) :: storage_change,total_in,total_out,bottom_outward_exchange,mass_residual
    class(canonical_forcing_t), allocatable :: forcing
    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    logical :: ok
    integer :: forcing_status

    pub_gc_e6_corrector_mass_diagnostics_c=1_c_int
    result_status=-1_c_int; completed=0_c_int; candidate_ready=0_c_int; mass_complete=0_c_int
    storage_change=0.0_c_double; total_in=0.0_c_double; total_out=0.0_c_double
    bottom_outward_exchange=0.0_c_double; mass_residual=0.0_c_double
    if(.not.initialized)return

    call fmr_capture_checkpoint(committed,checkpoint,ok)
    if(.not.ok)return
    call materializer%materialize(real(head_m,real64),datum,forcing,forcing_status)
    if(forcing_status/=0 .or. .not.allocated(forcing))return

    select type(typed_forcing=>forcing)
    type is(fmr_b110_physical_forcing_t)
      call corrector_backend%run_trial(column,template,corrector_parameters,committed,typed_forcing,corrector_config, &
           window%t0,window%t1,checkpoint,result,candidate,diagnostics)
    class default
      return
    end select

    result_status=int(result%status,c_int)
    if(result%completed)completed=1_c_int
    if(candidate%ready())candidate_ready=1_c_int
    if(result%mass%complete)mass_complete=1_c_int
    storage_change=result%mass%storage_change
    total_in=result%mass%total_in
    total_out=result%mass%total_out
    bottom_outward_exchange=result%bottom_outward_exchange_native
    mass_residual=result%mass%residual

    if(candidate%ready())call corrector_backend%discard_trial_candidate(candidate,diagnostics)
    pub_gc_e6_corrector_mass_diagnostics_c=0_c_int
  end function pub_gc_e6_corrector_mass_diagnostics_c

  integer(c_int) function pub_gc_e6_swap_discard_c() bind(C,name="pub_gc_e6_swap_discard_c")
    pub_gc_e6_swap_discard_c=1_c_int
    if(.not.initialized)return
    call participant%discard_candidate(corrector_backend)
    pub_gc_e6_swap_discard_c=0_c_int
  end function pub_gc_e6_swap_discard_c

  integer(c_int) function pub_gc_e6_swap_preflight_c() bind(C,name="pub_gc_e6_swap_preflight_c")
    pub_gc_e6_swap_preflight_c=1_c_int
    if(.not.initialized)return
    if(.not.participant%publication_ready(committed,window))return
    pub_gc_e6_swap_preflight_c=0_c_int
  end function pub_gc_e6_swap_preflight_c

  integer(c_int) function pub_gc_e6_ledger_prepare_c() bind(C,name="pub_gc_e6_ledger_prepare_c")
    type(groundwater_interface_lineage_t) :: lineage
    integer :: status
    pub_gc_e6_ledger_prepare_c=1_c_int
    if(.not.initialized .or. .not.last_trial%valid)return
    if(ledger_prepared)return
    lineage%coupling_id=COUPLING_ID; lineage%swap_lineage_id=COLUMN_ID; lineage%swap_origin_revision=0_int64
    lineage%groundwater_lineage_id=GW_LINEAGE_ID; lineage%groundwater_origin_revision=0_int64
    lineage%candidate_revision=1_int64
    call ledger%stage_exchange(window,lineage,last_trial%bottom_outward_exchange_cm*0.01_real64,status)
    if(status/=GW_MASS_LEDGER_OK)return
    call ledger%prepare_trial(prepared_ledger,status); if(status/=GW_MASS_LEDGER_OK)return
    ledger_prepared=.true.; pub_gc_e6_ledger_prepare_c=0_c_int
  end function pub_gc_e6_ledger_prepare_c

  integer(c_int) function pub_gc_e6_ledger_preflight_c() bind(C,name="pub_gc_e6_ledger_preflight_c")
    pub_gc_e6_ledger_preflight_c=1_c_int
    if(.not.initialized .or. .not.ledger_prepared)return
    if(.not.ledger%prepared_ready_for_commit(prepared_ledger))return
    pub_gc_e6_ledger_preflight_c=0_c_int
  end function pub_gc_e6_ledger_preflight_c

  integer(c_int) function pub_gc_e6_swap_commit_c() bind(C,name="pub_gc_e6_swap_commit_c")
    logical :: did_commit
    integer :: status
    pub_gc_e6_swap_commit_c=1_c_int
    if(.not.initialized)return
    call participant%commit_candidate(corrector_backend,committed,window,did_commit,status)
    if(.not.did_commit .or. status/=GW_SWAP_PARTICIPANT_OK)return
    pub_gc_e6_swap_commit_c=0_c_int
  end function pub_gc_e6_swap_commit_c

  integer(c_int) function pub_gc_e6_ledger_commit_c() bind(C,name="pub_gc_e6_ledger_commit_c")
    pub_gc_e6_ledger_commit_c=1_c_int
    if(.not.initialized .or. .not.ledger_prepared)return
    if(.not.ledger%prepared_ready_for_commit(prepared_ledger))return
    call ledger%commit_prepared(prepared_ledger); ledger_prepared=.false.
    pub_gc_e6_ledger_commit_c=0_c_int
  end function pub_gc_e6_ledger_commit_c

  integer(c_int) function pub_gc_e6_abort_prepublication_c() bind(C,name="pub_gc_e6_abort_prepublication_c")
    pub_gc_e6_abort_prepublication_c=1_c_int
    if(.not.initialized)return
    if(participant%has_live_candidate())call participant%discard_candidate(corrector_backend)
    if(ledger_prepared)then
      if(ledger%prepared_ready_for_commit(prepared_ledger))call ledger%abort_prepared(prepared_ledger)
      ledger_prepared=.false.
    end if
    pub_gc_e6_abort_prepublication_c=0_c_int
  end function pub_gc_e6_abort_prepublication_c

  integer(c_int) function pub_gc_e6_state_c(revision,time_day,ledger_count,ledger_exchange_m) bind(C,name="pub_gc_e6_state_c")
    integer(c_int), intent(out) :: revision, ledger_count
    real(c_double), intent(out) :: time_day, ledger_exchange_m
    type(groundwater_interface_mass_snapshot_t) :: snap
    logical :: available
    real(real64) :: t
    pub_gc_e6_state_c=1_c_int; revision=-1; ledger_count=-1; time_day=0.0_c_double; ledger_exchange_m=0.0_c_double
    if(.not.initialized)return
    revision=int(committed%current_revision(),c_int)
    call committed%current_time(t,available); if(.not.available)return
    call ledger%snapshot(snap); if(.not.snap%available)return
    time_day=t; ledger_count=int(snap%committed_exchange_count,c_int); ledger_exchange_m=snap%committed_swap_outward_exchange_m
    pub_gc_e6_state_c=0_c_int
  end function pub_gc_e6_state_c

  integer(c_int) function pub_gc_e6_drainage_coverage_c(covered) bind(C,name="pub_gc_e6_drainage_coverage_c")
    integer(c_int), intent(out) :: covered
    covered=0_c_int
    if(drainage_tangent_covered)covered=1_c_int
    pub_gc_e6_drainage_coverage_c=0_c_int
  end function pub_gc_e6_drainage_coverage_c

  integer(c_int) function pub_gc_e6_predictor_run_diagnostics_c(available,result_status,completed,direction_available, &
       transaction_calls,accepted_substeps,attempts,retries,trial_rollbacks,solver_rejections,temporal_rejections, &
       temporal_unavailable_rejections,mass_rejections,internal_retries,max_temporal_indicator,min_substep,max_substep) &
       bind(C,name="pub_gc_e6_predictor_run_diagnostics_c")
    integer(c_int), intent(out) :: available,result_status,completed,direction_available
    integer(c_int), intent(out) :: transaction_calls,accepted_substeps,attempts,retries,trial_rollbacks
    integer(c_int), intent(out) :: solver_rejections,temporal_rejections,temporal_unavailable_rejections
    integer(c_int), intent(out) :: mass_rejections,internal_retries
    real(c_double), intent(out) :: max_temporal_indicator,min_substep,max_substep

    pub_gc_e6_predictor_run_diagnostics_c=0_c_int
    available=0_c_int; result_status=-1_c_int; completed=0_c_int; direction_available=0_c_int
    transaction_calls=0_c_int; accepted_substeps=0_c_int; attempts=0_c_int; retries=0_c_int
    trial_rollbacks=0_c_int; solver_rejections=0_c_int; temporal_rejections=0_c_int
    temporal_unavailable_rejections=0_c_int; mass_rejections=0_c_int; internal_retries=0_c_int
    max_temporal_indicator=0.0_c_double; min_substep=0.0_c_double; max_substep=0.0_c_double

    if(.not.e3d2_predictor_diagnostics_ready)return
    available=1_c_int
    result_status=int(e3d2_predictor_result%status,c_int)
    if(e3d2_predictor_result%completed)completed=1_c_int
    if(e3d2_predictor_result%accepted_trajectory_direction%available)direction_available=1_c_int
    transaction_calls=int(e3d2_predictor_diagnostics%transaction_calls,c_int)
    accepted_substeps=int(e3d2_predictor_diagnostics%accepted_substeps,c_int)
    attempts=int(e3d2_predictor_diagnostics%attempts,c_int)
    retries=int(e3d2_predictor_diagnostics%retries,c_int)
    trial_rollbacks=int(e3d2_predictor_diagnostics%trial_rollbacks,c_int)
    solver_rejections=int(e3d2_predictor_diagnostics%solver_rejections,c_int)
    temporal_rejections=int(e3d2_predictor_diagnostics%temporal_rejections,c_int)
    temporal_unavailable_rejections=int(e3d2_predictor_diagnostics%temporal_certificate_unavailable_rejections,c_int)
    mass_rejections=int(e3d2_predictor_diagnostics%mass_rejections,c_int)
    internal_retries=int(e3d2_predictor_diagnostics%internal_retries,c_int)
    max_temporal_indicator=e3d2_predictor_diagnostics%max_temporal_indicator
    min_substep=e3d2_predictor_diagnostics%min_accepted_substep_duration
    max_substep=e3d2_predictor_diagnostics%max_accepted_substep_duration
  end function pub_gc_e6_predictor_run_diagnostics_c

  integer(c_int) function pub_gc_e6_e1_diagnostics_c(mass_complete,q_bot,q_u,u,h_start,h_end, &
       bottom_exchange,terminal_flux,storage_start,storage_end,storage_change,total_in,total_out,residual) &
       bind(C,name="pub_gc_e6_e1_diagnostics_c")
    integer(c_int), intent(out) :: mass_complete
    real(c_double), intent(out) :: q_bot,q_u,u,h_start,h_end,bottom_exchange,terminal_flux
    real(c_double), intent(out) :: storage_start,storage_end,storage_change,total_in,total_out,residual
    pub_gc_e6_e1_diagnostics_c=1_c_int
    mass_complete=0_c_int
    q_bot=0.0_c_double; q_u=0.0_c_double; u=0.0_c_double
    h_start=0.0_c_double; h_end=0.0_c_double
    bottom_exchange=0.0_c_double; terminal_flux=0.0_c_double
    storage_start=0.0_c_double; storage_end=0.0_c_double; storage_change=0.0_c_double
    total_in=0.0_c_double; total_out=0.0_c_double; residual=0.0_c_double
    if(.not.initialized .or. .not.e1_ready)return
    if(e1_mass_complete)mass_complete=1_c_int
    q_bot=e1_q_bot_predictor_cm_per_day
    q_u=e1_q_u_cm_per_day
    u=e1_u
    h_start=e1_h_start_m
    h_end=e1_h_end_m
    bottom_exchange=e1_bottom_outward_exchange_native
    terminal_flux=e1_terminal_bottom_outward_flux_native
    storage_start=e1_storage_start
    storage_end=e1_storage_end
    storage_change=e1_storage_change
    total_in=e1_total_in
    total_out=e1_total_out
    residual=e1_mass_residual
    pub_gc_e6_e1_diagnostics_c=0_c_int
  end function pub_gc_e6_e1_diagnostics_c

  integer(c_int) function pub_gc_e6_last_trial_diagnostics_c(q_swap_m_per_s,bottom_exchange_cm) &
       bind(C,name="pub_gc_e6_last_trial_diagnostics_c")
    real(c_double), intent(out) :: q_swap_m_per_s,bottom_exchange_cm
    pub_gc_e6_last_trial_diagnostics_c=1_c_int
    q_swap_m_per_s=0.0_c_double; bottom_exchange_cm=0.0_c_double
    if(.not.initialized .or. .not.last_trial%valid)return
    q_swap_m_per_s=last_trial%q_swap_m_per_s
    bottom_exchange_cm=last_trial%bottom_outward_exchange_cm
    pub_gc_e6_last_trial_diagnostics_c=0_c_int
  end function pub_gc_e6_last_trial_diagnostics_c

  subroutine initialize_parameters(p,bottom_mode)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer,intent(in)::bottom_mode
    integer::k
    p%parameter_set_id=560061_int64; p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod); p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=0.032_real64; p%cofgen(2,k)=0.423_real64; p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64; p%cofgen(5,k)=0.365_real64; p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k); p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64; p%cofgen(10,k)=p%cofgen(3,k); p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k); p%cofgen(22,k)=-1.0e6_real64; p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=bottom_mode; p%swkimpl=0; p%swkmean=1; p%swsophy=0
    p%max_iterations=16; p%max_backtracking=8; p%min_step_duration=1.0e-10_real64
    p%compartment_balance_tolerance=MASS_TOL; p%total_balance_tolerance=MASS_TOL
    p%head_abs_tolerance=HEAD_TOL; p%head_rel_tolerance=HEAD_TOL; p%ponding_tolerance=HEAD_TOL
    p%root_extraction_active=.false.; p%macropore_active=.false.; p%snow_active=.false.
    p%hysteresis_active=.false.; p%tabulated_hydraulics_active=.false.; p%elasticity_active=.false.
    p%frost_active=.false.; p%soil_temperature_active=.false.
    p%drainage_response_active=.true.
    p%drainage_qbot_smooth_freatic_projection=.true.
    allocate(p%drainage_response_levels(2))
    p%drainage_response_levels(1)%variant=FMR_DRAIN_VARIANT_TABULATED
    allocate(p%drainage_response_levels(1)%tabulated%groundwater_depth(2), &
         p%drainage_response_levels(1)%tabulated%signed_exchange_rate(2))
    p%drainage_response_levels(1)%tabulated%groundwater_depth=[0.5_real64,2.5_real64]
    p%drainage_response_levels(1)%tabulated%signed_exchange_rate=[4.0e-3_real64,1.0e-3_real64]
    p%drainage_response_levels(2)%variant=FMR_DRAIN_VARIANT_TABULATED
    allocate(p%drainage_response_levels(2)%tabulated%groundwater_depth(2), &
         p%drainage_response_levels(2)%tabulated%signed_exchange_rate(2))
    p%drainage_response_levels(2)%tabulated%groundwater_depth=[0.5_real64,2.5_real64]
    p%drainage_response_levels(2)%tabulated%signed_exchange_rate=[2.0e-3_real64,-1.0e-3_real64]
  end subroutine initialize_parameters

  subroutine initialize_forcing(f,q)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    real(real64),intent(in)::q
    f%top_flux=0.0_real64; f%top_head=-999.0_real64
    f%bottom_flux=q; f%bottom_head=-999.0_real64
    allocate(f%drainage_response_controls(2),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%subsurface_irrigation_source=0.0_real64; f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_column_template(c,t)
    type(fmr_logical_column_t),intent(out)::c
    type(fmr_template_t),intent(out)::t
    t%template_id=540001_int64; t%physics_topology_id=540002_int64; t%vertical_layout_id=540003_int64
    t%state_layout_id=540004_int64; t%solver_interface_id=540005_int64; t%optional_state_layout_id=0_int64
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY; t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=COLUMN_ID; c%template_id=t%template_id; c%parameter_ref=1_int64; c%state_handle=1_int64
    c%forcing_handle=1_int64; c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_template

  subroutine initialize_configs(pred,corr)
    type(canonical_numerical_config_t),intent(out)::pred,corr
    pred%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE; pred%transaction%temporal_tolerance=0.0_real64
    pred%transaction%mass_tolerance=MASS_TOL; pred%transaction%retry_scale=0.5_real64; pred%transaction%max_retries=12
    pred%max_committed_substeps=32; pred%progress_tolerance=0.0_real64
    pred%model_temporal_indicator_budget_available=.true.; pred%model_temporal_indicator_budget=HEAD_BUDGET
    pred%accepted_trajectory_direction%requested=.true.
    pred%accepted_trajectory_direction%control_coordinate=SW_STEP_CONTROL_BOTTOM_FLUX
    corr=pred; corr%accepted_trajectory_direction%requested=.false.
  end subroutine initialize_configs

  subroutine initialize_committed_state(state,p,ok)
    type(kernel_committed_state_t),intent(out)::state
    type(fmr_b110_physical_parameters_t),intent(in)::p
    logical,intent(out)::ok
    type(fmr_b110_physical_state_t)::physical
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    real(real64)::heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    real(real64)::accepted_predecessor_right_derivative(numnod)
    heads=[-2.2_real64,-1.2_real64,-0.2_real64,0.8_real64]
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,active_duration_day)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    physical%active_nodes=numnod
    allocate(physical%pressure_head(numnod),physical%water_content(numnod))
    physical%pressure_head=heads; physical%water_content=water
    physical%ponding_depth=0.0_real64; physical%groundwater_level=-0.3_real64
    accepted_predecessor_right_derivative=0.0_real64
    call fmr_new_b110_temporal_indicator_committed_state(state,COLUMN_ID,physical,0.0_real64,ok, &
         accepted_predecessor_right_derivative)
  end subroutine initialize_committed_state

  subroutine materialize_solver_view(candidate,state,parameter_set,ok)
    type(kernel_candidate_state_t),intent(in)::candidate
    type(soil_water_physical_state_t),intent(out)::state
    type(soil_water_parameter_set_t),intent(out)::parameter_set
    logical,intent(out)::ok
    class(transaction_state_t),allocatable::snapshot
    logical::available
    ok=.false.; call candidate%snapshot(snapshot,available); if(.not.available .or. .not.allocated(snapshot))return
    select type(typed=>snapshot)
    class is(fmr_b110_physical_state_t)
      state%active_nodes=typed%active_nodes; allocate(state%pressure_head(typed%active_nodes),state%water_content(typed%active_nodes))
      state%pressure_head=typed%pressure_head; state%water_content=typed%water_content
      state%ponding_depth=typed%ponding_depth; state%groundwater_level=typed%groundwater_level
    class default
      return
    end select
    parameter_set%parameter_set_id=predictor_parameters%parameter_set_id; parameter_set%active_nodes=predictor_parameters%active_nodes
    allocate(parameter_set%z(numnod),parameter_set%dz(numnod),parameter_set%node_distance(numnod))
    parameter_set%z=predictor_parameters%z; parameter_set%dz=predictor_parameters%dz
    parameter_set%node_distance=predictor_parameters%node_distance; ok=.true.
  end subroutine materialize_solver_view

  subroutine materialize_origin_face(p,hp,qbot,face,status)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    type(b110_default_mvg_parameters_t),target,intent(in)::hp
    real(real64),intent(in)::qbot
    type(modflow6_prescribed_qbot_bottom_face_t),intent(out)::face
    integer,intent(out)::status
    type(b110_default_mvg_provider_t)::provider
    real(real64)::heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    integer :: i
    heads=[-2.2_real64,-1.2_real64,-0.2_real64,0.8_real64]
    call bind_b110_default_mvg_provider(provider,hp,active_duration_day)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    call materialize_modflow6_prescribed_qbot_bottom_face(heads(numnod),conductivity(numnod),qbot, &
         0.5_real64*p%dz(numnod),datum,face,status)
  end subroutine materialize_origin_face
end module mod_pub_gc_e6_active_drainage_bridge
