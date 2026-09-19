#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib

WIDTHS=("2.5","5.0")
HISTORIES=("WT_RISE","WT_FALL")
ROUTES=("0.00005000","0.00002500")

def close(a,b,tol=5.0e-12):
    return abs(float(a)-float(b))<=tol

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--case-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c4f-result",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    c4f=json.loads(args.c4f_result.read_text())
    assert pre["phase"]=="PREREGISTERED_AFTER_C4F_BEFORE_SECONDARY_METRIC_SENSITIVITY"
    assert c4f["decision"]==pre["predecessors"]["C4F"]["required_decision"]

    cases={}
    for path in sorted(args.case_dir.glob("*.json")):
        p=json.loads(path.read_text())
        if p.get("schema")!="swap5.lare.bc2.c4g.case-result.v1":
            continue
        key=(str(p["width_cm"]),p["history"])
        if key in cases:
            raise SystemExit(f"duplicate C4G case {key}")
        cases[key]=p
    expected={(w,h) for w in WIDTHS for h in HISTORIES}
    if set(cases)!=expected:
        raise SystemExit(f"C4G case set mismatch missing={sorted(expected-set(cases))} extra={sorted(set(cases)-expected)}")

    complete=all(p["complete"] for p in cases.values())
    max_add=0.0
    max_sq=0.0
    c4f_reproduced=True
    summary={}

    for w,h in sorted(expected):
        summary.setdefault(w,{})[h]={}
        for route in ROUTES:
            rr=cases[(w,h)]["routes"][route]
            hc=rr["hard_checks"]
            max_add=max(max_add,float(hc["max_family_state_additivity_residual_cm"]))
            max_sq=max(max_sq,float(hc["max_unweighted_squared_norm_identity_residual_theta2"]),float(hc["max_depth_weighted_squared_norm_identity_residual_theta2"]))
            ref=c4f["summary"][w][h][route]
            c4f_reproduced &= close(rr["unweighted"]["remainder_to_local_ratio"],ref["remainder_to_local_ratio"])
            c4f_reproduced &= close(rr["unweighted"]["fraction_removal_improves"],ref["fraction_removal_improves"])
            summary[w][h][route]={
                "unweighted":rr["unweighted"],
                "depth_weighted":rr["depth_weighted"],
                "fraction_interval_direction_changes_between_metrics":rr["fraction_interval_direction_changes_between_metrics"],
                "C4F_QI_hydraulic_blocked_interval_count":ref["hydraulic_blocked_interval_count"]
            }

    hard_ok=(
        complete and
        max_add<=float(pre["hard_gates"]["additive_identity_cm"]) and
        max_sq<=float(pre["hard_gates"]["squared_norm_identity_theta2"]) and
        c4f_reproduced
    )

    rise_robust=hard_ok and all(
        summary["2.5"]["WT_RISE"][route]["unweighted"]["pooled_direction"]=="WORSENS"
        and summary["2.5"]["WT_RISE"][route]["depth_weighted"]["pooled_direction"]=="WORSENS"
        and summary["5.0"]["WT_RISE"][route]["unweighted"]["pooled_direction"]=="IMPROVES"
        and summary["5.0"]["WT_RISE"][route]["depth_weighted"]["pooled_direction"]=="IMPROVES"
        for route in ROUTES
    )

    if not hard_ok:
        decision="C4G_DIAGNOSTIC_BLOCKED"
    elif rise_robust:
        decision="WIDTH_EFFECT_ROBUST_TO_DEPTH_WEIGHTING"
    else:
        decision="WIDTH_EFFECT_METRIC_SENSITIVE"

    result={
        "schema":"swap5.lare.bc2.c4g.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C4G",
        "decision":decision,
        "complete":complete,
        "historical_primary_metric_unchanged":True,
        "C4F_unweighted_metrics_reproduced":c4f_reproduced,
        "WT_RISE_width_effect_robust":rise_robust,
        "hard_checks":{
            "maximum_additive_residual_cm":max_add,
            "maximum_squared_norm_identity_residual_theta2":max_sq,
            "additive_gate_cm":float(pre["hard_gates"]["additive_identity_cm"]),
            "squared_norm_gate_theta2":float(pre["hard_gates"]["squared_norm_identity_theta2"])
        },
        "summary":summary,
        "interpretation":[
            "C4G is a secondary metric-sensitivity analysis. It does not replace or revise the preregistered unweighted C2/C3/C4E shape metric.",
            "The depth-weighted norm reduces the leverage of a thin terminal coordinate relative to the historical equal-coordinate norm.",
            "If the 2.5-versus-5 cm WT_RISE removal direction survives this reweighting, the width dependence cannot be dismissed as an equal-coordinate RMS artifact.",
            "For 2.5 cm WT_FALL, algebraic weighted metrics over all intervals are diagnostic only because C4F showed that the QI-removal counterfactual is physically inadmissible on 499 intervals."
        ],
        "next_authority":"PHYSICALLY_ADMISSIBLE_TERMINAL_RECONSTRUCTION_HYPOTHESIS_MAY_BE_PREREGISTERED" if rise_robust else "METRIC_DEPENDENCE_MUST_BE_RESOLVED_BEFORE_CLOSURE_DESIGN",
        "next_model_change_authorized":False,
        "groundwater_feedback_authorized":False,
        "application_acceptance_adjudicated":False,
        "speed_claim_authorized":False,
        "production_rom_authorized":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":decision,
        "C4F_unweighted_metrics_reproduced":c4f_reproduced,
        "WT_RISE_width_effect_robust":rise_robust,
        "hard_checks":result["hard_checks"],
        "summary":summary
    },sort_keys=True))
    return 0 if decision!="C4G_DIAGNOSTIC_BLOCKED" else 2

if __name__=="__main__":
    raise SystemExit(main())
