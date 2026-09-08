#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr06-smoke-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FMR05_SOURCE="c28e7a2810b4a3678c577335a6a3086b173eb976"
check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FMR06_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/process/mod_snow_process.f90 54702d71b4c84dce2842813549bd14c57301a383
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 202ab846cbd30d149d0d450249b3d517e333994f
check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 e4f5bc0bf47e2721d689e62107b5224196a093d9
check_blob src/kernel/mod_kernel_transactions.f90 9f7c16e71cfb93b57f796ba759bae73824318a2f
check_blob src/transaction/mod_transaction_reference.f90 b1878606ae6cb2b04a7b4b15e3e537deacf4477f
check_blob src/runtime/mod_canonical_contracts.f90 0c2b15fc45011c580384cf6a618e7b378fdccf0a
check_blob src/runtime/mod_canonical_interval_runtime.f90 f2cae79d533343db818c11e0b61b605ac5f6739d

python3 - <<'PY'
from pathlib import Path
import subprocess
changed = subprocess.check_output([
    'git','diff','--name-only','c28e7a2810b4a3678c577335a6a3086b173eb976','HEAD','--','src'
], text=True).splitlines()
expected = [
    'src/process/mod_snow_process.f90',
    'src/runtime/mod_fmr_serialized_reference_backend.f90',
]
assert changed == expected, f'unexpected F-MR06 production source changes: {changed}'
backend = Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text().lower()
for forbidden in ['call headcalc(', 'use variables', 'use mod_grid', '!$omp', 'omp_lib', 'parallel do']:
    assert forbidden not in backend, f'F-MR06 runtime boundary leak: {forbidden}'
for token in ['prepare_snow_outer_event', 'evaluate_snow_reference_call', 'snow_event_prepared',
              'snow_event_applied_this_call', 'snowfall_external_in', 'sublimation_external_out',
              'melt_internal_transfer', 'fmr_trial_from_checkpoint']:
    assert token in backend, f'missing F-MR06 snow seam token: {token}'
print('FMR06_SOURCE_SCOPE_AND_ARCHITECTURE PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
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
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/test_fmr06_snow_smoke.f90 -o "$OUT/test_fmr06_snow_smoke.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test_fmr06_snow_smoke.o" -o "$OUT/fmr06_snow_smoke"
  "$OUT/fmr06_snow_smoke" > "$OUT/snow.txt" 2>&1 || { cat "$OUT/snow.txt" >&2; exit 1; }
  grep -Fq 'FMR06_SNOW_ONE_CALL_DAILY_TRIAL=PASS' "$OUT/snow.txt"
  grep -Fq 'FMR06_SNOW_ROLLBACK=PASS' "$OUT/snow.txt"
  grep -Fq 'FMR06_SNOW_REPLAY_BITWISE=PASS' "$OUT/snow.txt"
  grep -Fq 'FMR06_SNOW_COMMIT=PASS' "$OUT/snow.txt"
  grep -Fq 'FMR06_SNOW_AUTHORITATIVE_MASS_COMPLETE=PASS' "$OUT/snow.txt"
  grep -Fq 'FMR06_SNOW_SUBDAILY_FAIL_CLOSED=PASS' "$OUT/snow.txt"
  grep -Fq 'FMR06_SNOW_MULTIDAY_FAIL_CLOSED=PASS' "$OUT/snow.txt"
  grep -Fq 'FMR06_SNOW_SMOKE_TEST PASS' "$OUT/snow.txt"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/test_fmr05_single_fmr04_identity.f90 -o "$OUT/test_fmr05_inactive.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test_fmr05_inactive.o" -o "$OUT/fmr05_inactive_regression"
  "$OUT/fmr05_inactive_regression" > "$OUT/inactive.txt" 2>&1 || { cat "$OUT/inactive.txt" >&2; exit 1; }
  grep -Fq 'FMR05_SINGLE_COLUMN_FMR04_ROUTE_IDENTITY=PASS' "$OUT/inactive.txt"
  grep -Fq 'FMR05_SINGLE_COLUMN_FMR04_MASS_BITWISE_IDENTITY=PASS' "$OUT/inactive.txt"
  grep -Fq 'FMR05_SINGLE_COLUMN_FMR04_COMMITTED_STATE_IDENTITY=PASS' "$OUT/inactive.txt"

  cat "$OUT/snow.txt" "$OUT/inactive.txt" > "$OUT/output.txt"
  sha256sum "$OUT/fmr06_snow_smoke" "$OUT/fmr05_inactive_regression" > "$OUT/executables.sha256"
  sha256sum "$OUT/output.txt" > "$OUT/output.sha256"
  echo "FMR06_SMOKE_O${opt}=PASS"
done

cmp "$BUILD/o0/snow.txt" "$BUILD/o2/snow.txt"
echo 'FMR06_SNOW_O0_O2_OUTPUT_IDENTITY=PASS'
cmp "$BUILD/o0/inactive.txt" "$BUILD/o2/inactive.txt"
echo 'FMR06_SNOW_INACTIVE_FMR05_O0_O2_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FMR06_O0_SNOW_EXECUTABLE_SHA256=$(sed -n '1s/ .*//p' "$BUILD/o0/executables.sha256")"
echo "FMR06_O0_INACTIVE_EXECUTABLE_SHA256=$(sed -n '2s/ .*//p' "$BUILD/o0/executables.sha256")"
echo "FMR06_O2_SNOW_EXECUTABLE_SHA256=$(sed -n '1s/ .*//p' "$BUILD/o2/executables.sha256")"
echo "FMR06_O2_INACTIVE_EXECUTABLE_SHA256=$(sed -n '2s/ .*//p' "$BUILD/o2/executables.sha256")"
echo "FMR06_SMOKE_OUTPUT_SHA256=$(cut -d' ' -f1 "$BUILD/o0/output.sha256")"
echo 'FMR06_SMOKE_GATE PASS'
