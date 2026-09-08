#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr05-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FMR05_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

# Exact F-VQ14/F-MR04/F-KT08/F-SI physical baseline consumed by F-MR05.
check_blob src/transaction/mod_transaction_reference.f90 b1878606ae6cb2b04a7b4b15e3e537deacf4477f
check_blob src/runtime/mod_canonical_contracts.f90 0c2b15fc45011c580384cf6a618e7b378fdccf0a
check_blob src/runtime/mod_canonical_interval_runtime.f90 f2cae79d533343db818c11e0b61b605ac5f6739d
check_blob src/kernel/mod_kernel_transactions.f90 9f7c16e71cfb93b57f796ba759bae73824318a2f
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 ade399a1df4b582c9038442093ccacce034f923d
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
# The only F-MR05 production source file.
check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 e4f5bc0bf47e2721d689e62107b5224196a093d9

echo 'FMR05_EXACT_BASELINE_AND_SOURCE_BLOBS PASS'
echo 'FMR05_FMR04_QUALIFIED_SOURCE_BLOBS_FORWARD PASS'

python3 - <<'PY'
from pathlib import Path
import json, subprocess
runtime = Path('src/runtime/mod_fmr_serialized_multiswap_runtime.f90').read_text().lower()
required_docs = [
 'F-MR05_DEPENDENCIES.json','F-MR05_MULTICOLUMN_CONTRACT.json','F-MR05_BACKEND_ADMISSION.json',
 'F-MR05_TRANSACTION_ISOLATION.json','F-MR05_MASS_ACCOUNTING.json','F-MR05_STATUS.json'
]
for name in required_docs:
    assert Path('integration/f-mr',name).exists(), f'missing required F-MR05 artifact {name}'
contract = json.loads(Path('integration/f-mr/F-MR05_MULTICOLUMN_CONTRACT.json').read_text())
admission = json.loads(Path('integration/f-mr/F-MR05_BACKEND_ADMISSION.json').read_text())
isolation = json.loads(Path('integration/f-mr/F-MR05_TRANSACTION_ISOLATION.json').read_text())
mass = json.loads(Path('integration/f-mr/F-MR05_MASS_ACCOUNTING.json').read_text())
status = json.loads(Path('integration/f-mr/F-MR05_STATUS.json').read_text())
for forbidden in ['call headcalc(', 'use variables', 'use mod_grid', 'use mod_snow', 'use mod_drain', 'use mod_irrigation',
                  '!$omp', 'omp_lib', 'shadow_profile_mass', 'mass_tolerance =', 'parallel do']:
    assert forbidden not in runtime, f'F-MR05 runtime boundary leak: {forbidden}'
for required in ['fmr_run_serialized_physical_multiswap', 'fmr_build_execution_order',
                 'fmr_serialized_reference_backend_t', 'fmr_capture_checkpoint', 'fmr_commit_candidate',
                 'mass%complete', 'missing_contribution_mask', 'tx_mass_missing_none', 'state_handle',
                 'parameter_ref', 'forcing_handle', 'fmr_serialized_batch_diagnostics_t',
                 'max_simultaneous_real_physical_solves', 'physical_solve_count',
                 'authoritative_aggregate_mass', 'dispatch_ordinal', 'admission_status']:
    assert required in runtime, f'missing F-MR05 runtime contract token: {required}'
assert contract['physical_execution']['max_concurrent_real_physical_solves'] == 1
assert contract['batch_contract']['calendar_assumption'] is False
assert admission['parallel_reference_backend_admitted'] is False
assert admission['admitted_profile'] == 'EXACT_FVQ14_RESTRICTED_PROFILE_ONLY'
assert isolation['transaction_owner'] == 'F-KT08'
assert isolation['runtime_local_transaction_clone'] is False
assert mass['canonical_owner'] == 'F-KT08 kernel_result.mass'
assert mass['new_tolerance'] is False
assert status['scientific_multicolumn_admission'] is False
assert status['fmq23_resume_allowed'] is False
changed = subprocess.check_output(['git','diff','--name-only','d27af923a1522440323ca61d4f50a90914ce5b6b','HEAD','--','src'],text=True).splitlines()
assert changed == ['src/runtime/mod_fmr_serialized_multiswap_runtime.f90'], f'unexpected F-MR05 production source changes: {changed}'
print('FMR05_ARCHITECTURE_AND_REQUALIFICATION_BOUNDARY PASS')
print('FMR05_PRODUCTION_SOURCE_SCOPE_ONLY_RUNTIME_MODULE PASS')
PY

