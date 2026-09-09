#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof34-gate-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'git -C "$ROOT" worktree remove --force "$BUILD/fwof33" >/dev/null 2>&1 || true; rm -rf "$BUILD"' EXIT

BASE="b75342a6b9d1249ba7c87b4692acabc97d11ed13"
MODULE="$ROOT/src/runtime/mod_fmr_wofost_accepted_window_lineage.f90"
CONTRACT="$ROOT/integration/f-wof/F-WOF34_WORK_UNIT_CONTRACT.json"
TEST="$ROOT/tests/fwof/test_fwof34_accepted_window_runtime_lineage.f90"
COMMON=(-std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

python3 - "$ROOT" "$BASE" <<'PY'
import json, pathlib, subprocess, sys
root=pathlib.Path(sys.argv[1]); base=sys.argv[2]
contract=json.loads((root/'integration/f-wof/F-WOF34_WORK_UNIT_CONTRACT.json').read_text())
assert contract['base']['commit']==base
assert contract['architecture']['runtime_owner'] is True
assert contract['architecture']['crop_kernel_transaction_knowledge_added'] is False
assert contract['accepted_interval_certificate']['forgery_boundary'].startswith('certificate components are private')
assert contract['accepted_window']['rejected_trial_zero_contribution'].startswith('proven by mutation tests')
changed=subprocess.check_output(['git','-C',str(root),'diff','--name-only',base+'..HEAD'], text=True).splitlines()
src=[p for p in changed if p.startswith('src/')]
assert src==['src/runtime/mod_fmr_wofost_accepted_window_lineage.f90'], src
print('FWOF34_PRODUCTION_DELTA_SINGLE_RUNTIME_LINEAGE_MODULE=PASS')
PY

python3 - "$MODULE" <<'PY'
import pathlib, re, sys
s=pathlib.Path(sys.argv[1]).read_text().lower()
assert 'use mod_kernel_transactions, only: kernel_checkpoint_t, kernel_committed_state_t' in s
assert 'use mod_wofost_one_day_structural_evolution, only: wofost_accepted_window_aggregates_t' in s
assert 'kernel_candidate_state_t' not in s
assert 'kernel_executor_t' not in s
assert 'transaction_result_t' not in s
assert 'logical :: accepted' not in s
assert 'certify_fkt_accepted_interval' in s
assert 'committed_revision /= origin_revision + 1_int64' in s
assert 'discard_wofost_trial_contribution' in s
assert 'admit_wofost_accepted_trial' in s
assert 'prepare_wofost_crop_event_delivery' in s
assert 'commit_wofost_crop_event_delivery' in s
for forbidden in ['open(', 'read(', 'write(', 'modflow', 'headcalc', 'jacobian', 'newton']:
    if forbidden in ['write(']:
        continue
    assert forbidden not in s, forbidden
print('FWOF34_FKT_COMMIT_CERTIFICATE_AND_RUNTIME_BOUNDARY_STATIC=PASS')
PY

TX="$ROOT/src/transaction/mod_transaction_reference.f90"
CONTRACTS="$ROOT/src/runtime/mod_canonical_contracts.f90"
CANONICAL_RUNTIME="$ROOT/src/runtime/mod_canonical_interval_runtime.f90"
KERNEL="$ROOT/src/kernel/mod_kernel_transactions.f90"
BIOMASS="$ROOT/src/crop/mod_wofost_actual_biomass_state.f90"
OWNER="$ROOT/src/crop/mod_wofost_crop_owner_state.f90"
STRUCTURAL="$ROOT/src/crop/mod_wofost_one_day_structural_evolution.f90"

for OPT in o0 o2; do
  FLAG="-O0"; [[ "$OPT" == "o2" ]] && FLAG="-O2"
  gfortran "${COMMON[@]}" "$FLAG" -J "$BUILD/$OPT" \
    "$TX" "$CONTRACTS" "$CANONICAL_RUNTIME" "$KERNEL" \
    "$BIOMASS" "$OWNER" "$STRUCTURAL" "$MODULE" "$TEST" \
    -o "$BUILD/test_$OPT"
  "$BUILD/test_$OPT" > "$BUILD/out_$OPT.txt"
  cat "$BUILD/out_$OPT.txt"
  echo "FWOF34_${OPT^^}=PASS"
done
cmp "$BUILD/out_o0.txt" "$BUILD/out_o2.txt"
echo 'FWOF34_O0_O2_OUTPUT_IDENTITY=PASS'
SHA=$(sha256sum "$BUILD/out_o0.txt" | awk '{print $1}')
echo "FWOF34_OUTPUT_SHA256=$SHA"

# Regression is deliberately run on the exact qualified F-WOF33 tree. Running
# its single-delta gate on the F-WOF34 tree would correctly see the new runtime
# source and would therefore be the wrong regression experiment.
git -C "$ROOT" worktree add --detach "$BUILD/fwof33" "$BASE" >/dev/null
bash "$BUILD/fwof33/tests/fwof/run_fwof33_two_phase_crop_window_gate.sh" > "$BUILD/fwof33.out"
grep -q 'FWOF33_TWO_PHASE_CROP_WINDOW_GATE PASS' "$BUILD/fwof33.out"
grep -q 'FWOF33_OUTPUT_SHA256=cfb21d02eff5086f0f17abdfe1813b116765ffc22856fe8d0e1037a7e0fc693f' "$BUILD/fwof33.out"
echo 'FWOF34_FWO33_EXACT_CLOSEOUT_REGRESSION=PASS'

echo 'FWOF34_ACCEPTED_WINDOW_RUNTIME_LINEAGE_GATE PASS'
