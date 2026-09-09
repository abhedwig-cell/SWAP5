module mod_fmr_parallel_worker_pool
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: TX_MASS_MISSING_UNSPECIFIED
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_soil_water_solver_contract, only: top_boundary_provider_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_run_serialized_physical_multiswap
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
    type(fmr_serialized_batch_diagnostics_t) :: local_runtime
    integer :: schedule_status

    serialized_dispatch_status = -1
    pool_status = FMR_PARALLEL_POOL_INVALID_WORKER_COUNT

    call fmr_build_parallel_schedule(columns, worker_count, assignments, schedule_status)
    if (schedule_status /= FMR_PARALLEL_SCHEDULE_OK) then
      call initialize_rejected_outputs(columns, t0, t1, 'INVALID_WORKER_COUNT', &
           results, diagnostics, aggregate, local_runtime)
      if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
      return
    end if

    if (worker_count /= 1) then
      pool_status = FMR_PARALLEL_POOL_MULTIWORKER_NOT_ADMITTED
      call initialize_rejected_outputs(columns, t0, t1, 'MULTIWORKER_NOT_ADMITTED', &
           results, diagnostics, aggregate, local_runtime)
      if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
      return
    end if

    call fmr_run_serialized_physical_multiswap(columns, templates, parameter_registry, forcing_registry, &
         state_registry, numerical_config, top_boundary, t0, t1, batch_size, results, diagnostics, aggregate, &
         serialized_dispatch_status, local_runtime)
    pool_status = FMR_PARALLEL_POOL_OK
    if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
  end subroutine fmr_run_parallel_physical_multiswap

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

end module mod_fmr_parallel_worker_pool
