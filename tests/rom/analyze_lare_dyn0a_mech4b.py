#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib
from collections import defaultdict

import numpy as np
from scipy.stats import spearmanr

LADDER=list(range(20,141,10))
PULSE_STEPS=range(1,257)
DLOW=10.0
MATERIALS=("SANDY_LOAM","SILT","CLAY_LOAM")
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
            "node":int(d["NODE"]),"h":float(d["H"])
        })
    if set(rows)!=set(range(1,1025)):
        raise ValueError(f"incomplete {path}: {len(rows)} steps")
    for step in rows:
        rows[step].sort(key=lambda r:r["node"])
        if [r["node"] for r in rows[step]]!=list(range(1,17)):
            raise ValueError(f"incomplete nodes {path} step {step}")
    return dict(rows)


def rms(values):
    a=np.asarray(values,float)
    return float(math.sqrt(float(np.mean(a*a)))) if a.size else 0.0


def safe_spearman(x,y):
    a=np.asarray(x,float);b=np.asarray(y,float)
    if np.all(a==a[0]) or np.all(b==b[0]): return 0.0
    v=float(spearmanr(a,b).statistic)
    return 0.0 if not math.isfinite(v) else v


def sample(rows,L):
    n=L//10
    psi=np.asarray([-r["h"] for r in rows],float)
    up=float(np.mean(psi[:n]));lo=float(psi[n])
    actual=2.0*(lo-up)/(L+DLOW)-(psi[n]-psi[n-1])/10.0
    pm15,pm5,pp5,pp15=psi[n-2],psi[n-1],psi[n],psi[n+1]
    psi2=(pm15+pp15-pm5-pp5)/200.0
    psi3=(pp15-pm15-3.0*(pp5-pm5))/1000.0
    e2=(DLOW-L)/3.0*psi2
    e3=e2+((DLOW*DLOW-DLOW*L+L*L)/12.0-25.0/6.0)*psi3
    return actual,e2,e3


def summarize_case(traj):
    byL={}
    for L in LADDER:
        actual=[];e2=[];e3=[]
        for step in PULSE_STEPS:
            a,b,c=sample(traj[step],L)
            actual.append(a);e2.append(b);e3.append(c)
        byL[L]={
            "actual_rms":rms(actual),
            "length_only":abs(L-DLOW),
            "taylor2_rms":rms(e2),
            "taylor3_rms":rms(e3),
        }
    av=[byL[L]["actual_rms"] for L in LADDER]
    actual_peak=min(L for L in LADDER if byL[L]["actual_rms"]==max(av))
    indicators={}
    for name,key in (
        ("LENGTH_ONLY","length_only"),
        ("TAYLOR2_RMS","taylor2_rms"),
        ("TAYLOR3_RMS","taylor3_rms")
    ):
        vals=[byL[L][key] for L in LADDER]
        peak=min(L for L in LADDER if byL[L][key]==max(vals))
        indicators[name]={
            "spearman":safe_spearman(vals,av),
            "peak_L_cm":peak,
            "peak_abs_error_cm":abs(peak-actual_peak),
            "exact_peak_hit":peak==actual_peak,
        }
    return {
        "actual_peak_L_cm":actual_peak,
        "indicators":indicators,
        "by_L":{str(L):byL[L] for L in LADDER}
    }


