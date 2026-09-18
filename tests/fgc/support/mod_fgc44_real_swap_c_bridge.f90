module mod_fgc44_real_swap_c_bridge
  use, intrinsic :: iso_c_binding, only: c_double, c_int
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_committed_state
  use mod_fmr_groundwater_head_forcing_adapter, only: fmr_groundwater_head_forcing_materializer_t
  use mod_fmr_groundwater_swap_participant, only: fmr_groundwater_swap_participant_t
  use mod_groundwater_swap_transaction_participant, only: groundwater_swap_trial_t, GW_SWAP_PARTICIPANT_OK
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

  real(real64), parameter :: H0_CM=-75.0_real64
  real(real64), parameter :: DURATION_DAY=0.25_real64
  real(real64), parameter :: TOL=1.0e-12_real64
  integer(int64), parameter :: COLUMN_ID=540044_int64
  integer(int64), parameter :: COUPLING_ID=440044_int64
  integer(int64), parameter :: GW_CELL_ID=7001_int64
  integer(int64), parameter :: GW_SERVICE_ID=640044_int64
  integer(int64), parameter :: GW_LINEAGE_ID=640045_int64
  integer(int64), parameter :: LEDGER_ID=740044_int64
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

  public :: fgc44_swap_initialize_c, fgc44_swap_trial_c, fgc44_swap_discard_c
  public :: fgc44_swap_preflight_c, fgc44_ledger_prepare_c, fgc44_ledger_preflight_c
  public :: fgc44_swap_commit_c, fgc44_ledger_commit_c, fgc44_abort_prepublication_c
  public :: fgc44_state_c

