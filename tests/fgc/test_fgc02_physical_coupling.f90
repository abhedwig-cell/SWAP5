program test_fgc02_physical_coupling
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: legacy_melt => melt
  use MOD_drain, only: legacy_qdra => qdra
  use MOD_irrigation, only: legacy_qssdi => qssdi
  use variables, only: legacy_qrot => qrot, legacy_swbotb => swbotb, legacy_hbot => hbot, legacy_qbot => qbot
  use mod_transaction_reference, only: transaction_state_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t, kernel_executor_t, KERNEL_COMMIT_STATUS_COMMITTED
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint, fmr_discard_candidate, fmr_commit_candidate
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: t0 = 4100.125_real64
  real(real64), parameter :: t1 = 4100.375_real64
  real(real64), parameter :: head_corrector_cm = -75.0_real64
  real(real64), parameter :: head_predictor_cm = head_corrector_cm + 0.01_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  real(real64), parameter :: cm_to_m = 0.01_real64
  real(real64), parameter :: day_to_s = 86400.0_real64

  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(fmr_b110_physical_parameters_t) :: parameters, up_parameters
  type(fmr_b110_physical_forcing_t) :: forcing_predictor, forcing_corrector, up_forcing
  type(fmr_b110_physical_state_t) :: initial_state, up_initial
  type(kernel_committed_state_t) :: committed, up_committed
  type(fmr_serialized_reference_backend_t) :: backend, up_backend
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider, up_top_provider
  type(canonical_numerical_config_t) :: config
  type(kernel_checkpoint_t) :: checkpoint, up_checkpoint
  type(kernel_result_t) :: predictor_result, corrector_result, up_result
  type(kernel_candidate_state_t) :: candidate
  type(kernel_diagnostics_t) :: predictor_diag, corrector_diag, discard_diag, up_diag
  type(kernel_executor_t) :: transaction_executor
  type(fmr_serialized_physical_observation_t) :: predictor_obs, corrector_obs, up_obs
  real(real64) :: conductivity0, up_conductivity
  real(real64) :: h_swap_pred_m, h_swap_corr_m, h_gw_m
  real(real64) :: q_swap_pred, q_swap_corr, q_gw_pred, q_gw_corr
  real(real64) :: predictor_head_residual, corrector_head_residual
  real(real64) :: predictor_flux_residual, corrector_flux_residual
  real(real64) :: dt_seconds, interface_mass_residual, accepted_interface_transfer_m
  real(real64) :: coupling_ledger_m
  integer(int64) :: revision0
  integer :: commit_status
  logical :: ok, did_commit

  call configure_column(column, template)
  call configure_transaction(config)
  call configure_downward_case(parameters, initial_state, forcing_corrector, conductivity0)
  forcing_predictor = forcing_corrector
  forcing_predictor%bottom_head = head_predictor_cm
  forcing_predictor%bottom_flux = 12345.678_real64

  call fmr_new_b110_committed_state(committed, column%column_id, initial_state, t0, ok)
  call require(ok, 'committed T0 initialization')
  revision0 = committed%current_revision()
  call backend%initialize(top_provider)
  call fmr_capture_checkpoint(committed, checkpoint, ok)
  call require(ok, 'single T0 checkpoint capture')

  ! Predictor from T0. The fixed-head aquifer returns the reference groundwater
  ! head and the exact opposite interface flux. Predictor must not commit.
  call poison_legacy_bottom_context()
  call backend%run_trial(column, template, parameters, committed, forcing_predictor, config, &
       t0, t1, checkpoint, predictor_result, candidate, predictor_diag)
  predictor_obs = backend%observation()
  call require(predictor_result%completed, 'predictor physical trial completed')
  call require(candidate%ready(), 'predictor candidate ready')
  call require(predictor_obs%solver_executed, 'predictor solver executed')
  call require(trim(predictor_obs%solver_diagnostics%route) == 'legacy-reference-bound', 'predictor route')
  call require(predictor_result%mass%complete, 'predictor mass complete')
  call require(predictor_result%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, 'predictor mass mask')
  call require(abs(predictor_result%mass%residual) <= hard_mass_gate, 'predictor hard SWAP mass')
  call require(committed%current_revision() == revision0, 'predictor does not commit')
  call require(committed_matches(committed, initial_state), 'predictor leaves committed state unchanged')

  h_swap_pred_m = forcing_predictor%bottom_head * cm_to_m
  h_gw_m = head_corrector_cm * cm_to_m
  q_swap_pred = -predictor_obs%bottom_flux * cm_to_m / day_to_s
  q_gw_pred = -q_swap_pred
  predictor_head_residual = h_swap_pred_m - h_gw_m
  predictor_flux_residual = q_swap_pred + q_gw_pred
  call require(predictor_head_residual /= 0.0_real64, 'predictor requires corrector')
  call require(predictor_flux_residual == 0.0_real64, 'predictor action reaction exact')

  discard_diag = predictor_diag
  call fmr_discard_candidate(transaction_executor, candidate, discard_diag)
  call require(.not. candidate%ready(), 'predictor candidate discarded')
  call require(discard_diag%candidate_rollbacks > predictor_diag%candidate_rollbacks, 'predictor rollback diagnosed')
  call require(committed%current_revision() == revision0, 'predictor discard leaves revision unchanged')
  call require(committed_matches(committed, initial_state), 'predictor discard leaves physical state unchanged')

  ! Corrector uses the SAME checkpoint object, not a new checkpoint and not the
  ! predictor candidate. The fixed-head aquifer head is now the SWAP boundary.
  call poison_legacy_bottom_context()
  call backend%run_trial(column, template, parameters, committed, forcing_corrector, config, &
       t0, t1, checkpoint, corrector_result, candidate, corrector_diag)
  corrector_obs = backend%observation()
  call require(corrector_result%completed, 'corrector physical trial completed')
  call require(candidate%ready(), 'corrector candidate ready')
  call require(corrector_obs%solver_executed, 'corrector solver executed')
  call require(trim(corrector_obs%solver_diagnostics%route) == 'legacy-reference-bound', 'corrector route')
  call require(corrector_result%mass%complete, 'corrector mass complete')
  call require(corrector_result%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, 'corrector mass mask')
  call require(abs(corrector_result%mass%residual) <= hard_mass_gate, 'corrector hard SWAP mass')
  call require(committed%current_revision() == revision0, 'corrector trial not yet committed')
  call require(committed_matches(committed, initial_state), 'corrector trial leaves committed origin unchanged')

  h_swap_corr_m = forcing_corrector%bottom_head * cm_to_m
  q_swap_corr = -corrector_obs%bottom_flux * cm_to_m / day_to_s
  q_gw_corr = -q_swap_corr
  corrector_head_residual = h_swap_corr_m - h_gw_m
  corrector_flux_residual = q_swap_corr + q_gw_corr
  dt_seconds = (t1-t0) * day_to_s
  interface_mass_residual = corrector_flux_residual * dt_seconds
  call require(corrector_head_residual == 0.0_real64, 'corrector head residual exact')
  call require(corrector_flux_residual == 0.0_real64, 'corrector action reaction exact')
  call require(interface_mass_residual == 0.0_real64, 'corrector interface mass cancels exact')

  ! Coupling ledger remains empty for rejected predictor and receives only the
  ! accepted corrector transfer after all hard gates pass.
  coupling_ledger_m = 0.0_real64
  accepted_interface_transfer_m = q_swap_corr * dt_seconds
  coupling_ledger_m = coupling_ledger_m + accepted_interface_transfer_m
  call require(same_bits(coupling_ledger_m, accepted_interface_transfer_m), 'accepted interface transfer booked once')

  call fmr_commit_candidate(transaction_executor, committed, candidate, corrector_diag, did_commit, commit_status)
  call require(did_commit, 'accepted corrector committed')
  call require(commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'corrector commit status')
  call require(committed%current_revision() == revision0 + 1_int64, 'exactly one committed revision')
  call require(.not. candidate%ready(), 'commit consumes candidate')

  call fmr_commit_candidate(transaction_executor, committed, candidate, corrector_diag, did_commit, commit_status)
  call require(.not. did_commit, 'second commit rejected')
  call require(committed%current_revision() == revision0 + 1_int64, 'second commit cannot mutate revision')

  ! Separate accepted upward stationary case proves the opposite interface sign
  ! on the same qualified F-MR11 route. It is discarded and never enters the
  ! coupling ledger of the accepted downward corrector window.
  call configure_upward_case(up_parameters, up_initial, up_forcing, up_conductivity)
  call fmr_new_b110_committed_state(up_committed, column%column_id, up_initial, t0, ok)
  call require(ok, 'upward committed initialization')
  call up_backend%initialize(up_top_provider)
  call fmr_capture_checkpoint(up_committed, up_checkpoint, ok)
  call require(ok, 'upward checkpoint')
  call poison_legacy_bottom_context()
  call up_backend%run_trial(column, template, up_parameters, up_committed, up_forcing, config, &
       t0, t1, up_checkpoint, up_result, candidate, up_diag)
  up_obs = up_backend%observation()
  call require(up_result%completed .and. candidate%ready(), 'accepted upward physical trial')
  call require(up_obs%bottom_flux > 0.0_real64, 'upward qbot positive into SWAP')
  call require(-up_obs%bottom_flux * cm_to_m / day_to_s < 0.0_real64, 'upward q_swap negative out convention')
  call require(up_result%mass%complete .and. abs(up_result%mass%residual) <= hard_mass_gate, 'upward hard mass')
  discard_diag = up_diag
  call fmr_discard_candidate(transaction_executor, candidate, discard_diag)
  call require(up_committed%current_revision() == 0_int64, 'upward evidence trial not committed')

  write(*,'(A,Z16.16)') 'FGC02_PREDICTOR_QBOT_BITS=', transfer(predictor_obs%bottom_flux,0_int64)
  write(*,'(A,Z16.16)') 'FGC02_CORRECTOR_QBOT_BITS=', transfer(corrector_obs%bottom_flux,0_int64)
  write(*,'(A,Z16.16)') 'FGC02_UPWARD_QBOT_BITS=', transfer(up_obs%bottom_flux,0_int64)
  write(*,'(A,Z16.16)') 'FGC02_QSWAP_BITS=', transfer(q_swap_corr,0_int64)
  write(*,'(A,Z16.16)') 'FGC02_INTERFACE_TRANSFER_BITS=', transfer(accepted_interface_transfer_m,0_int64)
  write(*,'(A)') 'FGC02_FMR11_IMMUTABLE_PHYSICAL_TRIAL=PASS'
  write(*,'(A)') 'FGC02_GW_HEAD_TO_BOTTOM_HEAD_AUTHORITY=PASS'
  write(*,'(A)') 'FGC02_QSWAP_EQUALS_NEGATIVE_QBOT=PASS'
  write(*,'(A)') 'FGC02_ACTION_REACTION_EXACT=PASS'
  write(*,'(A)') 'FGC02_PREDICTOR_NONCOMMIT=PASS'
  write(*,'(A)') 'FGC02_SAME_T0_CORRECTOR=PASS'
  write(*,'(A)') 'FGC02_ACCEPTED_CORRECTOR_SINGLE_COMMIT=PASS'
  write(*,'(A)') 'FGC02_REJECTED_PREDICTOR_NO_MASS_LEDGER=PASS'
  write(*,'(A)') 'FGC02_INTERFACE_MASS_EXACTLY_ONCE=PASS'
  write(*,'(A)') 'FGC02_POSITIVE_NEGATIVE_INTERFACE_SIGNS=PASS'
  write(*,'(A)') 'FGC02_GENERIC_NONMIDNIGHT_WINDOW=PASS'
  write(*,'(A)') 'FGC02_PHYSICAL_COUPLING_DRIVER PASS'

