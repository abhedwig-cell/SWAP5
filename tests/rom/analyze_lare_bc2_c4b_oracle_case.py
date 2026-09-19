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

c1=load_module("bc2c1","analyze_lare_bc2_c1_teacher_forced.py")
c0=c1.c0

WIDTHS=(2.5,5.0)
HISTORIES=tuple(c0.HISTORY_STEPS)
OBS_DT=c1.OBS_DT
PRIMARY_DT=0.00005
CROSS_DT=0.000025
DTS=(PRIMARY_DT,CROSS_DT)
GATE=1.0e-10
NFIXED=c1.NFIXED
PHYS_N=c1.PHYS_N
IDX_WB=c1.IDX_WB
IDX_WT=c1.IDX_WT
IDX_CUM_QH=c1.IDX_CUM_QH
IDX_CUM_QI=c1.IDX_CUM_QI
THETA_S=c1.THETA_S

VARIANTS=(
    "BASE_C0",
    "ORACLE_Q90",
    "ORACLE_QI",
    "ORACLE_QH",
    "ORACLE_GI",
    "ORACLE_QI_QH",
    "ORACLE_QI_QH_GI",
    "ORACLE_Q90_QI_QH_GI",
)
SINGLE_ORACLES=("ORACLE_Q90","ORACLE_QI","ORACLE_QH","ORACLE_GI")


def shape_rms(delta_w,H,d):
    B=H-c0.ANCHOR-d
    if B<=0:
        raise ValueError("OUTSIDE_QUALIFIED_DOMAIN nonpositive bulk thickness")
    thickness=np.asarray([c0.FIXED_DZ]*NFIXED+[B,d],dtype=float)
    dw=np.asarray(delta_w,dtype=float)
    theta_delta=dw/thickness
    uniform=float(np.sum(dw))/float(np.sum(thickness))
    shape=theta_delta-uniform
    residual=float(np.sum(thickness*shape))
    return float(np.sqrt(np.mean(shape*shape))),residual


def exact_interval_oracles(history,step,d,init_meta,init_nodes,states,nodes):
    y0,p0,_=c1.exact_reference_state(history,step-1,d,init_meta,init_nodes,states,nodes)
    y1,p1,_=c1.exact_reference_state(history,step,d,init_meta,init_nodes,states,nodes)
    refs=c1.reference_fluxes(history,step,p0,p1,states)
    q90=float(refs["q90"]); qi=float(refs["qi"]); qH=float(refs["qH"])
    Gi=(float(y1[IDX_WB]-y0[IDX_WB])/OBS_DT)-q90+qi
    H0=float(p0["H"]); H1=float(p1["H"])
    return y0,y1,H0,H1,{"q90":q90,"qi":qi,"qH":qH,"Gi":Gi}


def variant_channels(variant):
    return {
        "q90": variant in ("ORACLE_Q90","ORACLE_Q90_QI_QH_GI"),
        "qi": variant in ("ORACLE_QI","ORACLE_QI_QH","ORACLE_QI_QH_GI","ORACLE_Q90_QI_QH_GI"),
        "qH": variant in ("ORACLE_QH","ORACLE_QI_QH","ORACLE_QI_QH_GI","ORACLE_Q90_QI_QH_GI"),
        "Gi": variant in ("ORACLE_GI","ORACLE_QI_QH_GI","ORACLE_Q90_QI_QH_GI"),
    }


def rhs_variant(y,H,Hdot,d,variant,oracle):
    dy,meta=c0.rhs(y,H,Hdot,d)
    dy=np.asarray(dy,dtype=float).copy()
    use=variant_channels(variant)

    q90_base=float(meta["q90"])
    qi_base=float(meta["qi"])
    qH_base=float(meta["qH"])
    Gi_base=float(meta["theta_i"])*Hdot

    dq90=(oracle["q90"]-q90_base) if use["q90"] else 0.0
    dqi=(oracle["qi"]-qi_base) if use["qi"] else 0.0
    dqH=(oracle["qH"]-qH_base) if use["qH"] else 0.0
    dGi=(oracle["Gi"]-Gi_base) if use["Gi"] else 0.0

    dy[NFIXED-1] -= dq90
    dy[IDX_WB] += dq90 - dqi + dGi
    dy[IDX_WT] += dqi - dqH - dGi
    dy[IDX_CUM_QH] += dqH
    dy[IDX_CUM_QI] += dqi

    return dy,{
        **meta,
        "q90_used":q90_base+dq90,
        "qi_used":qi_base+dqi,
        "qH_used":qH_base+dqH,
        "Gi_used":Gi_base+dGi,
    }


