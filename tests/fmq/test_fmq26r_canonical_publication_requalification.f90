program test_fmq26r_canonical_publication_requalification
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, fmr_serialized_batch_diagnostics_t, &
       FMR_SERIAL_DISPATCH_OK
  use mod_fmr_parallel_worker_pool, only: fmr_run_parallel_physical_multiswap, FMR_PARALLEL_POOL_OK
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  integer, parameter :: ncol = 7
  integer, parameter :: permutation(ncol) = [4, 1, 7, 2, 6, 3, 5]
  real(real64), parameter :: t0 = 4260.125_real64
  real(real64), parameter :: t1 = 4260.625_real64
  real(real64), parameter :: head0 = -75.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  type(fmr_logical_column_t) :: base_columns(ncol), reversed_columns(ncol), permuted_columns(ncol)
  type(fmr_template_t) :: templates(1)
  type(fmr_b110_physical_parameters_t) :: parameters(1)
  type(fmr_b110_physical_forcing_t) :: forcings(ncol)
  type(fmr_b110_physical_state_t) :: seed
  type(fixed_flux_top_boundary_provider_t), target :: top_provider
  type(canonical_numerical_config_t) :: config
  real(real64) :: conductivity0, residual_reverse_2, residual_permuted_2, residual_reverse_4, residual_permuted_4
  integer :: i

  call configure_template(templates(1))
  call configure_parameters(parameters(1), seed, conductivity0)
  call configure_transaction(config)
  do i = 1, ncol
    base_columns(i)%column_id = 926800_int64 + int(41*i,int64)
    base_columns(i)%template_id = templates(1)%template_id
    base_columns(i)%parameter_ref = 1_int64
    base_columns(i)%state_handle = int(i,int64)
    base_columns(i)%forcing_handle = int(i,int64)
    base_columns(i)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    call configure_forcing(forcings(i), conductivity0, 1.0_real64 + 0.011_real64*real(i,real64))
  end do
  reversed_columns = base_columns(ncol:1:-1)
  permuted_columns = base_columns(permutation)

  call run_publication_case(reversed_columns, 2, residual_reverse_2)
  write(*,'(A)') 'FMQ26R_REVERSED_2_WORKERS_CANONICAL_PUBLICATION=PASS'
  call run_publication_case(permuted_columns, 2, residual_permuted_2)
  write(*,'(A)') 'FMQ26R_PERMUTED_2_WORKERS_CANONICAL_PUBLICATION=PASS'
  call run_publication_case(reversed_columns, 4, residual_reverse_4)
  write(*,'(A)') 'FMQ26R_REVERSED_4_WORKERS_CANONICAL_PUBLICATION=PASS'
  call run_publication_case(permuted_columns, 4, residual_permuted_4)
  write(*,'(A)') 'FMQ26R_PERMUTED_4_WORKERS_CANONICAL_PUBLICATION=PASS'

  call require(residual_reverse_2 == residual_permuted_2, '2-worker aggregate mass independent of input order')
  call require(residual_reverse_4 == residual_permuted_4, '4-worker aggregate mass independent of input order')
  call require(residual_reverse_2 == residual_reverse_4, 'aggregate mass independent of worker count')
  write(*,'(A)') 'FMQ26R_AGGREGATE_MASS_PUBLICATION_INDEPENDENCE=PASS'
  write(*,'(A)') 'FMQ26R_CANONICAL_PUBLICATION_REQUALIFICATION PASS'

