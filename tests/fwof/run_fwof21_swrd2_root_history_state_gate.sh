#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof21-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=c201e393834b260401edcd7ceb2a4864ec65684f
NEW_SRC=src/crop/mod_swrd2_crop_lifecycle_state.f90
changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "$NEW_SRC" ]] || {
  echo 'FWOF21_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FWOF21_PRODUCTION_DELTA_SINGLE_SWRD2_STATE_SUBTYPE=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FWOF21_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/crop/mod_crop_lifecycle_state.f90 c1fbb2c615254cfda0b26a7aff20447fb9960502
check_blob integration/f-wof/F-WOF20_STATUS.json 3196a3045ab1ec417e1858e9583002ccd05938d9
check_blob src/transaction/mod_transaction_reference.f90 b1878606ae6cb2b04a7b4b15e3e537deacf4477f
check_blob src/runtime/mod_canonical_contracts.f90 0c2b15fc45011c580384cf6a618e7b378fdccf0a
check_blob src/runtime/mod_canonical_interval_runtime.f90 f2cae79d533343db818c11e0b61b605ac5f6739d
check_blob src/kernel/mod_kernel_transactions.f90 9f7c16e71cfb93b57f796ba759bae73824318a2f
check_blob src/adapter/mod_b1_10_process_checkpoint.f90 bbb9f0fbfdb9624a426d75735e8b93fe3b68b3ae
check_blob src/crop/mod_crop_root_geometry_snapshot_producer.f90 56c3e10ccd25e6790882a649d472bd67a31d0f7b
echo 'FWOF21_FWO20_FKT_LEGACY_AND_GEOMETRY_LOCKS=PASS'

python3 - <<'PY'
from pathlib import Path
import json

text = Path('src/crop/mod_swrd2_crop_lifecycle_state.f90').read_text()
code = '\n'.join(line.split('!', 1)[0] for line in text.splitlines()).lower()

for required in [
    'extends(crop_lifecycle_state_t)',
    'type, extends(crop_lifecycle_state_t), public :: swrd2_crop_lifecycle_state_t',
    'real(real64) :: actual_root_depth',
    'real(real64) :: potential_root_depth',
    'procedure :: clone => swrd2_crop_lifecycle_clone',
    'procedure, public :: validate => swrd2_crop_lifecycle_validate',
    'allocate(swrd2_crop_lifecycle_state_t :: copy)',
    'self%crop_lifecycle_state_t%validate()'
]:
    assert required in code, required

for forbidden in [
    'wrt', 'wrtpot', 'noddrz', 'rdm', 'rdi', 'rri', 'iptra_day', 'iqrot_day', 'ialpdry_day', 'ialpwet_day',
    'save ::', 't1900', 'daynr', 'calendar_', 'open(', 'close(', 'read(', 'inquire(',
    'mod_fmr_', 'mod_soil_water_solver', 'headcalc', 'reference_richards'
]:
    assert forbidden not in code, forbidden

base_code = Path('src/crop/mod_crop_lifecycle_state.f90').read_text().lower()
assert 'actual_root_depth' not in base_code
assert 'potential_root_depth' not in base_code
assert 'wrt' not in base_code

contract = json.loads(Path('integration/f-wof/F-WOF21_SWRD2_ROOT_HISTORY_STATE_CONTRACT.json').read_text())
evidence = json.loads(Path('integration/f-wof/F-WOF21_SOURCE_BOUND_ROOT_HISTORY_EVIDENCE.json').read_text())

assert contract['mode_decision']['SWRD_1']['extra_committed_root_history'] == []
assert contract['mode_decision']['SWRD_2']['extra_committed_root_history'] == ['actual_root_depth', 'potential_root_depth']
assert contract['mode_decision']['SWRD_3']['decision'] == 'BLOCK_STANDALONE_WRT_DUPLICATION'
assert contract['production_type']['allocated_only_for_SWRD2_execution_class'] is True
assert evidence['SWRD_2_history']['classification'] == 'IRREDUCIBLE_OPTIONAL_COMMITTED_ROOT_HISTORY'
assert evidence['WRT_broader_ownership']['classification'] == 'BROADER_CROP_BIOMASS_STATE_NOT_ROOT_GEOMETRY_HELPER'
assert evidence['WRT_broader_ownership']['standalone_SWRD3_WRT_state_permitted'] is False
assert evidence['decision'] == 'IMPLEMENT_SWRD2_OPTIONAL_HISTORY_BLOCK_STANDALONE_WRT_DUPLICATION'

print('FWOF21_OPTIONAL_STATE_AND_WRT_OWNERSHIP_STATIC=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
TX="$ROOT/src/transaction/mod_transaction_reference.f90"
CONTRACTS="$ROOT/src/runtime/mod_canonical_contracts.f90"
RUNTIME="$ROOT/src/runtime/mod_canonical_interval_runtime.f90"
KERNEL="$ROOT/src/kernel/mod_kernel_transactions.f90"
BASE_CROP="$ROOT/src/crop/mod_crop_lifecycle_state.f90"
SWRD2="$ROOT/src/crop/mod_swrd2_crop_lifecycle_state.f90"
TEST="$ROOT/tests/fwof/test_fwof21_swrd2_root_history_state.f90"

for OPT in o0 o2; do
  FLAG=-O0
  [[ "$OPT" == "o2" ]] && FLAG=-O2
  gfortran "${COMMON[@]}" "$FLAG" -J "$BUILD/$OPT" \
    "$TX" "$CONTRACTS" "$RUNTIME" "$KERNEL" "$BASE_CROP" "$SWRD2" "$TEST" -o "$BUILD/$OPT/test"
  "$BUILD/$OPT/test" > "$BUILD/$OPT/output.txt" 2>&1 || { cat "$BUILD/$OPT/output.txt" >&2; exit 1; }

  for marker in \
    'FWOF21_SWRD1_USES_COMMON_STATE_WITHOUT_ROOT_HISTORY=PASS' \
    'FWOF21_CLONE_PRESERVES_SWRD2_DYNAMIC_SUBTYPE=PASS' \
    'FWOF21_INVALID_ROOT_HISTORY_FAILS_CLOSED=PASS' \
    'FWOF21_FKT_COMMITTED_STATE_PRESERVES_SWRD2_SUBTYPE=PASS' \
    'FWOF21_FKT_CHECKPOINT_PRESERVES_ROOT_HISTORY=PASS' \
    'FWOF21_TRIAL_DISCARD_LEAVES_SWRD2_HISTORY_UNCHANGED=PASS' \
    'FWOF21_CHECKPOINT_REPLAY_BITWISE_IDENTITY=PASS' \
    'FWOF21_WRT_NOT_DUPLICATED_IN_SWRD2_STATE=PASS' \
    'FWOF21_SWRD2_ROOT_HISTORY_STATE_TEST PASS'; do
    grep -Fq "$marker" "$BUILD/$OPT/output.txt"
  done
  echo "FWOF21_${OPT^^}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FWOF21_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FWOF21_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FWOF21_SWRD2_ROOT_HISTORY_STATE_GATE PASS'
