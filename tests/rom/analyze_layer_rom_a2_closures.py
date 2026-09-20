#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib
import re
from collections import defaultdict

import numpy as np
from numpy.polynomial.legendre import leggauss
from scipy.optimize import least_squares

TR=0.02
TS=0.427494
ALPHA=0.021659
N=1.734737
M=1.0-1.0/N
KS=31.225016
LAM=0.98087
PSI_MIN=0.010000001
GL_X,GL_W=leggauss(16)

PARTITIONS={
    "L3":[0.0,140.0,150.0,160.0],
    "L4":[0.0,130.0,140.0,150.0,160.0],
}
PRIMARY_CASES={"S2_B1_F2","S2_B1_F3","S2_B1_F4","S3_B1_F3"}
CLOSURES=("C_LARE_TAYLOR","C_DARCY_HARMONIC","C_HEAD_LINEAR")


def fields(payload:str)->dict[str,str]:
    out={}
    for item in payload.split("|"):
        if "=" in item:
            k,v=item.split("=",1)
            out[k]=v
    return out


def theta_from_psi(psi):
    psi=np.asarray(psi,dtype=float)
    se=np.power(1.0+np.power(ALPHA*psi,N),-M)
    return TR+(TS-TR)*se


def psi_from_theta(theta:float)->float:
    se=(theta-TR)/(TS-TR)
    if not 0.0 < se < 1.0:
        raise ValueError(f"invalid mean Se={se}")
    return ((se**(-1.0/M)-1.0)**(1.0/N))/ALPHA


def k_from_psi(psi):
    psi=np.asarray(psi,dtype=float)
    se=np.power(1.0+np.power(ALPHA*psi,N),-M)
    term=1.0-np.power(1.0-np.power(se,1.0/M),M)
    return KS*np.power(se,LAM)*np.square(term)


def k_from_theta(theta:float)->float:
    return float(k_from_psi(psi_from_theta(theta)))


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


def layer_theta(rows:list[dict[str,float]],bounds:list[float])->list[float]:
    result=[]
    for lo,hi in zip(bounds,bounds[1:]):
        width=hi-lo
        covered=0.0
        theta_int=0.0
        for row in rows:
            center=abs(row["z"])
            top=center-0.5*row["dz"]
            bottom=center+0.5*row["dz"]
            w=overlap(lo,hi,top,bottom)
            if w<=0.0:
                continue
            covered+=w
            theta_int+=row["theta"]*w
        if abs(covered-width)>1e-9:
            raise ValueError(f"layer coverage drift {lo}-{hi}: {covered}")
        result.append(theta_int/width)
    return result


def reference_flux(rows:list[dict[str,float]],boundary:float)->float:
    upper_node=int(round(boundary/10.0))
    lower_node=upper_node+1
    ru=rows[upper_node-1]
    rl=rows[lower_node-1]
    if abs(abs(ru["z"])-(boundary-5.0))>1e-9 or abs(abs(rl["z"])-(boundary+5.0))>1e-9:
        raise ValueError(f"fine interface geometry mismatch at {boundary}")
    ku=float(k_from_psi(-ru["h"]))
    kl=float(k_from_psi(-rl["h"]))
    kface=0.5*(ku+kl)
    return kface*(1.0+((-rl["h"])-(-ru["h"]))/10.0)


def q_lare(theta_u:float,theta_l:float,du:float,dl:float)->float:
    pu=psi_from_theta(theta_u)
    pl=psi_from_theta(theta_l)
    ku=k_from_theta(theta_u)
    kl=k_from_theta(theta_l)
    kface=(dl*ku+du*kl)/(du+dl)
    return kface*(1.0+2.0*(pl-pu)/(du+dl))


def q_harmonic(theta_u:float,theta_l:float,du:float,dl:float)->float:
    pu=psi_from_theta(theta_u)
    pl=psi_from_theta(theta_l)
    ku=k_from_theta(theta_u)
    kl=k_from_theta(theta_l)
    kface=(du+dl)/(du/ku+dl/kl)
    return kface*(1.0+2.0*(pl-pu)/(du+dl))


