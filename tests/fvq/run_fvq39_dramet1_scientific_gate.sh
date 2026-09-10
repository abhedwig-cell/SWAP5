#!/usr/bin/env bash
set -euo pipefail

BASE=3553c63e753bbf714378cd0dff5047769ad3185b

changed="$(git diff --name-only "${BASE}...HEAD")"
if printf '%s\n' "$changed" | grep -Eq '^(src/|reference/)'; then
  echo 'FVQ39_NO_PRODUCTION_OR_REFERENCE_DELTA=FAIL'
  printf '%s\n' "$changed"
  exit 1
fi
echo 'FVQ39_NO_PRODUCTION_OR_REFERENCE_DELTA=PASS'

if grep -Eq 'F-PM08C1|test_fpm08c1|CANDIDATE_EVIDENCE' tests/fvq/test_fvq39_dramet1_scientific.py; then
  # Candidate SHA/path constants are allowed, but authoring tests/evidence must not be imported or parsed.
  if grep -Eq 'tests/fpm/|F-PM08C1_CANDIDATE_EVIDENCE' tests/fvq/test_fvq39_dramet1_scientific.py; then
    echo 'FVQ39_INDEPENDENT_ORACLE_STATIC_SEPARATION=FAIL'
    exit 1
  fi
fi
echo 'FVQ39_INDEPENDENT_ORACLE_STATIC_SEPARATION=PASS'

python3 tests/fvq/test_fvq39_dramet1_scientific.py
