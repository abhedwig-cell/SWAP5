module mod_fmr_deterministic_runtime
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use omp_lib, only: omp_get_thread_num
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t, kernel_committed_state_t, &
       kernel_checkpoint_t, kernel_executor_t, kernel_result_t, kernel_candidate_state_t, &
       kernel_diagnostics_t, KERNEL_STATUS_CHECKPOINT_MISMATCH
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint, fmr_trial_from_checkpoint, &
       fmr_commit_candidate, fmr_discard_candidate
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, fmr_memory_report_t, fmr_build_execution_order, &
       fmr_count_templates, fmr_metadata_bytes_per_column, FMR_BACKEND_DETERMINISTIC_TEST
  implicit none
  private

  type, extends(canonical_state_t), public :: fmr_test_state_t
    real(real64) :: water = 0.0_real64
  contains
    procedure :: clone => fmr_test_clone
  end type fmr_test_state_t

  type, extends(kernel_parameters_t), public :: fmr_test_parameters_t
    real(real64) :: flux_scale = 1.0_real64
  end type fmr_test_parameters_t

  type, extends(canonical_forcing_t), public :: fmr_test_forcing_t
    real(real64) :: inflow_rate = 0.0_real64
    real(real64) :: outflow_rate = 0.0_real64
  end type fmr_test_forcing_t

  type, public :: fmr_test_job_control_t
    integer :: runtime_failures_before_success = 0
    integer :: internal_failures = 0
    integer :: max_runtime_retries = 0
    integer :: cost_weight = 1
    logical :: terminal_failure = .false.
    logical :: inject_mass_defect = .false.
  end type fmr_test_job_control_t

  type, public :: fmr_test_result_t
    integer(int64) :: column_id = 0_int64
    logical :: completed = .false.
    real(real64) :: initial_storage = 0.0_real64
    real(real64) :: final_storage = 0.0_real64
    real(real64) :: total_in = 0.0_real64
    real(real64) :: total_out = 0.0_real64
    real(real64) :: unrounded_mass_residual = 0.0_real64
  end type fmr_test_result_t

  type, extends(kernel_model_t) :: fmr_test_model_t
    real(real64) :: flux_scale = 1.0_real64
    real(real64) :: inflow_rate = 0.0_real64
    real(real64) :: outflow_rate = 0.0_real64
    real(real64) :: warm_seed = 0.0_real64
    integer(int64) :: active_column_id = 0_int64
    integer :: kernel_call_in_job = 0
    integer :: advance_in_kernel = 0
    integer :: runtime_failures_before_success = 0
    integer :: internal_failures = 0
    integer :: cost_weight = 1
    logical :: terminal_failure = .false.
    logical :: inject_mass_defect = .false.
    integer(int64) :: scratch_token = 0_int64
    integer(int64) :: job_cost = 0_int64
  contains
    procedure :: configure_parameters => fmr_configure_parameters
    procedure :: execution_admitted => fmr_execution_admitted
    procedure :: prepare_interval => fmr_prepare_interval
    procedure :: advance => fmr_advance
    procedure :: storage => fmr_storage
    procedure :: temporal_error => fmr_temporal_error
    procedure :: begin_job => fmr_begin_job
    procedure :: poison => fmr_poison_model
  end type fmr_test_model_t

  type :: fmr_deterministic_worker_t
    integer :: worker_id = 0
    type(fmr_test_model_t) :: model
    type(kernel_executor_t) :: kernel
  contains
    procedure :: initialize => fmr_initialize_worker
    procedure :: poison => fmr_poison_worker
  end type fmr_deterministic_worker_t

  public :: fmr_new_committed_state
  public :: fmr_committed_water
  public :: fmr_run_deterministic

