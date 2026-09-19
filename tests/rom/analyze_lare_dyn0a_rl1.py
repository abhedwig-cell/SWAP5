#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib
import re
from collections import defaultdict

TR=0.02
TS=0.427494
ALPHA=0.021659
N=1.734737
M=1.0-1.0/N
KS=31.225016
LAM=0.98087

D3_BOUNDS=[0.0,140.0,150.0,160.0]
SE_BY_INDEX={1:0.65,2:0.85,3:0.95}
FORCING_BY_INDEX={1:"EQ",2:"WET",3:"DRY",4:"WET_DRY"}
CRITICAL_CASE="S3_B1_F3"
HIGH_STATE={"S2_B1_F2","S2_B1_F3","S2_B1_F4","S3_B1_F3"}


def fields(payload:str)->dict[str,str]:
    out={}
    for item in payload.split("|"):
        if "=" in item:
            k,v=item.split("=",1); out[k]=v
    return out


def k_from_h(h:float)->float:
    if not h < -0.01:
        raise ValueError(f"strict branch required, h={h}")
    se=(1.0+(ALPHA*abs(h))**N)**(-M)
    return KS*(se**LAM)*(1.0-(1.0-se**(1.0/M))**M)**2


def psi_k_from_theta(theta:float)->tuple[float,float]:
    se=(theta-TR)/(TS-TR)
    if not 0.0 < se < 1.0:
        raise ValueError(f"invalid Se={se}")
    psi=((se**(-1.0/M)-1.0)**(1.0/N))/ALPHA
    k=KS*(se**LAM)*(1.0-(1.0-se**(1.0/M))**M)**2
    return psi,k


def case_meta(case_id:str):
    m=re.fullmatch(r"S([123])_B1_F([1234])",case_id)
    if not m:
        raise ValueError(case_id)
    return SE_BY_INDEX[int(m.group(1))],FORCING_BY_INDEX[int(m.group(2))]


def lare_case_id(member:str,ref_case:str)->str:
    se,forcing=case_meta(ref_case)
    return f"{member}_SE{int(round(100*se)):03d}_FIXED_FLUX_{forcing}"


def load_ref(path:pathlib.Path):
    rows=defaultdict(list)
    for line in path.open(errors="replace"):
        if not line.startswith("LAREDYN0R_NODE|"):
            continue
        d=fields(line.split("|",1)[1])
        rows[int(d["STEP"])].append({
            "node":int(d["NODE"]),
            "z":float(d["Z"]),
            "dz":float(d["DZ"]),
            "h":float(d["H"]),
            "theta":float(d["THETA"]),
        })
    if set(rows)!=set(range(1,1025)):
        raise SystemExit(f"incomplete Reference trajectory {path}")
    for step in rows:
        rows[step].sort(key=lambda r:r["node"])
        if [r["node"] for r in rows[step]]!=list(range(1,17)):
            raise SystemExit(f"incomplete nodes {path} step {step}")
    return rows


def overlap(a0,a1,b0,b1):
    return max(0.0,min(a1,b1)-max(a0,b0))


def project(rows,bounds):
    out=[]
    for lo,hi in zip(bounds,bounds[1:]):
        storage=0.0; covered=0.0
        for row in rows:
            c=abs(row["z"]); top=c-0.5*row["dz"]; bot=c+0.5*row["dz"]
            w=overlap(lo,hi,top,bot)
            storage+=row["theta"]*w
            covered+=w
        if abs(covered-(hi-lo))>1e-9:
            raise SystemExit(f"coverage drift {lo}-{hi}: {covered}")
        out.append(storage)
    return out


def fine_d3_series(rows_by_step):
    return [project(rows_by_step[s],D3_BOUNDS) for s in range(1,1025)]


def member_to_d3_series(case:dict,bounds:list[float]):
    raw=case["finest_reference"]["layer_storage_cm"]
    if len(raw)!=1025:
        raise SystemExit("unexpected LARE trajectory length")
    out=[]
    for row in raw[1:]:
        first=0.0; second=None; third=None
        for value,lo,hi in zip(row,bounds,bounds[1:]):
            if hi<=140.0+1e-12:
                first+=float(value)
            elif abs(lo-140.0)<=1e-12 and abs(hi-150.0)<=1e-12:
                second=float(value)
            elif abs(lo-150.0)<=1e-12 and abs(hi-160.0)<=1e-12:
                third=float(value)
        if second is None or third is None:
            raise SystemExit(f"member does not preserve D3 lower bands: {bounds}")
        out.append([first,second,third])
    return out


