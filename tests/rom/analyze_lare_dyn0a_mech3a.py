#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib

import numpy as np
from scipy.integrate import quad
from scipy.optimize import brentq


def mvg(material: dict[str, float]):
    tr=float(material["theta_r"])
    ts=float(material["theta_s"])
    alpha=float(material["alpha_per_cm"])
    n=float(material["n"])
    ks=float(material["Ksat_cm_per_day"])
    lam=float(material["lambda"])
    m=1.0-1.0/n

    def theta_from_se(se: float) -> float:
        return tr+(ts-tr)*se

    def se_from_theta(theta: float) -> float:
        return (theta-tr)/(ts-tr)

    def conductivity_se(se: float) -> float:
        if not (0.0 < se < 1.0):
            if se >= 1.0:
                return ks
            return 0.0
        bracket=1.0-(1.0-se**(1.0/m))**m
        return ks*se**lam*bracket**2

    def h_from_se(se: float) -> float:
        a=se**(-1.0/m)-1.0
        return -(a**(1.0/n))/alpha

    def dh_dtheta(theta: float) -> float:
        se=se_from_theta(theta)
        a=se**(-1.0/m)-1.0
        dh_dse=(1.0/(alpha*n*m))*a**(1.0/n-1.0)*se**(-1.0/m-1.0)
        return dh_dse/(ts-tr)

    def diffusivity_theta(theta: float) -> float:
        se=se_from_theta(theta)
        return conductivity_se(se)*dh_dtheta(theta)

    return {
        "theta_from_se":theta_from_se,
        "se_from_theta":se_from_theta,
        "K_se":conductivity_se,
        "h_se":h_from_se,
        "D_theta":diffusivity_theta,
        "tr":tr,"ts":ts,"ks":ks,
    }


def target_se(model, se0: float, multiplier: float) -> float:
    k0=model["K_se"](se0)
    target=multiplier*k0
    if not (0.0 < target < model["ks"]):
        raise ValueError(f"target K outside unsaturated branch: {target}")
    if multiplier > 1.0:
        lo,hi=se0,1.0-1.0e-12
    else:
        lo,hi=1.0e-10,se0
    return brentq(lambda se:model["K_se"](se)-target,lo,hi,xtol=1e-14,rtol=1e-14,maxiter=300)


def integrate_path(fun, theta0: float, theta1: float) -> float:
    val,err=quad(fun,theta0,theta1,epsabs=1e-12,epsrel=1e-10,limit=400)
    if not math.isfinite(val):
        raise ValueError("nonfinite integral")
    return val


def scales_for_case(model, se0: float, forcing: str, duration: float, wet_mult: float, dry_mult: float):
    mult=wet_mult if forcing=="WET" else dry_mult
    se1=target_se(model,se0,mult)
    theta0=model["theta_from_se"](se0)
    theta1=model["theta_from_se"](se1)
    delta=abs(theta1-theta0)
    if delta <= 0.0:
        raise ValueError("zero constitutive path")

    d0=model["D_theta"](theta0)
    int_d=abs(integrate_path(model["D_theta"],theta0,theta1))
    da=int_d/delta

    def ln_d(theta: float) -> float:
        d=model["D_theta"](theta)
        if not (d>0.0 and math.isfinite(d)):
            raise ValueError("invalid D for log path")
        return math.log(d)
    int_log=abs(integrate_path(ln_d,theta0,theta1))
    dg=math.exp(int_log/delta)

    def parlange_integrand(theta: float) -> float:
        return (theta1+theta-2.0*theta0)*model["D_theta"](theta)
    sd2=abs(integrate_path(parlange_integrand,theta0,theta1))
    sd=math.sqrt(sd2)

    return {
        "se1":se1,
        "theta0":theta0,
        "theta1":theta1,
        "delta_theta_abs":delta,
        "K0_cm_per_day":model["K_se"](se0),
        "K1_cm_per_day":model["K_se"](se1),
        "D0_cm2_per_day":d0,
        "D_path_arithmetic_cm2_per_day":da,
        "D_path_geometric_cm2_per_day":dg,
        "S_D_cm_per_sqrt_day":sd,
        "ell_cm":{
            "LOCAL_D0":math.sqrt(d0*duration),
            "PATH_ARITHMETIC_D":math.sqrt(da*duration),
            "PATH_GEOMETRIC_D":math.sqrt(dg*duration),
            "PARLANGE_SD":sd*math.sqrt(duration)/delta,
        }
    }


