#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BASE=3553c63e753bbf714378cd0dff5047769ad3185b

changed_src="$(git diff --name-only "$BASE" -- src)"
[[ -z "$changed_src" ]] || {
  echo 'FPM08C2_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FPM08C2_NO_PRODUCTION_SOURCE_DELTA=PASS'

python3 - <<'PY'
import json
from pathlib import Path
p=json.loads(Path('integration/f-pm/F-PM08C2_DOMAIN_CHARACTERIZATION.json').read_text())
assert p['source_authority']['fpm08c_parent']=='3553c63e753bbf714378cd0dff5047769ad3185b'
assert p['source_authority']['legacy_drainage_file_sha256']=='48e4792acd0a129a6939008bd51e82f9fed4668fcf8d28d03da0bc6efe6944cc'
assert sorted(p['families'])==['IPOS1','IPOS2_3','IPOS4','IPOS5']
assert len(p['recommended_child_split'])==3
assert p['production_implementation_admitted'] is False
assert 'wetper>0' in p['families']['IPOS4']['minimum_uniform_domain']
assert 'geofac>0' in p['families']['IPOS5']['minimum_uniform_domain']
print('FPM08C2_SOURCE_AUTHORITY_LOCKS=PASS')
print('FPM08C2_RESPONSE_FAMILY_SPLIT_EXPLICIT=PASS')
print('FPM08C2_NO_PRODUCTION_ADMISSION=PASS')
PY

python3 tests/fpm/test_fpm08c2_hooghoudt_ernst_domain.py | tee /tmp/fpm08c2-output.txt
for marker in \
  'FPM08C2_IPOS1_STABLE_BRANCH_TANGENT_FD=PASS' \
  'FPM08C2_IPOS2_STABLE_BRANCH_TANGENT_FD=PASS' \
  'FPM08C2_IPOS3_STABLE_BRANCH_TANGENT_FD=PASS' \
  'FPM08C2_IPOS4_STABLE_BRANCH_TANGENT_FD=PASS' \
  'FPM08C2_IPOS5_STABLE_BRANCH_TANGENT_FD=PASS' \
  'FPM08C2_IPOS4_INTERFACE_KINK=PASS' \
  'FPM08C2_EQDEPTH_X1E6_EFFECTIVELY_CONTINUOUS=PASS' \
  'FPM08C2_EQDEPTH_X05_FINITE_BRANCH_JUMP=PASS' \
  'FPM08C2_LEGACY_READER_ADMITS_MATHEMATICALLY_INVALID_EDGE_VALUES=PASS' \
  'FPM08C2_IPOS5_KVBOT_UNUSED_IN_NORMALIZED_FORM=PASS' \
  'FPM08C2_HOOGHOUDT_ERNST_DOMAIN_CHARACTERIZATION PASS'; do
  grep -Fq "$marker" /tmp/fpm08c2-output.txt
done

echo "FPM08C2_CHARACTERIZATION_OUTPUT_SHA256=$(sha256sum /tmp/fpm08c2-output.txt | cut -d' ' -f1)"
echo 'FPM08C2_HOOGHOUDT_ERNST_DOMAIN_GATE PASS'
