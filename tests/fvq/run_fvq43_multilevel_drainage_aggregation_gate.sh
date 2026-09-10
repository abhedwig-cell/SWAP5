#!/usr/bin/env bash
set -euo pipefail

BASE=b982d4d0c8686e5c5fcb965633d34a4e0ba46fcf
changed="$(git diff --name-only "${BASE}...HEAD")"
if printf '%s\n' "$changed" | grep -Eq '^(src/|reference/)'; then
  echo 'FVQ43_NO_PRODUCTION_OR_REFERENCE_DELTA=FAIL'
  printf '%s\n' "$changed"
  exit 1
fi
echo 'FVQ43_NO_PRODUCTION_OR_REFERENCE_DELTA=PASS'

python3 - <<'PY'
from pathlib import Path
p = Path('tests/fvq/test_fvq43_multilevel_drainage_aggregation.py').read_text()
for forbidden in [
    'tests/fpm/',
    'F-PM08C4_CANDIDATE_EVIDENCE',
    'F-PM08C4_INVARIANT_AUDIT',
    'F-PM08C4_CANDIDATE_CONTRACT'
]:
    assert forbidden not in p, forbidden
for required in [
    '61dc2ee0e5e2344a855e429e8e3d49a04ffe007e',
    '70d35512ef7c5958f7e4bf284cba104a7b641fdb',
    '48e4792acd0a129a6939008bd51e82f9fed4668fcf8d28d03da0bc6efe6944cc',
    'sequential_sum',
    'make_legacy_cases',
    'scalability_extension_is_not_legacy_equivalence'
]:
    assert required in p, required
print('FVQ43_INDEPENDENT_ORACLE_STATIC_SEPARATION=PASS')
PY

python3 tests/fvq/test_fvq43_multilevel_drainage_aggregation.py

echo 'FVQ43_MULTILEVEL_DRAINAGE_AGGREGATION_GATE=PASS'
