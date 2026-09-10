#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmq28-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FMQ28_GATE_FAIL $*" >&2; exit 1; }
CANDIDATE=e8858ce4816fc6ddfaf9ec252832c76cd3094705
OLD=4b6807c1d78c0c7d8bfe0f7a03a4c6c07d4444b9
MATRIX_BLOB=26cc6e0ace986dc40db7635de7192958a1c0b868
ORDER_BLOB=f2584b0236e85d4f6e8b687cee97981eaaa909c9

[[ -z "$(git diff --name-only "$CANDIDATE"..HEAD -- src)" ]] || fail 'production source drift after candidate'
mapfile -t remediation_src < <(git diff --name-only "$OLD".."$CANDIDATE" -- src)
[[ ${#remediation_src[@]} -eq 1 && "${remediation_src[0]}" == "src/runtime/mod_fmr_parallel_worker_pool.f90" ]] || \
  fail "unexpected F-MR22 production scope: ${remediation_src[*]:-none}"

git cat-file blob "$MATRIX_BLOB" > "$BUILD/test_matrix.f90"
git cat-file blob "$ORDER_BLOB" > "$BUILD/test_order.f90"
[[ "$(git hash-object "$BUILD/test_matrix.f90")" == "$MATRIX_BLOB" ]] || fail 'matrix harness blob mismatch'
[[ "$(git hash-object "$BUILD/test_order.f90")" == "$ORDER_BLOB" ]] || fail 'order sentinel blob mismatch'
echo 'FMQ28_SOURCE_LOCK=PASS'
echo 'FMQ28_REMEDIATION_SCOPE_PUBLICATION_ONLY=PASS'
echo 'FMQ28_IMMUTABLE_PRIOR_QUALIFICATION_HARNESSES=PASS'

python3 - <<'PY'
from pathlib import Path
p=Path('src/runtime/mod_fmr_parallel_worker_pool.f90').read_text().lower()
assert 'subroutine canonicalize_publication' in p
assert 'call fmr_build_execution_order(columns, order)' in p
normal=p.index('call build_parallel_aggregate')
finalize=p.index('call finalize_parallel_runtime', normal)
canon=p.index('call canonicalize_publication(columns, results, diagnostics)', finalize)
assert normal < finalize < canon
print('FMQ28_CANONICAL_REORDER_AFTER_AGGREGATE_REDUCTION=PASS')
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

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/test_matrix.f90" -o "$OUT/matrix.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/matrix.o" -o "$OUT/matrix"
  "$OUT/matrix" > "$OUT/matrix.txt" 2>&1 || { cat "$OUT/matrix.txt" >&2; fail "matrix O$opt"; }
  while read -r n b o; do
    grep -Fq "FMQ26_POSITIVE_N${n}_B${b}_O${o}=PASS" "$OUT/matrix.txt" || fail "positive n=$n b=$b order=$o O$opt"
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
    grep -Fq "$marker" "$OUT/matrix.txt" || fail "missing matrix marker O$opt: $marker"
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/test_order.f90" -o "$OUT/order.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/order.o" -o "$OUT/order"
  "$OUT/order" > "$OUT/order.txt" 2>&1 || { cat "$OUT/order.txt" >&2; fail "canonical order O$opt"; }
  grep -Fq 'FMQ26_CANONICAL_PUBLICATION_ORDER=PASS' "$OUT/order.txt" || fail "canonical order marker O$opt"
  echo "FMQ28_O${opt}=PASS"
done

cmp -s "$BUILD/o0/matrix.txt" "$BUILD/o2/matrix.txt" || { diff -u "$BUILD/o0/matrix.txt" "$BUILD/o2/matrix.txt" >&2 || true; fail 'matrix O0/O2 identity'; }
cmp -s "$BUILD/o0/order.txt" "$BUILD/o2/order.txt" || { diff -u "$BUILD/o0/order.txt" "$BUILD/o2/order.txt" >&2 || true; fail 'order O0/O2 identity'; }
echo 'FMQ28_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/matrix.txt"
cat "$BUILD/o0/order.txt"
echo 'FMQ28_GATE=PASS'
