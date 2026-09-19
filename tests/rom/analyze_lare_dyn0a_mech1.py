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

PARTITIONS={
    "D3":[0.0,140.0,150.0,160.0],
    "D4":[0.0,130.0,140.0,150.0,160.0],
}
SE_BY_INDEX={1:0.65,2:0.85,3:0.95}
FORCING_BY_INDEX={1:"EQ",2:"WET",3:"DRY",4:"WET_DRY"}
HIGH_STATE_CASES={"S2_B1_F2","S2_B1_F3","S2_B1_F4","S3_B1_F3"}


def fields(payload:str)->dict[str,str]:
    out={}
    for item in payload.split("|"):
        if "=" in item:
            k,v=item.split("=",1); out[k]=v
    return out


def k_from_h(h:float)->float:
    if not h < -0.01:
        raise ValueError(f"MECH1 requires strict unsaturated branch, got h={h}")
    se=(1.0+(ALPHA*abs(h))**N)**(-M)
    return KS*(se**LAM)*(1.0-(1.0-se**(1.0/M))**M)**2


def psi_from_theta(theta:float)->float:
    se=(theta-TR)/(TS-TR)
    if not (0.0 < se < 1.0):
        raise ValueError(f"invalid mean Se={se}")
    return ((se**(-1.0/M)-1.0)**(1.0/N))/ALPHA


def k_from_theta(theta:float)->float:
    se=(theta-TR)/(TS-TR)
    if not (0.0 < se < 1.0):
        raise ValueError(f"invalid mean Se={se}")
    return KS*(se**LAM)*(1.0-(1.0-se**(1.0/M))**M)**2


def load_case(path:pathlib.Path)->dict[int,list[dict[str,float]]]:
    rows=defaultdict(list)
    for line in path.read_text(errors="replace").splitlines():
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
        raise ValueError(f"incomplete Reference case {path}: {len(rows)} steps")
    for step in rows:
        rows[step].sort(key=lambda x:x["node"])
        if [r["node"] for r in rows[step]]!=list(range(1,17)):
            raise ValueError(f"incomplete nodes at {path} step {step}")
    return dict(rows)


def overlap(a0,a1,b0,b1):
    return max(0.0,min(a1,b1)-max(a0,b0))


def layer_stats(rows:list[dict[str,float]], bounds:list[float]):
    result=[]
    for lo,hi in zip(bounds,bounds[1:]):
        width=hi-lo
        covered=0.0
        theta_int=0.0
        psi_int=0.0
        k_int=0.0
        for row in rows:
            center=abs(row["z"])
            top=center-0.5*row["dz"]
            bottom=center+0.5*row["dz"]
            w=overlap(lo,hi,top,bottom)
            if w<=0.0:
                continue
            kval=k_from_h(row["h"])
            covered+=w
            theta_int+=row["theta"]*w
            psi_int+=(-row["h"])*w
            k_int+=kval*w
        if abs(covered-width)>1e-9:
            raise ValueError(f"layer coverage drift {lo}-{hi}: {covered}")
        theta_bar=theta_int/width
        result.append({
            "dz":width,
            "theta_bar":theta_bar,
            "psi_standard":psi_from_theta(theta_bar),
            "k_standard":k_from_theta(theta_bar),
            "psi_exact_mean":psi_int/width,
            "k_exact_mean":k_int/width,
        })
    return result


