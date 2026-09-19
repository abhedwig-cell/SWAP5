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
    assert pre["phase"]=="PREREGISTERED_AFTER_C4M_BEFORE_FACE_INTERPOLATED_GRADIENT_TEST"
    assert pre["pre_execution_operationalisation"]["before_first_C4N_execution"] is True

    cases={}
    for p in sorted(args.case_dir.glob("*.json")):
        r=json.loads(p.read_text())
        if r.get("schema")!="swap5.lare.bc2.c4n.case-result.v1": continue
        key=(str(r["width_cm"]),r["history"])
        if key in cases: raise SystemExit(f"duplicate case {key}")
        cases[key]=r
    expected={(w,h) for w in WIDTHS for h in HISTORIES}
    if set(cases)!=expected:
        raise SystemExit(f"case mismatch missing={sorted(expected-set(cases))} extra={sorted(set(cases)-expected)}")

    blocked=[]; supported=[]; unsupported=[]; summary={}
    max_qiid=0.0; max_qhid=0.0; min_kr=float("inf"); min_ki=float("inf"); max_hydro=0.0
    for w,h in sorted(expected):
        r=cases[(w,h)]; hc=r["hard_checks"]
        max_qiid=max(max_qiid,float(hc["max_B8_qi_identity_cm_per_day"]))
        max_qhid=max(max_qhid,float(hc["max_qH_candidate_vs_B9_identity_cm_per_day"]))
        min_kr=min(min_kr,float(hc["minimum_reference_K_cm_per_day"]))
        min_ki=min(min_ki,float(hc["minimum_candidate_K_cm_per_day"]))
        max_hydro=max(max_hydro,float(hc["max_hydrostatic_abs_slope_minus_1"]))
        if r["decision"]=="C4N_CASE_BLOCKED": blocked.append((w,h))
        elif r["decision"]=="C4N_CASE_SUPPORTED": supported.append((w,h))
        else: unsupported.append((w,h))
        summary.setdefault(w,{})[h]={
            "decision":r["decision"],"qi":r["qi"],"slope_error":r["slope_error"],
            "correction_geometry":r["correction_geometry"],"hard_checks":hc
        }

    hard_ok=(
        not blocked
        and max_qiid<=float(pre["hard_gates"]["B8_qi_identity_cm_per_day"])
        and max_qhid<=float(pre["hard_gates"]["qH_candidate_vs_B9_identity_cm_per_day"])
        and min_kr>0.0 and min_ki>0.0
        and max_hydro<=float(pre["hard_gates"]["hydrostatic_abs_slope_minus_1"])
    )
    moving={(w,h) for w in WIDTHS for h in ("WT_RISE","WT_FALL")}
    holds={(w,"WT_HOLD") for w in WIDTHS}
    moving_all=hard_ok and moving.issubset(set(supported))
    hold_all=hard_ok and holds.issubset(set(supported))
    if not hard_ok:
        decision="C4N_DIAGNOSTIC_BLOCKED"
    elif moving_all and hold_all:
        decision="FACE_INTERPOLATED_GRADIENT_STATIC_CANDIDATE_SUPPORTED"
    elif moving_all:
        decision="FACE_INTERPOLATED_GRADIENT_MOVING_ONLY"
    else:
        decision="FACE_INTERPOLATED_GRADIENT_MIXED"

    result={
        "schema":"swap5.lare.bc2.c4n.result.v1",
        "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C4N",
        "decision":decision,"complete":len(cases)==6,
        "hard_checks":{
            "maximum_B8_qi_identity_cm_per_day":max_qiid,
            "maximum_qH_candidate_vs_B9_identity_cm_per_day":max_qhid,
            "minimum_reference_K_cm_per_day":min_kr,
            "minimum_candidate_K_cm_per_day":min_ki,
            "maximum_hydrostatic_abs_slope_minus_1":max_hydro
        },
        "supported_cases":[{"width_cm":w,"history":h} for w,h in supported],
        "unsupported_cases":[{"width_cm":w,"history":h} for w,h in unsupported],
        "blocked_cases":[{"width_cm":w,"history":h} for w,h in blocked],
        "summary":summary,
        "interpretation":[
            "C4N tests an opposite-distance face interpolation of the two B9 one-sided slope proxies. The geometry weight is fixed before response inspection.",
            "Interface K and qH are exactly the B9 values; only qi gradient amplitude changes.",
            "No C4L cubic replay is required, so the C4M comparator reproducibility blocker is absent by construction.",
            "No static result authorizes propagated dynamics."
        ],
        "next_authority":(
            "PREREGISTER_PROPAGATED_FACE_INTERPOLATED_DYNAMICS"
            if decision=="FACE_INTERPOLATED_GRADIENT_STATIC_CANDIDATE_SUPPORTED"
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
    print(json.dumps({
        "decision":decision,"hard_checks":result["hard_checks"],
        "supported_cases":result["supported_cases"],
        "unsupported_cases":result["unsupported_cases"],
        "blocked_cases":result["blocked_cases"],
        "summary":{w:{h:{
            "decision":summary[w][h]["decision"],
            "qi_BASE":summary[w][h]["qi"]["BASE"],
            "qi_FACE":summary[w][h]["qi"]["FACE"],
            "slope_BASE":summary[w][h]["slope_error"]["BASE"],
            "slope_FACE":summary[w][h]["slope_error"]["FACE"],
            "correction":summary[w][h]["correction_geometry"]
        } for h in HISTORIES} for w in WIDTHS}
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
