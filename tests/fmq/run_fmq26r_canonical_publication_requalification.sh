#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmq26r-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FMQ26R_GATE_FAIL $*" >&2; exit 1; }
REMEDIATION=e8858ce4816fc6ddfaf9ec252832c76cd3094705

git merge-base --is-ancestor "$REMEDIATION" HEAD || fail 'remediation head is not ancestor'
[[ -z "$(git diff --name-only "$REMEDIATION"..HEAD -- src)" ]] || fail 'qualification branch changes production source'
echo 'FMQ26R_EXACT_REMEDIATION_ANCESTRY=PASS'
echo 'FMQ26R_QUALIFICATION_SOURCE_ISOLATION=PASS'

# Retain the authoring-side regression matrix, then decide independently below.
bash tests/fmr/run_fmr22_canonical_publication_gate.sh > "$BUILD/remediation_gate.txt" 2>&1 || {
  cat "$BUILD/remediation_gate.txt" >&2
  fail 'F-MR22 regression gate'
}
grep -Fq 'FMR22_GATE=PASS' "$BUILD/remediation_gate.txt" || fail 'missing F-MR22 gate marker'
echo 'FMQ26R_FMR22_REGRESSION_GATE=PASS'

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
    tests/fmq/test_fmq26r_canonical_publication_requalification.f90 -o "$OUT/test.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "qualification executable O$opt"; }
  for marker in \
    FMQ26R_REVERSED_2_WORKERS_CANONICAL_PUBLICATION=PASS \
    FMQ26R_PERMUTED_2_WORKERS_CANONICAL_PUBLICATION=PASS \
    FMQ26R_REVERSED_4_WORKERS_CANONICAL_PUBLICATION=PASS \
    FMQ26R_PERMUTED_4_WORKERS_CANONICAL_PUBLICATION=PASS \
    FMQ26R_AGGREGATE_MASS_PUBLICATION_INDEPENDENCE=PASS \
    'FMQ26R_CANONICAL_PUBLICATION_REQUALIFICATION PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || fail "missing O$opt marker: $marker"
  done
  echo "FMQ26R_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 output identity'
}
echo 'FMQ26R_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo 'FMQ26R_GATE=PASS'
