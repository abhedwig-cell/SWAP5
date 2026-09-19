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

    files=sorted(args.case_dir.glob("*.json"))
    by_key={}
    for path in files:
        p=json.loads(path.read_text())
        if p.get("schema")!="swap5.lare.bc2.c2a.case-result.v1":
            continue
        key=(str(p["width_cm"]),p["history"])
        if key in by_key:
            raise SystemExit(f"duplicate C2A case {key}")
        by_key[key]=p

    expected={(d,h) for d in WIDTHS for h in HISTORIES}
    if set(by_key)!=expected:
        raise SystemExit(f"C2A case set mismatch missing={sorted(expected-set(by_key))} extra={sorted(set(by_key)-expected)}")

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
        "schema":"swap5.lare.bc2.c2a.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C2A",
        "decision":"BC2_C2A_ACTUAL_DRIFT_GAIN_MAPPED" if complete else "BC2_C2A_DIAGNOSTIC_BLOCKED",
        "complete":complete,
        "execution_mode":"SHARDED_EXECUTION_EQUIVALENT",
        "diagnostic":"ACTUAL_TRAJECTORY_ONE_INTERVAL_SHAPE_GAIN",
        "hard_checks":{
            "failure_count":len(failures),
            "max_ledger_or_mass_neutral_residual":max_hard,
            "gate":GATE,
        },
        "failures":failures,
        "cases":cases,
        "interpretation":[
            "Eight width/history cases were executed independently but use the identical preregistered C2A algorithm and immutable Reference authority.",
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
            "hard_max":max(
                row["max_abs_free_physical_ledger_residual_cm"],
                row["max_abs_teacher_interval_ledger_residual_cm"],
                row["max_abs_mass_neutral_projection_residual_cm"],
            ),
        } for h,row in hrows.items()}
        for d,hrows in cases.items()
    }
    print(json.dumps({
        "decision":result["decision"],
        "complete":complete,
        "cases":compact
    },sort_keys=True))
    return 0 if complete else 2

if __name__=="__main__":
    raise SystemExit(main())
