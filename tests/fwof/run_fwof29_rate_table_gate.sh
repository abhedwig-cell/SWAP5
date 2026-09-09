#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof29-$$"
mkdir -p "$BUILD/table-o0" "$BUILD/table-o2" "$BUILD/view-o0" "$BUILD/view-o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=64e566590ff8fb4fd8aa194c92d16436f86ea02d
NEW_SRC=src/crop/mod_wofost_rate_table.f90
changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "$NEW_SRC" ]] || {
  echo 'FWOF29_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FWOF29_PRODUCTION_DELTA_SINGLE_RATE_TABLE_MODULE=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FWOF29_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/crop/mod_wofost_actual_biomass_state.f90 feab0672b38e1c9668ac418cbe9d800f032cf4d8
check_blob src/crop/mod_wofost_crop_owner_state.f90 31bb390a0b70bec0a3f525f1d704a2c53890f9b4
check_blob src/crop/mod_wofost_one_day_rate_state_view.f90 eb0cf889676b617fef0542bc1b87e14b4f8b650c
check_blob integration/f-wof/F-WOF28_STATUS.json 1f54a513a05bda7d916008e8b98b6cdc65cf19b0
check_blob integration/f-wof/F-WOF28_QUALIFICATION_EVIDENCE.json 6078c6f8a200e7879e1b0df93101cd24363acef6
echo 'FWOF29_FWO28_CLOSEOUT_AND_OWNER_VIEW_LOCK=PASS'

python3 - <<'PY'
from pathlib import Path
import json, re

text = Path('src/crop/mod_wofost_rate_table.f90').read_text()
code = '\n'.join(line.split('!', 1)[0] for line in text.splitlines()).lower()
contract = json.loads(Path('integration/f-wof/F-WOF29_WORK_UNIT_CONTRACT.json').read_text())
status28 = json.loads(Path('integration/f-wof/F-WOF28_STATUS.json').read_text())

assert contract['base']['commit'] == '64e566590ff8fb4fd8aa194c92d16436f86ea02d'
assert status28['status'] == 'QUALIFIED_WOFOST_ONE_DAY_SEMANTIC_RATE_STATE_VIEW'
assert contract['production_scope']['active_knots_only'] is True
assert contract['production_scope']['strictly_increasing_x'] is True
assert contract['production_scope']['private_storage'] is True
assert contract['production_scope']['public_mutator_after_construction'] is False
assert contract['production_scope']['persistent_column_state_added'] is False
assert contract['production_scope']['crop_rate_equations_added'] is False

for required in [
    'type, public :: wofost_rate_table_t',
    'private\n    real(real64), allocatable :: x(:)',
    'real(real64), allocatable :: y(:)',
    'procedure, public :: ready',
    'procedure, public :: knot_count',
    'procedure, public :: evaluate',
    'public :: construct_wofost_rate_table',
    'if (x_values(i) <= x_values(i-1))',
    'slope = (self%y(hi) - self%y(lo)) / (self%x(hi) - self%x(lo))',
    'value_y = self%y(lo) + (query_x - self%x(lo)) * slope'
]:
    assert required in code, required

assert 'dimension(' not in code
assert 'sentinel' not in code
assert 'unused tail' not in code
for forbidden in [
    'pgass', 'reltr', 'iqrot', 'iptra', 'daynr', 't1900', 'astro(',
    'mod_integral', 'mod_meteo', 'headcalc', 'modflow', '.swp', 'plant_interface'
]:
    assert forbidden not in code, forbidden
assert not re.search(r'\b(open|close|inquire|read|write)\s*\(', code)

print('FWOF29_PRIVATE_ACTIVE_KNOT_STORAGE_STATIC=PASS')
print('FWOF29_STRICT_ORDER_AND_FINITE_VALIDATION_STATIC=PASS')
print('FWOF29_LEGACY_AFGEN_ARITHMETIC_ORDER_STATIC=PASS')
print('FWOF29_NO_SENTINEL_TAIL_PARSER_OR_RATE_PHYSICS_STATIC=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
TABLE="$ROOT/src/crop/mod_wofost_rate_table.f90"
TABLE_TEST="$ROOT/tests/fwof/test_fwof29_rate_table_substrate.f90"
TX="$ROOT/src/transaction/mod_transaction_reference.f90"
BIOMASS="$ROOT/src/crop/mod_wofost_actual_biomass_state.f90"
OWNER="$ROOT/src/crop/mod_wofost_crop_owner_state.f90"
VIEW="$ROOT/src/crop/mod_wofost_one_day_rate_state_view.f90"
VIEW_TEST="$ROOT/tests/fwof/test_fwof28_rate_state_view_assembly.f90"

for OPT in o0 o2; do
  FLAG=-O0
  [[ "$OPT" == "o2" ]] && FLAG=-O2
  gfortran "${COMMON[@]}" "$FLAG" -J "$BUILD/table-$OPT" \
    "$TABLE" "$TABLE_TEST" -o "$BUILD/table-$OPT/test"
  "$BUILD/table-$OPT/test" > "$BUILD/table-$OPT/output.txt" 2>&1 || {
    cat "$BUILD/table-$OPT/output.txt" >&2
    exit 1
  }
  for marker in \
    'FWOF29_FULL_LEGACY_AFGEN_BITWISE_EQUIVALENCE=PASS' \
    'FWOF29_SENTINEL_TAIL_REMOVAL_PRESERVES_ACTIVE_FUNCTION=PASS' \
    'FWOF29_SINGLE_KNOT_CONSTANT_TABLE=PASS' \
    'FWOF29_INVALID_TABLE_DATA_FAILS_CLOSED=PASS' \
    'FWOF29_NONFINITE_QUERY_FAILS_CLOSED_WITHOUT_ARITHMETIC=PASS' \
    'FWOF29_RATE_TABLE_SUBSTRATE_TEST PASS'; do
    grep -Fq "$marker" "$BUILD/table-$OPT/output.txt"
  done
  echo "FWOF29_${OPT^^}=PASS"
done

cmp "$BUILD/table-o0/output.txt" "$BUILD/table-o2/output.txt"
echo 'FWOF29_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/table-o0/output.txt"
echo "FWOF29_OUTPUT_SHA256=$(sha256sum "$BUILD/table-o0/output.txt" | cut -d' ' -f1)"

for OPT in o0 o2; do
  FLAG=-O0
  [[ "$OPT" == "o2" ]] && FLAG=-O2
  gfortran "${COMMON[@]}" "$FLAG" -J "$BUILD/view-$OPT" \
    "$TX" "$BIOMASS" "$OWNER" "$VIEW" "$VIEW_TEST" -o "$BUILD/view-$OPT/test"
  "$BUILD/view-$OPT/test" > "$BUILD/view-$OPT/output.txt" 2>&1 || {
    cat "$BUILD/view-$OPT/output.txt" >&2
    exit 1
  }
done
cmp "$BUILD/view-o0/output.txt" "$BUILD/view-o2/output.txt"
VIEW_SHA="$(sha256sum "$BUILD/view-o0/output.txt" | cut -d' ' -f1)"
[[ "$VIEW_SHA" == '9b2b856922cc4b27a2edf24a3ca5a58924eaef40c0ad47c15bfb10d5be3c05c3' ]] || {
  echo "FWOF29_FWO28_REGRESSION_SHA_MISMATCH actual=$VIEW_SHA" >&2
  exit 1
}
grep -Fq 'FWOF28_RATE_STATE_VIEW_ASSEMBLY_TEST PASS' "$BUILD/view-o0/output.txt"
echo 'FWOF29_FWO28_RATE_STATE_VIEW_EXACT_REGRESSION=PASS'

echo 'FWOF29_RATE_TABLE_GATE PASS'
