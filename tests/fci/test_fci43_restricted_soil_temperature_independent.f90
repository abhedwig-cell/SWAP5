program test_fvq58_restricted_soil_temperature_independent
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_restricted_soil_temperature, only: &
       SOIL_TEMP_OK, SOIL_TEMP_INVALID_INTERVAL, SOIL_TEMP_INVALID_HYDRAULIC_VIEW, &
       soil_temperature_parameters_t, soil_temperature_numerical_config_t, soil_temperature_forcing_t, &
       soil_temperature_state_t, soil_temperature_restart_payload_t, soil_temperature_field_view_t, &
       soil_temperature_workspace_t, soil_temperature_result_t, soil_temperature_diagnostics_t, &
       initialize_soil_temperature_parameters, initialize_soil_temperature_state, &
       trial_restricted_soil_temperature, commit_soil_temperature_state, build_soil_temperature_field_view, &
       copy_soil_temperature_profile, soil_temperature_at_node, export_soil_temperature_restart, &
       reconstruct_soil_temperature_restart
  implicit none

  integer, parameter :: n = 5
  real(real64), parameter :: dz(n) = [2.0_real64, 5.0_real64, 8.0_real64, 12.0_real64, 20.0_real64]
  real(real64), parameter :: dist(n) = [1.0_real64, 3.5_real64, 6.5_real64, 10.0_real64, 16.0_real64]
  real(real64), parameter :: theta_sat(n) = [0.42_real64, 0.45_real64, 0.50_real64, 0.38_real64, 0.55_real64]
  real(real64), parameter :: fq(n) = [0.48_real64, 0.35_real64, 0.20_real64, 0.45_real64, 0.10_real64]
  real(real64), parameter :: fc(n) = [0.08_real64, 0.15_real64, 0.25_real64, 0.14_real64, 0.23_real64]
  real(real64), parameter :: fo(n) = [0.02_real64, 0.05_real64, 0.05_real64, 0.03_real64, 0.12_real64]
  type(soil_temperature_parameters_t) :: parameters
  type(soil_temperature_numerical_config_t) :: numerical
  integer :: status

  call initialize_soil_temperature_parameters(dz, dist, theta_sat, fq, fc, fo, parameters, status)
  call check(status == SOIL_TEMP_OK .and. parameters%ready(), 'parameter initialization')
  numerical%energy_abs_tolerance_j_cm2 = 1.0e-9_real64

  call test_dense_scientific_oracle(parameters, numerical)
  call test_zero_gradient_and_flux_sign(parameters, numerical)
  call test_temporal_refinement(parameters, numerical)
  call test_transaction_restart_and_views(parameters, numerical)
  call test_fail_closed(parameters, numerical)
  call test_multiswap_isolation(parameters, numerical)
  print '(a)', 'FVQ58_INDEPENDENT_ORACLE=PASS'

