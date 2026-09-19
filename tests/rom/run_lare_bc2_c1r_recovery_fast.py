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
    mod=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

c1=load_module("bc2c1","analyze_lare_bc2_c1_teacher_forced.py")
c0=c1.c0

WIDTH=2.5
HISTORY="WT_CYCLE"
PRIMARY_KEY="0.00005000"
CROSS=0.000025
CROSS_KEY=f"{CROSS:.8f}"
GATE=1.0e-10

def classes(row):
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
    ap.add_argument("--c1-result",required=True,type=pathlib.Path)
    ap.add_argument("--c0-result",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    c1res=json.loads(args.c1_result.read_text())
    c0res=json.loads(args.c0_result.read_text())
    assert pre["phase"]=="PREREGISTERED_AFTER_C1_PRIMARY_ROUTE_DOMAIN_EXIT_BEFORE_RECOVERY_EXECUTION"
    assert pre["numerical_recovery"]["recovered_primary_dt_day"]==5e-05
    assert pre["numerical_recovery"]["new_cross_dt_day"]==CROSS
    assert c1res["decision"]=="BC2_C1_DIAGNOSTIC_BLOCKED"
    assert c0res["decision"]=="BC2_C0_ENRICHED_DYNAMICS_MIXED_RESPONSE"
    primary=c1res["cases"]["2.5"]["WT_CYCLE"][PRIMARY_KEY]
    assert hard_max(primary)<=GATE
    assert c1res["failures"]=={
        "2.5:WT_CYCLE:0.00010000":
        "OUTSIDE_QUALIFIED_DOMAIN Se=[0.4725465153356722,1.0000110667249589]"
    }

    init_meta,init_nodes,states,nodes=c0.b0.load_reference(args.reference)
    failure=None
    cross=None
    try:
        cross=c1.decompose(HISTORY,WIDTH,CROSS,init_meta,init_nodes,states,nodes)
    except (ValueError,RuntimeError,FloatingPointError) as exc:
        failure=str(exc)

    pclass=classes(primary)
    cclass=classes(cross) if cross is not None else {}
    match={k:pclass.get(k)==cclass.get(k) for k in ("state_shape","q90","qi","qH")}
    max_hard=max(hard_max(primary),hard_max(cross) if cross is not None else math.inf)
    complete=cross is not None and failure is None and max_hard<=GATE and all(match.values())

    result={
        "schema":"swap5.lare.bc2.c1r.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C1R",
        "implementation":"IMMUTABLE_C1_PRIMARY_PLUS_NEW_CROSS_ONLY",
        "decision":"BC2_C1R_NUMERICAL_QUALIFICATION_RECOVERED" if complete else "BC2_C1R_RECOVERY_BLOCKED",
        "complete":complete,
        "case":{"width_cm":WIDTH,"history":HISTORY},
        "original_C1_primary_failure_retained":True,
        "immutable_recovered_primary":{
            "source":"integration/f-rom/LARE_BC2_C1_RESULT.json",
            "dt_day":5e-05,
            "classification":pclass,
            "max_hard_residual":hard_max(primary),
        },
        "new_cross":{
            "dt_day":CROSS,
            "status":"QUALIFIED" if cross is not None else "BLOCKED",
            "classification":cclass,
            "max_hard_residual":None if cross is None else hard_max(cross),
            "row":cross,
        },
        "hard_checks":{
            "new_cross_qualified":cross is not None and failure is None,
            "max_additive_or_ledger_residual":max_hard,
            "gate":GATE,
            "classification_match":match,
        },
        "failure":failure,
        "numerical_floor":None if cross is None else numerical_floor(primary,cross),
        "interpretation":[
            "The already-qualified 0.00005-day C1 route is consumed immutably rather than recomputed.",
            "Only the preregistered unseen 0.000025-day cross route is newly evaluated.",
            "The original 0.0001-day C1 domain exit remains explicitly retained and C1 itself remains a blocked work unit.",
            "No state, closure, forcing, geometry, width, H(t), decomposition identity or classification rule is changed."
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
        "immutable_primary_classification":pclass,
        "new_cross_classification":cclass,
    },sort_keys=True))
    return 0 if complete else 2

if __name__=="__main__":
    raise SystemExit(main())