def heun_step_variant(y,dt,H0,H1,Hdot,d,variant,oracle):
    f0,_=rhs_variant(y,H0,Hdot,d,variant,oracle)
    guess=y+dt*f0
    for iteration in range(1,c0.MAX_CORRECTOR+1):
        f1,_=rhs_variant(guess,H1,Hdot,d,variant,oracle)
        nxt=y+0.5*dt*(f0+f1)
        old=c0.convergence_vector(guess,H1,d)
        new=c0.convergence_vector(nxt,H1,d)
        if np.max(np.abs(new-old))<=c0.CORRECTOR_TOL:
            return nxt,iteration
        guess=nxt
    raise RuntimeError("NUMERICAL_BLOCKED iterative Heun corrector")


def advance(y0,H0,H1,dt,d,variant,oracle):
    ratio=OBS_DT/dt
    nsub=int(round(ratio))
    if nsub<=0 or abs(ratio-nsub)>1e-12:
        raise RuntimeError("dt does not divide observation interval")
    y=np.array(y0,dtype=float,copy=True)
    y[IDX_CUM_QH]=0.0
    y[IDX_CUM_QI]=0.0
    Hdot=(H1-H0)/OBS_DT
    max_iter=0
    for sub in range(nsub):
        fa=sub/nsub; fb=(sub+1)/nsub
        Ha=H0+(H1-H0)*fa
        Hb=H0+(H1-H0)*fb
        y,it=heun_step_variant(y,dt,Ha,Hb,Hdot,d,variant,oracle)
        max_iter=max(max_iter,it)
    return y,max_iter


def rms(values):
    a=np.asarray(values,dtype=float)
    return float(np.sqrt(np.mean(a*a))) if a.size else 0.0


def summarize_variant(rows,cumulative,Hfinal,d):
    shape=[r["shape_rms"] for r in rows]
    total=[r["total_error_cm"] for r in rows]
    wb=[r["Wb_error_cm"] for r in rows]
    wt=[r["Wt_error_cm"] for r in rows]
    cum_shape,cum_res=shape_rms(cumulative,Hfinal,d)
    return {
        "interval_count":len(rows),
        "interval_shape_rms_theta":rms(shape),
        "interval_shape_max_theta":float(max(shape) if shape else 0.0),
        "total_storage_error_rms_cm":rms(total),
        "total_storage_error_max_abs_cm":float(max([abs(x) for x in total] or [0.0])),
        "Wb_error_rms_cm":rms(wb),
        "Wt_error_rms_cm":rms(wt),
        "cumulative_local_error_vector_cm":[float(x) for x in cumulative],
        "cumulative_shape_rms_theta_at_final_geometry":cum_shape,
        "cumulative_shape_mass_neutral_residual_cm":cum_res,
        "max_abs_ledger_residual_cm":float(max([abs(r["ledger_residual_cm"]) for r in rows] or [0.0])),
        "max_corrector_iterations":int(max([r["corrector_iterations"] for r in rows] or [0])),
    }


