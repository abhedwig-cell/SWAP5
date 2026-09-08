#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpe03-fvq19-$$"
EVIDENCE_DIR="${FPE03_EVIDENCE_DIR:-$ROOT/fpe03-fvq19-evidence}"
mkdir -p "$BUILD" "$EVIDENCE_DIR"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE='54e10f990c36c6be9cdc54b4b2a430435585b04e'
OLD_FPE03='e67d624967f53184904e689333594015e9658683'
OLD_TEST_BLOB='6623613a3526c119bf1fada5540eed93346592e1'

if [[ -n "$(git diff --name-only "$BASE" HEAD -- src)" ]]; then
  echo 'FPE03_RESUME_PRODUCTION_SOURCE_CHANGED_AFTER_FPE05=FAIL' >&2
  git diff --name-only "$BASE" HEAD -- src >&2
  exit 1
fi
echo 'FPE03_RESUME_EXACT_FPE05_PRODUCTION_SOURCE=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FPE03_RESUME_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
  printf '%s  %s\n' "$actual" "$path" >> "$EVIDENCE_DIR/source-blobs.txt"
}

: > "$EVIDENCE_DIR/source-blobs.txt"
check_blob src/process/mod_snow_process.f90 54702d71b4c84dce2842813549bd14c57301a383
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 202ab846cbd30d149d0d450249b3d517e333994f
check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 7a60f8b8d18672098fed1c6890a95aac738ed21d
check_blob src/kernel/mod_kernel_transactions.f90 af42c7d51ef545e20c76d3000f1ed1493690d68e
check_blob src/transaction/mod_transaction_reference.f90 b1878606ae6cb2b04a7b4b15e3e537deacf4477f
check_blob src/runtime/mod_canonical_contracts.f90 0c2b15fc45011c580384cf6a618e7b378fdccf0a
check_blob src/runtime/mod_canonical_interval_runtime.f90 f2cae79d533343db818c11e0b61b605ac5f6739d
check_blob src/solver/mod_soil_water_solver_contract.f90 57b51997d28807fbe2da1b2e5bf654fc4167adb9
check_blob src/solver/mod_reference_richards_workspace.f90 93285b2ca24669494c93c00403e3783fca6758e9
check_blob src/solver/mod_reference_richards_state_binding.f90 e68d88382c6502c571713cc97fddd4e18434e271
check_blob src/solver/mod_b110_default_mvg_provider.f90 97d67eb373073b183be6d1bf5b756ecb5125dde2
check_blob src/solver/mod_b110_source_sink_provider.f90 d6c57add72387e5c0022a44319fff08046194aac
check_blob src/adapter/mod_reference_richards_legacy_binding.f90 eb4b74ee422bc331ed3d6abaa40dd9f85b2551c0
check_blob src/legacy/b1_10_port/headcalc.f90 be5978827095445b15de7baf607728792de6a366
check_blob tests/fsi/fsi04_real_headcalc_stubs.f90 23c00e4a188e88bc36ef95cbe4faaacdd6aad639
check_blob tests/fmr/mod_fmr04_fixed_top_provider.f90 942c56e3ba2b1739506e1d5b0ac889e6fd163ea7

git show "$OLD_FPE03":tests/fpe/test_fpe03_reference_stress.f90 > "$BUILD/test_fpe03_reference_stress.f90"
actual_old_blob="$(git hash-object "$BUILD/test_fpe03_reference_stress.f90")"
[[ "$actual_old_blob" == "$OLD_TEST_BLOB" ]] || {
  echo "FPE03_RESUME_OLD_HARNESS_BLOB_MISMATCH expected=$OLD_TEST_BLOB actual=$actual_old_blob" >&2
  exit 1
}
echo "FPE03_RESUME_IMMUTABLE_HISTORICAL_HARNESS=$actual_old_blob" | tee "$EVIDENCE_DIR/harness-lock.txt"

