#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib
from collections import defaultdict

import numpy as np
from scipy.optimize import least_squares

TR=0.02
TS=0.427494
ALPHA=0.021659
N=1.734737
M=1.0-1.0/N
KS=31.225016
LAM=0.98087
PSI_MIN=0.01
L=140.0
CENTER=70.0
PRIMARY=("S2_B1_F2","S2_B1_F3","S2_B1_F4","S3_B1_F3")
CANDIDATES=("C_M1_LINEAR_THETA","C_M1_LINEAR_PSI")
XTOL=1.0e-12
FTOL=1.0e-12
GTOL=1.0e-12
MAX_NFEV=80
MEAN_GATE=1.0e-10
M1_GATE=1.0e-9
QUAD_MEAN_GATE=1.0e-10
QUAD_M1_GATE=1.0e-9
LOCAL_IDENTITY_GATE=1.0e-10
GL={n:np.polynomial.legendre.leggauss(n) for n in (64,128)}


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
    if not (0.0 < se < 1.0):
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


def select_band(rows,lo,hi):
    selected=[
        r for r in rows
        if r["z"]-0.5*r["dz"] >= lo-1e-9
        and r["z"]+0.5*r["dz"] <= hi+1e-9
    ]
    covered=sum(r["dz"] for r in selected)
    if abs(covered-(hi-lo))>1e-9:
        raise ValueError(f"band coverage mismatch {lo}-{hi}: {covered}")
    return selected


def mean_theta(rows,lo,hi):
    rr=select_band(rows,lo,hi)
    return sum(r["theta"]*r["dz"] for r in rr)/(hi-lo)


def exact_m1(rows):
    rr=select_band(rows,0.0,L)
    # Exact for the piecewise-constant fine-cell state because the centered
    # coordinate integrates to dz*(cell_center-CENTER) on each cell.
    return sum(r["theta"]*r["dz"]*(r["z"]-CENTER) for r in rr)/L


def ref_flux(rows,boundary):
    upper_node=int(round(boundary/10.0))
    lower_node=upper_node+1
    ru=rows[upper_node-1]
    rl=rows[lower_node-1]
    pu=-ru["h"]; pl=-rl["h"]
    if pu<=PSI_MIN or pl<=PSI_MIN:
        raise ValueError("Reference face outside strict unsaturated domain")
    ku=float(k_from_psi(pu)); kl=float(k_from_psi(pl))
    return 0.5*(ku+kl)*(1.0+(pl-pu)/10.0)


def q_equal10(theta_u,theta_l):
    pu=psi_from_theta(theta_u); pl=psi_from_theta(theta_l)
    ku=k_from_theta(theta_u); kl=k_from_theta(theta_l)
    return 0.5*(ku+kl)*(1.0+(pl-pu)/10.0)


def q_lare(theta_u,theta_l,du,dl):
    pu=psi_from_theta(theta_u); pl=psi_from_theta(theta_l)
    ku=k_from_theta(theta_u); kl=k_from_theta(theta_l)
    kface=(dl*ku+du*kl)/(du+dl)
    return kface*(1.0+2.0*(pl-pu)/(du+dl))


def linear_theta_virtual(theta_bar,m1):
    b=12.0*m1/(L*L)
    theta_top=theta_bar-b*L/2.0
    theta_bottom=theta_bar+b*L/2.0
    if not (TR < theta_top < TS and TR < theta_bottom < TS):
        raise ValueError("linear-theta reconstruction outside physical theta domain")
    theta135=theta_bar+b*(135.0-CENTER)
    if not TR < theta135 < TS:
        raise ValueError("linear-theta virtual point outside physical theta domain")
    psi135=psi_from_theta(theta135)
    if psi135<=PSI_MIN:
        raise ValueError("linear-theta virtual point outside strict psi domain")
    return {
        "theta135":theta135,
        "psi135":psi135,
        "k135":k_from_theta(theta135),
        "slope_theta_per_cm":b,
        "theta_top":theta_top,
        "theta_bottom":theta_bottom,
    }


