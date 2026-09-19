#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib
import re
from collections import defaultdict

import numpy as np
from scipy.stats import rankdata, spearmanr

LADDER=list(range(20,141,10))
PULSE_STEPS=range(1,257)
DLOW=10.0
SIGN_ZERO=1.0e-12
SE_BY_INDEX={1:0.65,2:0.85,3:0.95}
FORCING_BY_INDEX={2:"WET",3:"DRY"}


def fields(payload):
    out={}
    for item in payload.split("|"):
        if "=" in item:
            k,v=item.split("=",1);out[k]=v
    return out


def load_case(path:pathlib.Path):
    rows=defaultdict(list)
    for line in path.read_text(errors="replace").splitlines():
        if not line.startswith("LAREDYN0R_NODE|"): continue
        d=fields(line.split("|",1)[1])
        rows[int(d["STEP"])].append({
            "node":int(d["NODE"]),
            "h":float(d["H"]),
            "theta":float(d["THETA"]),
            "z":float(d["Z"]),
            "dz":float(d["DZ"]),
        })
    if set(rows)!=set(range(1,1025)):
        raise ValueError(f"incomplete Reference case {path}: {len(rows)}")
    for step in rows:
        rows[step].sort(key=lambda r:r["node"])
        if [r["node"] for r in rows[step]]!=list(range(1,17)):
            raise ValueError(f"incomplete nodes {path} step {step}")
    return dict(rows)


def rms(values):
    values=np.asarray(values,dtype=float)
    return float(math.sqrt(float(np.mean(values*values)))) if values.size else 0.0


def safe_spearman(x,y):
    x=np.asarray(x,dtype=float);y=np.asarray(y,dtype=float)
    if np.all(x==x[0]) or np.all(y==y[0]):
        return 0.0
    value=float(spearmanr(x,y).statistic)
    return 0.0 if not math.isfinite(value) else value


def interface_sample(rows,L):
    n=L//10
    psi=np.asarray([-r["h"] for r in rows],dtype=float)
    psi_up_mean=float(np.mean(psi[:n]))
    psi_low_mean=float(psi[n])
    g_layer=2.0*(psi_low_mean-psi_up_mean)/(L+DLOW)
    g_ref=(psi[n]-psi[n-1])/10.0
    actual=g_layer-g_ref

    pm15=psi[n-2]
    pm5=psi[n-1]
    pp5=psi[n]
    pp15=psi[n+1]
    psi2=(pm15+pp15-pm5-pp5)/200.0
    psi3=(pp15-pm15-3.0*(pp5-pm5))/1000.0
    e2=(DLOW-L)/3.0*psi2
    coeff3=(DLOW*DLOW-DLOW*L+L*L)/12.0-25.0/6.0
    e3=e2+coeff3*psi3
    return actual,e2,e3,psi2,psi3


def case_summary(traj):
    perL={}
    pooled=[]
    for L in LADDER:
        a=[];e2=[];e3=[];p2=[];p3=[]
        for step in PULSE_STEPS:
            vals=interface_sample(traj[step],L)
            a.append(vals[0]);e2.append(vals[1]);e3.append(vals[2]);p2.append(vals[3]);p3.append(vals[4])
            pooled.append((vals[0],vals[1],vals[2]))
        perL[L]={
            "actual_rms":rms(a),
            "taylor2_rms":rms(e2),
            "taylor3_rms":rms(e3),
            "psi2_rms_per_cm":rms(p2),
            "psi3_rms_per_cm2":rms(p3),
            "length_only":abs(L-DLOW),
        }

    actual=[perL[L]["actual_rms"] for L in LADDER]
    indicators={
        "LENGTH_ONLY":[perL[L]["length_only"] for L in LADDER],
        "TAYLOR2_RMS":[perL[L]["taylor2_rms"] for L in LADDER],
        "TAYLOR3_RMS":[perL[L]["taylor3_rms"] for L in LADDER],
    }
    actual_peak=min(L for L in LADDER if perL[L]["actual_rms"]==max(actual))
    ranks={}
    for name,values in indicators.items():
        peak=min(L for L in LADDER if values[LADDER.index(L)]==max(values))
        ranks[name]={
            "spearman":safe_spearman(values,actual),
            "peak_L_cm":peak,
            "peak_abs_error_cm":abs(peak-actual_peak),
            "exact_peak_hit":peak==actual_peak,
        }

    return {
        "by_L":{str(L):perL[L] for L in LADDER},
        "actual_peak_L_cm":actual_peak,
        "indicators":ranks,
        "signed_samples":pooled,
    }


