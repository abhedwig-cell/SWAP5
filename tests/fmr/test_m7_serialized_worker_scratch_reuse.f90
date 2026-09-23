program test_m7_serialized_worker_scratch_reuse
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_executor_t, kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE, FMR_OPTIONAL_STATE_LAYOUT_BASE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, &
       fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_execute_serialized_physical_column
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: NCOLUMN = 3
  real(real64), parameter :: T0 = 0.0_real64
  real(real64), parameter :: T1 = 0.25_real64
  real(real64), parameter :: H0 = -75.0_real64
  real(real64), parameter :: HARD_MASS_GATE = 1.0e-12_real64

  type(fmr_serialized_reference_backend_t) :: backend
  type(kernel_executor_t) :: transaction_control
  type(fmr_logical_column_t) :: columns(NCOLUMN)
  type(fmr_template_t) :: templates(1)
  type(fmr_b110_physical_parameters_t) :: parameters(NCOLUMN)
  type(fmr_b110_physical_forcing_t) :: forcings(NCOLUMN)
  type(kernel_committed_state_t) :: states(NCOLUMN)
  type(fmr_serialized_column_result_t) :: results(NCOLUMN)
  type(fmr_column_diagnostics_t) :: diagnostics(NCOLUMN)
  type(fmr_serialized_batch_diagnostics_t) :: runtime
  type(fmr_b110_physical_state_t) :: initial_state
  type(fmr_b110_physical_state_t) :: first_state, middle_state, last_state
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(canonical_numerical_config_t) :: numerical
  real(real64) :: conductivity0
  integer :: i, active_physical_calls
  logical :: ok

  call initialize_parameters(parameters(1), 730001_int64)
  call determine_initial_state(parameters(1), initial_state, conductivity0)
  do i = 2, NCOLUMN
    parameters(i) = parameters(1)
    parameters(i)%parameter_set_id = 730000_int64 + int(i, int64)
  end do

  templates(1)%template_id = 731001_int64
  templates(1)%physics_topology_id = 731002_int64
  templates(1)%vertical_layout_id = 731003_int64
  templates(1)%state_layout_id = 731004_int64
  templates(1)%solver_interface_id = 731005_int64
  templates(1)%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_BASE
  templates(1)%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
  templates(1)%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

  do i = 1, NCOLUMN
    columns(i)%column_id = 732000_int64 + int(i, int64)
    columns(i)%template_id = templates(1)%template_id
    columns(i)%parameter_ref = int(i, int64)
    columns(i)%state_handle = int(i, int64)
    columns(i)%forcing_handle = int(i, int64)
    columns(i)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    call configure_forcing(forcings(i), -conductivity0, conductivity0, &
         merge(1.013_real64, 1.026_real64, i /= 2))
    if (i == 2) forcings(i)%top_flux = -0.75_real64 * conductivity0
    call fmr_new_b110_committed_state(states(i), columns(i)%column_id, initial_state, T0, ok)
    call require(ok, 'committed state initialization')
  end do

  numerical%transaction%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
  numerical%transaction%temporal_tolerance = 1.0e-6_real64
  numerical%transaction%mass_tolerance = HARD_MASS_GATE
  numerical%transaction%retry_scale = 0.5_real64
  numerical%transaction%max_retries = 8
  numerical%max_committed_substeps = 32
  numerical%progress_tolerance = 0.0_real64

  call backend%initialize(top)
  active_physical_calls = 0
  runtime = fmr_serialized_batch_diagnostics_t()
  do i = 1, NCOLUMN
    results(i) = fmr_serialized_column_result_t()
    results(i)%column_id = columns(i)%column_id
    results(i)%requested_t0 = T0
    results(i)%requested_t1 = T1
    diagnostics(i) = fmr_column_diagnostics_t()
    diagnostics(i)%column_id = columns(i)%column_id
    call fmr_execute_serialized_physical_column(backend, transaction_control, columns(i), templates, parameters, &
         forcings, states, numerical, T0, T1, results(i), diagnostics(i), runtime, active_physical_calls)
    call require(results(i)%completed .and. results(i)%committed, 'A-B-A column accepted and committed')
    call require(results(i)%mass%complete, 'A-B-A column mass complete')
    call require(abs(results(i)%mass%residual) <= HARD_MASS_GATE, 'A-B-A hard mass gate')
    call require(states(i)%current_revision() == 1_int64, 'A-B-A committed revision')
  end do

  call snapshot_physical_state(states(1), first_state, ok)
  call require(ok, 'first A state snapshot')
  call snapshot_physical_state(states(3), last_state, ok)
  call require(ok, 'last A state snapshot')
  call snapshot_physical_state(states(2), middle_state, ok)
  call require(ok, 'intervening B state snapshot')
  call require(physical_states_identical(first_state, last_state), 'A-B-A physical state identity')
  call require(mass_results_identical(results(1), results(3)), 'A-B-A mass result identity')
  call require(.not. physical_states_identical(first_state, middle_state), 'intervening B is a distinct physical workload')

  print '(a)', 'M7_WORKER_SCRATCH_A_B_A_STATE_IDENTITY=PASS'
  print '(a)', 'M7_WORKER_SCRATCH_A_B_A_MASS_IDENTITY=PASS'
  print '(a)', 'M7_WORKER_SCRATCH_ALL_COLUMNS_COMMITTED_HARD_MASS=PASS'
  print '(a)', 'M7_SERIALIZED_WORKER_SCRATCH_REUSE_CROSS_COLUMN=PASS'

