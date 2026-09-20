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

c5f=load("c5f_for_c5g",HERE/"analyze_lare_bc2_c5f_spatiotemporal.py")
c5b=c5f.c5b
fields=c5f.fields

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
        out[h]={"q":[sum(bex[i*factor:(i+1)*factor])/BASE_DT for i in range(BASE_STEPS)]}
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

    refs={
      "R512_T1":parse_aggregated(a.r512_t1,1),
      "R1024_T1":parse_aggregated(a.r1024_t1,1),
      "R512_T2":parse_aggregated(a.r512_t2,2),
      "R1024_T2":parse_aggregated(a.r1024_t2,2),
      "R512_T4":parse_aggregated(a.r512_t4,4),
      "R1024_T4":parse_aggregated(a.r1024_t4,4),
    }

    spatial={
      "T1":c5b.qdistance(refs["R512_T1"],refs["R1024_T1"]),
      "T2":c5b.qdistance(refs["R512_T2"],refs["R1024_T2"]),
      "T4":c5b.qdistance(refs["R512_T4"],refs["R1024_T4"]),
    }
    temporal={
      "R512_T1_T2":c5b.qdistance(refs["R512_T1"],refs["R512_T2"]),
      "R512_T2_T4":c5b.qdistance(refs["R512_T2"],refs["R512_T4"]),
      "R1024_T1_T2":c5b.qdistance(refs["R1024_T1"],refs["R1024_T2"]),
      "R1024_T2_T4":c5b.qdistance(refs["R1024_T2"],refs["R1024_T4"]),
    }

    baseline_identity={
      "spatial_T1":abs(spatial["T1"]["rmse_cm_per_day"]-float(c5fr["spatial"]["R512_T1_vs_R1024_T1"]["rmse_cm_per_day"]))<=1e-15,
      "spatial_T2":abs(spatial["T2"]["rmse_cm_per_day"]-float(c5fr["spatial"]["R512_T2_vs_R1024_T2"]["rmse_cm_per_day"]))<=1e-15,
      "R512_T1_T2":abs(temporal["R512_T1_T2"]["rmse_cm_per_day"]-float(c5fr["temporal"]["R512_T1_vs_T2"]["rmse_cm_per_day"]))<=1e-15,
      "R1024_T1_T2":abs(temporal["R1024_T1_T2"]["rmse_cm_per_day"]-float(c5fr["temporal"]["R1024_T1_vs_T2"]["rmse_cm_per_day"]))<=1e-15,
      "R1024_T2_T4":abs(temporal["R1024_T2_T4"]["rmse_cm_per_day"]-float(c5fr["temporal"]["R1024_T2_T4"]["rmse_cm_per_day"]))<=1e-15,
    }
    if not all(baseline_identity.values()):
        raise RuntimeError("C5G baseline does not reproduce C5F anchors")

    t1=spatial["T1"]["rmse_cm_per_day"]
    t2=spatial["T2"]["rmse_cm_per_day"]
    t4=spatial["T4"]["rmse_cm_per_day"]
    r512_t12=temporal["R512_T1_T2"]["rmse_cm_per_day"]
    r512_t24=temporal["R512_T2_T4"]["rmse_cm_per_day"]
    r1024_t12=temporal["R1024_T1_T2"]["rmse_cm_per_day"]
    r1024_t24=temporal["R1024_T2_T4"]["rmse_cm_per_day"]

    matrix={
      "spatial_T2_over_T1":t2/t1,
      "spatial_T4_over_T2":t4/t2,
      "spatial_T4_change_from_T2_fraction":abs(t4-t2)/t2,
      "R512_temporal_order":order(r512_t12,r512_t24),
      "R1024_temporal_order":order(r1024_t12,r1024_t24),
      "R512_T2_T4_over_spatial_T4":r512_t24/t4,
      "R1024_T2_T4_over_spatial_T4":r1024_t24/t4,
      "both_finest_temporal_shifts_subdominant_to_spatial_T4":(r512_t24<t4 and r1024_t24<t4),
      "both_temporal_routes_progressing":(r512_t24<r512_t12 and r1024_t24<r1024_t12),
    }

    if matrix["both_temporal_routes_progressing"] and matrix["both_finest_temporal_shifts_subdominant_to_spatial_T4"]:
        status="MATCHED_T4_MATRIX_TEMPORAL_PROGRESS_AND_SPATIAL_DOMINANCE_CONFIRMED"
    elif matrix["both_temporal_routes_progressing"]:
        status="MATCHED_T4_MATRIX_TEMPORAL_PROGRESS_BUT_SPATIAL_DOMINANCE_NOT_CONFIRMED"
    else:
        status="MATCHED_T4_MATRIX_TEMPORAL_PROGRESS_NOT_CONSISTENT"

    out={
      "schema":"swap5.lare.bc2.c5g.result.v1",
      "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C5G",
      "role":"MATCHED_R512_R1024_X_T1_T2_T4_MATRIX_COMPLETION",
      "status":status,
      "formal_C5A_decision_retained":"C5A_DYNAMIC_HEAD_REDUCED_FRONTIER_NOT_PRESERVED",
      "baseline_identity_to_C5F":baseline_identity,
      "spatial":spatial,
      "temporal":temporal,
      "matrix":matrix,
      "signed_diagnostics":{
        "spatial_T4":c5b.signed_diagnostics(refs["R512_T4"],refs["R1024_T4"]),
        "temporal_R512_T2_T4":c5b.signed_diagnostics(refs["R512_T2"],refs["R512_T4"]),
        "temporal_R1024_T2_T4":c5b.signed_diagnostics(refs["R1024_T2"],refs["R1024_T4"]),
      },
      "interpretation_boundaries":[
        "C5G adds only the missing R512 T4 cell.",
        "All outputs are compared on the original 0.0008-day aggregation windows.",
        "Spatial dominance is relative to the tested T4 temporal shifts, not an application tolerance.",
        "No continuum truth, LARE closure admission or application acceptance follows automatically."
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
    print(json.dumps({"status":status,"spatial_RMSE":{k:v["rmse_cm_per_day"] for k,v in spatial.items()},"temporal_RMSE":{k:v["rmse_cm_per_day"] for k,v in temporal.items()},"matrix":matrix},sort_keys=True))

if __name__=="__main__":
    main()
