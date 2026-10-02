#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib
from collections import defaultdict

import numpy as np
from scipy.integrate import solve_ivp
from scipy.optimize import least_squares

TR=0.02
TS=0.427494
ALPHA=0.021659
N=1.734737
M=1.0-1.0/N
KS=31.225016
LAM=0.98087
PSI_MIN=0.0100001

ODE_RTOL=2.0e-10
ODE_ATOL_PSI=1.0e-10
ODE_ATOL_STORAGE=1.0e-11
LS_TOL=1.0e-12
MAX_NFEV=40

PARTITIONS={
    "L3":[0.0,140.0,150.0,160.0],
    "L4":[0.0,130.0,140.0,150.0,160.0],
}
PRIMARY=("S2_B1_F2","S2_B1_F3","S2_B1_F4","S3_B1_F3")
CLOSURES=("C_LARE_TAYLOR","C_INT_CENTROID_LONG_ONLY","C_QS_STORAGE_LONG_ONLY")


def fields(payload:str)->dict[str,str]:
    out={}
    for item in payload.split("|"):
        if "=" in item:
            k,v=item.split("=",1)
            out[k]=v
    return out


def se_from_psi(psi):
    psi=np.asarray(psi,dtype=float)
    return np.power(1.0+np.power(ALPHA*psi,N),-M)


def theta_from_psi(psi):
    return TR+(TS-TR)*se_from_psi(psi)


def psi_from_theta(theta:float)->float:
    se=(theta-TR)/(TS-TR)
    if not 0.0 < se < 1.0:
        raise ValueError(f"theta outside MvG domain: {theta}")
    return float(np.power(np.power(se,-1.0/M)-1.0,1.0/N)/ALPHA)


def k_from_psi(psi):
    se=se_from_psi(psi)
    term=1.0-np.power(1.0-np.power(se,1.0/M),M)
    return KS*np.power(se,LAM)*np.square(term)


def k_from_theta(theta:float)->float:
    return float(k_from_psi(psi_from_theta(theta)))


