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
HEUN_DT=(0.0002,0.0001)
CORRECTOR_TOL=1.0e-13
MAX_CORRECTOR=50
LEDGER_GATE=1.0e-10
HISTORY_STEPS={"WT_HOLD":256,"WT_RISE":512,"WT_FALL":512,"WT_CYCLE":768}
VARIANTS=("BC2_CONSERVATIVE","BC2_PUBLISHED_THETA")


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
            r=fields(line.split("|",1)[1])
            init_meta[r["HISTORY"]]={"total":float(r["TOTAL_STORAGE"])}
        elif line.startswith("LAREBC2A2_INITIAL_NODE|"):
            r=fields(line.split("|",1)[1])
            init_nodes[r["HISTORY"]][int(r["NODE"])]={
                "z":float(r["Z"]),"h":float(r["H"]),"theta":float(r["THETA"])
            }
        elif line.startswith("LAREBC2A2_STATE|"):
            r=fields(line.split("|",1)[1])
            states[(r["HISTORY"],int(r["STEP"]))]={
                "total":float(r["TOTAL_STORAGE"]),
                "bottom_exchange":float(r["BOTTOM_OUTWARD_EXCHANGE"]),
            }
        elif line.startswith("LAREBC2A2_NODE|"):
            r=fields(line.split("|",1)[1])
            nodes[(r["HISTORY"],int(r["STEP"]))][int(r["NODE"])]={
                "z":float(r["Z"]),"h":float(r["H"]),"theta":float(r["THETA"])
            }
    if set(init_meta)!=set(HISTORY_STEPS):
        raise RuntimeError("initial reference structure mismatch")
    for history,nsteps in HISTORY_STEPS.items():
        if set(init_nodes[history])!=set(range(1,17)):
            raise RuntimeError(f"incomplete initial nodes {history}")
        for step in range(1,nsteps+1):
            key=(history,step)
            if key not in states or set(nodes[key])!=set(range(1,17)):
                raise RuntimeError(f"incomplete reference {key}")
    return init_meta,init_nodes,states,nodes


def diagnose_H(profile:dict[int,dict[str,float]])->float:
    crossings=[]
    for i in range(1,16):
        a,b=profile[i],profile[i+1]
        ha,hb=a["h"],b["h"]
        if ha==0.0 or hb==0.0:
            raise ValueError("zero pressure on node")
        if ha<0.0 and hb>0.0:
            z=a["z"]+(-ha)*(b["z"]-a["z"])/(hb-ha)
            crossings.append(-z)
    if len(crossings)!=1:
        raise ValueError(f"expected one crossing, got {crossings}")
    return crossings[0]


def psi_k(theta:np.ndarray)->tuple[np.ndarray,np.ndarray]:
    se=(theta-THETA_R)/(THETA_S-THETA_R)
    if np.any(~np.isfinite(se)) or np.any(se<=0.0) or np.any(se>=1.0):
        raise ValueError(f"OUTSIDE_QUALIFIED_DOMAIN Se=[{np.min(se)},{np.max(se)}]")
    psi=np.power(np.power(se,-1.0/M_VG)-1.0,1.0/N_VG)/ALPHA
    term=1.0-np.power(1.0-np.power(se,1.0/M_VG),M_VG)
    k=KS*np.power(se,LAMBDA)*np.square(term)
    if np.any(~np.isfinite(psi)) or np.any(~np.isfinite(k)) or np.any(k<0.0):
        raise ValueError("OUTSIDE_QUALIFIED_DOMAIN constitutive")
    return psi,k


def unpack_theta(y:np.ndarray,H:float,variant:str)->np.ndarray:
    L=H-ANCHOR
    if L<=0.0:
        raise ValueError("OUTSIDE_QUALIFIED_DOMAIN nonpositive moving thickness")
    fixed=y[:NFIXED]/FIXED_DZ
    moving=y[NFIXED]/L if variant=="BC2_CONSERVATIVE" else y[NFIXED]
    return np.concatenate([fixed,[moving]])


