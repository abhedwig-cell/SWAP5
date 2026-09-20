#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib

import numpy as np

OBS_DT=0.0008
NOBS=1024
HISTORIES=("S01","S02","S03","S04")
BINS=16


def fields(line:str)->dict[str,str]:
    out={}
    for item in line.split("|")[1:]:
        if "=" in item:
            k,v=item.split("=",1)
            out[k]=v
    return out


def factor_from_route(route:str)->int:
    if route.endswith("_T16"):
        return 16
    if route.endswith("_T8"):
        return 8
    raise ValueError(route)


def parse(path:pathlib.Path,route:str)->dict[str,dict[str,np.ndarray]]:
    factor=factor_from_route(route)
    states={h:{} for h in HISTORIES}
    profiles={h:{} for h in HISTORIES}
    max_abs_mass=0.0

    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("LAREDYN0R_STATE|"):
            r=fields(line)
            h=r.get("CASE")
            if h not in states:
                continue
            step=int(r["STEP"])
            states[h][step]={
                "total":float(r["TOTAL_STORAGE"]),
                "bottom_exchange":float(r["BOTTOM_DOWNWARD_EXCHANGE"]),
                "bottom_flux":float(r["BOTTOM_DOWNWARD_FLUX"]),
                "mass":float(r["MASS"]),
            }
            max_abs_mass=max(max_abs_mass,abs(float(r["MASS"])))
        elif line.startswith("LAREDYN0R_PROFILE|"):
            r=fields(line)
            h=r.get("CASE")
            if h not in profiles:
                continue
            obs=int(r["OBS_STEP"])
            b=int(r["BIN"])
            profiles[h].setdefault(obs,{})[b]=float(r["THETA"])

    out={}
    for h in HISTORIES:
        expected_steps=NOBS*factor
        if sorted(states[h])!=list(range(1,expected_steps+1)):
            raise RuntimeError(f"{route} {h} state coverage mismatch: {len(states[h])}/{expected_steps}")
        if sorted(profiles[h])!=list(range(1,NOBS+1)):
            raise RuntimeError(f"{route} {h} profile observation coverage mismatch: {len(profiles[h])}/{NOBS}")
        for obs in range(1,NOBS+1):
            if sorted(profiles[h][obs])!=list(range(1,BINS+1)):
                raise RuntimeError(f"{route} {h} obs {obs} profile bins incomplete")

        total=[]
        cumulative=[]
        interval=[]
        theta=[]
        root40=[]
        upper80=[]
        running=0.0
        profile_state_max_diff=0.0

        for obs in range(1,NOBS+1):
            lo=(obs-1)*factor+1
            hi=obs*factor
            ex=sum(states[h][step]["bottom_exchange"] for step in range(lo,hi+1))
            running+=ex
            prof=np.asarray([profiles[h][obs][b] for b in range(1,BINS+1)],dtype=float)
            t=float(states[h][hi]["total"])
            ptotal=float(np.sum(prof)*10.0)
            profile_state_max_diff=max(profile_state_max_diff,abs(ptotal-t))
            total.append(t)
            cumulative.append(running)
            interval.append(ex/OBS_DT)
            theta.append(prof)
            root40.append(float(np.sum(prof[:4])*10.0))
            upper80.append(float(np.sum(prof[:8])*10.0))

        out[h]={
            "total_storage_cm":np.asarray(total),
            "cumulative_bottom_exchange_cm":np.asarray(cumulative),
            "interval_bottom_flux_cm_per_day":np.asarray(interval),
            "theta_10cm":np.asarray(theta),
            "root_zone_0_40_storage_cm":np.asarray(root40),
            "upper_0_80_storage_cm":np.asarray(upper80),
            "profile_state_total_max_abs_difference_cm":profile_state_max_diff,
        }

    return {
        "histories":out,
        "max_abs_transaction_mass_cm":max_abs_mass,
        "factor":factor,
    }


def rmse(x:np.ndarray)->float:
    return float(np.sqrt(np.mean(np.square(x))))


def compare(a:dict,b:dict)->dict[str,object]:
    diffs={
        "total_storage_rmse_cm":[],
        "root_zone_0_40_storage_rmse_cm":[],
        "upper_0_80_storage_rmse_cm":[],
        "cumulative_bottom_exchange_rmse_cm":[],
        "interval_bottom_flux_rmse_cm_per_day":[],
        "mapped_10cm_theta_rmse":[],
    }
    pooled={k:[] for k in diffs}
    signed_history=[]
    sign_mismatch=0
    by_history={}

    for h in HISTORIES:
        ah=a["histories"][h]
        bh=b["histories"][h]
        dtot=ah["total_storage_cm"]-bh["total_storage_cm"]
        dr40=ah["root_zone_0_40_storage_cm"]-bh["root_zone_0_40_storage_cm"]
        du80=ah["upper_0_80_storage_cm"]-bh["upper_0_80_storage_cm"]
        dcum=ah["cumulative_bottom_exchange_cm"]-bh["cumulative_bottom_exchange_cm"]
        dq=ah["interval_bottom_flux_cm_per_day"]-bh["interval_bottom_flux_cm_per_day"]
        dtheta=ah["theta_10cm"]-bh["theta_10cm"]

        vals={
            "total_storage_rmse_cm":rmse(dtot),
            "root_zone_0_40_storage_rmse_cm":rmse(dr40),
            "upper_0_80_storage_rmse_cm":rmse(du80),
            "cumulative_bottom_exchange_rmse_cm":rmse(dcum),
            "interval_bottom_flux_rmse_cm_per_day":rmse(dq),
            "mapped_10cm_theta_rmse":rmse(dtheta),
        }
        hm=int(np.count_nonzero(np.sign(ah["interval_bottom_flux_cm_per_day"])!=np.sign(bh["interval_bottom_flux_cm_per_day"])))
        bias=float(np.mean(dq))
        by_history[h]={**vals,"signed_bottom_flux_bias_cm_per_day":bias,"bottom_flux_sign_mismatch_count":hm}
        signed_history.append(abs(bias))
        sign_mismatch+=hm

        pooled["total_storage_rmse_cm"].append(dtot)
        pooled["root_zone_0_40_storage_rmse_cm"].append(dr40)
        pooled["upper_0_80_storage_rmse_cm"].append(du80)
        pooled["cumulative_bottom_exchange_rmse_cm"].append(dcum)
        pooled["interval_bottom_flux_rmse_cm_per_day"].append(dq)
        pooled["mapped_10cm_theta_rmse"].append(dtheta.ravel())

    result={}
    for key,arrays in pooled.items():
        result[key]=rmse(np.concatenate([np.asarray(x).ravel() for x in arrays]))
    result["mean_abs_history_signed_bottom_flux_error_cm_per_day"]=float(np.mean(signed_history))
    result["bottom_flux_sign_mismatch_count"]=int(sign_mismatch)
    return {"pooled":result,"by_history":by_history}


