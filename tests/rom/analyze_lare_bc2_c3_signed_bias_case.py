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

PRIMARY_DT=0.00005
CROSS_DT=0.000025
DTS=(PRIMARY_DT,CROSS_DT)
OBS_DT=c1.OBS_DT
GATE=1.0e-10
NFIXED=c1.NFIXED
PHYS_N=c1.PHYS_N
IDX_WB=c1.IDX_WB
IDX_WT=c1.IDX_WT
THETA_S=c1.THETA_S
VALID_WIDTHS=(2.5,5.0)
VALID_HISTORIES=tuple(c0.HISTORY_STEPS)
FIXED_KEYS=tuple(f"Q{10*(i+1)}" for i in range(NFIXED))
ELEMENTARY_KEYS=FIXED_KEYS+("QI","QH","GEOMETRY_GI")
FAMILY_MEMBERS={
    "FIXED_INTERIOR_Q":FIXED_KEYS[:-1],
    "Q90":("Q90",),
    "QI":("QI",),
    "QH":("QH",),
    "GEOMETRY_GI":("GEOMETRY_GI",),
}

def rms(x):
    a=np.asarray(x,dtype=float)
    return float(np.sqrt(np.mean(a*a))) if a.size else 0.0

def maxabs(x):
    a=np.asarray(x,dtype=float)
    return float(np.max(np.abs(a))) if a.size else 0.0

def thicknesses(H,d):
    B=H-c0.ANCHOR-d
    if B<=0.0:
        raise ValueError("OUTSIDE_QUALIFIED_DOMAIN nonpositive bulk thickness")
    return np.asarray([c0.FIXED_DZ]*NFIXED+[B,d],dtype=float)

def shape_rms(delta_w,H,d):
    L=thicknesses(H,d)
    dw=np.asarray(delta_w,dtype=float)
    raw=dw/L
    uniform=float(np.sum(dw))/float(np.sum(L))
    shape=raw-uniform
    return rms(shape),float(np.sum(L*shape))

def fixed_fluxes_from_storage(start,end):
    a=np.asarray(start,dtype=float)
    b=np.asarray(end,dtype=float)
    q=np.zeros(NFIXED,dtype=float)
    q[0]=-(b[0]-a[0])/OBS_DT
    for i in range(1,NFIXED):
        q[i]=q[i-1]-(b[i]-a[i])/OBS_DT
    return q

def contribution_vectors(errors):
    out={}
    for j,key in enumerate(FIXED_KEYS):
        v=np.zeros(PHYS_N,dtype=float)
        v[j]-=errors[key]*OBS_DT
        v[j+1]+=errors[key]*OBS_DT
        out[key]=v
    v=np.zeros(PHYS_N,dtype=float)
    v[IDX_WB]-=errors["QI"]*OBS_DT
    v[IDX_WT]+=errors["QI"]*OBS_DT
    out["QI"]=v
    v=np.zeros(PHYS_N,dtype=float)
    v[IDX_WT]-=errors["QH"]*OBS_DT
    out["QH"]=v
    v=np.zeros(PHYS_N,dtype=float)
    v[IDX_WB]+=errors["GEOMETRY_GI"]*OBS_DT
    v[IDX_WT]-=errors["GEOMETRY_GI"]*OBS_DT
    out["GEOMETRY_GI"]=v
    return out

def summarize_channel(biases,shape_values,cumulative_vector,Hfinal,d):
    b=np.asarray(biases,dtype=float)
    signed=float(np.sum(b)*OBS_DT)
    absolute=float(np.sum(np.abs(b))*OBS_DT)
    pos=int(np.count_nonzero(b>0.0))
    neg=int(np.count_nonzero(b<0.0))
    zero=int(len(b)-pos-neg)
    sr,res=shape_rms(cumulative_vector,Hfinal,d)
    return {
        "interval_count":int(len(b)),
        "mean_signed_bias_cm_per_day":float(np.mean(b)) if len(b) else 0.0,
        "rms_bias_cm_per_day":rms(b),
        "max_abs_bias_cm_per_day":maxabs(b),
        "signed_integrated_bias_cm":signed,
        "absolute_integrated_bias_cm":absolute,
        "coherence_ratio_abs_signed_over_absolute_integral":0.0 if absolute==0.0 else abs(signed)/absolute,
        "positive_interval_count":pos,
        "negative_interval_count":neg,
        "zero_interval_count":zero,
        "one_interval_shape_injection_rms_theta":rms(shape_values),
        "one_interval_shape_injection_max_theta":maxabs(shape_values),
        "cumulative_storage_injection_cm":[float(x) for x in cumulative_vector],
        "cumulative_injection_shape_rms_theta_at_final_geometry":sr,
        "cumulative_injection_shape_mass_neutral_residual_cm":res,
    }

