#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-gc-e3-${GITHUB_RUN_ID:-local}-$$"
RESULTS="${PUB_GC_E3_RESULT_DIR:-$BUILD/results}"
mkdir -p "$BUILD" "$RESULTS"
trap 'rm -rf "$BUILD"' EXIT

FGC44_BUILD_DIR="$BUILD/fgc44" FGC44_SKIP_E2E=1 \
  bash tests/fgc/run_fgc44_real_swap_modflow_end_to_end.sh

LIBMF6="$BUILD/fgc44/modflow-bin/libmf6.so"
SWAPLIB="$BUILD/fgc44/bridge/libfgc44_swap.so"

windows=(2.5e-5 1.0e-4 4.0e-4 1.6e-3)
sys=(0.02 0.15 0.30)
treatments=(constant affine strong)

for w in "${windows[@]}"; do
  for sy in "${sys[@]}"; do
    tag="w${w}_sy${sy}"
    for treatment in "${treatments[@]}"; do
      echo "PUB_GC_E3_TREATMENT_START=$tag:$treatment"
      LIBMF6="$LIBMF6" \
      FGC44_SWAP_LIB="$SWAPLIB" \
      E3_WINDOW_DAY="$w" \
      E3_SY="$sy" \
      E3_TREATMENT="$treatment" \
      E3_RESULT_PATH="$RESULTS/${tag}_${treatment}.json" \
        python3 tests/publication/pub_gc_e3_case.py
      echo "PUB_GC_E3_TREATMENT_END=$tag:$treatment"
    done
  done
done

python3 - "$RESULTS" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

root=Path(sys.argv[1])
files=sorted(root.glob("w*_sy*_*.json"))
if len(files)!=36:
    raise SystemExit(f"expected 36 E3 treatment files, found {len(files)}")

by_case={}
for p in files:
    x=json.loads(p.read_text())
    if x.get("harness_status")!="OK":
        raise SystemExit(f"harness error in {p.name}: {x.get('harness_error')}")
    key=(float(x["window_day"]),float(x["specific_yield"]))
    by_case.setdefault(key,{})[x["treatment"]]=x

if len(by_case)!=12:
    raise SystemExit(f"expected 12 E3 cases, found {len(by_case)}")

rows=[]
for (window,sy), treatments in sorted(by_case.items()):
    if set(treatments)!={"constant","affine","strong"}:
        raise SystemExit(f"missing treatment for W={window}, Sy={sy}: {sorted(treatments)}")

    l0=treatments["constant"]["outcome"]
    l1=treatments["affine"]["outcome"]
    strong=treatments["strong"]["outcome"]

    row={
        "window_day":window,
        "window_seconds":window*86400.0,
        "specific_yield":sy,
        "loose_constant_status":l0.get("status"),
        "loose_constant_head_m":l0.get("head_m"),
        "loose_constant_q_gw_m_per_s":l0.get("q_gw_m_per_s"),
        "loose_constant_q_swap_diagnostic_m_per_s":l0.get("q_swap_diagnostic_m_per_s"),
        "loose_constant_residual_m_per_s":l0.get("interface_residual_m_per_s"),
        "loose_constant_modflow_solves":l0.get("modflow_solve_calls"),
        "predictor_affine_status":l1.get("status"),
        "predictor_affine_head_m":l1.get("head_m"),
        "predictor_affine_q_gw_m_per_s":l1.get("q_gw_m_per_s"),
        "predictor_affine_q_swap_diagnostic_m_per_s":l1.get("q_swap_diagnostic_m_per_s"),
        "predictor_affine_residual_m_per_s":l1.get("interface_residual_m_per_s"),
        "predictor_affine_modflow_solves":l1.get("modflow_solve_calls"),
        "strong_status":strong.get("status"),
        "strong_iterations":strong.get("iterations"),
        "strong_head_m":strong.get("head_m"),
        "strong_q_gw_m_per_s":strong.get("q_gw_m_per_s"),
        "strong_q_swap_m_per_s":strong.get("q_swap_m_per_s"),
        "strong_residual_m_per_s":strong.get("interface_residual_m_per_s"),
        "strong_swap_work":strong.get("operational_swap_window_evaluations"),
        "strong_modflow_solves":strong.get("modflow_solve_calls"),
    }

    if strong.get("status")=="CONVERGED":
        sh=float(strong["head_m"])
        sq=float(strong["q_gw_m_per_s"])
        for prefix,base in (("loose_constant",l0),("predictor_affine",l1)):
            if base.get("status")=="OK":
                row[f"{prefix}_residual_over_tol"]=abs(float(base["interface_residual_m_per_s"]))/1.0e-15
                row[f"{prefix}_head_difference_from_strong_m"]=float(base["head_m"])-sh
                row[f"{prefix}_groundwater_flux_difference_from_strong_m_per_s"]=float(base["q_gw_m_per_s"])-sq
    rows.append(row)

anchor=next(
    row for row in rows
    if abs(row["window_day"]-1.0e-4)<1e-16 and abs(row["specific_yield"]-0.15)<1e-14
)
if anchor["strong_status"]!="CONVERGED":
    raise SystemExit(f"anchor did not converge: {anchor}")
if abs(float(anchor["strong_residual_m_per_s"]))>1.0e-15:
    raise SystemExit("anchor flux residual outside frozen tolerance")
if abs(float(anchor["strong_head_m"])-(-0.71499996773317653))>1.0e-9:
    raise SystemExit(f"anchor head drift: {anchor['strong_head_m']}")

payload={
    "schema":"pub-gc-e3-summary-v1",
    "case_count":len(rows),
    "treatment_run_count":len(files),
    "anchor":"PASS",
    "matrix":rows,
}
(root/"PUB_GC_E3_SUMMARY.json").write_text(
    json.dumps(payload,indent=2,sort_keys=True)+"\n"
)

print("PUB_GC_E3_ANCHOR=PASS")
for row in rows:
    print(
        "PUB_GC_E3_ROW "
        f"W={row['window_day']:.8g} "
        f"SY={row['specific_yield']:.8g} "
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
