#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib

WIDTHS=("2.5","5.0")

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--case-dir",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()
    cases={}
    for path in sorted(args.case_dir.glob("*.json")):
        p=json.loads(path.read_text())
        if p.get("schema")!="swap5.lare.bc2.c3b.case-result.v1":
            continue
        key=str(p["width_cm"])
        if key in cases:
            raise SystemExit(f"duplicate width {key}")
        cases[key]=p
    if set(cases)!=set(WIDTHS):
        raise SystemExit(f"C3B widths mismatch {sorted(cases)}")
    complete=all(p["complete"] for p in cases.values())
    decisions={w:cases[w]["decision"] for w in WIDTHS}
    if not complete:
        decision="NUMERICAL_DIAGNOSTIC_BLOCKED"
    elif all(v=="DIRECTION_PARTITION_EXPLAINS_CYCLE_RANK_SHIFT" for v in decisions.values()):
        decision="DIRECTION_PARTITION_EXPLAINS_CYCLE_RANK_SHIFT"
    else:
        decision="WITHIN_DIRECTION_REGIME_DEPENDENCE_REMAINS"
    max_hard=0.0
    for p in cases.values():
        for route in p["routes"].values():
            max_hard=max(max_hard,float(route["hard_checks"]["maximum"]))
    result={
        "schema":"swap5.lare.bc2.c3b.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C3B",
        "decision":decision,
        "complete":complete,
        "width_decisions":decisions,
        "cases":cases,
        "hard_checks":{
            "maximum_recorded_hard_residual_or_identity_error":max_hard,
            "gate":1.0e-10,
            "all_widths_both_routes_qualified":complete,
        },
        "interpretation":[
            "The cycle is partitioned only by exact Hdot sign using preregistered A2 geometry.",
            "No closure, state, fitted threshold or oracle intervention is introduced.",
            "A positive decision supports direction-dependent signed accumulation as the explanation for the full-cycle rank shift.",
            "A negative qualified decision retains finer within-direction or phase dependence."
        ],
        "next_step_rule":(
            "A positive decision may authorize a newly preregistered teacher-forced causal oracle panel within fixed Hdot-sign regimes; it does not authorize a direction-switched deployable closure."
            if decision=="DIRECTION_PARTITION_EXPLAINS_CYCLE_RANK_SHIFT"
            else "Do not simplify the regime partition to Hdot sign alone."
        ),
        "model_changed":False,
        "next_model_change_authorized":False,
        "oracle_counterfactual_executed":False,
        "groundwater_feedback_authorized":False,
        "application_acceptance_adjudicated":False,
        "production_rom_authorized":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "schema":result["schema"],
        "decision":decision,
        "width_decisions":decisions,
        "hard_checks":result["hard_checks"],
        "block_tops":{
            w:{
                route:[
                    {
                        "steps":b["steps"],
                        "regime":b["regime"],
                        "top":b["family_rank_by_cumulative_shape_injection"][0]
                    } for b in cases[w]["routes"][route]["blocks"]
                ] for route in sorted(cases[w]["routes"])
            } for w in WIDTHS
        }
    },sort_keys=True))
    return 0 if complete else 2

if __name__=="__main__":
    raise SystemExit(main())
