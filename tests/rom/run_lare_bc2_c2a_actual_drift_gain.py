#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import pathlib
import statistics

import numpy as np

HERE=pathlib.Path(__file__).resolve().parent

def load_module(name,filename):
    spec=importlib.util.spec_from_file_location(name,HERE/filename)
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

c1=load_module("bc2c1","analyze_lare_bc2_c1_teacher_forced.py")
c0=c1.c0

WIDTHS=(2.5,5.0)
DT=0.00005
FLOOR=1.0e-12
GATE=1.0e-10
NFIXED=c0.NFIXED
IDX_WB=c0.IDX_WB
IDX_WT=c0.IDX_WT
IDX_CUM_QH=c0.IDX_CUM_QH
IDX_CUM_QI=c0.IDX_CUM_QI
PHYS_N=NFIXED+2
OBS_DT=c0.OBS_DT
THETA_S=c0.THETA_S
FIXED_DZ=c0.FIXED_DZ
ANCHOR=c0.ANCHOR

def rms(v):
    a=np.asarray(v,dtype=float)
    return float(np.sqrt(np.mean(a*a)))

def percentile(values,q):
    if not values:
        return None
    return float(np.percentile(np.asarray(values,dtype=float),q))

def shape_coord(y,H,d):
    B=H-ANCHOR-d
    if B<=0:
        raise ValueError("OUTSIDE_QUALIFIED_DOMAIN nonpositive bulk thickness")
    fixed=np.asarray(y[:NFIXED],dtype=float)/FIXED_DZ
    return np.concatenate([fixed,[float(y[IDX_WB])/B,float(y[IDX_WT])/d]])

def finite_reference(y,p,U):
    vals=np.concatenate([
        np.asarray(y[:PHYS_N],dtype=float),
        np.asarray([p["H"],U],dtype=float)
    ])
    return bool(np.all(np.isfinite(vals)))

def run_case(history,d,dt,init_meta,init_nodes,states,nodes):
    yfree,p0,U0=c1.exact_reference_state(
        history,0,d,init_meta,init_nodes,states,nodes
    )
    if not finite_reference(yfree,p0,U0):
        raise RuntimeError("NONFINITE_REFERENCE_PROJECTION_INITIAL")
    Hinitial=float(p0["H"])
    cum_free_qH=0.0
    rows=[]
    max_ledger=0.0
    max_iter=0

    for step in range(1,c0.HISTORY_STEPS[history]+1):
        yref0,pref0,Uref0=c1.exact_reference_state(
            history,step-1,d,init_meta,init_nodes,states,nodes
        )
        yref1,pref1,Uref1=c1.exact_reference_state(
            history,step,d,init_meta,init_nodes,states,nodes
        )
        if not finite_reference(yref0,pref0,Uref0) or not finite_reference(yref1,pref1,Uref1):
            raise RuntimeError("NONFINITE_REFERENCE_PROJECTION")

        H0=float(pref0["H"]); H1=float(pref1["H"])
        start_err=shape_coord(yfree,H0,d)-shape_coord(yref0,H0,d)
        start_norm=rms(start_err)

        teacher=c1.advance_interval(yref0,H0,H1,dt,d)
        free=c1.advance_interval(yfree,H0,H1,dt,d)
        max_iter=max(max_iter,teacher["max_corrector_iterations"],free["max_corrector_iterations"])

        teacher_coord=shape_coord(teacher["y"],H1,d)
        free_coord=shape_coord(free["y"],H1,d)
        ref_coord=shape_coord(yref1,H1,d)

        propagated=free_coord-teacher_coord
        local=teacher_coord-ref_coord
        total=free_coord-ref_coord
        prop_norm=rms(propagated)
        local_norm=rms(local)
        total_norm=rms(total)

        gain=None
        cosine=None
        if start_norm>FLOOR:
            gain=prop_norm/start_norm
            if prop_norm>FLOOR:
                denom=float(np.linalg.norm(start_err)*np.linalg.norm(propagated))
                cosine=float(np.dot(start_err,propagated)/denom) if denom>0 else None

        cum_free_qH += float(free["qH"])*OBS_DT
        Uf=float(np.sum(free["y"][:PHYS_N]))
        ledger=Uf-U0+cum_free_qH-THETA_S*(H1-Hinitial)
        max_ledger=max(max_ledger,abs(ledger))

        rows.append({
            "step":step,
            "H_start_cm":H0,
            "H_end_cm":H1,
            "start_shape_rms_theta":start_norm,
            "state_induced_shape_rms_theta":prop_norm,
            "local_closure_shape_rms_theta":local_norm,
            "total_free_shape_rms_theta":total_norm,
            "gain":gain,
            "cosine_previous_error_vs_propagated":cosine,
            "physical_moving_ledger_residual_cm":ledger,
        })

        yfree=np.array(free["y"],copy=True)
        yfree[IDX_CUM_QH]=0.0
        yfree[IDX_CUM_QI]=0.0

    gains=[float(r["gain"]) for r in rows if r["gain"] is not None and math.isfinite(float(r["gain"]))]
    cosines=[float(r["cosine_previous_error_vs_propagated"]) for r in rows if r["cosine_previous_error_vs_propagated"] is not None]
    eligible=len(gains)
    gt=[g for g in gains if g>1.0]
    first=next((r["step"] for r in rows if r["gain"] is not None and r["gain"]>1.0),None)
    local=[r["local_closure_shape_rms_theta"] for r in rows]
    total=[r["total_free_shape_rms_theta"] for r in rows]

    return {
        "status":"QUALIFIED",
        "dt_day":dt,
        "interval_count":len(rows),
        "eligible_gain_interval_count":eligible,
        "fraction_gain_gt_one":(len(gt)/eligible if eligible else 0.0),
        "predominantly_amplifying":(eligible>0 and len(gt)/eligible>0.5),
        "first_interval_gain_gt_one":first,
        "gain":{
            "median":float(statistics.median(gains)) if gains else None,
            "p95":percentile(gains,95),
            "maximum":max(gains) if gains else None,
        },
        "cosine":{
            "median":float(statistics.median(cosines)) if cosines else None,
            "p05":percentile(cosines,5),
            "p95":percentile(cosines,95),
        },
        "local_teacher_reference_shape_rms_theta":{
            "rms_over_intervals":rms(local),
            "maximum":max(local),
        },
        "total_free_reference_shape_rms_theta":{
            "rms_over_intervals":rms(total),
            "maximum":max(total),
        },
        "max_abs_physical_moving_ledger_residual_cm":max_ledger,
        "max_corrector_iterations":max_iter,
        "trajectory":rows,
    }