contains

  subroutine initialize_parameters(p, parameter_id)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    integer(int64), intent(in) :: parameter_id
    integer :: k
    p%parameter_set_id = parameter_id
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
      p%cofgen(7,k) = 1.0_real64 - 1.0_real64 / p%cofgen(6,k)
      p%cofgen(8,k) = p%cofgen(4,k)
      p%cofgen(10,k) = p%cofgen(3,k)
      p%cofgen(11,k) = 0.999_real64
      p%cofgen(12,k) = 0.99_real64 * p%cofgen(3,k)
      p%cofgen(22,k) = -1.0e6_real64
      p%cofgen(23,k) = 1.0e-12_real64
    end do
    p%bottom_mode = 2
    p%swkimpl = 0
    p%swkmean = 1
    p%swsophy = 0
    p%max_iterations = 16
    p%max_backtracking = 8
    p%min_step_duration = 1.0e-8_real64
    p%compartment_balance_tolerance = HARD_MASS_GATE
    p%total_balance_tolerance = HARD_MASS_GATE
    p%head_abs_tolerance = HARD_MASS_GATE
    p%head_rel_tolerance = HARD_MASS_GATE
    p%ponding_tolerance = HARD_MASS_GATE
    p%root_extraction_active = .false.
    p%macropore_active = .false.
    p%snow_active = .false.
    p%hysteresis_active = .false.
    p%tabulated_hydraulics_active = .false.
    p%elasticity_active = .false.
    p%frost_active = .false.
    p%soil_temperature_active = .false.
    p%drainage_response_active = .false.
  end subroutine initialize_parameters

  subroutine determine_initial_state(p, state, conductivity)
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: conductivity
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), hydraulic_conductivity(numnod), capacity(numnod), dkdh(numnod)
    call initialize_b110_default_mvg_parameters(hp, p%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, T1 - T0)
    heads = H0
    call provider%evaluate(heads, water, hydraulic_conductivity, capacity, dkdh)
    conductivity = hydraulic_conductivity(1)
    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
  end subroutine determine_initial_state

  subroutine configure_forcing(forcing, top_flux, bottom_flux, scale)
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(in) :: top_flux, bottom_flux, scale
    integer :: k
    forcing%top_flux = top_flux
    forcing%top_head = H0
    forcing%bottom_flux = bottom_flux
    forcing%bottom_head = -100.0_real64
    allocate(forcing%drainage_flux_by_level(2,numnod), forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    do k = 1, numnod
      forcing%drainage_flux_by_level(1,k) = scale * 1.0e-5_real64 * real(k,real64)
      forcing%drainage_flux_by_level(2,k) = -scale * 2.0e-6_real64 * real(k+1,real64)
      forcing%subsurface_irrigation_source(k) = forcing%drainage_flux_by_level(1,k) + &
           forcing%drainage_flux_by_level(2,k)
      forcing%root_extraction_sink(k) = 0.0_real64
    end do
  end subroutine configure_forcing

  subroutine snapshot_physical_state(committed, state, available)
    type(kernel_committed_state_t), intent(in) :: committed
    type(fmr_b110_physical_state_t), intent(out) :: state
    logical, intent(out) :: available
    class(transaction_state_t), allocatable :: snapshot
    call committed%snapshot(snapshot, available)
    if (.not. available) return
    select type (physical => snapshot)
    type is (fmr_b110_physical_state_t)
      state = physical
    class default
      available = .false.
    end select
  end subroutine snapshot_physical_state

  logical function physical_states_identical(a, b) result(equal)
    type(fmr_b110_physical_state_t), intent(in) :: a, b
    integer :: k
    equal = .false.
    if (a%active_nodes /= b%active_nodes) return
    if (.not. allocated(a%pressure_head) .or. .not. allocated(b%pressure_head)) return
    if (.not. allocated(a%water_content) .or. .not. allocated(b%water_content)) return
    if (size(a%pressure_head) /= size(b%pressure_head) .or. size(a%water_content) /= size(b%water_content)) return
    if (.not. same_bits(a%ponding_depth, b%ponding_depth) .or. &
        .not. same_bits(a%groundwater_level, b%groundwater_level)) return
    do k = 1, a%active_nodes
      if (.not. same_bits(a%pressure_head(k), b%pressure_head(k)) .or. &
          .not. same_bits(a%water_content(k), b%water_content(k))) return
    end do
    equal = .true.
  end function physical_states_identical

  logical function mass_results_identical(a, b) result(equal)
    type(fmr_serialized_column_result_t), intent(in) :: a, b
    equal = a%completed .and. b%completed .and. a%committed .and. b%committed .and. &
         a%mass%complete .and. b%mass%complete .and. &
         a%mass%missing_contribution_mask == b%mass%missing_contribution_mask .and. &
         same_bits(a%mass%storage_start, b%mass%storage_start) .and. &
         same_bits(a%mass%storage_end, b%mass%storage_end) .and. &
         same_bits(a%mass%storage_change, b%mass%storage_change) .and. &
         same_bits(a%mass%total_in, b%mass%total_in) .and. &
         same_bits(a%mass%total_out, b%mass%total_out) .and. &
         same_bits(a%mass%residual, b%mass%residual)
  end function mass_results_identical

  pure logical function same_bits(a, b)
    real(real64), intent(in) :: a, b
    same_bits = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function same_bits

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,1x,a)') 'M7_WORKER_SCRATCH_REUSE_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_m7_serialized_worker_scratch_reuse
