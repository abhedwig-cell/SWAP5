#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import pathlib
import sys
from collections import defaultdict

import numpy as np

HERE=pathlib.Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location("b1",HERE/"analyze_layer_rom_b1_fixed_head_ladder.py")
b1=importlib.util.module_from_spec(spec)
sys.modules["b1"]=b1
spec.loader.exec_module(b1)

GW=(
 "storage_rmse_cm","cumulative_bottom_rmse_cm",
 "qavg_rmse_cm_per_day","qavg_sign_errors","abs_mean_signed_qavg_error_cm_per_day",
 "qend_rmse_cm_per_day","qend_sign_errors","abs_mean_signed_qend_error_cm_per_day",
 "max_abs_final_cumulative_bottom_error_cm"
)
PROFILE=("upper_storage_rmse_cm","lower_storage_rmse_cm","mapped_theta_rmse")
ORDER=("L2","L3","L4","L6")


def stats(v):
    a=np.asarray(v,dtype=float)
    return {"rmse":float(np.sqrt(np.mean(a*a))),"mean":float(np.mean(a)),"max_abs":float(np.max(np.abs(a)))}


def sign(x):
    return 1 if x>0 else (-1 if x<0 else 0)


def ref_qend(r16,hist,step):
    theta=float(r16["nodes"][(hist,step,16)]["THETA"])
    return float(b1.qbottom_zero_head(np.asarray([theta]),np.asarray([10.0])))


def summarize(rows):
    S=[];C=[];QA=[];QE=[];T=[];U=[];L=[];sa=0;se=0;finals=[]
    for h,z in rows.items():
        S+=z["S"];C+=z["C"];QA+=z["QA"];QE+=z["QE"];T+=z["T"];U+=z["U"];L+=z["L"]
        sa+=sum(z["sa"]);se+=sum(z["se"]);finals.append(z["C"][-1])
    return {
      "storage_rmse_cm":stats(S)["rmse"],
      "cumulative_bottom_rmse_cm":stats(C)["rmse"],
      "qavg_rmse_cm_per_day":stats(QA)["rmse"],
      "qavg_sign_errors":int(sa),
      "abs_mean_signed_qavg_error_cm_per_day":abs(stats(QA)["mean"]),
      "qend_rmse_cm_per_day":stats(QE)["rmse"],
      "qend_sign_errors":int(se),
      "abs_mean_signed_qend_error_cm_per_day":abs(stats(QE)["mean"]),
      "max_abs_final_cumulative_bottom_error_cm":max(abs(x) for x in finals),
      "mapped_theta_rmse":stats(T)["rmse"],
      "upper_storage_rmse_cm":stats(U)["rmse"],
      "lower_storage_rmse_cm":stats(L)["rmse"]
    }


def blank():
    return {h:{k:[] for k in ("S","C","QA","QE","T","U","L","sa","se")} for h in b1.HISTS}


def append(z,total,cum,qavg,qend,mapped,upper,lower,r16,hist,step,refcum):
    rr=r16["states"][(hist,step)]
    rqavg=float(rr["BOTTOM_OUTWARD_EXCHANGE"])/b1.OBS_DT
    persisted=float(rr["BOTTOM_FLUX"])
    if abs(rqavg-persisted)>1e-10:raise RuntimeError("Reference QAVG identity failure")
    rqend=ref_qend(r16,hist,step)
    z["S"].append(total-float(rr["TOTAL_STORAGE"]))
    z["C"].append(cum-refcum)
    z["QA"].append(qavg-rqavg);z["QE"].append(qend-rqend)
    z["sa"].append(int(sign(rqavg)!=0 and sign(qavg)!=sign(rqavg)))
    z["se"].append(int(sign(rqend)!=0 and sign(qend)!=sign(rqend)))
    for node,t in enumerate(mapped,1):
        z["T"].append(float(t)-float(r16["nodes"][(hist,step,node)]["THETA"]))
    ru=sum(float(r16["nodes"][(hist,step,node)]["THETA"])*10.0 for node in range(1,9))
    rl=sum(float(r16["nodes"][(hist,step,node)]["THETA"])*10.0 for node in range(9,17))
    z["U"].append(upper-ru);z["L"].append(lower-rl)