def avg_theta_linear(ptop:float,pbottom:float,z0:float,z1:float,du:float,dl:float)->float:
    z=0.5*(z1-z0)*GL_X+0.5*(z1+z0)
    psi=ptop+(z+du)/(du+dl)*(pbottom-ptop)
    if np.any(psi<=PSI_MIN):
        raise ValueError("HEAD_LINEAR_OUTSIDE_STRICT_UNSATURATED_DOMAIN")
    return float(0.5*np.sum(GL_W*theta_from_psi(psi)))


def q_head_linear(theta_u:float,theta_l:float,du:float,dl:float)->tuple[float,float,int]:
    pu=psi_from_theta(theta_u)
    pl=psi_from_theta(theta_l)
    slope0=2.0*(pl-pu)/(du+dl)
    interface0=pu+slope0*du/2.0
    ptop=max(PSI_MIN*1.001,interface0-slope0*du)
    pbottom=max(PSI_MIN*1.001,interface0+slope0*dl)
    x0=np.log([ptop-PSI_MIN,pbottom-PSI_MIN])

    def residual(x):
        p0,p1=PSI_MIN+np.exp(x)
        return np.asarray([
            (avg_theta_linear(p0,p1,-du,0.0,du,dl)-theta_u)/(TS-TR),
            (avg_theta_linear(p0,p1,0.0,dl,du,dl)-theta_l)/(TS-TR),
        ])

    sol=least_squares(
        residual,x0,xtol=1e-12,ftol=1e-12,gtol=1e-12,max_nfev=100
    )
    r=residual(sol.x)
    storage_residual=float(np.max(np.abs(r))*(TS-TR))
    if not sol.success or storage_residual>1e-11:
        raise RuntimeError(
            f"HEAD_LINEAR_RECONSTRUCTION_FAIL success={sol.success} residual={storage_residual}"
        )
    ptop,pbottom=PSI_MIN+np.exp(sol.x)
    pinterface=ptop+du/(du+dl)*(pbottom-ptop)
    slope=(pbottom-ptop)/(du+dl)
    if min(ptop,pinterface,pbottom)<=PSI_MIN:
        raise ValueError("HEAD_LINEAR_OUTSIDE_STRICT_UNSATURATED_DOMAIN")
    q=float(k_from_psi(pinterface))*(1.0+slope)
    if not math.isfinite(q):
        raise FloatingPointError("HEAD_LINEAR_NONFINITE_FLUX")
    return q,storage_residual,int(sol.nfev)


def closure_flux(name:str,theta_u:float,theta_l:float,du:float,dl:float):
    if name=="C_LARE_TAYLOR":
        return q_lare(theta_u,theta_l,du,dl),0.0,0
    if name=="C_DARCY_HARMONIC":
        return q_harmonic(theta_u,theta_l,du,dl),0.0,0
    if name=="C_HEAD_LINEAR":
        return q_head_linear(theta_u,theta_l,du,dl)
    raise ValueError(name)


def sign(x:float)->int:
    return 1 if x>0.0 else (-1 if x<0.0 else 0)


def rms(values:list[float])->float:
    return math.sqrt(sum(v*v for v in values)/len(values)) if values else 0.0


def summarize(errors:list[float],sign_mismatch:int)->dict[str,float|int]:
    return {
        "sample_count":len(errors),
        "rms_error_cm_per_day":rms(errors),
        "max_abs_error_cm_per_day":max((abs(x) for x in errors),default=0.0),
        "mean_signed_error_cm_per_day":sum(errors)/len(errors) if errors else 0.0,
        "flux_sign_mismatch_count":sign_mismatch,
    }


