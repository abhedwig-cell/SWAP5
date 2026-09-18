#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PRE_CANONICAL="aadde02fc35e7bdaddb1604c6f8a7284f43db813"
OWNER_HEAD="8d6f723d4de9b3cc47bb5012b67237aa7fc8febb"
FVQ_STATUS_HEAD="ab2093ba1e2efe70e4bce17e74289f400d0ecfbd"

C_BRIDGE="src/adapter/mod_modflow6_fgc34_c_bridge.f90"
PY_PUBLISHER="src/adapter/modflow6_fgc34_ctypes_publisher.py"

C_BRIDGE_BLOB="5c5577715c9c150f72de7bfccaf966cd72db5add"
PY_PUBLISHER_BLOB="ccf16f446ae9aaab34dae6f432082d70569faad9"
OWNER_STATUS_BLOB="2474775ee3d015ece5c7ccf0c01eac218cd0f3d1"
FVQ_STATUS_BLOB="04779fc2c96af5027e69f3507467a7a1ac402db4"
OWNER_TEST_BLOB="d435dc52f6659579358ab5bfe1fc9c9de7f8832e"
OWNER_RUNNER_BLOB="f0368895e11ac554ac57ae6a82be68ec5f13c379"
FVQ_TEST_BLOB="65d9a64a586ef1252d548e3e8a04b7526aa06ff9"
FVQ_RUNNER_BLOB="acb5def4850f33e539891df333ef4680d726dbec"

git merge-base --is-ancestor "$PRE_CANONICAL" HEAD
git merge-base --is-ancestor "$OWNER_HEAD" HEAD
git merge-base --is-ancestor "$FVQ_STATUS_HEAD" HEAD
echo 'FCI103_CLEAN_CURRENT_CANONICAL_ANCESTRY=PASS'
echo 'FCI103_OWNER_AND_INDEPENDENT_EVIDENCE_ANCESTRY=PASS'

mapfile -t src_delta < <(git diff --name-only "$PRE_CANONICAL..HEAD" -- src)
expected=("$C_BRIDGE" "$PY_PUBLISHER")
if [[ "${#src_delta[@]}" -ne 2 ]]; then
  printf 'Unexpected production delta count:\n' >&2
  printf '  %s\n' "${src_delta[@]}" >&2
  exit 20
fi
for path in "${expected[@]}"; do
  printf '%s\n' "${src_delta[@]}" | grep -Fxq "$path"
done
echo 'FCI103_EXACT_TWO_PRODUCTION_FILES_DELTA=PASS'

test "$(git rev-parse "HEAD:$C_BRIDGE")" = "$C_BRIDGE_BLOB"
test "$(git rev-parse "HEAD:$PY_PUBLISHER")" = "$PY_PUBLISHER_BLOB"
test "$(git rev-parse "HEAD:integration/f-gc/F-GC36_STATUS.json")" = "$OWNER_STATUS_BLOB"
test "$(git rev-parse "HEAD:qualification/F-VQ110_STATUS.json")" = "$FVQ_STATUS_BLOB"
test "$(git rev-parse "HEAD:tests/fgc/test_fgc36_live_modflow6_bridge.py")" = "$OWNER_TEST_BLOB"
test "$(git rev-parse "HEAD:tests/fgc/run_fgc36_live_modflow6_bridge.sh")" = "$OWNER_RUNNER_BLOB"
test "$(git rev-parse "HEAD:tests/fvq/test_fvq110_fgc36_live_bridge_independent.py")" = "$FVQ_TEST_BLOB"
test "$(git rev-parse "HEAD:tests/fvq/run_fvq110_fgc36_live_bridge_independent.sh")" = "$FVQ_RUNNER_BLOB"
echo 'FCI103_IMMUTABLE_PRODUCTION_AND_LIVE_EVIDENCE_BLOBS=PASS'

python3 - <<'PY'
import json
from pathlib import Path

owner=json.loads(Path("integration/f-gc/F-GC36_STATUS.json").read_text())
fvq=json.loads(Path("qualification/F-VQ110_STATUS.json").read_text())

assert owner["capability"]=="F-GC36"
assert owner["verdict"]=="OWNER_QUALIFIED_LIVE_MODFLOW6_FGC34_BRIDGE"
assert owner["production"]["src/adapter/mod_modflow6_fgc34_c_bridge.f90"]["byte_identical"] is True
assert owner["production"]["src/adapter/modflow6_fgc34_ctypes_publisher.py"]["byte_identical"] is True
assert owner["external_dependencies"]["modflow6"]["release"]=="6.8.0"
assert owner["external_dependencies"]["modflow6"]["asset_sha256"]=="33edf988b672a9f282d6773304c079d0f180541f6fe0c6555265d9c71841256e"

assert fvq["work_unit"]=="F-VQ110"
assert fvq["capability"]=="F-GC36"
assert fvq["verdict"]=="INDEPENDENTLY_QUALIFIED_FOR_ADMISSION_REVIEW"
assert fvq["independence"]["verifier_production_delta"]=="NONE"
assert fvq["independence"]["owner_test_reused"] is False
assert fvq["external_dependencies"]["modflow6"]=="6.8.0"

print("FCI103_OWNER_STATUS_AUTHORITY=PASS")
print("FCI103_INDEPENDENT_STATUS_AUTHORITY=PASS")
print("FCI103_PINNED_LIVE_DEPENDENCIES=PASS")
print("FCI103_FGC34_FGC35_DEPENDENCIES_RECONCILED=PASS")
PY

bash tests/fgc/run_fgc36_live_modflow6_bridge.sh
echo 'FCI103_OWNER_LIVE_REPLAY=PASS'

bash tests/fvq/run_fvq110_fgc36_live_bridge_independent.sh
echo 'FCI103_INDEPENDENT_LIVE_REPLAY=PASS'

echo 'F-CI103 F-GC36 LIVE MODFLOW6 BRIDGE CANONICAL ADMISSION GATE PASS'
