#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-eb-i17-$$"
BASE="0334f473cf1324b340faa5a36033047cf0266ebe"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "EB_I17_GATE_FAIL $*" >&2; exit 97; }
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

OWNER_I04_BLOB="2247370ee34fac73a0e2d0b9fa15e171467aded3"
[[ "$(git rev-parse HEAD:src/process/mod_liquid_water_sensible_enthalpy.f90)" == "$OWNER_I04_BLOB" ]] || \
  fail 'I04 sensible enthalpy primitive drift'

python3 - <<'PY'
from pathlib import Path
import json

provider = Path('src/runtime/mod_fmr_external_bottom_thermal_donor.f90').read_text().lower()
evaluator = Path('src/runtime/mod_fmr_bottom_sensible_energy.f90').read_text().lower()
for name, text in [('provider', provider), ('evaluator', evaluator)]:
    for forbidden in ['modflow', 'headcalc', 'mod_reference_richards', 'mod_kernel_transactions', '.swp']:
        if forbidden in text:
            raise SystemExit(f'EB_I17_GATE_FAIL {name} leaked forbidden dependency: {forbidden}')

for token in [
    'quadrature_time_value = t1',
    'outward_exchange_context_value',
    'fmr_external_donor_response_complete',
    'fmr_external_donor_response_unavailable',
    'fmr_external_donor_response_stale',
    'provenance_id_value',
    'identity_matches',
]:
    if token not in provider:
        raise SystemExit(f'EB_I17_GATE_FAIL missing provider contract token: {token}')

response_block = provider.split('type, public :: fmr_external_bottom_donor_response_t', 1)[1].split(
    'end type fmr_external_bottom_donor_response_t', 1)[0]
for forbidden in ['outward_exchange_context', 'bottom_outward_exchange', 'q_swap', 'q_groundwater', 'flux']:
    if forbidden in response_block:
        raise SystemExit(f'EB_I17_GATE_FAIL provider response became a water authority: {forbidden}')

for token in [
    'evaluate_fmr_bottom_sensible_energy_with_external_provider',
    'initialize_fmr_external_bottom_donor_request',
    'call provider(request, response)',
    'response%identity_matches(request)',
    'sample%bottom_outward_exchange_native, &',
    'external_inward_subtotal',
    'external_counts',
]:
    if token not in evaluator:
        raise SystemExit(f'EB_I17_GATE_FAIL missing evaluator binding token: {token}')

if 'mod_groundwater_coupling_contract' in evaluator or 'mod_groundwater_coupling_contract' in provider:
    raise SystemExit('EB_I17_GATE_FAIL generic thermal seam depends on groundwater contract type')

p = Path('tests/eb/EB-I17_ARCHITECTURE_AUDIT.json')
audit = json.loads(p.read_text())
assert audit['work_unit'] == 'EB-I17'
assert audit['scope'] == 'GENERIC_EXTERNAL_DONOR_PROVIDER_AND_CANDIDATE_EVALUATOR_BINDING_ONLY'
items = audit['invariants']
assert [item['id'] for item in items] == list(range(1, 31))
assert all(item['status'] in {'pass', 'preserved'} for item in items)
assert all(str(item['evidence']).strip() for item in items)

status = json.loads(Path('tests/eb/EB-I17_STATUS.json').read_text())
assert status['work_unit'] == 'EB-I17'
assert status['implemented'] is True
assert status['runtime_integrated'] is False
assert status['accepted_energy_publication'] is False
assert status['canonical_admission'] is False

