#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib

WIDTHS=("2.5","5.0")
HISTORIES=("WT_HOLD","WT_RISE","WT_FALL","WT_CYCLE")
PRIMARY="0.00005000"
CROSS="0.00002500"
ROUTES=(PRIMARY,CROSS)
DYNAMIC=("WT_RISE","WT_FALL","WT_CYCLE")
SHAPE_KEY="cumulative_shape_rms_theta_at_final_geometry"

def best(case,route):
    return case["routes"][route]["unique_best_single_channel"]

def shape(case,route,variant):
    return float(case["routes"][route]["variants"][variant][SHAPE_KEY])

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--case-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    assert pre["phase"]=="PREREGISTERED_AFTER_C3A_BEFORE_ORACLE_INTERVENTION_RESPONSE"

    cases={}
    for pth in sorted(args.case_dir.glob("*.json")):
        p=json.loads(pth.read_text())
        if p.get("schema")!="swap5.lare.bc2.c4b.case-result.v1":
            continue
        key=(str(p["width_cm"]),p["history"])
        if key in cases:
            raise SystemExit(f"duplicate C4B case {key}")
        cases[key]=p
    expected={(w,h) for w in WIDTHS for h in HISTORIES}
    if set(cases)!=expected:
        raise SystemExit(f"C4B case mismatch missing={sorted(expected-set(cases))} extra={sorted(set(cases)-expected)}")

    failures={}
    max_hard=0.0
    for key,p in cases.items():
        if not p["complete"] or p["decision"]!="BC2_C4B_ORACLE_CASE_MAPPED":
            failures[f"{key[0]}:{key[1]}"]="CASE_BLOCKED"
            continue
        for route in ROUTES:
            hc=p["routes"][route]["hard_checks"]
            max_hard=max(max_hard,max(float(v) for k,v in hc.items() if k!="gate"))

    complete=not failures and max_hard<=1e-10

    hold_q90=complete and all(
        best(cases[(w,"WT_HOLD")],r)=="ORACLE_Q90"
        for w in WIDTHS for r in ROUTES
    )
    monotone_qi=complete and all(
        best(cases[(w,h)],r)=="ORACLE_QI"
        for w in WIDTHS for h in ("WT_RISE","WT_FALL") for r in ROUTES
    )
    cycle_qh=complete and all(
        best(cases[(w,"WT_CYCLE")],r)=="ORACLE_QH"
        for w in WIDTHS for r in ROUTES
    )
    coupled_qi_qh=complete and all(
        shape(cases[(w,h)],r,"ORACLE_QI_QH") < shape(cases[(w,h)],r,"ORACLE_QI")
        and shape(cases[(w,h)],r,"ORACLE_QI_QH") < shape(cases[(w,h)],r,"ORACLE_QH")
        for w in WIDTHS for h in DYNAMIC for r in ROUTES
    )

    if not complete:
        decision="C4B_DIAGNOSTIC_BLOCKED"
    elif monotone_qi and cycle_qh:
        decision="REGIME_DEPENDENT_COUPLED_LOWER_BOUNDARY_CAUSALITY"
    elif monotone_qi:
        decision="MONOTONE_QI_CAUSALITY_ONLY"
    elif cycle_qh:
        decision="CYCLE_QH_CAUSALITY_ONLY"
    else:
        decision="MULTI_CHANNEL_OR_SUBINTERVAL_DYNAMICS_REQUIRED"

    case_summary={}
    for w in WIDTHS:
        case_summary[w]={}
        for h in HISTORIES:
            p=cases[(w,h)]
            if not p["complete"] or p["decision"]!="BC2_C4B_ORACLE_CASE_MAPPED":
                case_summary[w][h]={
                    "decision":p["decision"],
                    "complete":False,
                    "failures":p.get("failures",{}),
                    "blocked_variant":p.get("blocked_variant"),
                    "blocked_interval":p.get("blocked_interval"),
                }
            else:
                case_summary[w][h]={
                    "decision":p["decision"],
                    "complete":True,
                    "primary_best_single":best(p,PRIMARY),
                    "cross_best_single":best(p,CROSS),
                    "primary_rank":p["routes"][PRIMARY]["single_channel_rank_by_cumulative_shape"],
                    "cross_rank":p["routes"][CROSS]["single_channel_rank_by_cumulative_shape"],
                    "primary_shapes":{v:shape(p,PRIMARY,v) for v in p["routes"][PRIMARY]["variants"]},
                    "cross_shapes":{v:shape(p,CROSS,v) for v in p["routes"][CROSS]["variants"]},
                }

    result={
        "schema":"swap5.lare.bc2.c4b.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C4B",
        "decision":decision,
        "complete":complete,
        "hard_checks":{
            "failure_count":len(failures),
            "maximum_recorded_hard_residual_or_identity_error":max_hard,
            "gate":1e-10,
        },
        "failures":failures,
        "frozen_hypotheses":{
            "HOLD_Q90_CAUSAL":hold_q90,
            "QI_CAUSAL_IN_MONOTONE_H_MOTION":monotone_qi,
            "QH_CAUSAL_IN_CYCLE_CUMULATIVE_SHAPE":cycle_qh,
            "COUPLED_QI_QH_STRICTLY_BETTER_IN_ALL_DYNAMIC_CASES":coupled_qi_qh,
        },
        "case_summary":case_summary,
        "cases":{f"{w}:{h}":cases[(w,h)] for w,h in sorted(expected)},
        "interpretation":[
            "C4B substitutes exact Reference interval-average channel values only as causal oracles; no deployable closure is tested.",
            "All cases start every interval from exact Reference-projected reduced state, so the comparison isolates within-interval causal error injection.",
            "Single-channel causal hypotheses require unanimity across the preregistered regime cases and both numerical routes.",
            "The qi+qH combined oracle is reported separately as an interaction diagnostic and cannot rescue a failed single-channel hypothesis.",
            "No global closure correction is authorized by a regime-dependent outcome."
        ],
        "model_candidate_tested":False,
        "next_model_change_authorized":False,
        "groundwater_feedback_authorized":False,
        "application_acceptance_adjudicated":False,
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":decision,
        "complete":complete,
        "hard_checks":result["hard_checks"],
        "frozen_hypotheses":result["frozen_hypotheses"],
        "case_summary":case_summary,
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())