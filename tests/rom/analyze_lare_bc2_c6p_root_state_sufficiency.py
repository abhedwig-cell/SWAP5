#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib

import numpy as np

MATERIALS={
    "B01":{"theta_r":0.02,"theta_s":0.427494,"alpha":0.021659,"n":1.734737},
    "B14":{"theta_r":0.01,"theta_s":0.416774,"alpha":0.00541,"n":1.301528},
}
PARTITIONS={
    "R4":[0,130,140,150,160],
    "R8":[0,90,100,110,120,130,140,150,160],
    "U4":[0,40,80,120,160],
    "U8":[0,20,40,60,80,100,120,140,160],
    "P4_TOP_LOWER":[0,10,140,150,160],
    "R16":list(range(0,161,10)),
}
PROFILES=("UNIFORM_030","UNIFORM_045","UNIFORM_060","TOP_DRY_BOTTOM_WET","TOP_WET_BOTTOM_DRY")
ROOTS=("UNIFORM","SHALLOW","DEEP")
DEMANDS={"LOW":0.0,"MID":0.5,"HIGH":1.0}
PATTERNS=("P0","P1_PLUS","P1_MINUS","P2_PLUS","P2_MINUS")
AMPLITUDES=(0.12,0.20)
DZ=0.5
DEPTH=160.0
ROOT_DEPTH=80.0
EDGES=np.arange(0.0,DEPTH+DZ*0.5,DZ)
CENTERS=0.5*(EDGES[:-1]+EDGES[1:])


def psi_from_se(se:np.ndarray|float,p:dict)->np.ndarray:
    se=np.asarray(se,dtype=float)
    m=1.0-1.0/p["n"]
    return np.power(np.power(se,-1.0/m)-1.0,1.0/p["n"])/p["alpha"]


def pressure_from_se(se,p):
    return -psi_from_se(se,p)


def feddes_alpha(h,h3,h4):
    h=np.asarray(h,dtype=float)
    a=np.ones_like(h)
    a[h<h4]=0.0
    mask=(h>=h4)&(h<=h3)
    a[mask]=(h4-h[mask])/(h4-h3)
    return a


def cumulative_root(kind,z):
    u=np.clip(np.asarray(z,dtype=float)/ROOT_DEPTH,0.0,1.0)
    if kind=="UNIFORM":
        return u
    if kind=="SHALLOW":
        return 2.0*u-u*u
    if kind=="DEEP":
        return u*u
    raise ValueError(kind)


def root_weights(kind):
    f=cumulative_root(kind,EDGES)
    w=np.diff(f)
    return w


def layer_mean_se(profile,zc):
    if profile=="UNIFORM_030": return 0.30
    if profile=="UNIFORM_045": return 0.45
    if profile=="UNIFORM_060": return 0.60
    if profile=="TOP_DRY_BOTTOM_WET": return 0.25+0.40*(zc/DEPTH)
    if profile=="TOP_WET_BOTTOM_DRY": return 0.65-0.40*(zc/DEPTH)
    raise ValueError(profile)


def orthogonal_shapes(x):
    # Discrete equal-volume inner product. Remove the constant component from
    # P1 and remove both constant and first-moment components from P2.
    one=np.ones_like(x)
    p1=x.copy()
    p1-=np.mean(p1)
    raw=0.5*(3.0*x*x-1.0)
    A=np.column_stack([one,x])
    coeff=np.linalg.lstsq(A,raw,rcond=None)[0]
    p2=raw-A@coeff
    return p1,p2


def build_profile(partition,coarse_profile,amp,pattern):
    se=np.empty_like(CENTERS)
    for top,bottom in zip(partition[:-1],partition[1:]):
        mask=(CENTERS>=top)&(CENTERS<bottom)
        z=CENTERS[mask]
        zc=0.5*(top+bottom)
        half=0.5*(bottom-top)
        x=(z-zc)/half
        p1,p2=orthogonal_shapes(x)
        mean=layer_mean_se(coarse_profile,zc)
        if pattern=="P0": shape=np.zeros_like(x)
        elif pattern=="P1_PLUS": shape=p1
        elif pattern=="P1_MINUS": shape=-p1
        elif pattern=="P2_PLUS": shape=p2
        elif pattern=="P2_MINUS": shape=-p2
        else: raise ValueError(pattern)
        se[mask]=mean+amp*shape
    return se


def layer_state(se,p,partition):
    theta=p["theta_r"]+(p["theta_s"]-p["theta_r"])*se
    S=[]; M=[]
    for top,bottom in zip(partition[:-1],partition[1:]):
        mask=(CENTERS>=top)&(CENTERS<bottom)
        zc=0.5*(top+bottom)
        S.append(float(np.sum(theta[mask])*DZ))
        M.append(float(np.sum((CENTERS[mask]-zc)*theta[mask])*DZ))
    return np.asarray(S),np.asarray(M)