def load_case(path:pathlib.Path):
    rows=defaultdict(list)
    for line in path.read_text(errors="replace").splitlines():
        if not line.startswith("LAREDYN0R_NODE|"):
            continue
        d=fields(line.split("|",1)[1])
        rows[int(d["STEP"])].append({
            "node":int(d["NODE"]),
            "z":abs(float(d["Z"])),
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


def layer_means(rows,bounds):
    out=[]
    for lo,hi in zip(bounds,bounds[1:]):
        selected=[
            r for r in rows
            if r["z"]-0.5*r["dz"] >= lo-1e-9
            and r["z"]+0.5*r["dz"] <= hi+1e-9
        ]
        width=hi-lo
        covered=sum(r["dz"] for r in selected)
        if abs(covered-width)>1e-9:
            raise ValueError(f"coverage mismatch {lo}-{hi}: {covered}")
        out.append(sum(r["theta"]*r["dz"] for r in selected)/width)
    return out


def reference_flux(rows,boundary:float)->float:
    upper_node=int(round(boundary/10.0))
    lower_node=upper_node+1
    ru=rows[upper_node-1]
    rl=rows[lower_node-1]
    psi_u=-ru["h"]
    psi_l=-rl["h"]
    if psi_u<=0.01 or psi_l<=0.01:
        raise ValueError("Reference face outside strict-unsaturated domain")
    ku=float(k_from_psi(psi_u))
    kl=float(k_from_psi(psi_l))
    return 0.5*(ku+kl)*(1.0+(psi_l-psi_u)/10.0)


def q_lare(theta_u:float,theta_l:float,du:float,dl:float)->float:
    pu=psi_from_theta(theta_u)
    pl=psi_from_theta(theta_l)
    ku=k_from_theta(theta_u)
    kl=k_from_theta(theta_l)
    kface=(dl*ku+du*kl)/(du+dl)
    return kface*(1.0+2.0*(pl-pu)/(du+dl))


def propagate(p0:float,q:float,length:float,with_storage:bool):
    def rhs(z,y):
        psi=float(y[0])
        if not psi>PSI_MIN:
            raise ValueError("OUTSIDE_STRICT_UNSATURATED_DOMAIN")
        deriv=[q/float(k_from_psi(psi))-1.0]
        if with_storage:
            deriv.append(float(theta_from_psi(psi)))
        return deriv
    y0=[p0,0.0] if with_storage else [p0]
    max_step=max(abs(length)/8.0,0.5)
    sol=solve_ivp(
        rhs,(0.0,length),y0,method="DOP853",
        rtol=ODE_RTOL,atol=([ODE_ATOL_PSI,ODE_ATOL_STORAGE] if with_storage else ODE_ATOL_PSI),max_step=max_step
    )
    if not sol.success or np.min(sol.y[0])<=PSI_MIN:
        raise RuntimeError("INTEGRATED_PROFILE_SOLVE_FAILED")
    return sol.y[:,-1]


def q_integrated_centroid(theta_u:float,theta_l:float,du:float,dl:float,q_init:float):
    pu=psi_from_theta(theta_u)
    pl=psi_from_theta(theta_l)
    distance=0.5*(du+dl)

    def residual(x):
        q=float(x[0])*KS
        try:
            pend=float(propagate(pu,q,distance,False)[0])
            return np.asarray([(pend-pl)/max(pl,1.0)])
        except (ValueError,RuntimeError,FloatingPointError,OverflowError):
            return np.asarray([100.0])

    sol=least_squares(
        residual,[q_init/KS],bounds=([-20.0],[20.0]),
        xtol=LS_TOL,ftol=LS_TOL,gtol=LS_TOL,max_nfev=MAX_NFEV
    )
    rr=float(abs(residual(sol.x)[0]))
    if not sol.success or rr>1.0e-9:
        raise RuntimeError(f"CENTROID_INTEGRATED_FAIL residual={rr}")
    return float(sol.x[0])*KS,int(sol.nfev),rr


def profile_storage_from_interface(psi_interface:float,q:float,du:float,dl:float):
    upper=propagate(psi_interface,q,-du,True)
    lower=propagate(psi_interface,q,dl,True)
    theta_u=-float(upper[1])/du
    theta_l=float(lower[1])/dl
    return theta_u,theta_l


def q_qs_storage(theta_u:float,theta_l:float,du:float,dl:float,x_init):
    def residual(x):
        psi_interface=PSI_MIN+math.exp(float(x[0]))
        q=float(x[1])*KS
        try:
            mu,ml=profile_storage_from_interface(psi_interface,q,du,dl)
            return np.asarray([
                (mu-theta_u)/(TS-TR),
                (ml-theta_l)/(TS-TR),
            ])
        except (ValueError,RuntimeError,FloatingPointError,OverflowError):
            return np.asarray([10.0,10.0])

    sol=least_squares(
        residual,x_init,bounds=([-20.0,-20.0],[20.0,20.0]),
        xtol=LS_TOL,ftol=LS_TOL,gtol=LS_TOL,max_nfev=MAX_NFEV
    )
    rr=residual(sol.x)
    storage_residual=float(np.max(np.abs(rr))*(TS-TR))
    if not sol.success or storage_residual>1.0e-10:
        raise RuntimeError(f"QS_STORAGE_FAIL residual={storage_residual}")
    return float(sol.x[1])*KS,sol.x.copy(),int(sol.nfev),storage_residual


def rms(values):
    return math.sqrt(sum(v*v for v in values)/len(values)) if values else 0.0


def summarize(errors,sign_mismatch,failures):
    return {
        "sample_count":len(errors),
        "rms_error_cm_per_day":rms(errors),
        "max_abs_error_cm_per_day":max((abs(v) for v in errors),default=None),
        "mean_signed_error_cm_per_day":sum(errors)/len(errors) if errors else None,
        "flux_sign_mismatch_count":sign_mismatch,
        "solve_failure_count":failures,
    }


def sign(x):
    return 1 if x>0.0 else (-1 if x<0.0 else 0)


def structural_tests():
    theta=TR+0.75*(TS-TR)
    du,dl=140.0,10.0
    k=k_from_theta(theta)
    q0=q_lare(theta,theta,du,dl)
    qc_uniform,_,_=q_integrated_centroid(theta,theta,du,dl,q0)
    psi=psi_from_theta(theta)
    x0=np.asarray([math.log(psi-PSI_MIN),q0/KS])
    qq_uniform,_,_,r_uniform=q_qs_storage(theta,theta,du,dl,x0)
    uniform_error=max(abs(q0-k),abs(qc_uniform-k),abs(qq_uniform-k))
    if uniform_error>1e-8 or r_uniform>1e-10:
        raise SystemExit("uniform-state identity failed")

    # Integrated centroid synthetic identity.
    pu=45.0
    qsyn_centroid=0.98*float(k_from_psi(pu))
    distance=75.0
    pl=float(propagate(pu,qsyn_centroid,distance,False)[0])
    tu=float(theta_from_psi(pu))
    tl=float(theta_from_psi(pl))
    qc_syn,_,_=q_integrated_centroid(tu,tl,140.0,10.0,qsyn_centroid)
    centroid_error=abs(qc_syn-qsyn_centroid)
    if centroid_error>1e-7:
        raise SystemExit("integrated-centroid synthetic identity failed")

    # Storage-constrained quasi-steady synthetic identity.
    psi_i=35.0
    qsyn_qs=0.8*float(k_from_psi(psi_i))
    tu,tl=profile_storage_from_interface(psi_i,qsyn_qs,140.0,10.0)
    x=np.asarray([math.log(psi_i-PSI_MIN),qsyn_qs/KS])
    qq_syn,_,_,r_syn=q_qs_storage(tu,tl,140.0,10.0,x)
    qs_error=abs(qq_syn-qsyn_qs)
    if qs_error>1e-7 or r_syn>1e-10:
        raise SystemExit("QS-storage synthetic identity failed")
    return {
        "uniform_max_abs_q_error_cm_per_day":uniform_error,
        "centroid_synthetic_abs_q_error_cm_per_day":centroid_error,
        "qs_synthetic_abs_q_error_cm_per_day":qs_error,
    }


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    prereg=json.loads(args.prereg.read_text())
    if prereg["phase"]!="PREREGISTERED_BEFORE_QUASI_STEADY_CLOSURE_RESULTS":
        raise SystemExit("wrong A2B preregistration phase")
    if tuple(c["id"] for c in prereg["closures"])!=CLOSURES:
        raise SystemExit("A2B closure list drift")
    freeze=prereg["pre_execution_numerical_freeze"]
    amendment=prereg["pre_execution_numerical_amendment"]
    if not freeze["before_first_official_A2B_result"] or not amendment["before_first_A2B_result"]:
        raise SystemExit("numerical contract not frozen/amended before execution")
    if amendment["solve_ivp"]["rtol"] != ODE_RTOL or amendment["solve_ivp"]["atol_psi"] != ODE_ATOL_PSI:
        raise SystemExit("ODE numerical amendment drift")
    if amendment["solve_ivp"]["atol_theta_integral"] != ODE_ATOL_STORAGE:
        raise SystemExit("storage-integral numerical amendment drift")
    if amendment["least_squares"]["xtol"] != LS_TOL or amendment["least_squares"]["max_nfev"] != MAX_NFEV:
        raise SystemExit("least-squares numerical amendment drift")
    tests=structural_tests()

    errors={p:{c:[] for c in CLOSURES} for p in PARTITIONS}
    sign_mismatch={p:{c:0 for c in CLOSURES} for p in PARTITIONS}
    failures={p:{c:0 for c in CLOSURES} for p in PARTITIONS}
    case_errors={p:{case:{c:[] for c in CLOSURES} for case in PRIMARY} for p in PARTITIONS}
    max_storage_residual=0.0
    max_centroid_nfev=0
    max_qs_nfev=0

    for part,bounds in PARTITIONS.items():
        du=bounds[1]-bounds[0]
        dl=bounds[2]-bounds[1]
        boundary=bounds[1]
        for case in PRIMARY:
            trajectory=load_case(args.reference_dir/f"fine-{case}-o2.txt")
            prev_centroid_q=None
            prev_qs_x=None
            for step in range(1,1025):
                means=layer_means(trajectory[step],bounds)
                tu,tl=means[0],means[1]
                qref=reference_flux(trajectory[step],boundary)
                qbase=q_lare(tu,tl,du,dl)
                candidates={"C_LARE_TAYLOR":qbase}

                centroid_inits=[]
                if prev_centroid_q is not None:
                    centroid_inits.append(prev_centroid_q)
                centroid_inits.append(qbase)
                centroid_ok=False
                for init_q in centroid_inits:
                    try:
                        qc,nfev,_=q_integrated_centroid(tu,tl,du,dl,init_q)
                        prev_centroid_q=qc
                        max_centroid_nfev=max(max_centroid_nfev,nfev)
                        candidates["C_INT_CENTROID_LONG_ONLY"]=qc
                        centroid_ok=True
                        break
                    except (ValueError,RuntimeError,FloatingPointError,OverflowError):
                        continue
                if not centroid_ok:
                    failures[part]["C_INT_CENTROID_LONG_ONLY"]+=1
                    prev_centroid_q=None

                pu=psi_from_theta(tu)
                pl=psi_from_theta(tl)
                slope=2.0*(pl-pu)/(du+dl)
                psi_interface=pu+slope*du/2.0
                fresh_qs=np.asarray([
                    math.log(max(psi_interface-PSI_MIN,1e-8)),
                    qbase/KS
                ])
                qs_inits=[]
                if prev_qs_x is not None:
                    qs_inits.append(prev_qs_x)
                qs_inits.append(fresh_qs)
                qs_ok=False
                for init in qs_inits:
                    try:
                        qq,x,nfev,res=q_qs_storage(tu,tl,du,dl,init)
                        prev_qs_x=x
                        max_qs_nfev=max(max_qs_nfev,nfev)
                        max_storage_residual=max(max_storage_residual,res)
                        candidates["C_QS_STORAGE_LONG_ONLY"]=qq
                        qs_ok=True
                        break
                    except (ValueError,RuntimeError,FloatingPointError,OverflowError):
                        continue
                if not qs_ok:
                    failures[part]["C_QS_STORAGE_LONG_ONLY"]+=1
                    prev_qs_x=None

                for closure,q in candidates.items():
                    err=q-qref
                    errors[part][closure].append(err)
                    case_errors[part][case][closure].append(err)
                    sign_mismatch[part][closure]+=int(sign(q)!=sign(qref))

    pooled={
        p:{
            c:summarize(errors[p][c],sign_mismatch[p][c],failures[p][c])
            for c in CLOSURES
        } for p in PARTITIONS
    }
    support={}
    base=pooled["L3"]["C_LARE_TAYLOR"]
    for closure in ("C_INT_CENTROID_LONG_ONLY","C_QS_STORAGE_LONG_ONLY"):
        row=pooled["L3"][closure]
        noninferior={
            "rms":row["rms_error_cm_per_day"] is not None and row["rms_error_cm_per_day"]<=base["rms_error_cm_per_day"]+1e-15,
            "max_abs":row["max_abs_error_cm_per_day"] is not None and row["max_abs_error_cm_per_day"]<=base["max_abs_error_cm_per_day"]+1e-15,
            "sign":row["flux_sign_mismatch_count"]<=base["flux_sign_mismatch_count"],
            "solve_failures":row["solve_failure_count"]<=base["solve_failure_count"],
        }
        strict=(
            row["rms_error_cm_per_day"] is not None and (
                row["rms_error_cm_per_day"]<base["rms_error_cm_per_day"]-1e-15
                or row["max_abs_error_cm_per_day"]<base["max_abs_error_cm_per_day"]-1e-15
                or row["flux_sign_mismatch_count"]<base["flux_sign_mismatch_count"]
                or row["solve_failure_count"]<base["solve_failure_count"]
            )
        )
        block_ok=True
        blocks=[]
        for case in PRIMARY:
            cand=case_errors["L3"][case][closure]
            bref=case_errors["L3"][case]["C_LARE_TAYLOR"]
            if len(cand)!=len(bref):
                block_ok=False
                blocks.append({"case":case,"reason":"solve_failure_or_missing"})
                continue
            if rms(cand)>rms(bref)+1e-15 and max(abs(x) for x in cand)>max(abs(x) for x in bref)+1e-15:
                block_ok=False
                blocks.append({"case":case,"reason":"worse_on_rms_and_max"})
        support[closure]={
            "component_noninferiority":noninferior,
            "strict_improvement":strict,
            "broad_support":block_ok,
            "worse_case_blocks":blocks,
            "supported":all(noninferior.values()) and strict and block_ok,
        }

    supported=[c for c,v in support.items() if v["supported"]]
    decision="A2B_STORAGE_ONLY_CLOSURE_SUPPORTED" if supported else "A2B_NO_STORAGE_ONLY_CLOSURE_SUPPORTED"

    result={
        "schema":"swap5.layer-rom.phase-a2b.result.v1",
        "workstream":"F-ROM-LAYER",
        "work_unit":"LAYER-ROM-A2B",
        "decision":decision,
        "structural_tests":tests,
        "primary_cases":list(PRIMARY),
        "pooled_long_interface":pooled,
        "candidate_support":support,
        "per_case_long_interface":{
            p:{
                case:{
                    c:summarize(case_errors[p][case][c],0,0)
                    for c in CLOSURES
                } for case in PRIMARY
            } for p in PARTITIONS
        },
        "numerical":{
            "max_qs_storage_residual_theta":max_storage_residual,
            "max_centroid_nfev":max_centroid_nfev,
            "max_qs_nfev":max_qs_nfev,
        },
        "fine_limit_guard":"All local-local 10 cm interfaces remain C_LARE_TAYLOR by construction; A2B changes only the single long-to-local interface.",
        "reduced_state_propagated":False,
        "application_acceptance":False,
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":decision,
        "pooled_long_interface":pooled,
        "candidate_support":support,
        "numerical":result["numerical"],
        "structural_tests":tests,
    },sort_keys=True))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
