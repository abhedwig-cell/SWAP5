#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib
import re

import numpy as np

OBS_DT=0.0008
NOBS=1024
SURF_H=("S01","S02","S03","S04")
GW_H=("G01","G02","G03","G04")
ROUTES=("R512_T32","R1024_T32","R2048_T32","R2048_T16","R2048_T8")
MASS_GATE=1.0e-12


def fields(line:str)->dict[str,str]:
    out={}
    for x in line.split("|")[1:]:
        if "=" in x:
            k,v=x.split("=",1); out[k]=v
    return out


def factor(route:str)->int:
    return int(route.rsplit("_T",1)[1])


def rmse(a)->float:
    x=np.asarray(a,dtype=float)
    return float(np.sqrt(np.mean(np.square(x))))


def parse_surface(path:pathlib.Path,route:str):
    f=factor(route)
    states={h:{} for h in SURF_H}
    profiles={h:{} for h in SURF_H}
    maxmass=0.0
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("LAREDYN0R_STATE|"):
            r=fields(line); h=r.get("CASE")
            if h in states:
                states[h][int(r["STEP"])]=r
                if "MASS" in r: maxmass=max(maxmass,abs(float(r["MASS"])))
        elif line.startswith("LAREDYN0R_PROFILE|"):
            r=fields(line); h=r.get("CASE")
            if h in profiles:
                profiles[h].setdefault(int(r["OBS_STEP"]),{})[int(r["BIN"])]=float(r["THETA"])
        elif line.startswith("LAREDYN0R_MAX_ABS_MASS="):
            maxmass=max(maxmass,abs(float(line.split("=",1)[1])))
    out={}
    for h in SURF_H:
        expected=NOBS*f
        if sorted(states[h])!=list(range(1,expected+1)):
            raise RuntimeError(f"{path}: surface state coverage {h} {len(states[h])}/{expected}")
        surf=[];root=[];upper=[];theta=[];total=[]
        for obs in range(1,NOBS+1):
            bins=profiles[h].get(obs,{})
            if sorted(bins)!=list(range(1,17)):
                raise RuntimeError(f"{path}: surface profile coverage {h} obs={obs}")
            p=np.asarray([bins[i] for i in range(1,17)],float)
            theta.append(p)
            surf.append(float(np.sum(p[:2])*10.0))
            root.append(float(np.sum(p[:4])*10.0))
            upper.append(float(np.sum(p[:8])*10.0))
            total.append(float(states[h][obs*f]["TOTAL_STORAGE"]))
        out[h]={
          "surface":np.asarray(surf),"root":np.asarray(root),"upper":np.asarray(upper),
          "theta":np.asarray(theta),"total":np.asarray(total)
        }
    return {"histories":out,"max_abs_mass_cm":maxmass}


def parse_gw(path:pathlib.Path,route:str):
    f=factor(route)
    states={h:{} for h in GW_H}
    profiles={h:{} for h in GW_H}
    maxmass=0.0
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("LAREGW1_STATE|"):
            r=fields(line); h=r.get("HISTORY")
            if h in states:
                states[h][int(r["STEP"])]=r
                if "MASS" in r: maxmass=max(maxmass,abs(float(r["MASS"])))
        elif line.startswith("LAREGW1_PROFILE|"):
            r=fields(line); h=r.get("HISTORY")
            if h in profiles:
                profiles[h].setdefault(int(r["OBS_STEP"]),{})[int(r["BIN"])]=float(r["THETA"])
        else:
            m=re.search(r"LAREGW1_MAX_ABS_MASS=([^\s]+)",line)
            if m: maxmass=max(maxmass,abs(float(m.group(1))))
    out={}
    for h in GW_H:
        expected=NOBS*f
        if sorted(states[h])!=list(range(1,expected+1)):
            raise RuntimeError(f"{path}: gw state coverage {h} {len(states[h])}/{expected}")
        total=[];cum=[];q=[];theta=[];cx=0.0
        for obs in range(1,NOBS+1):
            rows=[states[h][s] for s in range((obs-1)*f+1,obs*f+1)]
            ex=sum(float(r["BOTTOM_OUTWARD_EXCHANGE"]) for r in rows)
            cx+=ex
            total.append(float(rows[-1]["TOTAL_STORAGE"]))
            cum.append(cx); q.append(ex/OBS_DT)
            bins=profiles[h].get(obs,{})
            if sorted(bins)!=list(range(1,17)):
                raise RuntimeError(f"{path}: gw profile coverage {h} obs={obs}")
            theta.append([bins[i] for i in range(1,17)])
        out[h]={
          "total":np.asarray(total),"cum":np.asarray(cum),"q":np.asarray(q),
          "theta":np.asarray(theta)
        }
    return {"histories":out,"max_abs_mass_cm":maxmass}


