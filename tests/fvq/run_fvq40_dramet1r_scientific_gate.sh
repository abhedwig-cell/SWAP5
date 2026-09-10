#!/usr/bin/env bash
set -euo pipefail

BASE=3553c63e753bbf714378cd0dff5047769ad3185b

changed="$(git diff --name-only "${BASE}...HEAD")"
if printf '%s\n' "$changed" | grep -Eq '^(src/|reference/)'; then
  echo 'FVQ40_NO_PRODUCTION_OR_REFERENCE_DELTA=FAIL'
  printf '%s\n' "$changed"
  exit 1
fi
echo 'FVQ40_NO_PRODUCTION_OR_REFERENCE_DELTA=PASS'

if grep -Eq 'tests/fpm/|F-PM08C1R_REMEDIATION_EVIDENCE|F-PM08C1_CANDIDATE_EVIDENCE' tests/fvq/test_fvq40_dramet1r_scientific.py; then
  echo 'FVQ40_INDEPENDENT_ORACLE_STATIC_SEPARATION=FAIL'
  exit 1
fi
echo 'FVQ40_INDEPENDENT_ORACLE_STATIC_SEPARATION=PASS'

python3 tests/fvq/test_fvq40_dramet1r_scientific.py

echo 'FVQ40_DRAMET1_REMEDIATED_SCIENTIFIC_GATE PASS'
