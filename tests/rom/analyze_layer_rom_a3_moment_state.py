#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import pathlib
from collections import defaultdict

import numpy as np
from scipy.optimize import least_squares

HERE=pathlib.Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location("a2b",HERE/"analyze_layer_rom_a2b_integrated_closures.py")
a2b=importlib.util.module_from_spec(spec)
spec.loader.exec_module(a2b)

L=140.0
ZC=70.0
ZFACE_UPPER_CENTER=135.0
PRIMARY=("S2_B1_F2","S2_B1_F3","S2_B1_F4","S3_B1_F3")
CANDIDATES=("C_M1_LINEAR_THETA","C_M1_LINEAR_PSI")
GL={n:np.polynomial.legendre.leggauss(n) for n in (64,128)}

def m1_reference(rows):
    vals=[r for r in rows if r["z"]+0.5*r["dz"]<=L+1e-9]
    covered=sum(r["dz"] for r in vals)
    if abs(covered-L)>1e-9:
        raise ValueError("long-layer coverage mismatch")
    mean=sum(r["theta"]*r["dz"] for r in vals)/L
    m1=sum((r["z"]-ZC)*r["theta"]*r["dz"] for r in vals)/L
    return mean,m1

def theta_linear_reconstruct(mean,m1,z):
    slope=12.0*m1/(L*L)
    theta=mean+slope*(z-ZC)
    t0=mean+slope*(0.0-ZC)
    t1=mean+slope*(L-ZC)
    if min(t0,t1)<=a2b.TR or max(t0,t1)>=a2b.TS:
        raise ValueError("linear-theta reconstruction outside constitutive domain")
    return theta,slope

def moments_linear_psi(center,slope,nq):
    xg,wg=GL[nq]
    z=0.5*L*(xg+1.0)
    psi=center+slope*(z-ZC)
    if np.min(psi)<=a2b.PSI_MIN or not np.all(np.isfinite(psi)):
        raise ValueError("linear-psi reconstruction outside strict-unsaturated domain")
    theta=a2b.theta_from_psi(psi)
    mean=float(0.5*np.sum(wg*theta))
    m1=float(0.5*np.sum(wg*(z-ZC)*theta))
    return mean,m1

def solve_linear_psi(mean_target,m1_target,pre):
    num=pre["pre_execution_numerical_freeze"]
    tol=num["least_squares"]
    psi0=a2b.psi_from_theta(mean_target)
    x0=np.asarray([math.log(max(psi0-0.01,1e-10)),0.0],dtype=float)
    scale_theta=a2b.TS-a2b.TR
    scale_m1=scale_theta*L

    def decode(x):
        center=0.01+math.exp(float(np.clip(x[0],-25.0,20.0)))
        slope=((center-0.01)/(0.5*L))*math.tanh(float(np.clip(x[1],-20.0,20.0)))
        return center,slope

    def residual(x):
        center,slope=decode(x)
        try:
            mean,m1=moments_linear_psi(center,slope,64)
        except Exception:
            return np.asarray([10.0,10.0])
        return np.asarray([(mean-mean_target)/scale_theta,(m1-m1_target)/scale_m1])

    sol=least_squares(
        residual,x0,xtol=tol["xtol"],ftol=tol["ftol"],gtol=tol["gtol"],
        max_nfev=tol["max_nfev"]
    )
    center,slope=decode(sol.x)
    mean64,m164=moments_linear_psi(center,slope,64)
    mean128,m1128=moments_linear_psi(center,slope,128)
    gates=num["reconstruction_gates"]
    checks={
        "mean_residual":abs(mean64-mean_target),
        "M1_residual_cm":abs(m164-m1_target),
        "mean_64_128":abs(mean64-mean128),
        "M1_64_128_cm":abs(m164-m1128)
    }
    if (
        not sol.success
        or checks["mean_residual"]>gates["max_abs_mean_theta_residual"]
        or checks["M1_residual_cm"]>gates["max_abs_M1_residual_cm"]
        or checks["mean_64_128"]>gates["max_abs_64_vs_128_mean_theta"]
        or checks["M1_64_128_cm"]>gates["max_abs_64_vs_128_M1_cm"]
    ):
        raise RuntimeError(f"linear-psi moment solve failed {checks}")
    return center,slope,int(sol.nfev),checks

