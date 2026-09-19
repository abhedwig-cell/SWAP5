#!/usr/bin/env python3
from __future__ import annotations

import argparse
import copy
import json
import pathlib
import sys

import numpy as np

sys.path.insert(0,str(pathlib.Path(__file__).resolve().parent))
import run_lare_bc1_stage_b as bc1

COMMON_BOUNDS=[0.0,140.0,150.0,160.0]
FLOAT_EQ_CM=1.0e-12

def common_storage(storage_rows,bounds):
    arr=np.asarray(storage_rows,dtype=float)
    out=np.zeros((arr.shape[0],len(COMMON_BOUNDS)-1),dtype=float)
    for j,(lo,hi) in enumerate(zip(bounds,bounds[1:])):
        target=None
        for k,(clo,chi) in enumerate(zip(COMMON_BOUNDS,COMMON_BOUNDS[1:])):
            if lo>=clo-1e-12 and hi<=chi+1e-12:
                target=k;break
        if target is None:
            raise RuntimeError(f"member layer {lo}-{hi} crosses common band")
        out[:,target]+=arr[:,j]
    return out

def compare_common(candidate,ref_steps,bounds):
    c=copy.deepcopy(candidate)
    c["layer_storage_cm"]=common_storage(candidate["layer_storage_cm"],bounds).tolist()
    return bc1.compare(c,ref_steps,COMMON_BOUNDS)

