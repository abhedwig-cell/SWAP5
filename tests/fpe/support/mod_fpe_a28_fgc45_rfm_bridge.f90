module mod_fgc45_real_multiswap_c_bridge
  use, intrinsic :: iso_c_binding, only: c_double, c_int
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY, FMR_NUMERICAL_CONTINUATION_NONE, FMR_OPTIONAL_STATE_LAYOUT_RFM
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_b110_rfm_state_t, fmr_serialized_reference_backend_t, &
       fmr_serialized_physical_observation_t, fmr_new_b110_temporal_indicator_committed_state, fmr_new_b110_rfm_committed_state
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
  use mod_modflow6_swap_predictor_response, only: modflow6_swap_predictor_lineage_t, modflow6_swap_predictor_response_t, &
       compose_modflow6_swap_predictor_response, modflow6_derivative_coverage_t, MODFLOW6_DERIVATIVE_CENTERED_FD
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
  use mod_rfm_physical_state, only: rfm_physical_state_t
  use mod_rfm_runtime_configuration, only: rfm_runtime_configuration_t, RFM_SORPTIVITY_POLICY_A28_V1
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  logical, save :: approximate_policy=.false.
  integer, parameter :: NTILE=2
  real(real64), parameter :: FRACTION(NTILE)=[0.35_real64,0.65_real64]
  integer(int64), parameter :: COLUMN_ID(NTILE)=[550045_int64,550046_int64]
  integer(int64), parameter :: LEDGER_ID(NTILE)=[750045_int64,750046_int64]
  real(real64), save :: H0_CM=-75.0_real64
  real(real64), save :: rainfall_cm_day=0._real64
  real(real64), save :: DURATION_DAY=1.0e-4_real64
  integer, save :: nonlinear_iteration_limit=16
  real(real64), save :: solver_balance_tolerance=TOL
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

  integer(c_int) function a28_set_iteration_limit_c(limit) bind(C,name="a28_set_iteration_limit_c")
    integer(c_int),value::limit
    a28_set_iteration_limit_c=1
    if(initialized.or.limit<1.or.limit>64)return
    nonlinear_iteration_limit=limit
    a28_set_iteration_limit_c=0
  end function

  integer(c_int) function a28_set_solver_balance_tolerance_c(tol) bind(C,name="a28_set_solver_balance_tolerance_c")
    real(c_double),value::tol
    a28_set_solver_balance_tolerance_c=1
    if(initialized.or..not.ieee_is_finite(tol).or.tol<=0._c_double)return
    solver_balance_tolerance=real(tol,real64)
    a28_set_solver_balance_tolerance_c=0
  end function

  integer(c_int) function a28_set_fixture_c(h0,dt,rain) bind(C,name="a28_set_fixture_c")
    real(c_double),value::h0,dt,rain
    a28_set_fixture_c=1
    if(initialized.or..not.ieee_is_finite(h0).or..not.ieee_is_finite(dt).or..not.ieee_is_finite(rain))return
    if(dt<=0.or.rain<0)return
    H0_CM=h0;DURATION_DAY=dt;rainfall_cm_day=rain
    a28_set_fixture_c=0
  end function

  subroutine a28_storage_c(matrix,rfm) bind(C,name="a28_storage_c")
    real(c_double),intent(out)::matrix(NTILE),rfm(NTILE)
    class(transaction_state_t),allocatable::snapshot
    integer::i
    logical::ok
    do i=1,NTILE
      call committed(i)%snapshot(snapshot,ok);if(.not.ok)error stop 'storage snapshot'
      select type(snapshot)
      type is(fmr_b110_rfm_state_t)
        matrix(i)=sum(snapshot%water_content*predictor_parameters(i)%dz)+snapshot%ponding_depth
        rfm(i)=snapshot%rfm%storage_cm()
      class default
        error stop 'RFM storage snapshot type'
      end select
    end do
  end subroutine

  integer(c_int) function a28_next_window_c(rain,hcof,rhs,href) bind(C,name="a28_next_window_c")
    real(c_double),value::rain
    real(c_double),intent(out)::hcof,rhs,href
    type(modflow6_swap_predictor_response_t)::response(NTILE)
    type(groundwater_direct_tile_binding_t)::binding(NTILE)
    type(modflow6_multiswap_cell_response_t)::cell
    type(modflow6_linear_boundary_term_t)::term
    integer::i,status
    logical::ok
    real(real64)::time
    a28_next_window_c=1
    if(.not.initialized.or.any(ledger_prepared).or.rain<0)return
    do i=1,NTILE
      if(participant(i)%has_live_candidate())return
      call committed(i)%current_time(time,ok);if(.not.ok)return
      if(time/=window%t1)return
    end do
    window%t0=window%t1;window%t1=window%t0+DURATION_DAY
    do i=1,NTILE
      base_forcing(i)%rfm_surface%precipitation_rate_cm_per_day=rain
      base_forcing(i)%rfm_surface%event_active=rain>0
      call materializer(i)%initialize(base_forcing(i))
      call build_tile_predictor_rfm_fd(i,response(i),status);if(status/=0)return
      binding(i)%groundwater_cell_id=GW_CELL_ID;binding(i)%tile_id=COLUMN_ID(i);binding(i)%area_fraction=FRACTION(i)
      call participant(i)%capture_origin(committed(i),status);if(status/=GW_SWAP_PARTICIPANT_OK)return
    end do
    href=sum(FRACTION*response%h_bot_end_m)
    call compose_modflow6_multiswap_cell_response(binding,response,real(href,real64),cell,status)
    if(status/=MODFLOW6_MULTI_CELL_OK.or..not.cell%valid)return
    call compose_modflow6_linear_boundary_term(cell,AREA_M2,term,status)
    if(status/=MODFLOW6_LINEAR_BACKEND_OK.or..not.term%valid)return
    hcof=term%hcof_m2_per_day;rhs=term%rhs_m3_per_day
    a28_next_window_c=0
  end function

  integer(c_int) function a28_set_policy_c(approximate) bind(C,name="a28_set_policy_c")
    integer(c_int),value::approximate
    a28_set_policy_c=1
    if(initialized.or.(approximate/=0.and.approximate/=1))return
    approximate_policy=approximate==1
    a28_set_policy_c=0
  end function

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
      if(.not.ok)then;write(*,'(a,i0)')'A28_FGC45_INIT_FAIL=STATE tile=',i;return;end if
      call predictor_backend(i)%initialize(top(i))
      call corrector_backend(i)%initialize(top(i))
      call configure_tile_rfm(predictor_backend(i),i,ok); if(.not.ok)then;write(*,'(a,i0)')'A28_FGC45_INIT_FAIL=PRED_RFM tile=',i;return;end if
      call configure_tile_rfm(corrector_backend(i),i,ok); if(.not.ok)then;write(*,'(a,i0)')'A28_FGC45_INIT_FAIL=CORR_RFM tile=',i;return;end if
      call materializer(i)%initialize(base_forcing(i))
      call build_tile_predictor_rfm_fd(i,response(i),status)
      if(status/=0)then;write(*,'(a,i0,a,i0)')'A28_FGC45_INIT_FAIL=PREDICTOR tile=',i,' status=',status;return;end if
      binding(i)%groundwater_cell_id=GW_CELL_ID
      binding(i)%tile_id=COLUMN_ID(i)
      binding(i)%area_fraction=FRACTION(i)
    end do

    href=FRACTION(1)*response(1)%h_bot_end_m+FRACTION(2)*response(2)%h_bot_end_m
    call compose_modflow6_multiswap_cell_response(binding,response,href,cell,status)
    if(status/=MODFLOW6_MULTI_CELL_OK .or. .not.cell%valid)then;write(*,'(a,i0)')'A28_FGC45_INIT_FAIL=CELL status=',status;return;end if
    call compose_modflow6_linear_boundary_term(cell,AREA_M2,term,status)
    if(status/=MODFLOW6_LINEAR_BACKEND_OK .or. .not.term%valid)then;write(*,'(a,i0)')'A28_FGC45_INIT_FAIL=TERM status=',status;return;end if
    hcof=term%hcof_m2_per_day; rhs=term%rhs_m3_per_day; reference_head=term%reference_head_m

    do i=1,NTILE
      call participant(i)%capture_origin(committed(i),status)
      if(status/=GW_SWAP_PARTICIPANT_OK)then;write(*,'(a,i0,a,i0)')'A28_FGC45_INIT_FAIL=ORIGIN tile=',i,' status=',status;return;end if
      call ledger(i)%bind_identity(LEDGER_ID(i),status)
      if(status/=GW_MASS_LEDGER_OK)then;write(*,'(a,i0,a,i0)')'A28_FGC45_INIT_FAIL=LEDGER tile=',i,' status=',status;return;end if
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
      lineage%coupling_id=COUPLING_ID; lineage%swap_lineage_id=COLUMN_ID(i); lineage%swap_origin_revision=committed(i)%current_revision()
      lineage%groundwater_lineage_id=GW_LINEAGE_ID; lineage%groundwater_origin_revision=committed(i)%current_revision()
      lineage%candidate_revision=committed(i)%current_revision()+1_int64
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

  ! Qualification-only FD. Full RFM trajectories; no tangent, no preferential state transfer.
  subroutine build_tile_predictor_rfm_fd(i,response,status)
    integer,intent(in)::i
    type(modflow6_swap_predictor_response_t),intent(out)::response
    integer,intent(out)::status
    type(modflow6_swap_predictor_lineage_t)::lineage
    type(modflow6_derivative_coverage_t)::coverage
    type(b110_default_mvg_parameters_t),target::hp
    type(modflow6_prescribed_qbot_bottom_face_t)::start_face
    real(real64),parameter::deltas(3)=[1.e-7_real64,1.e-6_real64,1.e-5_real64]
    real(real64)::hbase,hplus,hminus,d(3)
    integer::j
    logical::ok
    status=1
    call sample_rfm_qbot(i,PREDICTOR_QBOT,hbase,ok);if(.not.ok)return
    do j=1,3
      call sample_rfm_qbot(i,PREDICTOR_QBOT+deltas(j),hplus,ok);if(.not.ok)return
      call sample_rfm_qbot(i,PREDICTOR_QBOT-deltas(j),hminus,ok);if(.not.ok)return
      d(j)=100._real64*(hplus-hminus)/(2._real64*deltas(j))
      write(*,'(a,i0,4(a,es24.16))')'A28_FD_DERIVATIVE tile=',i,' dq=',deltas(j),' hp_m=',hplus,' hm_m=',hminus,' derivative_day=',d(j)
    end do
    if(.not.all(ieee_is_finite(d)))return
    if(minval(abs(d))<=1.e-8_real64)return
    if(maxval(abs(d-d(2)))/abs(d(2))>1.e-3_real64)then
      write(*,'(a,i0,3(a,es24.16))')'A28_FD_STABILITY_FAIL tile=',i,' t0_day=',window%t0,' t1_day=',window%t1, &
           ' relative_spread=',maxval(abs(d-d(2)))/abs(d(2))
      call probe_rfm_fd_delta_ladder(i)
      return
    end if
    call initialize_b110_default_mvg_parameters(hp,predictor_parameters(i)%cofgen)
    call materialize_origin_face(predictor_parameters(i),hp,PREDICTOR_QBOT,start_face,status)
    if(status/=MODFLOW6_BOTTOM_FACE_OK)return
    lineage%coupling_id=COUPLING_ID;lineage%swap_lineage_id=committed(i)%current_lineage_id()
    lineage%swap_origin_revision=committed(i)%current_revision()
    lineage%groundwater_service_id=GW_SERVICE_ID;lineage%groundwater_lineage_id=GW_LINEAGE_ID
    lineage%groundwater_origin_revision=committed(i)%current_revision()
    coverage%lower_face_head_semantics_covered=.true.
    coverage%dynamic_top_boundary_active=.true.
    coverage%other_state_dependent_source_sink_active=.true.
    call compose_modflow6_swap_predictor_response(window,lineage,PREDICTOR_QBOT,start_face%hydraulic_head_m,hbase,d(2), &
         MODFLOW6_DERIVATIVE_CENTERED_FD,coverage,'centered-fd-rfm-full-trajectory','fgc45-rfm-fd',response,status)
    write(*,'(a,i0,a,i0,5(a,es24.16))')'A28_FD_RESPONSE tile=',i,' status=',status,' h0_m=',response%h_bot_start_m, &
         ' h1_m=',response%h_bot_end_m,' derivative_day=',d(2),' u=',response%coupling_storage_coefficient_u,' q_u_cm_day=',response%q_u_cm_per_day
    if(.not.response%valid)status=1
  end subroutine

  subroutine sample_rfm_qbot(i,q,hbot,ok)
    integer,intent(in)::i
    real(real64),intent(in)::q
    real(real64),intent(out)::hbot
    logical,intent(out)::ok
    type(kernel_checkpoint_t)::checkpoint
    type(kernel_result_t)::r
    type(kernel_candidate_state_t)::candidate
    type(kernel_diagnostics_t)::diag
    type(fmr_b110_physical_forcing_t)::forcing
    type(fmr_serialized_physical_observation_t)::observation
    type(soil_water_physical_state_t)::view
    type(soil_water_parameter_set_t)::ps
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    type(modflow6_prescribed_qbot_bottom_face_t)::face
    class(transaction_state_t),allocatable::before,after,saved,replay
    real(real64)::water(numnod),k(numnod),cap(numnod),dk(numnod),t0,t1,oldtime,newtime
    integer(int64)::oldrevision
    integer::status,rep
    logical::available
    ok=.false.;hbot=0
    oldrevision=committed(i)%current_revision();call committed(i)%current_time(oldtime,available);if(.not.available)return
    call committed(i)%snapshot(before,available);if(.not.available)return
    call fmr_capture_checkpoint(committed(i),checkpoint,available);if(.not.available)return
    forcing=base_forcing(i);forcing%bottom_flux=q
    do rep=1,2
      call predictor_backend(i)%run_trial(column(i),template(i),predictor_parameters(i),committed(i),forcing, &
           predictor_config,window%t0,window%t1,checkpoint,r,candidate,diag)
      write(*,'(a,i0,a,i0,a,es24.16,a,l1,6(a,i0),2(a,es24.16))')'A28_FD_TRIAL tile=',i,' replay=',rep,' q_cm_day=',q, &
           ' completed=',r%completed,' status=',r%status,' attempts=',diag%attempts,' retries=',diag%retries, &
           ' solver_rejections=',diag%solver_rejections,' temporal_rejections=',diag%temporal_rejections, &
           ' nonlinear_iterations=',diag%nonlinear_iterations,' mass_cm=',r%mass%residual,' max_step_mass_cm=',diag%max_abs_step_mass_residual
      if(diag%solver_rejections>0)then
        observation=predictor_backend(i)%observation()
        write(*,'(a,i0,7(a,i0),a,a)')'A28_FD_LAST_SOLVER tile=',i, &
             ' solver_executed=',merge(1,0,observation%solver_executed), &
             ' solver_status=',observation%solver_status, &
             ' nonlinear_iterations=',observation%solver_diagnostics%nonlinear_iterations, &
             ' jacobian_builds=',observation%solver_diagnostics%jacobian_builds, &
             ' linear_solves=',observation%solver_diagnostics%linear_solves, &
             ' backtracking_attempts=',observation%solver_diagnostics%backtracking_attempts, &
             ' alternative_solver_calls=',observation%solver_diagnostics%alternative_solver_calls, &
             ' route=',trim(observation%solver_diagnostics%route)
      end if
      if(.not.r%completed.or..not.candidate%ready())return
      if(abs(r%mass%residual)>TOL.or.diag%max_abs_step_mass_residual>TOL)return
      if(candidate%current_lineage_id()/=committed(i)%current_lineage_id())return
      if(candidate%origin_revision()/=oldrevision)return
      call candidate%origin_interval(t0,t1,available);if(.not.available)return
      if(t0/=window%t0.or.t1/=window%t1)return
      call candidate%snapshot(replay,available);if(.not.available)return
      if(rep==1)then
        call replay%clone(saved)
        call materialize_solver_view(candidate,predictor_parameters(i),view,ps,available);if(.not.available)return
        call initialize_b110_default_mvg_parameters(hp,predictor_parameters(i)%cofgen)
        call bind_b110_default_mvg_provider(provider,hp,DURATION_DAY)
        call provider%evaluate(view%pressure_head,water,k,cap,dk)
        call materialize_modflow6_prescribed_qbot_bottom_face(view%pressure_head(numnod),k(numnod),q, &
             0.5_real64*predictor_parameters(i)%dz(numnod),datum,face,status)
        if(status/=MODFLOW6_BOTTOM_FACE_OK)return
        hbot=face%hydraulic_head_m
      else
        if(.not.same_rfm_snapshot(saved,replay))return
      end if
      call predictor_backend(i)%discard_trial_candidate(candidate,diag)
      if(candidate%ready())return
      call committed(i)%snapshot(after,available);if(.not.available)return
      if(.not.same_rfm_snapshot(before,after))return
      call committed(i)%current_time(newtime,available);if(.not.available)return
      if(committed(i)%current_revision()/=oldrevision.or.newtime/=oldtime)return
      if(diag%committed_state_mutations/=0)return
    end do
    ok=ieee_is_finite(hbot)
    write(*,'(a,i0,a,es24.16,a,es24.16,a)')'A28_FD_SAMPLE_PASS tile=',i,' q_cm_day=',q,' face_head_m=',hbot, &
         ' candidate_provenance=PASS immutable=PASS discard=PASS replay=PASS'
  end subroutine

  subroutine probe_rfm_fd_delta_ladder(i)
    integer,intent(in)::i
    real(real64),parameter::delta(7)=[1.e-7_real64,3.e-7_real64,1.e-6_real64,3.e-6_real64, &
         1.e-5_real64,3.e-5_real64,1.e-4_real64]
    real(real64)::hp,hm,derivative
    integer::j
    logical::okp,okm
    write(*,'(a,i0,a,2(es24.16,1x))')'A28_FD_DELTA_LADDER tile=',i,' window=',window%t0,window%t1
    do j=1,size(delta)
      call sample_rfm_qbot(i,PREDICTOR_QBOT+delta(j),hp,okp)
      call sample_rfm_qbot(i,PREDICTOR_QBOT-delta(j),hm,okm)
      if(.not.okp.or..not.okm)then
        write(*,'(a,i0,a,es24.16,a,l1,a,l1)')'A28_FD_LADDER_SAMPLE_FAIL tile=',i,' dq=',delta(j),' plus=',okp,' minus=',okm
        return
      end if
      derivative=100._real64*(hp-hm)/(2._real64*delta(j))
      write(*,'(a,i0,2(a,es24.16))')'A28_FD_LADDER tile=',i,' dq=',delta(j),' derivative_day=',derivative
    end do
  end subroutine

  logical function same_rfm_snapshot(a,b) result(same)
    class(transaction_state_t),intent(in)::a,b
    same=.false.
    select type(a)
    type is(fmr_b110_rfm_state_t)
      select type(b)
      type is(fmr_b110_rfm_state_t)
        same=a%active_nodes==b%active_nodes
        if(.not.same)return
        same=all(transfer(a%pressure_head,[0_int64],size(a%pressure_head))==transfer(b%pressure_head,[0_int64],size(b%pressure_head))).and. &
             all(transfer(a%water_content,[0_int64],size(a%water_content))==transfer(b%water_content,[0_int64],size(b%water_content))).and. &
             transfer(a%ponding_depth,0_int64)==transfer(b%ponding_depth,0_int64).and. &
             transfer(a%groundwater_level,0_int64)==transfer(b%groundwater_level,0_int64).and.a%rfm%same_values(b%rfm)
      end select
    end select
  end function

  subroutine configure_tile_rfm(backend,i,ok)
    type(fmr_serialized_reference_backend_t),intent(inout)::backend
    integer,intent(in)::i
    logical,intent(out)::ok
    type(rfm_runtime_configuration_t)::c
    real(real64)::area,deep,depth
    integer::endpoint_node
    area=merge(0.05_real64,0.10_real64,i==1)
    deep=merge(0.25_real64,0.65_real64,i==1)
    if(numnod>4)then
      endpoint_node=3
    else
      endpoint_node=merge(3,4,i==1)
    end if
    depth=abs(z(endpoint_node))
    c%enabled=.true.;c%sigma_b=.65_real64;c%f_mb=deep;c%connectivity_p=1._real64
    c%z_ah_cm=0.25_real64;c%z_ic_cm=depth;c%chi_wall=1._real64;c%exchange_length_cm=0.5_real64
    c%mb_contact_length_cm=abs(z(numnod))+0.5_real64*dz(numnod);c%sorptivity_panels=64
    
    if(approximate_policy)c%sorptivity_policy=RFM_SORPTIVITY_POLICY_A28_V1
    c%mb_wall_node_index=numnod;c%endpoint_depth_cm=[depth];c%endpoint_contact_thickness_cm=[dz(endpoint_node)]
    c%endpoint_area_fraction=[area*(1._real64-deep)];c%endpoint_node_index=[endpoint_node]
    call backend%configure_rfm_runtime(c,ok)
  end subroutine configure_tile_rfm

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
    p%max_iterations=nonlinear_iteration_limit; p%max_backtracking=8; p%min_step_duration=1.0e-8_real64
    p%compartment_balance_tolerance=solver_balance_tolerance; p%total_balance_tolerance=solver_balance_tolerance; p%head_abs_tolerance=TOL
    p%head_rel_tolerance=TOL; p%ponding_tolerance=TOL; p%root_extraction_active=.false.
    p%macropore_active=.false.; p%snow_active=.false.; p%hysteresis_active=.false.
    p%tabulated_hydraulics_active=.false.; p%elasticity_active=.false.; p%frost_active=.false.
    p%soil_temperature_active=.false.; p%drainage_response_active=.false.
  end subroutine initialize_parameters

  subroutine initialize_forcing(f,q)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    real(real64),intent(in)::q
    f%top_flux=0.0_real64; f%top_head=H0_CM; f%bottom_flux=q; f%bottom_head=H0_CM
    allocate(f%rfm_surface); f%rfm_surface%supplied=.true.; f%rfm_surface%event_active=.false.
    f%rfm_surface%precipitation_rate_cm_per_day=rainfall_cm_day; f%rfm_surface%event_active=rainfall_cm_day>0
    f%rfm_surface%ponding_max_cm=0.1_real64; f%rfm_surface%runoff_resistance_day=0.1_real64
    f%rfm_surface%runoff_exponent=1.0_real64
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64; f%subsurface_irrigation_source=0.0_real64; f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_column_template(c,t,i)
    type(fmr_logical_column_t),intent(out)::c
    type(fmr_template_t),intent(out)::t
    integer,intent(in)::i
    t%template_id=560000_int64+i; t%physics_topology_id=560010_int64; t%vertical_layout_id=560020_int64
    t%state_layout_id=560030_int64; t%solver_interface_id=560040_int64; t%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_RFM
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=COLUMN_ID(i); c%template_id=t%template_id; c%parameter_ref=i; c%state_handle=i
    c%forcing_handle=i; c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_template

  subroutine initialize_configs(pred,corr)
    type(canonical_numerical_config_t),intent(out)::pred,corr
    pred%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF; pred%transaction%temporal_tolerance=HEAD_BUDGET
    pred%transaction%mass_tolerance=TOL; pred%transaction%retry_scale=0.5_real64; pred%transaction%max_retries=12
    pred%max_committed_substeps=4096; pred%progress_tolerance=0.0_real64
    pred%model_temporal_indicator_budget_available=.true.; pred%model_temporal_indicator_budget=HEAD_BUDGET
    pred%accepted_trajectory_direction%requested=.false.
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
    physical%pressure_head=heads; physical%water_content=water; physical%ponding_depth=0.0_real64
    physical%groundwater_level=merge(H0_CM+z(1),-2.0_real64,numnod>4)
    accepted_predecessor_right_derivative=0.0_real64
    block
      type(rfm_physical_state_t)::rfm_state
      call rfm_state%initialize(1,ok); if(.not.ok)return
      call fmr_new_b110_rfm_committed_state(state,lineage_id,physical,rfm_state,0.0_real64,ok)
    end block
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
    block
      class(transaction_state_t),allocatable::origin_snapshot
      logical::ok
      integer::tile
      tile=int(p%parameter_set_id-1000_int64)
      call committed(tile)%snapshot(origin_snapshot,ok)
      if(.not.ok)then;status=1;return;end if
      select type(origin_snapshot)
      class is(fmr_b110_physical_state_t)
        heads=origin_snapshot%pressure_head
      class default
        status=1;return
      end select
    end block
    call bind_b110_default_mvg_provider(provider,hp,DURATION_DAY)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    call materialize_modflow6_prescribed_qbot_bottom_face(heads(numnod),conductivity(numnod),qbot, &
         0.5_real64*p%dz(numnod),datum,face,status)
  end subroutine materialize_origin_face
end module mod_fgc45_real_multiswap_c_bridge
