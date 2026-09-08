#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof16-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=f23883eea13aef7c70a235acf0eccfeca772f41e
NEW_SRC=src/crop/mod_nonadaptive_crop_root_view_producer.f90
changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "$NEW_SRC" ]] || {
  echo 'FWOF16_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FWOF16_PRODUCTION_DELTA_SINGLE_CROP_PRODUCER=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FWOF16_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/crop/mod_crop_root_uptake_input_contract.f90 cc5594f6c7a91ac2ff37af611d40c740b7f25521
check_blob src/crop/mod_crop_root_uptake_input_assembly.f90 71f1e237c41af56ee85dcadfaae330f5d50ae0f7
check_blob integration/f-wof/F-WOF12_SOURCE_BOUND_PROVIDER_INVENTORY.json 53613edbbc238e9b4fbc17f8ad336db378c2b2e5
check_blob integration/f-wof/F-WOF15_STATUS.json 7d3451fbd69258422d4131f00449870819d8bf92
echo 'FWOF16_FWO13_FWO15_SOURCE_LOCKS=PASS'

python3 - <<'PY'
from pathlib import Path
import json

p = Path('src/crop/mod_nonadaptive_crop_root_view_producer.f90').read_text().lower()
for forbidden in [
    'mod_fmr_', 'mod_soil_water_solver', 'mod_process_hydraulic_view', 'reference_richards',
    'headcalc', 'mod_meteo', 'mod_cropdevelopment', 'plant_interface',
    'open(', 'close(', 'inquire(', 'read(', 'write(', 't1900', 'daystart', 'dayend',
    'calendar_', 'potential_transpiration', 'wroot_node', 'swrdc'
]:
    assert forbidden not in p, forbidden
for required in [
    'mod_crop_root_uptake_input_assembly', 'crop_root_state_view_t',
    'build_nonadaptive_crop_root_state_view', 'nonadaptive_root_profile_parameters_t',
    'crop_root_geometry_snapshot_t', 'intent(in) :: parameters', 'intent(in) :: snapshot',
    'nonadapt_root_view_ambiguous_node_boundary', 'linear_table_value', 'first_bottom_beyond'
]:
    assert required in p, required

contract = json.loads(Path('integration/f-wof/F-WOF16_NONADAPTIVE_ROOT_VIEW_PRODUCER_CONTRACT.json').read_text())
assert contract['admitted_physics']['root_distribution'] == 'SWRDC != 1 only'
assert contract['transaction_and_state']['producer_mutates_input_state'] is False
assert contract['transaction_and_state']['producer_owns_committed_state'] is False
assert contract['transaction_and_state']['producer_allocates_persistent_per_node_state'] is False
assert contract['boundary_ambiguity_policy']['qualified_production_policy'] == 'FAIL_CLOSED_WITHIN_1E_MINUS_8_CM_OF_A_NODE_BOTTOM_WHEN_ROOT_DEPTH_IS_POSITIVE'
assert 'SWRDC=1 adaptive redistribution' in contract['forbidden']
assert 'root-growth evolution' in contract['forbidden']
assert 'ET or potential-transpiration calculation' in contract['forbidden']
print('FWOF16_SCOPE_AND_ARCHITECTURE_STATIC=PASS')
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
    -c src/crop/mod_nonadaptive_crop_root_view_producer.f90 -o "$OUT/root_view.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/fwof/test_fwof16_nonadaptive_root_view_producer.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/crop_contract.o" "$OUT/crop_assembly.o" "$OUT/root_view.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }

  for marker in \
    'FWOF16_INACTIVE_CROP_DEPENDENCY_FREE=PASS' \
    'FWOF16_EMERGED_ZERO_ROOT_DEPENDENCY_FREE=PASS' \
    'FWOF16_MULTI_NODE_NONUNIFORM_RDCTB_B110_ORACLE=PASS' \
    'FWOF16_FWO13_VIEW_VALIDATION=PASS' \
    'FWOF16_INPUTS_READ_ONLY=PASS' \
    'FWOF16_ONE_NODE_ENDPOINTS=PASS' \
    'FWOF16_NODE_BOUNDARY_AMBIGUITY_FAIL_CLOSED=PASS' \
    'FWOF16_INVALID_GRID_DEPTH_TABLE_FAIL_CLOSED=PASS' \
    'FWOF16_A_B_A_BITWISE_IDENTITY=PASS' \
    'FWOF16_NONADAPTIVE_ROOT_VIEW_PRODUCER_TEST PASS'; do
    grep -Fq "$marker" "$OUT/output.txt"
  done

  grep -Eq '^FWOF16_MULTI_NODE_B110_ORACLE_MAX_ABS_DIFF=[[:space:]]*[0-9.+-]+E[+-][0-9]+' "$OUT/output.txt"
  echo "FWOF16_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FWOF16_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FWOF16_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FWOF16_NONADAPTIVE_ROOT_VIEW_PRODUCER_GATE PASS'
