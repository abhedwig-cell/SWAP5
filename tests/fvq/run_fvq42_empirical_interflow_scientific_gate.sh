#!/usr/bin/env bash
set -euo pipefail

BASE=3553c63e753bbf714378cd0dff5047769ad3185b
changed="$(git diff --name-only "${BASE}...HEAD")"
if printf '%s\n' "$changed" | grep -Eq '^(src/|reference/)'; then
  echo 'FVQ42_NO_PRODUCTION_OR_REFERENCE_DELTA=FAIL'
  printf '%s\n' "$changed"
  exit 1
fi
echo 'FVQ42_NO_PRODUCTION_OR_REFERENCE_DELTA=PASS'

python3 - <<'PY'
from pathlib import Path
p=Path('tests/fvq/test_fvq42_empirical_interflow_scientific.py').read_text()
for forbidden in ['tests/fpm/', 'F-PM08C3_CANDIDATE_EVIDENCE', 'F-PM08C3_INVARIANT_AUDIT']:
    assert forbidden not in p, forbidden
for required in [
    '66199567e95369f42bbc75b1b279aa959050a733',
    'eb53096b678d08b76d3fb1adb2247bc2a58ee748',
    'legacy_active_oracle',
    'legacy_active_tangent_oracle',
    '48e4792acd0a129a6939008bd51e82f9fed4668fcf8d28d03da0bc6efe6944cc'
]:
    assert required in p, required
print('FVQ42_INDEPENDENT_ORACLE_STATIC_SEPARATION=PASS')
PY

python3 tests/fvq/test_fvq42_empirical_interflow_scientific.py

echo 'FVQ42_EMPIRICAL_INTERFLOW_SCIENTIFIC_GATE=PASS'
