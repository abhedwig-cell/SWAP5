#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, math, pathlib, sys

HERE=pathlib.Path(__file__).resolve().parent
HISTS=("Z01","Z02","Z03","Z04")
BASE_DT=0.0008
BASE_STEPS=1024

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    mod=importlib.util.module_from_spec(spec)
    sys.modules[name]=mod
    spec.loader.exec_module(mod)
    return mod

c5b=load("c5b_for_c5g",HERE/"analyze_lare_bc2_c5b_signed_flux_mechanism.py")
fields=c5b.bc.fields

def parse_aggregated(path:pathlib.Path,factor:int):
    states={}
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("LAREGW1_STATE|"):
            r=fields(line.split("|",1)[1])
            h=r.get("HISTORY")
            if h in HISTS:
                states[(h,int(r["STEP"]))]=r
    expected=BASE_STEPS*factor
    out={}
    for h in HISTS:
        bex=[]
        for step in range(1,expected+1):
            key=(h,step)
            if key not in states:
                raise RuntimeError(f"incomplete C5G Reference {key}, factor={factor}")
            bex.append(float(states[key]["BOTTOM_OUTWARD_EXCHANGE"]))
        q=[]
        for i in range(BASE_STEPS):
            q.append(sum(bex[i*factor:(i+1)*factor])/BASE_DT)
        out[h]={"q":q}
    return out

