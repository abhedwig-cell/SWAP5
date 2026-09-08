program test_fmr11_prescribed_bottom_head_runtime
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

  real(real64), parameter :: t0 = 2600.25_real64
  real(real64), parameter :: t1 = 2600.50_real64
  real(real64), parameter :: head0 = -75.0_real64
  real(real64), parameter :: inflow_head = -55.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  integer, parameter :: bad_modes(4) = [1,3,8,9]

  type(fmr_logical_column_t) :: columns(1)
  type(fmr_template_t) :: templates(1)
  type(fmr_b110_physical_parameters_t) :: parameters(1), bad_parameters
  type(fmr_b110_physical_forcing_t) :: forcing_a(1), forcing_seed2(1), forcing_b
  type(fmr_b110_physical_state_t) :: initial_state
  type(kernel_committed_state_t) :: trial_committed, runtime_state_a(1), runtime_state_seed2(1)
  type(fmr_serialized_reference_backend_t) :: backend
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider
  type(canonical_numerical_config_t) :: config
  type(kernel_checkpoint_t) :: checkpoint
  type(kernel_result_t) :: trial_a, trial_b, trial_a2, rejected
  type(kernel_candidate_state_t) :: candidate
  type(kernel_diagnostics_t) :: trial_diag, discard_diag
  type(kernel_executor_t) :: discard_executor
  type(fmr_serialized_physical_observation_t) :: obs_a, obs_b, obs_a2
  type(fmr_serialized_column_result_t), allocatable :: result_a(:), result_seed2(:)
  type(fmr_column_diagnostics_t), allocatable :: diag_a(:), diag_seed2(:)
  type(fmr_aggregate_diagnostics_t) :: aggregate_a, aggregate_seed2
  type(fmr_serialized_batch_diagnostics_t) :: runtime_a, runtime_seed2
  real(real64) :: conductivity0, expected_amount
  integer(int64) :: revision_before
  integer :: dispatch_a, dispatch_seed2, i
  logical :: ok

  call configure_physical_parameters(parameters(1), initial_state, conductivity0)
  call configure_column(columns(1), templates(1))
  call configure_transaction(config)
  call configure_forcing(forcing_a(1), conductivity0, 123.456_real64, head0)
  forcing_seed2(1) = forcing_a(1)
  forcing_seed2(1)%bottom_flux = -987.654_real64
  forcing_b = forcing_a(1)
  forcing_b%bottom_head = inflow_head
  forcing_b%bottom_flux = 314.159_real64
  expected_amount = conductivity0 * (t1-t0)

  ! ------------------------------------------------------------------
  ! Direct backend A/B/A from one immutable committed checkpoint origin.
  ! This exposes the authoritative solver qbot without extending the
  ! production runtime result API. No direct trial is committed.
  ! ------------------------------------------------------------------
  call fmr_new_b110_committed_state(trial_committed, columns(1)%column_id, initial_state, t0, ok)
  call require(ok, 'direct committed init')
  revision_before = trial_committed%current_revision()
  call backend%initialize(top_provider)

  call fmr_capture_checkpoint(trial_committed, checkpoint, ok)
  call require(ok, 'capture A checkpoint')
  call poison_legacy_bottom_context()
  call backend%run_trial(columns(1), templates(1), parameters(1), trial_committed, forcing_a(1), config, &
       t0, t1, checkpoint, trial_a, candidate, trial_diag)
  obs_a = backend%observation()
  call require(trial_a%completed, 'stationary mode5 direct trial completed')
  call require(candidate%ready(), 'stationary mode5 candidate ready')
  call require(obs_a%solver_executed, 'stationary mode5 solver executed')
  call require(trim(obs_a%solver_diagnostics%route) == 'legacy-reference-bound', 'stationary mode5 route')
  call require(same_bits(obs_a%bottom_flux, -conductivity0), 'stationary authoritative qbot')
  call require(.not. same_bits(obs_a%bottom_flux, forcing_a(1)%bottom_flux), 'bottom flux seed not authoritative')
  call require(trial_a%mass%complete, 'stationary direct mass complete')
  call require(trial_a%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, 'stationary direct mass mask')
  call require(abs(trial_a%mass%residual) <= hard_mass_gate, 'stationary direct hard mass')
  call require(same_bits(trial_a%mass%total_in, expected_amount), 'stationary direct top input amount')
  call require(same_bits(trial_a%mass%total_out, expected_amount), 'stationary direct qbot output exactly once')
  call require(trial_committed%current_revision() == revision_before, 'trial does not mutate committed revision')
  call require(committed_matches_initial(trial_committed, initial_state), 'trial leaves committed physical state unchanged')

  discard_diag = trial_diag
  call fmr_discard_candidate(discard_executor, candidate, discard_diag)
  call require(.not. candidate%ready(), 'discard invalidates candidate')
  call require(discard_diag%candidate_rollbacks > trial_diag%candidate_rollbacks, 'discard diagnostic recorded')
  call require(trial_committed%current_revision() == revision_before, 'discard leaves revision unchanged')
  call require(committed_matches_initial(trial_committed, initial_state), 'discard leaves committed state unchanged')

  call fmr_capture_checkpoint(trial_committed, checkpoint, ok)
  call require(ok, 'capture B checkpoint')
  call poison_legacy_bottom_context()
  call backend%run_trial(columns(1), templates(1), parameters(1), trial_committed, forcing_b, config, &
       t0, t1, checkpoint, trial_b, candidate, trial_diag)
  obs_b = backend%observation()
  call require(obs_b%solver_executed, 'high-head mode5 solver executed')
  call require(obs_b%bottom_flux > 0.0_real64, 'fixed high prescribed head produces supported positive qbot')
  call require(.not. same_bits(obs_b%bottom_flux, obs_a%bottom_flux), 'bottom head changes authoritative qbot')
  if (candidate%ready()) then
    discard_diag = trial_diag
    call fmr_discard_candidate(discard_executor, candidate, discard_diag)
  end if
  call require(trial_committed%current_revision() == revision_before, 'B trial/discard leaves revision unchanged')
  call require(committed_matches_initial(trial_committed, initial_state), 'B trial/discard leaves committed state unchanged')

  call fmr_capture_checkpoint(trial_committed, checkpoint, ok)
  call require(ok, 'capture replay A checkpoint')
  call poison_legacy_bottom_context()
  call backend%run_trial(columns(1), templates(1), parameters(1), trial_committed, forcing_a(1), config, &
       t0, t1, checkpoint, trial_a2, candidate, trial_diag)
  obs_a2 = backend%observation()
  call require(trial_a2%completed .and. candidate%ready(), 'replay A completed')
  call require(same_bits(obs_a2%bottom_flux, obs_a%bottom_flux), 'A/B/A qbot bitwise replay')
  call require(obs_a2%solver_diagnostics%nonlinear_iterations == obs_a%solver_diagnostics%nonlinear_iterations, &
       'A/B/A solver iteration identity')
  call require(same_bits(trial_a2%mass%total_in, trial_a%mass%total_in) .and. &
       same_bits(trial_a2%mass%total_out, trial_a%mass%total_out) .and. &
       same_bits(trial_a2%mass%residual, trial_a%mass%residual), 'A/B/A mass identity')
  discard_diag = trial_diag
  call fmr_discard_candidate(discard_executor, candidate, discard_diag)
  call require(committed_matches_initial(trial_committed, initial_state), 'A/B/A committed isolation')

  ! Explicitly unowned physical routes stay fail closed at runtime admission.
  do i = 1, size(bad_modes)
    bad_parameters = parameters(1)
    bad_parameters%bottom_mode = bad_modes(i)
    call fmr_capture_checkpoint(trial_committed, checkpoint, ok)
    call require(ok, 'capture unsupported mode checkpoint')
    call backend%run_trial(columns(1), templates(1), bad_parameters, trial_committed, forcing_a(1), config, &
         t0, t1, checkpoint, rejected, candidate, trial_diag)
    call require(.not. rejected%completed, 'unsupported bottom mode rejected')
    call require(trial_diag%admission_rejections > 0, 'unsupported bottom mode admission rejection')
    call require(.not. candidate%ready(), 'unsupported bottom mode no candidate')
  end do

  bad_parameters = parameters(1)
  bad_parameters%swkimpl = 1
  call fmr_capture_checkpoint(trial_committed, checkpoint, ok)
  call require(ok, 'capture swkimpl1 checkpoint')
  call backend%run_trial(columns(1), templates(1), bad_parameters, trial_committed, forcing_a(1), config, &
       t0, t1, checkpoint, rejected, candidate, trial_diag)
  call require(.not. rejected%completed .and. trial_diag%admission_rejections > 0, 'swkimpl1 fail closed')

  bad_parameters = parameters(1)
  bad_parameters%macropore_active = .true.
  call fmr_capture_checkpoint(trial_committed, checkpoint, ok)
  call require(ok, 'capture macropore checkpoint')
  call backend%run_trial(columns(1), templates(1), bad_parameters, trial_committed, forcing_a(1), config, &
       t0, t1, checkpoint, rejected, candidate, trial_diag)
  call require(.not. rejected%completed .and. trial_diag%admission_rejections > 0, 'active macropores fail closed')

  ! ------------------------------------------------------------------
  ! Composed serialized MultiSWAP runtime admission. Two fresh committed
  ! states differ only in the irrelevant bottom_flux seed. Both must commit
  ! exactly the same stationary mode-5 state and authoritative mass.
  ! ------------------------------------------------------------------
  call fmr_new_b110_committed_state(runtime_state_a(1), columns(1)%column_id, initial_state, t0, ok)
  call require(ok, 'runtime A committed init')
  call fmr_new_b110_committed_state(runtime_state_seed2(1), columns(1)%column_id, initial_state, t0, ok)
  call require(ok, 'runtime seed2 committed init')

  call poison_legacy_bottom_context()
  call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcing_a, runtime_state_a, config, &
       top_provider, t0, t1, 1, result_a, diag_a, aggregate_a, dispatch_a, runtime_a)
  call poison_legacy_bottom_context()
  call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcing_seed2, runtime_state_seed2, config, &
       top_provider, t0, t1, 1, result_seed2, diag_seed2, aggregate_seed2, dispatch_seed2, runtime_seed2)

  call require(dispatch_a == FMR_SERIAL_DISPATCH_OK .and. dispatch_seed2 == FMR_SERIAL_DISPATCH_OK, &
       'serialized dispatch')
  call require(result_a(1)%admitted .and. result_seed2(1)%admitted, 'mode5 runtime admitted')
  call require(result_a(1)%completed .and. result_a(1)%committed .and. &
       result_seed2(1)%completed .and. result_seed2(1)%committed, 'mode5 runtime committed')
  call require(result_a(1)%solver_executed .and. result_seed2(1)%solver_executed, 'mode5 runtime solver executed')
  call require(trim(result_a(1)%solver_route) == 'legacy-reference-bound' .and. &
       trim(result_seed2(1)%solver_route) == 'legacy-reference-bound', 'mode5 runtime route')
  call require(result_a(1)%solver_iterations == result_seed2(1)%solver_iterations, 'seed solver iteration identity')
  call require(result_a(1)%mass%complete .and. result_seed2(1)%mass%complete, 'runtime mass complete')
  call require(result_a(1)%mass%missing_contribution_mask == TX_MASS_MISSING_NONE .and. &
       result_seed2(1)%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, 'runtime mass mask')
  call require(abs(result_a(1)%mass%residual) <= hard_mass_gate .and. &
       abs(result_seed2(1)%mass%residual) <= hard_mass_gate, 'runtime hard mass')
  call require(same_bits(result_a(1)%mass%total_in, expected_amount), 'runtime top input amount')
  call require(same_bits(result_a(1)%mass%total_out, expected_amount), 'runtime qbot output exactly once')
  call require(same_bits(result_seed2(1)%mass%total_in, result_a(1)%mass%total_in) .and. &
       same_bits(result_seed2(1)%mass%total_out, result_a(1)%mass%total_out) .and. &
       same_bits(result_seed2(1)%mass%residual, result_a(1)%mass%residual), 'runtime bottom-flux seed mass independence')
  call require(committed_states_identical(runtime_state_a(1), runtime_state_seed2(1)), &
       'runtime bottom-flux seed state independence')
  call require(committed_matches_initial(runtime_state_a(1), initial_state), 'stationary mode5 committed state identity')
  call require(runtime_state_a(1)%current_revision() == 1_int64 .and. &
       runtime_state_seed2(1)%current_revision() == 1_int64, 'single committed revision')
  call require(runtime_a%max_simultaneous_real_physical_solves == 1 .and. &
       runtime_seed2%max_simultaneous_real_physical_solves == 1, 'serialized physical solve bound')
  call require(runtime_a%authoritative_aggregate_mass%complete .and. &
       runtime_a%authoritative_aggregate_mass%missing_contribution_mask == TX_MASS_MISSING_NONE, &
       'aggregate authoritative mass complete')
  call require(same_bits(runtime_a%authoritative_aggregate_mass%total_in, result_a(1)%mass%total_in) .and. &
       same_bits(runtime_a%authoritative_aggregate_mass%total_out, result_a(1)%mass%total_out) .and. &
       same_bits(runtime_a%authoritative_aggregate_mass%residual, result_a(1)%mass%residual), &
       'aggregate authoritative mass exactly once')
  call require(runtime_a%authoritative_aggregate_mass%accepted_transaction_count == 1, &
       'one accepted authoritative transaction')
  call require(diag_a(1)%retries == 0 .and. diag_seed2(1)%retries == 0, &
       'stationary exact temporal acceptance without retries')

  write(*,'(A,Z16.16)') 'FMR11_NEGATIVE_QBOT_BITS=', transfer(obs_a%bottom_flux,0_int64)
  write(*,'(A,Z16.16)') 'FMR11_POSITIVE_QBOT_BITS=', transfer(obs_b%bottom_flux,0_int64)
  write(*,'(A,Z16.16)') 'FMR11_RUNTIME_MASS_IN_BITS=', transfer(result_a(1)%mass%total_in,0_int64)
  write(*,'(A,Z16.16)') 'FMR11_RUNTIME_MASS_OUT_BITS=', transfer(result_a(1)%mass%total_out,0_int64)
  write(*,'(A,I0)') 'FMR11_RUNTIME_SOLVER_ITERATIONS=', result_a(1)%solver_iterations
  write(*,'(A)') 'FMR11_BOTTOM_HEAD_AUTHORITY=PASS'
  write(*,'(A)') 'FMR11_AUTHORITATIVE_QBOT_OBSERVED=PASS'
  write(*,'(A)') 'FMR11_POSITIVE_NEGATIVE_QBOT=PASS'
  write(*,'(A)') 'FMR11_TRIAL_DISCARD_NO_COMMIT=PASS'
  write(*,'(A)') 'FMR11_A_B_A_REPLAY=PASS'
  write(*,'(A)') 'FMR11_UNSUPPORTED_PHYSICAL_ROUTES_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FMR11_EXACT_TEMPORAL_ZERO_TOLERANCE_ACCEPTANCE=PASS'
  write(*,'(A)') 'FMR11_QBOT_MASS_EXACTLY_ONCE=PASS'
  write(*,'(A)') 'FMR11_BOTTOM_FLUX_SEED_INDEPENDENCE=PASS'
  write(*,'(A)') 'FMR11_SERIALIZED_ONLY=PASS'
  write(*,'(A)') 'FMR11_PRESCRIBED_BOTTOM_HEAD_RUNTIME_TEST PASS'