def metrics(rows, candidate: str):
    logs=np.asarray([math.log(row["lambda"][candidate]) for row in rows],dtype=float)
    center=float(np.mean(logs))
    centered=logs-center
    by_material={}
    by_forcing={}
    for material in sorted({row["material"] for row in rows}):
        vals=[math.log(row["lambda"][candidate]) for row in rows if row["material"]==material]
        by_material[material]=float(np.mean(vals))
    for forcing in sorted({row["forcing"] for row in rows}):
        vals=[math.log(row["lambda"][candidate]) for row in rows if row["forcing"]==forcing]
        by_forcing[forcing]=float(np.mean(vals))
    return {
        "global_geometric_multiplier_c":math.exp(center),
        "pooled_ln_lambda_std":float(np.std(logs,ddof=0)),
        "max_abs_centered_ln_lambda_residual":float(np.max(np.abs(centered))),
        "lambda_min":float(np.exp(np.min(logs))),
        "lambda_max":float(np.exp(np.max(logs))),
        "lambda_max_over_min":float(np.exp(np.max(logs)-np.min(logs))),
        "B01_vs_B14_abs_mean_ln_lambda_shift":abs(by_material["B01"]-by_material["B14"]),
        "WET_vs_DRY_abs_mean_ln_lambda_shift":abs(by_forcing["WET"]-by_forcing["DRY"]),
        "material_mean_ln_lambda":by_material,
        "forcing_mean_ln_lambda":by_forcing,
    }


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    p=json.loads(args.prereg.read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_NONLINEAR_PENETRATION_SCALE_COMPARISON"
    duration=float(p["pulse"]["duration_day"])
    wet_mult=float(p["pulse"]["wet_flux_multiplier"])
    dry_mult=float(p["pulse"]["dry_flux_multiplier"])
    materials={
        mid:mvg(p["constitutive_authority"][mid])
        for mid in ("B01","B14")
    }
    candidates=[row["id"] for row in p["candidate_scales"]]
    expected=["LOCAL_D0","PATH_ARITHMETIC_D","PATH_GEOMETRIC_D","PARLANGE_SD"]
    assert candidates==expected

    rows=[]
    for case in p["discovery_only"]["observed_cases"]:
        material=case["material"]
        se0=float(case["se0"])
        forcing=case["forcing"]
        peak=float(case["peak_L_cm"])
        c=scales_for_case(materials[material],se0,forcing,duration,wet_mult,dry_mult)
        lambdas={cid:peak/c["ell_cm"][cid] for cid in candidates}
        rows.append({
            **case,
            "forcing_equivalent_path":c,
            "lambda":lambdas,
        })

    summary={cid:metrics(rows,cid) for cid in candidates}
    ranking=sorted(
        candidates,
        key=lambda cid:(
            summary[cid]["pooled_ln_lambda_std"],
            summary[cid]["B01_vs_B14_abs_mean_ln_lambda_shift"],
            summary[cid]["max_abs_centered_ln_lambda_residual"],
            cid,
        )
    )
    selected=ranking[0]
    base=summary["LOCAL_D0"]
    chosen=summary[selected]
    eligible=(
        selected!="LOCAL_D0"
        and chosen["pooled_ln_lambda_std"] < base["pooled_ln_lambda_std"]
        and chosen["B01_vs_B14_abs_mean_ln_lambda_shift"] < base["B01_vs_B14_abs_mean_ln_lambda_shift"]
    )
    decision=(
        "NONLINEAR_SCALE_SELECTED_FOR_BLIND_VALIDATION"
        if eligible else
        "NO_SIMPLE_NONLINEAR_SCALE_SELECTED"
    )

    result={
        "schema":"swap5.lare.dyn0a.mech3a.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-DYN0A-MECH3A",
        "decision":decision,
        "discovery_only":True,
        "case_count":len(rows),
        "cases":rows,
        "candidate_metrics":summary,
        "selection_ranking":ranking,
        "selected_candidate":selected if eligible else None,
        "selected_candidate_before_eligibility_gate":selected,
        "blind_validation_eligible":eligible,
        "eligibility_check":{
            "selected_improves_pooled_log_dispersion_vs_LOCAL_D0":chosen["pooled_ln_lambda_std"] < base["pooled_ln_lambda_std"],
            "selected_improves_material_shift_vs_LOCAL_D0":chosen["B01_vs_B14_abs_mean_ln_lambda_shift"] < base["B01_vs_B14_abs_mean_ln_lambda_shift"],
        },
        "interpretation_firewall":[
            "B01 and B14 are discovery materials; no cross-material generality follows from this ranking.",
            "One global multiplicative c is reported only to expose scale dispersion and is not a fitted LARE parameter.",
            "Blind validation requires a new preregistration on previously unexposed materials before new peak trajectories are generated."
        ],
        "lare_closure_changed":False,
        "production_rom_authorized":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "schema":result["schema"],
        "decision":decision,
        "selection_ranking":ranking,
        "selected_candidate":result["selected_candidate"],
        "candidate_metrics":summary
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