def face_flux(theta_upper,theta_lower):
    psi_u=a2b.psi_from_theta(theta_upper)
    psi_l=a2b.psi_from_theta(theta_lower)
    ku=a2b.k_from_theta(theta_upper)
    kl=a2b.k_from_theta(theta_lower)
    return 0.5*(ku+kl)*(1.0+(psi_l-psi_u)/10.0)

def metrics(rows):
    if not rows:
        return {
            "count":0,"rms":None,"max_abs":None,"mean_signed":None,
            "sign_mismatch":0,"theta135_rms":None,"psi135_rms":None,"K135_rms":None
        }
    e=np.asarray([r["qerr"] for r in rows],dtype=float)
    te=np.asarray([r["theta135_err"] for r in rows],dtype=float)
    pe=np.asarray([r["psi135_err"] for r in rows],dtype=float)
    ke=np.asarray([r["K135_err"] for r in rows],dtype=float)
    return {
        "count":len(rows),
        "rms":float(np.sqrt(np.mean(e*e))),
        "max_abs":float(np.max(np.abs(e))),
        "mean_signed":float(np.mean(e)),
        "sign_mismatch":int(sum(r["sign_mismatch"] for r in rows)),
        "theta135_rms":float(np.sqrt(np.mean(te*te))),
        "theta135_max_abs":float(np.max(np.abs(te))),
        "psi135_rms_cm":float(np.sqrt(np.mean(pe*pe))),
        "psi135_max_abs_cm":float(np.max(np.abs(pe))),
        "K135_rms_cm_per_day":float(np.sqrt(np.mean(ke*ke))),
        "K135_max_abs_cm_per_day":float(np.max(np.abs(ke)))
    }

def baseline_metrics(errors,sign_mismatch):
    e=np.asarray(errors,dtype=float)
    return {
        "count":len(errors),
        "rms":float(np.sqrt(np.mean(e*e))),
        "max_abs":float(np.max(np.abs(e))),
        "mean_signed":float(np.mean(e)),
        "sign_mismatch":int(sign_mismatch)
    }

