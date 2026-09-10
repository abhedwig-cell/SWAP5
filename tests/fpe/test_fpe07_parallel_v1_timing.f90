program test_fpe07_parallel_v1_timing
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

  integer, parameter :: ncol = 32
  integer, parameter :: batch_size = 9
  integer, parameter :: warmup_blocks = 2
  integer, parameter :: measured_blocks = 12
  integer, parameter :: repetitions = 8
  real(real64), parameter :: t0 = 2000.125_real64
  real(real64), parameter :: t1 = 2000.625_real64
  real(real64), parameter :: head0 = -75.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64

  type(fmr_logical_column_t) :: columns(ncol)
  type(fmr_template_t) :: templates(1)
  type(fmr_b110_physical_parameters_t) :: parameters(1)
  type(fmr_b110_physical_forcing_t) :: forcings(ncol)
  type(kernel_committed_state_t) :: states(ncol)
  type(fmr_serialized_column_result_t), allocatable :: results(:)
  type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
  type(fmr_aggregate_diagnostics_t) :: aggregate
  type(fmr_serialized_batch_diagnostics_t) :: runtime
  type(fmr_b110_physical_state_t) :: initial_state
  type(fixed_flux_top_boundary_provider_t), target :: top_provider
  type(canonical_numerical_config_t) :: config
  integer(int64) :: tick0, tick1, rate, max_count
  real(real64) :: conductivity0, elapsed_us
  integer :: b, p, r, workers, serialized_status, pool_status, i
  integer :: arm_order(3)

  call system_clock(count_rate=rate, count_max=max_count)
  call require(rate > 0_int64, 'positive system_clock rate')

  call configure_template(templates(1))
  call configure_parameters(parameters(1), initial_state, conductivity0)
  call configure_transaction(config)
  do i = 1, ncol
    columns(i)%column_id = 920000_int64 + int(i,int64)
    columns(i)%template_id = templates(1)%template_id
    columns(i)%parameter_ref = 1_int64
    columns(i)%state_handle = int(i,int64)
    columns(i)%forcing_handle = int(i,int64)
    columns(i)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    call configure_forcing(forcings(i), conductivity0, 1.0_real64 + 0.01_real64*real(i,real64))
  end do

  write(*,'(A,I0)') 'FPE07_CLOCK_RATE=', rate
  write(*,'(A,I0)') 'FPE07_CLOCK_MAX=', max_count
  write(*,'(A,I0)') 'FPE07_NCOL=', ncol
  write(*,'(A,I0)') 'FPE07_BATCH_SIZE=', batch_size
  write(*,'(A,I0)') 'FPE07_WARMUP_BLOCKS=', warmup_blocks
  write(*,'(A,I0)') 'FPE07_MEASURED_BLOCKS=', measured_blocks
  write(*,'(A,I0)') 'FPE07_REPETITIONS_PER_ARM_BLOCK=', repetitions

  do b = 1, warmup_blocks
    call block_order(b, arm_order)
    do p = 1, 3
      workers = arm_order(p)
      call initialize_states(states, columns, initial_state)
      call run_once(workers, states, serialized_status, pool_status, runtime)
      call validate_run(workers, serialized_status, pool_status, results, runtime)
    end do
  end do
  write(*,'(A)') 'FPE07_WARMUP_COMPLETE=PASS'

  do b = 1, measured_blocks
    call block_order(b, arm_order)
    do p = 1, 3
      workers = arm_order(p)
      do r = 1, repetitions
        call initialize_states(states, columns, initial_state)
        call system_clock(tick0)
        call run_once(workers, states, serialized_status, pool_status, runtime)
        call system_clock(tick1)
        call validate_run(workers, serialized_status, pool_status, results, runtime)
        if (tick1 >= tick0) then
          elapsed_us = 1.0e6_real64 * real(tick1-tick0,real64) / real(rate,real64)
        else
          elapsed_us = 1.0e6_real64 * real((max_count-tick0)+tick1+1_int64,real64) / real(rate,real64)
        end if
        write(*,'(A,I0,A,I0,A,I0,A,I0,A,ES24.16,A,I0)') &
             'FPE07_RAW,', b, ',', workers, ',', r, ',', tick1-tick0, ',', elapsed_us, ',', &
             runtime%max_simultaneous_real_physical_solves
      end do
    end do
  end do

  write(*,'(A)') 'FPE07_TIMING_DRIVER PASS'

