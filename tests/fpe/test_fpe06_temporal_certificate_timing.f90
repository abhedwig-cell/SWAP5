program test_fpe06_temporal_certificate_timing
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_result_t, kernel_diagnostics_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE, FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state, fmr_new_b110_temporal_indicator_committed_state
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: t0 = 4200.375_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  integer, parameter :: principal_advances_per_interval = 3
  integer(int64), parameter :: lineage_id = 206101_int64

  character(len=16) :: arm
  character(len=128) :: arg
  real(real64) :: head0, bottom_jump, step_dt, test_budget
  real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
  real(real64) :: static_residual(numnod), hdot_n(numnod)
  real(real64) :: elapsed_seconds, per_trial_seconds
  integer(int64) :: count0, count1, count_rate, count_max
  integer :: repetitions, warmup, i, stat
  logical :: ok, active_arm
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t) :: constitutive
  type(fmr_b110_physical_state_t) :: initial_state
  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_b110_physical_forcing_t) :: forcing
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(fixed_flux_top_boundary_provider_t), target :: top_provider
  type(fmr_serialized_reference_backend_t) :: backend
  type(kernel_committed_state_t) :: committed
  type(kernel_checkpoint_t) :: checkpoint
  type(kernel_candidate_state_t) :: candidate
  type(kernel_result_t) :: result
  type(kernel_diagnostics_t) :: diagnostics
  type(fmr_serialized_physical_observation_t) :: observation
  type(canonical_numerical_config_t) :: config

  if (command_argument_count() /= 7) error stop 'F-PE06 timing requires ARM h0 jump dt budget repetitions warmup'
  call get_command_argument(1,arm)
  arm = adjustl(arm)
  active_arm = trim(arm) == 'B'
  call require(trim(arm) == 'A' .or. active_arm, 'arm A or B')
  call read_real_arg(2, head0)
  call read_real_arg(3, bottom_jump)
  call read_real_arg(4, step_dt)
  call read_real_arg(5, test_budget)
  call read_int_arg(6, repetitions)
  call read_int_arg(7, warmup)
  call require(ieee_is_finite(head0) .and. ieee_is_finite(bottom_jump), 'finite hydraulic case')
  call require(ieee_is_finite(step_dt) .and. step_dt > 0.0_real64, 'positive finite dt')
  call require(ieee_is_finite(test_budget) .and. test_budget > 0.0_real64, 'positive finite test budget')
  call require(repetitions > 0 .and. warmup >= 0, 'valid repetition counts')

  call configure_fixture(head0, bottom_jump, step_dt, column, template, parameters, forcing, initial_state, &
       hydraulic_parameters, constitutive, heads, water, conductivity, capacity, dkdh)

  static_residual = 0.0_real64
  static_residual(numnod) = conductivity(1)*(head0-(head0+bottom_jump))/(0.5_real64*parameters%dz(numnod))
  hdot_n = -static_residual/(capacity*parameters%dz)
  call require(all(ieee_is_finite(hdot_n)), 'finite right-derivative seed')

  if (active_arm) then
    column%template_id = 20612_int64
    template%template_id = column%template_id
    template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    call fmr_new_b110_temporal_indicator_committed_state(committed, lineage_id, initial_state, t0, ok, hdot_n)
  else
    column%template_id = 20611_int64
    template%template_id = column%template_id
    template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    call fmr_new_b110_committed_state(committed, lineage_id, initial_state, t0, ok)
  end if
  call require(ok, 'committed initialization')
  call fmr_capture_checkpoint(committed, checkpoint, ok)
  call require(ok, 'checkpoint')
  call configure_transaction(config, test_budget)
  call backend%initialize(top_provider)

  do i = 1, warmup
    call backend%run_trial(column, template, parameters, committed, forcing, config, t0, t0+step_dt, checkpoint, &
         result, candidate, diagnostics)
    call validate_last_run(active_arm, result, candidate, diagnostics, backend%observation())
  end do

  call system_clock(count0, count_rate, count_max)
  call require(count_rate > 0_int64 .and. count_max > count0, 'usable system_clock')
  do i = 1, repetitions
    call backend%run_trial(column, template, parameters, committed, forcing, config, t0, t0+step_dt, checkpoint, &
         result, candidate, diagnostics)
    if (.not. result%completed) error stop 'F-PE06 timed run did not complete'
  end do
  call system_clock(count1)
  call require(count1 >= count0, 'system_clock did not wrap')
  elapsed_seconds = real(count1-count0,real64)/real(count_rate,real64)
  per_trial_seconds = elapsed_seconds/real(repetitions,real64)
  call require(ieee_is_finite(elapsed_seconds) .and. elapsed_seconds > 0.0_real64, 'positive elapsed time')
  call require(ieee_is_finite(per_trial_seconds) .and. per_trial_seconds > 0.0_real64, 'positive per-trial time')

  observation = backend%observation()
  call validate_last_run(active_arm, result, candidate, diagnostics, observation)

  write(*,'(A,A)') 'FPE06_TIMING_ARM=',trim(arm)
  write(*,'(A,I0)') 'FPE06_TIMING_REPETITIONS=',repetitions
  write(*,'(A,I0)') 'FPE06_TIMING_WARMUP=',warmup
  write(*,'(A,I0)') 'FPE06_TIMING_CLOCK_RATE=',count_rate
  write(*,'(A,ES26.17E3)') 'FPE06_TIMING_SECONDS=',elapsed_seconds
  write(*,'(A,ES26.17E3)') 'FPE06_TIMING_PER_TRIAL_SECONDS=',per_trial_seconds
  write(*,'(A,I0)') 'FPE06_TIMING_HEADCALC=',diagnostics%headcalc_calls
  write(*,'(A,I0)') 'FPE06_TIMING_LINEAR_SOLVES=',diagnostics%linear_solves
  write(*,'(A,ES26.17E3)') 'FPE06_TIMING_MASS_RESIDUAL=',result%mass%residual
  write(*,'(A)') 'FPE06_TIMING_CASE=PASS'

