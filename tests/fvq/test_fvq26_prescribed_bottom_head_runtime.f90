program test_fvq26_prescribed_bottom_head_runtime
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
  real(real64), parameter :: head_reference = -75.0_real64
  real(real64), parameter :: head_inflow = -55.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  integer, parameter :: rejected_modes(4) = [1, 3, 8, 9]

  type(fmr_logical_column_t) :: columns(1)
  type(fmr_template_t) :: templates(1)
  type(fmr_b110_physical_parameters_t) :: parameters(1), rejected_parameters
  type(fmr_b110_physical_forcing_t) :: forcing_reference(1), forcing_seed(1), forcing_inflow
  type(fmr_b110_physical_state_t) :: initial_state
  type(kernel_committed_state_t) :: direct_committed, runtime_reference(1), runtime_seed(1)
  type(fmr_serialized_reference_backend_t) :: backend
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider
  type(canonical_numerical_config_t) :: config
  type(kernel_checkpoint_t) :: checkpoint
  type(kernel_result_t) :: trial_reference, trial_inflow, trial_replay, rejected
  type(kernel_candidate_state_t) :: candidate
  type(kernel_diagnostics_t) :: trial_diagnostics, discard_diagnostics
  type(kernel_executor_t) :: discard_executor
  type(fmr_serialized_physical_observation_t) :: obs_reference, obs_inflow, obs_replay
  type(fmr_serialized_column_result_t), allocatable :: result_reference(:), result_seed(:)
  type(fmr_column_diagnostics_t), allocatable :: diag_reference(:), diag_seed(:)
  type(fmr_aggregate_diagnostics_t) :: aggregate_reference, aggregate_seed
  type(fmr_serialized_batch_diagnostics_t) :: runtime_diag_reference, runtime_diag_seed
  real(real64) :: conductivity_reference, expected_qbot, expected_boundary_amount
  integer(int64) :: committed_revision
  integer :: dispatch_reference, dispatch_seed, i
  logical :: ok

  call configure_parameters(parameters(1), initial_state, conductivity_reference)
  call configure_column(columns(1), templates(1))
  call configure_transaction(config)

  expected_qbot = -conductivity_reference
  expected_boundary_amount = conductivity_reference * (t1 - t0)

  call configure_forcing(forcing_reference(1), conductivity_reference, 2468.0_real64, head_reference)
  forcing_seed(1) = forcing_reference(1)
  forcing_seed(1)%bottom_flux = -8642.0_real64
  forcing_inflow = forcing_reference(1)
  forcing_inflow%bottom_head = head_inflow
  forcing_inflow%bottom_flux = 1357.0_real64

  ! Independent direct-runtime oracle.  For a uniform stationary profile with
  ! lower face head equal to the last-node head, the B1.10 lower Darcy gradient
  ! is exactly one.  Therefore qbot must be -K.  This expected value is derived
  ! here from the constitutive provider and is not read from F-MR11 owner output.
  call fmr_new_b110_committed_state(direct_committed, columns(1)%column_id, initial_state, t0, ok)
  call require(ok, 'direct committed initialization')
  committed_revision = direct_committed%current_revision()
  call backend%initialize(top_provider)

  call fmr_capture_checkpoint(direct_committed, checkpoint, ok)
  call require(ok, 'reference checkpoint')
  call poison_legacy_bottom_context()
  call backend%run_trial(columns(1), templates(1), parameters(1), direct_committed, forcing_reference(1), config, &
       t0, t1, checkpoint, trial_reference, candidate, trial_diagnostics)
  obs_reference = backend%observation()
  call require(trial_reference%completed, 'reference trial completed')
  call require(candidate%ready(), 'reference candidate ready')
  call require(obs_reference%solver_executed, 'reference solver executed')
  call require(trim(obs_reference%solver_diagnostics%route) == 'legacy-reference-bound', 'reference solver route')
  call require(same_bits(obs_reference%bottom_flux, expected_qbot), 'independent Darcy qbot identity')
  call require(.not. same_bits(obs_reference%bottom_flux, forcing_reference(1)%bottom_flux), &
       'input bottom flux seed is not authority')
  call require(trial_reference%mass%complete, 'reference mass complete')
  call require(trial_reference%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, 'reference mass mask')
  call require(abs(trial_reference%mass%residual) <= hard_mass_gate, 'reference hard mass closure')
  call require(same_bits(trial_reference%mass%total_in, expected_boundary_amount), &
       'independent expected top inflow amount')
  call require(same_bits(trial_reference%mass%total_out, expected_boundary_amount), &
       'independent expected bottom outflow amount')
  call require(trial_diagnostics%temporal_rejections == 0, 'zero-tolerance exact temporal acceptance')
  call require(trial_diagnostics%mass_rejections == 0, 'hard mass accepted without retry')
  call require(direct_committed%current_revision() == committed_revision, 'trial does not commit')
  call require(committed_matches_initial(direct_committed, initial_state), 'trial leaves committed state unchanged')

  discard_diagnostics = trial_diagnostics
  call fmr_discard_candidate(discard_executor, candidate, discard_diagnostics)
  call require(.not. candidate%ready(), 'discard invalidates candidate')
  call require(direct_committed%current_revision() == committed_revision, 'discard leaves revision unchanged')
  call require(committed_matches_initial(direct_committed, initial_state), 'discard leaves physical state unchanged')

  ! Exercise the opposite qbot sign from the same committed origin.
  call fmr_capture_checkpoint(direct_committed, checkpoint, ok)
  call require(ok, 'inflow checkpoint')
  call poison_legacy_bottom_context()
  call backend%run_trial(columns(1), templates(1), parameters(1), direct_committed, forcing_inflow, config, &
       t0, t1, checkpoint, trial_inflow, candidate, trial_diagnostics)
  obs_inflow = backend%observation()
  call require(obs_inflow%solver_executed, 'inflow solver executed')
  call require(obs_inflow%bottom_flux > 0.0_real64, 'positive qbot supported')
  call require(.not. same_bits(obs_inflow%bottom_flux, obs_reference%bottom_flux), 'bottom head controls qbot')
  if (candidate%ready()) then
    discard_diagnostics = trial_diagnostics
    call fmr_discard_candidate(discard_executor, candidate, discard_diagnostics)
  end if
  call require(direct_committed%current_revision() == committed_revision, 'inflow trial does not commit')
  call require(committed_matches_initial(direct_committed, initial_state), 'inflow discard restores origin')

  ! A/B/A replay from the exact same committed origin.
  call fmr_capture_checkpoint(direct_committed, checkpoint, ok)
  call require(ok, 'replay checkpoint')
  call poison_legacy_bottom_context()
  call backend%run_trial(columns(1), templates(1), parameters(1), direct_committed, forcing_reference(1), config, &
       t0, t1, checkpoint, trial_replay, candidate, trial_diagnostics)
  obs_replay = backend%observation()
  call require(trial_replay%completed, 'replay completed')
  call require(candidate%ready(), 'replay candidate ready')
  call require(same_bits(obs_replay%bottom_flux, obs_reference%bottom_flux), 'A/B/A qbot identity')
  call require(obs_replay%solver_diagnostics%nonlinear_iterations == &
       obs_reference%solver_diagnostics%nonlinear_iterations, 'A/B/A iteration identity')
  call require(same_bits(trial_replay%mass%total_in, trial_reference%mass%total_in), 'A/B/A mass-in identity')
  call require(same_bits(trial_replay%mass%total_out, trial_reference%mass%total_out), 'A/B/A mass-out identity')
  discard_diagnostics = trial_diagnostics
  call fmr_discard_candidate(discard_executor, candidate, discard_diagnostics)
  call require(committed_matches_initial(direct_committed, initial_state), 'A/B/A committed isolation')

  ! Unsupported physical/numerical routes remain fail closed.
  do i = 1, size(rejected_modes)
    rejected_parameters = parameters(1)
    rejected_parameters%bottom_mode = rejected_modes(i)
    call fmr_capture_checkpoint(direct_committed, checkpoint, ok)
    call require(ok, 'rejected-mode checkpoint')
    call backend%run_trial(columns(1), templates(1), rejected_parameters, direct_committed, forcing_reference(1), &
         config, t0, t1, checkpoint, rejected, candidate, trial_diagnostics)
    call require(.not. rejected%completed, 'unsupported bottom mode rejected')
    call require(trial_diagnostics%admission_rejections > 0, 'unsupported bottom mode admission diagnostic')
    call require(.not. candidate%ready(), 'unsupported bottom mode has no candidate')
  end do

  rejected_parameters = parameters(1)
  rejected_parameters%swkimpl = 1
  call fmr_capture_checkpoint(direct_committed, checkpoint, ok)
  call require(ok, 'swkimpl1 checkpoint')
  call backend%run_trial(columns(1), templates(1), rejected_parameters, direct_committed, forcing_reference(1), &
       config, t0, t1, checkpoint, rejected, candidate, trial_diagnostics)
  call require(.not. rejected%completed, 'swkimpl1 rejected')
  call require(trial_diagnostics%admission_rejections > 0, 'swkimpl1 admission diagnostic')

  rejected_parameters = parameters(1)
  rejected_parameters%macropore_active = .true.
  call fmr_capture_checkpoint(direct_committed, checkpoint, ok)
  call require(ok, 'macropore checkpoint')
  call backend%run_trial(columns(1), templates(1), rejected_parameters, direct_committed, forcing_reference(1), &
       config, t0, t1, checkpoint, rejected, candidate, trial_diagnostics)
  call require(.not. rejected%completed, 'active macropores rejected')
  call require(trial_diagnostics%admission_rejections > 0, 'active macropore admission diagnostic')

  ! Composed serialized runtime with two deliberately different bottom_flux
  ! seeds.  The committed states and authoritative mass must remain bitwise
  ! identical because bottom_head is the mode-5 authority.
  call fmr_new_b110_committed_state(runtime_reference(1), columns(1)%column_id, initial_state, t0, ok)
  call require(ok, 'runtime reference init')
  call fmr_new_b110_committed_state(runtime_seed(1), columns(1)%column_id, initial_state, t0, ok)
  call require(ok, 'runtime seed init')

  call poison_legacy_bottom_context()
  call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcing_reference, runtime_reference, &
       config, top_provider, t0, t1, 1, result_reference, diag_reference, aggregate_reference, &
       dispatch_reference, runtime_diag_reference)
  call poison_legacy_bottom_context()
  call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcing_seed, runtime_seed, &
       config, top_provider, t0, t1, 1, result_seed, diag_seed, aggregate_seed, dispatch_seed, runtime_diag_seed)

  call require(dispatch_reference == FMR_SERIAL_DISPATCH_OK, 'reference serialized dispatch')
  call require(dispatch_seed == FMR_SERIAL_DISPATCH_OK, 'seed serialized dispatch')
  call require(result_reference(1)%admitted .and. result_seed(1)%admitted, 'mode5 runtime admitted')
  call require(result_reference(1)%completed .and. result_reference(1)%committed, 'reference runtime committed')
  call require(result_seed(1)%completed .and. result_seed(1)%committed, 'seed runtime committed')
  call require(result_reference(1)%solver_executed .and. result_seed(1)%solver_executed, 'runtime solver executed')
  call require(trim(result_reference(1)%solver_route) == 'legacy-reference-bound', 'runtime solver route')
  call require(result_reference(1)%mass%complete .and. result_seed(1)%mass%complete, 'runtime mass complete')
  call require(result_reference(1)%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, 'runtime mass mask')
  call require(abs(result_reference(1)%mass%residual) <= hard_mass_gate, 'runtime hard mass closure')
  call require(same_bits(result_reference(1)%mass%total_in, expected_boundary_amount), &
       'runtime independent top input amount')
  call require(same_bits(result_reference(1)%mass%total_out, expected_boundary_amount), &
       'runtime independent bottom output amount')
  call require(same_bits(result_reference(1)%mass%total_in, result_seed(1)%mass%total_in), &
       'seed-independent runtime mass in')
  call require(same_bits(result_reference(1)%mass%total_out, result_seed(1)%mass%total_out), &
       'seed-independent runtime mass out')
  call require(committed_states_identical(runtime_reference(1), runtime_seed(1)), 'seed-independent committed state')
  call require(committed_matches_initial(runtime_reference(1), initial_state), 'stationary committed state identity')
  call require(runtime_reference(1)%current_revision() == 1_int64, 'single runtime commit')
  call require(runtime_seed(1)%current_revision() == 1_int64, 'single seed runtime commit')
  call require(diag_reference(1)%retries == 0 .and. diag_seed(1)%retries == 0, &
       'zero-tolerance stationary runtime no retries')
  call require(runtime_diag_reference%max_simultaneous_real_physical_solves == 1, 'serialized solve bound')
  call require(runtime_diag_seed%max_simultaneous_real_physical_solves == 1, 'serialized seed solve bound')
  call require(runtime_diag_reference%authoritative_aggregate_mass%complete, 'aggregate mass complete')
  call require(runtime_diag_reference%authoritative_aggregate_mass%accepted_transaction_count == 1, &
       'aggregate accepted transaction exactly once')
  call require(same_bits(runtime_diag_reference%authoritative_aggregate_mass%total_in, &
       result_reference(1)%mass%total_in), 'aggregate mass in exactly once')
  call require(same_bits(runtime_diag_reference%authoritative_aggregate_mass%total_out, &
       result_reference(1)%mass%total_out), 'aggregate mass out exactly once')

  write(*,'(A,Z16.16)') 'FVQ26_EXPECTED_QBOT_BITS=', transfer(expected_qbot, 0_int64)
  write(*,'(A,Z16.16)') 'FVQ26_OBSERVED_QBOT_BITS=', transfer(obs_reference%bottom_flux, 0_int64)
  write(*,'(A,Z16.16)') 'FVQ26_POSITIVE_QBOT_BITS=', transfer(obs_inflow%bottom_flux, 0_int64)
  write(*,'(A,Z16.16)') 'FVQ26_EXPECTED_BOUNDARY_AMOUNT_BITS=', transfer(expected_boundary_amount, 0_int64)
  write(*,'(A)') 'FVQ26_INDEPENDENT_DARCY_QBOT=PASS'
  write(*,'(A)') 'FVQ26_BOTTOM_HEAD_AUTHORITY=PASS'
  write(*,'(A)') 'FVQ26_BOTTOM_FLUX_SEED_IRRELEVANCE=PASS'
  write(*,'(A)') 'FVQ26_POSITIVE_NEGATIVE_QBOT=PASS'
  write(*,'(A)') 'FVQ26_QBOT_MASS_EXACTLY_ONCE=PASS'
  write(*,'(A)') 'FVQ26_TRANSACTION_DISCARD_ISOLATION=PASS'
  write(*,'(A)') 'FVQ26_A_B_A_REPLAY=PASS'
  write(*,'(A)') 'FVQ26_ZERO_TOLERANCE_TEMPORAL_ACCEPTANCE=PASS'
  write(*,'(A)') 'FVQ26_FAIL_CLOSED_PROFILE=PASS'
  write(*,'(A)') 'FVQ26_SERIALIZED_ONLY=PASS'
  write(*,'(A)') 'FVQ26_PRESCRIBED_BOTTOM_HEAD_RUNTIME_ORACLE PASS'