print('EB_I17_STATIC_OWNERSHIP=PASS')
print('EB_I17_ARCHITECTURE_30=PASS')
PY

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/runtime/mod_fmr_bottom_thermal_carrier.f90 -o "$OUT/carrier.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/process/mod_liquid_water_sensible_enthalpy.f90 -o "$OUT/enthalpy.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/runtime/mod_fmr_external_bottom_thermal_donor.f90 -o "$OUT/provider.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/runtime/mod_fmr_bottom_sensible_energy.f90 -o "$OUT/energy.o"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/eb/test_eb_i17_external_bottom_thermal_donor.f90 -o "$OUT/test_i17.o"
  gfortran -O"$opt" "$OUT/carrier.o" "$OUT/enthalpy.o" "$OUT/provider.o" "$OUT/energy.o" "$OUT/test_i17.o" \
    -o "$OUT/test_i17"
  "$OUT/test_i17" > "$OUT/i17.txt" 2>&1 || {
    cat "$OUT/i17.txt" >&2
    fail "I17 O$opt execution"
  }

  for marker in \
    'EB_I17_COMPLETE_EXTERNAL_BINDING=PASS' \
    'EB_I17_REQUEST_T1_QUADRATURE=PASS' \
    'EB_I17_CANDIDATE_Q_AUTHORITY=PASS' \
    'EB_I17_LEGACY_FAIL_CLOSED_PRESERVED=PASS' \
    'EB_I17_NO_PROVIDER_FOR_LOCAL_OR_ZERO=PASS' \
    'EB_I17_UNAVAILABLE_STALE_FAIL_CLOSED=PASS' \
    'EB_I17_IDENTITY_MISMATCH_FAIL_CLOSED=PASS' \
    'EB_I17_NONFINITE_PROVIDER_FAIL_CLOSED=PASS' \
    'EB_I17_INVALID_CONTEXT_FAIL_CLOSED=PASS' \
    'EB_I17_MIXED_REFERENCE_SHIFT=PASS' \
    'EB_I17_EXTERNAL_BOTTOM_THERMAL_DONOR_GATE PASS'; do
    grep -Fq "$marker" "$OUT/i17.txt" || {
      cat "$OUT/i17.txt" >&2
      fail "missing I17 O$opt marker: $marker"
    }
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/eb/test_eb_i15_bottom_sensible_energy.f90 -o "$OUT/test_i15.o"
  gfortran -O"$opt" "$OUT/carrier.o" "$OUT/enthalpy.o" "$OUT/provider.o" "$OUT/energy.o" "$OUT/test_i15.o" \
    -o "$OUT/test_i15"
  "$OUT/test_i15" > "$OUT/i15.txt" 2>&1 || {
    cat "$OUT/i15.txt" >&2
    fail "I15 preservation O$opt execution"
  }
  grep -Fq 'EB_I15_BOTTOM_SENSIBLE_ENERGY_GATE PASS' "$OUT/i15.txt" || fail "I15 preservation marker O$opt"
  echo "EB_I17_O${opt}=PASS"
done

cmp -s "$BUILD/o0/i17.txt" "$BUILD/o2/i17.txt" || {
  diff -u "$BUILD/o0/i17.txt" "$BUILD/o2/i17.txt" >&2 || true
  fail 'I17 O0/O2 output identity'
}
cmp -s "$BUILD/o0/i15.txt" "$BUILD/o2/i15.txt" || {
  diff -u "$BUILD/o0/i15.txt" "$BUILD/o2/i15.txt" >&2 || true
  fail 'I15 preservation O0/O2 output identity'
}
echo "EB_I17_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/i17.txt" | awk '{print $1}')"
echo "EB_I17_I15_PRESERVATION_SHA256=$(sha256sum "$BUILD/o0/i15.txt" | awk '{print $1}')"
cat "$BUILD/o0/i17.txt"

while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  case "$path" in
    src/runtime/mod_fmr_external_bottom_thermal_donor.f90|\
    src/runtime/mod_fmr_bottom_sensible_energy.f90|\
    tests/eb/test_eb_i17_external_bottom_thermal_donor.f90|\
    tests/eb/run_eb_i17_external_bottom_thermal_donor_gate.sh|\
    tests/eb/EB-I17_ARCHITECTURE_AUDIT.json|\
    tests/eb/EB-I17_STATUS.json|\
    tests/eb/EB-I17_CLOSURE.md|\
    .github/workflows/eb-i17-qualification.yml)
      ;;
    *) fail "unexpected EB-I17 branch delta: $path" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD)

echo 'EB_I17_EXACT_SCOPE_ALLOWLIST=PASS'
git diff --check "$BASE"..HEAD || fail 'branch whitespace check'
echo 'EB_I17_EXTERNAL_BOTTOM_THERMAL_DONOR_QUALIFICATION_GATE=PASS'
