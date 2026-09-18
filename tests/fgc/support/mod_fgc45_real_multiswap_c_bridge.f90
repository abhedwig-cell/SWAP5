module mod_fgc45_real_multiswap_c_bridge
  use, intrinsic :: iso_c_binding, only: c_double, c_int
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_temporal_indicator_committed_state
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

  integer, parameter :: NTILE=2
  real(real64), parameter :: H0_CM=-75.0_real64
  real(real64), parameter :: DURATION_DAY=1.0e-4_real64
  real(real64), parameter :: TOL=1.0e-12_real64
  real(real64), parameter :: PREDICTOR_QBOT=1.0e-6_real64
  real(real64), parameter :: HEAD_BUDGET=1.0e-5_real64
  real(real64), parameter :: AREA_M2=1.0_real64
  integer(int64), parameter :: COUPLING_ID=450045_int64
  integer(int64), parameter :: GW_CELL_ID=7001_int64
  integer(int64), parameter :: GW_SERVICE_ID=650045_int64
  integer(int64), parameter :: GW_LINEAGE_ID=650046_int64
  integer(int64), parameter :: TILE_IDS(NTILE)=[550045_int64,550046_int64]
  integer(int64), parameter :: LEDGER_IDS(NTILE)=[750045_int64,750046_int64]
  real(real64), parameter :: FRACTIONS(NTILE)=[0.375_real64,0.625_real64]
  real(real64), parameter :: KSAT_SCALES(NTILE)=[1.0_real64,0.82_real64]

  type :: tile_context_t
    type(fmr_b110_physical_parameters_t) :: predictor_parameters
    type(fmr_b110_physical_parameters_t) :: corrector_parameters
    type(fmr_b110_physical_forcing_t) :: base_forcing
    type(fmr_logical_column_t) :: column
    type(kernel_committed_state_t) :: committed
    type(fmr_serialized_reference_backend_t) :: predictor_backend
    type(fmr_serialized_reference_backend_t) :: corrector_backend
    type(fmr_groundwater_head_forcing_materializer_t) :: materializer
    type(fmr_groundwater_swap_participant_t) :: participant
    type(groundwater_swap_trial_t) :: last_trial
    type(groundwater_interface_mass_ledger_t) :: ledger
    type(groundwater_interface_mass_prepared_t) :: prepared_ledger
    logical :: ledger_prepared=.false.
  end type tile_context_t

  type(tile_context_t), save :: tiles(NTILE)
  type(fmr_template_t), save :: template
  type(canonical_numerical_config_t), save :: predictor_config, corrector_config
  type(groundwater_head_datum_t), save :: datum
  type(groundwater_coupling_window_t), save :: window
  type(fixed_flux_top_boundary_provider_t), target, save :: top
  real(real64), save :: predictor_q(NTILE)=0.0_real64
  real(real64), save :: predictor_u(NTILE)=0.0_real64
  real(real64), save :: predictor_h(NTILE)=0.0_real64
  logical, save :: initialized=.false.

  public :: fgc45_multiswap_initialize_c, fgc45_multiswap_predictor_meta_c
  public :: fgc45_multiswap_trial_c, fgc45_multiswap_discard_c, fgc45_multiswap_preflight_c
  public :: fgc45_multiswap_ledger_prepare_c, fgc45_multiswap_ledger_preflight_c
  public :: fgc45_multiswap_commit_c, fgc45_multiswap_ledger_commit_c
  public :: fgc45_multiswap_abort_prepublication_c, fgc45_multiswap_state_c

