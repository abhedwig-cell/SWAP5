#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib

WIDTHS=("2.5","5.0")
HISTORIES=("WT_RISE","WT_FALL")
ROUTES=("0.00005000","0.00002500")

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--case-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    assert pre["phase"]=="PREREGISTERED_AFTER_C3B_C4D_BEFORE_LOCAL_QI_CAUSAL_COUNTERFACTUAL"
    cases={}
    for path in sorted(args.case_dir.glob("*.json")):
        p=json.loads(path.read_text())
        if p.get("schema")!="swap5.lare.bc2.c4e.case-result.v1":
            continue
        key=(str(p["width_cm"]),p["history"])
        if key in cases:
            raise SystemExit(f"duplicate C4E case {key}")
        cases[key]=p

    expected={(w,h) for w in WIDTHS for h in HISTORIES}
    if set(cases)!=expected:
        raise SystemExit(f"C4E case set mismatch: {sorted(cases)}")

    complete=all(p["complete"] for p in cases.values())
    hardmax=0.0
    all_rank_match=True
    all_qi_unique=True
    all_qi_improves=True
    any_blocked=False
    summary={}

    for w in WIDTHS:
        summary[w]={}
        for h in HISTORIES:
            p=cases[(w,h)]
            all_rank_match &= bool(p["primary_cross_removal_rank_match"])
            summary[w][h]={}
            for route in ROUTES:
                rr=p["routes"][route]
                hardmax=max(hardmax,max(float(v) for k,v in rr["hard_checks"].items() if k!="gate"))
                any_blocked |= rr["decision"]=="CASE_DIAGNOSTIC_BLOCKED"
                all_qi_unique &= bool(rr["QI_unique_best_single_family_removal"])
                all_qi_improves &= bool(rr["QI_strictly_improves_BASE"])
                b=float(rr["variants"]["BASE"]["pooled_rms_shape_error_theta"])
                q=float(rr["variants"]["REMOVE_QI"]["pooled_rms_shape_error_theta"])
                summary[w][h][route]={
                    "case_decision":rr["decision"],
                    "rank":rr["single_family_removal_rank_by_pooled_shape_error"],
                    "BASE_pooled_rms_shape_error_theta":b,
                    "REMOVE_QI_pooled_rms_shape_error_theta":q,
                    "QI_shape_error_ratio_to_BASE":None if b==0.0 else q/b,
                    "QI_fraction_intervals_improved":rr["variants"]["REMOVE_QI"]["fraction_intervals_lower_shape_error_than_BASE"],
                    "all_single_family_controls_admissible":rr["all_single_family_controls_admissible"]
                }

    gate=float(pre["hard_gates"]["additive_identity_cm"])
    if not complete or hardmax>gate or any_blocked:
        decision="QI_LOCAL_CAUSAL_DIAGNOSTIC_BLOCKED"
    elif not all_rank_match:
        decision="QI_LOCAL_CAUSAL_MIXED"
    elif all_qi_unique and all_qi_improves:
        decision="QI_LOCAL_CAUSAL_SUPPORT"
    elif all_qi_improves:
        decision="QI_LOCAL_CAUSAL_MIXED"
    else:
        decision="QI_LOCAL_CAUSAL_NOT_SUPPORTED"

    result={
        "schema":"swap5.lare.bc2.c4e.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C4E",
        "decision":decision,
        "complete":complete,
        "summary":summary,
        "cases":{f"{w}:{h}":cases[(w,h)] for w,h in sorted(cases)},
        "hard_checks":{
            "maximum_recorded_hard_residual_or_identity_error":hardmax,
            "gate":gate,
            "all_cases_complete":complete,
            "all_primary_cross_removal_rank_match":all_rank_match,
            "all_QI_counterfactuals_strictly_improve_BASE":all_qi_improves,
            "all_QI_counterfactuals_unique_best":all_qi_unique,
            "any_counterfactual_comparison_blocked":any_blocked
        },
        "interpretation":[
            "C4E is a one-interval teacher-forced endpoint counterfactual. No counterfactual state is propagated.",
            "A positive result means QI local bias is the uniquely strongest single-family causal contributor to monotone-phase endpoint shape error under the frozen additive C3 decomposition.",
            "A positive result does not prove that direct QI flux substitution is stable or physically admissible in a free-running reduced model.",
            "C4B remains authoritative evidence that direct free-running oracle substitution may leave the qualified domain.",
            "Any next model hypothesis must alter a physically admissible terminal-profile/QI reconstruction rather than inject an arbitrary corrective flux."
        ],
        "next_model_change_authorized":False,
        "model_changed":False,
        "counterfactual_propagated":False,
        "groundwater_feedback_authorized":False,
        "application_acceptance_adjudicated":False,
        "production_rom_authorized":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "schema":result["schema"],
        "decision":decision,
        "hard_checks":result["hard_checks"],
        "summary":summary
    },sort_keys=True))
    return 0 if complete and hardmax<=gate else 2

if __name__=="__main__":
    raise SystemExit(main())
