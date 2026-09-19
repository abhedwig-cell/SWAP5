#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import pathlib

import numpy as np

HERE = pathlib.Path(__file__).resolve().parent

def load_module(name: str, filename: str):
    spec = importlib.util.spec_from_file_location(name, HERE / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

c1 = load_module("bc2c1", "analyze_lare_bc2_c1_teacher_forced.py")
c0 = c1.c0

DT = 0.00005
GAIN_FLOOR = 1.0e-12
HARD_GATE = 1.0e-10
WIDTHS = (2.5, 5.0)
HISTORIES = tuple(c0.HISTORY_STEPS)

def rms(x: np.ndarray) -> float:
    a=np.asarray(x,dtype=float)
    return float(np.sqrt(np.mean(a*a))) if a.size else 0.0

def thicknesses(H: float, d: float) -> np.ndarray:
    B=H-c0.ANCHOR-d
    if B <= 0.0:
        raise ValueError("OUTSIDE_QUALIFIED_DOMAIN nonpositive bulk thickness")
    return np.asarray([c0.FIXED_DZ]*c0.NFIXED+[B,d],dtype=float)

def error_coordinates(delta_w: np.ndarray, H: float, d: float) -> dict[str, object]:
    L=thicknesses(H,d)
    dw=np.asarray(delta_w,dtype=float)
    raw=dw/L
    total=float(np.sum(dw))
    uniform=total/float(np.sum(L))
    shape=raw-uniform
    weighted_residual=float(np.sum(L*shape))
    return {
        "raw_theta":raw,
        "shape_theta":shape,
        "raw_theta_rms":rms(raw),
        "shape_theta_rms":rms(shape),
        "total_storage_cm":total,
        "uniform_theta_component":uniform,
        "mass_neutral_weighted_residual_cm":weighted_residual,
    }

def cosine(a: np.ndarray,b: np.ndarray) -> float | None:
    na=float(np.linalg.norm(a)); nb=float(np.linalg.norm(b))
    if na <= GAIN_FLOOR or nb <= GAIN_FLOOR:
        return None
    return float(np.dot(a,b)/(na*nb))

def summarize(values: list[float]) -> dict[str,float|int|None]:
    if not values:
        return {"count":0,"median":None,"p95":None,"max":None,"fraction_gt_1":None}
    a=np.asarray(values,dtype=float)
    return {
        "count":int(a.size),
        "median":float(np.median(a)),
        "p95":float(np.quantile(a,0.95)),
        "max":float(np.max(a)),
        "fraction_gt_1":float(np.mean(a>1.0)),
    }

def run_case(history,d,init_meta,init_nodes,states,nodes):
    yfree,p0,U0=c1.exact_reference_state(history,0,d,init_meta,init_nodes,states,nodes)
    Hinitial=float(p0["H"])
    cum_free_qH=0.0
    max_free_ledger=0.0
    max_teacher_ledger=0.0
    max_mass_neutral_residual=0.0
    rows=[]
    gains=[]
    first_gt1=None

    for step in range(1,c0.HISTORY_STEPS[history]+1):
        yref_start,pref_start,_=c1.exact_reference_state(history,step-1,d,init_meta,init_nodes,states,nodes)
        yref_end,pref_end,_=c1.exact_reference_state(history,step,d,init_meta,init_nodes,states,nodes)
        H0=float(pref_start["H"]); H1=float(pref_end["H"])

        start=error_coordinates(
            yfree[:c1.PHYS_N]-yref_start[:c1.PHYS_N],H0,d
        )

        teacher=c1.advance_interval(yref_start,H0,H1,DT,d)
        free=c1.advance_interval(yfree,H0,H1,DT,d)
        yt=teacher["y"]; yf=free["y"]; yr=yref_end

        propagated=error_coordinates(
            yf[:c1.PHYS_N]-yt[:c1.PHYS_N],H1,d
        )
        local=error_coordinates(
            yt[:c1.PHYS_N]-yr[:c1.PHYS_N],H1,d
        )
        total=error_coordinates(
            yf[:c1.PHYS_N]-yr[:c1.PHYS_N],H1,d
        )

        max_mass_neutral_residual=max(
            max_mass_neutral_residual,
            abs(float(start["mass_neutral_weighted_residual_cm"])),
            abs(float(propagated["mass_neutral_weighted_residual_cm"])),
            abs(float(local["mass_neutral_weighted_residual_cm"])),
            abs(float(total["mass_neutral_weighted_residual_cm"])),
        )

        denom=float(start["shape_theta_rms"])
        if denom > GAIN_FLOOR:
            gain=float(propagated["shape_theta_rms"])/denom
            gains.append(gain)
            if gain>1.0 and first_gt1 is None:
                first_gt1=step
            gain_status="DEFINED"
        else:
            gain=None
            gain_status="BELOW_GAIN_DENOMINATOR_FLOOR"

        cos=cosine(
            np.asarray(start["shape_theta"],dtype=float),
            np.asarray(propagated["shape_theta"],dtype=float)
        )

        Ut=float(np.sum(yt[:c1.PHYS_N]))
        Uref_start=float(np.sum(yref_start[:c1.PHYS_N]))
        teacher_ledger=Ut-Uref_start+float(teacher["qH"])*c1.OBS_DT-c1.THETA_S*(H1-H0)
        max_teacher_ledger=max(max_teacher_ledger,abs(teacher_ledger))

        cum_free_qH += float(free["qH"])*c1.OBS_DT
        Uf=float(np.sum(yf[:c1.PHYS_N]))
        free_ledger=Uf-U0+cum_free_qH-c1.THETA_S*(H1-Hinitial)
        max_free_ledger=max(max_free_ledger,abs(free_ledger))

        row={
            "step":step,
            "H_start_cm":H0,
            "H_end_cm":H1,
            "start_shape_theta_rms":float(start["shape_theta_rms"]),
            "start_raw_theta_rms":float(start["raw_theta_rms"]),
            "start_total_storage_error_cm":float(start["total_storage_cm"]),
            "propagated_shape_theta_rms":float(propagated["shape_theta_rms"]),
            "propagated_raw_theta_rms":float(propagated["raw_theta_rms"]),
            "propagated_total_storage_difference_cm":float(propagated["total_storage_cm"]),
            "local_shape_theta_rms":float(local["shape_theta_rms"]),
            "local_raw_theta_rms":float(local["raw_theta_rms"]),
            "local_total_storage_error_cm":float(local["total_storage_cm"]),
            "total_free_shape_theta_rms":float(total["shape_theta_rms"]),
            "total_free_total_storage_error_cm":float(total["total_storage_cm"]),
            "gain_status":gain_status,
            "actual_shape_gain":gain,
            "shape_direction_cosine":cos,
        }
        rows.append(row)

        yfree=np.array(yf,copy=True)
        yfree[c1.IDX_CUM_QH]=0.0
        yfree[c1.IDX_CUM_QI]=0.0

    log_gain_sum=float(np.sum(np.log(np.asarray(gains,dtype=float)))) if gains and all(g>0 for g in gains) else None
    return {
        "status":"QUALIFIED",
        "width_cm":d,
        "history":history,
        "internal_dt_day":DT,
        "gain_denominator_floor_theta_rms":GAIN_FLOOR,
        "gain_summary":summarize(gains),
        "first_interval_gain_gt_1":first_gt1,
        "eligible_log_gain_sum":log_gain_sum,
        "max_abs_free_physical_ledger_residual_cm":max_free_ledger,
        "max_abs_teacher_interval_ledger_residual_cm":max_teacher_ledger,
        "max_abs_mass_neutral_projection_residual_cm":max_mass_neutral_residual,
        "trajectory":rows,
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c1r-result",required=True,type=pathlib.Path)
    ap.add_argument("--binding",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    c1r=json.loads(args.c1r_result.read_text())
    binding=json.loads(args.binding.read_text())
    assert pre["phase"]=="PREREGISTERED_CONDITIONALLY_BEFORE_C1R_RESULT_EXPOSURE"
    assert pre["pre_execution_shape_metric_clarification"]["gain_denominator_floor_theta_rms"]==GAIN_FLOOR
    assert c1r["decision"]==pre["execution_condition"]["required_C1R_decision"]
    assert c1r["complete"] is True
    assert binding["required_C1R_decision"]==c1r["decision"]
    assert binding["C2_execution_authorized"] is True

    init_meta,init_nodes,states,nodes=c0.b0.load_reference(args.reference)
    cases={}
    failures={}
    for d in WIDTHS:
        cases[str(d)]={}
        for h in HISTORIES:
            try:
                cases[str(d)][h]=run_case(h,d,init_meta,init_nodes,states,nodes)
            except (ValueError,RuntimeError,FloatingPointError) as exc:
                failures[f"{d}:{h}"]=str(exc)

    hard_values=[]
    for drow in cases.values():
        for row in drow.values():
            hard_values.extend([
                row["max_abs_free_physical_ledger_residual_cm"],
                row["max_abs_teacher_interval_ledger_residual_cm"],
                row["max_abs_mass_neutral_projection_residual_cm"],
            ])
    max_hard=max(hard_values or [math.inf])
    complete=not failures and max_hard<=HARD_GATE
    result={
        "schema":"swap5.lare.bc2.c2a.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C2A",
        "decision":"BC2_C2A_ACTUAL_DRIFT_GAIN_MAPPED" if complete else "BC2_C2A_DIAGNOSTIC_BLOCKED",
        "complete":complete,
        "diagnostic":"ACTUAL_TRAJECTORY_ONE_INTERVAL_SHAPE_GAIN",
        "hard_checks":{
            "failure_count":len(failures),
            "max_ledger_or_mass_neutral_residual":max_hard,
            "gate":HARD_GATE,
        },
        "failures":failures,
        "cases":cases,
        "interpretation":[
            "Gain compares propagation of the already-existing free-state shape deviation with its start-of-interval magnitude under the unchanged C0 map.",
            "A gain above one is interval-local amplification along the actual accumulated-error direction, not a global stability eigenvalue.",
            "Teacher-minus-Reference local bias is reported beside the propagated state component so repeated bias and amplification remain distinguishable.",
            "No state, closure, stabilizer, projection correction, forcing or H(t) is changed."
        ],
        "diagnostic_B_authorized":complete,
        "next_model_change_authorized":False,
        "groundwater_feedback_authorized":False,
        "application_acceptance_adjudicated":False,
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    compact={
        d:{h:{
            "gain_summary":row["gain_summary"],
            "first_interval_gain_gt_1":row["first_interval_gain_gt_1"],
            "max_ledger":max(row["max_abs_free_physical_ledger_residual_cm"],row["max_abs_teacher_interval_ledger_residual_cm"])
        } for h,row in hrows.items()}
        for d,hrows in cases.items()
    }
    print(json.dumps({"decision":result["decision"],"complete":complete,"cases":compact},sort_keys=True))
    return 0 if complete else 2

if __name__=="__main__":
    raise SystemExit(main())
