#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof37-donor-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=cf790e559884f2c834db098fe6a010527cd504bf
DONOR=b75342a6b9d1249ba7c87b4692acabc97d11ed13
EXPECTED_FWO33_OUTPUT_SHA=cfb21d02eff5086f0f17abdfe1813b116765ffc22856fe8d0e1037a7e0fc693f

cat > "$BUILD/expected-src-delta.txt" <<'EOF'
src/crop/mod_wofost_finalize_rates.f90
src/crop/mod_wofost_one_day_rate_state_view.f90
src/crop/mod_wofost_prepare_assimilation.f90
src/crop/mod_wofost_rate_parameters.f90
src/crop/mod_wofost_rate_table.f90
src/crop/mod_wofost_two_phase_crop_window.f90
EOF
git diff --name-only "$BASE"..HEAD -- src | sort > "$BUILD/actual-src-delta.txt"
diff -u "$BUILD/expected-src-delta.txt" "$BUILD/actual-src-delta.txt"
echo 'FWOF37_EXACT_SIX_FILE_PRODUCTION_DONOR_DELTA=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FWOF37_BLOB_MISMATCH path=$path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/crop/mod_wofost_actual_biomass_state.f90 feab0672b38e1c9668ac418cbe9d800f032cf4d8
check_blob src/crop/mod_wofost_crop_owner_state.f90 31bb390a0b70bec0a3f525f1d704a2c53890f9b4
check_blob src/crop/mod_wofost_one_day_structural_evolution.f90 c1fd9704ca1617f1f34d41fd7ec38640cce81d94
check_blob src/crop/mod_wofost_one_day_rate_state_view.f90 eb0cf889676b617fef0542bc1b87e14b4f8b650c
check_blob src/crop/mod_wofost_rate_table.f90 5a0e8387157c5d1e1a6a94a24c19c7519c6bfcd5
check_blob src/crop/mod_wofost_rate_parameters.f90 b2e2b86e2f0b8be3f569604523b4891af40016b5
check_blob src/crop/mod_wofost_prepare_assimilation.f90 9d948be4fbd264fd3c3316fbc2b323d0c3b69f44
check_blob src/crop/mod_wofost_finalize_rates.f90 5a57ef2301e6ee308db7fa2ab486a86f2f689ee0
check_blob src/crop/mod_wofost_two_phase_crop_window.f90 45fac1cd92cb2269cb30b56b8b89dc8ec49c7485
echo 'FWOF37_EXACT_FWO33_COMPONENT_BLOB_CLOSURE=PASS'

python3 - <<'PY'
from pathlib import Path
import re
src = Path('src/crop/mod_wofost_two_phase_crop_window.f90').read_text(encoding='utf-8')
code = '\n'.join(line.split('!', 1)[0] for line in src.splitlines()).lower()
for required in [
    'subroutine begin_wofost_one_day_crop_window',
    'call prepare_wofost_one_day_candidate',
    'call assemble_wofost_one_day_rate_state_view',
    'call prepare_wofost_actual_assimilation',
    'subroutine complete_wofost_one_day_crop_window',
    'call finalize_wofost_one_day_rates',
    'call finalize_wofost_one_day_candidate'
]:
    assert required in code, required
for forbidden in [
    'mod_kernel_transactions', 'mod_fmr_', 'headcalc', 'modflow', 'jacobian',
    'newton', 'daynr', 't1900', '.swp'
]:
    assert forbidden not in code, forbidden
assert 'save' not in code
assert not re.search(r'\bintent\(inout\)\b', code)
assert not re.search(r'\b(open|close|inquire|read|write)\s*\(', code)
print('FWOF37_CROP_KERNEL_RUNTIME_TRANSACTION_IO_ISOLATION=PASS')
PY

git show "$DONOR:tests/fwof/test_fwof33_two_phase_crop_window.f90" > "$BUILD/test_fwof33_two_phase_crop_window.f90"

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
TEST="$BUILD/test_fwof33_two_phase_crop_window.f90"

for OPT in 0 2; do
  OUT="$BUILD/o$OPT"
  pushd "$OUT" >/dev/null
  gfortran "${COMMON[@]}" -O"$OPT" -J . -I . -c \
    "$TX" "$BIOMASS" "$OWNER" "$STRUCT" "$VIEW" "$TABLE" "$PARAM" "$PREP" "$FINAL" "$COMPOSE"
  gfortran "${COMMON[@]}" -O"$OPT" -J . -I . "$TEST" ./*.o -o test
  ./test > output.txt 2>&1
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
    grep -Fq "$marker" "$OUT/output.txt"
  done
  echo "FWOF37_FWO33_O${OPT}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
SHA="$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
[[ "$SHA" == "$EXPECTED_FWO33_OUTPUT_SHA" ]] || {
  echo "FWOF37_FWO33_OUTPUT_SHA_MISMATCH expected=$EXPECTED_FWO33_OUTPUT_SHA actual=$SHA" >&2
  exit 1
}
echo 'FWOF37_FWO33_O0_O2_OUTPUT_IDENTITY=PASS'
echo "FWOF37_FWO33_EXACT_CLOSEOUT_TRANSCRIPT=PASS SHA256=$SHA"
echo 'FWOF37_DONOR_COMPOSITION_GATE PASS'
