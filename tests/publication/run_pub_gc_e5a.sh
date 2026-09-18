#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-gc-e5-${GITHUB_RUN_ID:-local}-$$"
OUT="${PUB_GC_E5_RESULT_DIR:-$BUILD/results}"
mkdir -p "$BUILD" "$OUT"
trap 'rm -rf "$BUILD"' EXIT

FGC44_BUILD_DIR="$BUILD/fgc44" FGC44_SKIP_E2E=1 bash tests/fgc/run_fgc44_real_swap_modflow_end_to_end.sh
LIBMF6="$BUILD/fgc44/modflow-bin/libmf6.so"
SWAPLIB="$BUILD/fgc44/bridge/libfgc44_swap.so"

: > "$OUT/cases.jsonl"
BASELINES=(
  "B1 1e-4 1e-6 -3.402833570476105e-5"
  "B3 1e-3 1e-4 -2.8821767195098304e-4"
  "B4 1e-2 1e-6 -1.190272325146675e-3"
)
KS=(0.01 0.1)
METHODS=(fp aitken secant uA oracle)

for item in "${BASELINES[@]}"; do
  read -r bid win qbot jr <<< "$item"
  for kval in "${KS[@]}"; do
    for method in "${METHODS[@]}"; do
      echo "PUB_GC_E5_CASE baseline=$bid K=$kval method=$method"
      output="$(
        LIBMF6="$LIBMF6" FGC44_SWAP_LIB="$SWAPLIB"         E5_BASELINE="$bid" E5_WINDOW_DAY="$win" E5_QBOT_CM_PER_DAY="$qbot"         E5_K_M_PER_DAY="$kval" E5_JR="$jr" E5_METHOD="$method"         python3 tests/publication/test_pub_gc_e5a_case.py
      )"
      printf '%s
' "$output"
      line="$(printf '%s
' "$output" | sed -n 's/^E5_JSON=//p' | tail -n 1)"
      test -n "$line" || { echo "missing E5 JSON" >&2; exit 1; }
      printf '%s
' "$line" >> "$OUT/cases.jsonl"
    done
  done
done

python3 - "$OUT" <<'PY'
from __future__ import annotations
import csv,json,math,sys
from pathlib import Path

out=Path(sys.argv[1])
rows=[json.loads(x) for x in (out/"cases.jsonl").read_text().splitlines() if x.strip()]
if len(rows)!=30:
    raise SystemExit(f"expected 30 E5a runs, got {len(rows)}")
if any(r.get("harness_status")!="OK" for r in rows):
    raise SystemExit("E5a harness error present")

by={}
for r in rows:
    key=(r["baseline"],float(r["k_m_per_day"]))
    by.setdefault(key,{})[r["method"]]=r["outcome"]

summary=[]
for key,methods in sorted(by.items()):
    if set(methods)!={"fp","aitken","secant","uA","oracle"}:
        raise SystemExit(f"missing method {key}")
    converged={m:o for m,o in methods.items() if o.get("status")=="CONVERGED"}
    # All converged methods should represent the same root to tight numerical scale.
    heads=[float(o["head_m"]) for o in converged.values()]
    qs=[float(o["q_swap_m_per_s"]) for o in converged.values()]
    head_span=max(heads)-min(heads) if heads else math.nan
    q_span=max(qs)-min(qs) if qs else math.nan
    if heads and head_span>1e-8:
        raise SystemExit(f"solution head span too large {key}: {head_span}")
    row={"baseline":key[0],"k_m_per_day":key[1],"head_span_m":head_span,"q_span_m_per_s":q_span}
    for m,o in methods.items():
        row[f"{m}_status"]=o.get("status")
        row[f"{m}_iterations"]=o.get("iterations")
        row[f"{m}_swap_work"]=o.get("swap_work")
        row[f"{m}_residual_m_per_s"]=o.get("residual_m_per_s")
    if methods["secant"].get("status")=="CONVERGED" and methods["oracle"].get("status")=="CONVERGED":
        row["deltaW_oracle_vs_secant"]=int(methods["secant"]["swap_work"])-int(methods["oracle"]["swap_work"])
    summary.append(row)

payload={"schema":"pub-gc-e5a-summary-v1","case_count":len(summary),"run_count":len(rows),"matrix":summary}
(out/"PUB_GC_E5A_SUMMARY.json").write_text(json.dumps(payload,indent=2,sort_keys=True)+"
")

fields=[]
for r in summary:
    for k in r:
        if k not in fields: fields.append(k)
with (out/"PUB_GC_E5A_TABLE.csv").open("w",newline="") as f:
    w=csv.DictWriter(f,fieldnames=fields); w.writeheader(); w.writerows(summary)

for r in summary:
    print("PUB_GC_E5_ROW "+json.dumps(r,sort_keys=True,separators=(",",":")))
print("PUB_GC_E5A_COMPLETE=PASS")
PY
