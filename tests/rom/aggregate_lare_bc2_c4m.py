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
    assert pre["phase"]=="PREREGISTERED_AFTER_C4L_BEFORE_INTERNAL_SLOPE_CORRECTION_REVIEW"
    assert pre["pre_execution_operationalisation"]["before_first_C4M_execution"] is True

    cases={}
    for p in sorted(args.case_dir.glob("*.json")):
        r=json.loads(p.read_text())
        if r.get("schema")!="swap5.lare.bc2.c4m.case-result.v1": continue
        key=(str(r["width_cm"]),r["history"])
        if key in cases: raise SystemExit(f"duplicate case {key}")
        cases[key]=r
    expected={(w,h) for w in WIDTHS for h in HISTORIES}
    if set(cases)!=expected:
        raise SystemExit(f"case set mismatch missing={sorted(expected-set(cases))} extra={sorted(set(cases)-expected)}")

    blocked=[]; supported=[]; unsupported=[]; summary={}
    max_qiid=0.0; max_qhid=0.0; max_hydro=0.0; min_k=float("inf"); all_repro=True
    for w,h in sorted(expected):
        r=cases[(w,h)]; hc=r["hard_checks"]
        max_qiid=max(max_qiid,float(hc["max_B8_qi_identity_cm_per_day"]))
        max_qhid=max(max_qhid,float(hc["max_qH_central_vs_B9_identity_cm_per_day"]))
        max_hydro=max(max_hydro,float(hc["central_hydrostatic_abs_slope_minus_1"]))
        min_k=min(min_k,float(hc["minimum_interface_K_cm_per_day"]))
        all_repro &= bool(hc["C4L_cubic_metrics_reproduced"])
        if r["decision"]=="C4M_CASE_BLOCKED": blocked.append((w,h))
        elif r["decision"]=="C4M_CASE_SUPPORTED": supported.append((w,h))
        else: unsupported.append((w,h))
        summary.setdefault(w,{})[h]={
          "decision":r["decision"],"qi":r["qi"],"slope_error":r["slope_error"],
          "correction_geometry":r["correction_geometry"],
          "endpoint_slope_diagnostics":r["endpoint_slope_diagnostics"],
          "hard_checks":hc
        }

    hard_ok=(
      not blocked
      and max_qiid<=float(pre["hard_gates"]["B8_qi_identity_cm_per_day"])
      and max_qhid<=float(pre["hard_gates"]["qH_central_vs_B9_identity_cm_per_day"])
      and max_hydro<=float(pre["hard_gates"]["central_hydrostatic_abs_slope_minus_1"])
      and min_k>0.0 and all_repro
    )
    moving={(w,h) for w in WIDTHS for h in ("WT_RISE","WT_FALL")}
    hold={(w,"WT_HOLD") for w in WIDTHS}
    moving_all=hard_ok and moving.issubset(set(supported))
    hold_all=hard_ok and hold.issubset(set(supported))
    if not hard_ok:
        decision="C4M_DIAGNOSTIC_BLOCKED"
    elif moving_all and hold_all:
        decision="CENTRAL_INTERFACE_GRADIENT_STATIC_CANDIDATE_SUPPORTED"
    elif moving_all:
        decision="CENTRAL_INTERFACE_GRADIENT_MOVING_ONLY"
    else:
        decision="CENTRAL_INTERFACE_GRADIENT_MIXED"

    result={
      "schema":"swap5.lare.bc2.c4m.result.v1","workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C4M",
      "decision":decision,"complete":True,
      "hard_checks":{
        "maximum_B8_qi_identity_cm_per_day":max_qiid,
        "maximum_qH_central_vs_B9_identity_cm_per_day":max_qhid,
        "maximum_central_hydrostatic_abs_slope_minus_1":max_hydro,
        "minimum_interface_K_cm_per_day":min_k,
        "all_C4L_cubic_metrics_reproduced":all_repro
      },
      "supported_cases":[{"width_cm":w,"history":h} for w,h in supported],
      "unsupported_cases":[{"width_cm":w,"history":h} for w,h in unsupported],
      "blocked_cases":[{"width_cm":w,"history":h} for w,h in blocked],
      "summary":summary,
      "interpretation":[
        "C4M compares the parameter-free central piecewise-linear interface gradient with the B9 terminal baseline and the C4L cubic on identical Reference-projected states.",
        "All primary slope comparisons use the preregistered exact interval-effective q=Kbar*(1-s) identity; arithmetic endpoint slopes are secondary only.",
        "The central candidate changes only qi. Its interface K and qH remain those of B9.",
        "Cubic response is recomputed only as a mechanism comparator and must reproduce the persisted post-repair C4L authority before interpretation.",
        "No static result authorizes propagated dynamics."
      ],
      "next_authority":(
        "PREREGISTER_PROPAGATED_CENTRAL_GRADIENT_DYNAMICS"
        if decision=="CENTRAL_INTERFACE_GRADIENT_STATIC_CANDIDATE_SUPPORTED"
        else "MECHANISM_REVIEW_BEFORE_ANY_PROPAGATION"
      ),
      "propagated_dynamics_authorized":False,"next_model_change_authorized":False,
      "groundwater_feedback_authorized":False,"application_acceptance_adjudicated":False,
      "speed_claim_authorized":False,"production_rom_authorized":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"hard_checks":result["hard_checks"],
                      "supported_cases":result["supported_cases"],
                      "unsupported_cases":result["unsupported_cases"],
                      "blocked_cases":result["blocked_cases"]},sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