python3 - <<'PY' | tee "$EVIDENCE_DIR/governance-audit.txt"
import json
from pathlib import Path
status = json.loads(Path('integration/f-pe/F-PE05_STATUS.json').read_text())
assert status['status'] == 'QUALIFIED_REFERENCE_NONSTATIONARY_TEMPORAL_ACCEPTANCE_AND_COST_CHARACTERIZATION'
assert status['fpe03_b01'] == 'RESOLVED_FOR_REFERENCE_CHARACTERIZATION_RESUME'
assert status['fpe02_b01'] == 'BLOCKED_SHARED_SEMANTICS_REQUIRES_FMR_FVQ_REQUALIFICATION'
assert status['BALANCED'] == 'DEFINED_NOT_ADMITTED'
assert status['THROUGHPUT'] == 'DEFINED_NOT_ADMITTED'
assert status['FALLBACK'] == 'DEFINED_NOT_ADMITTED'
print('FPE03_RESUME_FPE05_QUALIFIED_DEPENDENCY=PASS')
print('FPE03_RESUME_FPE02_B01_STILL_BLOCKED=PASS')
print('FPE03_RESUME_NON_REFERENCE_POLICY_NOT_ADMITTED=PASS')
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
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c "$BUILD/test_fpe03_reference_stress.f90" -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/fpe03-resume"
  "$OUT/fpe03-resume" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }
  grep -Fq 'FPE03_REFERENCE_STRESS_CHARACTERIZATION PASS' "$OUT/output.txt"
  grep -Fq 'FPE03_REPRESENTATIVE_TAIL_PERCENTILES=NOT_CLAIMED' "$OUT/output.txt"
  grep -Fq 'FPE03_BOUNDED_COST_POLICY_ADMISSION=NOT_IN_SCOPE' "$OUT/output.txt"
  cp "$OUT/output.txt" "$EVIDENCE_DIR/stress-o${opt}.txt"
  sha256sum "$OUT/output.txt" > "$EVIDENCE_DIR/stress-o${opt}.sha256"
  echo "FPE03_RESUME_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FPE03_RESUME_O0_O2_OUTPUT_IDENTITY=PASS'

grep -E '^FPE03_(ACCEPTED_CASES|REJECTED_CASES|HIGHER_COST_ACCEPTED_CASES|BASELINE_|MAX_ACCEPTED_|MAX_ALL_|ACCEPTED_HIGHER_COST_PHYSICAL_STRESS_FIXTURE)' \
  "$BUILD/o0/output.txt" | tee "$EVIDENCE_DIR/current-metrics.txt"

python3 - "$EVIDENCE_DIR/current-metrics.txt" <<'PY' | tee "$EVIDENCE_DIR/historical-comparison.txt"
import sys
from pathlib import Path
vals = {}
for line in Path(sys.argv[1]).read_text().splitlines():
    if '=' in line:
        k,v=line.split('=',1); vals[k]=v
hist = {
    'FPE03_ACCEPTED_CASES':'6',
    'FPE03_REJECTED_CASES':'18',
    'FPE03_HIGHER_COST_ACCEPTED_CASES':'0',
    'FPE03_BASELINE_HEADCALC_CALLS':'3',
    'FPE03_BASELINE_NONLINEAR_ITERATIONS':'3',
    'FPE03_BASELINE_BACKTRACKING_ATTEMPTS':'3',
    'FPE03_MAX_ALL_NONLINEAR_ITERATIONS':'24',
    'FPE03_MAX_ALL_BACKTRACKING_ATTEMPTS':'96',
    'FPE03_MAX_ALL_INTERNAL_RETRIES':'3',
}
identical = all(vals.get(k)==v for k,v in hist.items())
print('FPE03_RESUME_HISTORICAL_KEY_METRICS_IDENTITY=' + ('PASS' if identical else 'CHANGED_CHARACTERIZATION'))
for k,v in hist.items():
    print(f'{k}_HISTORICAL={v}_CURRENT={vals.get(k,"MISSING")}')
PY

{
  echo 'FPE03_RESUME_GATE=PASS_CURRENT_LINEAGE_CHARACTERIZATION'
  echo 'FPE03_RESUME_SCIENTIFIC_ADMISSION_EXPANDED=NO'
  echo 'FPE03_RESUME_BOUNDED_COST_POLICY_ADMITTED=NO'
  echo 'FPE03_RESUME_NEXT=DERIVE_SMALLEST_DIAGNOSTIC_NONSTATIONARY_STRESS_OVERLAY'
} | tee "$EVIDENCE_DIR/summary.txt"

cat "$BUILD/o0/output.txt"
cat "$EVIDENCE_DIR/historical-comparison.txt"
cat "$EVIDENCE_DIR/summary.txt"
