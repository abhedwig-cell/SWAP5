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
HISTORIES=("S05","S06","S07","S08")
ROUTES=("R512_T32","R1024_T32","R2048_T32","R2048_T16","R2048_T8")
MASS_GATE=1.0e-12
U=2.0**-53
REVERSALS=(256,512,768)
WINDOWS=((128,384),(384,640),(640,896))
PHASES={
    "S05":("WET","DRY","WET","DRY"),
    "S06":("DRY","WET","DRY","WET"),
    "S07":("WET","DRY","WET","DRY"),
    "S08":("DRY","WET","DRY","WET"),
}

def fields(line:str)->dict[str,str]:
    out={}
    for x in line.split("|")[1:]:
        if "=" in x:
            k,v=x.split("=",1); out[k]=v
    return out

def factor(route:str)->int:
    return int(route.rsplit("_T",1)[1])

def nodes(route:str)->int:
    return int(route.split("_",1)[0][1:])

def gamma(k:int)->float:
    ku=k*U
    if ku>=1.0:
        raise RuntimeError(f"invalid gamma argument {k}")
    return ku/(1.0-ku)

def fp_bound(values,operations:int):
    x=np.asarray(values,dtype=float)
    return gamma(operations)*np.abs(x)+0.5*np.abs(np.spacing(x))

def rmse(values)->float:
    x=np.asarray(values,dtype=float)
    return float(np.sqrt(np.mean(np.square(x))))

