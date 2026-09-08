#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE='a6470b90f100b7ed9837c5e092b39d011fd28476'
BUILD="${TMPDIR:-/tmp}/swap5-fsi18-cliff-$$"
EVIDENCE_DIR="${FSI18_EVIDENCE_DIR:-$ROOT/fsi18-convergence-cliff-evidence}"
mkdir -p "$BUILD" "$EVIDENCE_DIR"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

if [[ -n "$(git diff --name-only "$BASE" HEAD -- src)" ]]; then
  echo 'FSI18_PRODUCTION_SOURCE_CHANGED_BEFORE_REPRODUCTION=FAIL' >&2
  git diff --name-only "$BASE" HEAD -- src >&2
  exit 1
fi
echo 'FSI18_EXACT_FSI16_PRODUCTION_SOURCE=PASS'

[[ "$(git rev-parse HEAD:src/legacy/b1_10_port/headcalc.f90)" == 'd92f77963329d61ab3feb988f912252c0161436c' ]] || {
  echo 'FSI18_HEADCALC_SOURCE_LOCK=FAIL' >&2; exit 1; }
[[ "$(git rev-parse HEAD:src/adapter/mod_reference_richards_legacy_binding.f90)" == '18c59ab9c63d206bf2af3678dacadfc3fd6de94c' ]] || {
  echo 'FSI18_ADAPTER_SOURCE_LOCK=FAIL' >&2; exit 1; }
echo 'FSI18_FSI16_OWNER_SOURCE_LOCK=PASS'

python3 - <<'PY' | tee "$EVIDENCE_DIR/contract-audit.txt"
import json
from pathlib import Path
c=json.loads(Path('integration/f-si/F-SI18_CONTRACT.json').read_text())
assert c['base_head']=='a6470b90f100b7ed9837c5e092b39d011fd28476'
assert c['status']=='AUDIT_AND_REPRODUCTION_AUTHORIZED_PRODUCTION_EDITS_BLOCKED'
assert c['hard_constraints']['production_edit_before_reproduction'] is False
assert c['hard_constraints']['change_reference_solver_controls_to_manufacture_tail'] is False
assert c['hard_constraints']['mass_conservation_remains_hard'] is True
print('FSI18_CONTRACT_AUDIT=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SOURCES=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  tests/fsi/mod_fsi07_top_provider.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for src in "${SOURCES[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -Werror -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/fsi/test_fsi18_reference_convergence_cliff.F90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/run-a.txt" 2>&1 || { cat "$OUT/run-a.txt" >&2; exit 1; }
  "$OUT/test" > "$OUT/run-b.txt" 2>&1 || { cat "$OUT/run-b.txt" >&2; exit 1; }
  cmp "$OUT/run-a.txt" "$OUT/run-b.txt"
  grep -Fq 'FSI18_REFERENCE_CONVERGENCE_CLIFF_PROBE PASS' "$OUT/run-a.txt"
  cp "$OUT/run-a.txt" "$EVIDENCE_DIR/probe-o${opt}.txt"
  sha256sum "$OUT/run-a.txt" > "$EVIDENCE_DIR/probe-o${opt}.sha256"
  echo "FSI18_O${opt}=PASS"
done

cmp "$BUILD/o0/run-a.txt" "$BUILD/o2/run-a.txt"
echo 'FSI18_O0_O2_IDENTITY=PASS'

python3 - "$BUILD/o0/run-a.txt" <<'PY' | tee "$EVIDENCE_DIR/classification.txt"
from pathlib import Path
import sys
vals={}
for line in Path(sys.argv[1]).read_text().splitlines():
    if '=' in line:
        k,v=line.split('=',1); vals[k.strip()]=v.strip()

def b(i, field):
    return vals[f'FSI18_CASE_{i}_{field}']=='T'
def n(i, field):
    return int(vals[f'FSI18_CASE_{i}_{field}'])

assert b(1,'CONVERGED')
plus3=b(2,'CONVERGED'); minus3=b(3,'CONVERGED')
plus10=b(4,'CONVERGED'); minus10=b(5,'CONVERGED')
reproduced = plus3 and minus3 and (not plus10) and (not minus10)
symmetric = (plus3==minus3) and (plus10==minus10)
print('FSI18_FPE03_BOUNDARY_REPRODUCED=' + ('YES' if reproduced else 'NO'))
print('FSI18_SIGN_SYMMETRY=' + ('YES' if symmetric else 'NO'))
for i in range(1,6):
    print(f"FSI18_CASE_{i}_SUMMARY=converged:{b(i,'CONVERGED')},nl:{n(i,'NONLINEAR_ITERATIONS')},retry:{n(i,'INTERNAL_RETRIES')},jac:{n(i,'JACOBIAN_BUILDS')},lin:{n(i,'LINEAR_SOLVES')},bt:{n(i,'BACKTRACKING_ATTEMPTS')}")
if reproduced:
    classification='REPRODUCED_ON_FSI16_SOLVER_LINEAGE'
elif symmetric:
    classification='NOT_REPRODUCED_BUT_SIGN_SYMMETRIC_ON_FSI16_SOLVER_LINEAGE'
else:
    classification='NOT_REPRODUCED_AND_ASYMMETRIC_REQUIRES_DIAGNOSIS'
print('FSI18_REPRODUCTION_CLASSIFICATION='+classification)
print('FSI18_PRODUCTION_CHANGE_AUTHORIZED=NO')
PY

cat "$EVIDENCE_DIR/classification.txt"
echo 'FSI18_REFERENCE_CONVERGENCE_CLIFF_GATE=PASS_CHARACTERIZATION_ONLY'
