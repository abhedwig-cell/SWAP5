#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-multi02-p2-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

for rep in 1 2 3; do
  bash tests/fpe/run_fpe_multi02_p0_worker_local.sh | tee "$BUILD/rep$rep.txt"
done

python3 - "$BUILD" <<'PY'
import statistics,sys
from pathlib import Path
root=Path(sys.argv[1])
vals={2:[],4:[]}
for rep in (1,2,3):
    rows={}
    for line in (root/f"rep{rep}.txt").read_text().splitlines():
        if not line.startswith("MULTI02_P0_SUMMARY|"): continue
        d={}
        for p in line.split("|")[1:]:
            k,v=p.split("=",1); d[k]=v
        if int(d["N"])==1000:
            rows[int(d["WORKERS"])]=d
    if set(rows)!={1,2,4}: raise SystemExit(f"missing N1000 rows rep={rep}")
    for w in (2,4):
        vals[w].append(float(rows[w]["SPEEDUP"]))
for w in (2,4):
    med=statistics.median(vals[w])
    print(f"MULTI02_P2_PERF|WORKERS={w}|REPLICATES={','.join(f'{x:.6f}' for x in vals[w])}|MEDIAN_SPEEDUP={med:.6f}|EFFICIENCY={med/w:.6f}")
if statistics.median(vals[2])<1.5: raise SystemExit("2-worker frozen speed gate failed")
if statistics.median(vals[4])<2.2: raise SystemExit("4-worker frozen speed gate failed")
print("FPE_MULTI02_P2_PERFORMANCE=PASS")
PY
