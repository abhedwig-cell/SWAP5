#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr04-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FMR04_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}
check_blob src/kernel/mod_kernel_transactions.f90 e8605e73a191e863374a26b096e0d597cb70cadd
check_blob src/solver/mod_soil_water_solver_contract.f90 57b51997d28807fbe2da1b2e5bf654fc4167adb9
check_blob src/solver/mod_reference_richards_workspace.f90 93285b2ca24669494c93c00403e3783fca6758e9
check_blob src/solver/mod_reference_richards_state_binding.f90 e68d88382c6502c571713cc97fddd4e18434e271
check_blob src/solver/mod_b110_default_mvg_provider.f90 97d67eb373073b183be6d1bf5b756ecb5125dde2
check_blob src/solver/mod_b110_source_sink_provider.f90 d6c57add72387e5c0022a44319fff08046194aac
check_blob src/adapter/mod_reference_richards_legacy_binding.f90 eb4b74ee422bc331ed3d6abaa40dd9f85b2551c0
check_blob src/legacy/b1_10_port/headcalc.f90 be5978827095445b15de7baf607728792de6a366
check_blob src/legacy/b1_10_port/soilwater.f90 470bc81a380e114d70fecd75426ec2331c1c9fcc
check_blob reference/swap-4.3.1/b1_10_source/MOD_MvG_functions.f90.gz.b64 6cfcec4e38b02343ba48e7e6fb5d595158e19653
check_blob reference/swap-4.3.1/b1_10_source/MOD_MvG_functions.manifest.json c64942d2964bb67c200f973b76e05222ad73067f

echo 'FMR04_EXACT_PRODUCTION_BLOBS PASS'

python3 - <<'PY'
from pathlib import Path
import json
runtime = Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text().lower()
context = Path('src/adapter/mod_b110_serialized_context_binding.f90').read_text().lower()
status = json.loads(Path('integration/f-mr/F-MR04_STATUS.json').read_text())
admission = json.loads(Path('integration/f-mr/F-MR04_BACKEND_ADMISSION.json').read_text())
for forbidden in ['call headcalc(', 'use variables', 'use mod_grid', 'use mod_snow', 'use mod_drain', 'use mod_irrigation']:
    assert forbidden not in runtime, f'F-MR runtime leaks solver/legacy internal: {forbidden}'
for required in ['fmr_trial_from_checkpoint', 'kernel_model_t', 'reference_richards_legacy_solver_t',
                 'b110_default_mvg_provider_t', 'b110_source_sink_provider_t',
                 'root_extraction_active', 'macropore_active', 'snow_active', 'swkimpl == 0']:
    assert required in runtime, f'missing runtime contract token: {required}'
for required in ['use variables', 'use mod_grid', 'bind_b110_serialized_legacy_context']:
    assert required in context, f'missing legacy context adapter token: {required}'
assert status['backend_admission']['PARALLEL_REFERENCE_BACKEND'] == 'NOT_ADMITTED'
assert status['scientific_admission'] is False
assert admission['backends']['PARALLEL_REFERENCE_BACKEND']['status'] == 'NOT_ADMITTED'
assert admission['backends']['PARALLEL_REFERENCE_BACKEND']['admitted'] is False
print('FMR04_ARCHITECTURE_BOUNDARY PASS')
PY

bash tests/fkt/run_fkt05_gate.sh >/dev/null
echo 'FMR04_FKT05_TRANSACTION_REGRESSION PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SRC=(
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
  src/runtime/mod_fmr_serialized_reference_backend.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
  tests/fmr/test_fmr04_serialized_physical.F90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for src in "${SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran -O"$opt" "${objects[@]}" -o "$OUT/fmr04_serialized_physical"
  if ! "$OUT/fmr04_serialized_physical" > "$OUT/output.txt" 2>&1; then
    cat "$OUT/output.txt" >&2
    echo "FMR04_O${opt}_EXECUTION FAIL" >&2
    exit 1
  fi
  grep -Fq 'FMR04_SERIALIZED_PHYSICAL_COMPOSITION_TEST PASS' "$OUT/output.txt"
  grep -Fq 'FMR04_REAL_HEADCALC_EXECUTED=TRUE' "$OUT/output.txt"
  grep -Fq 'FMR04_KERNEL_FULL_INTERVAL_MASS_COMPLETE=F' "$OUT/output.txt"
  grep -Fq 'FMR04_FULL_INTERVAL_MASS_ADMISSION=BLOCKED_FKT_RESULT_BOUNDARY_INCOMPLETE' "$OUT/output.txt"
  grep -Fq 'FMR04_ACTIVE_ROOT_FAIL_CLOSED=PASS' "$OUT/output.txt"
  grep -Fq 'FMR04_MACROPORE_FAIL_CLOSED=PASS' "$OUT/output.txt"
  grep -Fq 'FMR04_SNOW_FAIL_CLOSED=PASS' "$OUT/output.txt"
  grep -Fq 'FMR04_SWKIMPL1_FAIL_CLOSED=PASS' "$OUT/output.txt"
  sha256sum "$OUT/fmr04_serialized_physical" | sed "s#${OUT}/##" > "$OUT/executable.sha256"
  sha256sum "$OUT/output.txt" > "$OUT/output.sha256"
  echo "FMR04_O${opt} PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FMR04_O0_O2_OUTPUT_IDENTITY PASS'
cat "$BUILD/o0/output.txt"
echo "FMR04_O0_EXECUTABLE_SHA256=$(cut -d' ' -f1 "$BUILD/o0/executable.sha256")"
echo "FMR04_O2_EXECUTABLE_SHA256=$(cut -d' ' -f1 "$BUILD/o2/executable.sha256")"
echo "FMR04_OUTPUT_SHA256=$(cut -d' ' -f1 "$BUILD/o0/output.sha256")"
echo 'FMR04_GATE PASS_WITH_FULL_INTERVAL_MASS_HOLD'