CONTINUOUS=(
    "total_storage_rmse_cm",
    "root_zone_0_40_storage_rmse_cm",
    "upper_0_80_storage_rmse_cm",
    "cumulative_bottom_exchange_rmse_cm",
    "interval_bottom_flux_rmse_cm_per_day",
    "mapped_10cm_theta_rmse",
    "mean_abs_history_signed_bottom_flux_error_cm_per_day",
)


def no_worse(temporal:dict,spatial:dict,tol:float)->tuple[bool,dict[str,bool]]:
    flags={k:float(temporal[k])<=float(spatial[k])+tol for k in CONTINUOUS}
    flags["bottom_flux_sign_mismatch_count"]=int(temporal["bottom_flux_sign_mismatch_count"])<=int(spatial["bottom_flux_sign_mismatch_count"])
    return all(flags.values()),flags


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    for material in ("b01","b14"):
        for route in ("r512-t16","r1024-t16","r2048-t16","r2048-t8"):
            ap.add_argument(f"--{material}-{route}",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_C6M_REFERENCE_RESPONSE"
    assert pre["scientific_firewall"]["candidate_response_generated"] is False
    tol=float(pre["quality_gate"]["equality_tolerance_numeric"])
    gate_mass=float(pre["integrity_gates"]["max_abs_transaction_mass_cm"])

    material_results={}
    integrity=True
    for material in ("B01","B14"):
        ml=material.lower()
        routes={}
        for route in ("R512_T16","R1024_T16","R2048_T16","R2048_T8"):
            key=route.lower().replace("_","-")
            p=getattr(a,f"{ml}_{key.replace('-','_')}")
            routes[route]=parse(p,route)
            integrity=integrity and routes[route]["max_abs_transaction_mass_cm"]<=gate_mass
            integrity=integrity and all(
                routes[route]["histories"][h]["profile_state_total_max_abs_difference_cm"]<=1e-9
                for h in HISTORIES
            )

        target=routes["R2048_T16"]
        c512=compare(routes["R512_T16"],target)
        c1024=compare(routes["R1024_T16"],target)
        t8=compare(routes["R2048_T8"],target)
        passed,flags=no_worse(t8["pooled"],c1024["pooled"],tol)
        material_results[material]={
            "reference_quality_pass":passed,
            "temporal_vs_R1024_componentwise":flags,
            "R512_T16_vs_R2048_T16":c512,
            "R1024_T16_vs_R2048_T16":c1024,
            "R2048_T8_vs_R2048_T16":t8,
            "max_abs_transaction_mass_cm":max(x["max_abs_transaction_mass_cm"] for x in routes.values()),
            "max_profile_state_total_difference_cm":max(
                routes[r]["histories"][h]["profile_state_total_max_abs_difference_cm"]
                for r in routes for h in HISTORIES
            ),
        }

    qualified=integrity and all(v["reference_quality_pass"] for v in material_results.values())
    status="C6M_SURFACE_REFERENCE_QUALIFIED" if qualified else "C6M_SURFACE_REFERENCE_NUMERICAL_QUALITY_BLOCKED"
    decision="AUTHORIZE_C6N_EXISTING_REPRESENTATION_SURFACE_BLIND_COMPARISON" if qualified else "STOP_BEFORE_LAYER_ROM_RESPONSE"

    out={
        "schema":"swap5.lare.bc2.c6m.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C6M",
        "status":status,
        "decision":decision,
        "integrity_pass":bool(integrity),
        "materials":material_results,
        "scientific_firewall":{
            "candidate_response_generated":False,
            "root_uptake_feedback_used":False,
            "new_closure_fit":False,
            "new_partition_selected":False,
            "application_acceptance_adjudicated":False,
            "performance_comparison_authorized":False,
            "speed_claim_authorized":False,
            "production_rom_authorized":False,
        },
        "model_changed":False,
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "status":status,
        "decision":decision,
        "integrity_pass":integrity,
        "quality":{m:{
            "pass":v["reference_quality_pass"],
            "temporal":v["R2048_T8_vs_R2048_T16"]["pooled"],
            "R1024":v["R1024_T16_vs_R2048_T16"]["pooled"],
        } for m,v in material_results.items()}
    },sort_keys=True))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
