#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import pathlib

import numpy as np
from scipy.optimize import least_squares

HERE=pathlib.Path(__file__).resolve().parent

def load_module(name,filename):
    spec=importlib.util.spec_from_file_location(name,HERE/filename)
    mod=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

b9=load_module("bc2b9_c4i","analyze_lare_bc2_b9_internal_flux.py")
b8=b9.b8
b5=b9.b5
b3=b9.b3

WIDTHS=(2.5,5.0)
HISTORIES=("WT_HOLD","WT_RISE","WT_FALL")
NQS=(64,128)
ROOT_GATE=1.0e-10
PSI_TOL=1.0e-10
UNIQUE_TOL=1.0e-8
Q_CROSS_GATE=1.0e-8
QI_ID_GATE=1.0e-10
HYDRO_GATE=1.0e-10
CMP_TOL=1.0e-12
GL={n:np.polynomial.legendre.leggauss(n) for n in NQS}

def coeffs_from_pressures(psi_i,psi_anchor,L,d):
    if not (L>d>0.0):
        raise ValueError("invalid quadratic geometry")
    b=(psi_anchor/L-psi_i/d)/(L-d)
    a=psi_i/d-b*d
    return float(a),float(b)

def psi_profile(x,a,b):
    return a*x+b*x*x

def profile_minimum(a,b,L):
    vals=[0.0,psi_profile(L,a,b)]
    if b!=0.0:
        x=-a/(2.0*b)
        if 0.0<x<L:
            vals.append(psi_profile(x,a,b))
    return float(min(vals))

def integrate_band(a,b,x0,x1,nq):
    xg,wg=GL[nq]
    half=0.5*(x1-x0)
    xx=x0+half*(xg+1.0)
    psi=psi_profile(xx,a,b)
    if np.min(psi)<-PSI_TOL:
        raise ValueError("quadratic profile enters positive-pressure domain")
    theta=b3.theta_from_psi(np.maximum(psi,0.0))
    return float(half*np.sum(wg*theta))

def storage_residuals_pressures(v,Wt,Wb,L,d,nq):
    psi_i=float(v[0]); psi_anchor=float(v[1])
    a,b=coeffs_from_pressures(psi_i,psi_anchor,L,d)
    if profile_minimum(a,b,L)<-PSI_TOL:
        # Smooth penalty; least_squares still has a deterministic direction.
        bad=abs(profile_minimum(a,b,L))
        return np.asarray([1e3*bad+1.0,1e3*bad+1.0],dtype=float)
    wt=integrate_band(a,b,0.0,d,nq)
    wb=integrate_band(a,b,d,L,nq)
    return np.asarray([wt-Wt,wb-Wb],dtype=float)

def root_close(x,y):
    ax,bx=x; ay,by=y
    return (
        abs(ax-ay)<=UNIQUE_TOL*(1.0+max(abs(ax),abs(ay)))
        and abs(bx-by)<=UNIQUE_TOL*(1.0+max(abs(bx),abs(by)))
    )

