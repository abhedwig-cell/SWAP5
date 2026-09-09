program test_fkt10_real_richards_history_binding
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF, &
       TX_TEMPORAL_MODEL_CERTIFICATE, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_numerical_config_t, canonical_mass_accounting_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_result_t, kernel_diagnostics_t, kernel_executor_t, KERNEL_STATUS_NOT_ADMITTED
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint, fmr_commit_candidate, fmr_discard_candidate
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE, FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, &
       fmr_b110_temporal_indicator_state_t, fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state, fmr_new_b110_temporal_indicator_committed_state
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_soil_water_solver_contract, only: SW_TEMPORAL_INDICATOR_AVAILABLE
  implicit none

  real(real64), parameter :: t0 = 1000.125_real64
  real(real64), parameter :: t1 = 1000.375_real64
  real(real64), parameter :: t2 = 1000.625_real64
  real(real64), parameter :: t3 = 1000.875_real64
  real(real64), parameter :: head0 = -75.0_real64
  real(real64), parameter :: bottom_jump = 0.01_real64
  integer(int64), parameter :: base_lineage = 101001_int64
  integer(int64), parameter :: history_lineage = 101002_int64

  type(fmr_logical_column_t) :: base_column, history_column
  type(fmr_template_t) :: base_template, history_template, bad_template
  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_b110_physical_forcing_t) :: forcing
  type(fmr_b110_physical_state_t) :: initial_state
  type(fixed_flux_top_boundary_provider_t), target :: top_provider
  type(fmr_serialized_reference_backend_t), target :: base_backend, history_backend
  type(kernel_committed_state_t) :: base_committed, history_committed
  type(kernel_checkpoint_t) :: base_checkpoint, history_checkpoint, checkpoint2, checkpoint3
  type(kernel_candidate_state_t) :: base_candidate, history_candidate, replay_candidate, second_candidate, &
       second_replay_candidate, rejected_candidate
  type(kernel_result_t) :: base_result, history_result, replay_result, second_result, second_replay_result, rejected_result
  type(kernel_diagnostics_t) :: base_diag, history_diag, replay_diag, second_diag, second_replay_diag, rejected_diag
  type(kernel_executor_t) :: transaction_control
  type(fmr_serialized_physical_observation_t) :: history_obs, certificate_obs
  type(canonical_numerical_config_t) :: config, certificate_config
  real(real64), allocatable :: first_trial_history(:), replay_history(:), committed_history(:), &
       second_trial_history(:), second_replay_history(:), committed_history2(:), before_reject_history(:), after_reject_history(:)
  integer(int64) :: base_fp, history_fp, replay_fp, second_fp, second_replay_fp
  integer(int64) :: revision0, revision1, revision2
  real(real64) :: committed_time
  logical :: ok, available, history_available, did_commit
  integer :: commit_status

  call configure_fixture(base_column, history_column, base_template, history_template, parameters, forcing, initial_state)
  call configure_transaction(config)
  call base_backend%initialize(top_provider)
  call history_backend%initialize(top_provider)

  call fmr_new_b110_committed_state(base_committed, base_lineage, initial_state, t0, ok)
  call require(ok, 'base committed initialization')
  call fmr_new_b110_temporal_indicator_committed_state(history_committed, history_lineage, initial_state, t0, ok)
  call require(ok, 'history committed initialization')
  revision0 = history_committed%current_revision()
  call require(revision0 == 0_int64, 'initial history revision')
  call get_committed_history(history_committed, committed_history, history_available)
  call require(.not. history_available, 'initial derivative history absent')

  call fmr_capture_checkpoint(base_committed, base_checkpoint, ok)
  call require(ok .and. base_checkpoint%ready(), 'base checkpoint')
  call fmr_capture_checkpoint(history_committed, history_checkpoint, ok)
  call require(ok .and. history_checkpoint%ready(), 'history checkpoint')

  call base_backend%run_trial(base_column, base_template, parameters, base_committed, forcing, config, &
       t0, t1, base_checkpoint, base_result, base_candidate, base_diag)
  call require(base_result%completed .and. base_candidate%ready(), 'baseline real Richards trial')
  call require(base_result%mass%complete .and. base_result%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, &
       'baseline authoritative mass complete')
  call require(abs(base_result%mass%residual) <= 1.0e-12_real64, 'baseline hard mass')

  call history_backend%run_trial(history_column, history_template, parameters, history_committed, forcing, config, &
       t0, t1, history_checkpoint, history_result, history_candidate, history_diag)
  call require(history_result%completed .and. history_candidate%ready(), 'history real Richards trial')
  call require(history_result%mass%complete .and. history_result%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, &
       'history authoritative mass complete')
  call require(abs(history_result%mass%residual) <= 1.0e-12_real64, 'history hard mass')

  base_fp = candidate_physical_fingerprint(base_candidate)
  history_fp = candidate_physical_fingerprint(history_candidate)
  call require(base_fp == history_fp, 'indicator does not change accepted physical candidate')
  call require(same_mass(base_result%mass, history_result%mass), 'indicator does not change authoritative mass')
  call require(base_diag%headcalc_calls == history_diag%headcalc_calls, 'indicator adds no HeadCalc trajectories')
  call require(base_diag%nonlinear_iterations == history_diag%nonlinear_iterations, 'indicator adds no nonlinear iterations')
  call require(base_diag%jacobian_builds == history_diag%jacobian_builds, 'indicator adds no Jacobian builds')
  call require(history_diag%linear_solves == base_diag%linear_solves + 1, 'first outer interval adds exactly one defect TRIDAG')

  history_obs = history_backend%observation()
  call require(history_obs%temporal_indicator_enabled, 'history service enabled')
  call require(history_obs%temporal_previous_derivative_available, 'accepted half-two sees private half-one history')
  call require(history_obs%temporal_current_derivative_available, 'current derivative materialized')
  call require(history_obs%temporal_indicator_status == SW_TEMPORAL_INDICATOR_AVAILABLE, 'indicator status available')
  call require(history_obs%temporal_indicator_available, 'indicator result available')
  call require(history_obs%temporal_additional_tridiagonal_solves == 1, 'one bounded defect solve')
  call require(history_obs%temporal_additional_full_nonlinear_solves == 0, 'zero indicator nonlinear trajectories')
  call require(ieee_is_finite(history_obs%temporal_head_inf_bound) .and. history_obs%temporal_head_inf_bound >= 0.0_real64, &
       'finite nonnegative B_inf')

  call get_candidate_history(history_candidate, first_trial_history, history_available)
  call require(history_available, 'trial candidate carries derivative history')
  call get_committed_history(history_committed, committed_history, history_available)
  call require(.not. history_available, 'uncommitted trial history not published')

  call fmr_discard_candidate(transaction_control, history_candidate, history_diag)
  call require(.not. history_candidate%ready(), 'history candidate rollback')
  call get_committed_history(history_committed, committed_history, history_available)
  call require(.not. history_available, 'rollback leaves committed history absent')
  call require(history_committed%current_revision() == revision0, 'rollback leaves revision unchanged')

  call history_backend%run_trial(history_column, history_template, parameters, history_committed, forcing, config, &
       t0, t1, history_checkpoint, replay_result, replay_candidate, replay_diag)
  call require(replay_result%completed .and. replay_candidate%ready(), 'replay trial materialized')
  replay_fp = candidate_physical_fingerprint(replay_candidate)
  call require(replay_fp == history_fp, 'rollback replay physical identity')
  call require(same_mass(replay_result%mass, history_result%mass), 'rollback replay mass identity')
  call get_candidate_history(replay_candidate, replay_history, history_available)
  call require(history_available, 'replay history available')
  call require(same_vector_bits(first_trial_history, replay_history), 'rollback replay derivative-history identity')

  call fmr_commit_candidate(transaction_control, history_committed, replay_candidate, replay_diag, did_commit, commit_status)
  call require(did_commit, 'first history candidate committed')
  revision1 = history_committed%current_revision()
  call require(revision1 == revision0 + 1_int64, 'first commit revision')
  call history_committed%current_time(committed_time, available)
  call require(available .and. same_real_bits(committed_time, t1), 'first commit time')
  call get_committed_history(history_committed, committed_history, history_available)
  call require(history_available, 'first committed derivative history available')
  call require(same_vector_bits(committed_history, replay_history), 'first committed history equals accepted candidate')

  call fmr_capture_checkpoint(history_committed, checkpoint2, ok)
  call require(ok .and. checkpoint2%origin_revision() == revision1, 'second checkpoint')
  call history_backend%run_trial(history_column, history_template, parameters, history_committed, forcing, config, &
       t1, t2, checkpoint2, second_result, second_candidate, second_diag)
  call require(second_result%completed .and. second_candidate%ready(), 'second real Richards trial')
  call require(second_result%mass%complete .and. abs(second_result%mass%residual) <= 1.0e-12_real64, 'second hard mass')
  history_obs = history_backend%observation()
  call require(history_obs%temporal_previous_derivative_available, 'second interval reads committed history')
  call require(history_obs%temporal_indicator_available, 'second interval B_inf available')
  call require(history_obs%temporal_additional_tridiagonal_solves == 1, 'second interval last solve one defect TRIDAG')
  call require(history_obs%temporal_additional_full_nonlinear_solves == 0, 'second interval no indicator nonlinear solve')
  call get_candidate_history(second_candidate, second_trial_history, history_available)
  call require(history_available, 'second candidate history')

  call fmr_discard_candidate(transaction_control, second_candidate, second_diag)
  call require(.not. second_candidate%ready(), 'second trial rollback')
  call get_committed_history(history_committed, committed_history2, history_available)
  call require(history_available .and. same_vector_bits(committed_history2, committed_history), &
       'second rollback preserves first committed history')
  call require(history_committed%current_revision() == revision1, 'second rollback revision unchanged')

  call history_backend%run_trial(history_column, history_template, parameters, history_committed, forcing, config, &
       t1, t2, checkpoint2, second_replay_result, second_replay_candidate, second_replay_diag)
  call require(second_replay_result%completed .and. second_replay_candidate%ready(), 'second replay materialized')
  second_fp = candidate_physical_fingerprint(second_replay_candidate)
  second_replay_fp = second_fp
  call get_candidate_history(second_replay_candidate, second_replay_history, history_available)
  call require(history_available .and. same_vector_bits(second_replay_history, second_trial_history), &
       'second replay derivative identity')
  call require(same_mass(second_replay_result%mass, second_result%mass), 'second replay mass identity')
  call fmr_commit_candidate(transaction_control, history_committed, second_replay_candidate, second_replay_diag, did_commit, commit_status)
  call require(did_commit, 'second history candidate committed')
  revision2 = history_committed%current_revision()
  call require(revision2 == revision1 + 1_int64, 'second commit revision')
  call get_committed_history(history_committed, committed_history2, history_available)
  call require(history_available .and. same_vector_bits(committed_history2, second_replay_history), &
       'second committed history equals accepted candidate')

  call fmr_capture_checkpoint(history_committed, checkpoint3, ok)
  call require(ok .and. checkpoint3%origin_revision() == revision2, 'certificate checkpoint')
  before_reject_history = committed_history2
  certificate_config = config
  certificate_config%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
  certificate_config%transaction%max_retries = 0
  call history_backend%run_trial(history_column, history_template, parameters, history_committed, forcing, certificate_config, &
       t2, t3, checkpoint3, rejected_result, rejected_candidate, rejected_diag)
  call require(.not. rejected_result%completed .and. .not. rejected_candidate%ready(), &
       'F-KT09 certificate path fails closed')
  call require(rejected_diag%temporal_certificate_unavailable_rejections == 1, &
       'certificate unavailable diagnosed once')
  certificate_obs = history_backend%observation()
  call require(certificate_obs%temporal_previous_derivative_available .and. certificate_obs%temporal_indicator_available, &
       'B_inf was available during certificate rejection')
  call require(certificate_obs%temporal_additional_tridiagonal_solves == 1 .and. &
       certificate_obs%temporal_additional_full_nonlinear_solves == 0, 'certificate rejection bounded indicator cost')
  call get_committed_history(history_committed, after_reject_history, history_available)
  call require(history_available .and. same_vector_bits(after_reject_history, before_reject_history), &
       'certificate rejection does not publish trial history')
  call require(history_committed%current_revision() == revision2, 'certificate rejection revision unchanged')

  bad_template = history_template
  bad_template%numerical_continuation_layout_id = 999_int64
  call history_backend%run_trial(history_column, bad_template, parameters, history_committed, forcing, config, &
       t2, t3, checkpoint3, rejected_result, rejected_candidate, rejected_diag)
  call require(rejected_result%status == KERNEL_STATUS_NOT_ADMITTED .and. .not. rejected_candidate%ready(), &
       'unknown numerical continuation layout fails closed')
  call require(rejected_diag%admission_rejections == 1, 'unknown layout rejection diagnosed')
  call get_committed_history(history_committed, after_reject_history, history_available)
  call require(history_available .and. same_vector_bits(after_reject_history, before_reject_history), &
       'unknown layout rejection preserves committed history')

  write(*,'(A,I0)') 'FKT10_REAL_BASE_HEADCALC_CALLS=', base_diag%headcalc_calls
  write(*,'(A,I0)') 'FKT10_REAL_HISTORY_HEADCALC_CALLS=', history_diag%headcalc_calls
  write(*,'(A,I0)') 'FKT10_REAL_BASE_LINEAR_SOLVES=', base_diag%linear_solves
  write(*,'(A,I0)') 'FKT10_REAL_HISTORY_LINEAR_SOLVES=', history_diag%linear_solves
  write(*,'(A,ES26.17E3)') 'FKT10_REAL_FIRST_BINF=', history_obs%temporal_head_inf_bound
  write(*,'(A,I0)') 'FKT10_REAL_SECOND_PHYSICAL_FP=', second_replay_fp
  write(*,'(A)') 'FKT10_GATE_D_REAL_RICHARDS_HISTORY_BINDING=PASS'
  write(*,'(A)') 'FKT10_GATE_E_PHYSICS_MASS_AND_COST_NONINTERFERENCE=PASS'
  write(*,'(A)') 'FKT10_GATE_F_REAL_TRANSACTION_HISTORY_ROLLBACK_COMMIT=PASS'
  write(*,'(A)') 'FKT10_GATE_E_FKT09_CERTIFICATE_NONPROMOTION=PASS'
  write(*,'(A)') 'FKT10_REAL_RICHARDS_HISTORY_BINDING_TEST PASS'