def rhs(y:np.ndarray,H:float,Hdot:float,variant:str)->tuple[np.ndarray,float]:
    L=H-ANCHOR
    theta=unpack_theta(y,H,variant)
    psi,k=psi_k(theta)
    q=np.empty(NFIXED,dtype=float)

    for i in range(NFIXED-1):
        kij=0.5*(k[i]+k[i+1])
        q[i]=kij*(1.0+2.0*(psi[i+1]-psi[i])/(2.0*FIXED_DZ))

    kij=(L*k[NFIXED-1]+FIXED_DZ*k[NFIXED])/(FIXED_DZ+L)
    q[NFIXED-1]=kij*(1.0+2.0*(psi[NFIXED]-psi[NFIXED-1])/(FIXED_DZ+L))

    qH=KS*(1.0-2.0*psi[NFIXED]/L)

    dy=np.zeros(NFIXED+2,dtype=float)
    dy[0]=-q[0]  # frozen top flux = 0
    for i in range(1,NFIXED):
        dy[i]=q[i-1]-q[i]

    if variant=="BC2_CONSERVATIVE":
        dy[NFIXED]=q[NFIXED-1]-qH+THETA_S*Hdot
    elif variant=="BC2_PUBLISHED_THETA":
        dy[NFIXED]=(q[NFIXED-1]-qH+THETA_S*Hdot)/L
    else:
        raise ValueError(variant)

    dy[NFIXED+1]=qH
    return dy,qH


def heun_step(y,dt,H0,H1,Hdot,variant):
    f0,_=rhs(y,H0,Hdot,variant)
    guess=y+dt*f0
    for iteration in range(1,MAX_CORRECTOR+1):
        f1,_=rhs(guess,H1,Hdot,variant)
        nxt=y+0.5*dt*(f0+f1)
        old_theta=unpack_theta(guess,H1,variant)
        new_theta=unpack_theta(nxt,H1,variant)
        if np.max(np.abs(new_theta-old_theta))<=CORRECTOR_TOL:
            return nxt,iteration
        guess=nxt
    raise RuntimeError("NUMERICAL_BLOCKED iterative Heun corrector")


def initial_state(history,variant,init_meta,init_nodes):
    profile=init_nodes[history]
    H0=diagnose_H(profile)
    if H0<=ANCHOR:
        raise ValueError("initial H not below anchor")
    fixed=np.asarray([profile[i]["theta"]*FIXED_DZ for i in range(1,NFIXED+1)],dtype=float)
    U0=init_meta[history]["total"]-THETA_S*(PROFILE_DEPTH-H0)
    moving=U0-float(np.sum(fixed))
    theta_m=moving/(H0-ANCHOR)
    psi_k(np.concatenate([fixed/FIXED_DZ,[theta_m]]))
    y=np.concatenate([fixed,[moving if variant=="BC2_CONSERVATIVE" else theta_m],[0.0]])
    return y,H0,U0


def reference_row(history,step,states,nodes):
    profile=nodes[(history,step)]
    H=diagnose_H(profile)
    total=states[(history,step)]["total"]
    U=total-THETA_S*(PROFILE_DEPTH-H)
    fixed=np.asarray([profile[i]["theta"]*FIXED_DZ for i in range(1,NFIXED+1)],dtype=float)
    moving=U-float(np.sum(fixed))
    bex=states[(history,step)]["bottom_exchange"]
    return H,U,fixed,moving,bex


def reversals(values:list[float])->list[int]:
    out=[];prev=0
    for step,value in enumerate(values,1):
        s=1 if value>0.0 else -1 if value<0.0 else 0
        if s==0:
            continue
        if prev and s!=prev:
            out.append(step)
        prev=s
    return out


