program test_fpe06_temporal_certificate_cost
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_NONE
  use mod_canonical_contracts, only: canonical_numerical_config_t, canonical_mass_accounting_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_result_t, kernel_diagnostics_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE, FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_temporal_indicator_state_t, &
       fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, &
       fmr_serialized_physical_observation_t, fmr_new_b110_committed_state, &
       fmr_new_b110_temporal_indicator_committed_state
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: t0 = 4100.375_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  integer(int64), parameter :: lineage_id = 206001_int64

  character(len=128) :: arg
  real(real64) :: head0, bottom_jump, step_dt, preflight_binf, test_budget
  real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
  real(real64) :: static_residual(numnod), hdot_n(numnod)
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t) :: constitutive
  type(fmr_b110_physical_state_t) :: initial_state
  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_b110_physical_forcing_t) :: forcing
  type(fmr_logical_column_t) :: column_a, column_b
  type(fmr_template_t) :: template_a, template_b
  type(fixed_flux_top_boundary_provider_t), target :: top_provider
  type(fmr_serialized_reference_backend_t) :: backend_preflight, backend_a, backend_b
  type(kernel_committed_state_t) :: committed_preflight, committed_a, committed_b
  type(kernel_checkpoint_t) :: checkpoint_preflight, checkpoint_a, checkpoint_b
  type(kernel_candidate_state_t) :: candidate_preflight, candidate_a, candidate_b
  type(kernel_result_t) :: result_preflight, result_a, result_b
  type(kernel_diagnostics_t) :: diagnostics_preflight, diagnostics_a, diagnostics_b
  type(fmr_serialized_physical_observation_t) :: observation_preflight, observation_a, observation_b
  type(canonical_numerical_config_t) :: config_preflight, config
  class(transaction_state_t), allocatable :: snapshot_a, snapshot_b
  integer :: stat
  logical :: ok, available_a, available_b

  if (command_argument_count() /= 3) error stop 'F-PE06 requires h0 jump dt'
  call read_real_arg(1, head0)
  call read_real_arg(2, bottom_jump)
  call read_real_arg(3, step_dt)
  call require(ieee_is_finite(head0) .and. ieee_is_finite(bottom_jump), 'finite hydraulic case')
  call require(ieee_is_finite(step_dt) .and. step_dt > 0.0_real64, 'positive finite dt')

  call configure_fixture(head0, bottom_jump, step_dt, column_a, template_a, parameters, forcing, initial_state, &
       hydraulic_parameters, constitutive, heads, water, conductivity, capacity, dkdh)
  column_b = column_a
  template_b = template_a
  column_a%template_id = 20601_int64
  template_a%template_id = column_a%template_id
  template_a%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
  column_b%template_id = 20602_int64
  template_b%template_id = column_b%template_id
  template_b%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY

  static_residual = 0.0_real64
  static_residual(numnod) = conductivity(1)*(head0-(head0+bottom_jump))/(0.5_real64*parameters%dz(numnod))
  hdot_n = -static_residual/(capacity*parameters%dz)
  call require(all(ieee_is_finite(hdot_n)), 'finite right-derivative seed')

  ! Untimed preflight obtains the same B_inf quantity whose direct/runtime equivalence
  ! was independently qualified by F-VQ34.  The resulting 2*B_inf budget is only the
  ! frozen VALID_ACCEPT test-oracle construction; PE06 does not select application policy.
  call configure_transaction(config_preflight)
  config_preflight%model_temporal_indicator_budget_available = .false.
  config_preflight%model_temporal_indicator_budget = 0.0_real64
  call fmr_new_b110_temporal_indicator_committed_state(committed_preflight, lineage_id, initial_state, t0, ok, hdot_n)
  call require(ok, 'preflight temporal committed initialization')
  call fmr_capture_checkpoint(committed_preflight, checkpoint_preflight, ok)
  call require(ok, 'preflight checkpoint')
  call backend_preflight%initialize(top_provider)
  call backend_preflight%run_trial(column_b, template_b, parameters, committed_preflight, forcing, config_preflight, &
       t0, t0+step_dt, checkpoint_preflight, result_preflight, candidate_preflight, diagnostics_preflight)
  observation_preflight = backend_preflight%observation()
  call require(result_preflight%completed .and. candidate_preflight%ready(), 'preflight TX_TEMPORAL_NONE completes')
  call require(observation_preflight%temporal_indicator_enabled, 'preflight temporal service enabled')
  call require(observation_preflight%temporal_indicator_available, 'preflight raw indicator available')
  call require(observation_preflight%temporal_additional_full_nonlinear_solves == 0, 'preflight zero extra nonlinear')
  call require(observation_preflight%temporal_additional_tridiagonal_solves == 1, 'preflight one defect tridag')
  preflight_binf = observation_preflight%temporal_head_inf_bound
  call require(ieee_is_finite(preflight_binf) .and. preflight_binf > 0.0_real64, 'positive finite preflight B_inf')
  test_budget = 2.0_real64*preflight_binf
  call require(ieee_is_finite(test_budget) .and. test_budget > 0.0_real64, 'positive finite test-oracle budget')

  call configure_transaction(config)
  config%model_temporal_indicator_budget_available = .true.
  config%model_temporal_indicator_budget = test_budget

  call fmr_new_b110_committed_state(committed_a, lineage_id, initial_state, t0, ok)
  call require(ok, 'A committed initialization')
  call fmr_new_b110_temporal_indicator_committed_state(committed_b, lineage_id, initial_state, t0, ok, hdot_n)
  call require(ok, 'B committed initialization')
  call fmr_capture_checkpoint(committed_a, checkpoint_a, ok)
  call require(ok, 'A checkpoint')
  call fmr_capture_checkpoint(committed_b, checkpoint_b, ok)
  call require(ok, 'B checkpoint')

  call backend_a%initialize(top_provider)
  call backend_b%initialize(top_provider)
  call backend_a%run_trial(column_a, template_a, parameters, committed_a, forcing, config, t0, t0+step_dt, &
       checkpoint_a, result_a, candidate_a, diagnostics_a)
  observation_a = backend_a%observation()
  call backend_b%run_trial(column_b, template_b, parameters, committed_b, forcing, config, t0, t0+step_dt, &
       checkpoint_b, result_b, candidate_b, diagnostics_b)
  observation_b = backend_b%observation()

  call require(result_a%completed .and. candidate_a%ready(), 'A completes')
  call require(result_b%completed .and. candidate_b%ready(), 'B completes')
  call require(.not. observation_a%temporal_indicator_enabled, 'A temporal service disabled')
  call require(observation_b%temporal_indicator_enabled, 'B temporal service enabled')
  call require(observation_b%temporal_previous_derivative_available, 'B seeded history available')
  call require(observation_b%temporal_indicator_available, 'B raw indicator available')
  call require(observation_b%temporal_certificate_available, 'B normalized certificate available')
  call require(close_to(observation_b%temporal_normalized_indicator, 0.5_real64), 'B uses frozen C_h=0.5 test oracle')
  call require(observation_b%temporal_additional_full_nonlinear_solves == 0, 'B zero extra nonlinear trajectories')
  call require(observation_b%temporal_additional_tridiagonal_solves == 1, 'B one defect tridag')

  call require(diagnostics_a%attempts == diagnostics_b%attempts .and. diagnostics_a%attempts == 1, 'same one attempt')
  call require(diagnostics_a%retries == diagnostics_b%retries .and. diagnostics_a%retries == 0, 'same zero retries')
  call require(diagnostics_a%trial_rollbacks == diagnostics_b%trial_rollbacks .and. diagnostics_a%trial_rollbacks == 0, &
       'same zero rollbacks')
  call require(diagnostics_a%headcalc_calls == diagnostics_b%headcalc_calls .and. diagnostics_a%headcalc_calls == 1, &
       'same one principal Richards trajectory')
  call require(diagnostics_a%nonlinear_iterations == diagnostics_b%nonlinear_iterations, 'same nonlinear iterations')
  call require(diagnostics_a%internal_retries == diagnostics_b%internal_retries, 'same internal retries')
  call require(diagnostics_a%jacobian_builds == diagnostics_b%jacobian_builds, 'same principal jacobian builds')
  call require(diagnostics_a%backtracking_attempts == diagnostics_b%backtracking_attempts, 'same backtracking')
  call require(diagnostics_a%alternative_solver_calls == diagnostics_b%alternative_solver_calls, 'same alternative solver calls')
  call require(same_solver_diagnostics(observation_a, observation_b), 'principal solver diagnostics exact')
  call require(diagnostics_b%linear_solves == diagnostics_a%linear_solves + 1, 'total linear solve delta exactly one')

  call candidate_a%snapshot(snapshot_a, available_a)
  call candidate_b%snapshot(snapshot_b, available_b)
  call require(available_a .and. available_b, 'candidate snapshots available')
  call require(same_physical_state(snapshot_a, snapshot_b), 'candidate physical state bitwise identical')
  call require(same_mass(result_a%mass, result_b%mass), 'strict mass result bitwise identical')
  call require(same_real_bits(diagnostics_a%max_abs_step_mass_residual, diagnostics_b%max_abs_step_mass_residual), &
       'max step mass residual bitwise identical')
  call require(diagnostics_a%mass_rejections == diagnostics_b%mass_rejections, 'mass rejection count identical')

  select type (state_a => snapshot_a)
  type is (fmr_b110_physical_state_t)
    continue
  class default
    call require(.false., 'A carrier has no temporal continuation subtype')
  end select
  select type (state_b => snapshot_b)
  type is (fmr_b110_temporal_indicator_state_t)
    call require(state_b%temporal_history_available(), 'B candidate carries updated derivative history')
  class default
    call require(.false., 'B carrier is temporal continuation subtype')
  end select

  write(*,'(A,ES26.17E3)') 'FPE06_PREFLIGHT_BINF=', preflight_binf
  write(*,'(A,ES26.17E3)') 'FPE06_TEST_ORACLE_BUDGET=', test_budget
  write(*,'(A,I0)') 'FPE06_A_HEADCALC=', diagnostics_a%headcalc_calls
  write(*,'(A,I0)') 'FPE06_B_HEADCALC=', diagnostics_b%headcalc_calls
  write(*,'(A,I0)') 'FPE06_A_LINEAR_SOLVES=', diagnostics_a%linear_solves
  write(*,'(A,I0)') 'FPE06_B_LINEAR_SOLVES=', diagnostics_b%linear_solves
  write(*,'(A,I0)') 'FPE06_B_EXTRA_TRIDAG=', observation_b%temporal_additional_tridiagonal_solves
  write(*,'(A,I0)') 'FPE06_B_EXTRA_NONLINEAR=', observation_b%temporal_additional_full_nonlinear_solves
  write(*,'(A,ES26.17E3)') 'FPE06_MASS_RESIDUAL=', result_b%mass%residual
  write(*,'(A)') 'FPE06_PRETIMING_EQUIVALENCE=PASS'

