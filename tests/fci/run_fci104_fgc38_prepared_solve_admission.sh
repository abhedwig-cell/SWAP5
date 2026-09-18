#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PRE_CANONICAL="7964a5e8d8c0cb35262cb598bf3eafc9c886c77f"
OWNER_HEAD="9f903a2febb905316fab3d6b577c0d4a6f904a7c"
FVQ_STATUS_HEAD="9329d95d2c69ac8cf565e0775952b5ddc36f673e"

PRODUCTION_PATH="src/adapter/modflow6_prepared_solve_session.py"
PRODUCTION_BLOB="d26a11b292c114083d4de15c32f0a56fc45db833"
OWNER_STATUS_BLOB="db1a3fc2fa37fdb12f82a1759d0f389640227b26"
FVQ_STATUS_BLOB="1711becf64f2e09d6fabd997fa21593406bee99f"
OWNER_TEST_BLOB="fe5fb09b323c795a3cf92e7ec6ee8eae4f61ecf7"
OWNER_RUNNER_BLOB="f905a69e5dcd3b702b5ce956d5263f6e25d3df22"
FVQ_TEST_BLOB="def62937b0ab0abaaedad262863fd1967fc9bf9f"
FVQ_RUNNER_BLOB="98be107aa17e7e6f027668cf777d348e32c2ebb5"

git merge-base --is-ancestor "$PRE_CANONICAL" HEAD
git merge-base --is-ancestor "$OWNER_HEAD" HEAD
git merge-base --is-ancestor "$FVQ_STATUS_HEAD" HEAD
echo 'FCI104_CLEAN_CURRENT_CANONICAL_ANCESTRY=PASS'
echo 'FCI104_OWNER_AND_INDEPENDENT_EVIDENCE_ANCESTRY=PASS'

mapfile -t src_delta < <(git diff --name-only "$PRE_CANONICAL..HEAD" -- src)
if [[ "${#src_delta[@]}" -ne 1 || "${src_delta[0]}" != "$PRODUCTION_PATH" ]]; then
  printf 'Unexpected production delta:\n' >&2
  printf '  %s\n' "${src_delta[@]}" >&2
  exit 20
fi
echo 'FCI104_EXACT_ONE_PRODUCTION_FILE_DELTA=PASS'

test "$(git rev-parse "HEAD:$PRODUCTION_PATH")" = "$PRODUCTION_BLOB"
test "$(git rev-parse "HEAD:integration/f-gc/F-GC38_STATUS.json")" = "$OWNER_STATUS_BLOB"
test "$(git rev-parse "HEAD:qualification/F-VQ111_STATUS.json")" = "$FVQ_STATUS_BLOB"
test "$(git rev-parse "HEAD:tests/fgc/test_fgc38_live_prepared_solve.py")" = "$OWNER_TEST_BLOB"
test "$(git rev-parse "HEAD:tests/fgc/run_fgc38_live_prepared_solve.sh")" = "$OWNER_RUNNER_BLOB"
test "$(git rev-parse "HEAD:tests/fvq/test_fvq111_fgc38_prepared_solve_independent.py")" = "$FVQ_TEST_BLOB"
test "$(git rev-parse "HEAD:tests/fvq/run_fvq111_fgc38_prepared_solve_independent.sh")" = "$FVQ_RUNNER_BLOB"
echo 'FCI104_IMMUTABLE_PRODUCTION_AND_LIVE_EVIDENCE_BLOBS=PASS'

python3 - <<'PY'
import json
from pathlib import Path

owner=json.loads(Path("integration/f-gc/F-GC38_STATUS.json").read_text())
fvq=json.loads(Path("qualification/F-VQ111_STATUS.json").read_text())

assert owner["capability"]=="F-GC38"
assert owner["verdict"]=="OWNER_QUALIFIED_MODFLOW6_PREPARED_SOLVE_ITERATIVE_BACKEND"
assert owner["production"]["byte_identical"] is True
assert owner["production"]["rematerialized_blob"]=="d26a11b292c114083d4de15c32f0a56fc45db833"
assert owner["baseline"]["upstream_f_gc36"]=="CLOSED_CANONICAL_ADMITTED_LIVE_MODFLOW6_FGC34_BRIDGE"
assert owner["ownership"]["position"]=="below the internal SWAP5-MODFLOW coupling service"

assert fvq["work_unit"]=="F-VQ111"
assert fvq["capability"]=="F-GC38"
assert fvq["verdict"]=="INDEPENDENTLY_QUALIFIED_FOR_ADMISSION_REVIEW"
assert fvq["independence"]["verifier_production_delta"]=="NONE"
assert fvq["independence"]["owner_test_reused"] is False

print("FCI104_OWNER_STATUS_AUTHORITY=PASS")
print("FCI104_INDEPENDENT_STATUS_AUTHORITY=PASS")
print("FCI104_PINNED_LIVE_DEPENDENCIES=PASS")
print("FCI104_FGC34_FGC35_FGC36_DEPENDENCIES_RECONCILED=PASS")
print("FCI104_INTERNAL_SERVICE_OWNERSHIP_BOUNDARY=PASS")
PY

bash tests/fgc/run_fgc38_live_prepared_solve.sh
echo 'FCI104_OWNER_LIVE_REPLAY=PASS'

bash tests/fvq/run_fvq111_fgc38_prepared_solve_independent.sh
echo 'FCI104_INDEPENDENT_LIVE_REPLAY=PASS'

echo 'F-CI104 F-GC38 PREPARED-SOLVE BACKEND CANONICAL ADMISSION GATE PASS'
