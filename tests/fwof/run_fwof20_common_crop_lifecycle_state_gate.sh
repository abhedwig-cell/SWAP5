#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof20-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=de5a1757edf863ebfc8bdf1c45e5c4eebafe9b11
NEW_SRC=src/crop/mod_crop_lifecycle_state.f90
changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "$NEW_SRC" ]] || {
  echo 'FWOF20_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FWOF20_PRODUCTION_DELTA_SINGLE_CROP_STATE_CARRIER=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FWOF20_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/transaction/mod_transaction_reference.f90 b1878606ae6cb2b04a7b4b15e3e537deacf4477f
check_blob src/runtime/mod_canonical_contracts.f90 0c2b15fc45011c580384cf6a618e7b378fdccf0a
check_blob src/runtime/mod_canonical_interval_runtime.f90 f2cae79d533343db818c11e0b61b605ac5f6739d
check_blob src/kernel/mod_kernel_transactions.f90 9f7c16e71cfb93b57f796ba759bae73824318a2f
check_blob src/adapter/mod_b1_10_process_checkpoint.f90 bbb9f0fbfdb9624a426d75735e8b93fe3b68b3ae
check_blob src/crop/mod_crop_root_geometry_snapshot_producer.f90 56c3e10ccd25e6790882a649d472bd67a31d0f7b
check_blob src/crop/mod_nonadaptive_crop_root_view_producer.f90 32e827c70f733b5451328ac7a95a1001a0d711f7
check_blob src/process/mod_reference_et_transpiration_process.f90 497b42f2450a003a070dbc4020573866d1ef93b0
echo 'FWOF20_FKT_LEGACY_ADAPTER_AND_UPSTREAM_LOCKS=PASS'

python3 - <<'PY'
from pathlib import Path
import json

text = Path('src/crop/mod_crop_lifecycle_state.f90').read_text()
code = '\n'.join(line.split('!', 1)[0] for line in text.splitlines()).lower()

for required in [
    'extends(transaction_state_t)',
    'type, extends(transaction_state_t), public :: crop_lifecycle_state_t',
    'logical :: crop_emerged',
    'real(real64) :: development_stage',
    'real(real64) :: leaf_area_index',
    'procedure :: clone => crop_lifecycle_clone',
    'procedure, public :: validate => crop_lifecycle_validate',
    'ieee_is_finite'
]:
    assert required in code, required

for forbidden in [
    'save ::', 't1900', 'daynr', 'calendar_', 'cropstart', 'cropend', 'open(', 'close(', 'inquire(', 'read(',
    'mod_fmr_', 'mod_soil_water_solver', 'headcalc', 'reference_richards',
    'potential_transpiration', 'vcover', 'crop_factor', 'fco2tra', 'rooted_nodes', 'cumulative_root_fraction',
    'actual_root_depth', 'potential_root_depth', 'wrt', 'solver scratch'
]:
    assert forbidden not in code, forbidden

contract = json.loads(Path('integration/f-wof/F-WOF20_COMMON_CROP_LIFECYCLE_STATE_CONTRACT.json').read_text())
recon = json.loads(Path('integration/f-wof/F-WOF20_FWO19_LEGACY_CHECKPOINT_RECONCILIATION.json').read_text())

assert contract['production_type']['fields'] == ['crop_emerged', 'development_stage', 'leaf_area_index']
assert contract['production_type']['extends'] == 'transaction_state_t'
assert contract['production_type']['calendar_fields'] is False
assert contract['production_type']['forcing_fields'] is False
assert contract['production_type']['ET_result_fields'] is False
assert contract['production_type']['root_distribution_fields'] is False
assert contract['production_type']['solver_fields'] is False
assert 'SWRD=2 actual_root_depth' in contract['explicitly_not_in_this_state']
assert 'WRT' in contract['explicitly_not_in_this_state']

assert recon['legacy_adapter_evidence']['blob'] == 'bbb9f0fbfdb9624a426d75735e8b93fe3b68b3ae'
assert recon['legacy_adapter_evidence']['transaction_state_type'] == 'b1_10_process_state_t'
assert recon['scope_correction']['production_blocker_unchanged'] is True
assert recon['classification'] == 'THEORY_CODE_EVIDENCE_RECONCILIATION_WITHOUT_PRODUCTION_CHANGE'

print('FWOF20_SCOPE_STATE_MINIMIZATION_AND_RECONCILIATION_STATIC=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
TX="$ROOT/src/transaction/mod_transaction_reference.f90"
CONTRACTS="$ROOT/src/runtime/mod_canonical_contracts.f90"
RUNTIME="$ROOT/src/runtime/mod_canonical_interval_runtime.f90"
KERNEL="$ROOT/src/kernel/mod_kernel_transactions.f90"
CROP="$ROOT/src/crop/mod_crop_lifecycle_state.f90"
TEST="$ROOT/tests/fwof/test_fwof20_common_crop_lifecycle_state.f90"

for OPT in o0 o2; do
  FLAG=-O0
  [[ "$OPT" == "o2" ]] && FLAG=-O2
  gfortran "${COMMON[@]}" "$FLAG" -J "$BUILD/$OPT" \
    "$TX" "$CONTRACTS" "$RUNTIME" "$KERNEL" "$CROP" "$TEST" -o "$BUILD/$OPT/test"
  "$BUILD/$OPT/test" > "$BUILD/$OPT/output.txt" 2>&1 || { cat "$BUILD/$OPT/output.txt" >&2; exit 1; }

  for marker in \
    'FWOF20_DIRECT_CLONE_IDENTITY_AND_INDEPENDENCE=PASS' \
    'FWOF20_INVALID_STATE_FAILS_CLOSED=PASS' \
    'FWOF20_FKT_COMMITTED_INITIALIZATION_CLONES_STATE=PASS' \
    'FWOF20_FKT_CHECKPOINT_EXACT_SNAPSHOT=PASS' \
    'FWOF20_TRIAL_DISCARD_LEAVES_COMMITTED_STATE_UNCHANGED=PASS' \
    'FWOF20_CHECKPOINT_A_B_A_REPLAY_BITWISE_IDENTITY=PASS' \
    'FWOF20_NO_CALENDAR_OR_EVOLUTION_PHYSICS_IN_CARRIER=PASS' \
    'FWOF20_COMMON_CROP_LIFECYCLE_STATE_TEST PASS'; do
    grep -Fq "$marker" "$BUILD/$OPT/output.txt"
  done
  echo "FWOF20_${OPT^^}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FWOF20_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FWOF20_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FWOF20_COMMON_CROP_LIFECYCLE_STATE_GATE PASS'
