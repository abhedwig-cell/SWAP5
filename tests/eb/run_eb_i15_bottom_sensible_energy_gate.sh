#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-eb-i15-$$"
BASE="a5aa6a1c81afe35940567bd0b6af0bf5707594d3"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "EB_I15_GATE_FAIL $*" >&2; exit 95; }
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

OWNER_I04_BLOB="2247370ee34fac73a0e2d0b9fa15e171467aded3"
CURRENT_I04_BLOB="$(git rev-parse HEAD:src/process/mod_liquid_water_sensible_enthalpy.f90)"
[[ "$CURRENT_I04_BLOB" == "$OWNER_I04_BLOB" ]] || fail "I04 primitive blob drift: $CURRENT_I04_BLOB"
echo 'EB_I15_I04_PRIMITIVE_BYTE_IDENTICAL=PASS'

python3 - <<'PY'
from pathlib import Path
import json

src = Path('src/runtime/mod_fmr_bottom_sensible_energy.f90').read_text().lower()
for forbidden in [
    'mod_kernel_transactions',
    'mod_soil_water_solver_contract',
    'headcalc',
    'mod_reference_richards',
    'modflow',
]:
    if forbidden in src:
        raise SystemExit(f'EB_I15_GATE_FAIL evaluator leaked forbidden dependency: {forbidden}')
required = [
    'use mod_fmr_bottom_thermal_carrier',
    'use mod_liquid_water_sensible_enthalpy',
    'sample%local_end_temperature_c',
    'fmr_bottom_energy_incomplete_external_donor',
    'result%outward_positive_energy_j_m2_value = 0.0_real64',
]
for token in required:
    if token not in src:
        raise SystemExit(f'EB_I15_GATE_FAIL missing evaluator contract token: {token}')

p = Path('tests/eb/EB-I15_ARCHITECTURE_AUDIT.json')
if not p.exists():
    raise SystemExit('EB_I15_GATE_FAIL architecture audit missing')
audit = json.loads(p.read_text())
items = audit.get('invariants', [])
ids = [item.get('id') for item in items]
if ids != list(range(1, 31)):
    raise SystemExit(f'EB_I15_GATE_FAIL architecture invariant ids are not exactly 1..30: {ids}')
if any(item.get('status') not in ('pass', 'preserved') for item in items):
    raise SystemExit('EB_I15_GATE_FAIL architecture audit contains unresolved invariant status')
if audit.get('scope') != 'PURE_CANDIDATE_EVALUATOR_NOT_RUNTIME_PUBLICATION':
    raise SystemExit('EB_I15_GATE_FAIL architecture scope drift')

print('EB_I15_RUNTIME_DEPENDENCY_DIRECTION=PASS')
print('EB_I15_EXTERNAL_FAIL_CLOSED_STATIC=PASS')
print('EB_I15_ARCHITECTURE_INVARIANTS_1_30=PASS')
PY

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/runtime/mod_fmr_bottom_thermal_carrier.f90 -o "$OUT/carrier.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/process/mod_liquid_water_sensible_enthalpy.f90 -o "$OUT/enthalpy.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/runtime/mod_fmr_bottom_sensible_energy.f90 -o "$OUT/energy.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/eb/test_eb_i15_bottom_sensible_energy.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/carrier.o" "$OUT/enthalpy.o" "$OUT/energy.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "O$opt execution"
  }
  for marker in \
    'EB_I15_LOCAL_TERMINAL_QUADRATURE=PASS' \
    'EB_I15_TERMINAL_NOT_START_TEMPERATURE=PASS' \
    'EB_I15_EXACT_ZERO_NO_DONOR=PASS' \
    'EB_I15_EXTERNAL_INFLOW_FAIL_CLOSED=PASS' \
    'EB_I15_INVALID_INPUTS_FAIL_CLOSED=PASS' \
    'EB_I15_REFERENCE_SHIFT_IDENTITY=PASS' \
    'EB_I15_BOTTOM_SENSIBLE_ENERGY_GATE PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || {
      cat "$OUT/output.txt" >&2
      fail "missing O$opt marker: $marker"
    }
  done
  echo "EB_I15_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 output identity'
}
HASH="$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo "EB_I15_OUTPUT_SHA256=$HASH"
echo 'EB_I15_O0_O2_EXACT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"

while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  case "$path" in
    src/process/mod_liquid_water_sensible_enthalpy.f90|\
    src/runtime/mod_fmr_bottom_sensible_energy.f90|\
    tests/eb/test_eb_i15_bottom_sensible_energy.f90|\
    tests/eb/run_eb_i15_bottom_sensible_energy_gate.sh|\
    tests/eb/EB-I15_ARCHITECTURE_AUDIT.json|\
    tests/eb/EB-I15_STATUS.json|\
    tests/eb/EB-I15_CLOSURE.md|\
    .github/workflows/eb-i15-qualification.yml)
      ;;
    *)
      fail "unexpected EB-I15 branch delta: $path"
      ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD)

echo 'EB_I15_EXACT_SCOPE_ALLOWLIST=PASS'
git diff --check "$BASE"..HEAD || fail 'branch whitespace check'
echo 'EB_I15_BOTTOM_SENSIBLE_ENERGY_QUALIFICATION_GATE=PASS'
