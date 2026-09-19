#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib
import sys

import numpy as np

import run_lare_bc1_stage_b as bc

LADDER={
    "R3":[0.0,140.0,150.0,160.0],
    "R4":[0.0,130.0,140.0,150.0,160.0],
    "R5":[0.0,120.0,130.0,140.0,150.0,160.0],
    "R6":[0.0,110.0,120.0,130.0,140.0,150.0,160.0],
    "R8":[0.0,90.0,100.0,110.0,120.0,130.0,140.0,150.0,160.0],
    "R12":[0.0,50.0,60.0,70.0,80.0,90.0,100.0,110.0,120.0,130.0,140.0,150.0,160.0],
    "R16":[float(x) for x in range(0,161,10)],
}
COMMON=[0.0,140.0,150.0,160.0]
ORDER=list(LADDER)
EQ_TOL=1.0e-12


def thickness(boundaries:list[float])->np.ndarray:
    return np.diff(np.asarray(boundaries,dtype=float))


def aggregate_storage(
    storage:np.ndarray,
    boundaries:list[float],
    target:list[float],
)->np.ndarray:
    out=np.zeros((storage.shape[0],len(target)-1),dtype=float)
    for i,(lo,hi) in enumerate(zip(boundaries,boundaries[1:])):
        placed=False
        for j,(tlo,thi) in enumerate(zip(target,target[1:])):
            if lo>=tlo-EQ_TOL and hi<=thi+EQ_TOL:
                out[:,j]+=storage[:,i]
                placed=True
                break
        if not placed:
            raise RuntimeError(f"layer {lo}-{hi} does not nest in target bands")
    return out


