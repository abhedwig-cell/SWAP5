#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-eb-i18-preflight-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "EB_I18_PREFLIGHT_FAIL $*" >&2; exit 181; }

BASE_RUNTIME_BLOB="f06a2eef7b47880e449cf9b201342d7bd1e197e1"
[[ "$(git hash-object src/runtime/mod_fmr_serialized_multiswap_runtime.f90)" == "$BASE_RUNTIME_BLOB" ]] || fail 'runtime base blob drift'

python3 tests/eb/_apply_eb_i18_runtime_patch.py
python3 tests/eb/_normalize_eb_i18_runtime_api.py

grep -Fq 'fmr_execute_serialized_column_with_bottom_energy' src/runtime/mod_fmr_serialized_multiswap_runtime.f90
! grep -Fq 'fmr_execute_serialized_resolved_physical_column_with_bottom_energy' src/runtime/mod_fmr_serialized_multiswap_runtime.f90
grep -Fq 'call backend%run_trial' src/runtime/mod_fmr_serialized_multiswap_runtime.f90
grep -Fq 'thermal_candidate = backend%bottom_thermal_snapshot()' src/runtime/mod_fmr_serialized_multiswap_runtime.f90
grep -Fq 'call prepare_candidate_bound_bottom_energy' src/runtime/mod_fmr_serialized_multiswap_runtime.f90
grep -Fq 'call fmr_commit_candidate_with_receipt' src/runtime/mod_fmr_serialized_multiswap_runtime.f90
grep -Fq 'call finalize_bottom_energy_publication' src/runtime/mod_fmr_serialized_multiswap_runtime.f90
! grep -Fq 'execution_provenance' src/runtime/mod_fmr_serialized_multiswap_runtime.f90
! grep -Fq 'exact_attempt_provenance' src/runtime/mod_fmr_serialized_multiswap_runtime.f90

echo 'EB_I18_PROCEDURAL_PROVENANCE_STATIC_PREFLIGHT=PASS'

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
  tests/fpm/mod_fpm08d7_optional_state_compat.f90
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/process/mod_liquid_water_sensible_enthalpy.f90
  src/runtime/mod_fmr_bottom_external_thermal_binding.f90
  src/runtime/mod_fmr_bottom_external_thermal_provider.f90
  src/runtime/mod_fmr_bottom_sensible_energy.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/runtime/mod_fmr_fixed_weir_serialized_runtime.f90
  src/runtime/mod_fmr_restart_state_contract.f90
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

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/eb/test_eb_i18_external_bottom_thermal_provider.f90 -o "$OUT/provider_test.o"
  gfortran -O"$opt" "$OUT/mod_fmr_bottom_external_thermal_provider.o" "$OUT/provider_test.o" \
    -o "$OUT/provider_test"
  "$OUT/provider_test" > "$OUT/provider_output.txt" 2>&1 || { cat "$OUT/provider_output.txt" >&2; fail "provider oracle O$opt"; }
  grep -Fq 'EB_I18_EXTERNAL_BOTTOM_THERMAL_PROVIDER_GATE PASS' "$OUT/provider_output.txt" || fail "provider marker O$opt"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/eb/test_eb_i18_transaction_publication.f90 -o "$OUT/transaction_test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/transaction_test.o" -o "$OUT/transaction_test"
  "$OUT/transaction_test" > "$OUT/transaction_output.txt" 2>&1 || {
    cat "$OUT/transaction_output.txt" >&2
    fail "transaction publication oracle O$opt"
  }
  for marker in \
    'EB_I18_EXTERNAL_COMPLETE_ACCEPTED_PUBLICATION=PASS' \
    'EB_I18_EXTERNAL_UNAVAILABLE_HYDROLOGY_COMMIT=PASS' \
    'EB_I18_EXTERNAL_STALE_HYDROLOGY_COMMIT=PASS' \
    'EB_I18_EXTERNAL_IDENTITY_MISMATCH_FAIL_CLOSED=PASS' \
    'EB_I18_EXTERNAL_INVALID_RESPONSE_FAIL_CLOSED=PASS' \
    'EB_I18_REJECTED_TRIAL_NO_PUBLICATION=PASS' \
    'EB_I18_BACKEND_REUSE_NO_STALE_PUBLICATION=PASS' \
    'EB_I18_TRANSACTION_PUBLICATION_GATE PASS'; do
    grep -Fq "$marker" "$OUT/transaction_output.txt" || {
      cat "$OUT/transaction_output.txt" >&2
      fail "missing transaction marker O$opt: $marker"
    }
  done

  echo "EB_I18_PROVIDER_ORACLE_O${opt}=PASS"
  echo "EB_I18_TRANSACTION_PUBLICATION_O${opt}=PASS"
  echo "EB_I18_STAGED_RUNTIME_COMPILE_O${opt}=PASS"
done

cmp -s "$BUILD/o0/provider_output.txt" "$BUILD/o2/provider_output.txt" || {
  diff -u "$BUILD/o0/provider_output.txt" "$BUILD/o2/provider_output.txt" >&2 || true
  fail 'provider O0/O2 semantic drift'
}
cmp -s "$BUILD/o0/transaction_output.txt" "$BUILD/o2/transaction_output.txt" || {
  diff -u "$BUILD/o0/transaction_output.txt" "$BUILD/o2/transaction_output.txt" >&2 || true
  fail 'transaction O0/O2 semantic drift'
}
echo 'EB_I18_PROVIDER_O0_O2_SEMANTIC_IDENTITY=PASS'
echo 'EB_I18_TRANSACTION_O0_O2_SEMANTIC_IDENTITY=PASS'

git diff --check -- src/runtime/mod_fmr_serialized_multiswap_runtime.f90 tests/eb/test_eb_i18_transaction_publication.f90
echo 'EB_I18_STAGED_RUNTIME_PREFLIGHT=PASS'