def aggregate(cases,name):
    rows=[r["summary"]["indicators"][name] for r in cases]
    return {
        "case_count":len(rows),
        "median_spearman":float(np.median([r["spearman"] for r in rows])),
        "mean_spearman":float(np.mean([r["spearman"] for r in rows])),
        "median_abs_peak_error_cm":float(np.median([r["peak_abs_error_cm"] for r in rows])),
        "mean_abs_peak_error_cm":float(np.mean([r["peak_abs_error_cm"] for r in rows])),
        "exact_peak_hit_count":sum(int(r["exact_peak_hit"]) for r in rows)
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
    ap.add_argument("--reference-dir",required=True,type=pathlib.Path)
    ap.add_argument("--status",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    p=json.loads(args.prereg.read_text())
    status=json.loads(args.status.read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_NEW_TAYLOR_RANKING_VALIDATION_TRAJECTORIES"
    assert p["ranking_experiment"]["L_cm"]==LADDER
    assert tuple(p["external_materials"]["materials"])==MATERIALS

    cases=[];excluded=[];usable={}
    for material in MATERIALS:
        qc=0;wet=False;dry=False
        for si,se0 in SE_BY_INDEX.items():
            for fi,forcing in FORCING_BY_INDEX.items():
                cid=f"S{si}_B1_F{fi}"
                st=status["materials"][material][cid]["status"]
                if st!="QUALIFIED":
                    excluded.append({"material":material,"case":cid,"se0":se0,"forcing":forcing,"status":st})
                    continue
                qc+=1;wet|=forcing=="WET";dry|=forcing=="DRY"
                traj=load_case(args.reference_dir/f"fine-{material}-{cid}-o2.txt")
                cases.append({
                    "material":material,"case":cid,"se0":se0,"forcing":forcing,
                    "summary":summarize_case(traj)
                })
        usable[material]={
            "qualified_case_count":qc,
            "has_WET":wet,
            "has_DRY":dry,
            "usable_for_minimum":wet and dry
        }

    panel_ok=sum(int(v["usable_for_minimum"]) for v in usable.values())>=2 and len(cases)>=10
    aggregate_summary={}
    per_material={}
    material_consistency={}
    aggregate_dominance=False
    if panel_ok:
        for name in ("LENGTH_ONLY","TAYLOR2_RMS","TAYLOR3_RMS"):
            aggregate_summary[name]=aggregate(cases,name)
        aggregate_dominance=dominates(aggregate_summary["TAYLOR3_RMS"],aggregate_summary["LENGTH_ONLY"])
        for material in MATERIALS:
            mc=[c for c in cases if c["material"]==material]
            if not usable[material]["usable_for_minimum"]:
                continue
            per_material[material]={
                name:aggregate(mc,name)
                for name in ("LENGTH_ONLY","TAYLOR2_RMS","TAYLOR3_RMS")
            }
            t=per_material[material]["TAYLOR3_RMS"];base=per_material[material]["LENGTH_ONLY"]
            material_consistency[material]=(
                t["median_spearman"]>base["median_spearman"]
                and t["median_abs_peak_error_cm"]<=base["median_abs_peak_error_cm"]
            )
        if aggregate_dominance and all(material_consistency.values()):
            decision="CURVATURE_RISK_RANKING_TRANSFER_SUPPORTED"
        elif aggregate_dominance:
            decision="CURVATURE_RISK_RANKING_TRANSFER_PARTIAL"
        else:
            decision="CURVATURE_RISK_RANKING_TRANSFER_NOT_SUPPORTED"
    else:
        decision="BLIND_RANKING_REFERENCE_INSUFFICIENT"

    result={
        "schema":"swap5.lare.dyn0a.mech4b.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-DYN0A-MECH4B",
        "decision":decision,
        "reference_panel_sufficient":panel_ok,
        "qualified_case_count":len(cases),
        "usable_materials":usable,
        "excluded_cases":excluded,
        "aggregate_indicator_summary":aggregate_summary,
        "aggregate_TAYLOR3_dominates_LENGTH_ONLY":aggregate_dominance,
        "per_material_indicator_summary":per_material,
        "material_consistency":material_consistency,
        "case_results":cases,
        "interpretation_firewall":[
            "The new materials and Taylor formula were frozen before the blind trajectories were generated.",
            "Only ranking of interface risk is tested; signed Taylor magnitude was already rejected as a closure correction by MECH4A.",
            "No coefficient is fitted and no layer size is selected from the blind panel.",
            "A supported result authorizes only further research on curvature-guided fixed-grid design."
        ],
        "application_acceptance_adjudicated":False,
        "closure_correction_authorized":False,
        "production_rom_authorized":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "schema":result["schema"],"decision":decision,
        "qualified_case_count":len(cases),
        "usable_materials":usable,
        "aggregate_indicator_summary":aggregate_summary,
        "aggregate_TAYLOR3_dominates_LENGTH_ONLY":aggregate_dominance,
        "material_consistency":material_consistency
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
