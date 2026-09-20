#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib

import numpy as np

NOBS=1024
HISTORIES=("U01","U02","U03","U04")
BINS=16
METRICS=(
    "surface_0_20_storage_rmse_cm",
    "root_zone_0_40_storage_rmse_cm",
    "upper_0_80_storage_rmse_cm",
    "mapped_10cm_theta_rmse",
)


def fields(line:str)->dict[str,str]:
    out={}
    for item in line.split("|")[1:]:
        if "=" in item:
            k,v=item.split("=",1)
            out[k]=v
    return out


def factor_from_route(route:str)->int:
    for factor in (32,16,8):
        if route.endswith(f"_T{factor}"):
            return factor
    raise ValueError(route)


def parse(path:pathlib.Path,route:str)->dict[str,object]:
    factor=factor_from_route(route)
    states={h:{} for h in HISTORIES}
    profiles={h:{} for h in HISTORIES}
    max_abs_mass=0.0

    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("LAREDYN0R_STATE|"):
            r=fields(line)
            h=r.get("CASE")
            if h in states:
                step=int(r["STEP"])
                states[h][step]={
                    "total":float(r["TOTAL_STORAGE"]),
                    "mass":float(r["MASS"]),
                }
                max_abs_mass=max(max_abs_mass,abs(float(r["MASS"])))
        elif line.startswith("LAREDYN0R_PROFILE|"):
            r=fields(line)
            h=r.get("CASE")
            if h in profiles:
                obs=int(r["OBS_STEP"])
                b=int(r["BIN"])
                profiles[h].setdefault(obs,{})[b]=float(r["THETA"])

    histories={}
    for h in HISTORIES:
        expected=NOBS*factor
        if sorted(states[h]) != list(range(1,expected+1)):
            raise RuntimeError(f"{route} {h}: state coverage {len(states[h])}/{expected}")
        if sorted(profiles[h]) != list(range(1,NOBS+1)):
            raise RuntimeError(f"{route} {h}: profile coverage {len(profiles[h])}/{NOBS}")

        total=[]
        surf20=[]
        root40=[]
        upper80=[]
        theta=[]
        profile_state_diff=0.0
        for obs in range(1,NOBS+1):
            bins=profiles[h][obs]
            if sorted(bins) != list(range(1,BINS+1)):
                raise RuntimeError(f"{route} {h} obs {obs}: incomplete profile")
            prof=np.asarray([bins[i] for i in range(1,BINS+1)],dtype=float)
            t=float(states[h][obs*factor]["total"])
            ptotal=float(np.sum(prof)*10.0)
            profile_state_diff=max(profile_state_diff,abs(ptotal-t))
            total.append(t)
            surf20.append(float(np.sum(prof[:2])*10.0))
            root40.append(float(np.sum(prof[:4])*10.0))
            upper80.append(float(np.sum(prof[:8])*10.0))
            theta.append(prof)

        histories[h]={
            "total_storage_cm":np.asarray(total),
            "surface_0_20_storage_cm":np.asarray(surf20),
            "root_zone_0_40_storage_cm":np.asarray(root40),
            "upper_0_80_storage_cm":np.asarray(upper80),
            "theta_10cm":np.asarray(theta),
            "profile_state_total_max_abs_difference_cm":profile_state_diff,
        }

    return {
        "histories":histories,
        "max_abs_transaction_mass_cm":max_abs_mass,
    }


def rmse(x:np.ndarray)->float:
    return float(np.sqrt(np.mean(np.square(np.asarray(x,dtype=float)))))


def compare(a:dict[str,object],b:dict[str,object])->dict[str,float]:
    mapping=(
        ("surface_0_20_storage_cm","surface_0_20_storage_rmse_cm"),
        ("root_zone_0_40_storage_cm","root_zone_0_40_storage_rmse_cm"),
        ("upper_0_80_storage_cm","upper_0_80_storage_rmse_cm"),
        ("theta_10cm","mapped_10cm_theta_rmse"),
    )
    pooled={out:[] for _,out in mapping}
    for h in HISTORIES:
        ah=a["histories"][h]
        bh=b["histories"][h]
        for src,out in mapping:
            pooled[out].append((ah[src]-bh[src]).ravel())
    return {k:rmse(np.concatenate(v)) for k,v in pooled.items()}


