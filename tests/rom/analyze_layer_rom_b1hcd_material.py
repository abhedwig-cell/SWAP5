#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib
import re
from collections import defaultdict
from typing import Any

import numpy as np

MATERIALS=("B02","B05","B06","B11","B12","B16")
MEMBERS=("L4","L6","R8")
HISTS=("X01","X02","X03","X04")
CHECKPOINTS=(64,128,256,512,1024)
TOL=1.0e-12
GW=(
    "storage_rmse_cm",
    "cumulative_bottom_rmse_cm",
    "bottom_flux_rmse_cm_per_day",
    "bottom_flux_sign_errors",
    "abs_mean_signed_bottom_flux_error_cm_per_day",
    "max_abs_final_cumulative_bottom_error_cm",
)
VERTICAL=("upper_storage_rmse_cm","lower_storage_rmse_cm","mapped_theta_rmse")
ALL=GW+VERTICAL


def fields(payload:str)->dict[str,str]:
    out={}
    for item in payload.split("|"):
        if "=" in item:
            k,v=item.split("=",1)
            out[k]=v
    return out


def parse_log(path:pathlib.Path)->dict[str,Any]:
    states={}
    nodes=defaultdict(dict)
    initial={}
    for line in path.read_text(errors="replace").splitlines():
        if "F_ROMV2_D13_REF_INITIAL|" in line:
            r=fields(line.split("F_ROMV2_D13_REF_INITIAL|",1)[1])
            initial[r["HISTORY"].strip()]=r
        elif "F_ROMV2_D13_REF_STATE|" in line:
            r=fields(line.split("F_ROMV2_D13_REF_STATE|",1)[1])
            states[(r["HISTORY"].strip(),int(r["STEP"]))]=r
        elif "F_ROMV2_D13_REF_NODE|" in line:
            r=fields(line.split("F_ROMV2_D13_REF_NODE|",1)[1])
            nodes[(r["HISTORY"].strip(),int(r["STEP"]))][int(r["NODE"])]=r
    return {"states":states,"nodes":dict(nodes),"initial":initial}


def qstats(values:list[float])->dict[str,float|int]:
    a=np.asarray(values,dtype=float)
    aa=np.abs(a)
    return {
        "count":int(a.size),
        "mean":float(np.mean(a)),
        "mean_abs":float(np.mean(aa)),
        "rmse":float(np.sqrt(np.mean(a*a))),
        "max_abs":float(np.max(aa)),
    }


def sign(x:float)->int:
    return 1 if x>0.0 else (-1 if x<0.0 else 0)


def reversal_steps(signs:list[int])->list[int]:
    out=[]
    previous=0
    for step,current in enumerate(signs,1):
        if current==0:
            continue
        if previous and current!=previous:
            out.append(step)
        previous=current
    return out


def map_piecewise(theta:list[float],bounds:list[float])->list[float]:
    out=[]
    for node in range(16):
        lo=node*10.0
        hi=(node+1)*10.0
        total=0.0
        for t,a,b in zip(theta,bounds,bounds[1:]):
            w=max(0.0,min(hi,b)-max(lo,a))
            if w>0.0:
                total+=t*w
        out.append(total/10.0)
    return out


def series_for_member(
    reference:dict[str,Any],
    qdir:pathlib.Path,
    member:str,
    bounds:list[float],
)->dict[str,dict[str,list]]:
    series={h:{
        "S":[],"C":[],"Q":[],"SIGNERR":[],"THETA":[],
        "UPPER":[],"LOWER":[],"CAND_SIGN":[],"REF_SIGN":[]
    } for h in HISTS}

    for hist in HISTS:
        candidate=parse_log(qdir/member/f"{member}-{hist}-o0.txt")
        expected={(hist,s) for s in range(1,1025)}
        if set(candidate["states"])!=expected:
            raise SystemExit(f"{member} {hist}: state structure drift {len(candidate['states'])}")
        if len(candidate["nodes"])!=1024:
            raise SystemExit(f"{member} {hist}: node-step structure drift")
        refcum=0.0
        candcum=0.0
        for step in range(1,1025):
            rr=reference["states"][(hist,step)]
            cr=candidate["states"][(hist,step)]
            refcum+=float(rr["BOTTOM_OUTWARD_EXCHANGE"])
            candcum+=float(cr["BOTTOM_OUTWARD_EXCHANGE"])
            refq=float(rr["BOTTOM_FLUX"])
            candq=float(cr["BOTTOM_FLUX"])
            z=series[hist]
            z["S"].append(float(cr["TOTAL_STORAGE"])-float(rr["TOTAL_STORAGE"]))
            z["C"].append(candcum-refcum)
            z["Q"].append(candq-refq)
            z["SIGNERR"].append(int(sign(refq)!=0 and sign(candq)!=sign(refq)))
            z["CAND_SIGN"].append(sign(candq))
            z["REF_SIGN"].append(sign(refq))
            z["UPPER"].append(float(cr["UPPER_STORAGE"])-float(rr["UPPER_STORAGE"]))
            z["LOWER"].append(float(cr["LOWER_STORAGE"])-float(rr["LOWER_STORAGE"]))

            cnode=candidate["nodes"][(hist,step)]
            theta=[float(cnode[i]["THETA"]) for i in range(1,len(bounds))]
            mapped=map_piecewise(theta,bounds)
            rnode=reference["nodes"][(hist,step)]
            for i,t in enumerate(mapped,1):
                z["THETA"].append(t-float(rnode[i]["THETA"]))
    return series


