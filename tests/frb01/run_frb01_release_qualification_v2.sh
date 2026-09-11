#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$ROOT/tests/frb01/.frb01-release-v2-$$.sh"
trap 'rm -f "$TMP"' EXIT
cp "$ROOT/tests/frb01/run_frb01_release_qualification.sh" "$TMP"
python3 - "$TMP" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
repl={
    "'FCI11_GATE PASS'":"FCI11_GATE_PASS",
    "'FCI12_GATE PASS'":"FCI12_GATE_PASS",
    "'FCI13_GATE PASS'":"FCI13_GATE_PASS",
    "'FCI14_GATE PASS'":"FCI14_GATE_PASS",
    "FCI28_PROCESS_RESTART_O0_O2_IDENTITY=PASS":"FCI28_O0_O2_OUTPUT_IDENTITY=PASS",
    "git merge-base --is-ancestor \"$CANDIDATE\" \"$RB1_SOURCE_SHA\" || fail 'root-active candidate not in RB1 source lineage'":"git merge-base --is-ancestor 85e17bb7ca26d2df070f99b2bf16ecf0abebec19 \"$RB1_SOURCE_SHA\" || fail 'final F-CI37 authority not in RB1 source lineage'",
}
for old,new in repl.items():
    if old not in s:
        raise SystemExit(f'FRB01 v2 patch token missing: {old}')
    s=s.replace(old,new,1)
p.write_text(s)
PY
bash "$TMP"
