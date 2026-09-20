#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, pathlib
import numpy as np

HISTS=("Z01","Z02","Z03","Z04")
BASE_STEPS=1024
BASE_DT=0.0008
FACTOR=16

def fields(payload:str):
    out={}
    for part in payload.split("|"):
        if "=" in part:
            k,v=part.split("=",1); out[k]=v
    return out

def phase_blocks(h):
    if h in ("Z01","Z02"):
        return ((1,256,"PHASE1"),(257,576,"PHASE2"),(577,1024,"HOLD"))
    return ((1,320,"PHASE1"),(321,576,"PHASE2"),(577,1024,"HOLD"))

def parse_aggregated(path:pathlib.Path):
    states={}
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("LAREGW1_STATE|"):
            r=fields(line.split("|",1)[1])
            h=r.get("HISTORY")
            if h in HISTS:
                states[(h,int(r["STEP"]))]=r
    expected=BASE_STEPS*FACTOR
    out={}
    for h in HISTS:
        bex=[]
        for step in range(1,expected+1):
            key=(h,step)
            if key not in states:
                raise RuntimeError(f"incomplete C5J route {path} at {key}")
            bex.append(float(states[key]["BOTTOM_OUTWARD_EXCHANGE"]))
        out[h]=np.asarray([sum(bex[i*FACTOR:(i+1)*FACTOR])/BASE_DT for i in range(BASE_STEPS)],dtype=float)
    return out

def gap(r512,r1024):
    return {h:r512[h]-r1024[h] for h in HISTS}

def combine(a,b,op):
    return {h:op(a[h],b[h]) for h in HISTS}

def interaction(base,g,k,gk):
    return {h:gk[h]-g[h]-k[h]+base[h] for h in HISTS}

def diag(v):
    pooled=np.concatenate([v[h] for h in HISTS])
    by_history={}
    by_phase={}
    for h in HISTS:
        x=v[h]
        by_history[h]={
          "signed_mean_cm_per_day":float(np.mean(x)),
          "rmse_cm_per_day":float(np.sqrt(np.mean(x*x))),
          "max_abs_cm_per_day":float(np.max(np.abs(x)))
        }
        phases={}
        for lo,hi,label in phase_blocks(h):
            y=x[lo-1:hi]
            phases[label]={
              "step_start":lo,"step_end":hi,
              "signed_mean_cm_per_day":float(np.mean(y)),
              "rmse_cm_per_day":float(np.sqrt(np.mean(y*y))),
              "max_abs_cm_per_day":float(np.max(np.abs(y)))
            }
        by_phase[h]=phases
    return {
      "signed_mean_cm_per_day":float(np.mean(pooled)),
      "rmse_cm_per_day":float(np.sqrt(np.mean(pooled*pooled))),
      "max_abs_cm_per_day":float(np.max(np.abs(pooled))),
      "by_history":by_history,
      "by_phase":by_phase
    }

def dot(a,b):
    return float(sum(np.dot(a[h],b[h]) for h in HISTS))

def projection(effect,base):
    den=dot(base,base)
    return None if den==0.0 else dot(effect,base)/den

