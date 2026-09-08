#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof18-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=c54e0bf1fff5c986ee64bf8fdb4248e5f4b15172
NEW_SRC=src/process/mod_reference_et_transpiration_process.f90
changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "$NEW_SRC" ]] || {
  echo 'FWOF18_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FWOF18_PRODUCTION_DELTA_SINGLE_ET_PROCESS=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FWOF18_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/crop/mod_crop_root_uptake_input_contract.f90 cc5594f6c7a91ac2ff37af611d40c740b7f25521
check_blob src/crop/mod_crop_root_uptake_input_assembly.f90 71f1e237c41af56ee85dcadfaae330f5d50ae0f7
check_blob src/crop/mod_crop_root_geometry_snapshot_producer.f90 56c3e10ccd25e6790882a649d472bd67a31d0f7b
check_blob src/crop/mod_nonadaptive_crop_root_view_producer.f90 32e827c70f733b5451328ac7a95a1001a0d711f7
echo 'FWOF18_CROP_AND_ASSEMBLY_SOURCE_LOCKS=PASS'

python3 - <<'PY'
from pathlib import Path
import json

text = Path('src/process/mod_reference_et_transpiration_process.f90').read_text()
code = '\n'.join(line.split('!', 1)[0] for line in text.splitlines()).lower()
full = text.lower()
for forbidden in [
    'mod_fmr_', 'mod_soil_water_solver', 'mod_process_hydraulic_view', 'reference_richards', 'headcalc',
    'mod_meteo', 'mod_cropdevelopment', 'plant_interface', 'atmosphere_interface',
    'open(', 'close(', 'inquire(', 'read(', 'write(', 't1900', 'daynr', 'daystart', 'dayend', 'calendar_',
    'penmon', 'swinter', 'swetr', 'swmetdetail', 'aintc', 'wfrac', 'ptra_wet', 'ptra_dry',
    'rain', 'irrig'
]:
    assert forbidden not in code, forbidden
for required in [
    'root_uptake_et_result_t', 'reference_et_forcing_t', 'transpiration_canopy_view_t',
    'evaluate_reference_et_transpiration', 'reference_et_mm_per_day', 'vegetation_cover_fraction',
    'crop_factor', 'co2_transpiration_factor', 'intent(in) :: forcing', 'intent(in) :: canopy'
]:
    assert required in full, required

contract = json.loads(Path('integration/f-wof/F-WOF18_REFERENCE_ET_TRANSPIRATION_CONTRACT.json').read_text())
evidence = json.loads(Path('integration/f-wof/F-WOF18_SOURCE_BOUND_ET_EVIDENCE.json').read_text())
route = contract['admitted_legacy_route']
assert route['SWETR'] == 1 and route['SWMETDETAIL'] == 0 and route['SWDIVIDE'] == 0 and route['SWINTER'] == 0
assert contract['target_api']['classification'] == 'CURRENT_INTERVAL_ET_PROCESS_RESULT_NOT_PERSISTENT_CROP_STATE'
assert contract['target_api']['persistent_state_required'] is False
assert contract['time_contract']['producer_requires_day_start_or_midnight'] is False
assert contract['time_contract']['producer_integrates_over_timestep'] is False
assert evidence['unit_reconciliation']['classification'] == 'THEORY_CODE_COMMENT_DISCREPANCY_NONEXECUTING_COMMENT'
assert evidence['ownership']['persistent_ET_state_required_for_this_route'] is False
assert evidence['current_SWAP5_inventory']['explicit_ET_process_present_before_F_WOF18'] is False
print('FWOF18_SCOPE_OWNERSHIP_UNITS_AND_ARCHITECTURE_STATIC=PASS')
PY

STRICT=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"

  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c src/crop/mod_crop_root_uptake_input_contract.f90 -o "$OUT/crop_contract.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c src/crop/mod_crop_root_uptake_input_assembly.f90 -o "$OUT/crop_assembly.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c src/process/mod_reference_et_transpiration_process.f90 -o "$OUT/ref_et.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/fwof/test_fwof18_reference_et_transpiration.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/crop_contract.o" "$OUT/crop_assembly.o" "$OUT/ref_et.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }

  for marker in \
    'FWOF18_INACTIVE_CROP_DEPENDENCY_FREE_ZERO=PASS' \
    'FWOF18_SWETR1_SWINTER0_B110_FORMULA_IDENTITY=PASS' \
    'FWOF18_INPUTS_READ_ONLY=PASS' \
    'FWOF18_ZERO_COVER_AND_CROP_FACTOR_ROUTES=PASS' \
    'FWOF18_CO2_TRANSPIRATION_FACTOR_APPLICATION=PASS' \
    'FWOF18_INVALID_ACTIVE_INPUTS_FAIL_CLOSED=PASS' \
    'FWOF18_A_B_A_BITWISE_IDENTITY=PASS' \
    'FWOF18_FWO13_ET_RESULT_CONSUMPTION=PASS' \
    'FWOF18_REFERENCE_ET_TRANSPIRATION_TEST PASS'; do
    grep -Fq "$marker" "$OUT/output.txt"
  done
  echo "FWOF18_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FWOF18_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FWOF18_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FWOF18_REFERENCE_ET_TRANSPIRATION_GATE PASS'
