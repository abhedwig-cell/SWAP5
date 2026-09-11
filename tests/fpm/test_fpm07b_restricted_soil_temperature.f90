program test_fpm07b_restricted_soil_temperature
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

  integer, parameter :: n = 4
  type(soil_temperature_parameters_t) :: parameters
  type(soil_temperature_numerical_config_t) :: numerical
  type(process_hydraulic_view_t) :: hyd_start, hyd_end, hyd_bad

  call setup(parameters, hyd_start, hyd_end, numerical)
  call test_zero_gradient(parameters, numerical, hyd_start, hyd_end)
  call test_constant_boundary_reference(parameters, numerical, hyd_start, hyd_end)
  call test_devries_regime_references(parameters, numerical, hyd_start, hyd_end)
  call test_temporal_refinement(parameters, numerical, hyd_start, hyd_end)
  call test_restart_and_transaction(parameters, numerical, hyd_start, hyd_end)
  call test_views_clone_and_fail_closed(parameters, numerical, hyd_start, hyd_end)
  call test_multiswap_isolation(parameters, numerical, hyd_start, hyd_end)

  hyd_bad = hyd_start
  hyd_bad%water_content(2) = 0.6_real64
  call assert_invalid_hydraulic(parameters, numerical, hyd_start, hyd_bad)

  print *, 'FPM07B_RESTRICTED_SOIL_TEMPERATURE_TEST PASS'