contains

  subroutine read_real_arg(index, value)
    integer, intent(in) :: index
    real(real64), intent(out) :: value
    call get_command_argument(index, arg)
    read(arg,*,iostat=stat) value
    call require(stat == 0, 'numeric command argument')
  end subroutine read_real_arg

  subroutine configure_transaction(c)
    type(canonical_numerical_config_t), intent(out) :: c
    c%transaction%temporal_tolerance = 0.0_real64
    c%transaction%mass_tolerance = hard_mass_gate
    c%transaction%retry_scale = 0.5_real64
    c%transaction%max_retries = 0
    c%transaction%temporal_mode = TX_TEMPORAL_NONE
    c%max_committed_substeps = 1
    c%progress_tolerance = 0.0_real64
    c%model_temporal_indicator_budget_available = .false.
    c%model_temporal_indicator_budget = 0.0_real64
  end subroutine configure_transaction

  subroutine configure_fixture(h0, jump, dt, col, tpl, p, f, state, hp, cp, h, theta, kval, cap, dk)
    real(real64), intent(in) :: h0, jump, dt
    type(fmr_logical_column_t), intent(out) :: col
    type(fmr_template_t), intent(out) :: tpl
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    type(fmr_b110_physical_forcing_t), intent(out) :: f
    type(fmr_b110_physical_state_t), intent(out) :: state
    type(b110_default_mvg_parameters_t), target, intent(out) :: hp
    type(b110_default_mvg_provider_t), intent(out) :: cp
    real(real64), intent(out) :: h(numnod), theta(numnod), kval(numnod), cap(numnod), dk(numnod)
    integer :: i

    col%column_id = 206001_int64
    col%template_id = 20601_int64
    col%parameter_ref = 1_int64
    col%state_handle = 1_int64
    col%forcing_handle = 1_int64
    col%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    tpl%template_id = col%template_id
    tpl%physics_topology_id = 20601_int64
    tpl%vertical_layout_id = 20602_int64
    tpl%state_layout_id = 20603_int64
    tpl%solver_interface_id = 20604_int64
    tpl%optional_state_layout_id = 0_int64
    tpl%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    tpl%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    p%parameter_set_id = 206001_int64
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod), p%cofgen(24,numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)
    p%cofgen = 0.0_real64
    do i = 1, numnod
      p%cofgen(1,i)=0.032_real64; p%cofgen(2,i)=0.423_real64; p%cofgen(3,i)=4.75_real64
      p%cofgen(4,i)=0.0135_real64; p%cofgen(5,i)=0.365_real64; p%cofgen(6,i)=1.455_real64
      p%cofgen(7,i)=1.0_real64-1.0_real64/p%cofgen(6,i); p%cofgen(8,i)=p%cofgen(4,i)
      p%cofgen(9,i)=0.0_real64; p%cofgen(10,i)=p%cofgen(3,i); p%cofgen(11,i)=0.999_real64
      p%cofgen(12,i)=0.99_real64*p%cofgen(3,i); p%cofgen(22,i)=-1.0e6_real64; p%cofgen(23,i)=1.0e-12_real64
    end do
    p%bottom_mode = 5
    p%swkimpl = 0
    p%swkmean = 1
    p%swsophy = 0
    p%max_iterations = 8
    p%max_backtracking = 4
    p%min_step_duration = 1.0e-6_real64
    p%compartment_balance_tolerance = hard_mass_gate
    p%total_balance_tolerance = hard_mass_gate
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

    call initialize_b110_default_mvg_parameters(hp, p%cofgen)
    call bind_b110_default_mvg_provider(cp, hp, dt)
    h = h0
    call cp%evaluate(h, theta, kval, cap, dk)
    call require(all(ieee_is_finite(cap)) .and. all(cap > 0.0_real64), 'positive finite capacity')
    call require(all(ieee_is_finite(kval)) .and. all(kval > 0.0_real64), 'positive finite conductivity')

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = h
    state%water_content = theta
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64

    f%top_flux = -kval(1)
    f%top_head = h0
    f%bottom_flux = 12345.678_real64
    f%bottom_head = h0+jump
    allocate(f%drainage_flux_by_level(1,numnod), f%subsurface_irrigation_source(numnod), f%root_extraction_sink(numnod))
    f%drainage_flux_by_level = 0.0_real64
    f%subsurface_irrigation_source = 0.0_real64
    f%root_extraction_sink = 0.0_real64
  end subroutine configure_fixture

  logical function same_solver_diagnostics(a, b) result(same)
    type(fmr_serialized_physical_observation_t), intent(in) :: a, b
    same = a%solver_status == b%solver_status .and. &
         a%solver_diagnostics%nonlinear_iterations == b%solver_diagnostics%nonlinear_iterations .and. &
         a%solver_diagnostics%jacobian_builds == b%solver_diagnostics%jacobian_builds .and. &
         a%solver_diagnostics%linear_solves == b%solver_diagnostics%linear_solves .and. &
         a%solver_diagnostics%backtracking_attempts == b%solver_diagnostics%backtracking_attempts .and. &
         a%solver_diagnostics%alternative_solver_calls == b%solver_diagnostics%alternative_solver_calls .and. &
         a%solver_diagnostics%internal_retries == b%solver_diagnostics%internal_retries .and. &
         trim(a%solver_diagnostics%route) == trim(b%solver_diagnostics%route)
  end function same_solver_diagnostics

  logical function same_physical_state(a, b) result(same)
    class(transaction_state_t), intent(in) :: a, b
    same = .false.
    select type (aa => a)
    class is (fmr_b110_physical_state_t)
      select type (bb => b)
      class is (fmr_b110_physical_state_t)
        same = aa%active_nodes == bb%active_nodes
        if (.not. same) return
        same = allocated(aa%pressure_head) .and. allocated(bb%pressure_head) .and. &
             allocated(aa%water_content) .and. allocated(bb%water_content)
        if (.not. same) return
        same = size(aa%pressure_head) == size(bb%pressure_head) .and. &
             size(aa%water_content) == size(bb%water_content)
        if (.not. same) return
        same = same_vector_bits(aa%pressure_head, bb%pressure_head) .and. &
             same_vector_bits(aa%water_content, bb%water_content) .and. &
             same_real_bits(aa%ponding_depth, bb%ponding_depth) .and. &
             same_real_bits(aa%groundwater_level, bb%groundwater_level)
      end select
    end select
  end function same_physical_state

  logical function same_mass(a, b) result(same)
    type(canonical_mass_accounting_t), intent(in) :: a, b
    same = (a%complete .eqv. b%complete) .and. &
         same_real_bits(a%interval_t0,b%interval_t0) .and. same_real_bits(a%interval_t1,b%interval_t1) .and. &
         a%origin_lineage_id == b%origin_lineage_id .and. a%origin_revision == b%origin_revision .and. &
         a%accepted_transaction_count == b%accepted_transaction_count .and. &
         a%missing_contribution_mask == b%missing_contribution_mask .and. &
         same_real_bits(a%storage_start,b%storage_start) .and. same_real_bits(a%storage_end,b%storage_end) .and. &
         same_real_bits(a%storage_change,b%storage_change) .and. same_real_bits(a%total_in,b%total_in) .and. &
         same_real_bits(a%total_out,b%total_out) .and. same_real_bits(a%residual,b%residual)
  end function same_mass

  logical function close_to(a,b) result(same)
    real(real64), intent(in) :: a,b
    same = ieee_is_finite(a) .and. ieee_is_finite(b) .and. &
         abs(a-b) <= 65536.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(a),abs(b))
  end function close_to

  logical function same_vector_bits(a,b) result(same)
    real(real64), intent(in) :: a(:),b(:)
    integer :: i
    same = size(a) == size(b)
    if (.not. same) return
    do i=1,size(a)
      if (.not. same_real_bits(a(i),b(i))) then
        same=.false.
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
      write(*,'(A,1X,A)') 'FPE06_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fpe06_temporal_certificate_cost
