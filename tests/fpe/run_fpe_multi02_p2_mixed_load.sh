#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-multi02-p2-mixed-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

for mode in MIXED MIXED_BALANCED; do
  MULTI02_MIXED_MODE="$mode" bash tests/fpe/run_fpe_multi02_p1_semantics.sh | tee "$BUILD/$mode.txt"
done

python3 - "$BUILD" <<'PY'
import statistics,sys
from pathlib import Path
root=Path(sys.argv[1])

def parse(mode):
    rows={}
    workers={}
    for line in (root/f"{mode}.txt").read_text().splitlines():
        if line.startswith("MULTI02_P0|"):
            d={}
            for p in line.split("|")[1:]:
                k,v=p.split("=",1); d[k]=v
            if int(d["N"])==1000:
                rows[int(d["WORKERS"])]=d
        elif line.startswith("MULTI02_WORKER|"):
            d={}
            for p in line.split("|")[1:]:
                k,v=p.split("=",1); d[k]=v
            if int(d["N"])==1000:
                workers[(int(d["WORKERS"]),int(d["WORKER"]))]=d
    if set(rows)!={1,2,4}: raise SystemExit(f"{mode}: missing N=1000 rows {rows.keys()}")
    return rows,workers

for mode in ("MIXED","MIXED_BALANCED"):
    rows,wrk=parse(mode)
    base=float(rows[1]["PARALLEL_SECONDS"])
    for w in (1,2,4):
        r=rows[w]
        t=float(r["PARALLEL_SECONDS"])
        speed=base/t
        per=[wrk[(w,i)] for i in range(1,w+1)]
        attempts=[int(x["ATTEMPTS"]) for x in per]
        nonlinear=[int(x["NONLINEAR"]) for x in per]
        backtrack=[int(x["BACKTRACK"]) for x in per]
        ratio=max(nonlinear)/(sum(nonlinear)/len(nonlinear)) if sum(nonlinear) else 1.0
        print(
          f"MULTI02_P2_MIXED|MODE={mode}|WORKERS={w}|SECONDS={t:.9f}|SPEEDUP={speed:.6f}"
          f"|EFFICIENCY={speed/w:.6f}|MAX_MEAN_NONLINEAR={ratio:.6f}"
          f"|WORKER_ATTEMPTS={','.join(map(str,attempts))}"
          f"|WORKER_NONLINEAR={','.join(map(str,nonlinear))}"
          f"|WORKER_BACKTRACK={','.join(map(str,backtrack))}"
          f"|MAX_Q_DIFF={r['MAX_Q_DIFF']}|MAX_T_DIFF={r['MAX_T_DIFF']}"
        )
    r4=rows[4]
    p4=[wrk[(4,i)] for i in range(1,5)]
    nlit=[int(x["NONLINEAR"]) for x in p4]
    load=max(nlit)/(sum(nlit)/4) if sum(nlit) else 1.0
    speed4=base/float(r4["PARALLEL_SECONDS"])
    if float(r4["MAX_Q_DIFF"]) != 0.0 or float(r4["MAX_T_DIFF"]) != 0.0:
        raise SystemExit(f"{mode}: semantic drift")
    # P2 preregistration decision is not forced here; report both gates explicitly.
    print(f"MULTI02_P2_DECISION_INPUT|MODE={mode}|SPEED4={speed4:.6f}|LOAD_RATIO={load:.6f}"
          f"|SPEED_GATE={speed4>=2.2}|LOAD_GATE={load<=1.20}")

print("FPE_MULTI02_P2_MIXED=PASS")
PY
