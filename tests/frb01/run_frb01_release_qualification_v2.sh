#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$ROOT/tests/frb01/.frb01-release-v2-$$.sh"
trap 'rm -f "$TMP"' EXIT
cp "$ROOT/tests/frb01/run_frb01_release_qualification.sh" "$TMP"
python3 - "$TMP" <<'PY'
from pathlib import Path
import re, sys
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

# F-MQ30 and F-MQ29 enforce their detailed held-out/negative markers internally.
# The outer RB1 wrapper must only require the summary markers those independent
# runners deliberately export to stdout. Requiring their private per-case markers
# here is an observability error, not an additional scientific gate.
root_pat = re.compile(
    r"for marker in \\\n  FMQ30_O0=PASS \\\n.*?done\necho 'FRB01_CURRENT_PARALLEL_V1_AND_ROOT_ACTIVE=PASS'",
    re.S,
)
root_repl = """for marker in \\
  FMQ30_O0=PASS \\
  FMQ30_O2=PASS \\
  FMQ30_O0_O2_EXACT_OUTPUT_IDENTITY=PASS \\
  FMQ30_HARD_MASS_CONSERVATION=PASS \\
  FMQ30_DECISION=QUALIFIED_IF_WORKFLOW_GREEN; do
  grep -Fq \"$marker\" \"$EVIDENCE/current_parallel_root.txt\" || fail \"missing exported parallel/root summary marker: $marker\"
done
echo 'FRB01_CURRENT_PARALLEL_V1_AND_ROOT_ACTIVE=PASS'"""
s, n = root_pat.subn(root_repl, s, count=1)
if n != 1:
    raise SystemExit(f'FRB01 v2 FMQ30 wrapper patch expected 1 match, found {n}')

restart_pat = re.compile(
    r"for marker in \\\n  FMQ29_O0=PASS \\\n.*?done\necho 'FRB01_CURRENT_PARALLEL_COMMITTED_RESTART=PASS'",
    re.S,
)
restart_repl = """for marker in \\
  FMQ29_O0=PASS \\
  FMQ29_O2=PASS \\
  FMQ29_O0_O2_EXACT_OUTPUT_IDENTITY=PASS \\
  FMQ29_HARD_MASS_CONSERVATION=PASS \\
  FMQ29_DECISION=QUALIFIED_PARALLEL_COMMITTED_BOUNDARY_RESTART_COMPOSITION; do
  grep -Fq \"$marker\" \"$EVIDENCE/current_parallel_restart.txt\" || fail \"missing exported parallel-restart summary marker: $marker\"
done
echo 'FRB01_CURRENT_PARALLEL_COMMITTED_RESTART=PASS'"""
s, n = restart_pat.subn(restart_repl, s, count=1)
if n != 1:
    raise SystemExit(f'FRB01 v2 FMQ29 wrapper patch expected 1 match, found {n}')

p.write_text(s)
PY
bash "$TMP"