contains

  subroutine test_dense_scientific_oracle(params, num)
    type(soil_temperature_parameters_t), intent(in) :: params
    type(soil_temperature_numerical_config_t), intent(in) :: num
    real(real64) :: theta0(n), theta1(n), old_temperature(n), surface_temperature, dt
    integer :: case_id

    old_temperature = [12.0_real64, 11.0_real64, 10.0_real64, 9.0_real64, 8.0_real64]
    do case_id = 1, 6
      select case (case_id)
      case (1)
        theta0 = 0.01_real64; theta1 = 0.01_real64; surface_temperature = 20.0_real64; dt = 0.03_real64
      case (2)
        theta0 = 0.02_real64; theta1 = 0.02_real64; surface_temperature = 5.0_real64; dt = 0.11_real64
      case (3)
        theta0 = 0.035_real64; theta1 = 0.035_real64; surface_temperature = 18.0_real64; dt = 0.20_real64
      case (4)
        theta0 = 0.05_real64; theta1 = 0.05_real64; surface_temperature = 3.0_real64; dt = 0.37_real64
      case (5)
        theta0 = 0.25_real64; theta1 = 0.25_real64; surface_temperature = 25.0_real64; dt = 0.80_real64
      case (6)
        theta0 = [0.010_real64, 0.018_real64, 0.030_real64, 0.060_real64, 0.200_real64]
        theta1 = [0.015_real64, 0.022_real64, 0.040_real64, 0.100_real64, 0.300_real64]
        surface_temperature = -2.0_real64; dt = 0.15_real64
      end select
      call compare_candidate_to_dense_oracle(params, num, theta0, theta1, old_temperature, surface_temperature, dt)
    end do
    print '(a)', 'FVQ58_DENSE_ORACLE_CASES=6'
    print '(a)', 'FVQ58_LEGACY_DEVRIES_DENSE_ORACLE=PASS'
  end subroutine test_dense_scientific_oracle

  subroutine compare_candidate_to_dense_oracle(params, num, theta0, theta1, old_temperature, surface_temperature, dt)
    type(soil_temperature_parameters_t), intent(in) :: params
    type(soil_temperature_numerical_config_t), intent(in) :: num
    real(real64), intent(in) :: theta0(n), theta1(n), old_temperature(n), surface_temperature, dt
    type(process_hydraulic_view_t) :: hydraulic_start, hydraulic_end
    type(soil_temperature_state_t) :: committed, trial
    type(soil_temperature_workspace_t) :: workspace
    type(soil_temperature_forcing_t) :: forcing
    type(soil_temperature_result_t) :: result
    type(soil_temperature_diagnostics_t) :: diagnostics
    real(real64), allocatable :: candidate_profile(:)
    real(real64) :: oracle_profile(n), oracle_flux, oracle_storage, oracle_boundary, oracle_residual
    integer :: s

    call make_hydraulic_view(theta0, hydraulic_start)
    call make_hydraulic_view(theta1, hydraulic_end)
    call initialize_soil_temperature_state(old_temperature, committed, s)
    call check(s == SOIL_TEMP_OK, 'oracle case state init')
    forcing%prescribed_surface_temperature_c = surface_temperature
    call trial_restricted_soil_temperature(params, num, forcing, hydraulic_start, hydraulic_end, committed, &
         7.125_real64, 7.125_real64 + dt, workspace, trial, result, diagnostics)
    call check(result%status == SOIL_TEMP_OK .and. result%produced, 'oracle case candidate trial')
    call copy_soil_temperature_profile(trial, candidate_profile, s)
    call check(s == SOIL_TEMP_OK, 'oracle case candidate profile')
    call independent_heat_step(theta0, theta1, old_temperature, surface_temperature, dt, &
         oracle_profile, oracle_flux, oracle_storage, oracle_boundary, oracle_residual)

    call check(maxval(abs(candidate_profile-oracle_profile)) < 5.0e-10_real64, 'dense profile oracle')
    call check(abs(result%top_heat_flux_into_soil_j_cm2_day-oracle_flux) < 5.0e-10_real64, 'dense flux oracle')
    call check(abs(result%sensible_storage_change_j_cm2-oracle_storage) < 5.0e-9_real64, 'dense storage oracle')
    call check(abs(result%boundary_energy_into_soil_j_cm2-oracle_boundary) < 5.0e-9_real64, 'dense boundary energy oracle')
    call check(abs(result%energy_residual_j_cm2-oracle_residual) < 5.0e-9_real64, 'dense residual oracle')
    call check(abs(oracle_residual) < 1.0e-9_real64, 'independent energy closure')
    call check(diagnostics%energy_accounting_complete, 'candidate energy accounting complete')
    call check(diagnostics%zero_bottom_heat_flux_used, 'candidate zero bottom marker')
    call check(diagnostics%prescribed_surface_temperature_used, 'candidate top boundary marker')
  end subroutine compare_candidate_to_dense_oracle

  subroutine test_zero_gradient_and_flux_sign(params, num)
    type(soil_temperature_parameters_t), intent(in) :: params
    type(soil_temperature_numerical_config_t), intent(in) :: num
    type(process_hydraulic_view_t) :: h0, h1
    type(soil_temperature_state_t) :: committed, trial
    type(soil_temperature_workspace_t) :: workspace
    type(soil_temperature_forcing_t) :: forcing
    type(soil_temperature_result_t) :: result
    type(soil_temperature_diagnostics_t) :: diagnostics
    real(real64), allocatable :: profile(:)
    real(real64) :: theta_uniform(n), old_uniform(n), oracle_profile(n)
    real(real64) :: heat_capacity(n), conductivity(n), oracle_flux, oracle_storage, oracle_boundary, oracle_residual
    real(real64) :: roundoff_flux_bound, flux_scale
    integer :: s

    theta_uniform = 0.20_real64
    old_uniform = 10.0_real64
    call make_hydraulic_view(theta_uniform, h0)
    call make_hydraulic_view(theta_uniform, h1)
    call initialize_soil_temperature_state(old_uniform, committed, s)
    forcing%prescribed_surface_temperature_c = 10.0_real64
    call trial_restricted_soil_temperature(params, num, forcing, h0, h1, committed, 0.0_real64, 0.4_real64, &
         workspace, trial, result, diagnostics)
    call check(result%status == SOIL_TEMP_OK, 'zero gradient trial')
    call copy_soil_temperature_profile(trial, profile, s)
    call check(s == SOIL_TEMP_OK, 'zero gradient profile copy')
    call independent_heat_step(theta_uniform, theta_uniform, old_uniform, 10.0_real64, 0.4_real64, &
         oracle_profile, oracle_flux, oracle_storage, oracle_boundary, oracle_residual)
    call independent_devries(theta_uniform, heat_capacity, conductivity)
    flux_scale = maxval(conductivity)*maxval(abs(old_uniform))/minval(dist)
    roundoff_flux_bound = 512.0_real64*epsilon(1.0_real64)*max(1.0_real64, flux_scale)
    call check(maxval(abs(profile-oracle_profile)) < 5.0e-10_real64, 'zero gradient independent profile oracle')
    call check(maxval(abs(profile-old_uniform)) < 1.0e-12_real64, 'zero gradient profile identity')
    call check(abs(result%top_heat_flux_into_soil_j_cm2_day-oracle_flux) < roundoff_flux_bound, 'zero gradient flux oracle')
    call check(abs(result%top_heat_flux_into_soil_j_cm2_day) < roundoff_flux_bound, 'zero gradient candidate roundoff bound')
    call check(abs(oracle_flux) < roundoff_flux_bound, 'zero gradient dense roundoff bound')
    call check(abs(oracle_storage) < 1.0e-9_real64 .and. abs(oracle_boundary) < 1.0e-9_real64 .and. &
         abs(oracle_residual) < 1.0e-9_real64, 'zero gradient energy identity')

    call initialize_soil_temperature_state(old_uniform, committed, s)
    forcing%prescribed_surface_temperature_c = 30.0_real64
    call trial_restricted_soil_temperature(params, num, forcing, h0, h1, committed, 1.0_real64, 1.2_real64, &
         workspace, trial, result, diagnostics)
    call check(result%status == SOIL_TEMP_OK .and. result%top_heat_flux_into_soil_j_cm2_day > 0.0_real64, 'hot surface flux sign')

    call initialize_soil_temperature_state(old_uniform, committed, s)
    forcing%prescribed_surface_temperature_c = -5.0_real64
    call trial_restricted_soil_temperature(params, num, forcing, h0, h1, committed, 2.0_real64, 2.2_real64, &
         workspace, trial, result, diagnostics)
    call check(result%status == SOIL_TEMP_OK .and. result%top_heat_flux_into_soil_j_cm2_day < 0.0_real64, 'cold surface flux sign')
    print '(a)', 'FVQ58_ZERO_GRADIENT_IDENTITY=PASS'
    print '(a)', 'FVQ58_BOUNDARY_SIGN_AND_ZERO_BOTTOM=PASS'
    print '(a)', 'FVQ58_SENSIBLE_ENERGY_CLOSURE=PASS'
  end subroutine test_zero_gradient_and_flux_sign

  subroutine test_temporal_refinement(params, num)
    type(soil_temperature_parameters_t), intent(in) :: params
    type(soil_temperature_numerical_config_t), intent(in) :: num
    real(real64), allocatable :: p1(:), p2(:), p4(:), p8(:)
    real(real64) :: e12, e24, e48
    call integrate_candidate(params, num, 1, 1.6_real64, 24.0_real64, p1)
    call integrate_candidate(params, num, 2, 1.6_real64, 24.0_real64, p2)
    call integrate_candidate(params, num, 4, 1.6_real64, 24.0_real64, p4)
    call integrate_candidate(params, num, 8, 1.6_real64, 24.0_real64, p8)
    e12 = maxval(abs(p1-p2)); e24 = maxval(abs(p2-p4)); e48 = maxval(abs(p4-p8))
    call check(e12 > 0.0_real64, 'temporal refinement nontrivial')
    call check(e24 < e12 .and. e48 < e24, 'temporal refinement monotone')
    print '(a)', 'FVQ58_TEMPORAL_REFINEMENT=PASS'
  end subroutine test_temporal_refinement

  subroutine integrate_candidate(params, num, steps, horizon, surface_temperature, profile)
    type(soil_temperature_parameters_t), intent(in) :: params
    type(soil_temperature_numerical_config_t), intent(in) :: num
    integer, intent(in) :: steps
    real(real64), intent(in) :: horizon, surface_temperature
    real(real64), allocatable, intent(out) :: profile(:)
    type(process_hydraulic_view_t) :: h0, h1
    type(soil_temperature_state_t) :: state
    type(soil_temperature_workspace_t) :: workspace
    type(soil_temperature_forcing_t) :: forcing
    real(real64) :: step_dt
    integer :: k, s
    call make_hydraulic_view([0.18_real64,0.22_real64,0.27_real64,0.16_real64,0.31_real64], h0)
    call make_hydraulic_view([0.18_real64,0.22_real64,0.27_real64,0.16_real64,0.31_real64], h1)
    call initialize_soil_temperature_state([8.0_real64,9.0_real64,10.0_real64,11.0_real64,12.0_real64], state, s)
    call check(s == SOIL_TEMP_OK, 'temporal init')
    forcing%prescribed_surface_temperature_c = surface_temperature
    step_dt = horizon/real(steps, real64)
    do k = 1, steps
      call advance_and_commit(params, num, forcing, h0, h1, state, real(k-1,real64)*step_dt, real(k,real64)*step_dt, workspace)
    end do
    call copy_soil_temperature_profile(state, profile, s)
    call check(s == SOIL_TEMP_OK, 'temporal final profile')
  end subroutine integrate_candidate

  subroutine test_transaction_restart_and_views(params, num)
    type(soil_temperature_parameters_t), intent(in) :: params
    type(soil_temperature_numerical_config_t), intent(in) :: num
    type(process_hydraulic_view_t) :: h0, h1
    type(soil_temperature_state_t) :: continuous, split, restored, trial
    type(soil_temperature_workspace_t) :: wc, ws
    type(soil_temperature_restart_payload_t) :: payload
    type(soil_temperature_forcing_t) :: forcing
    type(soil_temperature_result_t) :: result
    type(soil_temperature_diagnostics_t) :: diagnostics
    type(soil_temperature_field_view_t) :: view
    class(transaction_state_t), allocatable :: cloned
    real(real64), allocatable :: pc(:), ps(:), before(:), after(:), clone_profile(:)
    real(real64) :: node_temperature
    integer :: s, k

    call make_hydraulic_view([0.12_real64,0.18_real64,0.24_real64,0.15_real64,0.28_real64], h0)
    call make_hydraulic_view([0.14_real64,0.20_real64,0.25_real64,0.17_real64,0.30_real64], h1)
    call initialize_soil_temperature_state([7.0_real64,8.0_real64,9.0_real64,10.0_real64,11.0_real64], continuous, s)
    call initialize_soil_temperature_state([7.0_real64,8.0_real64,9.0_real64,10.0_real64,11.0_real64], split, s)
    forcing%prescribed_surface_temperature_c = 16.0_real64
    do k = 1, 4
      call advance_and_commit(params, num, forcing, h0, h1, continuous, real(k-1,real64)*0.2_real64, real(k,real64)*0.2_real64, wc)
    end do
    do k = 1, 2
      call advance_and_commit(params, num, forcing, h0, h1, split, real(k-1,real64)*0.2_real64, real(k,real64)*0.2_real64, ws)
    end do
    call export_soil_temperature_restart(split, payload, s)
    call check(s == SOIL_TEMP_OK .and. payload%schema_version == 1, 'restart export')
    call check(allocated(payload%temperature_c) .and. size(payload%temperature_c) == n, 'minimal restart payload')
    call reconstruct_soil_temperature_restart(payload, restored, s)
    call check(s == SOIL_TEMP_OK, 'restart reconstruct')
    do k = 3, 4
      call advance_and_commit(params, num, forcing, h0, h1, restored, real(k-1,real64)*0.2_real64, real(k,real64)*0.2_real64, ws)
    end do
    call copy_soil_temperature_profile(continuous, pc, s)
    call copy_soil_temperature_profile(restored, ps, s)
    call check(maxval(abs(pc-ps)) < 1.0e-15_real64, 'continuous split restart identity')

    call copy_soil_temperature_profile(restored, before, s)
    forcing%prescribed_surface_temperature_c = 27.0_real64
    call trial_restricted_soil_temperature(params, num, forcing, h0, h1, restored, 10.0_real64, 10.3_real64, &
         ws, trial, result, diagnostics)
    call check(result%status == SOIL_TEMP_OK .and. result%produced, 'discardable trial')
    call copy_soil_temperature_profile(restored, after, s)
    call check(maxval(abs(before-after)) < 1.0e-15_real64, 'trial immutability')
    call check(.not. diagnostics%committed_state_mutated, 'immutability diagnostic')

    call restored%clone(cloned)
    select type (cloned_state => cloned)
    type is (soil_temperature_state_t)
      call copy_soil_temperature_profile(cloned_state, clone_profile, s)
      call check(s == SOIL_TEMP_OK .and. maxval(abs(clone_profile-before)) < 1.0e-15_real64, 'transaction clone')
    class default
      call check(.false., 'transaction clone type')
    end select
    call build_soil_temperature_field_view(restored, view, s)
    call check(s == SOIL_TEMP_OK .and. view%active_nodes == n, 'semantic field view')
    call check(maxval(abs(view%temperature_c-before)) < 1.0e-15_real64, 'semantic field view values')
    call soil_temperature_at_node(restored, 4, node_temperature, s)
    call check(s == SOIL_TEMP_OK .and. abs(node_temperature-before(4)) < 1.0e-15_real64, 'semantic node query')
    print '(a)', 'FVQ58_TRANSACTION_IMMUTABILITY=PASS'
    print '(a)', 'FVQ58_CONTINUOUS_SPLIT_RESTART_IDENTITY=PASS'
    print '(a)', 'FVQ58_MINIMAL_RESTART_AND_SEMANTIC_VIEW=PASS'
  end subroutine test_transaction_restart_and_views

  subroutine test_fail_closed(params, num)
    type(soil_temperature_parameters_t), intent(in) :: params
    type(soil_temperature_numerical_config_t), intent(in) :: num
    type(process_hydraulic_view_t) :: h0, h1, bad
    type(soil_temperature_state_t) :: committed, trial
    type(soil_temperature_workspace_t) :: workspace
    type(soil_temperature_forcing_t) :: forcing
    type(soil_temperature_result_t) :: result
    type(soil_temperature_diagnostics_t) :: diagnostics
    integer :: s
    call make_hydraulic_view([0.15_real64,0.18_real64,0.20_real64,0.16_real64,0.25_real64], h0)
    call make_hydraulic_view([0.16_real64,0.19_real64,0.21_real64,0.17_real64,0.26_real64], h1)
    call initialize_soil_temperature_state([10.0_real64,10.0_real64,10.0_real64,10.0_real64,10.0_real64], committed, s)
    forcing%prescribed_surface_temperature_c = 12.0_real64
    call trial_restricted_soil_temperature(params, num, forcing, h0, h1, committed, 3.0_real64, 3.0_real64, &
         workspace, trial, result, diagnostics)
    call check(result%status == SOIL_TEMP_INVALID_INTERVAL .and. .not. result%produced, 'invalid interval fail closed')
    bad = h1
    bad%water_content(3) = theta_sat(3) + 0.01_real64
    call trial_restricted_soil_temperature(params, num, forcing, h0, bad, committed, 3.0_real64, 3.2_real64, &
         workspace, trial, result, diagnostics)
    call check(result%status == SOIL_TEMP_INVALID_HYDRAULIC_VIEW .and. .not. result%produced, 'invalid hydraulic fail closed')
    print '(a)', 'FVQ58_FAIL_CLOSED_INVALID_INPUTS=PASS'
  end subroutine test_fail_closed

  subroutine test_multiswap_isolation(params, num)
    type(soil_temperature_parameters_t), intent(in) :: params
    type(soil_temperature_numerical_config_t), intent(in) :: num
    type(process_hydraulic_view_t) :: h0, h1
    type(soil_temperature_state_t) :: interleaved(4), reference(4)
    type(soil_temperature_workspace_t) :: shared_workspace, reference_workspace(4)
    type(soil_temperature_forcing_t) :: forcing(4)
    real(real64), allocatable :: pi(:), pr(:)
    real(real64) :: initial_value(4), surface_value(4)
    integer :: i, k, s
    call make_hydraulic_view([0.10_real64,0.14_real64,0.18_real64,0.12_real64,0.22_real64], h0)
    call make_hydraulic_view([0.11_real64,0.15_real64,0.19_real64,0.13_real64,0.23_real64], h1)
    initial_value = [4.0_real64, 8.0_real64, 12.0_real64, 16.0_real64]
    surface_value = [-2.0_real64, 6.0_real64, 18.0_real64, 30.0_real64]
    do i = 1, 4
      call initialize_soil_temperature_state([initial_value(i),initial_value(i),initial_value(i),initial_value(i),initial_value(i)], interleaved(i), s)
      call check(s == SOIL_TEMP_OK, 'multiswap interleaved init')
      call initialize_soil_temperature_state([initial_value(i),initial_value(i),initial_value(i),initial_value(i),initial_value(i)], reference(i), s)
      call check(s == SOIL_TEMP_OK, 'multiswap reference init')
      forcing(i)%prescribed_surface_temperature_c = surface_value(i)
    end do
    do k = 1, 5
      do i = 1, 4
        call advance_and_commit(params, num, forcing(i), h0, h1, interleaved(i), real(k-1,real64)*0.07_real64, &
             real(k,real64)*0.07_real64, shared_workspace)
      end do
    end do
    do i = 1, 4
      do k = 1, 5
        call advance_and_commit(params, num, forcing(i), h0, h1, reference(i), real(k-1,real64)*0.07_real64, &
             real(k,real64)*0.07_real64, reference_workspace(i))
      end do
      call copy_soil_temperature_profile(interleaved(i), pi, s); call check(s == SOIL_TEMP_OK, 'multiswap interleaved profile')
      call copy_soil_temperature_profile(reference(i), pr, s); call check(s == SOIL_TEMP_OK, 'multiswap reference profile')
      call check(maxval(abs(pi-pr)) < 1.0e-15_real64, 'multiswap interleaving isolation')
      deallocate(pi, pr)
    end do
    print '(a)', 'FVQ58_MULTISWAP_COLUMN_ISOLATION=PASS'
  end subroutine test_multiswap_isolation

  subroutine advance_and_commit(params, num, forcing, h0, h1, state, t0, t1, workspace)
    type(soil_temperature_parameters_t), intent(in) :: params
    type(soil_temperature_numerical_config_t), intent(in) :: num
    type(soil_temperature_forcing_t), intent(in) :: forcing
    type(process_hydraulic_view_t), intent(in) :: h0, h1
    type(soil_temperature_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(soil_temperature_workspace_t), intent(inout) :: workspace
    type(soil_temperature_state_t) :: trial
    type(soil_temperature_result_t) :: result
    type(soil_temperature_diagnostics_t) :: diagnostics
    integer :: s
    call trial_restricted_soil_temperature(params, num, forcing, h0, h1, state, t0, t1, workspace, trial, result, diagnostics)
    call check(result%status == SOIL_TEMP_OK .and. result%produced, 'advance trial')
    call check(.not. diagnostics%committed_state_mutated, 'advance committed immutable')
    call commit_soil_temperature_state(state, trial, s)
    call check(s == SOIL_TEMP_OK, 'advance commit')
  end subroutine advance_and_commit

  subroutine make_hydraulic_view(theta, view)
    real(real64), intent(in) :: theta(n)
    type(process_hydraulic_view_t), intent(out) :: view
    view%active_nodes = n
    allocate(view%water_content(n))
    view%water_content = theta
  end subroutine make_hydraulic_view

  subroutine independent_heat_step(theta_start, theta_end, old_temperature, surface_temperature, dt, &
       new_temperature, top_flux, storage_change, boundary_energy, residual)
    real(real64), intent(in) :: theta_start(n), theta_end(n), old_temperature(n), surface_temperature, dt
    real(real64), intent(out) :: new_temperature(n), top_flux, storage_change, boundary_energy, residual
    real(real64) :: theta(n), heat_capacity(n), conductivity(n), face(n), matrix(n,n), rhs(n)
    real(real64) :: lower_coefficient, upper_coefficient
    integer :: i
    theta = 0.5_real64*(theta_start+theta_end)
    call independent_devries(theta, heat_capacity, conductivity)
    face(1) = conductivity(1)
    do i = 2, n
      face(i) = 0.5_real64*(conductivity(i-1)+conductivity(i))
    end do
    matrix = 0.0_real64; rhs = 0.0_real64
    lower_coefficient = -dt*face(1)/(dz(1)*dist(1))
    upper_coefficient = -dt*face(2)/(dz(1)*dist(2))
    matrix(1,1) = heat_capacity(1)-lower_coefficient-upper_coefficient
    matrix(1,2) = upper_coefficient
    rhs(1) = heat_capacity(1)*old_temperature(1)-lower_coefficient*surface_temperature
    do i = 2, n-1
      lower_coefficient = -dt*face(i)/(dz(i)*dist(i))
      upper_coefficient = -dt*face(i+1)/(dz(i)*dist(i+1))
      matrix(i,i-1) = lower_coefficient
      matrix(i,i) = heat_capacity(i)-lower_coefficient-upper_coefficient
      matrix(i,i+1) = upper_coefficient
      rhs(i) = heat_capacity(i)*old_temperature(i)
    end do
    lower_coefficient = -dt*face(n)/(dz(n)*dist(n))
    matrix(n,n-1) = lower_coefficient
    matrix(n,n) = heat_capacity(n)-lower_coefficient
    rhs(n) = heat_capacity(n)*old_temperature(n)
    call dense_solve(matrix, rhs, new_temperature)
    storage_change = sum(heat_capacity*dz*(new_temperature-old_temperature))
    top_flux = face(1)*(surface_temperature-new_temperature(1))/dist(1)
    boundary_energy = dt*top_flux
    residual = storage_change-boundary_energy
  end subroutine independent_heat_step

  subroutine independent_devries(theta, heat_capacity, conductivity)
    real(real64), intent(in) :: theta(n)
    real(real64), intent(out) :: heat_capacity(n), conductivity(n)
    real(real64), parameter :: c_quartz=800.0_real64, c_clay=900.0_real64, c_water=4180.0_real64
    real(real64), parameter :: c_air=1010.0_real64, c_organic=1920.0_real64
    real(real64), parameter :: rho_quartz=2660.0_real64, rho_clay=2650.0_real64, rho_water=1000.0_real64
    real(real64), parameter :: rho_air=1.2_real64, rho_organic=1300.0_real64
    real(real64), parameter :: k_quartz=8.8_real64, k_clay=2.92_real64, k_water=0.57_real64
    real(real64), parameter :: k_air=0.025_real64, k_organic=0.25_real64
    real(real64), parameter :: g_quartz=0.14_real64, g_clay=0.125_real64, g_water=0.14_real64, g_organic=0.5_real64
    real(real64), parameter :: theta_dry=0.02_real64, theta_wet=0.05_real64
    real(real64) :: k_qw, k_cw, k_ow, k_wa, k_qa, k_ca, k_oa
    real(real64) :: fkk_dry, fk_dry, fkk_wet, fk_wet
    real(real64) :: f_air, g_air, g_air_dry, k_aw, numerator, denominator, k_dry, k_wet
    integer :: i
    k_qw = weighting(k_quartz, k_water, g_quartz)
    k_cw = weighting(k_clay, k_water, g_clay)
    k_ow = weighting(k_organic, k_water, g_organic)
    k_wa = weighting(k_water, k_air, g_water)
    k_qa = weighting(k_quartz, k_air, g_quartz)
    k_ca = weighting(k_clay, k_air, g_clay)
    k_oa = weighting(k_organic, k_air, g_organic)
    do i = 1, n
      f_air = max(0.0_real64, theta_sat(i)-theta(i))
      heat_capacity(i) = (fq(i)*rho_quartz*c_quartz + fc(i)*rho_clay*c_clay + fo(i)*rho_organic*c_organic + &
           theta(i)*rho_water*c_water + f_air*rho_air*c_air)*1.0e-6_real64
      if (theta(i) > theta_dry) then
        g_air = 0.333_real64-f_air/theta_sat(i)*0.298_real64
      else
        g_air_dry = 0.333_real64-f_air/theta_sat(i)*0.298_real64
        g_air = 0.013_real64+theta(i)/theta_dry*(g_air_dry-0.013_real64)
      end if
      k_aw = weighting(k_air, k_water, g_air)
      fkk_dry = fq(i)*(k_qa*k_quartz)+fc(i)*(k_ca*k_clay)+fo(i)*(k_oa*k_organic)
      fk_dry = fq(i)*k_qa+fc(i)*k_ca+fo(i)*k_oa
      fkk_wet = fq(i)*(k_qw*k_quartz)+fc(i)*(k_cw*k_clay)+fo(i)*(k_ow*k_organic)
      fk_wet = fq(i)*k_qw+fc(i)*k_cw+fo(i)*k_ow
      if (theta(i) <= theta_dry) then
        numerator = fkk_dry+f_air*k_air+theta(i)*(k_wa*k_water)
        denominator = fk_dry+f_air+theta(i)*k_wa
        conductivity(i) = numerator/denominator*1.25_real64*864.0_real64
      else if (theta(i) >= theta_wet) then
        numerator = fkk_wet+f_air*k_aw*k_air+theta(i)*k_water
        denominator = fk_wet+f_air*k_aw+theta(i)
        conductivity(i) = numerator/denominator*864.0_real64
      else
        numerator = fkk_dry+f_air*k_air+theta_dry*(k_wa*k_water)
        denominator = fk_dry+f_air+theta_dry*k_wa
        k_dry = numerator/denominator*1.25_real64
        numerator = fkk_wet+f_air*k_aw*k_air+theta_wet*k_water
        denominator = fk_wet+f_air*k_aw+theta_wet
        k_wet = numerator/denominator
        conductivity(i) = (k_dry+(theta(i)-theta_dry)*(k_wet-k_dry)/(theta_wet-theta_dry))*864.0_real64
      end if
    end do
  end subroutine independent_devries

  real(real64) function weighting(k_component, k_medium, shape_factor) result(value)
    real(real64), intent(in) :: k_component, k_medium, shape_factor
    real(real64) :: ratio
    ratio = k_component/k_medium
    value = 0.66_real64/(1.0_real64+(ratio-1.0_real64)*shape_factor) + &
            0.33_real64/(1.0_real64+(ratio-1.0_real64)*(1.0_real64-2.0_real64*shape_factor))
  end function weighting

  subroutine dense_solve(a_input, b_input, x)
    real(real64), intent(in) :: a_input(n,n), b_input(n)
    real(real64), intent(out) :: x(n)
    real(real64) :: a(n,n), b(n), row_tmp(n), scalar_tmp, factor
    integer :: i, j, k, pivot
    a = a_input; b = b_input
    do k = 1, n-1
      pivot = k
      do i = k+1, n
        if (abs(a(i,k)) > abs(a(pivot,k))) pivot = i
      end do
      call check(abs(a(pivot,k)) > 1.0e-20_real64, 'dense pivot')
      if (pivot /= k) then
        row_tmp = a(k,:); a(k,:) = a(pivot,:); a(pivot,:) = row_tmp
        scalar_tmp = b(k); b(k) = b(pivot); b(pivot) = scalar_tmp
      end if
      do i = k+1, n
        factor = a(i,k)/a(k,k); a(i,k) = 0.0_real64
        do j = k+1, n
          a(i,j) = a(i,j)-factor*a(k,j)
        end do
        b(i) = b(i)-factor*b(k)
      end do
    end do
    call check(abs(a(n,n)) > 1.0e-20_real64, 'dense final pivot')
    x(n) = b(n)/a(n,n)
    do i = n-1, 1, -1
      x(i) = (b(i)-sum(a(i,i+1:n)*x(i+1:n)))/a(i,i)
    end do
  end subroutine dense_solve

  subroutine check(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a)') 'FVQ58_FAIL: '//trim(label)
      error stop 58
    end if
  end subroutine check

end program test_fvq58_restricted_soil_temperature_independent