def checkpoint(series:dict[str,dict[str,list]],cp:int)->dict[str,Any]:
    S=[];C=[];Q=[];T=[];U=[];L=[];signerr=0;finals=[];by={}
    for hist in HISTS:
        z=series[hist]
        S+=z["S"][:cp]
        C+=z["C"][:cp]
        Q+=z["Q"][:cp]
        T+=z["THETA"][:cp*16]
        U+=z["UPPER"][:cp]
        L+=z["LOWER"][:cp]
        signerr+=sum(z["SIGNERR"][:cp])
        finals.append(z["C"][cp-1])
        by[hist]={
            "storage_rmse_cm":qstats(z["S"][:cp])["rmse"],
            "cumulative_bottom_rmse_cm":qstats(z["C"][:cp])["rmse"],
            "bottom_flux_rmse_cm_per_day":qstats(z["Q"][:cp])["rmse"],
            "bottom_flux_sign_errors":sum(z["SIGNERR"][:cp]),
            "abs_mean_signed_bottom_flux_error_cm_per_day":abs(qstats(z["Q"][:cp])["mean"]),
            "abs_final_cumulative_bottom_error_cm":abs(z["C"][cp-1]),
            "mapped_theta_rmse":qstats(z["THETA"][:cp*16])["rmse"],
            "upper_storage_rmse_cm":qstats(z["UPPER"][:cp])["rmse"],
            "lower_storage_rmse_cm":qstats(z["LOWER"][:cp])["rmse"],
            "reference_reversal_steps":reversal_steps(z["REF_SIGN"][:cp]),
            "candidate_reversal_steps":reversal_steps(z["CAND_SIGN"][:cp]),
        }
        by[hist]["reversal_step_sequence_mismatch"]=(
            by[hist]["reference_reversal_steps"]!=by[hist]["candidate_reversal_steps"]
        )
    return {
        "storage_rmse_cm":qstats(S)["rmse"],
        "cumulative_bottom_rmse_cm":qstats(C)["rmse"],
        "bottom_flux_rmse_cm_per_day":qstats(Q)["rmse"],
        "bottom_flux_sign_errors":int(signerr),
        "abs_mean_signed_bottom_flux_error_cm_per_day":abs(qstats(Q)["mean"]),
        "max_abs_final_cumulative_bottom_error_cm":max(abs(x) for x in finals),
        "mapped_theta_rmse":qstats(T)["rmse"],
        "upper_storage_rmse_cm":qstats(U)["rmse"],
        "lower_storage_rmse_cm":qstats(L)["rmse"],
        "by_history":by,
    }


def relation_value(lare:float|int,cor:float|int,key:str)->str:
    if key=="bottom_flux_sign_errors":
        if int(cor)<int(lare): return "COR_STRICTLY_BETTER"
        if int(cor)>int(lare): return "LARE_STRICTLY_BETTER"
        return "NUMERICALLY_EQUAL"
    a=float(lare);b=float(cor)
    if b<a-TOL: return "COR_STRICTLY_BETTER"
    if a<b-TOL: return "LARE_STRICTLY_BETTER"
    return "NUMERICALLY_EQUAL"


def vector_relation(lare:dict[str,Any],cor:dict[str,Any],keys:tuple[str,...])->str:
    rel=[relation_value(lare[k],cor[k],k) for k in keys]
    cor_no=all(x in ("COR_STRICTLY_BETTER","NUMERICALLY_EQUAL") for x in rel)
    lare_no=all(x in ("LARE_STRICTLY_BETTER","NUMERICALLY_EQUAL") for x in rel)
    if cor_no and any(x=="COR_STRICTLY_BETTER" for x in rel):
        return "COR_COMPONENTWISE_NO_WORSE"
    if lare_no and any(x=="LARE_STRICTLY_BETTER" for x in rel):
        return "LARE_COMPONENTWISE_NO_WORSE"
    if all(x=="NUMERICALLY_EQUAL" for x in rel):
        return "NUMERICALLY_EQUIVALENT"
    return "TRADEOFF"


def comparison(lare:dict[str,Any],cor:dict[str,Any])->dict[str,Any]:
    component={}
    gaps={}
    for key in ALL:
        component[key]=relation_value(lare[key],cor[key],key)
        if key!="bottom_flux_sign_errors":
            gaps[key]=float(lare[key])-float(cor[key])
        else:
            gaps[key]=int(lare[key])-int(cor[key])
    return {
        "component_relation":component,
        "descriptive_lare_minus_cor_gap":gaps,
        "GW6_vector_relation":vector_relation(lare,cor,GW),
        "vertical_state_vector_relation":vector_relation(lare,cor,VERTICAL),
    }