contains

  integer(c_int) function fgc45_multiswap_initialize_c(hcof,rhs,reference_head) bind(C,name="fgc45_multiswap_initialize_c")
    real(c_double), intent(out) :: hcof,rhs,reference_head
    type(modflow6_swap_predictor_response_t) :: responses(NTILE)
    type(groundwater_direct_tile_binding_t) :: bindings(NTILE)
    type(modflow6_multiswap_cell_response_t) :: cell
    type(modflow6_linear_boundary_term_t) :: term
    real(real64) :: href
    integer :: i,status

    fgc45_multiswap_initialize_c=1_c_int
    hcof=0.0_c_double; rhs=0.0_c_double; reference_head=0.0_c_double
    initialized=.false.
    call initialize_template(template)
    call initialize_configs(predictor_config,corrector_config)
    datum%available=.true.; datum%datum_id=550045_int64; datum%bottom_boundary_elevation_m=0.0_real64
    window%t0=0.0_real64; window%t1=DURATION_DAY

    do i=1,NTILE
      call initialize_tile(tiles(i),TILE_IDS(i),LEDGER_IDS(i),KSAT_SCALES(i),responses(i),status)
      if(status/=0)return
      bindings(i)%groundwater_cell_id=GW_CELL_ID
      bindings(i)%tile_id=TILE_IDS(i)
      bindings(i)%area_fraction=FRACTIONS(i)
      predictor_q(i)=responses(i)%q_u_m_per_s
      predictor_u(i)=responses(i)%coupling_storage_coefficient_u
      predictor_h(i)=responses(i)%h_bot_end_m
    end do

    href=FRACTIONS(1)*responses(1)%h_bot_end_m+FRACTIONS(2)*responses(2)%h_bot_end_m
    call compose_modflow6_multiswap_cell_response(bindings,responses,href,cell,status)
    if(status/=MODFLOW6_MULTI_CELL_OK .or. .not.cell%valid)return
    call compose_modflow6_linear_boundary_term(cell,AREA_M2,term,status)
    if(status/=MODFLOW6_LINEAR_BACKEND_OK .or. .not.term%valid)return
    hcof=term%hcof_m2_per_day; rhs=term%rhs_m3_per_day; reference_head=term%reference_head_m
    initialized=.true.; fgc45_multiswap_initialize_c=0_c_int
  end function fgc45_multiswap_initialize_c

  integer(c_int) function fgc45_multiswap_predictor_meta_c(q1,q2,u1,u2,h1,h2) bind(C,name="fgc45_multiswap_predictor_meta_c")
    real(c_double), intent(out) :: q1,q2,u1,u2,h1,h2
    fgc45_multiswap_predictor_meta_c=1_c_int
    q1=0.0_c_double; q2=0.0_c_double; u1=0.0_c_double; u2=0.0_c_double; h1=0.0_c_double; h2=0.0_c_double
    if(.not.initialized)return
    q1=predictor_q(1); q2=predictor_q(2); u1=predictor_u(1); u2=predictor_u(2)
    h1=predictor_h(1); h2=predictor_h(2)
    fgc45_multiswap_predictor_meta_c=0_c_int
  end function fgc45_multiswap_predictor_meta_c

  integer(c_int) function fgc45_multiswap_trial_c(head_m,q_area_weighted_m_per_s) bind(C,name="fgc45_multiswap_trial_c")
    real(c_double), value, intent(in) :: head_m
    real(c_double), intent(out) :: q_area_weighted_m_per_s
    integer :: i,status

    fgc45_multiswap_trial_c=1_c_int; q_area_weighted_m_per_s=0.0_c_double
    if(.not.initialized)return
    do i=1,NTILE
      call tiles(i)%participant%trial_from_origin(tiles(i)%corrector_backend,tiles(i)%column,template, &
           tiles(i)%corrector_parameters,tiles(i)%committed,tiles(i)%materializer,corrector_config,datum,window, &
           real(head_m,real64),tiles(i)%last_trial,status)
      if(status/=GW_SWAP_PARTICIPANT_OK .or. .not.tiles(i)%last_trial%valid)then
        call discard_live_candidates()
        fgc45_multiswap_trial_c=int(100*i+status,c_int)
        return
      end if
      q_area_weighted_m_per_s=q_area_weighted_m_per_s+FRACTIONS(i)*tiles(i)%last_trial%q_swap_m_per_s
    end do
    if(.not.ieee_is_finite(q_area_weighted_m_per_s))then
      call discard_live_candidates()
      return
    end if
    fgc45_multiswap_trial_c=0_c_int
  end function fgc45_multiswap_trial_c

  integer(c_int) function fgc45_multiswap_discard_c() bind(C,name="fgc45_multiswap_discard_c")
    fgc45_multiswap_discard_c=1_c_int
    if(.not.initialized)return
    call discard_live_candidates()
    fgc45_multiswap_discard_c=0_c_int
  end function fgc45_multiswap_discard_c

  integer(c_int) function fgc45_multiswap_preflight_c() bind(C,name="fgc45_multiswap_preflight_c")
    integer :: i
    fgc45_multiswap_preflight_c=1_c_int
    if(.not.initialized)return
    do i=1,NTILE
      if(.not.tiles(i)%participant%publication_ready(tiles(i)%committed,window))return
    end do
    fgc45_multiswap_preflight_c=0_c_int
  end function fgc45_multiswap_preflight_c

  integer(c_int) function fgc45_multiswap_ledger_prepare_c() bind(C,name="fgc45_multiswap_ledger_prepare_c")
    type(groundwater_interface_lineage_t) :: lineage
    real(real64) :: weighted_exchange_m
    integer :: i,status

    fgc45_multiswap_ledger_prepare_c=1_c_int
    if(.not.initialized)return
    do i=1,NTILE
      if(.not.tiles(i)%last_trial%valid .or. tiles(i)%ledger_prepared)return
    end do
    do i=1,NTILE
      lineage=groundwater_interface_lineage_t()
      lineage%coupling_id=COUPLING_ID
      lineage%swap_lineage_id=TILE_IDS(i)
      lineage%swap_origin_revision=0_int64
      lineage%groundwater_lineage_id=GW_LINEAGE_ID
      lineage%groundwater_origin_revision=0_int64
      lineage%candidate_revision=1_int64
      weighted_exchange_m=FRACTIONS(i)*tiles(i)%last_trial%bottom_outward_exchange_cm*0.01_real64
      call tiles(i)%ledger%stage_exchange(window,lineage,weighted_exchange_m,status)
      if(status/=GW_MASS_LEDGER_OK)then
        call abort_ledgers()
        return
      end if
      call tiles(i)%ledger%prepare_trial(tiles(i)%prepared_ledger,status)
      if(status/=GW_MASS_LEDGER_OK)then
        call abort_ledgers()
        return
      end if
      tiles(i)%ledger_prepared=.true.
    end do
    fgc45_multiswap_ledger_prepare_c=0_c_int
  end function fgc45_multiswap_ledger_prepare_c

  integer(c_int) function fgc45_multiswap_ledger_preflight_c() bind(C,name="fgc45_multiswap_ledger_preflight_c")
    integer :: i
    fgc45_multiswap_ledger_preflight_c=1_c_int
    if(.not.initialized)return
    do i=1,NTILE
      if(.not.tiles(i)%ledger_prepared)return
      if(.not.tiles(i)%ledger%prepared_ready_for_commit(tiles(i)%prepared_ledger))return
    end do
    fgc45_multiswap_ledger_preflight_c=0_c_int
  end function fgc45_multiswap_ledger_preflight_c

  integer(c_int) function fgc45_multiswap_commit_c() bind(C,name="fgc45_multiswap_commit_c")
    logical :: did_commit
    integer :: i,status,committed_count

    fgc45_multiswap_commit_c=1_c_int
    if(.not.initialized)return
    do i=1,NTILE
      if(.not.tiles(i)%participant%publication_ready(tiles(i)%committed,window))return
    end do
    committed_count=0
    do i=1,NTILE
      call tiles(i)%participant%commit_candidate(tiles(i)%corrector_backend,tiles(i)%committed,window,did_commit,status)
      if(.not.did_commit .or. status/=GW_SWAP_PARTICIPANT_OK)then
        if(committed_count>0)error stop 'F-GC45 late SWAP tile commit failed after prior tile publication'
        return
      end if
      committed_count=committed_count+1
    end do
    fgc45_multiswap_commit_c=0_c_int
  end function fgc45_multiswap_commit_c

  integer(c_int) function fgc45_multiswap_ledger_commit_c() bind(C,name="fgc45_multiswap_ledger_commit_c")
    integer :: i
    fgc45_multiswap_ledger_commit_c=1_c_int
    if(.not.initialized)return
    do i=1,NTILE
      if(.not.tiles(i)%ledger_prepared)return
      if(.not.tiles(i)%ledger%prepared_ready_for_commit(tiles(i)%prepared_ledger))return
    end do
    do i=1,NTILE
      call tiles(i)%ledger%commit_prepared(tiles(i)%prepared_ledger)
      tiles(i)%ledger_prepared=.false.
    end do
    fgc45_multiswap_ledger_commit_c=0_c_int
  end function fgc45_multiswap_ledger_commit_c

  integer(c_int) function fgc45_multiswap_abort_prepublication_c() bind(C,name="fgc45_multiswap_abort_prepublication_c")
    fgc45_multiswap_abort_prepublication_c=1_c_int
    if(.not.initialized)return
    call discard_live_candidates()
    call abort_ledgers()
    fgc45_multiswap_abort_prepublication_c=0_c_int
  end function fgc45_multiswap_abort_prepublication_c

  integer(c_int) function fgc45_multiswap_state_c(rev1,rev2,t1,t2,count1,count2,ledger_total_m) &
       bind(C,name="fgc45_multiswap_state_c")
    integer(c_int), intent(out) :: rev1,rev2,count1,count2
    real(c_double), intent(out) :: t1,t2,ledger_total_m
    type(groundwater_interface_mass_snapshot_t) :: snap
    real(real64) :: time_value
    logical :: available
    integer :: i

    fgc45_multiswap_state_c=1_c_int
    rev1=-1; rev2=-1; count1=-1; count2=-1
    t1=0.0_c_double; t2=0.0_c_double; ledger_total_m=0.0_c_double
    if(.not.initialized)return
    rev1=int(tiles(1)%committed%current_revision(),c_int)
    rev2=int(tiles(2)%committed%current_revision(),c_int)
    call tiles(1)%committed%current_time(time_value,available); if(.not.available)return
    t1=time_value
    call tiles(2)%committed%current_time(time_value,available); if(.not.available)return
    t2=time_value
    do i=1,NTILE
      call tiles(i)%ledger%snapshot(snap)
      if(.not.snap%available)return
      if(i==1)count1=int(snap%committed_exchange_count,c_int)
      if(i==2)count2=int(snap%committed_exchange_count,c_int)
      ledger_total_m=ledger_total_m+snap%committed_swap_outward_exchange_m
    end do
    fgc45_multiswap_state_c=0_c_int
  end function fgc45_multiswap_state_c

  subroutine initialize_tile(tile,tile_id,ledger_id,ksat_scale,response,status)
    type(tile_context_t), intent(inout) :: tile
    integer(int64), intent(in) :: tile_id,ledger_id
    real(real64), intent(in) :: ksat_scale
    type(modflow6_swap_predictor_response_t), intent(out) :: response
    integer, intent(out) :: status

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
    type(modflow6_prescribed_qbot_bottom_face_t) :: start_face
    type(groundwater_interface_state_t) :: accepted_interface
    real(real64) :: q_swap,q_groundwater
    integer :: local_status,flux_status
    logical :: ok

    status=1; response=modflow6_swap_predictor_response_t(); tile%ledger_prepared=.false.
    call initialize_parameters(tile%predictor_parameters,SW_STEP_CONTROL_BOTTOM_FLUX,ksat_scale)
    call initialize_parameters(tile%corrector_parameters,5,ksat_scale)
    call initialize_forcing(tile%base_forcing,PREDICTOR_QBOT)
    call initialize_column(tile%column,tile_id)
    call initialize_committed_state(tile%committed,tile%predictor_parameters,tile_id,ok); if(.not.ok)return
    call tile%predictor_backend%initialize(top)
    call tile%corrector_backend%initialize(top)
    call tile%materializer%initialize(tile%base_forcing)

    call fmr_capture_checkpoint(tile%committed,checkpoint,ok); if(.not.ok)return
    predictor_forcing=tile%base_forcing; predictor_forcing%bottom_flux=PREDICTOR_QBOT
    call tile%predictor_backend%run_trial(tile%column,template,tile%predictor_parameters,tile%committed,predictor_forcing, &
         predictor_config,window%t0,window%t1,checkpoint,result,candidate,diagnostics)
    if(.not.result%completed)return
    if(.not.candidate%ready())return
    if(.not.result%accepted_trajectory_direction%available)return

    call initialize_b110_default_mvg_parameters(hp,tile%predictor_parameters%cofgen)
    call bind_b110_default_mvg_provider(constitutive,hp,DURATION_DAY)
    call materialize_solver_view(candidate,tile%predictor_parameters,predictor_state,solver_parameters,ok); if(.not.ok)return
    call build_modflow6_swap_predictor_tangent_endpoint(predictor_state,solver_parameters,constitutive, &
         result%accepted_trajectory_direction,PREDICTOR_QBOT,datum,.false.,.false.,.false.,.false.,endpoint,local_status)
    if(local_status/=MODFLOW6_TANGENT_ENDPOINT_OK .or. .not.endpoint%authoritative)return
    call materialize_origin_face(tile%predictor_parameters,hp,PREDICTOR_QBOT,start_face,local_status)
    if(local_status/=MODFLOW6_BOTTOM_FACE_OK .or. .not.start_face%valid)return

    predictor_lineage%coupling_id=COUPLING_ID
    predictor_lineage%swap_lineage_id=tile_id
    predictor_lineage%swap_origin_revision=0_int64
    predictor_lineage%groundwater_service_id=GW_SERVICE_ID
    predictor_lineage%groundwater_lineage_id=GW_LINEAGE_ID
    predictor_lineage%groundwater_origin_revision=0_int64
    call swap_bottom_flux_cm_per_day_to_interface_flux_m_per_s(PREDICTOR_QBOT,q_swap,flux_status)
    if(flux_status/=GW_INTERFACE_OK)return
    call pair_groundwater_flux_from_swap(q_swap,q_groundwater,flux_status); if(flux_status/=GW_INTERFACE_OK)return
    accepted_interface%h_swap_m=start_face%hydraulic_head_m
    accepted_interface%h_groundwater_m=start_face%hydraulic_head_m
    accepted_interface%q_swap_m_per_s=q_swap
    accepted_interface%q_groundwater_m_per_s=q_groundwater
    call capture_modflow6_swap_predictor_origin(accepted_interface,window%t0,predictor_lineage,.true.,origin,local_status)
    if(local_status/=MODFLOW6_PREDICTOR_ORIGIN_OK)return
    call assemble_modflow6_swap_predictor_response(origin,window,candidate,result,endpoint,response,local_status)
    if(local_status/=MODFLOW6_PREDICTOR_ASSEMBLER_OK .or. .not.response%valid)return

    call tile%predictor_backend%discard_trial_candidate(candidate,diagnostics)
    call tile%participant%capture_origin(tile%committed,local_status); if(local_status/=GW_SWAP_PARTICIPANT_OK)return
    call tile%ledger%bind_identity(ledger_id,local_status); if(local_status/=GW_MASS_LEDGER_OK)return
    status=0
  end subroutine initialize_tile

  subroutine discard_live_candidates()
    integer :: i
    do i=1,NTILE
      if(tiles(i)%participant%has_live_candidate())call tiles(i)%participant%discard_candidate(tiles(i)%corrector_backend)
    end do
  end subroutine discard_live_candidates

  subroutine abort_ledgers()
    integer :: i
    do i=1,NTILE
      if(tiles(i)%ledger_prepared)then
        if(tiles(i)%ledger%prepared_ready_for_commit(tiles(i)%prepared_ledger)) &
             call tiles(i)%ledger%abort_prepared(tiles(i)%prepared_ledger)
        tiles(i)%ledger_prepared=.false.
      else if(tiles(i)%ledger%has_active_trial())then
        call discard_active_ledger(tiles(i)%ledger)
      end if
    end do
  end subroutine abort_ledgers

  subroutine discard_active_ledger(ledger)
    type(groundwater_interface_mass_ledger_t), intent(inout) :: ledger
    integer :: status
    if(ledger%has_active_trial())call ledger%discard_trial(status)
  end subroutine discard_active_ledger

  subroutine initialize_parameters(p,bottom_mode,ksat_scale)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer,intent(in)::bottom_mode
    real(real64),intent(in)::ksat_scale
    integer::k
    p%parameter_set_id=550000_int64+int(1000.0_real64*ksat_scale,int64); p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod); p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=0.032_real64; p%cofgen(2,k)=0.423_real64; p%cofgen(3,k)=4.75_real64*ksat_scale
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

  subroutine initialize_forcing(f,q)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    real(real64),intent(in)::q
    f%top_flux=q; f%top_head=H0_CM; f%bottom_flux=q; f%bottom_head=H0_CM
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64; f%subsurface_irrigation_source=0.0_real64; f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_template(t)
    type(fmr_template_t),intent(out)::t
    t%template_id=550001_int64; t%physics_topology_id=550002_int64; t%vertical_layout_id=550003_int64
    t%state_layout_id=550004_int64; t%solver_interface_id=550005_int64; t%optional_state_layout_id=0_int64
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_template

  subroutine initialize_column(c,tile_id)
    type(fmr_logical_column_t),intent(out)::c
    integer(int64),intent(in)::tile_id
    c%column_id=tile_id; c%template_id=template%template_id; c%parameter_ref=tile_id
    c%state_handle=tile_id; c%forcing_handle=tile_id; c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column

  subroutine initialize_configs(pred,corr)
    type(canonical_numerical_config_t),intent(out)::pred,corr
    pred%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE; pred%transaction%temporal_tolerance=0.0_real64
    pred%transaction%mass_tolerance=TOL; pred%transaction%retry_scale=0.5_real64; pred%transaction%max_retries=8
    pred%max_committed_substeps=32; pred%progress_tolerance=0.0_real64
    pred%model_temporal_indicator_budget_available=.true.; pred%model_temporal_indicator_budget=HEAD_BUDGET
    pred%accepted_trajectory_direction%requested=.true.
    pred%accepted_trajectory_direction%control_coordinate=SW_STEP_CONTROL_BOTTOM_FLUX
    corr=pred; corr%accepted_trajectory_direction%requested=.false.
  end subroutine initialize_configs

  subroutine initialize_committed_state(state,p,lineage,ok)
    type(kernel_committed_state_t),intent(out)::state
    type(fmr_b110_physical_parameters_t),intent(in)::p
    integer(int64),intent(in)::lineage
    logical,intent(out)::ok
    type(fmr_b110_physical_state_t)::physical
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    real(real64)::heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    real(real64)::accepted_predecessor_right_derivative(numnod)
    integer::i
    heads(1)=H0_CM
    do i=2,numnod
      heads(i)=heads(i-1)+p%node_distance(i)
    end do
    call initialize_b110_default_mvg_parameters(hp,p%cofgen); call bind_b110_default_mvg_provider(provider,hp,DURATION_DAY)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    physical%active_nodes=numnod; allocate(physical%pressure_head(numnod),physical%water_content(numnod))
    physical%pressure_head=heads; physical%water_content=water; physical%ponding_depth=0.0_real64
    physical%groundwater_level=-2.0_real64
    accepted_predecessor_right_derivative=0.0_real64
    call fmr_new_b110_temporal_indicator_committed_state(state,lineage,physical,0.0_real64,ok, &
         accepted_predecessor_right_derivative)
  end subroutine initialize_committed_state

  subroutine materialize_solver_view(candidate,p,state,parameter_set,ok)
    type(kernel_candidate_state_t),intent(in)::candidate
    type(fmr_b110_physical_parameters_t),intent(in)::p
    type(soil_water_physical_state_t),intent(out)::state
    type(soil_water_parameter_set_t),intent(out)::parameter_set
    logical,intent(out)::ok
    class(transaction_state_t),allocatable::snapshot
    logical::available
    ok=.false.; call candidate%snapshot(snapshot,available)
    if(.not.available)return
    if(.not.allocated(snapshot))return
    select type(typed=>snapshot)
    class is(fmr_b110_physical_state_t)
      state%active_nodes=typed%active_nodes
      allocate(state%pressure_head(typed%active_nodes),state%water_content(typed%active_nodes))
      state%pressure_head=typed%pressure_head; state%water_content=typed%water_content
      state%ponding_depth=typed%ponding_depth; state%groundwater_level=typed%groundwater_level
    class default
      return
    end select
    parameter_set%parameter_set_id=p%parameter_set_id; parameter_set%active_nodes=p%active_nodes
    allocate(parameter_set%z(numnod),parameter_set%dz(numnod),parameter_set%node_distance(numnod))
    parameter_set%z=p%z; parameter_set%dz=p%dz; parameter_set%node_distance=p%node_distance
    ok=.true.
  end subroutine materialize_solver_view

  subroutine materialize_origin_face(p,hp,qbot,face,status)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    type(b110_default_mvg_parameters_t),target,intent(in)::hp
    real(real64),intent(in)::qbot
    type(modflow6_prescribed_qbot_bottom_face_t),intent(out)::face
    integer,intent(out)::status
    type(b110_default_mvg_provider_t)::provider
    real(real64)::heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    integer::i
    heads(1)=H0_CM
    do i=2,numnod
      heads(i)=heads(i-1)+p%node_distance(i)
    end do
    call bind_b110_default_mvg_provider(provider,hp,DURATION_DAY)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    call materialize_modflow6_prescribed_qbot_bottom_face(heads(numnod),conductivity(numnod),qbot, &
         0.5_real64*p%dz(numnod),datum,face,status)
  end subroutine materialize_origin_face

end module mod_fgc45_real_multiswap_c_bridge
