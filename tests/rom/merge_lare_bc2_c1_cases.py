#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import pathlib
from collections import Counter

HERE=pathlib.Path(__file__).resolve().parent

def load_module(name,filename):
    spec=importlib.util.spec_from_file_location(name,HERE/filename)
    m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

c1=load_module("bc2c1","analyze_lare_bc2_c1_teacher_forced.py")
c0=c1.c0

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--cases-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c0-result",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    c0res=json.loads(a.c0_result.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_TEACHER_FORCED_DRIFT_DECOMPOSITION"
    assert c0res["decision"]==pre["predecessor"]["required_decision"]
    assert c0res["production_rom_authorized"] is False

    cases={}
    failures={}
    for d in c1.WIDTHS:
        dk=str(d)
        cases[dk]={}
        for history in c0.HISTORY_STEPS:
            path=a.cases_dir/f"case-{d:g}-{history}.json"
            if not path.exists():
                failures[f"{d}:{history}:CASE_ARTIFACT"]="missing"
                cases[dk][history]={}
                continue
            row=json.loads(path.read_text())
            if float(row["width_cm"])!=float(d) or row["history"]!=history:
                failures[f"{d}:{history}:CASE_IDENTITY"]="mismatch"
                cases[dk][history]={}
                continue
            cases[dk][history]=row.get("runs",{})
            for route,reason in row.get("failures",{}).items():
                failures[f"{d}:{history}:{route}"]=reason

    primary_key=f"{c1.PRIMARY_DT:.8f}"
    cross_key=f"{c1.CROSS_DT:.8f}"
    all_routes=all(
        primary_key in cases[str(d)][h] and cross_key in cases[str(d)][h]
        for d in c1.WIDTHS for h in c0.HISTORY_STEPS
    )

    hard_vals=[]
    classifications={}
    floors={}
    for d in c1.WIDTHS:
        dk=str(d)
        classifications[dk]={}
        floors[dk]={}
        for h in c0.HISTORY_STEPS:
            row=cases[dk][h]
            if primary_key not in row:
                classifications[dk][h]={"status":"BLOCKED"}
                continue
            p=row[primary_key]
            route_hard={}
            for route_key in (primary_key,cross_key):
                if route_key not in row:
                    continue
                rr=row[route_key]
                vals=[
                    rr["max_abs_additive_state_identity_residual_cm"],
                    rr["max_abs_additive_flux_identity_residual_cm_per_day"],
                    rr["max_abs_free_physical_ledger_residual_cm"],
                    rr["max_abs_teacher_interval_ledger_residual_cm"],
                ]
                hard_vals.extend(vals)
                route_hard[route_key]=max(vals)
            classifications[dk][h]={
                "state_shape":p["state_shape"]["dominance"],
                "q90":p["fluxes"]["q90"]["dominance"],
                "qi":p["fluxes"]["qi"]["dominance"],
                "qH":p["fluxes"]["qH"]["dominance"],
                "first_interval_state_component_exceeds_local":p["first_interval_state_component_exceeds_local"],
                "max_hard_residual_by_route":route_hard,
            }
            if cross_key in row:
                floors[dk][h]=c1.numerical_floor(p,row[cross_key])
                floors[dk][h]["classification_match"]={
                    "state_shape":p["state_shape"]["dominance"]==row[cross_key]["state_shape"]["dominance"],
                    "q90":p["fluxes"]["q90"]["dominance"]==row[cross_key]["fluxes"]["q90"]["dominance"],
                    "qi":p["fluxes"]["qi"]["dominance"]==row[cross_key]["fluxes"]["qi"]["dominance"],
                    "qH":p["fluxes"]["qH"]["dominance"]==row[cross_key]["fluxes"]["qH"]["dominance"],
                }

    max_hard=max(hard_vals or [math.inf])
    complete=all_routes and not failures and max_hard<=c1.IDENTITY_GATE
    counts=Counter()
    for drow in classifications.values():
        for hrow in drow.values():
            for key in ("state_shape","q90","qi","qH"):
                if key in hrow:
                    counts[f"{key}:{hrow[key]}"]+=1

    result={
        "schema":"swap5.lare.bc2.c1.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C1",
        "decision":"BC2_C1_ERROR_CHANNELS_DECOMPOSED" if complete else "BC2_C1_DIAGNOSTIC_BLOCKED",
        "execution_mode":"SHARDED_WIDTH_HISTORY_CASES_MERGED_DETERMINISTICALLY",
        "complete":complete,
        "hard_checks":{
            "all_primary_and_cross_routes_qualified":all_routes and not failures,
            "all_primary_and_cross_routes_hard_gated":True,
            "all_reference_projections_finite":len(failures)==0,
            "failure_count":len(failures),
            "max_additive_or_ledger_residual_across_primary_and_cross":max_hard,
            "gate":c1.IDENTITY_GATE,
        },
        "failures":failures,
        "classification_counts":dict(counts),
        "classifications":classifications,
        "numerical_floor":floors,
        "cases":cases,
        "interpretation":[
            "Teacher-forced one-interval error evaluates the unchanged C0 closure from exact Reference-projected reduced state.",
            "Free-minus-teacher isolates accumulated reduced-state drift under the same H(t), integrator and closures.",
            "All decomposition identities are checked before norms are formed.",
            "The sharded execution is algebraically identical to the preregistered monolithic decomposition; sharding changes scheduling only.",
            "No new state, closure, fit, direction switch, groundwater feedback or application tolerance is introduced."
        ],
        "next_model_change_authorized":False,
        "application_acceptance_adjudicated":False,
        "groundwater_feedback_authorized":False,
        "production_rom_authorized":False,
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "schema":result["schema"],
        "decision":result["decision"],
        "complete":complete,
        "hard_checks":result["hard_checks"],
        "classification_counts":result["classification_counts"],
        "classifications":classifications,
    },sort_keys=True))
    return 0 if complete else 2

if __name__=="__main__":
    raise SystemExit(main())
