#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import pathlib
import sys

import numpy as np

HERE=pathlib.Path(__file__).resolve().parent
HISTORIES=("V01","V02","V03","V04")
MEMBERS=("U4","U8","R8","R16")
ROUTES=("R512_T32","R1024_T32","R2048_T32","R2048_T16","R2048_T8")
TARGET="R2048_T32"
OBS_DT=0.0008
GUARD=2.9103830456733704e-11
METRIC_MAP=(
    ("root_zone_0_40_storage_cm","root_zone_0_40_storage_rmse_cm"),
    ("upper_0_80_storage_cm","upper_0_80_storage_rmse_cm"),
    ("theta_10cm","mapped_10cm_theta_rmse"),
    ("interval_actual_root_uptake_cm_per_day","interval_actual_root_uptake_rmse_cm_per_day"),
    ("cumulative_actual_root_uptake_cm","cumulative_actual_root_uptake_rmse_cm"),
)

def load_module(name:str,path:pathlib.Path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    mod=importlib.util.module_from_spec(spec)
    sys.modules[name]=mod
    spec.loader.exec_module(mod)
    return mod

refmod=load_module("rom_root_s3_refparse",HERE/"analyze_lare_bc2_c6r_reference_uncertainty.py")
candmod=load_module("rom_root_s3_candidate_module",HERE/"run_rom_root_s3_dynamic_feedback.py")

def fields(line:str)->dict[str,str]:
    out={}
    for item in line.split("|")[1:]:
        if "=" in item:
            k,v=item.split("=",1)
            out[k]=v
    return out

def factor(route:str)->int:
    return int(route.rsplit("_T",1)[1])

def rmse(a,b)->float:
    x=np.asarray(a,dtype=float)-np.asarray(b,dtype=float)
    return float(np.sqrt(np.mean(x*x)))

def parse_reference_extended(path:pathlib.Path,route:str,material:str,initial_se:dict)->dict:
    base=refmod.parse(path,route)
    fac=factor(route)
    exchanges={h:{} for h in HISTORIES}
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("LAREDYN0R_STATE|"):
            r=fields(line)
            h=r.get("CASE")
            if h in exchanges:
                exchanges[h][int(r["STEP"])]=float(r["BOTTOM_DOWNWARD_EXCHANGE"])
    candmod.s2.configure_material(material)
    for h in HISTORIES:
        expected=1024*fac
        if sorted(exchanges[h])!=list(range(1,expected+1)):
            raise RuntimeError(f"{path} {h}: bottom-exchange coverage")
        interval=[]
        cumulative=[]
        running=0.0
        for obs in range(1,1025):
            lo=(obs-1)*fac+1
            hi=obs*fac
            amount=math.fsum(exchanges[h][i] for i in range(lo,hi+1))
            running+=amount
            interval.append(amount/OBS_DT)
            cumulative.append(running)
        theta=np.asarray(base["histories"][h]["theta_10cm"],dtype=float)
        theta0=float(candmod.s2.bc.theta_from_se(float(initial_se[h])))
        redistribution=np.std(theta-theta0,axis=1)
        base["histories"][h]["interval_bottom_downward_flux_cm_per_day"]=np.asarray(interval)
        base["histories"][h]["cumulative_bottom_downward_cm"]=np.asarray(cumulative)
        base["histories"][h]["profile_redistribution_index"]=np.asarray(redistribution)
    return base

def stress_summary(fraction)->dict:
    arr=np.asarray(fraction,dtype=float)
    idx=np.where(arr < 1.0-GUARD)[0]
    return {
        "onset_observation":None if idx.size==0 else int(idx[0]+1),
        "stressed_observation_count":int(idx.size),
        "stress_duration_day":float(idx.size*OBS_DT),
        "minimum_fraction":float(np.min(arr)),
    }

def timing_uncertainty(routes:dict,history:str)->dict:
    target=stress_summary(routes[TARGET]["histories"][history]["actual_over_potential_fraction"])
    onset_diffs=[]
    duration_diffs=[]
    for r in ROUTES:
        s=stress_summary(routes[r]["histories"][history]["actual_over_potential_fraction"])
        if target["onset_observation"] is None or s["onset_observation"] is None:
            onset_diffs.append(1024 if target["onset_observation"]!=s["onset_observation"] else 0)
        else:
            onset_diffs.append(abs(target["onset_observation"]-s["onset_observation"]))
        duration_diffs.append(abs(target["stressed_observation_count"]-s["stressed_observation_count"]))
    return {
        "target":target,
        "max_onset_observation_difference":int(max(onset_diffs)),
        "max_stressed_observation_count_difference":int(max(duration_diffs)),
    }

def alpha_from_h(h:np.ndarray,tp:float)->np.ndarray:
    return candmod.drought_alpha(np.asarray(h,dtype=float),tp)

def threshold_diagnostic(ref_history:dict,material:str,history:str,member:str)->dict:
    candmod.s2.configure_material(material)
    theta=np.asarray(ref_history["theta_10cm"],dtype=float)
    bounds=candmod.PARTITIONS[member]
    tp=float(candmod.HISTORIES[history]["tp"])
    profile=str(candmod.HISTORIES[history]["root"])
    h3=candmod.critical_h3(tp)
    bins=np.arange(0.0,161.0,10.0)
    root10=candmod.s2.layer_root_fractions(bins.tolist(),profile)
    retained_root=candmod.s2.layer_root_fractions(bounds,profile)
    span_count=0
    proxy=[]
    for obs in range(theta.shape[0]):
        psi,_=candmod.s2.bc.psi_k(theta[obs])
        h10=-psi
        fine_effect=float(np.dot(root10,alpha_from_h(h10,tp)))
        retained_effect=0.0
        for li,(lo,hi) in enumerate(zip(bounds,bounds[1:])):
            if retained_root[li]<=0.0:
                continue
            i0=int(round(lo/10.0)); i1=int(round(hi/10.0))
            vals=theta[obs,i0:i1]
            hs=h10[i0:i1]
            if len(hs)>1 and float(np.min(hs)) <= h3 <= float(np.max(hs)):
                span_count+=1
            width=hi-lo
            theta_bar=float(np.mean(vals)) if width>0 else float("nan")
            psi_bar,_=candmod.s2.bc.psi_k(np.asarray([theta_bar]))
            retained_effect += float(retained_root[li])*float(alpha_from_h(np.asarray([-psi_bar[0]]),tp)[0])
        proxy.append(retained_effect-fine_effect)
    p=np.asarray(proxy)
    return {
        "retained_layer_h3_threshold_span_count":int(span_count),
        "ten_cm_root_weighted_vs_retained_mean_alpha_proxy_rmse":float(np.sqrt(np.mean(p*p))),
        "ten_cm_root_weighted_vs_retained_mean_alpha_proxy_max_abs":float(np.max(np.abs(p))),
        "proxy_is_not_fine_node_exact":True,
    }

def candidate_case(path:pathlib.Path)->dict:
    return json.loads(path.read_text())

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--ra02r-result",required=True,type=pathlib.Path)
    ap.add_argument("--s3c0-result",required=True,type=pathlib.Path)
    ap.add_argument("--candidate-dir",required=True,type=pathlib.Path)
    for prefix in ("ra02r","s3c0"):
        for mat in ("b01","b14"):
            for route in ROUTES:
                ap.add_argument(f"--{prefix}-{mat}-{route.lower().replace('_','-')}",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    dyn_auth=json.loads(a.ra02r_result.read_text())
    full_auth=json.loads(a.s3c0_result.read_text())
    assert pre["state"]=="PREREGISTERED_BEFORE_ANY_STAGE3_REDUCED_DYNAMIC_FEEDBACK_RESPONSE"
    assert dyn_auth["status"]=="RA02R_STRESS_ACTIVE_REFERENCE_QUALIFIED"
    assert full_auth["status"]=="S3C0_FULL_POTENTIAL_REFERENCE_QUALIFIED"

    initial=pre["domain"]["initial_effective_saturation"]
    refs={"dynamic":{},"full":{}}
    for material in ("B01","B14"):
        ml=material.lower()
        refs["dynamic"][material]={}
        refs["full"][material]={}
        for route in ROUTES:
            key=route.lower().replace("_","-")
            refs["dynamic"][material][route]=parse_reference_extended(
                getattr(a,f"ra02r_{ml}_{key.replace('-','_')}",None) if False else
                getattr(a,f"ra02r_{ml}_{route.lower()}"),route,material,initial[material])
            refs["full"][material][route]=parse_reference_extended(
                getattr(a,f"s3c0_{ml}_{route.lower()}"),route,material,initial[material])

    cases={}
    member_summary={m:{"case_count":0,"bounded_success_count":0,"feedback_bound_ratio_by_metric":{k:[] for _,k in METRIC_MAP}} for m in MEMBERS}

    for material in ("B01","B14"):
        dyn_u=dyn_auth["materials"][material]["metrics"]
        full_u=full_auth["materials"][material]["metrics"]
        timing={h:timing_uncertainty(refs["dynamic"][material],h) for h in HISTORIES}
        for history in HISTORIES:
            rd=refs["dynamic"][material][TARGET]["histories"][history]
            rf=refs["full"][material][TARGET]["histories"][history]
            for member in MEMBERS:
                path=a.candidate_dir/f"{material}_{history}_{member}.json"
                c=candidate_case(path)
                cid=f"{material}_{history}_{member}"
                if c["status"]!="QUALIFIED":
                    cases[cid]={
                        "status":c["status"],"failure":c.get("failure"),
                        "bounded_success":False,
                        "missing_information":{"D_hydraulic_propagation_supported":False},
                    }
                    member_summary[member]["case_count"]+=1
                    continue
                cd=c["dynamic"]; cf=c["full_potential_control"]
                metrics={}
                feedback_pass=True
                hydraulic_d=[]
                for src,mkey in METRIC_MAP:
                    e_dyn=rmse(cd[src],rd[src])
                    e_base=rmse(cf[src],rf[src])
                    delta_c=np.asarray(cd[src],dtype=float)-np.asarray(cf[src],dtype=float)
                    delta_r=np.asarray(rd[src],dtype=float)-np.asarray(rf[src],dtype=float)
                    e_feedback=float(np.sqrt(np.mean((delta_c-delta_r)**2)))
                    ud=float(dyn_u[mkey]["U_combined"])
                    uf=float(full_u[mkey]["U_combined"])
                    bound=ud+uf
                    p=e_feedback<=bound
                    feedback_pass &= p
                    d_support=bool(p and e_dyn>ud)
                    hydraulic_d.append(d_support)
                    ratio=e_feedback/bound if bound>0.0 else (0.0 if e_feedback==0.0 else math.inf)
                    metrics[mkey]={
                        "dynamic_absolute_rmse":e_dyn,
                        "full_potential_hydraulic_baseline_rmse":e_base,
                        "feedback_effect_rmse":e_feedback,
                        "dynamic_reference_U":ud,
                        "full_potential_reference_U":uf,
                        "feedback_effect_bound":bound,
                        "feedback_effect_bound_ratio":ratio,
                        "feedback_effect_numerically_distinguishable":not p,
                        "hydraulic_propagation_D_supported":d_support,
                    }
                    member_summary[member]["feedback_bound_ratio_by_metric"][mkey].append(ratio)

                ref_stress=timing[history]["target"]
                cand_stress=c["stress"]
                if ref_stress["onset_observation"] is None or cand_stress["onset_observation"] is None:
                    onset_diff=1024 if ref_stress["onset_observation"]!=cand_stress["onset_observation"] else 0
                else:
                    onset_diff=abs(ref_stress["onset_observation"]-cand_stress["onset_observation"])
                duration_diff=abs(ref_stress["stressed_observation_count"]-cand_stress["stressed_observation_count"])
                timing_pass=(onset_diff<=timing[history]["max_onset_observation_difference"] and
                             duration_diff<=timing[history]["max_stressed_observation_count_difference"])

                frac_rmse=rmse(cd["actual_over_potential_fraction"],rd["actual_over_potential_fraction"])
                frac_max=float(np.max(np.abs(np.asarray(cd["actual_over_potential_fraction"])-np.asarray(rd["actual_over_potential_fraction"]))))
                cum=np.asarray(cd["cumulative_actual_root_uptake_cm"])-np.asarray(rd["cumulative_actual_root_uptake_cm"])
                terminal_cum=float(cum[-1])
                redistribution_abs=rmse(cd["profile_redistribution_index"],rd["profile_redistribution_index"])
                redistribution_delta=rmse(
                    np.asarray(cd["profile_redistribution_index"])-np.asarray(cf["profile_redistribution_index"]),
                    np.asarray(rd["profile_redistribution_index"])-np.asarray(rf["profile_redistribution_index"])
                )
                bottom_cum=rmse(cd["cumulative_bottom_downward_cm"],rd["cumulative_bottom_downward_cm"])
                bottom_flux=rmse(cd["interval_bottom_downward_flux_cm_per_day"],rd["interval_bottom_downward_flux_cm_per_day"])
                thresh=threshold_diagnostic(rd,material,history,member)
                bounded=bool(feedback_pass and timing_pass)
                member_summary[member]["case_count"]+=1
                member_summary[member]["bounded_success_count"]+=int(bounded)
                cases[cid]={
                    "status":"QUALIFIED",
                    "bounded_success":bounded,
                    "feedback_metrics":metrics,
                    "stress":{
                        "reference":ref_stress,
                        "candidate":cand_stress,
                        "onset_observation_difference":onset_diff,
                        "duration_observation_difference":duration_diff,
                        "onset_numerical_uncertainty_observations":timing[history]["max_onset_observation_difference"],
                        "duration_numerical_uncertainty_observations":timing[history]["max_stressed_observation_count_difference"],
                        "timing_within_reference_numerical_uncertainty":timing_pass,
                    },
                    "additional_component_diagnostics":{
                        "actual_transpiration_fraction_rmse":frac_rmse,
                        "actual_transpiration_fraction_max_abs_error":frac_max,
                        "cumulative_root_uptake_terminal_error_cm":terminal_cum,
                        "profile_redistribution_index_rmse":redistribution_abs,
                        "profile_redistribution_feedback_effect_rmse":redistribution_delta,
                        "cumulative_bottom_exchange_rmse_cm":bottom_cum,
                        "interval_bottom_flux_rmse_cm_per_day":bottom_flux,
                        "max_abs_water_ledger_cm":max(float(cd["max_abs_water_ledger_cm"]),float(cf["max_abs_water_ledger_cm"])),
                    },
                    "threshold_distribution_diagnostic":thresh,
                    "missing_information":{
                        "D_hydraulic_propagation_supported":bool(any(hydraulic_d)),
                        "A_threshold_crossing_proxy_present":bool(thresh["retained_layer_h3_threshold_span_count"]>0),
                        "B_root_weighted_distribution_proxy_nonzero":bool(thresh["ten_cm_root_weighted_vs_retained_mean_alpha_proxy_max_abs"]>0.0),
                        "C_upper_zone_placement_requires_cross_representation_synthesis":True,
                        "E_memory_not_adjudicated":True,
                    },
                }

    for member,v in member_summary.items():
        v["all_cases_bounded_success"]=v["bounded_success_count"]==v["case_count"]==8
        v["feedback_bound_ratio_by_metric"]={
            k:{
                "max":float(max(vals)) if vals else None,
                "mean":float(sum(vals)/len(vals)) if vals else None
            } for k,vals in v["feedback_bound_ratio_by_metric"].items()
        }

    all_success=all(v["all_cases_bounded_success"] for v in member_summary.values())
    any_success=any(v["all_cases_bounded_success"] for v in member_summary.values())
    if all_success:
        decision="MINIMAL_FEEDBACK_NOT_FALSIFIED_ALL_TESTED_REPRESENTATIONS"
    elif any_success:
        decision="PURPOSE_REPRESENTATION_DEPENDENT_MINIMAL_FEEDBACK_RESULT"
    else:
        decision="MINIMAL_FEEDBACK_FALSIFIED_ON_AT_LEAST_ONE_COMPONENT_IN_EVERY_TESTED_REPRESENTATION"

    out={
        "schema":"swap5.rom_root.s3.result.v1",
        "workstream":"ROM-ROOT",
        "work_unit":"ROM-ROOT-S3",
        "date":"2026-09-23",
        "status":"STAGE3_DYNAMIC_FEEDBACK_BLIND_COMPARISON_COMPLETE",
        "decision":decision,
        "cases":cases,
        "representation_summary":member_summary,
        "all_tested_representations_bounded_success":all_success,
        "at_least_one_representation_bounded_success":any_success,
        "interpretation":{
            "bounded_success_meaning":"No feedback-specific discrepancy above independently qualified Reference numerical uncertainty and stress timing within frozen Reference timing uncertainty on the tested mechanistic domain.",
            "application_acceptance":False,
            "crop_validation":False,
            "new_state_selected":False,
            "performance_claim":False,
        },
        "scientific_firewall":{
            "new_partition_selected":False,
            "new_hydraulic_closure_selected":False,
            "new_root_specific_state_selected":False,
            "application_acceptance_adjudicated":False,
            "performance_comparison_authorized":False,
            "production_rom_authorized":False,
        },
        "model_changed":False,
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "status":out["status"],"decision":decision,
        "representations":{m:{
            "bounded_success_count":v["bounded_success_count"],
            "all_cases":v["all_cases_bounded_success"],
            "max_feedback_bound_ratio":max(
                (q["max"] for q in v["feedback_bound_ratio_by_metric"].values() if q["max"] is not None),
                default=None
            )
        } for m,v in member_summary.items()}
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