contains

  subroutine fmr_test_clone(self, copy)
    class(fmr_test_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy

    allocate(fmr_test_state_t :: copy)
    select type (copy)
    type is (fmr_test_state_t)
      copy%water = self%water
    end select
  end subroutine fmr_test_clone

  subroutine fmr_new_committed_state(committed, lineage_id, water, initial_time, ok)
    type(kernel_committed_state_t), intent(out) :: committed
    integer(int64), intent(in) :: lineage_id
    real(real64), intent(in) :: water, initial_time
    logical, intent(out) :: ok
    class(transaction_state_t), allocatable :: state

    allocate(fmr_test_state_t :: state)
    select type (state)
    type is (fmr_test_state_t)
      state%water = water
    end select
    call committed%initialize(lineage_id, state, ok, initial_time)
  end subroutine fmr_new_committed_state

  real(real64) function fmr_committed_water(committed) result(value)
    type(kernel_committed_state_t), intent(in) :: committed
    class(transaction_state_t), allocatable :: snapshot
    logical :: ok

    call committed%snapshot(snapshot, ok)
    if (.not. ok) error stop 'F-MR deterministic committed snapshot unavailable'
    select type (snapshot)
    type is (fmr_test_state_t)
      value = snapshot%water
    class default
      error stop 'F-MR deterministic state type mismatch'
    end select
  end function fmr_committed_water

  subroutine fmr_begin_job(self, column_id, control)
    class(fmr_test_model_t), intent(inout) :: self
    integer(int64), intent(in) :: column_id
    type(fmr_test_job_control_t), intent(in) :: control

    self%active_column_id = column_id
    self%kernel_call_in_job = 0
    self%advance_in_kernel = 0
    self%runtime_failures_before_success = max(0, control%runtime_failures_before_success)
    self%internal_failures = max(0, control%internal_failures)
    self%cost_weight = max(1, control%cost_weight)
    self%terminal_failure = control%terminal_failure
    self%inject_mass_defect = control%inject_mass_defect
    self%scratch_token = 0_int64
    self%job_cost = 0_int64
  end subroutine fmr_begin_job

  subroutine fmr_poison_model(self)
    class(fmr_test_model_t), intent(inout) :: self
    self%scratch_token = huge(0_int64)
    self%warm_seed = -huge(0.0_real64)
  end subroutine fmr_poison_model

  subroutine fmr_configure_parameters(self, parameters)
    class(fmr_test_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters

    select type (parameters)
    type is (fmr_test_parameters_t)
      self%flux_scale = parameters%flux_scale
    class default
      error stop 'F-MR deterministic unexpected parameter type'
    end select
    self%kernel_call_in_job = self%kernel_call_in_job + 1
    self%advance_in_kernel = 0
  end subroutine fmr_configure_parameters

  logical function fmr_execution_admitted(self, parameters, numerical_config)
    class(fmr_test_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    logical :: parameter_ok

    parameter_ok = .false.
    select type (parameters)
    type is (fmr_test_parameters_t)
      parameter_ok = parameters%flux_scale >= 0.0_real64
    class default
      parameter_ok = .false.
    end select
    fmr_execution_admitted = parameter_ok .and. numerical_config%max_committed_substeps > 0 .and. &
         self%active_column_id > 0_int64
  end function fmr_execution_admitted

  subroutine fmr_prepare_interval(self, forcing, interval, config)
    class(fmr_test_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config

    select type (forcing)
    type is (fmr_test_forcing_t)
      self%inflow_rate = forcing%inflow_rate
      self%outflow_rate = forcing%outflow_rate
    class default
      error stop 'F-MR deterministic unexpected forcing type'
    end select
    if (interval%t1 <= interval%t0) error stop 'F-MR deterministic invalid interval'
    if (config%max_committed_substeps <= 0) error stop 'F-MR deterministic invalid config'
  end subroutine fmr_prepare_interval

  subroutine fmr_advance(self, state, t0, t1, outcome)
    class(fmr_test_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    integer :: k
    real(real64) :: dt, mass_in, mass_out

    outcome = trial_outcome_t()
    self%advance_in_kernel = self%advance_in_kernel + 1
    self%warm_seed = self%warm_seed + 1.0_real64
    self%job_cost = self%job_cost + int(self%cost_weight, int64)
    do k = 1, self%cost_weight
      self%scratch_token = ieor(self%scratch_token, int(k + self%advance_in_kernel, int64))
    end do

    if (self%terminal_failure .or. &
        self%kernel_call_in_job <= self%runtime_failures_before_success) then
      outcome%solver_ok = .false.
      outcome%nonlinear_iterations = self%cost_weight
      return
    end if
    if (self%advance_in_kernel <= self%internal_failures) then
      outcome%solver_ok = .false.
      outcome%nonlinear_iterations = self%cost_weight
      return
    end if

    dt = t1 - t0
    mass_in = self%flux_scale * self%inflow_rate * dt
    mass_out = self%flux_scale * self%outflow_rate * dt
    select type (state)
    type is (fmr_test_state_t)
      state%water = state%water + mass_in - mass_out
    class default
      error stop 'F-MR deterministic unexpected state type'
    end select

    outcome%solver_ok = .true.
    outcome%mass_in = mass_in
    outcome%mass_out = mass_out
    if (self%inject_mass_defect) outcome%mass_out = outcome%mass_out + 1.0e-6_real64
    outcome%nonlinear_iterations = self%cost_weight
  end subroutine fmr_advance

  real(real64) function fmr_storage(self, state) result(value)
    class(fmr_test_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state

    if (self%active_column_id < 0_int64) error stop 'unreachable F-MR column id'
    select type (state)
    type is (fmr_test_state_t)
      value = state%water
    class default
      error stop 'F-MR deterministic storage type mismatch'
    end select
  end function fmr_storage

  real(real64) function fmr_temporal_error(self, full_state, half_state) result(value)
    class(fmr_test_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state

    if (self%active_column_id < 0_int64) error stop 'unreachable F-MR column id'
    if (.not. same_type_as(full_state, half_state)) error stop 'F-MR deterministic temporal state mismatch'
    value = 0.0_real64
  end function fmr_temporal_error

  subroutine fmr_initialize_worker(self, worker_id)
    class(fmr_deterministic_worker_t), target, intent(inout) :: self
    integer, intent(in) :: worker_id

    self%worker_id = worker_id
    call self%kernel%bind_model(self%model)
  end subroutine fmr_initialize_worker

  subroutine fmr_poison_worker(self)
    class(fmr_deterministic_worker_t), intent(inout) :: self
    call self%model%poison()
  end subroutine fmr_poison_worker

  subroutine fmr_run_deterministic(columns, templates, parameters, forcings, states, controls, &
                                   numerical_config, t0, t1, worker_count, batch_size, results, &
                                   diagnostics, aggregate, memory, poison_worker_scratch)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_template_t), intent(in) :: templates(:)
    type(fmr_test_parameters_t), intent(in) :: parameters(:)
    type(fmr_test_forcing_t), intent(in) :: forcings(:)
    type(kernel_committed_state_t), intent(inout) :: states(:)
    type(fmr_test_job_control_t), intent(in) :: controls(:)
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    real(real64), intent(in) :: t0, t1
    integer, intent(in) :: worker_count, batch_size
    type(fmr_test_result_t), allocatable, intent(out) :: results(:)
    type(fmr_column_diagnostics_t), allocatable, intent(out) :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t), intent(out) :: aggregate
    type(fmr_memory_report_t), intent(out) :: memory
    logical, intent(in), optional :: poison_worker_scratch

    type(fmr_deterministic_worker_t), allocatable, target :: workers(:)
    integer, allocatable :: order(:)
    integer :: i, batch_start, batch_end, pos, idx, worker_id, batches
    logical :: poison

    if (worker_count <= 0 .or. batch_size <= 0) error stop 'F-MR invalid worker or batch size'
    if (size(states) < size(columns) .or. size(controls) < size(columns)) then
      error stop 'F-MR state/control registry too small'
    end if

    poison = .false.
    if (present(poison_worker_scratch)) poison = poison_worker_scratch
    allocate(results(size(columns)), diagnostics(size(columns)))
    do i = 1, size(columns)
      diagnostics(i)%column_id = columns(i)%column_id
      diagnostics(i)%template_id = columns(i)%template_id
      diagnostics(i)%backend = columns(i)%backend_id
      diagnostics(i)%execution_class = columns(i)%execution_class
      allocate(diagnostics(i)%worker_assignments(1))
      diagnostics(i)%worker_assignments = 0
      results(i)%column_id = columns(i)%column_id
    end do

    call fmr_build_execution_order(columns, order)
    allocate(workers(worker_count))
    do i = 1, worker_count
      call workers(i)%initialize(i)
      if (poison) call workers(i)%poison()
    end do

    batches = (size(columns) + batch_size - 1) / batch_size
    do batch_start = 1, size(columns), batch_size
      batch_end = min(size(columns), batch_start + batch_size - 1)
!$omp parallel do schedule(dynamic,1) num_threads(worker_count) private(pos,idx,worker_id)
      do pos = batch_start, batch_end
        idx = order(pos)
        worker_id = omp_get_thread_num() + 1
        call execute_column(workers(worker_id), columns(idx), templates, parameters, forcings, &
             states(idx), controls(idx), numerical_config, t0, t1, results(idx), diagnostics(idx))
      end do
!$omp end parallel do
    end do

    call build_aggregate(columns, diagnostics, worker_count, batches, aggregate)
    call build_memory_report(parameters, states, workers, memory)
  end subroutine fmr_run_deterministic

  subroutine execute_column(worker, column, templates, parameters, forcings, committed, control, &
                            numerical_config, t0, t1, output, diagnostic)
    type(fmr_deterministic_worker_t), target, intent(inout) :: worker
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: templates(:)
    type(fmr_test_parameters_t), intent(in) :: parameters(:)
    type(fmr_test_forcing_t), intent(in) :: forcings(:)
    type(kernel_committed_state_t), intent(inout) :: committed
    type(fmr_test_job_control_t), intent(in) :: control
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    real(real64), intent(in) :: t0, t1
    type(fmr_test_result_t), intent(inout) :: output
    type(fmr_column_diagnostics_t), intent(inout) :: diagnostic

    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_result_t) :: kernel_result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: kernel_diag
    integer :: runtime_attempt, max_attempts
    integer(int64) :: cost_before
    logical :: ok, did_commit, time_available
    real(real64) :: committed_time

    diagnostic%worker_assignments(1) = worker%worker_id
    output%initial_storage = fmr_committed_water(committed)
    if (.not. column_is_routable(column, templates, parameters, forcings)) then
      diagnostic%rejected = 1
      diagnostic%failure_classification = 'ROUTING_REJECTED'
      call update_committed_provenance(committed, diagnostic)
      output%final_storage = output%initial_storage
      return
    end if

    call fmr_capture_checkpoint(committed, checkpoint, ok)
    if (.not. ok) then
      diagnostic%rejected = 1
      diagnostic%failure_classification = 'CHECKPOINT_CAPTURE_FAILED'
      call update_committed_provenance(committed, diagnostic)
      output%final_storage = output%initial_storage
      return
    end if
    diagnostic%checkpoint_captures = 1
    call worker%model%begin_job(column%column_id, control)
    max_attempts = max(1, control%max_runtime_retries + 1)
    cost_before = worker%model%job_cost

    do runtime_attempt = 1, max_attempts
      diagnostic%runtime_attempts = diagnostic%runtime_attempts + 1
      diagnostic%checkpoint_replays = diagnostic%checkpoint_replays + 1
      call fmr_trial_from_checkpoint(worker%kernel, parameters(int(column%parameter_ref)), committed, &
           forcings(int(column%forcing_handle)), numerical_config, t0, t1, checkpoint, kernel_result, &
           candidate, kernel_diag)
      diagnostic%attempts = diagnostic%attempts + kernel_diag%attempts
      diagnostic%retries = diagnostic%retries + kernel_diag%retries

      if (kernel_result%status == KERNEL_STATUS_CHECKPOINT_MISMATCH) then
        diagnostic%rejected = 1
        diagnostic%failure_classification = 'CHECKPOINT_MISMATCH'
        exit
      end if

      if (kernel_result%completed) then
        call fmr_commit_candidate(worker%kernel, committed, candidate, kernel_diag, did_commit)
        if (did_commit) then
          diagnostic%accepted = 1
          diagnostic%failure_classification = 'NONE'
          output%completed = .true.
          output%total_in = kernel_result%mass%total_in
          output%total_out = kernel_result%mass%total_out
          output%unrounded_mass_residual = kernel_result%mass%residual
          diagnostic%unrounded_mass_residual = kernel_result%mass%residual
          exit
        end if
        diagnostic%rejected = 1
        diagnostic%failure_classification = 'COMMIT_REJECTED'
        exit
      end if

      call fmr_discard_candidate(worker%kernel, candidate, kernel_diag)
      if (runtime_attempt < max_attempts) then
        diagnostic%retries = diagnostic%retries + 1
      else
        diagnostic%rejected = 1
        if (control%inject_mass_defect) then
          diagnostic%failure_classification = 'HARD_MASS_REJECTED'
        else if (control%terminal_failure) then
          diagnostic%failure_classification = 'TERMINAL_FAILURE'
        else
          diagnostic%failure_classification = 'RETRY_EXHAUSTED'
        end if
      end if
    end do

    diagnostic%synthetic_cost = worker%model%job_cost - cost_before
    output%final_storage = fmr_committed_water(committed)
    if (output%completed) then
      output%unrounded_mass_residual = output%initial_storage + output%total_in - &
           output%total_out - output%final_storage
      diagnostic%unrounded_mass_residual = output%unrounded_mass_residual
    end if
    call committed%current_time(committed_time, time_available)
    diagnostic%committed_time = committed_time
    diagnostic%committed_time_bound = time_available
    diagnostic%committed_revision = committed%current_revision()
  end subroutine execute_column

  logical function column_is_routable(column, templates, parameters, forcings)
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: templates(:)
    type(fmr_test_parameters_t), intent(in) :: parameters(:)
    type(fmr_test_forcing_t), intent(in) :: forcings(:)
    integer :: i
    logical :: found_template

    found_template = .false.
    do i = 1, size(templates)
      if (templates(i)%template_id == column%template_id) then
        found_template = templates(i)%compatible_backend_id == FMR_BACKEND_DETERMINISTIC_TEST
        exit
      end if
    end do
    column_is_routable = found_template .and. column%backend_id == FMR_BACKEND_DETERMINISTIC_TEST .and. &
         column%parameter_ref >= 1_int64 .and. column%parameter_ref <= int(size(parameters), int64) .and. &
         column%forcing_handle >= 1_int64 .and. column%forcing_handle <= int(size(forcings), int64)
  end function column_is_routable

  subroutine update_committed_provenance(committed, diagnostic)
    type(kernel_committed_state_t), intent(in) :: committed
    type(fmr_column_diagnostics_t), intent(inout) :: diagnostic
    logical :: available

    diagnostic%committed_revision = committed%current_revision()
    call committed%current_time(diagnostic%committed_time, available)
    diagnostic%committed_time_bound = available
  end subroutine update_committed_provenance

  subroutine build_aggregate(columns, diagnostics, worker_count, batches, aggregate)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_column_diagnostics_t), intent(in) :: diagnostics(:)
    integer, intent(in) :: worker_count, batches
    type(fmr_aggregate_diagnostics_t), intent(out) :: aggregate
    integer(int64), allocatable :: costs(:)
    integer :: i, worker_id, p95_index
    real(real64) :: total_cost

    aggregate%columns = size(columns)
    aggregate%templates = fmr_count_templates(columns)
    aggregate%batches = batches
    aggregate%workers = worker_count
    allocate(aggregate%work_distribution(worker_count))
    aggregate%work_distribution = 0_int64
    allocate(costs(size(columns)))
    total_cost = 0.0_real64

    do i = 1, size(columns)
      aggregate%attempts = aggregate%attempts + diagnostics(i)%attempts
      aggregate%retries = aggregate%retries + diagnostics(i)%retries
      if (diagnostics(i)%accepted == 0) aggregate%failures = aggregate%failures + 1
      aggregate%aggregate_unrounded_mass_residual = aggregate%aggregate_unrounded_mass_residual + &
           diagnostics(i)%unrounded_mass_residual
      costs(i) = diagnostics(i)%synthetic_cost
      total_cost = total_cost + real(costs(i), real64)
      if (costs(i) > aggregate%max_cost) aggregate%max_cost = costs(i)
      if (allocated(diagnostics(i)%worker_assignments)) then
        worker_id = diagnostics(i)%worker_assignments(1)
        if (worker_id >= 1 .and. worker_id <= worker_count) then
          aggregate%work_distribution(worker_id) = aggregate%work_distribution(worker_id) + costs(i)
        end if
      end if
    end do
    if (size(columns) > 0) aggregate%mean_cost = total_cost / real(size(columns), real64)
    call sort_int64(costs)
    if (size(costs) > 0) then
      p95_index = max(1, ceiling(0.95_real64 * real(size(costs), real64)))
      aggregate%p95_cost = real(costs(p95_index), real64)
    end if
  end subroutine build_aggregate

  subroutine sort_int64(values)
    integer(int64), intent(inout) :: values(:)
    integer(int64) :: key
    integer :: i, j

    do i = 2, size(values)
      key = values(i)
      j = i - 1
      do while (j >= 1)
        if (values(j) <= key) exit
        values(j + 1) = values(j)
        j = j - 1
      end do
      values(j + 1) = key
    end do
  end subroutine sort_int64

  subroutine build_memory_report(parameters, states, workers, memory)
    type(fmr_test_parameters_t), intent(in) :: parameters(:)
    type(kernel_committed_state_t), intent(in) :: states(:)
    type(fmr_deterministic_worker_t), intent(in) :: workers(:)
    type(fmr_memory_report_t), intent(out) :: memory
    type(fmr_test_state_t) :: state_probe

    memory%logical_runtime_metadata_bytes_per_column = fmr_metadata_bytes_per_column()
    memory%committed_physical_state_bytes_per_column = int(storage_size(state_probe) / 8, int64)
    if (size(states) > 0) then
      memory%committed_carrier_bytes_per_column = int(storage_size(states(1)) / 8, int64)
    end if
    if (size(parameters) > 0) then
      memory%shared_immutable_parameter_bytes = int(size(parameters), int64) * &
           int(storage_size(parameters(1)) / 8, int64)
    end if
    memory%optional_state_overhead_bytes = 0_int64
    if (size(workers) > 0) then
      memory%worker_scratch_bytes_per_worker = int(storage_size(workers(1)) / 8, int64)
    end if
  end subroutine build_memory_report

end module mod_fmr_deterministic_runtime
