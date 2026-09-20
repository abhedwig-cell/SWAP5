#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, math, pathlib, sys
import numpy as np

HERE=pathlib.Path(__file__).resolve().parent
HISTS=("Z01","Z02","Z03","Z04")
FACTOR=16
BASE_DT=0.0008
BASE_STEPS=1024

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    mod=importlib.util.module_from_spec(spec)
    sys.modules[name]=mod
    spec.loader.exec_module(mod)
    return mod

c5b=load("c5b_for_c5l",HERE/"analyze_lare_bc2_c5b_signed_flux_mechanism.py")
fields=c5b.bc.fields

def parse(path:pathlib.Path):
    states={}
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("LAREGW1_STATE|"):
            r=fields(line.split("|",1)[1])
            h=r.get("HISTORY")
            if h in HISTS:
                states[(h,int(r["STEP"]))]=r
    out={}
    for h in HISTS:
        bex=[]
        for step in range(1,BASE_STEPS*FACTOR+1):
            k=(h,step)
            if k not in states:
                raise RuntimeError(f"incomplete C5L route {path} {k}")
            bex.append(float(states[k]["BOTTOM_OUTWARD_EXCHANGE"]))
        out[h]={"q":[sum(bex[i*FACTOR:(i+1)*FACTOR])/BASE_DT for i in range(BASE_STEPS)]}
    return out

def order(a,b):
    if a<=0.0 or b<=0.0:return None
    return math.log(a/b,2.0)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--r512",required=True,type=pathlib.Path)
    ap.add_argument("--r1024",required=True,type=pathlib.Path)
    ap.add_argument("--r2048",required=True,type=pathlib.Path)
    ap.add_argument("--c5i-result",required=True,type=pathlib.Path)
    ap.add_argument("--c5k-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    p=json.loads(a.prereg.read_text())
    c5i=json.loads(a.c5i_result.read_text())
    c5k=json.loads(a.c5k_closeout.read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_C5L_R2048_RESPONSE"
    assert c5k["status"]=="CLOSED_LOCAL_HALF_CELL_THEORY_DOES_NOT_SUPPORT_NEW_DYNAMIC_BOUNDARY_OPERATOR_CURRENT_REFERENCE_SPATIAL_EXTENSION_NEXT"
    assert c5k["authority"]["result_sha256"]=="aeb315e72d2b4f60cd8e01cac316bbb89d703ed9f3166b0e0f34f064969a1ce9"
    assert c5k["adjudication"]["CURRENT_REFERENCE_R2048_T16_EXTENSION_AUTHORIZED"] is True

    r512=parse(a.r512); r1024=parse(a.r1024); r2048=parse(a.r2048)
    d512_1024=c5b.qdistance(r512,r1024)
    d1024_2048=c5b.qdistance(r1024,r2048)
    d512_2048=c5b.qdistance(r512,r2048)
    frozen=float(c5i["spatial"]["T16"]["rmse_cm_per_day"])
    baseline_identity=abs(d512_1024["rmse_cm_per_day"]-frozen)<=1e-15
    if not baseline_identity:
        raise RuntimeError("C5L R512-R1024 baseline does not reproduce C5I T16")

    aerr=d512_1024["rmse_cm_per_day"]; berr=d1024_2048["rmse_cm_per_day"]
    if berr<aerr:
        direction="SPATIAL_REFINEMENT_PROGRESSING_AT_R2048"
    elif berr>aerr:
        direction="SPATIAL_REFINEMENT_NOT_PROGRESSING_AT_R2048"
    else:
        direction="SPATIAL_ADJACENT_GAP_NUMERICALLY_UNCHANGED_AT_R2048"

    temporal_anchor=float(c5i["temporal"]["R1024"]["T8_T16"]["rmse_cm_per_day"])
    out={
      "schema":"swap5.lare.bc2.c5l.result.v1",
      "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C5L",
      "role":"CURRENT_REFERENCE_SINGLE_R2048_T16_SPATIAL_EXTENSION",
      "status":direction,
      "formal_C5A_decision_retained":"C5A_DYNAMIC_HEAD_REDUCED_FRONTIER_NOT_PRESERVED",
      "baseline_identity_to_C5I_T16":baseline_identity,
      "adjacent_spatial":{
        "R512_R1024":d512_1024,
        "R1024_R2048":d1024_2048,
        "R512_R2048":d512_2048,
        "R1024_R2048_over_R512_R1024":berr/aerr,
        "descriptive_order_R512_R1024_R2048":order(aerr,berr)
      },
      "signed_diagnostics":{
        "R512_R1024":c5b.signed_diagnostics(r512,r1024),
        "R1024_R2048":c5b.signed_diagnostics(r1024,r2048)
      },
      "temporal_context":{
        "frozen_R1024_T8_T16_RMSE_cm_per_day":temporal_anchor,
        "R1024_R2048_spatial_over_frozen_R1024_temporal_anchor":berr/temporal_anchor if temporal_anchor else None,
        "note":"Cross-scale context only; R2048 temporal error was not independently refined in C5L."
      },
      "interpretation_boundaries":[
        "C5L changes spatial resolution only and retains the exact current Reference G0K0 boundary and T16 transaction interval.",
        "A smaller adjacent-grid difference indicates spatial refinement progress, not continuum truth.",
        "The descriptive order is not an application tolerance or admission threshold.",
        "R2048 is not automatically a new scientific truth reference.",
        "C5L does not authorize a production Reference change, LARE rerun or speed claim."
      ],
      "scientific_firewall":{
        "production_reference_changed":False,
        "boundary_counterfactual_executed":False,
        "new_reference_physics_admitted":False,
        "T32_executed":False,
        "R4096_executed":False,
        "new_lare_run":False,
        "new_lare_closure":False,
        "C5A_formal_decision_changed":False,
        "application_acceptance_adjudicated":False,
        "performance_comparison_authorized":False,
        "speed_claim_authorized":False,
        "production_rom_authorized":False
      }
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "status":direction,
      "R512_R1024_RMSE":aerr,
      "R1024_R2048_RMSE":berr,
      "ratio":berr/aerr,
      "order":out["adjacent_spatial"]["descriptive_order_R512_R1024_R2048"],
      "spatial_over_temporal_anchor":out["temporal_context"]["R1024_R2048_spatial_over_frozen_R1024_temporal_anchor"]
    },sort_keys=True))

if __name__=="__main__":
    main()
