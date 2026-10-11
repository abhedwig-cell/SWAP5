#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PRE_CANONICAL="7b864853ca22baa73141b2dec9ed2f3915ef520d"
OWNER_HEAD="7993c143eaa1cf8d6580fdd7bde0ae05b07b5b4d"
FVQ_STATUS_HEAD="29829ebb674bd02019c643cc3b2ad21e1c8cfe03"
PRODUCTION_PATH="src/runtime/mod_modflow6_multiswap_cell_response.f90"
PRODUCTION_BLOB="288a274612f6c0be0b3ced149028066a066908ca"
OWNER_STATUS_BLOB="4ff6dfa168d82ffffd351a6acad2dea2c3bc3ae1"
FVQ_STATUS_BLOB="b9d5c19e8c936ff2ea28ca83ffaf7e59a0af4bdc"
OWNER_TEST_BLOB="63dd573354cd6f7845722e13be35b263fd21745c"
FVQ_TEST_BLOB="e5c8f7a29aaa4198d834744f950cc9d43d45045d"

git merge-base --is-ancestor "$PRE_CANONICAL" HEAD
git merge-base --is-ancestor "$OWNER_HEAD" HEAD
git merge-base --is-ancestor "$FVQ_STATUS_HEAD" HEAD
echo 'FCI99_CLEAN_CURRENT_CANONICAL_ANCESTRY=PASS'
echo 'FCI99_OWNER_AND_INDEPENDENT_EVIDENCE_ANCESTRY=PASS'

mapfile -t src_delta < <(git diff --name-only "$PRE_CANONICAL..HEAD" -- src)
if [[ "${#src_delta[@]}" -ne 1 || "${src_delta[0]}" != "$PRODUCTION_PATH" ]]; then
  printf 'Unexpected production delta:\n' >&2
  printf '  %s\n' "${src_delta[@]}" >&2
  exit 20
fi
echo 'FCI99_EXACT_ONE_PRODUCTION_FILE_DELTA=PASS'

test "$(git rev-parse "HEAD:$PRODUCTION_PATH")" = "$PRODUCTION_BLOB"
test "$(git rev-parse "HEAD:integration/f-gc/F-GC40_STATUS.json")" = "$OWNER_STATUS_BLOB"
test "$(git rev-parse "HEAD:qualification/F-VQ106_STATUS.json")" = "$FVQ_STATUS_BLOB"
test "$(git rev-parse "HEAD:tests/fgc/test_fgc40_modflow6_multiswap_cell_response.f90")" = "$OWNER_TEST_BLOB"
test "$(git rev-parse "HEAD:tests/fvq/test_fvq106_fgc40_independent.f90")" = "$FVQ_TEST_BLOB"
echo 'FCI99_IMMUTABLE_PRODUCTION_AND_EVIDENCE_BLOBS=PASS'

python3 - <<'PY'
import json
from pathlib import Path

owner = json.loads(Path("integration/f-gc/F-GC40_STATUS.json").read_text())
fvq = json.loads(Path("qualification/F-VQ106_STATUS.json").read_text())

assert owner["capability"] == "F-GC40"
assert owner["verdict"] == "OWNER_QUALIFIED_TYPED_MULTISWAP_AFFINE_CELL_RESPONSE"
assert owner["production"]["byte_identical"] is True
assert owner["production"]["reidentified_blob"] == "288a274612f6c0be0b3ced149028066a066908ca"

assert fvq["work_unit"] == "F-VQ106"
assert fvq["capability"] == "F-GC40"
assert fvq["verdict"] == "INDEPENDENTLY_QUALIFIED_FOR_ADMISSION_REVIEW"
assert fvq["independence"]["verifier_production_delta"] == "NONE"
assert fvq["independence"]["owner_test_reused"] is False

print("FCI99_OWNER_STATUS_AUTHORITY=PASS")
print("FCI99_INDEPENDENT_STATUS_AUTHORITY=PASS")
print("FCI99_IDENTITY_COLLISION_CORRECTED=PASS")
PY

bash tests/fgc/run_fgc40_modflow6_multiswap_cell_response.sh
echo 'FCI99_OWNER_REPLAY=PASS'

bash tests/fvq/run_fvq106_fgc40_independent.sh
echo 'FCI99_INDEPENDENT_REPLAY=PASS'

echo 'F-CI99 F-GC40 CANONICAL ADMISSION GATE PASS'
