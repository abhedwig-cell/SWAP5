#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof33-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2" "$BUILD/fwof31-o0" "$BUILD/fwof31-o2" "$BUILD/fwof32-o0" "$BUILD/fwof32-o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=5c35f2c244a476819a673c46b6e926561ea99c84
NEW_SRC=src/crop/mod_wofost_two_phase_crop_window.f90
changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "$NEW_SRC" ]] || {
  echo 'FWOF33_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FWOF33_PRODUCTION_DELTA_SINGLE_COMPOSITION_MODULE=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FWOF33_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/crop/mod_wofost_actual_biomass_state.f90 feab0672b38e1c9668ac418cbe9d800f032cf4d8
check_blob src/crop/mod_wofost_crop_owner_state.f90 31bb390a0b70bec0a3f525f1d704a2c53890f9b4
check_blob src/crop/mod_wofost_one_day_structural_evolution.f90 c1fd9704ca1617f1f34d41fd7ec38640cce81d94
check_blob src/crop/mod_wofost_one_day_rate_state_view.f90 eb0cf889676b617fef0542bc1b87e14b4f8b650c
check_blob src/crop/mod_wofost_rate_parameters.f90 b2e2b86e2f0b8be3f569604523b4891af40016b5
check_blob src/crop/mod_wofost_prepare_assimilation.f90 9d948be4fbd264fd3c3316fbc2b323d0c3b69f44
check_blob src/crop/mod_wofost_finalize_rates.f90 5a57ef2301e6ee308db7fa2ab486a86f2f689ee0
check_blob integration/f-wof/F-WOF32_STATUS.json fe62012af68f816604e60d9e45d8b5a7d6f0524b
echo 'FWOF33_FWO32_CLOSEOUT_AND_COMPONENT_CHAIN_LOCK=PASS'

python3 - <<'PY'
from pathlib import Path
import json, re

src = Path('src/crop/mod_wofost_two_phase_crop_window.f90').read_text()
code = '\n'.join(line.split('!', 1)[0] for line in src.splitlines()).lower()
contract = json.loads(Path('integration/f-wof/F-WOF33_WORK_UNIT_CONTRACT.json').read_text())
status32 = json.loads(Path('integration/f-wof/F-WOF32_STATUS.json').read_text())

assert contract['base']['commit'] == '5c35f2c244a476819a673c46b6e926561ea99c84'
assert contract['base']['exact_closeout_conclusion'] == 'success'
assert status32['status'] == 'QUALIFIED_RESTRICTED_PURE_WOFOST_PHASE_B_RATE_PROVIDER_WITH_RUNTIME_LINEAGE_HOLD'
assert contract['accepted_window_provenance_hold']['implemented_or_proven_by_F_WOF33'] is False
assert contract['phase_B_complete']['commit_authority'] is False
assert contract['temporal_contract']['scheduler_implemented_here'] is False

for required in [
    'subroutine begin_wofost_one_day_crop_window',
    'call prepare_wofost_one_day_candidate',
    'call assemble_wofost_one_day_rate_state_view',
    'call prepare_wofost_actual_assimilation',
    'subroutine complete_wofost_one_day_crop_window',
    'call finalize_wofost_one_day_rates',
    'call finalize_wofost_one_day_candidate',
    'type(wofost_crop_owner_state_t) :: prepared_candidate',
    'type(wofost_one_day_rate_state_view_t) :: rate_state_view',
    'type(wofost_prepare_assimilation_result_t) :: prepared_assimilation',
    'type(wofost_finalize_rate_forcing_t) :: phase_b_forcing',
    'candidate = window%prepared_candidate'
]:
    assert required in code, required

# Component invocation order must be monotone within each public phase.
begin = code[code.index('subroutine begin_wofost_one_day_crop_window'):code.index('end subroutine begin_wofost_one_day_crop_window')]
assert begin.index('call prepare_wofost_one_day_candidate') < begin.index('call assemble_wofost_one_day_rate_state_view') < begin.index('call prepare_wofost_actual_assimilation')
complete = code[code.index('subroutine complete_wofost_one_day_crop_window'):code.index('end subroutine complete_wofost_one_day_crop_window')]
assert complete.index('call finalize_wofost_one_day_rates') < complete.index('call finalize_wofost_one_day_candidate')

# Runtime/transaction/solver ownership must not leak into crop composition.
for forbidden in [
    'transaction_result_t', 'execute_reference_interval', 'mod_kernel_transactions',
    'mod_fmr_', 'root_water_uptake', 'headcalc', 'modflow', 'jacobian', 'newton',
    'daynr', 't1900', '.swp'
]:
    assert forbidden not in code, forbidden
assert 'save' not in code
assert not re.search(r'\bintent\(inout\)\b', code)
assert not re.search(r'\b(open|close|inquire|read|write)\s*\(', code)

# The trial context must not own/copy the immutable rate bundle or accepted accumulator.
ctx = code[code.index('type, public :: wofost_two_phase_crop_window_t'):code.index('end type wofost_two_phase_crop_window_t')]
assert 'wofost_rate_parameter_bundle_t' not in ctx
assert 'wofost_accepted_window_aggregates_t' not in ctx
assert 'transaction' not in ctx

print('FWOF33_EXACT_TWO_PHASE_COMPONENT_ORDER_STATIC=PASS')
print('FWOF33_TRIAL_CONTEXT_HAS_NO_PARAMETER_BUNDLE_OR_ACCEPTED_ACCUMULATOR=PASS')
print('FWOF33_NO_COMMIT_SCHEDULER_SOLVER_TRANSACTION_OR_IO_DEPENDENCY=PASS')
print('FWOF33_RUNTIME_ACCEPTED_WINDOW_PROVENANCE_HOLD_STATIC=PASS')
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
COMPOSE="$ROOT/src/crop/mod_wofost_two_phase_crop_window.f90"
TEST="$ROOT/tests/fwof/test_fwof33_two_phase_crop_window.f90"
TEST31="$ROOT/tests/fwof/test_fwof31_prepare_assimilation.f90"
TEST32="$ROOT/tests/fwof/test_fwof32_finalize_rates.f90"

compile_modules() {
  local dir="$1" flag="$2"
  pushd "$dir" >/dev/null
  gfortran "${COMMON[@]}" "$flag" -J . -I . -c \
    "$TX" "$BIOMASS" "$OWNER" "$STRUCT" "$VIEW" "$TABLE" "$PARAM" "$PREP" "$FINAL" "$COMPOSE"
  popd >/dev/null
}

for OPT in o0 o2; do
  FLAG=-O0
  [[ "$OPT" == "o2" ]] && FLAG=-O2
  compile_modules "$BUILD/$OPT" "$FLAG"
  pushd "$BUILD/$OPT" >/dev/null
  gfortran "${COMMON[@]}" "$FLAG" -J . -I . "$TEST" ./*.o -o test
  ./test > output.txt 2>&1 || { cat output.txt >&2; exit 1; }
  popd >/dev/null
  for marker in \
    'FWOF33_PHASE_A_COMPONENT_ORDER_AND_BITWISE_COMPOSITION=PASS' \
    'FWOF33_PHASE_B_AND_STRUCTURAL_COMPONENT_ORDER_BITWISE_COMPOSITION=PASS' \
    'FWOF33_EXACTLY_ONE_COHORT_SHIFT_PER_COMPLETE=PASS' \
    'FWOF33_BEGIN_AND_COMPLETE_LEAVE_COMMITTED_STATE_UNCHANGED=PASS' \
    'FWOF33_SAME_CHECKPOINT_BEGIN_REPLAY_BITWISE_IDENTITY=PASS' \
    'FWOF33_SAME_CONTEXT_COMPLETE_REPLAY_BITWISE_IDENTITY=PASS' \
    'FWOF33_FAILED_PHASE_B_RETURNS_UNADVANCED_PREPARED_CANDIDATE=PASS' \
    'FWOF33_WINDOW_CONTEXT_REUSABLE_AFTER_DISCARDED_COMPLETE=PASS' \
    'FWOF33_FAILED_STRUCTURAL_FINALIZE_RETURNS_UNADVANCED_PREPARED_CANDIDATE=PASS' \
    'FWOF33_INACTIVE_CROP_SKIPS_ALL_ACTIVE_ONLY_DEPENDENCIES=PASS' \
    'FWOF33_ONLY_QUALIFIED_ONE_DAY_EVENT_AND_FAILED_BEGIN_IS_ATOMIC=PASS' \
    'FWOF33_TWO_PHASE_CROP_WINDOW_TEST PASS'; do
    grep -Fq "$marker" "$BUILD/$OPT/output.txt"
  done
  echo "FWOF33_${OPT^^}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FWOF33_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FWOF33_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"

# Exact F-WOF31 regression against unchanged component sources.
for OPT in o0 o2; do
  FLAG=-O0
  [[ "$OPT" == "o2" ]] && FLAG=-O2
  pushd "$BUILD/fwof31-$OPT" >/dev/null
  gfortran "${COMMON[@]}" "$FLAG" -J . -I . \
    "$TX" "$BIOMASS" "$OWNER" "$VIEW" "$TABLE" "$PARAM" "$PREP" "$TEST31" -o test
  ./test > output.txt 2>&1
  popd >/dev/null
done
cmp "$BUILD/fwof31-o0/output.txt" "$BUILD/fwof31-o2/output.txt"
SHA31="$(sha256sum "$BUILD/fwof31-o0/output.txt" | cut -d' ' -f1)"
[[ "$SHA31" == 'd4ad755913eb884d5e764499a33fb7937114f82d61dee1a69b03dfb650003335' ]] || {
  echo "FWOF33_FWO31_REGRESSION_SHA_MISMATCH actual=$SHA31" >&2
  exit 1
}
echo 'FWOF33_FWO31_PREPARE_ASSIMILATION_EXACT_REGRESSION=PASS'

# Exact F-WOF32 regression. Production modules stay under full -Werror;
# only the existing F-WOF32 fixture retains its documented compare-real warning.
for OPT in o0 o2; do
  FLAG=-O0
  [[ "$OPT" == "o2" ]] && FLAG=-O2
  pushd "$BUILD/fwof32-$OPT" >/dev/null
  gfortran "${COMMON[@]}" "$FLAG" -J . -I . -c \
    "$TX" "$BIOMASS" "$OWNER" "$STRUCT" "$VIEW" "$TABLE" "$PARAM" "$PREP" "$FINAL"
  gfortran "${COMMON[@]}" -Wno-error=compare-reals "$FLAG" -J . -I . "$TEST32" ./*.o -o test
  ./test > output.txt 2>&1
  popd >/dev/null
done
cmp "$BUILD/fwof32-o0/output.txt" "$BUILD/fwof32-o2/output.txt"
SHA32="$(sha256sum "$BUILD/fwof32-o0/output.txt" | cut -d' ' -f1)"
[[ "$SHA32" == 'ba19ecb50b3365065244d6daf3483888875195e6d06ddf36432f5b84452c3584' ]] || {
  echo "FWOF33_FWO32_REGRESSION_SHA_MISMATCH actual=$SHA32" >&2
  exit 1
}
echo 'FWOF33_FWO32_FINALIZE_RATES_EXACT_REGRESSION=PASS'

echo 'FWOF33_TWO_PHASE_CROP_WINDOW_GATE PASS'
