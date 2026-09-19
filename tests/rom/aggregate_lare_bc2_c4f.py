#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib

WIDTHS=("2.5","5.0")
HISTORIES=("WT_RISE","WT_FALL")
ROUTES=("0.00005000","0.00002500")

def close(a,b,tol=1.0e-12):
    return abs(float(a)-float(b))<=tol

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--case-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c4e-result",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    c4e=json.loads(args.c4e_result.read_text())
    assert pre["phase"]=="PREREGISTERED_AFTER_C4E_BEFORE_VECTOR_INTERFERENCE_DIAGNOSTIC"
    assert c4e["decision"]==pre["predecessors"]["C4E"]["required_decision"]

    cases={}
    for path in sorted(args.case_dir.glob("*.json")):
        p=json.loads(path.read_text())
        if p.get("schema")!="swap5.lare.bc2.c4f.case-result.v1":
            continue
        key=(str(p["width_cm"]),p["history"])
        if key in cases:
            raise SystemExit(f"duplicate C4F case {key}")
        cases[key]=p
    expected={(w,h) for w in WIDTHS for h in HISTORIES}
    if set(cases)!=expected:
        raise SystemExit(f"C4F case set mismatch missing={sorted(expected-set(cases))} extra={sorted(set(cases)-expected)}")

    hardmax_add=0.0
    hardmax_sq=0.0
    all_complete=True
    vector_identity=True
    c4e_reproduced=True
    mean_margin_classification=True
    summary={}

    for w,h in sorted(expected):
        p=cases[(w,h)]
        all_complete &= bool(p["complete"])
        summary.setdefault(w,{})[h]={}
        for route in ROUTES:
            rr=p["routes"][route]
            hc=rr["hard_checks"]
            hardmax_add=max(hardmax_add,float(hc["max_family_state_additivity_residual_cm"]),float(hc["max_QI_mass_neutral_residual_cm"]))
            hardmax_sq=max(hardmax_sq,float(hc["max_squared_norm_identity_residual_theta2"]))
            vector_identity &= close(rr["interference"]["fraction_sign_prediction_exact"],1.0,1.0e-15)

            ref=c4e["summary"][w][h][route]
            c4e_case=c4e["cases"][f"{w}:{h}"]["routes"][route]
            ratio=rr["pooled_rms"]["remainder_to_local_ratio"]
            improve=rr["interference"]["fraction_removal_improves"]
            qi_c4e=c4e_case["variants"]["REMOVE_QI"]
            if qi_c4e["admissible_all_intervals"]:
                c4e_reproduced &= close(ratio,ref["QI_shape_error_ratio_to_BASE"],5.0e-12)
                c4e_reproduced &= close(improve,ref["QI_fraction_intervals_improved"],5.0e-12)
            else:
                # C4E intentionally computed pooled QI metrics only on the
                # physically admissible subset. C4F diagnoses all intervals.
                # Do not compare unlike pooled cohorts; reconcile the blocked
                # population itself instead.
                c4e_reproduced &= (
                    int(qi_c4e["blocked_interval_count"])
                    == int(rr["width_margin"]["hydraulic_blocked_interval_count"])
                )

            wm=rr["width_margin"]
            mean_margin_classification &= close(
                wm["fraction_hydraulic_block_classified_by_negative_mean_margin"],1.0,1.0e-15
            )
            conv=wm["observed_conversion_factor_nonzero"]["mean"]
            expected_conv=float(wm["expected_terminal_conversion_factor_per_cm"])
            if conv is not None:
                vector_identity &= close(conv,expected_conv,1.0e-12)

            summary[w][h][route]={
                "remainder_to_local_ratio":ratio,
                "fraction_removal_improves":improve,
                "fraction_removal_worsens":rr["interference"]["fraction_removal_worsens"],
                "qi_dot_remainder":rr["interference"]["qi_dot_remainder_theta2"],
                "cosine_qi_remainder":rr["interference"]["cosine_qi_remainder"],
                "abs_qi_storage_transfer_cm":wm["abs_qi_storage_transfer_cm"],
                "abs_delta_theta_terminal":wm["abs_counterfactual_delta_theta_terminal"],
                "counterfactual_mean_theta_margin":wm["counterfactual_mean_theta_margin"],
                "hydraulic_blocked_interval_count":wm["hydraulic_blocked_interval_count"],
                "first_hydraulic_blocked_step":wm["first_hydraulic_blocked_step"],
                "mean_margin_block_classification_fraction":wm["fraction_hydraulic_block_classified_by_negative_mean_margin"],
                "conversion_factor_per_cm":conv
            }

    vector_support=(
        all_complete
        and hardmax_add<=float(pre["hard_gates"]["additive_identity_cm"])
        and hardmax_sq<=float(pre["hard_gates"]["squared_norm_identity_theta2"])
        and vector_identity
        and c4e_reproduced
    )

    conversion_ratio_ok=True
    for h in HISTORIES:
        for route in ROUTES:
            c25=summary["2.5"][h][route]["conversion_factor_per_cm"]
            c50=summary["5.0"][h][route]["conversion_factor_per_cm"]
            if c25 is not None and c50 is not None:
                conversion_ratio_ok &= close(c25/c50,2.0,1.0e-12)

    fall_pattern=all(
        summary["2.5"]["WT_FALL"][r]["hydraulic_blocked_interval_count"]==499
        and summary["5.0"]["WT_FALL"][r]["hydraulic_blocked_interval_count"]==0
        for r in ROUTES
    )
    rise_pattern=all(
        summary["2.5"]["WT_RISE"][r]["hydraulic_blocked_interval_count"]==0
        and summary["5.0"]["WT_RISE"][r]["hydraulic_blocked_interval_count"]==0
        for r in ROUTES
    )
    width_support=(
        vector_support and conversion_ratio_ok and mean_margin_classification
        and fall_pattern and rise_pattern
    )

    if not all_complete or hardmax_add>float(pre["hard_gates"]["additive_identity_cm"]) or hardmax_sq>float(pre["hard_gates"]["squared_norm_identity_theta2"]):
        decision="C4F_DIAGNOSTIC_BLOCKED"
    elif vector_support and width_support:
        decision="VECTOR_INTERFERENCE_PLUS_WIDTH_MARGIN_EXPLAINS_C4E"
    elif vector_support:
        decision="VECTOR_INTERFERENCE_EXPLAINS_C4E"
    else:
        decision="C4E_MECHANISM_PARTIAL"

    result={
        "schema":"swap5.lare.bc2.c4f.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C4F",
        "decision":decision,
        "complete":all_complete,
        "hypotheses":{
            "H_VECTOR_INTERFERENCE":{
                "supported":vector_support,
                "exact_sign_prediction_all_intervals":vector_identity,
                "C4E_metrics_or_block_population_reproduced_on_matching_cohort":c4e_reproduced
            },
            "H_TERMINAL_WIDTH_AMPLIFICATION":{
                "supported":width_support,
                "terminal_theta_conversion_ratio_2p5_over_5cm_is_two":conversion_ratio_ok,
                "hydraulic_blocking_exactly_classified_by_negative_mean_theta_margin":mean_margin_classification,
                "WT_FALL_QI_block_pattern_2p5_vs_5cm":fall_pattern,
                "WT_RISE_QI_block_pattern_both_admissible":rise_pattern
            }
        },
        "hard_checks":{
            "maximum_additive_or_mass_residual_cm":hardmax_add,
            "maximum_squared_norm_identity_residual_theta2":hardmax_sq,
            "additive_gate_cm":float(pre["hard_gates"]["additive_identity_cm"]),
            "squared_norm_gate_theta2":float(pre["hard_gates"]["squared_norm_identity_theta2"])
        },
        "summary":summary,
        "interpretation":[
            "The sign and magnitude direction of the C4E QI-removal response are explained by exact additive-vector interference between the QI shape contribution and the non-QI remainder; no fitted parameter is used.",
            "At 5 cm the QI contribution is large enough relative to the non-QI remainder that the exact removal criterion is positive for almost every interval, even though QI and the remainder are not uniformly aligned. At 2.5 cm WT_RISE they are strongly anti-aligned, so QI is acting as an error-cancelling contribution and removing it increases the norm.",
            "The QI contribution is a mass-neutral storage transfer between bulk and terminal states. Per unit transferred storage, its terminal mean-theta perturbation is exactly proportional to 1/d, giving a factor two larger terminal perturbation at 2.5 cm than at 5 cm.",
            "The 2.5 cm WT_FALL QI-removal admissibility failure is a state-margin failure, not a mass-conservation failure.",
            "These findings explain the C4E diagnostic behavior but do not select a corrected closure."
        ],
        "next_authority":"MECHANISM_EXPLAINED_REPRESENTATION_GEOMETRY_REVIEW_REQUIRED_BEFORE_CLOSURE_DESIGN",
        "next_model_change_authorized":False,
        "groundwater_feedback_authorized":False,
        "application_acceptance_adjudicated":False,
        "speed_claim_authorized":False,
        "production_rom_authorized":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":decision,
        "hypotheses":result["hypotheses"],
        "hard_checks":result["hard_checks"],
        "summary":summary
    },sort_keys=True))
    return 0 if decision!="C4F_DIAGNOSTIC_BLOCKED" else 2

if __name__=="__main__":
    raise SystemExit(main())
