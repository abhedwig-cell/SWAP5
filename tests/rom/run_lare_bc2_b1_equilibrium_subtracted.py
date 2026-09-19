#!/usr/bin/env python3
from __future__ import annotations

import argparse
import collections
import functools
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
RHS_GATE=1.0e-10
QUAD_GATE=1.0e-10
HISTORY_STEPS={"WT_HOLD":256,"WT_RISE":512,"WT_FALL":512,"WT_CYCLE":768}

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


def theta_from_psi(psi):
    p=np.asarray(psi,dtype=float)
    if np.any(p<0.0) or np.any(~np.isfinite(p)):
        raise ValueError("invalid hydrostatic suction")
    se=np.power(1.0+np.power(ALPHA*p,N_VG),-M_VG)
    return THETA_R+(THETA_S-THETA_R)*se


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


def integrate_hydrostatic_storage(z0:float,z1:float,H:float,nq:int)->float:
    if not (0.0<=z0<z1<=H):
        raise ValueError(f"invalid equilibrium interval {z0},{z1},H={H}")
    x,w=_GL64 if nq==64 else _GL128 if nq==128 else np.polynomial.legendre.leggauss(nq)
    half=0.5*(z1-z0)
    mid=0.5*(z1+z0)
    z=mid+half*x
    return float(half*np.sum(w*theta_from_psi(H-z)))


@functools.lru_cache(maxsize=65536)
def equilibrium_state_64(H:float)->tuple[float,...]:
    if H<=ANCHOR:
        raise ValueError("equilibrium H below anchor")
    storage=[]
    for i in range(NFIXED):
        storage.append(integrate_hydrostatic_storage(i*FIXED_DZ,(i+1)*FIXED_DZ,H,64))
    storage.append(integrate_hydrostatic_storage(ANCHOR,H,H,64))
    return tuple(storage)


def equilibrium_state(H:float)->np.ndarray:
    return np.asarray(equilibrium_state_64(float(H)),dtype=float)


def unpack_theta(y:np.ndarray,H:float)->np.ndarray:
    L=H-ANCHOR
    if L<=0.0:
        raise ValueError("OUTSIDE_QUALIFIED_DOMAIN nonpositive moving thickness")
    fixed=y[:NFIXED]/FIXED_DZ
    moving=y[NFIXED]/L
    return np.concatenate([fixed,[moving]])


def standard_fluxes(theta:np.ndarray,H:float)->tuple[np.ndarray,float]:
    L=H-ANCHOR
    psi,k=psi_k(theta)
    q=np.empty(NFIXED,dtype=float)
    for i in range(NFIXED-1):
        kij=0.5*(k[i]+k[i+1])
        q[i]=kij*(1.0+(psi[i+1]-psi[i])/FIXED_DZ)
    kij=(L*k[NFIXED-1]+FIXED_DZ*k[NFIXED])/(FIXED_DZ+L)
    q[NFIXED-1]=kij*(1.0+2.0*(psi[NFIXED]-psi[NFIXED-1])/(FIXED_DZ+L))
    qH=KS*(1.0-2.0*psi[NFIXED]/L)
    return q,qH


def required_equilibrium_fluxes(H:float,Hdot:float)->tuple[np.ndarray,float]:
    # q(z) positive downward and q(0)=0.
    theta_surface=float(theta_from_psi(H))
    q=np.empty(NFIXED,dtype=float)
    for i in range(NFIXED):
        z=(i+1)*FIXED_DZ
        q[i]=(float(theta_from_psi(H-z))-theta_surface)*Hdot
    qH=(THETA_S-theta_surface)*Hdot
    return q,qH


def corrected_fluxes(y:np.ndarray,H:float,Hdot:float)->tuple[np.ndarray,float]:
    theta=unpack_theta(y,H)
    q_state,qH_state=standard_fluxes(theta,H)

    y_eq=equilibrium_state(H)
    theta_eq=unpack_theta(np.concatenate([y_eq,[0.0]]),H)
    q_eq_discrete,qH_eq_discrete=standard_fluxes(theta_eq,H)
    q_eq_required,qH_eq_required=required_equilibrium_fluxes(H,Hdot)

    q=q_state-q_eq_discrete+q_eq_required
    qH=qH_state-qH_eq_discrete+qH_eq_required
    return q,qH


