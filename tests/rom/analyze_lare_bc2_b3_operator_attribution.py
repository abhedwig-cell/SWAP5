#!/usr/bin/env python3
from __future__ import annotations

import argparse
import collections
import json
import math
import pathlib

import numpy as np

THETA_R=0.02
THETA_S=0.427494
ALPHA=0.021659
N_VG=1.734737
M_VG=1.0-1.0/N_VG
KS=31.225016
LAMBDA=0.98087
PROFILE_DEPTH=160.0
ANCHOR=90.0
FIXED_DZ=10.0
NFIXED=9
OBS_DT=0.0008
HDOT_EPS=1.0e-12
BALANCE_GATE=1.0e-10
QUAD_GATE=1.0e-10
HISTORY_STEPS={"WT_HOLD":256,"WT_RISE":512,"WT_FALL":512,"WT_CYCLE":768}
OPERATORS=("STANDARD_B0","RESIDUAL_ONLY_B2","PATH_PRESERVING_B1")

_GL64=np.polynomial.legendre.leggauss(64)
_GL128=np.polynomial.legendre.leggauss(128)


def fields(payload:str)->dict[str,str]:
    out={}
    for item in payload.split("|"):
        if "=" in item:
            k,v=item.split("=",1);out[k]=v
    return out


def load_reference(path:pathlib.Path):
    init_meta={}
    init_nodes=collections.defaultdict(dict)
    states={}
    nodes=collections.defaultdict(dict)
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("LAREBC2A2_INITIAL|"):
            r=fields(line.split("|",1)[1]);init_meta[r["HISTORY"]]={"total":float(r["TOTAL_STORAGE"])}
        elif line.startswith("LAREBC2A2_INITIAL_NODE|"):
            r=fields(line.split("|",1)[1]);init_nodes[r["HISTORY"]][int(r["NODE"])]={
                "z":float(r["Z"]),"h":float(r["H"]),"theta":float(r["THETA"])}
        elif line.startswith("LAREBC2A2_STATE|"):
            r=fields(line.split("|",1)[1]);states[(r["HISTORY"],int(r["STEP"]))]={
                "total":float(r["TOTAL_STORAGE"]),"bottom_exchange":float(r["BOTTOM_OUTWARD_EXCHANGE"])}
        elif line.startswith("LAREBC2A2_NODE|"):
            r=fields(line.split("|",1)[1]);nodes[(r["HISTORY"],int(r["STEP"]))][int(r["NODE"])]={
                "z":float(r["Z"]),"h":float(r["H"]),"theta":float(r["THETA"])}
    if set(init_meta)!=set(HISTORY_STEPS):
        raise RuntimeError("initial reference structure mismatch")
    for h,n in HISTORY_STEPS.items():
        if set(init_nodes[h])!=set(range(1,17)): raise RuntimeError(f"incomplete initial {h}")
        for step in range(1,n+1):
            if (h,step) not in states or set(nodes[(h,step)])!=set(range(1,17)):
                raise RuntimeError(f"incomplete reference {(h,step)}")
    return init_meta,init_nodes,states,nodes


def diagnose_H(profile)->float:
    crossings=[]
    for i in range(1,16):
        a,b=profile[i],profile[i+1]
        if a["h"]<0.0 and b["h"]>0.0:
            crossings.append(-(a["z"]+(-a["h"])*(b["z"]-a["z"])/(b["h"]-a["h"])))
    if len(crossings)!=1: raise ValueError(f"expected one crossing, got {crossings}")
    return crossings[0]


def theta_from_psi(psi):
    p=np.asarray(psi,dtype=float)
    se=np.power(1.0+np.power(ALPHA*p,N_VG),-M_VG)
    return THETA_R+(THETA_S-THETA_R)*se


def psi_k(theta):
    t=np.asarray(theta,dtype=float)
    se=(t-THETA_R)/(THETA_S-THETA_R)
    if np.any(se<=0.0) or np.any(se>=1.0) or np.any(~np.isfinite(se)):
        raise ValueError("projected state outside constitutive domain")
    psi=np.power(np.power(se,-1.0/M_VG)-1.0,1.0/N_VG)/ALPHA
    term=1.0-np.power(1.0-np.power(se,1.0/M_VG),M_VG)
    k=KS*np.power(se,LAMBDA)*np.square(term)
    return psi,k


