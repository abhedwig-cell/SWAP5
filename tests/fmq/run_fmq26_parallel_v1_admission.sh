#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmq26-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FMQ26_GATE_FAIL $*" >&2; exit 1; }
CANDIDATE=4b6807c1d78c0c7d8bfe0f7a03a4c6c07d4444b9

[[ -z "$(git diff --name-only "$CANDIDATE"..HEAD -- src)" ]] || fail 'production source drift'
for spec in \
  src/runtime/mod_fmr_runtime_core.f90:adc2b7514cc062c0cde4e71582ba8ed7776a7335 \
  src/runtime/mod_fmr_serialized_reference_backend.f90:e0432faa0e05a3c136ee5aed6fddb12ad631848d \
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90:be4005a97e35c498ffc40297409a75efe65ff5df \
  src/adapter/mod_reference_richards_legacy_binding.f90:1c7be9119986eb8ad3bd3c00b0b3b3afb4ed68ff \
  src/legacy/b1_10_port/headcalc.f90:04c4877754b39161d5afa0f2496a015fd3334cc5 \
  src/runtime/mod_fmr_parallel_physical_scheduler.f90:544a1ca16fdeebdfce7f89d1ddf1825fa32fa654 \
  src/runtime/mod_fmr_parallel_worker_pool.f90:393e9bfbc4c078d259a5ec70aca78f50e54e8b35; do
  path="${spec%%:*}"
  blob="${spec##*:}"
  [[ "$(git rev-parse HEAD:"$path")" == "$blob" ]] || fail "source lock drift: $path"
done
echo 'FMQ26_SOURCE_LOCK=PASS'

python3 - <<'PY'
from pathlib import Path
pool = Path('src/runtime/mod_fmr_parallel_worker_pool.f90').read_text(encoding='utf-8').lower()
backend = Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text(encoding='utf-8').lower()
scheduler = Path('src/runtime/mod_fmr_parallel_physical_scheduler.f90').read_text(encoding='utf-8').lower()
flat_pool = ' '.join(pool.split())
flat_backend = ' '.join(backend.split())
flat_scheduler = ' '.join(scheduler.split())

assert 'type(fmr_serialized_reference_backend_t), allocatable :: backends(:)' in flat_pool
assert 'type(kernel_executor_t), allocatable :: transaction_controls(:)' in flat_pool
assert 'allocate(backends(worker_count), transaction_controls(worker_count), worker_runtime(worker_count))' in flat_pool
assert '!$omp parallel num_threads(worker_count)' in pool
assert 'fmr_execute_serialized_physical_column(backends(w), transaction_controls(w)' in flat_pool
assert 'allocate(backends(size(columns))' not in flat_pool
assert 'type(reference_richards_legacy_solver_t) :: solver' in flat_backend
assert 'type(reference_richards_legacy_workspace_t) :: workspace' in flat_backend
assert 'type(fmr_serialized_reference_model_t) :: model' in flat_backend
assert 'call fmr_build_execution_order(columns, order)' in flat_scheduler
assert 'assignments(pos)%worker_id = mod(pos - 1, worker_count) + 1' in flat_scheduler
assert 'do pos = 1, size(assignments)' in flat_pool
print('FMQ26_WORKER_OWNED_HEAVY_SOLVER_WORKSPACE=PASS')
print('FMQ26_NO_PER_COLUMN_HEAVY_SOLVER_OWNERSHIP=PASS')
print('FMQ26_CANONICAL_SCHEDULER_REDUCTION_SEAM=PASS')
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

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmq/test_fmq26_parallel_v1_admission.f90 -o "$OUT/test.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "O$opt positive executable"; }

  while read -r n b o; do
    grep -Fq "FMQ26_POSITIVE_N${n}_B${b}_O${o}=PASS" "$OUT/output.txt" || fail "missing O$opt positive n=$n b=$b order=$o"
  done <<'CASES'
2 1 0
2 2 1
7 2 2
7 3 3
7 7 0
8 3 1
8 5 2
17 4 3
17 9 0
31 7 1
31 16 2
32 8 3
32 9 0
32 17 1
CASES

  for marker in \
    FMQ26_INPUT_ORDER_INDEPENDENCE=PASS \
    FMQ26_REJECTION_AT_BATCH_BOUNDARY=PASS \
    FMQ26_REJECTION_INTERIOR=PASS \
    FMQ26_TWO_WORKER_SEPARATED_REJECTIONS=PASS \
    FMQ26_UNSUPPORTED_PROFILES_FAIL_CLOSED=PASS \
    FMQ26_TRUE_MULTIWORKER_OVERLAP_CONTROL=PASS \
    FMQ26_HARD_MASS_ALL_CASES=PASS \
    FMQ26_WORKER_COUNT_INDEPENDENCE=PASS \
    FMQ26_DETERMINISTIC_REPLAY=PASS \
    'FMQ26_PARALLEL_V1_ADMISSION_TEST PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || fail "missing O$opt marker: $marker"
  done
  echo "FMQ26_O${opt}_POSITIVE_MATRIX=PASS"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmq/test_fmq26_canonical_publication_order.f90 -o "$OUT/publication.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/publication.o" -o "$OUT/publication"
  set +e
  "$OUT/publication" > "$OUT/publication_output.txt" 2>&1
  rc=$?
  set -e
  cat "$OUT/publication_output.txt"
  [[ $rc -eq 26 ]] || fail "O$opt publication-order sentinel rc=$rc"
  for marker in \
    FMQ26_CANONICAL_PUBLICATION_ORDER=FAIL \
    FMQ26_INPUT_ORDER_LEAKS_INTO_PUBLISHED_ARRAY_ORDER=OBSERVED; do
    grep -Fq "$marker" "$OUT/publication_output.txt" || fail "missing O$opt publication marker: $marker"
  done
  grep '^FMQ26_' "$OUT/publication_output.txt" > "$OUT/publication_markers.txt"
  echo "FMQ26_O${opt}_PUBLICATION_ORDER_VIOLATION_REPRODUCED=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'positive O0/O2 output identity'
}
echo 'FMQ26_O0_O2_POSITIVE_OUTPUT_IDENTITY=PASS'
cmp -s "$BUILD/o0/publication_markers.txt" "$BUILD/o2/publication_markers.txt" || {
  diff -u "$BUILD/o0/publication_markers.txt" "$BUILD/o2/publication_markers.txt" >&2 || true
  fail 'publication-defect O0/O2 identity'
}
echo 'FMQ26_O0_O2_PUBLICATION_DEFECT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo 'FMQ26_CANDIDATE_CANONICAL_PUBLICATION_ORDER_VIOLATION=OBSERVED'
echo 'FMQ26_DECISION=NOT_QUALIFIED'
exit 26
