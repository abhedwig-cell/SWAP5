#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
TMP="tests/fvq/.fvq66_independent_v2_${GITHUB_RUN_ID:-local}.sh"
trap 'rm -f "$TMP"' EXIT
python3 - "tests/fvq/run_fvq66_fkt18_independent.sh" "$TMP" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text()
src=src.replace(
"    logical :: initialized, available, did_commit\n    integer :: commit_status\n",
"    logical :: initialized, available, did_commit, time_available\n    integer :: commit_status\n    real(real64) :: committed_time_check\n")
src=src.replace(
"    call require(committed%current_time() == 5.0_real64, 'kernel committed time mutated')\n",
"    call committed%current_time(committed_time_check, time_available)\n    call require(time_available .and. committed_time_check == 5.0_real64, 'kernel committed time mutated')\n")
if "committed%current_time()" in src:
    raise SystemExit("FVQ66_V2_PATCH_FAIL: stale function-style current_time call")
Path(sys.argv[2]).write_text(src)
PY
chmod +x "$TMP"
bash "$TMP"