contains

  subroutine run_once(workers, state_registry, serialized_status, pool_status, runtime)
    integer, intent(in) :: workers
    type(kernel_committed_state_t), intent(inout) :: state_registry(:)
    integer, intent(out) :: serialized_status, pool_status
    type(fmr_serialized_batch_diagnostics_t), intent(out) :: runtime
    call fmr_run_parallel_physical_multiswap(columns, templates, parameters, forcings, state_registry, config, &
         top_provider, t0, t1, batch_size, workers, results, diagnostics, aggregate, &
         serialized_status, pool_status, runtime)
  end subroutine run_once

  subroutine validate_run(workers, serialized_status, pool_status, values, runtime)
    integer, intent(in) :: workers, serialized_status, pool_status
    type(fmr_serialized_column_result_t), intent(in) :: values(:)
    type(fmr_serialized_batch_diagnostics_t), intent(in) :: runtime
    call require(pool_status == FMR_PARALLEL_POOL_OK, 'pool status')
    call require(serialized_status == FMR_SERIAL_DISPATCH_OK, 'serialized dispatch status')
    call require(size(values) == ncol, 'result cardinality')
    call require(all_committed(values), 'all columns committed')
    call require(max_abs_residual(values) <= hard_mass_gate, 'hard mass gate')
    call require(runtime%number_committed == ncol .and. runtime%number_rejected == 0, 'runtime commit cardinality')
    if (workers == 1) then
      call require(runtime%max_simultaneous_real_physical_solves == 1, 'serialized overlap cardinality')
    else if (workers == 2) then
      call require(runtime%max_simultaneous_real_physical_solves >= 2 .and. &
                   runtime%max_simultaneous_real_physical_solves <= 2, 'two-worker overlap')
    else if (workers == 4) then
      call require(runtime%max_simultaneous_real_physical_solves >= 2 .and. &
                   runtime%max_simultaneous_real_physical_solves <= 4, 'four-worker overlap')
    else
      call require(.false., 'unexpected worker count')
    end if
  end subroutine validate_run

  subroutine block_order(block, order)
    integer, intent(in) :: block
    integer, intent(out) :: order(3)
    select case (mod(block-1,6)+1)
    case (1); order = [1,2,4]
    case (2); order = [4,2,1]
    case (3); order = [2,1,4]
    case (4); order = [4,1,2]
    case (5); order = [2,4,1]
    case (6); order = [1,4,2]
    end select
  end subroutine block_order

  subroutine configure_template(template)
    type(fmr_template_t), intent(out) :: template
    template%template_id = 9200_int64
    template%physics_topology_id = 920001_int64
    template%vertical_layout_id = 920002_int64
    template%state_layout_id = 920003_int64
    template%solver_interface_id = 920004_int64
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

    value%parameter_set_id = 920001_int64
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
    call require(all(conductivity == conductivity(1)), 'uniform conductivity fixture')
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

  subroutine initialize_states(values, column_registry, seed)
    type(kernel_committed_state_t), intent(out) :: values(:)
    type(fmr_logical_column_t), intent(in) :: column_registry(:)
    type(fmr_b110_physical_state_t), intent(in) :: seed
    type(fmr_b110_physical_state_t) :: state
    logical :: ok
    integer :: j
    call require(size(values) == size(column_registry), 'state registry shape')
    do j = 1, size(values)
      state = seed
      state%groundwater_level = -2.0_real64 - 0.01_real64*real(j,real64)
      call fmr_new_b110_committed_state(values(j), column_registry(j)%column_id, state, t0, ok)
      call require(ok, 'committed state initialization')
    end do
  end subroutine initialize_states

  logical function all_committed(values) result(ok_all)
    type(fmr_serialized_column_result_t), intent(in) :: values(:)
    integer :: j
    ok_all = .true.
    do j = 1, size(values)
      if (.not. values(j)%completed .or. .not. values(j)%committed .or. .not. values(j)%mass%complete) then
        ok_all = .false.
        return
      end if
    end do
  end function all_committed

  real(real64) function max_abs_residual(values) result(value)
    type(fmr_serialized_column_result_t), intent(in) :: values(:)
    integer :: j
    value = 0.0_real64
    do j = 1, size(values)
      if (values(j)%committed) value = max(value, abs(values(j)%mass%residual))
    end do
  end function max_abs_residual

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,A)') 'FPE07_FAIL ', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fpe07_parallel_v1_timing
