#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-gc-e5-${GITHUB_RUN_ID:-local}-$$"
OUT="${PUB_GC_E5_RESULT_DIR:-$BUILD/results}"
mkdir -p "$BUILD" "$OUT"
trap 'rm -rf "$BUILD"' EXIT

PUB_GC_SWAP_BUILD_DIR="$BUILD/swap" bash tests/publication/build_pub_gc_swap_bridge.sh
SWAPLIB="$BUILD/swap/bridge/libfgc44_swap.so"
test -f "$SWAPLIB"

: > "$OUT/raw.jsonl"
: > "$OUT/output.txt"

for id in B1 B2 B3 B4; do
  echo "PUB_GC_E5_BASELINE_START=$id" | tee -a "$OUT/output.txt"
  REC="$(
    FGC44_SWAP_LIB="$SWAPLIB"     E5_BASELINE_ID="$id"       python3 tests/publication/test_pub_gc_e5_information_value.py
  )"
  printf '%s
' "$REC" | tee -a "$OUT/output.txt"
  JSON_LINE="$(printf '%s
' "$REC" | sed -n 's/^E5_JSON=//p' | tail -n 1)"
  test -n "$JSON_LINE" || { echo "missing E5 JSON for $id" >&2; exit 1; }
  printf '%s
' "$JSON_LINE" >> "$OUT/raw.jsonl"
  echo "PUB_GC_E5_BASELINE_END=$id" | tee -a "$OUT/output.txt"
done

python3 - "$OUT" <<'PY'
from __future__ import annotations
import csv, json, sys
from pathlib import Path

out=Path(sys.argv[1])
records=[json.loads(line) for line in (out/"raw.jsonl").read_text().splitlines() if line.strip()]
if len(records)!=4:
    raise SystemExit(f"expected 4 E5 baseline records, found {len(records)}")

rows=[]
for base in records:
    if base["authority_state_final"] != base["authority_state_origin"]:
        raise SystemExit(f"authority changed for {base['baseline_id']}")
    for r in base["results"]:
        rows.append({
            "baseline_id":base["baseline_id"],
            "window_day":base["window_day"],
            "qbot_cm_per_day":base["qbot_cm_per_day"],
            "u_A":base["u_A"],
            "J_R":base["J_R"],
            "C":r["C"],
            "method":r["method"],
            "status":r["status"],
            "swap_evaluations":r["swap_evaluations"],
            "final_transfer_residual_m":r.get("final_transfer_residual_m"),
            "final_head_error_m":r.get("final_head_error_m"),
        })

by={}
for row in rows:
    by[(row["baseline_id"],float(row["C"]),row["method"])]=row

comparisons=[]
for base in ("B1","B2","B3","B4"):
    for C in (0.1,0.5,0.9,1.1,1.5,2.0):
        sec=by[(base,C,"SECANT_COLD")]
        ua=by[(base,C,"U_A")]
        oracle=by[(base,C,"ORACLE_JR")]
        fp=by[(base,C,"FP")]
        ait=by[(base,C,"AITKEN")]
        comp={
            "baseline_id":base,
            "C":C,
            "FP_status":fp["status"],
            "FP_work":fp["swap_evaluations"],
            "AITKEN_status":ait["status"],
            "AITKEN_work":ait["swap_evaluations"],
            "SECANT_status":sec["status"],
            "SECANT_work":sec["swap_evaluations"],
            "U_A_status":ua["status"],
            "U_A_work":ua["swap_evaluations"],
            "ORACLE_status":oracle["status"],
            "ORACLE_work":oracle["swap_evaluations"],
        }
        if sec["status"]=="CONVERGED" and ua["status"]=="CONVERGED":
            comp["DeltaW_uA_vs_secant"]=sec["swap_evaluations"]-ua["swap_evaluations"]
        if sec["status"]=="CONVERGED" and oracle["status"]=="CONVERGED":
            comp["DeltaW_oracle_vs_secant"]=sec["swap_evaluations"]-oracle["swap_evaluations"]
        comparisons.append(comp)

payload={
    "schema":"pub-gc-e5-information-value-summary-v1",
    "baseline_count":len(records),
    "case_count":len(comparisons),
    "algorithm_result_count":len(rows),
    "rows":rows,
    "comparisons":comparisons,
}
(out/"PUB_GC_E5_SUMMARY.json").write_text(json.dumps(payload,indent=2,sort_keys=True)+"
")

fields=[
    "baseline_id","C",
    "FP_status","FP_work","AITKEN_status","AITKEN_work",
    "SECANT_status","SECANT_work","U_A_status","U_A_work",
    "ORACLE_status","ORACLE_work","DeltaW_uA_vs_secant","DeltaW_oracle_vs_secant",
]
with (out/"PUB_GC_E5_COMPARISON.csv").open("w",newline="") as f:
    w=csv.DictWriter(f,fieldnames=fields)
    w.writeheader()
    for row in comparisons:
        w.writerow(row)

print("PUB_GC_E5_MATRIX_COMPLETE=PASS")
for row in comparisons:
    print(
        "PUB_GC_E5_ROW "
        f"B={row['baseline_id']} C={row['C']} "
        f"FP={row['FP_status']}:{row['FP_work']} "
        f"AIT={row['AITKEN_status']}:{row['AITKEN_work']} "
        f"SEC={row['SECANT_status']}:{row['SECANT_work']} "
        f"UA={row['U_A_status']}:{row['U_A_work']} "
        f"OR={row['ORACLE_status']}:{row['ORACLE_work']} "
        f"DU={row.get('DeltaW_uA_vs_secant')} "
        f"DO={row.get('DeltaW_oracle_vs_secant')}"
    )
PY
