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

c5b=load("c5b_for_c5h",HERE/"analyze_lare_bc2_c5b_signed_flux_mechanism.py")
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
                raise RuntimeError(f"incomplete C5H Reference {key}, factor={factor}")
            bex.append(float(states[key]["BOTTOM_OUTWARD_EXCHANGE"]))
        out[h]={"q":[sum(bex[i*factor:(i+1)*factor])/BASE_DT for i in range(BASE_STEPS)]}
    return out

def order(a,b):
    if a<=0.0 or b<=0.0:return None
    return math.log(a/b,2.0)

def main():
    ap=argparse.ArgumentParser()
    for g in ("512","1024"):
        for f in (1,2,4,8):
            ap.add_argument(f"--r{g}-t{f}",required=True,type=pathlib.Path)
    ap.add_argument("--c5g-result",required=True,type=pathlib.Path)
    ap.add_argument("--c5g-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    p=json.loads(a.prereg.read_text())
    c5gr=json.loads(a.c5g_result.read_text())
    c5gc=json.loads(a.c5g_closeout.read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_C5H_T8_RESPONSE"
    assert c5gc["status"]=="CLOSED_MATCHED_MATRIX_SPATIAL_GAP_INCREASES_WITH_TEMPORAL_REFINEMENT_T8_REQUIRED"
    assert c5gc["authority"]["result_sha256"]=="88f05603f4af17f68f85c95d3f9b7e7e552715082b8323c62e107bc4022b73c3"

    r512={f:parse_aggregated(getattr(a,f"r512_t{f}"),f) for f in (1,2,4,8)}
    r1024={f:parse_aggregated(getattr(a,f"r1024_t{f}"),f) for f in (1,2,4,8)}

    spatial={f"T{f}":c5b.qdistance(r512[f],r1024[f]) for f in (1,2,4,8)}
    t512={f"T{x}_T{y}":c5b.qdistance(r512[x],r512[y]) for x,y in ((1,2),(2,4),(4,8))}
    t1024={f"T{x}_T{y}":c5b.qdistance(r1024[x],r1024[y]) for x,y in ((1,2),(2,4),(4,8))}

    baseline_identity={
      "spatial_T1":abs(spatial["T1"]["rmse_cm_per_day"]-float(c5gr["spatial"]["T1"]["rmse_cm_per_day"]))<=1e-15,
      "spatial_T2":abs(spatial["T2"]["rmse_cm_per_day"]-float(c5gr["spatial"]["T2"]["rmse_cm_per_day"]))<=1e-15,
      "spatial_T4":abs(spatial["T4"]["rmse_cm_per_day"]-float(c5gr["spatial"]["T4"]["rmse_cm_per_day"]))<=1e-15,
      "R512_T2_T4":abs(t512["T2_T4"]["rmse_cm_per_day"]-float(c5gr["temporal"]["R512"]["T2_T4"]["rmse_cm_per_day"]))<=1e-15,
      "R1024_T2_T4":abs(t1024["T2_T4"]["rmse_cm_per_day"]-float(c5gr["temporal"]["R1024"]["T2_T4"]["rmse_cm_per_day"]))<=1e-15,
    }
    if not all(baseline_identity.values()):
        raise RuntimeError("C5H baseline does not reproduce C5G")

    sp4=spatial["T4"]["rmse_cm_per_day"]
    sp8=spatial["T8"]["rmse_cm_per_day"]
    a512=t512["T2_T4"]["rmse_cm_per_day"]; b512=t512["T4_T8"]["rmse_cm_per_day"]
    a1024=t1024["T2_T4"]["rmse_cm_per_day"]; b1024=t1024["T4_T8"]["rmse_cm_per_day"]

    if sp8 < sp4-1e-12:
        direction="DECREASES"
    elif sp8 > sp4+1e-12:
        direction="INCREASES"
    else:
        direction="UNCHANGED"

    temporal_progress_512=b512<a512
    temporal_progress_1024=b1024<a1024
    subdom_512=b512<sp8
    subdom_1024=b1024<sp8

    if direction=="DECREASES" and temporal_progress_512 and temporal_progress_1024 and subdom_512 and subdom_1024:
        status="T8_TEMPORAL_PROGRESS_SPATIAL_GAP_REVERSES_AND_TEMPORAL_SUBDOMINANT"
    elif direction=="INCREASES" and temporal_progress_512 and temporal_progress_1024:
        status="T8_TEMPORAL_PROGRESS_SPATIAL_GAP_CONTINUES_INCREASING"
    elif direction=="UNCHANGED" and temporal_progress_512 and temporal_progress_1024:
        status="T8_TEMPORAL_PROGRESS_SPATIAL_GAP_STABILIZES"
    else:
        status="T8_SPACE_TIME_PATTERN_MIXED_OR_TEMPORAL_PROGRESS_BLOCKED"

    out={
      "schema":"swap5.lare.bc2.c5h.result.v1",
      "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C5H",
      "role":"MATCHED_R512_R1024_T8_REFERENCE_EXTENSION",
      "status":status,
      "formal_C5A_decision_retained":"C5A_DYNAMIC_HEAD_REDUCED_FRONTIER_NOT_PRESERVED",
      "baseline_identity_to_C5G":baseline_identity,
      "common_output_window_day":BASE_DT,
      "spatial":spatial,
      "temporal":{
        "R512":t512,
        "R1024":t1024,
        "order_R512_T1_T2_T4":order(t512["T1_T2"]["rmse_cm_per_day"],t512["T2_T4"]["rmse_cm_per_day"]),
        "order_R512_T2_T4_T8":order(a512,b512),
        "order_R1024_T1_T2_T4":order(t1024["T1_T2"]["rmse_cm_per_day"],t1024["T2_T4"]["rmse_cm_per_day"]),
        "order_R1024_T2_T4_T8":order(a1024,b1024)
      },
      "interaction":{
        "spatial_T8_over_T4":sp8/sp4,
        "spatial_T8_direction":direction,
        "R512_T4_T8_over_spatial_T8":b512/sp8 if sp8 else None,
        "R1024_T4_T8_over_spatial_T8":b1024/sp8 if sp8 else None,
        "R1024_over_R512_T4_T8_temporal_shift":b1024/b512 if b512 else None,
        "temporal_progress_R512":temporal_progress_512,
        "temporal_progress_R1024":temporal_progress_1024,
        "temporal_subdominant_R512":subdom_512,
        "temporal_subdominant_R1024":subdom_1024
      },
      "signed_diagnostics":{
        "spatial_T8":c5b.signed_diagnostics(r512[8],r1024[8]),
        "temporal_R512_T4_T8":c5b.signed_diagnostics(r512[4],r512[8]),
        "temporal_R1024_T4_T8":c5b.signed_diagnostics(r1024[4],r1024[8])
      },
      "interpretation_boundaries":[
        "C5H changes only the main transaction interval from T4 to T8 at both existing spatial resolutions.",
        "All outputs are re-aggregated to the original 0.0008-day physical windows.",
        "Temporal subdominance is a relative error-scale statement, not application acceptance.",
        "C5H does not admit a continuum Reference or authorize LARE/closure changes."
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
      "spatial_RMSE":{k:v["rmse_cm_per_day"] for k,v in spatial.items()},
      "temporal_RMSE":{
        "R512_T2_T4":a512,"R512_T4_T8":b512,
        "R1024_T2_T4":a1024,"R1024_T4_T8":b1024
      },
      "orders":{
        "R512_old":out["temporal"]["order_R512_T1_T2_T4"],
        "R512_new":out["temporal"]["order_R512_T2_T4_T8"],
        "R1024_old":out["temporal"]["order_R1024_T1_T2_T4"],
        "R1024_new":out["temporal"]["order_R1024_T2_T4_T8"]
      },
      "interaction":out["interaction"]
    },sort_keys=True))

if __name__=="__main__":
    main()
