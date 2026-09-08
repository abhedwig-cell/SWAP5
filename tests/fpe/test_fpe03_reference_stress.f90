program test_fpe03_reference_stress
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: melt
  use MOD_drain, only: legacy_qdra => qdra
  use MOD_irrigation, only: legacy_qssdi => qssdi
  use variables, only: legacy_qrot => qrot
  use mod_transaction_reference, only: TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  integer, parameter :: ncases = 24
  real(real64), parameter :: t0 = 1000.125_real64
  real(real64), parameter :: t1 = 1000.625_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64

  type :: stress_case_t
    character(len=32) :: name = ''
    real(real64) :: heads(4) = 0.0_real64
    real(real64) :: top_scale = -1.0_real64
    real(real64) :: bottom_scale = -1.0_real64
  end type stress_case_t

  type :: case_metrics_t
    logical :: accepted = .false.
    integer :: kernel_status = 0
    integer :: accepted_substeps = 0
    integer :: nonlinear_iterations = 0
    integer :: internal_retries = 0
    integer :: headcalc_calls = 0
    integer :: jacobian_builds = 0
    integer :: linear_solves = 0
    integer :: backtracking_attempts = 0
    integer :: alternative_solver_calls = 0
    real(real64) :: mass_residual = 0.0_real64
    character(len=32) :: solver_route = 'not-run'
  end type case_metrics_t

  type(stress_case_t) :: cases(ncases)
  type(case_metrics_t) :: metrics(ncases)
  integer :: i, accepted_count, higher_cost_count
  integer :: max_headcalc, max_nonlinear, max_backtracking, max_retries
  integer :: max_headcalc_case, max_nonlinear_case, max_backtracking_case, max_retries_case
  integer :: all_max_nonlinear, all_max_backtracking, all_max_retries

  call require(numnod == 4, 'F-PE03 fixture requires exact four-node admitted test grid')
  call initialize_cases(cases)

  do i = 1, ncases
    call run_case(i, cases(i), metrics(i))
    call print_case(i, cases(i), metrics(i))
  end do

  call require(metrics(1)%accepted, 'easy reference baseline must be accepted')
  accepted_count = count(metrics%accepted)
  higher_cost_count = 0
  do i = 2, ncases
    if (.not. metrics(i)%accepted) cycle
    if (cost_exceeds(metrics(i), metrics(1))) higher_cost_count = higher_cost_count + 1
  end do

  call find_maxima(metrics, max_headcalc, max_headcalc_case, max_nonlinear, max_nonlinear_case, &
       max_backtracking, max_backtracking_case, max_retries, max_retries_case)
  all_max_nonlinear = maxval(metrics%nonlinear_iterations)
  all_max_backtracking = maxval(metrics%backtracking_attempts)
  all_max_retries = maxval(metrics%internal_retries)

  write(*,'(A,I0)') 'FPE03_ACCEPTED_CASES=', accepted_count
  write(*,'(A,I0)') 'FPE03_REJECTED_CASES=', ncases-accepted_count
  write(*,'(A,I0)') 'FPE03_HIGHER_COST_ACCEPTED_CASES=', higher_cost_count
  write(*,'(A,I0)') 'FPE03_BASELINE_HEADCALC_CALLS=', metrics(1)%headcalc_calls
  write(*,'(A,I0)') 'FPE03_BASELINE_NONLINEAR_ITERATIONS=', metrics(1)%nonlinear_iterations
  write(*,'(A,I0)') 'FPE03_BASELINE_BACKTRACKING_ATTEMPTS=', metrics(1)%backtracking_attempts
  write(*,'(A,I0)') 'FPE03_MAX_ACCEPTED_HEADCALC_CALLS=', max_headcalc
  write(*,'(A,I0)') 'FPE03_MAX_ACCEPTED_HEADCALC_CASE=', max_headcalc_case
  write(*,'(A,I0)') 'FPE03_MAX_ACCEPTED_NONLINEAR_ITERATIONS=', max_nonlinear
  write(*,'(A,I0)') 'FPE03_MAX_ACCEPTED_NONLINEAR_CASE=', max_nonlinear_case
  write(*,'(A,I0)') 'FPE03_MAX_ACCEPTED_BACKTRACKING_ATTEMPTS=', max_backtracking
  write(*,'(A,I0)') 'FPE03_MAX_ACCEPTED_BACKTRACKING_CASE=', max_backtracking_case
  write(*,'(A,I0)') 'FPE03_MAX_ACCEPTED_INTERNAL_RETRIES=', max_retries
  write(*,'(A,I0)') 'FPE03_MAX_ACCEPTED_RETRY_CASE=', max_retries_case
  write(*,'(A,I0)') 'FPE03_MAX_ALL_NONLINEAR_ITERATIONS=', all_max_nonlinear
  write(*,'(A,I0)') 'FPE03_MAX_ALL_BACKTRACKING_ATTEMPTS=', all_max_backtracking
  write(*,'(A,I0)') 'FPE03_MAX_ALL_INTERNAL_RETRIES=', all_max_retries
  if (higher_cost_count > 0) then
    write(*,'(A)') 'FPE03_ACCEPTED_HIGHER_COST_PHYSICAL_STRESS_FIXTURE=OBSERVED'
  else
    write(*,'(A)') 'FPE03_ACCEPTED_HIGHER_COST_PHYSICAL_STRESS_FIXTURE=NOT_OBSERVED'
  end if
  write(*,'(A)') 'FPE03_REPRESENTATIVE_TAIL_PERCENTILES=NOT_CLAIMED'
  write(*,'(A)') 'FPE03_BOUNDED_COST_POLICY_ADMISSION=NOT_IN_SCOPE'
  write(*,'(A)') 'FPE03_REFERENCE_STRESS_CHARACTERIZATION PASS'

