#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, pathlib
import numpy as np

OBS_DT=0.0008
NOBS=1024
HISTORIES=("U01","U02","U03","U04")
BINS=16

def fields(line):
    out={}
    for item in line.split("|")[1:]:
        if "=" in item:
            k,v=item.split("=",1); out[k]=v
    return out

def factor_from_route(route):
    if route.endswith("_T16"): return 16
    if route.endswith("_T8"): return 8
    raise ValueError(route)

def parse(path,route):
    factor=factor_from_route(route)
    states={h:{} for h in HISTORIES}; profiles={h:{} for h in HISTORIES}
    max_abs_mass=0.0
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("LAREDYN0R_STATE|"):
            r=fields(line); h=r.get("CASE")
            if h in states:
                step=int(r["STEP"])
                states[h][step]={"total":float(r["TOTAL_STORAGE"]),"mass":float(r["MASS"])}
                max_abs_mass=max(max_abs_mass,abs(float(r["MASS"])))
        elif line.startswith("LAREDYN0R_PROFILE|"):
            r=fields(line); h=r.get("CASE")
            if h in profiles:
                obs=int(r["OBS_STEP"]); b=int(r["BIN"])
                profiles[h].setdefault(obs,{})[b]=float(r["THETA"])
    out={}
    for h in HISTORIES:
        exp=NOBS*factor
        if sorted(states[h])!=list(range(1,exp+1)):
            raise RuntimeError(f"{route} {h} state coverage {len(states[h])}/{exp}")
        if sorted(profiles[h])!=list(range(1,NOBS+1)):
            raise RuntimeError(f"{route} {h} profile coverage {len(profiles[h])}/{NOBS}")
        total=[]; surf20=[]; root40=[]; upper80=[]; theta=[]
        pmax=0.0
        for obs in range(1,NOBS+1):
            bins=profiles[h][obs]
            if sorted(bins)!=list(range(1,BINS+1)):
                raise RuntimeError(f"{route} {h} obs {obs} incomplete profile")
            prof=np.array([bins[i] for i in range(1,BINS+1)],dtype=float)
            t=float(states[h][obs*factor]["total"])
            ptotal=float(np.sum(prof)*10.0)
            pmax=max(pmax,abs(ptotal-t))
            total.append(t); surf20.append(float(np.sum(prof[:2])*10.0))
            root40.append(float(np.sum(prof[:4])*10.0))
            upper80.append(float(np.sum(prof[:8])*10.0)); theta.append(prof)
        out[h]={
          "total_storage_cm":np.asarray(total),
          "surface_0_20_storage_cm":np.asarray(surf20),
          "root_zone_0_40_storage_cm":np.asarray(root40),
          "upper_0_80_storage_cm":np.asarray(upper80),
          "theta_10cm":np.asarray(theta),
          "profile_state_total_max_abs_difference_cm":pmax
        }
    return {"histories":out,"max_abs_transaction_mass_cm":max_abs_mass}

def rmse(x): return float(np.sqrt(np.mean(np.square(np.asarray(x,dtype=float)))))

def compare(a,b):
    keys=[
      ("total_storage_cm","total_storage_rmse_cm"),
      ("surface_0_20_storage_cm","surface_0_20_storage_rmse_cm"),
      ("root_zone_0_40_storage_cm","root_zone_0_40_storage_rmse_cm"),
      ("upper_0_80_storage_cm","upper_0_80_storage_rmse_cm"),
      ("theta_10cm","mapped_10cm_theta_rmse"),
    ]
    pooled={out:[] for _,out in keys}; by_history={}
    for h in HISTORIES:
        hr={}
        for src,out in keys:
            d=a["histories"][h][src]-b["histories"][h][src]
            hr[out]=rmse(d); pooled[out].append(d.ravel())
        by_history[h]=hr
    return {"pooled":{k:rmse(np.concatenate(v)) for k,v in pooled.items()},"by_history":by_history}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    for material in ("b01","b14"):
        for route in ("r512-t16","r1024-t16","r2048-t16","r2048-t8"):
            ap.add_argument(f"--{material}-{route}",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    p=json.loads(a.prereg.read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_C6M2_REFERENCE_RESPONSE"
    tol=float(p["quality_gate"]["equality_tolerance_numeric"])
    mass_gate=float(p["integrity_gates"]["max_abs_transaction_mass_cm"])
    consistency=float(p["integrity_gates"]["profile_state_total_consistency_cm"])

    materials={}; integrity=True
    for material in ("B01","B14"):
        ml=material.lower(); routes={}
        for route in ("R512_T16","R1024_T16","R2048_T16","R2048_T8"):
            arg=f"{ml}_{route.lower().replace('_','_')}"
            path=getattr(a,arg)
            routes[route]=parse(path,route)
            integrity &= routes[route]["max_abs_transaction_mass_cm"]<=mass_gate
            integrity &= all(routes[route]["histories"][h]["profile_state_total_max_abs_difference_cm"]<=consistency for h in HISTORIES)
        target=routes["R2048_T16"]
        c512=compare(routes["R512_T16"],target)
        c1024=compare(routes["R1024_T16"],target)
        t8=compare(routes["R2048_T8"],target)
        flags={k:float(t8["pooled"][k])<=float(c1024["pooled"][k])+tol for k in t8["pooled"]}
        materials[material]={
          "reference_quality_pass":all(flags.values()),
          "temporal_vs_R1024_componentwise":flags,
          "R512_T16_vs_R2048_T16":c512,
          "R1024_T16_vs_R2048_T16":c1024,
          "R2048_T8_vs_R2048_T16":t8,
          "max_abs_transaction_mass_cm":max(v["max_abs_transaction_mass_cm"] for v in routes.values()),
          "max_profile_state_total_difference_cm":max(routes[r]["histories"][h]["profile_state_total_max_abs_difference_cm"] for r in routes for h in HISTORIES)
        }
    qualified=bool(integrity and all(v["reference_quality_pass"] for v in materials.values()))
    status="C6M2_SURFACE_FIXED_FLUX_REFERENCE_QUALIFIED" if qualified else "C6M2_SURFACE_FIXED_FLUX_REFERENCE_NUMERICAL_QUALITY_BLOCKED"
    decision="AUTHORIZE_C6N_BLIND_EXISTING_REPRESENTATION_UPPER_ZONE_PROFILE_COMPARISON" if qualified else "STOP_BEFORE_LAYER_ROM_RESPONSE"
    out={
      "schema":"swap5.lare.bc2.c6m2.result.v1","workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C6M2",
      "status":status,"decision":decision,"integrity_pass":bool(integrity),"materials":materials,
      "interpretation_boundary":"Bottom flux is prescribed and excluded from fidelity adjudication.",
      "scientific_firewall":{
        "candidate_response_generated":False,"bottom_exchange_fidelity_adjudicated":False,
        "root_uptake_feedback_used":False,"new_representation_selected":False,
        "application_acceptance_adjudicated":False,"performance_comparison_authorized":False,
        "production_rom_authorized":False
      },"model_changed":False
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"status":status,"decision":decision,"integrity":integrity,
      "quality":{m:{"pass":v["reference_quality_pass"],"R1024":v["R1024_T16_vs_R2048_T16"]["pooled"],"T8":v["R2048_T8_vs_R2048_T16"]["pooled"]} for m,v in materials.items()}},sort_keys=True))
if __name__=="__main__": main()
