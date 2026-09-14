#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpm14-transactional-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FPM14_TRANSACTIONAL_RUNTIME_GATE_FAIL $*" >&2; exit 87; }

python3 tools/fpm14/apply_backend_drainage_response_patch.py
python3 tools/fpm14/refine_backend_drainage_response_patch.py

grep -Fq 'F-PM14 drainage response runtime composition' src/runtime/mod_fmr_serialized_reference_backend.f90 || \
  fail 'checked backend transform marker missing'
grep -Fq 'evaluate_fmr_drainage_response_bottom_lumped' src/runtime/mod_fmr_serialized_reference_backend.f90 || \
  fail 'backend response evaluation missing'
grep -Fq 'fmr_drainage_response_configuration_status' src/runtime/mod_fmr_serialized_reference_backend.f90 || \
  fail 'explicit response preflight status missing'
grep -Fq 'call account_external_fluxes' src/runtime/mod_fmr_serialized_reference_backend.f90 || \
  fail 'existing authoritative mass ledger route missing'
if grep -Fiq 'headcalc' src/runtime/mod_fmr_drainage_response_binding.f90; then
  fail 'response binding depends on HeadCalc internals'
fi
if grep -Eiq 'open\s*\(|read\s*\(|write\s*\(|\.swp|midnight|calendar' src/runtime/mod_fmr_drainage_response_binding.f90; then
  fail 'response binding contains forbidden I/O or calendar assumptions'
fi
python3 - <<'PY'
from pathlib import Path
s=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
a=s[s.index('logical function fmr_serialized_execution_admitted'):s.index('end function fmr_serialized_execution_admitted')]
assert 'self%drainage_response_levels' not in a
assert 'self%drainage_response_active' not in a
print('FPM14_ADMISSION_INDEPENDENT_OF_WORKER_SCRATCH=PASS')
PY
echo 'FPM14_BACKEND_CHECKED_TRANSFORM_STATIC_GUARDS=PASS'

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

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/fpm/test_fpm14_drainage_response_transactional_runtime.f90 -o "$OUT/transactional-test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/transactional-test.o" -o "$OUT/transactional-test"
  "$OUT/transactional-test" > "$OUT/transactional-output.txt" 2>&1 || {
    cat "$OUT/transactional-output.txt" >&2; fail "transactional owner test O$opt execution";
  }
  for marker in \
    'FPM14_ACTIVE_RESPONSE_SINGLE_ACCEPTED_BOOKING=PASS' \
    'FPM14_ACTIVE_RESPONSE_HARD_MASS_CLOSURE=PASS' \
    'FPM14_UNSUPPORTED_RESPONSE_TRANSACTION_ROLLBACK=PASS' \
    'FPM14_DRAINAGE_RESPONSE_TRANSACTIONAL_RUNTIME_OWNER_TEST PASS'; do
      grep -Fq "$marker" "$OUT/transactional-output.txt" || {
        cat "$OUT/transactional-output.txt" >&2; fail "missing transactional O$opt marker: $marker";
      }
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/fpm/test_fpm14_multiswap_restart_isolation.f90 -o "$OUT/isolation-test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/isolation-test.o" -o "$OUT/isolation-test"
  "$OUT/isolation-test" > "$OUT/isolation-output.txt" 2>&1 || {
    cat "$OUT/isolation-output.txt" >&2; fail "MultiSWAP/restart owner test O$opt execution";
  }
  for marker in \
    'FPM14_MULTISWAP_ACTIVE_INACTIVE_ACTIVE_ISOLATION=PASS' \
    'FPM14_MULTISWAP_EXECUTION_ORDER_INDEPENDENCE=PASS' \
    'FPM14_RESTART_NO_ADDITIONAL_DRAINAGE_STATE=PASS' \
    'FPM14_RESTART_CONTINUATION_EQUIVALENCE=PASS' \
    'FPM14_MULTISWAP_RESTART_ISOLATION_OWNER_TEST PASS'; do
      grep -Fq "$marker" "$OUT/isolation-output.txt" || {
        cat "$OUT/isolation-output.txt" >&2; fail "missing isolation O$opt marker: $marker";
      }
  done
  echo "FPM14_TRANSACTIONAL_AND_ISOLATION_O${opt}=PASS"
done

cmp -s "$BUILD/o0/transactional-output.txt" "$BUILD/o2/transactional-output.txt" || {
  diff -u "$BUILD/o0/transactional-output.txt" "$BUILD/o2/transactional-output.txt" >&2 || true
  fail 'transactional O0/O2 output identity'
}
cmp -s "$BUILD/o0/isolation-output.txt" "$BUILD/o2/isolation-output.txt" || {
  diff -u "$BUILD/o0/isolation-output.txt" "$BUILD/o2/isolation-output.txt" >&2 || true
  fail 'MultiSWAP/restart O0/O2 output identity'
}
echo 'FPM14_TRANSACTIONAL_RUNTIME_O0_O2_EXACT_IDENTITY=PASS'
echo 'FPM14_MULTISWAP_RESTART_O0_O2_EXACT_IDENTITY=PASS'
cat "$BUILD/o0/transactional-output.txt"
cat "$BUILD/o0/isolation-output.txt"
echo "FPM14_TRANSACTIONAL_RUNTIME_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/transactional-output.txt" | awk '{print $1}')"
echo "FPM14_MULTISWAP_RESTART_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/isolation-output.txt" | awk '{print $1}')"
echo 'FPM14_DRAINAGE_RESPONSE_TRANSACTIONAL_RUNTIME_OWNER_GATE=PASS'
