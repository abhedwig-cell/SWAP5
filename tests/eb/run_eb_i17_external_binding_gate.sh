#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-eb-i17-$$"
BASE="eacf7e4a05eb8ee9c9304c4184d85427b2587ee9"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "EB_I17_GATE_FAIL $*" >&2; exit 97; }
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

# Preserve established scientific, transfer, and coupling authorities exactly.
[[ "$(git rev-parse HEAD:src/process/mod_liquid_water_sensible_enthalpy.f90)" == "2247370ee34fac73a0e2d0b9fa15e171467aded3" ]] || fail 'EB-I04 enthalpy primitive drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_bottom_thermal_carrier.f90)" == "c371be3e22eaa6da70ca8cbb060bc42d1e0e0bfb" ]] || fail 'EB-I13 thermal carrier drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_groundwater_coupling_contract.f90)" == "fc598d14eabafcb025bb55621f7b00d6d1816f10" ]] || fail 'groundwater coupling contract drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_groundwater_exchange_service_contract.f90)" == "f0fc25592624360802713a9487813d119e7dc4e9" ]] || fail 'groundwater exchange service drift'
echo 'EB_I17_OWNER_AUTHORITIES_BYTE_IDENTICAL=PASS'

python3 - <<'PY'
from pathlib import Path
import json

binding = Path('src/runtime/mod_fmr_bottom_external_thermal_binding.f90').read_text().lower()
for forbidden in [
    'mod_groundwater',
    'modflow',
    'headcalc',
    'mod_soil_water_solver',
    'bottom_outward_exchange_native',
    'q_swap',
    'q_groundwater',
]:
    if forbidden in binding:
        raise SystemExit(f'EB_I17_GATE_FAIL binding leaked forbidden ownership/dependency: {forbidden}')
for required in [
    'candidate_lineage_id_value',
    'sample_ordinal',
    'donor_temperature_c',
    'provenance_token',
    'fmr_ext_thermal_binding_duplicate',
    'fmr_ext_thermal_binding_nonfinite',
    'fmr_ext_thermal_binding_unavailable',
]:
    if required not in binding:
        raise SystemExit(f'EB_I17_GATE_FAIL binding token missing: {required}')

evaluator = Path('src/runtime/mod_fmr_bottom_sensible_energy.f90').read_text().lower()
for required in [
    'public :: evaluate_fmr_bottom_sensible_energy',
    'public :: evaluate_fmr_bottom_sensible_energy_with_external',
    'use mod_fmr_bottom_external_thermal_binding',
    'call evaluate_fmr_bottom_sensible_energy(candidate, parameters, base_result)',
    'sample%bottom_outward_exchange_native, donor_temperature_c',
    'fmr_bottom_energy_invalid_external_binding',
]:
    if required not in evaluator:
        raise SystemExit(f'EB_I17_GATE_FAIL evaluator token missing: {required}')
for forbidden in ['modflow', 'headcalc', 'mod_groundwater']:
    if forbidden in evaluator:
        raise SystemExit(f'EB_I17_GATE_FAIL evaluator leaked source-specific dependency: {forbidden}')

audit = json.loads(Path('tests/eb/EB-I17_ARCHITECTURE_AUDIT.json').read_text())
if audit.get('scope') != 'CANDIDATE_SCOPED_EXTERNAL_THERMAL_BINDING_AND_OPT_IN_EVALUATOR_NO_PUBLICATION':
    raise SystemExit('EB_I17_GATE_FAIL architecture scope drift')
items = audit.get('invariants', [])
ids = [item.get('id') for item in items]
if ids != list(range(1, 31)):
    raise SystemExit(f'EB_I17_GATE_FAIL architecture invariant IDs not exactly 1..30: {ids}')
if any(item.get('status') not in ('pass', 'preserved') for item in items):
    raise SystemExit('EB_I17_GATE_FAIL unresolved architecture invariant')

status = json.loads(Path('tests/eb/EB-I17_STATUS.json').read_text())
if status.get('decision') != 'IMPLEMENTED_CANDIDATE_SCOPED_EXTERNAL_BINDING':
    raise SystemExit('EB_I17_GATE_FAIL status decision drift')
if status.get('qualification_state') != 'QUALIFIED_WHEN_EXACT_UNCHANGED_HEAD_WORKFLOW_SUCCEEDS':
    raise SystemExit('EB_I17_GATE_FAIL qualification-state drift')
if status.get('mass_authority') != 'UNCHANGED_ACCEPTED_BOTTOM_THERMAL_CARRIER_WATER_EXCHANGE':
    raise SystemExit('EB_I17_GATE_FAIL mass authority drift')
if status.get('source_specific_dependency') is not False:
    raise SystemExit('EB_I17_GATE_FAIL source-specific dependency declared')

print('EB_I17_BINDING_DEPENDENCY_DIRECTION=PASS')
print('EB_I17_EVALUATOR_COMPOSITION_STATIC=PASS')
print('EB_I17_ARCHITECTURE_INVARIANTS_1_30=PASS')
print('EB_I17_GOVERNANCE_DISPOSITION=PASS')
PY

