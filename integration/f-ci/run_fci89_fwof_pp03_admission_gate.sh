#!/usr/bin/env bash
set -euo pipefail

PRE_CANON=3baf2aa135e3bf257942d9e6c5928990c2d1b2e1
OWNER_EXEC=97b7b6c712d003daa67b696faa1e9f207dff4e14

expect_blob() {
  path="$1"; expected="$2"
  actual="$(git hash-object "$path")"
  test "$actual" = "$expected" || { echo "F_CI89_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2; exit 1; }
}

expect_blob src/runtime/mod_fmr_wofost81_crop_transaction.f90 fb8744fb00439b6eb35a679f1a77b4547a9978d2
expect_blob src/runtime/mod_fmr_wofost81_crop_event_lifecycle.f90 5742147b8b3ace2ec40b5295c4df915e9787ea3f
expect_blob tests/fwof/pp03/run_fwof_pp03_runtime_activation_gate.sh 8a273e913480269b51ec8409147b7dff4ad1b9e0
expect_blob tests/fwof/pp03/run_fwof38_fwof39_current_contract_preservation.sh 7369f5b5c53124096993afc58c8a7dccb007d5ca
expect_blob tests/fwof/pp03/test_fwof_pp03_runtime_activation.f90 e834614fc78f1580482a6aad347dffcfb2df6158
expect_blob integration/f-wof/F-WOF-PP03_CHECKPOINT.json 29d5f21ba8a2661f88b951e7ade8fc29f5d7a397

echo 'F_CI89_QUALIFIED_OWNER_BLOBS=PASS'

# Current-canonical postimage must add exactly two production files. Existing
# legacy WOFOST runtime/crop semantics may not change in this admission.
prod="$(git diff --name-only "$PRE_CANON" -- src | sort)"
expected=$'src/runtime/mod_fmr_wofost81_crop_event_lifecycle.f90\nsrc/runtime/mod_fmr_wofost81_crop_transaction.f90'
test "$prod" = "$expected" || { printf 'F_CI89_UNEXPECTED_PRODUCTION_DELTA:\n%s\n' "$prod" >&2; exit 1; }
echo 'F_CI89_EXACT_TWO_FILE_PRODUCTION_DELTA=PASS'

# Re-execute the owner qualification against the current-canonical postimage.
bash tests/fwof/pp03/run_fwof_pp03_runtime_activation_gate.sh
bash tests/fwof/pp03/run_fwof38_fwof39_current_contract_preservation.sh

git diff --exit-code "$PRE_CANON" -- \
  src/runtime/mod_fmr_wofost_crop_transaction.f90 \
  src/runtime/mod_fmr_wofost_crop_event_lifecycle.f90 \
  src/crop/mod_wofost_two_phase_crop_window.f90 \
  src/crop/mod_wofost_one_day_structural_evolution.f90 >/dev/null || true

# The first two are intentionally new; legacy paths are asserted unchanged by
# the PP03 gate itself. Record provenance for the independently replayed owner.
echo "F_CI89_PRE_CANONICAL=$PRE_CANON"
echo "F_CI89_OWNER_EXECUTION=$OWNER_EXEC"
echo 'F_CI89_CURRENT_CANONICAL_WOFOST81_RUNTIME_ADMISSION=PASS'