contains

  subroutine validate_last_run(active, res, cand, diag, obs)
    logical, intent(in) :: active
    type(kernel_result_t), intent(in) :: res
    type(kernel_candidate_state_t), intent(in) :: cand
    type(kernel_diagnostics_t), intent(in) :: diag
    type(fmr_serialized_physical_observation_t), intent(in) :: obs
    call require(res%completed, 'timing run completed')
    call require(cand%ready(), 'timing candidate ready')
    call require(diag%attempts == 1 .and. diag%retries == 0 .and. diag%trial_rollbacks == 0, 'one accepted attempt')
    call require(diag%headcalc_calls == principal_advances_per_interval, 'three principal advances')
    call require(diag%mass_rejections == 0, 'no mass rejection')
    call require(abs(res%mass%residual) <= hard_mass_gate, 'hard mass gate')
    if (active) then
      call require(obs%temporal_indicator_enabled, 'B service enabled')
      call require(obs%temporal_indicator_available, 'B indicator available')
      call require(obs%temporal_certificate_available, 'B normalization available')
      call require(obs%temporal_additional_full_nonlinear_solves == 0, 'B zero extra nonlinear per advance')
      call require(obs%temporal_additional_tridiagonal_solves == 1, 'B one defect tridag per advance')
    else
      call require(.not. obs%temporal_indicator_enabled, 'A service disabled')
    end if
  end subroutine validate_last_run

  subroutine read_real_arg(index, value)
    integer, intent(in) :: index
    real(real64), intent(out) :: value
    call get_command_argument(index,arg)
    read(arg,*,iostat=stat) value
    call require(stat == 0, 'real command argument')
  end subroutine read_real_arg

  subroutine read_int_arg(index, value)
    integer, intent(in) :: index
    integer, intent(out) :: value
    call get_command_argument(index,arg)
    read(arg,*,iostat=stat) value
    call require(stat == 0, 'integer command argument')
  end subroutine read_int_arg

  subroutine configure_transaction(c, budget)
    type(canonical_numerical_config_t), intent(out) :: c
    real(real64), intent(in) :: budget
    c%transaction%temporal_tolerance = huge(0.0_real64)
    c%transaction%mass_tolerance = hard_mass_gate
    c%transaction%retry_scale = 0.5_real64
    c%transaction%max_retries = 0
    c%transaction%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
    c%max_committed_substeps = 1
    c%progress_tolerance = 0.0_real64
    c%model_temporal_indicator_budget_available = .true.
    c%model_temporal_indicator_budget = budget
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
    integer :: j

    col%column_id = 206101_int64
    col%template_id = 20611_int64
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
    do j = 1, numnod
      p%cofgen(1,j)=0.032_real64; p%cofgen(2,j)=0.423_real64; p%cofgen(3,j)=4.75_real64
      p%cofgen(4,j)=0.0135_real64; p%cofgen(5,j)=0.365_real64; p%cofgen(6,j)=1.455_real64
      p%cofgen(7,j)=1.0_real64-1.0_real64/p%cofgen(6,j); p%cofgen(8,j)=p%cofgen(4,j)
      p%cofgen(9,j)=0.0_real64; p%cofgen(10,j)=p%cofgen(3,j); p%cofgen(11,j)=0.999_real64
      p%cofgen(12,j)=0.99_real64*p%cofgen(3,j); p%cofgen(22,j)=-1.0e6_real64; p%cofgen(23,j)=1.0e-12_real64
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

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FPE06_TIMING_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fpe06_temporal_certificate_timing
