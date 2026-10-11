from __future__ import annotations

import argparse
import json
import math
import re
from collections import Counter
from pathlib import Path

CASE_RE = re.compile(
    r"^F_ROSS21_CASE\|CASE=(?P<case>\d+)\|ISE=(?P<ise>\d+)\|M=(?P<material>[^|]+)\|F=(?P<forcing>[^|]+)"
    r"\|CLASS=(?P<classification>[^|]+)\|LIN=(?P<lin>-?\d+)\|RETRY=(?P<retry>-?\d+)\|ALT=(?P<alt>-?\d+)"
    r"\|LEVEL=(?P<level>-?\d+)\|MASS=(?P<mass>[^|]+)\|TEMP=(?P<temp>[^|]+)"
    r"\|HINF=(?P<h_inf>[^|]+)\|HRMS=(?P<h_rms>[^|]+)"
    r"\|TINF=(?P<t_inf>[^|]+)\|TRMS=(?P<t_rms>[^|]+)\|STORAGE=(?P<storage>[^|]+)$"
)
HARD_MASS_TOL_CM = 1.0e-12

def fnum(value: str) -> float:
    try:
        return float(value)
    except ValueError:
        return math.nan

def main() -> int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--input", type=Path, required=True)
    ap.add_argument("--output", type=Path, required=True)
    args=ap.parse_args()

    rows=[]
    for raw in args.input.read_text(encoding="utf-8",errors="replace").splitlines():
        m=CASE_RE.match(raw.strip())
        if not m:
            continue
        d=m.groupdict()
        rows.append({
            "case":int(d["case"]),
            "ise":int(d["ise"]),
            "material":d["material"].strip(),
            "forcing":d["forcing"].strip(),
            "classification":d["classification"].strip(),
            "linear_solves":int(d["lin"]),
            "internal_retries":int(d["retry"]),
            "alternative_solver_calls":int(d["alt"]),
            "level":int(d["level"]),
            "mass_residual_cm":fnum(d["mass"]),
            "temporal_indicator":fnum(d["temp"]),
            "head_inf_vs_reference":fnum(d["h_inf"]),
            "theta_inf_vs_reference":fnum(d["t_inf"]),
        })

    if len(rows)!=216 or sorted(r["case"] for r in rows)!=list(range(1,217)):
        raise RuntimeError(f"expected 216 ordered case records, got {len(rows)}")

    route_valid=[r for r in rows if r["classification"] not in {"ROSSFAST_ROUTE_INVALID","BOTH_ROUTES_INVALID"}]
    temporal_ok=[r for r in route_valid if math.isfinite(r["temporal_indicator"]) and r["temporal_indicator"]<=1.0]
    mass_ok=[r for r in route_valid if math.isfinite(r["mass_residual_cm"]) and abs(r["mass_residual_cm"])<=HARD_MASS_TOL_CM]
    expected_work={0:6,1:18,2:42}
    work_ok=[r for r in route_valid if r["level"] in expected_work and r["linear_solves"]==expected_work[r["level"]]]
    retry_ok=[r for r in route_valid if r["internal_retries"]==0 and r["alternative_solver_calls"]==0]
    fast=[r for r in route_valid if r["level"]==0]
    mid=[r for r in route_valid if r["level"]==1]
    final=[r for r in route_valid if r["level"]==2]

    tier_distribution_ok=(len(fast)==212 and len(mid)==2 and len(final)==2 and
                          {r["material"] for r in mid}=={"O01"} and
                          {r["material"] for r in final}=={"B05"} and
                          all(r["ise"]==3 for r in mid+final))
    passed=(len(route_valid)==216 and len(temporal_ok)==216 and len(mass_ok)==216 and
            len(work_ok)==216 and len(retry_ok)==216 and tier_distribution_ok)

    by_material=Counter(r["material"] for r in mid+final)
    by_ise=Counter(str(r["ise"]) for r in mid+final)
    by_forcing=Counter(r["forcing"] for r in mid+final)
    result={
        "schema":"swap5.f-ross21.all-material-research-matrix.v1",
        "case_count":216,
        "route_valid_count":len(route_valid),
        "temporal_accepted_count":len(temporal_ok),
        "mass_pass_count":len(mass_ok),
        "work_contract_pass_count":len(work_ok),
        "retry_contract_pass_count":len(retry_ok),
        "K2_final_count":len(fast),
        "K4_final_count":len(mid),
        "K8_final_count":len(final),
        "tier_distribution_expected":tier_distribution_ok,
        "escalation_by_material":dict(sorted(by_material.items())),
        "escalation_by_effective_saturation_index":dict(sorted(by_ise.items())),
        "escalation_by_forcing":dict(sorted(by_forcing.items())),
        "mean_linear_solves":sum(r["linear_solves"] for r in route_valid)/len(route_valid) if route_valid else None,
        "worst":{
            "temporal_indicator":max((r["temporal_indicator"] for r in route_valid),default=None),
            "mass_residual_abs_cm":max((abs(r["mass_residual_cm"]) for r in route_valid),default=None),
        },
        "failed_cases":{
            "route":[r["case"] for r in rows if r not in route_valid],
            "temporal":[r["case"] for r in route_valid if r not in temporal_ok],
            "mass":[r["case"] for r in route_valid if r not in mass_ok],
            "work":[r["case"] for r in route_valid if r not in work_ok],
            "retry":[r["case"] for r in route_valid if r not in retry_ok],
            "tier_distribution":[] if tier_distribution_ok else [r["case"] for r in mid+final],
        },
        "gate":"PASS" if passed else "FAIL",
        "rows":rows,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print(json.dumps(result,indent=2,sort_keys=True))
    print(f"F_ROSS21_ALL_MATERIAL_ROUTE_VALID={len(route_valid)}")
    print(f"F_ROSS21_ALL_MATERIAL_TEMPORAL_ACCEPTED={len(temporal_ok)}")
    print(f"F_ROSS21_ALL_MATERIAL_K2_FINAL={len(fast)}")
    print(f"F_ROSS21_ALL_MATERIAL_K4_FINAL={len(mid)}")
    print(f"F_ROSS21_ALL_MATERIAL_K8_FINAL={len(final)}")
    print(f"F_ROSS21_ALL_MATERIAL_MEAN_LINEAR_SOLVES={result['mean_linear_solves']:.12g}")
    print(f"F_ROSS21_ALL_MATERIAL_GATE={result['gate']}")
    return 0 if passed else 2

if __name__=="__main__":
    raise SystemExit(main())
