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

def load_module(name:str,path:pathlib.Path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    mod=importlib.util.module_from_spec(spec)
    sys.modules[name]=mod
    spec.loader.exec_module(mod)
    return mod

s2=load_module("rom_root_s3_s2",HERE/"run_rom_root_s2_prescribed_sink.py")

OBS_DT=s2.OBS_DT
DT=s2.DT
STEPS=s2.STEPS
ROOT_DEPTH=s2.ROOT_DEPTH
LEDGER_GATE=s2.LEDGER_GATE
PARTITIONS=s2.PARTITIONS
HISTORIES=s2.HISTORIES
ACTIVATION_GUARD=2.9103830456733704e-11

def h_from_se(se:float)->float:
    return -float(s2.bc.psi_from_se(se))

def critical_h3(tp:float)->float:
    h3l=h_from_se(0.35)
    h3h=h_from_se(0.55)
    adcrl=0.10
    adcrh=0.50
    if tp < adcrl:
        return h3l
    if tp <= adcrh:
        return h3h + ((adcrh-tp)/(adcrh-adcrl))*(h3l-h3h)
    return h3h

def drought_alpha(h:np.ndarray,tp:float)->np.ndarray:
    h=np.asarray(h,dtype=float)
    h3=critical_h3(tp)
    h4=h_from_se(0.08)
    out=np.ones_like(h)
    out[h < h4]=0.0
    mask=(h >= h4) & (h <= h3)
    out[mask]=(h4-h[mask])/(h4-h3)
    if np.any(~np.isfinite(out)) or np.any(out < -1e-14) or np.any(out > 1.0+1e-14):
        raise RuntimeError("invalid drought alpha")
    return np.clip(out,0.0,1.0)

def map_piecewise_to_10cm(storage:np.ndarray,bounds:list[float])->list[float]:
    dz=np.diff(np.asarray(bounds,dtype=float))
    theta=np.asarray(storage,dtype=float)/dz
    out=[]
    for j in range(16):
        lo=10.0*j
        hi=lo+10.0
        water=0.0
        for value,a,b in zip(theta,bounds,bounds[1:]):
            width=max(0.0,min(hi,b)-max(lo,a))
            if width>0.0:
                water+=float(value)*width
        out.append(water/10.0)
    return out

def integrated_storage(storage:np.ndarray,bounds:list[float],lo:float,hi:float)->float:
    dz=np.diff(np.asarray(bounds,dtype=float))
    theta=np.asarray(storage,dtype=float)/dz
    water=0.0
    for value,a,b in zip(theta,bounds,bounds[1:]):
        width=max(0.0,min(hi,b)-max(lo,a))
        if width>0.0:
            water+=float(value)*width
    return water

def feedback_sink(y:np.ndarray,dz:np.ndarray,tp:float,fractions:np.ndarray)->tuple[np.ndarray,np.ndarray,np.ndarray]:
    theta=np.asarray(y[:len(dz)],dtype=float)/dz
    psi,_=s2.bc.psi_k(theta)
    h=-psi
    alpha=drought_alpha(h,tp)
    sink=tp*fractions*alpha
    return sink,h,alpha

def solve(material:str,history:str,member:str,mode:str)->dict:
    s2.configure_material(material)
    bounds,dz,y,k0,psi0,se0=s2.initialize(material,history,member)
    n=len(dz)
    tp=float(HISTORIES[history]["tp"])
    profile=str(HISTORIES[history]["root"])
    fractions=s2.layer_root_fractions(bounds,profile)
    full_sink=tp*fractions
    initial_storage=float(np.sum(y[:n]))
    initial_theta10=np.asarray(map_piecewise_to_10cm(y[:n],bounds),dtype=float)
    substeps=int(round(OBS_DT/DT))
    if substeps<=0 or abs(substeps*DT-OBS_DT)>1e-15:
        raise RuntimeError("Stage3 dt does not divide observation interval")

    root_increments=[]
    storage=[]
    root40=[]
    upper80=[]
    theta10=[]
    redistribution=[]
    cumulative_top=[]
    cumulative_bottom=[]
    cumulative_root=[]
    interval_bottom_flux=[]
    actual_rate=[]
    actual_fraction=[]
    layer_h=[]
    layer_alpha=[]
    layer_sink=[]
    max_ledger=0.0
    max_corrector=0
    prev_bottom=0.0

    for _obs in range(1,STEPS+1):
        obs_root=[]
        last_h=np.zeros(n,dtype=float)
        last_alpha=np.ones(n,dtype=float)
        last_sink=np.zeros(n,dtype=float)
        for _ in range(substeps):
            if mode=="DYNAMIC":
                sink,last_h,last_alpha=feedback_sink(y,dz,tp,fractions)
            elif mode=="FULL_POTENTIAL":
                theta=y[:n]/dz
                psi,_=s2.bc.psi_k(theta)
                last_h=-psi
                last_alpha=np.ones(n,dtype=float)
                sink=full_sink
            else:
                raise ValueError(mode)
            last_sink=np.asarray(sink,dtype=float).copy()
            y,iterations=s2.heun_step(y,DT,dz,k0,psi0,"PRESCRIBED_ROOT",last_sink)
            inc=math.fsum(float(v) for v in last_sink)*DT
            root_increments.append(inc)
            obs_root.append(inc)
            y[n+2]=math.fsum(root_increments)
            max_corrector=max(max_corrector,int(iterations))

        total=float(np.sum(y[:n]))
        ledger=(total-initial_storage)-(float(y[n])-float(y[n+1])-float(y[n+2]))
        max_ledger=max(max_ledger,abs(ledger))
        prof=np.asarray(map_piecewise_to_10cm(y[:n],bounds),dtype=float)
        storage.append(np.asarray(y[:n],dtype=float).copy())
        root40.append(integrated_storage(y[:n],bounds,0.0,40.0))
        upper80.append(integrated_storage(y[:n],bounds,0.0,80.0))
        theta10.append(prof)
        redistribution.append(float(np.std(prof-initial_theta10)))
        cumulative_top.append(float(y[n]))
        cumulative_bottom.append(float(y[n+1]))
        cumulative_root.append(float(y[n+2]))
        interval_bottom_flux.append((float(y[n+1])-prev_bottom)/OBS_DT)
        prev_bottom=float(y[n+1])
        rate=math.fsum(obs_root)/OBS_DT
        actual_rate.append(rate)
        actual_fraction.append(rate/tp)
        layer_h.append(last_h.copy())
        layer_alpha.append(last_alpha.copy())
        layer_sink.append(last_sink.copy())

    return {
        "status":"QUALIFIED" if max_ledger<=LEDGER_GATE else "LEDGER_FAILED",
        "mode":mode,
        "material":material,
        "history":history,
        "member":member,
        "dimension":n,
        "boundaries_cm":bounds,
        "initial_se":se0,
        "dt_day":DT,
        "observation_dt_day":OBS_DT,
        "potential_transpiration_cm_per_day":tp,
        "root_profile":profile,
        "layer_root_fraction":fractions.tolist(),
        "root_zone_0_40_storage_cm":root40,
        "upper_0_80_storage_cm":upper80,
        "theta_10cm":np.asarray(theta10).tolist(),
        "profile_redistribution_index":redistribution,
        "cumulative_top_downward_cm":cumulative_top,
        "cumulative_bottom_downward_cm":cumulative_bottom,
        "interval_bottom_downward_flux_cm_per_day":interval_bottom_flux,
        "cumulative_actual_root_uptake_cm":cumulative_root,
        "interval_actual_root_uptake_cm_per_day":actual_rate,
        "actual_over_potential_fraction":actual_fraction,
        "layer_mean_pressure_head_cm":np.asarray(layer_h).tolist(),
        "layer_drought_alpha":np.asarray(layer_alpha).tolist(),
        "layer_root_sink_cm_per_day":np.asarray(layer_sink).tolist(),
        "max_abs_water_ledger_cm":max_ledger,
        "max_corrector_iterations":max_corrector,
    }

def stress_summary(sol:dict)->dict:
    frac=np.asarray(sol["actual_over_potential_fraction"],dtype=float)
    stressed=np.where(frac < 1.0-ACTIVATION_GUARD)[0]
    onset=None if stressed.size==0 else int(stressed[0]+1)
    return {
        "onset_observation":onset,
        "stressed_observation_count":int(stressed.size),
        "stress_duration_day":float(stressed.size*OBS_DT),
        "minimum_fraction":float(np.min(frac)),
        "maximum_fraction_deficit":float(max(0.0,1.0-float(np.min(frac)))),
    }

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--material",required=True,choices=("B01","B14"))
    ap.add_argument("--history",required=True,choices=tuple(HISTORIES))
    ap.add_argument("--member",required=True,choices=tuple(PARTITIONS))
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--s3c0-result",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    c0=json.loads(a.s3c0_result.read_text())
    assert pre["state"]=="PREREGISTERED_BEFORE_ANY_STAGE3_REDUCED_DYNAMIC_FEEDBACK_RESPONSE"
    assert c0["status"]=="S3C0_FULL_POTENTIAL_REFERENCE_QUALIFIED"
    assert pre["minimal_feedback"]["fitted_coefficients"] is False
    assert pre["minimal_feedback"]["new_memory_state"] is False

    try:
        dynamic=solve(a.material,a.history,a.member,"DYNAMIC")
        full=solve(a.material,a.history,a.member,"FULL_POTENTIAL")
        status="QUALIFIED" if dynamic["status"]=="QUALIFIED" and full["status"]=="QUALIFIED" else "LEDGER_FAILED"
        failure=None
    except ValueError as exc:
        dynamic=None
        full=None
        status="OUTSIDE_QUALIFIED_DOMAIN"
        failure=str(exc)
    except (RuntimeError,FloatingPointError) as exc:
        dynamic=None
        full=None
        status="NUMERICAL_BLOCKED"
        failure=str(exc)

    out={
        "schema":"swap5.rom_root.s3.candidate.v1",
        "workstream":"ROM-ROOT",
        "work_unit":"ROM-ROOT-S3",
        "material":a.material,
        "history":a.history,
        "member":a.member,
        "status":status,
        "failure":failure,
        "dynamic":dynamic,
        "full_potential_control":full,
        "stress":None if dynamic is None else stress_summary(dynamic),
        "scientific_firewall":{
            "representation_changed":False,
            "closure_changed":False,
            "fitted_coefficient_used":False,
            "error_correction_used":False,
            "relaxation_used":False,
            "new_memory_state_used":False,
            "application_acceptance_adjudicated":False,
            "performance_comparison_authorized":False,
            "production_rom_authorized":False,
        },
        "model_changed":False,
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "material":a.material,"history":a.history,"member":a.member,
        "status":status,
        "stress":out["stress"],
        "dynamic_ledger":None if dynamic is None else dynamic["max_abs_water_ledger_cm"],
        "full_ledger":None if full is None else full["max_abs_water_ledger_cm"],
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
