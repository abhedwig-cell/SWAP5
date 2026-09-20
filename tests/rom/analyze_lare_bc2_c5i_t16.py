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

c5b=load("c5b_for_c5i",HERE/"analyze_lare_bc2_c5b_signed_flux_mechanism.py")
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
                raise RuntimeError(f"incomplete C5I Reference {key}, factor={factor}")
            bex.append(float(states[key]["BOTTOM_OUTWARD_EXCHANGE"]))
        out[h]={"q":[sum(bex[i*factor:(i+1)*factor])/BASE_DT for i in range(BASE_STEPS)]}
    return out

def order(a,b):
    if a<=0.0 or b<=0.0:return None
    return math.log(a/b,2.0)

def main():
    ap=argparse.ArgumentParser()
    for g in ("512","1024"):
        for f in (4,8,16):
            ap.add_argument(f"--r{g}-t{f}",required=True,type=pathlib.Path)
    ap.add_argument("--c5h-result",required=True,type=pathlib.Path)
    ap.add_argument("--c5h-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    p=json.loads(a.prereg.read_text())
    c5hr=json.loads(a.c5h_result.read_text())
    c5hc=json.loads(a.c5h_closeout.read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_C5I_T16_RESPONSE"
    assert c5hc["status"]=="CLOSED_T8_TEMPORAL_PROGRESS_SPATIAL_GAP_STILL_INCREASING_T16_REQUIRED"
    assert c5hc["authority"]["result_sha256"]=="2af0756ec31ec62bd6348404d656a969d5b5005c262c72ed0318cf950723c75e"

    r512={f:parse_aggregated(getattr(a,f"r512_t{f}"),f) for f in (4,8,16)}
    r1024={f:parse_aggregated(getattr(a,f"r1024_t{f}"),f) for f in (4,8,16)}

    spatial={f"T{f}":c5b.qdistance(r512[f],r1024[f]) for f in (4,8,16)}
    t512={"T4_T8":c5b.qdistance(r512[4],r512[8]),"T8_T16":c5b.qdistance(r512[8],r512[16])}
    t1024={"T4_T8":c5b.qdistance(r1024[4],r1024[8]),"T8_T16":c5b.qdistance(r1024[8],r1024[16])}

    baseline_identity={
      "spatial_T4":abs(spatial["T4"]["rmse_cm_per_day"]-float(c5hr["spatial"]["T4"]["rmse_cm_per_day"]))<=1e-15,
      "spatial_T8":abs(spatial["T8"]["rmse_cm_per_day"]-float(c5hr["spatial"]["T8"]["rmse_cm_per_day"]))<=1e-15,
      "R512_T4_T8":abs(t512["T4_T8"]["rmse_cm_per_day"]-float(c5hr["temporal"]["R512"]["T4_T8"]["rmse_cm_per_day"]))<=1e-15,
      "R1024_T4_T8":abs(t1024["T4_T8"]["rmse_cm_per_day"]-float(c5hr["temporal"]["R1024"]["T4_T8"]["rmse_cm_per_day"]))<=1e-15,
    }
    if not all(baseline_identity.values()):
        raise RuntimeError("C5I baseline does not reproduce C5H")

    sp8=spatial["T8"]["rmse_cm_per_day"]; sp16=spatial["T16"]["rmse_cm_per_day"]
    a512=t512["T4_T8"]["rmse_cm_per_day"]; b512=t512["T8_T16"]["rmse_cm_per_day"]
    a1024=t1024["T4_T8"]["rmse_cm_per_day"]; b1024=t1024["T8_T16"]["rmse_cm_per_day"]

    if sp16 < sp8-1e-12: direction="DECREASES"
    elif sp16 > sp8+1e-12: direction="INCREASES"
    else: direction="UNCHANGED"

    prog512=b512<a512; prog1024=b1024<a1024
    sub512=b512<sp16; sub1024=b1024<sp16
    rel_change=abs(sp16-sp8)/sp8 if sp8 else None

    if direction=="UNCHANGED" and prog512 and prog1024:
        status="T16_TEMPORAL_PROGRESS_SPATIAL_GAP_NUMERICALLY_STABLE"
    elif direction=="DECREASES" and prog512 and prog1024:
        status="T16_TEMPORAL_PROGRESS_SPATIAL_GAP_REVERSES"
    elif direction=="INCREASES" and prog512 and prog1024:
        status="T16_TEMPORAL_PROGRESS_SPATIAL_GAP_CONTINUES_INCREASING"
    else:
        status="T16_SPACE_TIME_PATTERN_MIXED_OR_TEMPORAL_PROGRESS_BLOCKED"

    out={
      "schema":"swap5.lare.bc2.c5i.result.v1",
      "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C5I",
      "role":"FINAL_MATCHED_TEMPORAL_EXTENSION_BEFORE_SPATIAL_EXTENSION",
      "status":status,
      "formal_C5A_decision_retained":"C5A_DYNAMIC_HEAD_REDUCED_FRONTIER_NOT_PRESERVED",
      "baseline_identity_to_C5H":baseline_identity,
      "common_output_window_day":BASE_DT,
      "spatial":spatial,
      "temporal":{
        "R512":t512,"R1024":t1024,
        "order_R512_T4_T8_T16":order(a512,b512),
        "order_R1024_T4_T8_T16":order(a1024,b1024)
      },
      "interaction":{
        "spatial_T16_over_T8":sp16/sp8,
        "spatial_T16_relative_change_abs":rel_change,
        "spatial_T16_direction":direction,
        "R512_T8_T16_over_spatial_T16":b512/sp16 if sp16 else None,
        "R1024_T8_T16_over_spatial_T16":b1024/sp16 if sp16 else None,
        "temporal_progress_R512":prog512,
        "temporal_progress_R1024":prog1024,
        "temporal_subdominant_R512":sub512,
        "temporal_subdominant_R1024":sub1024,
        "R1024_over_R512_T8_T16_temporal_shift":b1024/b512 if b512 else None
      },
      "signed_diagnostics":{
        "spatial_T16":c5b.signed_diagnostics(r512[16],r1024[16]),
        "temporal_R512_T8_T16":c5b.signed_diagnostics(r512[8],r512[16]),
        "temporal_R1024_T8_T16":c5b.signed_diagnostics(r1024[8],r1024[16])
      },
      "interpretation_boundaries":[
        "C5I is Reference-only and refines only the main transaction interval from T8 to T16 at R512 and R1024.",
        "All exchanges are aggregated to the original 0.0008-day physical windows.",
        "No numerical stability percentage is preregistered as an acceptance threshold; relative change is reported continuously.",
        "C5I does not itself establish continuum truth or authorize LARE/closure changes."
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
        "R512_T4_T8":a512,"R512_T8_T16":b512,
        "R1024_T4_T8":a1024,"R1024_T8_T16":b1024
      },
      "orders":{"R512":out["temporal"]["order_R512_T4_T8_T16"],"R1024":out["temporal"]["order_R1024_T4_T8_T16"]},
      "interaction":out["interaction"]
    },sort_keys=True))

if __name__=="__main__":
    main()