def integrate_eq(z0,z1,H,nq):
    x,w=_GL64 if nq==64 else _GL128
    half=0.5*(z1-z0);mid=0.5*(z1+z0)
    z=mid+half*x
    return float(half*np.sum(w*theta_from_psi(H-z)))


def equilibrium_storage(H,nq=64):
    out=[integrate_eq(i*10.0,(i+1)*10.0,H,nq) for i in range(NFIXED)]
    out.append(integrate_eq(ANCHOR,H,H,nq))
    return np.asarray(out,dtype=float)


def standard_fluxes(storage,H):
    L=H-ANCHOR
    theta=np.concatenate([storage[:NFIXED]/FIXED_DZ,[storage[NFIXED]/L]])
    psi,k=psi_k(theta)
    q=np.empty(NFIXED,dtype=float)
    for i in range(NFIXED-1):
        q[i]=0.5*(k[i]+k[i+1])*(1.0+(psi[i+1]-psi[i])/FIXED_DZ)
    kij=(L*k[NFIXED-1]+FIXED_DZ*k[NFIXED])/(FIXED_DZ+L)
    q[NFIXED-1]=kij*(1.0+2.0*(psi[NFIXED]-psi[NFIXED-1])/(FIXED_DZ+L))
    qH=KS*(1.0-2.0*psi[NFIXED]/L)
    return q,qH


def required_eq_fluxes(H,Hdot):
    theta_surface=float(theta_from_psi(H))
    q=np.asarray([
        (float(theta_from_psi(H-(i+1)*FIXED_DZ))-theta_surface)*Hdot
        for i in range(NFIXED)
    ],dtype=float)
    qH=(THETA_S-theta_surface)*Hdot
    return q,qH


def operator_fluxes(storage,H,Hdot,operator):
    qs,qHs=standard_fluxes(storage,H)
    if operator=="STANDARD_B0":
        return qs,qHs
    eq=equilibrium_storage(H,64)
    qe,qHe=standard_fluxes(eq,H)
    qr=qs-qe;qHr=qHs-qHe
    if operator=="RESIDUAL_ONLY_B2":
        return qr,qHr
    if operator=="PATH_PRESERVING_B1":
        qp,qHp=required_eq_fluxes(H,Hdot)
        return qr+qp,qHr+qHp
    raise ValueError(operator)


def project(profile,total):
    H=diagnose_H(profile)
    fixed=np.asarray([profile[i]["theta"]*FIXED_DZ for i in range(1,NFIXED+1)],dtype=float)
    U=total-THETA_S*(PROFILE_DEPTH-H)
    moving=U-float(np.sum(fixed))
    storage=np.concatenate([fixed,[moving]])
    psi_k(np.concatenate([fixed/FIXED_DZ,[moving/(H-ANCHOR)]]))
    return H,storage,U


def direction(Hdot):
    if Hdot < -HDOT_EPS: return "WATER_TABLE_RISING"
    if Hdot > HDOT_EPS: return "WATER_TABLE_FALLING"
    return "HOLD"


def flux_stats(rows,face):
    ref=np.asarray([r[f"{face}_ref"] for r in rows],dtype=float)
    cand=np.asarray([r[f"{face}_cand"] for r in rows],dtype=float)
    err=cand-ref
    if len(err)==0: return None
    if np.std(ref)>0.0 and np.std(cand)>0.0:
        corr=float(np.corrcoef(ref,cand)[0,1])
    else:
        corr=None
    return {
        "count":int(len(err)),
        "signed_mean_error_cm_per_day":float(np.mean(err)),
        "mean_abs_error_cm_per_day":float(np.mean(np.abs(err))),
        "rms_error_cm_per_day":float(np.sqrt(np.mean(err*err))),
        "max_abs_error_cm_per_day":float(np.max(np.abs(err))),
        "sign_mismatch_count":int(np.count_nonzero(np.sign(ref)!=np.sign(cand))),
        "pearson_correlation":corr,
    }


