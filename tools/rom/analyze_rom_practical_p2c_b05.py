#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, pathlib, sys

EVENT=("bottom_flux_sign_mismatch_count","reversal_sequence_mismatch_count","reversal_timing_error_steps")
CONT=("cumulative_bottom_exchange_error_cm","interval_bottom_flux_error_cm_per_day","total_storage_error_cm","history_signed_bottom_flux_bias_cm_per_day","long_horizon_exchange_drift_cm")

def load_module(path:pathlib.Path):
    spec=importlib.util.spec_from_file_location("p2a_analysis",str(path))
    mod=importlib.util.module_from_spec(spec); sys.modules[spec.name]=mod
    spec.loader.exec_module(mod); return mod

def rel(left,right,keys,tol=1e-12):
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

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--p2a-analyzer",required=True,type=pathlib.Path)
    ap.add_argument("--cor-g4",required=True,type=pathlib.Path)
    ap.add_argument("--cor-g6",required=True,type=pathlib.Path)
    ap.add_argument("--fine-reference",required=True,type=pathlib.Path)
    ap.add_argument("--p2a-result",required=True,type=pathlib.Path)
    ap.add_argument("--p2b-result",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    m=load_module(a.p2a_analyzer)
    ref=m.parse_gw(a.fine_reference)
    cor4=m.gw_metrics(m.pseudo_gw(m.parse_gw(a.cor_g4)),ref)
    cor6=m.gw_metrics(m.pseudo_gw(m.parse_gw(a.cor_g6)),ref)
    p2a=json.loads(a.p2a_result.read_text())
    p2b=json.loads(a.p2b_result.read_text())
    lr4=next(x["candidate_metrics"] for x in p2a["cases"] if x["purpose"]=="GW_LB" and x["material"]=="B05")
    lr6=next(x["G6_metrics"] for x in p2b["cases"] if x["material"]=="B05")

    cor4_vs_lr4_event=rel(cor4,lr4,EVENT,0.0)
    cor6_vs_lr6_event=rel(cor6,lr6,EVENT,0.0)
    cor6_vs_cor4_event=rel(cor6,cor4,EVENT,0.0)
    cor4_vs_lr4_cont=rel(cor4,lr4,CONT,1e-12)
    cor6_vs_lr6_cont=rel(cor6,lr6,CONT,1e-12)
    cor6_vs_cor4_cont=rel(cor6,cor4,CONT,1e-12)

    closure_support=(
      (cor4_vs_lr4_event["left_no_worse"] and cor4_vs_lr4_event["left_strict"]) or
      (cor6_vs_lr6_event["left_no_worse"] and cor6_vs_lr6_event["left_strict"])
    )
    representation_persistent=(
      not closure_support and
      cor6_vs_cor4_event["decision"] in ("EQUAL_WITHIN_TOLERANCE","RIGHT_COMPONENTWISE_NO_WORSE","TRADEOFF")
    )
    if closure_support and cor6_vs_cor4_event["left_no_worse"] and cor6_vs_cor4_event["left_strict"]:
        attribution="MIXED_CLOSURE_PROPAGATION_AND_SPATIAL_INFORMATION"
    elif closure_support:
        attribution="CLOSURE_PROPAGATION_DEFECT_SUPPORTED"
    elif representation_persistent:
        attribution="REPRESENTATION_PLACEMENT_DEFECT_SUPPORTED"
    else:
        attribution="MIXED_ATTRIBUTION"

    out={
      "schema":"swap5.rom-practical.p2c-b05.result.v1",
      "workstream":"ROM-PRACTICAL","work_unit":"ROM-PRACTICAL-P2C-B05",
      "status":"P2C_B05_ATTRIBUTION_COMPLETE",
      "B05":{
        "LR_G4":lr4,"LR_G6":lr6,"COR_G4":cor4,"COR_G6":cor6,
        "event_relations":{
          "COR_G4_vs_LR_G4":cor4_vs_lr4_event,
          "COR_G6_vs_LR_G6":cor6_vs_lr6_event,
          "COR_G6_vs_COR_G4":cor6_vs_cor4_event
        },
        "continuous_relations":{
          "COR_G4_vs_LR_G4":cor4_vs_lr4_cont,
          "COR_G6_vs_LR_G6":cor6_vs_lr6_cont,
          "COR_G6_vs_COR_G4":cor6_vs_cor4_cont
        }
      },
      "attribution":attribution,
      "G6_spatial_information_value":bool(cor6_vs_cor4_event["left_no_worse"] and cor6_vs_cor4_event["left_strict"]),
      "G8_executed":False,"closure_changed":False,
      "production_rom_authorized":False,"application_acceptance_adjudicated":False
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"attribution":attribution,"G6_spatial_information_value":out["G6_spatial_information_value"],"event_relations":out["B05"]["event_relations"]},sort_keys=True))
if __name__=="__main__": main()