def monotonic(values:list[float|int],key:str)->bool:
    if key=="bottom_flux_sign_errors":
        return all(int(b)<=int(a) for a,b in zip(values,values[1:]))
    return all(float(b)<=float(a)+TOL for a,b in zip(values,values[1:]))


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--material",required=True)
    ap.add_argument("--b1h-dir",required=True,type=pathlib.Path)
    ap.add_argument("--b1hcq-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    if pre["phase"]!="PREREGISTERED_BEFORE_FIRST_SAME_PARTITION_HYDROLOGICAL_ERROR_EXPOSURE":
        raise SystemExit("wrong B1HC-D preregistration phase")
    if a.material not in MATERIALS:
        raise SystemExit("material outside frozen B1HC-D cohort")

    b1h=json.loads((a.b1h_dir/f"LAYER_ROM_B1H_{a.material}_RESULT.json").read_text())
    if b1h["decision"]!="B1H_MATERIAL_TRANSFER_CHARACTERIZED":
        raise SystemExit("B1H material authority mismatch")
    reference=parse_log(a.b1h_dir/f"R16_{a.material}.txt")
    expected_ref={(h,s) for h in HISTS for s in range(1,1025)}
    if set(reference["states"])!=expected_ref or len(reference["nodes"])!=len(expected_ref):
        raise SystemExit("R16 Reference structure drift")

    member_specs={x["id"]:x for x in pre["cohort"]["members"]}
    cor={}
    comparisons={}
    for member in MEMBERS:
        qresult=json.loads((a.b1hcq_dir/member/f"LAYER_ROM_B1HCQ_{a.material}_{member}_RESULT.json").read_text())
        if qresult["qualified_history_count"]!=4 or qresult["technical_failure_histories"] or qresult["fail_closed_histories"]:
            raise SystemExit(f"{member}: comparator qualification drift")
        bounds=[float(x) for x in member_specs[member]["boundaries_cm"]]
        series=series_for_member(reference,a.b1hcq_dir,member,bounds)
        cor[member]={str(cp):checkpoint(series,cp) for cp in CHECKPOINTS}
        comparisons[member]={}
        for cp in CHECKPOINTS:
            lare=b1h["summaries"][member][str(cp)]
            comparisons[member][str(cp)]=comparison(lare,cor[member][str(cp)])

    dimension_order={"LARE":{},"CoRichards":{}}
    for route in ("LARE","CoRichards"):
        for cp in CHECKPOINTS:
            rows={}
            for key in ALL:
                vals=[]
                for member in MEMBERS:
                    source=(b1h["summaries"][member][str(cp)] if route=="LARE" else cor[member][str(cp)])
                    vals.append(source[key])
                rows[key]={"L4_L6_R8":vals,"nonincreasing":monotonic(vals,key)}
            dimension_order[route][str(cp)]=rows

    result={
        "schema":"swap5.layer-rom.phase-b1hc-d.material-result.v1",
        "workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-B1HC-D",
        "material":a.material,
        "decision":"B1HCD_MATERIAL_DECOMPOSED",
        "checkpoints_steps":list(CHECKPOINTS),
        "primary_checkpoint_step":1024,
        "LARE":{m:b1h["summaries"][m] for m in MEMBERS},
        "CoRichards":cor,
        "same_partition_comparison":comparisons,
        "dimension_order":dimension_order,
        "integrity":{
            "reference_state_count":len(reference["states"]),
            "reference_node_step_count":len(reference["nodes"]),
            "all_three_comparators_qualified":True,
            "all_frozen_LARE_summaries_present":all(m in b1h["summaries"] for m in MEMBERS),
            "pass":True
        },
        "interpretation_firewalls":[
            "The descriptive Layer-ROM minus CoRichards metric gap is not an additive closure-error estimate.",
            "No new Reference or Layer-ROM trajectory is generated.",
            "No partition, closure, threshold, material or history is selected from the comparator response.",
            "No application acceptance or runtime comparison is made."
        ],
        "performance_measurement_performed":False,
        "application_acceptance_adjudicated":False,
        "production_rom_authorized":False
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "material":a.material,
        "day1_GW6_relation":{m:comparisons[m]["1024"]["GW6_vector_relation"] for m in MEMBERS},
        "day1_LARE":{m:{k:b1h["summaries"][m]["1024"][k] for k in GW} for m in MEMBERS},
        "day1_CoRichards":{m:{k:cor[m]["1024"][k] for k in GW} for m in MEMBERS},
        "day1_dimension_monotone":{
            r:{k:v["nonincreasing"] for k,v in dimension_order[r]["1024"].items()}
            for r in ("LARE","CoRichards")
        }
    },sort_keys=True))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