def run_lare(bounds,r16):
    rows=blank();maxledger=0.0;maxiter=0
    dim=len(bounds)-1
    for hist,lam in b1.HISTS.items():
        dz,y,initial=b1.initial(lam,bounds,r16["initial"][hist])
        prev=0.0;refcum=0.0
        for step in range(1,b1.NSTEPS+1):
            for _ in range(b1.SUBSTEPS):
                y,it=b1.heun_step(y,dz);maxiter=max(maxiter,it)
            theta=y[:dim]/dz;b1.psi_k(theta)
            total=float(np.sum(y[:dim]));cum=float(y[dim+1])
            qavg=(cum-prev)/b1.OBS_DT;prev=cum
            qend=float(b1.qbottom_zero_head(theta,dz))
            ledger=total-initial+cum;maxledger=max(maxledger,abs(ledger))
            if abs(ledger)>b1.LEDGER_GATE:raise RuntimeError(f"ledger {ledger}")
            refcum+=float(r16["states"][(hist,step)]["BOTTOM_OUTWARD_EXCHANGE"])
            mapped=b1.map_piecewise_to_10cm(theta,bounds)
            upper=b1.integrated_storage(theta,bounds,0,80);lower=b1.integrated_storage(theta,bounds,80,160)
            append(rows[hist],total,cum,qavg,qend,mapped,upper,lower,r16,hist,step,refcum)
    return summarize(rows),maxledger,maxiter


def run_r2(r2,r16):
    rows=blank()
    for hist in b1.HISTS:
        cum=0.0;refcum=0.0
        for step in range(1,b1.NSTEPS+1):
            rr=r2["states"][(hist,step)]
            ex=float(rr["BOTTOM_OUTWARD_EXCHANGE"]);cum+=ex
            qavg=ex/b1.OBS_DT
            if abs(qavg-float(rr["BOTTOM_FLUX"]))>1e-10:raise RuntimeError("R2 QAVG identity failure")
            t1=float(r2["nodes"][(hist,step,1)]["THETA"]);t2=float(r2["nodes"][(hist,step,2)]["THETA"])
            qend=float(b1.qbottom_zero_head(np.asarray([t2]),np.asarray([80.0])))
            refcum+=float(r16["states"][(hist,step)]["BOTTOM_OUTWARD_EXCHANGE"])
            mapped=[t1]*8+[t2]*8
            append(rows[hist],float(rr["TOTAL_STORAGE"]),cum,qavg,qend,mapped,t1*80,t2*80,r16,hist,step,refcum)
    return summarize(rows)


def relation(a,b,key,tol):
    if key.endswith("_sign_errors"):
        if int(a)<int(b):return "A_STRICTLY_BETTER"
        if int(a)>int(b):return "B_STRICTLY_BETTER"
        return "NUMERICALLY_EQUAL"
    if float(a)<float(b)-tol:return "A_STRICTLY_BETTER"
    if float(b)<float(a)-tol:return "B_STRICTLY_BETTER"
    return "NUMERICALLY_EQUAL"