def uptake_fraction(se,p,root_kind,demand_lambda):
    h4=float(pressure_from_se(0.08,p))
    h3l=float(pressure_from_se(0.35,p))
    h3h=float(pressure_from_se(0.55,p))
    h3=h3l+demand_lambda*(h3h-h3l)
    h=pressure_from_se(se,p)
    w=root_weights(root_kind)
    return float(np.sum(w*feddes_alpha(h,h3,h4))),h3,h4


def mean_storage_approx(partition,coarse_profile,p,root_kind,demand_lambda):
    h4=float(pressure_from_se(0.08,p))
    h3l=float(pressure_from_se(0.35,p))
    h3h=float(pressure_from_se(0.55,p))
    h3=h3l+demand_lambda*(h3h-h3l)
    w=root_weights(root_kind)
    total=0.0
    for top,bottom in zip(partition[:-1],partition[1:]):
        mask=(CENTERS>=top)&(CENTERS<bottom)
        df=float(np.sum(w[mask]))
        if df==0.0: continue
        zc=0.5*(top+bottom)
        mean=layer_mean_se(coarse_profile,zc)
        h=float(pressure_from_se(mean,p))
        total+=df*float(feddes_alpha(np.array([h]),h3,h4)[0])
    return total


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c6o",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    pre=json.loads(a.prereg.read_text())
    c6o=json.loads(a.c6o.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_C6P_NUMERICAL_EVALUATION"
    assert c6o["decision"]=="AUTHORIZE_RESPONSE_FREE_ROOT_UPTAKE_STATE_SUFFICIENCY_DISCRIMINATOR_BEFORE_ANY_ET_DROUGHT_TRAJECTORY"

    hc=pre["hard_checks"]
    s_tol=float(hc["matched_storage_max_abs_cm"])
    m_tol=float(hc["matched_P2_moment_max_abs_cm2"])
    zero=float(hc["numerical_zero_tolerance"])
    se_lo,se_hi=map(float,hc["Se_interval"])

    rows=[]
    max_storage=0.0
    max_p2_moment=0.0
    max_root_sum=0.0
    min_se=math.inf; max_se=-math.inf
    all_uptake_bounded=True

    for material,p in MATERIALS.items():
      for part_id,partition in PARTITIONS.items():
        for coarse_profile in PROFILES:
          for amp in AMPLITUDES:
            profiles={pat:build_profile(partition,coarse_profile,amp,pat) for pat in PATTERNS}
            min_se=min(min_se,min(float(np.min(x)) for x in profiles.values()))
            max_se=max(max_se,max(float(np.max(x)) for x in profiles.values()))
            if any(np.min(x)<se_lo-1e-14 or np.max(x)>se_hi+1e-14 for x in profiles.values()):
                raise RuntimeError(f"Se bound failure {material} {part_id} {coarse_profile} {amp}")
            states={pat:layer_state(se,p,partition) for pat,se in profiles.items()}
            S0,M0=states["P0"]
            for pat,(S,M) in states.items():
                max_storage=max(max_storage,float(np.max(np.abs(S-S0))))
            max_p2_moment=max(max_p2_moment,float(np.max(np.abs(states["P2_PLUS"][1]-states["P2_MINUS"][1]))))
            max_p2_moment=max(max_p2_moment,float(np.max(np.abs(states["P2_PLUS"][1]-M0))))
            for root in ROOTS:
              w=root_weights(root)
              max_root_sum=max(max_root_sum,abs(float(np.sum(w))-1.0))
              for demand,lam in DEMANDS.items():
                vals={}
                h3=h4=None
                for pat,se in profiles.items():
                    vals[pat],h3,h4=uptake_fraction(se,p,root,lam)
                    all_uptake_bounded &= (-1e-14<=vals[pat]<=1.0+1e-14)
                approx=mean_storage_approx(partition,coarse_profile,p,root,lam)
                rows.append({
                  "material":material,"partition":part_id,"coarse_profile":coarse_profile,
                  "amplitude_Se":amp,"root_distribution":root,"demand_class":demand,
                  "h3_cm":h3,"h4_cm":h4,
                  "uptake_fraction":vals,
                  "mean_storage_feedback_fraction":approx,
                  "storage_only_ambiguity_fraction":max(vals.values())-min(vals.values()),
                  "S_plus_M_P2_ambiguity_fraction":abs(vals["P2_PLUS"]-vals["P2_MINUS"]),
                  "max_mean_storage_feedback_abs_error_fraction":max(abs(v-approx) for v in vals.values())
                })

    hard={
      "Se_bounds":min_se>=se_lo-1e-14 and max_se<=se_hi+1e-14,
      "root_weight_sum":max_root_sum<=float(hc["root_weight_sum_tolerance"]),
      "matched_storage":max_storage<=s_tol,
      "matched_P2_moment":max_p2_moment<=m_tol,
      "uptake_fraction_bounds":bool(all_uptake_bounded)
    }
    if not all(hard.values()):
        raise RuntimeError(f"hard check failure: {hard}")

    h_storage=any(r["storage_only_ambiguity_fraction"]>zero for r in rows)
    h_sm=any(r["S_plus_M_P2_ambiguity_fraction"]>zero for r in rows)
    h_mean=any(r["max_mean_storage_feedback_abs_error_fraction"]>zero for r in rows)

    summaries={}
    for material in MATERIALS:
      summaries[material]={}
      for part in PARTITIONS:
        rr=[r for r in rows if r["material"]==material and r["partition"]==part]
        summaries[material][part]={
          "case_count":len(rr),
          "storage_only_ambiguity_fraction":{
            "median":float(np.median([x["storage_only_ambiguity_fraction"] for x in rr])),
            "max":max(x["storage_only_ambiguity_fraction"] for x in rr)
          },
          "S_plus_M_P2_ambiguity_fraction":{
            "median":float(np.median([x["S_plus_M_P2_ambiguity_fraction"] for x in rr])),
            "max":max(x["S_plus_M_P2_ambiguity_fraction"] for x in rr)
          },
          "mean_storage_feedback_abs_error_fraction":{
            "median_max_over_patterns":float(np.median([x["max_mean_storage_feedback_abs_error_fraction"] for x in rr])),
            "max":max(x["max_mean_storage_feedback_abs_error_fraction"] for x in rr)
          }
        }

    if h_storage and h_sm and h_mean:
        decision="C6P_EXISTING_STORAGE_AND_GEOMETRIC_FIRST_MOMENT_NOT_EXACTLY_SUFFICIENT_FOR_GENERAL_FEDDES_FEEDBACK"
    elif h_storage and not h_sm:
        decision="C6P_FIRST_MOMENT_REMOVES_FROZEN_STRUCTURAL_AMBIGUITY"
    else:
        decision="C6P_NO_STRUCTURAL_AMBIGUITY_DEMONSTRATED_ON_FROZEN_DOMAIN"

    top_storage=sorted(rows,key=lambda r:r["storage_only_ambiguity_fraction"],reverse=True)[:20]
    top_sm=sorted(rows,key=lambda r:r["S_plus_M_P2_ambiguity_fraction"],reverse=True)[:20]
    top_mean=sorted(rows,key=lambda r:r["max_mean_storage_feedback_abs_error_fraction"],reverse=True)[:20]

    out={
      "schema":"swap5.lare.bc2.c6p.result.v1",
      "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C6P",
      "status":decision,"decision":decision,
      "case_count":len(rows),
      "hard_checks":{
        "pass":all(hard.values()),"components":hard,
        "minimum_Se":min_se,"maximum_Se":max_se,
        "max_abs_matched_storage_difference_cm":max_storage,
        "max_abs_matched_P2_moment_difference_cm2":max_p2_moment,
        "max_abs_root_weight_sum_error":max_root_sum
      },
      "hypotheses":{
        "H_STORAGE_NOT_EXACTLY_SUFFICIENT":h_storage,
        "H_S_PLUS_M_NOT_EXACTLY_SUFFICIENT":h_sm,
        "H_MEAN_STORAGE_FEEDBACK_NOT_EXACT":h_mean
      },
      "partition_summaries":summaries,
      "top_storage_ambiguity_cases":top_storage,
      "top_S_plus_M_ambiguity_cases":top_sm,
      "top_mean_storage_feedback_error_cases":top_mean,
      "interpretation_boundary":[
        "The Se-anchored Feddes thresholds are synthetic structural probes, not crop/application calibration.",
        "Ambiguity is a state-identifiability result, not an application error tolerance.",
        "P2_PLUS and P2_MINUS have the same retained storage and centered geometric first water-content moment by construction.",
        "No new state or uptake closure is selected from this result."
      ],
      "scientific_firewall":{
        "hydrological_response_generated":False,"dynamic_root_feedback_implemented":False,
        "new_representation_selected":False,"new_partition_selected":False,
        "application_tolerance_selected":False,"application_acceptance_adjudicated":False,
        "performance_comparison_authorized":False,"production_rom_authorized":False
      },
      "model_changed":False
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "decision":decision,"case_count":len(rows),"hard":out["hard_checks"],
      "hypotheses":out["hypotheses"],
      "summary":summaries
    },sort_keys=True))

if __name__=="__main__":
    main()
