#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib
import re
from collections import defaultdict

import numpy as np

OBS_DT=0.0008
OBSERVATIONS=1024
STRESS_GUARD=2.9103830456733704e-11
MATERIALS=("B01","B14")
HISTORIES=("V01","V02","V03","V04")
MEMBERS=("U4","U8","R8","R16")
PARTITIONS={
    "U4":[0.0,40.0,80.0,120.0,160.0],
    "U8":[0.0,20.0,40.0,60.0,80.0,100.0,120.0,140.0,160.0],
    "R8":[0.0,90.0,100.0,110.0,120.0,130.0,140.0,150.0,160.0],
    "R16":[float(x) for x in range(0,161,10)],
}
TP={"V01":0.6,"V02":0.3,"V03":0.6,"V04":0.3}
ROOT_PROFILE={"V01":"SHALLOW","V02":"SHALLOW","V03":"UNIFORM","V04":"UNIFORM"}
INITIAL_SE={
    "B01":{"V01":0.551,"V02":0.42671759600680326,"V03":0.551,"V04":0.42671759600680326},
    "B14":{"V01":0.551,"V02":0.40713288830832667,"V03":0.551,"V04":0.40713288830832667},
}
MATERIAL={
    "B01":{"tr":0.02,"ts":0.427494,"alpha":0.021659,"n":1.734737},
    "B14":{"tr":0.01,"ts":0.416774,"alpha":0.00541,"n":1.301528},
}
UNCERTAINTY_METRICS={
    "root_zone_0_40_storage_cm":"root_zone_0_40_storage_rmse_cm",
    "upper_zone_0_80_storage_cm":"upper_0_80_storage_rmse_cm",
    "mapped_10cm_theta":"mapped_10cm_theta_rmse",
    "actual_root_uptake_cm_per_day":"interval_actual_root_uptake_rmse_cm_per_day",
    "cumulative_root_uptake_cm":"cumulative_actual_root_uptake_rmse_cm",
}


def fields(line:str)->dict[str,str]:
    out={}
    for item in line.split("|")[1:]:
        if "=" in item:
            k,v=item.split("=",1)
            out[k]=v
    return out


def pressure_head_from_theta(theta:np.ndarray,material:str)->np.ndarray:
    p=MATERIAL[material]
    m=1.0-1.0/p["n"]
    se=(np.asarray(theta,dtype=float)-p["tr"])/(p["ts"]-p["tr"])
    if np.any(se<=0.0) or np.any(se>=1.0):
        raise RuntimeError("reference profile outside inverse-retention domain")
    psi=np.power(np.power(se,-1.0/m)-1.0,1.0/p["n"])/p["alpha"]
    return -psi


def pressure_head_from_se(se:float,material:str)->float:
    p=MATERIAL[material]
    m=1.0-1.0/p["n"]
    return -float((se**(-1.0/m)-1.0)**(1.0/p["n"])/p["alpha"])


def critical_h3(tp:float,material:str)->float:
    h3l=pressure_head_from_se(0.35,material)
    h3h=pressure_head_from_se(0.55,material)
    if tp<0.10:return h3l
    if tp<=0.50:return h3h+((0.50-tp)/0.40)*(h3l-h3h)
    return h3h


def feddes_alpha(head:np.ndarray,tp:float,material:str)->np.ndarray:
    h=np.asarray(head,dtype=float)
    h4=pressure_head_from_se(0.08,material)
    h3=critical_h3(tp,material)
    out=np.ones_like(h)
    out[h<h4]=0.0
    mask=(h>=h4)&(h<=h3)
    out[mask]=(h4-h[mask])/(h4-h3)
    return np.clip(out,0.0,1.0)


def root_cumulative(z:float,profile:str)->float:
    u=min(1.0,max(0.0,z/80.0))
    return 2.0*u-u*u if profile=="SHALLOW" else u


def root_fractions(bounds:list[float],profile:str)->np.ndarray:
    return np.diff([root_cumulative(z,profile) for z in bounds])


def onset_and_duration(frac:np.ndarray)->dict:
    stressed=(1.0-np.asarray(frac,dtype=float))>STRESS_GUARD
    idx=np.flatnonzero(stressed)
    if idx.size==0:
        return {"onset":None,"duration":0,"episodes":0,"persistent_to_end":False}
    starts=int(np.sum(stressed & np.concatenate(([True],~stressed[:-1]))))
    onset=int(idx[0]+1)
    return {
        "onset":onset,
        "duration":int(np.sum(stressed)),
        "episodes":starts,
        "persistent_to_end":bool(np.all(stressed[idx[0]:])),
    }


