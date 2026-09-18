#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PRE_CANONICAL="1dfdd75345b3c6feb358b521db79bb4a5be1dc1b"
OWNER_HEAD="3d01e4301ef0613b8e5440b1f74b0b9b62123f3d"
FVQ_STATUS_HEAD="6e3b1c74e271aaab6dbfa2d130343f054ffd7c38"
PRODUCTION_PATH="src/runtime/mod_modflow6_linear_response_backend.f90"
PRODUCTION_BLOB="1d3c1af6baab71f63749555339d0c89e8aed4ddf"
OWNER_STATUS_BLOB="88224657ab2152dfab29453a2c30325a16a84664"
FVQ_STATUS_BLOB="80ebce83f6d6d11b0033dc6547d5ab7ac6e6c935"
OWNER_TEST_BLOB="6df9fdd21a2069516ecfb4defc5d618d9009f003"
FVQ_TEST_BLOB="a28a0c6293f8c293ef3ded3b68991555b17fa598"

git merge-base --is-ancestor "$PRE_CANONICAL" HEAD
git merge-base --is-ancestor "$OWNER_HEAD" HEAD
git merge-base --is-ancestor "$FVQ_STATUS_HEAD" HEAD
echo 'FCI100_CLEAN_CURRENT_CANONICAL_ANCESTRY=PASS'
echo 'FCI100_OWNER_AND_INDEPENDENT_EVIDENCE_ANCESTRY=PASS'

mapfile -t src_delta < <(git diff --name-only "$PRE_CANONICAL..HEAD" -- src)
if [[ "${#src_delta[@]}" -ne 1 || "${src_delta[0]}" != "$PRODUCTION_PATH" ]]; then
  printf 'Unexpected production delta:\n' >&2
  printf '  %s\n' "${src_delta[@]}" >&2
  exit 20
fi
echo 'FCI100_EXACT_ONE_PRODUCTION_FILE_DELTA=PASS'

test "$(git rev-parse "HEAD:$PRODUCTION_PATH")" = "$PRODUCTION_BLOB"
test "$(git rev-parse "HEAD:integration/f-gc/F-GC33_STATUS.json")" = "$OWNER_STATUS_BLOB"
test "$(git rev-parse "HEAD:qualification/F-VQ107_STATUS.json")" = "$FVQ_STATUS_BLOB"
test "$(git rev-parse "HEAD:tests/fgc/test_fgc33_modflow6_linear_response_backend.f90")" = "$OWNER_TEST_BLOB"
test "$(git rev-parse "HEAD:tests/fvq/test_fvq107_fgc33_independent.f90")" = "$FVQ_TEST_BLOB"
echo 'FCI100_IMMUTABLE_PRODUCTION_AND_EVIDENCE_BLOBS=PASS'

python3 - <<'PY'
import json
from pathlib import Path
owner=json.loads(Path("integration/f-gc/F-GC33_STATUS.json").read_text())
fvq=json.loads(Path("qualification/F-VQ107_STATUS.json").read_text())

assert owner["capability"]=="F-GC33"
assert owner["verdict"]=="OWNER_QUALIFIED_MODFLOW6_LINEAR_RESPONSE_BACKEND"
assert owner["production"]["byte_identical"] is True
assert owner["production"]["rematerialized_blob"]=="1d3c1af6baab71f63749555339d0c89e8aed4ddf"
assert owner["authority_reconciliation"]["corrected_dependency"]=="F-GC40"

assert fvq["work_unit"]=="F-VQ107"
assert fvq["capability"]=="F-GC33"
assert fvq["verdict"]=="INDEPENDENTLY_QUALIFIED_FOR_ADMISSION_REVIEW"
assert fvq["independence"]["verifier_production_delta"]=="NONE"
assert fvq["independence"]["owner_test_reused"] is False

print("FCI100_OWNER_STATUS_AUTHORITY=PASS")
print("FCI100_INDEPENDENT_STATUS_AUTHORITY=PASS")
print("FCI100_FGC40_DEPENDENCY_RECONCILED=PASS")
PY

bash tests/fgc/run_fgc33_modflow6_linear_response_backend.sh
echo 'FCI100_OWNER_REPLAY=PASS'

bash tests/fvq/run_fvq107_fgc33_independent.sh
echo 'FCI100_INDEPENDENT_REPLAY=PASS'

echo 'F-CI100 F-GC33 CANONICAL ADMISSION GATE PASS'
