#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PRE_CANONICAL="0372b44157747dc90fa690810f57e373e670373b"
OWNER_HEAD="2bc4ccb1cbedde8af60cd8390799373ed4310cb1"
FVQ_STATUS_HEAD="db4d82d28c5e954ff35f396724d751d1d6f00e8e"
PRODUCTION_PATH="src/runtime/mod_modflow6_api_binding.f90"
PRODUCTION_BLOB="780ed4bf3a8bdf067db40f4aedd800832144eca6"
OWNER_STATUS_BLOB="bde7290db300dd7368fde0e9be07835981886bc0"
FVQ_STATUS_BLOB="70d808df2694bbcc160f787cc71ef5eb2daca303"
OWNER_TEST_BLOB="ad1941bfe81fadc520cc0eaa09c104f46b3827a2"
FVQ_TEST_BLOB="97e4539484d7506cd8f47bbe6b75c424e406348b"

git merge-base --is-ancestor "$PRE_CANONICAL" HEAD
git merge-base --is-ancestor "$OWNER_HEAD" HEAD
git merge-base --is-ancestor "$FVQ_STATUS_HEAD" HEAD
echo 'FCI101_CLEAN_CURRENT_CANONICAL_ANCESTRY=PASS'
echo 'FCI101_OWNER_AND_INDEPENDENT_EVIDENCE_ANCESTRY=PASS'

mapfile -t src_delta < <(git diff --name-only "$PRE_CANONICAL..HEAD" -- src)
if [[ "${#src_delta[@]}" -ne 1 || "${src_delta[0]}" != "$PRODUCTION_PATH" ]]; then
  printf 'Unexpected production delta:\n' >&2
  printf '  %s\n' "${src_delta[@]}" >&2
  exit 20
fi
echo 'FCI101_EXACT_ONE_PRODUCTION_FILE_DELTA=PASS'

test "$(git rev-parse "HEAD:$PRODUCTION_PATH")" = "$PRODUCTION_BLOB"
test "$(git rev-parse "HEAD:integration/f-gc/F-GC34_STATUS.json")" = "$OWNER_STATUS_BLOB"
test "$(git rev-parse "HEAD:qualification/F-VQ108_STATUS.json")" = "$FVQ_STATUS_BLOB"
test "$(git rev-parse "HEAD:tests/fgc/test_fgc34_modflow6_api_binding.f90")" = "$OWNER_TEST_BLOB"
test "$(git rev-parse "HEAD:tests/fvq/test_fvq108_fgc34_independent.f90")" = "$FVQ_TEST_BLOB"
echo 'FCI101_IMMUTABLE_PRODUCTION_AND_EVIDENCE_BLOBS=PASS'

python3 - <<'PY'
import json
from pathlib import Path
owner=json.loads(Path("integration/f-gc/F-GC34_STATUS.json").read_text())
fvq=json.loads(Path("qualification/F-VQ108_STATUS.json").read_text())
assert owner["capability"]=="F-GC34"
assert owner["verdict"]=="OWNER_QUALIFIED_MODFLOW6_TYPED_API_BINDING"
assert owner["production"]["byte_identical"] is True
assert owner["production"]["rematerialized_blob"]=="780ed4bf3a8bdf067db40f4aedd800832144eca6"
assert owner["authority_reconciliation"]["canonical_f_gc33"].startswith("MODFLOW6 Linear Response Backend")
assert fvq["work_unit"]=="F-VQ108"
assert fvq["capability"]=="F-GC34"
assert fvq["verdict"]=="INDEPENDENTLY_QUALIFIED_FOR_ADMISSION_REVIEW"
assert fvq["independence"]["verifier_production_delta"]=="NONE"
assert fvq["independence"]["owner_test_reused"] is False
print("FCI101_OWNER_STATUS_AUTHORITY=PASS")
print("FCI101_INDEPENDENT_STATUS_AUTHORITY=PASS")
print("FCI101_FGC33_DEPENDENCY_RECONCILED=PASS")
PY

bash tests/fgc/run_fgc34_modflow6_api_binding.sh
echo 'FCI101_OWNER_REPLAY=PASS'

bash tests/fvq/run_fvq108_fgc34_independent.sh
echo 'FCI101_INDEPENDENT_REPLAY=PASS'

echo 'F-CI101 F-GC34 CANONICAL ADMISSION GATE PASS'
