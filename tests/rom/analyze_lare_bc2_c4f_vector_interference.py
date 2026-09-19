#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import pathlib

import numpy as np

HERE=pathlib.Path(__file__).resolve().parent

def load_module(name,filename):
    spec=importlib.util.spec_from_file_location(name,HERE/filename)
    mod=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

c4e=load_module("bc2c4e","analyze_lare_bc2_c4e_local_qi_causal.py")
c3=c4e.c3
c1=c4e.c1
c0=c4e.c0

OBS_DT=c3.OBS_DT
PHYS_N=c3.PHYS_N
NFIXED=c3.NFIXED
IDX_WB=c3.IDX_WB
IDX_WT=c3.IDX_WT
THETA_R=c0.THETA_R
THETA_S=c3.THETA_S
GATE=1.0e-10
SQ_GATE=1.0e-12
DTS=(0.00005,0.000025)
WIDTHS=(2.5,5.0)
HISTORIES=("WT_RISE","WT_FALL")

def rms(x):
    a=np.asarray(x,dtype=float)
    return float(np.sqrt(np.mean(a*a))) if a.size else 0.0

def shape_vector(delta_w,H,d):
    L=c3.thicknesses(H,d)
    dw=np.asarray(delta_w,dtype=float)
    raw=dw/L
    uniform=float(np.sum(dw))/float(np.sum(L))
    return raw-uniform

def safe_cos(a,b):
    aa=float(np.dot(a,a)); bb=float(np.dot(b,b))
    if aa<=0.0 or bb<=0.0:
        return None
    return float(np.dot(a,b)/math.sqrt(aa*bb))

def quantiles(values):
    a=np.asarray(values,dtype=float)
    if not len(a):
        return {"mean":None,"median":None,"p05":None,"p95":None,"min":None,"max":None}
    return {
        "mean":float(np.mean(a)),
        "median":float(np.median(a)),
        "p05":float(np.percentile(a,5)),
        "p95":float(np.percentile(a,95)),
        "min":float(np.min(a)),
        "max":float(np.max(a)),
    }

