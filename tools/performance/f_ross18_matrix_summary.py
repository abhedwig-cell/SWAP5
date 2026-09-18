from __future__ import annotations

import argparse
import json
import math
import re
from pathlib import Path

CASE_RE = re.compile(
    r"^F_ROSS18_CASE\|CASE=(?P<case>\d+)\|ISE=(?P<ise>\d+)\|M=(?P<material>[^|]+)\|F=(?P<forcing>[^|]+)"
    r"\|CLASS=(?P<classification>[^|]+)\|LIN=(?P<lin>-?\d+)\|RETRY=(?P<retry>-?\d+)\|ALT=(?P<alt>-?\d+)"
    r"\|MASS=(?P<mass>[^|]+)\|TEMP=(?P<temp>[^|]+)"
    r"\|HINF=(?P<h_inf>[^|]+)\|HRMS=(?P<h_rms>[^|]+)"
    r"\|TINF=(?P<t_inf>[^|]+)\|TRMS=(?P<t_rms>[^|]+)\|STORAGE=(?P<storage>[^|]+)$"
)

def fnum(x: str) -> float:
    try:
        return float(x)
    except ValueError:
        return math.nan

def main() -> int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--variant", required=True)
    ap.add_argument("--expected-linear-solves", type=int, required=True)
    ap.add_argument("--input", type=Path, required=True)
    ap.add_argument("--output", type=Path, required=True)
    args=ap.parse_args()

    rows=[]
    for raw in args.input.read_text(encoding="utf-8",errors="replace").splitlines():
        m=CASE_RE.match(raw.strip())
        if not m:
            continue
        d=m.groupdict()
        row={
            "case":int(d["case"]),
            "ise":int(d["ise"]),
            "material":d["material"].strip(),
            "forcing":d["forcing"].strip(),
            "classification":d["classification"].strip(),
            "linear_solves":int(d["lin"]),
            "internal_retries":int(d["retry"]),
            "alternative_solver_calls":int(d["alt"]),
            "mass_residual_cm":fnum(d["mass"]),
            "temporal_indicator":fnum(d["temp"]),
            "head_inf_vs_reference":fnum(d["h_inf"]),
            "head_rms_vs_reference":fnum(d["h_rms"]),
            "theta_inf_vs_reference":fnum(d["t_inf"]),
            "theta_rms_vs_reference":fnum(d["t_rms"]),
            "storage_abs_vs_reference_cm":fnum(d["storage"]),
        }
        rows.append(row)

    if len(rows)!=36 or sorted(r["case"] for r in rows)!=list(range(1,37)):
        raise RuntimeError(f"expected exactly 36 case records, got {len(rows)}")

    valid=[r for r in rows if r["classification"] not in {"ROSSFAST_ROUTE_INVALID","BOTH_ROUTES_INVALID"}]
    paired=[r for r in rows if r["classification"]=="PAIRED_VALID_ADMISSIBLE"]
    discrepancy=[r for r in rows if r["classification"]=="PAIRED_VALID_DISCREPANCY_FAIL"]
    ross_invalid=[r for r in rows if r["classification"]=="ROSSFAST_ROUTE_INVALID"]
    ref_invalid=[r for r in rows if r["classification"]=="REFERENCE_ROUTE_INVALID"]
    both_invalid=[r for r in rows if r["classification"]=="BOTH_ROUTES_INVALID"]
    temporal_accepted=[r for r in valid if math.isfinite(r["temporal_indicator"]) and r["temporal_indicator"]<=1.0]
    work_ok=[r for r in valid if r["linear_solves"]==args.expected_linear_solves and r["internal_retries"]==0 and r["alternative_solver_calls"]==0]

    def vmax(key: str):
        vals=[r[key] for r in valid if math.isfinite(r[key])]
        return max(vals) if vals else None

    production_candidate=(
        len(paired)==36 and len(temporal_accepted)==36 and len(work_ok)==36
        and not ross_invalid and not ref_invalid and not both_invalid
    )
    result={
        "schema":"swap5.f-ross18.substep-science-result.v1",
        "variant":args.variant,
        "expected_linear_solves":args.expected_linear_solves,
        "case_count":36,
        "counts":{
            "paired_valid_admissible":len(paired),
            "paired_valid_discrepancy_fail":len(discrepancy),
            "rossfast_route_invalid":len(ross_invalid),
            "reference_route_invalid":len(ref_invalid),
            "both_routes_invalid":len(both_invalid),
            "rossfast_route_valid":len(valid),
            "temporal_indicator_le_1":len(temporal_accepted),
            "expected_work_count_and_no_retry":len(work_ok),
        },
        "worst":{
            "temporal_indicator":vmax("temporal_indicator"),
            "head_inf_vs_reference":vmax("head_inf_vs_reference"),
            "head_rms_vs_reference":vmax("head_rms_vs_reference"),
            "theta_inf_vs_reference":vmax("theta_inf_vs_reference"),
            "theta_rms_vs_reference":vmax("theta_rms_vs_reference"),
            "storage_abs_vs_reference_cm":vmax("storage_abs_vs_reference_cm"),
            "mass_residual_abs_cm":max((abs(r["mass_residual_cm"]) for r in valid if math.isfinite(r["mass_residual_cm"])),default=None),
        },
        "production_candidate_under_preregistered_research_rule":production_candidate,
        "rows":rows,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print(json.dumps(result,indent=2,sort_keys=True))
    print(f"F_ROSS18_VARIANT={args.variant}")
    print(f"F_ROSS18_PAIRED_VALID={len(paired)}")
    print(f"F_ROSS18_TEMPORAL_ACCEPTED={len(temporal_accepted)}")
    print(f"F_ROSS18_ROUTE_VALID={len(valid)}")
    print(f"F_ROSS18_PRODUCTION_CANDIDATE={'TRUE' if production_candidate else 'FALSE'}")
    print("F_ROSS18_SCIENCE_SUMMARY=PASS")
    return 0

if __name__=="__main__":
    raise SystemExit(main())
