#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PRE_CANONICAL="15883938da5777f90f097c8f6938458840ccb75a"
OWNER_HEAD="d678b5953c64be3f3f2056c369fd8b8eb7deab82"
FVQ_STATUS_HEAD="087660e2ff9d890fb7c9bc860328f8e573f56bcc"

OWNER_STATUS_BLOB="9b335bf14909801c910556252c133c06a0bdedc9"
FVQ_STATUS_BLOB="47a8ea46a56acd038903aeb4b832dca52c7e6eea"
HARNESS_BLOB="0ab5cd1d5b701389972ddfcdf7f4ebc7dc198aec"
OWNER_TEST_BLOB="165b640b3183f6b28f1b2fb154ac32a33a86dbaa"
FVQ_TEST_BLOB="502355332d45a26b1474b8935cf6cbd51a184e6f"

git merge-base --is-ancestor "$PRE_CANONICAL" HEAD
git merge-base --is-ancestor "$OWNER_HEAD" HEAD
git merge-base --is-ancestor "$FVQ_STATUS_HEAD" HEAD
echo 'FCI105_CLEAN_CURRENT_CANONICAL_ANCESTRY=PASS'
echo 'FCI105_OWNER_AND_INDEPENDENT_EVIDENCE_ANCESTRY=PASS'

if [[ -n "$(git diff --name-only "$PRE_CANONICAL..HEAD" -- src)" ]]; then
  echo "F-CI105 must be zero-production-delta" >&2
  git diff --name-only "$PRE_CANONICAL..HEAD" -- src >&2
  exit 20
fi
echo 'FCI105_ZERO_PRODUCTION_CODE_DELTA=PASS'

test "$(git rev-parse "HEAD:integration/f-gc/F-GC39_STATUS.json")" = "$OWNER_STATUS_BLOB"
test "$(git rev-parse "HEAD:qualification/F-VQ112_STATUS.json")" = "$FVQ_STATUS_BLOB"
test "$(git rev-parse "HEAD:tests/fgc/support/fgc39_prepared_solve_service_harness.py")" = "$HARNESS_BLOB"
test "$(git rev-parse "HEAD:tests/fgc/test_fgc39_prepared_solve_service_contract.py")" = "$OWNER_TEST_BLOB"
test "$(git rev-parse "HEAD:tests/fvq/test_fvq112_fgc39_independent.py")" = "$FVQ_TEST_BLOB"
echo 'FCI105_IMMUTABLE_CONTRACT_AND_EVIDENCE_BLOBS=PASS'

python3 - <<'PY'
import json
from pathlib import Path

owner=json.loads(Path("integration/f-gc/F-GC39_STATUS.json").read_text())
fvq=json.loads(Path("qualification/F-VQ112_STATUS.json").read_text())

assert owner["capability"]=="F-GC39"
assert owner["verdict"]=="OWNER_QUALIFIED_PREPARED_SOLVE_COUPLING_SERVICE_CONTRACT"
assert owner["artifacts"]["production_delta"]=="NONE"
assert owner["ownership"]["imod_coupler"].startswith("coarse orchestration only")
assert owner["canonical_dependencies"]["f_gc34"].startswith("CLOSED_CANONICAL")
assert owner["canonical_dependencies"]["f_gc35"].startswith("CLOSED_CANONICAL")
assert owner["canonical_dependencies"]["f_gc36"].startswith("CLOSED_CANONICAL")
assert owner["canonical_dependencies"]["f_gc38"].startswith("CLOSED_CANONICAL")

assert fvq["work_unit"]=="F-VQ112"
assert fvq["capability"]=="F-GC39"
assert fvq["verdict"]=="INDEPENDENTLY_QUALIFIED_FOR_ADMISSION_REVIEW"
assert fvq["independence"]["verifier_production_delta"]=="NONE"
assert fvq["independence"]["owner_test_reused"] is False

print("FCI105_OWNER_STATUS_AUTHORITY=PASS")
print("FCI105_INDEPENDENT_STATUS_AUTHORITY=PASS")
print("FCI105_IMOD_OWNERSHIP_BOUNDARY=PASS")
print("FCI105_CANONICAL_PREPARED_SOLVE_STACK=PASS")
PY

bash tests/fgc/run_fgc39_prepared_solve_service_contract.sh
echo 'FCI105_OWNER_REPLAY=PASS'

bash tests/fvq/run_fvq112_fgc39_independent.sh
echo 'FCI105_INDEPENDENT_REPLAY=PASS'

echo 'F-CI105 F-GC39 COUPLING-SERVICE CONTRACT ADMISSION GATE PASS'
