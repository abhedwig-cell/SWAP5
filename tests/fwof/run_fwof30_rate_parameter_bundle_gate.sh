#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof30-$$"
mkdir -p "$BUILD/bundle-o0" "$BUILD/bundle-o2" "$BUILD/fwof29-o0" "$BUILD/fwof29-o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=55a823276a1869f15623d1d0694add4df54dec2e
NEW_SRC=src/crop/mod_wofost_rate_parameters.f90
changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "$NEW_SRC" ]] || {
  echo 'FWOF30_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FWOF30_PRODUCTION_DELTA_SINGLE_PARAMETER_BUNDLE_MODULE=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FWOF30_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/crop/mod_wofost_rate_table.f90 5a0e8387157c5d1e1a6a94a24c19c7519c6bfcd5
check_blob integration/f-wof/F-WOF29_STATUS.json d94a9148041af09d3418ee29cd70aa8295f371d2
check_blob integration/f-wof/F-WOF29_QUALIFICATION_EVIDENCE.json 5be93041cab5abbdb8bca5f542a0820a756fc6d9
echo 'FWOF30_FWO29_CLOSEOUT_AND_TABLE_SUBSTRATE_LOCK=PASS'

python3 - <<'PY'
from pathlib import Path
import json, re

text = Path('src/crop/mod_wofost_rate_parameters.f90').read_text()
code = '\n'.join(line.split('!', 1)[0] for line in text.splitlines()).lower()
contract = json.loads(Path('integration/f-wof/F-WOF30_WORK_UNIT_CONTRACT.json').read_text())
status29 = json.loads(Path('integration/f-wof/F-WOF29_STATUS.json').read_text())

assert contract['base']['commit'] == '55a823276a1869f15623d1d0694add4df54dec2e'
assert status29['status'] == 'QUALIFIED_COMPACT_IMMUTABLE_WOFOST_RATE_TABLE_SUBSTRATE'
assert contract['production_scope']['dynamic_column_state_added'] is False
assert contract['production_scope']['rate_equations_added'] is False
assert contract['production_scope']['parser_or_file_IO_added'] is False

for required in [
    'type, public :: wofost_rate_scalar_parameters_t',
    'type, public :: wofost_rate_parameter_tables_t',
    'type, public :: wofost_rate_parameter_bundle_t\n    private',
    'public :: construct_wofost_rate_parameter_bundle',
    'procedure, public :: ready',
    'procedure, public :: scalar_view',
    'bundle%scalars%daylength_upper_hours = 0.0_real64',
    'bundle%scalars%daylength_lower_hours = 0.0_real64'
]:
    assert required in code, required

semantic_tables = [
    'temperature_sum_increment', 'maximum_assimilation', 'daytime_temperature_factor',
    'minimum_temperature_factor', 'maintenance_respiration_factor',
    'root_partition_fraction', 'leaf_partition_fraction', 'stem_partition_fraction',
    'storage_partition_fraction', 'relative_root_death_rate',
    'relative_stem_death_rate', 'specific_leaf_area'
]
for name in semantic_tables:
    assert f'type(wofost_rate_table_t) :: {name}' in code, name
    assert f'procedure, public :: evaluate_{name}' in code, name

for scalar_fragment in [
    'vegetative_temperature_sum_required, 10000.0_real64',
    'generative_temperature_sum_required, 10000.0_real64',
    'diffuse_extinction_coefficient, 2.0_real64',
    'initial_light_use_efficiency, 0.0_real64, 10.0_real64',
    'co2_to_dry_matter_fraction, 1.0_real64',
    'attainable_yield_multiplier, 0.0_real64, 1.0_real64',
    'conversion_efficiency_root, 1.0_real64',
    'conversion_efficiency_stem, 1.0_real64',
    'conversion_efficiency_leaf, 1.0_real64',
    'conversion_efficiency_storage, 0.0_real64, 1.0_real64',
    'respiration_temperature_q10, 5.0_real64',
    'maximum_leaf_relative_death_rate, 0.0_real64, 3.0_real64',
    'leaf_age_base_temperature, -10.0_real64, 30.0_real64',
    'maximum_relative_lai_growth_rate, 0.0_real64, 1.0_real64'
]:
    assert scalar_fragment in code, scalar_fragment

assert 'daylength_upper_hours <= scalars%daylength_lower_hours' in code
assert 'allocate(' not in code
for forbidden_word in ['ssa', 'spa', 'span', 'dvsend', 'kdir', 'tdwi', 'sw_potrelmf', 'iqrot', 'iptra', 'pgass', 'daynr', 't1900']:
    assert not re.search(rf'\b{forbidden_word}\b', code), forbidden_word
for forbidden in ['astro(', 'mod_integral', 'mod_meteo', 'headcalc', 'modflow', '.swp', 'plant_interface']:
    assert forbidden not in code, forbidden
assert not re.search(r'\b(open|close|inquire|read|write)\s*\(', code)

print('FWOF30_EXACT_RESTRICTED_PARAMETER_MEMBERSHIP_STATIC=PASS')
print('FWOF30_PRIVATE_BUNDLE_NO_PUBLIC_MUTATOR_STATIC=PASS')
print('FWOF30_SOURCE_BOUND_SCALAR_DOMAIN_RULES_STATIC=PASS')
print('FWOF30_TWELVE_QUALIFIED_TABLE_DEPENDENCIES_STATIC=PASS')
print('FWOF30_NO_STATE_FORCING_PARSER_CALENDAR_OR_RATE_PHYSICS_STATIC=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
TABLE="$ROOT/src/crop/mod_wofost_rate_table.f90"
PARAMS="$ROOT/src/crop/mod_wofost_rate_parameters.f90"
PARAM_TEST="$ROOT/tests/fwof/test_fwof30_rate_parameter_bundle.f90"
FWO29_TEST="$ROOT/tests/fwof/test_fwof29_rate_table_substrate.f90"

for OPT in o0 o2; do
  FLAG=-O0
  [[ "$OPT" == "o2" ]] && FLAG=-O2
  gfortran "${COMMON[@]}" "$FLAG" -J "$BUILD/bundle-$OPT" \
    "$TABLE" "$PARAMS" "$PARAM_TEST" -o "$BUILD/bundle-$OPT/test"
  "$BUILD/bundle-$OPT/test" > "$BUILD/bundle-$OPT/output.txt" 2>&1 || {
    cat "$BUILD/bundle-$OPT/output.txt" >&2
    exit 1
  }
  for marker in \
    'FWOF30_SCALAR_VIEW_COPY_AND_BUNDLE_IMMUTABILITY=PASS' \
    'FWOF30_ALL_TWELVE_SEMANTIC_TABLE_ROUTES=PASS' \
    'FWOF30_IDSL0_INACTIVE_PHOTOPERIOD_CANONICALIZED=PASS' \
    'FWOF30_CVO_ZERO_DEFERRED_TO_FO_AWARE_RATE_VALIDATION=PASS' \
    'FWOF30_SOURCE_BOUND_AND_DENOMINATOR_DOMAINS_FAIL_CLOSED=PASS' \
    'FWOF30_UNREADY_TABLE_SET_FAILS_CLOSED=PASS' \
    'FWOF30_NONFINITE_TABLE_QUERY_FAILS_CLOSED_WITHOUT_ARITHMETIC=PASS' \
    'FWOF30_RATE_PARAMETER_BUNDLE_TEST PASS'; do
    grep -Fq "$marker" "$BUILD/bundle-$OPT/output.txt"
  done
  echo "FWOF30_${OPT^^}=PASS"
done

cmp "$BUILD/bundle-o0/output.txt" "$BUILD/bundle-o2/output.txt"
echo 'FWOF30_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/bundle-o0/output.txt"
echo "FWOF30_OUTPUT_SHA256=$(sha256sum "$BUILD/bundle-o0/output.txt" | cut -d' ' -f1)"

for OPT in o0 o2; do
  FLAG=-O0
  [[ "$OPT" == "o2" ]] && FLAG=-O2
  gfortran "${COMMON[@]}" "$FLAG" -J "$BUILD/fwof29-$OPT" \
    "$TABLE" "$FWO29_TEST" -o "$BUILD/fwof29-$OPT/test"
  "$BUILD/fwof29-$OPT/test" > "$BUILD/fwof29-$OPT/output.txt" 2>&1 || {
    cat "$BUILD/fwof29-$OPT/output.txt" >&2
    exit 1
  }
done
cmp "$BUILD/fwof29-o0/output.txt" "$BUILD/fwof29-o2/output.txt"
FWO29_SHA="$(sha256sum "$BUILD/fwof29-o0/output.txt" | cut -d' ' -f1)"
[[ "$FWO29_SHA" == '780387c7e71b1a72319f67e96f188fb95f2856bb30b941490fec9c7b09f161c8' ]] || {
  echo "FWOF30_FWO29_REGRESSION_SHA_MISMATCH actual=$FWO29_SHA" >&2
  exit 1
}
grep -Fq 'FWOF29_RATE_TABLE_SUBSTRATE_TEST PASS' "$BUILD/fwof29-o0/output.txt"
echo 'FWOF30_FWO29_RATE_TABLE_EXACT_REGRESSION=PASS'

echo 'FWOF30_RATE_PARAMETER_BUNDLE_GATE PASS'
