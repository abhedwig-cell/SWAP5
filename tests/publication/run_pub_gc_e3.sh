#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-gc-e3-${GITHUB_RUN_ID:-local}-$$"
RESULTS="${PUB_GC_E3_RESULT_DIR:-$BUILD/results}"
mkdir -p "$BUILD" "$RESULTS"
trap 'rm -rf "$BUILD"' EXIT

FGC44_BUILD_DIR="$BUILD/fgc44" FGC44_SKIP_E2E=1   bash tests/fgc/run_fgc44_real_swap_modflow_end_to_end.sh

LIBMF6="$BUILD/fgc44/modflow-bin/libmf6.so"
SWAPLIB="$BUILD/fgc44/bridge/libfgc44_swap.so"

windows=(2.5e-5 1.0e-4 4.0e-4 1.6e-3)
sys=(0.02 0.15 0.30)

for w in "${windows[@]}"; do
  for sy in "${sys[@]}"; do
    tag="w${w}_sy${sy}"
    echo "PUB_GC_E3_CASE_START=$tag"
    LIBMF6="$LIBMF6"     FGC44_SWAP_LIB="$SWAPLIB"     E3_WINDOW_DAY="$w"     E3_SY="$sy"     E3_RESULT_PATH="$RESULTS/$tag.json"       python3 tests/publication/pub_gc_e3_case.py
    echo "PUB_GC_E3_CASE_END=$tag"
  done
done

python3 - "$RESULTS" <<'PY'
from __future__ import annotations
import json, math, sys
from pathlib import Path

root=Path(sys.argv[1])
files=sorted(root.glob("w*_sy*.json"))
if len(files)!=12:
    raise SystemExit(f"expected 12 E3 cases, found {len(files)}")

rows=[]
for p in files:
    x=json.loads(p.read_text())
    if x.get("harness_status")!="OK":
        raise SystemExit(f"harness error in {p.name}: {x.get('harness_error')}")
    rows.append(x)

anchor=next(x for x in rows if abs(x["window_day"]-1.0e-4)<1e-16 and abs(x["specific_yield"]-0.15)<1e-14)
strong=anchor["strong"]
if strong.get("status")!="CONVERGED":
    raise SystemExit(f"anchor did not converge: {strong}")
if abs(strong["interface_residual_m_per_s"])>1.0e-15:
    raise SystemExit("anchor flux residual outside frozen tolerance")
if abs(strong["head_m"]-(-0.71499996773317653))>1.0e-9:
    raise SystemExit(f"anchor head drift: {strong['head_m']}")

summary=[]
for x in sorted(rows,key=lambda z:(z["window_day"],z["specific_yield"])):
    s=x["strong"]
    l0=x["loose_constant"]
    l1=x["predictor_affine"]
    summary.append({
        "window_day":x["window_day"],
        "specific_yield":x["specific_yield"],
        "loose_constant_status":l0.get("status"),
        "loose_constant_residual_m_per_s":l0.get("interface_residual_m_per_s"),
        "loose_constant_residual_over_tol":l0.get("residual_over_coupling_tolerance"),
        "predictor_affine_status":l1.get("status"),
        "predictor_affine_residual_m_per_s":l1.get("interface_residual_m_per_s"),
        "predictor_affine_residual_over_tol":l1.get("residual_over_coupling_tolerance"),
        "strong_status":s.get("status"),
        "strong_iterations":s.get("iterations"),
        "strong_residual_m_per_s":s.get("interface_residual_m_per_s"),
        "strong_head_m":s.get("head_m"),
        "strong_swap_work":s.get("operational_swap_window_evaluations"),
        "strong_modflow_solves":s.get("modflow_solve_calls"),
        "l0_head_difference_from_strong_m":l0.get("head_difference_from_strong_m"),
        "l1_head_difference_from_strong_m":l1.get("head_difference_from_strong_m"),
    })

payload={
    "schema":"pub-gc-e3-summary-v1",
    "case_count":len(rows),
    "anchor":"PASS",
    "matrix":summary,
}
(root/"PUB_GC_E3_SUMMARY.json").write_text(json.dumps(payload,indent=2,sort_keys=True)+"
")

print("PUB_GC_E3_ANCHOR=PASS")
for row in summary:
    print(
        "PUB_GC_E3_ROW "
        f"W={row['window_day']:.8g} SY={row['specific_yield']:.8g} "
        f"L0={row['loose_constant_status']} "
        f"L0R={row['loose_constant_residual_m_per_s']} "
        f"L1={row['predictor_affine_status']} "
        f"L1R={row['predictor_affine_residual_m_per_s']} "
        f"S={row['strong_status']} "
        f"N={row['strong_iterations']} "
        f"SR={row['strong_residual_m_per_s']}"
    )
print("PUB_GC_E3_MATRIX_COMPLETE=PASS")
PY