def common_storage_metrics(
    candidate:dict[str,object],
    ref_steps:list[dict[str,object]],
    boundaries:list[float],
)->dict[str,float]:
    cs=np.asarray(candidate["layer_storage_cm"],dtype=float)
    cc=aggregate_storage(cs,boundaries,COMMON)
    rs=np.asarray([bc.project_reference(row["nodes"],COMMON) for row in ref_steps],dtype=float)
    diff=cc-rs
    return {
        "max_abs_common_band_storage_error_cm":float(np.max(np.abs(diff))),
        "mean_abs_common_band_storage_error_cm":float(np.mean(np.abs(diff))),
        "max_abs_final_common_band_storage_error_cm":float(np.max(np.abs(diff[-1]))),
    }


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_HEAD_DRIVEN_RESOLUTION_LADDER_EXECUTION"
    assert pre["fixed_model"]["prescribed_head_closure"]=="CURRENT_LAYER_FACE"
    assert [row["id"] for row in pre["ladder"]]==ORDER

    ref=bc.load_reference(args.reference)
    cases={}
    aggregate={}
    g03_first_qualified=None

    for member,bounds in LADDER.items():
        bc.PARTITIONS[member]=thickness(bounds)
        member_rows=[]
        for history in bc.HISTORY_SE:
            case=bc.Case(member,history,"CURRENT_LAYER_FACE")
            refinements={};failures={}
            for dt in bc.HEUN_DT:
                key=f"{dt:.7f}"
                try:
                    refinements[key]=bc.solve(case,dt)
                except ValueError as exc:
                    failures[key]=f"OUTSIDE_QUALIFIED_DOMAIN: {exc}"
                except (RuntimeError,FloatingPointError) as exc:
                    failures[key]=f"NUMERICAL_BLOCKED: {exc}"
            finest=refinements.get("0.0001000")
            if finest is not None:
                status="QUALIFIED"
                candidate_metrics=bc.compare(finest,ref[history]["steps"],bounds)
                common_metrics=common_storage_metrics(finest,ref[history]["steps"],bounds)
                metrics={**candidate_metrics,**common_metrics}
                member_rows.append(metrics)
                if history=="G03" and g03_first_qualified is None:
                    g03_first_qualified=member
            elif "OUTSIDE_QUALIFIED_DOMAIN" in failures.get("0.0001000",""):
                status="OUTSIDE_QUALIFIED_DOMAIN";metrics=None
            else:
                status="NUMERICAL_BLOCKED";metrics=None
            floor=None
            if "0.0002000" in refinements and "0.0001000" in refinements:
                floor=bc.numerical_floor(refinements["0.0002000"],refinements["0.0001000"])
            cases[f"{member}_{history}"]={
                "member":member,"dimension":len(bounds)-1,"boundaries_cm":bounds,
                "history":history,"status":status,"metrics":metrics,
                "numerical_floor":floor,"failures":failures,
                "finest_max_corrector_iterations":None if finest is None else finest["max_corrector_iterations"],
            }

        aggregate[member]={
            "dimension":len(bounds)-1,
            "long_layer_cm":bounds[1]-bounds[0],
            "qualified_history_count":sum(cases[f"{member}_{h}"]["status"]=="QUALIFIED" for h in bc.HISTORY_SE),
            "outside_qualified_domain_count":sum(cases[f"{member}_{h}"]["status"]=="OUTSIDE_QUALIFIED_DOMAIN" for h in bc.HISTORY_SE),
            "numerical_blocked_count":sum(cases[f"{member}_{h}"]["status"]=="NUMERICAL_BLOCKED" for h in bc.HISTORY_SE),
            "max_abs_common_band_storage_error_cm":None if not member_rows else max(x["max_abs_common_band_storage_error_cm"] for x in member_rows),
            "mean_of_history_mean_abs_common_band_storage_error_cm":None if not member_rows else sum(x["mean_abs_common_band_storage_error_cm"] for x in member_rows)/len(member_rows),
            "max_abs_cumulative_bottom_exchange_error_cm":None if not member_rows else max(x["max_abs_cumulative_bottom_exchange_error_cm"] for x in member_rows),
            "max_abs_interval_bottom_flux_error_cm_per_day":None if not member_rows else max(x["max_abs_interval_bottom_flux_error_cm_per_day"] for x in member_rows),
            "bottom_flux_sign_mismatch_count":None if not member_rows else sum(x["bottom_flux_sign_mismatch_count"] for x in member_rows),
            "reversal_sequence_mismatch_history_count":None if not member_rows else sum(not x["reversal_sequence_length_match"] for x in member_rows),
            "max_reversal_step_difference":None if not member_rows else max([x["max_reversal_step_difference"] for x in member_rows if x["max_reversal_step_difference"] is not None] or [0]),
        }

    adjacent={}
    all_noninferior=True
    g00_all_correct=True
    for low,high in zip(ORDER[:-1],ORDER[1:]):
        rows=[]
        pair_ok=True
        for history in bc.HISTORY_SE:
            a=cases[f"{low}_{history}"];b=cases[f"{high}_{history}"]
            if a["status"]=="QUALIFIED" and b["status"]=="QUALIFIED":
                ma=a["metrics"];mb=b["metrics"]
                storage_ok=mb["max_abs_common_band_storage_error_cm"]<=ma["max_abs_common_band_storage_error_cm"]+EQ_TOL
                exchange_ok=mb["max_abs_cumulative_bottom_exchange_error_cm"]<=ma["max_abs_cumulative_bottom_exchange_error_cm"]+EQ_TOL
                pair_ok=pair_ok and storage_ok and exchange_ok
                rows.append({
                    "history":history,
                    "low_max_common_storage_cm":ma["max_abs_common_band_storage_error_cm"],
                    "high_max_common_storage_cm":mb["max_abs_common_band_storage_error_cm"],
                    "storage_noninferior":storage_ok,
                    "low_max_cum_bottom_cm":ma["max_abs_cumulative_bottom_exchange_error_cm"],
                    "high_max_cum_bottom_cm":mb["max_abs_cumulative_bottom_exchange_error_cm"],
                    "exchange_noninferior":exchange_ok,
                })
        all_noninferior=all_noninferior and pair_ok
        adjacent[f"{low}_to_{high}"]={
            "common_history_count":len(rows),"all_primary_integrated_metrics_noninferior":pair_ok,
            "histories":rows,
        }

    for member in ORDER:
        row=cases[f"{member}_G00"]
        if row["status"]=="QUALIFIED":
            g00_all_correct=g00_all_correct and (
                row["metrics"]["candidate_reversal_steps"]==row["metrics"]["reference_reversal_steps"]
            )

    decision=(
        "BC1_HEAD_RESOLUTION_CONVERGENCE_CLEAR"
        if all_noninferior and g00_all_correct
        else "BC1_HEAD_RESOLUTION_EFFECT_NONMONOTONE"
    )

    result={
        "schema":"swap5.lare.bc1.rl1.result.v1",
        "workstream":"F-ROM-LARE","work_unit":"LARE-BC1-RL1",
        "decision":decision,
        "authority":{
            "preregistration":str(args.prereg),
            "bc1_stage_b":"integration/f-rom/LARE_BC1_STAGE_B_CLOSEOUT.json",
            "reference_artifact_id":10585316225,
            "reference_payload_sha256":"7d92c4524d16836a25200851ce560b041971d05f65256785e8cf1ef59ae0b345",
        },
        "ladder_aggregate":aggregate,
        "adjacent_resolution_checks":adjacent,
        "G03_first_qualified_member":g03_first_qualified,
        "G00_reversal_sequence_correct_for_all_qualified_members":g00_all_correct,
        "cases":cases,
        "interpretation":[
            "Every member uses the same no-fit CURRENT_LAYER_FACE prescribed-head closure and unchanged standard interior LARE closure.",
            "The ladder changes only fixed-layer resolution; therefore systematic improvement is closure/discretization convergence, not new state-selection evidence.",
            "R16 is a no-spatial-reduction control and cannot be relabelled a ROM.",
            "No observed point on the curve is selected as application-acceptable inside RL1."
        ],
        "application_acceptance_adjudicated":False,
        "moving_water_table_authorized":False,
        "speed_claim":False,
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":decision,
        "ladder_aggregate":aggregate,
        "G03_first_qualified_member":g03_first_qualified,
        "G00_reversal_sequence_correct_for_all_qualified_members":g00_all_correct,
        "adjacent_noninferior":{k:v["all_primary_integrated_metrics_noninferior"] for k,v in adjacent.items()},
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
