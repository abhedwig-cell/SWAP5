#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-multi02-p2mixed-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

for mode in MIXED MIXED_BALANCED; do
  MULTI02_MIXED_MODE="$mode" bash tests/fpe/run_fpe_multi02_p1_semantics.sh | tee "$BUILD/$mode.txt"
done

python3 - "$BUILD" <<'PY'
import sys
from pathlib import Path
root=Path(sys.argv[1])

def read(mode):
    raw={}
    p1={}
    for line in (root/f"{mode}.txt").read_text().splitlines():
        if line.startswith("MULTI02_P0|"):
            d={}
            for q in line.split("|")[1:]:
                k,v=q.split("=",1); d[k]=v
            if int(d["N"])==1000:
                raw[int(d["WORKERS"])]=d
        elif line.startswith("MULTI02_P1|"):
            d={}
            for q in line.split("|")[1:]:
                k,v=q.split("=",1); d[k]=v
            if int(d["N"])==1000:
                p1[int(d["WORKERS"])]=d
    if set(raw)!={1,2,4} or set(p1)!={1,2,4}:
        raise SystemExit(f"missing N1000 rows {mode}")
    return raw,p1

results={}
for mode in ("MIXED","MIXED_BALANCED"):
    raw,p1=read(mode)
    base=float(raw[1]["PARALLEL_SECONDS"])
    for w in (1,2,4):
        sec=float(raw[w]["PARALLEL_SECONDS"])
        speed=base/sec
        ratio=float(p1[w]["WORK_RATIO"])
        results[(mode,w)]=(speed,ratio,sec,p1[w])
        print(f"MULTI02_P2_MIXED|ORDER={mode}|WORKERS={w}|SECONDS={sec:.9f}|SPEEDUP={speed:.6f}"
              f"|EFFICIENCY={speed/w:.6f}|WORK_RATIO={ratio:.6f}"
              f"|W1_NL={p1[w]['W1_NL']}|W2_NL={p1[w]['W2_NL']}|W3_NL={p1[w]['W3_NL']}|W4_NL={p1[w]['W4_NL']}"
              f"|MAX_Q_DIFF={raw[w]['MAX_Q_DIFF']}|MAX_T_DIFF={raw[w]['MAX_T_DIFF']}")
# Semantic identity is already enforced inside each run.
# Classification gate is deliberately not forced to PASS here: an ordering-sensitive
# failure is a valid discriminator result and must be preserved.
for mode in ("MIXED","MIXED_BALANCED"):
    speed,ratio,_,_=results[(mode,4)]
    print(f"MULTI02_P2_CLASSIFY|ORDER={mode}|FOUR_WORKER_SPEED_PASS={str(speed>=2.2).upper()}"
          f"|WORK_BALANCE_PASS={str(ratio<=1.20).upper()}")
print("FPE_MULTI02_P2_MIXED=PASS")
PY
