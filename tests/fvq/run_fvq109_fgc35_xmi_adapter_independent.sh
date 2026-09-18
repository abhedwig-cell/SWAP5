#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

OWNER_HEAD="7d64f9e1fd48b512f3dee2c0ea3d645804310812"
PRODUCTION_PATH="src/adapter/modflow6_xmi_package_adapter.py"
PRODUCTION_BLOB="cf127a6fc17d895ced04bf1a013ca53e6aa3a713"

test "$(git rev-parse "HEAD:$PRODUCTION_PATH")" = "$PRODUCTION_BLOB"
test "$(git rev-parse "$OWNER_HEAD:$PRODUCTION_PATH")" = "$PRODUCTION_BLOB"
test -z "$(git diff --name-only "$OWNER_HEAD..HEAD" -- src)"
echo 'FVQ109_VERIFIER_PRODUCTION_DELTA_NONE=PASS'
echo 'FVQ109_OWNER_PRODUCTION_BLOB_LOCK=PASS'

python3 - <<'PY'
from pathlib import Path
v=Path("tests/fvq/test_fvq109_fgc35_xmi_adapter_independent.py").read_text()
assert "test_fgc35_modflow6_xmi_package_adapter" not in v
assert "lifecycle_generation_oracle" in v
assert "failure_state_oracle" in v
print("FVQ109_OWNER_TEST_NOT_REUSED=PASS")
print("FVQ109_INDEPENDENT_ORACLE_STRUCTURE=PASS")
PY

python3 tests/fvq/test_fvq109_fgc35_xmi_adapter_independent.py
echo 'F-VQ109 F-GC35 INDEPENDENT QUALIFICATION PASS'