def compact_case(row):
    return {k:v for k,v in row.items() if k!="trajectory"}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c1r-result",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    c1r=json.loads(args.c1r_result.read_text())
    assert pre["phase"]=="PREREGISTERED_CONDITIONALLY_BEFORE_C1R_RESULT_EXPOSURE"
    assert pre["execution_condition"]["required_C1R_decision"]=="BC2_C1R_NUMERICAL_QUALIFICATION_RECOVERED"
    assert c1r["decision"]=="BC2_C1R_NUMERICAL_QUALIFICATION_RECOVERED"
    assert c1r["complete"] is True
    alg=pre["pre_execution_algorithm_clarification"]["diagnostic_A"]
    assert float(alg["denominator_numerical_floor_theta_rms"])==FLOOR
    assert float(pre["numerical_route"]["primary_internal_dt_day"])==DT

    init_meta,init_nodes,states,nodes=c0.b0.load_reference(args.reference)
    cases={}
    failures={}
    max_ledger=0.0
    for d in WIDTHS:
        cases[str(d)]={}
        for history in c0.HISTORY_STEPS:
            try:
                row=run_case(history,d,DT,init_meta,init_nodes,states,nodes)
                cases[str(d)][history]=row
                max_ledger=max(max_ledger,row["max_abs_physical_moving_ledger_residual_cm"])
            except (ValueError,RuntimeError,FloatingPointError) as exc:
                failures[f"{d}:{history}"]=str(exc)

    complete=(not failures and max_ledger<=GATE and
              all(cases.get(str(d),{}).get(h,{}).get("status")=="QUALIFIED"
                  for d in WIDTHS for h in c0.HISTORY_STEPS))

    result={
        "schema":"swap5.lare.bc2.c2a.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C2A",
        "decision":"BC2_C2A_ACTUAL_DRIFT_GAIN_MAPPED" if complete else "BC2_C2A_NUMERICAL_DIAGNOSTIC_BLOCKED",
        "complete":complete,
        "condition_authority":{
            "c1r_decision":c1r["decision"],
            "c1_original_failure_retained":c1r["original_C1_primary_failure_retained"],
        },
        "hard_checks":{
            "failure_count":len(failures),
            "all_reference_projections_finite":not any("NONFINITE_REFERENCE" in v for v in failures.values()),
            "max_abs_physical_moving_ledger_residual_cm":max_ledger,
            "gate_cm":GATE,
        },
        "failures":failures,
        "cases":cases,
        "summary":{
            str(d):{h:compact_case(cases[str(d)][h]) for h in cases.get(str(d),{})}
            for d in WIDTHS
        },
        "predominantly_amplifying_cases":[
            {"width_cm":d,"history":h}
            for d in WIDTHS for h,row in cases.get(str(d),{}).items()
            if row["predominantly_amplifying"]
        ],
        "interpretation":[
            "Gain measures propagation of the actual pre-existing reduced-state shape error through one unchanged C0 observation interval.",
            "Teacher-reference local closure error is reported alongside gain but is not included in the gain numerator.",
            "A gain above one is a trajectory-direction amplification diagnostic, not a global stability theorem.",
            "No state, closure, stabilizer, forcing, geometry, groundwater feedback or application tolerance is changed."
        ],
        "diagnostic_B_authorized":complete,
        "model_change_authorized":False,
        "application_acceptance_adjudicated":False,
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":result["decision"],
        "complete":complete,
        "hard_checks":result["hard_checks"],
        "predominantly_amplifying_cases":result["predominantly_amplifying_cases"],
        "summary":result["summary"],
    },sort_keys=True))
    return 0 if complete else 2

if __name__=="__main__":
    raise SystemExit(main())