def solve(history,variant,dt,init_meta,init_nodes,states,nodes):
    ratio=OBS_DT/dt
    nsub=int(round(ratio))
    if nsub<=0 or abs(ratio-nsub)>1.0e-12:
        raise RuntimeError("dt does not divide observation interval")

    y,Hprev,U0=initial_state(history,variant,init_meta,init_nodes)
    Hinitial=Hprev
    max_ledger=0.0
    max_corrector=0
    cum_ref=0.0
    rows=[]
    q_candidate=[]
    q_reference=[]

    for step in range(1,HISTORY_STEPS[history]+1):
        Hend,Uref,fixed_ref,moving_ref,bex=reference_row(history,step,states,nodes)
        Hdot=(Hend-Hprev)/OBS_DT
        cumb_start=float(y[NFIXED+1])

        for sub in range(nsub):
            fa=sub/nsub
            fb=(sub+1)/nsub
            Ha=Hprev+(Hend-Hprev)*fa
            Hb=Hprev+(Hend-Hprev)*fb
            y,it=heun_step(y,dt,Ha,Hb,Hdot,variant)
            max_corrector=max(max_corrector,it)

        theta=unpack_theta(y,Hend,variant)
        psi_k(theta)
        moving=float(y[NFIXED]) if variant=="BC2_CONSERVATIVE" else (Hend-ANCHOR)*float(y[NFIXED])
        U=float(np.sum(y[:NFIXED]))+moving
        cum_candidate=float(y[NFIXED+1])
        cum_ref+=bex
        q_interval=(cum_candidate-cumb_start)/OBS_DT
        q_ref=bex/OBS_DT
        physical_ledger=U-U0+cum_candidate-THETA_S*(Hend-Hinitial)
        max_ledger=max(max_ledger,abs(physical_ledger))

        rows.append({
            "step":step,"H_cm":Hend,
            "fixed_storage_error_cm":(y[:NFIXED]-fixed_ref).tolist(),
            "moving_storage_error_cm":moving-moving_ref,
            "total_unsaturated_storage_error_cm":U-Uref,
            "cumulative_qH_error_cm":cum_candidate-cum_ref,
            "interval_qH_error_cm_per_day":q_interval-q_ref,
            "qH_candidate_cm_per_day":q_interval,
            "qH_reference_cm_per_day":q_ref,
            "physical_ledger_residual_cm":physical_ledger,
        })
        q_candidate.append(q_interval);q_reference.append(q_ref)
        Hprev=Hend

    fixed_errors=np.asarray([r["fixed_storage_error_cm"] for r in rows],dtype=float)
    moving_errors=np.asarray([r["moving_storage_error_cm"] for r in rows],dtype=float)
    total_errors=np.asarray([r["total_unsaturated_storage_error_cm"] for r in rows],dtype=float)
    cum_errors=np.asarray([r["cumulative_qH_error_cm"] for r in rows],dtype=float)
    q_errors=np.asarray([r["interval_qH_error_cm_per_day"] for r in rows],dtype=float)
    crev=reversals(q_candidate);rrev=reversals(q_reference)
    rev_match=len(crev)==len(rrev)
    max_rev=None if not rev_match else max([abs(a-b) for a,b in zip(crev,rrev)] or [0])

    return {
        "status":"QUALIFIED",
        "dt_day":dt,
        "max_abs_fixed_layer_storage_error_cm":float(np.max(np.abs(fixed_errors))),
        "max_abs_moving_layer_storage_error_cm":float(np.max(np.abs(moving_errors))),
        "max_abs_total_unsaturated_storage_error_cm":float(np.max(np.abs(total_errors))),
        "max_abs_cumulative_qH_error_cm":float(np.max(np.abs(cum_errors))),
        "final_signed_cumulative_qH_error_cm":float(cum_errors[-1]),
        "max_abs_interval_qH_error_cm_per_day":float(np.max(np.abs(q_errors))),
        "qH_sign_mismatch_count":int(np.count_nonzero(np.sign(q_candidate)!=np.sign(q_reference))),
        "candidate_reversal_steps":crev,
        "reference_reversal_steps":rrev,
        "reversal_sequence_length_match":rev_match,
        "max_reversal_step_difference":max_rev,
        "max_reversal_time_difference_minutes":None if max_rev is None else max_rev*OBS_DT*24.0*60.0,
        "max_abs_physical_moving_ledger_residual_cm":max_ledger,
        "max_corrector_iterations":max_corrector,
        "theta_min":float(min(np.min(unpack_theta(initial_state(history,variant,init_meta,init_nodes)[0],initial_state(history,variant,init_meta,init_nodes)[1],variant)), np.min([THETA_S]))),
        "trajectory":rows,
    }