def source_cases(args):
    specs=[]

    b01_status=json.loads(args.b01_status.read_text())["geometries"]["fine"]
    for si,se in SE_BY_INDEX.items():
        for fi,forcing in FORCING_BY_INDEX.items():
            cid=f"S{si}_B1_F{fi}"
            specs.append({
                "material":"B01","se0":se,"forcing":forcing,"case":cid,
                "status":b01_status[cid]["status"],
                "path":args.b01_dir/f"fine-{cid}-o2.txt"
            })

    b14_status=json.loads(args.b14_status.read_text())["geometries"]["fine"]
    for si,se in SE_BY_INDEX.items():
        for fi,forcing in FORCING_BY_INDEX.items():
            cid=f"S{si}_B1_F{fi}"
            specs.append({
                "material":"B14","se0":se,"forcing":forcing,"case":cid,
                "status":b14_status[cid]["status"],
                "path":args.b14_dir/f"fine-{cid}-o2.txt"
            })

    cp_status=json.loads(args.carsel_status.read_text())["materials"]
    for material in ("SAND","LOAM","CLAY"):
        for si,se in SE_BY_INDEX.items():
            for fi,forcing in FORCING_BY_INDEX.items():
                cid=f"S{si}_B1_F{fi}"
                specs.append({
                    "material":material,"se0":se,"forcing":forcing,"case":cid,
                    "status":cp_status[material][cid]["status"],
                    "path":args.carsel_dir/f"fine-{material}-{cid}-o2.txt"
                })
    return specs


def aggregate_indicator(case_rows,name):
    vals=[row["summary"]["indicators"][name] for row in case_rows]
    return {
        "case_count":len(vals),
        "median_spearman":float(np.median([v["spearman"] for v in vals])),
        "mean_spearman":float(np.mean([v["spearman"] for v in vals])),
        "median_abs_peak_error_cm":float(np.median([v["peak_abs_error_cm"] for v in vals])),
        "mean_abs_peak_error_cm":float(np.mean([v["peak_abs_error_cm"] for v in vals])),
        "exact_peak_hit_count":sum(int(v["exact_peak_hit"]) for v in vals),
    }