def joint_stats(rows):
    q90e=np.asarray([r["q90_cand"]-r["q90_ref"] for r in rows],dtype=float)
    qHe=np.asarray([r["qH_cand"]-r["qH_ref"] for r in rows],dtype=float)
    tendency=q90e-qHe
    rq90=float(np.sqrt(np.mean(q90e*q90e))) if len(rows) else math.nan
    rqH=float(np.sqrt(np.mean(qHe*qHe))) if len(rows) else math.nan
    return {
        "rms_q90_over_rms_qH":None if rqH==0.0 else rq90/rqH,
        "signed_error_covariance":float(np.mean((q90e-np.mean(q90e))*(qHe-np.mean(qHe)))) if len(rows) else None,
        "moving_tendency_signed_mean_error_cm_per_day":float(np.mean(tendency)),
        "moving_tendency_mean_abs_error_cm_per_day":float(np.mean(np.abs(tendency))),
        "moving_tendency_rms_error_cm_per_day":float(np.sqrt(np.mean(tendency*tendency))),
        "moving_tendency_max_abs_error_cm_per_day":float(np.max(np.abs(tendency))),
    }


def better_or_equal(candidate,standard):
    return (
        candidate["rms_error_cm_per_day"]<=standard["rms_error_cm_per_day"]+1e-14
        and candidate["mean_abs_error_cm_per_day"]<=standard["mean_abs_error_cm_per_day"]+1e-14
    )