def run_route(history,d,dt,init_meta,init_nodes,states,nodes):
    rows={v:[] for v in VARIANTS}
    cumulative={v:np.zeros(PHYS_N,dtype=float) for v in VARIANTS}
    max_oracle_identity=0.0
    max_baseline_identity=0.0
    max_shape_residual=0.0
    Hfinal=None

    for step in range(1,c0.HISTORY_STEPS[history]+1):
        y0,yr,H0,H1,oracle=exact_interval_oracles(history,step,d,init_meta,init_nodes,states,nodes)
        Hfinal=H1

        # Independent Reference identity checks.
        qH_direct=states[(history,step)]["bottom_exchange"]/OBS_DT
        max_oracle_identity=max(max_oracle_identity,abs(oracle["qH"]-qH_direct))

        baseline_check=c1.advance_interval(y0,H0,H1,dt,d)
        baseline_y=np.asarray(baseline_check["y"][:PHYS_N],dtype=float)

        for variant in VARIANTS:
            y,it=advance(y0,H0,H1,dt,d,variant,oracle)
            phys=np.asarray(y[:PHYS_N],dtype=float)
            if variant=="BASE_C0":
                max_baseline_identity=max(max_baseline_identity,float(np.max(np.abs(phys-baseline_y))))

            err=phys-np.asarray(yr[:PHYS_N],dtype=float)
            sr,res=shape_rms(err,H1,d)
            max_shape_residual=max(max_shape_residual,abs(res))
            ledger=(
                float(np.sum(phys-np.asarray(y0[:PHYS_N],dtype=float)))
                + float(y[IDX_CUM_QH])
                - THETA_S*(H1-H0)
            )
            row={
                "step":step,
                "shape_rms":sr,
                "total_error_cm":float(np.sum(err)),
                "Wb_error_cm":float(err[IDX_WB]),
                "Wt_error_cm":float(err[IDX_WT]),
                "ledger_residual_cm":ledger,
                "corrector_iterations":it,
            }
            rows[variant].append(row)
            cumulative[variant]+=err

    summaries={
        v:summarize_variant(rows[v],cumulative[v],float(Hfinal),d)
        for v in VARIANTS
    }
    base=summaries["BASE_C0"]
    for v in VARIANTS:
        if v=="BASE_C0":
            summaries[v]["relative_to_BASE"]={}
            continue
        cur=summaries[v]
        rel={}
        for key in (
            "interval_shape_rms_theta",
            "interval_shape_max_theta",
            "total_storage_error_rms_cm",
            "Wb_error_rms_cm",
            "Wt_error_rms_cm",
            "cumulative_shape_rms_theta_at_final_geometry",
        ):
            b=float(base[key]); c=float(cur[key])
            rel[key+"_fraction"]=None if b==0.0 else c/b
            rel[key+"_reduction_fraction"]=None if b==0.0 else 1.0-c/b
        summaries[v]["relative_to_BASE"]=rel

    single_rank=sorted(
        SINGLE_ORACLES,
        key=lambda v:(summaries[v]["cumulative_shape_rms_theta_at_final_geometry"],v)
    )
    hard=max(
        max_oracle_identity,
        max_baseline_identity,
        max_shape_residual,
        max(v["max_abs_ledger_residual_cm"] for v in summaries.values()),
    )
    return {
        "status":"QUALIFIED" if hard<=GATE else "HARD_GATE_FAILED",
        "dt_day":dt,
        "variants":summaries,
        "single_channel_rank_by_cumulative_shape":single_rank,
        "best_single_channel":single_rank[0],
        "hard_checks":{
            "max_reference_oracle_identity_cm_per_day":max_oracle_identity,
            "max_BASE_vs_C1_implementation_identity_cm":max_baseline_identity,
            "max_mass_neutral_projection_residual_cm":max_shape_residual,
            "max_variant_physical_ledger_residual_cm":max(v["max_abs_ledger_residual_cm"] for v in summaries.values()),
            "gate":GATE,
        }
    }


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c3a",required=True,type=pathlib.Path)
    ap.add_argument("--width",required=True,type=float)
    ap.add_argument("--history",required=True,choices=HISTORIES)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    if args.width not in WIDTHS:
        raise SystemExit("unauthorized width")
    pre=json.loads(args.prereg.read_text())
    c3a=json.loads(args.c3a.read_text())
    assert pre["phase"]=="PREREGISTERED_AFTER_C3A_BEFORE_ORACLE_INTERVENTION_RESPONSE"
    assert c3a["decision"]==pre["predecessor"]["required_C3A_decision"]
    assert c3a["c4_authority"]=="NO_GLOBAL_CLOSURE_CHANGE_NEW_REGIME_PREREGISTRATION_REQUIRED"

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
    pk=f"{PRIMARY_DT:.8f}"; ck=f"{CROSS_DT:.8f}"
    complete=not failures and pk in routes and ck in routes
    result={
        "schema":"swap5.lare.bc2.c4b.case-result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C4B",
        "width_cm":args.width,
        "history":args.history,
        "decision":"BC2_C4B_ORACLE_CASE_MAPPED" if complete else "BC2_C4B_CASE_BLOCKED",
        "complete":complete,
        "routes":routes,
        "failures":failures,
        "model_candidate_tested":False,
        "oracle_diagnostic_only":True,
        "next_model_change_authorized":False,
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    if complete:
        print(json.dumps({
            "decision":result["decision"],
            "width_cm":args.width,
            "history":args.history,
            "primary_best_single":routes[pk]["best_single_channel"],
            "cross_best_single":routes[ck]["best_single_channel"],
            "primary_single_rank":routes[pk]["single_channel_rank_by_cumulative_shape"],
            "cross_single_rank":routes[ck]["single_channel_rank_by_cumulative_shape"],
            "primary_cumulative_shape":{v:routes[pk]["variants"][v]["cumulative_shape_rms_theta_at_final_geometry"] for v in VARIANTS},
            "primary_interval_shape":{v:routes[pk]["variants"][v]["interval_shape_rms_theta"] for v in VARIANTS},
            "hard_checks":routes[pk]["hard_checks"],
        },sort_keys=True))
    else:
        print(json.dumps({"decision":result["decision"],"failures":failures},sort_keys=True))
    return 0 if complete else 2

if __name__=="__main__":
    raise SystemExit(main())
