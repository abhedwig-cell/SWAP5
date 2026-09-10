from pathlib import Path
import subprocess

SERIAL = Path('src/runtime/mod_fmr_serialized_multiswap_runtime.f90')
POOL = Path('src/runtime/mod_fmr_parallel_worker_pool.f90')
EXPECTED = {
    str(SERIAL): 'be4005a97e35c498ffc40297409a75efe65ff5df',
    str(POOL): '393e9bfbc4c078d259a5ec70aca78f50e54e8b35',
}

def blob(path):
    return subprocess.check_output(['git','rev-parse',f'HEAD:{path}'], text=True).strip()

def replace_once(text, old, new, label):
    n = text.count(old)
    if n != 1:
        raise SystemExit(f'FMR20R_FAIL {label}: expected 1 occurrence, found {n}')
    return text.replace(old, new, 1)

for path, expected in EXPECTED.items():
    actual = blob(path)
    if actual != expected:
        raise SystemExit(f'FMR20R_FAIL preimage {path}: {actual} != {expected}')
print('FMR20R_G01_PREIMAGE_LOCK=PASS')

s = SERIAL.read_text()
s = replace_once(s,
"  public :: fmr_run_serialized_physical_multiswap\n  public :: fmr_execute_serialized_physical_column\n",
"  public :: fmr_run_serialized_physical_multiswap\n  public :: fmr_execute_serialized_physical_column\n  public :: fmr_publish_canonical_column_outputs\n",
'public helper')
s = replace_once(s,
"    call initialize_runtime_diagnostics(size(columns), t0, t1, local_runtime)\n    active_physical_calls = 0\n",
"    call initialize_runtime_diagnostics(size(columns), t0, t1, local_runtime)\n    call fmr_build_execution_order(columns, order)\n    active_physical_calls = 0\n",
'early canonical order')
s = replace_once(s,
"      call build_aggregate(columns, diagnostics, 0, aggregate)\n      call finalize_runtime_diagnostics(results, local_runtime)\n      if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime\n      return\n    end if\n\n    if (.not. registry_structure_valid(columns, templates, state_registry)) then",
"      call build_aggregate(columns, diagnostics, 0, aggregate)\n      call finalize_runtime_diagnostics(results, local_runtime)\n      call fmr_publish_canonical_column_outputs(results, diagnostics, order)\n      if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime\n      return\n    end if\n\n    if (.not. registry_structure_valid(columns, templates, state_registry)) then",
'invalid request publication')
s = replace_once(s,
"      call build_aggregate(columns, diagnostics, 0, aggregate)\n      call finalize_runtime_diagnostics(results, local_runtime)\n      if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime\n      return\n    end if\n\n    call backend%initialize(top_boundary)\n    call fmr_build_execution_order(columns, order)\n",
"      call build_aggregate(columns, diagnostics, 0, aggregate)\n      call finalize_runtime_diagnostics(results, local_runtime)\n      call fmr_publish_canonical_column_outputs(results, diagnostics, order)\n      if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime\n      return\n    end if\n\n    call backend%initialize(top_boundary)\n",
'registry rejection publication')
s = replace_once(s,
"    call build_aggregate(columns, diagnostics, batches, aggregate, order)\n    call finalize_runtime_diagnostics(results, local_runtime, order)\n    if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime\n  end subroutine fmr_run_serialized_physical_multiswap\n\n  subroutine initialize_outputs",
"    call build_aggregate(columns, diagnostics, batches, aggregate, order)\n    call finalize_runtime_diagnostics(results, local_runtime, order)\n    call fmr_publish_canonical_column_outputs(results, diagnostics, order)\n    if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime\n  end subroutine fmr_run_serialized_physical_multiswap\n\n  subroutine fmr_publish_canonical_column_outputs(results, diagnostics, order)\n    type(fmr_serialized_column_result_t), allocatable, intent(inout) :: results(:)\n    type(fmr_column_diagnostics_t), allocatable, intent(inout) :: diagnostics(:)\n    integer, intent(in) :: order(:)\n    type(fmr_serialized_column_result_t), allocatable :: canonical_results(:)\n    type(fmr_column_diagnostics_t), allocatable :: canonical_diagnostics(:)\n    integer :: pos\n\n    if (size(order) /= size(results) .or. size(order) /= size(diagnostics)) &\n         error stop 'F-MR20R canonical publication order shape mismatch'\n    allocate(canonical_results(size(results)), canonical_diagnostics(size(diagnostics)))\n    do pos = 1, size(order)\n      if (order(pos) < 1 .or. order(pos) > size(results)) &\n           error stop 'F-MR20R canonical publication order index invalid'\n      canonical_results(pos) = results(order(pos))\n      canonical_diagnostics(pos) = diagnostics(order(pos))\n    end do\n    call move_alloc(canonical_results, results)\n    call move_alloc(canonical_diagnostics, diagnostics)\n  end subroutine fmr_publish_canonical_column_outputs\n\n  subroutine initialize_outputs",
'canonical publication helper')
SERIAL.write_text(s)
print('FMR20R_G02_SERIALIZED_PUBLICATION_PATCH=PASS')