def psi_params(x):
    pc=PSI_MIN+math.exp(float(x[0]))
    smax=(pc-PSI_MIN)/(L/2.0)
    slope=smax*math.tanh(float(x[1]))
    return pc,slope


def quad_linear_psi(x,nq):
    pc,slope=psi_params(x)
    xg,wg=GL[nq]
    z=0.5*L*(xg+1.0)
    psi=pc+slope*(z-CENTER)
    if np.min(psi)<=PSI_MIN or not np.all(np.isfinite(psi)):
        raise ValueError("linear-psi reconstruction outside strict domain")
    theta=theta_from_psi(psi)
    integral=0.5*L*np.sum(wg*theta)
    moment=0.5*L*np.sum(wg*(z-CENTER)*theta)/L
    return float(integral/L),float(moment)


def linear_psi_initial(theta_bar,m1):
    pc=psi_from_theta(theta_bar)
    btheta=12.0*m1/(L*L)
    t0=theta_bar-btheta*L/2.0
    t1=theta_bar+btheta*L/2.0
    slope=0.0
    if TR < t0 < TS and TR < t1 < TS:
        p0=psi_from_theta(t0); p1=psi_from_theta(t1)
        slope=(p1-p0)/L
    smax=max((pc-PSI_MIN)/(L/2.0),1e-14)
    ratio=max(-0.95,min(0.95,slope/smax))
    return np.asarray([math.log(pc-PSI_MIN),np.arctanh(ratio)],dtype=float)


def solve_linear_psi(theta_bar,m1):
    x0=linear_psi_initial(theta_bar,m1)
    scale_theta=TS-TR
    scale_m1=(TS-TR)*L

    def residual(x):
        try:
            mt,mm=quad_linear_psi(x,64)
            return np.asarray([(mt-theta_bar)/scale_theta,(mm-m1)/scale_m1])
        except (ValueError,FloatingPointError,OverflowError):
            return np.asarray([100.0,100.0])

    sol=least_squares(
        residual,x0,xtol=XTOL,ftol=FTOL,gtol=GTOL,max_nfev=MAX_NFEV
    )
    m64,m164=quad_linear_psi(sol.x,64)
    m128,m1128=quad_linear_psi(sol.x,128)
    mean_res=abs(m64-theta_bar)
    m1_res=abs(m164-m1)
    if (not sol.success or mean_res>MEAN_GATE or m1_res>M1_GATE
            or abs(m64-m128)>QUAD_MEAN_GATE or abs(m164-m1128)>QUAD_M1_GATE):
        raise ValueError(
            f"linear-psi reconstruction gate failed success={sol.success} "
            f"mean_res={mean_res} m1_res={m1_res} "
            f"quad_mean={abs(m64-m128)} quad_m1={abs(m164-m1128)}"
        )
    pc,slope=psi_params(sol.x)
    p0=pc-slope*L/2.0; p1=pc+slope*L/2.0
    if min(p0,p1)<=PSI_MIN:
        raise ValueError("linear-psi endpoint domain failure")
    psi135=pc+slope*(135.0-CENTER)
    theta135=float(theta_from_psi(psi135))
    k135=float(k_from_psi(psi135))
    return {
        "theta135":theta135,
        "psi135":psi135,
        "k135":k135,
        "psi_center":pc,
        "slope_psi_per_cm":slope,
        "mean_residual_theta":mean_res,
        "m1_residual_theta_cm":m1_res,
        "quad_mean_difference_theta":abs(m64-m128),
        "quad_m1_difference_theta_cm":abs(m164-m1128),
        "nfev":int(sol.nfev),
    }


def candidate_flux(state,theta_lower):
    pl=psi_from_theta(theta_lower); kl=k_from_theta(theta_lower)
    return 0.5*(state["k135"]+kl)*(1.0+(pl-state["psi135"])/10.0)


def rms(values):
    if not values:
        return None
    a=np.asarray(values,dtype=float)
    return float(np.sqrt(np.mean(a*a)))