def axis_uncertainty(coarse:float,fine:float)->dict[str,object]:
    finite=math.isfinite(coarse) and math.isfinite(fine)
    monotone=bool(finite and coarse>0.0 and fine>0.0 and fine<coarse)
    if not monotone:
        return {
            "qualified":False,
            "coarse_to_medium_norm":coarse,
            "medium_to_fine_norm":fine,
            "observed_order":None,
            "fine_GCI_style_uncertainty":None,
            "reason":"NONCONVERGENT_OR_NUMERICALLY_UNRESOLVED",
        }
    p=math.log(coarse/fine,2.0)
    if not math.isfinite(p) or p<=0.0:
        return {
            "qualified":False,
            "coarse_to_medium_norm":coarse,
            "medium_to_fine_norm":fine,
            "observed_order":p if math.isfinite(p) else None,
            "fine_GCI_style_uncertainty":None,
            "reason":"NONPOSITIVE_OR_NONFINITE_OBSERVED_ORDER",
        }
    denom=2.0**p-1.0
    if not math.isfinite(denom) or denom<=0.0:
        return {
            "qualified":False,
            "coarse_to_medium_norm":coarse,
            "medium_to_fine_norm":fine,
            "observed_order":p,
            "fine_GCI_style_uncertainty":None,
            "reason":"INVALID_RICHARDSON_DENOMINATOR",
        }
    u=1.25*fine/denom
    return {
        "qualified":True,
        "coarse_to_medium_norm":coarse,
        "medium_to_fine_norm":fine,
        "observed_order":p,
        "fine_GCI_style_uncertainty":u,
        "reason":"QUALIFIED_MONOTONE_THREE_LEVEL_CONVERGENCE",
    }


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    for material in ("b01","b14"):
        for route in ("r512-t32","r1024-t32","r2048-t32","r2048-t16","r2048-t8"):
            ap.add_argument(f"--{material}-{route}",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_C6N1_T32_REFERENCE_RESPONSE"
    mass_gate=float(pre["reference_design"]["max_abs_transaction_mass_cm"])
    consistency=1.0e-9

    materials={}
    integrity=True
    for material in ("B01","B14"):
        ml=material.lower()
        routes={}
        for route in ("R512_T32","R1024_T32","R2048_T32","R2048_T16","R2048_T8"):
            path=getattr(a,f"{ml}_{route.lower()}")
            routes[route]=parse(path,route)
            integrity &= routes[route]["max_abs_transaction_mass_cm"] <= mass_gate
            integrity &= all(
                routes[route]["histories"][h]["profile_state_total_max_abs_difference_cm"] <= consistency
                for h in HISTORIES
            )

        s_coarse=compare(routes["R512_T32"],routes["R1024_T32"])
        s_fine=compare(routes["R1024_T32"],routes["R2048_T32"])
        t_coarse=compare(routes["R2048_T8"],routes["R2048_T16"])
        t_fine=compare(routes["R2048_T16"],routes["R2048_T32"])

        metric_results={}
        for metric in METRICS:
            space=axis_uncertainty(s_coarse[metric],s_fine[metric])
            time=axis_uncertainty(t_coarse[metric],t_fine[metric])
            combined=None
            if space["qualified"] and time["qualified"]:
                combined=float(space["fine_GCI_style_uncertainty"]+time["fine_GCI_style_uncertainty"])
            metric_results[metric]={
                "space":space,
                "time":time,
                "combined_reference_uncertainty":combined,
                "qualified":bool(space["qualified"] and time["qualified"]),
            }

        material_pass=all(v["qualified"] for v in metric_results.values())
        materials[material]={
            "reference_uncertainty_pass":material_pass,
            "metrics":metric_results,
            "max_abs_transaction_mass_cm":max(routes[r]["max_abs_transaction_mass_cm"] for r in routes),
            "max_profile_state_total_difference_cm":max(
                routes[r]["histories"][h]["profile_state_total_max_abs_difference_cm"]
                for r in routes for h in HISTORIES
            ),
        }

    qualified=bool(integrity and all(v["reference_uncertainty_pass"] for v in materials.values()))
    status="C6N1_R2048_T32_REFERENCE_UNCERTAINTY_QUALIFIED" if qualified else "C6N1_REFERENCE_UNCERTAINTY_NOT_QUALIFIED"
    decision="AUTHORIZE_C6N2_EXISTING_REPRESENTATION_PROSPECTIVE_SURFACE_COMPARISON" if qualified else "STOP_BEFORE_LAYER_ROM_RESPONSE"

    out={
        "schema":"swap5.lare.bc2.c6n1.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C6N1",
        "status":status,
        "decision":decision,
        "integrity_pass":bool(integrity),
        "reference_target":"R2048_T32",
        "materials":materials,
        "interpretation":{
            "reference_is_continuum_truth":False,
            "application_tolerance_selected":False,
            "candidate_response_generated":False,
            "future_rule":"Candidate differences at or below the admitted combined numerical uncertainty are numerically unresolved."
        },
        "scientific_firewall":{
            "candidate_response_generated":False,
            "new_representation_selected":False,
            "application_acceptance_adjudicated":False,
            "performance_comparison_authorized":False,
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
        "materials":{m:{
            "pass":v["reference_uncertainty_pass"],
            "metrics":{k:{
                "pass":q["qualified"],
                "p_space":q["space"]["observed_order"],
                "p_time":q["time"]["observed_order"],
                "U_combined":q["combined_reference_uncertainty"],
            } for k,q in v["metrics"].items()}
        } for m,v in materials.items()}
    },sort_keys=True))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