p = POOL.read_text()
p = replace_once(p,
"       fmr_aggregate_diagnostics_t, fmr_count_templates, FMR_BACKEND_SERIALIZED_REFERENCE, &\n",
"       fmr_aggregate_diagnostics_t, fmr_count_templates, fmr_build_execution_order, FMR_BACKEND_SERIALIZED_REFERENCE, &\n",
'pool execution order import')
p = replace_once(p,
"       fmr_serialized_batch_diagnostics_t, fmr_run_serialized_physical_multiswap, &\n       fmr_execute_serialized_physical_column, FMR_SERIAL_DISPATCH_OK\n",
"       fmr_serialized_batch_diagnostics_t, fmr_run_serialized_physical_multiswap, &\n       fmr_execute_serialized_physical_column, fmr_publish_canonical_column_outputs, FMR_SERIAL_DISPATCH_OK\n",
'pool publication helper import')
p = replace_once(p,
"    type(fmr_parallel_assignment_t), allocatable :: assignments(:)\n",
"    type(fmr_parallel_assignment_t), allocatable :: assignments(:)\n    integer, allocatable :: publication_order(:)\n",
'pool publication order declaration')
p = replace_once(p,
"    serialized_dispatch_status = -1\n    pool_status = FMR_PARALLEL_POOL_INVALID_WORKER_COUNT\n\n    call fmr_build_parallel_schedule(columns, worker_count, assignments, schedule_status)\n",
"    serialized_dispatch_status = -1\n    pool_status = FMR_PARALLEL_POOL_INVALID_WORKER_COUNT\n\n    call fmr_build_execution_order(columns, publication_order)\n    call fmr_build_parallel_schedule(columns, worker_count, assignments, schedule_status)\n",
'pool canonical order construction')
p = replace_once(p,
"      call initialize_rejected_outputs(columns, t0, t1, 'INVALID_WORKER_COUNT', &\n           results, diagnostics, aggregate, local_runtime)\n      if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime\n",
"      call initialize_rejected_outputs(columns, t0, t1, 'INVALID_WORKER_COUNT', &\n           results, diagnostics, aggregate, local_runtime)\n      call fmr_publish_canonical_column_outputs(results, diagnostics, publication_order)\n      if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime\n",
'invalid worker publication')
p = replace_once(p,
"      call initialize_rejected_outputs(columns, t0, t1, 'MULTIWORKER_NOT_ADMITTED', &\n           results, diagnostics, aggregate, local_runtime)\n      if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime\n",
"      call initialize_rejected_outputs(columns, t0, t1, 'MULTIWORKER_NOT_ADMITTED', &\n           results, diagnostics, aggregate, local_runtime)\n      call fmr_publish_canonical_column_outputs(results, diagnostics, publication_order)\n      if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime\n",
'profile rejection publication')
p = replace_once(p,
"      call initialize_rejected_outputs(columns, t0, t1, 'OPENMP_TEAM_NOT_ADMITTED', &\n           results, diagnostics, aggregate, local_runtime)\n      if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime\n",
"      call initialize_rejected_outputs(columns, t0, t1, 'OPENMP_TEAM_NOT_ADMITTED', &\n           results, diagnostics, aggregate, local_runtime)\n      call fmr_publish_canonical_column_outputs(results, diagnostics, publication_order)\n      if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime\n",
'openmp rejection publication')
p = replace_once(p,
"    call build_parallel_aggregate(columns, diagnostics, assignments, batch_size, worker_count, aggregate)\n    call finalize_parallel_runtime(results, assignments, worker_runtime, t0, t1, local_runtime)\n    serialized_dispatch_status = FMR_SERIAL_DISPATCH_OK\n",
"    call build_parallel_aggregate(columns, diagnostics, assignments, batch_size, worker_count, aggregate)\n    call finalize_parallel_runtime(results, assignments, worker_runtime, t0, t1, local_runtime)\n    call fmr_publish_canonical_column_outputs(results, diagnostics, publication_order)\n    serialized_dispatch_status = FMR_SERIAL_DISPATCH_OK\n",
'success publication')
POOL.write_text(p)
print('FMR20R_G03_PARALLEL_PUBLICATION_PATCH=PASS')
print('FMR20R_MATERIALIZATION=PASS')
