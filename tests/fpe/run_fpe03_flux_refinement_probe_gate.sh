#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpe03-flux-refinement-$$"
EVIDENCE_DIR="${FPE03_FLUX_REFINEMENT_EVIDENCE_DIR:-$ROOT/fpe03-flux-refinement-evidence}"
BASE='54e10f990c36c6be9cdc54b4b2a430435585b04e'
OLD_FPE03='e67d624967f53184904e689333594015e9658683'
OLD_TEST_BLOB='6623613a3526c119bf1fada5540eed93346592e1'
FMR06_BLOB='ed4b742b76e97ff0ad27b386850c1d093e4f03d1'
mkdir -p "$BUILD" "$EVIDENCE_DIR"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

if [[ -n "$(git diff --name-only "$BASE" HEAD -- src)" ]]; then
  echo 'FPE03_FLUX_REFINEMENT_PRODUCTION_SOURCE_CHANGED_AFTER_FPE05=FAIL' >&2
  git diff --name-only "$BASE" HEAD -- src >&2
  exit 1
fi
echo 'FPE03_FLUX_REFINEMENT_EXACT_FPE05_PRODUCTION_SOURCE=PASS'

actual_fmr06="$(git hash-object tests/fmr/test_fmr06_snow_multiswap.f90)"
[[ "$actual_fmr06" == "$FMR06_BLOB" ]] || {
  echo "FPE03_FLUX_REFINEMENT_FMR06_FIXTURE_MISMATCH expected=$FMR06_BLOB actual=$actual_fmr06" >&2
  exit 1
}

git show "$OLD_FPE03":tests/fpe/test_fpe03_reference_stress.f90 > "$BUILD/old-fpe03.f90"
actual_old="$(git hash-object "$BUILD/old-fpe03.f90")"
[[ "$actual_old" == "$OLD_TEST_BLOB" ]] || {
  echo "FPE03_FLUX_REFINEMENT_OLD_FPE03_MISMATCH expected=$OLD_TEST_BLOB actual=$actual_old" >&2
  exit 1
}

python3 tests/fpe/fpe03_make_nonstationary_snow_overlay.py \
  "$BUILD/old-fpe03.f90" tests/fmr/test_fmr06_snow_multiswap.f90 "$BUILD/base-overlay.f90" \
  > "$EVIDENCE_DIR/base-generation.txt"
python3 tests/fpe/fpe03_make_flux_refinement_probe.py \
  "$BUILD/base-overlay.f90" "$BUILD/refinement.f90" \
  | tee "$EVIDENCE_DIR/refinement-generation.txt"

grep -Fq 'FPE03_FMR06_ACTIVE_SNOW_SOURCE_ANCHORS=PASS' "$EVIDENCE_DIR/base-generation.txt"
grep -Fq 'FPE03_FLUX_REFINEMENT_CASES=11' "$EVIDENCE_DIR/refinement-generation.txt"
grep -Fq 'FPE03_FLUX_REFINEMENT_NONZERO_PERTURBATIONS=10' "$EVIDENCE_DIR/refinement-generation.txt"
grep -Fq 'FPE03_FLUX_REFINEMENT_SCIENTIFIC_ADMISSION_EXPANDED=NO' "$EVIDENCE_DIR/refinement-generation.txt"
sha256sum "$BUILD/base-overlay.f90" "$BUILD/refinement.f90" > "$EVIDENCE_DIR/generated-probes.sha256"

