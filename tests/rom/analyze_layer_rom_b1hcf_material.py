#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import pathlib
import sys
from collections import defaultdict
from typing import Any

import numpy as np

MATERIALS=("B02","B05","B06","B11","B12","B16")
HISTS=("X01","X02","X03","X04")
CHECKPOINTS=(64,128,256,512,1024)
OBS_DT=0.001
TOL=1.0e-12
GW=(
    "storage_rmse_cm",
    "cumulative_bottom_rmse_cm",
    "qavg_rmse_cm_per_day",
    "qavg_sign_errors",
    "abs_mean_signed_qavg_error_cm_per_day",
    "qend_rmse_cm_per_day",
    "qend_sign_errors",
    "abs_mean_signed_qend_error_cm_per_day",
    "max_abs_final_cumulative_bottom_error_cm",
)
PROFILE=("upper_storage_rmse_cm","lower_storage_rmse_cm","mapped_theta_rmse")
UNCHANGED=("storage_rmse_cm","cumulative_bottom_rmse_cm","max_abs_final_cumulative_bottom_error_cm",
           "mapped_theta_rmse","upper_storage_rmse_cm","lower_storage_rmse_cm")


def load(name:str,path:pathlib.Path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    mod=importlib.util.module_from_spec(spec)
    sys.modules[name]=mod
    spec.loader.exec_module(mod)
    return mod


def patch_material(c4v,mat,lambdas):
    c4v.TR=float(mat["theta_r"]);c4v.TS=float(mat["theta_s"])
    c4v.ALPHA=float(mat["alpha_per_cm"]);c4v.N=float(mat["n"])
    c4v.M=1.0-1.0/c4v.N;c4v.KS=float(mat["Ksat_cm_per_day"]);c4v.ELL=float(mat["lambda"])
    c4v.DTHETA=(c4v.TS-c4v.TR)/c4v.NBINS
    c4v.THETA_I=c4v.TR+c4v.I*c4v.DTHETA
    c4v.HISTS={f"X{i:02d}":float(v) for i,v in enumerate(lambdas,1)}
    c4v.THETA=[c4v.TR+j*c4v.DTHETA for j in range(c4v.J0,c4v.J1+1)]
    c4v.PSI=[c4v.psi_scalar(t) for t in c4v.THETA]
    b=c4v.bc1
    b.THETA_R=c4v.TR;b.THETA_S=c4v.TS;b.ALPHA=c4v.ALPHA;b.N_VG=c4v.N
    b.M_VG=c4v.M;b.KS=c4v.KS;b.LAMBDA=c4v.ELL


def fields(payload:str)->dict[str,str]:
    out={}
    for p in payload.split("|"):
        if "=" in p:
            k,v=p.split("=",1);out[k]=v
    return out


def parse_single_history(path:pathlib.Path):
    states={};nodes=defaultdict(dict);geom=None;initial={}
    for line in path.read_text(errors="replace").splitlines():
        if "F_ROMV2_D13_REF_GEOMETRY|" in line:
            geom=fields(line.split("F_ROMV2_D13_REF_GEOMETRY|",1)[1])
        elif "F_ROMV2_D13_REF_INITIAL|" in line:
            r=fields(line.split("F_ROMV2_D13_REF_INITIAL|",1)[1]);initial[r["HISTORY"].strip()]=r
        elif "F_ROMV2_D13_REF_STATE|" in line:
            r=fields(line.split("F_ROMV2_D13_REF_STATE|",1)[1]);states[(r["HISTORY"].strip(),int(r["STEP"]))]=r
        elif "F_ROMV2_D13_REF_NODE|" in line:
            r=fields(line.split("F_ROMV2_D13_REF_NODE|",1)[1]);nodes[(r["HISTORY"].strip(),int(r["STEP"]))][int(r["NODE"])]=r
    if geom is None or len(initial)!=1 or len(states)!=1024 or len(nodes)!=1024:
        raise RuntimeError(f"filtered comparator structure mismatch {path}")
    n=int(geom["N"])
    hist=next(iter(initial))
    if set(states)!={(hist,s) for s in range(1,1025)}:
        raise RuntimeError("filtered comparator state identity mismatch")
    if any(set(nodes[(hist,s)])!=set(range(1,n+1)) for s in range(1,1025)):
        raise RuntimeError("filtered comparator node identity mismatch")
    return {"n":n,"hist":hist,"states":states,"nodes":dict(nodes),"initial":initial}


def qstats(values):
    a=np.asarray(values,dtype=float)
    return {
        "count":int(a.size),
        "mean":float(np.mean(a)),
        "mean_abs":float(np.mean(np.abs(a))),
        "rmse":float(np.sqrt(np.mean(a*a))),
        "max_abs":float(np.max(np.abs(a))),
    }


def sign(x:float)->int:
    return 1 if x>0 else (-1 if x<0 else 0)


def map_piecewise(theta,bounds):
    out=[]
    for node in range(16):
        lo=node*10.0;hi=(node+1)*10.0;v=0.0
        for t,a,b in zip(theta,bounds,bounds[1:]):
            w=max(0.0,min(hi,b)-max(lo,a))
            if w>0:v+=float(t)*w
        out.append(v/10.0)
    return out


def terminal_ref_q(c4v,r16,hist,step):
    theta=float(r16["nodes"][(hist,step,16)]["THETA"])
    return float(c4v.qbottom_zero_head(np.asarray([theta]),np.asarray([10.0])))


def empty_series():
    return {h:{k:[] for k in ("S","C","QAVG","QEND","theta","upper","lower","qavg_sign","qend_sign")} for h in HISTS}


def append(series,hist,total,cum,qavg,qend,mapped,upper,lower,r16,c4v,step,refcum):
    rr=r16["states"][(hist,step)]
    ref_total=float(rr["TOTAL_STORAGE"])
    ref_qavg=float(rr["BOTTOM_OUTWARD_EXCHANGE"])/OBS_DT
    persisted=float(rr["BOTTOM_FLUX"])
    if abs(ref_qavg-persisted)>1e-10:
        raise RuntimeError(f"Reference QAVG identity failed {hist} {step}: {ref_qavg} {persisted}")
    ref_qend=terminal_ref_q(c4v,r16,hist,step)
    z=series[hist]
    z["S"].append(total-ref_total);z["C"].append(cum-refcum[step-1])
    z["QAVG"].append(qavg-ref_qavg);z["QEND"].append(qend-ref_qend)
    z["qavg_sign"].append(int(sign(ref_qavg)!=0 and sign(qavg)!=sign(ref_qavg)))
    z["qend_sign"].append(int(sign(ref_qend)!=0 and sign(qend)!=sign(ref_qend)))
    for node,t in enumerate(mapped,1):
        z["theta"].append(float(t)-float(r16["nodes"][(hist,step,node)]["THETA"]))
    ru=sum(float(r16["nodes"][(hist,step,node)]["THETA"])*10.0 for node in range(1,9))
    rl=sum(float(r16["nodes"][(hist,step,node)]["THETA"])*10.0 for node in range(9,17))
    z["upper"].append(upper-ru);z["lower"].append(lower-rl)


def checkpoint(series,cp):
    S=[];C=[];QA=[];QE=[];T=[];U=[];L=[];sa=0;se=0;finals=[]
    for h in HISTS:
        z=series[h]
        S+=z["S"][:cp];C+=z["C"][:cp];QA+=z["QAVG"][:cp];QE+=z["QEND"][:cp]
        T+=z["theta"][:cp*16];U+=z["upper"][:cp];L+=z["lower"][:cp]
        sa+=sum(z["qavg_sign"][:cp]);se+=sum(z["qend_sign"][:cp]);finals.append(z["C"][cp-1])
    return {
        "storage_rmse_cm":qstats(S)["rmse"],
        "cumulative_bottom_rmse_cm":qstats(C)["rmse"],
        "qavg_rmse_cm_per_day":qstats(QA)["rmse"],
        "qavg_sign_errors":int(sa),
        "abs_mean_signed_qavg_error_cm_per_day":abs(qstats(QA)["mean"]),
        "qend_rmse_cm_per_day":qstats(QE)["rmse"],
        "qend_sign_errors":int(se),
        "abs_mean_signed_qend_error_cm_per_day":abs(qstats(QE)["mean"]),
        "max_abs_final_cumulative_bottom_error_cm":max(abs(x) for x in finals),
        "mapped_theta_rmse":qstats(T)["rmse"],
        "upper_storage_rmse_cm":qstats(U)["rmse"],
        "lower_storage_rmse_cm":qstats(L)["rmse"],
    }


def run_lare_corrected(c4v,member,r16):
    bounds=[float(x) for x in member["boundaries_cm"]];dim=int(member["dimension"])
    dz0=np.diff(np.asarray(bounds,dtype=float))
    series=empty_series();maxledger=0.0;maxiter=0
    for hist,lam in c4v.HISTS.items():
        dz,y=c4v.initial_state(lam,bounds)
        initial=float(np.sum(y[:dim]));prev_cum=0.0
        if abs(initial-float(r16["initial"][hist]["TOTAL_STORAGE"]))>1e-12:
            raise RuntimeError("initial storage identity mismatch")
        refcum=c4v.ref_arrays(r16,hist)
        for step in range(1,1025):
            for _ in range(c4v.SUBSTEPS):
                y,it=c4v.heun_step(y,c4v.DT,dz);maxiter=max(maxiter,it)
            theta=y[:dim]/dz;c4v.bc1.psi_k(theta)
            total=float(np.sum(y[:dim]));cum=float(y[dim+1])
            qavg=(cum-prev_cum)/OBS_DT;prev_cum=cum
            qend=float(c4v.qbottom_zero_head(theta,dz))
            ledger=total-initial+cum;maxledger=max(maxledger,abs(ledger))
            if abs(ledger)>c4v.LEDGER_GATE:raise RuntimeError(f"water ledger {ledger}")
            mapped=c4v.map_piecewise_to_10cm(theta,bounds)
            upper=c4v.integrated_storage(theta,bounds,0.0,80.0);lower=c4v.integrated_storage(theta,bounds,80.0,160.0)
            append(series,hist,total,cum,qavg,qend,mapped,upper,lower,r16,c4v,step,refcum)
    return {
      "id":member["id"],"dimension":dim,"series":series,
      "summaries":{str(cp):checkpoint(series,cp) for cp in CHECKPOINTS},
      "max_abs_water_ledger_cm":maxledger,"max_corrector_iterations":maxiter,
      "dz_cm":list(map(float,dz0))
    }


def run_cor_corrected(c4v,member,bounds,qdir,r16):
    series=empty_series()
    for hist in HISTS:
        p=qdir/member/f"{member}-{hist}-o0.txt"
        cor=parse_single_history(p)
        if cor["hist"]!=hist:raise RuntimeError(f"{member} history mismatch {hist}")
        if cor["n"]!=len(bounds)-1:raise RuntimeError(f"{member} geometry mismatch")
        cum=0.0;refcum=c4v.ref_arrays(r16,hist)
        for step in range(1,1025):
            rr=cor["states"][(hist,step)]
            ex=float(rr["BOTTOM_OUTWARD_EXCHANGE"]);cum+=ex
            qavg=ex/OBS_DT
            if abs(qavg-float(rr["BOTTOM_FLUX"]))>1e-10:
                raise RuntimeError(f"{member} CoRichards QAVG identity failed {hist} {step}")
            theta=[float(cor["nodes"][(hist,step)][i]["THETA"]) for i in range(1,cor["n"]+1)]
            qend=float(c4v.qbottom_zero_head(np.asarray([theta[-1]]),np.asarray([bounds[-1]-bounds[-2]])))
            mapped=map_piecewise(theta,bounds)
            total=float(rr["TOTAL_STORAGE"]);upper=float(rr["UPPER_STORAGE"]);lower=float(rr["LOWER_STORAGE"])
            append(series,hist,total,cum,qavg,qend,mapped,upper,lower,r16,c4v,step,refcum)
    return {str(cp):checkpoint(series,cp) for cp in CHECKPOINTS}


def relation(a,b,key):
    if key.endswith("_sign_errors"):
        if int(a)<int(b):return "A_STRICTLY_BETTER"
        if int(a)>int(b):return "B_STRICTLY_BETTER"
        return "NUMERICALLY_EQUAL"
    x=float(a);y=float(b)
    if x<y-TOL:return "A_STRICTLY_BETTER"
    if y<x-TOL:return "B_STRICTLY_BETTER"
    return "NUMERICALLY_EQUAL"


def vector_relation(a,b,keys):
    rel={k:relation(a[k],b[k],k) for k in keys}
    ano=all(v in ("A_STRICTLY_BETTER","NUMERICALLY_EQUAL") for v in rel.values())
    bno=all(v in ("B_STRICTLY_BETTER","NUMERICALLY_EQUAL") for v in rel.values())
    if ano and any(v=="A_STRICTLY_BETTER" for v in rel.values()):label="A_COMPONENTWISE_NO_WORSE"
    elif bno and any(v=="B_STRICTLY_BETTER" for v in rel.values()):label="B_COMPONENTWISE_NO_WORSE"
    elif all(v=="NUMERICALLY_EQUAL" for v in rel.values()):label="NUMERICALLY_EQUIVALENT"
    else:label="TRADEOFF"
    return {"vector_relation":label,"component_relation":rel}


def monotone(vals,key):
    if key.endswith("_sign_errors"):
        return all(int(b)<=int(a) for a,b in zip(vals,vals[1:]))
    return all(float(b)<=float(a)+TOL for a,b in zip(vals,vals[1:]))


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--material",required=True)
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--b1h-result",required=True,type=pathlib.Path)
    ap.add_argument("--b1h-prereg",required=True,type=pathlib.Path)
    ap.add_argument("--b1hcq-dir",required=True,type=pathlib.Path)
    ap.add_argument("--basis-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    p=json.loads(a.prereg.read_text())
    if p["phase"]!="PREREGISTERED_BEFORE_CORRECTED_FIXED_HEAD_FLUX_METRICS":
        raise SystemExit("wrong B1HCF preregistration")
    b1h=json.loads(a.b1h_result.read_text());bp=json.loads(a.b1h_prereg.read_text())
    if a.material not in MATERIALS or b1h["material"]!=a.material:
        raise SystemExit("material identity mismatch")

    c4v=load("layer_rom_b1hcf_c4v",a.basis_dir/"analyze_lare_bc2_c4v_one_day.py")
    patch_material(c4v,b1h["material_parameters"],b1h["scaled_lambdas"])
    r16=c4v.parse_ref(a.reference)
    reps={x["id"]:x for x in bp["representations"]}
    routes={rid:run_lare_corrected(c4v,reps[rid],r16) for rid in ("L4","L6","R8","U4","U8","R16_OP")}

    # Hard reproducibility control on components unaffected by flux semantics.
    max_repro=0.0
    for rid,route in routes.items():
        old=b1h["summaries"][rid]
        for cp in CHECKPOINTS:
            for key in UNCHANGED:
                max_repro=max(max_repro,abs(float(route["summaries"][str(cp)][key])-float(old[str(cp)][key])))
    if max_repro>float(p["hard_controls"]["rerun_LayerROM_storage_cumulative_profile_vs_persisted_B1H_max_abs"]):
        raise SystemExit(f"Layer-ROM reproduction drift {max_repro}")

    cor={}
    for rid in ("L4","L6","R8"):
        bounds=[float(x) for x in reps[rid]["boundaries_cm"]]
        cor[rid]=run_cor_corrected(c4v,rid,bounds,a.b1hcq_dir,r16)

    placement={
      "dimension4":{
        "GW":vector_relation(routes["L4"]["summaries"]["1024"],routes["U4"]["summaries"]["1024"],GW),
        "PROFILE":vector_relation(routes["L4"]["summaries"]["1024"],routes["U4"]["summaries"]["1024"],PROFILE)
      },
      "dimension8":{
        "GW":vector_relation(routes["R8"]["summaries"]["1024"],routes["U8"]["summaries"]["1024"],GW),
        "PROFILE":vector_relation(routes["R8"]["summaries"]["1024"],routes["U8"]["summaries"]["1024"],PROFILE)
      }
    }
    same_partition={}
    for rid in ("L4","L6","R8"):
        same_partition[rid]={
          "GW":vector_relation(routes[rid]["summaries"]["1024"],cor[rid]["1024"],GW),
          "PROFILE":vector_relation(routes[rid]["summaries"]["1024"],cor[rid]["1024"],PROFILE)
        }

    dimorder={"LayerROM":{},"CoRichards":{}}
    for route_name,source in (("LayerROM",{r:routes[r]["summaries"] for r in ("L4","L6","R8")}),("CoRichards",cor)):
        for key in GW+PROFILE:
            vals=[source[r]["1024"][key] for r in ("L4","L6","R8")]
            dimorder[route_name][key]={"L4_L6_R8":vals,"nonincreasing":monotone(vals,key)}

    impact={}
    for rid in ("L4","L6","R8","U4","U8","R16_OP"):
        impact[rid]={
          "superseded_bottom_flux_rmse_cm_per_day":float(b1h["summaries"][rid]["1024"]["bottom_flux_rmse_cm_per_day"]),
          "corrected_qavg_rmse_cm_per_day":routes[rid]["summaries"]["1024"]["qavg_rmse_cm_per_day"],
          "corrected_qend_rmse_cm_per_day":routes[rid]["summaries"]["1024"]["qend_rmse_cm_per_day"],
          "superseded_bottom_flux_sign_errors":int(b1h["summaries"][rid]["1024"]["bottom_flux_sign_errors"]),
          "corrected_qavg_sign_errors":routes[rid]["summaries"]["1024"]["qavg_sign_errors"],
          "corrected_qend_sign_errors":routes[rid]["summaries"]["1024"]["qend_sign_errors"],
        }

    result={
      "schema":"swap5.layer-rom.phase-b1hcf.material-result.v1",
      "workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-B1HCF",
      "material":a.material,"decision":"B1HCF_MATERIAL_RECONCILED",
      "integrity":{
        "pass":True,
        "max_unaffected_B1H_reproduction_abs":max_repro,
        "max_R16_OP_water_ledger_cm":routes["R16_OP"]["max_abs_water_ledger_cm"]
      },
      "LayerROM":{rid:routes[rid]["summaries"] for rid in routes},
      "CoRichards":cor,
      "corrected_placement":placement,
      "corrected_same_partition":same_partition,
      "day1_dimension_order":dimorder,
      "old_to_corrected_flux_metric_impact":impact,
      "R16_OP_day1":routes["R16_OP"]["summaries"]["1024"],
      "interpretation_firewalls":[
        "QAVG compares interval-average exchange rates on both sides.",
        "QEND compares end-state Darcy diagnostics on both sides.",
        "The old mixed-semantics bottom_flux metric is reported only as superseded provenance.",
        "No weighted score, application threshold, runtime claim or production decision is made."
      ],
      "application_acceptance_adjudicated":False,
      "production_rom_authorized":False
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "material":a.material,
      "placement":placement,
      "same_partition":same_partition,
      "R16_OP":result["R16_OP_day1"],
      "impact":impact,
      "dimension_order":dimorder
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
