#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BASE=3ce245e3cac068268bdff2f0af0fdcdf022c82aa

changed_src="$(git diff --name-only "$BASE" -- src)"
[[ -z "$changed_src" ]] || {
  echo 'FPM08C_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FPM08C_NO_PRODUCTION_SOURCE_DELTA=PASS'

python3 - <<'PY'
import json
from pathlib import Path
p=json.loads(Path('integration/f-pm/F-PM08C_RESPONSE_SENSITIVITY_CHARACTERIZATION.json').read_text())
assert p['source_authority']['legacy_drainage_sha256']=='48e4792acd0a129a6939008bd51e82f9fed4668fcf8d28d03da0bc6efe6944cc'
assert p['source_authority']['legacy_functions_sha256']=='b32dee127747e619cb92965d0473173ec7fd93c56128a0dbd5ebf5942c300527'
assert p['families']['DRAMET3_INTERFLOW']['input_range']['expintfl']==[0.1,1.0]
assert p['production_implementation_admitted_by_this_artifact'] is False
assert len(p['recommended_child_split'])==4
print('FPM08C_SOURCE_AUTHORITY_LOCKS=PASS')
print('FPM08C_FOUR_RESPONSE_CLASSES_EXPLICIT=PASS')
print('FPM08C_NO_PRODUCTION_ADMISSION=PASS')
PY

python3 tests/fpm/test_fpm08c_response_sensitivity.py | tee /tmp/fpm08c-output.txt
for marker in \
  'FPM08C_DRAMET1_PIECEWISE_LINEAR_SENSITIVITY=PASS' \
  'FPM08C_DRAMET1_KNOT_NONSMOOTHNESS=PASS' \
  'FPM08C_DRAMET2_IPOS1_ANALYTIC_TANGENT_FD=PASS' \
  'FPM08C_DRAMET2_IPOS2_ANALYTIC_TANGENT_FD=PASS' \
  'FPM08C_DRAMET2_IPOS3_ANALYTIC_TANGENT_FD=PASS' \
  'FPM08C_DRAMET2_IPOS4_ANALYTIC_TANGENT_FD=PASS' \
  'FPM08C_DRAMET2_IPOS5_ANALYTIC_TANGENT_FD=PASS' \
  'FPM08C_DRAMET2_IPOS4_INTERFACE_KINK=PASS' \
  'FPM08C_DRAMET2_SMALL_CUTOFF_BRANCH=PASS' \
  'FPM08C_DRAMET2_EXACT_CUTOFF_REPRESENTATION_SENSITIVE=PASS' \
  'FPM08C_INTERFLOW_ACTIVE_TANGENT_FD=PASS' \
  'FPM08C_INTERFLOW_SUBLINEAR_ACTIVATION_TANGENT_DIVERGES=PASS' \
  'FPM08C_MULTILEVEL_STABLE_BRANCH_DERIVATIVE_SUM=PASS' \
  'FPM08C_RESPONSE_SENSITIVITY_CHARACTERIZATION PASS'; do
  grep -Fq "$marker" /tmp/fpm08c-output.txt
done

echo "FPM08C_CHARACTERIZATION_OUTPUT_SHA256=$(sha256sum /tmp/fpm08c-output.txt | cut -d' ' -f1)"
echo 'FPM08C_RESPONSE_SENSITIVITY_GATE PASS'