def run_route(history,d,dt,init_meta,init_nodes,states,nodes):
    bias={k:[] for k in ELEMENTARY_KEYS}
    shape={k:[] for k in ELEMENTARY_KEYS}
    cum={k:np.zeros(PHYS_N,dtype=float) for k in ELEMENTARY_KEYS}
    max_add=0.0
    max_teacher_ledger=0.0
    max_reference_ledger=0.0
    max_q90_teacher_identity=0.0
    max_q90_reference_identity=0.0
    max_shape_mass_neutral=0.0
    final_H=None

    for step in range(1,c0.HISTORY_STEPS[history]+1):
        y0,p0,_=c1.exact_reference_state(history,step-1,d,init_meta,init_nodes,states,nodes)
        yr,p1,_=c1.exact_reference_state(history,step,d,init_meta,init_nodes,states,nodes)
        H0=float(p0["H"]); H1=float(p1["H"]); final_H=H1
        teacher=c1.advance_interval(y0,H0,H1,dt,d)
        yt=np.asarray(teacher["y"][:PHYS_N],dtype=float)
        y0p=np.asarray(y0[:PHYS_N],dtype=float)
        yrp=np.asarray(yr[:PHYS_N],dtype=float)

        qteach=fixed_fluxes_from_storage(y0p[:NFIXED],yt[:NFIXED])
        qref=fixed_fluxes_from_storage(y0p[:NFIXED],yrp[:NFIXED])
        refs=c1.reference_fluxes(history,step,p0,p1,states)
        max_q90_teacher_identity=max(max_q90_teacher_identity,abs(float(qteach[-1])-float(teacher["q90"])))
        max_q90_reference_identity=max(max_q90_reference_identity,abs(float(qref[-1])-float(refs["q90"])))

        Gi_teacher=(float(yt[IDX_WB]-y0p[IDX_WB])/OBS_DT)-float(qteach[-1])+float(teacher["qi"])
        Gi_ref=(float(yrp[IDX_WB]-y0p[IDX_WB])/OBS_DT)-float(qref[-1])+float(refs["qi"])

        errors={}
        for j,key in enumerate(FIXED_KEYS):
            errors[key]=float(qteach[j]-qref[j])
        errors["QI"]=float(teacher["qi"])-float(refs["qi"])
        errors["QH"]=float(teacher["qH"])-float(refs["qH"])
        errors["GEOMETRY_GI"]=Gi_teacher-Gi_ref

        contrib=contribution_vectors(errors)
        summed=np.sum(np.stack(list(contrib.values())),axis=0)
        local=yt-yrp
        max_add=max(max_add,float(np.max(np.abs(summed-local))))

        tledger=float(np.sum(yt-y0p))+float(teacher["qH"])*OBS_DT-THETA_S*(H1-H0)
        rledger=float(np.sum(yrp-y0p))+float(refs["qH"])*OBS_DT-THETA_S*(H1-H0)
        max_teacher_ledger=max(max_teacher_ledger,abs(tledger))
        max_reference_ledger=max(max_reference_ledger,abs(rledger))

        for key in ELEMENTARY_KEYS:
            bias[key].append(errors[key])
            sr,res=shape_rms(contrib[key],H1,d)
            shape[key].append(sr)
            cum[key]+=contrib[key]
            max_shape_mass_neutral=max(max_shape_mass_neutral,abs(res))

    elem={
        key:summarize_channel(bias[key],shape[key],cum[key],float(final_H),d)
        for key in ELEMENTARY_KEYS
    }
    fam={}
    for f,members in FAMILY_MEMBERS.items():
        fbias=np.sum(np.column_stack([np.asarray(bias[k]) for k in members]),axis=1)
        fshape=[]
        fcum=np.zeros(PHYS_N,dtype=float)
        # reconstruct family contribution per interval from elementary storage vectors
        # by recomputing scalar shape from stored bias contribution vectors
        for idx in range(len(fbias)):
            errs={k:0.0 for k in ELEMENTARY_KEYS}
            for k in members:
                errs[k]=bias[k][idx]
            v=np.sum(np.stack(list(contribution_vectors(errs).values())),axis=0)
            Hstep=(
                c1.exact_reference_state(history,idx+1,d,init_meta,init_nodes,states,nodes)[1]["H"]
            )
            sr,res=shape_rms(v,float(Hstep),d)
            fshape.append(sr)
            fcum+=v
            max_shape_mass_neutral=max(max_shape_mass_neutral,abs(res))
        fam[f]=summarize_channel(fbias,fshape,fcum,float(final_H),d)

    family_rank=sorted(
        fam,
        key=lambda k:(-fam[k]["cumulative_injection_shape_rms_theta_at_final_geometry"],k)
    )
    return {
        "status":"QUALIFIED" if max(
            max_add,max_teacher_ledger,max_reference_ledger,
            max_q90_teacher_identity,max_q90_reference_identity,max_shape_mass_neutral
        )<=GATE else "HARD_GATE_FAILED",
        "dt_day":dt,
        "elementary_channels":elem,
        "families":fam,
        "family_rank_by_cumulative_shape_injection":family_rank,
        "hard_checks":{
            "max_channel_state_additivity_residual_cm":max_add,
            "max_teacher_physical_ledger_residual_cm":max_teacher_ledger,
            "max_reference_physical_ledger_residual_cm":max_reference_ledger,
            "max_teacher_q90_reconstruction_identity_cm_per_day":max_q90_teacher_identity,
            "max_reference_q90_reconstruction_identity_cm_per_day":max_q90_reference_identity,
            "max_mass_neutral_projection_residual_cm":max_shape_mass_neutral,
            "gate":GATE,
        }
    }

