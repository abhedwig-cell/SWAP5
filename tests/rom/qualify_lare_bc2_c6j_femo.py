#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import pathlib

import numpy as np
from scipy.optimize import least_squares


def load_module(name: str, path: pathlib.Path):
    spec=importlib.util.spec_from_file_location(name,path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    mod=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def se_from_psi(core, psi):
    p=np.asarray(psi,dtype=float)
    if np.any(~np.isfinite(p)) or np.any(p<=0.0):
        raise ValueError("nonpositive/nonfinite suction")
    return np.power(1.0+np.power(core.ALPHA*p,core.N_VG),-core.M_VG)


def theta_from_psi(core,psi):
    return core.theta_from_se(se_from_psi(core,psi))


def psi_limits(core):
    wet=float(core.psi_from_theta(float(core.theta_from_se(core.SE_HI))))
    dry=float(core.psi_from_theta(float(core.theta_from_se(core.SE_LO))))
    return wet,dry


def local_values(core,A,B,d,xg,wg):
    x=0.5*d*np.asarray(xg,dtype=float)
    psi=A+B*x
    wet,dry=psi_limits(core)
    if np.any(~np.isfinite(psi)) or np.any(psi<=wet) or np.any(psi>=dry):
        raise ValueError("profile outside frozen interior suction interval")
    theta=np.asarray(theta_from_psi(core,psi),dtype=float)
    dz=0.5*d
    S=dz*float(np.dot(wg,theta))
    M=dz*float(np.dot(wg,x*theta))
    return S,M,theta,psi,x


def residual(core,x,target,d,prereg):
    penalty=float(prereg["local_profile_numerical_contract"].get("invalid_trial_penalty",1000.0))
    try:
        S,M,_,_,_=local_values(core,float(x[0]),float(x[1]),d,core.GL96_X,core.GL96_W)
        return np.array([
            (S-target[0])/max(1e-14,core.DELTA_THETA*d),
            (M-target[1])/max(1e-14,core.DELTA_THETA*d*d)
        ],dtype=float)
    except (ValueError,FloatingPointError,OverflowError):
        return np.array([penalty,penalty],dtype=float)


def base_start(core,se,M,d):
    th=float(core.theta_from_se(se))
    A=float(core.psi_from_theta(th))
    dtdp=1.0/float(core.dpsi_dtheta(th))
    B=12.0*float(M)/(dtdp*d**3) if abs(dtdp)>0.0 else 0.0
    return A,B


def starts(core,se,M,d):
    A,B=base_start(core,se,M,d)
    return [
        ("BASE",np.array([A,B],dtype=float)),
        ("A_LOW",np.array([0.8*A,B],dtype=float)),
        ("A_HIGH",np.array([1.2*A,B],dtype=float)),
        ("B_PLUS",np.array([A,B+0.2*A/d],dtype=float)),
        ("B_MINUS",np.array([A,B-0.2*A/d],dtype=float)),
    ]


def sample_profile(core,A,B,d,n=257):
    x=np.linspace(-0.5*d,0.5*d,n)
    psi=A+B*x
    se=np.asarray(se_from_psi(core,psi),dtype=float)
    theta=np.asarray(core.theta_from_se(se),dtype=float)
    return x,psi,se,theta


def local_jacobian(core,A,B,d):
    _,_,theta,_,x=local_values(core,A,B,d,core.GL192_X,core.GL192_W)
    dtdp=1.0/np.asarray(core.dpsi_dtheta(theta),dtype=float)
    dz=0.5*d
    w=np.asarray(core.GL192_W,dtype=float)
    J=np.array([
        [dz*np.dot(w,dtdp),dz*np.dot(w,x*dtdp)],
        [dz*np.dot(w,x*dtdp),dz*np.dot(w,x*x*dtdp)]
    ],dtype=float)
    return J


def solve_layer(core,se,S,M,d,prereg):
    opts=prereg["local_profile_numerical_contract"]["solver_options"]
    rows=[]
    sols=[]
    for sid,x0 in starts(core,se,M,d):
        res=least_squares(
            lambda x: residual(core,x,(S,M),d,prereg),
            x0,method=opts["method"],
            xtol=float(opts["xtol"]),ftol=float(opts["ftol"]),gtol=float(opts["gtol"]),
            max_nfev=int(opts["max_nfev"])
        )
        row={"start":sid,"success":bool(res.success),"status":int(res.status),"nfev":int(res.nfev),
             "cost":float(res.cost),"optimality":float(res.optimality),"A_cm":float(res.x[0]),"B":float(res.x[1])}
        try:
            S192,M192,_,_,_=local_values(core,float(res.x[0]),float(res.x[1]),d,core.GL192_X,core.GL192_W)
            xx,pp,ss,tt=sample_profile(core,float(res.x[0]),float(res.x[1]),d,257)
            J=local_jacobian(core,float(res.x[0]),float(res.x[1]),d)
            eig=np.linalg.eigvalsh(0.5*(J+J.T))
            row.update({
                "state_error_S_cm":abs(S192-S),
                "state_error_M_cm2":abs(M192-M),
                "Se_min":float(np.min(ss)),"Se_max":float(np.max(ss)),
                "moment_jacobian_eigenvalues":eig.tolist(),
                "moment_jacobian_condition_number":float(np.linalg.cond(J)),
                "diagnostic_error":None
            })
            sols.append((sid,res.x.copy(),tt.copy(),row))
        except Exception as exc:
            row["diagnostic_error"]=str(exc)
        rows.append(row)

    ag=prereg["local_profile_numerical_contract"]["agreement"]
    recovery=prereg["local_profile_numerical_contract"]["state_recovery"]
    margin=float(prereg["local_profile_numerical_contract"]["interior_margin_Se"])
    all_conv=len(sols)==len(rows) and all(r["success"] for r in rows)
    unique=all_conv
    max_theta=max_A=max_B=0.0
    if all_conv:
        for i in range(len(sols)):
            for j in range(i+1,len(sols)):
                max_theta=max(max_theta,float(np.max(np.abs(sols[i][2]-sols[j][2]))))
                max_A=max(max_A,abs(float(sols[i][1][0]-sols[j][1][0])))
                max_B=max(max_B,abs(float(sols[i][1][1]-sols[j][1][1])))
        unique=(max_theta<=float(ag["max_abs_theta_difference"]) and
                max_A<=float(ag["max_abs_A_difference_cm"]) and
                max_B<=float(ag["max_abs_B_difference"]))
    interior=all_conv and all(
        r["Se_min"]>core.SE_LO+margin and r["Se_max"]<core.SE_HI-margin for r in rows
    )
    state_recovery=all_conv and all(
        r["state_error_S_cm"]<=float(recovery["max_abs_storage_cm"]) and
        r["state_error_M_cm2"]<=float(recovery["max_abs_moment_cm2"]) for r in rows
    )
    jac_neg=all_conv and all(
        max(r["moment_jacobian_eigenvalues"])<0.0 and math.isfinite(r["moment_jacobian_condition_number"])
        for r in rows
    )
    primary=sols[0][1] if sols and sols[0][0]=="BASE" else None
    return {
        "all_starts_converged":all_conv,
        "unique_profile":unique,
        "interior_profile":interior,
        "state_recovery":state_recovery,
        "moment_jacobian_negative_definite":jac_neg,
        "max_pair_theta_difference":max_theta,
        "max_pair_A_difference_cm":max_A,
        "max_pair_B_difference":max_B,
        "runs":rows,
        "primary_coeff":primary.tolist() if primary is not None else None
    }


def build_state_cases(core,c6c,c6e):
    out=[]
    dom=c6c["synthetic_domain"]
    for pname,bounds in dom["partitions"].items():
        widths=[float(b-a) for a,b in zip(bounds,bounds[1:])]
        for profile in dom["mean_Se_profiles"]:
            ses=core.profile_se(profile,len(widths))
            means=[float(core.theta_from_se(se)) for se in ses]
            stor=[m*d for m,d in zip(means,widths)]
            for pat in dom["moment_patterns"]:
                moms,mus=core.moment_values(pat,len(widths),ses,widths)
                out.append({
                    "domain":"C6C","id":"|".join(["C6C",pname,profile["id"],pat["id"]]),
                    "partition":pname,"bounds":[float(x) for x in bounds],"widths":widths,
                    "profile":profile["id"],"moment_pattern":pat["id"],"ses":list(map(float,ses)),
                    "means":means,"storages":list(map(float,stor)),"moments":list(map(float,moms)),
                    "head_boundaries":dom["boundary_cases"]
                })
    bounds=[float(x) for x in c6e["representation"]["boundaries_cm"]]
    widths=[float(x) for x in c6e["representation"]["widths_cm"]]
    for profile in c6e["response_free_state_domain"]["mean_Se_profiles"]:
        ses=core.profile_se(profile,len(widths))
        means=[float(core.theta_from_se(se)) for se in ses]
        stor=[m*d for m,d in zip(means,widths)]
        for pat in c6e["response_free_state_domain"]["moment_patterns"]:
            moms,mus=core.moment_values(pat,len(widths),ses,widths)
            out.append({
                "domain":"C6E","id":"|".join(["C6E","D12_B2P5",profile["id"],pat["id"]]),
                "partition":"D12_B2P5","bounds":bounds,"widths":widths,
                "profile":profile["id"],"moment_pattern":pat["id"],"ses":list(map(float,ses)),
                "means":means,"storages":list(map(float,stor)),"moments":list(map(float,moms)),
                "flux_boundaries":c6e["prescribed_flux_domain"]["anchors"]
            })
    return out


def moment_realizable(core,case):
    return all(
        core.SE_LO<=se<=core.SE_HI and abs(M)<=core.mmax_bounded(se,d)+1e-12
        for se,M,d in zip(case["ses"],case["moments"],case["widths"])
    )


def cumtrap(y,x):
    y=np.asarray(y,dtype=float); x=np.asarray(x,dtype=float)
    out=np.zeros_like(y)
    if len(y)>1:
        out[1:]=np.cumsum(0.5*(y[1:]+y[:-1])*np.diff(x))
    return out


def layer_tangent(core,A,B,d,n):
    x=np.linspace(-0.5*d,0.5*d,n)
    psi=A+B*x
    theta=np.asarray(theta_from_psi(core,psi),dtype=float)
    dtdp=1.0/np.asarray(core.dpsi_dtheta(theta),dtype=float)
    J=local_jacobian(core,A,B,d)
    Jinv=np.linalg.inv(J)
    base=np.column_stack([np.ones_like(x),x])
    tang=dtdp[:,None]*(base@Jinv)
    scales=np.array([core.DELTA_THETA*d,core.DELTA_THETA*d*d],dtype=float)
    tang_scaled=tang*scales[None,:]
    cum=np.column_stack([cumtrap(tang_scaled[:,0],x),cumtrap(tang_scaled[:,1],x)])
    return x,theta,tang_scaled,cum,J


def metric_from_profiles(core,case,coeffs,n):
    N=len(case["widths"]); dim=2*N
    G=np.zeros((dim,dim),dtype=float)
    bvec=np.zeros(dim,dtype=float)
    C=np.zeros(dim,dtype=float)
    scales=[]
    for i,d in enumerate(case["widths"]):
        scales.extend([core.DELTA_THETA*d,core.DELTA_THETA*d*d])
        C[2*i]=core.DELTA_THETA*d
    for i,(d,ab) in enumerate(zip(case["widths"],coeffs)):
        A,B=ab
        x,theta,tang,cum,J=layer_tangent(core,A,B,d,n)
        ztop=case["bounds"][i]
        z=ztop+0.5*d+x
        K=np.asarray(core.k_from_theta(theta),dtype=float)
        Bmat=np.zeros((n,dim),dtype=float)
        for j in range(i):
            Bmat[:,2*j]=C[2*j]
        Bmat[:,2*i]=cum[:,0]
        Bmat[:,2*i+1]=cum[:,1]
        invK=1.0/K
        for a in range(dim):
            bvec[a]+=float(np.trapz(Bmat[:,a]*invK,z))
        weighted=Bmat[:,:,None]*Bmat[:,None,:]*invK[:,None,None]
        G+=np.trapz(weighted,z,axis=0)
    return 0.5*(G+G.T),bvec,C,np.asarray(scales,dtype=float)


def energy_gradient_scaled(case,coeffs,scales):
    g=np.zeros(len(scales),dtype=float)
    for i,(ab,a,b) in enumerate(zip(coeffs,case["bounds"][:-1],case["bounds"][1:])):
        A,B=ab; zc=0.5*(a+b)
        g[2*i]=(-A-zc)*scales[2*i]
        g[2*i+1]=(-B-1.0)*scales[2*i+1]
    return g


def metric_diagnostics(core,case,coeffs,prereg):
    mc=prereg["tangent_metric_contract"]
    n1=int(mc["metric_grid"]["primary_points_per_layer"])
    n2=int(mc["metric_grid"]["independent_points_per_layer"])
    G,b,C,scales=metric_from_profiles(core,case,coeffs,n1)
    G2,b2,C2,scales2=metric_from_profiles(core,case,coeffs,n2)
    normG=max(1e-300,float(np.linalg.norm(G2)))
    normb=max(1e-300,float(np.linalg.norm(b2)))
    sym=float(np.linalg.norm(G-G.T))/max(1e-300,float(np.linalg.norm(G)))
    evals=np.linalg.eigvalsh(G)
    maxeig=float(np.max(evals)); mineig=float(np.min(evals))
    rel=mineig/maxeig if maxeig>0 else -math.inf
    relG=float(np.linalg.norm(G-G2))/normG
    relb=float(np.linalg.norm(b-b2))/normb
    cond=float(np.linalg.cond(G))
    gates=mc["gates"]
    ok=(np.all(np.isfinite(G)) and np.all(np.isfinite(b)) and math.isfinite(cond)
        and sym<=float(gates["G_symmetry_relative"])
        and maxeig>0.0 and rel>=float(gates["G_min_eigenvalue_relative_to_max"])
        and relG<=float(gates["G_primary_independent_relative_frobenius"])
        and relb<=float(gates["b_primary_independent_relative_l2"]))
    return {
        "qualified":bool(ok),"symmetry_relative":sym,
        "min_eigenvalue":mineig,"max_eigenvalue":maxeig,"min_over_max_eigenvalue":rel,
        "condition_number":cond,"metric_grid_relative_frobenius":relG,
        "b_grid_relative_l2":relb
    },(G,b,C,scales)


def head_operator(core,case,coeffs,metric,bc,prereg):
    G,b,C,scales=metric
    g=energy_gradient_scaled(case,coeffs,scales)
    q0=float(core.k_from_theta(case["means"][0]))
    psi_bottom=float(bc["bottom_head_multiplier"])*float(core.psi_from_theta(case["means"][-1]))
    H=float(case["bounds"][-1])
    mu_b=-psi_bottom-H
    l=g-q0*b-mu_b*C
    try:
        ydot=np.linalg.solve(G,-l)
        res=G@ydot+l
        scaled=float(np.linalg.norm(res))/max(1.0,float(np.linalg.norm(l)))
        finite=bool(np.all(np.isfinite(ydot)))
    except np.linalg.LinAlgError:
        ydot=np.full_like(l,np.nan); scaled=math.inf; finite=False
    gate=float(prereg["boundary_operator_contract"]["prescribed_head"]["gate_stationarity_residual"])
    return {"id":bc["id"],"qualified":finite and scaled<=gate,
            "stationarity_residual":scaled,"rate_norm":float(np.linalg.norm(ydot)) if finite else None,
            "qtop_cm_per_day":q0,"bottom_suction_cm":psi_bottom}


def flux_operator(core,case,coeffs,metric,bc,prereg):
    G,b,C,scales=metric
    g=energy_gradient_scaled(case,coeffs,scales)
    q0=float(bc["q_cm_per_day"]); qb=q0
    l=g-q0*b
    KKT=np.block([[G,C[:,None]],[C[None,:],np.zeros((1,1))]])
    rhs=np.concatenate([-l,np.array([q0-qb])])
    try:
        sol=np.linalg.solve(KKT,rhs)
        ydot=sol[:-1]; lam=sol[-1]
        stat=G@ydot+C*lam+l
        sr=float(np.linalg.norm(stat))/max(1.0,float(np.linalg.norm(l)))
        cr=abs(float(C@ydot-(q0-qb)))
        finite=bool(np.all(np.isfinite(sol)))
    except np.linalg.LinAlgError:
        ydot=np.full_like(l,np.nan); sr=math.inf; cr=math.inf; finite=False
    hc=prereg["boundary_operator_contract"]["prescribed_flux"]
    return {"id":bc["id"],"qualified":finite and sr<=float(hc["gate_stationarity_residual"]) and cr<=float(hc["gate_constraint_residual_cm_per_day"]),
            "stationarity_residual":sr,"constraint_residual_cm_per_day":cr,
            "rate_norm":float(np.linalg.norm(ydot)) if finite else None,"qhold_cm_per_day":q0}


def qualify_case(core,case,prereg):
    local=[]
    coeffs=[]
    for se,S,M,d in zip(case["ses"],case["storages"],case["moments"],case["widths"]):
        r=solve_layer(core,float(se),float(S),float(M),float(d),prereg)
        local.append(r)
        if r["primary_coeff"] is None:
            coeffs.append(None)
        else:
            coeffs.append([float(x) for x in r["primary_coeff"]])
    gates={
        "moment_realizable":moment_realizable(core,case),
        "all_local_starts_converged":all(r["all_starts_converged"] for r in local),
        "all_local_profiles_unique":all(r["unique_profile"] for r in local),
        "all_local_profiles_interior":all(r["interior_profile"] for r in local),
        "all_local_state_recovery":all(r["state_recovery"] for r in local),
        "all_local_jacobians_negative_definite":all(r["moment_jacobian_negative_definite"] for r in local),
    }
    metric_diag=None; metric_raw=None; head=[]; flux=[]
    if all(gates.values()) and all(c is not None for c in coeffs):
        metric_diag,metric_raw=metric_diagnostics(core,case,coeffs,prereg)
        if case["domain"]=="C6C":
            head=[head_operator(core,case,coeffs,metric_raw,bc,prereg) for bc in case["head_boundaries"]]
        else:
            flux=[flux_operator(core,case,coeffs,metric_raw,bc,prereg) for bc in case["flux_boundaries"]]
    return {
        "id":case["id"],"domain":case["domain"],"partition":case["partition"],
        "profile":case["profile"],"moment_pattern":case["moment_pattern"],
        "gates":gates,"local_layers":local,"metric":metric_diag,
        "head_operators":head,"flux_operators":flux
    }


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c6i",required=True,type=pathlib.Path)
    ap.add_argument("--c6c-prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c6e-prereg",required=True,type=pathlib.Path)
    ap.add_argument("--core",required=True,type=pathlib.Path)
    ap.add_argument("--shard-index",required=True,type=int)
    ap.add_argument("--shard-count",required=True,type=int)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    p=json.loads(a.prereg.read_text())
    c6i=json.loads(a.c6i.read_text())
    c6c=json.loads(a.c6c_prereg.read_text())
    c6e=json.loads(a.c6e_prereg.read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_C6J_NUMERICAL_RESPONSE"
    assert c6i["decision"]=="PREREGISTER_FREE_ENERGY_MOMENT_ONSAGER_REDUCTION_FOR_RESPONSE_FREE_MATHEMATICAL_QUALIFICATION"
    assert p["scientific_firewall"]["hydrological_response_used"] is False
    core=load_module("c6c_core",a.core)
    cases=build_state_cases(core,c6c,c6e)
    assert len(cases)==126
    rows=[]
    for idx,case in enumerate(cases):
        if idx%a.shard_count!=a.shard_index:
            continue
        r=qualify_case(core,case,p)
        r["case_index"]=idx
        rows.append(r)
    out={
        "schema":"swap5.lare.bc2.c6j.shard.v1","workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C6J",
        "shard_index":a.shard_index,"shard_count":a.shard_count,"total_state_case_count":len(cases),
        "state_case_count":len(rows),"rows":rows,
        "scientific_firewall":{
            "hydrological_response_used":False,"model_run_executed":False,
            "c6d_response_used_for_design":False,"c6e_failures_used_for_penalty_design":False,
            "BEMR_reopened":False,"free_running_FEMO_implemented":False,
            "production_rom_authorized":False
        }
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"shard_index":a.shard_index,"state_case_count":len(rows),
                      "first":rows[0]["case_index"] if rows else None,
                      "last":rows[-1]["case_index"] if rows else None},sort_keys=True))


if __name__=="__main__":
    main()
