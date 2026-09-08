#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof23-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=6a8a1bba3f817de9b7db16b0cbe8d87bb892041b
NEW_SRC=src/crop/mod_wofost_actual_biomass_state.f90
changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "$NEW_SRC" ]] || {
  echo 'FWOF23_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FWOF23_PRODUCTION_DELTA_SINGLE_BIOMASS_STATE_CARRIER=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FWOF23_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/transaction/mod_transaction_reference.f90 b1878606ae6cb2b04a7b4b15e3e537deacf4477f
check_blob src/runtime/mod_canonical_contracts.f90 0c2b15fc45011c580384cf6a618e7b378fdccf0a
check_blob src/runtime/mod_canonical_interval_runtime.f90 f2cae79d533343db818c11e0b61b605ac5f6739d
check_blob src/kernel/mod_kernel_transactions.f90 9f7c16e71cfb93b57f796ba759bae73824318a2f
check_blob src/adapter/mod_b1_10_process_checkpoint.f90 bbb9f0fbfdb9624a426d75735e8b93fe3b68b3ae
check_blob src/crop/mod_crop_lifecycle_state.f90 c1fbb2c615254cfda0b26a7aff20447fb9960502
check_blob src/crop/mod_swrd2_crop_lifecycle_state.f90 206a2b472119c459b884ee360bd19c7a2ac7077b
check_blob src/crop/mod_crop_root_geometry_snapshot_producer.f90 56c3e10ccd25e6790882a649d472bd67a31d0f7b
check_blob integration/f-wof/F-WOF22_STATUS.json 602b15625f53a352ec17e88130b343e7de057ace
echo 'FWOF23_FKT_FWO22_AND_GEOMETRY_LOCKS=PASS'

python3 - <<'PY'
from pathlib import Path
import json

text = Path('src/crop/mod_wofost_actual_biomass_state.f90').read_text()
code = '\n'.join(line.split('!', 1)[0] for line in text.splitlines()).lower()

required = [
    'type, extends(transaction_state_t), public :: wofost_actual_biomass_state_t',
    'real(real64) :: root_biomass',
    'real(real64) :: stem_biomass',
    'real(real64) :: storage_biomass',
    'real(real64) :: exponential_leaf_area_index',
    'real(real64), allocatable :: leaf_biomass(:)',
    'real(real64), allocatable :: specific_leaf_area(:)',
    'real(real64), allocatable :: leaf_age(:)',
    'procedure :: clone => wofost_actual_biomass_clone',
    'procedure, public :: actual_root_biomass => wofost_actual_root_biomass',
    'procedure, public :: living_leaf_biomass => wofost_living_leaf_biomass',
    'procedure, public :: leaf_area_sum => wofost_leaf_area_sum',
    'ieee_is_finite'
]
for token in required:
    assert token in code, token

for forbidden in [
    '366', 'wrtpot', 'dwrt', 'dwst', 'dwlv', 'fl_potential',
    'development_stage', 'dvs', 'tsum', 'vernal', 'anthesis',
    'calendar', 'cropstart', 'cropend', 'daynr', 't1900',
    'open(', 'close(', 'inquire(', 'read(',
    'mod_fmr_', 'mod_soil_water_solver', 'headcalc', 'reference_richards',
    'root_growth', 'growth_rate', 'maintenance_respiration'
]:
    assert forbidden not in code, forbidden

contract = json.loads(Path('integration/f-wof/F-WOF23_PRIMARY_BIOMASS_STATE_CONTRACT.json').read_text())
evidence = json.loads(Path('integration/f-wof/F-WOF23_SOURCE_BOUND_BIOMASS_STATE_EVIDENCE.json').read_text())
status22 = json.loads(Path('integration/f-wof/F-WOF22_STATUS.json').read_text())

assert contract['base']['commit'] == '6a8a1bba3f817de9b7db16b0cbe8d87bb892041b'
assert status22['status'] == 'QUALIFIED_WRT_BIOMASS_OWNER_READINESS_SWRD3_PRODUCTION_BLOCKED'
assert contract['core_committed_biomass_state'] == [
    'root_biomass_WRT', 'stem_biomass_WST', 'storage_biomass_WSO',
    'active_leaf_cohort_biomass_LV', 'active_leaf_cohort_specific_leaf_area_SLA',
    'active_leaf_cohort_age_LVAGE', 'exponential_leaf_area_index_LAIEXP'
]
assert contract['representation']['leaf_cohort_count'].startswith('derived from equal allocatable')
assert contract['representation']['leaf_arrays'].startswith('store active cohorts only')
assert contract['read_only_view']['duplicate_state'] is False
assert contract['admitted_route_scope']['potential_reference_trajectory'] is False
assert contract['admitted_route_scope']['grassland_management_dead_biomass'] is False
assert 'WRT-only helper state' in contract['forbidden']
assert 'fixed 366-element cohort arrays per inactive/short-lived column' in contract['forbidden']

assert evidence['core_living_biomass']['classification'] == 'IRREDUCIBLE_PRIMARY_COMMITTED_BIOMASS_STATE'
assert evidence['leaf_cohort_history']['classification'] == 'IRREDUCIBLE_ACTIVE_COHORT_HISTORY'
assert evidence['incremental_LAIEXP']['classification'] == 'IRREDUCIBLE_PRIMARY_COMMITTED_BIOMASS_STATE'
assert evidence['reconstructible_fields']['WLV']['classification'] == 'RECONSTRUCTIBLE_VIEW'
assert evidence['reconstructible_fields']['LASUM']['classification'] == 'RECONSTRUCTIBLE_VIEW'
assert evidence['reconstructible_fields']['LAI']['classification'] == 'RECONSTRUCTIBLE_VIEW_WITH_IMMUTABLE_PARAMETERS'
assert evidence['excluded_or_optional_fields']['DWRT']['classification'] == 'OUTPUT_RESTART_ACCUMULATOR_NOT_CORE_BIOMASS_CONTINUATION'
assert evidence['excluded_or_optional_fields']['DWST_DWLV']['mandatory_for_core_standard_WOFOST_route'] is False
assert evidence['time_semantics']['arbitrary_interval_evolution_qualified_here'] is False
assert evidence['actual_WRT_view']['view_requires_duplicate_WRT_state'] is False
assert evidence['decision'] == 'IMPLEMENT_COMPACT_PRIMARY_ACTUAL_WOFOST_BIOMASS_CARRIER_WITH_ACTIVE_COHORT_HISTORY_AND_READ_ONLY_WRT_VIEW'

print('FWOF23_SOURCE_BOUND_STATE_MINIMIZATION=PASS')
print('FWOF23_ACTIVE_COHORT_DYNAMIC_STORAGE=PASS')
print('FWOF23_RECONSTRUCTIBLE_WLV_LASUM_LAI_NOT_DUPLICATED=PASS')
print('FWOF23_OPTIONAL_DEAD_AND_POTENTIAL_STATE_EXCLUDED=PASS')
print('FWOF23_GENERIC_TIME_CARRIER_WITH_EVOLUTION_CADENCE_UNQUALIFIED=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
TX="$ROOT/src/transaction/mod_transaction_reference.f90"
CONTRACTS="$ROOT/src/runtime/mod_canonical_contracts.f90"
RUNTIME="$ROOT/src/runtime/mod_canonical_interval_runtime.f90"
KERNEL="$ROOT/src/kernel/mod_kernel_transactions.f90"
BIOMASS="$ROOT/src/crop/mod_wofost_actual_biomass_state.f90"
TEST="$ROOT/tests/fwof/test_fwof23_primary_biomass_state.f90"

for OPT in o0 o2; do
  FLAG=-O0
  [[ "$OPT" == "o2" ]] && FLAG=-O2
  gfortran "${COMMON[@]}" "$FLAG" -J "$BUILD/$OPT" \
    "$TX" "$CONTRACTS" "$RUNTIME" "$KERNEL" "$BIOMASS" "$TEST" -o "$BUILD/$OPT/test"
  "$BUILD/$OPT/test" > "$BUILD/$OPT/output.txt" 2>&1 || { cat "$BUILD/$OPT/output.txt" >&2; exit 1; }

  for marker in \
    'FWOF23_COMPACT_ACTIVE_COHORT_AND_RECONSTRUCTIBLE_VIEWS=PASS' \
    'FWOF23_DEEP_CLONE_COHORT_INDEPENDENCE=PASS' \
    'FWOF23_INVALID_BIOMASS_STATE_FAILS_CLOSED=PASS' \
    'FWOF23_FKT_COMMITTED_INITIALIZATION_DEEP_CLONES_BIOMASS=PASS' \
    'FWOF23_FKT_CHECKPOINT_PRESERVES_COMPACT_BIOMASS=PASS' \
    'FWOF23_TRIAL_DISCARD_LEAVES_COMMITTED_BIOMASS_UNCHANGED=PASS' \
    'FWOF23_CHECKPOINT_A_B_A_REPLAY_BITWISE_IDENTITY=PASS' \
    'FWOF23_ACTUAL_WRT_VIEW_FROM_PRIMARY_BIOMASS_STATE=PASS' \
    'FWOF23_NO_CROP_EVOLUTION_OR_CALENDAR_STATE=PASS' \
    'FWOF23_PRIMARY_BIOMASS_STATE_TEST PASS'; do
    grep -Fq "$marker" "$BUILD/$OPT/output.txt"
  done
  echo "FWOF23_${OPT^^}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FWOF23_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FWOF23_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FWOF23_PRIMARY_BIOMASS_STATE_GATE PASS'