def interface_rows(rows:list[dict[str,float]], bounds:list[float]):
    layers=layer_stats(rows,bounds)
    output=[]
    for i,boundary in enumerate(bounds[1:-1]):
        up=layers[i]; lo=layers[i+1]
        du=up["dz"]; dl=lo["dz"]
        center_distance=0.5*(du+dl)

        k_standard=(dl*up["k_standard"]+du*lo["k_standard"])/(du+dl)
        q_standard=k_standard*(1.0+(lo["psi_standard"]-up["psi_standard"])/center_distance)

        k_layer_mean=(dl*up["k_exact_mean"]+du*lo["k_exact_mean"])/(du+dl)
        q_exact_layer_means=k_layer_mean*(1.0+(lo["psi_exact_mean"]-up["psi_exact_mean"])/center_distance)

        upper_node=int(round(boundary/10.0))
        lower_node=upper_node+1
        ru=rows[upper_node-1]
        rl=rows[lower_node-1]
        if abs(abs(ru["z"])-(boundary-5.0))>1e-9 or abs(abs(rl["z"])-(boundary+5.0))>1e-9:
            raise ValueError(f"fine interface geometry mismatch at {boundary}")

        k_face=0.5*(k_from_h(ru["h"])+k_from_h(rl["h"]))
        q_local_k_mean_gradient=k_face*(1.0+(lo["psi_exact_mean"]-up["psi_exact_mean"])/center_distance)
        q_reference=k_face*(1.0+((-rl["h"])-(-ru["h"]))/(0.5*(ru["dz"]+rl["dz"])))

        e_const=q_standard-q_exact_layer_means
        e_k=q_exact_layer_means-q_local_k_mean_gradient
        e_grad=q_local_k_mean_gradient-q_reference
        e_total=q_standard-q_reference
        identity=e_total-(e_const+e_k+e_grad)

        output.append({
            "interface_cm":boundary,
            "q_standard_cm_per_day":q_standard,
            "q_exact_layer_means_cm_per_day":q_exact_layer_means,
            "q_local_K_mean_gradient_cm_per_day":q_local_k_mean_gradient,
            "q_reference_cm_per_day":q_reference,
            "E_constitutive_cm_per_day":e_const,
            "E_K_localization_cm_per_day":e_k,
            "E_gradient_cm_per_day":e_grad,
            "E_total_cm_per_day":e_total,
            "identity_residual_cm_per_day":identity,
        })
    return output


def rms(values):
    return math.sqrt(sum(v*v for v in values)/len(values)) if values else 0.0