def compare_surface(a,b):
    vals={"surface_0_20_storage_rmse_cm":[],"root_0_40_storage_rmse_cm":[],
          "upper_0_80_storage_rmse_cm":[],"mapped_10cm_theta_rmse":[],
          "total_storage_rmse_cm":[]}
    timing=[]
    for h in SURF_H:
        aa=a["histories"][h]; bb=b["histories"][h]
        vals["surface_0_20_storage_rmse_cm"].append((aa["surface"]-bb["surface"]).ravel())
        vals["root_0_40_storage_rmse_cm"].append((aa["root"]-bb["root"]).ravel())
        vals["upper_0_80_storage_rmse_cm"].append((aa["upper"]-bb["upper"]).ravel())
        vals["mapped_10cm_theta_rmse"].append((aa["theta"]-bb["theta"]).ravel())
        vals["total_storage_rmse_cm"].append((aa["total"]-bb["total"]).ravel())
        for key in ("root","upper"):
            for fn in (np.argmin,np.argmax):
                timing.append(abs(int(fn(aa[key]))-int(fn(bb[key]))))
    return {
      "continuous":{k:rmse(np.concatenate(v)) for k,v in vals.items()},
      "max_storage_extremum_timing_difference_steps":max(timing or [0])
    }


def reversals(x):
    a=np.asarray(x,float)
    s=np.sign(a)
    out=[]
    last=0
    for i,v in enumerate(s):
        if v==0: continue
        if last!=0 and v!=last: out.append(i+1)
        last=int(v)
    return out


def compare_gw(a,b):
    vals={"total_storage_rmse_cm":[],"cumulative_bottom_rmse_cm":[],
          "interval_bottom_flux_rmse_cm_per_day":[],"mapped_10cm_theta_rmse":[]}
    sign=0; rev_count=0; rev_timing=0
    for h in GW_H:
        aa=a["histories"][h]; bb=b["histories"][h]
        vals["total_storage_rmse_cm"].append((aa["total"]-bb["total"]).ravel())
        vals["cumulative_bottom_rmse_cm"].append((aa["cum"]-bb["cum"]).ravel())
        vals["interval_bottom_flux_rmse_cm_per_day"].append((aa["q"]-bb["q"]).ravel())
        vals["mapped_10cm_theta_rmse"].append((aa["theta"]-bb["theta"]).ravel())
        sign+=int(np.count_nonzero(np.sign(aa["q"])!=np.sign(bb["q"])))
        ra=reversals(aa["q"]); rb=reversals(bb["q"])
        if len(ra)!=len(rb):
            rev_count+=1
            rev_timing=max(rev_timing,NOBS)
        else:
            rev_timing=max(rev_timing,max([abs(x-y) for x,y in zip(ra,rb)] or [0]))
    return {
      "continuous":{k:rmse(np.concatenate(v)) for k,v in vals.items()},
      "bottom_flux_sign_mismatch_count":sign,
      "reversal_sequence_mismatch_history_count":rev_count,
      "max_reversal_timing_difference_steps":rev_timing
    }


def axis(coarse:float,fine:float):
    ok=math.isfinite(coarse) and math.isfinite(fine) and coarse>0.0 and fine>0.0 and fine<coarse
    if not ok:
        return {"qualified":False,"coarse":coarse,"fine":fine,"observed_order":None,
                "fine_uncertainty":None,"reason":"NONMONOTONE_OR_UNRESOLVED"}
    p=math.log(coarse/fine,2.0)
    den=2.0**p-1.0
    if not math.isfinite(p) or p<=0.0 or not math.isfinite(den) or den<=0.0:
        return {"qualified":False,"coarse":coarse,"fine":fine,"observed_order":p,
                "fine_uncertainty":None,"reason":"INVALID_OBSERVED_ORDER"}
    return {"qualified":True,"coarse":coarse,"fine":fine,"observed_order":p,
            "fine_uncertainty":1.25*fine/den,"reason":"QUALIFIED_MONOTONE_THREE_LEVEL"}