contains

  subroutine set_uniform(c, name, head, top_scale, bottom_scale)
    type(stress_case_t), intent(out) :: c
    character(len=*), intent(in) :: name
    real(real64), intent(in) :: head, top_scale, bottom_scale
    c%name = name
    c%heads = head
    c%top_scale = top_scale
    c%bottom_scale = bottom_scale
  end subroutine set_uniform

  subroutine initialize_cases(c)
    type(stress_case_t), intent(out) :: c(ncases)

    call set_uniform(c(1), 'easy_uniform_m75', -75.0_real64, -1.0_real64, -1.0_real64)
    call set_uniform(c(2), 'wet_uniform_m5', -5.0_real64, -1.0_real64, -1.0_real64)
    call set_uniform(c(3), 'uniform_m50', -50.0_real64, -1.0_real64, -1.0_real64)
    call set_uniform(c(4), 'uniform_m100', -100.0_real64, -1.0_real64, -1.0_real64)
    call set_uniform(c(5), 'dry_uniform_m500', -500.0_real64, -1.0_real64, -1.0_real64)
    call set_uniform(c(6), 'very_dry_uniform_m5000', -5000.0_real64, -1.0_real64, -1.0_real64)

    c(7)%name = 'tiny_gradient_down'
    c(7)%heads = [-74.99_real64,-75.00_real64,-75.01_real64,-75.02_real64]
    c(8)%name = 'tiny_gradient_up'
    c(8)%heads = [-75.02_real64,-75.01_real64,-75.00_real64,-74.99_real64]
    c(9)%name = 'small_gradient_down'
    c(9)%heads = [-74.9_real64,-75.0_real64,-75.1_real64,-75.2_real64]
    c(10)%name = 'gradient_down_1cm'
    c(10)%heads = [-74.0_real64,-75.0_real64,-76.0_real64,-77.0_real64]

    call set_uniform(c(11), 'top_flux_plus_0p01pct', -75.0_real64, -1.0001_real64, -1.0_real64)
    call set_uniform(c(12), 'top_flux_minus_0p01pct', -75.0_real64, -0.9999_real64, -1.0_real64)
    call set_uniform(c(13), 'top_flux_plus_0p1pct', -75.0_real64, -1.001_real64, -1.0_real64)
    call set_uniform(c(14), 'top_flux_minus_0p1pct', -75.0_real64, -0.999_real64, -1.0_real64)
    call set_uniform(c(15), 'top_flux_plus_1pct', -75.0_real64, -1.01_real64, -1.0_real64)
    call set_uniform(c(16), 'top_flux_minus_1pct', -75.0_real64, -0.99_real64, -1.0_real64)
    call set_uniform(c(17), 'top_flux_plus_10pct', -75.0_real64, -1.10_real64, -1.0_real64)
    call set_uniform(c(18), 'top_flux_minus_10pct', -75.0_real64, -0.90_real64, -1.0_real64)
    call set_uniform(c(19), 'opposing_flux_1pct_a', -75.0_real64, -1.01_real64, -0.99_real64)
    call set_uniform(c(20), 'opposing_flux_1pct_b', -75.0_real64, -0.99_real64, -1.01_real64)
    call set_uniform(c(21), 'm50_top_plus_0p1pct', -50.0_real64, -1.001_real64, -1.0_real64)
    call set_uniform(c(22), 'm100_top_plus_0p1pct', -100.0_real64, -1.001_real64, -1.0_real64)
    call set_uniform(c(23), 'm5_top_plus_0p1pct', -5.0_real64, -1.001_real64, -1.0_real64)
    call set_uniform(c(24), 'm500_top_plus_0p1pct', -500.0_real64, -1.001_real64, -1.0_real64)
  end subroutine initialize_cases

  subroutine run_case(case_id, spec, metric)
    integer, intent(in) :: case_id
    type(stress_case_t), intent(in) :: spec
    type(case_metrics_t), intent(out) :: metric
    type(fmr_logical_column_t) :: columns(1)
    type(fmr_template_t) :: templates(1)
    type(fmr_b110_physical_parameters_t) :: parameters(1)
    type(fmr_b110_physical_forcing_t) :: forcings(1)
    type(fmr_b110_physical_state_t) :: initial_state
    type(kernel_committed_state_t) :: states(1)
    type(fmr_serialized_column_result_t), allocatable :: results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    type(fmr04_fixed_flux_top_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    real(real64) :: k_top, k_bottom
    integer :: dispatch_status
    logical :: ok

    metric = case_metrics_t()
    call configure_template(templates(1))
    call configure_parameters(parameters(1), initial_state, spec%heads, k_top, k_bottom)
    call configure_forcing(forcings(1), spec, k_top, k_bottom)
    call configure_transaction(config)

    columns(1)%column_id = 503000_int64 + int(case_id, int64)
    columns(1)%template_id = templates(1)%template_id
    columns(1)%parameter_ref = 1_int64
    columns(1)%state_handle = 1_int64
    columns(1)%forcing_handle = 1_int64
    columns(1)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    call fmr_new_b110_committed_state(states(1), columns(1)%column_id, initial_state, t0, ok)
    call require(ok, 'committed-state initialization')

    legacy_qdra = 12345.0_real64
    legacy_qssdi = -54321.0_real64
    legacy_qrot = 0.0_real64
    swmacro = 0
    melt = 0.0_real64

    call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, states, config, &
         top_provider, t0, t1, 1, results, diagnostics, aggregate, dispatch_status)
    call require(dispatch_status == FMR_SERIAL_DISPATCH_OK, 'serialized dispatch status')
    call require(size(results) == 1, 'single result')

    metric%kernel_status = results(1)%kernel_status
    metric%accepted_substeps = results(1)%accepted_substeps
    metric%nonlinear_iterations = results(1)%solver_nonlinear_iterations
    metric%internal_retries = results(1)%solver_internal_retries
    metric%headcalc_calls = results(1)%solver_headcalc_calls
    metric%jacobian_builds = results(1)%solver_jacobian_builds
    metric%linear_solves = results(1)%solver_linear_solves
    metric%backtracking_attempts = results(1)%solver_backtracking_attempts
    metric%alternative_solver_calls = results(1)%solver_alternative_solver_calls
    metric%mass_residual = results(1)%mass%residual
    metric%solver_route = results(1)%solver_route
    metric%accepted = results(1)%completed .and. results(1)%committed .and. results(1)%mass%complete .and. &
         results(1)%mass%missing_contribution_mask == TX_MASS_MISSING_NONE

    if (metric%accepted) then
      call require(abs(metric%mass_residual) <= hard_mass_gate, 'accepted stress case hard mass gate')
      call require(states(1)%current_revision() == 1_int64, 'accepted stress case committed once')
    else
      call require(.not. results(1)%committed, 'rejected stress case not committed')
      call require(states(1)%current_revision() == 0_int64, 'rejected stress case revision unchanged')
    end if
  end subroutine run_case

  subroutine configure_template(template)
    type(fmr_template_t), intent(out) :: template
    template%template_id = 503_int64
    template%physics_topology_id = 50501_int64
    template%vertical_layout_id = 50502_int64
    template%state_layout_id = 50503_int64
    template%solver_interface_id = 50504_int64
    template%optional_state_layout_id = 0_int64
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_template

  subroutine configure_parameters(parameters, state, heads, k_top, k_bottom)
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(in) :: heads(4)
    real(real64), intent(out) :: k_top, k_bottom
    type(b110_default_mvg_parameters_t), target :: hyd_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: i

    parameters%parameter_set_id = 50301_int64
    parameters%active_nodes = numnod
    allocate(parameters%z(numnod), parameters%dz(numnod), parameters%node_distance(numnod))
    parameters%z = z
    parameters%dz = dz
    parameters%node_distance = disnod(1:numnod)
    allocate(parameters%cofgen(24,numnod))
    parameters%cofgen = 0.0_real64
    do i = 1, numnod
      parameters%cofgen(1,i) = 0.032_real64
      parameters%cofgen(2,i) = 0.423_real64
      parameters%cofgen(3,i) = 4.75_real64
      parameters%cofgen(4,i) = 0.0135_real64
      parameters%cofgen(5,i) = 0.365_real64
      parameters%cofgen(6,i) = 1.455_real64
      parameters%cofgen(7,i) = 1.0_real64 - 1.0_real64/parameters%cofgen(6,i)
      parameters%cofgen(8,i) = parameters%cofgen(4,i)
      parameters%cofgen(9,i) = 0.0_real64
      parameters%cofgen(10,i) = parameters%cofgen(3,i)
      parameters%cofgen(11,i) = 0.999_real64
      parameters%cofgen(12,i) = 0.99_real64*parameters%cofgen(3,i)
      parameters%cofgen(22,i) = -1.0e6_real64
      parameters%cofgen(23,i) = 1.0e-12_real64
    end do
    parameters%bottom_mode = 7
    parameters%swkimpl = 0
    parameters%swkmean = 1
    parameters%swsophy = 0
    parameters%max_iterations = 8
    parameters%max_backtracking = 4
    parameters%min_step_duration = 1.0e-6_real64
    parameters%compartment_balance_tolerance = 1.0e-12_real64
    parameters%total_balance_tolerance = 1.0e-12_real64
    parameters%head_abs_tolerance = 1.0e-12_real64
    parameters%head_rel_tolerance = 1.0e-12_real64
    parameters%ponding_tolerance = 1.0e-12_real64
    parameters%root_extraction_active = .false.
    parameters%macropore_active = .false.
    parameters%snow_active = .false.
    parameters%hysteresis_active = .false.
    parameters%tabulated_hydraulics_active = .false.
    parameters%elasticity_active = .false.
    parameters%frost_active = .false.

    call initialize_b110_default_mvg_parameters(hyd_parameters, parameters%cofgen)
    call bind_b110_default_mvg_provider(constitutive, hyd_parameters, t1-t0)
    call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
    k_top = conductivity(1)
    k_bottom = conductivity(numnod)
    call require(k_top > 0.0_real64 .and. k_bottom > 0.0_real64, 'positive endpoint conductivity')

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
  end subroutine configure_parameters

  subroutine configure_forcing(forcing, spec, k_top, k_bottom)
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    type(stress_case_t), intent(in) :: spec
    real(real64), intent(in) :: k_top, k_bottom
    integer :: i

    forcing%top_flux = spec%top_scale * k_top
    forcing%top_head = spec%heads(1)
    forcing%bottom_flux = spec%bottom_scale * k_bottom
    forcing%bottom_head = spec%heads(numnod)
    allocate(forcing%drainage_flux_by_level(2,numnod), forcing%subsurface_irrigation_source(numnod), &
             forcing%root_extraction_sink(numnod))
    do i = 1, numnod
      forcing%drainage_flux_by_level(1,i) = 1.0e-5_real64*real(i,real64)
      forcing%drainage_flux_by_level(2,i) = -2.0e-6_real64*real(i+1,real64)
      forcing%subsurface_irrigation_source(i) = forcing%drainage_flux_by_level(1,i) + &
                                                forcing%drainage_flux_by_level(2,i)
      forcing%root_extraction_sink(i) = 0.0_real64
    end do
  end subroutine configure_forcing

  subroutine configure_transaction(config)
    type(canonical_numerical_config_t), intent(out) :: config
    config%transaction%temporal_tolerance = 0.0_real64
    config%transaction%mass_tolerance = hard_mass_gate
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 2
    config%max_committed_substeps = 8
    config%progress_tolerance = 0.0_real64
  end subroutine configure_transaction

  logical function cost_exceeds(candidate, baseline) result(exceeds)
    type(case_metrics_t), intent(in) :: candidate, baseline
    exceeds = candidate%headcalc_calls > baseline%headcalc_calls .or. &
         candidate%nonlinear_iterations > baseline%nonlinear_iterations .or. &
         candidate%backtracking_attempts > baseline%backtracking_attempts .or. &
         candidate%internal_retries > baseline%internal_retries .or. &
         candidate%jacobian_builds > baseline%jacobian_builds .or. &
         candidate%linear_solves > baseline%linear_solves
  end function cost_exceeds

  subroutine print_case(i, spec, metric)
    integer, intent(in) :: i
    type(stress_case_t), intent(in) :: spec
    type(case_metrics_t), intent(in) :: metric
    character(len=16) :: prefix

    write(prefix,'(A,I2.2)') 'FPE03_CASE_', i
    write(*,'(A,A)') trim(prefix)//'_NAME=', trim(spec%name)
    write(*,'(A,L1)') trim(prefix)//'_ACCEPTED=', metric%accepted
    write(*,'(A,I0)') trim(prefix)//'_KERNEL_STATUS=', metric%kernel_status
    write(*,'(A,A)') trim(prefix)//'_SOLVER_ROUTE=', trim(metric%solver_route)
    write(*,'(A,I0)') trim(prefix)//'_ACCEPTED_SUBSTEPS=', metric%accepted_substeps
    write(*,'(A,I0)') trim(prefix)//'_NONLINEAR_ITERATIONS=', metric%nonlinear_iterations
    write(*,'(A,I0)') trim(prefix)//'_INTERNAL_RETRIES=', metric%internal_retries
    write(*,'(A,I0)') trim(prefix)//'_HEADCALC_CALLS=', metric%headcalc_calls
    write(*,'(A,I0)') trim(prefix)//'_JACOBIAN_BUILDS=', metric%jacobian_builds
    write(*,'(A,I0)') trim(prefix)//'_LINEAR_SOLVES=', metric%linear_solves
    write(*,'(A,I0)') trim(prefix)//'_BACKTRACKING_ATTEMPTS=', metric%backtracking_attempts
    write(*,'(A,I0)') trim(prefix)//'_ALTERNATIVE_SOLVER_CALLS=', metric%alternative_solver_calls
    write(*,'(A,ES26.17E3)') trim(prefix)//'_MASS_RESIDUAL=', metric%mass_residual
  end subroutine print_case

  subroutine find_maxima(m, max_hc, max_hc_i, max_nl, max_nl_i, max_bt, max_bt_i, max_rt, max_rt_i)
    type(case_metrics_t), intent(in) :: m(ncases)
    integer, intent(out) :: max_hc, max_hc_i, max_nl, max_nl_i, max_bt, max_bt_i, max_rt, max_rt_i
    integer :: i

    max_hc = -1; max_hc_i = 0
    max_nl = -1; max_nl_i = 0
    max_bt = -1; max_bt_i = 0
    max_rt = -1; max_rt_i = 0
    do i = 1, ncases
      if (.not. m(i)%accepted) cycle
      if (m(i)%headcalc_calls > max_hc) then
        max_hc = m(i)%headcalc_calls; max_hc_i = i
      end if
      if (m(i)%nonlinear_iterations > max_nl) then
        max_nl = m(i)%nonlinear_iterations; max_nl_i = i
      end if
      if (m(i)%backtracking_attempts > max_bt) then
        max_bt = m(i)%backtracking_attempts; max_bt_i = i
      end if
      if (m(i)%internal_retries > max_rt) then
        max_rt = m(i)%internal_retries; max_rt_i = i
      end if
    end do
  end subroutine find_maxima

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(A)') 'FPE03_FAIL '//trim(message)
      error stop 1
    end if
  end subroutine require

end program test_fpe03_reference_stress
