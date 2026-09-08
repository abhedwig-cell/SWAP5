program test_fvq26_prescribed_bottom_head_runtime_v2
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
       kernel_candidate_state_t, kernel_diagnostics_t, kernel_executor_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint, fmr_discard_candidate
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: t0 = 3200.125_real64
  real(real64), parameter :: t1 = 3200.375_real64
  real(real64), parameter :: head_down = -75.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  integer, parameter :: rejected_modes(4) = [1, 3, 8, 9]

  type(fmr_logical_column_t) :: columns(1)
  type(fmr_template_t) :: templates(1)
  type(fmr_b110_physical_parameters_t) :: down_parameters(1), up_parameters(1), rejected_parameters
  type(fmr_b110_physical_forcing_t) :: down_forcing(1), down_seed_forcing(1), up_forcing(1)
  type(fmr_b110_physical_state_t) :: down_initial, up_initial
  type(kernel_committed_state_t) :: direct_committed
  type(kernel_committed_state_t) :: runtime_down(1), runtime_seed(1), runtime_up(1)
  type(fmr_serialized_reference_backend_t) :: backend
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider
  type(canonical_numerical_config_t) :: config
  type(kernel_checkpoint_t) :: checkpoint
  type(kernel_result_t) :: trial_down, trial_up, trial_replay, rejected
  type(kernel_candidate_state_t) :: candidate
  type(kernel_diagnostics_t) :: trial_diagnostics, discard_diagnostics
  type(kernel_executor_t) :: discard_executor
  type(fmr_serialized_physical_observation_t) :: obs_down, obs_up, obs_replay
  type(fmr_serialized_column_result_t), allocatable :: result_down(:), result_seed(:), result_up(:)
  type(fmr_column_diagnostics_t), allocatable :: diag_down(:), diag_seed(:), diag_up(:)
  type(fmr_aggregate_diagnostics_t) :: aggregate_down, aggregate_seed, aggregate_up
  type(fmr_serialized_batch_diagnostics_t) :: runtime_diag_down, runtime_diag_seed, runtime_diag_up
  real(real64) :: k_down, k_up, expected_down_qbot, expected_up_qbot
  real(real64) :: expected_down_amount, expected_up_amount
  integer(int64) :: committed_revision
  integer :: dispatch_down, dispatch_seed, dispatch_up, i
  logical :: ok

  call configure_column(columns(1), templates(1))
  call configure_transaction(config)
  call configure_downward_case(down_parameters(1), down_initial, down_forcing(1), k_down)
  down_seed_forcing(1) = down_forcing(1)
  down_seed_forcing(1)%bottom_flux = -8642.0_real64
  call configure_upward_case(up_parameters(1), up_initial, up_forcing(1), k_up)

  expected_down_qbot = -k_down
  expected_up_qbot = k_up
  expected_down_amount = k_down * (t1-t0)
  expected_up_amount = k_up * (t1-t0)

  ! ------------------------------------------------------------------
  ! Direct stationary downward solution. For uniform head the lower Darcy
  ! gradient is +1, therefore qbot=-K. The bottom_flux input is deliberately
  ! unrelated and must not appear in the authoritative result.
  ! ------------------------------------------------------------------
  call fmr_new_b110_committed_state(direct_committed, columns(1)%column_id, down_initial, t0, ok)
  call require(ok, 'downward committed initialization')
  committed_revision = direct_committed%current_revision()
  call backend%initialize(top_provider)
  call fmr_capture_checkpoint(direct_committed, checkpoint, ok)
  call require(ok, 'downward checkpoint')
  call poison_legacy_bottom_context()
  call backend%run_trial(columns(1), templates(1), down_parameters(1), direct_committed, down_forcing(1), config, &
       t0, t1, checkpoint, trial_down, candidate, trial_diagnostics)
  obs_down = backend%observation()
  call require(trial_down%completed, 'downward trial completed')
  call require(candidate%ready(), 'downward candidate ready')
  call require(obs_down%solver_executed, 'downward solver executed')
  call require(same_bits(obs_down%bottom_flux, expected_down_qbot), 'downward independent Darcy qbot')
  call require(.not. same_bits(obs_down%bottom_flux, down_forcing(1)%bottom_flux), 'downward seed not authority')
  call require(trial_down%mass%complete, 'downward mass complete')
  call require(trial_down%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, 'downward mass mask')
  call require(abs(trial_down%mass%residual) <= hard_mass_gate, 'downward hard mass')
  call require(same_bits(trial_down%mass%total_in, expected_down_amount), 'downward expected mass in')
  call require(same_bits(trial_down%mass%total_out, expected_down_amount), 'downward expected mass out')
  call require(trial_diagnostics%temporal_rejections == 0, 'downward temporal acceptance')
  call require(trial_diagnostics%mass_rejections == 0, 'downward mass acceptance')
  call require(direct_committed%current_revision() == committed_revision, 'downward trial not committed')
  call require(committed_matches(direct_committed, down_initial), 'downward committed origin unchanged')
  discard_diagnostics = trial_diagnostics
  call fmr_discard_candidate(discard_executor, candidate, discard_diagnostics)
  call require(.not. candidate%ready(), 'downward candidate discarded')

  ! ------------------------------------------------------------------
  ! Exact stationary upward solution with accepted positive qbot.
  ! Heads are saturated and increase by 2*disnod per node, giving every
  ! internal gradient -1. The lower face head extends the same line, while
  ! qtop=+Ks. Thus the exact solution has qbot=+Ks and zero storage change.
  ! This case cannot pass by echoing the deliberately negative bottom seed.
  ! ------------------------------------------------------------------
  call fmr_new_b110_committed_state(direct_committed, columns(1)%column_id, up_initial, t0, ok)
  call require(ok, 'upward committed initialization')
  committed_revision = direct_committed%current_revision()
  call fmr_capture_checkpoint(direct_committed, checkpoint, ok)
  call require(ok, 'upward checkpoint')
  call poison_legacy_bottom_context()
  call backend%run_trial(columns(1), templates(1), up_parameters(1), direct_committed, up_forcing(1), config, &
       t0, t1, checkpoint, trial_up, candidate, trial_diagnostics)
  obs_up = backend%observation()
  call require(trial_up%completed, 'upward trial completed')
  call require(candidate%ready(), 'upward candidate ready')
  call require(obs_up%solver_executed, 'upward solver executed')
  call require(obs_up%bottom_flux > 0.0_real64, 'upward qbot positive')
  call require(same_bits(obs_up%bottom_flux, expected_up_qbot), 'upward independent Darcy qbot')
  call require(.not. same_bits(obs_up%bottom_flux, up_forcing(1)%bottom_flux), 'upward seed not authority')
  call require(trial_up%mass%complete, 'upward mass complete')
  call require(trial_up%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, 'upward mass mask')
  call require(abs(trial_up%mass%residual) <= hard_mass_gate, 'upward hard mass')
  call require(same_bits(trial_up%mass%total_in, expected_up_amount), 'upward expected bottom input')
  call require(same_bits(trial_up%mass%total_out, expected_up_amount), 'upward expected top output')
  call require(trial_diagnostics%temporal_rejections == 0, 'upward temporal acceptance')
  call require(trial_diagnostics%mass_rejections == 0, 'upward mass acceptance')
  call require(direct_committed%current_revision() == committed_revision, 'upward trial not committed')
  call require(committed_matches(direct_committed, up_initial), 'upward committed origin unchanged')
  discard_diagnostics = trial_diagnostics
  call fmr_discard_candidate(discard_executor, candidate, discard_diagnostics)
  call require(.not. candidate%ready(), 'upward candidate discarded')

  ! A/B/A replay: return to the downward origin after a distinct accepted
  ! upward trial and require bitwise qbot/mass/route identity.
  call fmr_new_b110_committed_state(direct_committed, columns(1)%column_id, down_initial, t0, ok)
  call require(ok, 'replay origin initialization')
  call fmr_capture_checkpoint(direct_committed, checkpoint, ok)
  call require(ok, 'replay checkpoint')
  call poison_legacy_bottom_context()
  call backend%run_trial(columns(1), templates(1), down_parameters(1), direct_committed, down_forcing(1), config, &
       t0, t1, checkpoint, trial_replay, candidate, trial_diagnostics)
  obs_replay = backend%observation()
  call require(trial_replay%completed, 'replay completed')
  call require(candidate%ready(), 'replay candidate ready')
  call require(same_bits(obs_replay%bottom_flux, obs_down%bottom_flux), 'A/B/A qbot identity')
  call require(obs_replay%solver_diagnostics%nonlinear_iterations == &
       obs_down%solver_diagnostics%nonlinear_iterations, 'A/B/A iterations')
  call require(same_bits(trial_replay%mass%total_in, trial_down%mass%total_in), 'A/B/A mass in')
  call require(same_bits(trial_replay%mass%total_out, trial_down%mass%total_out), 'A/B/A mass out')
  discard_diagnostics = trial_diagnostics
  call fmr_discard_candidate(discard_executor, candidate, discard_diagnostics)
  call require(committed_matches(direct_committed, down_initial), 'A/B/A committed isolation')

  ! Unowned routes remain fail closed.
  do i = 1, size(rejected_modes)
    rejected_parameters = down_parameters(1)
    rejected_parameters%bottom_mode = rejected_modes(i)
    call fmr_capture_checkpoint(direct_committed, checkpoint, ok)
    call require(ok, 'unsupported checkpoint')
    call backend%run_trial(columns(1), templates(1), rejected_parameters, direct_committed, down_forcing(1), &
         config, t0, t1, checkpoint, rejected, candidate, trial_diagnostics)
    call require(.not. rejected%completed, 'unsupported mode rejected')
    call require(trial_diagnostics%admission_rejections > 0, 'unsupported admission diagnostic')
    call require(.not. candidate%ready(), 'unsupported mode no candidate')
  end do
  rejected_parameters = down_parameters(1)
  rejected_parameters%swkimpl = 1
  call fmr_capture_checkpoint(direct_committed, checkpoint, ok)
  call backend%run_trial(columns(1), templates(1), rejected_parameters, direct_committed, down_forcing(1), &
       config, t0, t1, checkpoint, rejected, candidate, trial_diagnostics)
  call require(.not. rejected%completed .and. trial_diagnostics%admission_rejections > 0, 'swkimpl1 fail closed')
  rejected_parameters = down_parameters(1)
  rejected_parameters%macropore_active = .true.
  call fmr_capture_checkpoint(direct_committed, checkpoint, ok)
  call backend%run_trial(columns(1), templates(1), rejected_parameters, direct_committed, down_forcing(1), &
       config, t0, t1, checkpoint, rejected, candidate, trial_diagnostics)
  call require(.not. rejected%completed .and. trial_diagnostics%admission_rejections > 0, 'macropores fail closed')

  ! Composed serialized downward route, twice with different irrelevant seeds.
  call fmr_new_b110_committed_state(runtime_down(1), columns(1)%column_id, down_initial, t0, ok)
  call require(ok, 'runtime down init')
  call fmr_new_b110_committed_state(runtime_seed(1), columns(1)%column_id, down_initial, t0, ok)
  call require(ok, 'runtime seed init')
  call poison_legacy_bottom_context()
  call fmr_run_serialized_physical_multiswap(columns, templates, down_parameters, down_forcing, runtime_down, &
       config, top_provider, t0, t1, 1, result_down, diag_down, aggregate_down, dispatch_down, runtime_diag_down)
  call poison_legacy_bottom_context()
  call fmr_run_serialized_physical_multiswap(columns, templates, down_parameters, down_seed_forcing, runtime_seed, &
       config, top_provider, t0, t1, 1, result_seed, diag_seed, aggregate_seed, dispatch_seed, runtime_diag_seed)
  call require(dispatch_down == FMR_SERIAL_DISPATCH_OK .and. dispatch_seed == FMR_SERIAL_DISPATCH_OK, &
       'downward serialized dispatch')
  call require(result_down(1)%completed .and. result_down(1)%committed, 'downward runtime committed')
  call require(result_seed(1)%completed .and. result_seed(1)%committed, 'seed runtime committed')
  call require(result_down(1)%mass%complete .and. result_seed(1)%mass%complete, 'downward runtime mass complete')
  call require(same_bits(result_down(1)%mass%total_in, expected_down_amount), 'downward runtime mass in')
  call require(same_bits(result_down(1)%mass%total_out, expected_down_amount), 'downward runtime mass out')
  call require(same_bits(result_down(1)%mass%total_in, result_seed(1)%mass%total_in), 'seed mass-in identity')
  call require(same_bits(result_down(1)%mass%total_out, result_seed(1)%mass%total_out), 'seed mass-out identity')
  call require(committed_states_identical(runtime_down(1), runtime_seed(1)), 'seed committed-state identity')
  call require(committed_matches(runtime_down(1), down_initial), 'downward stationary runtime state')
  call require(diag_down(1)%retries == 0 .and. diag_seed(1)%retries == 0, 'downward zero-tolerance no retries')
  call require(runtime_diag_down%max_simultaneous_real_physical_solves == 1, 'downward serialized bound')
  call require(runtime_diag_down%authoritative_aggregate_mass%accepted_transaction_count == 1, &
       'downward exactly one accepted transaction')
  call require(same_bits(runtime_diag_down%authoritative_aggregate_mass%total_in, result_down(1)%mass%total_in), &
       'downward aggregate mass in exactly once')
  call require(same_bits(runtime_diag_down%authoritative_aggregate_mass%total_out, result_down(1)%mass%total_out), &
       'downward aggregate mass out exactly once')

  ! Composed serialized accepted positive-qbot route.
  call fmr_new_b110_committed_state(runtime_up(1), columns(1)%column_id, up_initial, t0, ok)
  call require(ok, 'runtime up init')
  call poison_legacy_bottom_context()
  call fmr_run_serialized_physical_multiswap(columns, templates, up_parameters, up_forcing, runtime_up, &
       config, top_provider, t0, t1, 1, result_up, diag_up, aggregate_up, dispatch_up, runtime_diag_up)
  call require(dispatch_up == FMR_SERIAL_DISPATCH_OK, 'upward serialized dispatch')
  call require(result_up(1)%admitted, 'upward runtime admitted')
  call require(result_up(1)%completed .and. result_up(1)%committed, 'upward runtime committed')
  call require(result_up(1)%solver_executed, 'upward runtime solver executed')
  call require(result_up(1)%mass%complete, 'upward runtime mass complete')
  call require(abs(result_up(1)%mass%residual) <= hard_mass_gate, 'upward runtime hard mass')
  call require(same_bits(result_up(1)%mass%total_in, expected_up_amount), 'upward runtime bottom input')
  call require(same_bits(result_up(1)%mass%total_out, expected_up_amount), 'upward runtime top output')
  call require(committed_matches(runtime_up(1), up_initial), 'upward stationary runtime state')
  call require(diag_up(1)%retries == 0, 'upward zero-tolerance no retries')
  call require(runtime_diag_up%max_simultaneous_real_physical_solves == 1, 'upward serialized bound')
  call require(runtime_diag_up%authoritative_aggregate_mass%accepted_transaction_count == 1, &
       'upward exactly one accepted transaction')

  write(*,'(A,Z16.16)') 'FVQ26V2_NEGATIVE_QBOT_BITS=', transfer(obs_down%bottom_flux, 0_int64)
  write(*,'(A,Z16.16)') 'FVQ26V2_POSITIVE_QBOT_BITS=', transfer(obs_up%bottom_flux, 0_int64)
  write(*,'(A,Z16.16)') 'FVQ26V2_EXPECTED_NEGATIVE_QBOT_BITS=', transfer(expected_down_qbot, 0_int64)
  write(*,'(A,Z16.16)') 'FVQ26V2_EXPECTED_POSITIVE_QBOT_BITS=', transfer(expected_up_qbot, 0_int64)
  write(*,'(A)') 'FVQ26V2_ACCEPTED_NEGATIVE_QBOT=PASS'
  write(*,'(A)') 'FVQ26V2_ACCEPTED_POSITIVE_QBOT=PASS'
  write(*,'(A)') 'FVQ26V2_BOTTOM_HEAD_AUTHORITY=PASS'
  write(*,'(A)') 'FVQ26V2_BOTTOM_FLUX_SEED_IRRELEVANCE=PASS'
  write(*,'(A)') 'FVQ26V2_QBOT_MASS_EXACTLY_ONCE=PASS'
  write(*,'(A)') 'FVQ26V2_TRANSACTION_DISCARD_ISOLATION=PASS'
  write(*,'(A)') 'FVQ26V2_A_B_A_REPLAY=PASS'
  write(*,'(A)') 'FVQ26V2_ZERO_TOLERANCE_TEMPORAL_ACCEPTANCE=PASS'
  write(*,'(A)') 'FVQ26V2_FAIL_CLOSED_PROFILE=PASS'
  write(*,'(A)') 'FVQ26V2_SERIALIZED_ONLY=PASS'
  write(*,'(A)') 'FVQ26V2_PRESCRIBED_BOTTOM_HEAD_RUNTIME_ORACLE PASS'

