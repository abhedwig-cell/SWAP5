#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import pathlib
import sys

import numpy as np

HERE=pathlib.Path(__file__).resolve().parent
OBS_DT=0.0008
NOBS=1024
DT=0.0001
LEDGER_GATE=1.0e-10
PARTITIONS={
    "S8":[0.0,10.0,20.0,30.0,40.0,50.0,60.0,80.0,160.0],
    "S12":[0.0,5.0,10.0,20.0,30.0,40.0,50.0,60.0,70.0,80.0,100.0,120.0,160.0],
    "S16":[0.0,5.0,10.0,15.0,20.0,25.0,30.0,35.0,40.0,50.0,60.0,70.0,80.0,100.0,120.0,140.0,160.0],
    "G8":[0.0,80.0,100.0,120.0,130.0,140.0,150.0,155.0,160.0],
    "G12":[0.0,40.0,80.0,100.0,120.0,130.0,140.0,145.0,150.0,152.5,155.0,157.5,160.0],
    "G16":[0.0,20.0,40.0,60.0,80.0,100.0,110.0,120.0,130.0,135.0,140.0,145.0,150.0,152.5,155.0,157.5,160.0],
}
ALLOWED={
    "SURF_P":("S8","S12","S16"),
    "GW_LB":("G8","G12","G16"),
}
SURF_SE={"17":0.73,"18":0.81,"19":0.87,"20":0.93}
GW_SE={"17":0.72,"18":0.80,"19":0.85,"20":0.90}


