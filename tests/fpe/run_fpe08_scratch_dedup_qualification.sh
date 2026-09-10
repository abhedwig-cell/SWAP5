#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpe08-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=5a78543cc744f8ff547575b3bdbbb56615dd9cc3
fail() { echo "FPE08_GATE_FAIL $*" >&2; exit 1; }

for spec in \
  src/runtime/mod_fmr_runtime_core.f90:adc2b7514cc062c0cde4e71582ba8ed7776a7335 \
  src/runtime/mod_fmr_serialized_reference_backend.f90:e0432faa0e05a3c136ee5aed6fddb12ad631848d \
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90:be4005a97e35c498ffc40297409a75efe65ff5df \
  src/runtime/mod_a23bu_worker_execution_context.f90:0ecb09bfa318a284e7841749d474d2f871363c81 \
  src/solver/mod_reference_richards_workspace.f90:59ef9d037c1875610d45ac83387ebab9e917e0fe \
  src/adapter/mod_reference_richards_legacy_binding.f90:1e3a227883cb2a0f79e40a22f016e7953d5fbab1 \
  src/legacy/b1_10_port/headcalc.f90:04c4877754b39161d5afa0f2496a015fd3334cc5 \
  src/runtime/mod_fmr_parallel_physical_scheduler.f90:544a1ca16fdeebdfce7f89d1ddf1825fa32fa654 \
  src/runtime/mod_fmr_parallel_worker_pool.f90:393e9bfbc4c078d259a5ec70aca78f50e54e8b35 \
  tests/fmr/test_fmr20_parallel_v1_qualification.f90:bfebfde94b3931367d69d502a6fc7b1deb8f2ad6 \
  tests/fpe/test_fpe08_scratch_dedup.f90:3b9ae676b5e38a782336af80cfd6515f30bac848; do
  path="${spec%%:*}"
  blob="${spec##*:}"
  [[ "$(git rev-parse HEAD:"$path")" == "$blob" ]] || fail "source lock drift: $path"
done
echo 'FPE08_G01_SOURCE_LOCK=PASS'

if ! git cat-file -e "$BASE^{commit}" 2>/dev/null; then
  git fetch --quiet --no-tags --depth=1 origin "$BASE"
fi
git diff --name-only "$BASE" HEAD -- src | sort > "$BUILD/src.changed"
printf '%s\n' \
  src/adapter/mod_reference_richards_legacy_binding.f90 \
  src/runtime/mod_a23bu_worker_execution_context.f90 | sort > "$BUILD/src.expected"
diff -u "$BUILD/src.expected" "$BUILD/src.changed" >/dev/null || {
  diff -u "$BUILD/src.expected" "$BUILD/src.changed" >&2 || true
  fail 'production source scope differs from exact two-file optimization'
}
echo 'FPE08_G02_BOUNDED_PRODUCTION_SCOPE=PASS'

python3 - <<'PY'
from pathlib import Path
a23=Path('src/runtime/mod_a23bu_worker_execution_context.f90').read_text()
binding=Path('src/adapter/mod_reference_richards_legacy_binding.f90').read_text()
head=Path('src/legacy/b1_10_port/headcalc.f90').read_text()
assert 'logical, intent(in), optional :: allocate_headcalc_scratch' in a23
assert 'allocate_scratch = .true.' in a23
assert 'if (present(allocate_headcalc_scratch)) allocate_scratch = allocate_headcalc_scratch' in a23
assert a23.count('if (allocate_scratch) then') == 1
assert binding.count('call a23bu_initialize_worker(ws%legacy_worker, n, allocate_headcalc_scratch=.false.)') == 1
assert 'ctx%headcalc' not in head
assert 'if (ctx%active_nodes /= numnod) call a23bu_initialize_worker(ctx, numnod)' in head
print('FPE08_G03_DEFAULT_ON_API_AND_CANONICAL_OPT_OUT=PASS')
print('FPE08_G04_HEADCALC_CANONICAL_SCRATCH_NONUSE=PASS')
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

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpe/test_fpe08_scratch_dedup.f90 -o "$OUT/memory_test.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/memory_test.o" -o "$OUT/memory_test"
  "$OUT/memory_test" > "$OUT/memory.txt" 2>&1 || { cat "$OUT/memory.txt" >&2; exit 1; }
  for marker in \
    'FPE08_DEFAULT_SCRATCH_BYTES=412' \
    'FPE08_CANONICAL_LEAN_SCRATCH_BYTES=0' \
    'FPE08_KNOWN_WORKER_PAYLOAD_BEFORE_BYTES=2792' \
    'FPE08_KNOWN_WORKER_PAYLOAD_AFTER_BYTES=2380' \
    'FPE08_REMOVED_BYTES_FOUR_NODE_FIXTURE=412' \
    'FPE08_SCRATCH_DEDUP_PROBE PASS'; do
    grep -Fq "$marker" "$OUT/memory.txt" || fail "missing O$opt memory marker: $marker"
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/test_fmr20_parallel_v1_qualification.f90 -o "$OUT/science_test.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/science_test.o" -o "$OUT/science_test"
  "$OUT/science_test" > "$OUT/science.txt" 2>&1 || { cat "$OUT/science.txt" >&2; exit 1; }
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
    grep -Fq "$marker" "$OUT/science.txt" || fail "missing O$opt science marker: $marker"
  done
  echo "FPE08_O${opt}=PASS"
done

cmp -s "$BUILD/o0/memory.txt" "$BUILD/o2/memory.txt" || {
  diff -u "$BUILD/o0/memory.txt" "$BUILD/o2/memory.txt" >&2 || true
  fail 'O0/O2 memory-probe output identity'
}
cmp -s "$BUILD/o0/science.txt" "$BUILD/o2/science.txt" || {
  diff -u "$BUILD/o0/science.txt" "$BUILD/o2/science.txt" >&2 || true
  fail 'O0/O2 scientific output identity'
}
echo 'FPE08_G05_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/memory.txt"
cat "$BUILD/o0/science.txt"
echo 'FPE08_SCRATCH_DEDUP_QUALIFICATION_GATE=PASS'