def parse_surface(path:pathlib.Path,route:str):
    f=factor(route); n=nodes(route)
    states={h:{} for h in HISTORIES}
    profiles={h:{} for h in HISTORIES}
    maxmass=0.0
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("LAREDYN0R_STATE|"):
            r=fields(line); h=r.get("CASE")
            if h in states:
                states[h][int(r["STEP"])]=r
                if "MASS" in r:
                    maxmass=max(maxmass,abs(float(r["MASS"])))
        elif line.startswith("LAREDYN0R_PROFILE|"):
            r=fields(line); h=r.get("CASE")
            if h in profiles:
                profiles[h].setdefault(int(r["OBS_STEP"]),{})[int(r["BIN"])]=float(r["THETA"])
        elif line.startswith("LAREDYN0R_MAX_ABS_MASS="):
            maxmass=max(maxmass,abs(float(line.split("=",1)[1])))
    out={}
    nbin=n//16
    for h in HISTORIES:
        expected=NOBS*f
        if sorted(states[h])!=list(range(1,expected+1)):
            raise RuntimeError(f"{path}: surface state coverage {h} {len(states[h])}/{expected}")
        theta=[]; total=[]
        for obs in range(1,NOBS+1):
            bins=profiles[h].get(obs,{})
            if sorted(bins)!=list(range(1,17)):
                raise RuntimeError(f"{path}: surface profile coverage {h} obs={obs}")
            p=np.asarray([bins[i] for i in range(1,17)],float)
            theta.append(p)
            total.append(float(states[h][obs*f]["TOTAL_STORAGE"]))
        theta=np.asarray(theta)
        total=np.asarray(total)
        surf=np.sum(theta[:,:2],axis=1)*10.0
        root=np.sum(theta[:,:4],axis=1)*10.0
        upper=np.sum(theta[:,:8],axis=1)*10.0
        theta_bound=fp_bound(theta,2*nbin+4)
        surf_bound=fp_bound(surf,2*(n//8)+8)
        root_bound=fp_bound(root,2*(n//4)+12)
        upper_bound=fp_bound(upper,2*(n//2)+20)
        total_bound=fp_bound(total,2*n+4)
        out[h]={
            "theta":theta,"theta_bound":theta_bound,
            "surface":surf,"surface_bound":surf_bound,
            "root":root,"root_bound":root_bound,
            "upper":upper,"upper_bound":upper_bound,
            "total":total,"total_bound":total_bound,
        }
    return {"histories":out,"max_abs_mass_cm":maxmass,"nodes":n}

def admissible_extremum(y,b,lo:int,hi:int,kind:str):
    # lo/hi are inclusive 1-based observation indices.
    ys=np.asarray(y[lo-1:hi],float)
    bs=np.asarray(b[lo-1:hi],float)
    idx=np.arange(lo,hi+1,dtype=int)
    if kind=="MAX":
        best_lower=float(np.max(ys-bs))
        keep=(ys+bs)>=best_lower
    elif kind=="MIN":
        best_upper=float(np.min(ys+bs))
        keep=(ys-bs)<=best_upper
    else:
        raise ValueError(kind)
    adm=idx[keep]
    if adm.size==0:
        raise RuntimeError("empty admissible extremum set")
    return adm

def set_distance(a,b)->int:
    aa=np.asarray(a,dtype=int); bb=np.asarray(b,dtype=int)
    if np.intersect1d(aa,bb).size:
        return 0
    return int(np.min(np.abs(aa[:,None]-bb[None,:])))

def compare_surface(a,b):
    spec=(
        ("surface_0_20_storage_rmse_cm","surface","surface_bound"),
        ("root_0_40_storage_rmse_cm","root","root_bound"),
        ("upper_0_80_storage_rmse_cm","upper","upper_bound"),
        ("mapped_10cm_theta_rmse","theta","theta_bound"),
        ("total_storage_rmse_cm","total","total_bound"),
    )
    vals={name:[] for name,_,_ in spec}
    floors={name:[] for name,_,_ in spec}
    timing=[]
    unobservable=[]
    for h in HISTORIES:
        aa=a["histories"][h]; bb=b["histories"][h]
        for name,key,bkey in spec:
            vals[name].append((aa[key]-bb[key]).ravel())
            floors[name].append((aa[bkey]+bb[bkey]).ravel())
        phases=PHASES[h]
        for key,bkey in (("root","root_bound"),("upper","upper_bound")):
            for event,(rev,window) in enumerate(zip(REVERSALS,WINDOWS),start=1):
                kind="MAX" if phases[event-1]=="WET" and phases[event]=="DRY" else "MIN"
                aset=admissible_extremum(aa[key],aa[bkey],window[0],window[1],kind)
                bset=admissible_extremum(bb[key],bb[bkey],window[0],window[1],kind)
                aw=int(aset[-1]-aset[0]); bw=int(bset[-1]-bset[0])
                observable=(aw<=2 and bw<=2)
                rec={
                    "history":h,"storage":key,"event":event,"forcing_reversal_observation":rev,
                    "kind":kind,"left_admissible":[int(x) for x in aset],
                    "right_admissible":[int(x) for x in bset],
                    "left_width_steps":aw,"right_width_steps":bw,
                    "observable":bool(observable),
                    "timing_distance_steps":set_distance(aset,bset)
                }
                timing.append(rec)
                if not observable:
                    unobservable.append(rec)
    continuous={
        name:{
            "error":rmse(np.concatenate(vals[name])),
            "indistinguishability_floor":rmse(np.concatenate(floors[name]))
        } for name,_,_ in spec
    }
    observable_records=[x for x in timing if x["observable"]]
    return {
        "continuous":continuous,
        "timing_events":timing,
        "unobservable_event_count":len(unobservable),
        "max_timing_ambiguity_width_steps":max(
            [max(x["left_width_steps"],x["right_width_steps"]) for x in timing] or [0]),
        "max_storage_extremum_timing_difference_steps":max(
            [x["timing_distance_steps"] for x in observable_records] or [0])
    }

def axis(coarse:float,fine:float,coarse_floor:float,fine_floor:float):
    finite=all(math.isfinite(x) and x>=0.0 for x in (coarse,fine,coarse_floor,fine_floor))
    if not finite:
        return {
            "qualified":False,"coarse":coarse,"fine":fine,
            "coarse_indistinguishability_floor":coarse_floor,
            "fine_indistinguishability_floor":fine_floor,
            "observed_order":None,"fine_uncertainty":None,"reason":"NONFINITE"
        }
    if coarse<=coarse_floor and fine<=fine_floor:
        return {
            "qualified":True,"coarse":coarse,"fine":fine,
            "coarse_indistinguishability_floor":coarse_floor,
            "fine_indistinguishability_floor":fine_floor,
            "observed_order":None,"fine_uncertainty":fine_floor,
            "reason":"QUALIFIED_NUMERICALLY_INDISTINGUISHABLE"
        }
    if coarse>0.0 and fine>0.0 and fine<coarse:
        p=math.log(coarse/fine,2.0)
        den=2.0**p-1.0
        if math.isfinite(p) and p>0.0 and math.isfinite(den) and den>0.0:
            return {
                "qualified":True,"coarse":coarse,"fine":fine,
                "coarse_indistinguishability_floor":coarse_floor,
                "fine_indistinguishability_floor":fine_floor,
                "observed_order":p,"fine_uncertainty":1.25*fine/den,
                "reason":"QUALIFIED_MONOTONE_THREE_LEVEL"
            }
    return {
        "qualified":False,"coarse":coarse,"fine":fine,
        "coarse_indistinguishability_floor":coarse_floor,
        "fine_indistinguishability_floor":fine_floor,
        "observed_order":None,"fine_uncertainty":None,
        "reason":"NONMONOTONE_OR_RESOLVED_FAILURE"
    }

def qualify_surface(material:str,root:pathlib.Path):
    routes={}
    for route in ROUTES:
        p=root/f"surface_{material}_{route}_o0.txt"
        routes[route]=parse_surface(p,route)
    sc=compare_surface(routes["R512_T32"],routes["R1024_T32"])
    sf=compare_surface(routes["R1024_T32"],routes["R2048_T32"])
    tc=compare_surface(routes["R2048_T8"],routes["R2048_T16"])
    tf=compare_surface(routes["R2048_T16"],routes["R2048_T32"])
    metrics={}
    for name in sc["continuous"]:
        sa=axis(
            sc["continuous"][name]["error"],sf["continuous"][name]["error"],
            sc["continuous"][name]["indistinguishability_floor"],sf["continuous"][name]["indistinguishability_floor"])
        ta=axis(
            tc["continuous"][name]["error"],tf["continuous"][name]["error"],
            tc["continuous"][name]["indistinguishability_floor"],tf["continuous"][name]["indistinguishability_floor"])
        metrics[name]={
            "space":sa,"time":ta,
            "combined_reference_uncertainty":(
                sa["fine_uncertainty"]+ta["fine_uncertainty"]
                if sa["qualified"] and ta["qualified"] else None),
            "qualified":bool(sa["qualified"] and ta["qualified"])
        }
    discrete={
        "spatial_unobservable_event_count":sf["unobservable_event_count"],
        "temporal_unobservable_event_count":tf["unobservable_event_count"],
        "spatial_max_timing_ambiguity_width_steps":sf["max_timing_ambiguity_width_steps"],
        "temporal_max_timing_ambiguity_width_steps":tf["max_timing_ambiguity_width_steps"],
        "spatial_max_storage_extremum_timing_difference_steps":sf["max_storage_extremum_timing_difference_steps"],
        "temporal_max_storage_extremum_timing_difference_steps":tf["max_storage_extremum_timing_difference_steps"],
    }
    discrete_pass=(
        discrete["spatial_unobservable_event_count"]==0 and
        discrete["temporal_unobservable_event_count"]==0 and
        discrete["spatial_max_timing_ambiguity_width_steps"]<=2 and
        discrete["temporal_max_timing_ambiguity_width_steps"]<=2 and
        discrete["spatial_max_storage_extremum_timing_difference_steps"]<=1 and
        discrete["temporal_max_storage_extremum_timing_difference_steps"]<=1
    )
    maxmass=max(v["max_abs_mass_cm"] for v in routes.values())
    passed=(maxmass<=MASS_GATE and discrete_pass and all(x["qualified"] for x in metrics.values()))
    return {
        "qualified":bool(passed),
        "metrics":metrics,
        "discrete_guard":discrete,
        "discrete_guard_pass":bool(discrete_pass),
        "timing_event_diagnostics":{"spatial":sf["timing_events"],"temporal":tf["timing_events"]},
        "max_abs_transaction_mass_cm":maxmass,
        "reference_target":"R2048_T32"
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--p1-reference",required=True,type=pathlib.Path)
    ap.add_argument("--root",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    pre=json.loads(a.prereg.read_text())
    p1=json.loads(a.p1_reference.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_ANY_P2_REFERENCE_OR_CANDIDATE_RESPONSE"
    assert p1["status"]=="P1_REFERENCE_NOT_QUALIFIED_STOP_BEFORE_CANDIDATES"
    inherited_gw=all(p1["results"]["gw"][m]["qualified"] for m in ("B01","B14"))
    assert inherited_gw
    assert p1["candidate_response_authorized"] is False
    results={m:qualify_surface(m,a.root) for m in ("B01","B14")}
    surface_ok=all(results[m]["qualified"] for m in results)
    qualified=bool(inherited_gw and surface_ok)
    status=(
        "P2_REFERENCE_QUALIFIED_CANDIDATES_AUTHORIZED"
        if qualified else "P2_REFERENCE_NOT_QUALIFIED_STOP_BEFORE_CANDIDATES"
    )
    out={
        "schema":"swap5.rom-purpose.p2.reference-result.v1",
        "workstream":"ROM-PURPOSE","work_unit":"ROM-PURPOSE-P2-REFERENCE",
        "status":status,"candidate_response_authorized":qualified,
        "inherited_groundwater_reference":{
            "source":"P1","B01":True,"B14":True,"qualified":True
        },
        "fresh_surface_reference":results,
        "interpretation":{
            "P1_failure_overridden":False,
            "numerical_indistinguishability_is_application_tolerance":False,
            "placement_or_closure_adjudicated":False,
            "candidate_response_generated":False
        },
        "scientific_firewall":{
            "P1_surface_histories_reused":False,
            "candidate_response_generated":False,
            "representation_tuned_from_response":False,
            "observability_threshold_fitted_to_response":False,
            "application_acceptance_adjudicated":False,
            "performance_comparison_authorized":False,
            "production_rom_authorized":False
        }
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "status":status,"qualified":qualified,
        "surface":{m:results[m]["qualified"] for m in results},
        "inherited_gw":inherited_gw
    },sort_keys=True))
    return 0 if qualified else 3

if __name__=="__main__":
    raise SystemExit(main())