def structural_tests(pre):
    # uniform state -> zero moment and uniform reconstruction
    theta=a2b.TR+0.70*(a2b.TS-a2b.TR)
    tl,slope=theta_linear_reconstruct(theta,0.0,ZFACE_UPPER_CENTER)
    c,b,_,checks=solve_linear_psi(theta,0.0,pre)
    tp=float(a2b.theta_from_psi(c+b*(ZFACE_UPPER_CENTER-ZC)))
    if abs(tl-theta)>1e-14 or abs(slope)>1e-14 or abs(tp-theta)>1e-10:
        raise SystemExit("uniform moment identity failed")

    # synthetic linear-theta exactness
    mean=0.30; slope_true=2.0e-4
    m1=slope_true*L*L/12.0
    got,slope=theta_linear_reconstruct(mean,m1,ZFACE_UPPER_CENTER)
    expected=mean+slope_true*(ZFACE_UPPER_CENTER-ZC)
    if abs(got-expected)>1e-14 or abs(slope-slope_true)>1e-14:
        raise SystemExit("linear-theta synthetic identity failed")

    # synthetic linear-psi recovery
    center_true=45.0; slope_true=0.12
    mt,m1t=moments_linear_psi(center_true,slope_true,128)
    center,slope,_,checks2=solve_linear_psi(mt,m1t,pre)
    if abs(center-center_true)>1e-7 or abs(slope-slope_true)>1e-9:
        raise SystemExit(f"linear-psi synthetic identity failed {center} {slope}")
    return {
        "uniform_theta135_abs_error":abs(tp-theta),
        "linear_theta_slope_abs_error":abs(slope_true-(12.0*m1/(L*L))),
        "linear_psi_center_abs_error_cm":abs(center-center_true),
        "linear_psi_slope_abs_error":abs(slope-slope_true),
        "linear_psi_synthetic_checks":checks2
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_FIRST_MOMENT_STATE_RESULT"
    assert pre["pre_execution_numerical_freeze"]["before_first_A3_execution"] is True
    tests=structural_tests(pre)

    pooled={c:[] for c in CANDIDATES}
    per_case={}
    failures={c:0 for c in CANDIDATES}
    max_nfev=0
    max_res={"mean":0.0,"M1":0.0,"mean_cross":0.0,"M1_cross":0.0}
    base_pooled=[]
    base_sign=0
    l4long_pooled=[]
    l4long_sign=0
    l4local_max=0.0

    for case in PRIMARY:
        trajectory=a2b.load_case(args.reference_dir/f"fine-{case}-o2.txt")
        case_rows={c:[] for c in CANDIDATES}
        base_errors=[]; base_case_sign=0
        l4_errors=[]; l4_case_sign=0

        for step in range(1,1025):
            rows=trajectory[step]
            mean,m1=m1_reference(rows)
            l3=a2b.layer_means(rows,[0.0,140.0,150.0,160.0])
            lower=l3[1]
            qref140=a2b.reference_flux(rows,140.0)
            qbase=a2b.q_lare(l3[0],l3[1],140.0,10.0)
            base_errors.append(qbase-qref140)
            base_pooled.append(qbase-qref140)
            base_case_sign+=int(np.sign(qbase)!=np.sign(qref140))
            base_sign+=int(np.sign(qbase)!=np.sign(qref140))

            # Same-dimension L4 controls.
            l4=a2b.layer_means(rows,[0.0,130.0,140.0,150.0,160.0])
            ql4local=a2b.q_lare(l4[1],l4[2],10.0,10.0)
            l4local_max=max(l4local_max,abs(ql4local-qref140))
            qref130=a2b.reference_flux(rows,130.0)
            ql4long=a2b.q_lare(l4[0],l4[1],130.0,10.0)
            l4_errors.append(ql4long-qref130)
            l4long_pooled.append(ql4long-qref130)
            l4_case_sign+=int(np.sign(ql4long)!=np.sign(qref130))
            l4long_sign+=int(np.sign(ql4long)!=np.sign(qref130))

            actual=rows[13]
            theta135=float(actual["theta"])
            psi135=-float(actual["h"])
            K135=float(a2b.k_from_theta(theta135))

            try:
                theta_u,_=theta_linear_reconstruct(mean,m1,ZFACE_UPPER_CENTER)
                q=face_flux(theta_u,lower)
                psi_u=a2b.psi_from_theta(theta_u)
                K_u=a2b.k_from_theta(theta_u)
                rec={
                    "qerr":q-qref140,
                    "sign_mismatch":int(np.sign(q)!=np.sign(qref140)),
                    "theta135_err":theta_u-theta135,
                    "psi135_err":psi_u-psi135,
                    "K135_err":K_u-K135
                }
                case_rows["C_M1_LINEAR_THETA"].append(rec)
                pooled["C_M1_LINEAR_THETA"].append(rec)
            except Exception:
                failures["C_M1_LINEAR_THETA"]+=1

            try:
                center,slope,nfev,checks=solve_linear_psi(mean,m1,pre)
                max_nfev=max(max_nfev,nfev)
                max_res["mean"]=max(max_res["mean"],checks["mean_residual"])
                max_res["M1"]=max(max_res["M1"],checks["M1_residual_cm"])
                max_res["mean_cross"]=max(max_res["mean_cross"],checks["mean_64_128"])
                max_res["M1_cross"]=max(max_res["M1_cross"],checks["M1_64_128_cm"])
                psi_u=center+slope*(ZFACE_UPPER_CENTER-ZC)
                theta_u=float(a2b.theta_from_psi(psi_u))
                K_u=float(a2b.k_from_psi(psi_u))
                q=face_flux(theta_u,lower)
                rec={
                    "qerr":q-qref140,
                    "sign_mismatch":int(np.sign(q)!=np.sign(qref140)),
                    "theta135_err":theta_u-theta135,
                    "psi135_err":psi_u-psi135,
                    "K135_err":K_u-K135
                }
                case_rows["C_M1_LINEAR_PSI"].append(rec)
                pooled["C_M1_LINEAR_PSI"].append(rec)
            except Exception:
                failures["C_M1_LINEAR_PSI"]+=1

        per_case[case]={
            "L3_C_LARE_TAYLOR":baseline_metrics(base_errors,base_case_sign),
            "L4_C_LARE_TAYLOR_LONG_130":baseline_metrics(l4_errors,l4_case_sign),
            **{c:metrics(case_rows[c]) for c in CANDIDATES}
        }

    base=baseline_metrics(base_pooled,base_sign)
    l4long=baseline_metrics(l4long_pooled,l4long_sign)
    pooled_metrics={c:metrics(pooled[c]) for c in CANDIDATES}

    support={}
    for c in CANDIDATES:
        row=pooled_metrics[c]
        component={
            "rms":row["rms"]<=base["rms"]+1e-15,
            "max_abs":row["max_abs"]<=base["max_abs"]+1e-15,
            "sign":row["sign_mismatch"]<=base["sign_mismatch"],
            "failure":failures[c]==0
        }
        strict=(row["rms"]<base["rms"]-1e-15 or row["max_abs"]<base["max_abs"]-1e-15 or row["sign_mismatch"]<base["sign_mismatch"])
        worse=[]
        for case in PRIMARY:
            b=per_case[case]["L3_C_LARE_TAYLOR"]
            q=per_case[case][c]
            if q["rms"]>b["rms"]+1e-15 and q["max_abs"]>b["max_abs"]+1e-15:
                worse.append(case)
        support[c]={
            "component_noninferiority":component,
            "strict_improvement":strict,
            "worse_on_both_rms_and_max_cases":worse,
            "supported":all(component.values()) and strict and not worse
        }

    supported=[c for c,v in support.items() if v["supported"]]
    decision="A3_FIRST_MOMENT_INFORMATION_SUPPORTED" if supported else "A3_FIRST_MOMENT_INFORMATION_NOT_SUPPORTED"

    gates=pre["pre_execution_numerical_freeze"]["reconstruction_gates"]
    if l4local_max>gates["L4_local_140_flux_identity_cm_per_day"]:
        raise SystemExit(f"L4 local face identity failed: {l4local_max}")

    result={
        "schema":"swap5.layer-rom.phase-a3.result.v1",
        "workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-A3",
        "decision":decision,
        "structural_tests":tests,
        "L3_baseline":base,
        "L3_M1":pooled_metrics,
        "L4_same_dimension_long_130":l4long,
        "L4_local_140_max_abs_flux_identity_error_cm_per_day":l4local_max,
        "per_case":per_case,
        "candidate_failures":failures,
        "candidate_support":support,
        "numerical":{
            "max_linear_psi_nfev":max_nfev,
            "max_mean_theta_residual":max_res["mean"],
            "max_M1_residual_cm":max_res["M1"],
            "max_mean_64_128_difference":max_res["mean_cross"],
            "max_M1_64_128_difference_cm":max_res["M1_cross"]
        },
        "interpretation_firewalls":[
            "Exact teacher-forced Reference moment state only; no moment evolution or reduced propagation is executed.",
            "No empirical coefficient or response fitting is used.",
            "L4 is the same-dimension explicit-resolution control, not an acceptance threshold.",
            "No application acceptance or speed claim follows."
        ],
        "reduced_state_propagated":False,
        "application_acceptance":False,
        "production_rom_authorized":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":decision,
        "L3_baseline":base,
        "L3_M1":pooled_metrics,
        "L4_same_dimension_long_130":l4long,
        "L4_local_140_identity_max":l4local_max,
        "candidate_support":support,
        "candidate_failures":failures,
        "numerical":result["numerical"]
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