def aggregate(cases,member,histories):
    rows=[cases[f"{member}_{h}"]["comparison"] for h in histories]
    return {
        "history_count":len(rows),
        "max_abs_common_band_storage_error_cm":max(x["max_abs_layer_storage_error_cm"] for x in rows),
        "mean_of_case_mean_abs_common_band_storage_error_cm":sum(x["mean_abs_layer_storage_error_cm"] for x in rows)/len(rows),
        "max_abs_cumulative_bottom_exchange_error_cm":max(x["max_abs_cumulative_bottom_exchange_error_cm"] for x in rows),
        "max_abs_interval_bottom_flux_error_cm_per_day":max(x["max_abs_interval_bottom_flux_error_cm_per_day"] for x in rows),
        "bottom_flux_sign_mismatch_count":sum(x["bottom_flux_sign_mismatch_count"] for x in rows),
        "reversal_sequence_mismatch_case_count":sum(not x["reversal_sequence_length_match"] for x in rows),
        "max_reversal_step_difference":max([x["max_reversal_step_difference"] for x in rows if x["max_reversal_step_difference"] is not None] or [0]),
        "max_abs_water_ledger_cm":max(x["max_abs_water_ledger_cm"] for x in rows),
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_HEAD_DRIVEN_RESOLUTION_LADDER"
    ref=bc1.load_reference(args.reference)

    ladder={}
    bounds={}
    for row in pre["ladder"]:
        b=[float(x) for x in row["boundaries_cm"]]
        dz=np.diff(np.asarray(b,dtype=float))
        ladder[row["id"]]=dz
        bounds[row["id"]]=b
        bc1.PARTITIONS[row["id"]]=dz
        bc1.BOUNDARIES[row["id"]]=b

    histories=list(pre["histories"])
    cases={}
    for member in ladder:
        for hist in histories:
            case=bc1.Case(member,hist,"CURRENT_LAYER_FACE")
            refinements={};failures={}
            for dt in bc1.HEUN_DT:
                key=f"{dt:.7f}"
                try:
                    refinements[key]=bc1.solve(case,dt)
                except ValueError as exc:
                    failures[key]=f"OUTSIDE_QUALIFIED_DOMAIN: {exc}"
                except (RuntimeError,FloatingPointError) as exc:
                    failures[key]=f"NUMERICAL_BLOCKED: {exc}"
            finest=refinements.get("0.0001000")
            if finest is not None:
                status="QUALIFIED"
                comparison=compare_common(finest,ref[hist]["steps"],bounds[member])
            elif "OUTSIDE_QUALIFIED_DOMAIN" in failures.get("0.0001000",""):
                status="OUTSIDE_QUALIFIED_DOMAIN";comparison=None
            else:
                status="NUMERICAL_BLOCKED";comparison=None
            floor=None
            if "0.0002000" in refinements and "0.0001000" in refinements:
                # For the numerical floor, compare in native member coordinates;
                # this is stricter than common-band aggregation for storage.
                floor=bc1.numerical_floor(refinements["0.0002000"],refinements["0.0001000"])
            cases[f"{member}_{hist}"]={
                "member":member,"history":hist,"dimension":len(ladder[member]),
                "boundaries_cm":bounds[member],"status":status,
                "comparison":comparison,"numerical_floor":floor,"failures":failures,
                "finest_max_corrector_iterations":None if finest is None else finest["max_corrector_iterations"]
            }

    status_by_member={}
    for member in ladder:
        rows=[cases[f"{member}_{h}"] for h in histories]
        status_by_member[member]={
            "QUALIFIED":sum(x["status"]=="QUALIFIED" for x in rows),
            "OUTSIDE_QUALIFIED_DOMAIN":sum(x["status"]=="OUTSIDE_QUALIFIED_DOMAIN" for x in rows),
            "NUMERICAL_BLOCKED":sum(x["status"]=="NUMERICAL_BLOCKED" for x in rows),
        }

    common_all=[h for h in histories if all(cases[f"{m}_{h}"]["status"]=="QUALIFIED" for m in ladder)]
    all_common_curve={m:aggregate(cases,m,common_all) for m in ladder} if common_all else {}

    ids=list(ladder)
    adjacent={}
    convergence=True
    strict_each=True
    for lo,hi in zip(ids[:-1],ids[1:]):
        hs=[h for h in histories if cases[f"{lo}_{h}"]["status"]=="QUALIFIED" and cases[f"{hi}_{h}"]["status"]=="QUALIFIED"]
        if not hs:
            adjacent[f"{lo}_TO_{hi}"]={"histories":[],"qualified":False}
            convergence=False;strict_each=False
            continue
        a=aggregate(cases,lo,hs);b=aggregate(cases,hi,hs)
        checks={
            "storage_max_noninferior":b["max_abs_common_band_storage_error_cm"]<=a["max_abs_common_band_storage_error_cm"]+FLOAT_EQ_CM,
            "bottom_exchange_max_noninferior":b["max_abs_cumulative_bottom_exchange_error_cm"]<=a["max_abs_cumulative_bottom_exchange_error_cm"]+FLOAT_EQ_CM,
            "sign_mismatch_noninferior":b["bottom_flux_sign_mismatch_count"]<=a["bottom_flux_sign_mismatch_count"],
            "reversal_mismatch_noninferior":b["reversal_sequence_mismatch_case_count"]<=a["reversal_sequence_mismatch_case_count"],
        }
        strict=(
            b["max_abs_common_band_storage_error_cm"]<a["max_abs_common_band_storage_error_cm"]-FLOAT_EQ_CM
            or b["max_abs_cumulative_bottom_exchange_error_cm"]<a["max_abs_cumulative_bottom_exchange_error_cm"]-FLOAT_EQ_CM
            or b["bottom_flux_sign_mismatch_count"]<a["bottom_flux_sign_mismatch_count"]
            or b["reversal_sequence_mismatch_case_count"]<a["reversal_sequence_mismatch_case_count"]
        )
        ok=all(checks.values()) and strict
        convergence &= all(checks.values())
        strict_each &= strict
        adjacent[f"{lo}_TO_{hi}"]={
            "histories":hs,"lower":a,"higher":b,"checks":checks,
            "strict_improvement_at_least_one_primary_component":strict,
            "adjacent_gate_pass":ok
        }

    decision="RESOLUTION_CONVERGENCE_CLEAR" if convergence and strict_each else "RESOLUTION_EFFECT_MIXED"

    # Per-member aggregate on its own qualified cohort is descriptive only.
    own_curve={}
    for member in ladder:
        hs=[h for h in histories if cases[f"{member}_{h}"]["status"]=="QUALIFIED"]
        own_curve[member]=None if not hs else aggregate(cases,member,hs)

    r16=own_curve["R16"]
    result={
        "schema":"swap5.lare.bc1.stage-c.result.v1",
        "workstream":"F-ROM-LARE","work_unit":"LARE-BC1-C",
        "decision":decision,
        "closure":"CURRENT_LAYER_FACE",
        "common_storage_bands_cm":[[0,140],[140,150],[150,160]],
        "status_by_member":status_by_member,
        "all_ladder_common_histories":common_all,
        "all_ladder_common_curve":all_common_curve,
        "own_qualified_cohort_curve":own_curve,
        "adjacent_resolution_checks":adjacent,
        "cases":cases,
        "R16_residual":{
            "qualified_case_count":status_by_member["R16"]["QUALIFIED"],
            "max_common_band_storage_error_cm":None if r16 is None else r16["max_abs_common_band_storage_error_cm"],
            "max_cumulative_bottom_exchange_error_cm":None if r16 is None else r16["max_abs_cumulative_bottom_exchange_error_cm"],
            "max_interval_bottom_flux_error_cm_per_day":None if r16 is None else r16["max_abs_interval_bottom_flux_error_cm_per_day"],
            "interpretation":"Reported without an acceptance threshold. Any nonzero asymptote can include Reference SWKIMPL=0 time-level and balance-materialized boundary semantics in addition to LARE integration differences."
        },
        "interpretation_firewall":[
            "R3-R16 uses one unchanged CURRENT_LAYER_FACE closure and one nested geometry ladder.",
            "No acceptable dimension or elbow is selected from this curve.",
            "R16 is a no-spatial-reduction control, not a ROM.",
            "Reference bottom exchange is interval water-balance exchange, not relabelled instantaneous current-K Darcy flux.",
            "Application acceptance and computational value remain unadjudicated."
        ],
        "application_acceptance_adjudicated":False,
        "speed_claim":False,
        "production_rom_authorized":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "schema":result["schema"],"decision":decision,
        "status_by_member":status_by_member,
        "all_ladder_common_histories":common_all,
        "all_ladder_common_curve":all_common_curve,
        "own_qualified_cohort_curve":own_curve,
        "R16_residual":result["R16_residual"]
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