contains

  subroutine run_publication_case(input_columns, workers, mass_residual)
    type(fmr_logical_column_t), intent(in) :: input_columns(:)
    integer, intent(in) :: workers
    real(real64), intent(out) :: mass_residual
    type(kernel_committed_state_t) :: states(ncol)
    type(fmr_serialized_column_result_t), allocatable :: results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    integer :: dispatch_status, pool_status, j

    call initialize_states(states)
    call fmr_run_parallel_physical_multiswap(input_columns, templates, parameters, forcings, states, config, top_provider, &
         t0, t1, 3, workers, results, diagnostics, aggregate, dispatch_status, pool_status, runtime)
    call require(pool_status == FMR_PARALLEL_POOL_OK .and. dispatch_status == FMR_SERIAL_DISPATCH_OK, 'parallel run status')
    call require(size(results) == ncol .and. size(diagnostics) == ncol, 'publication sizes')
    call require(runtime%number_committed == ncol, 'all columns committed')
    call require(runtime%authoritative_aggregate_mass%complete, 'aggregate mass complete')
    call require(runtime%authoritative_aggregate_mass%missing_contribution_mask == 0_int64, 'aggregate mass missing mask')
    call require(abs(runtime%authoritative_aggregate_mass%residual) <= hard_mass_gate, 'aggregate mass residual')

    do j = 1, ncol
      call require(results(j)%column_id == base_columns(j)%column_id, 'canonical result publication order')
      call require(diagnostics(j)%column_id == base_columns(j)%column_id, 'canonical diagnostic publication order')
    end do
    mass_residual = runtime%authoritative_aggregate_mass%residual
  end subroutine run_publication_case

  subroutine initialize_states(states)
    type(kernel_committed_state_t), intent(out) :: states(:)
    type(fmr_b110_physical_state_t) :: state
    logical :: ok
    integer :: j
    do j = 1, size(states)
      state = seed
      state%groundwater_level = -2.0_real64 - 0.006_real64*real(j,real64)
      call fmr_new_b110_committed_state(states(j), base_columns(j)%column_id, state, t0, ok)
      call require(ok, 'committed state initialization')
    end do
  end subroutine initialize_states

  subroutine configure_template(template)
    type(fmr_template_t), intent(out) :: template
    template%template_id = 9268_int64
    template%physics_topology_id = 926801_int64
    template%vertical_layout_id = 926802_int64
    template%state_layout_id = 926803_int64
    template%solver_interface_id = 926804_int64
    template%optional_state_layout_id = 0_int64
    template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_template

  subroutine configure_parameters(value, state, conductivity0)
    type(fmr_b110_physical_parameters_t), intent(out) :: value
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: conductivity0
    type(b110_default_mvg_parameters_t), target :: hyd_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: j

    value%parameter_set_id = 926801_int64
    value%active_nodes = numnod
    allocate(value%z(numnod), value%dz(numnod), value%node_distance(numnod), value%cofgen(24,numnod))
    value%z = z
    value%dz = dz
    value%node_distance = disnod(1:numnod)
    value%cofgen = 0.0_real64
    do j = 1, numnod
      value%cofgen(1,j) = 0.032_real64
      value%cofgen(2,j) = 0.423_real64
      value%cofgen(3,j) = 4.75_real64
      value%cofgen(4,j) = 0.0135_real64
      value%cofgen(5,j) = 0.365_real64
      value%cofgen(6,j) = 1.455_real64
      value%cofgen(7,j) = 1.0_real64 - 1.0_real64/value%cofgen(6,j)
      value%cofgen(8,j) = value%cofgen(4,j)
      value%cofgen(10,j) = value%cofgen(3,j)
      value%cofgen(11,j) = 0.999_real64
      value%cofgen(12,j) = 0.99_real64*value%cofgen(3,j)
      value%cofgen(22,j) = -1.0e6_real64
      value%cofgen(23,j) = 1.0e-12_real64
    end do
    value%bottom_mode = 7
    value%swkimpl = 0
    value%swkmean = 1
    value%swsophy = 0
    value%root_extraction_active = .false.
    value%macropore_active = .false.
    value%snow_active = .false.
    value%hysteresis_active = .false.
    value%tabulated_hydraulics_active = .false.
    value%elasticity_active = .false.
    value%frost_active = .false.

    call initialize_b110_default_mvg_parameters(hyd_parameters, value%cofgen)
    call bind_b110_default_mvg_provider(constitutive, hyd_parameters, t1-t0)
    heads = head0
    call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
    conductivity0 = conductivity(1)
    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
  end subroutine configure_parameters

  subroutine configure_forcing(forcing, conductivity0, scale)
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(in) :: conductivity0, scale
    integer :: j
    forcing%top_flux = -conductivity0
    forcing%top_head = head0
    forcing%bottom_flux = -conductivity0
    forcing%bottom_head = -100.0_real64
    allocate(forcing%drainage_flux_by_level(2,numnod), forcing%subsurface_irrigation_source(numnod), &
             forcing%root_extraction_sink(numnod))
    do j = 1, numnod
      forcing%drainage_flux_by_level(1,j) = scale*1.0e-5_real64*real(j,real64)
      forcing%drainage_flux_by_level(2,j) = -scale*2.0e-6_real64*real(j+1,real64)
      forcing%subsurface_irrigation_source(j) = forcing%drainage_flux_by_level(1,j) + &
           forcing%drainage_flux_by_level(2,j)
      forcing%root_extraction_sink(j) = 0.0_real64
    end do
  end subroutine configure_forcing

  subroutine configure_transaction(value)
    type(canonical_numerical_config_t), intent(out) :: value
    value%transaction%temporal_tolerance = 0.0_real64
    value%transaction%mass_tolerance = hard_mass_gate
    value%transaction%retry_scale = 0.5_real64
    value%transaction%max_retries = 2
    value%max_committed_substeps = 8
    value%progress_tolerance = 0.0_real64
  end subroutine configure_transaction

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A)') 'FMQ26R_FAIL: '//trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fmq26r_canonical_publication_requalification
