#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof28-$$"
mkdir -p "$BUILD/view-o0" "$BUILD/view-o2" "$BUILD/fwof26-o0" "$BUILD/fwof26-o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=3944fc59b1780586e91d31e1f632e458ea29ad23
NEW_SRC=src/crop/mod_wofost_one_day_rate_state_view.f90
changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "$NEW_SRC" ]] || {
  echo 'FWOF28_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FWOF28_PRODUCTION_DELTA_SINGLE_RATE_STATE_VIEW_MODULE=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FWOF28_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/crop/mod_wofost_actual_biomass_state.f90 feab0672b38e1c9668ac418cbe9d800f032cf4d8
check_blob src/crop/mod_wofost_crop_owner_state.f90 31bb390a0b70bec0a3f525f1d704a2c53890f9b4
check_blob src/crop/mod_wofost_one_day_structural_evolution.f90 c1fd9704ca1617f1f34d41fd7ec38640cce81d94
check_blob integration/f-wof/F-WOF27_STATUS.json 92d2d9d5a08b46a852d23f0764b6fc8ab7d4ef52
check_blob integration/f-wof/F-WOF27_QUALIFICATION_EVIDENCE.json 42b9e5168f24b632d4963b882309617f23586887
echo 'FWOF28_FWO27_CLOSEOUT_AND_PRIOR_OWNER_LOCK=PASS'

python3 - <<'PY'
from pathlib import Path
import json, re

text = Path('src/crop/mod_wofost_one_day_rate_state_view.f90').read_text()
code = '\n'.join(line.split('!', 1)[0] for line in text.splitlines()).lower()
contract = json.loads(Path('integration/f-wof/F-WOF28_WORK_UNIT_CONTRACT.json').read_text())
status27 = json.loads(Path('integration/f-wof/F-WOF27_STATUS.json').read_text())

assert contract['base']['commit'] == '3944fc59b1780586e91d31e1f632e458ea29ad23'
assert status27['status'] == 'QUALIFIED_RESTRICTED_STANDARD_WOFOST_ONE_DAY_RATE_EVALUATOR_READINESS'
assert contract['production_scope']['persistent_state_added'] is False
assert contract['production_scope']['rate_physics_added'] is False
assert contract['production_scope']['state_mutation'] is False

for required in [
    'type, public :: wofost_one_day_rate_state_view_t',
    'real(real64) :: development_stage',
    'real(real64) :: actual_root_biomass',
    'real(real64) :: actual_stem_biomass',
    'real(real64) :: actual_storage_biomass',
    'real(real64) :: living_leaf_biomass',
    'real(real64) :: actual_leaf_area_index',
    'real(real64) :: exponential_leaf_area_index',
    'subroutine assemble_wofost_one_day_rate_state_view',
    'type(wofost_crop_owner_state_t), intent(in) :: owner'
]:
    assert required in code, required

assert 'allocatable' not in code
assert not re.search(r'\bleaf_biomass\s*\(', code)
for forbidden in [
    'pgass', 'reltr', 'iqrot', 'iptra', 'afgen', 'totass', 'assim(',
    'daynr', 't1900', 'astro(', 'mod_integral', 'mod_meteo', 'headcalc', 'modflow', '.swp'
]:
    assert forbidden not in code, forbidden
assert not re.search(r'\b(open|close|inquire|read|write)\s*\(', code)

print('FWOF28_COMPACT_SCALAR_VIEW_STATIC=PASS')
print('FWOF28_OWNER_READ_ONLY_BOUNDARY_STATIC=PASS')
print('FWOF28_NO_RATE_PHYSICS_CALENDAR_IO_OR_SOLVER_DEPENDENCY=PASS')
print('FWOF28_NO_LEAF_COHORT_COPY_IN_VIEW=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -Wno-unused-variable -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
TX="$ROOT/src/transaction/mod_transaction_reference.f90"
CONTRACTS="$ROOT/src/runtime/mod_canonical_contracts.f90"
RUNTIME="$ROOT/src/runtime/mod_canonical_interval_runtime.f90"
KERNEL="$ROOT/src/kernel/mod_kernel_transactions.f90"
BIOMASS="$ROOT/src/crop/mod_wofost_actual_biomass_state.f90"
OWNER="$ROOT/src/crop/mod_wofost_crop_owner_state.f90"
VIEW="$ROOT/src/crop/mod_wofost_one_day_rate_state_view.f90"
EVOLUTION="$ROOT/src/crop/mod_wofost_one_day_structural_evolution.f90"
VIEW_TEST="$ROOT/tests/fwof/test_fwof28_rate_state_view_assembly.f90"
FWO26_TEST="$ROOT/tests/fwof/test_fwof26_one_day_structural_evolution.f90"

for OPT in o0 o2; do
  FLAG=-O0
  [[ "$OPT" == "o2" ]] && FLAG=-O2
  gfortran "${COMMON[@]}" "$FLAG" -J "$BUILD/view-$OPT" \
    "$TX" "$BIOMASS" "$OWNER" "$VIEW" "$VIEW_TEST" -o "$BUILD/view-$OPT/test"
  "$BUILD/view-$OPT/test" > "$BUILD/view-$OPT/output.txt" 2>&1 || {
    cat "$BUILD/view-$OPT/output.txt" >&2
    exit 1
  }
  for marker in \
    'FWOF28_INACTIVE_ROUTE_NO_ACTIVE_CANOPY_DEPENDENCY=PASS' \
    'FWOF28_ACTIVE_SEMANTIC_RATE_STATE_VIEW=PASS' \
    'FWOF28_ASSEMBLY_DOES_NOT_MUTATE_OWNER=PASS' \
    'FWOF28_ACTIVE_CANOPY_PARAMETERS_FAIL_CLOSED=PASS' \
    'FWOF28_INVALID_OWNER_FAILS_CLOSED=PASS' \
    'FWOF28_ACTIVE_NEGATIVE_DVS_FAILS_CLOSED=PASS' \
    'FWOF28_RATE_STATE_VIEW_ASSEMBLY_TEST PASS'; do
    grep -Fq "$marker" "$BUILD/view-$OPT/output.txt"
  done
  echo "FWOF28_${OPT^^}=PASS"
done

cmp "$BUILD/view-o0/output.txt" "$BUILD/view-o2/output.txt"
echo 'FWOF28_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/view-o0/output.txt"
echo "FWOF28_OUTPUT_SHA256=$(sha256sum "$BUILD/view-o0/output.txt" | cut -d' ' -f1)"

for OPT in o0 o2; do
  FLAG=-O0
  [[ "$OPT" == "o2" ]] && FLAG=-O2
  gfortran "${COMMON[@]}" "$FLAG" -J "$BUILD/fwof26-$OPT" \
    "$TX" "$CONTRACTS" "$RUNTIME" "$KERNEL" "$BIOMASS" "$OWNER" "$EVOLUTION" "$FWO26_TEST" \
    -o "$BUILD/fwof26-$OPT/test"
  "$BUILD/fwof26-$OPT/test" > "$BUILD/fwof26-$OPT/output.txt" 2>&1 || {
    cat "$BUILD/fwof26-$OPT/output.txt" >&2
    exit 1
  }
done
cmp "$BUILD/fwof26-o0/output.txt" "$BUILD/fwof26-o2/output.txt"
FWO26_SHA="$(sha256sum "$BUILD/fwof26-o0/output.txt" | cut -d' ' -f1)"
[[ "$FWO26_SHA" == 'e3ec4954bc2a98984eb232f41eb073f44474cb988f2e8c01cc71e375794fefa0' ]] || {
  echo "FWOF28_FWO26_REGRESSION_SHA_MISMATCH actual=$FWO26_SHA" >&2
  exit 1
}
grep -Fq 'FWOF26_ONE_DAY_STRUCTURAL_EVOLUTION_TEST PASS' "$BUILD/fwof26-o0/output.txt"
echo 'FWOF28_FWO26_STRUCTURAL_REGRESSION_EXACT_OUTPUT=PASS'

echo 'FWOF28_RATE_STATE_VIEW_GATE PASS'
