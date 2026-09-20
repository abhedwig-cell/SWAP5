#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import pathlib

import numpy as np
from scipy.optimize import least_squares


def load_core(path: pathlib.Path):
    spec=importlib.util.spec_from_file_location("c6c_core",path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    mod=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def condition_number(result):
    try:
        s=np.linalg.svd(result.jac,compute_uv=False)
        if len(s)==0 or s[-1]<=0.0:
            return math.inf
        return float(s[0]/s[-1])
    except Exception:
        return math.inf


def build_cases(core,p):
    bounds=[float(x) for x in p["representation"]["boundaries_cm"]]
    widths=[b-a for a,b in zip(bounds,bounds[1:])]
    cases=[]
    for profile in p["response_free_state_domain"]["mean_Se_profiles"]:
        ses=core.profile_se(profile,len(widths))
        means=[float(core.theta_from_se(se)) for se in ses]
        storages=[mean*d for mean,d in zip(means,widths)]
        for pattern in p["response_free_state_domain"]["moment_patterns"]:
            moments,mus=core.moment_values(pattern,len(widths),ses,widths)
            for bc in p["prescribed_flux_domain"]["anchors"]:
                cases.append({
                    "id":"|".join([profile["id"],pattern["id"],bc["id"]]),
                    "profile":profile["id"],
                    "moment_pattern":pattern["id"],
                    "boundary":bc["id"],
                    "bounds":bounds,
                    "widths":widths,
                    "ses":ses,
                    "means":means,
                    "storages":storages,
                    "moments":moments,
                    "mus":mus,
                    "qtop":float(bc["q_cm_per_day"]),
                    "qbottom":float(bc["q_cm_per_day"]),
                })
    return cases


def moment_bound_gate(core,case):
    return all(
        core.SE_LO<=se<=core.SE_HI and abs(m)<=core.mmax_bounded(se,d)+1e-12
        for se,m,d in zip(case["ses"],case["moments"],case["widths"])
    )


def residual_vector(core,x,case,p):
    n=len(case["widths"])
    penalty=1000.0
    scales=p["numerical_contract"]["residual_scaling"]
    pscale=float(scales["interface_pressure_cm"])
    qscale=float(scales["interface_flux_cm_per_day"])
    try:
        coeffs=[np.asarray(x[4*i:4*i+4],dtype=float) for i in range(n)]
        if any(np.any(~np.isfinite(c)) for c in coeffs):
            return np.full(4*n,penalty,dtype=float)
        r=[]; top=[]; bottom=[]
        for coeff,d,starget,mtarget in zip(coeffs,case["widths"],case["storages"],case["moments"]):
            srec,mrec=core.layer_state(coeff,d)
            r.append((srec-starget)/max(1e-12,core.DELTA_THETA*d))
            r.append((mrec-mtarget)/max(1e-12,core.DELTA_THETA*d*d))
            top.append(core.face_state(coeff,d,-1.0))
            bottom.append(core.face_state(coeff,d,1.0))
        for i in range(n-1):
            r.append((bottom[i]["psi"]-top[i+1]["psi"])/pscale)
            r.append((bottom[i]["q"]-top[i+1]["q"])/qscale)
        r.append((top[0]["q"]-case["qtop"])/float(scales["top_flux_cm_per_day"]))
        r.append((bottom[-1]["q"]-case["qbottom"])/float(scales["bottom_flux_cm_per_day"]))
        a=np.asarray(r,dtype=float)
        if a.shape!=(4*n,) or np.any(~np.isfinite(a)):
            return np.full(4*n,penalty,dtype=float)
        return a
    except (ValueError,FloatingPointError,OverflowError):
        return np.full(4*n,penalty,dtype=float)


def diagnostics(core,x,case,p):
    n=len(case["widths"])
    coeffs=[np.asarray(x[4*i:4*i+4],dtype=float) for i in range(n)]
    xis=np.linspace(-1.0,1.0,129)
    se_all=[]; top=[]; bottom=[]
    s_err=[]; m_err=[]; qs=[]; qm=[]
    for coeff,d,starget,mtarget in zip(coeffs,case["widths"],case["storages"],case["moments"]):
        se_all.extend(np.asarray(core.se_profile(coeff,xis),dtype=float).tolist())
        top.append(core.face_state(coeff,d,-1.0))
        bottom.append(core.face_state(coeff,d,1.0))
        s96,m96=core.layer_state(coeff,d,core.GL96_X,core.GL96_W)
        s192,m192=core.layer_state(coeff,d,core.GL192_X,core.GL192_W)
        s_err.append(abs(s192-starget)); m_err.append(abs(m192-mtarget))
        qs.append(abs(s192-s96)); qm.append(abs(m192-m96))
    pj=[bottom[i]["psi"]-top[i+1]["psi"] for i in range(n-1)]
    qj=[bottom[i]["q"]-top[i+1]["q"] for i in range(n-1)]
    return {
        "Se_min":float(min(se_all)),
        "Se_max":float(max(se_all)),
        "max_abs_interface_pressure_jump_cm":max([abs(v) for v in pj] or [0.0]),
        "max_abs_interface_flux_jump_cm_per_day":max([abs(v) for v in qj] or [0.0]),
        "abs_top_flux_residual_cm_per_day":abs(top[0]["q"]-case["qtop"]),
        "abs_bottom_flux_residual_cm_per_day":abs(bottom[-1]["q"]-case["qbottom"]),
        "max_abs_storage_recovery_cm":max(s_err or [0.0]),
        "max_abs_moment_recovery_cm2":max(m_err or [0.0]),
        "max_abs_96_192_storage_delta_cm":max(qs or [0.0]),
        "max_abs_96_192_moment_delta_cm2":max(qm or [0.0]),
    }


def qualified(diag,p):
    g=p["numerical_contract"]["physical_residual_gates"]
    q=p["numerical_contract"]["quadrature_consistency_gates"]
    return (
        0.02-1e-14<=diag["Se_min"] and diag["Se_max"]<=0.995+1e-14
        and diag["max_abs_interface_pressure_jump_cm"]<=float(g["max_abs_interface_pressure_jump_cm"])
        and diag["max_abs_interface_flux_jump_cm_per_day"]<=float(g["max_abs_interface_flux_jump_cm_per_day"])
        and diag["abs_top_flux_residual_cm_per_day"]<=float(g["max_abs_top_flux_residual_cm_per_day"])
        and diag["abs_bottom_flux_residual_cm_per_day"]<=float(g["max_abs_bottom_flux_residual_cm_per_day"])
        and diag["max_abs_storage_recovery_cm"]<=float(g["max_abs_storage_recovery_cm"])
        and diag["max_abs_moment_recovery_cm2"]<=float(g["max_abs_moment_recovery_cm2"])
        and diag["max_abs_96_192_storage_delta_cm"]<=float(q["max_abs_storage_delta_cm"])
        and diag["max_abs_96_192_moment_delta_cm2"]<=float(q["max_abs_moment_delta_cm2"])
    )


def start_vectors(core,case,p):
    base=np.concatenate([
        core.base_coeff_for_layer(se,M,d)
        for se,M,d in zip(case["ses"],case["moments"],case["widths"])
    ])
    out=[]
    for spec in p["numerical_contract"]["fixed_initial_starts"]:
        x=base.copy()
        x[2::4]+=float(spec["p2_dual_delta"])
        x[3::4]+=float(spec["p3_dual_delta"])
        out.append((spec["id"],x))
    return out


def qualify_case(core,case,p):
    opts=p["numerical_contract"]["solver_options"]
    sols=[]; runs=[]
    for sid,x0 in start_vectors(core,case,p):
        res=least_squares(
            lambda x: residual_vector(core,x,case,p),x0,method="trf",
            xtol=float(opts["xtol"]),ftol=float(opts["ftol"]),gtol=float(opts["gtol"]),
            max_nfev=int(opts["max_nfev"])
        )
        diag=None
        try:
            diag=diagnostics(core,res.x,case,p)
        except Exception as exc:
            diag_error=str(exc)
        else:
            diag_error=None
        ok=bool(res.success and diag is not None and qualified(diag,p))
        runs.append({
            "start":sid,"success":bool(res.success),"qualified":ok,
            "status":int(res.status),"nfev":int(res.nfev),
            "cost":float(res.cost),"optimality":float(res.optimality),
            "condition_number":condition_number(res),
            "diagnostics":diag,"diagnostic_error":diag_error
        })
        if ok:
            sols.append((sid,res.x.copy(),diag))

    all_converged=len(sols)==len(runs)==5
    unique=False
    max_theta=max_p=max_q=0.0
    if all_converged:
        unique=True
        ag=p["numerical_contract"]["solution_agreement_across_starts"]
        for i in range(len(sols)):
            for j in range(i+1,len(sols)):
                dt,dp,dq=core.solution_distance(sols[i][1],sols[j][1],case,p)
                max_theta=max(max_theta,dt); max_p=max(max_p,dp); max_q=max(max_q,dq)
                if not (
                    dt<=float(ag["max_abs_theta_difference"])
                    and dp<=float(ag["max_abs_face_pressure_difference_cm"])
                    and dq<=float(ag["max_abs_face_flux_difference_cm_per_day"])
                ):
                    unique=False
    return {
        "id":case["id"],
        "profile":case["profile"],
        "moment_pattern":case["moment_pattern"],
        "boundary":case["boundary"],
        "moment_bound_gate":moment_bound_gate(core,case),
        "all_starts_converged":all_converged,
        "unique_numerical_branch":unique,
        "bounded_realizability":all(r["diagnostics"] is not None and 0.02-1e-14<=r["diagnostics"]["Se_min"] and r["diagnostics"]["Se_max"]<=0.995+1e-14 for r in runs),
        "hydraulic_continuity":all(r["qualified"] for r in runs),
        "state_recovery":all(r["qualified"] for r in runs),
        "quadrature_consistency":all(r["qualified"] for r in runs),
        "max_pair_theta_difference":max_theta,
        "max_pair_face_pressure_difference_cm":max_p,
        "max_pair_face_flux_difference_cm_per_day":max_q,
        "runs":runs,
    }


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c6d",required=True,type=pathlib.Path)
    ap.add_argument("--core",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    p=json.loads(a.prereg.read_text())
    c6d=json.loads(a.c6d.read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_C6E_NUMERICAL_RESPONSE"
    assert p["scientific_firewall"]["hydrological_response_used"] is False
    assert p["scientific_firewall"]["c6d_response_used_for_design"] is False
    assert c6d["decision"]=="AUTHORIZE_RESPONSE_FREE_PRESCRIBED_FLUX_BOUNDARY_MATHEMATICAL_QUALIFICATION_BEFORE_FRESH_BLIND_FREE_RUNNING"
    core=load_core(a.core)

    cases=build_cases(core,p)
    assert len(cases)==126
    rows=[qualify_case(core,c,p) for c in cases]
    gates={
      "G1_STRICT_STATE_MOMENT_REALIZABILITY":all(r["moment_bound_gate"] for r in rows),
      "G2_ALL_CASES_CONVERGE":all(r["all_starts_converged"] for r in rows),
      "G3_UNIQUE_NUMERICAL_BRANCH":all(r["unique_numerical_branch"] for r in rows),
      "G4_BOUNDED_REALIZABILITY":all(r["bounded_realizability"] for r in rows),
      "G5_HYDRAULIC_CONTINUITY":all(r["hydraulic_continuity"] for r in rows),
      "G6_STATE_RECOVERY":all(r["state_recovery"] for r in rows),
      "G7_QUADRATURE_CONSISTENCY":all(r["quadrature_consistency"] for r in rows),
      "G8_NO_RESPONSE_DATA":True
    }
    status="C6E_BEMR_PRESCRIBED_FLUX_BOUNDARY_QUALIFIED" if all(gates.values()) else "C6E_BEMR_PRESCRIBED_FLUX_BOUNDARY_NOT_QUALIFIED"
    def count(k): return sum(bool(r[k]) for r in rows)
    cond=[run["condition_number"] for r in rows for run in r["runs"] if math.isfinite(run["condition_number"])]
    all_diag=[run["diagnostics"] for r in rows for run in r["runs"] if run["diagnostics"] is not None]
    extrema={
      "min_Se":min(d["Se_min"] for d in all_diag) if all_diag else None,
      "max_Se":max(d["Se_max"] for d in all_diag) if all_diag else None,
      "max_abs_interface_pressure_jump_cm":max(d["max_abs_interface_pressure_jump_cm"] for d in all_diag) if all_diag else None,
      "max_abs_interface_flux_jump_cm_per_day":max(d["max_abs_interface_flux_jump_cm_per_day"] for d in all_diag) if all_diag else None,
      "max_abs_top_flux_residual_cm_per_day":max(d["abs_top_flux_residual_cm_per_day"] for d in all_diag) if all_diag else None,
      "max_abs_bottom_flux_residual_cm_per_day":max(d["abs_bottom_flux_residual_cm_per_day"] for d in all_diag) if all_diag else None,
      "max_abs_storage_recovery_cm":max(d["max_abs_storage_recovery_cm"] for d in all_diag) if all_diag else None,
      "max_abs_moment_recovery_cm2":max(d["max_abs_moment_recovery_cm2"] for d in all_diag) if all_diag else None
    }
    out={
      "schema":"swap5.lare.bc2.c6e.result.v1",
      "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C6E",
      "status":status,
      "role":"NO_HYDROLOGICAL_RESPONSE_BEMR_PRESCRIBED_FLUX_BOUNDARY_QUALIFICATION",
      "case_count":len(rows),
      "fixed_start_count":len(rows)*5,
      "gates":gates,
      "qualification_counts":{
        "moment_bound_pass":count("moment_bound_gate"),
        "all_starts_converged":count("all_starts_converged"),
        "unique_numerical_branch":count("unique_numerical_branch"),
        "bounded_realizability":count("bounded_realizability"),
        "hydraulic_continuity":count("hydraulic_continuity"),
        "state_recovery":count("state_recovery"),
        "quadrature_consistency":count("quadrature_consistency")
      },
      "conditioning":{
        "finite_jacobian_condition_count":len(cond),
        "median_condition_number":float(np.median(cond)) if cond else None,
        "max_condition_number":max(cond) if cond else None,
        "hard_gate":False
      },
      "diagnostic_extrema":extrema,
      "cases":rows,
      "scientific_firewall":{
        "hydrological_response_used":False,
        "model_run_executed":False,
        "c6d_response_used_for_design":False,
        "free_running_bemr_implemented":False,
        "moment_fitting":False,
        "moment_localization":False,
        "c6c_retuning":False,
        "application_acceptance_adjudicated":False,
        "performance_comparison_authorized":False,
        "speed_claim_authorized":False,
        "production_rom_authorized":False
      }
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "status":status,"case_count":len(rows),"gates":gates,
      "counts":out["qualification_counts"],"conditioning":out["conditioning"],
      "extrema":extrema
    },sort_keys=True))


if __name__=="__main__":
    main()
