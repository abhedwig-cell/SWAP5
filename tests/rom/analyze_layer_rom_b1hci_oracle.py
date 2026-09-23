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
from scipy.integrate import solve_ivp

HISTS=("X01","X02","X03","X04")
STEPS=1024
OBS_DT=0.001
HEUN_DT=(1.0e-4,5.0e-5,2.5e-5)
COMPONENT_MAP={
    "storage_rms":"storage",
    "cumulative_bottom_rms":"cumulative_bottom",
    "qavg_rms":"qavg",
    "qend_rms":"qend",
    "mapped_theta_rms":"mapped_theta",
}


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


def extract_series(c4v,bounds:list[float],dz:np.ndarray,ys:np.ndarray,initial:float)->dict[str,Any]:
    dim=len(dz)
    if ys.shape!=(dim+2,STEPS):
        raise RuntimeError(f"trajectory shape drift: {ys.shape}")
    S=[];C=[];QAVG=[];QEND=[];theta_map=[]
    prev=0.0
    max_ledger=0.0
    for j in range(STEPS):
        y=ys[:,j]
        theta=y[:dim]/dz
        c4v.bc1.psi_k(theta)
        total=float(np.sum(y[:dim]))
        cum=float(y[dim+1])
        qavg=(cum-prev)/OBS_DT
        prev=cum
        qend=float(c4v.qbottom_zero_head(theta,dz))
        mapped=[float(x) for x in c4v.map_piecewise_to_10cm(theta,bounds)]
        ledger=total-initial+cum
        max_ledger=max(max_ledger,abs(ledger))
        if not all(math.isfinite(x) for x in [total,cum,qavg,qend,*mapped]):
            raise RuntimeError("nonfinite trajectory observable")
        S.append(total);C.append(cum);QAVG.append(qavg);QEND.append(qend);theta_map.append(mapped)
    return {
        "S":S,"C":C,"QAVG":QAVG,"QEND":QEND,"theta":theta_map,
        "max_abs_water_ledger_cm":max_ledger,
    }


def run_heun(c4v,member:dict[str,Any],dt:float,ledger_gate:float)->dict[str,Any]:
    ratio=OBS_DT/dt
    substeps=int(round(ratio))
    if substeps<=0 or abs(substeps*dt-OBS_DT)>1e-15:
        raise RuntimeError(f"nonintegral Heun dt {dt}")
    bounds=[float(x) for x in member["boundaries_cm"]]
    dim=int(member["dimension"])
    series={};max_ledger=0.0;max_iter=0
    for hist in HISTS:
        dz,y=c4v.initial_state(c4v.HISTS[hist],bounds)
        initial=float(np.sum(y[:dim]))
        cols=[]
        for _step in range(STEPS):
            for _ in range(substeps):
                y,it=c4v.heun_step(y,dt,dz)
                max_iter=max(max_iter,int(it))
            cols.append(y.copy())
        z=extract_series(c4v,bounds,dz,np.asarray(cols,dtype=float).T,initial)
        max_ledger=max(max_ledger,float(z["max_abs_water_ledger_cm"]))
        if max_ledger>ledger_gate:
            raise RuntimeError(f"Heun water ledger {max_ledger}")
        series[hist]=z
    return {
        "integrator":"HEUN","dt_day":dt,"series":series,
        "max_abs_water_ledger_cm":max_ledger,
        "max_corrector_iterations":max_iter,
    }


def run_oracle(c4v,member:dict[str,Any],spec:dict[str,Any],ledger_gate:float)->dict[str,Any]:
    bounds=[float(x) for x in member["boundaries_cm"]]
    dim=int(member["dimension"])
    t_eval=np.arange(1,STEPS+1,dtype=float)*OBS_DT
    series={};max_ledger=0.0;total_nfev=0;total_njev=0;total_nlu=0
    for hist in HISTS:
        dz,y0=c4v.initial_state(c4v.HISTS[hist],bounds)
        initial=float(np.sum(y0[:dim]))
        def fun(_t,y):
            return np.asarray(c4v.rhs(y,dz),dtype=float)
        sol=solve_ivp(
            fun,(0.0,STEPS*OBS_DT),y0,
            method=spec["method"],t_eval=t_eval,
            rtol=float(spec["rtol"]),atol=float(spec["atol"]),
            max_step=float(spec["max_step_day"]),
            dense_output=False,
            vectorized=False,
        )
        if not sol.success or sol.y.shape!=(dim+2,STEPS):
            raise RuntimeError(f"{spec['id']} integration failed {hist}: {sol.message}")
        z=extract_series(c4v,bounds,dz,np.asarray(sol.y,dtype=float),initial)
        max_ledger=max(max_ledger,float(z["max_abs_water_ledger_cm"]))
        if max_ledger>ledger_gate:
            raise RuntimeError(f"{spec['id']} water ledger {hist}: {max_ledger}")
        series[hist]=z
        total_nfev+=int(sol.nfev)
        total_njev+=int(getattr(sol,"njev",0) or 0)
        total_nlu+=int(getattr(sol,"nlu",0) or 0)
    return {
        "integrator":spec["id"],
        "method":spec["method"],
        "rtol":spec["rtol"],"atol":spec["atol"],
        "series":series,
        "max_abs_water_ledger_cm":max_ledger,
        "nfev":total_nfev,"njev":total_njev,"nlu":total_nlu,
    }


