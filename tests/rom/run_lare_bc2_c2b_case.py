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

c2b=load_module("bc2c2b","analyze_lare_bc2_c2b_tangent_panel.py")
c1=c2b.c1
c0=c2b.c0

VALID_WIDTHS=(2.5,5.0)
VALID_HISTORIES=("WT_HOLD","WT_RISE","WT_FALL","WT_CYCLE")

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c1r-result",required=True,type=pathlib.Path)
    ap.add_argument("--c2a-result",required=True,type=pathlib.Path)
    ap.add_argument("--binding",required=True,type=pathlib.Path)
    ap.add_argument("--width",required=True,type=float)
    ap.add_argument("--history",required=True,choices=VALID_HISTORIES)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    if args.width not in VALID_WIDTHS:
        raise SystemExit("unauthorized width")

    pre=json.loads(args.prereg.read_text())
    c1r=json.loads(args.c1r_result.read_text())
    c2a=json.loads(args.c2a_result.read_text())
    binding=json.loads(args.binding.read_text())

    assert pre["phase"]=="PREREGISTERED_CONDITIONALLY_BEFORE_C1R_RESULT_EXPOSURE"
    assert tuple(pre["diagnostic_B_blind_tangent_panel"]["perturbation_amplitudes_theta"])==c2b.EPSILONS
    assert c1r["decision"]=="BC2_C1R_NUMERICAL_QUALIFICATION_RECOVERED"
    assert c1r["complete"] is True
    assert c2a["decision"]=="BC2_C2A_ACTUAL_DRIFT_GAIN_MAPPED"
    assert c2a["complete"] is True
    assert c2a["diagnostic_B_authorized"] is True
    assert binding["required_C2A_decision"]==c2a["decision"]
    assert binding["C2B_execution_authorized"] is True

    init_meta,init_nodes,states,nodes=c0.b0.load_reference(args.reference)
    row=c2b.run_case(args.history,args.width,init_meta,init_nodes,states,nodes)
    hard=max(
        row["max_abs_branch_ledger_residual_cm"],
        row["max_abs_mass_neutral_projection_residual_cm"],
    )
    qualified=row["status"]=="QUALIFIED" and hard<=c2b.GATE

    result={
        "schema":"swap5.lare.bc2.c2b.case-result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C2B",
        "execution_mode":"SHARDED_EXECUTION_EQUIVALENT",
        "width_cm":args.width,
        "history":args.history,
        "qualified":qualified,
        "hard_max":hard,
        "hard_gate":c2b.GATE,
        "case":row,
        "model_changed":False,
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")

    flags=[
        bool(s["amplifying_both_eps"])
        for s in row["state_summaries"]
    ]
    print(json.dumps({
        "width_cm":args.width,
        "history":args.history,
        "qualified":qualified,
        "selected_start_steps":row["selected_start_steps"],
        "amplifying_state_count":sum(flags),
        "frozen_state_count":len(flags),
        "fraction_amplifying":sum(flags)/len(flags) if flags else 0.0,
        "max_directional_gain":max([r["max_directional_shape_gain"] for r in row["records"]] or [0.0]),
        "skip_count":len(row["skipped_constitutive_directions"]),
        "hard_max":hard,
    },sort_keys=True))
    return 0 if qualified else 2

if __name__=="__main__":
    raise SystemExit(main())
