module mod_fgc45_real_multiswap_c_bridge
  use, intrinsic :: iso_c_binding, only: c_double, c_int
  use, intrinsic :: iso_fortran_env, only: int64, real64
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
  real(real64), parameter :: FRACTION(NTILE)=[0.35_real64,0.65_real64]
  integer(int64), parameter :: COLUMN_ID(NTILE)=[550045_int64,550046_int64]
  integer(int64), parameter :: LEDGER_ID(NTILE)=[750045_int64,750046_int64]
  real(real64), parameter :: H0_CM=-75.0_real64
  real(real64), parameter :: DURATION_DAY=1.0e-4_real64
  real(real64), parameter :: TOL=1.0e-12_real64
  real(real64), parameter :: PREDICTOR_QBOT=1.0e-6_real64
  real(real64), parameter :: HEAD_BUDGET=1.0e-5_real64
  integer(int64), parameter :: COUPLING_ID=450045_int64
  integer(int64), parameter :: GW_CELL_ID=7001_int64
  integer(int64), parameter :: GW_SERVICE_ID=650045_int64
  integer(int64), parameter :: GW_LINEAGE_ID=650046_int64
  real(real64), parameter :: AREA_M2=1.0_real64

  type(fmr_b110_physical_parameters_t), save :: predictor_parameters(NTILE), corrector_parameters(NTILE)
  type(fmr_b110_physical_forcing_t), save :: base_forcing(NTILE)
  type(fmr_logical_column_t), save :: column(NTILE)
  type(fmr_template_t), save :: template(NTILE)
  type(canonical_numerical_config_t), save :: predictor_config, corrector_config
  type(kernel_committed_state_t), save :: committed(NTILE)
  type(fmr_serialized_reference_backend_t), save :: predictor_backend(NTILE), corrector_backend(NTILE)
  type(fmr_groundwater_head_forcing_materializer_t), save :: materializer(NTILE)
  type(fmr_groundwater_swap_participant_t), save :: participant(NTILE)
  type(groundwater_swap_trial_t), save :: last_trial(NTILE)
  type(groundwater_head_datum_t), save :: datum
  type(groundwater_coupling_window_t), save :: window
  type(groundwater_interface_mass_ledger_t), save :: ledger(NTILE)
  type(groundwater_interface_mass_prepared_t), save :: prepared_ledger(NTILE)
  type(fixed_flux_top_boundary_provider_t), target, save :: top(NTILE)
  logical, save :: initialized=.false.
  logical, save :: ledger_prepared(NTILE)=.false.

  public :: fgc45_initialize_c, fgc45_trial_c, fgc45_discard_c
  public :: fgc45_swap_preflight_c, fgc45_ledgers_prepare_c, fgc45_ledgers_preflight_c
  public :: fgc45_swap_commit_c, fgc45_ledgers_commit_c, fgc45_abort_prepublication_c
  public :: fgc45_state_c

