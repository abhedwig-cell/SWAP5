#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr20-v1-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FMR20_V1_GATE_FAIL $*" >&2; exit 1; }

for spec in \
  src/runtime/mod_fmr_runtime_core.f90:adc2b7514cc062c0cde4e71582ba8ed7776a7335 \
  src/runtime/mod_fmr_serialized_reference_backend.f90:e0432faa0e05a3c136ee5aed6fddb12ad631848d \
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90:be4005a97e35c498ffc40297409a75efe65ff5df \
  src/adapter/mod_reference_richards_legacy_binding.f90:1c7be9119986eb8ad3bd3c00b0b3b3afb4ed68ff \
  src/legacy/b1_10_port/headcalc.f90:04c4877754b39161d5afa0f2496a015fd3334cc5 \
  src/runtime/mod_fmr_parallel_physical_scheduler.f90:544a1ca16fdeebdfce7f89d1ddf1825fa32fa654 \
  src/runtime/mod_fmr_parallel_worker_pool.f90:393e9bfbc4c078d259a5ec70aca78f50e54e8b35 \
  tests/fmr/test_fmr20_parallel_v1_qualification.f90:bfebfde94b3931367d69d502a6fc7b1deb8f2ad6; do
  path="${spec%%:*}"
  blob="${spec##*:}"
  [[ "$(git rev-parse HEAD:"$path")" == "$blob" ]] || fail "source lock drift: $path"
done
echo 'FMR20_V1_G01_SOURCE_LOCK=PASS'

python3 - <<'PY'
from pathlib import Path
pool = Path('src/runtime/mod_fmr_parallel_worker_pool.f90').read_text().lower()
serial = Path('src/runtime/mod_fmr_serialized_multiswap_runtime.f90').read_text().lower()
head = Path('src/legacy/b1_10_port/headcalc.f90').read_text().lower()
backend = Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text().lower()
assert 'use omp_lib' in pool
assert '!$omp parallel num_threads(worker_count)' in pool
assert '!$omp barrier' in pool
assert 'type(fmr_serialized_reference_backend_t), allocatable :: backends(:)' in pool
assert 'call fmr_execute_serialized_physical_column(backends(w)' in pool
assert 'worker_count == 1' in pool
assert 'worker_count /= 2 .and. worker_count /= 4' in pool
assert 'type is (fixed_flux_top_boundary_provider_t)' in pool
assert 'parameter_registry(parameter_index)%bottom_mode /= 7' in pool
assert 'parameter_registry(parameter_index)%swkimpl /= 0' in pool
assert 'state_claimed(state_index)' in pool
assert 'public :: fmr_execute_serialized_physical_column' in serial
assert '!$omp atomic capture' in serial
assert '!$omp atomic update' in serial
assert 'bind_b110_serialized_legacy_context' not in backend
assert 'at_min_dt = ctx%control%at_min_dt' in head
assert 'day_start_event = ctx%time%day_start_event' in head
print('FMR20_V1_G02_PARALLEL_ARCHITECTURE_LOCK=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/runtime/mod_fmr_parallel_physical_scheduler.f90
  src/runtime/mod_fmr_parallel_worker_pool.f90
)

export OMP_DYNAMIC=FALSE
export OMP_THREAD_LIMIT=4
export OMP_PROC_BIND=spread
export OMP_PLACES=cores

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/fmr/test_fmr20_parallel_v1_qualification.f90 -o "$OUT/test.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }
  for marker in \
    FMR20_V1_SERIAL_REFERENCE=PASS \
    FMR20_V1_REAL_OVERLAP_2_WORKERS=PASS \
    FMR20_V1_REAL_OVERLAP_4_WORKERS=PASS \
    FMR20_V1_SERIAL_VS_2_WORKER_IDENTITY=PASS \
    FMR20_V1_SERIAL_VS_4_WORKER_IDENTITY=PASS \
    FMR20_V1_WORKER_COUNT_INDEPENDENCE=PASS \
    FMR20_V1_A_B_A_REPEATABILITY=PASS \
    FMR20_V1_INPUT_ORDER_INDEPENDENCE=PASS \
    FMR20_V1_CROSS_COLUMN_REJECTION_ISOLATION=PASS \
    FMR20_V1_NEGATIVE_PROFILE_FAIL_CLOSED=PASS \
    FMR20_V1_SHARED_PARAMETER_INTEGRITY=PASS \
    'FMR20_PARALLEL_V1_QUALIFICATION_TEST PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || fail "missing O$opt marker: $marker"
  done
  echo "FMR20_V1_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 output identity'
}
echo 'FMR20_V1_G03_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo 'FMR20_PARALLEL_V1_QUALIFICATION_GATE=PASS'