def storage_metrics(candidate,reference):
    diffs=[[c-r for c,r in zip(cr,rr)] for cr,rr in zip(candidate,reference)]
    flat=[abs(v) for row in diffs for v in row]
    return {
        "max_abs_common_band_storage_cm":max(flat),
        "mean_abs_common_band_storage_cm":sum(flat)/len(flat),
        "max_abs_140_150_storage_cm":max(abs(row[1]) for row in diffs),
        "max_abs_150_160_storage_cm":max(abs(row[2]) for row in diffs),
        "final_signed_common_band_storage_cm":diffs[-1],
    }


def layer_theta(rows,lo,hi):
    storage=project(rows,[lo,hi])[0]
    return storage/(hi-lo)


def standard_flux_error_at_long_interface(rows,bounds):
    boundary=bounds[1]
    long_lo,long_hi=bounds[0],bounds[1]
    local_lo,local_hi=bounds[1],bounds[2]
    tu=layer_theta(rows,long_lo,long_hi)
    tl=layer_theta(rows,local_lo,local_hi)
    psi_u,k_u=psi_k_from_theta(tu)
    psi_l,k_l=psi_k_from_theta(tl)
    du=long_hi-long_lo; dl=local_hi-local_lo
    k_face_lare=(dl*k_u+du*k_l)/(du+dl)
    q_lare=k_face_lare*(1.0+2.0*(psi_l-psi_u)/(du+dl))

    upper_node=int(round(boundary/10.0))
    lower_node=upper_node+1
    ru=rows[upper_node-1]; rl=rows[lower_node-1]
    if abs(abs(ru["z"])-(boundary-5.0))>1e-9 or abs(abs(rl["z"])-(boundary+5.0))>1e-9:
        raise SystemExit(f"fine interface geometry drift at {boundary}")
    k_ref=0.5*(k_from_h(ru["h"])+k_from_h(rl["h"]))
    q_ref=k_ref*(1.0+((-rl["h"])-(-ru["h"]))/(0.5*(ru["dz"]+rl["dz"])))
    return q_lare-q_ref


