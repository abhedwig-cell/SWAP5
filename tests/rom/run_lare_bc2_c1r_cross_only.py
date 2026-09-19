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

c1r=load_module("bc2c1r","run_lare_bc2_c1r_recovery.py")
c1=c1r.c1

WIDTH=2.5
HISTORY="WT_CYCLE"
PRIMARY=0.00005
CROSS=0.000025
GATE=1.0e-10
PRIMARY_KEY=f"{PRIMARY:.8f}"
CROSS_KEY=f"{CROSS:.8f}"

def hard_max(row):
    return max(
        row["max_abs_additive_state_identity_residual_cm"],
        row["max_abs_additive_flux_identity_residual_cm_per_day"],
        row["max_abs_free_physical_ledger_residual_cm"],
        row["max_abs_teacher_interval_ledger_residual_cm"],
    )

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c1-result",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    c1res=json.loads(args.c1_result.read_text())
    assert pre["phase"]=="PREREGISTERED_AFTER_C1_PRIMARY_ROUTE_DOMAIN_EXIT_BEFORE_RECOVERY_EXECUTION"
    reuse=pre["pre_execution_reuse_clarification"]
    assert reuse["before_first_C1R_result_exposure"] is True
    assert float(pre["numerical_recovery"]["recovered_primary_dt_day"])==PRIMARY
    assert float(pre["numerical_recovery"]["new_cross_dt_day"])==CROSS
    assert c1res["decision"]=="BC2_C1_DIAGNOSTIC_BLOCKED"
    assert c1res["production_rom_authorized"] is False

    primary=c1res["cases"][str(WIDTH)][HISTORY][PRIMARY_KEY]
    assert primary["status"]=="QUALIFIED"
    primary_classes=c1r.channel_classes(primary)

    init_meta,init_nodes,states,nodes=c1.c0.b0.load_reference(args.reference)
    failures={}
    cross=None
    try:
        cross=c1.decompose(HISTORY,WIDTH,CROSS,init_meta,init_nodes,states,nodes)
    except (ValueError,RuntimeError,FloatingPointError) as exc:
        failures[CROSS_KEY]=str(exc)

    cross_classes=c1r.channel_classes(cross) if cross is not None else {}
    class_match={
        key:(primary_classes.get(key)==cross_classes.get(key))
        for key in ("state_shape","q90","qi","qH")
    }
    hard_values=[hard_max(primary)]
    if cross is not None:
        hard_values.append(hard_max(cross))
    max_hard=max(hard_values or [math.inf])

    complete=(
        cross is not None
        and not failures
        and max_hard<=GATE
        and all(class_match.values())
    )

    result={
        "schema":"swap5.lare.bc2.c1r.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C1R",
        "decision":"BC2_C1R_NUMERICAL_QUALIFICATION_RECOVERED" if complete else "BC2_C1R_RECOVERY_BLOCKED",
        "complete":complete,
        "case":{"width_cm":WIDTH,"history":HISTORY},
        "original_C1_primary_failure_retained":True,
        "execution_route":"PERSISTED_C1_PRIMARY_PLUS_NEW_CROSS_ONLY",
        "reuse_authority":{
            "primary_source":"integration/f-rom/LARE_BC2_C1_RESULT.json",
            "primary_key":PRIMARY_KEY,
            "primary_status":primary["status"],
            "scientific_semantics_unchanged":True,
        },
        "routes":{
            "recovered_primary_dt_day":PRIMARY,
            "new_cross_dt_day":CROSS,
        },
        "hard_checks":{
            "both_routes_qualified":cross is not None and not failures,
            "failure_count":len(failures),
            "max_additive_or_ledger_residual":max_hard,
            "gate":GATE,
            "classification_match":class_match,
        },
        "failures":failures,
        "classifications":{
            "recovered_primary":primary_classes,
            "new_cross":cross_classes,
        },
        "numerical_floor":(
            c1r.numerical_floor(primary,cross)
            if cross is not None else None
        ),
        "runs":{
            PRIMARY_KEY:primary,
            **({CROSS_KEY:cross} if cross is not None else {})
        },
        "interpretation":[
            "The original C1 0.0001-day primary-route domain exit remains part of the evidence and is not reclassified as a pass.",
            "The already persisted and hard-gated C1 0.00005-day cross route is reused byte-for-value as the C1R recovered-primary route.",
            "Only the preregistered 0.000025-day route is newly executed.",
            "No state, closure, forcing, geometry, width, H(t), decomposition identity, classification rule or tolerance is changed."
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
        "execution_route":result["execution_route"],
    },sort_keys=True))
    return 0 if complete else 2

if __name__=="__main__":
    raise SystemExit(main())