contains

  subroutine setup(params, hs, he, num)
    type(soil_temperature_parameters_t), intent(out) :: params
    type(process_hydraulic_view_t), intent(out) :: hs, he
    type(soil_temperature_numerical_config_t), intent(out) :: num
    real(real64) :: dz(n), dist(n), theta_sat(n), fq(n), fc(n), fo(n)
    integer :: s

    dz = [5.0_real64, 5.0_real64, 10.0_real64, 10.0_real64]
    dist = [2.5_real64, 5.0_real64, 7.5_real64, 10.0_real64]
    theta_sat = 0.45_real64
    fq = 0.35_real64
    fc = 0.15_real64
    fo = 0.05_real64
    call initialize_soil_temperature_parameters(dz, dist, theta_sat, fq, fc, fo, params, s)
    call check(s == SOIL_TEMP_OK, 'parameter initialization')
    call check(params%ready(), 'parameter ready')
    call check(params%node_count() == n, 'parameter node count')

    hs%active_nodes = n
    he%active_nodes = n
    allocate(hs%water_content(n), he%water_content(n))
    hs%water_content = 0.25_real64
    he%water_content = 0.25_real64

    num%require_energy_closure = .true.
    num%energy_abs_tolerance_j_cm2 = 1.0e-9_real64
  end subroutine setup

  subroutine test_zero_gradient(params, num, hs, he)
    type(soil_temperature_parameters_t), intent(in) :: params
    type(soil_temperature_numerical_config_t), intent(in) :: num
    type(process_hydraulic_view_t), intent(in) :: hs, he
    type(soil_temperature_state_t) :: committed, trial
    type(soil_temperature_workspace_t) :: workspace
    type(soil_temperature_forcing_t) :: forcing
    type(soil_temperature_result_t) :: result
    type(soil_temperature_diagnostics_t) :: diagnostics
    real(real64), allocatable :: profile(:), before(:)
    integer :: s

    call initialize_soil_temperature_state([10.0_real64,10.0_real64,10.0_real64,10.0_real64], committed, s)
    call check(s == SOIL_TEMP_OK, 'zero-gradient state init')
    call copy_soil_temperature_profile(committed, before, s)
    call check(s == SOIL_TEMP_OK, 'zero-gradient before copy')
    forcing%prescribed_surface_temperature_c = 10.0_real64
    call trial_restricted_soil_temperature(params, num, forcing, hs, he, committed, 4.25_real64, 4.75_real64, &
         workspace, trial, result, diagnostics)
    call check(result%status == SOIL_TEMP_OK .and. result%produced, 'zero-gradient trial')
    call check(.not. diagnostics%committed_state_mutated, 'zero-gradient committed immutable')
    call copy_soil_temperature_profile(committed, profile, s)
    call check(maxval(abs(profile-before)) < 1.0e-15_real64, 'trial did not mutate committed')
    deallocate(profile)
    call copy_soil_temperature_profile(trial, profile, s)
    call check(maxval(abs(profile-10.0_real64)) < 1.0e-13_real64, 'zero-gradient identity')
    call check(abs(result%top_heat_flux_into_soil_j_cm2_day) < 1.0e-11_real64, 'zero-gradient top flux')
    call check(abs(result%sensible_storage_change_j_cm2) < 1.0e-11_real64, 'zero-gradient storage')
    call check(abs(result%energy_residual_j_cm2) < 1.0e-11_real64, 'zero-gradient energy residual')
    print *, 'FPM07B_ZERO_GRADIENT_CONDUCTION_IDENTITY=PASS'
  end subroutine test_zero_gradient

  subroutine test_constant_boundary_reference(params, num, hs, he)
    type(soil_temperature_parameters_t), intent(in) :: params
    type(soil_temperature_numerical_config_t), intent(in) :: num
    type(process_hydraulic_view_t), intent(in) :: hs, he
    type(soil_temperature_state_t) :: committed, trial
    type(soil_temperature_workspace_t) :: workspace
    type(soil_temperature_forcing_t) :: forcing
    type(soil_temperature_result_t) :: result
    type(soil_temperature_diagnostics_t) :: diagnostics
    real(real64), allocatable :: profile(:)
    real(real64), parameter :: expected(n) = [18.60746269542683_real64, 16.601323719086693_real64, &
                                              14.488199231429059_real64, 13.295345147276143_real64]
    integer :: s

    call initialize_soil_temperature_state([10.0_real64,10.0_real64,10.0_real64,10.0_real64], committed, s)
    forcing%prescribed_surface_temperature_c = 20.0_real64
    call trial_restricted_soil_temperature(params, num, forcing, hs, he, committed, 2.0_real64, 2.5_real64, &
         workspace, trial, result, diagnostics)
    call check(result%status == SOIL_TEMP_OK, 'constant boundary trial')
    call copy_soil_temperature_profile(trial, profile, s)
    call check(maxval(abs(profile-expected)) < 2.0e-9_real64, 'constant boundary independent reference')
    call check(abs(result%sensible_storage_change_j_cm2 - result%boundary_energy_into_soil_j_cm2) < 1.0e-9_real64, &
         'constant boundary energy accounting')
    call check(diagnostics%prescribed_surface_temperature_used, 'surface dirichlet marker')
    call check(diagnostics%zero_bottom_heat_flux_used, 'zero bottom flux marker')
    call check(diagnostics%energy_accounting_complete, 'energy accounting marker')
    print *, 'FPM07B_CONSTANT_BOUNDARY_INDEPENDENT_REFERENCE=PASS'
    print *, 'FPM07B_SENSIBLE_ENERGY_ACCOUNTING=PASS'
  end subroutine test_constant_boundary_reference

  subroutine test_devries_regime_references(params, num, hs, he)
    type(soil_temperature_parameters_t), intent(in) :: params
    type(soil_temperature_numerical_config_t), intent(in) :: num
    type(process_hydraulic_view_t), intent(in) :: hs, he
    type(process_hydraulic_view_t) :: h0, h1
    real(real64), parameter :: expected_dry(n) = [17.239957882377_real64, 14.175924833025677_real64, &
                                                   11.704808574562213_real64, 10.723313680717709_real64]
    real(real64), parameter :: expected_transition(n) = [18.0616583668849_real64, 15.518873444864097_real64, &
                                                          13.07444205235607_real64, 11.850013866201516_real64]
    h0 = hs
    h1 = he
    h0%water_content = 0.01_real64
    h1%water_content = 0.01_real64
    call assert_reference_profile(params, num, h0, h1, expected_dry, 'dry De Vries reference')
    h0%water_content = 0.035_real64
    h1%water_content = 0.035_real64
    call assert_reference_profile(params, num, h0, h1, expected_transition, 'transition De Vries reference')
    print *, 'FPM07B_DEVRIES_DRY_TRANSITION_WET_REGIMES=PASS'
  end subroutine test_devries_regime_references

  subroutine assert_reference_profile(params, num, hs, he, expected, label)
    type(soil_temperature_parameters_t), intent(in) :: params
    type(soil_temperature_numerical_config_t), intent(in) :: num
    type(process_hydraulic_view_t), intent(in) :: hs, he
    real(real64), intent(in) :: expected(:)
    character(len=*), intent(in) :: label
    type(soil_temperature_state_t) :: state, trial
    type(soil_temperature_workspace_t) :: workspace
    type(soil_temperature_forcing_t) :: forcing
    type(soil_temperature_result_t) :: result
    type(soil_temperature_diagnostics_t) :: diagnostics
    real(real64), allocatable :: profile(:)
    integer :: s
    call initialize_soil_temperature_state([10.0_real64,10.0_real64,10.0_real64,10.0_real64], state, s)
    forcing%prescribed_surface_temperature_c = 20.0_real64
    call trial_restricted_soil_temperature(params, num, forcing, hs, he, state, 0.0_real64, 0.5_real64, &
         workspace, trial, result, diagnostics)
    call check(result%status == SOIL_TEMP_OK, trim(label)//' trial')
    call copy_soil_temperature_profile(trial, profile, s)
    call check(maxval(abs(profile-expected)) < 2.0e-9_real64, trim(label))
  end subroutine assert_reference_profile

  subroutine test_temporal_refinement(params, num, hs, he)
    type(soil_temperature_parameters_t), intent(in) :: params
    type(soil_temperature_numerical_config_t), intent(in) :: num
    type(process_hydraulic_view_t), intent(in) :: hs, he
    real(real64), allocatable :: p1(:), p2(:), p4(:), p8(:)
    real(real64) :: e12, e24, e48

    call integrate_profile(params, num, hs, he, 1, 2.0_real64, 20.0_real64, 10.0_real64, p1)
    call integrate_profile(params, num, hs, he, 2, 2.0_real64, 20.0_real64, 10.0_real64, p2)
    call integrate_profile(params, num, hs, he, 4, 2.0_real64, 20.0_real64, 10.0_real64, p4)
    call integrate_profile(params, num, hs, he, 8, 2.0_real64, 20.0_real64, 10.0_real64, p8)
    e12 = maxval(abs(p1-p2))
    e24 = maxval(abs(p2-p4))
    e48 = maxval(abs(p4-p8))
    call check(e24 < e12 .and. e48 < e24, 'temporal refinement convergence')
    call check(e12 > 0.5_real64 .and. e48 < 0.4_real64, 'temporal refinement nontrivial')
    print *, 'FPM07B_TEMPORAL_REFINEMENT=PASS'
  end subroutine test_temporal_refinement

  subroutine test_restart_and_transaction(params, num, hs, he)
    type(soil_temperature_parameters_t), intent(in) :: params
    type(soil_temperature_numerical_config_t), intent(in) :: num
    type(process_hydraulic_view_t), intent(in) :: hs, he
    type(soil_temperature_state_t) :: continuous, split, restored, trial
    type(soil_temperature_workspace_t) :: w_cont, w_split
    type(soil_temperature_restart_payload_t) :: payload
    type(soil_temperature_forcing_t) :: forcing
    type(soil_temperature_result_t) :: result
    type(soil_temperature_diagnostics_t) :: diagnostics
    real(real64), allocatable :: pc(:), ps(:), before(:), after(:)
    integer :: s, k

    call initialize_soil_temperature_state([9.0_real64,9.0_real64,9.0_real64,9.0_real64], continuous, s)
    call initialize_soil_temperature_state([9.0_real64,9.0_real64,9.0_real64,9.0_real64], split, s)
    forcing%prescribed_surface_temperature_c = 16.0_real64
    do k = 1, 4
      call advance_one(params, num, forcing, hs, he, continuous, real(k-1,real64)*0.25_real64, &
           real(k,real64)*0.25_real64, w_cont)
    end do
    do k = 1, 2
      call advance_one(params, num, forcing, hs, he, split, real(k-1,real64)*0.25_real64, &
           real(k,real64)*0.25_real64, w_split)
    end do
    call export_soil_temperature_restart(split, payload, s)
    call check(s == SOIL_TEMP_OK .and. payload%schema_version == 1, 'restart export')
    call check(size(payload%temperature_c) == n, 'restart payload only profile')
    call reconstruct_soil_temperature_restart(payload, restored, s)
    call check(s == SOIL_TEMP_OK, 'restart reconstruct')
    do k = 3, 4
      call advance_one(params, num, forcing, hs, he, restored, real(k-1,real64)*0.25_real64, &
           real(k,real64)*0.25_real64, w_split)
    end do
    call copy_soil_temperature_profile(continuous, pc, s)
    call copy_soil_temperature_profile(restored, ps, s)
    call check(maxval(abs(pc-ps)) < 1.0e-15_real64, 'continuous split restart exact identity')

    call copy_soil_temperature_profile(restored, before, s)
    forcing%prescribed_surface_temperature_c = 30.0_real64
    call trial_restricted_soil_temperature(params, num, forcing, hs, he, restored, 10.0_real64, 10.5_real64, &
         w_split, trial, result, diagnostics)
    call check(result%status == SOIL_TEMP_OK, 'discardable valid trial')
    call copy_soil_temperature_profile(restored, after, s)
    call check(maxval(abs(before-after)) < 1.0e-15_real64, 'rejected/discarded trial immutable')
    call check(.not. diagnostics%committed_state_mutated, 'diagnostic says committed immutable')
    print *, 'FPM07B_CONTINUOUS_SPLIT_RESTART_IDENTITY=PASS'
    print *, 'FPM07B_REJECTED_TRIAL_IMMUTABILITY=PASS'
  end subroutine test_restart_and_transaction

  subroutine test_views_clone_and_fail_closed(params, num, hs, he)
    type(soil_temperature_parameters_t), intent(in) :: params
    type(soil_temperature_numerical_config_t), intent(in) :: num
    type(process_hydraulic_view_t), intent(in) :: hs, he
    type(soil_temperature_state_t) :: state, trial
    type(soil_temperature_workspace_t) :: workspace
    type(soil_temperature_forcing_t) :: forcing
    type(soil_temperature_result_t) :: result
    type(soil_temperature_diagnostics_t) :: diagnostics
    type(soil_temperature_field_view_t) :: view
    class(transaction_state_t), allocatable :: cloned
    real(real64) :: tnode
    real(real64), allocatable :: p(:), pc(:)
    integer :: s

    call initialize_soil_temperature_state([7.0_real64,8.0_real64,9.0_real64,10.0_real64], state, s)
    call build_soil_temperature_field_view(state, view, s)
    call check(s == SOIL_TEMP_OK .and. view%active_nodes == n, 'temperature semantic view')
    call check(maxval(abs(view%temperature_c-[7.0_real64,8.0_real64,9.0_real64,10.0_real64])) < 1.0e-15_real64, 'view values')
    call soil_temperature_at_node(state, 3, tnode, s)
    call check(s == SOIL_TEMP_OK .and. abs(tnode-9.0_real64) < 1.0e-15_real64, 'semantic node query')
    call state%clone(cloned)
    select type (cloned_state => cloned)
    type is (soil_temperature_state_t)
      call copy_soil_temperature_profile(cloned_state, pc, s)
      call copy_soil_temperature_profile(state, p, s)
      call check(maxval(abs(pc-p)) < 1.0e-15_real64, 'transaction clone')
    class default
      call check(.false., 'transaction clone type')
    end select

    forcing%prescribed_surface_temperature_c = 10.0_real64
    call trial_restricted_soil_temperature(params, num, forcing, hs, he, state, 5.0_real64, 5.0_real64, &
         workspace, trial, result, diagnostics)
    call check(result%status == SOIL_TEMP_INVALID_INTERVAL .and. .not. result%produced, 'invalid interval fail closed')
    print *, 'FPM07B_TRANSACTION_STATE_AND_SEMANTIC_VIEW=PASS'
    print *, 'FPM07B_FAIL_CLOSED_INVALID_INTERVAL=PASS'
  end subroutine test_views_clone_and_fail_closed

  subroutine test_multiswap_isolation(params, num, hs, he)
    type(soil_temperature_parameters_t), intent(in) :: params
    type(soil_temperature_numerical_config_t), intent(in) :: num
    type(process_hydraulic_view_t), intent(in) :: hs, he
    type(soil_temperature_state_t) :: interleaved(3), reference(3)
    type(soil_temperature_workspace_t) :: shared_workspace, ref_workspace(3)
    type(soil_temperature_forcing_t) :: f(3)
    real(real64), allocatable :: pi(:), pr(:)
    integer :: i, k, s
    real(real64) :: initial_value(3), surface_value(3)

    initial_value = [8.0_real64, 10.0_real64, 12.0_real64]
    surface_value = [5.0_real64, 15.0_real64, 25.0_real64]
    do i = 1, 3
      call initialize_soil_temperature_state([initial_value(i),initial_value(i),initial_value(i),initial_value(i)], interleaved(i), s)
      call initialize_soil_temperature_state([initial_value(i),initial_value(i),initial_value(i),initial_value(i)], reference(i), s)
      f(i)%prescribed_surface_temperature_c = surface_value(i)
    end do

    do k = 1, 4
      do i = 1, 3
        call advance_one(params, num, f(i), hs, he, interleaved(i), real(k-1,real64)*0.125_real64, &
             real(k,real64)*0.125_real64, shared_workspace)
      end do
    end do
    do i = 1, 3
      do k = 1, 4
        call advance_one(params, num, f(i), hs, he, reference(i), real(k-1,real64)*0.125_real64, &
             real(k,real64)*0.125_real64, ref_workspace(i))
      end do
      call copy_soil_temperature_profile(interleaved(i), pi, s)
      call copy_soil_temperature_profile(reference(i), pr, s)
      call check(maxval(abs(pi-pr)) < 1.0e-15_real64, 'MultiSWAP interleaving isolation')
      deallocate(pi, pr)
    end do
    print *, 'FPM07B_MULTISWAP_COLUMN_ISOLATION=PASS'
  end subroutine test_multiswap_isolation

  subroutine assert_invalid_hydraulic(params, num, hs, hb)
    type(soil_temperature_parameters_t), intent(in) :: params
    type(soil_temperature_numerical_config_t), intent(in) :: num
    type(process_hydraulic_view_t), intent(in) :: hs, hb
    type(soil_temperature_state_t) :: state, trial
    type(soil_temperature_workspace_t) :: w
    type(soil_temperature_forcing_t) :: f
    type(soil_temperature_result_t) :: r
    type(soil_temperature_diagnostics_t) :: d
    integer :: s
    call initialize_soil_temperature_state([10.0_real64,10.0_real64,10.0_real64,10.0_real64], state, s)
    f%prescribed_surface_temperature_c = 10.0_real64
    call trial_restricted_soil_temperature(params, num, f, hs, hb, state, 0.0_real64, 1.0_real64, w, trial, r, d)
    call check(r%status == SOIL_TEMP_INVALID_HYDRAULIC_VIEW .and. .not. r%produced, 'invalid hydraulic fail closed')
    print *, 'FPM07B_FAIL_CLOSED_INVALID_HYDRAULIC_VIEW=PASS'
  end subroutine assert_invalid_hydraulic

  subroutine integrate_profile(params, num, hs, he, steps, total_dt, surface, initial, profile)
    type(soil_temperature_parameters_t), intent(in) :: params
    type(soil_temperature_numerical_config_t), intent(in) :: num
    type(process_hydraulic_view_t), intent(in) :: hs, he
    integer, intent(in) :: steps
    real(real64), intent(in) :: total_dt, surface, initial
    real(real64), allocatable, intent(out) :: profile(:)
    type(soil_temperature_state_t) :: state
    type(soil_temperature_workspace_t) :: workspace
    type(soil_temperature_forcing_t) :: forcing
    integer :: s, k
    real(real64) :: dt

    call initialize_soil_temperature_state([initial,initial,initial,initial], state, s)
    call check(s == SOIL_TEMP_OK, 'integrate init')
    forcing%prescribed_surface_temperature_c = surface
    dt = total_dt/real(steps,real64)
    do k = 1, steps
      call advance_one(params, num, forcing, hs, he, state, real(k-1,real64)*dt, real(k,real64)*dt, workspace)
    end do
    call copy_soil_temperature_profile(state, profile, s)
    call check(s == SOIL_TEMP_OK, 'integrate profile')
  end subroutine integrate_profile

  subroutine advance_one(params, num, forcing, hs, he, state, t0, t1, workspace)
    type(soil_temperature_parameters_t), intent(in) :: params
    type(soil_temperature_numerical_config_t), intent(in) :: num
    type(soil_temperature_forcing_t), intent(in) :: forcing
    type(process_hydraulic_view_t), intent(in) :: hs, he
    type(soil_temperature_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(soil_temperature_workspace_t), intent(inout) :: workspace
    type(soil_temperature_state_t) :: trial
    type(soil_temperature_result_t) :: result
    type(soil_temperature_diagnostics_t) :: diagnostics
    integer :: s

    call trial_restricted_soil_temperature(params, num, forcing, hs, he, state, t0, t1, workspace, trial, result, diagnostics)
    call check(result%status == SOIL_TEMP_OK .and. result%produced, 'advance trial')
    call check(.not. diagnostics%committed_state_mutated, 'advance trial immutability')
    call commit_soil_temperature_state(state, trial, s)
    call check(s == SOIL_TEMP_OK, 'advance commit')
  end subroutine advance_one

  subroutine check(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a)') 'FAIL: '//trim(label)
      error stop 1
    end if
  end subroutine check

end program test_fpm07b_restricted_soil_temperature