def structural_tests()->dict[str,float]:
    theta=TR+0.7*(TS-TR)
    k=k_from_theta(theta)
    uniform={}
    for name in CLOSURES:
        q,res,_=closure_flux(name,theta,theta,140.0,10.0)
        uniform[name]=abs(q-k)
        if abs(q-k)>1e-10 or res>1e-11:
            raise SystemExit(f"uniform identity failed for {name}: q={q} K={k} res={res}")

    du,dl=140.0,10.0
    ptop,pbottom=80.0,20.0
    tu=avg_theta_linear(ptop,pbottom,-du,0.0,du,dl)
    tl=avg_theta_linear(ptop,pbottom,0.0,dl,du,dl)
    q,res,_=q_head_linear(tu,tl,du,dl)
    pinterface=ptop+du/(du+dl)*(pbottom-ptop)
    expected=float(k_from_psi(pinterface))*(1.0+(pbottom-ptop)/(du+dl))
    linear_error=abs(q-expected)
    if linear_error>1e-9 or res>1e-11:
        raise SystemExit(f"linear head identity failed: q={q} expected={expected} res={res}")
    return {
        "uniform_identity_max_abs_cm_per_day":max(uniform.values()),
        "head_linear_identity_abs_cm_per_day":linear_error,
    }


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference-dir",required=True,type=pathlib.Path)
    ap.add_argument("--status",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    prereg=json.loads(args.prereg.read_text())
    if prereg["phase"]!="PREREGISTERED_BEFORE_NEW_CLOSURE_FLUX_RESULTS":
        raise SystemExit("wrong A2 preregistration phase")
    if tuple(x["id"] for x in prereg["closures"])!=CLOSURES:
        raise SystemExit("closure list drift")
    tests=structural_tests()

    status=json.loads(args.status.read_text())["geometries"]["fine"]
    qualified=[case for case,row in status.items() if row["status"]=="QUALIFIED"]
    missing=PRIMARY_CASES-set(qualified)
    if missing:
        raise SystemExit(f"primary cases not qualified: {sorted(missing)}")

    all_errors={
        p:{c:[] for c in CLOSURES} for p in PARTITIONS
    }
    primary_errors={
        p:{c:[] for c in CLOSURES} for p in PARTITIONS
    }
    primary_sign={
        p:{c:0 for c in CLOSURES} for p in PARTITIONS
    }
    solve_failures={
        p:{c:0 for c in CLOSURES} for p in PARTITIONS
    }
    max_storage_residual=0.0
    max_nfev=0
    blocks={p:{} for p in PARTITIONS}

    for part,bounds in PARTITIONS.items():
        for case in sorted(qualified):
            trajectory=load_case(args.reference_dir/f"fine-{case}-o2.txt")
            block_errors={c:defaultdict(list) for c in CLOSURES}
            block_sign={c:defaultdict(int) for c in CLOSURES}
            for step in range(1,1025):
                theta=layer_theta(trajectory[step],bounds)
                for i,boundary in enumerate(bounds[1:-1]):
                    du=bounds[i+1]-bounds[i]
                    dl=bounds[i+2]-bounds[i+1]
                    qref=reference_flux(trajectory[step],boundary)
                    for closure in CLOSURES:
                        try:
                            q,res,nfev=closure_flux(closure,theta[i],theta[i+1],du,dl)
                        except (ValueError,RuntimeError,FloatingPointError,OverflowError):
                            solve_failures[part][closure]+=1
                            continue
                        max_storage_residual=max(max_storage_residual,res)
                        max_nfev=max(max_nfev,nfev)
                        err=q-qref
                        key=str(int(boundary))
                        block_errors[closure][key].append(err)
                        block_sign[closure][key]+=int(sign(q)!=sign(qref))
                        all_errors[part][closure].append(err)
                        if case in PRIMARY_CASES:
                            primary_errors[part][closure].append(err)
                            primary_sign[part][closure]+=int(sign(q)!=sign(qref))
            blocks[part][case]={}
            for closure in CLOSURES:
                blocks[part][case][closure]={
                    iface:summarize(values,block_sign[closure][iface])
                    for iface,values in sorted(block_errors[closure].items(),key=lambda x:int(x[0]))
                }

    if max_storage_residual>1e-11:
        raise SystemExit(f"storage reconstruction residual {max_storage_residual}")

    pooled={}
    for part in PARTITIONS:
        pooled[part]={}
        for closure in CLOSURES:
            pooled[part][closure]=summarize(
                primary_errors[part][closure],primary_sign[part][closure]
            )
            pooled[part][closure]["all_qualified_rms_error_cm_per_day"]=rms(all_errors[part][closure])
            pooled[part][closure]["closure_solve_failure_count"]=solve_failures[part][closure]

    baseline=pooled["L3"]["C_LARE_TAYLOR"]
    support={}
    for closure in ("C_DARCY_HARMONIC","C_HEAD_LINEAR"):
        row=pooled["L3"][closure]
        pooled_noninferior=(
            row["rms_error_cm_per_day"]<=baseline["rms_error_cm_per_day"]+1e-15
            and row["max_abs_error_cm_per_day"]<=baseline["max_abs_error_cm_per_day"]+1e-15
            and row["flux_sign_mismatch_count"]<=baseline["flux_sign_mismatch_count"]
        )
        strict=(
            row["rms_error_cm_per_day"]<baseline["rms_error_cm_per_day"]-1e-15
            or row["max_abs_error_cm_per_day"]<baseline["max_abs_error_cm_per_day"]-1e-15
            or row["flux_sign_mismatch_count"]<baseline["flux_sign_mismatch_count"]
        )
        block_ok=True
        for case in sorted(PRIMARY_CASES):
            for iface,base_block in blocks["L3"][case]["C_LARE_TAYLOR"].items():
                cand=blocks["L3"][case][closure][iface]
                if (
                    cand["rms_error_cm_per_day"]>base_block["rms_error_cm_per_day"]+1e-15
                    and cand["max_abs_error_cm_per_day"]>base_block["max_abs_error_cm_per_day"]+1e-15
                ):
                    block_ok=False
        support[closure]={
            "pooled_vector_noninferior":pooled_noninferior,
            "strictly_better_at_least_one_pooled_component":strict,
            "no_primary_block_worse_on_both_rms_and_max":block_ok,
            "storage_only_closure_improvement_supported":pooled_noninferior and strict and block_ok and solve_failures["L3"][closure]==0,
        }

    supported=[k for k,v in support.items() if v["storage_only_closure_improvement_supported"]]
    if supported:
        decision="STORAGE_ONLY_CLOSURE_IMPROVEMENT_SUPPORTED"
    else:
        decision="NO_STORAGE_ONLY_CLOSURE_CLEARS_FROZEN_A2_VECTOR"

    result={
        "schema":"swap5.layer-rom.phase-a2.result.v1",
        "workstream":"F-ROM-LAYER",
        "work_unit":"LAYER-ROM-A2",
        "decision":decision,
        "structural_tests":tests,
        "qualified_reference_cases":sorted(qualified),
        "primary_high_state_dynamic_cases":sorted(PRIMARY_CASES),
        "pooled_primary":pooled,
        "candidate_support":support,
        "primary_blocks":{
            p:{case:blocks[p][case] for case in sorted(PRIMARY_CASES)}
            for p in PARTITIONS
        },
        "numerical":{
            "max_head_linear_storage_reconstruction_residual_theta":max_storage_residual,
            "max_head_linear_nfev":max_nfev,
        },
        "interpretation_firewall":[
            "All candidate fluxes are teacher-forced from exact Reference-projected layer storage.",
            "No candidate state is propagated in A2.",
            "L3 and L4 partitions remain frozen from A1; no layer placement is selected from A2 response.",
            "No application tolerance or aggregate weighted score is used.",
        ],
        "next_rule":(
            "Propagate the supported storage-only closure under a separately preregistered fixed-flux dynamics gate."
            if supported else
            "Do not add an empirical correction. Reconcile whether a gradient/moment state or a different physical profile closure is justified before propagation."
        ),
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":decision,
        "structural_tests":tests,
        "L3_primary":pooled["L3"],
        "L4_primary":pooled["L4"],
        "candidate_support":support,
        "numerical":result["numerical"],
    },sort_keys=True))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
