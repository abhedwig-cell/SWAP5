#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fmr44-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FMR44_GATE_FAIL $*" >&2; exit 144; }

python3 tests/fmr/_apply_fmr44_serialized_qbot_patch.py

grep -Fq 'request%boundary%bottom_mode /= 5 .and. request%boundary%bottom_mode /= 2' \
  src/adapter/mod_b110_serialized_context_binding.f90 || fail 'serialized context mode2 admission missing'
grep -Fq 'parameters%bottom_mode == 2' src/runtime/mod_fmr_serialized_reference_backend.f90 || \
  fail 'serialized backend mode2 admission missing'
grep -Fq 'request%boundary%bottom_flux = self%bottom_flux' src/runtime/mod_fmr_serialized_reference_backend.f90 || \
  fail 'bottom flux forcing transport missing'
grep -Fq 'request%boundary%bottom_mode = self%bottom_mode' src/runtime/mod_fmr_serialized_reference_backend.f90 || \
  fail 'bottom mode transport missing'

echo 'FMR44_STATIC_SERIALIZED_MODE2_BINDING=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
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
  src/process/mod_snow_process.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/process/mod_restricted_fixed_weir_surface_water.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
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

  # Diagnostic separation oracle: exercise the same real-MVG prescribed-qbot
  # cases directly through reference_richards_legacy_solver_t before any
  # serialized runtime/transaction composition. This diagnostic intentionally
  # does not require positive-qbot convergence; it records the bounded envelope
  # and lets the subsequent qualification gate remain the fail-closed authority.
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/fmr/test_fmr44_direct_qbot_envelope.f90 -o "$OUT/direct.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/direct.o" -o "$OUT/direct"
  "$OUT/direct" > "$OUT/direct.txt" 2>&1 || { cat "$OUT/direct.txt" >&2; fail "direct qbot envelope O$opt"; }
  grep -Fq 'FMR44_DIRECT_REAL_MVG_QBOT_ENVELOPE_COMPLETE=PASS' "$OUT/direct.txt" || {
    cat "$OUT/direct.txt" >&2
    fail "direct qbot envelope marker O$opt"
  }
  cat "$OUT/direct.txt"
  echo "FMR44_DIRECT_ENVELOPE_O${opt}=PASS"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/fmr/test_fmr44_serialized_prescribed_qbot_runtime.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "runtime oracle O$opt"; }
  for marker in \
    'FMR44_MODE2_EQUILIBRIUM_TRANSACTION=PASS' \
    'FMR44_POSITIVE_QBOT_ACCEPTED_INFLOW=PASS' \
    'FMR44_NEARBY_BOTTOM_MODE_FAIL_CLOSED=PASS' \
    'FMR44_SERIALIZED_PRESCRIBED_QBOT_RUNTIME_GATE PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing O$opt marker $marker"; }
  done
  cat "$OUT/output.txt"
  echo "FMR44_RUNTIME_O${opt}=PASS"
done

cmp -s "$BUILD/o0/direct.txt" "$BUILD/o2/direct.txt" || {
  diff -u "$BUILD/o0/direct.txt" "$BUILD/o2/direct.txt" >&2 || true
  fail 'direct O0/O2 semantic drift'
}
echo 'FMR44_DIRECT_O0_O2_SEMANTIC_IDENTITY=PASS'

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 semantic drift'
}
echo 'FMR44_O0_O2_SEMANTIC_IDENTITY=PASS'

git diff --check -- src/adapter/mod_b110_serialized_context_binding.f90 \
  src/runtime/mod_fmr_serialized_reference_backend.f90 \
  tests/fmr/test_fmr44_serialized_prescribed_qbot_runtime.f90 \
  tests/fmr/test_fmr44_direct_qbot_envelope.f90

echo 'FMR44_QUALIFICATION_GATE=PASS'
