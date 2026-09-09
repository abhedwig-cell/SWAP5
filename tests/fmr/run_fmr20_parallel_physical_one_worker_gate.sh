#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr20-physical-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE_REF=origin/qualification/f-mq23-fvq14-real-physics-runtime
CORE=src/runtime/mod_fmr_runtime_core.f90
CORE_BLOB=543af573b34bfccd8fbdecf719af22994c5236b2
SERIAL_BACKEND=src/runtime/mod_fmr_serialized_reference_backend.f90
SERIAL_BACKEND_BLOB=ade399a1df4b582c9038442093ccacce034f923d
SERIAL_RUNTIME=src/runtime/mod_fmr_serialized_multiswap_runtime.f90
SERIAL_RUNTIME_BLOB=e4f5bc0bf47e2721d689e62107b5224196a093d9
SCHEDULER=src/runtime/mod_fmr_parallel_physical_scheduler.f90
SCHEDULER_BLOB=544a1ca16fdeebdfce7f89d1ddf1825fa32fa654
POOL=src/runtime/mod_fmr_parallel_worker_pool.f90
POOL_BLOB=ee5ddff3312e400abfe84b31895711a7be0be923
TEST=tests/fmr/test_fmr20_parallel_physical_one_worker.f90
TEST_BLOB=649a34e7c9e05d3fe47b15adcad8abe101ee2ad3

fail() { echo "FMR20_PHYSICAL_GATE_FAIL $*" >&2; exit 1; }

for spec in \
  "$CORE:$CORE_BLOB" \
  "$SERIAL_BACKEND:$SERIAL_BACKEND_BLOB" \
  "$SERIAL_RUNTIME:$SERIAL_RUNTIME_BLOB" \
  "$SCHEDULER:$SCHEDULER_BLOB" \
  "$POOL:$POOL_BLOB" \
  "$TEST:$TEST_BLOB"; do
  path="${spec%%:*}"
  blob="${spec##*:}"
  [[ "$(git rev-parse HEAD:"$path")" == "$blob" ]] || fail "source lock drift $path"
done
echo 'FMR20_P01_SOURCE_LOCK=PASS'

git fetch --quiet --no-tags origin \
  qualification/f-mq23-fvq14-real-physics-runtime:refs/remotes/origin/qualification/f-mq23-fvq14-real-physics-runtime
git diff --name-only "$BASE_REF" HEAD -- src > "$BUILD/src.changed"
printf '%s\n' \
  src/runtime/mod_fmr_parallel_physical_scheduler.f90 \
  src/runtime/mod_fmr_parallel_worker_pool.f90 > "$BUILD/src.expected"
diff -u "$BUILD/src.expected" "$BUILD/src.changed" >/dev/null || {
  diff -u "$BUILD/src.expected" "$BUILD/src.changed" >&2 || true
  fail 'production source scope differs from two additive MR20 modules'
}
echo 'FMR20_P02_ADDITIVE_SOURCE_SCOPE_ONLY=PASS'

python3 - <<'PY'
from pathlib import Path
scheduler = Path('src/runtime/mod_fmr_parallel_physical_scheduler.f90').read_text().lower()
pool = Path('src/runtime/mod_fmr_parallel_worker_pool.f90').read_text().lower()
for forbidden in ['!$omp', 'omp_lib', 'call headcalc(', 'use variables', 'use mod_grid', 'use mod_snow', 'use mod_drain', 'use mod_irrigation']:
    assert forbidden not in scheduler, f'scheduler boundary leak: {forbidden}'
    assert forbidden not in pool, f'pool boundary leak: {forbidden}'
for required in ['fmr_build_execution_order', 'mod(pos - 1, worker_count) + 1', 'canonical_position', 'worker_id']:
    assert required in scheduler, f'missing deterministic scheduler token: {required}'
for required in ['worker_count /= 1', 'fmr_parallel_pool_multiworker_not_admitted',
                 'fmr_run_serialized_physical_multiswap', 'multiworker_not_admitted']:
    assert required in pool, f'missing fail-closed pool token: {required}'
assert pool.index('worker_count /= 1') < pool.index('call fmr_run_serialized_physical_multiswap'), \
    'serialized physical delegate reachable before multiworker rejection'
print('FMR20_P03_NO_DIRECT_LEGACY_OR_OPENMP_BOUNDARY_LEAK=PASS')
print('FMR20_P04_MULTIWORKER_FAILS_BEFORE_SERIALIZED_PHYSICS=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
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
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/runtime/mod_fmr_parallel_physical_scheduler.f90
  src/runtime/mod_fmr_parallel_worker_pool.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c "$TEST" -o "$OUT/test_fmr20_physical.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test_fmr20_physical.o" -o "$OUT/fmr20_physical"
  "$OUT/fmr20_physical" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }

  for marker in \
    FMR20_PRODUCTION_SCHEDULER_CANONICAL_IDENTITY=PASS \
    FMR20_PRODUCTION_SCHEDULER_INVALID_WORKER_FAIL_CLOSED=PASS \
    FMR20_ONE_WORKER_MQ23_RESULT_IDENTITY=PASS \
    FMR20_ONE_WORKER_MQ23_DIAGNOSTIC_IDENTITY=PASS \
    FMR20_ONE_WORKER_MQ23_AGGREGATE_IDENTITY=PASS \
    FMR20_ONE_WORKER_MQ23_RUNTIME_DIAGNOSTIC_IDENTITY=PASS \
    FMR20_ONE_WORKER_MQ23_COMMITTED_STATE_IDENTITY=PASS \
    FMR20_ONE_WORKER_HARD_MASS_GATE=PASS \
    FMR20_MULTIWORKER_REAL_PHYSICS_NOT_ADMITTED=PASS \
    FMR20_MULTIWORKER_ZERO_PHYSICAL_SOLVES=PASS \
    FMR20_MULTIWORKER_COMMITTED_STATE_NONMUTATION=PASS \
    FMR20_ZERO_WORKER_FAIL_CLOSED=PASS \
    'FMR20_PARALLEL_PHYSICAL_ONE_WORKER_TEST PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || fail "missing marker O$opt: $marker"
  done
  echo "FMR20_PHYSICAL_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 output identity'
}
echo 'FMR20_P05_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo 'FMR20_PARALLEL_PHYSICAL_ONE_WORKER_GATE=PASS'