contains

  subroutine configure_column(column, template)
    type(fmr_logical_column_t), intent(out) :: column
    type(fmr_template_t), intent(out) :: template
    template%template_id = 1111_int64
    template%physics_topology_id = 111101_int64
    template%vertical_layout_id = 111102_int64
    template%state_layout_id = 111103_int64
    template%solver_interface_id = 111104_int64
    template%optional_state_layout_id = 111105_int64
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    column%column_id = 1111001_int64
    column%template_id = template%template_id
    column%parameter_ref = 1_int64
    column%state_handle = 1_int64
    column%forcing_handle = 1_int64
    column%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_column

  subroutine configure_physical_parameters(p, state, conductivity0)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: conductivity0
    type(b110_default_mvg_parameters_t), target :: hyd_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: k

    p%parameter_set_id = 111101_int64
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

    call initialize_b110_default_mvg_parameters(hyd_parameters, p%cofgen)
    call bind_b110_default_mvg_provider(constitutive, hyd_parameters, t1-t0)
    heads = head0
    call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
    do k = 2, numnod
      call require(same_bits(conductivity(k),conductivity(1)), 'uniform fixture conductivity')
    end do
    conductivity0 = conductivity(1)
    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
  end subroutine configure_physical_parameters

  subroutine configure_forcing(f, conductivity0, bottom_seed, bottom_head)
    type(fmr_b110_physical_forcing_t), intent(out) :: f
    real(real64), intent(in) :: conductivity0, bottom_seed, bottom_head
    f%top_flux = -conductivity0
    f%top_head = head0
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
    legacy_qdra = 12345.0_real64
    legacy_qssdi = -54321.0_real64
    legacy_qrot = 0.0_real64
    legacy_swbotb = 3
    legacy_hbot = 54321.0_real64
    legacy_qbot = -12345.0_real64
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

  logical function committed_states_identical(a,b)
    type(kernel_committed_state_t), intent(in) :: a,b
    class(transaction_state_t), allocatable :: sa,sb
    logical :: oka,okb
    integer :: k
    committed_states_identical = .false.
    call a%snapshot(sa,oka)
    call b%snapshot(sb,okb)
    if (.not. oka .or. .not. okb) return
    select type (pa => sa)
    type is (fmr_b110_physical_state_t)
      select type (pb => sb)
      type is (fmr_b110_physical_state_t)
        if (pa%active_nodes /= pb%active_nodes) return
        do k = 1, pa%active_nodes
          if (.not. same_bits(pa%pressure_head(k),pb%pressure_head(k))) return
          if (.not. same_bits(pa%water_content(k),pb%water_content(k))) return
        end do
        if (.not. same_bits(pa%ponding_depth,pb%ponding_depth)) return
        if (.not. same_bits(pa%groundwater_level,pb%groundwater_level)) return
        committed_states_identical = .true.
      end select
    end select
  end function committed_states_identical

  logical function same_bits(a,b)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia = transfer(a,ia)
    ib = transfer(b,ib)
    same_bits = ia == ib
  end function same_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FMR11_PRESCRIBED_BOTTOM_HEAD_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fmr11_prescribed_bottom_head_runtime
