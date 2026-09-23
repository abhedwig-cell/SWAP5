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
OBS_DT=0.0008
DT=0.0001
OBSERVATIONS=1024
HORIZON=OBS_DT*OBSERVATIONS
ROOT_DEPTH=80.0
LEDGER_GATE=1.0e-10
STRESS_GUARD=2.9103830456733704e-11

PARTITIONS={
    "U4":[0.0,40.0,80.0,120.0,160.0],
    "U8":[0.0,20.0,40.0,60.0,80.0,100.0,120.0,140.0,160.0],
    "R8":[0.0,90.0,100.0,110.0,120.0,130.0,140.0,150.0,160.0],
    "R16":[float(x) for x in range(0,161,10)],
}
HISTORIES={
    "V01":{"root":"SHALLOW","tp":0.60,"state":"HIGH"},
    "V02":{"root":"SHALLOW","tp":0.30,"state":"LOW"},
    "V03":{"root":"UNIFORM","tp":0.60,"state":"HIGH"},
    "V04":{"root":"UNIFORM","tp":0.30,"state":"LOW"},
}
INITIAL_SE={
    "B01":{"HIGH":0.551,"LOW":0.42671759600680326},
    "B14":{"HIGH":0.551,"LOW":0.40713288830832667},
}


def load_module(name:str,path:pathlib.Path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    mod=importlib.util.module_from_spec(spec)
    sys.modules[name]=mod
    spec.loader.exec_module(mod)
    return mod


bc=load_module("rom_root_s3_bc",HERE/"run_lare_bc1_stage_b.py")


def json_default(value):
    if isinstance(value,np.generic):
        return value.item()
    raise TypeError(type(value).__name__)


def configure_material(material:str)->None:
    if material=="B01":
        bc.THETA_R=0.02
        bc.THETA_S=0.427494
        bc.ALPHA=0.021659
        bc.N_VG=1.734737
        bc.M_VG=1.0-1.0/bc.N_VG
        bc.KS=31.225016
        bc.LAMBDA=0.98087
    elif material=="B14":
        bc.THETA_R=0.01
        bc.THETA_S=0.416774
        bc.ALPHA=0.00541
        bc.N_VG=1.301528
        bc.M_VG=1.0-1.0/bc.N_VG
        bc.KS=0.895023
        bc.LAMBDA=-0.334926
    else:
        raise ValueError(material)


def pressure_head_from_se(se:float)->float:
    return -bc.psi_from_se(float(se))


def critical_h3(tp:float)->float:
    h3l=pressure_head_from_se(0.35)
    h3h=pressure_head_from_se(0.55)
    if tp<0.10:
        return h3l
    if tp<=0.50:
        return h3h+((0.50-tp)/(0.50-0.10))*(h3l-h3h)
    return h3h


def feddes_alpha(head_cm:np.ndarray,tp:float)->np.ndarray:
    h=np.asarray(head_cm,dtype=float)
    h4=pressure_head_from_se(0.08)
    h3=critical_h3(tp)
    out=np.ones_like(h)
    dry=h<h4
    ramp=(h>=h4)&(h<=h3)
    out[dry]=0.0
    out[ramp]=(h4-h[ramp])/(h4-h3)
    if np.any(~np.isfinite(out)) or np.any(out<-1e-15) or np.any(out>1.0+1e-15):
        raise RuntimeError("invalid Feddes alpha")
    return np.clip(out,0.0,1.0)


def cumulative_root_fraction(z_cm:float,profile:str)->float:
    u=min(1.0,max(0.0,z_cm/ROOT_DEPTH))
    if profile=="SHALLOW":
        return 2.0*u-u*u
    if profile=="UNIFORM":
        return u
    raise ValueError(profile)


def layer_root_fractions(bounds:list[float],profile:str)->np.ndarray:
    f=np.asarray([cumulative_root_fraction(z,profile) for z in bounds],dtype=float)
    out=np.diff(f)
    out[np.abs(out)<=64.0*np.finfo(float).eps]=0.0
    if np.any(out<0.0):
        raise RuntimeError("negative root fraction")
    if abs(math.fsum(float(x) for x in out)-1.0)>64.0*np.finfo(float).eps:
        raise RuntimeError("root fractions do not sum to one")
    return out


def initialize(material:str,history:str,member:str):
    configure_material(material)
    bounds=PARTITIONS[member]
    dz=np.diff(np.asarray(bounds,dtype=float))
    se0=INITIAL_SE[material][HISTORIES[history]["state"]]
    theta0=bc.theta_from_se(se0)
    theta=np.full(len(dz),theta0,dtype=float)
    psi,k=bc.psi_k(theta)
    y=np.concatenate([theta*dz,[0.0,0.0,0.0]])
    return bounds,dz,y,float(k[0]),float(psi[0]),float(theta0)


def hydraulic_fluxes(y:np.ndarray,dz:np.ndarray,k0:float):
    theta=y[:len(dz)]/dz
    qint=bc.interface_fluxes(theta,dz)
    return qint,k0,k0


def rhs_with_sink(y:np.ndarray,dz:np.ndarray,k0:float,sink:np.ndarray)->np.ndarray:
    n=len(dz)
    qint,qt,qb=hydraulic_fluxes(y,dz,k0)
    dy=np.zeros_like(y)
    for i in range(n):
        qup=qt if i==0 else qint[i-1]
        qdn=qb if i==n-1 else qint[i]
        dy[i]=qup-qdn-sink[i]
    dy[n]=qt
    dy[n+1]=qb
    dy[n+2]=float(np.sum(sink))
    return dy


def heun_step(y:np.ndarray,dt:float,dz:np.ndarray,k0:float,sink:np.ndarray):
    f0=rhs_with_sink(y,dz,k0,sink)
    guess=y+dt*f0
    n=len(dz)
    for iteration in range(1,bc.HEUN_MAX_CORRECTOR+1):
        fg=rhs_with_sink(guess,dz,k0,sink)
        nxt=y+0.5*dt*(f0+fg)
        if np.max(np.abs(nxt[:n]/dz-guess[:n]/dz))<=bc.HEUN_CORRECTOR_TOL_THETA:
            return nxt,iteration
        guess=nxt
    raise RuntimeError("iterative Heun corrector did not converge")


def map_10cm(theta:np.ndarray,bounds:list[float])->np.ndarray:
    out=np.empty(16,dtype=float)
    for b in range(16):
        lo=10.0*b
        hi=lo+10.0
        idx=None
        for i,(a,z) in enumerate(zip(bounds,bounds[1:])):
            if a<=lo+1e-12 and z>=hi-1e-12:
                idx=i
                break
        if idx is None:
            raise RuntimeError(("10cm mapping",bounds,lo,hi))
        out[b]=theta[idx]
    return out


def dynamic_sink(y:np.ndarray,dz:np.ndarray,tp:float,fractions:np.ndarray):
    theta=y[:len(dz)]/dz
    psi,_=bc.psi_k(theta)
    head=-psi
    alpha=feddes_alpha(head,tp)
    sink=tp*fractions*alpha
    return sink,head,alpha


def solve_route(material:str,history:str,member:str,route:str)->dict:
    bounds,dz,y,k0,psi0,theta0=initialize(material,history,member)
    del psi0
    tp=float(HISTORIES[history]["tp"])
    fractions=layer_root_fractions(bounds,HISTORIES[history]["root"])
    full_sink=tp*fractions
    n=len(dz)
    initial_total=float(np.sum(y[:n]))
    initial_profile=np.full(16,theta0,dtype=float)
    substeps=int(round(OBS_DT/DT))
    if substeps!=8:
        raise RuntimeError("frozen Stage3 temporal ratio changed")

    actual_fraction=[]
    actual_rate=[]
    cumulative_root=[]
    root40=[]
    upper80=[]
    lower80_anomaly=[]
    profiles=[]
    redistribution=[]
    cumulative_bottom=[]
    interval_bottom=[]
    layer_theta=[]
    layer_head=[]
    layer_alpha=[]
    max_ledger=0.0
    max_corrector=0
    prev_bottom=0.0
    observation_root=0.0

    for obs in range(1,OBSERVATIONS+1):
        for _ in range(substeps):
            if route=="DYNAMIC":
                sink,head,alpha=dynamic_sink(y,dz,tp,fractions)
            elif route=="FULL_POTENTIAL":
                sink=full_sink
                theta=y[:n]/dz
                psi,_=bc.psi_k(theta)
                head=-psi
                alpha=np.ones(n,dtype=float)
            else:
                raise ValueError(route)
            dt_local=DT
            observation_root+=float(np.sum(sink))*dt_local
            y,it=heun_step(y,dt_local,dz,k0,sink)
            max_corrector=max(max_corrector,it)

        theta=y[:n]/dz
        bc.psi_k(theta)
        profile=map_10cm(theta,bounds)
        total=float(np.sum(y[:n]))
        ledger=(total-initial_total)-(float(y[n])-float(y[n+1])-float(y[n+2]))
        max_ledger=max(max_ledger,abs(ledger))
        rate=observation_root/OBS_DT
        frac=rate/tp
        actual_rate.append(rate)
        actual_fraction.append(frac)
        cumulative_root.append(float(y[n+2]))
        profiles.append(profile.tolist())
        root40.append(float(np.sum(profile[:4])*10.0))
        upper80.append(float(np.sum(profile[:8])*10.0))
        lower80_anomaly.append(float(np.sum((profile[8:]-initial_profile[8:])*10.0))
        redistribution.append(float(np.std(profile-initial_profile)))
        cumb=float(y[n+1])
        cumulative_bottom.append(cumb)
        interval_bottom.append((cumb-prev_bottom)/OBS_DT)
        prev_bottom=cumb
        observation_root=0.0

        # Observation-end diagnostics only. Feedback itself was evaluated from
        # each committed transaction-start state above.
        psi,_=bc.psi_k(theta)
        h=-psi
        a=feddes_alpha(h,tp) if route=="DYNAMIC" else np.ones(n,dtype=float)
        layer_theta.append(theta.tolist())
        layer_head.append(h.tolist())
        layer_alpha.append(a.tolist())

    if max_ledger>LEDGER_GATE:
        raise RuntimeError(f"water ledger {max_ledger} > {LEDGER_GATE}")
    if any(x<-STRESS_GUARD or x>1.0+STRESS_GUARD for x in actual_fraction):
        raise RuntimeError("actual transpiration fraction outside bounded range")

    return {
        "route":route,
        "status":"QUALIFIED",
        "material":material,
        "history":history,
        "member":member,
        "boundaries_cm":bounds,
        "root_profile":HISTORIES[history]["root"],
        "potential_transpiration_cm_per_day":tp,
        "initial_effective_saturation":INITIAL_SE[material][HISTORIES[history]["state"]],
        "root_fraction":fractions.tolist(),
        "dt_day":DT,
        "observation_dt_day":OBS_DT,
        "actual_root_uptake_cm_per_day":actual_rate,
        "actual_transpiration_fraction":actual_fraction,
        "cumulative_root_uptake_cm":cumulative_root,
        "root_zone_0_40_storage_cm":root40,
        "upper_zone_0_80_storage_cm":upper80,
        "lower_zone_80_160_storage_anomaly_cm":lower80_anomaly,
        "mapped_10cm_theta":profiles,
        "profile_redistribution_index":redistribution,
        "cumulative_bottom_downward_exchange_cm":cumulative_bottom,
        "interval_bottom_downward_flux_cm_per_day":interval_bottom,
        "layer_theta":layer_theta,
        "layer_pressure_head_cm":layer_head,
        "layer_feddes_alpha":layer_alpha,
        "max_abs_water_ledger_cm":max_ledger,
        "max_corrector_iterations":max_corrector,
    }


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--material",required=True,choices=("B01","B14"))
    ap.add_argument("--history",required=True,choices=tuple(HISTORIES))
    ap.add_argument("--s3-prereg",required=True,type=pathlib.Path)
    ap.add_argument("--s3c0-result",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.s3_prereg.read_text())
    c0=json.loads(a.s3c0_result.read_text())
    if pre["state"]!="PREREGISTERED_BEFORE_ANY_STAGE3_REDUCED_DYNAMIC_FEEDBACK_RESPONSE":
        raise SystemExit("invalid Stage3 preregistration")
    if c0["status"]!="S3C0_FULL_POTENTIAL_REFERENCE_QUALIFIED" or c0["decision"]!="STAGE3_DYNAMIC_REDUCED_RESPONSE_MAY_EXECUTE":
        raise SystemExit("S3-C0 is not qualified")
    if pre["scientific_firewall"]["reduced_dynamic_feedback_response_generated"] is not False:
        raise SystemExit("Stage3 firewall not pristine")

    cases={}
    for member in PARTITIONS:
        dynamic=solve_route(a.material,a.history,member,"DYNAMIC")
        control=solve_route(a.material,a.history,member,"FULL_POTENTIAL")
        cases[member]={"DYNAMIC":dynamic,"FULL_POTENTIAL":control}

    out={
        "schema":"swap5.rom_root.s3.candidate-response.v1",
        "workstream":"ROM-ROOT",
        "work_unit":"ROM-ROOT-S3",
        "material":a.material,
        "history":a.history,
        "cases":cases,
        "candidate_definition":"LAYER_MEAN_HEAD_FEDDES",
        "feedback_evaluation_timing":"committed transaction start",
        "sink_held_inside_trial":True,
        "scientific_firewall":{
            "new_partition_selected":False,
            "new_hydraulic_closure_selected":False,
            "new_root_specific_state_selected":False,
            "fitted_coefficient_used":False,
            "relaxation_used":False,
            "error_correction_used":False,
            "application_acceptance_adjudicated":False,
            "performance_comparison_authorized":False,
            "production_rom_authorized":False,
        },
        "model_changed":False,
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True,default=json_default)+"\n")
    print(json.dumps({
        "material":a.material,
        "history":a.history,
        "members":{m:{
            "dynamic_max_ledger":cases[m]["DYNAMIC"]["max_abs_water_ledger_cm"],
            "control_max_ledger":cases[m]["FULL_POTENTIAL"]["max_abs_water_ledger_cm"],
            "dynamic_min_fraction":min(cases[m]["DYNAMIC"]["actual_transpiration_fraction"]),
            "dynamic_final_root_cm":cases[m]["DYNAMIC"]["cumulative_root_uptake_cm"][-1],
        } for m in PARTITIONS}
    },sort_keys=True,default=json_default))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
