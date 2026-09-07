program test_fmr01_runtime
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core
  use mod_fmr_deterministic_runtime
  implicit none

  integer :: failures

  failures = 0
  call test_template_contract(failures)
  call test_required_batch_sizes(failures)
  call test_order_partition_worker_independence(failures)
  call test_scratch_poison_and_worker_migration(failures)
  call test_difficult_tail_and_failure_isolation(failures)
  call test_hard_mass_rejection(failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'FMR01_RUNTIME_GATE FAIL failures=', failures
    error stop 1
  end if
  write(*,'(A)') 'FMR01_RUNTIME_GATE PASS'

contains

  subroutine expect_true(condition, label, failures)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    if (.not. condition) then
      failures = failures + 1
      write(*,'(A,A)') 'FAIL ', trim(label)
    end if
  end subroutine expect_true

  subroutine expect_bits(actual, expected, label, failures)
    real(real64), intent(in) :: actual, expected
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    call expect_true(transfer(actual, 0_int64) == transfer(expected, 0_int64), label, failures)
  end subroutine expect_bits

  subroutine test_template_contract(failures)
    integer, intent(inout) :: failures
    type(fmr_template_t) :: template

    template%template_id = 11_int64
    template%physics_topology_id = 101_int64
    template%state_layout_id = 201_int64
    template%compatible_backend_id = FMR_BACKEND_DETERMINISTIC_TEST
    call expect_true(fmr_assignment_compatible(template, 101_int64, 201_int64, &
         FMR_BACKEND_DETERMINISTIC_TEST), 'template compatible assignment accepted', failures)
    call expect_true(.not. fmr_assignment_compatible(template, 102_int64, 201_int64, &
         FMR_BACKEND_DETERMINISTIC_TEST), 'physics mismatch rejected', failures)
    call expect_true(.not. fmr_assignment_compatible(template, 101_int64, 202_int64, &
         FMR_BACKEND_DETERMINISTIC_TEST), 'state layout mismatch rejected', failures)
    call expect_true(.not. fmr_assignment_compatible(template, 101_int64, 201_int64, &
         FMR_BACKEND_PARALLEL_REFERENCE), 'parallel backend mismatch rejected', failures)
  end subroutine test_template_contract

  subroutine test_required_batch_sizes(failures)
    integer, intent(inout) :: failures
    integer, parameter :: sizes(7) = [1, 2, 8, 17, 31, 32, 64]
    integer :: i
    type(fmr_memory_report_t) :: memory17, memory64

    do i = 1, size(sizes)
      if (sizes(i) == 17) then
        call run_easy_case(sizes(i), 4, 17, 0, .false., failures, memory17)
      else if (sizes(i) == 64) then
        call run_easy_case(sizes(i), 4, 31, 0, .false., failures, memory64)
      else
        call run_easy_case(sizes(i), 4, max(1, sizes(i)), 0, .false., failures)
      end if
      write(*,'(A,I0,A)') 'FMR01_BATCH size=', sizes(i), ' PASS'
    end do

    call expect_true(memory17%logical_runtime_metadata_bytes_per_column > 0_int64, &
         'logical metadata bytes measured', failures)
    call expect_true(memory17%committed_physical_state_bytes_per_column > 0_int64, &
         'physical state bytes measured', failures)
    call expect_true(memory17%worker_scratch_bytes_per_worker > 0_int64, &
         'worker scratch bytes measured', failures)
    call expect_true(memory17%worker_scratch_bytes_per_worker == memory64%worker_scratch_bytes_per_worker, &
         'worker scratch per worker independent of column count', failures)
    call expect_true(memory17%shared_immutable_parameter_bytes == memory64%shared_immutable_parameter_bytes, &
         'shared parameter storage independent of column count', failures)
    call expect_true(memory64%optional_state_overhead_bytes == 0_int64, &
         'unused optional state has zero deterministic overhead', failures)
    write(*,'(A,5(I0,1X))') 'FMR01_MEMORY ', &
         memory64%logical_runtime_metadata_bytes_per_column, &
         memory64%committed_physical_state_bytes_per_column, &
         memory64%shared_immutable_parameter_bytes, &
         memory64%optional_state_overhead_bytes, &
         memory64%worker_scratch_bytes_per_worker
  end subroutine test_required_batch_sizes

  subroutine test_order_partition_worker_independence(failures)
    integer, intent(inout) :: failures
    integer, parameter :: n = 64
    integer, parameter :: worker_counts(4) = [1, 2, 4, 8]
    type(fmr_test_result_t), allocatable :: baseline(:), variant(:)
    type(fmr_column_diagnostics_t), allocatable :: baseline_diag(:), variant_diag(:)
    integer :: i

    call execute_case(n, 1, 17, 0, .false., .false., baseline, baseline_diag)
    do i = 1, size(worker_counts)
      call execute_case(n, worker_counts(i), 17, 0, .false., .false., variant, variant_diag)
      call compare_by_column_id(baseline, baseline_diag, variant, variant_diag, &
           'worker count independence', failures)
      write(*,'(A,I0,A)') 'FMR01_WORKERS workers=', worker_counts(i), ' PASS'
    end do

    call execute_case(n, 4, 31, 1, .false., .false., variant, variant_diag)
    call compare_by_column_id(baseline, baseline_diag, variant, variant_diag, &
         'reversed order and partition independence', failures)
    call execute_case(n, 4, 32, 2, .false., .false., variant, variant_diag)
    call compare_by_column_id(baseline, baseline_diag, variant, variant_diag, &
         'shuffle order and partition independence', failures)
  end subroutine test_order_partition_worker_independence

  subroutine test_scratch_poison_and_worker_migration(failures)
    integer, intent(inout) :: failures
    type(fmr_test_result_t), allocatable :: clean(:), poisoned(:), migrated(:)
    type(fmr_column_diagnostics_t), allocatable :: clean_diag(:), poison_diag(:), migrated_diag(:)

    call execute_case(32, 2, 17, 0, .false., .false., clean, clean_diag)
    call execute_case(32, 2, 17, 0, .true., .false., poisoned, poison_diag)
    call compare_by_column_id(clean, clean_diag, poisoned, poison_diag, &
         'poisoned worker scratch physical identity', failures)

    call execute_case(32, 8, 31, 1, .true., .false., migrated, migrated_diag)
    call compare_by_column_id(clean, clean_diag, migrated, migrated_diag, &
         'worker migration identity', failures)
  end subroutine test_scratch_poison_and_worker_migration

  subroutine test_difficult_tail_and_failure_isolation(failures)
    integer, intent(inout) :: failures
    type(fmr_test_result_t), allocatable :: results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    type(fmr_memory_report_t) :: memory
    integer :: i, accepted_easy, difficult_index
    integer(int64) :: max_easy_cost

    call execute_case(32, 4, 32, 0, .true., .true., results, diagnostics, aggregate, memory)
    accepted_easy = 0
    max_easy_cost = 0_int64
    difficult_index = find_result_index(results, 1_int64)
    do i = 1, size(results)
      if (results(i)%column_id /= 1_int64) then
        if (results(i)%completed) accepted_easy = accepted_easy + 1
        max_easy_cost = max(max_easy_cost, diagnostics(i)%synthetic_cost)
      end if
    end do
    call expect_true(accepted_easy == 31, '31 easy columns survive difficult tail', failures)
    call expect_true(results(difficult_index)%completed, 'difficult column eventually accepted', failures)
    call expect_true(diagnostics(difficult_index)%checkpoint_replays >= 2, &
         'difficult column replays same checkpoint', failures)
    call expect_true(diagnostics(difficult_index)%synthetic_cost > max_easy_cost, &
         'difficult column diagnosed with larger synthetic cost', failures)
    call expect_true(aggregate%failures == 0, 'difficult tail does not fail batch', failures)
    write(*,'(A,3(I0,1X))') 'FMR01_DIFFICULT_TAIL ', &
         diagnostics(difficult_index)%synthetic_cost, max_easy_cost, &
         diagnostics(difficult_index)%retries

    call execute_terminal_case(failures)
  end subroutine test_difficult_tail_and_failure_isolation

  subroutine execute_terminal_case(failures)
    integer, intent(inout) :: failures
    type(fmr_logical_column_t), allocatable :: columns(:)
    type(fmr_template_t), allocatable :: templates(:)
    type(fmr_test_parameters_t), allocatable :: parameters(:)
    type(fmr_test_forcing_t), allocatable :: forcings(:)
    type(kernel_committed_state_t), allocatable :: states(:)
    type(fmr_test_job_control_t), allocatable :: controls(:)
    type(fmr_test_result_t), allocatable :: results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    type(fmr_memory_report_t) :: memory
    type(canonical_numerical_config_t) :: config
    real(real64) :: initial_terminal
    integer :: i, idx

    call make_case(8, columns, templates, parameters, forcings, states, controls, config)
    controls(1)%terminal_failure = .true.
    controls(1)%max_runtime_retries = 2
    initial_terminal = fmr_committed_water(states(int(columns(1)%state_handle)))
    call fmr_run_deterministic(columns, templates, parameters, forcings, states, controls, config, &
         3.125_real64, 3.625_real64, 4, 8, results, diagnostics, aggregate, memory)
    idx = find_result_index(results, columns(1)%column_id)
    call expect_true(.not. results(idx)%completed, 'terminal column rejected', failures)
    call expect_bits(results(idx)%final_storage, initial_terminal, &
         'terminal failure leaves committed state unchanged', failures)
    call expect_true(trim(diagnostics(idx)%failure_classification) == 'TERMINAL_FAILURE', &
         'terminal failure classified', failures)
    do i = 2, size(results)
      call expect_true(results(i)%completed, 'terminal A does not change B', failures)
    end do
  end subroutine execute_terminal_case

  subroutine test_hard_mass_rejection(failures)
    integer, intent(inout) :: failures
    type(fmr_logical_column_t), allocatable :: columns(:)
    type(fmr_template_t), allocatable :: templates(:)
    type(fmr_test_parameters_t), allocatable :: parameters(:)
    type(fmr_test_forcing_t), allocatable :: forcings(:)
    type(kernel_committed_state_t), allocatable :: states(:)
    type(fmr_test_job_control_t), allocatable :: controls(:)
    type(fmr_test_result_t), allocatable :: results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    type(fmr_memory_report_t) :: memory
    type(canonical_numerical_config_t) :: config
    real(real64) :: initial
    integer :: idx

    call make_case(2, columns, templates, parameters, forcings, states, controls, config)
    controls(1)%inject_mass_defect = .true.
    controls(1)%max_runtime_retries = 1
    initial = fmr_committed_water(states(int(columns(1)%state_handle)))
    call fmr_run_deterministic(columns, templates, parameters, forcings, states, controls, config, &
         3.125_real64, 3.625_real64, 2, 2, results, diagnostics, aggregate, memory)
    idx = find_result_index(results, columns(1)%column_id)
    call expect_true(.not. results(idx)%completed, 'mass mismatch fails hard', failures)
    call expect_bits(results(idx)%final_storage, initial, 'mass mismatch cannot commit', failures)
    call expect_true(trim(diagnostics(idx)%failure_classification) == 'HARD_MASS_REJECTED', &
         'mass mismatch classified', failures)
    call expect_true(results(find_result_index(results, columns(2)%column_id))%completed, &
         'mass failure isolated from neighbor', failures)
  end subroutine test_hard_mass_rejection

  subroutine run_easy_case(n, workers, batch_size, order_mode, poison, failures, memory_out)
    integer, intent(in) :: n, workers, batch_size, order_mode
    logical, intent(in) :: poison
    integer, intent(inout) :: failures
    type(fmr_memory_report_t), intent(out), optional :: memory_out
    type(fmr_test_result_t), allocatable :: results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    type(fmr_memory_report_t) :: memory
    integer :: i

    call execute_case(n, workers, batch_size, order_mode, poison, .false., &
         results, diagnostics, aggregate, memory)
    do i = 1, n
      call expect_true(results(i)%completed, 'easy column completed', failures)
      call expect_true(diagnostics(i)%accepted == 1, 'easy column accepted', failures)
      call expect_true(abs(results(i)%unrounded_mass_residual) <= 1.0e-12_real64, &
           'per-column unrounded mass residual hard gate', failures)
      call expect_true(diagnostics(i)%checkpoint_captures == 1, &
           'one reusable checkpoint captured per column', failures)
    end do
    call expect_true(abs(aggregate%aggregate_unrounded_mass_residual) <= &
         1.0e-11_real64, 'aggregate unrounded mass residual hard gate', failures)
    if (present(memory_out)) memory_out = memory
  end subroutine run_easy_case

  subroutine execute_case(n, workers, batch_size, order_mode, poison, difficult, results, diagnostics, &
                          aggregate_out, memory_out)
    integer, intent(in) :: n, workers, batch_size, order_mode
    logical, intent(in) :: poison, difficult
    type(fmr_test_result_t), allocatable, intent(out) :: results(:)
    type(fmr_column_diagnostics_t), allocatable, intent(out) :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t), intent(out), optional :: aggregate_out
    type(fmr_memory_report_t), intent(out), optional :: memory_out
    type(fmr_logical_column_t), allocatable :: columns(:), ordered_columns(:)
    type(fmr_template_t), allocatable :: templates(:)
    type(fmr_test_parameters_t), allocatable :: parameters(:)
    type(fmr_test_forcing_t), allocatable :: forcings(:)
    type(kernel_committed_state_t), allocatable :: states(:)
    type(fmr_test_job_control_t), allocatable :: controls(:), ordered_controls(:)
    type(canonical_numerical_config_t) :: config
    type(fmr_aggregate_diagnostics_t) :: aggregate
    type(fmr_memory_report_t) :: memory
    integer, allocatable :: permutation(:)
    integer :: i

    call make_case(n, columns, templates, parameters, forcings, states, controls, config)
    if (difficult) then
      controls(1)%runtime_failures_before_success = 1
      controls(1)%internal_failures = 3
      controls(1)%max_runtime_retries = 2
      controls(1)%cost_weight = 64
      columns(1)%execution_class = FMR_EXECUTION_DIFFICULT
    end if
    call make_permutation(n, order_mode, permutation)
    allocate(ordered_columns(n), ordered_controls(n))
    do i = 1, n
      ordered_columns(i) = columns(permutation(i))
      ordered_controls(i) = controls(permutation(i))
    end do
    call fmr_run_deterministic(ordered_columns, templates, parameters, forcings, states, &
         ordered_controls, config, 3.125_real64, 3.625_real64, workers, batch_size, &
         results, diagnostics, aggregate, memory, poison)
    if (present(aggregate_out)) aggregate_out = aggregate
    if (present(memory_out)) memory_out = memory
  end subroutine execute_case

  subroutine make_case(n, columns, templates, parameters, forcings, states, controls, config)
    integer, intent(in) :: n
    type(fmr_logical_column_t), allocatable, intent(out) :: columns(:)
    type(fmr_template_t), allocatable, intent(out) :: templates(:)
    type(fmr_test_parameters_t), allocatable, intent(out) :: parameters(:)
    type(fmr_test_forcing_t), allocatable, intent(out) :: forcings(:)
    type(kernel_committed_state_t), allocatable, intent(out) :: states(:)
    type(fmr_test_job_control_t), allocatable, intent(out) :: controls(:)
    type(canonical_numerical_config_t), intent(out) :: config
    integer :: i
    logical :: ok

    allocate(columns(n), templates(2), parameters(2), forcings(n), states(n), controls(n))
    templates(1)%template_id = 101_int64
    templates(1)%physics_topology_id = 1001_int64
    templates(1)%vertical_layout_id = 2001_int64
    templates(1)%state_layout_id = 3001_int64
    templates(1)%solver_interface_id = 4001_int64
    templates(1)%compatible_backend_id = FMR_BACKEND_DETERMINISTIC_TEST
    templates(2) = templates(1)
    templates(2)%template_id = 102_int64
    templates(2)%physics_topology_id = 1002_int64
    parameters(1)%flux_scale = 1.0_real64
    parameters(2)%flux_scale = 0.5_real64

    do i = 1, n
      columns(i)%column_id = int(i, int64)
      columns(i)%template_id = merge(101_int64, 102_int64, mod(i, 2) == 1)
      columns(i)%parameter_ref = int(1 + mod(i, 2), int64)
      columns(i)%state_handle = int(i, int64)
      columns(i)%forcing_handle = int(i, int64)
      columns(i)%backend_id = FMR_BACKEND_DETERMINISTIC_TEST
      columns(i)%execution_class = FMR_EXECUTION_EASY
      forcings(i)%inflow_rate = 0.02_real64 + real(i, real64) * 1.0e-5_real64
      forcings(i)%outflow_rate = 0.005_real64 + real(mod(i, 7), real64) * 1.0e-6_real64
      call fmr_new_committed_state(states(i), columns(i)%column_id, &
           10.0_real64 + real(i, real64) * 0.01_real64, 3.125_real64, ok)
      if (.not. ok) error stop 'F-MR test state initialization failed'
      controls(i)%max_runtime_retries = 1
      controls(i)%cost_weight = 1
    end do

    config%transaction%temporal_tolerance = 1.0_real64
    config%transaction%mass_tolerance = 1.0e-12_real64
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 4
    config%max_committed_substeps = 64
    config%progress_tolerance = 0.0_real64
  end subroutine make_case

  subroutine make_permutation(n, mode, permutation)
    integer, intent(in) :: n, mode
    integer, allocatable, intent(out) :: permutation(:)
    integer :: i, odd_count, pos

    allocate(permutation(n))
    select case (mode)
    case (0)
      do i = 1, n
        permutation(i) = i
      end do
    case (1)
      do i = 1, n
        permutation(i) = n - i + 1
      end do
    case default
      odd_count = (n + 1) / 2
      pos = 0
      do i = 1, odd_count
        pos = pos + 1
        permutation(pos) = 2 * i - 1
      end do
      do i = 1, n / 2
        pos = pos + 1
        permutation(pos) = 2 * i
      end do
    end select
  end subroutine make_permutation

  subroutine compare_by_column_id(a, ad, b, bd, label, failures)
    type(fmr_test_result_t), intent(in) :: a(:), b(:)
    type(fmr_column_diagnostics_t), intent(in) :: ad(:), bd(:)
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    integer :: i, j

    do i = 1, size(a)
      j = find_result_index(b, a(i)%column_id)
      call expect_true(j > 0, trim(label)//' id present', failures)
      if (j <= 0) cycle
      call expect_true(a(i)%completed .eqv. b(j)%completed, trim(label)//' completion', failures)
      call expect_bits(a(i)%final_storage, b(j)%final_storage, trim(label)//' state', failures)
      call expect_bits(a(i)%unrounded_mass_residual, b(j)%unrounded_mass_residual, &
           trim(label)//' mass residual', failures)
      call expect_true(ad(i)%accepted == bd(j)%accepted, trim(label)//' accepted', failures)
      call expect_true(ad(i)%template_id == bd(j)%template_id, trim(label)//' template', failures)
    end do
  end subroutine compare_by_column_id

  integer function find_result_index(results, column_id) result(index)
    type(fmr_test_result_t), intent(in) :: results(:)
    integer(int64), intent(in) :: column_id
    integer :: i

    index = 0
    do i = 1, size(results)
      if (results(i)%column_id == column_id) then
        index = i
        return
      end if
    end do
  end function find_result_index

end program test_fmr01_runtime