contains

  subroutine configure_column(column, template)
    type(fmr_logical_column_t), intent(out) :: column
    type(fmr_template_t), intent(out) :: template
    template%template_id = 2601_int64
    template%physics_topology_id = 260101_int64
    template%vertical_layout_id = 260102_int64
    template%state_layout_id = 260103_int64
    template%solver_interface_id = 260104_int64
    template%optional_state_layout_id = 260105_int64
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    column%column_id = 2601001_int64
    column%template_id = template%template_id
    column%parameter_ref = 1_int64
    column%state_handle = 1_int64
    column%forcing_handle = 1_int64
    column%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_column

  subroutine configure_parameters(p, state, conductivity_reference)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: conductivity_reference
    type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: k

    p%parameter_set_id = 260101_int64
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod), p%cofgen(24,numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)
    p%cofgen = 0.0_real64
    do k = 1, numnod
      p%cofgen(1,k) = 0.032_real64
      p%cofgen(2,k) = 0.423_real64
      p%cofgen(3,k) = 4.75_real64
      p%cofgen(4,k) = 0.0135_real64
      p%cofgen(5,k) = 0.365_real64
      p%cofgen(6,k) = 1.455_real64
      p%cofgen(7,k) = 1.0_real64 - 1.0_real64/p%cofgen(6,k)
      p%cofgen(8,k) = p%cofgen(4,k)
      p%cofgen(9,k) = 0.0_real64
      p%cofgen(10,k) = p%cofgen(3,k)
      p%cofgen(11,k) = 0.999_real64
      p%cofgen(12,k) = 0.99_real64*p%cofgen(3,k)
      p%cofgen(22,k) = -1.0e6_real64
      p%cofgen(23,k) = 1.0e-12_real64
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

    call initialize_b110_default_mvg_parameters(hydraulic_parameters, p%cofgen)
    call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, t1-t0)
    heads = head_reference
    call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
    do k = 2, numnod
      call require(same_bits(conductivity(k), conductivity(1)), 'uniform conductivity fixture')
    end do
    conductivity_reference = conductivity(1)

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
  end subroutine configure_parameters

  subroutine configure_forcing(f, conductivity_reference, bottom_seed, bottom_head)
    type(fmr_b110_physical_forcing_t), intent(out) :: f
    real(real64), intent(in) :: conductivity_reference, bottom_seed, bottom_head
    f%top_flux = -conductivity_reference
    f%top_head = head_reference
    f%bottom_flux = bottom_seed
    f%bottom_head = bottom_head
    allocate(f%drainage_flux_by_level(1,numnod), f%subsurface_irrigation_source(numnod), &
             f%root_extraction_sink(numnod))
    f%drainage_flux_by_level = 0.0_real64
    f%subsurface_irrigation_source = 0.0_real64
    f%root_extraction_sink = 0.0_real64
  end subroutine configure_forcing

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

  logical function committed_matches_initial(committed, initial)
    type(kernel_committed_state_t), intent(in) :: committed
    type(fmr_b110_physical_state_t), intent(in) :: initial
    class(transaction_state_t), allocatable :: snapshot
    logical :: available
    integer :: k
    committed_matches_initial = .false.
    call committed%snapshot(snapshot, available)
    if (.not. available) return
    select type (physical => snapshot)
    type is (fmr_b110_physical_state_t)
      if (physical%active_nodes /= initial%active_nodes) return
      if (.not. allocated(physical%pressure_head) .or. .not. allocated(physical%water_content)) return
      do k = 1, physical%active_nodes
        if (.not. same_bits(physical%pressure_head(k), initial%pressure_head(k))) return
        if (.not. same_bits(physical%water_content(k), initial%water_content(k))) return
      end do
      if (.not. same_bits(physical%ponding_depth, initial%ponding_depth)) return
      if (.not. same_bits(physical%groundwater_level, initial%groundwater_level)) return
      committed_matches_initial = .true.
    end select
  end function committed_matches_initial

  logical function committed_states_identical(a, b)
    type(kernel_committed_state_t), intent(in) :: a, b
    class(transaction_state_t), allocatable :: state_a, state_b
    logical :: ok_a, ok_b
    integer :: k
    committed_states_identical = .false.
    call a%snapshot(state_a, ok_a)
    call b%snapshot(state_b, ok_b)
    if (.not. ok_a .or. .not. ok_b) return
    select type (physical_a => state_a)
    type is (fmr_b110_physical_state_t)
      select type (physical_b => state_b)
      type is (fmr_b110_physical_state_t)
        if (physical_a%active_nodes /= physical_b%active_nodes) return
        do k = 1, physical_a%active_nodes
          if (.not. same_bits(physical_a%pressure_head(k), physical_b%pressure_head(k))) return
          if (.not. same_bits(physical_a%water_content(k), physical_b%water_content(k))) return
        end do
        if (.not. same_bits(physical_a%ponding_depth, physical_b%ponding_depth)) return
        if (.not. same_bits(physical_a%groundwater_level, physical_b%groundwater_level)) return
        committed_states_identical = .true.
      end select
    end select
  end function committed_states_identical

  pure logical function same_bits(a, b)
    real(real64), intent(in) :: a, b
    same_bits = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function same_bits

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FVQ26_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fvq26_prescribed_bottom_head_runtime
