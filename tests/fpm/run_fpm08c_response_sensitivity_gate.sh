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

changed_ref="$(git diff --name-only "$BASE" -- reference)"
[[ -z "$changed_ref" ]] || {
  echo 'FPM08C_UNEXPECTED_REFERENCE_DELTA' >&2
  printf '%s\n' "$changed_ref" >&2
  exit 1
}
echo 'FPM08C_NO_REFERENCE_SOURCE_DELTA=PASS'

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

r=json.loads(Path('integration/f-pm/F-PM08C_CHILD_COMPLETION_RECONCILIATION.json').read_text())
assert r['parent_decomposition_closeout']=='3553c63e753bbf714378cd0dff5047769ad3185b'
assert len(r['children'])==4
assert r['scope_reconciliation']['all_four_required_children_completed'] is True
assert r['scope_reconciliation']['negative_side_DRAMET3_infiltration_qualified'] is False
assert r['scope_reconciliation']['production_family_composition_qualified'] is False
assert r['scope_reconciliation']['runtime_binding_qualified'] is False
assert r['scope_reconciliation']['canonical_admission_qualified'] is False
assert r['decision']=='QUALIFIED_FPM08C_REQUIRED_CHILD_SET_COMPLETE_WITH_EXPLICIT_NEGATIVE_DRAMET3_AND_RUNTIME_HOLDS'
print('FPM08C_CHILD_COMPLETION_SCOPE_RECONCILIATION=PASS')
print('FPM08C_NEGATIVE_DRAMET3_HOLD_EXPLICIT=PASS')
print('FPM08C_COORDINATION_ONLY_CLOSEOUT=PASS')
PY

for authority in \
  f5f567c6af4879bf80107a7579dd342de6d5afe0 \
  49728b999b884a37643908c1dad40269f4e2db9b \
  702db051bf5dd0960a962be919ea0cfbf01895a4 \
  3542ff83f38a9dd8de407ceca65ed968407559f5; do
  git cat-file -e "$authority^{commit}"
done

git show f5f567c6af4879bf80107a7579dd342de6d5afe0:integration/f-vq/F-VQ40_STATUS.json | \
  grep -Fq 'QUALIFIED_DRAMET1_TABULATED_RESPONSE_SCIENTIFIC_EQUIVALENCE_WITH_EXPLICIT_FAIL_CLOSED_LEGACY_DEGENERATE'
git show 49728b999b884a37643908c1dad40269f4e2db9b:integration/f-vq/F-VQ38_STATUS.json | \
  grep -Fq 'QUALIFIED_DRAMET2_IPOS1_TO_5_RESPONSE_FAMILY_SCIENTIFIC_EQUIVALENCE_WITHIN_NORMALIZED_VALID_DOMAIN'
git show 702db051bf5dd0960a962be919ea0cfbf01895a4:integration/f-vq/F-VQ42_STATUS.json | \
  grep -Fq 'QUALIFIED_EMPIRICAL_INTERFLOW_DRAINAGE_SIDE_RESPONSE_AND_SENSITIVITY_WITH_EXPLICIT_ACTIVATION_SINGULARITY'
git show 3542ff83f38a9dd8de407ceca65ed968407559f5:integration/f-vq/F-VQ43_STATUS.json | \
  grep -Fq 'QUALIFIED_MULTILEVEL_DRAINAGE_AGGREGATION_LEGACY_ORDER_EQUIVALENCE_AND_CONSERVATIVE_SENSITIVITY_COMPOSITION'
echo 'FPM08C_FOUR_INDEPENDENT_CHILD_AUTHORITIES_LOCKED=PASS'

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