contains

  integer(c_int) function fgc45_initialize_c(hcof,rhs,reference_head) bind(C,name="fgc45_initialize_c")
    real(c_double),intent(out)::hcof,rhs,reference_head
    type(modflow6_swap_predictor_response_t) :: response(NTILE)
    type(groundwater_direct_tile_binding_t) :: binding(NTILE)
    type(modflow6_multiswap_cell_response_t) :: cell
    type(modflow6_linear_boundary_term_t) :: term
    real(real64) :: href
    integer :: i,status
    logical :: ok

    fgc45_initialize_c=1_c_int; hcof=0.0_c_double; rhs=0.0_c_double; reference_head=0.0_c_double
    initialized=.false.; ledger_prepared=.false.
    datum%available=.true.; datum%datum_id=550045_int64; datum%bottom_boundary_elevation_m=0.0_real64
    window%t0=0.0_real64; window%t1=DURATION_DAY
    call initialize_configs(predictor_config,corrector_config)

    do i=1,NTILE
      call initialize_parameters(predictor_parameters(i),SW_STEP_CONTROL_BOTTOM_FLUX,1000_int64+i)
      call initialize_parameters(corrector_parameters(i),5,2000_int64+i)
      call initialize_forcing(base_forcing(i),PREDICTOR_QBOT)
      call initialize_column_template(column(i),template(i),i)
      call initialize_committed_state(committed(i),predictor_parameters(i),COLUMN_ID(i),ok)
      if(.not.ok)return
      call predictor_backend(i)%initialize(top(i))
      call corrector_backend(i)%initialize(top(i))
      call materializer(i)%initialize(base_forcing(i))
      call build_tile_predictor(i,response(i),status)
      if(status/=0)return
      binding(i)%groundwater_cell_id=GW_CELL_ID
      binding(i)%tile_id=COLUMN_ID(i)
      binding(i)%area_fraction=FRACTION(i)
    end do

    href=FRACTION(1)*response(1)%h_bot_end_m+FRACTION(2)*response(2)%h_bot_end_m
    call compose_modflow6_multiswap_cell_response(binding,response,href,cell,status)
    if(status/=MODFLOW6_MULTI_CELL_OK .or. .not.cell%valid)return
    call compose_modflow6_linear_boundary_term(cell,AREA_M2,term,status)
    if(status/=MODFLOW6_LINEAR_BACKEND_OK .or. .not.term%valid)return
    hcof=term%hcof_m2_per_day; rhs=term%rhs_m3_per_day; reference_head=term%reference_head_m

    do i=1,NTILE
      call participant(i)%capture_origin(committed(i),status)
      if(status/=GW_SWAP_PARTICIPANT_OK)return
      call ledger(i)%bind_identity(LEDGER_ID(i),status)
      if(status/=GW_MASS_LEDGER_OK)return
    end do
    initialized=.true.; fgc45_initialize_c=0_c_int
  end function fgc45_initialize_c

  integer(c_int) function fgc45_trial_c(head_m,q_weighted,q1,q2) bind(C,name="fgc45_trial_c")
    real(c_double),value,intent(in)::head_m
    real(c_double),intent(out)::q_weighted,q1,q2
    real(real64) :: q(NTILE)
    integer :: i,j,status

    fgc45_trial_c=1_c_int; q_weighted=0.0_c_double; q1=0.0_c_double; q2=0.0_c_double
    if(.not.initialized)return
    do i=1,NTILE
      call participant(i)%trial_from_origin(corrector_backend(i),column(i),template(i),corrector_parameters(i), &
           committed(i),materializer(i),corrector_config,datum,window,real(head_m,real64),last_trial(i),status)
      if(status/=GW_SWAP_PARTICIPANT_OK .or. .not.last_trial(i)%valid)then
        do j=1,i-1
          if(participant(j)%has_live_candidate())call participant(j)%discard_candidate(corrector_backend(j))
        end do
        fgc45_trial_c=int(max(1,status),c_int)
        return
      end if
      q(i)=last_trial(i)%q_swap_m_per_s
    end do
    q_weighted=FRACTION(1)*q(1)+FRACTION(2)*q(2); q1=q(1); q2=q(2)
    fgc45_trial_c=0_c_int
  end function fgc45_trial_c

  integer(c_int) function fgc45_discard_c() bind(C,name="fgc45_discard_c")
    integer :: i
    fgc45_discard_c=1_c_int
    if(.not.initialized)return
    do i=1,NTILE
      if(participant(i)%has_live_candidate())call participant(i)%discard_candidate(corrector_backend(i))
    end do
    fgc45_discard_c=0_c_int
  end function fgc45_discard_c

  integer(c_int) function fgc45_swap_preflight_c() bind(C,name="fgc45_swap_preflight_c")
    integer :: i
    fgc45_swap_preflight_c=1_c_int
    if(.not.initialized)return
    do i=1,NTILE
      if(.not.participant(i)%publication_ready(committed(i),window))return
    end do
    fgc45_swap_preflight_c=0_c_int
  end function fgc45_swap_preflight_c

  integer(c_int) function fgc45_ledgers_prepare_c() bind(C,name="fgc45_ledgers_prepare_c")
    type(groundwater_interface_lineage_t) :: lineage
    integer :: i,j,status
    fgc45_ledgers_prepare_c=1_c_int
    if(.not.initialized)return
    if(any(ledger_prepared))return
    do i=1,NTILE
      if(.not.last_trial(i)%valid)return
      lineage=groundwater_interface_lineage_t()
      lineage%coupling_id=COUPLING_ID; lineage%swap_lineage_id=COLUMN_ID(i); lineage%swap_origin_revision=0_int64
      lineage%groundwater_lineage_id=GW_LINEAGE_ID; lineage%groundwater_origin_revision=0_int64
      lineage%candidate_revision=1_int64
      call ledger(i)%stage_exchange(window,lineage,FRACTION(i)*last_trial(i)%bottom_outward_exchange_cm*0.01_real64,status)
      if(status/=GW_MASS_LEDGER_OK)then
        do j=1,i-1
          if(ledger(j)%has_active_trial())call ledger(j)%discard_trial(status)
        end do
        return
      end if
      call ledger(i)%prepare_trial(prepared_ledger(i),status)
      if(status/=GW_MASS_LEDGER_OK)return
      ledger_prepared(i)=.true.
    end do
    fgc45_ledgers_prepare_c=0_c_int
  end function fgc45_ledgers_prepare_c

  integer(c_int) function fgc45_ledgers_preflight_c() bind(C,name="fgc45_ledgers_preflight_c")
    integer :: i
    fgc45_ledgers_preflight_c=1_c_int
    if(.not.initialized .or. .not.all(ledger_prepared))return
    do i=1,NTILE
      if(.not.ledger(i)%prepared_ready_for_commit(prepared_ledger(i)))return
    end do
    fgc45_ledgers_preflight_c=0_c_int
  end function fgc45_ledgers_preflight_c

  integer(c_int) function fgc45_swap_commit_c() bind(C,name="fgc45_swap_commit_c")
    integer :: i,status,committed_count
    logical :: did_commit
    fgc45_swap_commit_c=1_c_int; committed_count=0
    if(.not.initialized)return
    do i=1,NTILE
      call participant(i)%commit_candidate(corrector_backend(i),committed(i),window,did_commit,status)
      if(.not.did_commit .or. status/=GW_SWAP_PARTICIPANT_OK)then
        if(committed_count>0)error stop 'F-GC45 late SWAP commit failure after publication point'
        return
      end if
      committed_count=committed_count+1
    end do
    fgc45_swap_commit_c=0_c_int
  end function fgc45_swap_commit_c

  integer(c_int) function fgc45_ledgers_commit_c() bind(C,name="fgc45_ledgers_commit_c")
    integer :: i
    fgc45_ledgers_commit_c=1_c_int
    if(.not.initialized .or. .not.all(ledger_prepared))return
    do i=1,NTILE
      if(.not.ledger(i)%prepared_ready_for_commit(prepared_ledger(i)))error stop 'F-GC45 late ledger invariant'
    end do
    do i=1,NTILE
      call ledger(i)%commit_prepared(prepared_ledger(i)); ledger_prepared(i)=.false.
    end do
    fgc45_ledgers_commit_c=0_c_int
  end function fgc45_ledgers_commit_c

  integer(c_int) function fgc45_abort_prepublication_c() bind(C,name="fgc45_abort_prepublication_c")
    integer :: i
    fgc45_abort_prepublication_c=1_c_int
    if(.not.initialized)return
    do i=1,NTILE
      if(participant(i)%has_live_candidate())call participant(i)%discard_candidate(corrector_backend(i))
      if(ledger_prepared(i))then
        if(ledger(i)%prepared_ready_for_commit(prepared_ledger(i)))call ledger(i)%abort_prepared(prepared_ledger(i))
        ledger_prepared(i)=.false.
      end if
    end do
    fgc45_abort_prepublication_c=0_c_int
  end function fgc45_abort_prepublication_c

  integer(c_int) function fgc45_state_c(rev1,rev2,t1,t2,count1,count2,exchange1,exchange2) bind(C,name="fgc45_state_c")
    integer(c_int),intent(out)::rev1,rev2,count1,count2
    real(c_double),intent(out)::t1,t2,exchange1,exchange2
    type(groundwater_interface_mass_snapshot_t)::snap1,snap2
    real(real64)::time1,time2
    logical::a1,a2
    fgc45_state_c=1_c_int; rev1=-1; rev2=-1; count1=-1; count2=-1
    t1=0.0_c_double; t2=0.0_c_double; exchange1=0.0_c_double; exchange2=0.0_c_double
    if(.not.initialized)return
    rev1=int(committed(1)%current_revision(),c_int); rev2=int(committed(2)%current_revision(),c_int)
    call committed(1)%current_time(time1,a1); call committed(2)%current_time(time2,a2)
    if(.not.a1 .or. .not.a2)return
    call ledger(1)%snapshot(snap1); call ledger(2)%snapshot(snap2)
    if(.not.snap1%available .or. .not.snap2%available)return
    t1=time1; t2=time2; count1=int(snap1%committed_exchange_count,c_int); count2=int(snap2%committed_exchange_count,c_int)
    exchange1=snap1%committed_swap_outward_exchange_m; exchange2=snap2%committed_swap_outward_exchange_m
    fgc45_state_c=0_c_int
  end function fgc45_state_c

  subroutine build_tile_predictor(i,response,status)
    integer,intent(in)::i
    type(modflow6_swap_predictor_response_t),intent(out)::response
    integer,intent(out)::status
    type(kernel_checkpoint_t)::checkpoint
    type(kernel_result_t)::result
    type(kernel_candidate_state_t)::candidate
    type(kernel_diagnostics_t)::diagnostics
    type(fmr_b110_physical_forcing_t)::predictor_forcing
    type(soil_water_physical_state_t)::predictor_state
    type(soil_water_parameter_set_t)::solver_parameters
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::constitutive
    type(modflow6_swap_predictor_tangent_endpoint_t)::endpoint
    type(modflow6_swap_predictor_origin_t)::origin
    type(modflow6_swap_predictor_lineage_t)::predictor_lineage
    type(modflow6_prescribed_qbot_bottom_face_t)::start_face
    type(groundwater_interface_state_t)::accepted_interface
    real(real64)::q_swap,q_groundwater
    integer::flux_status
    logical::ok

    status=1
    call fmr_capture_checkpoint(committed(i),checkpoint,ok); if(.not.ok)return
    predictor_forcing=base_forcing(i); predictor_forcing%bottom_flux=PREDICTOR_QBOT
    call predictor_backend(i)%run_trial(column(i),template(i),predictor_parameters(i),committed(i),predictor_forcing, &
         predictor_config,window%t0,window%t1,checkpoint,result,candidate,diagnostics)
    if(.not.result%completed)return
    if(.not.candidate%ready())return
    if(.not.result%accepted_trajectory_direction%available)return
    call initialize_b110_default_mvg_parameters(hp,predictor_parameters(i)%cofgen)
    call bind_b110_default_mvg_provider(constitutive,hp,DURATION_DAY)
    call materialize_solver_view(candidate,predictor_parameters(i),predictor_state,solver_parameters,ok); if(.not.ok)return
    call build_modflow6_swap_predictor_tangent_endpoint(predictor_state,solver_parameters,constitutive, &
         result%accepted_trajectory_direction,PREDICTOR_QBOT,datum,.false.,.false.,.false.,.false.,endpoint,status)
    if(status/=MODFLOW6_TANGENT_ENDPOINT_OK .or. .not.endpoint%authoritative)return
    call materialize_origin_face(predictor_parameters(i),hp,PREDICTOR_QBOT,start_face,status)
    if(status/=MODFLOW6_BOTTOM_FACE_OK .or. .not.start_face%valid)return
    predictor_lineage%coupling_id=COUPLING_ID; predictor_lineage%swap_lineage_id=COLUMN_ID(i)
    predictor_lineage%swap_origin_revision=0_int64; predictor_lineage%groundwater_service_id=GW_SERVICE_ID
    predictor_lineage%groundwater_lineage_id=GW_LINEAGE_ID; predictor_lineage%groundwater_origin_revision=0_int64
    call swap_bottom_flux_cm_per_day_to_interface_flux_m_per_s(PREDICTOR_QBOT,q_swap,flux_status)
    if(flux_status/=GW_INTERFACE_OK)return
    call pair_groundwater_flux_from_swap(q_swap,q_groundwater,flux_status); if(flux_status/=GW_INTERFACE_OK)return
    accepted_interface%h_swap_m=start_face%hydraulic_head_m; accepted_interface%h_groundwater_m=start_face%hydraulic_head_m
    accepted_interface%q_swap_m_per_s=q_swap; accepted_interface%q_groundwater_m_per_s=q_groundwater
    call capture_modflow6_swap_predictor_origin(accepted_interface,window%t0,predictor_lineage,.true.,origin,status)
    if(status/=MODFLOW6_PREDICTOR_ORIGIN_OK)return
    call assemble_modflow6_swap_predictor_response(origin,window,candidate,result,endpoint,response,status)
    if(status/=MODFLOW6_PREDICTOR_ASSEMBLER_OK .or. .not.response%valid)return
    call predictor_backend(i)%discard_trial_candidate(candidate,diagnostics)
    status=0
  end subroutine build_tile_predictor

  subroutine initialize_parameters(p,bottom_mode,parameter_id)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer,intent(in)::bottom_mode
    integer(int64),intent(in)::parameter_id
    integer::k
    p%parameter_set_id=parameter_id; p%active_nodes=numnod
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

  subroutine initialize_forcing(f,q)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    real(real64),intent(in)::q
    f%top_flux=q; f%top_head=H0_CM; f%bottom_flux=q; f%bottom_head=H0_CM
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64; f%subsurface_irrigation_source=0.0_real64; f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_column_template(c,t,i)
    type(fmr_logical_column_t),intent(out)::c
    type(fmr_template_t),intent(out)::t
    integer,intent(in)::i
    t%template_id=560000_int64+i; t%physics_topology_id=560010_int64; t%vertical_layout_id=560020_int64
    t%state_layout_id=560030_int64; t%solver_interface_id=560040_int64; t%optional_state_layout_id=0_int64
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=COLUMN_ID(i); c%template_id=t%template_id; c%parameter_ref=i; c%state_handle=i
    c%forcing_handle=i; c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_template

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

  subroutine initialize_committed_state(state,p,lineage_id,ok)
    type(kernel_committed_state_t),intent(out)::state
    type(fmr_b110_physical_parameters_t),intent(in)::p
    integer(int64),intent(in)::lineage_id
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
    physical%pressure_head=heads; physical%water_content=water; physical%ponding_depth=0.0_real64; physical%groundwater_level=-2.0_real64
    accepted_predecessor_right_derivative=0.0_real64
    call fmr_new_b110_temporal_indicator_committed_state(state,lineage_id,physical,0.0_real64,ok, &
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
      state%active_nodes=typed%active_nodes; allocate(state%pressure_head(typed%active_nodes),state%water_content(typed%active_nodes))
      state%pressure_head=typed%pressure_head; state%water_content=typed%water_content
      state%ponding_depth=typed%ponding_depth; state%groundwater_level=typed%groundwater_level
    class default
      return
    end select
    parameter_set%parameter_set_id=p%parameter_set_id; parameter_set%active_nodes=p%active_nodes
    allocate(parameter_set%z(numnod),parameter_set%dz(numnod),parameter_set%node_distance(numnod))
    parameter_set%z=p%z; parameter_set%dz=p%dz; parameter_set%node_distance=p%node_distance; ok=.true.
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
