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
check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 915b7c9bf27cf56ac2669a8354ef385e38a7ef54

echo 'FMR05_EXACT_BASELINE_AND_SOURCE_BLOBS PASS'
echo 'FMR05_FMR04_QUALIFIED_SOURCE_BLOBS_FORWARD PASS'

python3 - <<'PY'
from pathlib import Path
import json
runtime = Path('src/runtime/mod_fmr_serialized_multiswap_runtime.f90').read_text().lower()
contract = json.loads(Path('integration/f-mr/F-MR05_DISPATCH_CONTRACT.json').read_text())
ownership = json.loads(Path('integration/f-mr/F-MR05_OWNERSHIP.json').read_text())
deps = json.loads(Path('integration/f-mr/F-MR05_DEPENDENCIES.json').read_text())
status = json.loads(Path('integration/f-mr/F-MR05_STATUS.json').read_text())
for forbidden in ['call headcalc(', 'use variables', 'use mod_grid', 'use mod_snow', 'use mod_drain', 'use mod_irrigation',
                  '!$omp', 'omp_lib', 'shadow_profile_mass', 'mass_tolerance =', 'parallel do']:
    assert forbidden not in runtime, f'F-MR05 runtime boundary leak: {forbidden}'
for required in ['fmr_run_serialized_physical_multiswap', 'fmr_build_execution_order',
                 'fmr_serialized_reference_backend_t', 'fmr_capture_checkpoint', 'fmr_commit_candidate',
                 'mass%complete', 'missing_contribution_mask', 'tx_mass_missing_none',
                 'aggregate_unrounded_mass_residual', 'state_handle', 'parameter_ref', 'forcing_handle']:
    assert required in runtime, f'missing F-MR05 runtime contract token: {required}'
assert contract['physical_parallelism'] == 1
assert ownership['serialization']['physical_worker_count'] == 1
assert ownership['serialization']['parallel_reference_backend_admitted'] is False
assert deps['dependencies']['F-VQ14']['qualified_source_commit'] == '11eb34ea3afe8f5dda0515c28d7e08428dd2e272'
assert deps['post_source_change_requirement']['f_vq14_admission_inherited_by_modified_source'] is False
assert status['required_postchange_requalification'] == 'F-VQ15'
print('FMR05_ARCHITECTURE_AND_REQUALIFICATION_BOUNDARY PASS')
PY

# Build an instrumented test copy only. Production source and the persisted focused
# test remain unchanged; this run is evidence gathering, not qualification.
DIAG_TEST="$BUILD/test_fmr05_mass_diagnostic.f90"
python3 - "$DIAG_TEST" <<'PY'
from pathlib import Path
import sys
src = Path('tests/fmr/test_fmr05_serialized_multiswap.f90').read_text()
src = src.replace(
"      call require(results(i)%mass%residual == 0.0_real64, 'accepted exact mass residual')",
"      write(*,'(A,I0,A,ES26.17E3)') 'FMR05_COLUMN_', results(i)%column_id, '_MASS_RESIDUAL=', results(i)%mass%residual\n      call require(abs(results(i)%mass%residual) <= 1.0e-12_real64, 'accepted F-KT hard mass residual')")
src = src.replace(
"      call require(results(i)%mass%total_in == results(i)%mass%total_out, 'accepted total in/out identity')",
"      call require(abs(results(i)%mass%total_in-results(i)%mass%total_out) <= 1.0e-12_real64, 'accepted in/out difference within hard mass gate')")
src = src.replace(
"      call require(diagnostics(i)%unrounded_mass_residual == 0.0_real64, 'diagnostic exact residual')",
"      call require(same_bits(diagnostics(i)%unrounded_mass_residual,results(i)%mass%residual), 'diagnostic authoritative residual identity')")
src = src.replace(
"    call require(aggregate%aggregate_unrounded_mass_residual == 0.0_real64, 'aggregate exact residual')",
"    write(*,'(A,ES26.17E3)') 'FMR05_DIAGNOSTIC_AGGREGATE_RESIDUAL=', aggregate%aggregate_unrounded_mass_residual")
src = src.replace(
"    call require(aggregate%aggregate_unrounded_mass_residual == 0.0_real64, 'failure case aggregate residual')",
"    write(*,'(A,ES26.17E3)') 'FMR05_DIAGNOSTIC_FAILURE_AGGREGATE_RESIDUAL=', aggregate%aggregate_unrounded_mass_residual")
src = src.replace(
"        call require(results(i)%mass%residual == 0.0_real64, 'neighbor exact residual')",
"        call require(abs(results(i)%mass%residual) <= 1.0e-12_real64, 'neighbor F-KT hard mass residual')")
src = src.replace(
"  call require(baseline_aggregate%aggregate_unrounded_mass_residual == 0.0_real64, 'aggregate exact mass identity')",
"  write(*,'(A,ES26.17E3)') 'FMR05_BASELINE_AGGREGATE_RESIDUAL=', baseline_aggregate%aggregate_unrounded_mass_residual")
src = src.replace(
"  write(*,'(A)') 'FMR05_AGGREGATE_UNROUNDED_MASS_RESIDUAL=0x0.0p+0'",
"  write(*,'(A,ES26.17E3)') 'FMR05_AGGREGATE_UNROUNDED_MASS_RESIDUAL=', baseline_aggregate%aggregate_unrounded_mass_residual")
Path(sys.argv[1]).write_text(src)
PY

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
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
  "$DIAG_TEST"
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
  gfortran -O"$opt" "${objects[@]}" -o "$OUT/fmr05_serialized_multiswap"
  "$OUT/fmr05_serialized_multiswap" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }
  for batch in 1 2 8 17 31 32; do grep -Fq "FMR05_BATCH_SIZE_${batch}=PASS" "$OUT/output.txt"; done
  grep -Fq 'FMR05_INPUT_ORDER_INDEPENDENCE=PASS' "$OUT/output.txt"
  grep -Fq 'FMR05_SINGLE_VS_MULTI_IDENTITY=PASS' "$OUT/output.txt"
  grep -Fq 'FMR05_FAILURE_ISOLATION=PASS' "$OUT/output.txt"
  grep -Fq 'FMR05_DUPLICATE_STATE_HANDLE_FAIL_CLOSED=PASS' "$OUT/output.txt"
  grep -Fq 'FMR05_PHYSICAL_WORKER_COUNT=1' "$OUT/output.txt"
  grep -Fq 'FMR05_PARALLEL_REFERENCE_BACKEND=NOT_ADMITTED' "$OUT/output.txt"
  grep -Fq 'FMR05_AUTHORITATIVE_MASS_COMPLETE_ALL_ACCEPTED=PASS' "$OUT/output.txt"
  grep -Fq 'FMR05_REAL_HEADCALC_MULTICOLUMN=PASS' "$OUT/output.txt"
  grep -Fq 'FMR05_SERIALIZED_MULTISWAP_TEST PASS' "$OUT/output.txt"
  echo "FMR05_DIAGNOSTIC_O${opt} COMPLETE"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FMR05_DIAGNOSTIC_O0_O2_OUTPUT_IDENTITY PASS'
cat "$BUILD/o0/output.txt"
echo 'FMR05_GATE DIAGNOSTIC_ONLY_NOT_QUALIFICATION'
