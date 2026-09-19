#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib

WIDTHS=("2.5","5.0")
PRED=("P_FACE","P_BOUNDARY","P_INTERACTION")

def dominates(a,b,c):
    return a["signed_cosine"]>b["signed_cosine"] and a["signed_cosine"]>c["signed_cosine"] and a["same_sign_fraction"]>b["same_sign_fraction"] and a["same_sign_fraction"]>c["same_sign_fraction"]

def at_least(a,b,c):
    return a["signed_cosine"]>=b["signed_cosine"] and a["signed_cosine"]>=c["signed_cosine"] and a["same_sign_fraction"]>=b["same_sign_fraction"] and a["same_sign_fraction"]>=c["same_sign_fraction"]

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--case-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()
    pre=json.loads(args.prereg.read_text())
    assert pre["phase"]=="PREREGISTERED_AFTER_C4N_BEFORE_EXISTING_STATE_CONDITIONER_MAP"

    cases={}
    for p in sorted(args.case_dir.glob("*.json")):
        r=json.loads(p.read_text())
        if r.get("schema")!="swap5.lare.bc2.c4o.width-result.v1": continue
        cases[str(r["width_cm"])]=r
    if set(cases)!=set(WIDTHS):
        raise SystemExit(f"width set mismatch {set(cases)}")

    hard=all(cases[w]["hard_pass"] for w in WIDTHS)
    if not hard:
        decision="C4O_DIAGNOSTIC_BLOCKED"
    else:
        inter_all=True; face_all=True; bound_all=True
        for w in WIDTHS:
            p=cases[w]["pooled_moving"]
            hold=cases[w]["histories"]["WT_HOLD"]["predictors"]
            inter_all &= dominates(p["P_INTERACTION"],p["P_FACE"],p["P_BOUNDARY"]) and hold["P_INTERACTION"]["predictor_rms"]<hold["P_FACE"]["predictor_rms"]
            face_all &= at_least(p["P_FACE"],p["P_BOUNDARY"],p["P_INTERACTION"])
            bound_all &= at_least(p["P_BOUNDARY"],p["P_FACE"],p["P_INTERACTION"])
        if inter_all:
            decision="FACE_BOUNDARY_INTERACTION_SIGNAL_SUPPORTED"
        elif face_all:
            decision="FACE_GEOMETRY_SIGNAL_REMAINS_STRONGER"
        elif bound_all:
            decision="BOUNDARY_SIGNAL_REMAINS_STRONGER"
        else:
            decision="NO_SINGLE_EXISTING_STATE_CONDITIONER_DOMINATES"

    result={
      "schema":"swap5.lare.bc2.c4o.result.v1",
      "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C4O",
      "decision":decision,"complete":len(cases)==2,
      "widths":cases,
      "interpretation":[
        "C4O is a zero-fit mechanism map over existing B9 state-derived signals.",
        "P_FACE is the C4N geometry-only correction signal; P_BOUNDARY is B9 lower-boundary disequilibrium; P_INTERACTION is their response-blind product.",
        "The decision compares signed cosine and sign agreement only; no response-dependent coefficient, sign flip or classifier is fitted.",
        "No C4O outcome authorizes a closure or propagated dynamics."
      ],
      "next_authority":(
        "PREREGISTER_PARAMETER_FREE_FACE_BOUNDARY_INTERACTION_CANDIDATE"
        if decision=="FACE_BOUNDARY_INTERACTION_SIGNAL_SUPPORTED"
        else "RETURN_TO_REPRESENTATION_SELECTION_NO_SIMPLE_CONDITIONER"
      ),
      "closure_authorized":False,
      "propagated_dynamics_authorized":False,
      "next_model_change_authorized":False,
      "groundwater_feedback_authorized":False,
      "application_acceptance_adjudicated":False,
      "speed_claim_authorized":False,
      "production_rom_authorized":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "decision":decision,
      "width_summary":{w:{
        "hard_pass":cases[w]["hard_pass"],
        "pooled_moving":cases[w]["pooled_moving"],
        "hold_predictor_rms":{p:cases[w]["histories"]["WT_HOLD"]["predictors"][p]["predictor_rms"] for p in PRED},
        "state_context":{h:cases[w]["histories"][h]["state_context"] for h in ("WT_HOLD","WT_RISE","WT_FALL")}
      } for w in WIDTHS}
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
