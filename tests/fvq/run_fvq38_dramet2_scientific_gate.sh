#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BASE=3e21bffdf8e8c354c336d0b4898fdf77db320bf1

protected_delta="$(git diff --name-only "$BASE" -- src reference)"
if [[ -n "$protected_delta" ]]; then
  echo 'FVQ38_QUALIFICATION_BRANCH_MODIFIES_PRODUCTION_OR_REFERENCE' >&2
  printf '%s\n' "$protected_delta" >&2
  exit 1
fi
echo 'FVQ38_NO_PRODUCTION_OR_REFERENCE_DELTA=PASS'

python3 - <<'PY'
import json
from pathlib import Path
contract=json.loads(Path('integration/f-vq/F-VQ38_QUALIFICATION_CONTRACT.json').read_text())
assert contract['clean_base']=='3e21bffdf8e8c354c336d0b4898fdf77db320bf1'
assert contract['candidate_closeouts']['F-PM08C2A']=='5417799834775293fd459cd3f7ba5be3d3e5723e'
assert contract['candidate_closeouts']['F-PM08C2B']=='4f1ff62ce6bf0b391760acb3b4677e475931c4e8'
assert contract['candidate_closeouts']['F-PM08C2C']=='e92807165e674b48600e8ec2ae132d1dfc85a798'
assert contract['legacy_authority']['drainage_f90_sha256']=='48e4792acd0a129a6939008bd51e82f9fed4668fcf8d28d03da0bc6efe6944cc'
text=Path('tests/fvq/test_fvq38_dramet2_scientific.py').read_text()
for forbidden in [
    'tests/fpm/test_fpm08c2a',
    'tests/fpm/test_fpm08c2b',
    'tests/fpm/test_fpm08c2c',
    'run_fpm08c2a', 'run_fpm08c2b', 'run_fpm08c2c'
]:
    assert forbidden not in text, forbidden
assert 'git_show' in text and 'eqdepth_oracle' in text and 'oracle_fd' in text
print('FVQ38_INDEPENDENT_ORACLE_STATIC_SEPARATION=PASS')
PY

python3 tests/fvq/test_fvq38_dramet2_scientific.py | tee /tmp/fvq38.out
for marker in \
  'FVQ38_FROZEN_DRAINAGE_SOURCE_IDENTITY=PASS' \
  'FVQ38_CANDIDATE_CLOSEOUT_BLOB_IDENTITY=PASS' \
  'FVQ38_CANDIDATE_O0_O2_OUTPUT_IDENTITY=PASS' \
  'FVQ38_IPOS1_TO_5_INDEPENDENT_FLUX_ORACLE=PASS' \
  'FVQ38_EQDEPTH_ALL_THREE_BRANCHES=PASS' \
  'FVQ38_IPOS4_INTERFACE_DERIVATIVE_SEMANTICS=PASS' \
  'FVQ38_NEGATIVE_RADIAL_RESISTANCE_PARITY=PASS' \
  'FVQ38_B110_CUTOFF_SIDEDNESS_ALL_IPOS=PASS' \
  'FVQ38_RESPONSE_TANGENTS_VS_INDEPENDENT_ORACLE_FD=PASS' \
  'FVQ38_DRAMET2_SCIENTIFIC_EQUIVALENCE PASS'; do
  grep -Fq "$marker" /tmp/fvq38.out
done

echo 'FVQ38_DRAMET2_SCIENTIFIC_GATE PASS'