python3 - <<'PY' | tee "$EVIDENCE_DIR/governance-audit.txt"
import json
from pathlib import Path
s = json.loads(Path('integration/f-pe/F-PE05_STATUS.json').read_text())
r = json.loads(Path('integration/f-pe/F-PE03_COST_CLIFF_ROOT_CAUSE.json').read_text())
b = json.loads(Path('integration/f-pe/F-PE03_FLUX_BOUNDARY_EVIDENCE.json').read_text())
assert s['status'] == 'QUALIFIED_REFERENCE_NONSTATIONARY_TEMPORAL_ACCEPTANCE_AND_COST_CHARACTERIZATION'
assert r['status'] == 'SOURCE_BOUND_COST_CLIFF_LOCALIZED_TO_FULL_TRIAL_RICHARDS_NONCONVERGENCE'
assert b['status'] == 'DETERMINISTIC_REFERENCE_FLUX_CONVERGENCE_BOUNDARY_BRACKETED_NO_HIGHER_COST_ACCEPTANCE'
assert b['boundary_interpretation']['largest_tested_accepted_relative_perturbation'] == 1e-12
assert b['boundary_interpretation']['smallest_tested_rejected_relative_perturbation'] == 1e-10
assert s['fpe02_b01'] == 'BLOCKED_SHARED_SEMANTICS_REQUIRES_FMR_FVQ_REQUALIFICATION'
assert s['BALANCED'] == 'DEFINED_NOT_ADMITTED'
assert s['THROUGHPUT'] == 'DEFINED_NOT_ADMITTED'
assert s['FALLBACK'] == 'DEFINED_NOT_ADMITTED'
print('FPE03_FLUX_REFINEMENT_REFERENCE_ONLY=PASS')
print('FPE03_FLUX_REFINEMENT_PRIOR_BRACKET_LOCK=PASS')
print('FPE03_FLUX_REFINEMENT_FPE02_B01_REMAINS_BLOCKED=PASS')
print('FPE03_FLUX_REFINEMENT_NO_POLICY_ADMISSION=PASS')
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

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/refinement.f90" -o "$OUT/probe.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/probe.o" -o "$OUT/probe"
  "$OUT/probe" > "$OUT/probe-a.txt" 2>&1 || { cat "$OUT/probe-a.txt" >&2; exit 1; }
  "$OUT/probe" > "$OUT/probe-b.txt" 2>&1 || { cat "$OUT/probe-b.txt" >&2; exit 1; }
  grep -Fq 'FPE03_NONSTATIONARY_BASELINE_FPE05_COST_IDENTITY=PASS' "$OUT/probe-a.txt"
  grep -Fq 'FPE03_FLUX_REFINEMENT_PERTURBATIONS=DIAGNOSTIC_NOT_SCIENTIFIC_ADMISSION' "$OUT/probe-a.txt"
  grep -Fq 'FPE03_FLUX_REFINEMENT_PROBE PASS' "$OUT/probe-a.txt"
  cmp "$OUT/probe-a.txt" "$OUT/probe-b.txt"
  cp "$OUT/probe-a.txt" "$EVIDENCE_DIR/probe-o${opt}.txt"
  sha256sum "$OUT/probe-a.txt" > "$EVIDENCE_DIR/output-o${opt}.sha256"
  echo "FPE03_FLUX_REFINEMENT_O${opt}=PASS"
done

cmp "$BUILD/o0/probe-a.txt" "$BUILD/o2/probe-a.txt"
echo 'FPE03_FLUX_REFINEMENT_O0_O2_IDENTITY=PASS'

python3 - "$BUILD/o0/probe-a.txt" <<'PY' | tee "$EVIDENCE_DIR/classification.txt"
import sys
from pathlib import Path

lines = Path(sys.argv[1]).read_text().splitlines()
vals = {}
for line in lines:
    if '=' in line:
        k, v = line.split('=', 1)
        vals[k.strip()] = v.strip()

baseline = {
    'ACCEPTED':'T',
    'ACCEPTED_SUBSTEPS':'1',
    'NONLINEAR_ITERATIONS':'3',
    'INTERNAL_RETRIES':'0',
    'HEADCALC_CALLS':'3',
    'JACOBIAN_BUILDS':'3',
    'LINEAR_SOLVES':'3',
    'BACKTRACKING_ATTEMPTS':'3',
    'ALTERNATIVE_SOLVER_CALLS':'0',
}
for suffix, expected in baseline.items():
    key = 'FPE03_CASE_01_' + suffix
    assert vals.get(key) == expected, (key, vals.get(key), expected)

