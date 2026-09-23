#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import pathlib
import sys
from typing import Any

import numpy as np

DT_LADDER=(1.0e-4,5.0e-5,2.5e-5)
HISTS=("X01","X02","X03","X04")
STEPS=1024
OBS_DT=0.001
CORE=("storage_rms","cumulative_bottom_rms","qavg_rms","qend_rms","mapped_theta_rms")


def load(name:str,path:pathlib.Path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    mod=importlib.util.module_from_spec(spec)
    sys.modules[name]=mod
    spec.loader.exec_module(mod)
    return mod


def patch_material(c4v,mat:dict[str,Any],lambdas:list[float])->None:
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


def run_candidate(c4v,member:dict[str,Any],dt:float,ledger_gate:float)->dict[str,Any]:
    ratio=OBS_DT/dt
    substeps=int(round(ratio))
    if substeps<=0 or abs(substeps*dt-OBS_DT)>1e-15:
        raise RuntimeError(f"nonintegral dt ladder {dt}")
    bounds=[float(x) for x in member["boundaries_cm"]]
    dim=int(member["dimension"])
    series={}
    max_ledger=0.0
    max_iter=0
    initial_by_hist={}
    for hist in HISTS:
        if hist not in c4v.HISTS:
            raise RuntimeError(f"missing history {hist}")
        dz,y=c4v.initial_state(c4v.HISTS[hist],bounds)
        initial=float(np.sum(y[:dim]))
        initial_by_hist[hist]=initial
        prev_cum=0.0
        z={"S":[],"C":[],"QAVG":[],"QEND":[],"theta":[]}
        for _step in range(1,STEPS+1):
            for _ in range(substeps):
                y,it=c4v.heun_step(y,dt,dz)
                max_iter=max(max_iter,int(it))
            theta=y[:dim]/dz
            c4v.bc1.psi_k(theta)
            total=float(np.sum(y[:dim]))
            cum=float(y[dim+1])
            qavg=(cum-prev_cum)/OBS_DT
            prev_cum=cum
            qend=float(c4v.qbottom_zero_head(theta,dz))
            ledger=total-initial+cum
            max_ledger=max(max_ledger,abs(ledger))
            if abs(ledger)>ledger_gate:
                raise RuntimeError(f"water ledger gate {hist} dt={dt}: {ledger}")
            mapped=[float(x) for x in c4v.map_piecewise_to_10cm(theta,bounds)]
            if len(mapped)!=16 or not all(math.isfinite(x) for x in mapped):
                raise RuntimeError("mapped theta structure failure")
            z["S"].append(total)
            z["C"].append(cum)
            z["QAVG"].append(qavg)
            z["QEND"].append(qend)
            z["theta"].append(mapped)
        series[hist]=z
    return {
        "id":member["id"],
        "dimension":dim,
        "dt_day":dt,
        "substeps_per_observation":substeps,
        "series":series,
        "initial_storage_cm":initial_by_hist,
        "max_abs_water_ledger_cm":max_ledger,
        "max_corrector_iterations":max_iter,
    }


def stats(diff:np.ndarray)->dict[str,float|int]:
    a=np.asarray(diff,dtype=float).reshape(-1)
    if a.size==0 or not np.all(np.isfinite(a)):
        raise RuntimeError("invalid self-difference vector")
    return {
        "count":int(a.size),
        "rms":float(np.sqrt(np.mean(a*a))),
        "max_abs":float(np.max(np.abs(a))),
    }


def compare(a:dict[str,Any],b:dict[str,Any])->dict[str,Any]:
    buckets={"storage":[],"cumulative_bottom":[],"qavg":[],"qend":[],"mapped_theta":[]}
    max_initial=0.0
    for hist in HISTS:
        max_initial=max(max_initial,abs(float(a["initial_storage_cm"][hist])-float(b["initial_storage_cm"][hist])))
        za=a["series"][hist];zb=b["series"][hist]
        buckets["storage"].append(np.asarray(za["S"])-np.asarray(zb["S"]))
        buckets["cumulative_bottom"].append(np.asarray(za["C"])-np.asarray(zb["C"]))
        buckets["qavg"].append(np.asarray(za["QAVG"])-np.asarray(zb["QAVG"]))
        buckets["qend"].append(np.asarray(za["QEND"])-np.asarray(zb["QEND"]))
        buckets["mapped_theta"].append(np.asarray(za["theta"])-np.asarray(zb["theta"]))
    if max_initial>1e-14:
        raise RuntimeError(f"initial-state drift across dt: {max_initial}")
    out={}
    for key,parts in buckets.items():
        out[key]=stats(np.concatenate([np.asarray(x).reshape(-1) for x in parts]))
    out["max_abs_initial_storage_difference_cm"]=max_initial
    return out


def classify(coarse_mid:float,mid_fine:float,tol:float)->str:
    if coarse_mid<=tol and mid_fine<=tol:
        return "SATURATED"
    if mid_fine<coarse_mid:
        return "CONVERGING"
    return "FLAT_OR_NONCONVERGENT"


def apparent_order(coarse_mid:float,mid_fine:float)->float|None:
    if coarse_mid<=0.0 or mid_fine<=0.0:
        return None
    return float(math.log(coarse_mid/mid_fine,2.0))


def characterize(routes:dict[str,dict[str,Any]],tol:float)->dict[str,Any]:
    labels=[f"{dt:.8f}" for dt in DT_LADDER]
    cm=compare(routes[labels[0]],routes[labels[1]])
    mf=compare(routes[labels[1]],routes[labels[2]])
    mapping={
        "storage_rms":"storage",
        "cumulative_bottom_rms":"cumulative_bottom",
        "qavg_rms":"qavg",
        "qend_rms":"qend",
        "mapped_theta_rms":"mapped_theta",
    }
    classes={}
    orders={}
    for core,obs in mapping.items():
        e1=float(cm[obs]["rms"]);e2=float(mf[obs]["rms"])
        classes[core]=classify(e1,e2,tol)
        orders[core]=apparent_order(e1,e2)
    self_convergent=(
        all(classes[k] in ("CONVERGING","SATURATED") for k in CORE)
        and any(classes[k]=="CONVERGING" for k in CORE)
    )
    return {
        "coarse_mid":cm,
        "mid_fine":mf,
        "component_classification":classes,
        "apparent_order":orders,
        "SELF_CONVERGENT":self_convergent,
    }


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--material",required=True)
    ap.add_argument("--b1h-result",required=True,type=pathlib.Path)
    ap.add_argument("--b1h-prereg",required=True,type=pathlib.Path)
    ap.add_argument("--basis-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    if pre["phase"]!="PREREGISTERED_BEFORE_CANDIDATE_SELF_CONVERGENCE_RESULTS":
        raise SystemExit("wrong B1HCH preregistration phase")
    op=pre.get("pre_execution_operationalization",{})
    if not op.get("before_first_B1HCH_execution",False):
        raise SystemExit("B1HCH operationalization not frozen")
    if pre["temporal_ladder"]["dt_day"]!=[0.0001,0.00005,0.000025]:
        raise SystemExit("B1HCH dt ladder drift")
    if op["candidate_generation"]["reference_input_to_analyzer"] is not False:
        raise SystemExit("B1HCH must remain Reference-independent")

    b1h=json.loads(a.b1h_result.read_text())
    bp=json.loads(a.b1h_prereg.read_text())
    if b1h["material"]!=a.material or a.material not in pre["scope"]["materials"]:
        raise SystemExit("B1H material identity mismatch")
    frozen=list(bp["initial_state_transfer"]["frozen_scaled_lambda"][a.material])
    observed=[float(x) for x in b1h["scaled_lambdas"]]
    if len(frozen)!=len(observed) or max(abs(float(x)-float(y)) for x,y in zip(frozen,observed))>1e-15:
        raise SystemExit("scaled lambda drift")

    c4v=load("layer_rom_b1hch_c4v",a.basis_dir/"analyze_lare_bc2_c4v_one_day.py")
    patch_material(c4v,b1h["material_parameters"],observed)
    reps={x["id"]:x for x in bp["representations"]}
    for rid in ("R16_OP","R8"):
        if rid not in reps:
            raise SystemExit(f"missing representation {rid}")

    ledger_gate=float(op["candidate_generation"]["water_ledger_gate_cm"])
    routes={}
    for rid in ("R16_OP","R8"):
        routes[rid]={}
        for dt in DT_LADDER:
            routes[rid][f"{dt:.8f}"]=run_candidate(c4v,reps[rid],dt,ledger_gate)

    tol=float(pre["numerical_identity_tolerance"])
    characterization={rid:characterize(routes[rid],tol) for rid in ("R16_OP","R8")}
    primary=bool(characterization["R16_OP"]["SELF_CONVERGENT"])

    max_ledger=max(
        float(route["max_abs_water_ledger_cm"])
        for rr in routes.values() for route in rr.values()
    )
    max_iter=max(
        int(route["max_corrector_iterations"])
        for rr in routes.values() for route in rr.values()
    )

    result={
        "schema":"swap5.layer-rom.phase-b1hch.material-result.v1",
        "workstream":"F-ROM-LAYER",
        "work_unit":"LAYER-ROM-B1HCH",
        "decision":"B1HCH_MATERIAL_SELF_CONVERGENCE_CHARACTERIZED",
        "material":a.material,
        "primary_R16_OP_SELF_CONVERGENT":primary,
        "R16_OP":characterization["R16_OP"],
        "R8_secondary":characterization["R8"],
        "integrity":{
            "pass":True,
            "reference_trajectory_used":False,
            "max_abs_water_ledger_cm":max_ledger,
            "max_corrector_iterations":max_iter,
            "all_initial_states_identical_across_dt":True,
        },
        "interpretation_firewalls":[
            "Primary self-convergence differences are candidate-versus-candidate only; no Reference trajectory is read.",
            "R8 is secondary context and cannot override the R16_OP decision.",
            "Self-convergence does not establish closeness to continuous Richards or application acceptance.",
            "No closure, state, partition or empirical coefficient is changed."
        ],
        "application_acceptance_adjudicated":False,
        "performance_measurement_performed":False,
        "production_rom_authorized":False
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "material":a.material,
        "R16_OP_SELF_CONVERGENT":primary,
        "R16_OP_classification":characterization["R16_OP"]["component_classification"],
        "R16_OP_coarse_mid_rms":{k:v["rms"] for k,v in characterization["R16_OP"]["coarse_mid"].items() if isinstance(v,dict) and "rms" in v},
        "R16_OP_mid_fine_rms":{k:v["rms"] for k,v in characterization["R16_OP"]["mid_fine"].items() if isinstance(v,dict) and "rms" in v},
        "R16_OP_apparent_order":characterization["R16_OP"]["apparent_order"],
        "R8_SELF_CONVERGENT":characterization["R8"]["SELF_CONVERGENT"],
        "max_abs_water_ledger_cm":max_ledger
    },sort_keys=True))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