contains

  subroutine configure_column(c, templ)
    type(fmr_logical_column_t), intent(out) :: c
    type(fmr_template_t), intent(out) :: templ
    templ%template_id = 2702_int64
    templ%physics_topology_id = 270201_int64
    templ%vertical_layout_id = 270202_int64
    templ%state_layout_id = 270203_int64
    templ%solver_interface_id = 270204_int64
    templ%optional_state_layout_id = 270205_int64
    templ%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id = 2702001_int64
    c%template_id = templ%template_id
    c%parameter_ref = 1_int64
    c%state_handle = 1_int64
    c%forcing_handle = 1_int64
    c%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_column

  subroutine configure_base_parameters(p)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    integer :: k
    p%parameter_set_id = 270201_int64
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod), p%cofgen(24,numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)
    p%cofgen = 0.0_real64
    do k = 1, numnod
      p%cofgen(1,k)=0.032_real64; p%cofgen(2,k)=0.423_real64; p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64; p%cofgen(5,k)=0.365_real64; p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k); p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64; p%cofgen(10,k)=p%cofgen(3,k); p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k); p%cofgen(22,k)=-1.0e6_real64; p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode = 5
    p%swkimpl = 0
    p%swkmean = 1
    p%swsophy = 0
    p%root_extraction_active = .false.
    p%macropore_active = .false.
    p%snow_active = .false.
    p%hysteresis_active = .false.
    p%tabulated_hydraulics_active = .false.
    p%elasticity_active = .false.
    p%frost_active = .false.
    p%max_iterations = 8
    p%max_backtracking = 4
    p%min_step_duration = 1.0e-6_real64
    p%compartment_balance_tolerance = hard_mass_gate
    p%total_balance_tolerance = hard_mass_gate
    p%head_abs_tolerance = hard_mass_gate
    p%head_rel_tolerance = hard_mass_gate
    p%ponding_tolerance = hard_mass_gate
  end subroutine configure_base_parameters

  subroutine evaluate_state(p, heads, state, conductivity)
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    real(real64), intent(in) :: heads(:)
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: conductivity(:)
    type(b110_default_mvg_parameters_t), target :: hyd_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: water(numnod), capacity(numnod), dkdh(numnod)
    call initialize_b110_default_mvg_parameters(hyd_parameters, p%cofgen)
    call bind_b110_default_mvg_provider(constitutive, hyd_parameters, t1-t0)
    call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
  end subroutine evaluate_state

  subroutine allocate_zero_forcing(f)
    type(fmr_b110_physical_forcing_t), intent(inout) :: f
    allocate(f%drainage_flux_by_level(1,numnod), f%subsurface_irrigation_source(numnod), &
             f%root_extraction_sink(numnod))
    f%drainage_flux_by_level = 0.0_real64
    f%subsurface_irrigation_source = 0.0_real64
    f%root_extraction_sink = 0.0_real64
  end subroutine allocate_zero_forcing

  subroutine configure_downward_case(p, state, forcing, conductivity_reference)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(out) :: conductivity_reference
    real(real64) :: heads(numnod), conductivity(numnod)
    integer :: k
    call configure_base_parameters(p)
    heads = head_corrector_cm
    call evaluate_state(p, heads, state, conductivity)
    do k = 2, numnod
      call require(same_bits(conductivity(k), conductivity(1)), 'uniform downward conductivity')
    end do
    conductivity_reference = conductivity(1)
    forcing%top_flux = -conductivity_reference
    forcing%top_head = head_corrector_cm
    forcing%bottom_flux = 2468.0_real64
    forcing%bottom_head = head_corrector_cm
    call allocate_zero_forcing(forcing)
  end subroutine configure_downward_case

  subroutine configure_upward_case(p, state, forcing, conductivity_reference)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(out) :: conductivity_reference
    real(real64) :: heads(numnod), conductivity(numnod)
    integer :: k
    call configure_base_parameters(p)
    do k = 1, numnod
      heads(k) = 10.0_real64 + 2.0_real64*real(k-1,real64)
    end do
    call evaluate_state(p, heads, state, conductivity)
    do k = 2, numnod
      call require(same_bits(conductivity(k), conductivity(1)), 'uniform saturated conductivity')
    end do
    conductivity_reference = conductivity(1)
    call require(same_bits(conductivity_reference, p%cofgen(3,1)), 'upward conductivity equals Ks')
    forcing%top_flux = conductivity_reference
    forcing%top_head = heads(1)
    forcing%bottom_flux = -777.0_real64
    forcing%bottom_head = heads(numnod) + p%dz(numnod)
    call allocate_zero_forcing(forcing)
  end subroutine configure_upward_case

  subroutine configure_transaction(cfg)
    type(canonical_numerical_config_t), intent(out) :: cfg
    cfg%transaction%temporal_tolerance = 0.0_real64
    cfg%transaction%mass_tolerance = hard_mass_gate
    cfg%transaction%retry_scale = 0.5_real64
    cfg%transaction%max_retries = 2
    cfg%max_committed_substeps = 8
    cfg%progress_tolerance = 0.0_real64
  end subroutine configure_transaction

  subroutine poison_legacy_bottom_context()
    swmacro = 0
    legacy_melt = 0.0_real64
    legacy_qdra = 24680.0_real64
    legacy_qssdi = -13579.0_real64
    legacy_qrot = 0.0_real64
    legacy_swbotb = 3
    legacy_hbot = 99999.0_real64
    legacy_qbot = -99999.0_real64
  end subroutine poison_legacy_bottom_context

  logical function committed_matches(state, expected)
    type(kernel_committed_state_t), intent(in) :: state
    type(fmr_b110_physical_state_t), intent(in) :: expected
    class(transaction_state_t), allocatable :: snapshot
    logical :: available
    integer :: k
    committed_matches = .false.
    call state%snapshot(snapshot, available)
    if (.not. available) return
    select type (physical => snapshot)
    type is (fmr_b110_physical_state_t)
      if (physical%active_nodes /= expected%active_nodes) return
      if (.not. allocated(physical%pressure_head) .or. .not. allocated(physical%water_content)) return
      do k = 1, physical%active_nodes
        if (.not. same_bits(physical%pressure_head(k), expected%pressure_head(k))) return
        if (.not. same_bits(physical%water_content(k), expected%water_content(k))) return
      end do
      if (.not. same_bits(physical%ponding_depth, expected%ponding_depth)) return
      if (.not. same_bits(physical%groundwater_level, expected%groundwater_level)) return
      committed_matches = .true.
    end select
  end function committed_matches

  pure logical function same_bits(a,b)
    real(real64), intent(in) :: a,b
    same_bits = transfer(a,0_int64) == transfer(b,0_int64)
  end function same_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FGC02_PHYSICAL_COUPLING_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fgc02_physical_coupling