def qualify_purpose(kind:str,material:str,root:pathlib.Path):
    parser=parse_surface if kind=="surface" else parse_gw
    cmpfun=compare_surface if kind=="surface" else compare_gw
    routes={}
    for route in ROUTES:
        p=root/f"{kind}_{material}_{route}_o0.txt"
        routes[route]=parser(p,route)
    sc=cmpfun(routes["R512_T32"],routes["R1024_T32"])
    sf=cmpfun(routes["R1024_T32"],routes["R2048_T32"])
    tc=cmpfun(routes["R2048_T8"],routes["R2048_T16"])
    tf=cmpfun(routes["R2048_T16"],routes["R2048_T32"])
    metrics={}
    for m in sc["continuous"]:
        sa=axis(sc["continuous"][m],sf["continuous"][m])
        ta=axis(tc["continuous"][m],tf["continuous"][m])
        metrics[m]={"space":sa,"time":ta,
          "combined_reference_uncertainty":(sa["fine_uncertainty"]+ta["fine_uncertainty"])
             if sa["qualified"] and ta["qualified"] else None,
          "qualified":bool(sa["qualified"] and ta["qualified"])}
    if kind=="surface":
        discrete={
          "spatial_max_storage_extremum_timing_difference_steps":sf["max_storage_extremum_timing_difference_steps"],
          "temporal_max_storage_extremum_timing_difference_steps":tf["max_storage_extremum_timing_difference_steps"],
        }
        discrete_pass=all(v<=1 for v in discrete.values())
    else:
        discrete={
          "spatial_bottom_flux_sign_mismatch_count":sf["bottom_flux_sign_mismatch_count"],
          "temporal_bottom_flux_sign_mismatch_count":tf["bottom_flux_sign_mismatch_count"],
          "spatial_reversal_sequence_mismatch_history_count":sf["reversal_sequence_mismatch_history_count"],
          "temporal_reversal_sequence_mismatch_history_count":tf["reversal_sequence_mismatch_history_count"],
          "spatial_max_reversal_timing_difference_steps":sf["max_reversal_timing_difference_steps"],
          "temporal_max_reversal_timing_difference_steps":tf["max_reversal_timing_difference_steps"],
        }
        discrete_pass=(discrete["spatial_bottom_flux_sign_mismatch_count"]==0 and
          discrete["temporal_bottom_flux_sign_mismatch_count"]==0 and
          discrete["spatial_reversal_sequence_mismatch_history_count"]==0 and
          discrete["temporal_reversal_sequence_mismatch_history_count"]==0 and
          discrete["spatial_max_reversal_timing_difference_steps"]<=1 and
          discrete["temporal_max_reversal_timing_difference_steps"]<=1)
    maxmass=max(v["max_abs_mass_cm"] for v in routes.values())
    passed=(maxmass<=MASS_GATE and discrete_pass and all(x["qualified"] for x in metrics.values()))
    return {
      "qualified":bool(passed),"metrics":metrics,"discrete_guard":discrete,
      "discrete_guard_pass":bool(discrete_pass),"max_abs_transaction_mass_cm":maxmass,
      "reference_target":"R2048_T32"
    }


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--root",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    pre=json.loads(a.prereg.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_ANY_P1_REFERENCE_OR_CANDIDATE_RESPONSE"
    results={}
    for kind in ("surface","gw"):
        results[kind]={}
        for material in ("B01","B14"):
            results[kind][material]=qualify_purpose(kind,material,a.root)
    qualified=all(results[k][m]["qualified"] for k in results for m in results[k])
    status="P1_REFERENCE_QUALIFIED_CANDIDATES_AUTHORIZED" if qualified else "P1_REFERENCE_NOT_QUALIFIED_STOP_BEFORE_CANDIDATES"
    out={
      "schema":"swap5.rom-purpose.p1.reference-result.v1",
      "workstream":"ROM-PURPOSE","work_unit":"ROM-PURPOSE-P1-REFERENCE",
      "status":status,"candidate_response_authorized":bool(qualified),
      "results":results,
      "interpretation":{
        "reference_is_continuum_truth":False,
        "numerical_uncertainty_is_application_tolerance":False,
        "placement_or_closure_adjudicated":False
      },
      "scientific_firewall":{
        "candidate_response_generated":False,
        "representation_tuned_from_response":False,
        "application_acceptance_adjudicated":False,
        "performance_comparison_authorized":False,
        "production_rom_authorized":False
      }
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"status":status,"qualified":qualified,
      "summary":{k:{m:results[k][m]["qualified"] for m in results[k]} for k in results}},sort_keys=True))
    return 0 if qualified else 3


if __name__=="__main__":
    raise SystemExit(main())
