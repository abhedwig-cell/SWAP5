#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpm08d7-restart-$$"
EVIDENCE_DIR="${FPM08D7_RESTART_EVIDENCE_DIR:-}"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FPM08D7_RESTART_GATE_FAIL $*" >&2; exit 88; }
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/kernel/mod_kernel_committed_persistence.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/process/mod_restricted_fixed_weir_surface_water.f90
  src/runtime/mod_fmr_optional_state_layouts.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_restart_state_contract.f90
  src/runtime/mod_fmr_committed_restart.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/fpm/test_fpm08d7_restart_lifecycle.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "restart owner test O$opt execution"; }
  for marker in \
    'FPM08D7_RESTART_EXPORT_EXACT_STATE=PASS' \
    'FPM08D7_RESTART_LAYOUT_TYPE_FAIL_CLOSED=PASS' \
    'FPM08D7_RESTART_REJECTION_ATOMIC=PASS' \
    'FPM08D7_RESTART_ROUNDTRIP_EXACT=PASS' \
    'FPM08D7_RESTART_LIFECYCLE_OWNER_TEST PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing O$opt marker: $marker"; }
  done
  echo "FPM08D7_RESTART_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'restart O0/O2 output identity'
}
HASH="$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo "FPM08D7_RESTART_OUTPUT_SHA256=$HASH"
echo 'FPM08D7_RESTART_O0_O2_EXACT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"

if [[ -n "$EVIDENCE_DIR" ]]; then
  mkdir -p "$EVIDENCE_DIR"
  cp "$BUILD/o0/output.txt" "$EVIDENCE_DIR/o0-output.txt"
  cp "$BUILD/o2/output.txt" "$EVIDENCE_DIR/o2-output.txt"
  printf '%s\n' "$HASH" > "$EVIDENCE_DIR/output-sha256.txt"
  git rev-parse HEAD > "$EVIDENCE_DIR/tested-head.txt"
  git rev-parse HEAD:src > "$EVIDENCE_DIR/src-tree.txt"
  git rev-parse HEAD:src/runtime/mod_fmr_restart_state_contract.f90 > "$EVIDENCE_DIR/restart-state-contract-blob.txt"
  git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90 > "$EVIDENCE_DIR/backend-blob.txt"
fi

echo 'FPM08D7_RESTART_LIFECYCLE_OWNER_GATE=PASS'