def order(a,b):
    if a<=0.0 or b<=0.0:
        return None
    return math.log(a/b,2.0)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--r512-t1",required=True,type=pathlib.Path)
    ap.add_argument("--r1024-t1",required=True,type=pathlib.Path)
    ap.add_argument("--r512-t2",required=True,type=pathlib.Path)
    ap.add_argument("--r1024-t2",required=True,type=pathlib.Path)
    ap.add_argument("--r512-t4",required=True,type=pathlib.Path)
    ap.add_argument("--r1024-t4",required=True,type=pathlib.Path)
    ap.add_argument("--c5f-result",required=True,type=pathlib.Path)
    ap.add_argument("--c5f-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    p=json.loads(a.prereg.read_text())
    c5fr=json.loads(a.c5f_result.read_text())
    c5fc=json.loads(a.c5f_closeout.read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_C5G_R512_T4_RESPONSE"
    assert c5fc["status"]=="CLOSED_TEMPORAL_PROGRESS_SUBDOMINANT_BUT_SPATIOTEMPORAL_INTERACTION_NONNEGLIGIBLE_MATCHED_T4_SPATIAL_CELL_REQUIRED"
    assert c5fc["authority"]["result_sha256"]=="ae686248db6b782047b0fce1f3fb01116d3dcda6dd691516aa2cc21b1b3ba180"

    r512={1:parse_aggregated(a.r512_t1,1),2:parse_aggregated(a.r512_t2,2),4:parse_aggregated(a.r512_t4,4)}
    r1024={1:parse_aggregated(a.r1024_t1,1),2:parse_aggregated(a.r1024_t2,2),4:parse_aggregated(a.r1024_t4,4)}

    spatial={f"T{f}":c5b.qdistance(r512[f],r1024[f]) for f in (1,2,4)}
    temporal_512={
      "T1_T2":c5b.qdistance(r512[1],r512[2]),
      "T2_T4":c5b.qdistance(r512[2],r512[4]),
    }
    temporal_1024={
      "T1_T2":c5b.qdistance(r1024[1],r1024[2]),
      "T2_T4":c5b.qdistance(r1024[2],r1024[4]),
    }

    frozen_sp1=float(c5fr["spatial"]["R512_T1_vs_R1024_T1"]["rmse_cm_per_day"])
    frozen_sp2=float(c5fr["spatial"]["R512_T2_vs_R1024_T2"]["rmse_cm_per_day"])
    frozen_1024_t24=float(c5fr["temporal"]["R1024_T2_T4"]["rmse_cm_per_day"])
    baseline_identity={
      "spatial_T1":abs(spatial["T1"]["rmse_cm_per_day"]-frozen_sp1)<=1e-15,
      "spatial_T2":abs(spatial["T2"]["rmse_cm_per_day"]-frozen_sp2)<=1e-15,
      "R1024_T2_T4":abs(temporal_1024["T2_T4"]["rmse_cm_per_day"]-frozen_1024_t24)<=1e-15,
    }
    if not all(baseline_identity.values()):
        raise RuntimeError("C5G baseline does not reproduce C5F anchors")

    sp1=spatial["T1"]["rmse_cm_per_day"]
    sp2=spatial["T2"]["rmse_cm_per_day"]
    sp4=spatial["T4"]["rmse_cm_per_day"]
    t512_12=temporal_512["T1_T2"]["rmse_cm_per_day"]
    t512_24=temporal_512["T2_T4"]["rmse_cm_per_day"]
    t1024_12=temporal_1024["T1_T2"]["rmse_cm_per_day"]
    t1024_24=temporal_1024["T2_T4"]["rmse_cm_per_day"]

    if sp4 < sp2-1e-12:
        status="MATRIX_COMPLETE_SPATIAL_GAP_DECREASES_AT_T4"
    elif sp4 > sp2+1e-12:
        status="MATRIX_COMPLETE_SPATIAL_GAP_INCREASES_AT_T4"
    else:
        status="MATRIX_COMPLETE_SPATIAL_GAP_NUMERICALLY_UNCHANGED_AT_T4"

    out={
      "schema":"swap5.lare.bc2.c5g.result.v1",
      "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C5G",
      "role":"MATCHED_R512_R1024_X_T1_T2_T4_REFERENCE_MATRIX_COMPLETION",
      "status":status,
      "formal_C5A_decision_retained":"C5A_DYNAMIC_HEAD_REDUCED_FRONTIER_NOT_PRESERVED",
      "baseline_identity_to_C5F":baseline_identity,
      "common_output_window_day":BASE_DT,
      "spatial":spatial,
      "temporal":{
        "R512":temporal_512,
        "R1024":temporal_1024,
        "order_R512":order(t512_12,t512_24),
        "order_R1024":order(t1024_12,t1024_24),
      },
      "interaction":{
        "spatial_T2_over_T1":sp2/sp1,
        "spatial_T4_over_T2":sp4/sp2,
        "spatial_T4_over_T1":sp4/sp1,
        "R512_T2_T4_over_spatial_T4":t512_24/sp4 if sp4 else None,
        "R1024_T2_T4_over_spatial_T4":t1024_24/sp4 if sp4 else None,
        "temporal_T2_T4_resolution_ratio_R1024_over_R512":t1024_24/t512_24 if t512_24 else None,
        "spatial_gap_abs_change_T1_to_T2":abs(sp2-sp1),
        "spatial_gap_abs_change_T2_to_T4":abs(sp4-sp2),
      },
      "signed_diagnostics":{
        "spatial_T4":c5b.signed_diagnostics(r512[4],r1024[4]),
        "temporal_R512_T2_T4":c5b.signed_diagnostics(r512[2],r512[4]),
        "temporal_R1024_T2_T4":c5b.signed_diagnostics(r1024[2],r1024[4]),
      },
      "interpretation_boundaries":[
        "C5G adds exactly one new cell, R512 T4, to complete the matched 2x3 space-time matrix.",
        "All comparisons are aggregated to the original 0.0008-day physical windows.",
        "Temporal and spatial ratios are diagnostic scale comparisons, not application tolerances.",
        "No result from C5G by itself establishes continuum truth or authorizes LARE/closure changes."
      ],
      "scientific_firewall":{
        "new_lare_run":False,
        "new_closure_fit":False,
        "physical_history_changed":False,
        "numerical_policy_changed":False,
        "C5A_formal_decision_changed":False,
        "application_acceptance_adjudicated":False,
        "performance_comparison_authorized":False,
        "speed_claim_authorized":False,
        "production_rom_authorized":False
      }
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "status":status,
      "spatial_RMSE":{"T1":sp1,"T2":sp2,"T4":sp4},
      "temporal_RMSE":{
        "R512_T1_T2":t512_12,"R512_T2_T4":t512_24,
        "R1024_T1_T2":t1024_12,"R1024_T2_T4":t1024_24
      },
      "temporal_orders":{"R512":out["temporal"]["order_R512"],"R1024":out["temporal"]["order_R1024"]},
      "interaction":out["interaction"]
    },sort_keys=True))

if __name__=="__main__":
    main()