contains

  integer(c_int) function fgc44_swap_initialize_c(hcof, rhs, reference_head) bind(C,name="fgc44_swap_initialize_c")
    real(c_double), intent(out) :: hcof, rhs, reference_head
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
    real(real64) :: qeq, q_swap, q_groundwater
    integer :: status, flux_status
    logical :: ok

    fgc44_swap_initialize_c=1_c_int; hcof=0.0_c_double; rhs=0.0_c_double; reference_head=0.0_c_double
    initialized=.false.; ledger_prepared=.false.
    call initialize_parameters(predictor_parameters,SW_STEP_CONTROL_BOTTOM_FLUX)
    call initialize_parameters(corrector_parameters,5)
    call determine_initial_conductivity(predictor_parameters,qeq)
    qeq=-qeq
    call initialize_forcing(base_forcing,qeq)
    call initialize_column_template(column,template)
    call initialize_configs(predictor_config,corrector_config)
    call initialize_committed_state(committed,predictor_parameters,ok)
    if(.not.ok)return

    datum%available=.true.; datum%datum_id=540044_int64; datum%bottom_boundary_elevation_m=0.0_real64
    window%t0=0.0_real64; window%t1=DURATION_DAY
    call predictor_backend%initialize(top)
    call corrector_backend%initialize(top)
    call materializer%initialize(base_forcing)

    call fmr_capture_checkpoint(committed,checkpoint,ok); if(.not.ok)return
    predictor_forcing=base_forcing; predictor_forcing%bottom_flux=qeq
    call predictor_backend%run_trial(column,template,predictor_parameters,committed,predictor_forcing,predictor_config, &
         window%t0,window%t1,checkpoint,result,candidate,diagnostics)
    if(.not.result%completed .or. .not.candidate%ready())return
    if(.not.result%accepted_trajectory_direction%available)return

    call initialize_b110_default_mvg_parameters(hp,predictor_parameters%cofgen)
    call bind_b110_default_mvg_provider(constitutive,hp,DURATION_DAY)
    call materialize_solver_view(candidate,predictor_state,solver_parameters,ok); if(.not.ok)return
    call build_modflow6_swap_predictor_tangent_endpoint(predictor_state,solver_parameters,constitutive, &
         result%accepted_trajectory_direction,qeq,datum,.false.,.false.,.false.,.false.,endpoint,status)
    if(status/=MODFLOW6_TANGENT_ENDPOINT_OK .or. .not.endpoint%authoritative)return
    call materialize_origin_face(predictor_parameters,hp,qeq,start_face,status)
    if(status/=MODFLOW6_BOTTOM_FACE_OK .or. .not.start_face%valid)return

    predictor_lineage%coupling_id=COUPLING_ID
    predictor_lineage%swap_lineage_id=COLUMN_ID
    predictor_lineage%swap_origin_revision=0_int64
    predictor_lineage%groundwater_service_id=GW_SERVICE_ID
    predictor_lineage%groundwater_lineage_id=GW_LINEAGE_ID
    predictor_lineage%groundwater_origin_revision=0_int64
    call swap_bottom_flux_cm_per_day_to_interface_flux_m_per_s(qeq,q_swap,flux_status); if(flux_status/=GW_INTERFACE_OK)return
    call pair_groundwater_flux_from_swap(q_swap,q_groundwater,flux_status); if(flux_status/=GW_INTERFACE_OK)return
    accepted_interface%h_swap_m=start_face%hydraulic_head_m
    accepted_interface%h_groundwater_m=start_face%hydraulic_head_m
    accepted_interface%q_swap_m_per_s=q_swap
    accepted_interface%q_groundwater_m_per_s=q_groundwater
    call capture_modflow6_swap_predictor_origin(accepted_interface,window%t0,predictor_lineage,.true.,origin,status)
    if(status/=MODFLOW6_PREDICTOR_ORIGIN_OK)return
    call assemble_modflow6_swap_predictor_response(origin,window,candidate,result,endpoint,response(1),status)
    if(status/=MODFLOW6_PREDICTOR_ASSEMBLER_OK .or. .not.response(1)%valid)return

    binding(1)%groundwater_cell_id=GW_CELL_ID; binding(1)%tile_id=COLUMN_ID; binding(1)%area_fraction=1.0_real64
    call compose_modflow6_multiswap_cell_response(binding,response,response(1)%h_bot_end_m,cell,status)
    if(status/=MODFLOW6_MULTI_CELL_OK .or. .not.cell%valid)return
    call compose_modflow6_linear_boundary_term(cell,AREA_M2,term,status)
    if(status/=MODFLOW6_LINEAR_BACKEND_OK .or. .not.term%valid)return
    hcof=term%hcof_m2_per_day; rhs=term%rhs_m3_per_day; reference_head=term%reference_head_m

    call predictor_backend%discard_trial_candidate(candidate,diagnostics)
    call participant%capture_origin(committed,status); if(status/=GW_SWAP_PARTICIPANT_OK)return
    call ledger%bind_identity(LEDGER_ID,status); if(status/=GW_MASS_LEDGER_OK)return
    initialized=.true.; fgc44_swap_initialize_c=0_c_int
  end function fgc44_swap_initialize_c

  integer(c_int) function fgc44_swap_trial_c(head_m,q_swap_m_per_s) bind(C,name="fgc44_swap_trial_c")
    real(c_double), value, intent(in) :: head_m
    real(c_double), intent(out) :: q_swap_m_per_s
    integer :: status
    fgc44_swap_trial_c=1_c_int; q_swap_m_per_s=0.0_c_double
    if(.not.initialized)return
    call participant%trial_from_origin(corrector_backend,column,template,corrector_parameters,committed,materializer, &
         corrector_config,datum,window,real(head_m,real64),last_trial,status)
    if(status/=GW_SWAP_PARTICIPANT_OK .or. .not.last_trial%valid)return
    q_swap_m_per_s=last_trial%q_swap_m_per_s
    fgc44_swap_trial_c=0_c_int
  end function fgc44_swap_trial_c

  integer(c_int) function fgc44_swap_discard_c() bind(C,name="fgc44_swap_discard_c")
    fgc44_swap_discard_c=1_c_int
    if(.not.initialized)return
    call participant%discard_candidate(corrector_backend)
    fgc44_swap_discard_c=0_c_int
  end function fgc44_swap_discard_c

  integer(c_int) function fgc44_swap_preflight_c() bind(C,name="fgc44_swap_preflight_c")
    fgc44_swap_preflight_c=1_c_int
    if(.not.initialized)return
    if(.not.participant%publication_ready(committed,window))return
    fgc44_swap_preflight_c=0_c_int
  end function fgc44_swap_preflight_c

  integer(c_int) function fgc44_ledger_prepare_c() bind(C,name="fgc44_ledger_prepare_c")
    type(groundwater_interface_lineage_t) :: lineage
    integer :: status
    fgc44_ledger_prepare_c=1_c_int
    if(.not.initialized .or. .not.last_trial%valid)return
    if(ledger_prepared)return
    lineage%coupling_id=COUPLING_ID; lineage%swap_lineage_id=COLUMN_ID; lineage%swap_origin_revision=0_int64
    lineage%groundwater_lineage_id=GW_LINEAGE_ID; lineage%groundwater_origin_revision=0_int64
    lineage%candidate_revision=1_int64
    call ledger%stage_exchange(window,lineage,last_trial%bottom_outward_exchange_cm*0.01_real64,status)
    if(status/=GW_MASS_LEDGER_OK)return
    call ledger%prepare_trial(prepared_ledger,status); if(status/=GW_MASS_LEDGER_OK)return
    ledger_prepared=.true.; fgc44_ledger_prepare_c=0_c_int
  end function fgc44_ledger_prepare_c

  integer(c_int) function fgc44_ledger_preflight_c() bind(C,name="fgc44_ledger_preflight_c")
    fgc44_ledger_preflight_c=1_c_int
    if(.not.initialized .or. .not.ledger_prepared)return
    if(.not.ledger%prepared_ready_for_commit(prepared_ledger))return
    fgc44_ledger_preflight_c=0_c_int
  end function fgc44_ledger_preflight_c

  integer(c_int) function fgc44_swap_commit_c() bind(C,name="fgc44_swap_commit_c")
    logical :: did_commit
    integer :: status
    fgc44_swap_commit_c=1_c_int
    if(.not.initialized)return
    call participant%commit_candidate(corrector_backend,committed,window,did_commit,status)
    if(.not.did_commit .or. status/=GW_SWAP_PARTICIPANT_OK)return
    fgc44_swap_commit_c=0_c_int
  end function fgc44_swap_commit_c

  integer(c_int) function fgc44_ledger_commit_c() bind(C,name="fgc44_ledger_commit_c")
    fgc44_ledger_commit_c=1_c_int
    if(.not.initialized .or. .not.ledger_prepared)return
    if(.not.ledger%prepared_ready_for_commit(prepared_ledger))return
    call ledger%commit_prepared(prepared_ledger); ledger_prepared=.false.
    fgc44_ledger_commit_c=0_c_int
  end function fgc44_ledger_commit_c

  integer(c_int) function fgc44_abort_prepublication_c() bind(C,name="fgc44_abort_prepublication_c")
    fgc44_abort_prepublication_c=1_c_int
    if(.not.initialized)return
    if(participant%has_live_candidate())call participant%discard_candidate(corrector_backend)
    if(ledger_prepared)then
      if(ledger%prepared_ready_for_commit(prepared_ledger))call ledger%abort_prepared(prepared_ledger)
      ledger_prepared=.false.
    end if
    fgc44_abort_prepublication_c=0_c_int
  end function fgc44_abort_prepublication_c

  integer(c_int) function fgc44_state_c(revision,time_day,ledger_count,ledger_exchange_m) bind(C,name="fgc44_state_c")
    integer(c_int), intent(out) :: revision, ledger_count
    real(c_double), intent(out) :: time_day, ledger_exchange_m
    type(groundwater_interface_mass_snapshot_t) :: snap
    logical :: available
    real(real64) :: t
    fgc44_state_c=1_c_int; revision=-1; ledger_count=-1; time_day=0.0_c_double; ledger_exchange_m=0.0_c_double
    if(.not.initialized)return
    revision=int(committed%current_revision(),c_int)
    call committed%current_time(t,available); if(.not.available)return
    call ledger%snapshot(snap); if(.not.snap%available)return
    time_day=t; ledger_count=int(snap%committed_exchange_count,c_int); ledger_exchange_m=snap%committed_swap_outward_exchange_m
    fgc44_state_c=0_c_int
  end function fgc44_state_c

  subroutine initialize_parameters(p,bottom_mode)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer,intent(in)::bottom_mode
    integer::k
    p%parameter_set_id=540044_int64; p%active_nodes=numnod
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
    p%max_iterations=16; p%max_backtracking=8; p%min_step_duration=1.0e-8_real64
    p%compartment_balance_tolerance=TOL; p%total_balance_tolerance=TOL; p%head_abs_tolerance=TOL
    p%head_rel_tolerance=TOL; p%ponding_tolerance=TOL; p%root_extraction_active=.false.
    p%macropore_active=.false.; p%snow_active=.false.; p%hysteresis_active=.false.
    p%tabulated_hydraulics_active=.false.; p%elasticity_active=.false.; p%frost_active=.false.
    p%soil_temperature_active=.false.; p%drainage_response_active=.false.
  end subroutine initialize_parameters

  subroutine determine_initial_conductivity(p,k0)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    real(real64),intent(out)::k0
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    real(real64)::heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    call initialize_b110_default_mvg_parameters(hp,p%cofgen); call bind_b110_default_mvg_provider(provider,hp,DURATION_DAY)
    heads=H0_CM; call provider%evaluate(heads,water,conductivity,capacity,dkdh); k0=conductivity(1)
  end subroutine determine_initial_conductivity

  subroutine initialize_forcing(f,q)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    real(real64),intent(in)::q
    f%top_flux=q; f%top_head=H0_CM; f%bottom_flux=q; f%bottom_head=H0_CM
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64; f%subsurface_irrigation_source=0.0_real64; f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_column_template(c,t)
    type(fmr_logical_column_t),intent(out)::c
    type(fmr_template_t),intent(out)::t
    t%template_id=540001_int64; t%physics_topology_id=540002_int64; t%vertical_layout_id=540003_int64
    t%state_layout_id=540004_int64; t%solver_interface_id=540005_int64; t%optional_state_layout_id=0_int64
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE; t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=COLUMN_ID; c%template_id=t%template_id; c%parameter_ref=1_int64; c%state_handle=1_int64
    c%forcing_handle=1_int64; c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_template

  subroutine initialize_configs(pred,corr)
    type(canonical_numerical_config_t),intent(out)::pred,corr
    pred%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF; pred%transaction%temporal_tolerance=1.0e-8_real64
    pred%transaction%mass_tolerance=TOL; pred%transaction%retry_scale=0.5_real64; pred%transaction%max_retries=8
    pred%max_committed_substeps=32; pred%progress_tolerance=0.0_real64
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
    heads=H0_CM
    call initialize_b110_default_mvg_parameters(hp,p%cofgen); call bind_b110_default_mvg_provider(provider,hp,DURATION_DAY)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    physical%active_nodes=numnod; allocate(physical%pressure_head(numnod),physical%water_content(numnod))
    physical%pressure_head=heads; physical%water_content=water; physical%ponding_depth=0.0_real64; physical%groundwater_level=-2.0_real64
    call fmr_new_b110_committed_state(state,COLUMN_ID,physical,0.0_real64,ok)
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
    heads=H0_CM; call bind_b110_default_mvg_provider(provider,hp,DURATION_DAY)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    call materialize_modflow6_prescribed_qbot_bottom_face(heads(numnod),conductivity(numnod),qbot, &
         0.5_real64*p%dz(numnod),datum,face,status)
  end subroutine materialize_origin_face
end module mod_fgc44_real_swap_c_bridge