def solve_quadratic(Wt,Wb,H,d,b9cand,nq):
    L=H-b3.ANCHOR
    if not (L>d>0.0):
        raise ValueError("terminal width leaves no bulk layer")

    psi_i_seed=max(0.0,float(b9cand["psi_i"]))
    psi_anchor_seed=max(0.0,psi_i_seed+float(b9cand["b_bulk"])*(L-d))
    seeds=[
        np.asarray([psi_i_seed,psi_anchor_seed],dtype=float),
        np.asarray([d,L],dtype=float),
        0.5*np.asarray([psi_i_seed,psi_anchor_seed],dtype=float),
        2.0*np.asarray([psi_i_seed,psi_anchor_seed],dtype=float),
    ]

    roots=[]
    diagnostics=[]
    for idx,seed in enumerate(seeds):
        try:
            sol=least_squares(
                storage_residuals_pressures,
                x0=np.maximum(seed,0.0),
                bounds=(np.zeros(2),np.full(2,np.inf)),
                args=(Wt,Wb,L,d,nq),
                xtol=1e-13,
                ftol=1e-13,
                gtol=1e-13,
                max_nfev=300,
            )
            psi_i=float(sol.x[0]); psi_anchor=float(sol.x[1])
            a,b=coeffs_from_pressures(psi_i,psi_anchor,L,d)
            minpsi=profile_minimum(a,b,L)
            rr=storage_residuals_pressures(sol.x,Wt,Wb,L,d,nq)
            maxres=float(np.max(np.abs(rr)))
            physical=math.isfinite(a) and math.isfinite(b) and minpsi>=-PSI_TOL
            valid=bool(sol.success and physical and maxres<=ROOT_GATE)
            diagnostics.append({
                "start_index":idx,
                "success":bool(sol.success),
                "valid":valid,
                "cost":float(sol.cost),
                "nfev":int(sol.nfev),
                "psi_i":psi_i,
                "psi_anchor":psi_anchor,
                "a":a,
                "b":b,
                "minimum_psi":minpsi,
                "max_storage_residual_cm":maxres,
            })
            if valid:
                roots.append((a,b,psi_i,psi_anchor,maxres))
        except Exception as exc:
            diagnostics.append({
                "start_index":idx,
                "success":False,
                "valid":False,
                "error":str(exc),
            })

    if len(roots)<2:
        raise ValueError(f"insufficient independent valid roots nq={nq} valid={len(roots)}")
    first=roots[0][:2]
    if not all(root_close(first,r[:2]) for r in roots[1:]):
        raise ValueError(f"AMBIGUOUS_RECONSTRUCTION nq={nq}")

    a=float(np.mean([r[0] for r in roots]))
    b=float(np.mean([r[1] for r in roots]))
    psi_i=a*d+b*d*d
    psi_anchor=a*L+b*L*L
    minpsi=profile_minimum(a,b,L)
    wt=integrate_band(a,b,0.0,d,nq)
    wb=integrate_band(a,b,d,L,nq)
    res=max(abs(wt-Wt),abs(wb-Wb))
    if res>ROOT_GATE or minpsi<-PSI_TOL:
        raise ValueError("reconciled quadratic root failed storage/physical gate")
    theta_i=float(b3.theta_from_psi(psi_i))
    _,ki_arr=b3.psi_k(np.asarray([theta_i],dtype=float))
    Ki=float(ki_arr[0])
    slope_i=a+2.0*b*d
    qi=Ki*(1.0-slope_i)
    qH=b3.KS*(1.0-a)
    return {
        "a":a,"b":b,"psi_i":psi_i,"psi_anchor":psi_anchor,
        "theta_i":theta_i,"Ki":Ki,"slope_i":slope_i,
        "qi":qi,"qH":qH,"Wt_reconstructed":wt,"Wb_reconstructed":wb,
        "max_storage_residual_cm":res,"minimum_psi":minpsi,
        "valid_root_count":len(roots),"starts":diagnostics,
    }

def endpoint(profile,total,d):
    p=b8.projected(profile,total,d)
    H=float(p["H"])
    B=H-b3.ANCHOR-d
    if B<=0.0:
        raise ValueError("terminal width leaves no bulk layer")
    baseline=b9.endpoint_candidates(profile,total,d)
    roots={n:solve_quadratic(float(p["Wt64"]),float(p["Wb64"]),H,d,baseline,n) for n in NQS}
    return {"projected":p,"baseline":baseline,"quad":roots}

def flux_metrics(rows,key,refkey):
    ref=np.asarray([r[refkey] for r in rows],dtype=float)
    pred=np.asarray([r[key] for r in rows],dtype=float)
    err=pred-ref
    corr=float(np.corrcoef(ref,pred)[0,1]) if np.std(ref)>0.0 and np.std(pred)>0.0 else None
    return {
        "count":int(len(rows)),
        "bias":float(np.mean(err)),
        "mae":float(np.mean(np.abs(err))),
        "rms":float(np.sqrt(np.mean(err*err))),
        "max_abs":float(np.max(np.abs(err))),
        "sign_mismatch":int(np.count_nonzero(np.sign(ref)!=np.sign(pred))),
        "corr":corr,
    }

