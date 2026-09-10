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

python3 - <<'PY'
from pathlib import Path
p=Path('tests/fvq/test_fvq40_dramet1_remediated_scientific.py').read_text()
for forbidden in ['tests/fpm/', 'F-PM08C1_CANDIDATE_EVIDENCE', 'F-PM08C1R_REMEDIATION_EVIDENCE']:
    assert forbidden not in p, forbidden
assert 'legacy_afgen' in p
assert 'legacy_qdrtab' in p
assert 'd87e21c9603063add7a7440a0aebe6fbac326d03' in p
assert '738f57c334910ab73bc8870e3aa8dda1c1a48c7a' in p
print('FVQ40_INDEPENDENT_ORACLE_STATIC_SEPARATION=PASS')
PY

python3 tests/fvq/test_fvq40_dramet1_remediated_scientific.py

echo 'FVQ40_DRAMET1_REQUALIFICATION_GATE=PASS'
