module mod_fmr_parallel_worker_pool
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use omp_lib, only: omp_get_thread_num, omp_get_num_threads, omp_get_thread_limit, omp_set_dynamic
  use mod_transaction_reference, only: TX_MASS_MISSING_NONE, TX_MASS_MISSING_UNSPECIFIED
  use mod_canonical_contracts, only: canonical_numerical_config_t, canonical_mass_accounting_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t
  use mod_soil_water_solver_contract, only: top_boundary_provider_t
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, fmr_count_templates, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_serialized_reference_backend_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_run_serialized_physical_multiswap, &
       fmr_execute_serialized_physical_column, FMR_SERIAL_DISPATCH_OK
  use mod_fmr_parallel_physical_scheduler, only: fmr_parallel_assignment_t, fmr_build_parallel_schedule, &
       FMR_PARALLEL_SCHEDULE_OK
  implicit none
  private

  integer, parameter, public :: FMR_PARALLEL_POOL_OK = 0
  integer, parameter, public :: FMR_PARALLEL_POOL_INVALID_WORKER_COUNT = 1
  integer, parameter, public :: FMR_PARALLEL_POOL_MULTIWORKER_NOT_ADMITTED = 2

  public :: fmr_run_parallel_physical_multiswap

contains

  subroutine fmr_run_parallel_physical_multiswap(columns, templates, parameter_registry, forcing_registry, &
                                                  state_registry, numerical_config, top_boundary, t0, t1, &
                                                  batch_size, worker_count, results, diagnostics, aggregate, &
                                                  serialized_dispatch_status, pool_status, runtime_diagnostics)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_template_t), intent(in) :: templates(:)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameter_registry(:)
    type(fmr_b110_physical_forcing_t), intent(in) :: forcing_registry(:)
    type(kernel_committed_state_t), intent(inout) :: state_registry(:)
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    class(top_boundary_provider_t), target, intent(in) :: top_boundary
    real(real64), intent(in) :: t0, t1
    integer, intent(in) :: batch_size
    integer, intent(in) :: worker_count
    type(fmr_serialized_column_result_t), allocatable, intent(out) :: results(:)
    type(fmr_column_diagnostics_t), allocatable, intent(out) :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t), intent(out) :: aggregate
    integer, intent(out) :: serialized_dispatch_status
    integer, intent(out) :: pool_status
    type(fmr_serialized_batch_diagnostics_t), intent(out), optional :: runtime_diagnostics

    type(fmr_parallel_assignment_t), allocatable :: assignments(:)
    type(fmr_serialized_reference_backend_t), allocatable :: backends(:)
    type(kernel_executor_t), allocatable :: transaction_controls(:)
    type(fmr_serialized_batch_diagnostics_t), allocatable :: worker_runtime(:)
    type(fmr_serialized_batch_diagnostics_t) :: local_runtime
    integer :: schedule_status, active_physical_calls, observed_threads
    integer :: w, pos, idx, batch_start, batch_end

    serialized_dispatch_status = -1
    pool_status = FMR_PARALLEL_POOL_INVALID_WORKER_COUNT

    call fmr_build_parallel_schedule(columns, worker_count, assignments, schedule_status)
    if (schedule_status /= FMR_PARALLEL_SCHEDULE_OK) then
      call initialize_rejected_outputs(columns, t0, t1, 'INVALID_WORKER_COUNT', &
           results, diagnostics, aggregate, local_runtime)
      if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
      return
    end if

    ! The already-qualified single-worker route remains an exact delegation to
    ! the serialized reference runtime.  F-MR20 V1 only opens a deliberately
    ! narrow multiworker profile below.
    if (worker_count == 1) then
      call fmr_run_serialized_physical_multiswap(columns, templates, parameter_registry, forcing_registry, &
           state_registry, numerical_config, top_boundary, t0, t1, batch_size, results, diagnostics, aggregate, &
           serialized_dispatch_status, local_runtime)
      pool_status = FMR_PARALLEL_POOL_OK
      if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
      return
    end if

    if ((worker_count /= 2 .and. worker_count /= 4) .or. batch_size <= 0 .or. t1 <= t0 .or. &
        worker_count > omp_get_thread_limit() .or. &
        .not. parallel_v1_profile_admitted(columns, templates, parameter_registry, forcing_registry, &
                                            state_registry, top_boundary)) then
      pool_status = FMR_PARALLEL_POOL_MULTIWORKER_NOT_ADMITTED
      call initialize_rejected_outputs(columns, t0, t1, 'MULTIWORKER_NOT_ADMITTED', &
           results, diagnostics, aggregate, local_runtime)
      if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
      return
    end if

    call initialize_parallel_outputs(columns, assignments, t0, t1, results, diagnostics, aggregate)
    allocate(backends(worker_count), transaction_controls(worker_count), worker_runtime(worker_count))
    do w = 1, worker_count
      call backends(w)%initialize(top_boundary)
      worker_runtime(w) = fmr_serialized_batch_diagnostics_t()
    end do

    active_physical_calls = 0
    observed_threads = 0
    call omp_set_dynamic(.false.)

    !$omp parallel num_threads(worker_count) default(shared) private(w,pos,idx,batch_start,batch_end)
    w = omp_get_thread_num() + 1
    !$omp single
    observed_threads = omp_get_num_threads()
    !$omp end single

    if (observed_threads == worker_count) then
      do batch_start = 1, size(assignments), batch_size
        batch_end = min(size(assignments), batch_start + batch_size - 1)
        do pos = batch_start, batch_end
          if (assignments(pos)%worker_id == w) then
            idx = assignments(pos)%column_index
            call fmr_execute_serialized_physical_column(backends(w), transaction_controls(w), columns(idx), templates, &
                 parameter_registry, forcing_registry, state_registry, numerical_config, t0, t1, &
                 results(idx), diagnostics(idx), worker_runtime(w), active_physical_calls)
          end if
        end do
        !$omp barrier
      end do
    end if
    !$omp end parallel

    if (observed_threads /= worker_count) then
      ! No worker executed a physical solve because every worker observed the
      ! same team-size guard before entering the batch loop.
      pool_status = FMR_PARALLEL_POOL_MULTIWORKER_NOT_ADMITTED
      if (allocated(results)) deallocate(results)
      if (allocated(diagnostics)) deallocate(diagnostics)
      call initialize_rejected_outputs(columns, t0, t1, 'OPENMP_TEAM_NOT_ADMITTED', &
           results, diagnostics, aggregate, local_runtime)
      if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
      return
    end if

    call build_parallel_aggregate(columns, diagnostics, assignments, batch_size, worker_count, aggregate)
    call finalize_parallel_runtime(results, assignments, worker_runtime, t0, t1, local_runtime)
    serialized_dispatch_status = FMR_SERIAL_DISPATCH_OK
    pool_status = FMR_PARALLEL_POOL_OK
    if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
  end subroutine fmr_run_parallel_physical_multiswap

  logical function parallel_v1_profile_admitted(columns, templates, parameter_registry, forcing_registry, &
                                                 state_registry, top_boundary) result(admitted)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_template_t), intent(in) :: templates(:)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameter_registry(:)
    type(fmr_b110_physical_forcing_t), intent(in) :: forcing_registry(:)
    type(kernel_committed_state_t), intent(in) :: state_registry(:)
    class(top_boundary_provider_t), intent(in) :: top_boundary

    logical, allocatable :: state_claimed(:)
    integer :: i, j, template_index, parameter_index, forcing_index, state_index, n

    admitted = .false.
    if (size(columns) <= 0 .or. size(templates) <= 0 .or. size(parameter_registry) <= 0 .or. &
        size(forcing_registry) <= 0 .or. size(state_registry) <= 0) return

    select type (top_boundary)
    type is (fixed_flux_top_boundary_provider_t)
      continue
    class default
      return
    end select

    do i = 1, size(templates)
      if (templates(i)%template_id <= 0_int64) return
      do j = i + 1, size(templates)
        if (templates(j)%template_id == templates(i)%template_id) return
      end do
    end do

    allocate(state_claimed(size(state_registry)))
    state_claimed = .false.

    do i = 1, size(columns)
      if (columns(i)%column_id <= 0_int64 .or. columns(i)%backend_id /= FMR_BACKEND_SERIALIZED_REFERENCE) return
      do j = i + 1, size(columns)
        if (columns(j)%column_id == columns(i)%column_id) return
      end do

      template_index = find_template_index(columns(i)%template_id, templates)
      if (template_index <= 0) return
      if (templates(template_index)%compatible_backend_id /= FMR_BACKEND_SERIALIZED_REFERENCE .or. &
          templates(template_index)%numerical_continuation_layout_id /= FMR_NUMERICAL_CONTINUATION_NONE .or. &
          templates(template_index)%optional_state_layout_id /= 0_int64) return

      if (columns(i)%parameter_ref < 1_int64 .or. columns(i)%parameter_ref > int(size(parameter_registry), int64)) return
      parameter_index = int(columns(i)%parameter_ref)
      n = parameter_registry(parameter_index)%active_nodes
      if (parameter_registry(parameter_index)%parameter_set_id <= 0_int64 .or. n <= 0) return
      if (.not. allocated(parameter_registry(parameter_index)%z) .or. &
          .not. allocated(parameter_registry(parameter_index)%dz) .or. &
          .not. allocated(parameter_registry(parameter_index)%node_distance) .or. &
          .not. allocated(parameter_registry(parameter_index)%cofgen)) return
      if (size(parameter_registry(parameter_index)%z) /= n .or. &
          size(parameter_registry(parameter_index)%dz) /= n .or. &
          size(parameter_registry(parameter_index)%node_distance) /= n .or. &
          size(parameter_registry(parameter_index)%cofgen,1) < 24 .or. &
          size(parameter_registry(parameter_index)%cofgen,2) /= n) return
      if (parameter_registry(parameter_index)%bottom_mode /= 7 .or. &
          parameter_registry(parameter_index)%swkimpl /= 0 .or. &
          parameter_registry(parameter_index)%swsophy /= 0 .or. &
          parameter_registry(parameter_index)%root_extraction_active .or. &
          parameter_registry(parameter_index)%snow_active .or. &
          parameter_registry(parameter_index)%macropore_active .or. &
          parameter_registry(parameter_index)%hysteresis_active .or. &
          parameter_registry(parameter_index)%tabulated_hydraulics_active .or. &
          parameter_registry(parameter_index)%elasticity_active .or. &
          parameter_registry(parameter_index)%frost_active .or. &
          allocated(parameter_registry(parameter_index)%snow)) return

      if (columns(i)%forcing_handle < 1_int64 .or. columns(i)%forcing_handle > int(size(forcing_registry), int64)) return
      forcing_index = int(columns(i)%forcing_handle)
      if (.not. allocated(forcing_registry(forcing_index)%drainage_flux_by_level) .or. &
          .not. allocated(forcing_registry(forcing_index)%subsurface_irrigation_source) .or. &
          .not. allocated(forcing_registry(forcing_index)%root_extraction_sink) .or. &
          allocated(forcing_registry(forcing_index)%snow)) return
      if (size(forcing_registry(forcing_index)%drainage_flux_by_level,1) <= 0 .or. &
          size(forcing_registry(forcing_index)%drainage_flux_by_level,2) /= n .or. &
          size(forcing_registry(forcing_index)%subsurface_irrigation_source) /= n .or. &
          size(forcing_registry(forcing_index)%root_extraction_sink) /= n) return
      if (any(.not. ieee_is_finite(forcing_registry(forcing_index)%root_extraction_sink)) .or. &
          any(abs(forcing_registry(forcing_index)%root_extraction_sink) > 0.0_real64)) return

      if (columns(i)%state_handle < 1_int64 .or. columns(i)%state_handle > int(size(state_registry), int64)) return
      state_index = int(columns(i)%state_handle)
      if (state_claimed(state_index) .or. .not. state_registry(state_index)%ready()) return
      state_claimed(state_index) = .true.
    end do

    admitted = .true.
  end function parallel_v1_profile_admitted

  subroutine initialize_parallel_outputs(columns, assignments, t0, t1, results, diagnostics, aggregate)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_parallel_assignment_t), intent(in) :: assignments(:)
    real(real64), intent(in) :: t0, t1
    type(fmr_serialized_column_result_t), allocatable, intent(out) :: results(:)
    type(fmr_column_diagnostics_t), allocatable, intent(out) :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t), intent(out) :: aggregate
    integer :: i, pos, idx

    allocate(results(size(columns)), diagnostics(size(columns)))
    aggregate = fmr_aggregate_diagnostics_t()
    do i = 1, size(columns)
      results(i)%column_id = columns(i)%column_id
      results(i)%requested_t0 = t0
      results(i)%requested_t1 = t1
      diagnostics(i)%column_id = columns(i)%column_id
      diagnostics(i)%template_id = columns(i)%template_id
      diagnostics(i)%backend = columns(i)%backend_id
      diagnostics(i)%execution_class = columns(i)%execution_class
      allocate(diagnostics(i)%worker_assignments(1))
      diagnostics(i)%worker_assignments = 0
    end do
    do pos = 1, size(assignments)
      idx = assignments(pos)%column_index
      results(idx)%dispatch_ordinal = pos
      diagnostics(idx)%worker_assignments(1) = assignments(pos)%worker_id
    end do
  end subroutine initialize_parallel_outputs

  subroutine build_parallel_aggregate(columns, diagnostics, assignments, batch_size, worker_count, aggregate)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_column_diagnostics_t), intent(in) :: diagnostics(:)
    type(fmr_parallel_assignment_t), intent(in) :: assignments(:)
    integer, intent(in) :: batch_size, worker_count
    type(fmr_aggregate_diagnostics_t), intent(out) :: aggregate
    integer :: pos, idx, worker_id

    aggregate = fmr_aggregate_diagnostics_t()
    aggregate%columns = size(columns)
    aggregate%templates = fmr_count_templates(columns)
    aggregate%batches = (size(columns) + batch_size - 1) / batch_size
    aggregate%workers = worker_count
    allocate(aggregate%work_distribution(worker_count))
    aggregate%work_distribution = 0_int64

    do pos = 1, size(assignments)
      idx = assignments(pos)%column_index
      worker_id = assignments(pos)%worker_id
      aggregate%attempts = aggregate%attempts + diagnostics(idx)%attempts
      aggregate%retries = aggregate%retries + diagnostics(idx)%retries
      if (diagnostics(idx)%accepted == 0) aggregate%failures = aggregate%failures + 1
      if (diagnostics(idx)%accepted == 1) then
        aggregate%aggregate_unrounded_mass_residual = aggregate%aggregate_unrounded_mass_residual + &
             diagnostics(idx)%unrounded_mass_residual
      end if
      aggregate%work_distribution(worker_id) = aggregate%work_distribution(worker_id) + &
           int(diagnostics(idx)%attempts, int64)
    end do
  end subroutine build_parallel_aggregate

  subroutine finalize_parallel_runtime(results, assignments, worker_runtime, t0, t1, runtime)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    type(fmr_parallel_assignment_t), intent(in) :: assignments(:)
    type(fmr_serialized_batch_diagnostics_t), intent(in) :: worker_runtime(:)
    real(real64), intent(in) :: t0, t1
    type(fmr_serialized_batch_diagnostics_t), intent(out) :: runtime
    integer :: pos, idx, w
    logical :: aggregate_complete

    runtime = fmr_serialized_batch_diagnostics_t()
    runtime%number_requested = size(results)
    runtime%effective_t0 = t0
    runtime%effective_t1 = t1
    runtime%deterministic_collection = .true.
    runtime%authoritative_aggregate_mass = canonical_mass_accounting_t()
    runtime%authoritative_aggregate_mass%interval_t0 = t0
    runtime%authoritative_aggregate_mass%interval_t1 = t1
    runtime%authoritative_aggregate_mass%missing_contribution_mask = TX_MASS_MISSING_UNSPECIFIED
    do w = 1, size(worker_runtime)
      runtime%max_simultaneous_real_physical_solves = max(runtime%max_simultaneous_real_physical_solves, &
           worker_runtime(w)%max_simultaneous_real_physical_solves)
    end do

    aggregate_complete = .true.
    do pos = 1, size(assignments)
      idx = assignments(pos)%column_index
      if (results(idx)%admitted) runtime%number_admitted = runtime%number_admitted + 1
      if (results(idx)%solver_executed) then
        runtime%number_executed = runtime%number_executed + 1
        runtime%physical_solve_count = runtime%physical_solve_count + 1
      end if
      if (results(idx)%committed) then
        runtime%number_committed = runtime%number_committed + 1
        aggregate_complete = aggregate_complete .and. results(idx)%mass%complete .and. &
             results(idx)%mass%missing_contribution_mask == TX_MASS_MISSING_NONE
        runtime%authoritative_aggregate_mass%accepted_transaction_count = &
             runtime%authoritative_aggregate_mass%accepted_transaction_count + &
             results(idx)%mass%accepted_transaction_count
        runtime%authoritative_aggregate_mass%storage_start = runtime%authoritative_aggregate_mass%storage_start + &
             results(idx)%mass%storage_start
        runtime%authoritative_aggregate_mass%storage_end = runtime%authoritative_aggregate_mass%storage_end + &
             results(idx)%mass%storage_end
        runtime%authoritative_aggregate_mass%storage_change = runtime%authoritative_aggregate_mass%storage_change + &
             results(idx)%mass%storage_change
        runtime%authoritative_aggregate_mass%total_in = runtime%authoritative_aggregate_mass%total_in + &
             results(idx)%mass%total_in
        runtime%authoritative_aggregate_mass%total_out = runtime%authoritative_aggregate_mass%total_out + &
             results(idx)%mass%total_out
        runtime%authoritative_aggregate_mass%residual = runtime%authoritative_aggregate_mass%residual + &
             results(idx)%mass%residual
        runtime%max_abs_column_mass_residual = max(runtime%max_abs_column_mass_residual, abs(results(idx)%mass%residual))
      else
        runtime%number_rejected = runtime%number_rejected + 1
      end if
    end do

    if (runtime%number_committed > 0 .and. aggregate_complete) then
      runtime%authoritative_aggregate_mass%complete = .true.
      runtime%authoritative_aggregate_mass%missing_contribution_mask = TX_MASS_MISSING_NONE
    else
      runtime%authoritative_aggregate_mass%complete = .false.
      runtime%authoritative_aggregate_mass%missing_contribution_mask = TX_MASS_MISSING_UNSPECIFIED
    end if
  end subroutine finalize_parallel_runtime

  subroutine initialize_rejected_outputs(columns, t0, t1, failure_classification, results, diagnostics, aggregate, runtime)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    real(real64), intent(in) :: t0, t1
    character(len=*), intent(in) :: failure_classification
    type(fmr_serialized_column_result_t), allocatable, intent(out) :: results(:)
    type(fmr_column_diagnostics_t), allocatable, intent(out) :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t), intent(out) :: aggregate
    type(fmr_serialized_batch_diagnostics_t), intent(out) :: runtime

    integer :: i

    allocate(results(size(columns)), diagnostics(size(columns)))
    aggregate = fmr_aggregate_diagnostics_t()
    runtime = fmr_serialized_batch_diagnostics_t()

    aggregate%columns = size(columns)
    aggregate%workers = 0
    aggregate%failures = size(columns)

    runtime%number_requested = size(columns)
    runtime%number_rejected = size(columns)
    runtime%effective_t0 = t0
    runtime%effective_t1 = t1
    runtime%authoritative_aggregate_mass%interval_t0 = t0
    runtime%authoritative_aggregate_mass%interval_t1 = t1
    runtime%authoritative_aggregate_mass%missing_contribution_mask = TX_MASS_MISSING_UNSPECIFIED

    do i = 1, size(columns)
      results(i)%column_id = columns(i)%column_id
      results(i)%requested_t0 = t0
      results(i)%requested_t1 = t1
      results(i)%admission_assessed = .true.
      results(i)%admitted = .false.
      results(i)%admission_status = failure_classification

      diagnostics(i)%column_id = columns(i)%column_id
      diagnostics(i)%template_id = columns(i)%template_id
      diagnostics(i)%backend = columns(i)%backend_id
      diagnostics(i)%execution_class = columns(i)%execution_class
      diagnostics(i)%rejected = 1
      diagnostics(i)%failure_classification = failure_classification
      allocate(diagnostics(i)%worker_assignments(0))
    end do
  end subroutine initialize_rejected_outputs

  integer function find_template_index(template_id, templates) result(index)
    integer(int64), intent(in) :: template_id
    type(fmr_template_t), intent(in) :: templates(:)
    integer :: i
    index = 0
    do i = 1, size(templates)
      if (templates(i)%template_id == template_id) then
        index = i
        return
      end if
    end do
  end function find_template_index

end module mod_fmr_parallel_worker_pool
