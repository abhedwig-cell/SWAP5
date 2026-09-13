#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-eb-i13-$$"
EVIDENCE_DIR="${EB_I13_EVIDENCE_DIR:-}"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "EB_I13_GATE_FAIL $*" >&2; exit 91; }
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

python3 - <<'PY'
from pathlib import Path
backend = Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
carrier = Path('src/runtime/mod_fmr_bottom_thermal_carrier.f90').read_text()
required_backend = [
    'type, extends(transaction_attempt_context_t) :: fmr_serialized_attempt_context_t',
    'type(fmr_bottom_thermal_carrier_t) :: bottom_thermal_carrier',
    'procedure :: capture_attempt_context => fmr_serialized_capture_attempt_context',
    'procedure :: restore_attempt_context => fmr_serialized_restore_attempt_context',
    'self%bottom_thermal_requested .and. parameters%soil_temperature_active',
    '2 * config%max_committed_substeps',
    'result%completed .and. candidate%ready()',
    'call self%model%bottom_thermal_carrier%materialize_candidate',
    'call self%bottom_thermal_carrier%copy_to(typed%bottom_thermal_carrier)',
    'call self%bottom_thermal_carrier%restore_from(typed%bottom_thermal_carrier)',
    'call record_bottom_thermal_sample',
]
for token in required_backend:
    if token not in backend:
        raise SystemExit(f'EB_I13_GATE_FAIL missing backend contract token: {token}')
for token in [
    'subroutine carrier_append_local',
    'subroutine carrier_append_external_incomplete',
    'subroutine carrier_append_zero',
    'subroutine carrier_restore_from',
    'subroutine carrier_materialize_candidate',
]:
    if token not in carrier:
        raise SystemExit(f'EB_I13_GATE_FAIL missing carrier contract token: {token}')
if 'use mod_fmr_bottom_thermal_carrier' in Path('src/kernel/mod_kernel_transactions.f90').read_text():
    raise SystemExit('EB_I13_GATE_FAIL carrier leaked into F-KT kernel')
print('EB_I13_STATIC_WORKER_LOCAL_TRANSACTION_SEAM=PASS')
print('EB_I13_STATIC_KERNEL_PERSISTENCE_SEPARATION=PASS')
PY

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
  src/solver/mod_process_hydraulic_view.f90
  src/process/mod_soil_temperature_contract.f90
  src/process/mod_restricted_soil_temperature.f90
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
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
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
    tests/eb/test_eb_i13_bottom_thermal_carrier.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "runtime O$opt execution"; }
  for marker in \
    'EB_I13_PRIMITIVE_LOCAL_EXTERNAL_ZERO_BOUNDED=PASS' \
    'EB_I13_REJECT_RETRY_ROLLBACK_EXACT_PREFIX=PASS' \
    'EB_I13_SERIALIZED_ACCEPTED_ROUTE_AND_LOCAL_TEMPERATURE=PASS' \
    'EB_I13_HYDROLOGIC_LEDGER_AND_CANDIDATE_PARITY=PASS' \
    'EB_I13_NO_EXTRA_PHYSICAL_SOLVE_PARITY=PASS' \
    'EB_I13_BOTTOM_THERMAL_CARRIER_GATE PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing O$opt marker: $marker"; }
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/eb/test_eb_i13_canonical_outer_routes.f90 -o "$OUT/outer-test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/outer-test.o" -o "$OUT/outer-test"
  "$OUT/outer-test" > "$OUT/outer-output.txt" 2>&1 || {
    cat "$OUT/outer-output.txt" >&2
    fail "outer lifecycle O$opt execution"
  }
  for marker in \
    'EB_I13_MULTI_SUBSTEP_ACCEPTED_ROUTE_SEQUENCE=PASS' \
    'EB_I13_PARTIAL_OUTER_FAILURE_NO_CANDIDATE=PASS' \
    'EB_I13_CANONICAL_OUTER_ROUTES_GATE PASS'; do
    grep -Fq "$marker" "$OUT/outer-output.txt" || {
      cat "$OUT/outer-output.txt" >&2
      fail "missing outer O$opt marker: $marker"
    }
  done

  echo "EB_I13_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 output identity'
}
cmp -s "$BUILD/o0/outer-output.txt" "$BUILD/o2/outer-output.txt" || {
  diff -u "$BUILD/o0/outer-output.txt" "$BUILD/o2/outer-output.txt" >&2 || true
  fail 'outer O0/O2 output identity'
}
HASH="$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
OUTER_HASH="$(sha256sum "$BUILD/o0/outer-output.txt" | awk '{print $1}')"
echo "EB_I13_OUTPUT_SHA256=$HASH"
echo "EB_I13_OUTER_OUTPUT_SHA256=$OUTER_HASH"
echo 'EB_I13_O0_O2_EXACT_IDENTITY=PASS'
echo 'EB_I13_OUTER_O0_O2_EXACT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
cat "$BUILD/o0/outer-output.txt"

git diff --check HEAD~1..HEAD || fail 'latest commit whitespace check'

if [[ -n "$EVIDENCE_DIR" ]]; then
  mkdir -p "$EVIDENCE_DIR"
  cp "$BUILD/o0/output.txt" "$EVIDENCE_DIR/o0-output.txt"
  cp "$BUILD/o2/output.txt" "$EVIDENCE_DIR/o2-output.txt"
  cp "$BUILD/o0/outer-output.txt" "$EVIDENCE_DIR/outer-o0-output.txt"
  cp "$BUILD/o2/outer-output.txt" "$EVIDENCE_DIR/outer-o2-output.txt"
  printf '%s\n' "$HASH" > "$EVIDENCE_DIR/output-sha256.txt"
  printf '%s\n' "$OUTER_HASH" > "$EVIDENCE_DIR/outer-output-sha256.txt"
  git rev-parse HEAD > "$EVIDENCE_DIR/tested-head.txt"
  git rev-parse HEAD:src/runtime/mod_fmr_bottom_thermal_carrier.f90 > "$EVIDENCE_DIR/carrier-blob.txt"
  git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90 > "$EVIDENCE_DIR/backend-blob.txt"
fi

echo 'EB_I13_BOTTOM_THERMAL_CARRIER_QUALIFICATION_GATE=PASS'