def strictly_better(candidate,standard):
    return (
        candidate["rms_error_cm_per_day"]<standard["rms_error_cm_per_day"]-1e-12
        or candidate["mean_abs_error_cm_per_day"]<standard["mean_abs_error_cm_per_day"]-1e-12
    )


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()
    pre=json.loads(args.prereg.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_REFERENCE_PROJECTED_OPERATOR_ATTRIBUTION"

    init_meta,init_nodes,states,nodes=load_reference(args.reference)

    # Quadrature check over all distinct H values sampled sparsely.
    Hvals=[]
    for h in HISTORY_STEPS:
        Hvals.append(diagnose_H(init_nodes[h]))
        Hvals.extend(diagnose_H(nodes[(h,s)]) for s in range(1,HISTORY_STEPS[h]+1))
    stride=max(1,len(Hvals)//128)
    quad=0.0
    for H in Hvals[::stride]+[min(Hvals),max(Hvals)]:
        quad=max(quad,float(np.max(np.abs(equilibrium_storage(H,64)-equilibrium_storage(H,128)))))

    all_rows=[]
    max_balance=0.0
    for history,nsteps in HISTORY_STEPS.items():
        Hprev,Sprev,Uprev=project(init_nodes[history],init_meta[history]["total"])
        for step in range(1,nsteps+1):
            H,S,U=project(nodes[(history,step)],states[(history,step)]["total"])
            Hdot=(H-Hprev)/OBS_DT
            qH_ref=states[(history,step)]["bottom_exchange"]/OBS_DT
            q90_ref_moving=(S[NFIXED]-Sprev[NFIXED])/OBS_DT + qH_ref - THETA_S*Hdot
            q90_ref_fixed=-(float(np.sum(S[:NFIXED]))-float(np.sum(Sprev[:NFIXED])))/OBS_DT
            balance=q90_ref_moving-q90_ref_fixed
            max_balance=max(max_balance,abs(balance))
            q90_ref=0.5*(q90_ref_moving+q90_ref_fixed)

            for op in OPERATORS:
                q0,qH0=operator_fluxes(Sprev,Hprev,Hdot,op)
                q1,qH1=operator_fluxes(S,H,Hdot,op)
                all_rows.append({
                    "history":history,"step":step,"direction":direction(Hdot),"operator":op,
                    "Hdot":Hdot,
                    "q90_ref":q90_ref,"qH_ref":qH_ref,
                    "q90_cand":0.5*(q0[NFIXED-1]+q1[NFIXED-1]),
                    "qH_cand":0.5*(qH0+qH1),
                    "q90_reference_identity_residual":balance,
                })
            Hprev,Sprev,Uprev=H,S,U

    finite=all(
        math.isfinite(r[k])
        for r in all_rows
        for k in ("q90_ref","qH_ref","q90_cand","qH_cand")
    )

    report={"by_direction":{},"by_history":{}}
    for group_name,group_values in (
        ("by_direction",["HOLD","WATER_TABLE_RISING","WATER_TABLE_FALLING"]),
        ("by_history",list(HISTORY_STEPS)),
    ):
        for group in group_values:
            report[group_name][group]={}
            for op in OPERATORS:
                rows=[r for r in all_rows if r["operator"]==op and (
                    r["direction"]==group if group_name=="by_direction" else r["history"]==group
                )]
                if not rows:
                    continue
                report[group_name][group][op]={
                    "q90":flux_stats(rows,"q90"),
                    "qH":flux_stats(rows,"qH"),
                    "joint":joint_stats(rows),
                }

    # Direction-conditioned ordering relative to B0.
    ordering={}
    direction_dependent=False
    for op in ("RESIDUAL_ONLY_B2","PATH_PRESERVING_B1"):
        ordering[op]={}
        for face in ("q90","qH"):
            statuses={}
            for d in ("WATER_TABLE_RISING","WATER_TABLE_FALLING"):
                std=report["by_direction"][d]["STANDARD_B0"][face]
                cand=report["by_direction"][d][op][face]
                if better_or_equal(cand,std) and strictly_better(cand,std):
                    statuses[d]="BETTER"
                elif better_or_equal(cand,std):
                    statuses[d]="NONINFERIOR_EQUAL"
                else:
                    statuses[d]="WORSE_OR_MIXED"
            ordering[op][face]=statuses
            if statuses["WATER_TABLE_RISING"]!=statuses["WATER_TABLE_FALLING"]:
                direction_dependent=True

    # Face-level comparison for standard operator over both moving directions.
    std_q90_larger=True
    std_qH_larger=True
    for d in ("WATER_TABLE_RISING","WATER_TABLE_FALLING"):
        q90=report["by_direction"][d]["STANDARD_B0"]["q90"]
        qH=report["by_direction"][d]["STANDARD_B0"]["qH"]
        std_q90_larger &= (
            q90["rms_error_cm_per_day"]>qH["rms_error_cm_per_day"]
            and q90["mean_abs_error_cm_per_day"]>qH["mean_abs_error_cm_per_day"]
        )
        std_qH_larger &= (
            qH["rms_error_cm_per_day"]>q90["rms_error_cm_per_day"]
            and qH["mean_abs_error_cm_per_day"]>q90["mean_abs_error_cm_per_day"]
        )

    hard_ok=quad<=QUAD_GATE and max_balance<=BALANCE_GATE and finite
    if not hard_ok:
        decision="BC2_B3_REFERENCE_OPERATOR_ATTRIBUTION_BLOCKED"
    elif direction_dependent:
        decision="BC2_B3_DIRECTION_DEPENDENT_MIXED_OPERATOR_ERROR"
    elif std_qH_larger:
        decision="BC2_B3_WATER_TABLE_FACE_CONSISTENTLY_LARGER_ERROR"
    elif std_q90_larger:
        decision="BC2_B3_FIXED_MOVING_INTERFACE_CONSISTENTLY_LARGER_ERROR"
    else:
        decision="BC2_B3_OPERATOR_ERRORS_COMPARABLE_OR_MIXED"

    result={
        "schema":"swap5.lare.bc2.b3.result.v1",
        "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-B3",
        "decision":decision,
        "hard_checks":{
            "max_reference_q90_identity_residual_cm_per_day":max_balance,
            "reference_balance_gate_cm_per_day":BALANCE_GATE,
            "quadrature_64_vs_128_max_storage_difference_cm":quad,
            "quadrature_gate_cm":QUAD_GATE,
            "all_fluxes_finite":finite,
        },
        "operator_ordering_relative_to_STANDARD_B0":ordering,
        "standard_face_consistency":{
            "q90_consistently_larger_error":std_q90_larger,
            "qH_consistently_larger_error":std_qH_larger,
        },
        **report,
        "interpretation":[
            "All candidate fluxes are evaluated on accepted Reference-projected states; no reduced dynamics is propagated.",
            "q90 Reference flux is reconstructed independently from both fixed-column storage change and moving-layer conservation; their agreement is a hard authority check.",
            "Direction-dependent ordering means that a single equilibrium correction cannot be justified as a universally improving moving-water-table closure from this experiment.",
            "No new closure, blending factor or direction-dependent switch is selected here."
        ],
        "next_model_change_authorized":False,
        "application_acceptance_adjudicated":False,
        "production_rom_authorized":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":decision,
        "hard_checks":result["hard_checks"],
        "operator_ordering":ordering,
        "standard_face_consistency":result["standard_face_consistency"],
        "by_direction":result["by_direction"],
    },sort_keys=True))
    return 0 if hard_ok else 2

if __name__=="__main__":
    raise SystemExit(main())