def parse_reference(path:pathlib.Path,material:str)->dict:
    roots={h:{} for h in HISTORIES}
    profiles={h:{} for h in HISTORIES}
    states={h:defaultdict(list) for h in HISTORIES}
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("LAREDYN0R_ROOT|"):
            r=fields(line); h=r.get("CASE")
            if h in roots:
                roots[h][int(r["OBS_STEP"])]={
                    "rate":float(r["ACTUAL_RATE"]),
                    "fraction":float(r["ACTUAL_FRACTION"]),
                }
        elif line.startswith("LAREDYN0R_PROFILE|"):
            r=fields(line); h=r.get("CASE")
            if h in profiles:
                obs=int(r["OBS_STEP"]); b=int(r["BIN"])
                profiles[h].setdefault(obs,{})[b]=float(r["THETA"])
        elif line.startswith("LAREDYN0R_STATE|"):
            r=fields(line); h=r.get("CASE")
            if h in states:
                step=int(r["STEP"])
                states[h][step].append({
                    "bottom_exchange":float(r["BOTTOM_DOWNWARD_EXCHANGE"]),
                    "bottom_flux":float(r["BOTTOM_DOWNWARD_FLUX"]),
                })

    out={}
    for h in HISTORIES:
        if sorted(roots[h])!=list(range(1,OBSERVATIONS+1)):
            raise RuntimeError(f"{path} {h} incomplete root")
        if sorted(profiles[h])!=list(range(1,OBSERVATIONS+1)):
            raise RuntimeError(f"{path} {h} incomplete profile")
        rate=np.array([roots[h][i]["rate"] for i in range(1,OBSERVATIONS+1)],dtype=float)
        frac=np.array([roots[h][i]["fraction"] for i in range(1,OBSERVATIONS+1)],dtype=float)
        prof=np.array([[profiles[h][i][b] for b in range(1,17)] for i in range(1,OBSERVATIONS+1)],dtype=float)
        cumulative=np.cumsum(rate*OBS_DT)
        root40=np.sum(prof[:,:4],axis=1)*10.0
        upper80=np.sum(prof[:,:8],axis=1)*10.0
        theta0=(MATERIAL[material]["tr"]+
                INITIAL_SE[material][h]*(MATERIAL[material]["ts"]-MATERIAL[material]["tr"]))
        initial=np.full(16,theta0)
        redistribution=np.std(prof-initial[None,:],axis=1)
        lower_anomaly=np.sum((prof[:,8:]-initial[None,8:])*10.0,axis=1)

        # Reconstructed target is fine-step state output. Sum 32 fine transaction
        # exchanges per observation. For non-target ladder routes this function is
        # still valid because their output factors differ, so derive grouping from
        # the root STEP field is unavailable here; target use only for metrics.
        all_steps=sorted(states[h])
        if not all_steps:
            raise RuntimeError(f"{path} {h} no states")
        if len(all_steps)%OBSERVATIONS!=0:
            raise RuntimeError(f"{path} {h} state/observation mismatch")
        factor=len(all_steps)//OBSERVATIONS
        interval_b=[]
        terminal_flux=[]
        for obs in range(OBSERVATIONS):
            ss=all_steps[obs*factor:(obs+1)*factor]
            rows=[row for s in ss for row in states[h][s]]
            if len(rows)!=factor:
                raise RuntimeError("unexpected duplicate state rows")
            interval_b.append(math.fsum(x["bottom_exchange"] for x in rows))
            terminal_flux.append(rows[-1]["bottom_flux"])
        interval_b=np.asarray(interval_b,dtype=float)
        cum_bottom=np.cumsum(interval_b)
        avg_bottom=interval_b/OBS_DT

        out[h]={
            "actual_root_uptake_cm_per_day":rate,
            "actual_transpiration_fraction":frac,
            "cumulative_root_uptake_cm":cumulative,
            "root_zone_0_40_storage_cm":root40,
            "upper_zone_0_80_storage_cm":upper80,
            "lower_zone_80_160_storage_anomaly_cm":lower_anomaly,
            "mapped_10cm_theta":prof,
            "profile_redistribution_index":redistribution,
            "cumulative_bottom_downward_exchange_cm":cum_bottom,
            "interval_bottom_downward_flux_cm_per_day":avg_bottom,
            "terminal_bottom_downward_flux_cm_per_day":np.asarray(terminal_flux),
            "stress":onset_and_duration(frac),
        }
    return out


