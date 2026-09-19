#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import pathlib

HERE=pathlib.Path(__file__).resolve().parent

def load_module(name, filename):
    spec=importlib.util.spec_from_file_location(name,HERE/filename)
    mod=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

c2a=load_module("bc2c2a","analyze_lare_bc2_c2a_actual_drift_gain.py")
c0=c2a.c0

VALID_WIDTHS=(2.5,5.0)
VALID_HISTORIES=("WT_HOLD","WT_RISE","WT_FALL","WT_CYCLE")

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c1r-result",required=True,type=pathlib.Path)
    ap.add_argument("--binding",required=True,type=pathlib.Path)
    ap.add_argument("--width",required=True,type=float)
    ap.add_argument("--history",required=True,choices=VALID_HISTORIES)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    if args.width not in VALID_WIDTHS:
        raise SystemExit("unauthorized width")

    pre=json.loads(args.prereg.read_text())
    c1r=json.loads(args.c1r_result.read_text())
    binding=json.loads(args.binding.read_text())
    assert pre["phase"]=="PREREGISTERED_CONDITIONALLY_BEFORE_C1R_RESULT_EXPOSURE"
    assert c1r["decision"]==pre["execution_condition"]["required_C1R_decision"]
    assert c1r["complete"] is True
    assert binding["required_C1R_decision"]==c1r["decision"]
    assert binding["C2_execution_authorized"] is True
    assert binding["C2_preregistration_blob_sha"]
    assert pre["pre_execution_metric_reconciliation"]["execution_authority"]["implementation"]=="tests/rom/analyze_lare_bc2_c2a_actual_drift_gain.py"

    init_meta,init_nodes,states,nodes=c0.b0.load_reference(args.reference)
    row=c2a.run_case(args.history,args.width,init_meta,init_nodes,states,nodes)
    hard=max(
        row["max_abs_free_physical_ledger_residual_cm"],
        row["max_abs_teacher_interval_ledger_residual_cm"],
        row["max_abs_mass_neutral_projection_residual_cm"],
    )
    qualified=row["status"]=="QUALIFIED" and hard<=c2a.HARD_GATE
    result={
        "schema":"swap5.lare.bc2.c2a.case-result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C2A",
        "execution_mode":"SHARDED_EXECUTION_EQUIVALENT",
        "width_cm":args.width,
        "history":args.history,
        "qualified":qualified,
        "hard_max":hard,
        "hard_gate":c2a.HARD_GATE,
        "case":row,
        "model_changed":False,
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "width_cm":args.width,
        "history":args.history,
        "qualified":qualified,
        "gain_summary":row["gain_summary"],
        "first_interval_gain_gt_1":row["first_interval_gain_gt_1"],
        "hard_max":hard,
    },sort_keys=True))
    return 0 if qualified else 2

if __name__=="__main__":
    raise SystemExit(main())