def run_route(history,d,dt,init_meta,init_nodes,states,nodes):
    rows=[]
    max_add=0.0
    max_sq_identity=0.0
    max_mass=0.0
    for step in range(1,c0.HISTORY_STEPS[history]+1):
        y0,p0,_=c1.exact_reference_state(history,step-1,d,init_meta,init_nodes,states,nodes)
        yr,p1,_=c1.exact_reference_state(history,step,d,init_meta,init_nodes,states,nodes)
        H0=float(p0["H"]); H1=float(p1["H"])
        teacher=c1.advance_interval(y0,H0,H1,dt,d)
        yt=np.asarray(teacher["y"][:PHYS_N],dtype=float)
        y0p=np.asarray(y0[:PHYS_N],dtype=float)
        yrp=np.asarray(yr[:PHYS_N],dtype=float)

        qteach=c3.fixed_fluxes_from_storage(y0p[:NFIXED],yt[:NFIXED])
        qref=c3.fixed_fluxes_from_storage(y0p[:NFIXED],yrp[:NFIXED])
        refs=c1.reference_fluxes(history,step,p0,p1,states)
        Gi_teacher=(float(yt[IDX_WB]-y0p[IDX_WB])/OBS_DT)-float(qteach[-1])+float(teacher["qi"])
        Gi_ref=(float(yrp[IDX_WB]-y0p[IDX_WB])/OBS_DT)-float(qref[-1])+float(refs["qi"])

        errors={}
        for j,key in enumerate(c3.FIXED_KEYS):
            errors[key]=float(qteach[j]-qref[j])
        errors["QI"]=float(teacher["qi"])-float(refs["qi"])
        errors["QH"]=float(teacher["qH"])-float(refs["qH"])
        errors["GEOMETRY_GI"]=Gi_teacher-Gi_ref
        fam=c4e.family_vectors(errors)
        local=yt-yrp
        family_sum=np.sum(np.stack(list(fam.values())),axis=0)
        max_add=max(max_add,float(np.max(np.abs(family_sum-local))))

        q=np.asarray(fam["QI"],dtype=float)
        rem=local-q
        max_mass=max(max_mass,abs(float(np.sum(q))))
        es=shape_vector(local,H1,d)
        qs=shape_vector(q,H1,d)
        rs=shape_vector(rem,H1,d)
        e2=float(np.mean(es*es))
        q2=float(np.mean(qs*qs))
        r2=float(np.mean(rs*rs))
        qdotr=float(np.mean(qs*rs))
        predictor=-(q2+2.0*qdotr)
        delta=r2-e2
        sq_res=abs(delta-predictor)
        max_sq_identity=max(max_sq_identity,sq_res)

        cf=yt-q
        B=H1-c0.ANCHOR-d
        teacher_theta_b=float(yt[IDX_WB]/B)
        teacher_theta_t=float(yt[IDX_WT]/d)
        cf_theta_b=float(cf[IDX_WB]/B)
        cf_theta_t=float(cf[IDX_WT]/d)
        dtheta_b=cf_theta_b-teacher_theta_b
        dtheta_t=cf_theta_t-teacher_theta_t
        mean_margin=min(
            cf_theta_b-THETA_R,THETA_S-cf_theta_b,
            cf_theta_t-THETA_R,THETA_S-cf_theta_t
        )
        hydraulic_ok=True
        hydraulic_reason=None
        interface_margin=None
        try:
            hs=c0.hydraulic_state(
                np.concatenate([cf,[0.0]*(c0.NSTATE-PHYS_N)]),
                H1,d
            )
            interface_margin=min(
                float(hs["theta_i"])-THETA_R,
                THETA_S-float(hs["theta_i"])
            )
        except (ValueError,RuntimeError,FloatingPointError) as exc:
            hydraulic_ok=False
            hydraulic_reason=str(exc)

        improves=r2<e2
        worsens=r2>e2
        sign_prediction_improves=(q2+2.0*qdotr)>0.0
        sign_prediction_worsens=(q2+2.0*qdotr)<0.0

        rows.append({
            "step":step,
            "H_end_cm":H1,
            "local_shape_rms_theta":math.sqrt(e2),
            "qi_shape_rms_theta":math.sqrt(q2),
            "remainder_shape_rms_theta":math.sqrt(r2),
            "qi_dot_remainder_theta2":qdotr,
            "cosine_qi_remainder":safe_cos(qs,rs),
            "removal_delta_mean_square_theta2":delta,
            "removal_predictor_delta_mean_square_theta2":predictor,
            "squared_norm_identity_residual_theta2":sq_res,
            "removal_improves":improves,
            "removal_worsens":worsens,
            "prediction_improves":sign_prediction_improves,
            "prediction_worsens":sign_prediction_worsens,
            "qi_storage_transfer_cm":float(q[IDX_WT]),
            "abs_qi_storage_transfer_cm":abs(float(q[IDX_WT])),
            "counterfactual_delta_theta_bulk":dtheta_b,
            "counterfactual_delta_theta_terminal":dtheta_t,
            "abs_delta_theta_terminal":abs(dtheta_t),
            "terminal_conversion_factor_per_cm":(
                abs(dtheta_t)/abs(float(q[IDX_WT]))
                if abs(float(q[IDX_WT]))>0.0 else None
            ),
            "counterfactual_mean_theta_margin":mean_margin,
            "counterfactual_hydraulic_admissible":hydraulic_ok,
            "counterfactual_hydraulic_reason":hydraulic_reason,
            "counterfactual_interface_theta_margin":interface_margin
        })

    n=len(rows)
    cos=[r["cosine_qi_remainder"] for r in rows if r["cosine_qi_remainder"] is not None]
    transfer=[r["abs_qi_storage_transfer_cm"] for r in rows]
    dtt=[r["abs_delta_theta_terminal"] for r in rows]
    margins=[r["counterfactual_mean_theta_margin"] for r in rows]
    iface=[r["counterfactual_interface_theta_margin"] for r in rows if r["counterfactual_interface_theta_margin"] is not None]
    blocked=[r for r in rows if not r["counterfactual_hydraulic_admissible"]]
    improve=sum(1 for r in rows if r["removal_improves"])
    worsen=sum(1 for r in rows if r["removal_worsens"])
    pred_match=sum(
        1 for r in rows
        if (r["removal_improves"]==r["prediction_improves"])
        and (r["removal_worsens"]==r["prediction_worsens"])
    )
    mean_margin_block_match=sum(
        1 for r in rows
        if (r["counterfactual_mean_theta_margin"]<0.0)
        == (not r["counterfactual_hydraulic_admissible"])
    )
    pooled_local=rms([r["local_shape_rms_theta"] for r in rows])
    pooled_qi=rms([r["qi_shape_rms_theta"] for r in rows])
    pooled_rem=rms([r["remainder_shape_rms_theta"] for r in rows])
    return {
        "status":"QUALIFIED" if max_add<=GATE and max_sq_identity<=SQ_GATE and max_mass<=GATE else "HARD_GATE_FAILED",
        "dt_day":dt,
        "interval_count":n,
        "pooled_rms":{
            "local_shape_theta":pooled_local,
            "qi_shape_theta":pooled_qi,
            "non_qi_remainder_shape_theta":pooled_rem,
            "remainder_to_local_ratio":None if pooled_local==0 else pooled_rem/pooled_local
        },
        "interference":{
            "qi_dot_remainder_theta2":quantiles([r["qi_dot_remainder_theta2"] for r in rows]),
            "cosine_qi_remainder":quantiles(cos),
            "fraction_removal_improves":improve/n,
            "fraction_removal_worsens":worsen/n,
            "fraction_sign_prediction_exact":pred_match/n
        },
        "width_margin":{
            "abs_qi_storage_transfer_cm":quantiles(transfer),
            "abs_counterfactual_delta_theta_terminal":quantiles(dtt),
            "expected_terminal_conversion_factor_per_cm":1.0/d,
            "observed_conversion_factor_nonzero":quantiles([
                r["terminal_conversion_factor_per_cm"]
                for r in rows if r["terminal_conversion_factor_per_cm"] is not None
            ]),
            "counterfactual_mean_theta_margin":quantiles(margins),
            "counterfactual_interface_theta_margin_admissible_only":quantiles(iface),
            "hydraulic_blocked_interval_count":len(blocked),
            "first_hydraulic_blocked_step":None if not blocked else blocked[0]["step"],
            "fraction_hydraulic_admissible":1.0-len(blocked)/n,
            "fraction_hydraulic_block_classified_by_negative_mean_margin":mean_margin_block_match/n
        },
        "hard_checks":{
            "max_family_state_additivity_residual_cm":max_add,
            "max_QI_mass_neutral_residual_cm":max_mass,
            "max_squared_norm_identity_residual_theta2":max_sq_identity,
            "additive_gate_cm":GATE,
            "squared_norm_gate_theta2":SQ_GATE
        },
        "intervals":rows
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c4e-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--width",required=True,type=float)
    ap.add_argument("--history",required=True,choices=HISTORIES)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    close=json.loads(args.c4e_closeout.read_text())
    assert pre["phase"]=="PREREGISTERED_AFTER_C4E_BEFORE_VECTOR_INTERFERENCE_DIAGNOSTIC"
    assert close["status"]==pre["predecessors"]["C4E"]["required_status"]
    assert close["decision"]==pre["predecessors"]["C4E"]["required_decision"]
    if args.width not in WIDTHS:
        raise SystemExit("unauthorized width")

    init_meta,init_nodes,states,nodes=c0.b0.load_reference(args.reference)
    routes={}
    failures={}
    for dt in DTS:
        key=f"{dt:.8f}"
        try:
            routes[key]=run_route(args.history,args.width,dt,init_meta,init_nodes,states,nodes)
            if routes[key]["status"]!="QUALIFIED":
                failures[key]=routes[key]["status"]
        except (ValueError,RuntimeError,FloatingPointError) as exc:
            failures[key]=str(exc)

    complete=not failures and len(routes)==2
    result={
        "schema":"swap5.lare.bc2.c4f.case-result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C4F",
        "width_cm":args.width,
        "history":args.history,
        "complete":complete,
        "decision":"BC2_C4F_CASE_MAPPED" if complete else "BC2_C4F_CASE_BLOCKED",
        "routes":routes,
        "failures":failures,
        "model_changed":False,
        "new_richards_solves":False,
        "counterfactual_propagated":False,
        "groundwater_feedback_authorized":False,
        "production_rom_authorized":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":result["decision"],
        "width_cm":args.width,
        "history":args.history,
        "routes":{k:{
            "status":v["status"],
            "pooled_rms":v["pooled_rms"],
            "interference":v["interference"],
            "width_margin":v["width_margin"],
            "hard_checks":v["hard_checks"]
        } for k,v in routes.items()},
        "failures":failures
    },sort_keys=True))
    return 0 if complete else 2

if __name__=="__main__":
    raise SystemExit(main())