levels = [1e-10, 3e-11, 1e-11, 3e-12, 1e-12]
accepted = {'plus': [], 'minus': []}
rejected = {'plus': [], 'minus': []}
higher = []
rejected_vectors = set()
accepted_vectors = set()
for j, level in enumerate(levels):
    for offset, sign in [(0, 'plus'), (1, 'minus')]:
        i = 2 + 2*j + offset
        p = f'FPE03_CASE_{i:02d}_'
        metrics = (
            int(vals[p+'NONLINEAR_ITERATIONS']),
            int(vals[p+'INTERNAL_RETRIES']),
            int(vals[p+'HEADCALC_CALLS']),
            int(vals[p+'JACOBIAN_BUILDS']),
            int(vals[p+'LINEAR_SOLVES']),
            int(vals[p+'BACKTRACKING_ATTEMPTS']),
            int(vals[p+'ALTERNATIVE_SOLVER_CALLS']),
        )
        if vals.get(p+'ACCEPTED') == 'T':
            accepted[sign].append(level)
            accepted_vectors.add(metrics)
            if metrics != (3,0,3,3,3,3,0):
                higher.append((sign, level, metrics))
        else:
            rejected[sign].append(level)
            rejected_vectors.add(metrics)

fmt = lambda xs: ','.join(f'{x:.0e}' for x in xs)
print('FPE03_FLUX_REFINEMENT_PLUS_ACCEPTED_LEVELS=' + fmt(accepted['plus']))
print('FPE03_FLUX_REFINEMENT_PLUS_REJECTED_LEVELS=' + fmt(rejected['plus']))
print('FPE03_FLUX_REFINEMENT_MINUS_ACCEPTED_LEVELS=' + fmt(accepted['minus']))
print('FPE03_FLUX_REFINEMENT_MINUS_REJECTED_LEVELS=' + fmt(rejected['minus']))
print(f'FPE03_FLUX_REFINEMENT_ACCEPTED_NONZERO={len(accepted["plus"])+len(accepted["minus"])}')
print(f'FPE03_FLUX_REFINEMENT_ACCEPTED_HIGHER_COST={len(higher)}')
print('FPE03_FLUX_REFINEMENT_ACCEPTED_COST_VECTORS=' + ';'.join(','.join(map(str,v)) for v in sorted(accepted_vectors)))
print('FPE03_FLUX_REFINEMENT_REJECTED_COST_VECTORS=' + ';'.join(','.join(map(str,v)) for v in sorted(rejected_vectors)))

for sign in ('plus','minus'):
    if accepted[sign] and rejected[sign]:
        largest_accepted = max(accepted[sign])
        smallest_rejected = min(rejected[sign])
        print(f'FPE03_FLUX_REFINEMENT_{sign.upper()}_LARGEST_ACCEPTED={largest_accepted:.0e}')
        print(f'FPE03_FLUX_REFINEMENT_{sign.upper()}_SMALLEST_REJECTED={smallest_rejected:.0e}')

if higher:
    classification = 'ACCEPTED_HIGHER_COST_TRANSITION_ROUTE_FOUND_REQUIRES_INDEPENDENT_SCIENTIFIC_ADMISSION'
elif accepted['plus'] and accepted['minus'] and rejected['plus'] and rejected['minus']:
    classification = 'BINARY_LOW_COST_OR_FULL_RETRY_TRANSITION_REFINED_NO_INTERMEDIATE_COST_ROUTE'
else:
    classification = 'ASYMMETRIC_OR_UNBRACKETED_TRANSITION_REQUIRES_REVIEW'
print('FPE03_FLUX_REFINEMENT_CLASSIFICATION=' + classification)
print('FPE03_FLUX_REFINEMENT_SCIENTIFIC_ADMISSION_EXPANDED=NO')
print('FPE03_FLUX_REFINEMENT_BOUNDED_COST_POLICY_ADMITTED=NO')
PY

{
  echo 'FPE03_FLUX_REFINEMENT_GATE=PASS_CHARACTERIZATION_ONLY'
  echo 'FPE03_FLUX_REFINEMENT_PRODUCTION_SOURCE_CHANGED=NO'
  echo 'FPE03_FLUX_REFINEMENT_SOLVER_CONTROLS_CHANGED=NO'
  echo 'FPE03_FLUX_REFINEMENT_FURTHER_BISECTION_IN_FPE03=NOT_PLANNED'
  echo 'FPE03_FLUX_REFINEMENT_PERTURBATIONS_REQUIRE_FVQ_BEFORE_PRODUCTION_CLAIMS=YES'
} | tee "$EVIDENCE_DIR/summary.txt"

cat "$EVIDENCE_DIR/classification.txt"
cat "$EVIDENCE_DIR/summary.txt"