def summarize(values):
    if not values:
        return {"count":0,"rms":None,"max_abs":None,"mean":None,"mean_abs":None}
    a=np.asarray(values,dtype=float)
    return {
        "count":int(len(a)),
        "rms":float(np.sqrt(np.mean(a*a))),
        "max_abs":float(np.max(np.abs(a))),
        "mean":float(np.mean(a)),
        "mean_abs":float(np.mean(np.abs(a))),
    }


def flux_summary(errors,sign_mismatch,failures):
    s=summarize(errors)
    return {
        "sample_count":s["count"],
        "rms_error_cm_per_day":s["rms"],
        "max_abs_error_cm_per_day":s["max_abs"],
        "mean_signed_error_cm_per_day":s["mean"],
        "mean_abs_error_cm_per_day":s["mean_abs"],
        "flux_sign_mismatch_count":int(sign_mismatch),
        "reconstruction_failure_count":int(failures),
    }


def sign(x):
    return 1 if x>0 else (-1 if x<0 else 0)


def structural_tests():
    # Uniform state identity.
    theta=0.30
    a=linear_theta_virtual(theta,0.0)
    p=solve_linear_psi(theta,0.0)
    if abs(a["theta135"]-theta)>1e-14 or abs(p["theta135"]-theta)>1e-9:
        raise SystemExit("A3 uniform-state identity failed")

    # Exact synthetic linear-theta reconstruction.
    tc=0.30; b=2.0e-4
    m1=b*L*L/12.0
    got=linear_theta_virtual(tc,m1)
    expected=tc+b*(135.0-CENTER)
    if abs(got["theta135"]-expected)>1e-14:
        raise SystemExit("A3 linear-theta synthetic identity failed")

    # Synthetic linear-psi profile recovery.
    pc=45.0; slope=0.20
    smax=(pc-PSI_MIN)/(L/2.0)
    xtrue=np.asarray([math.log(pc-PSI_MIN),np.arctanh(slope/smax)])
    mt,mm=quad_linear_psi(xtrue,128)
    rec=solve_linear_psi(mt,mm)
    expected_psi=pc+slope*(135.0-CENTER)
    if abs(rec["psi135"]-expected_psi)>1e-7:
        raise SystemExit("A3 linear-psi synthetic identity failed")
    return {
        "uniform_linear_theta_theta135_abs_error":abs(a["theta135"]-theta),
        "uniform_linear_psi_theta135_abs_error":abs(p["theta135"]-theta),
        "linear_theta_synthetic_theta135_abs_error":abs(got["theta135"]-expected),
        "linear_psi_synthetic_psi135_abs_error_cm":abs(rec["psi135"]-expected_psi),
    }


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    if pre["phase"]!="PREREGISTERED_BEFORE_FIRST_MOMENT_STATE_RESULT":
        raise SystemExit("wrong A3 preregistration phase")
    op=pre["pre_execution_operationalization"]
    if not op["before_first_A3_execution"]:
        raise SystemExit("A3 operationalization not frozen")
    rec=pre.get("pre_execution_authority_reconciliation",{})
    if not rec.get("before_first_A3_execution"):
        raise SystemExit("A3 numerical authority reconciliation not frozen")
    if rec.get("governing_numerics")!="pre_execution_numerical_freeze plus pre_execution_operationalization":
        raise SystemExit("A3 governing numerical authority drift")
    if "pre_execution_numerical_amendment" in pre:
        raise SystemExit("withdrawn A3 endpoint amendment still present")
    if tuple(c["id"] for c in pre["moment_closures"])!=CANDIDATES:
        raise SystemExit("A3 candidate list drift")
    tests=structural_tests()

    errors={c:[] for c in ("C_LARE_TAYLOR",)+CANDIDATES}
    signs={c:0 for c in ("C_LARE_TAYLOR",)+CANDIDATES}
    failures={c:0 for c in CANDIDATES}
    rec_theta={c:[] for c in CANDIDATES}
    rec_psi={c:[] for c in CANDIDATES}
    rec_k={c:[] for c in CANDIDATES}
    case_errors={case:{c:[] for c in ("C_LARE_TAYLOR",)+CANDIDATES} for case in PRIMARY}
    case_signs={case:{c:0 for c in ("C_LARE_TAYLOR",)+CANDIDATES} for case in PRIMARY}
    case_fail={case:{c:0 for c in CANDIDATES} for case in PRIMARY}
    l4_long={case:[] for case in PRIMARY}
    l4_local_identity=[]
    max_mean_res=max_m1_res=max_qmean=max_qm1=0.0
    max_nfev=0

    for case in PRIMARY:
        trajectory=load_case(args.reference_dir/f"fine-{case}-o2.txt")
        for step in range(1,1025):
            rows=trajectory[step]
            tbar=mean_theta(rows,0.0,140.0)
            tlower=mean_theta(rows,140.0,150.0)
            m1=exact_m1(rows)
            qref140=ref_flux(rows,140.0)
            qbase=q_lare(tbar,tlower,140.0,10.0)
            e=qbase-qref140
            errors["C_LARE_TAYLOR"].append(e)
            case_errors[case]["C_LARE_TAYLOR"].append(e)
            mismatch=int(sign(qbase)!=sign(qref140))
            signs["C_LARE_TAYLOR"]+=mismatch
            case_signs[case]["C_LARE_TAYLOR"]+=mismatch

            true=rows[13]  # 130-140 cm fine cell, center z=135 cm
            true_theta=float(true["theta"])
            true_psi=-float(true["h"])
            true_k=float(k_from_psi(true_psi))

            for cid in CANDIDATES:
                try:
                    state=linear_theta_virtual(tbar,m1) if cid=="C_M1_LINEAR_THETA" else solve_linear_psi(tbar,m1)
                    if cid=="C_M1_LINEAR_PSI":
                        max_mean_res=max(max_mean_res,state["mean_residual_theta"])
                        max_m1_res=max(max_m1_res,state["m1_residual_theta_cm"])
                        max_qmean=max(max_qmean,state["quad_mean_difference_theta"])
                        max_qm1=max(max_qm1,state["quad_m1_difference_theta_cm"])
                        max_nfev=max(max_nfev,state["nfev"])
                    q=candidate_flux(state,tlower)
                    err=q-qref140
                    errors[cid].append(err)
                    case_errors[case][cid].append(err)
                    mm=int(sign(q)!=sign(qref140))
                    signs[cid]+=mm
                    case_signs[case][cid]+=mm
                    rec_theta[cid].append(state["theta135"]-true_theta)
                    rec_psi[cid].append(state["psi135"]-true_psi)
                    rec_k[cid].append(state["k135"]-true_k)
                except (ValueError,RuntimeError,FloatingPointError,OverflowError):
                    failures[cid]+=1
                    case_fail[case][cid]+=1

            # Same-dimension L4 controls.
            t0130=mean_theta(rows,0.0,130.0)
            t130140=mean_theta(rows,130.0,140.0)
            qref130=ref_flux(rows,130.0)
            l4_long[case].append(q_lare(t0130,t130140,130.0,10.0)-qref130)
            qlocal=q_equal10(t130140,tlower)
            l4_local_identity.append(qlocal-qref140)

    max_local_identity=max(abs(x) for x in l4_local_identity)
    if max_local_identity>LOCAL_IDENTITY_GATE:
        raise SystemExit(f"A3 L4 local 140 identity failed: {max_local_identity}")

    pooled={
        c:flux_summary(errors[c],signs[c],failures.get(c,0))
        for c in ("C_LARE_TAYLOR",)+CANDIDATES
    }
    by_case={}
    for case in PRIMARY:
        by_case[case]={}
        for c in ("C_LARE_TAYLOR",)+CANDIDATES:
            by_case[case][c]=flux_summary(
                case_errors[case][c],
                case_signs[case][c],
                case_fail[case].get(c,0)
            )

    reconstruction={
        c:{
            "theta_135_error":summarize(rec_theta[c]),
            "psi_135_error_cm":summarize(rec_psi[c]),
            "K_135_error_cm_per_day":summarize(rec_k[c]),
        } for c in CANDIDATES
    }
    l4_control={
        "L4_LONG_130":{
            "pooled":summarize([e for case in PRIMARY for e in l4_long[case]]),
            "by_case":{case:summarize(l4_long[case]) for case in PRIMARY},
        },
        "L4_LOCAL_140":{
            "maximum_abs_flux_identity_error_cm_per_day":max_local_identity,
            "gate_cm_per_day":LOCAL_IDENTITY_GATE,
        }
    }

    base=pooled["C_LARE_TAYLOR"]
    support={}
    for cid in CANDIDATES:
        row=pooled[cid]
        noninferior={
            "rms":row["rms_error_cm_per_day"] is not None and row["rms_error_cm_per_day"]<=base["rms_error_cm_per_day"]+1e-15,
            "max_abs":row["max_abs_error_cm_per_day"] is not None and row["max_abs_error_cm_per_day"]<=base["max_abs_error_cm_per_day"]+1e-15,
            "sign":row["flux_sign_mismatch_count"]<=base["flux_sign_mismatch_count"],
            "failures":row["reconstruction_failure_count"]<=base["reconstruction_failure_count"],
        }
        strict=(
            row["rms_error_cm_per_day"]<base["rms_error_cm_per_day"]-1e-15
            or row["max_abs_error_cm_per_day"]<base["max_abs_error_cm_per_day"]-1e-15
            or row["flux_sign_mismatch_count"]<base["flux_sign_mismatch_count"]
        )
        worse=[]
        for case in PRIMARY:
            a=by_case[case][cid]; b=by_case[case]["C_LARE_TAYLOR"]
            if a["reconstruction_failure_count"]>0 or a["sample_count"]!=b["sample_count"]:
                worse.append({"case":case,"reason":"reconstruction_failure_or_missing"})
            elif (a["rms_error_cm_per_day"]>b["rms_error_cm_per_day"]+1e-15
                  and a["max_abs_error_cm_per_day"]>b["max_abs_error_cm_per_day"]+1e-15):
                worse.append({"case":case,"reason":"worse_on_rms_and_max"})
        support[cid]={
            "component_noninferiority":noninferior,
            "strict_improvement":strict,
            "broad_support":len(worse)==0,
            "worse_primary_cases":worse,
            "supported":all(noninferior.values()) and strict and len(worse)==0,
        }

    supported=[c for c in CANDIDATES if support[c]["supported"]]
    labels=op["decision_labels"]
    decision=labels["supported"] if supported else labels["unsupported"]

    result={
        "schema":"swap5.layer-rom.phase-a3.result.v1",
        "workstream":"F-ROM-LAYER",
        "work_unit":"LAYER-ROM-A3",
        "decision":decision,
        "supported_moment_closures":supported,
        "structural_tests":tests,
        "primary_cases":list(PRIMARY),
        "observations_per_case":1024,
        "pooled_flux":pooled,
        "by_case_flux":by_case,
        "reconstruction":reconstruction,
        "same_dimension_controls":l4_control,
        "support":support,
        "numerical":{
            "max_linear_psi_mean_residual_theta":max_mean_res,
            "max_linear_psi_M1_residual_theta_cm":max_m1_res,
            "max_64_vs_128_mean_theta":max_qmean,
            "max_64_vs_128_M1_theta_cm":max_qm1,
            "max_linear_psi_nfev":max_nfev,
        },
        "interpretation_firewalls":[
            "All A3 states are exact projections of fine Reference state; no reduced propagation occurs.",
            "No fitted coefficient, response-conditioned switch or partition retuning is used.",
            "L4_LOCAL_140 is an operator identity guard; L4_LONG_130 is a same-scalar-dimension localization control, not an application threshold.",
            "Operator support does not authorize a prognostic M1 evolution law; that requires a separate continuity-based preregistration."
        ],
        "reduced_state_propagated":False,
        "application_acceptance":False,
        "speed_claim":False,
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":decision,
        "supported_moment_closures":supported,
        "pooled_flux":pooled,
        "support":support,
        "reconstruction":reconstruction,
        "same_dimension_controls":l4_control,
        "numerical":result["numerical"],
        "structural_tests":tests,
    },sort_keys=True))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