def numerical_floor(coarse,fine):
    ca=np.asarray([r["total_unsaturated_storage_error_cm"] for r in coarse["trajectory"]])
    fa=np.asarray([r["total_unsaturated_storage_error_cm"] for r in fine["trajectory"]])
    cc=np.asarray([r["cumulative_qH_error_cm"] for r in coarse["trajectory"]])
    fc=np.asarray([r["cumulative_qH_error_cm"] for r in fine["trajectory"]])
    cq=np.asarray([r["interval_qH_error_cm_per_day"] for r in coarse["trajectory"]])
    fq=np.asarray([r["interval_qH_error_cm_per_day"] for r in fine["trajectory"]])
    return {
        "max_abs_total_unsaturated_storage_difference_cm":float(np.max(np.abs(ca-fa))),
        "max_abs_cumulative_qH_difference_cm":float(np.max(np.abs(cc-fc))),
        "max_abs_interval_qH_difference_cm_per_day":float(np.max(np.abs(cq-fq))),
    }


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_PRESCRIBED_MOVING_GEOMETRY_REPLAY"
    assert pre["model_geometry"]["fixed_anchor_a_cm"]==ANCHOR
    assert pre["authority"]["a2_decision"]=="BC2_REFERENCE_GEOMETRY_QUALIFIED"

    init_meta,init_nodes,states,nodes=load_reference(args.reference)
    cases={}
    for variant in VARIANTS:
        for history in HISTORY_STEPS:
            refinements={};failures={}
            for dt in HEUN_DT:
                key=f"{dt:.7f}"
                try:
                    refinements[key]=solve(history,variant,dt,init_meta,init_nodes,states,nodes)
                except ValueError as exc:
                    failures[key]=f"OUTSIDE_QUALIFIED_DOMAIN: {exc}"
                except (RuntimeError,FloatingPointError) as exc:
                    failures[key]=f"NUMERICAL_BLOCKED: {exc}"
            fine=refinements.get("0.0001000")
            if fine is not None:
                status="QUALIFIED"
            elif "OUTSIDE_QUALIFIED_DOMAIN" in failures.get("0.0001000",""):
                status="OUTSIDE_QUALIFIED_DOMAIN"
            else:
                status="NUMERICAL_BLOCKED"
            floor=None
            if "0.0002000" in refinements and "0.0001000" in refinements:
                floor=numerical_floor(refinements["0.0002000"],refinements["0.0001000"])
            cases[f"{variant}_{history}"]={
                "variant":variant,"history":history,"status":status,
                "fine":fine,"numerical_floor":floor,"failures":failures,
            }

    conservative=[cases[f"BC2_CONSERVATIVE_{h}"] for h in HISTORY_STEPS]
    all_cons_qualified=all(row["status"]=="QUALIFIED" for row in conservative)
    all_cons_floor=all(row["numerical_floor"] is not None for row in conservative)
    max_cons_ledger=max(
        row["fine"]["max_abs_physical_moving_ledger_residual_cm"]
        for row in conservative if row["fine"] is not None
    ) if any(row["fine"] is not None for row in conservative) else math.inf

    if all_cons_qualified and all_cons_floor and max_cons_ledger<=LEDGER_GATE:
        decision="BC2_CONSERVATIVE_MOVING_GEOMETRY_QUALIFIED"
    elif any(row["status"]=="OUTSIDE_QUALIFIED_DOMAIN" for row in conservative):
        decision="BC2_CONSERVATIVE_MOVING_GEOMETRY_OUTSIDE_DOMAIN"
    elif any(row["status"]=="NUMERICAL_BLOCKED" for row in conservative):
        decision="BC2_CONSERVATIVE_NUMERICALLY_BLOCKED"
    else:
        decision="BC2_REFERENCE_OR_GEOMETRY_INSUFFICIENT"

    def compact(row):
        fine=row["fine"]
        if fine is None:
            return {"status":row["status"],"failures":row["failures"],"numerical_floor":row["numerical_floor"]}
        return {
            "status":row["status"],
            "max_abs_fixed_layer_storage_error_cm":fine["max_abs_fixed_layer_storage_error_cm"],
            "max_abs_moving_layer_storage_error_cm":fine["max_abs_moving_layer_storage_error_cm"],
            "max_abs_total_unsaturated_storage_error_cm":fine["max_abs_total_unsaturated_storage_error_cm"],
            "max_abs_cumulative_qH_error_cm":fine["max_abs_cumulative_qH_error_cm"],
            "max_abs_interval_qH_error_cm_per_day":fine["max_abs_interval_qH_error_cm_per_day"],
            "qH_sign_mismatch_count":fine["qH_sign_mismatch_count"],
            "candidate_reversal_steps":fine["candidate_reversal_steps"],
            "reference_reversal_steps":fine["reference_reversal_steps"],
            "max_reversal_step_difference":fine["max_reversal_step_difference"],
            "max_abs_physical_moving_ledger_residual_cm":fine["max_abs_physical_moving_ledger_residual_cm"],
            "numerical_floor":row["numerical_floor"],
        }

    result={
        "schema":"swap5.lare.bc2.b0.result.v1",
        "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-B0",
        "decision":decision,
        "reference":{
            "a2_artifact_id":10587360597,
            "geometry_source":"strict interior zero-pressure crossing from A2 accepted profiles"
        },
        "conservative":{
            h:compact(cases[f"BC2_CONSERVATIVE_{h}"]) for h in HISTORY_STEPS
        },
        "published_theta_diagnostic":{
            h:compact(cases[f"BC2_PUBLISHED_THETA_{h}"]) for h in HISTORY_STEPS
        },
        "max_conservative_physical_ledger_residual_cm":max_cons_ledger,
        "stationary_geometry_control":{
            "history":"WT_HOLD",
            "note":"Any nonzero response error here is fixed-geometry LARE closure/equilibrium drift, not moving-geometry error.",
            "conservative":compact(cases["BC2_CONSERVATIVE_WT_HOLD"])
        },
        "interpretation":[
            "BC2_CONSERVATIVE is adjudicated on control-volume conservation, numerical qualification and domain coverage; no application error threshold is introduced.",
            "BC2_PUBLISHED_THETA remains diagnostic only because BC2-A1 established that its displayed equation is not moving-control-volume equivalent.",
            "The WT_HOLD control quantifies residual standard-LARE hydrostatic/closure drift and prevents attributing all response error in moving histories to geometry.",
            "This geometry-isolation experiment is deliberately high-dimensional relative to a ROM and does not establish computational value."
        ],
        "application_acceptance_adjudicated":False,
        "speed_claim":False,
        "production_rom_authorized":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":decision,
        "max_conservative_ledger_cm":max_cons_ledger,
        "conservative":result["conservative"],
        "published_theta_diagnostic":result["published_theta_diagnostic"],
    },sort_keys=True))
    return 0 if decision=="BC2_CONSERVATIVE_MOVING_GEOMETRY_QUALIFIED" else 2


if __name__=="__main__":
    raise SystemExit(main())