compile_and_run() {
  local opt="$1"
  local out="$BUILD/o$opt"
  mkdir -p "$out"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c src/runtime/mod_fmr_bottom_thermal_carrier.f90 -o "$out/carrier.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c src/runtime/mod_fmr_bottom_external_thermal_binding.f90 -o "$out/binding.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c src/process/mod_liquid_water_sensible_enthalpy.f90 -o "$out/enthalpy.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c src/runtime/mod_fmr_bottom_sensible_energy.f90 -o "$out/energy.o"

  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c tests/eb/test_eb_i17_external_bottom_thermal_binding.f90 -o "$out/test_i17.o"
  gfortran -O"$opt" "$out/carrier.o" "$out/binding.o" "$out/enthalpy.o" "$out/energy.o" "$out/test_i17.o" -o "$out/test_i17"
  "$out/test_i17" > "$out/i17.txt" 2>&1 || { cat "$out/i17.txt" >&2; fail "I17 O$opt execution"; }

  for marker in \
    'EB_I17_EXTERNAL_SAMPLE_RESOLVED_TOTAL=PASS' \
    'EB_I17_MISSING_BINDING_FAIL_CLOSED=PASS' \
    'EB_I17_LINEAGE_MISMATCH_REJECTED=PASS' \
    'EB_I17_DUPLICATE_NONFINITE_REJECTED=PASS' \
    'EB_I17_NONEXTERNAL_BINDING_REJECTED=PASS' \
    'EB_I17_I15_LOCAL_ROUTE_PRESERVED=PASS' \
    'EB_I17_EXTERNAL_BOTTOM_THERMAL_BINDING_GATE PASS'; do
    grep -Fq "$marker" "$out/i17.txt" || { cat "$out/i17.txt" >&2; fail "missing I17 O$opt marker: $marker"; }
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c tests/eb/test_eb_i15_bottom_sensible_energy.f90 -o "$out/test_i15.o"
  gfortran -O"$opt" "$out/carrier.o" "$out/binding.o" "$out/enthalpy.o" "$out/energy.o" "$out/test_i15.o" -o "$out/test_i15"
  "$out/test_i15" > "$out/i15.txt" 2>&1 || { cat "$out/i15.txt" >&2; fail "I15 regression O$opt execution"; }
  for marker in \
    'EB_I15_LOCAL_TERMINAL_QUADRATURE=PASS' \
    'EB_I15_TERMINAL_NOT_START_TEMPERATURE=PASS' \
    'EB_I15_EXACT_ZERO_NO_DONOR=PASS' \
    'EB_I15_EXTERNAL_INFLOW_FAIL_CLOSED=PASS' \
    'EB_I15_INVALID_INPUTS_FAIL_CLOSED=PASS' \
    'EB_I15_REFERENCE_SHIFT_IDENTITY=PASS' \
    'EB_I15_BOTTOM_SENSIBLE_ENERGY_GATE PASS'; do
    grep -Fq "$marker" "$out/i15.txt" || { cat "$out/i15.txt" >&2; fail "missing I15 O$opt marker: $marker"; }
  done
  echo "EB_I17_O${opt}=PASS"
}

compile_and_run 0
compile_and_run 2

cmp -s "$BUILD/o0/i17.txt" "$BUILD/o2/i17.txt" || {
  diff -u "$BUILD/o0/i17.txt" "$BUILD/o2/i17.txt" >&2 || true
  fail 'I17 O0/O2 output identity'
}
cmp -s "$BUILD/o0/i15.txt" "$BUILD/o2/i15.txt" || {
  diff -u "$BUILD/o0/i15.txt" "$BUILD/o2/i15.txt" >&2 || true
  fail 'I15 regression O0/O2 output identity'
}
echo "EB_I17_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/i17.txt" | awk '{print $1}')"
echo "EB_I17_I15_REGRESSION_SHA256=$(sha256sum "$BUILD/o0/i15.txt" | awk '{print $1}')"
echo 'EB_I17_O0_O2_EXACT_IDENTITY=PASS'
echo 'EB_I17_I15_REGRESSION_O0_O2_EXACT_IDENTITY=PASS'
cat "$BUILD/o0/i17.txt"

while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  case "$path" in
    src/runtime/mod_fmr_bottom_external_thermal_binding.f90|\
    src/runtime/mod_fmr_bottom_sensible_energy.f90|\
    tests/eb/test_eb_i17_external_bottom_thermal_binding.f90|\
    tests/eb/EB-I17_ARCHITECTURE_AUDIT.json|\
    tests/eb/EB-I17_STATUS.json|\
    tests/eb/EB-I17_CLOSURE.md|\
    tests/eb/run_eb_i17_external_binding_gate.sh|\
    .github/workflows/eb-i17-qualification.yml)
      ;;
    *) fail "unexpected EB-I17 branch delta: $path" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD)

echo 'EB_I17_EXACT_SCOPE_ALLOWLIST=PASS'
git diff --check "$BASE"..HEAD || fail 'branch whitespace check'
echo 'EB_I17_EXTERNAL_BOTTOM_THERMAL_BINDING_QUALIFICATION_GATE=PASS'