def rms(values):
    return math.sqrt(sum(v*v for v in values)/len(values)) if values else 0.0


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--rl1",required=True,type=pathlib.Path)
    ap.add_argument("--reference-dir",required=True,type=pathlib.Path)
    ap.add_argument("--reference-status",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    prereg=json.loads(args.prereg.read_text())
    assert prereg["phase"]=="PREREGISTERED_BEFORE_NESTED_RESOLUTION_LADDER_EXECUTION"
    tol=float(prereg["pre_execution_numerical_equality"]["storage_error_abs_cm"])
    rl1=json.loads(args.rl1.read_text())
    status=json.loads(args.reference_status.read_text())["geometries"]["fine"]
    ladder=[row["id"] for row in prereg["ladder"]]
    bounds={row["id"]:[float(x) for x in row["boundaries_cm"]] for row in prereg["ladder"]}

    fine_cache={}
    member_rows={}
    mechanism={}

    for member in ladder:
        cases=[]
        excluded=[]
        mech_all=[]
        mech_high=[]
        for ref_case in sorted(status):
            lid=lare_case_id(member,ref_case)
            lcase=rl1["cases"][lid]
            if status[ref_case]["status"]!="QUALIFIED" or lcase["status"]!="QUALIFIED":
                excluded.append({
                    "reference_case":ref_case,
                    "fine_status":status[ref_case]["status"],
                    "lare_status":lcase["status"],
                })
                continue
            if ref_case not in fine_cache:
                fine_cache[ref_case]=load_ref(args.reference_dir/f"fine-{ref_case}-o2.txt")
            ref_nodes=fine_cache[ref_case]
            ref_series=fine_d3_series(ref_nodes)
            cand=member_to_d3_series(lcase,bounds[member])
            metrics=storage_metrics(cand,ref_series)
            se0,forcing=case_meta(ref_case)
            cases.append({
                "reference_case":ref_case,
                "se0":se0,
                "forcing":forcing,
                "error":metrics,
            })
            if forcing!="EQ":
                vals=[
                    standard_flux_error_at_long_interface(ref_nodes[s],bounds[member])
                    for s in range(1,1025)
                ]
                mech_all.extend(vals)
                if ref_case in HIGH_STATE:
                    mech_high.extend(vals)
        dynamic=[row for row in cases if row["forcing"]!="EQ"]
        member_rows[member]={
            "dimension":len(bounds[member])-1,
            "boundaries_cm":bounds[member],
            "long_layer_thickness_cm":bounds[member][1]-bounds[member][0],
            "qualified_case_count":len(cases),
            "qualified_dynamic_case_count":len(dynamic),
            "excluded_cases":excluded,
            "cases":cases,
            "aggregate":{
                "maximum_dynamic_common_band_error_cm":max(
                    (r["error"]["max_abs_common_band_storage_cm"] for r in dynamic),
                    default=None
                ),
                "mean_of_case_mean_dynamic_error_cm":(
                    sum(r["error"]["mean_abs_common_band_storage_cm"] for r in dynamic)/len(dynamic)
                    if dynamic else None
                ),
            }
        }
        critical=next((r for r in cases if r["reference_case"]==CRITICAL_CASE),None)
        member_rows[member]["critical_Se095_DRY_max_error_cm"]=(
            critical["error"]["max_abs_common_band_storage_cm"] if critical else None
        )
        mechanism[member]={
            "interface_cm":bounds[member][1],
            "long_layer_thickness_cm":bounds[member][1],
            "dynamic_all":{
                "sample_count":len(mech_all),
                "rms_flux_error_cm_per_day":rms(mech_all),
                "max_abs_flux_error_cm_per_day":max((abs(v) for v in mech_all),default=None),
            },
            "MECH1_high_state":{
                "sample_count":len(mech_high),
                "rms_flux_error_cm_per_day":rms(mech_high),
                "max_abs_flux_error_cm_per_day":max((abs(v) for v in mech_high),default=None),
            }
        }

    adjacent=[]
    monotone=True
    for lower,higher in zip(ladder[:-1],ladder[1:]):
        lo_cases={r["reference_case"]:r for r in member_rows[lower]["cases"] if r["forcing"]!="EQ"}
        hi_cases={r["reference_case"]:r for r in member_rows[higher]["cases"] if r["forcing"]!="EQ"}
        common=sorted(set(lo_cases)&set(hi_cases))
        violations=[]
        strict=0
        for cid in common:
            lo=lo_cases[cid]["error"]; hi=hi_cases[cid]["error"]
            max_ok=hi["max_abs_common_band_storage_cm"] <= lo["max_abs_common_band_storage_cm"] + tol
            mean_ok=hi["mean_abs_common_band_storage_cm"] <= lo["mean_abs_common_band_storage_cm"] + tol
            if not (max_ok and mean_ok):
                violations.append({
                    "case":cid,
                    "lower_max_cm":lo["max_abs_common_band_storage_cm"],
                    "higher_max_cm":hi["max_abs_common_band_storage_cm"],
                    "lower_mean_cm":lo["mean_abs_common_band_storage_cm"],
                    "higher_mean_cm":hi["mean_abs_common_band_storage_cm"],
                })
            if (
                hi["max_abs_common_band_storage_cm"] < lo["max_abs_common_band_storage_cm"]-tol
                or hi["mean_abs_common_band_storage_cm"] < lo["mean_abs_common_band_storage_cm"]-tol
            ):
                strict+=1
        if violations:
            monotone=False
        adjacent.append({
            "lower":lower,
            "higher":higher,
            "common_dynamic_case_count":len(common),
            "noninferior_all_max_and_mean":not violations,
            "strict_improvement_case_count":strict,
            "violations":violations,
        })

    critical_curve=[
        {
            "member":m,
            "dimension":member_rows[m]["dimension"],
            "max_error_cm":member_rows[m]["critical_Se095_DRY_max_error_cm"],
        }
        for m in ladder
        if member_rows[m]["critical_Se095_DRY_max_error_cm"] is not None
    ]
    for a,b in zip(critical_curve[:-1],critical_curve[1:]):
        if b["max_error_cm"] > a["max_error_cm"] + tol:
            monotone=False

    decision="RESOLUTION_CONVERGENCE_CLEAR" if monotone else "RESOLUTION_EFFECT_NONMONOTONE"
    result={
        "schema":"swap5.lare.dyn0a.rl1.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-DYN0A-RL1",
        "decision":decision,
        "floating_equality_abs_cm":tol,
        "members":member_rows,
        "adjacent_resolution_checks":adjacent,
        "critical_Se095_DRY_curve":critical_curve,
        "mechanism_curve":mechanism,
        "interpretation_firewall":[
            "RL1 measures the complete error-versus-dimension curve and does not choose an acceptable dimension.",
            "R16 is a no-spatial-reduction control, not a ROM candidate.",
            "The LARE closure is unchanged for every member.",
            "Coarse-Richards numerical blocking is not used as evidence of LARE superiority."
        ],
        "application_acceptance_adjudicated":False,
        "speed_claim":False,
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "schema":result["schema"],
        "decision":decision,
        "curve":[{
            "member":m,
            "dimension":member_rows[m]["dimension"],
            "max_dynamic_error_cm":member_rows[m]["aggregate"]["maximum_dynamic_common_band_error_cm"],
            "mean_case_mean_error_cm":member_rows[m]["aggregate"]["mean_of_case_mean_dynamic_error_cm"],
            "critical_error_cm":member_rows[m]["critical_Se095_DRY_max_error_cm"],
            "high_state_flux_rms_cm_per_day":mechanism[m]["MECH1_high_state"]["rms_flux_error_cm_per_day"],
        } for m in ladder]
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