def dominates(a,b):
    nonworse=(
        a["median_spearman"]>=b["median_spearman"]
        and a["median_abs_peak_error_cm"]<=b["median_abs_peak_error_cm"]
        and a["exact_peak_hit_count"]>=b["exact_peak_hit_count"]
    )
    strict=(
        a["median_spearman"]>b["median_spearman"]
        or a["median_abs_peak_error_cm"]<b["median_abs_peak_error_cm"]
        or a["exact_peak_hit_count"]>b["exact_peak_hit_count"]
    )
    return nonworse and strict


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--b01-dir",required=True,type=pathlib.Path)
    ap.add_argument("--b01-status",required=True,type=pathlib.Path)
    ap.add_argument("--b14-dir",required=True,type=pathlib.Path)
    ap.add_argument("--b14-status",required=True,type=pathlib.Path)
    ap.add_argument("--carsel-dir",required=True,type=pathlib.Path)
    ap.add_argument("--carsel-status",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    p=json.loads(args.prereg.read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_TAYLOR_GRADIENT_STRUCTURE_ANALYSIS"
    assert p["pre_execution_operationalization"]["before_first_MECH4A_result"] is True
    assert p["derivative_estimator"]["tested_interfaces_cm"]==LADDER

    cases=[]
    excluded=[]
    pooled_actual=[];pooled_e2=[];pooled_e3=[]
    material_counts=defaultdict(int)
    sign2_num=sign2_den=sign3_num=sign3_den=0

    for spec in source_cases(args):
        if spec["status"]!="QUALIFIED":
            excluded.append({k:spec[k] for k in ("material","case","se0","forcing","status")})
            continue
        traj=load_case(spec["path"])
        summary=case_summary(traj)
        samples=summary.pop("signed_samples")
        for actual,e2,e3 in samples:
            pooled_actual.append(actual);pooled_e2.append(e2);pooled_e3.append(e3)
            if abs(actual)>SIGN_ZERO:
                sign2_den+=1;sign3_den+=1
                sign2_num+=int(math.copysign(1.0,actual)==math.copysign(1.0,e2)) if abs(e2)>0 else 0
                sign3_num+=int(math.copysign(1.0,actual)==math.copysign(1.0,e3)) if abs(e3)>0 else 0
        cases.append({**{k:spec[k] for k in ("material","case","se0","forcing")},"summary":summary})
        material_counts[spec["material"]]+=1

    indicators={name:aggregate_indicator(cases,name) for name in ("LENGTH_ONLY","TAYLOR2_RMS","TAYLOR3_RMS")}
    curvature_names=["TAYLOR2_RMS","TAYLOR3_RMS"]
    best=sorted(
        curvature_names,
        key=lambda name:(
            -indicators[name]["median_spearman"],
            indicators[name]["median_abs_peak_error_cm"],
            -indicators[name]["exact_peak_hit_count"],
            name
        )
    )[0]

    actual=np.asarray(pooled_actual);e2=np.asarray(pooled_e2);e3=np.asarray(pooled_e3)
    baseline_rms=rms(actual)
    res2=rms(actual-e2)
    res3=rms(actual-e3)
    signed_chain=res3<res2<baseline_rms
    rank_dom=dominates(indicators[best],indicators["LENGTH_ONLY"])

    if rank_dom and signed_chain:
        decision="CURVATURE_RANKING_SUPPORTED_AND_TAYLOR3_IMPROVES"
    elif rank_dom:
        decision="CURVATURE_RANKING_SUPPORTED_LOCAL_EXPANSION_INCOMPLETE"
    elif signed_chain:
        decision="LOCAL_TAYLOR_STRUCTURE_SUPPORTED_WITHOUT_RANKING_GAIN"
    else:
        decision="TAYLOR_CURVATURE_STRUCTURE_NOT_SUPPORTED"

    result={
        "schema":"swap5.lare.dyn0a.mech4a.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-DYN0A-MECH4A",
        "decision":decision,
        "qualified_case_count":len(cases),
        "qualified_case_count_by_material":dict(material_counts),
        "excluded_cases":excluded,
        "indicator_summary":indicators,
        "best_curvature_indicator":best,
        "best_curvature_dominates_length_only":rank_dom,
        "signed_prediction":{
            "sample_count":len(actual),
            "zero_prediction_rms_actual_gradient_error":baseline_rms,
            "taylor2_residual_rms":res2,
            "taylor3_residual_rms":res3,
            "taylor3_lt_taylor2_lt_zero_baseline":signed_chain,
            "taylor2_sign_agreement_fraction":sign2_num/sign2_den if sign2_den else None,
            "taylor3_sign_agreement_fraction":sign3_num/sign3_den if sign3_den else None,
        },
        "cases":cases,
        "interpretation_firewall":[
            "MECH4A uses already exposed fine-Reference trajectories and is mechanism discovery, not blind transfer.",
            "The actual error is the normalized MECH1 gradient-reconstruction component using exact fine-profile layer-mean capillary potential.",
            "Taylor coefficients are analytic and unfitted; no material or forcing multiplier is estimated.",
            "A later blind MECH4B must freeze any curvature-based indicator before generating trajectories on unused materials."
        ],
        "application_acceptance_adjudicated":False,
        "lare_propagation_changed":False,
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "schema":result["schema"],"decision":decision,
        "qualified_case_count":len(cases),
        "indicator_summary":indicators,
        "best_curvature_indicator":best,
        "best_curvature_dominates_length_only":rank_dom,
        "signed_prediction":result["signed_prediction"]
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
