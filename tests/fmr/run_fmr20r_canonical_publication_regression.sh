#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr20r-$$"
mkdir -p "$BUILD/fmq26"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FMR20R_GATE_FAIL $*" >&2; exit 1; }
BASE=4b6807c1d78c0c7d8bfe0f7a03a4c6c07d4444b9
BASE_REF=refs/remotes/origin/fmr20r-rejected-candidate
FMQ26_REF=refs/remotes/origin/fmr20r-fmq26-evidence

# Exact remediation postimage locks.
for spec in \
  src/runtime/mod_fmr_runtime_core.f90:adc2b7514cc062c0cde4e71582ba8ed7776a7335 \
  src/runtime/mod_fmr_serialized_reference_backend.f90:e0432faa0e05a3c136ee5aed6fddb12ad631848d \
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90:139c7f5e4e6c4337fb8d41af2e7a83056ebc9bcf \
  src/adapter/mod_reference_richards_legacy_binding.f90:1c7be9119986eb8ad3bd3c00b0b3b3afb4ed68ff \
  src/legacy/b1_10_port/headcalc.f90:04c4877754b39161d5afa0f2496a015fd3334cc5 \
  src/runtime/mod_fmr_parallel_physical_scheduler.f90:544a1ca16fdeebdfce7f89d1ddf1825fa32fa654 \
  src/runtime/mod_fmr_parallel_worker_pool.f90:b2adb1118df40fcba42e191eb098b78a2c57e802; do
  path="${spec%%:*}"; blob="${spec##*:}"
  [[ "$(git rev-parse HEAD:"$path")" == "$blob" ]] || fail "source lock drift: $path"
done
echo 'FMR20R_G01_POSTIMAGE_SOURCE_LOCK=PASS'

# Reconcile exact independently rejected candidate and bound source delta.
git fetch --quiet --no-tags --depth=1 origin "$BASE:$BASE_REF"
[[ "$(git rev-parse "$BASE_REF")" == "$BASE" ]] || fail 'rejected candidate drift'
git diff --name-only "$BASE_REF" HEAD -- src > "$BUILD/src.changed"
printf '%s\n' \
  src/runtime/mod_fmr_parallel_worker_pool.f90 \
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90 > "$BUILD/src.expected"
diff -u "$BUILD/src.expected" "$BUILD/src.changed" >/dev/null || {
  diff -u "$BUILD/src.expected" "$BUILD/src.changed" >&2 || true
  fail 'remediation source scope widened'
}
echo 'FMR20R_G02_EXACT_TWO_FILE_SOURCE_DELTA=PASS'

python3 - <<'PY'
from pathlib import Path
serial = Path('src/runtime/mod_fmr_serialized_multiswap_runtime.f90').read_text().lower()
pool = Path('src/runtime/mod_fmr_parallel_worker_pool.f90').read_text().lower()

assert 'subroutine fmr_publish_canonical_column_outputs' in serial
assert 'call fmr_publish_canonical_column_outputs(results, diagnostics, order)' in serial
assert 'call fmr_publish_canonical_column_outputs(results, diagnostics, publication_order)' in pool
# Publication must follow scientific/aggregate finalization on success paths.
spos = serial.index('call finalize_runtime_diagnostics(results, local_runtime, order)')
spub = serial.index('call fmr_publish_canonical_column_outputs(results, diagnostics, order)', spos)
assert spub > spos
ppos = pool.index('call finalize_parallel_runtime(results, assignments, worker_runtime, t0, t1, local_runtime)')
ppub = pool.index('call fmr_publish_canonical_column_outputs(results, diagnostics, publication_order)', ppos)
assert ppub > ppos
# No second execution/physics path was introduced by remediation.
assert serial.count('subroutine fmr_execute_serialized_physical_column') == 1
assert 'fmr_build_parallel_schedule' in pool
assert '!$omp parallel num_threads(worker_count)' in pool
print('FMR20R_G03_PUBLICATION_AFTER_FINALIZATION=PASS')
print('FMR20R_G04_EXECUTION_AND_SCHEDULER_SEAMS_PRESERVED=PASS')
PY

# Fetch the exact independent F-MQ26 test sources. Do not copy them into the
# remediation branch; preserve independent evidence provenance.
git fetch --quiet --no-tags --depth=1 origin \
  qualification/f-mq26-parallel-real-physics-v1-admission:"$FMQ26_REF"
[[ "$(git rev-parse "$FMQ26_REF":tests/fmq/test_fmq26_parallel_v1_admission.f90)" == \
   26cc6e0ace986dc40db7635de7192958a1c0b868 ]] || fail 'FMQ26 positive test provenance drift'
[[ "$(git rev-parse "$FMQ26_REF":tests/fmq/test_fmq26_canonical_publication_order.f90)" == \
   f2584b0236e85d4f6e8b687cee97981eaaa909c9 ]] || fail 'FMQ26 publication test provenance drift'
git show "$FMQ26_REF":tests/fmq/test_fmq26_parallel_v1_admission.f90 > "$BUILD/fmq26/test_positive.f90"
git show "$FMQ26_REF":tests/fmq/test_fmq26_canonical_publication_order.f90 > "$BUILD/fmq26/test_publication.f90"
echo 'FMR20R_G05_EXACT_INDEPENDENT_FMQ26_TEST_PROVENANCE=PASS'

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
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"
  objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/fmq26/test_positive.f90" -o "$OUT/positive.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/positive.o" -o "$OUT/positive"
  "$OUT/positive" > "$OUT/positive.txt" 2>&1 || { cat "$OUT/positive.txt" >&2; fail "O$opt FMQ26 positive regression"; }
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
    grep -Fq "$marker" "$OUT/positive.txt" || fail "missing O$opt positive marker: $marker"
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/fmq26/test_publication.f90" -o "$OUT/publication.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/publication.o" -o "$OUT/publication"
  "$OUT/publication" > "$OUT/publication.txt" 2>&1 || { cat "$OUT/publication.txt" >&2; fail "O$opt canonical publication"; }
  grep -Fq 'FMQ26_CANONICAL_PUBLICATION_ORDER=PASS' "$OUT/publication.txt" || fail "missing O$opt canonical publication PASS"
  if grep -Fq 'FMQ26_CANONICAL_PUBLICATION_ORDER=FAIL' "$OUT/publication.txt"; then fail "O$opt defect still reproduced"; fi
  echo "FMR20R_O${opt}=PASS"
done

cmp -s "$BUILD/o0/positive.txt" "$BUILD/o2/positive.txt" || {
  diff -u "$BUILD/o0/positive.txt" "$BUILD/o2/positive.txt" >&2 || true
  fail 'positive O0/O2 output identity'
}
cmp -s "$BUILD/o0/publication.txt" "$BUILD/o2/publication.txt" || {
  diff -u "$BUILD/o0/publication.txt" "$BUILD/o2/publication.txt" >&2 || true
  fail 'publication O0/O2 output identity'
}
echo 'FMR20R_G06_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/publication.txt"
echo 'FMR20R_INDEPENDENT_FMQ26_DEFECT_REPRODUCER_NOW_PASS=PASS'
echo 'FMR20R_OWNER_REMEDIATION_GATE=PASS'
