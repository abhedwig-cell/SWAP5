#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof24-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=b34c541dbc781ab25d73f6cdf2a86c8a17be6f64
NEW_SRC=src/crop/mod_wofost_crop_owner_state.f90
changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "$NEW_SRC" ]] || {
  echo 'FWOF24_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FWOF24_PRODUCTION_DELTA_SINGLE_WOFOST_OWNER_STATE=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FWOF24_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/transaction/mod_transaction_reference.f90 b1878606ae6cb2b04a7b4b15e3e537deacf4477f
check_blob src/runtime/mod_canonical_contracts.f90 0c2b15fc45011c580384cf6a618e7b378fdccf0a
check_blob src/runtime/mod_canonical_interval_runtime.f90 f2cae79d533343db818c11e0b61b605ac5f6739d
check_blob src/kernel/mod_kernel_transactions.f90 9f7c16e71cfb93b57f796ba759bae73824318a2f
check_blob src/crop/mod_crop_lifecycle_state.f90 c1fbb2c615254cfda0b26a7aff20447fb9960502
check_blob src/crop/mod_swrd2_crop_lifecycle_state.f90 206a2b472119c459b884ee360bd19c7a2ac7077b
check_blob src/crop/mod_wofost_actual_biomass_state.f90 feab0672b38e1c9668ac418cbe9d800f032cf4d8
check_blob src/crop/mod_crop_root_geometry_snapshot_producer.f90 56c3e10ccd25e6790882a649d472bd67a31d0f7b
check_blob integration/f-wof/F-WOF23_STATUS.json 58551547a8e1a1978693234f5e43854fc7ef6662
echo 'FWOF24_FKT_PRIOR_STATE_AND_FWO17_LOCKS=PASS'

python3 - <<'PY'
from pathlib import Path
import json, re

text = Path('src/crop/mod_wofost_crop_owner_state.f90').read_text()
code = '\n'.join(line.split('!', 1)[0] for line in text.splitlines()).lower()

for required in [
    'type, extends(transaction_state_t), public :: wofost_crop_owner_state_t',
    'logical :: crop_emerged',
    'real(real64) :: development_stage',
    'type(wofost_actual_biomass_state_t), allocatable :: biomass',
    'procedure :: clone => wofost_crop_owner_clone',
    'procedure, public :: read_actual_root_biomass => wofost_read_actual_root_biomass',
    'procedure, public :: derive_actual_leaf_area_index => wofost_derive_actual_leaf_area_index'
]:
    assert required in code, required

assert 'use mod_crop_lifecycle_state' not in code
assert not re.search(r'real\s*\(real64\)\s*::\s*leaf_area_index\b', code)
assert 'wrtpot' not in code
assert 'potential_biomass' not in code
assert '366' not in code
for forbidden in [
    't1900', 'daynr', 'calendar_', 'cropstart', 'cropend', 'open(', 'close(', 'inquire(', 'read(',
    'mod_fmr_', 'mod_soil_water_solver', 'headcalc', 'reference_richards',
    'growth_rate', 'root_growth', 'maintenance_respiration'
]:
    assert forbidden not in code, forbidden

contract = json.loads(Path('integration/f-wof/F-WOF24_WOFOST_CROP_OWNER_COMPOSITE_CONTRACT.json').read_text())
evidence = json.loads(Path('integration/f-wof/F-WOF24_STATE_RECONCILIATION_EVIDENCE.json').read_text())
status23 = json.loads(Path('integration/f-wof/F-WOF23_STATUS.json').read_text())

assert contract['base']['commit'] == 'b34c541dbc781ab25d73f6cdf2a86c8a17be6f64'
assert status23['status'] == 'QUALIFIED_COMPACT_PRIMARY_ACTUAL_WOFOST_BIOMASS_STATE_AND_WRT_VIEW_CARRIER'
assert contract['atomic_owner_state']['fields'] == [
    'crop_emerged', 'development_stage_DVS', 'optional_primary_actual_WOFOST_biomass'
]
assert contract['atomic_owner_state']['single_FKT_authority'] is True
assert contract['LAI_reconciliation']['WOFOST_composite_decision'].startswith('do not embed crop_lifecycle_state_t')
assert contract['LAI_reconciliation']['leaf_area_index'].startswith('read-only derived view')
assert contract['optional_state_scaling']['inactive_or_pre_emergence_WOFOST_column'] == 'no biomass allocation'
assert contract['read_only_views']['actual_root_biomass'].startswith('returns authoritative F-WOF23')
assert 'nested F-WOF20 leaf_area_index as a second WOFOST LAI authority' in contract['forbidden']

assert evidence['current_lineage_reconciliation']['duplicate_LAI_if_naively_nested'] is True
assert evidence['current_lineage_reconciliation']['resolution'].startswith('WOFOST-specific atomic owner')
assert evidence['state_presence_semantics']['not_emerged']['biomass_allocated'] is False
assert evidence['state_presence_semantics']['emerged']['biomass_allocated'] is True
assert evidence['F_WOF17_composition']['source_change_required'] is False
assert evidence['F_WOF17_composition']['WRTPOT_required'] is False
assert evidence['decision'] == 'IMPLEMENT_WOFOST_SPECIFIC_ATOMIC_OWNER_WITH_OPTIONAL_BIOMASS_AND_DERIVED_LAI'

print('FWOF24_ROUTE_SPECIFIC_STATE_MINIMIZATION=PASS')
print('FWOF24_DUPLICATE_WOFOST_LAI_AUTHORITY_FORBIDDEN=PASS')
print('FWOF24_INACTIVE_BIOMASS_ALLOCATION_FORBIDDEN=PASS')
print('FWOF24_FWO17_SWRD3_CONSUMER_REUSE_STATIC=PASS')
print('FWOF24_EVOLUTION_AND_POTENTIAL_SHADOW_EXCLUDED=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
TX="$ROOT/src/transaction/mod_transaction_reference.f90"
CONTRACTS="$ROOT/src/runtime/mod_canonical_contracts.f90"
RUNTIME="$ROOT/src/runtime/mod_canonical_interval_runtime.f90"
KERNEL="$ROOT/src/kernel/mod_kernel_transactions.f90"
ROOT_CONTRACT="$ROOT/src/crop/mod_crop_root_uptake_input_contract.f90"
ROOT_ASSEMBLY="$ROOT/src/crop/mod_crop_root_uptake_input_assembly.f90"
NONADAPT="$ROOT/src/crop/mod_nonadaptive_crop_root_view_producer.f90"
GEOMETRY="$ROOT/src/crop/mod_crop_root_geometry_snapshot_producer.f90"
BIOMASS="$ROOT/src/crop/mod_wofost_actual_biomass_state.f90"
OWNER="$ROOT/src/crop/mod_wofost_crop_owner_state.f90"
TEST="$ROOT/tests/fwof/test_fwof24_crop_owner_composite_state.f90"

for OPT in o0 o2; do
  FLAG=-O0
  [[ "$OPT" == "o2" ]] && FLAG=-O2
  gfortran "${COMMON[@]}" "$FLAG" -J "$BUILD/$OPT" \
    "$TX" "$CONTRACTS" "$RUNTIME" "$KERNEL" \
    "$ROOT_CONTRACT" "$ROOT_ASSEMBLY" "$NONADAPT" "$GEOMETRY" \
    "$BIOMASS" "$OWNER" "$TEST" -o "$BUILD/$OPT/test"
  "$BUILD/$OPT/test" > "$BUILD/$OPT/output.txt" 2>&1 || { cat "$BUILD/$OPT/output.txt" >&2; exit 1; }

  for marker in \
    'FWOF24_INACTIVE_WOFOST_HAS_NO_BIOMASS_OR_ACTIVE_PARAMETER_DEPENDENCY=PASS' \
    'FWOF24_AUTHORITATIVE_WRT_AND_DERIVED_LAI_VIEWS=PASS' \
    'FWOF24_DEEP_CLONE_ATOMIC_LIFECYCLE_AND_BIOMASS=PASS' \
    'FWOF24_OWNER_PRESENCE_AND_NONFINITE_VALIDATION_FAILS_CLOSED=PASS' \
    'FWOF24_FKT_COMMITTED_INITIALIZATION_CLONES_ATOMIC_OWNER=PASS' \
    'FWOF24_FKT_CHECKPOINT_ATOMIC_LIFECYCLE_BIOMASS=PASS' \
    'FWOF24_TRIAL_BIOMASS_DEALLOCATION_DISCARD_ISOLATED=PASS' \
    'FWOF24_CHECKPOINT_A_B_A_REPLAY_BITWISE_IDENTITY=PASS' \
    'FWOF24_ACTUAL_WRT_VIEW_COMPOSES_WITH_UNCHANGED_FWO17_SWRD3_GEOMETRY=PASS' \
    'FWOF24_NO_DUPLICATE_WOFOST_LAI_STATE=PASS' \
    'FWOF24_NO_WOFOST_EVOLUTION_OR_CALENDAR_SEMANTICS=PASS' \
    'FWOF24_CROP_OWNER_COMPOSITE_STATE_TEST PASS'; do
    grep -Fq "$marker" "$BUILD/$OPT/output.txt"
  done
  echo "FWOF24_${OPT^^}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FWOF24_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FWOF24_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FWOF24_CROP_OWNER_COMPOSITE_STATE_GATE PASS'