def rhs(y:np.ndarray,H:float,Hdot:float)->tuple[np.ndarray,float]:
    q,qH=corrected_fluxes(y,H,Hdot)
    dy=np.zeros(NFIXED+2,dtype=float)
    dy[0]=-q[0]
    for i in range(1,NFIXED):
        dy[i]=q[i-1]-q[i]
    dy[NFIXED]=q[NFIXED-1]-qH+THETA_S*Hdot
    dy[NFIXED+1]=qH
    return dy,qH


def equilibrium_exact_derivative(H:float,Hdot:float)->np.ndarray:
    dy=np.zeros(NFIXED+2,dtype=float)
    for i in range(NFIXED):
        z0=i*FIXED_DZ
        z1=(i+1)*FIXED_DZ
        dy[i]=(float(theta_from_psi(H-z0))-float(theta_from_psi(H-z1)))*Hdot
    dy[NFIXED]=float(theta_from_psi(H-ANCHOR))*Hdot
    dy[NFIXED+1]=(THETA_S-float(theta_from_psi(H)))*Hdot
    return dy


def heun_step(y,dt,H0,H1,Hdot):
    f0,_=rhs(y,H0,Hdot)
    guess=y+dt*f0
    for iteration in range(1,MAX_CORRECTOR+1):
        f1,_=rhs(guess,H1,Hdot)
        nxt=y+0.5*dt*(f0+f1)
        old_theta=unpack_theta(guess,H1)
        new_theta=unpack_theta(nxt,H1)
        if np.max(np.abs(new_theta-old_theta))<=CORRECTOR_TOL:
            return nxt,iteration
        guess=nxt
    raise RuntimeError("NUMERICAL_BLOCKED iterative Heun corrector")


def initial_state(history,init_meta,init_nodes):
    profile=init_nodes[history]
    H0=diagnose_H(profile)
    if H0<=ANCHOR:
        raise ValueError("initial H not below anchor")
    fixed=np.asarray([profile[i]["theta"]*FIXED_DZ for i in range(1,NFIXED+1)],dtype=float)
    U0=init_meta[history]["total"]-THETA_S*(PROFILE_DEPTH-H0)
    moving=U0-float(np.sum(fixed))
    theta_m=moving/(H0-ANCHOR)
    psi_k(np.concatenate([fixed/FIXED_DZ,[theta_m]]))
    y=np.concatenate([fixed,[moving],[0.0]])
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


def quadrature_crosscheck(H_values:list[float])->float:
    maximum=0.0
    for H in H_values:
        for i in range(NFIXED):
            z0=i*FIXED_DZ;z1=(i+1)*FIXED_DZ
            maximum=max(maximum,abs(
                integrate_hydrostatic_storage(z0,z1,H,64)-
                integrate_hydrostatic_storage(z0,z1,H,128)
            ))
        maximum=max(maximum,abs(
            integrate_hydrostatic_storage(ANCHOR,H,H,64)-
            integrate_hydrostatic_storage(ANCHOR,H,H,128)
        ))
    return maximum


def manifold_rhs_crosscheck(samples:list[tuple[float,float]])->float:
    maximum=0.0
    for H,Hdot in samples:
        eq=equilibrium_state(H)
        y=np.concatenate([eq,[0.0]])
        got,_=rhs(y,H,Hdot)
        expected=equilibrium_exact_derivative(H,Hdot)
        maximum=max(maximum,float(np.max(np.abs(got-expected))))
    return maximum


def solve(history,dt,init_meta,init_nodes,states,nodes):
    ratio=OBS_DT/dt
    nsub=int(round(ratio))
    if nsub<=0 or abs(ratio-nsub)>1.0e-12:
        raise RuntimeError("dt does not divide observation interval")

    y,Hprev,U0=initial_state(history,init_meta,init_nodes)
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
            fa=sub/nsub;fb=(sub+1)/nsub
            Ha=Hprev+(Hend-Hprev)*fa
            Hb=Hprev+(Hend-Hprev)*fb
            y,it=heun_step(y,dt,Ha,Hb,Hdot)
            max_corrector=max(max_corrector,it)

        theta=unpack_theta(y,Hend)
        psi_k(theta)
        moving=float(y[NFIXED])
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
        "trajectory":rows,
    }