def main():
    ap=argparse.ArgumentParser()
    for cell in ("base","geometry","conductivity","combined"):
        for g in ("512","1024"):
            ap.add_argument(f"--{cell}-r{g}",required=True,type=pathlib.Path)
    ap.add_argument("--c5i-result",required=True,type=pathlib.Path)
    ap.add_argument("--c5i-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    p=json.loads(a.prereg.read_text())
    c5i=json.loads(a.c5i_result.read_text())
    close=json.loads(a.c5i_closeout.read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_REFERENCE_BOUNDARY_COUNTERFACTUAL_RESPONSE"
    assert close["status"]=="CLOSED_T16_TEMPORAL_PROGRESS_SPATIAL_GAP_CONTINUES_INCREASING_REFERENCE_BOUNDARY_DISCRETIZATION_AUDIT_REQUIRED"
    assert close["authority"]["result_sha256"]=="865339e6bd85eb86d5b905de1af9a7e87321878d3ae47e6f2e7ee9b70a08b302"
    assert p["implementation_binding"]["state"]=="BOUND_BEFORE_EXECUTION"

    routes={}
    for cell in ("base","geometry","conductivity","combined"):
        routes[cell]={
          "R512":parse_aggregated(getattr(a,f"{cell}_r512")),
          "R1024":parse_aggregated(getattr(a,f"{cell}_r1024"))
        }

    gaps={cell:gap(v["R512"],v["R1024"]) for cell,v in routes.items()}
    gd={cell:diag(v) for cell,v in gaps.items()}
    base_rmse=gd["base"]["rmse_cm_per_day"]
    frozen=float(c5i["spatial"]["T16"]["rmse_cm_per_day"])
    baseline_identity=abs(base_rmse-frozen)<=1e-15
    if not baseline_identity:
        raise RuntimeError(f"C5J baseline mismatch {base_rmse} vs {frozen}")

    e_g=combine(gaps["geometry"],gaps["base"],lambda x,y:x-y)
    e_k=combine(gaps["conductivity"],gaps["base"],lambda x,y:x-y)
    e_gk=combine(gaps["combined"],gaps["base"],lambda x,y:x-y)
    inter=interaction(gaps["base"],gaps["geometry"],gaps["conductivity"],gaps["combined"])
    contrasts={
      "geometry_main":diag(e_g),
      "conductivity_main":diag(e_k),
      "combined_shift":diag(e_gk),
      "factorial_interaction":diag(inter)
    }

    for key,v in contrasts.items():
        v["rmse_over_baseline_gap"]=v["rmse_cm_per_day"]/base_rmse if base_rmse else None
        vec={"geometry_main":e_g,"conductivity_main":e_k,"combined_shift":e_gk,"factorial_interaction":inter}[key]
        v["projection_on_baseline_gap"]=projection(vec,gaps["base"])

    ratios={cell:gd[cell]["rmse_cm_per_day"]/base_rmse for cell in ("geometry","conductivity","combined")}
    reduced=[cell for cell in ("geometry","conductivity","combined") if gd[cell]["rmse_cm_per_day"] < base_rmse]
    gnorm=contrasts["geometry_main"]["rmse_cm_per_day"]
    knorm=contrasts["conductivity_main"]["rmse_cm_per_day"]
    scale=max(gnorm,knorm,1.0)
    if abs(gnorm-knorm)<=1e-12*scale:
        ordering="CONTRASTS_COMPARABLE"
    elif gnorm>knorm:
        ordering="GEOMETRY_CONTRAST_LARGER_THAN_CONDUCTIVITY_CONTRAST"
    else:
        ordering="CONDUCTIVITY_CONTRAST_LARGER_THAN_GEOMETRY_CONTRAST"

    hold_max={}
    for cell in ("geometry","conductivity","combined"):
        vals=[]
        for h in HISTS:
            vals.append(gd[cell]["by_phase"][h]["HOLD"]["max_abs_cm_per_day"])
        hold_max[cell]=max(vals)

    out={
      "schema":"swap5.lare.bc2.c5j.result.v1",
      "workstream":"F-ROM-LARE",
      "work_unit":"LARE-BC2-C5J",
      "role":"PROSPECTIVE_ZERO_FIT_FACTORIAL_REFERENCE_BOUNDARY_DIAGNOSTIC",
      "status":"C5J_FACTORIAL_REFERENCE_BOUNDARY_SENSITIVITY_CHARACTERIZED",
      "formal_C5A_decision_retained":"C5A_DYNAMIC_HEAD_REDUCED_FRONTIER_NOT_PRESERVED",
      "baseline_identity_to_C5I_T16":baseline_identity,
      "factorial_cells":{
        "G0K0_CURRENT_REFERENCE":gd["base"],
        "G1K0_DISTANCE_DOUBLE_CONTROL":gd["geometry"],
        "G0K1_CENTER_BOUNDARY_ARITHMETIC_K":gd["conductivity"],
        "G1K1_COMBINED":gd["combined"]
      },
      "contrasts":contrasts,
      "spatial_gap_rmse_ratio_to_current":ratios,
      "counterfactuals_reducing_spatial_gap":reduced,
      "descriptive_ordering":ordering,
      "factorial_interaction_over_larger_main_contrast":(
        contrasts["factorial_interaction"]["rmse_cm_per_day"]/max(gnorm,knorm)
        if max(gnorm,knorm)>0.0 else None
      ),
      "hold_max_abs_spatial_gap_cm_per_day":hold_max,
      "interpretation_boundaries":[
        "C5J diagnoses sensitivity of the high-resolution spatial gap; it does not establish which counterfactual is physically correct.",
        "G1 is a semantic distance control, not a proposed production discretization.",
        "K1 is zero-fit and extends frozen swkmean=1 arithmetic conductivity averaging to the prescribed boundary.",
        "A reduction in R512-R1024 gap is not an acceptance criterion and does not by itself establish continuum accuracy.",
        "No T32, R2048, LARE rerun, closure fit or production Reference modification is part of C5J."
      ],
      "scientific_firewall":{
        "production_reference_changed":False,
        "new_reference_physics_admitted":False,
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
      "status":out["status"],
      "baseline_spatial_rmse":base_rmse,
      "cell_spatial_rmse":{k:v["rmse_cm_per_day"] for k,v in gd.items()},
      "contrast_rmse":{k:v["rmse_cm_per_day"] for k,v in contrasts.items()},
      "contrast_projection":{k:v["projection_on_baseline_gap"] for k,v in contrasts.items()},
      "ratios":ratios,
      "reduced":reduced,
      "ordering":ordering,
      "interaction_over_larger_main":out["factorial_interaction_over_larger_main_contrast"],
      "hold_max":hold_max
    },sort_keys=True))

if __name__=="__main__":
    main()
