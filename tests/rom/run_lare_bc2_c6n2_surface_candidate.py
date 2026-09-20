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
NSTEPS=1024
DT=0.0001
SUBSTEPS=8
LEDGER_GATE=1.0e-10
HISTS={
    "U01":0.65,
    "U02":0.85,
    "U03":0.95,
    "U04":0.75,
}
PARTITIONS={
    "R3":[0.0,140.0,150.0,160.0],
    "R4":[0.0,130.0,140.0,150.0,160.0],
    "R5":[0.0,120.0,130.0,140.0,150.0,160.0],
    "R6":[0.0,110.0,120.0,130.0,140.0,150.0,160.0],
    "R8":[0.0,90.0,100.0,110.0,120.0,130.0,140.0,150.0,160.0],
    "R12":[0.0,50.0,60.0,70.0,80.0,90.0,100.0,110.0,120.0,130.0,140.0,150.0,160.0],
    "R16":[float(x) for x in range(0,161,10)],
    "P4_TOP_LOWER":[0.0,10.0,140.0,150.0,160.0],
    "U4":[0.0,40.0,80.0,120.0,160.0],
    "U8":[0.0,20.0,40.0,60.0,80.0,100.0,120.0,140.0,160.0],
}
LADDER=("R3","R4","R5","R6","R8","R12","R16")
CONTROLS=("P4_TOP_LOWER","U4","U8")


def load_module(name:str,path:pathlib.Path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    mod=importlib.util.module_from_spec(spec)
    sys.modules[name]=mod
    spec.loader.exec_module(mod)
    return mod


bc=load_module("bc1_c6n2",HERE/"run_lare_bc1_stage_b.py")


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
    bc.HISTORY_SE=dict(HISTS)
    bc.OBS_DT=OBS_DT
    bc.STEPS=NSTEPS
    for name,bounds in PARTITIONS.items():
        bc.PARTITIONS[name]=np.diff(np.asarray(bounds,dtype=float))


def symbol(history:str,step:int)->str:
    if history=="U01":
        if step<=224:return "WET"
        if step<=512:return "DRY"
        return "HOLD"
    if history=="U02":
        if step<=224:return "DRY"
        if step<=512:return "WET"
        return "HOLD"
    if history=="U03":
        if step<=288:return "WET"
        if step<=512:return "DRY"
        return "HOLD"
    if history=="U04":
        if step<=288:return "DRY"
        if step<=512:return "WET"
        return "HOLD"
    raise ValueError(history)


def qtop_downward(sym:str,k0:float)->float:
    if sym=="WET":return 1.125*k0
    if sym=="DRY":return 0.875*k0
    if sym=="HOLD":return k0
    raise ValueError(sym)


def boundary_psi(history:str,sym:str,psi0:float):
    return None


def map_piecewise_to_10cm(storage,bounds):
    dz=np.diff(np.asarray(bounds,dtype=float))
    theta=np.asarray(storage,dtype=float)/dz
    out=[]
    for j in range(16):
        lo=10.0*j;hi=lo+10.0
        water=0.0
        for t,a,b in zip(theta,bounds,bounds[1:]):
            w=max(0.0,min(hi,b)-max(lo,a))
            if w>0.0:
                water+=float(t)*w
        out.append(water/10.0)
    return out


def integrated_storage(storage,bounds,lo,hi):
    dz=np.diff(np.asarray(bounds,dtype=float))
    theta=np.asarray(storage,dtype=float)/dz
    water=0.0
    for t,a,b in zip(theta,bounds,bounds[1:]):
        w=max(0.0,min(hi,b)-max(lo,a))
        if w>0.0:
            water+=float(t)*w
    return water


def run_member(material:str,member:str):
    configure_material(material)
    bc.symbol=symbol
    bc.qtop_downward=qtop_downward
    bc.boundary_psi=boundary_psi
    bounds=PARTITIONS[member]
    histories={}
    status="QUALIFIED"
    failures={}
    maxledger=0.0
    maxiter=0
    for h in HISTS:
        try:
            sol=bc.solve(bc.Case(member,h,"CURRENT_LAYER_FACE"),DT)
            ledger=float(sol["max_abs_water_ledger_cm"])
            if ledger>LEDGER_GATE:
                raise RuntimeError(f"water ledger gate {ledger}")
            storage=np.asarray(sol["layer_storage_cm"],dtype=float)
            histories[h]={
                "total_storage_cm":np.sum(storage,axis=1).tolist(),
                "surface_0_20_storage_cm":[integrated_storage(row,bounds,0.0,20.0) for row in storage],
                "root_zone_0_40_storage_cm":[integrated_storage(row,bounds,0.0,40.0) for row in storage],
                "upper_0_80_storage_cm":[integrated_storage(row,bounds,0.0,80.0) for row in storage],
                "theta_10cm":[map_piecewise_to_10cm(row,bounds) for row in storage],
            }
            maxledger=max(maxledger,ledger)
            maxiter=max(maxiter,int(sol["max_corrector_iterations"]))
        except ValueError as exc:
            status="OUTSIDE_QUALIFIED_DOMAIN"
            failures[h]=str(exc)
        except (RuntimeError,FloatingPointError) as exc:
            status="NUMERICAL_BLOCKED"
            failures[h]=str(exc)
    return {
        "material":material,
        "id":member,
        "dimension":len(bounds)-1,
        "boundaries_cm":bounds,
        "status":status,
        "failures":failures,
        "max_abs_water_ledger_cm":maxledger,
        "max_corrector_iterations":maxiter,
        "histories":histories if status=="QUALIFIED" and len(histories)==len(HISTS) else None,
    }


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--material",required=True,choices=("B01","B14"))
    ap.add_argument("--member",required=True,choices=tuple(PARTITIONS))
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c6n1-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    close=json.loads(a.c6n1_closeout.read_text())
    assert pre["phase"]=="SCIENTIFIC_DESIGN_FROZEN_BEFORE_C6N1_RESULT_EXECUTION_BLOCKED"
    assert close["status"]=="CLOSED_R2048_T32_REFERENCE_UNCERTAINTY_QUALIFIED_C6N2_AUTHORIZED"
    assert close["decision"]=="AUTHORIZE_C6N2_EXISTING_REPRESENTATION_PROSPECTIVE_SURFACE_PROFILE_COMPARISON"
    assert close["next_authority"]["state"]=="EXISTING_REPRESENTATION_PROSPECTIVE_SURFACE_PROFILE_COMPARISON_AUTHORIZED"

    out={
        "schema":"swap5.lare.bc2.c6n2.candidate.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C6N2",
        "candidate":run_member(a.material,a.member),
        "scientific_firewall":{
            "new_representation_selected":False,
            "closure_changed":False,
            "application_acceptance_adjudicated":False,
            "performance_comparison_authorized":False,
            "production_rom_authorized":False,
        },
        "model_changed":False,
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    c=out["candidate"]
    print(json.dumps({"material":a.material,"member":a.member,"status":c["status"],
                      "max_abs_water_ledger_cm":c["max_abs_water_ledger_cm"]},sort_keys=True))


if __name__=="__main__":
    main()
