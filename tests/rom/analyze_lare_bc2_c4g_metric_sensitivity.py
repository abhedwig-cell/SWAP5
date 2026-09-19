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

c4f=load_module("bc2c4f","analyze_lare_bc2_c4f_vector_interference.py")
c4e=c4f.c4e
c3=c4f.c3
c1=c4f.c1
c0=c4f.c0

OBS_DT=c3.OBS_DT
PHYS_N=c3.PHYS_N
NFIXED=c3.NFIXED
IDX_WB=c3.IDX_WB
IDX_WT=c3.IDX_WT
GATE=1.0e-10
SQ_GATE=1.0e-12
DTS=(0.00005,0.000025)
WIDTHS=(2.5,5.0)
HISTORIES=("WT_RISE","WT_FALL")

def weighted_mean_square(v,L):
    v=np.asarray(v,dtype=float); L=np.asarray(L,dtype=float)
    return float(np.sum(L*v*v)/np.sum(L))

def weighted_dot(a,b,L):
    a=np.asarray(a,dtype=float); b=np.asarray(b,dtype=float); L=np.asarray(L,dtype=float)
    return float(np.sum(L*a*b)/np.sum(L))

def cosine(a,b,weights=None):
    a=np.asarray(a,dtype=float); b=np.asarray(b,dtype=float)
    if weights is None:
        aa=float(np.mean(a*a)); bb=float(np.mean(b*b)); ab=float(np.mean(a*b))
    else:
        aa=weighted_mean_square(a,weights); bb=weighted_mean_square(b,weights); ab=weighted_dot(a,b,weights)
    if aa<=0.0 or bb<=0.0:
        return None
    return float(ab/math.sqrt(aa*bb))

def rms(values):
    a=np.asarray(values,dtype=float)
    return float(np.sqrt(np.mean(a*a))) if a.size else 0.0

def run_route(history,d,dt,init_meta,init_nodes,states,nodes):
    rows=[]
    max_add=0.0
    max_unw_identity=0.0
    max_w_identity=0.0
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
        max_add=max(max_add,float(np.max(np.abs(np.sum(np.stack(list(fam.values())),axis=0)-local))))
        q=np.asarray(fam["QI"],dtype=float)
        rem=local-q
        L=c3.thicknesses(H1,d)
        es=c4f.shape_vector(local,H1,d)
        qs=c4f.shape_vector(q,H1,d)
        rs=c4f.shape_vector(rem,H1,d)

        ue2=float(np.mean(es*es)); uq2=float(np.mean(qs*qs)); ur2=float(np.mean(rs*rs)); udot=float(np.mean(qs*rs))
        we2=weighted_mean_square(es,L); wq2=weighted_mean_square(qs,L); wr2=weighted_mean_square(rs,L); wdot=weighted_dot(qs,rs,L)
        udelta=ur2-ue2; upred=-(uq2+2.0*udot)
        wdelta=wr2-we2; wpred=-(wq2+2.0*wdot)
        max_unw_identity=max(max_unw_identity,abs(udelta-upred))
        max_w_identity=max(max_w_identity,abs(wdelta-wpred))

        rows.append({
            "step":step,
            "unweighted":{
                "local_rms":math.sqrt(ue2),"qi_rms":math.sqrt(uq2),"remainder_rms":math.sqrt(ur2),
                "qi_dot_remainder":udot,"cosine_qi_remainder":cosine(qs,rs),
                "delta_mean_square":udelta,"removal_improves":ur2<ue2,"removal_worsens":ur2>ue2
            },
            "depth_weighted":{
                "local_rms":math.sqrt(we2),"qi_rms":math.sqrt(wq2),"remainder_rms":math.sqrt(wr2),
                "qi_dot_remainder":wdot,"cosine_qi_remainder":cosine(qs,rs,L),
                "delta_mean_square":wdelta,"removal_improves":wr2<we2,"removal_worsens":wr2>we2
            }
        })

    def summarize(metric):
        local=rms([r[metric]["local_rms"] for r in rows])
        qi=rms([r[metric]["qi_rms"] for r in rows])
        rem=rms([r[metric]["remainder_rms"] for r in rows])
        n=len(rows)
        imp=sum(r[metric]["removal_improves"] for r in rows)
        wor=sum(r[metric]["removal_worsens"] for r in rows)
        cos=[r[metric]["cosine_qi_remainder"] for r in rows if r[metric]["cosine_qi_remainder"] is not None]
        return {
            "pooled_local_rms":local,
            "pooled_qi_rms":qi,
            "pooled_remainder_rms":rem,
            "remainder_to_local_ratio":None if local==0.0 else rem/local,
            "pooled_direction":"IMPROVES" if rem<local else "WORSENS" if rem>local else "EQUAL",
            "fraction_removal_improves":imp/n,
            "fraction_removal_worsens":wor/n,
            "mean_cosine_qi_remainder":None if not cos else float(np.mean(cos)),
            "median_cosine_qi_remainder":None if not cos else float(np.median(cos))
        }

    sign_change=sum(
        r["unweighted"]["removal_improves"]!=r["depth_weighted"]["removal_improves"]
        or r["unweighted"]["removal_worsens"]!=r["depth_weighted"]["removal_worsens"]
        for r in rows
    )
    return {
        "status":"QUALIFIED" if max_add<=GATE and max_unw_identity<=SQ_GATE and max_w_identity<=SQ_GATE else "HARD_GATE_FAILED",
        "dt_day":dt,
        "interval_count":len(rows),
        "unweighted":summarize("unweighted"),
        "depth_weighted":summarize("depth_weighted"),
        "fraction_interval_direction_changes_between_metrics":sign_change/len(rows),
        "hard_checks":{
            "max_family_state_additivity_residual_cm":max_add,
            "max_unweighted_squared_norm_identity_residual_theta2":max_unw_identity,
            "max_depth_weighted_squared_norm_identity_residual_theta2":max_w_identity,
            "additive_gate_cm":GATE,
            "squared_norm_gate_theta2":SQ_GATE
        }
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c4f-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--width",required=True,type=float)
    ap.add_argument("--history",required=True,choices=HISTORIES)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    close=json.loads(args.c4f_closeout.read_text())
    assert pre["phase"]=="PREREGISTERED_AFTER_C4F_BEFORE_SECONDARY_METRIC_SENSITIVITY"
    assert close["status"]==pre["predecessors"]["C4F"]["required_status"]
    assert close["decision"]==pre["predecessors"]["C4F"]["required_decision"]
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
        "schema":"swap5.lare.bc2.c4g.case-result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C4G",
        "width_cm":args.width,
        "history":args.history,
        "decision":"BC2_C4G_CASE_MAPPED" if complete else "BC2_C4G_CASE_BLOCKED",
        "complete":complete,
        "routes":routes,
        "failures":failures,
        "model_changed":False,
        "new_richards_solves":False,
        "production_rom_authorized":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":result["decision"],"width_cm":args.width,"history":args.history,
        "routes":routes,"failures":failures
    },sort_keys=True))
    return 0 if complete else 2

if __name__=="__main__":
    raise SystemExit(main())
