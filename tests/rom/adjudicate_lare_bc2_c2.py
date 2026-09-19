#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib

WIDTHS=("2.5","5.0")
HISTORIES=("WT_HOLD","WT_RISE","WT_FALL","WT_CYCLE")

def actual_amplifying(row):
    frac=row["gain_summary"]["fraction_gt_1"]
    return frac is not None and float(frac)>0.5

def tangent_state_flags(row):
    selected=[int(x) for x in row["selected_start_steps"]]
    by_state={s:False for s in selected}
    for rec in row["records"]:
        vals=list(rec["amplitudes"].values())
        if len(vals)!=2:
            continue
        if all(float(v["directional_shape_gain"])>1.0 for v in vals):
            by_state[int(rec["start_step"])]=True
    return by_state

def tangent_amplifying(row):
    flags=tangent_state_flags(row)
    if not flags:
        return False
    return sum(bool(v) for v in flags.values())/len(flags)>0.5

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c2a",required=True,type=pathlib.Path)
    ap.add_argument("--c2b",required=True,type=pathlib.Path)
    ap.add_argument("--binding",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    a=json.loads(args.c2a.read_text())
    b=json.loads(args.c2b.read_text())
    binding=json.loads(args.binding.read_text())
    rules=pre["pre_execution_decision_rule_clarification"]
    assert a["decision"]=="BC2_C2A_ACTUAL_DRIFT_GAIN_MAPPED" and a["complete"] is True
    assert b["decision"]=="BC2_C2B_BLIND_TANGENT_PANEL_MAPPED" and b["complete"] is True
    assert binding["required_C2A_decision"]==a["decision"]
    assert binding["required_C2B_decision"]==b["decision"]
    assert binding["C2C_execution_authorized"] is True
    assert "More than 50%" in rules["actual_case_amplifying"]
    assert "More than 50%" in rules["tangent_case_amplifying"]

    cases={}
    classes=[]
    for d in WIDTHS:
        cases[d]={}
        for h in HISTORIES:
            ar=a["cases"][d][h]
            br=b["cases"][d][h]
            aa=actual_amplifying(ar)
            flags=tangent_state_flags(br)
            ta=tangent_amplifying(br)
            if aa and ta:
                cls="AMPLIFICATION_SUPPORTED"
            elif (not aa) and (not ta):
                cls="BIAS_ACCUMULATION_SUPPORTED"
            else:
                cls="MIXED_STATE_DYNAMICS"
            classes.append(cls)
            cases[d][h]={
                "classification":cls,
                "actual_case_amplifying":aa,
                "actual_gain_fraction_gt_1":ar["gain_summary"]["fraction_gt_1"],
                "actual_gain_median":ar["gain_summary"]["median"],
                "actual_gain_p95":ar["gain_summary"]["p95"],
                "actual_gain_max":ar["gain_summary"]["max"],
                "tangent_case_amplifying":ta,
                "tangent_amplifying_state_count":sum(bool(v) for v in flags.values()),
                "tangent_frozen_state_count":len(flags),
                "tangent_state_flags":{str(k):v for k,v in sorted(flags.items())},
                "tangent_max_directional_gain":max(
                    [float(x["max_directional_shape_gain"]) for x in br["records"]] or [0.0]
                ),
                "tangent_constitutive_skip_count":len(br["skipped_constitutive_directions"]),
            }

    if all(x=="AMPLIFICATION_SUPPORTED" for x in classes):
        decision="MANIFOLD_AMPLIFICATION_SUPPORTED"
        next_direction="Investigate a physically explicit invariant/manifold-stability treatment before changing local closure formulas."
    elif all(x=="BIAS_ACCUMULATION_SUPPORTED" for x in classes):
        decision="BIAS_ACCUMULATION_DOMINANT"
        next_direction="Investigate persistent teacher-reference local closure bias by channel; no stabilizer is justified."
    else:
        decision="MIXED_STATE_DYNAMICS"
        next_direction="Retain width/history-specific dynamics. Do not introduce one global stabilizer or wholesale closure replacement."

    result={
        "schema":"swap5.lare.bc2.c2c.adjudication.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C2C",
        "decision":decision,
        "complete":True,
        "case_classifications":cases,
        "classification_counts":{
            name:classes.count(name)
            for name in ("AMPLIFICATION_SUPPORTED","BIAS_ACCUMULATION_SUPPORTED","MIXED_STATE_DYNAMICS")
        },
        "next_research_direction":next_direction,
        "interpretation":[
            "C2A and C2B use the unchanged C0 map and do not modify the reduced model.",
            "A case requires both repeated actual-error amplification and blind local mass-neutral tangent amplification to support the amplification label.",
            "Only unanimous eight-case agreement permits a global amplification or bias-accumulation conclusion; otherwise the result is explicitly mixed.",
            "The g=1 boundary and strict-majority rules were frozen before C2 response exposure."
        ],
        "next_model_change_authorized":False,
        "groundwater_feedback_authorized":False,
        "application_acceptance_adjudicated":False,
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":decision,
        "classification_counts":result["classification_counts"],
        "cases":cases
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