def strictly_better(cand,base):
    return (
        cand["rms"]<base["rms"]-CMP_TOL
        and cand["mae"]<base["mae"]-CMP_TOL
        and cand["sign_mismatch"]<=base["sign_mismatch"]
    )

def noninferior(cand,base):
    return (
        cand["rms"]<=base["rms"]+CMP_TOL
        and cand["mae"]<=base["mae"]+CMP_TOL
        and cand["sign_mismatch"]<=base["sign_mismatch"]
    )

def scalar_stats(values):
    a=np.asarray(values,dtype=float)
    return {
        "count":int(len(a)),
        "min":float(np.min(a)),
        "mean":float(np.mean(a)),
        "max":float(np.max(a)),
        "rms":float(np.sqrt(np.mean(a*a))),
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--b8-result",required=True,type=pathlib.Path)
    ap.add_argument("--b9-result",required=True,type=pathlib.Path)
    ap.add_argument("--c4h-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    r8=json.loads(args.b8_result.read_text())
    r9=json.loads(args.b9_result.read_text())
    c4h=json.loads(args.c4h_closeout.read_text())
    assert pre["phase"]=="PREREGISTERED_AFTER_C4H_BEFORE_QUADRATIC_STORAGE_RECONSTRUCTION"
    assert pre["pre_execution_solver_clarification"]["before_first_C4I_execution"] is True
    assert r8["decision"]==pre["predecessors"]["B8"]["required_decision"]
    assert pre["predecessors"]["B9"]["required_preferred_operator"] in r9["preferred_operator"]
    assert c4h["status"]==pre["predecessors"]["C4H"]["required_status"]
    assert c4h["decision"]==pre["predecessors"]["C4H"]["required_decision"]

    init_meta,init_nodes,states,nodes=b3.load_reference(args.reference)
    rows_by_width={str(d):[] for d in WIDTHS}
    failures=[]
    max_qi_identity=0.0
    max_storage_res=0.0
    max_qi_cross=0.0
    max_qH_cross=0.0
    min_psi=float("inf")
    min_valid_roots=99

    # Manufactured hydrostatic recovery over representative observed geometries.
    max_hydro_a=0.0
    max_hydro_b=0.0
    for d in WIDTHS:
        for H in (105.0,120.0,138.0):
            L=H-b3.ANCHOR
            Wt=b5.storage_for_slope(1.0,d,64)
            # Hydrostatic global profile psi=x in the bulk band.
            Wb=b9.bulk_storage_for_slope(1.0,L-d,d,64)
            seed={
                "psi_i":d,
                "b_bulk":1.0,
            }
            for nq in NQS:
                q=solve_quadratic(Wt,Wb,H,d,seed,nq)
                max_hydro_a=max(max_hydro_a,abs(q["a"]-1.0))
                max_hydro_b=max(max_hydro_b,abs(q["b"]))

    for d in WIDTHS:
        dkey=str(d)
        for history in HISTORIES:
            try:
                prev=endpoint(init_nodes[history],init_meta[history]["total"],d)
            except Exception as exc:
                failures.append({"width_cm":d,"history":history,"step":0,"error":str(exc)})
                continue
            for step in range(1,b3.HISTORY_STEPS[history]+1):
                try:
                    cur=endpoint(nodes[(history,step)],states[(history,step)]["total"],d)
                except Exception as exc:
                    failures.append({"width_cm":d,"history":history,"step":step,"error":str(exc)})
                    break

                p0=prev["projected"]; p1=cur["projected"]
                qH_ref=states[(history,step)]["bottom_exchange"]/b3.OBS_DT
                q90=-(p1["Wfixed"]-p0["Wfixed"])/b3.OBS_DT
                Hdot=(p1["H"]-p0["H"])/b3.OBS_DT
                Gi=0.5*(p0["theta_i"]+p1["theta_i"])*Hdot
                dWb=(p1["Wb64"]-p0["Wb64"])/b3.OBS_DT
                dWt=(p1["Wt64"]-p0["Wt64"])/b3.OBS_DT
                qi_bulk=q90+Gi-dWb
                qi_term=dWt+qH_ref-b3.THETA_S*Hdot+Gi
                max_qi_identity=max(max_qi_identity,abs(qi_bulk-qi_term))
                qi_ref=0.5*(qi_bulk+qi_term)

                b0=prev["baseline"]; b1=cur["baseline"]
                qi_base=0.5*(b0["TERMINAL_SIDE_LINEAR"]+b1["TERMINAL_SIDE_LINEAR"])
                qH_base=0.5*(b3.KS*(1.0-b0["a_t"])+b3.KS*(1.0-b1["a_t"]))

                q0=prev["quad"][64]; q1=cur["quad"][64]
                q0x=prev["quad"][128]; q1x=cur["quad"][128]
                qi_quad=0.5*(q0["qi"]+q1["qi"])
                qH_quad=0.5*(q0["qH"]+q1["qH"])
                qi_quad_x=0.5*(q0x["qi"]+q1x["qi"])
                qH_quad_x=0.5*(q0x["qH"]+q1x["qH"])
                max_qi_cross=max(max_qi_cross,abs(qi_quad-qi_quad_x))
                max_qH_cross=max(max_qH_cross,abs(qH_quad-qH_quad_x))

                for ep in (q0,q1,q0x,q1x):
                    max_storage_res=max(max_storage_res,float(ep["max_storage_residual_cm"]))
                    min_psi=min(min_psi,float(ep["minimum_psi"]))
                    min_valid_roots=min(min_valid_roots,int(ep["valid_root_count"]))

                rows_by_width[dkey].append({
                    "history":history,
                    "step":step,
                    "qi_ref":qi_ref,
                    "qH_ref":qH_ref,
                    "qi_BASE":qi_base,
                    "qH_BASE":qH_base,
                    "qi_QUADRATIC":qi_quad,
                    "qH_QUADRATIC":qH_quad,
                    "qi_QUADRATIC_128":qi_quad_x,
                    "qH_QUADRATIC_128":qH_quad_x,
                    "a_quad":0.5*(q0["a"]+q1["a"]),
                    "b_quad":0.5*(q0["b"]+q1["b"]),
                    "slope_i_quad":0.5*(q0["slope_i"]+q1["slope_i"]),
                })
                prev=cur

    expected_per_width=sum(b3.HISTORY_STEPS[h] for h in HISTORIES)
    complete=(
        not failures
        and all(len(rows_by_width[str(d)])==expected_per_width for d in WIDTHS)
    )
    hard_ok=(
        complete
        and max_qi_identity<=QI_ID_GATE
        and max_storage_res<=ROOT_GATE
        and min_psi>=-PSI_TOL
        and min_valid_roots>=2
        and max_qi_cross<=Q_CROSS_GATE
        and max_qH_cross<=Q_CROSS_GATE
        and max_hydro_a<=HYDRO_GATE
        and max_hydro_b<=HYDRO_GATE
    )

    report={}
    qi_support={}
    qH_noninferior={}
    for d in WIDTHS:
        dk=str(d)
        report[dk]={}
        qi_support[dk]={}
        qH_noninferior[dk]={}
        rows=rows_by_width[dk]
        for history in HISTORIES:
            rr=[r for r in rows if r["history"]==history]
            report[dk][history]={
                "qi":{
                    "BASE_TERMINAL_SIDE_LINEAR":flux_metrics(rr,"qi_BASE","qi_ref"),
                    "C1_QUADRATIC_STORAGE_PROFILE":flux_metrics(rr,"qi_QUADRATIC","qi_ref"),
                },
                "qH":{
                    "BASE_TERMINAL_SIDE_LINEAR":flux_metrics(rr,"qH_BASE","qH_ref"),
                    "C1_QUADRATIC_STORAGE_PROFILE":flux_metrics(rr,"qH_QUADRATIC","qH_ref"),
                },
                "quadratic_shape":{
                    "a":scalar_stats([r["a_quad"] for r in rr]),
                    "b":scalar_stats([r["b_quad"] for r in rr]),
                    "slope_i":scalar_stats([r["slope_i_quad"] for r in rr]),
                }
            }
            if history in ("WT_RISE","WT_FALL"):
                qi_support[dk][history]=strictly_better(
                    report[dk][history]["qi"]["C1_QUADRATIC_STORAGE_PROFILE"],
                    report[dk][history]["qi"]["BASE_TERMINAL_SIDE_LINEAR"]
                )
            qH_noninferior[dk][history]=noninferior(
                report[dk][history]["qH"]["C1_QUADRATIC_STORAGE_PROFILE"],
                report[dk][history]["qH"]["BASE_TERMINAL_SIDE_LINEAR"]
            )

    qi_all=hard_ok and all(qi_support[str(d)][h] for d in WIDTHS for h in ("WT_RISE","WT_FALL"))
    qH_all=hard_ok and all(qH_noninferior[str(d)][h] for d in WIDTHS for h in HISTORIES)
    if not hard_ok:
        decision="C4I_RECONSTRUCTION_BLOCKED"
    elif qi_all and qH_all:
        decision="QUADRATIC_STORAGE_RECONSTRUCTION_SUPPORTED"
    elif qi_all:
        decision="QI_IMPROVES_QH_TRADEOFF"
    else:
        decision="QUADRATIC_RECONSTRUCTION_MIXED"

    result={
        "schema":"swap5.lare.bc2.c4i.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C4I",
        "decision":decision,
        "complete":complete,
        "hard_checks":{
            "max_abs_B8_qi_bulk_minus_terminal_cm_per_day":max_qi_identity,
            "B8_qi_identity_gate_cm_per_day":QI_ID_GATE,
            "max_storage_reconstruction_residual_cm":max_storage_res,
            "storage_gate_cm":ROOT_GATE,
            "minimum_profile_psi_cm":min_psi,
            "psi_nonnegative_tolerance_cm":PSI_TOL,
            "minimum_valid_multistart_roots_per_quadrature_state":min_valid_roots,
            "required_minimum_valid_multistart_roots":2,
            "max_abs_qi_64_vs_128_cm_per_day":max_qi_cross,
            "max_abs_qH_64_vs_128_cm_per_day":max_qH_cross,
            "q_crosscheck_gate_cm_per_day":Q_CROSS_GATE,
            "max_hydrostatic_abs_a_minus_1":max_hydro_a,
            "max_hydrostatic_abs_b":max_hydro_b,
            "hydrostatic_gate":HYDRO_GATE,
            "failure_count":len(failures)
        },
        "qi_support":qi_support,
        "qH_noninferior":qH_noninferior,
        "report":report,
        "failures":failures[:20],
        "interpretation":[
            "C4I solves the existing Wb and Wt storage constraints for one C1-smooth quadratic pressure profile over the whole moving lower domain. No response is used in reconstruction.",
            "The profile uses no extra prognostic state and preserves the water-table pressure boundary psi=0.",
            "Hydrostatic psi=x is a manufactured identity case, not a fitted calibration target.",
            "Candidate support requires improved qi closure across both widths and moving directions without sacrificing the lower-boundary qH closure.",
            "No propagated reduced dynamics are authorized by this static Reference-state comparison."
        ],
        "propagated_dynamics_authorized":False,
        "next_model_change_authorized":False,
        "groundwater_feedback_authorized":False,
        "application_acceptance_adjudicated":False,
        "speed_claim_authorized":False,
        "production_rom_authorized":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":decision,
        "hard_checks":result["hard_checks"],
        "qi_support":qi_support,
        "qH_noninferior":qH_noninferior,
        "summary":{
            d:{h:{
                "qi_base":report[d][h]["qi"]["BASE_TERMINAL_SIDE_LINEAR"],
                "qi_quad":report[d][h]["qi"]["C1_QUADRATIC_STORAGE_PROFILE"],
                "qH_base":report[d][h]["qH"]["BASE_TERMINAL_SIDE_LINEAR"],
                "qH_quad":report[d][h]["qH"]["C1_QUADRATIC_STORAGE_PROFILE"],
                "shape":report[d][h]["quadratic_shape"]
            } for h in HISTORIES} for d in map(str,WIDTHS)
        }
    },sort_keys=True))
    return 0 if hard_ok else 2

if __name__=="__main__":
    raise SystemExit(main())
