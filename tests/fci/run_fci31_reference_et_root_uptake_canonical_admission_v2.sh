#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SOURCE="$ROOT/tests/fci/run_fci31_reference_et_root_uptake_canonical_admission.sh"
TMP="$ROOT/tests/fci/.fci31-admission-v2-${GITHUB_RUN_ID:-$$}-${GITHUB_RUN_ATTEMPT:-0}.sh"
REPLAY="$ROOT/tests/fci/.fci31-fci30-preservation-${GITHUB_RUN_ID:-$$}-${GITHUB_RUN_ATTEMPT:-0}.sh"

cleanup_wrapper() {
  rm -f "$TMP" "$REPLAY"
}
trap cleanup_wrapper EXIT

cp "$SOURCE" "$TMP"
python3 - "$TMP" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text(encoding='utf-8')
old='FCI30_REPLAY="$BUILD/fci30-preservation.sh"'
new='FCI30_REPLAY="${FCI31_REPLAY_PATH:?}"'
if s.count(old) != 1:
    raise SystemExit(f'FCI31 V2 replay-path anchor count={s.count(old)}')
s=s.replace(old,new,1)
p.write_text(s,encoding='utf-8')
PY

export FCI31_REPLAY_PATH="$REPLAY"
echo 'FCI31_NESTED_FCI30_REPLAY_PATH_HARDENED=PASS'
bash "$TMP"