def summarize_block(rows):
    comps=["E_constitutive_cm_per_day","E_K_localization_cm_per_day","E_gradient_cm_per_day"]
    total=[r["E_total_cm_per_day"] for r in rows]
    max_row=max(rows,key=lambda r:abs(r["E_total_cm_per_day"]))
    return {
        "sample_count":len(rows),
        "rms_total_flux_error_cm_per_day":rms(total),
        "max_abs_total_flux_error_cm_per_day":max(abs(v) for v in total),
        "component_rms_cm_per_day":{c:rms([r[c] for r in rows]) for c in comps},
        "max_error_step":max_row["step"],
        "max_error_time_day":max_row["step"]*0.0008,
        "components_at_max_error_cm_per_day":{c:max_row[c] for c in comps},
        "total_at_max_error_cm_per_day":max_row["E_total_cm_per_day"],
    }


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference-dir",required=True,type=pathlib.Path)
    ap.add_argument("--status",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    prereg=json.loads(args.prereg.read_text())
    if prereg["phase"]!="PREREGISTERED_BEFORE_INTERFACE_FLUX_DECOMPOSITION":
        raise SystemExit("wrong MECH1 preregistration phase")
    if not prereg["pre_execution_operationalization"]["before_first_MECH1_flux_result"]:
        raise SystemExit("MECH1 operationalization not frozen")

    status=json.loads(args.status.read_text())
    fine=status["geometries"]["fine"]
    qualified=[case for case,row in fine.items() if row["status"]=="QUALIFIED"]

    detailed={}
    max_identity=0.0
    pooled={p:{c:[] for c in ("E_constitutive_cm_per_day","E_K_localization_cm_per_day","E_gradient_cm_per_day","E_total_cm_per_day")} for p in PARTITIONS}

    for part,bounds in PARTITIONS.items():
        detailed[part]={}
        for case in sorted(qualified):
            m=re.fullmatch(r"S([123])_B1_F([1234])",case)
            if not m:
                raise ValueError(case)
            se0=SE_BY_INDEX[int(m.group(1))]
            forcing=FORCING_BY_INDEX[int(m.group(2))]
            trajectory=load_case(args.reference_dir/f"fine-{case}-o2.txt")
            by_interface=defaultdict(list)
            for step in range(1,1025):
                for row in interface_rows(trajectory[step],bounds):
                    row={**row,"step":step}
                    max_identity=max(max_identity,abs(row["identity_residual_cm_per_day"]))
                    by_interface[str(int(row["interface_cm"]))].append(row)
                    if case in HIGH_STATE_CASES:
                        for comp in pooled[part]:
                            pooled[part][comp].append(row[comp])
            detailed[part][case]={
                "se0":se0,
                "forcing":forcing,
                "high_state_dynamic_primary_cohort":case in HIGH_STATE_CASES,
                "interfaces":{
                    interface:summarize_block(rows)
                    for interface,rows in sorted(by_interface.items(),key=lambda kv:int(kv[0]))
                }
            }

    pooled_summary={}
    for part in PARTITIONS:
        crms={
            c:rms(pooled[part][c])
            for c in ("E_constitutive_cm_per_day","E_K_localization_cm_per_day","E_gradient_cm_per_day")
        }
        largest=max(crms,key=crms.get)
        pooled_summary[part]={
            "sample_count":len(pooled[part]["E_total_cm_per_day"]),
            "component_rms_cm_per_day":crms,
            "rms_total_flux_error_cm_per_day":rms(pooled[part]["E_total_cm_per_day"]),
            "max_abs_total_flux_error_cm_per_day":max(abs(x) for x in pooled[part]["E_total_cm_per_day"]),
            "largest_component_rms":largest,
        }

    # Check component dominance at every active D3 high-state case/interface block.
    d3_dominants=[]
    for case in sorted(HIGH_STATE_CASES):
        for interface,block in detailed["D3"][case]["interfaces"].items():
            comps=block["component_rms_cm_per_day"]
            if max(comps.values()) <= 1e-12:
                continue
            d3_dominants.append({
                "case":case,
                "interface_cm":int(interface),
                "largest_component":max(comps,key=comps.get),
                "component_rms_cm_per_day":comps,
            })

    unique={row["largest_component"] for row in d3_dominants}
    pooled_largest=pooled_summary["D3"]["largest_component_rms"]
    if unique=={"E_gradient_cm_per_day"} and pooled_largest=="E_gradient_cm_per_day":
        decision="GRADIENT_RECONSTRUCTION_DOMINANT"
    elif unique=={"E_constitutive_cm_per_day"} and pooled_largest=="E_constitutive_cm_per_day":
        decision="CONSTITUTIVE_AVERAGING_DOMINANT"
    elif unique=={"E_K_localization_cm_per_day"} and pooled_largest=="E_K_localization_cm_per_day":
        decision="INTERFACE_LOCALIZATION_DOMINANT"
    else:
        decision="MIXED_CLOSURE_ERROR"

    result={
        "schema":"swap5.lare.dyn0a.mech1.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-DYN0A-MECH1",
        "decision":decision,
        "qualified_reference_cases":sorted(qualified),
        "high_state_dynamic_primary_cohort":sorted(HIGH_STATE_CASES),
        "decomposition_identity_max_abs_residual_cm_per_day":max_identity,
        "pooled_high_state_dynamic":pooled_summary,
        "D3_active_block_dominance":d3_dominants,
        "cases":detailed,
        "interpretation_firewall":[
            "Flux decomposition is evaluated on exact projected fine-Reference states, not on propagated LARE states.",
            "No closure parameter is fitted and no layer boundary is changed.",
            "Component RMS values diagnose operator error and are not application acceptance thresholds."
        ],
        "lare_state_propagated":False,
        "closure_modified":False,
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "schema":result["schema"],
        "decision":decision,
        "decomposition_identity_max_abs_residual_cm_per_day":max_identity,
        "pooled_high_state_dynamic":pooled_summary,
        "D3_active_block_dominance":d3_dominants,
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
