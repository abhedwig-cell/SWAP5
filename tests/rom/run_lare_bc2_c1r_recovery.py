#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import pathlib

HERE=pathlib.Path(__file__).resolve().parent

def load_module(name,filename):
    spec=importlib.util.spec_from_file_location(name,HERE/filename)
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

c1=load_module("bc2c1","analyze_lare_bc2_c1_teacher_forced.py")
c0=c1.c0

WIDTH=2.5
HISTORY="WT_CYCLE"
PRIMARY=0.00005
CROSS=0.000025
GATE=1.0e-10

def channel_classes(row):
    return {
        "state_shape":row["state_shape"]["dominance"],
        "q90":row["fluxes"]["q90"]["dominance"],
        "qi":row["fluxes"]["qi"]["dominance"],
        "qH":row["fluxes"]["qH"]["dominance"],
    }

def hard_max(row):
    return max(
        row["max_abs_additive_state_identity_residual_cm"],
        row["max_abs_additive_flux_identity_residual_cm_per_day"],
        row["max_abs_free_physical_ledger_residual_cm"],
        row["max_abs_teacher_interval_ledger_residual_cm"],
    )

def numerical_floor(a,b):
    out={}
    for ch in ("state_shape","total_unsaturated_storage"):
        out[ch]={
            "local_rms_difference":abs(a[ch]["local_closure"]["rms"]-b[ch]["local_closure"]["rms"]),
            "state_rms_difference":abs(a[ch]["state_induced"]["rms"]-b[ch]["state_induced"]["rms"]),
            "total_rms_difference":abs(a[ch]["total_free"]["rms"]-b[ch]["total_free"]["rms"]),
        }
    out["fluxes"]={}
    for name in ("q90","qi","qH"):
        out["fluxes"][name]={
            "local_rms_difference":abs(a["fluxes"][name]["local_closure"]["rms"]-b["fluxes"][name]["local_closure"]["rms"]),
            "state_rms_difference":abs(a["fluxes"][name]["state_induced"]["rms"]-b["fluxes"][name]["state_induced"]["rms"]),
            "total_rms_difference":abs(a["fluxes"][name]["total_free"]["rms"]-b["fluxes"][name]["total_free"]["rms"]),
        }
    return out

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c0-result",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    c0res=json.loads(args.c0_result.read_text())
    assert pre["phase"]=="PREREGISTERED_AFTER_C1_PRIMARY_ROUTE_DOMAIN_EXIT_BEFORE_RECOVERY_EXECUTION"
    assert pre["trigger_evidence"]["blocked_case"]=={"width_cm":2.5,"history":"WT_CYCLE"}
    assert float(pre["numerical_recovery"]["recovered_primary_dt_day"])==PRIMARY
    assert float(pre["numerical_recovery"]["new_cross_dt_day"])==CROSS
    assert c0res["decision"]=="BC2_C0_ENRICHED_DYNAMICS_MIXED_RESPONSE"

    init_meta,init_nodes,states,nodes=c0.b0.load_reference(args.reference)
    runs={}
    failures={}
    for dt in (PRIMARY,CROSS):
        key=f"{dt:.8f}"
        try:
            runs[key]=c1.decompose(
                HISTORY,WIDTH,dt,init_meta,init_nodes,states,nodes
            )
        except (ValueError,RuntimeError,FloatingPointError) as exc:
            failures[key]=str(exc)

    pkey=f"{PRIMARY:.8f}"
    ckey=f"{CROSS:.8f}"
    both=pkey in runs and ckey in runs
    max_hard=max([hard_max(row) for row in runs.values()] or [math.inf])
    pclasses=channel_classes(runs[pkey]) if pkey in runs else {}
    cclasses=channel_classes(runs[ckey]) if ckey in runs else {}
    class_match={
        key:(pclasses.get(key)==cclasses.get(key))
        for key in ("state_shape","q90","qi","qH")
    }
    complete=(
        both
        and not failures
        and max_hard<=GATE
        and all(class_match.values())
    )

    result={
        "schema":"swap5.lare.bc2.c1r.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C1R",
        "decision":(
            "BC2_C1R_NUMERICAL_QUALIFICATION_RECOVERED"
            if complete else
            "BC2_C1R_RECOVERY_BLOCKED"
        ),
        "complete":complete,
        "case":{"width_cm":WIDTH,"history":HISTORY},
        "original_C1_primary_failure_retained":True,
        "routes":{
            "recovered_primary_dt_day":PRIMARY,
            "new_cross_dt_day":CROSS,
        },
        "hard_checks":{
            "both_routes_qualified":both and not failures,
            "failure_count":len(failures),
            "max_additive_or_ledger_residual":max_hard,
            "gate":GATE,
            "classification_match":class_match,
        },
        "failures":failures,
        "classifications":{
            "recovered_primary":pclasses,
            "new_cross":cclasses,
        },
        "numerical_floor":(
            numerical_floor(runs[pkey],runs[ckey])
            if both else None
        ),
        "runs":runs,
        "interpretation":[
            "The original C1 0.0001-day primary-route domain exit remains part of the evidence and is not reclassified as a pass.",
            "C1R tests whether the already-preregistered qualified 0.00005-day route is stable against one additional factor-two temporal refinement.",
            "No state, closure, forcing, geometry, terminal width, H(t), decomposition identity, or classification rule is changed."
        ],
        "next_model_change_authorized":False,
        "application_acceptance_adjudicated":False,
        "groundwater_feedback_authorized":False,
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":result["decision"],
        "complete":complete,
        "hard_checks":result["hard_checks"],
        "classifications":result["classifications"],
    },sort_keys=True))
    return 0 if complete else 2

if __name__=="__main__":
    raise SystemExit(main())
