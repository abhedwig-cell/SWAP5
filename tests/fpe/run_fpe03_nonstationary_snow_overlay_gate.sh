#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpe03-snow-overlay-$$"
EVIDENCE_DIR="${FPE03_OVERLAY_EVIDENCE_DIR:-$ROOT/fpe03-snow-overlay-evidence}"
BASE='54e10f990c36c6be9cdc54b4b2a430435585b04e'
OLD_FPE03='e67d624967f53184904e689333594015e9658683'
OLD_TEST_BLOB='6623613a3526c119bf1fada5540eed93346592e1'
FMR06_BLOB='ed4b742b76e97ff0ad27b386850c1d093e4f03d1'
mkdir -p "$BUILD" "$EVIDENCE_DIR"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

if [[ -n "$(git diff --name-only "$BASE" HEAD -- src)" ]]; then
  echo 'FPE03_SNOW_OVERLAY_PRODUCTION_SOURCE_CHANGED_AFTER_FPE05=FAIL' >&2
  git diff --name-only "$BASE" HEAD -- src >&2
  exit 1
fi
echo 'FPE03_SNOW_OVERLAY_EXACT_FPE05_PRODUCTION_SOURCE=PASS'

actual_fmr06="$(git hash-object tests/fmr/test_fmr06_snow_multiswap.f90)"
[[ "$actual_fmr06" == "$FMR06_BLOB" ]] || {
  echo "FPE03_SNOW_OVERLAY_FMR06_FIXTURE_MISMATCH expected=$FMR06_BLOB actual=$actual_fmr06" >&2
  exit 1
}

git show "$OLD_FPE03":tests/fpe/test_fpe03_reference_stress.f90 > "$BUILD/old-fpe03.f90"
actual_old="$(git hash-object "$BUILD/old-fpe03.f90")"
[[ "$actual_old" == "$OLD_TEST_BLOB" ]] || {
  echo "FPE03_SNOW_OVERLAY_OLD_FPE03_MISMATCH expected=$OLD_TEST_BLOB actual=$actual_old" >&2
  exit 1
}

python3 tests/fpe/fpe03_make_nonstationary_snow_overlay.py \
  "$BUILD/old-fpe03.f90" tests/fmr/test_fmr06_snow_multiswap.f90 "$BUILD/overlay.f90" \
  | tee "$EVIDENCE_DIR/generation.txt"

grep -Fq 'FPE03_FMR06_ACTIVE_SNOW_SOURCE_ANCHORS=PASS' "$EVIDENCE_DIR/generation.txt"
grep -Fq 'FPE03_NONSTATIONARY_PERTURBATION_COUNT=3' "$EVIDENCE_DIR/generation.txt"
grep -Fq 'FPE03_NONSTATIONARY_PERTURBATIONS_SCIENTIFIC_ADMISSION=NO' "$EVIDENCE_DIR/generation.txt"
sha256sum "$BUILD/overlay.f90" > "$EVIDENCE_DIR/generated-overlay.sha256"

python3 - <<'PY' | tee "$EVIDENCE_DIR/governance-audit.txt"
import json
from pathlib import Path
s = json.loads(Path('integration/f-pe/F-PE05_STATUS.json').read_text())
assert s['status'] == 'QUALIFIED_REFERENCE_NONSTATIONARY_TEMPORAL_ACCEPTANCE_AND_COST_CHARACTERIZATION'
assert s['fpe03_b01'] == 'RESOLVED_FOR_REFERENCE_CHARACTERIZATION_RESUME'
assert s['fpe02_b01'] == 'BLOCKED_SHARED_SEMANTICS_REQUIRES_FMR_FVQ_REQUALIFICATION'
assert s['BALANCED'] == 'DEFINED_NOT_ADMITTED'
assert s['THROUGHPUT'] == 'DEFINED_NOT_ADMITTED'
assert s['FALLBACK'] == 'DEFINED_NOT_ADMITTED'
print('FPE03_SNOW_OVERLAY_REFERENCE_ONLY=PASS')
print('FPE03_SNOW_OVERLAY_FPE02_B01_REMAINS_BLOCKED=PASS')
print('FPE03_SNOW_OVERLAY_NO_POLICY_ADMISSION=PASS')
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

  # Re-run the immutable admitted FMR06 MultiSWAP fixture as the current-lineage control.
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/fmr/test_fmr06_snow_multiswap.f90 -o "$OUT/fmr06.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/fmr06.o" -o "$OUT/fmr06"
  "$OUT/fmr06" > "$OUT/fmr06.txt" 2>&1 || { cat "$OUT/fmr06.txt" >&2; exit 1; }
  grep -Fq 'FMR06_SNOW_MULTISWAP_TEST PASS' "$OUT/fmr06.txt"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/overlay.f90" -o "$OUT/overlay.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/overlay.o" -o "$OUT/overlay"
  "$OUT/overlay" > "$OUT/overlay-a.txt" 2>&1 || { cat "$OUT/overlay-a.txt" >&2; exit 1; }
  "$OUT/overlay" > "$OUT/overlay-b.txt" 2>&1 || { cat "$OUT/overlay-b.txt" >&2; exit 1; }
  grep -Fq 'FPE03_NONSTATIONARY_BASELINE_FPE05_COST_IDENTITY=PASS' "$OUT/overlay-a.txt"
  grep -Fq 'FPE03_NONSTATIONARY_SNOW_PERTURBATIONS=DIAGNOSTIC_NOT_SCIENTIFIC_ADMISSION' "$OUT/overlay-a.txt"
  grep -Fq 'FPE03_NONSTATIONARY_SNOW_OVERLAY PASS' "$OUT/overlay-a.txt"
  cmp "$OUT/overlay-a.txt" "$OUT/overlay-b.txt"

  cp "$OUT/fmr06.txt" "$EVIDENCE_DIR/fmr06-control-o${opt}.txt"
  cp "$OUT/overlay-a.txt" "$EVIDENCE_DIR/overlay-o${opt}.txt"
  sha256sum "$OUT/fmr06.txt" "$OUT/overlay-a.txt" > "$EVIDENCE_DIR/output-o${opt}.sha256"
  echo "FPE03_SNOW_OVERLAY_O${opt}=PASS"
