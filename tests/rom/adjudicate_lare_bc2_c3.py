#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib

DYNAMIC_CASES=(
    ("2.5","WT_RISE"),("2.5","WT_FALL"),("2.5","WT_CYCLE"),
    ("5.0","WT_RISE"),("5.0","WT_FALL"),("5.0","WT_CYCLE"),
)
PRIMARY="0.00005000"
CROSS="0.00002500"

def main() -> int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--c3",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    c3=json.loads(args.c3.read_text())
    pre=json.loads(args.prereg.read_text())

    assert pre["phase"]=="PREREGISTERED_AFTER_HOLD_CONTROL_EXPOSURE_BEFORE_DYNAMIC_C3_RESULT_EXPOSURE"
    assert pre["exposure_firewall"]["dynamic_cases_observed_before_rule"] is False
    assert pre["ranking_metric"]=="cumulative_injection_shape_rms_theta_at_final_geometry"
    assert c3["schema"]=="swap5.lare.bc2.c3.result.v1"

    hard_complete=(
        c3.get("complete") is True
        and c3.get("decision")=="BC2_C3_SIGNED_LOCAL_BIAS_LEDGER_MAPPED"
        and c3["hard_checks"]["failure_count"]==0
        and c3["hard_checks"]["maximum_recorded_hard_residual_or_identity_error"]
            <= c3["hard_checks"]["gate"]
        and c3["hard_checks"]["all_case_primary_and_cross_routes_qualified"] is True
    )

    dynamic={}
    primary_tops=[]
    cross_tops=[]
    rank1_mismatches=[]
    missing=[]

    for width,history in DYNAMIC_CASES:
        try:
            case=c3["cases"][width][history]
            pr=case["routes"][PRIMARY]["family_rank_by_cumulative_shape_injection"]
            cr=case["routes"][CROSS]["family_rank_by_cumulative_shape_injection"]
        except (KeyError,TypeError,IndexError):
            missing.append(f"{width}:{history}")
            continue
        ptop=pr[0]
        ctop=cr[0]
        primary_tops.append(ptop)
        cross_tops.append(ctop)
        mismatch=ptop!=ctop
        if mismatch:
            rank1_mismatches.append(f"{width}:{history}")
        dynamic[f"{width}:{history}"]={
            "primary_rank":pr,
            "cross_rank":cr,
            "primary_top":ptop,
            "cross_top":ctop,
            "rank1_match":not mismatch,
        }

    all_cases_present=len(dynamic)==len(DYNAMIC_CASES) and not missing
    same_primary=len(set(primary_tops))==1 if primary_tops else False
    same_cross=len(set(cross_tops))==1 if cross_tops else False
    same_family_across_routes=(
        same_primary and same_cross
        and primary_tops[0]==cross_tops[0]
        and not rank1_mismatches
    )
    global_supported=hard_complete and all_cases_present and same_family_across_routes

    if not hard_complete or not all_cases_present:
        decision="NUMERICAL_DIAGNOSTIC_BLOCKED"
        selected=None
        c4_authority="NO_MODEL_CHANGE"
    elif global_supported:
        decision="GLOBAL_SINGLE_FAMILY_SUPPORTED"
        selected=primary_tops[0]
        c4_authority="GLOBAL_SURGICAL_TEACHER_FORCED_C4_PERMITTED_FOR_SELECTED_FAMILY_ONLY"
    else:
        decision="REGIME_DEPENDENT_BIAS_INJECTION"
        selected=None
        c4_authority="NO_GLOBAL_CLOSURE_CHANGE_NEW_REGIME_PREREGISTRATION_REQUIRED"

    result={
        "schema":"swap5.lare.bc2.c3a.adjudication.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C3A",
        "decision":decision,
        "complete":hard_complete and all_cases_present,
        "frozen_rule_source":"integration/f-rom/LARE_BC2_C3_ADJUDICATION_PREREGISTRATION.json",
        "dynamic_cases":dynamic,
        "checks":{
            "c3_hard_complete":hard_complete,
            "all_six_dynamic_cases_present":all_cases_present,
            "missing_cases":missing,
            "same_primary_top_family_all_dynamic":same_primary,
            "same_cross_top_family_all_dynamic":same_cross,
            "primary_cross_rank1_mismatch_cases":rank1_mismatches,
            "unanimous_same_family_both_routes":same_family_across_routes,
        },
        "selected_global_family":selected,
        "c4_authority":c4_authority,
        "interpretation":[
            "The decision implements the prospectively frozen unanimity rule; no effect-size threshold, top-k substitution or majority fallback is introduced.",
            "HOLD is excluded from dynamic-family selection exactly as preregistered.",
            "REGIME_DEPENDENT_BIAS_INJECTION forbids a global closure correction and requires a separately preregistered regime partition before any counterfactual."
        ],
        "next_model_change_authorized":False,
        "groundwater_feedback_authorized":False,
        "application_acceptance_adjudicated":False,
        "production_rom_authorized":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":decision,
        "complete":result["complete"],
        "selected_global_family":selected,
        "checks":result["checks"],
        "c4_authority":c4_authority,
    },sort_keys=True))
    return 0 if result["complete"] else 2

if __name__=="__main__":
    raise SystemExit(main())
