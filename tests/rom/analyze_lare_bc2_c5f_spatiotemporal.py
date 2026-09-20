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

c5b=load("c5b_for_c5f",HERE/"analyze_lare_bc2_c5b_signed_flux_mechanism.py")
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
                raise RuntimeError(f"incomplete C5F Reference {key}, factor={factor}")
            bex.append(float(states[key]["BOTTOM_OUTWARD_EXCHANGE"]))
        q=[]
        for i in range(BASE_STEPS):
            chunk=bex[i*factor:(i+1)*factor]
            q.append(sum(chunk)/BASE_DT)
        out[h]={"q":q}
    return out

def order(a,b):
    if a<=0.0 or b<=0.0:return None
    return math.log(a/b,2.0)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--r512-t1",required=True,type=pathlib.Path)
    ap.add_argument("--r1024-t1",required=True,type=pathlib.Path)
    ap.add_argument("--r512-t2",required=True,type=pathlib.Path)
    ap.add_argument("--r1024-t2",required=True,type=pathlib.Path)
    ap.add_argument("--r1024-t4",type=pathlib.Path)
    ap.add_argument("--c5e-result",required=True,type=pathlib.Path)
    ap.add_argument("--c5e-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    p=json.loads(a.prereg.read_text())
    c5er=json.loads(a.c5e_result.read_text())
    c5ec=json.loads(a.c5e_closeout.read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_C5F_REFINED_TIME_RESPONSE"
    assert c5ec["status"]=="CLOSED_REFERENCE_REFINEMENT_STRONGLY_IMPROVING_THROUGH_R1024_SPATIOTEMPORAL_RECONCILIATION_NEXT"
    assert c5ec["authority"]["result_sha256"]=="80288f4dbc6d7fce59aef7c92226de702a8506810c3c49debf486abcf906e75a"

    r512_t1=parse_aggregated(a.r512_t1,1)
    r1024_t1=parse_aggregated(a.r1024_t1,1)
    r512_t2=parse_aggregated(a.r512_t2,2)
    r1024_t2=parse_aggregated(a.r1024_t2,2)
    t4_available=a.r1024_t4 is not None and a.r1024_t4.exists()
    r1024_t4=parse_aggregated(a.r1024_t4,4) if t4_available else None

    spatial_t1=c5b.qdistance(r512_t1,r1024_t1)
    spatial_t2=c5b.qdistance(r512_t2,r1024_t2)
    temporal_512_t1_t2=c5b.qdistance(r512_t1,r512_t2)
    temporal_1024_t1_t2=c5b.qdistance(r1024_t1,r1024_t2)

    frozen=float(c5er["adjacent_grid_distances"]["R512_vs_R1024"]["rmse_cm_per_day"])
    baseline_identity={
      "R512_R1024_T1_RMSE":abs(spatial_t1["rmse_cm_per_day"]-frozen)<=1e-15
    }
    if not all(baseline_identity.values()):
        raise RuntimeError("C5F baseline parser does not reproduce C5E R512-R1024")

    temporal={}
    if t4_available:
        temporal_1024_t2_t4=c5b.qdistance(r1024_t2,r1024_t4)
        temporal={
          "R1024_T2_T4":temporal_1024_t2_t4,
          "estimated_temporal_order_R1024":order(
            temporal_1024_t1_t2["rmse_cm_per_day"],
            temporal_1024_t2_t4["rmse_cm_per_day"]
          ),
          "temporal_progressing_at_T4":temporal_1024_t2_t4["rmse_cm_per_day"]<temporal_1024_t1_t2["rmse_cm_per_day"],
          "finest_temporal_shift_over_spatial_T2":(
            temporal_1024_t2_t4["rmse_cm_per_day"]/spatial_t2["rmse_cm_per_day"]
            if spatial_t2["rmse_cm_per_day"] else None
          ),
          "finest_temporal_shift_subdominant_to_spatial_T2":(
            temporal_1024_t2_t4["rmse_cm_per_day"]<spatial_t2["rmse_cm_per_day"]
          )
        }
    else:
        temporal={
          "R1024_T2_T4":None,
          "estimated_temporal_order_R1024":None,
          "temporal_progressing_at_T4":None,
          "finest_temporal_shift_over_spatial_T2":None,
          "finest_temporal_shift_subdominant_to_spatial_T2":None
        }

    ratios={
      "R512_T1_T2_over_spatial_T1":temporal_512_t1_t2["rmse_cm_per_day"]/spatial_t1["rmse_cm_per_day"],
      "R1024_T1_T2_over_spatial_T1":temporal_1024_t1_t2["rmse_cm_per_day"]/spatial_t1["rmse_cm_per_day"],
      "spatial_T2_over_spatial_T1":spatial_t2["rmse_cm_per_day"]/spatial_t1["rmse_cm_per_day"],
      "spatial_interaction_abs_change_fraction":abs(spatial_t2["rmse_cm_per_day"]-spatial_t1["rmse_cm_per_day"])/spatial_t1["rmse_cm_per_day"]
    }

    if t4_available and temporal["temporal_progressing_at_T4"] and temporal["finest_temporal_shift_subdominant_to_spatial_T2"]:
        status="TEMPORAL_REFINEMENT_PROGRESSING_AND_SUBDOMINANT_TO_R512_R1024_SPATIAL_GAP"
    elif t4_available and temporal["temporal_progressing_at_T4"]:
        status="TEMPORAL_REFINEMENT_PROGRESSING_BUT_NOT_SUBDOMINANT_TO_SPATIAL_GAP"
    elif t4_available:
        status="TEMPORAL_REFINEMENT_NOT_PROGRESSING_AT_R1024"
    else:
        status="R1024_T4_QUALIFICATION_UNAVAILABLE_TEMPORAL_RECONCILIATION_PARTIAL"

    out={
      "schema":"swap5.lare.bc2.c5f.result.v1",
      "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C5F",
      "role":"REFERENCE_ONLY_SPATIOTEMPORAL_RECONCILIATION",
      "status":status,
      "formal_C5A_decision_retained":"C5A_DYNAMIC_HEAD_REDUCED_FRONTIER_NOT_PRESERVED",
      "baseline_identity_to_C5E":baseline_identity,
      "T4_available":t4_available,
      "common_output_window_day":BASE_DT,
      "spatial":{
        "R512_T1_vs_R1024_T1":spatial_t1,
        "R512_T2_vs_R1024_T2":spatial_t2
      },
      "temporal":{
        "R512_T1_vs_T2":temporal_512_t1_t2,
        "R1024_T1_vs_T2":temporal_1024_t1_t2,
        **temporal
      },
      "ratios":ratios,
      "signed_diagnostics":{
        "spatial_R512_T2_vs_R1024_T2":c5b.signed_diagnostics(r512_t2,r1024_t2),
        "temporal_R1024_T1_vs_T2":c5b.signed_diagnostics(r1024_t1,r1024_t2),
        "temporal_R1024_T2_vs_T4":c5b.signed_diagnostics(r1024_t2,r1024_t4) if t4_available else None
      },
      "interpretation_boundaries":[
        "All refined-time exchanges are aggregated back to the original 0.0008-day physical windows before comparison.",
        "Seed transactions are unchanged so C5F refines only the main dynamic-history transaction interval.",
        "A temporal shift smaller than the same-scale spatial gap is a relative dominance statement, not a hydrological acceptance tolerance.",
        "C5F does not by itself admit R1024 as continuum truth or authorize a LARE closure."
      ],
      "scientific_firewall":{
        "new_lare_run":False,
        "new_closure_fit":False,
        "physical_history_changed":False,
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
      "spatial_T1_RMSE":spatial_t1["rmse_cm_per_day"],
      "spatial_T2_RMSE":spatial_t2["rmse_cm_per_day"],
      "temporal_R512_T1_T2":temporal_512_t1_t2["rmse_cm_per_day"],
      "temporal_R1024_T1_T2":temporal_1024_t1_t2["rmse_cm_per_day"],
      "temporal_R1024_T2_T4":None if not t4_available else temporal["R1024_T2_T4"]["rmse_cm_per_day"],
      "ratios":ratios,
      "temporal_order":temporal["estimated_temporal_order_R1024"],
      "finest_temporal_over_spatial":temporal["finest_temporal_shift_over_spatial_T2"]
    },sort_keys=True))

if __name__=="__main__":
    main()