contains

  subroutine configure_column(column, template)
    type(fmr_logical_column_t), intent(out) :: column
    type(fmr_template_t), intent(out) :: template
    template%template_id = 2626_int64
    template%physics_topology_id = 262601_int64
    template%vertical_layout_id = 262602_int64
    template%state_layout_id = 262603_int64
    template%solver_interface_id = 262604_int64
    template%optional_state_layout_id = 262605_int64
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    column%column_id = 2626001_int64
    column%template_id = template%template_id
    column%parameter_ref = 1_int64
    column%state_handle = 1_int64
    column%forcing_handle = 1_int64
    column%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_column

  subroutine configure_base_parameters(p)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    integer :: k
    p%parameter_set_id = 262601_int64
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
    type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: water(numnod), capacity(numnod), dkdh(numnod)
    call initialize_b110_default_mvg_parameters(hydraulic_parameters, p%cofgen)
    call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, t1-t0)
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
    heads = head_down
    call evaluate_state(p, heads, state, conductivity)
    do k = 2, numnod
      call require(same_bits(conductivity(k), conductivity(1)), 'downward uniform conductivity')
    end do
    conductivity_reference = conductivity(1)
    forcing%top_flux = -conductivity_reference
    forcing%top_head = head_down
    forcing%bottom_flux = 2468.0_real64
    forcing%bottom_head = head_down
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
      call require(same_bits(conductivity(k), conductivity(1)), 'upward saturated conductivity')
    end do
    conductivity_reference = conductivity(1)
    call require(same_bits(conductivity_reference, p%cofgen(3,1)), 'upward conductivity equals Ks')
    forcing%top_flux = conductivity_reference
    forcing%top_head = heads(1)
    forcing%bottom_flux = -777.0_real64
    ! Explicit HeadCalc geometry owns the lower face distance as 0.5*dz(n),
    ! so extending the -1 Darcy gradient requires hbot-h(n)=2*0.5*dz(n)=dz(n).
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

  logical function committed_matches(committed, expected)
    type(kernel_committed_state_t), intent(in) :: committed
    type(fmr_b110_physical_state_t), intent(in) :: expected
    class(transaction_state_t), allocatable :: snapshot
    logical :: available
    integer :: k
    committed_matches = .false.
    call committed%snapshot(snapshot, available)
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

  logical function committed_states_identical(a, b)
    type(kernel_committed_state_t), intent(in) :: a, b
    class(transaction_state_t), allocatable :: sa, sb
    logical :: oka, okb
    integer :: k
    committed_states_identical = .false.
    call a%snapshot(sa, oka)
    call b%snapshot(sb, okb)
    if (.not. oka .or. .not. okb) return
    select type (pa => sa)
    type is (fmr_b110_physical_state_t)
      select type (pb => sb)
      type is (fmr_b110_physical_state_t)
        if (pa%active_nodes /= pb%active_nodes) return
        do k = 1, pa%active_nodes
          if (.not. same_bits(pa%pressure_head(k), pb%pressure_head(k))) return
          if (.not. same_bits(pa%water_content(k), pb%water_content(k))) return
        end do
        if (.not. same_bits(pa%ponding_depth, pb%ponding_depth)) return
        if (.not. same_bits(pa%groundwater_level, pb%groundwater_level)) return
        committed_states_identical = .true.
      end select
    end select
  end function committed_states_identical

  pure logical function same_bits(a,b)
    real(real64), intent(in) :: a,b
    same_bits = transfer(a,0_int64) == transfer(b,0_int64)
  end function same_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FVQ26V2_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fvq26_prescribed_bottom_head_runtime_v2