def load_module(name:str,path:pathlib.Path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    mod=importlib.util.module_from_spec(spec)
    sys.modules[name]=mod
    spec.loader.exec_module(mod)
    return mod


bc=load_module("rom_purpose_p2_layer_base",HERE/"rom_purpose_p1_layer_base.py")


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
    bc.OBS_DT=OBS_DT
    bc.STEPS=NOBS
    for name,bounds in PARTITIONS.items():
        bc.PARTITIONS[name]=np.diff(np.asarray(bounds,dtype=float))
        bc.BOUNDARIES[name]=list(bounds)


def histories(purpose:str)->dict[str,float]:
    if purpose=="SURF_P":
        return {f"S{k}":v for k,v in SURF_SE.items()}
    if purpose=="GW_LB":
        return {f"G{k}":v for k,v in GW_SE.items()}
    raise ValueError(purpose)


def symbol_surface(history:str,step:int)->str:
    if history in ("S17","S19"):
        if step<=256:return "WET"
        if step<=512:return "DRY"
        if step<=768:return "WET"
        return "DRY"
    if history in ("S18","S20"):
        if step<=256:return "DRY"
        if step<=512:return "WET"
        if step<=768:return "DRY"
        return "WET"
    raise ValueError(history)


def qtop_surface(sym:str,k0:float)->float:
    if sym=="WET":return 1.15*k0
    if sym=="DRY":return 0.85*k0
    raise ValueError(sym)


def boundary_surface(history:str,sym:str,psi0:float):
    # P4 SURF_P retains the preregistered gravity-equilibrium bottom flux.
    return None


def symbol_gw(history:str,step:int)->str:
    if history=="G17":
        if step<=256:return "BOTTOM_HEAD_RISE"
        if step<=640:return "BOTTOM_HEAD_FALL"
        return "HOLD"
    if history=="G18":
        if step<=256:return "BOTTOM_HEAD_FALL"
        if step<=640:return "BOTTOM_HEAD_RISE"
        return "HOLD"
    if history=="G19":
        if step<=384:return "BOTTOM_HEAD_RISE"
        if step<=768:return "BOTTOM_HEAD_FALL"
        return "HOLD"
    if history=="G20":
        if step<=384:return "BOTTOM_HEAD_FALL"
        if step<=768:return "BOTTOM_HEAD_RISE"
        return "HOLD"
    raise ValueError(history)


def qtop_gw(sym:str,k0:float)->float:
    return k0


def boundary_gw(history:str,sym:str,psi0:float):
    if sym=="BOTTOM_HEAD_RISE":return 0.90*psi0
    if sym=="BOTTOM_HEAD_FALL":return 1.10*psi0
    if sym=="HOLD":return None
    raise ValueError((history,sym))


def map_piecewise_to_10cm(storage,bounds):
    dz=np.diff(np.asarray(bounds,dtype=float))
    theta=np.asarray(storage,dtype=float)/dz
    out=[]
    for j in range(16):
        lo=10.0*j; hi=lo+10.0; water=0.0
        for t,a,b in zip(theta,bounds,bounds[1:]):
            w=max(0.0,min(hi,b)-max(lo,a))
            if w>0.0: water+=float(t)*w
        out.append(water/10.0)
    return out


def integrated_storage(storage,bounds,lo,hi):
    dz=np.diff(np.asarray(bounds,dtype=float))
    theta=np.asarray(storage,dtype=float)/dz
    water=0.0
    for t,a,b in zip(theta,bounds,bounds[1:]):
        w=max(0.0,min(hi,b)-max(lo,a))
        if w>0.0: water+=float(t)*w
    return float(water)


def run_candidate(purpose:str,material:str,member:str):
    configure_material(material)
    bc.HISTORY_SE=histories(purpose)
    if purpose=="SURF_P":
        bc.symbol=symbol_surface
        bc.qtop_downward=qtop_surface
        bc.boundary_psi=boundary_surface
    elif purpose=="GW_LB":
        bc.symbol=symbol_gw
        bc.qtop_downward=qtop_gw
        bc.boundary_psi=boundary_gw
    else:
        raise ValueError(purpose)

    if member not in ALLOWED[purpose]:
        raise ValueError(f"{member} not authorized for {purpose}")
    bounds=PARTITIONS[member]
    result={}
    failures={}
    overall="QUALIFIED"
    maxledger=0.0
    maxiter=0

    for history in bc.HISTORY_SE:
        try:
            sol=bc.solve(bc.Case(member,history,"CURRENT_LAYER_FACE"),DT)
            ledger=float(sol["max_abs_water_ledger_cm"])
            if ledger>LEDGER_GATE:
                raise RuntimeError(f"water ledger gate {ledger}")
            storage=np.asarray(sol["layer_storage_cm"],dtype=float)
            result[history]={
                "total_storage_cm":np.sum(storage,axis=1).tolist(),
                "surface_0_20_storage_cm":[integrated_storage(row,bounds,0.0,20.0) for row in storage],
                "root_zone_0_40_storage_cm":[integrated_storage(row,bounds,0.0,40.0) for row in storage],
                "upper_0_80_storage_cm":[integrated_storage(row,bounds,0.0,80.0) for row in storage],
                "theta_10cm":[map_piecewise_to_10cm(row,bounds) for row in storage],
                "cumulative_bottom_downward_cm":[float(x) for x in sol["cumulative_bottom_downward_cm"]],
                "interval_average_bottom_downward_flux_cm_per_day":[float(x) for x in sol["interval_average_bottom_downward_flux_cm_per_day"]],
            }
            maxledger=max(maxledger,ledger)
            maxiter=max(maxiter,int(sol["max_corrector_iterations"]))
        except ValueError as exc:
            overall="OUTSIDE_QUALIFIED_DOMAIN"
            failures[history]=str(exc)
        except (RuntimeError,FloatingPointError) as exc:
            if overall!="OUTSIDE_QUALIFIED_DOMAIN":
                overall="NUMERICAL_BLOCKED"
            failures[history]=str(exc)

    return {
        "purpose":purpose,
        "material":material,
        "id":member,
        "dimension":len(bounds)-1,
        "boundaries_cm":bounds,
        "closure":"CURRENT_LAYER_FACE",
        "candidate_dt_day":DT,
        "status":overall,
        "failures":failures,
        "max_abs_water_ledger_cm":maxledger,
        "max_corrector_iterations":maxiter,
        "histories":result if overall=="QUALIFIED" and len(result)==4 else None,
    }


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--purpose",required=True,choices=("GW_LB","SURF_P"))
    ap.add_argument("--material",required=True,choices=("B01","B14"))
    ap.add_argument("--member",required=True,choices=tuple(PARTITIONS))
    ap.add_argument("--p4-prereg",required=True,type=pathlib.Path)
    ap.add_argument("--metric-contract",required=True,type=pathlib.Path)
    ap.add_argument("--p4-reference-result",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.p4_prereg.read_text())
    metric=json.loads(a.metric_contract.read_text())
    p4ref=json.loads(a.p4_reference_result.read_text())

    assert pre["phase"]=="PREREGISTERED_BEFORE_ANY_P4_REFERENCE_LAYER_ROM_OR_MATCHED_RICHARDS_RESPONSE"
    assert metric["status"]=="FROZEN_BEFORE_ANY_P1_REFERENCE_RESPONSE"
    assert p4ref["status"]=="P4_REFERENCE_QUALIFIED_CANDIDATES_AUTHORIZED"
    assert p4ref["candidate_response_authorized"] is True

    reps=pre["frozen_representations"]
    if a.member.startswith("S"):
        expected=reps["SURF_P"][a.member]
    elif a.member.startswith("G"):
        expected=reps["GW_LB"][a.member]
    assert [float(x) for x in expected]==PARTITIONS[a.member]
    assert pre["layer_rom_execution"]["closure"]=="CURRENT_LAYER_FACE"
    assert a.member in pre["layer_rom_execution"]["matrix"][a.purpose]

    candidate=run_candidate(a.purpose,a.material,a.member)
    out={
      "schema":"swap5.rom-purpose.p4.layer-candidate.v1",
      "workstream":"ROM-PURPOSE",
      "work_unit":"ROM-PURPOSE-P4-CANDIDATE",
      "candidate":candidate,
      "authority":{
        "surface_reference":"P4 fresh S17-S20",
        "groundwater_reference":"P4 fresh G17-G20",
        "P3_closed_not_reopened":True
      },
      "scientific_firewall":{
        "P4_reference_qualified_before_response":True,
        "representation_changed_after_reference_response":False,
        "closure_changed":False,
        "application_acceptance_adjudicated":False,
        "performance_comparison_authorized":False,
        "production_rom_authorized":False
      },
      "model_changed":False
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "purpose":a.purpose,"material":a.material,"member":a.member,
      "status":candidate["status"],
      "max_abs_water_ledger_cm":candidate["max_abs_water_ledger_cm"]
    },sort_keys=True))


if __name__=="__main__":
    main()