def pooled_stats(a:dict[str,Any],b:dict[str,Any])->dict[str,dict[str,float|int]]:
    fields={"storage":"S","cumulative_bottom":"C","qavg":"QAVG","qend":"QEND","mapped_theta":"theta"}
    out={}
    for name,key in fields.items():
        parts=[]
        for hist in HISTS:
            x=np.asarray(a["series"][hist][key],dtype=float)
            y=np.asarray(b["series"][hist][key],dtype=float)
            if x.shape!=y.shape:
                raise RuntimeError(f"shape mismatch {hist} {key}: {x.shape} {y.shape}")
            parts.append((x-y).reshape(-1))
        d=np.concatenate(parts)
        if not np.all(np.isfinite(d)):
            raise RuntimeError(f"nonfinite comparison {name}")
        out[name]={
            "count":int(d.size),
            "rms":float(np.sqrt(np.mean(d*d))),
            "max_abs":float(np.max(np.abs(d))),
        }
    return out


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--material",required=True)
    ap.add_argument("--b1h-result",required=True,type=pathlib.Path)
    ap.add_argument("--b1h-prereg",required=True,type=pathlib.Path)
    ap.add_argument("--b1hch-result",required=True,type=pathlib.Path)
    ap.add_argument("--basis-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    if pre["phase"]!="PREREGISTERED_BEFORE_INDEPENDENT_NUMERICAL_ORACLE_RESULTS":
        raise SystemExit("wrong B1HCI preregistration phase")
    if pre["scope"]["reference_used_in_primary_oracle_decision"] is not False:
        raise SystemExit("Reference firewall drift")
    b1h=json.loads(a.b1h_result.read_text())
    bp=json.loads(a.b1h_prereg.read_text())
    ch=json.loads(a.b1hch_result.read_text())
    if b1h["material"]!=a.material or a.material not in pre["scope"]["materials"]:
        raise SystemExit("material identity mismatch")
    frozen=list(bp["initial_state_transfer"]["frozen_scaled_lambda"][a.material])
    observed=[float(x) for x in b1h["scaled_lambdas"]]
    if len(frozen)!=len(observed) or max(abs(float(x)-float(y)) for x,y in zip(frozen,observed))>1e-15:
        raise SystemExit("scaled lambda drift")
    if ch["decision"]!="B1HCH_R16_SELF_CONVERGENCE_MIXED":
        raise SystemExit("B1HCH aggregate authority drift")

    c4v=load("layer_rom_b1hci_c4v",a.basis_dir/"analyze_lare_bc2_c4v_one_day.py")
    patch_material(c4v,b1h["material_parameters"],observed)
    reps={x["id"]:x for x in bp["representations"]}
    oracle_specs={x["id"]:x for x in pre["independent_oracles"]}
    if set(oracle_specs)!={"DOP853_STRICT","RADAU_STRICT"}:
        raise SystemExit("oracle specification drift")

    ledger_gate=1e-10
    routes={}
    for rid in ("R16_OP","R8"):
        routes[rid]={"HEUN":{},"ORACLE":{}}
        for dt in HEUN_DT:
            routes[rid]["HEUN"][f"{dt:.8f}"]=run_heun(c4v,reps[rid],dt,ledger_gate)
        for oid in ("DOP853_STRICT","RADAU_STRICT"):
            routes[rid]["ORACLE"][oid]=run_oracle(c4v,reps[rid],oracle_specs[oid],ledger_gate)

    floors={k:float(v) for k,v in pre["oracle_agreement_gate"]["per_component_absolute_floor"].items()}
    midfine=ch["R16_OP_pairwise_rms"][a.material]["R16_OP"]["mid_fine"]

    evaluation={}
    for rid in ("R16_OP","R8"):
        dop=routes[rid]["ORACLE"]["DOP853_STRICT"]
        rad=routes[rid]["ORACLE"]["RADAU_STRICT"]
        oracle_pair=pooled_stats(dop,rad)
        heun_vs_oracle={
            label:pooled_stats(route,dop)
            for label,route in routes[rid]["HEUN"].items()
        }
        component={}
        for comp,obs in COMPONENT_MAP.items():
            floor=floors[comp]
            # The primary design binds gates to immutable R16_OP B1HCH scale for both
            # R16_OP and secondary R8 context so the numerical gate is not representation-retuned.
            mf=float(midfine[comp])
            oracle_limit=max(floor,0.10*mf)
            oracle_ok=float(oracle_pair[obs]["rms"])<=oracle_limit
            d1=float(heun_vs_oracle["0.00010000"][obs]["rms"])
            d2=float(heun_vs_oracle["0.00005000"][obs]["rms"])
            d3=float(heun_vs_oracle["0.00002500"][obs]["rms"])
            if mf<=floor:
                label="NUMERICALLY_SATURATED" if d3<=floor else "FINE_HEUN_OUTSIDE_NUMERICAL_FLOOR"
                heun_ok=d3<=floor
            else:
                monotone=(d2<=d1+floor and d3<=d2+floor)
                final_bound=max(floor,0.75*mf)
                heun_ok=monotone and d3<=final_bound
                label="HEUN_APPROACHES_ORACLE" if heun_ok else "HEUN_ORACLE_RELATION_FAILS"
            component[comp]={
                "B1HCH_mid_fine_rms":mf,
                "absolute_floor":floor,
                "oracle_pair_rms":float(oracle_pair[obs]["rms"]),
                "oracle_pair_limit":oracle_limit,
                "oracle_agreement_pass":oracle_ok,
                "heun_to_DOP853_rms":{
                    "0.00010000":d1,"0.00005000":d2,"0.00002500":d3
                },
                "heun_classification":label,
                "heun_pass":heun_ok,
            }
        oracle_all=all(v["oracle_agreement_pass"] for v in component.values())
        heun_all=all(v["heun_pass"] for v in component.values())
        evaluation[rid]={
            "oracle_pair":oracle_pair,
            "components":component,
            "oracle_agreement_all_components":oracle_all,
            "heun_to_oracle_all_components":heun_all,
            "material_supported":oracle_all and heun_all,
            "solver_effort":{
                oid:{
                    "nfev":routes[rid]["ORACLE"][oid]["nfev"],
                    "njev":routes[rid]["ORACLE"][oid]["njev"],
                    "nlu":routes[rid]["ORACLE"][oid]["nlu"],
                    "max_abs_water_ledger_cm":routes[rid]["ORACLE"][oid]["max_abs_water_ledger_cm"],
                } for oid in ("DOP853_STRICT","RADAU_STRICT")
            },
            "max_heun_water_ledger_cm":max(
                float(x["max_abs_water_ledger_cm"]) for x in routes[rid]["HEUN"].values()
            )
        }

    primary=evaluation["R16_OP"]
    if not primary["oracle_agreement_all_components"]:
        material_decision="B1HCI_MATERIAL_ORACLE_UNRESOLVED"
    elif primary["heun_to_oracle_all_components"]:
        material_decision="B1HCI_MATERIAL_HEUN_LIMIT_SUPPORTED"
    else:
        material_decision="B1HCI_MATERIAL_HEUN_ORACLE_RELATION_MIXED"

    result={
        "schema":"swap5.layer-rom.phase-b1hci.material-result.v1",
        "workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-B1HCI",
        "decision":material_decision,
        "material":a.material,
        "R16_OP":evaluation["R16_OP"],
        "R8_secondary":evaluation["R8"],
        "integrity":{
            "pass":True,
            "reference_trajectory_used":False,
            "hydrological_model_changed":False,
            "max_water_ledger_cm":max(
                evaluation["R16_OP"]["max_heun_water_ledger_cm"],
                evaluation["R8"]["max_heun_water_ledger_cm"],
                max(v["max_abs_water_ledger_cm"] for v in evaluation["R16_OP"]["solver_effort"].values()),
                max(v["max_abs_water_ledger_cm"] for v in evaluation["R8"]["solver_effort"].values()),
            )
        },
        "interpretation_firewalls":[
            "DOP853 and Radau integrate the exact same frozen Layer-ROM ODE as the Heun route.",
            "No Reference trajectory enters the primary oracle relation.",
            "Numerical oracle gates are not hydrological or application acceptance tolerances.",
            "R8 remains secondary and cannot override R16_OP."
        ],
        "application_acceptance_adjudicated":False,
        "performance_measurement_performed":False,
        "production_rom_authorized":False,
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "material":a.material,
        "decision":material_decision,
        "R16_OP_components":primary["components"],
        "R16_OP_solver_effort":primary["solver_effort"],
        "R8_material_supported":evaluation["R8"]["material_supported"],
        "max_water_ledger_cm":result["integrity"]["max_water_ledger_cm"]
    },sort_keys=True))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
