#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, pathlib, sys

EVENT=("bottom_flux_sign_mismatch_count","reversal_sequence_mismatch_count","reversal_timing_error_steps")
CONT=("cumulative_bottom_exchange_error_cm","interval_bottom_flux_error_cm_per_day","total_storage_error_cm","history_signed_bottom_flux_bias_cm_per_day","long_horizon_exchange_drift_cm")

def load_module(path):
    spec=importlib.util.spec_from_file_location("p2a_analysis",str(path))
    mod=importlib.util.module_from_spec(spec); sys.modules[spec.name]=mod
    spec.loader.exec_module(mod); return mod

def relation(left,right,keys,tol=1e-12):
    l=all(float(left[k])<=float(right[k])+tol for k in keys)
    r=all(float(right[k])<=float(left[k])+tol for k in keys)
    ls=any(float(left[k])<float(right[k])-tol for k in keys)
    rs=any(float(right[k])<float(left[k])-tol for k in keys)
    if l and ls and not (r and rs): d="LEFT_COMPONENTWISE_NO_WORSE"
    elif r and rs and not (l and ls): d="RIGHT_COMPONENTWISE_NO_WORSE"
    elif l and r: d="EQUAL_WITHIN_TOLERANCE"
    else: d="TRADEOFF"
    return {"decision":d,"left_no_worse":l,"right_no_worse":r,"left_strict":ls,"right_strict":rs,
            "left_minus_right":{k:float(left[k])-float(right[k]) for k in keys}}

def candidate_metrics(m,path,ref):
    obj=json.loads(path.read_text())
    return m.gw_metrics(obj["histories"],ref)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--p2a-analyzer",required=True,type=pathlib.Path)
    ap.add_argument("--lr-g8",required=True,type=pathlib.Path)
    ap.add_argument("--lr-u8",required=True,type=pathlib.Path)
    ap.add_argument("--cor-g8",required=True,type=pathlib.Path)
    ap.add_argument("--cor-u8",required=True,type=pathlib.Path)
    ap.add_argument("--fine-reference",required=True,type=pathlib.Path)
    ap.add_argument("--r128",required=True,type=pathlib.Path)
    ap.add_argument("--p2b-result",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    m=load_module(a.p2a_analyzer)
    ref=m.parse_gw(a.fine_reference); r128=m.parse_gw(a.r128)
    comp=m.gw_metrics(m.pseudo_gw(r128),ref)
    lr8=candidate_metrics(m,a.lr_g8,ref)
    lu8=candidate_metrics(m,a.lr_u8,ref)
    cg8=m.gw_metrics(m.pseudo_gw(m.parse_gw(a.cor_g8)),ref)
    cu8=m.gw_metrics(m.pseudo_gw(m.parse_gw(a.cor_u8)),ref)
    p2b=json.loads(a.p2b_result.read_text())
    g6=next(x["G6_metrics"] for x in p2b["cases"] if x["material"]=="B05")

    rels={
      "LR_G8_vs_G6_event":relation(lr8,g6,EVENT,0.0),
      "LR_U8_vs_G6_event":relation(lu8,g6,EVENT,0.0),
      "LR_G8_vs_LR_U8_event":relation(lr8,lu8,EVENT,0.0),
      "COR_G8_vs_LR_G8_event":relation(cg8,lr8,EVENT,0.0),
      "COR_U8_vs_LR_U8_event":relation(cu8,lu8,EVENT,0.0),
      "COR_G8_vs_COR_U8_event":relation(cg8,cu8,EVENT,0.0),
      "LR_G8_vs_G6_cont":relation(lr8,g6,CONT,1e-12),
      "LR_U8_vs_G6_cont":relation(lu8,g6,CONT,1e-12),
      "LR_G8_vs_LR_U8_cont":relation(lr8,lu8,CONT,1e-12),
      "COR_G8_vs_LR_G8_cont":relation(cg8,lr8,CONT,1e-12),
      "COR_U8_vs_LR_U8_cont":relation(cu8,lu8,CONT,1e-12)
    }

    closure_emerges=(
      (rels["COR_G8_vs_LR_G8_event"]["left_no_worse"] and rels["COR_G8_vs_LR_G8_event"]["left_strict"]) or
      (rels["COR_U8_vs_LR_U8_event"]["left_no_worse"] and rels["COR_U8_vs_LR_U8_event"]["left_strict"])
    )
    placement_u8=(rels["LR_G8_vs_LR_U8_event"]["right_no_worse"] and rels["LR_G8_vs_LR_U8_event"]["right_strict"])
    g8_improves=(rels["LR_G8_vs_G6_event"]["left_no_worse"] and rels["LR_G8_vs_G6_event"]["left_strict"])
    u8_improves=(rels["LR_U8_vs_G6_event"]["left_no_worse"] and rels["LR_U8_vs_G6_event"]["left_strict"])
    g8_no_worse_u8=rels["LR_G8_vs_LR_U8_event"]["left_no_worse"]

    if closure_emerges:
        decision="CLOSURE_EFFECT_EMERGES_AT_EIGHT_STATES"
    elif placement_u8:
        decision="PLACEMENT_MISMATCH_SUPPORTED"
    elif g8_improves and g8_no_worse_u8:
        decision="LOWER_FOCUSED_STATE_COUNT_VALUE"
    elif not g8_improves and not u8_improves:
        decision="EIGHT_STATE_REPRESENTATION_INSUFFICIENT"
    else:
        decision="MIXED"

    out={
      "schema":"swap5.rom-practical.p2d-b05.result.v1",
      "workstream":"ROM-PRACTICAL","work_unit":"ROM-PRACTICAL-P2D-B05",
      "status":"P2D_B05_EIGHT_STATE_ATTRIBUTION_COMPLETE",
      "metrics":{"G6":g6,"LR_G8":lr8,"LR_U8":lu8,"COR_G8":cg8,"COR_U8":cu8,"R128_vs_R256":comp},
      "relations":rels,
      "decision":decision,
      "closure_effect_emerges":closure_emerges,
      "G8_improves_G6":g8_improves,
      "U8_improves_G6":u8_improves,
      "U8_better_than_G8":placement_u8,
      "state_count_above_8_executed":False,
      "new_closure_executed":False,
      "production_rom_authorized":False,
      "application_acceptance_adjudicated":False
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"G8_improves_G6":g8_improves,"U8_improves_G6":u8_improves,"U8_better_than_G8":placement_u8,"closure_effect_emerges":closure_emerges},sort_keys=True))
if __name__=="__main__": main()