def vector_relation(a,b,keys,tol):
    rel={k:relation(a[k],b[k],k,tol) for k in keys}
    ano=all(v in ("A_STRICTLY_BETTER","NUMERICALLY_EQUAL") for v in rel.values())
    bno=all(v in ("B_STRICTLY_BETTER","NUMERICALLY_EQUAL") for v in rel.values())
    if ano and any(v=="A_STRICTLY_BETTER" for v in rel.values()):label="A_COMPONENTWISE_NO_WORSE"
    elif bno and any(v=="B_STRICTLY_BETTER" for v in rel.values()):label="B_COMPONENTWISE_NO_WORSE"
    elif all(v=="NUMERICALLY_EQUAL" for v in rel.values()):label="NUMERICALLY_EQUIVALENT"
    else:label="TRADEOFF"
    return {"vector_relation":label,"component_relation":rel}


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--r16",required=True,type=pathlib.Path)
    ap.add_argument("--r2",required=True,type=pathlib.Path)
    ap.add_argument("--old-b1",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    pre=json.loads(a.prereg.read_text())
    if pre["phase"]!="PREREGISTERED_BEFORE_B01_FIXED_HEAD_FRONTIER_REPAIR":raise SystemExit("wrong B1R phase")
    r16=b1.parse_d13(a.r16);r2=b1.parse_d13(a.r2);old=json.loads(a.old_b1.read_text())
    tol=float(pre["comparator_rule"]["relation_tolerance"])
    r2m=run_r2(r2,r16)
    candidates={};maxledger=0.0;maxiter=0;max_repro=0.0
    for spec in pre["scope"]["candidates"]:
        rid=spec["id"];bounds=[float(x) for x in spec["boundaries_cm"]]
        sm,led,it=run_lare(bounds,r16);maxledger=max(maxledger,led);maxiter=max(maxiter,it)
        candidates[rid]=sm
        oldrow=old["members"][rid]
        for newkey,oldkey in (
          ("storage_rmse_cm","total_storage_rmse_cm"),
          ("cumulative_bottom_rmse_cm","cumulative_bottom_exchange_rmse_cm"),
          ("mapped_theta_rmse","mapped_R16_theta_rmse")
        ):
            max_repro=max(max_repro,abs(float(sm[newkey])-float(oldrow[oldkey])))
    if max_repro>1e-11:raise SystemExit(f"retained B1 reproduction drift {max_repro}")

    relations={rid:{
      "GW":vector_relation(sm,r2m,GW,tol),
      "PROFILE":vector_relation(sm,r2m,PROFILE,tol)
    } for rid,sm in candidates.items()}
    crossing=[rid for rid in ORDER if relations[rid]["GW"]["vector_relation"]=="A_COMPONENTWISE_NO_WORSE"]
    mindim=min((len(next(x for x in pre["scope"]["candidates"] if x["id"]==rid)["boundaries_cm"])-1 for rid in crossing),default=None)

    fmc=json.loads((pathlib.Path("/dev/null")).read_text()) if False else None
    result={
      "schema":"swap5.layer-rom.phase-b1r.result.v1",
      "workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-B1R",
      "decision":"B1R_CORRECTED_R2_FRONTIER_REBUILT",
      "integrity":{"pass":True,"max_retained_B1_reproduction_abs":max_repro,"max_water_ledger_cm":maxledger,"max_corrector_iterations":maxiter},
      "R2_corrected":r2m,
      "LayerROM_corrected":candidates,
      "relations_to_R2":relations,
      "corrected_R2_GW_frontier":{"minimum_dimension":mindim,"crossing_members":crossing},
      "FMC":{
        "corrected_flux_frontier":"HELD",
        "retained_existing_components":["storage","cumulative bottom exchange","mapped profile"],
        "reason":pre["FMC_handling"]["reason"]
      },
      "supersession":{
        "old_B1_decision":"B1_DIMENSION4_GW_FRONTIER_REPLICATED",
        "old_R2_flux_components":"SUPERSEDED",
        "old_FMC_flux_frontier":"HELD",
        "B2_one_day_reversal_frontier":"HELD_PENDING_B2R"
      },
      "scientific_adjudication":[
        "The corrected R2 comparison uses interval-average QAVG against interval-average QAVG and terminal zero-head Darcy QEND against terminal zero-head Darcy QEND.",
        "Storage, cumulative exchange and mapped-profile reproduction is unchanged relative to B1.",
        "FMC flux is not imputed from aggregate old-semantics errors and therefore does not enter a corrected multi-component frontier.",
        "The result is comparator-relative development evidence, not application acceptance."
      ],
      "next":"Repair B2 one-day/reversal fixed-head authority with corrected QAVG/QEND after B1HCG temporal diagnosis is closed.",
      "application_acceptance_adjudicated":False,"performance_measurement_performed":False,"production_rom_authorized":False
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":result["decision"],"frontier":result["corrected_R2_GW_frontier"],"relations":relations,"R2":r2m,"LayerROM":candidates},sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
