#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PRE_CANONICAL="7d335dbbfd16407aca235ccf41a6c70534a1c4df"
OWNER_HEAD="7d64f9e1fd48b512f3dee2c0ea3d645804310812"
FVQ_STATUS_HEAD="9ecd770f4a8b9ddf639d9f917c567927721cb111"
PRODUCTION_PATH="src/adapter/modflow6_xmi_package_adapter.py"
PRODUCTION_BLOB="cf127a6fc17d895ced04bf1a013ca53e6aa3a713"
OWNER_STATUS_BLOB="0bead6f34e41ea9b8db5ca35aa8c0981a338d6e7"
FVQ_STATUS_BLOB="80c8ab46cd026a8a9e4fe9a162a6949f69718f12"
OWNER_TEST_BLOB="e234dd18767df7cb368989ac10b7fefc3a173160"
FVQ_TEST_BLOB="ffda6cd3de69603bb7d79f7c0afbb56fcd83f869"

git merge-base --is-ancestor "$PRE_CANONICAL" HEAD
git merge-base --is-ancestor "$OWNER_HEAD" HEAD
git merge-base --is-ancestor "$FVQ_STATUS_HEAD" HEAD
echo 'FCI102_CLEAN_CURRENT_CANONICAL_ANCESTRY=PASS'
echo 'FCI102_OWNER_AND_INDEPENDENT_EVIDENCE_ANCESTRY=PASS'

mapfile -t src_delta < <(git diff --name-only "$PRE_CANONICAL..HEAD" -- src)
if [[ "${#src_delta[@]}" -ne 1 || "${src_delta[0]}" != "$PRODUCTION_PATH" ]]; then
  printf 'Unexpected production delta:\n' >&2
  printf '  %s\n' "${src_delta[@]}" >&2
  exit 20
fi
echo 'FCI102_EXACT_ONE_PRODUCTION_FILE_DELTA=PASS'

test "$(git rev-parse "HEAD:$PRODUCTION_PATH")" = "$PRODUCTION_BLOB"
test "$(git rev-parse "HEAD:integration/f-gc/F-GC35_STATUS.json")" = "$OWNER_STATUS_BLOB"
test "$(git rev-parse "HEAD:qualification/F-VQ109_STATUS.json")" = "$FVQ_STATUS_BLOB"
test "$(git rev-parse "HEAD:tests/fgc/test_fgc35_modflow6_xmi_package_adapter.py")" = "$OWNER_TEST_BLOB"
test "$(git rev-parse "HEAD:tests/fvq/test_fvq109_fgc35_xmi_adapter_independent.py")" = "$FVQ_TEST_BLOB"
echo 'FCI102_IMMUTABLE_PRODUCTION_AND_EVIDENCE_BLOBS=PASS'

python3 - <<'PY'
import json
from pathlib import Path
owner=json.loads(Path("integration/f-gc/F-GC35_STATUS.json").read_text())
fvq=json.loads(Path("qualification/F-VQ109_STATUS.json").read_text())
assert owner["capability"]=="F-GC35"
assert owner["verdict"]=="OWNER_QUALIFIED_XMI_PACKAGE_ADAPTER_CONTRACT"
assert owner["production"]["byte_identical"] is True
assert owner["production"]["rematerialized_blob"]=="cf127a6fc17d895ced04bf1a013ca53e6aa3a713"
assert owner["authority_reconciliation"]["canonical_f_gc34"].startswith("MODFLOW6 Typed API Binding")
assert fvq["work_unit"]=="F-VQ109"
assert fvq["capability"]=="F-GC35"
assert fvq["verdict"]=="INDEPENDENTLY_QUALIFIED_FOR_ADMISSION_REVIEW"
assert fvq["independence"]["verifier_production_delta"]=="NONE"
assert fvq["independence"]["owner_test_reused"] is False
print("FCI102_OWNER_STATUS_AUTHORITY=PASS")
print("FCI102_INDEPENDENT_STATUS_AUTHORITY=PASS")
print("FCI102_FGC34_DEPENDENCY_RECONCILED=PASS")
PY

bash tests/fgc/run_fgc35_modflow6_xmi_package_adapter.sh
echo 'FCI102_OWNER_REPLAY=PASS'

bash tests/fvq/run_fvq109_fgc35_xmi_adapter_independent.sh
echo 'FCI102_INDEPENDENT_REPLAY=PASS'

echo 'F-CI102 F-GC35 CANONICAL ADMISSION GATE PASS'