# Preserve the exact existing F-MR04 one-column serialized physical route.
bash tests/fmr/run_fmr04_gate.sh > "$BUILD/fmr04_regression.txt"
grep -Fq 'FMR04_GATE PASS' "$BUILD/fmr04_regression.txt"
echo 'FMR05_FMR04_SINGLE_COLUMN_REGRESSION PASS'

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

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/test_fmr05_serialized_multiswap.f90 -o "$OUT/test_base.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test_base.o" -o "$OUT/fmr05_serialized_multiswap"
  "$OUT/fmr05_serialized_multiswap" > "$OUT/base.txt" 2>&1 || { cat "$OUT/base.txt" >&2; exit 1; }

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/test_fmr05_strict_acceptance.f90 -o "$OUT/test_strict.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test_strict.o" -o "$OUT/fmr05_strict_acceptance"
  "$OUT/fmr05_strict_acceptance" > "$OUT/strict.txt" 2>&1 || { cat "$OUT/strict.txt" >&2; exit 1; }

  cat "$OUT/base.txt" "$OUT/strict.txt" > "$OUT/output.txt"
  for batch in 1 2 8 17 31 32; do grep -Fq "FMR05_BATCH_SIZE_${batch}=PASS" "$OUT/base.txt"; done
  grep -Fq 'FMR05_INPUT_ORDER_INDEPENDENCE=PASS' "$OUT/base.txt"
  grep -Fq 'FMR05_SINGLE_VS_MULTI_IDENTITY=PASS' "$OUT/base.txt"
  grep -Fq 'FMR05_FAILURE_ISOLATION=PASS' "$OUT/base.txt"
  grep -Fq 'FMR05_DUPLICATE_STATE_HANDLE_FAIL_CLOSED=PASS' "$OUT/base.txt"
  grep -Fq 'FMR05_AUTHORITATIVE_MASS_COMPLETE_ALL_ACCEPTED=PASS' "$OUT/base.txt"
  grep -Fq 'FMR05_TWO_COLUMN_A_B=PASS' "$OUT/strict.txt"
  grep -Fq 'FMR05_B_A_COLUMN_ID_BINDING=PASS' "$OUT/strict.txt"
  grep -Fq 'FMR05_A_B_A_REPEATABILITY=PASS' "$OUT/strict.txt"
  grep -Fq 'FMR05_IMMUTABLE_PARAMETER_SHARING=PASS' "$OUT/strict.txt"
  grep -Fq 'FMR05_UNSUPPORTED_ROOT_EXTRACTION=PASS' "$OUT/strict.txt"
  grep -Fq 'FMR05_UNSUPPORTED_MACROPORE=PASS' "$OUT/strict.txt"
  grep -Fq 'FMR05_UNSUPPORTED_SNOW=PASS' "$OUT/strict.txt"
  grep -Fq 'FMR05_UNSUPPORTED_SWKIMPL=PASS' "$OUT/strict.txt"
  grep -Fq 'FMR05_CROSS_COLUMN_CHECKPOINT_REJECTION=PASS' "$OUT/strict.txt"
  grep -Fq 'FMR05_STALE_CHECKPOINT_REJECTION=PASS' "$OUT/strict.txt"
  grep -Fq 'FMR05_ROLLBACK_A_LEAVES_A_B_UNCHANGED=PASS' "$OUT/strict.txt"
  grep -Fq 'FMR05_COMMIT_A_LEAVES_B_UNCHANGED=PASS' "$OUT/strict.txt"
  grep -Fq 'FMR05_GENERIC_TIME_1000_125_TO_1000_625=PASS' "$OUT/strict.txt"
  grep -Fq 'FMR05_MAX_SIMULTANEOUS_REAL_PHYSICAL_SOLVES=1' "$OUT/strict.txt"
  grep -Fq 'FMR05_STRICT_ACCEPTANCE_TEST PASS' "$OUT/strict.txt"
  sha256sum "$OUT/fmr05_serialized_multiswap" "$OUT/fmr05_strict_acceptance" > "$OUT/executables.sha256"
  sha256sum "$OUT/output.txt" > "$OUT/output.sha256"
  echo "FMR05_O${opt} PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FMR05_O0_O2_OUTPUT_IDENTITY PASS'
cat "$BUILD/o0/output.txt"
echo "FMR05_O0_BASE_EXECUTABLE_SHA256=$(sed -n '1s/ .*//p' "$BUILD/o0/executables.sha256")"
echo "FMR05_O0_STRICT_EXECUTABLE_SHA256=$(sed -n '2s/ .*//p' "$BUILD/o0/executables.sha256")"
echo "FMR05_O2_BASE_EXECUTABLE_SHA256=$(sed -n '1s/ .*//p' "$BUILD/o2/executables.sha256")"
echo "FMR05_O2_STRICT_EXECUTABLE_SHA256=$(sed -n '2s/ .*//p' "$BUILD/o2/executables.sha256")"
echo "FMR05_OUTPUT_SHA256=$(cut -d' ' -f1 "$BUILD/o0/output.sha256")"
echo 'FMR05_GATE PASS_STRICT_RUNTIME_CANDIDATE_REQUIRES_FVQ15'