def parse_timing(path:pathlib.Path)->dict:
    roots={h:{} for h in HISTORIES}
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("LAREDYN0R_ROOT|"):
            r=fields(line); h=r.get("CASE")
            if h in roots:
                roots[h][int(r["OBS_STEP"])]=float(r["ACTUAL_FRACTION"])
    return {h:onset_and_duration(np.array([roots[h][i] for i in range(1,OBSERVATIONS+1)])) for h in HISTORIES}


def candidate_metric(route:dict,name:str)->np.ndarray:
    return np.asarray(route[name],dtype=float)


def rmse(x:np.ndarray)->float:
    x=np.asarray(x,dtype=float)
    return float(np.sqrt(np.mean(x*x)))


def maxabs(x:np.ndarray)->float:
    return float(np.max(np.abs(np.asarray(x,dtype=float))))


def uncertainty_map(result:dict,material:str)->dict[str,float]:
    metrics=result["materials"][material]["metrics"]
    return {k:float(v["U_combined"]) for k,v in metrics.items()}


def feedback_effect_metrics(cand_dyn:dict,cand_ctl:dict,ref_dyn:dict,ref_ctl:dict)->dict:
    result={}
    names=[
        "actual_root_uptake_cm_per_day",
        "cumulative_root_uptake_cm",
        "root_zone_0_40_storage_cm",
        "upper_zone_0_80_storage_cm",
        "lower_zone_80_160_storage_anomaly_cm",
        "mapped_10cm_theta",
        "profile_redistribution_index",
        "cumulative_bottom_downward_exchange_cm",
        "interval_bottom_downward_flux_cm_per_day",
    ]
    for name in names:
        cd=candidate_metric(cand_dyn,name)
        cc=candidate_metric(cand_ctl,name)
        rd=np.asarray(ref_dyn[name],dtype=float)
        rc=np.asarray(ref_ctl[name],dtype=float)
        err=(cd-cc)-(rd-rc)
        result[name]={
            "feedback_effect_rmse":rmse(err),
            "feedback_effect_max_abs":maxabs(err),
            "direct_dynamic_vs_reference_rmse":rmse(cd-rd),
            "full_potential_baseline_rmse":rmse(cc-rc),
            "dynamic_vs_full_potential_rmse":rmse(cd-cc),
        }
    frac_err=(np.asarray(cand_dyn["actual_transpiration_fraction"])-1.0)-(
        np.asarray(ref_dyn["actual_transpiration_fraction"])-1.0
    )
    result["actual_transpiration_fraction"]={
        "feedback_effect_rmse":rmse(frac_err),
        "feedback_effect_max_abs":maxabs(frac_err),
        "direct_dynamic_vs_reference_rmse":rmse(np.asarray(cand_dyn["actual_transpiration_fraction"])-np.asarray(ref_dyn["actual_transpiration_fraction"])),
    }
    return result


