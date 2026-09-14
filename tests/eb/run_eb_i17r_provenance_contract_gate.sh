#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BASE=b9517b136bc879c01ad1019a8f0e2e0be72370b6
CONTRACT=tests/eb/EB-I17R_PROVENANCE_CONTRACT.md
STATUS=tests/eb/EB-I17R_STATUS.json
AUDIT=tests/eb/EB-I17R_ARCHITECTURE_AUDIT.json
fail(){ echo "EB_I17R_GATE_FAIL $*" >&2; exit 117; }

[[ -f "$CONTRACT" && -f "$STATUS" && -f "$AUDIT" ]] || fail 'required evidence missing'
grep -Fq 'F-VQ70' "$CONTRACT" || fail 'negative F-VQ70 evidence not reconciled'
grep -Fq 'F-PM12' "$CONTRACT" || fail 'F-PM12 candidate-bound authority not reconciled'
grep -Fq 'F-VQ72' "$CONTRACT" || fail 'F-VQ72 independent authority not reconciled'
grep -Fq 'SHALL NOT rely on a caller-created identity token' "$CONTRACT" || fail 'caller-token nonauthority rule missing'
grep -Fq 'the same kernel candidate object' "$CONTRACT" || fail 'same-candidate procedural rule missing'
grep -Fq 'SHALL NOT retroactively reject or roll back' "$CONTRACT" || fail 'optional-energy hydrology rule missing'
grep -Fq 'no public API may accept an independently supplied prepared energy result plus an independently supplied commit receipt' "$CONTRACT" || fail 'public pairing prohibition missing'

python3 - <<'PY'
import json
from pathlib import Path
s=json.loads(Path('tests/eb/EB-I17R_STATUS.json').read_text())
assert s['decision']=='DESIGN_FROZEN_PROCEDURAL_CANDIDATE_BINDING_REQUIRED'
assert s['production_change'] is False
assert s['findings']['f_vq70_independent_qualification'].startswith('NEGATIVE_')
assert s['findings']['f_kt20_production_authority'] is False
assert s['findings']['f_pm12_f_vq72_candidate_bound_procedural_pattern']=='INDEPENDENTLY_QUALIFIED'
a=json.loads(Path('tests/eb/EB-I17R_ARCHITECTURE_AUDIT.json').read_text())
ids=[x['id'] for x in a['invariants']]
assert ids==list(range(1,31)), ids
assert all(x['status'] in ('PASS','PRESERVED') for x in a['invariants'])
print('EB_I17R_JSON_EVIDENCE=PASS')
PY

# Design-only remediation. Production and reference source must be byte-identical to qualified EB-I17 base.
git diff --quiet "$BASE"..HEAD -- src reference || fail 'production/reference source changed in design-only remediation'
changed="$(git diff --name-only "$BASE"..HEAD)"
while IFS= read -r p; do
  [[ -z "$p" ]] && continue
  case "$p" in
    tests/eb/EB-I17R_PROVENANCE_CONTRACT.md|tests/eb/EB-I17R_STATUS.json|tests/eb/EB-I17R_ARCHITECTURE_AUDIT.json|tests/eb/run_eb_i17r_provenance_contract_gate.sh|.github/workflows/eb-i17r-provenance-contract.yml) ;;
    *) fail "path outside exact design scope: $p" ;;
  esac
done <<< "$changed"

git diff --check "$BASE"..HEAD
echo 'EB_I17R_NO_PRODUCTION_CHANGE=PASS'
echo 'EB_I17R_ALL_30_INVARIANTS=PASS'
echo 'EB_I17R_FKT20_NONADMISSIBLE_ROUTE_EXCLUDED=PASS'
echo 'EB_I17R_FPM12_FVQ72_PATTERN_SELECTED=PASS'
echo 'EB_I17R_PROVENANCE_CONTRACT_GATE PASS'