contains

  subroutine configure_fixture(base_col, hist_col, base_tpl, hist_tpl, p, f, state)
    type(fmr_logical_column_t), intent(out) :: base_col, hist_col
    type(fmr_template_t), intent(out) :: base_tpl, hist_tpl
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    type(fmr_b110_physical_forcing_t), intent(out) :: f
    type(fmr_b110_physical_state_t), intent(out) :: state
    type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: i

    base_col%column_id = 101001_int64
    base_col%template_id = 10101_int64
    base_col%parameter_ref = 1_int64
    base_col%state_handle = 1_int64
    base_col%forcing_handle = 1_int64
    base_col%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    hist_col = base_col
    hist_col%column_id = 101002_int64
    hist_col%template_id = 10102_int64
    hist_col%state_handle = 2_int64

    base_tpl%template_id = base_col%template_id
    base_tpl%physics_topology_id = 101_int64
    base_tpl%vertical_layout_id = 102_int64
    base_tpl%state_layout_id = 103_int64
    base_tpl%solver_interface_id = 104_int64
    base_tpl%optional_state_layout_id = 0_int64
    base_tpl%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    base_tpl%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    hist_tpl = base_tpl
    hist_tpl%template_id = hist_col%template_id
    hist_tpl%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY

    p%parameter_set_id = 101001_int64
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod), p%cofgen(24,numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)
    p%cofgen = 0.0_real64
    do i = 1, numnod
      p%cofgen(1,i) = 0.032_real64
      p%cofgen(2,i) = 0.423_real64
      p%cofgen(3,i) = 4.75_real64
      p%cofgen(4,i) = 0.0135_real64
      p%cofgen(5,i) = 0.365_real64
      p%cofgen(6,i) = 1.455_real64
      p%cofgen(7,i) = 1.0_real64 - 1.0_real64/p%cofgen(6,i)
      p%cofgen(8,i) = p%cofgen(4,i)
      p%cofgen(9,i) = 0.0_real64
      p%cofgen(10,i) = p%cofgen(3,i)
      p%cofgen(11,i) = 0.999_real64
      p%cofgen(12,i) = 0.99_real64*p%cofgen(3,i)
      p%cofgen(22,i) = -1.0e6_real64
      p%cofgen(23,i) = 1.0e-12_real64
    end do
    p%bottom_mode = 5
    p%swkimpl = 0
    p%swkmean = 1
    p%swsophy = 0
    p%max_iterations = 8
    p%max_backtracking = 4
    p%min_step_duration = 1.0e-6_real64
    p%compartment_balance_tolerance = 1.0e-12_real64
    p%total_balance_tolerance = 1.0e-12_real64
    p%head_abs_tolerance = 1.0e-12_real64
    p%head_rel_tolerance = 1.0e-12_real64
    p%ponding_tolerance = 1.0e-12_real64
    p%root_extraction_active = .false.
    p%macropore_active = .false.
    p%snow_active = .false.
    p%hysteresis_active = .false.
    p%tabulated_hydraulics_active = .false.
    p%elasticity_active = .false.
    p%frost_active = .false.

    call initialize_b110_default_mvg_parameters(hydraulic_parameters, p%cofgen)
    call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, t1-t0)
    heads = head0
    call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
    call require(all(ieee_is_finite(capacity)) .and. all(capacity > 0.0_real64), 'fixture capacity')
    call require(all(ieee_is_finite(conductivity)) .and. all(conductivity > 0.0_real64), 'fixture conductivity')
    do i = 2, numnod
      call require(same_real_bits(conductivity(i), conductivity(1)), 'uniform initial conductivity')
    end do

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64

    f%top_flux = -conductivity(1)
    f%top_head = head0
    f%bottom_flux = 12345.678_real64
    f%bottom_head = head0 + bottom_jump
    allocate(f%drainage_flux_by_level(1,numnod), f%subsurface_irrigation_source(numnod), f%root_extraction_sink(numnod))
    f%drainage_flux_by_level = 0.0_real64
    f%subsurface_irrigation_source = 0.0_real64
    f%root_extraction_sink = 0.0_real64
  end subroutine configure_fixture

  subroutine configure_transaction(c)
    type(canonical_numerical_config_t), intent(out) :: c
    c%transaction%temporal_tolerance = 1.0e30_real64
    c%transaction%mass_tolerance = 1.0e-12_real64
    c%transaction%retry_scale = 0.5_real64
    c%transaction%max_retries = 0
    c%transaction%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
    c%max_committed_substeps = 4
    c%progress_tolerance = 0.0_real64
  end subroutine configure_transaction

  subroutine get_committed_history(committed, derivative, available_out)
    type(kernel_committed_state_t), intent(in) :: committed
    real(real64), allocatable, intent(out) :: derivative(:)
    logical, intent(out) :: available_out
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    call committed%snapshot(snapshot, got)
    call require(got, 'committed history snapshot')
    select type (s => snapshot)
    type is (fmr_b110_temporal_indicator_state_t)
      call s%temporal_history_snapshot(derivative, available_out)
    class default
      call require(.false., 'committed history dynamic type')
    end select
  end subroutine get_committed_history

  subroutine get_candidate_history(candidate, derivative, available_out)
    type(kernel_candidate_state_t), intent(in) :: candidate
    real(real64), allocatable, intent(out) :: derivative(:)
    logical, intent(out) :: available_out
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    call candidate%snapshot(snapshot, got)
    call require(got, 'candidate history snapshot')
    select type (s => snapshot)
    type is (fmr_b110_temporal_indicator_state_t)
      call s%temporal_history_snapshot(derivative, available_out)
    class default
      call require(.false., 'candidate history dynamic type')
    end select
  end subroutine get_candidate_history

  integer(int64) function candidate_physical_fingerprint(candidate) result(fp)
    type(kernel_candidate_state_t), intent(in) :: candidate
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    call candidate%snapshot(snapshot, got)
    call require(got, 'candidate physical fingerprint snapshot')
    fp = physical_fingerprint(snapshot)
  end function candidate_physical_fingerprint

  integer(int64) function physical_fingerprint(snapshot) result(fp)
    class(transaction_state_t), intent(in) :: snapshot
    integer :: i
    fp = 1469598103934665603_int64
    select type (s => snapshot)
    class is (fmr_b110_physical_state_t)
      fp = ieor(fp, int(s%active_nodes,int64))
      do i = 1, s%active_nodes
        fp = ieor(fp, transfer(s%pressure_head(i),fp))
        fp = ieor(fp, transfer(s%water_content(i),fp))
      end do
      fp = ieor(fp, transfer(s%ponding_depth,fp))
      fp = ieor(fp, transfer(s%groundwater_level,fp))
    class default
      call require(.false., 'physical fingerprint dynamic type')
    end select
  end function physical_fingerprint

  logical function same_mass(a,b) result(same)
    type(canonical_mass_accounting_t), intent(in) :: a,b
    same = a%complete .eqv. b%complete
    same = same .and. a%accepted_transaction_count == b%accepted_transaction_count
    same = same .and. a%missing_contribution_mask == b%missing_contribution_mask
    same = same .and. same_real_bits(a%storage_start,b%storage_start)
    same = same .and. same_real_bits(a%storage_end,b%storage_end)
    same = same .and. same_real_bits(a%storage_change,b%storage_change)
    same = same .and. same_real_bits(a%total_in,b%total_in)
    same = same .and. same_real_bits(a%total_out,b%total_out)
    same = same .and. same_real_bits(a%residual,b%residual)
  end function same_mass

  logical function same_vector_bits(a,b) result(same)
    real(real64), intent(in) :: a(:),b(:)
    integer :: i
    same = size(a) == size(b)
    if (.not. same) return
    do i = 1, size(a)
      if (.not. same_real_bits(a(i),b(i))) then
        same = .false.
        return
      end if
    end do
  end function same_vector_bits

  logical function same_real_bits(a,b) result(same)
    real(real64), intent(in) :: a,b
    same = transfer(a,0_int64) == transfer(b,0_int64)
  end function same_real_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FKT10_REAL_RICHARDS_HISTORY_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fkt10_real_richards_history_binding
