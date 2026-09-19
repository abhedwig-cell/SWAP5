#!/usr/bin/env python3
from __future__ import annotations

import argparse
import collections
import json
import pathlib

WIDTHS=("2.5","5.0")
HISTORIES=("WT_HOLD","WT_RISE","WT_FALL","WT_CYCLE")
PRIMARY="0.00005000"
CROSS="0.00002500"

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--case-dir",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    by_key={}
    for path in sorted(args.case_dir.glob("*.json")):
        p=json.loads(path.read_text())
        if p.get("schema")!="swap5.lare.bc2.c3.case-result.v1":
            continue
        key=(str(p["width_cm"]),p["history"])
        if key in by_key:
            raise SystemExit(f"duplicate C3 case {key}")
        by_key[key]=p
    expected={(w,h) for w in WIDTHS for h in HISTORIES}
    if set(by_key)!=expected:
        raise SystemExit(f"C3 case set mismatch missing={sorted(expected-set(by_key))} extra={sorted(set(by_key)-expected)}")

    cases={w:{} for w in WIDTHS}
    failures={}
    dynamic_rank_counts=collections.Counter()
    route_rank_mismatch=[]
    max_hard=0.0
    for w,h in sorted(expected):
        p=by_key[(w,h)]
        cases[w][h]=p
        if not p["complete"] or p["decision"]!="BC2_C3_SIGNED_BIAS_CASE_MAPPED":
            failures[f"{w}:{h}"]="CASE_BLOCKED"
            continue
        for route in (PRIMARY,CROSS):
            vals=p["routes"][route]["hard_checks"]
            max_hard=max(max_hard,max(float(v) for k,v in vals.items() if k!="gate"))
        if not p["route_consistency"]["family_rank_match"]:
            route_rank_mismatch.append(f"{w}:{h}")
        if h!="WT_HOLD":
            dynamic_rank_counts[p["routes"][PRIMARY]["family_rank_by_cumulative_shape_injection"][0]]+=1

    complete=not failures
    unanimous_dynamic_family=None
    if complete and len(dynamic_rank_counts)==1:
        unanimous_dynamic_family=next(iter(dynamic_rank_counts))
    result={
        "schema":"swap5.lare.bc2.c3.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C3",
        "decision":"BC2_C3_SIGNED_LOCAL_BIAS_LEDGER_MAPPED" if complete else "BC2_C3_DIAGNOSTIC_BLOCKED",
        "complete":complete,
        "hard_checks":{
            "failure_count":len(failures),
            "maximum_recorded_hard_residual_or_identity_error":max_hard,
            "gate":1.0e-10,
            "all_case_primary_and_cross_routes_qualified":complete,
        },
        "failures":failures,
        "dynamic_primary_top_family_counts":dict(dynamic_rank_counts),
        "unanimous_dynamic_top_family":unanimous_dynamic_family,
        "primary_cross_family_rank_mismatch_cases":route_rank_mismatch,
        "cases":cases,
        "interpretation":[
            "C3 is an exact conservation-ledger attribution of teacher-reference local bias, not a closure intervention.",
            "All internal flux errors, q90, qi, qH and the moving-boundary geometric transfer are converted into additive physical-state storage contributions.",
            "Family ranking uses cumulative mass-neutral shape injection at final geometry; signed flux magnitude alone is not treated as causal dominance.",
            "Primary and cross internal time steps are both retained. A rank mismatch is reported rather than tuned away.",
            "No C3 result by itself authorizes a corrected closure; any intervention requires a new preregistered C4 counterfactual."
        ],
        "next_model_change_authorized":False,
        "groundwater_feedback_authorized":False,
        "application_acceptance_adjudicated":False,
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":result["decision"],
        "complete":complete,
        "hard_checks":result["hard_checks"],
        "dynamic_primary_top_family_counts":result["dynamic_primary_top_family_counts"],
        "unanimous_dynamic_top_family":unanimous_dynamic_family,
        "primary_cross_family_rank_mismatch_cases":route_rank_mismatch,
        "primary_case_summary":{
            w:{h:{
                "rank":cases[w][h]["routes"][PRIMARY]["family_rank_by_cumulative_shape_injection"],
                "top":cases[w][h]["routes"][PRIMARY]["family_rank_by_cumulative_shape_injection"][0],
                "top_metrics":cases[w][h]["routes"][PRIMARY]["families"][
                    cases[w][h]["routes"][PRIMARY]["family_rank_by_cumulative_shape_injection"][0]
                ],
            } for h in HISTORIES}
            for w in WIDTHS
        } if complete else {}
    },sort_keys=True))
    return 0 if complete else 2

if __name__=="__main__":
    raise SystemExit(main())
