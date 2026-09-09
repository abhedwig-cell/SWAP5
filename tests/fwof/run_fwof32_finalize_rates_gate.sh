#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof32-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2" "$BUILD/fwof31-o0" "$BUILD/fwof31-o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=90020b1d24a3142a86a8c2d5d835e6ae38084df4
NEW_SRC=src/crop/mod_wofost_finalize_rates.f90
changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "$NEW_SRC" ]] || {
  echo 'FWOF32_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FWOF32_PRODUCTION_DELTA_SINGLE_FINALIZE_RATE_MODULE=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FWOF32_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/crop/mod_wofost_one_day_structural_evolution.f90 c1fd9704ca1617f1f34d41fd7ec38640cce81d94
check_blob src/crop/mod_wofost_one_day_rate_state_view.f90 eb0cf889676b617fef0542bc1b87e14b4f8b650c
check_blob src/crop/mod_wofost_rate_parameters.f90 b2e2b86e2f0b8be3f569604523b4891af40016b5
check_blob src/crop/mod_wofost_prepare_assimilation.f90 9d948be4fbd264fd3c3316fbc2b323d0c3b69f44
check_blob integration/f-wof/F-WOF31_STATUS.json 6403398ad2442b16be0022b5ceee87c391ef4069
echo 'FWOF32_FWO31_CLOSEOUT_AND_UPSTREAM_RATE_BOUNDARY_LOCK=PASS'

python3 - <<'PY'
from pathlib import Path
import json, re

src = Path('src/crop/mod_wofost_finalize_rates.f90').read_text()
code = '\n'.join(line.split('!', 1)[0] for line in src.splitlines()).lower()
contract = json.loads(Path('integration/f-wof/F-WOF32_WORK_UNIT_CONTRACT.json').read_text())
status31 = json.loads(Path('integration/f-wof/F-WOF31_STATUS.json').read_text())

assert contract['base']['commit'] == '90020b1d24a3142a86a8c2d5d835e6ae38084df4'
assert contract['base']['exact_closeout_conclusion'] == 'success'
assert status31['status'] == 'QUALIFIED_RESTRICTED_PURE_WOFOST_ACTUAL_PGASS_PREPARE_PROVIDER'
assert contract['production_scope']['persistent_state_added'] is False
assert contract['production_scope']['state_mutation'] is False
assert contract['accepted_window_provenance_contract']['runtime_binding_implemented_here'] is False
assert contract['accepted_window_provenance_contract']['end_to_end_provenance_claimed_here'] is False

for required in [
    'subroutine finalize_wofost_one_day_rates',
    'type(wofost_one_day_rate_state_view_t), intent(in) :: state_view',
    'type(wofost_rate_parameter_bundle_t), intent(in) :: parameters',
    'type(wofost_prepare_assimilation_result_t), intent(in) :: prepared',
    'type(wofost_accepted_window_aggregates_t), intent(in) :: aggregates',
    'reltr = b110_relative_transpiration(aggregates)',
    'dvr = dvred * dtsum / scalars%vegetative_temperature_sum_required',
    'dvr = dtsum / scalars%generative_temperature_sum_required',
    'gass = prepared%actual_pgass * reltr',
    'partition_check = fr + (fs + fl + fo) * (1.0_real64 - fr) - 1.0_real64',
    'carbon_check = (gass - mres -',
    'fr + (fl + fs + fo) * (1.0_real64 - fr)',
    'status = wofost_finalize_rates_cvo_storage_conflict',
    'laicr = 3.2_real64 / scalars%diffuse_extinction_coefficient',
    'glaiex = reltr * state_view%exponential_leaf_area_index *',
    'rates%lai_exponential_rate_recomputed = .false.',
    'rates%relative_transpiration_used = reltr'
]:
    assert required in code, required

assert 'save' not in code
assert 'allocatable' not in code
assert 'transaction_result' not in code
assert 'execute_reference_interval' not in code
for forbidden in [
    'daynr', 't1900', 'astro(', 'mod_integral', 'headcalc', 'modflow', '.swp',
    'open(', 'close(', 'inquire(', 'read(', 'write('
]:
    assert forbidden not in code, forbidden
assert not re.search(r'\bintent\(inout\)\b', code)

assert contract['explicit_restrictions_or_discrepancies'][0]['id'] == 'F-WOF32-NEGATIVE-DTSUM-OUTSIDE-RESTRICTED-PACKET'
assert contract['explicit_restrictions_or_discrepancies'][1]['id'] == 'F-WOF32-CVO-ZERO-NONZERO-FO'
print('FWOF32_EXACT_PHASE_B_INPUT_AND_PACKET_BOUNDARY_STATIC=PASS')
print('FWOF32_B110_RATE_FORMULA_AND_CHECK_ORDER_STATIC=PASS')
print('FWOF32_NO_STATE_MUTATION_PERSISTENT_RATE_WORKSPACE_OR_RUNTIME_TRANSACTION_DEPENDENCY=PASS')
print('FWOF32_ACCEPTED_WINDOW_PROVENANCE_OWNER_BOUNDARY_STATIC=PASS')
print('FWOF32_RESTRICTED_DTSUM_AND_CVO_DISCREPANCIES_PERSISTED=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
TX="$ROOT/src/transaction/mod_transaction_reference.f90"
BIOMASS="$ROOT/src/crop/mod_wofost_actual_biomass_state.f90"
OWNER="$ROOT/src/crop/mod_wofost_crop_owner_state.f90"
STRUCT="$ROOT/src/crop/mod_wofost_one_day_structural_evolution.f90"
VIEW="$ROOT/src/crop/mod_wofost_one_day_rate_state_view.f90"
TABLE="$ROOT/src/crop/mod_wofost_rate_table.f90"
PARAM="$ROOT/src/crop/mod_wofost_rate_parameters.f90"
PREP="$ROOT/src/crop/mod_wofost_prepare_assimilation.f90"
FINAL="$ROOT/src/crop/mod_wofost_finalize_rates.f90"
TEST="$ROOT/tests/fwof/test_fwof32_finalize_rates.f90"
TEST31="$ROOT/tests/fwof/test_fwof31_prepare_assimilation.f90"

for OPT in o0 o2; do
  FLAG=-O0
  [[ "$OPT" == "o2" ]] && FLAG=-O2
  # The production sources remain under full -Werror. The qualification fixture
  # intentionally dispatches two table shapes from exact REAL constants; keep
  # that fixture-only compare-real warning non-fatal without weakening modules.
  gfortran "${COMMON[@]}" "$FLAG" -J "$BUILD/$OPT" -c \
    "$TX" "$BIOMASS" "$OWNER" "$STRUCT" "$VIEW" "$TABLE" "$PARAM" "$PREP" "$FINAL"
  gfortran "${COMMON[@]}" -Wno-error=compare-reals "$FLAG" -I "$BUILD/$OPT" -J "$BUILD/$OPT" \
    "$TEST" ./*.o -o "$BUILD/$OPT/test"
  rm -f ./*.o
  "$BUILD/$OPT/test" > "$BUILD/$OPT/output.txt" 2>&1 || {
    cat "$BUILD/$OPT/output.txt" >&2
    exit 1
  }
  for marker in \
    'FWOF32_B110_FULL_RATE_PACKET_BITWISE_TRANSCRIPT_EQUIVALENCE=PASS' \
    'FWOF32_STATE_PARAMETERS_PREPARED_AND_AGGREGATES_READ_ONLY=PASS' \
    'FWOF32_B110_RELTR_NEGLIGIBLE_IPTRA_SEMANTICS=PASS' \
    'FWOF32_IDSL0_HAS_NO_DAYLP_DEPENDENCY=PASS' \
    'FWOF32_GLAIEXP_RECOMPUTE_VS_CARRYOVER_CONTRACT=PASS' \
    'FWOF32_CVO_ZERO_STORAGE_ALLOCATION_STRENGTHENING=PASS' \
    'FWOF32_B110_PARTITION_CHECK_FAILS_CLOSED=PASS' \
    'FWOF32_NEGATIVE_DTSUM_RESTRICTED_PROFILE_FAILS_CLOSED=PASS' \
    'FWOF32_INPUT_AND_TABLE_DOMAIN_VALIDATION=PASS' \
    'FWOF32_FINALIZE_RATES_TEST PASS'; do
    grep -Fq "$marker" "$BUILD/$OPT/output.txt"
  done
  echo "FWOF32_${OPT^^}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FWOF32_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FWOF32_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"

# Re-run the exact F-WOF31 production test against unchanged F-WOF31 sources.
for OPT in o0 o2; do
  FLAG=-O0
  [[ "$OPT" == "o2" ]] && FLAG=-O2
  gfortran "${COMMON[@]}" "$FLAG" -J "$BUILD/fwof31-$OPT" \
    "$TX" "$BIOMASS" "$OWNER" "$VIEW" "$TABLE" "$PARAM" "$PREP" "$TEST31" \
    -o "$BUILD/fwof31-$OPT/test"
  "$BUILD/fwof31-$OPT/test" > "$BUILD/fwof31-$OPT/output.txt" 2>&1
 done
cmp "$BUILD/fwof31-o0/output.txt" "$BUILD/fwof31-o2/output.txt"
SHA31="$(sha256sum "$BUILD/fwof31-o0/output.txt" | cut -d' ' -f1)"
[[ "$SHA31" == 'd4ad755913eb884d5e764499a33fb7937114f82d61dee1a69b03dfb650003335' ]] || {
  echo "FWOF32_FWO31_REGRESSION_SHA_MISMATCH actual=$SHA31" >&2
  exit 1
}
grep -Fq 'FWOF31_PREPARE_ASSIMILATION_TEST PASS' "$BUILD/fwof31-o0/output.txt"
echo 'FWOF32_FWO31_PREPARE_ASSIMILATION_EXACT_REGRESSION=PASS'

echo 'FWOF32_FINALIZE_RATES_GATE PASS'
