#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof17-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=df29eb9111d98a466cfdfc30f8a0a2546dc63d74
NEW_SRC=src/crop/mod_crop_root_geometry_snapshot_producer.f90
changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "$NEW_SRC" ]] || {
  echo 'FWOF17_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FWOF17_PRODUCTION_DELTA_SINGLE_CROP_GEOMETRY_PRODUCER=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FWOF17_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/crop/mod_crop_root_uptake_input_contract.f90 cc5594f6c7a91ac2ff37af611d40c740b7f25521
check_blob src/crop/mod_crop_root_uptake_input_assembly.f90 71f1e237c41af56ee85dcadfaae330f5d50ae0f7
check_blob src/crop/mod_nonadaptive_crop_root_view_producer.f90 32e827c70f733b5451328ac7a95a1001a0d711f7
check_blob integration/f-wof/F-WOF15_STATUS.json 7d3451fbd69258422d4131f00449870819d8bf92
check_blob integration/f-wof/F-WOF16_STATUS.json 3e718dc9cf72f81c31cfd78ec07e87af2e72b39d || true

echo 'FWOF17_UPSTREAM_SOURCE_LOCKS=PASS'

python3 - <<'PY'
from pathlib import Path
import json

p = Path('src/crop/mod_crop_root_geometry_snapshot_producer.f90').read_text().lower()
for forbidden in [
    'mod_fmr_', 'mod_soil_water_solver', 'mod_process_hydraulic_view', 'reference_richards',
    'headcalc', 'mod_meteo', 'mod_cropdevelopment', 'plant_interface',
    'open(', 'close(', 'inquire(', 'read(', 'write(', 't1900', 'daystart', 'dayend',
    'calendar_', 'potential_transpiration', 'noddrz', 'cumdens', 'wroot_node', 'rdpot'
]:
    assert forbidden not in p, forbidden
for required in [
    'crop_root_geometry_snapshot_t',
    'build_swrd1_root_geometry_snapshot',
    'build_swrd2_root_geometry_snapshot',
    'build_swrd3_root_geometry_snapshot',
    'root_depth_table_t',
    'intent(in) :: crop_emerged',
    'intent(in) :: maximum_root_depth',
    'valid_depth_table',
    'table_value'
]:
    assert required in p, required

contract = json.loads(Path('integration/f-wof/F-WOF17_OPTION_AWARE_ROOT_GEOMETRY_CONTRACT.json').read_text())
assert contract['mode_contracts']['SWRD_1']['independent_root_depth_state_required'] is False
assert contract['mode_contracts']['SWRD_2']['independent_root_depth_state_required'] is True
assert contract['mode_contracts']['SWRD_3']['independent_root_depth_state_required'] is False
assert contract['target_api']['mutates_committed_state'] is False
assert contract['target_api']['owns_committed_state'] is False
assert contract['target_api']['runtime_dependency'] is False
assert contract['target_api']['solver_dependency'] is False
assert contract['target_api']['ET_dependency'] is False
assert any('strictly positive' in item for item in contract['validation'])
print('FWOF17_SCOPE_OWNERSHIP_AND_ARCHITECTURE_STATIC=PASS')
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
    -c src/crop/mod_crop_root_geometry_snapshot_producer.f90 -o "$OUT/root_geometry.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/fwof/test_fwof17_option_aware_root_geometry.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/crop_contract.o" "$OUT/crop_assembly.o" "$OUT/root_view.o" "$OUT/root_geometry.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }

  for marker in \
    'FWOF17_INACTIVE_ALL_MODES_DEPENDENCY_FREE=PASS' \
    'FWOF17_SWRD1_AFGEN_B110_IDENTITY=PASS' \
    'FWOF17_SWRD2_COMMITTED_DEPTH_BITWISE_PASSTHROUGH=PASS' \
    'FWOF17_SWRD3_AFGEN_B110_IDENTITY=PASS' \
    'FWOF17_INPUT_TABLES_READ_ONLY=PASS' \
    'FWOF17_INVALID_ACTIVE_INPUTS_FAIL_CLOSED=PASS' \
    'FWOF17_A_B_A_BITWISE_IDENTITY=PASS' \
    'FWOF17_FWO16_NONADAPTIVE_VIEW_COMPOSITION=PASS' \
    'FWOF17_FWO13_VIEW_VALIDATION=PASS' \
    'FWOF17_OPTION_AWARE_ROOT_GEOMETRY_TEST PASS'; do
    grep -Fq "$marker" "$OUT/output.txt"
  done

  echo "FWOF17_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FWOF17_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FWOF17_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FWOF17_OPTION_AWARE_ROOT_GEOMETRY_GATE PASS'
