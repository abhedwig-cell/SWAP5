#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib

WIDTHS=("2.5","5.0")
HISTORIES=("WT_HOLD","WT_RISE","WT_FALL")

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--case-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()
    pre=json.loads(args.prereg.read_text())
    assert pre["phase"]=="PREREGISTERED_AFTER_C4K_BEFORE_QH_PRESERVING_CUBIC_RECONSTRUCTION"

    cases={}
    for p in sorted(args.case_dir.glob("*.json")):
        r=json.loads(p.read_text())
        if r.get("schema")!="swap5.lare.bc2.c4l.case-result.v1": continue
        key=(str(r["width_cm"]),r["history"])
        if key in cases: raise SystemExit(f"duplicate case {key}")
        cases[key]=r
    expected={(w,h) for w in WIDTHS for h in HISTORIES}
    if set(cases)!=expected:
        raise SystemExit(f"case set mismatch missing={sorted(expected-set(cases))} extra={sorted(set(cases)-expected)}")

    blocked=[]; unsupported=[]; supported=[]
    max_store=0.0; minpsi=float("inf"); minroots=999; max_qx=0.0; max_qh=0.0; max_qiid=0.0
    summary={}
    for w,h in sorted(expected):
        r=cases[(w,h)]
        hc=r["hard_checks"]
        max_store=max(max_store,float(hc["max_storage_residual_cm"]))
        minpsi=min(minpsi,float(hc["minimum_psi_cm"]))
        minroots=min(minroots,int(hc["minimum_valid_roots"]))
        max_qx=max(max_qx,float(hc["max_qi_64_vs_128_cm_per_day"]))
        max_qh=max(max_qh,float(hc["max_qH_candidate_vs_baseline_cm_per_day"]))
        max_qiid=max(max_qiid,float(hc["max_B8_qi_identity_cm_per_day"]))
        if r["decision"]=="C4L_CASE_BLOCKED": blocked.append((w,h))
        elif r["decision"]=="C4L_CASE_NOT_SUPPORTED": unsupported.append((w,h))
        else: supported.append((w,h))
        summary.setdefault(w,{})[h]={
            "decision":r["decision"],
            "qi_BASE":r["qi"]["BASE"],
            "qi_CUBIC":r["qi"]["CUBIC"],
            "qH_BASE":r["qH"]["BASE"],
            "qH_CUBIC":r["qH"]["CUBIC"],
            "shape":r["shape"],
            "hard_checks":hc
        }

    hard_ok=(
        not blocked
        and max_store<=float(pre["hard_gates"]["storage_residual_cm"])
        and minpsi>=-float(pre["hard_gates"]["psi_nonnegative_tolerance_cm"])
        and minroots>=int(pre["hard_gates"]["minimum_valid_multistart_roots"])
        and max_qx<=float(pre["hard_gates"]["qi_64_vs_128_cm_per_day"])
        and max_qh<=float(pre["hard_gates"]["qH_candidate_vs_B9_identity_cm_per_day"])
        and max_qiid<=float(pre["hard_gates"]["B8_qi_identity_cm_per_day"])
    )

    moving={(w,h) for w in WIDTHS for h in ("WT_RISE","WT_FALL")}
    hold={(w,"WT_HOLD") for w in WIDTHS}
    moving_all=hard_ok and moving.issubset(set(supported))
    hold_all=hard_ok and hold.issubset(set(supported))
    if not hard_ok:
        decision="C4L_RECONSTRUCTION_BLOCKED"
    elif moving_all and hold_all:
        decision="QH_PRESERVING_CUBIC_QI_SUPPORTED"
    elif moving_all:
        decision="QH_PRESERVING_CUBIC_MOVING_ONLY"
    else:
        decision="QH_PRESERVING_CUBIC_MIXED"

    result={
        "schema":"swap5.lare.bc2.c4l.result.v1",
        "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C4L",
        "decision":decision,
        "complete":len(cases)==6,
        "hard_checks":{
            "maximum_storage_residual_cm":max_store,
            "minimum_profile_psi_cm":minpsi,
            "minimum_valid_multistart_roots":minroots,
            "maximum_qi_64_vs_128_cm_per_day":max_qx,
            "maximum_qH_candidate_vs_B9_identity_cm_per_day":max_qh,
            "maximum_B8_qi_identity_cm_per_day":max_qiid
        },
        "supported_cases":[{"width_cm":w,"history":h} for w,h in supported],
        "unsupported_cases":[{"width_cm":w,"history":h} for w,h in unsupported],
        "blocked_cases":[{"width_cm":w,"history":h} for w,h in blocked],
        "summary":summary,
        "interpretation":[
            "C4L preserves the B7/B9 qH terminal slope exactly and changes only the internal qi gradient through curvature inferred from the existing Wb/Wt/H state.",
            "The cubic coefficients are solved only from storage constraints; no flux response enters reconstruction.",
            "Positive support would remain static Reference-state closure evidence and would not authorize propagated dynamics."
        ],
        "next_authority":(
            "PREREGISTER_PROPAGATED_CUBIC_DYNAMICS" if decision=="QH_PRESERVING_CUBIC_QI_SUPPORTED"
            else "MECHANISM_REVIEW_BEFORE_ANY_PROPAGATION"
        ),
        "propagated_dynamics_authorized":False,
        "next_model_change_authorized":False,
        "groundwater_feedback_authorized":False,
        "application_acceptance_adjudicated":False,
        "speed_claim_authorized":False,
        "production_rom_authorized":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"hard_checks":result["hard_checks"],
                      "supported_cases":result["supported_cases"],
                      "unsupported_cases":result["unsupported_cases"],
                      "blocked_cases":result["blocked_cases"]},sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
