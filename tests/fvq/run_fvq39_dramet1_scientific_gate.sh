#!/usr/bin/env bash
set -euo pipefail

BASE=3553c63e753bbf714378cd0dff5047769ad3185b
STATUS=integration/f-vq/F-VQ39_STATUS.json

changed="$(git diff --name-only "${BASE}...HEAD")"
if printf '%s\n' "$changed" | grep -Eq '^(src/|reference/)'; then
  echo 'FVQ39_NO_PRODUCTION_OR_REFERENCE_DELTA=FAIL'
  printf '%s\n' "$changed"
  exit 1
fi
echo 'FVQ39_NO_PRODUCTION_OR_REFERENCE_DELTA=PASS'

if grep -Eq 'tests/fpm/|F-PM08C1_CANDIDATE_EVIDENCE' tests/fvq/test_fvq39_dramet1_scientific.py; then
  echo 'FVQ39_INDEPENDENT_ORACLE_STATIC_SEPARATION=FAIL'
  exit 1
fi
echo 'FVQ39_INDEPENDENT_ORACLE_STATIC_SEPARATION=PASS'

set +e
output="$(python3 tests/fvq/test_fvq39_dramet1_scientific.py 2>&1)"
rc=$?
set -e
printf '%s\n' "$output"

if [[ $rc -eq 0 ]]; then
  echo 'FVQ39_DRAMET1_SCIENTIFIC_GATE=PASS_SCIENTIFIC_EQUIVALENCE'
  exit 0
fi

if [[ $rc -eq 2 ]] \
  && grep -q 'FVQ39_ONE_POINT_ZERO_LEGACY_COUNTEREXAMPLE=FAIL_CLOSED_SOURCE_OBSERVABLE_MISMATCH' <<<"$output" \
  && grep -q 'FVQ39_DRAMET1_SCIENTIFIC_EQUIVALENCE=FAIL_CLOSED_REMEDIATION_REQUIRED' <<<"$output" \
  && grep -q '"decision": "FAIL_CLOSED_DRAMET1_SOURCE_OBSERVABLE_MISMATCH_REQUIRES_REMEDIATION"' "$STATUS"; then
  echo 'FVQ39_EXPECTED_FAIL_CLOSED_DISPOSITION_REPLAY=PASS'
  echo 'FVQ39_DRAMET1_SCIENTIFIC_GATE=PASS_FAIL_CLOSED_BLOCK_PRESERVED'
  exit 0
fi

echo "FVQ39_DRAMET1_SCIENTIFIC_GATE=FAIL_UNEXPECTED_RESULT rc=${rc}"
exit 1