done

cmp "$BUILD/o0/fmr06.txt" "$BUILD/o2/fmr06.txt"
cmp "$BUILD/o0/overlay-a.txt" "$BUILD/o2/overlay-a.txt"
echo 'FPE03_SNOW_OVERLAY_FMR06_CONTROL_O0_O2_IDENTITY=PASS'
echo 'FPE03_SNOW_OVERLAY_O0_O2_IDENTITY=PASS'

python3 - "$BUILD/o0/overlay-a.txt" <<'PY' | tee "$EVIDENCE_DIR/classification.txt"
import re, sys
from pathlib import Path
lines = Path(sys.argv[1]).read_text().splitlines()
vals = {}
for line in lines:
    if '=' in line:
        k,v = line.split('=',1)
        vals[k.strip()] = v.strip()

assert vals.get('FPE03_CASE_01_ACCEPTED') == 'T'
expected = {
    'FPE03_CASE_01_ACCEPTED_SUBSTEPS':'1',
    'FPE03_CASE_01_NONLINEAR_ITERATIONS':'3',
    'FPE03_CASE_01_INTERNAL_RETRIES':'0',
    'FPE03_CASE_01_HEADCALC_CALLS':'3',
    'FPE03_CASE_01_JACOBIAN_BUILDS':'3',
    'FPE03_CASE_01_LINEAR_SOLVES':'3',
    'FPE03_CASE_01_BACKTRACKING_ATTEMPTS':'3',
    'FPE03_CASE_01_ALTERNATIVE_SOLVER_CALLS':'0',
}
for k,v in expected.items():
    assert vals.get(k) == v, (k, vals.get(k), v)

accepted = []
rejected = []
higher = []
for i in range(2,5):
    p = f'FPE03_CASE_{i:02d}_'
    if vals.get(p+'ACCEPTED') == 'T':
        accepted.append(i)
        if (int(vals[p+'NONLINEAR_ITERATIONS']) > 3 or
            int(vals[p+'HEADCALC_CALLS']) > 3 or
            int(vals[p+'JACOBIAN_BUILDS']) > 3 or
            int(vals[p+'LINEAR_SOLVES']) > 3 or
            int(vals[p+'BACKTRACKING_ATTEMPTS']) > 3 or
            int(vals[p+'INTERNAL_RETRIES']) > 0):
            higher.append(i)
    else:
        rejected.append(i)

print(f'FPE03_SNOW_OVERLAY_PERTURBED_ACCEPTED={len(accepted)}')
print(f'FPE03_SNOW_OVERLAY_PERTURBED_REJECTED={len(rejected)}')
print(f'FPE03_SNOW_OVERLAY_PERTURBED_ACCEPTED_HIGHER_COST={len(higher)}')
print('FPE03_SNOW_OVERLAY_ACCEPTED_CASE_IDS=' + ','.join(map(str,accepted)))
print('FPE03_SNOW_OVERLAY_REJECTED_CASE_IDS=' + ','.join(map(str,rejected)))
print('FPE03_SNOW_OVERLAY_HIGHER_COST_CASE_IDS=' + ','.join(map(str,higher)))
if higher:
    result = 'PROMISING_ACCEPTED_HIGHER_COST_DIAGNOSTIC_CASE_FOUND_REQUIRES_INDEPENDENT_SCIENTIFIC_ADMISSION'
elif rejected:
    result = 'DIAGNOSTIC_COST_CLIFF_PERSISTS_NO_ACCEPTED_DIFFICULT_CASE'
else:
    result = 'ALL_PERTURBATIONS_ACCEPT_LOW_COST_NO_DIFFICULT_CASE_FOUND'
print('FPE03_SNOW_OVERLAY_CLASSIFICATION=' + result)
print('FPE03_SNOW_OVERLAY_SCIENTIFIC_ADMISSION_EXPANDED=NO')
print('FPE03_SNOW_OVERLAY_BOUNDED_COST_POLICY_ADMITTED=NO')
PY

{
  echo 'FPE03_NONSTATIONARY_SNOW_OVERLAY_GATE=PASS_CHARACTERIZATION_ONLY'
  echo 'FPE03_NONSTATIONARY_SNOW_OVERLAY_PRODUCTION_SOURCE_CHANGED=NO'
  echo 'FPE03_NONSTATIONARY_SNOW_OVERLAY_PERTURBATIONS_REQUIRE_FVQ_BEFORE_PRODUCTION_CLAIMS=YES'
} | tee "$EVIDENCE_DIR/summary.txt"

cat "$EVIDENCE_DIR/classification.txt"
cat "$EVIDENCE_DIR/summary.txt"