def numerical_floor(coarse,fine):
    def arr(name,row):
        return np.asarray([x[name] for x in row["trajectory"]],dtype=float)
    return {
        "max_abs_total_unsaturated_storage_difference_cm":float(np.max(np.abs(
            arr("total_unsaturated_storage_error_cm",coarse)-arr("total_unsaturated_storage_error_cm",fine)
        ))),
        "max_abs_cumulative_qH_difference_cm":float(np.max(np.abs(
            arr("cumulative_qH_error_cm",coarse)-arr("cumulative_qH_error_cm",fine)
        ))),
        "max_abs_interval_qH_difference_cm_per_day":float(np.max(np.abs(
            arr("interval_qH_error_cm_per_day",coarse)-arr("interval_qH_error_cm_per_day",fine)
        ))),
    }


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


def gate_value(value):
    return math.inf if value is None else float(value)


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--b0-result",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    b0=json.loads(args.b0_result.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_EQUILIBRIUM_SUBTRACTED_MOVING_GEOMETRY_CONTROL"
    assert pre["predecessor"]["required_b0_decision"]==b0["decision"]
    assert b0["decision"]=="BC2_CONSERVATIVE_MOVING_GEOMETRY_QUALIFIED_WITH_RESPONSE_CONFUNDING"

    init_meta,init_nodes,states,nodes=load_reference(args.reference)

    H_values=[]
    rhs_samples=[]
    for history,nsteps in HISTORY_STEPS.items():
        Hprev=diagnose_H(init_nodes[history])
        H_values.append(Hprev)
        for step in range(1,nsteps+1):
            H=diagnose_H(nodes[(history,step)])
            Hdot=(H-Hprev)/OBS_DT
            H_values.append(H)
            rhs_samples.append((0.5*(Hprev+H),Hdot))
            Hprev=H

    # Subsample only for the quadrature duplication check; the same deterministic
    # 64-point rule is used at every RHS evaluation.
    stride=max(1,len(H_values)//128)
    quad_error=quadrature_crosscheck(H_values[::stride]+[min(H_values),max(H_values)])
    rhs_error=manifold_rhs_crosscheck(rhs_samples[::max(1,len(rhs_samples)//256)])

    cases={}
    for history in HISTORY_STEPS:
        refinements={};failures={}
        for dt in HEUN_DT:
            key=f"{dt:.7f}"
            try:
                refinements[key]=solve(history,dt,init_meta,init_nodes,states,nodes)
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
        cases[history]={"status":status,"fine":fine,"numerical_floor":floor,"failures":failures}

    all_qualified=all(row["status"]=="QUALIFIED" for row in cases.values())
    all_floor=all(row["numerical_floor"] is not None for row in cases.values())
    max_ledger=max(
        row["fine"]["max_abs_physical_moving_ledger_residual_cm"]
        for row in cases.values() if row["fine"] is not None
    ) if any(row["fine"] is not None for row in cases.values()) else math.inf

    comparisons={}
    all_noninferior=True
    strict_any=False
    for history,row in cases.items():
        fine=compact(row)
        base=b0["conservative"][history]
        if fine["status"]!="QUALIFIED":
            comparisons[history]={"qualified":False}
            all_noninferior=False
            continue
        components={
            "total_storage":fine["max_abs_total_unsaturated_storage_error_cm"]<=base["max_total_unsat_error_cm"]+1e-14,
            "cumulative_qH":fine["max_abs_cumulative_qH_error_cm"]<=base["max_cum_qH_error_cm"]+1e-14,
            "sign_mismatch":fine["qH_sign_mismatch_count"]<=base["sign_mismatch_count"],
            "reversal_step":gate_value(fine["max_reversal_step_difference"])<=gate_value(base.get("max_reversal_step_difference"))+1e-14,
        }
        strict={
            "total_storage":fine["max_abs_total_unsaturated_storage_error_cm"]<base["max_total_unsat_error_cm"]-1e-12,
            "cumulative_qH":fine["max_abs_cumulative_qH_error_cm"]<base["max_cum_qH_error_cm"]-1e-12,
            "sign_mismatch":fine["qH_sign_mismatch_count"]<base["sign_mismatch_count"],
            "reversal_step":gate_value(fine["max_reversal_step_difference"])<gate_value(base.get("max_reversal_step_difference"))-1e-12,
        }
        noninferior=all(components.values())
        all_noninferior &= noninferior
        strict_any |= any(strict.values())
        comparisons[history]={
            "qualified":True,
            "component_noninferiority":components,
            "strict_improvement":strict,
            "noninferior_all_components":noninferior,
            "b1":{
                "max_total_unsat_error_cm":fine["max_abs_total_unsaturated_storage_error_cm"],
                "max_cum_qH_error_cm":fine["max_abs_cumulative_qH_error_cm"],
                "max_interval_qH_error_cm_per_day":fine["max_abs_interval_qH_error_cm_per_day"],
                "sign_mismatch_count":fine["qH_sign_mismatch_count"],
                "max_reversal_step_difference":fine["max_reversal_step_difference"],
            },
            "b0":{
                "max_total_unsat_error_cm":base["max_total_unsat_error_cm"],
                "max_cum_qH_error_cm":base["max_cum_qH_error_cm"],
                "max_interval_qH_error_cm_per_day":base["max_interval_qH_error_cm_per_day"],
                "sign_mismatch_count":base["sign_mismatch_count"],
                "max_reversal_step_difference":base.get("max_reversal_step_difference"),
            }
        }

    hard_ok=(
        all_qualified and all_floor
        and quad_error<=QUAD_GATE
        and rhs_error<=RHS_GATE
        and max_ledger<=LEDGER_GATE
    )

    if not hard_ok:
        decision="BC2_B1_EQSUB_CONTROL_NUMERICALLY_BLOCKED"
    elif all_noninferior and strict_any:
        decision="BC2_B1_EQSUB_CONTROL_RELATIVE_SUPPORT"
    elif any(
        any(v for v in row.get("component_noninferiority",{}).values())
        for row in comparisons.values()
    ):
        decision="BC2_B1_EQSUB_CONTROL_MIXED_RESPONSE"
    else:
        decision="BC2_B1_EQSUB_CONTROL_NO_RELATIVE_SUPPORT"

    hold=compact(cases["WT_HOLD"])
    b0hold=b0["conservative"]["WT_HOLD"]
    result={
        "schema":"swap5.lare.bc2.b1.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-B1",
        "decision":decision,
        "hard_gates":{
            "all_histories_qualified":all_qualified,
            "all_histories_have_temporal_floor":all_floor,
            "quadrature_64_vs_128_max_storage_difference_cm":quad_error,
            "quadrature_gate_cm":QUAD_GATE,
            "hydrostatic_manifold_rhs_max_residual_cm_per_day":rhs_error,
            "hydrostatic_manifold_rhs_gate_cm_per_day":RHS_GATE,
            "max_physical_moving_ledger_residual_cm":max_ledger,
            "ledger_gate_cm":LEDGER_GATE,
        },
        "histories":{h:compact(cases[h]) for h in HISTORY_STEPS},
        "relative_to_B0":comparisons,
        "stationary_WT_HOLD_attribution":{
            "B0_total_storage_error_cm":b0hold["max_total_unsat_error_cm"],
            "B1_total_storage_error_cm":hold["max_abs_total_unsaturated_storage_error_cm"],
            "storage_error_ratio_B1_over_B0":hold["max_abs_total_unsaturated_storage_error_cm"]/b0hold["max_total_unsat_error_cm"],
            "B0_cumulative_qH_error_cm":b0hold["max_cum_qH_error_cm"],
            "B1_cumulative_qH_error_cm":hold["max_abs_cumulative_qH_error_cm"],
            "cumulative_error_ratio_B1_over_B0":hold["max_abs_cumulative_qH_error_cm"]/b0hold["max_cum_qH_error_cm"],
            "B0_sign_mismatch_count":b0hold["sign_mismatch_count"],
            "B1_sign_mismatch_count":hold["qH_sign_mismatch_count"],
        },
        "interpretation":[
            "BC2-B1 is a diagnostic equilibrium-path-preserving control, not selected production LARE physics.",
            "The correction has no fitted coefficient: it subtracts the standard-LARE discrete hydrostatic residual and adds the exact flux path required by the moving hydrostatic storage manifold.",
            "WT_HOLD isolates fixed-geometry hydrostatic drift. Moving-history residuals after that drift is reduced quantify non-equilibrium closure/geometry response under the prescribed Reference H(t).",
            "No hydrological application tolerance is applied."
        ],
        "application_acceptance_adjudicated":False,
        "speed_claim":False,
        "production_rom_authorized":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":decision,
        "hard_gates":result["hard_gates"],
        "stationary_WT_HOLD_attribution":result["stationary_WT_HOLD_attribution"],
        "relative_to_B0":comparisons,
    },sort_keys=True))
    return 0 if hard_ok else 2


if __name__=="__main__":
    raise SystemExit(main())