def threshold_diagnostics(ref_profile:np.ndarray,material:str,history:str,member:str)->dict:
    bounds=PARTITIONS[member]
    tp=TP[history]
    profile=ROOT_PROFILE[history]
    h10=pressure_head_from_theta(ref_profile,material)
    h3=critical_h3(tp,material); h4=pressure_head_from_se(0.08,material)
    frac10=root_fractions([float(x) for x in range(0,81,10)],profile)
    retained_frac=root_fractions(bounds,profile)
    straddle_h3=0; straddle_h4=0
    mean_vs_10=[]
    onset_rows=[]
    for obs in range(OBSERVATIONS):
        ten_feedback=float(np.sum(frac10*feddes_alpha(h10[obs,:8],tp,material)))
        layer_feedback=0.0
        any_h3=False;any_h4=False
        for i,(lo,hi) in enumerate(zip(bounds,bounds[1:])):
            if lo>=80.0 or retained_frac[i]==0.0:
                continue
            bins_full=list(range(int(lo//10),int(hi//10)))
            bins_root=list(range(int(lo//10),int(min(hi,80.0)//10)))
            theta_bar=float(np.mean(ref_profile[obs,bins_full]))
            hbar=float(pressure_head_from_theta(np.asarray([theta_bar]),material)[0])
            layer_feedback+=float(retained_frac[i])*float(feddes_alpha(np.asarray([hbar]),tp,material)[0])
            vals=h10[obs,bins_root]
            if float(np.min(vals))<=h3<=float(np.max(vals)):
                any_h3=True
            if float(np.min(vals))<=h4<=float(np.max(vals)):
                any_h4=True
        straddle_h3+=int(any_h3);straddle_h4+=int(any_h4)
        mean_vs_10.append(layer_feedback-ten_feedback)
        onset_rows.append({"h3":any_h3,"h4":any_h4})
    return {
        "observations_with_h3_straddling":straddle_h3,
        "observations_with_h4_straddling":straddle_h4,
        "retained_mean_minus_10cm_root_weighted_feedback_rmse":rmse(np.asarray(mean_vs_10)),
        "retained_mean_minus_10cm_root_weighted_feedback_max_abs":maxabs(np.asarray(mean_vs_10)),
        "per_observation_threshold_straddling":onset_rows,
    }


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--s3-prereg",required=True,type=pathlib.Path)
    ap.add_argument("--ra02r-result",required=True,type=pathlib.Path)
    ap.add_argument("--s3c0-result",required=True,type=pathlib.Path)
    ap.add_argument("--ra02r-dir",required=True,type=pathlib.Path)
    ap.add_argument("--s3c0-dir",required=True,type=pathlib.Path)
    ap.add_argument("--candidate-dir",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.s3_prereg.read_text())
    ra_result=json.loads(a.ra02r_result.read_text())
    c0_result=json.loads(a.s3c0_result.read_text())
    if pre["state"]!="PREREGISTERED_BEFORE_ANY_STAGE3_REDUCED_DYNAMIC_FEEDBACK_RESPONSE":
        raise SystemExit("invalid S3 preregistration")
    if c0_result["status"]!="S3C0_FULL_POTENTIAL_REFERENCE_QUALIFIED":
        raise SystemExit("S3C0 not qualified")

    ref_dyn={}
    ref_ctl={}
    for material in MATERIALS:
        ref_dyn[material]=parse_reference(a.ra02r_dir/f"{material}_R2048_T32_o0.txt",material)
        ref_ctl[material]=parse_reference(a.s3c0_dir/f"{material}_R2048_T32_o0.txt",material)

    # Timing uncertainty is derived only from the fixed numerical ladders before
    # candidate adjudication. C0 is full potential and therefore has no onset.
    route_names=("R512_T32","R1024_T32","R2048_T32","R2048_T16","R2048_T8")
    timing={}
    for material in MATERIALS:
        per={h:[] for h in HISTORIES}
        for route in route_names:
            t=parse_timing(a.ra02r_dir/f"{material}_{route}_o0.txt")
            for h in HISTORIES:
                per[h].append(t[h])
        timing[material]={}
        for h,vals in per.items():
            on=[x["onset"] for x in vals if x["onset"] is not None]
            du=[x["duration"] for x in vals]
            timing[material][h]={
                "reference_route_onsets":on,
                "reference_onset_min":min(on),
                "reference_onset_max":max(on),
                "reference_route_durations":du,
                "reference_duration_min":min(du),
                "reference_duration_max":max(du),
            }

    cases={}
    representation_summary={m:{"covered_metric_pass":True,"timing_pass":True,"integrity_pass":True} for m in MEMBERS}
    for material in MATERIALS:
        u_dyn=uncertainty_map(ra_result,material)
        u_ctl=uncertainty_map(c0_result,material)
        for history in HISTORIES:
            cand=json.loads((a.candidate_dir/f"{material}_{history}.json").read_text())
            for member in MEMBERS:
                cd=cand["cases"][member]["DYNAMIC"]
                cc=cand["cases"][member]["FULL_POTENTIAL"]
                metrics=feedback_effect_metrics(cd,cc,ref_dyn[material][history],ref_ctl[material][history])
                covered={}
                for cname,uname in UNCERTAINTY_METRICS.items():
                    value=metrics[cname]["feedback_effect_rmse"]
                    bound=u_dyn[uname]+u_ctl[uname]
                    ratio=(value/bound if bound>0.0 else (0.0 if value==0.0 else math.inf))
                    covered[cname]={
                        "feedback_effect_rmse":value,
                        "reference_feedback_uncertainty_bound":bound,
                        "ratio_to_bound":ratio,
                        "numerically_unresolved":bool(ratio<=1.0),
                    }
                    representation_summary[member]["covered_metric_pass"] &= bool(ratio<=1.0)

                stress=onset_and_duration(np.asarray(cd["actual_transpiration_fraction"]))
                tw=timing[material][history]
                onset_ok=(stress["onset"] is not None and tw["reference_onset_min"]<=stress["onset"]<=tw["reference_onset_max"])
                duration_ok=(tw["reference_duration_min"]<=stress["duration"]<=tw["reference_duration_max"])
                timing_ok=bool(onset_ok and duration_ok)
                representation_summary[member]["timing_pass"] &= timing_ok
                integrity=(float(cd["max_abs_water_ledger_cm"])<=1.0e-10 and float(cc["max_abs_water_ledger_cm"])<=1.0e-10)
                representation_summary[member]["integrity_pass"] &= integrity

                td=threshold_diagnostics(np.asarray(ref_dyn[material][history]["mapped_10cm_theta"]),material,history,member)
                onset_ref=ref_dyn[material][history]["stress"]["onset"]
                onset_straddle=(td["per_observation_threshold_straddling"][onset_ref-1] if onset_ref else None)
                del td["per_observation_threshold_straddling"]

                cases[f"{material}_{history}_{member}"]={
                    "material":material,
                    "history":history,
                    "member":member,
                    "feedback_effect_metrics":metrics,
                    "covered_metric_adjudication":covered,
                    "candidate_stress":stress,
                    "reference_stress":ref_dyn[material][history]["stress"],
                    "timing_uncertainty":tw,
                    "onset_within_reference_numerical_range":onset_ok,
                    "duration_within_reference_numerical_range":duration_ok,
                    "integrity_pass":integrity,
                    "threshold_diagnostics":td,
                    "reference_onset_threshold_straddling":onset_straddle,
                }

    for member in MEMBERS:
        row=representation_summary[member]
        row["feedback_equivalence_pass"]=bool(row["covered_metric_pass"] and row["timing_pass"] and row["integrity_pass"])

    reduced_pass=[m for m in ("U4","U8","R8") if representation_summary[m]["feedback_equivalence_pass"]]
    overall=("MINIMAL_EXISTING_STATE_FEEDBACK_NOT_SHOWN_INSUFFICIENT_ON_TESTED_DOMAIN"
             if reduced_pass else
             "MINIMAL_EXISTING_STATE_FEEDBACK_FALSIFIED_ON_ONE_OR_MORE_PREREGISTERED_COMPONENTS_FOR_ALL_REDUCED_REPRESENTATIONS")

    placement={}
    for material in MATERIALS:
        for history in HISTORIES:
            u8=cases[f"{material}_{history}_U8"]["feedback_effect_metrics"]["actual_root_uptake_cm_per_day"]["feedback_effect_rmse"]
            r8=cases[f"{material}_{history}_R8"]["feedback_effect_metrics"]["actual_root_uptake_cm_per_day"]["feedback_effect_rmse"]
            placement[f"{material}_{history}"]={
                "U8_root_feedback_effect_rmse":u8,
                "R8_root_feedback_effect_rmse":r8,
                "smaller_error":"U8" if u8<r8 else ("R8" if r8<u8 else "EQUAL"),
            }

    out={
        "schema":"swap5.rom_root.s3.result.v1",
        "workstream":"ROM-ROOT",
        "work_unit":"ROM-ROOT-S3",
        "date":"2026-09-23",
        "status":"STAGE3_DYNAMIC_FEEDBACK_ANALYZED",
        "decision":overall,
        "reduced_representations_passing_bounded_success":reduced_pass,
        "representation_summary":representation_summary,
        "cases":cases,
        "upper_zone_placement_diagnostic":placement,
        "missing_information_boundary":{
            "A":"Use threshold-straddling diagnostics at and across stress onset; evidence is diagnostic, not an automatic state selection.",
            "B":"Use retained-mean versus 10-cm root-weighted feedback discrepancy on projected Reference profiles; 10-cm resolution is not proof of the fine functional.",
            "C":"Use U8 versus R8 same-dimension error pattern.",
            "D":"Use full-potential baseline RMSE separately from feedback-effect RMSE in every component.",
            "E":"Not independently adjudicated because the frozen Reference Feddes process has no separate stress-memory state and S3 has no preregistered matched-current-state prior-history experiment."
        },
        "application_acceptance":False,
        "scientific_firewall":{
            "new_partition_selected":False,
            "new_hydraulic_closure_selected":False,
            "new_root_specific_state_selected":False,
            "new_memory_state_selected":False,
            "application_acceptance_adjudicated":False,
            "performance_comparison_authorized":False,
            "production_rom_authorized":False
        },
        "model_changed":False
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":overall,
        "reduced_pass":reduced_pass,
        "representation_summary":representation_summary,
    },sort_keys=True))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
