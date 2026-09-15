#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fci69-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

TX=src/transaction/mod_transaction_reference.f90
CONTRACTS=src/runtime/mod_canonical_contracts.f90
RUNTIME=src/runtime/mod_canonical_interval_runtime.f90
KERNEL=src/kernel/mod_kernel_transactions.f90
ORCH=src/runtime/mod_fmr_checkpoint_orchestrator.f90
POLICY=src/runtime/mod_rossfast_d3r_execution_policy.f90
BACKEND=src/runtime/mod_fmr_serialized_reference_backend.f90
TEST=tests/fci/test_fci69_fmr_serialized_selector_forwarding.f90

# Reuse admitted F-CI66/F-CI67/F-CI68 authority byte-for-byte.
test "$(git rev-parse HEAD:$TX)" = d5a71a526efaebd82054580c3186f8e3545db331
test "$(git rev-parse HEAD:$CONTRACTS)" = 3cbb81b25626e6574ae83416f088dc52882f91fc
test "$(git rev-parse HEAD:$RUNTIME)" = b12327aa6e77bdbf4586fe0bed82cf0e7704f237
test "$(git rev-parse HEAD:$KERNEL)" = d3a53385e3707f05e5396bbd6f218633b9803f65
test "$(git rev-parse HEAD:$ORCH)" = 0dceaa2d108d5c7e1263e0f424a056a8df585908
test "$(git rev-parse HEAD:$POLICY)" = a39a636d01f373ae6ef0dc3ac0e1e25b6522fda9

grep -Fq 'use mod_canonical_interval_runtime, only: canonical_subinterval_target_selector' "$BACKEND"
grep -Fq 'procedure(canonical_subinterval_target_selector), optional :: target_selector' "$BACKEND"
grep -Fq 'diagnostics, target_selector)' "$BACKEND"
if grep -Eqi 'ROSSFAST|ROSS01' "$BACKEND"; then
  echo 'FCI69_GENERIC_BACKEND_CONTAINS_ROSSFAST_POLICY' >&2
  exit 69
fi

MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  "$TX"
  src/transaction/mod_fkt_temporal_indicator_history.f90
  "$CONTRACTS"
  "$RUNTIME"
  "$KERNEL"
  src/runtime/mod_fmr_runtime_core.f90
  "$ORCH"
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/process/mod_drainage_process.f90
  src/process/mod_drainage_tabulated_response.f90
  src/process/mod_drainage_hooghoudt_equivalent_depth.f90
  src/process/mod_drainage_hooghoudt_ipos1_response.f90
  src/process/mod_drainage_hooghoudt_ipos23_response.f90
  src/process/mod_drainage_ernst_ipos45_preparation.f90
  src/process/mod_drainage_ernst_ipos45_response.f90
  src/process/mod_drainage_empirical_interflow_response.f90
  src/process/mod_drainage_multilevel_aggregation.f90
  src/runtime/mod_fmr_drainage_response_binding.f90
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
  "$BACKEND"
  "$POLICY"
)

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 69; }
  grep -Fq 'FCI69_SERIALIZED_BACKEND_ROSSFAST_SELECTOR_FORWARDING=PASS' "$OUT/output.txt"
  grep -Fq 'FCI69_ABSENT_PRESENT_IDENTITY=PASS' "$OUT/output.txt"
  grep -Fq 'FCI69_FMR_SERIALIZED_SELECTOR_FORWARDING_TEST PASS' "$OUT/output.txt"
  grep -Eq 'FCI69_SELECTOR_CALLS=[1-9][0-9]*' "$OUT/output.txt"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  exit 69
}

git diff --check -- "$BACKEND" "$TEST" tests/fci/run_fci69_fmr_serialized_selector_forwarding.sh
echo "FCI69_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'FCI69_EXACT_SERIALIZED_BACKEND_SELECTOR_COMPOSITION=PASS'
