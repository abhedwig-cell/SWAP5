#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib

WIDTHS=("2.5","5.0")
HISTORIES=("WT_HOLD","WT_RISE","WT_FALL","WT_CYCLE")
GATE=1.0e-10

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--case-dir",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    by_key={}
    for path in sorted(args.case_dir.glob("*.json")):
        p=json.loads(path.read_text())
        if p.get("schema")!="swap5.lare.bc2.c2b.case-result.v1":
            continue
        key=(str(p["width_cm"]),p["history"])
        if key in by_key:
            raise SystemExit(f"duplicate C2B case {key}")
        by_key[key]=p

    expected={(d,h) for d in WIDTHS for h in HISTORIES}
    if set(by_key)!=expected:
        raise SystemExit(f"C2B case set mismatch missing={sorted(expected-set(by_key))} extra={sorted(set(by_key)-expected)}")

    cases={d:{} for d in WIDTHS}
    failures={}
    hard=[]
    for d,h in sorted(expected):
        p=by_key[(d,h)]
        row=p["case"]
        cases[d][h]=row
        hard.append(float(p["hard_max"]))
        if not p["qualified"]:
            failures[f"{d}:{h}"]="CASE_NOT_QUALIFIED"

    max_hard=max(hard or [math.inf])
    complete=not failures and max_hard<=GATE
    result={
        "schema":"swap5.lare.bc2.c2b.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C2B",
        "decision":"BC2_C2B_BLIND_TANGENT_PANEL_MAPPED" if complete else "BC2_C2B_NUMERICAL_DIAGNOSTIC_BLOCKED",
        "complete":complete,
        "execution_mode":"SHARDED_EXECUTION_EQUIVALENT",
        "diagnostic":"FROZEN_MASS_NEUTRAL_ADJACENT_MODE_TANGENT_PANEL",
        "hard_checks":{
            "failure_count":len(failures),
            "max_ledger_or_mass_neutral_residual":max_hard,
            "gate":GATE,
        },
        "failures":failures,
        "cases":cases,
        "interpretation":[
            "Eight width/history cases were executed independently but call the identical preregistered C2B run_case implementation.",
            "Frozen exact Reference-projected states, adjacent mass-neutral modes and both preregistered epsilon amplitudes are unchanged.",
            "Directional gain above one at both epsilon amplitudes is reported per state without fitted consistency tolerance.",
            "No stabilizer, state enrichment, closure change, H feedback or application threshold is introduced."
        ],
        "next_model_change_authorized":False,
        "groundwater_feedback_authorized":False,
        "application_acceptance_adjudicated":False,
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")

    compact={}
    for d,hrows in cases.items():
        compact[d]={}
        for h,row in hrows.items():
            flags=[bool(s["amplifying_both_eps"]) for s in row["state_summaries"]]
            compact[d][h]={
                "selected_start_steps":row["selected_start_steps"],
                "amplifying_state_count":sum(flags),
                "frozen_state_count":len(flags),
                "fraction_amplifying":sum(flags)/len(flags) if flags else 0.0,
                "max_directional_gain":max([x["max_directional_shape_gain"] for x in row["records"]] or [0.0]),
                "skip_count":len(row["skipped_constitutive_directions"]),
                "hard_max":max(row["max_abs_branch_ledger_residual_cm"],row["max_abs_mass_neutral_projection_residual_cm"]),
            }
    print(json.dumps({"decision":result["decision"],"complete":complete,"cases":compact},sort_keys=True))
    return 0 if complete else 2

if __name__=="__main__":
    raise SystemExit(main())