def route_difference(a,b):
    out={"elementary_channels":{},"families":{}}
    fields=(
        "mean_signed_bias_cm_per_day","rms_bias_cm_per_day","max_abs_bias_cm_per_day",
        "signed_integrated_bias_cm","absolute_integrated_bias_cm",
        "coherence_ratio_abs_signed_over_absolute_integral",
        "one_interval_shape_injection_rms_theta","one_interval_shape_injection_max_theta",
        "cumulative_injection_shape_rms_theta_at_final_geometry"
    )
    for section in ("elementary_channels","families"):
        for key in a[section]:
            out[section][key]={
                f:abs(float(a[section][key][f])-float(b[section][key][f]))
                for f in fields
            }
    out["family_rank_match"]=a["family_rank_by_cumulative_shape_injection"]==b["family_rank_by_cumulative_shape_injection"]
    return out

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c2-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--width",required=True,type=float)
    ap.add_argument("--history",required=True,choices=VALID_HISTORIES)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    if args.width not in VALID_WIDTHS:
        raise SystemExit("unauthorized width")
    pre=json.loads(args.prereg.read_text())
    close=json.loads(args.c2_closeout.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_SIGNED_LOCAL_BIAS_LEDGER_EXECUTION"
    assert close["decision"]==pre["predecessor"]["required_C2_decision"]
    assert tuple(pre["model_policy"]["widths_cm"])==VALID_WIDTHS
    assert tuple(pre["model_policy"]["histories"])==VALID_HISTORIES
    assert float(pre["model_policy"]["primary_internal_dt_day"])==PRIMARY_DT
    assert float(pre["model_policy"]["cross_internal_dt_day"])==CROSS_DT

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
    diff=route_difference(routes[pk],routes[ck]) if complete else None
    result={
        "schema":"swap5.lare.bc2.c3.case-result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C3",
        "width_cm":args.width,
        "history":args.history,
        "decision":"BC2_C3_SIGNED_BIAS_CASE_MAPPED" if complete else "BC2_C3_CASE_BLOCKED",
        "complete":complete,
        "routes":routes,
        "route_consistency":diff,
        "failures":failures,
        "model_changed":False,
        "next_model_change_authorized":False,
        "groundwater_feedback_authorized":False,
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    if complete:
        p=routes[pk]
        print(json.dumps({
            "decision":result["decision"],
            "width_cm":args.width,
            "history":args.history,
            "primary_family_rank":p["family_rank_by_cumulative_shape_injection"],
            "primary_families":{k:{
                "signed_integrated_bias_cm":v["signed_integrated_bias_cm"],
                "absolute_integrated_bias_cm":v["absolute_integrated_bias_cm"],
                "coherence":v["coherence_ratio_abs_signed_over_absolute_integral"],
                "cumulative_shape_rms":v["cumulative_injection_shape_rms_theta_at_final_geometry"],
                "interval_shape_rms":v["one_interval_shape_injection_rms_theta"],
            } for k,v in p["families"].items()},
            "family_rank_match_cross":diff["family_rank_match"],
            "hard_checks":p["hard_checks"],
        },sort_keys=True))
    else:
        print(json.dumps({"decision":result["decision"],"failures":failures},sort_keys=True))
    return 0 if complete else 2

if __name__=="__main__":
    raise SystemExit(main())
