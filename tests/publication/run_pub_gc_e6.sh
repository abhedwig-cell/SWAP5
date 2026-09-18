#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/pub-gc-e6-${GITHUB_RUN_ID:-local}-$$"
RESULTS="${PUB_GC_E6_RESULT_DIR:-$BUILD/results}"
mkdir -p "$BUILD" "$RESULTS"
trap 'rm -rf "$BUILD"' EXIT

PUB_GC_E6_BUILD_DIR="$BUILD/build" bash tests/publication/build_pub_gc_e6_active_drainage.sh | tee "$RESULTS/init.txt"
LIBMF6="$BUILD/build/modflow-bin/libmf6.so"
SWAPLIB="$BUILD/build/bridge/libpub_gc_e6_swap.so"

for sy in 0.02 0.15 0.30; do
  E6_SY="$sy" LIBMF6="$LIBMF6" PUB_GC_E6_SWAP_LIB="$SWAPLIB" \
    python3 tests/publication/test_pub_gc_e6_live_case.py | tee "$RESULTS/sy_${sy}.txt"
done

python3 - "$RESULTS" <<'PY'
from __future__ import annotations
import json,sys
from pathlib import Path
root=Path(sys.argv[1])
rows=[]
for p in sorted(root.glob("sy_*.txt")):
    lines=[x for x in p.read_text().splitlines() if x.startswith("PUB_GC_E6_JSON=")]
    if len(lines)!=1: raise SystemExit(f"missing E6 JSON in {p}")
    rows.append(json.loads(lines[0].split("=",1)[1]))
payload={"schema":"pub-gc-e6-summary-v1","cases":rows}
(root/"PUB_GC_E6_RESULT_RAW.json").write_text(json.dumps(payload,indent=2,sort_keys=True)+"\n")
for r in rows:
    print("PUB_GC_E6_ROW",r["specific_yield"],r["loose"]["status"],r["strong"]["status"],
          r.get("delta_head_strong_minus_loose_m"),r.get("delta_integrated_exchange_m"))
if not all(r["loose"].get("status")=="OK" for r in rows):
    raise SystemExit("at least one E6 loose case unavailable")
print("PUB_GC_E6_MATRIX_EXECUTED=PASS")
PY
