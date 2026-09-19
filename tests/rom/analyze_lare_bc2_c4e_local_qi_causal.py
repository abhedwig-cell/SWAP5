#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import pathlib

import numpy as np

HERE=pathlib.Path(__file__).resolve().parent

def load_module(name,filename):
    spec=importlib.util.spec_from_file_location(name,HERE/filename)
    mod=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

c3=load_module("bc2c3","analyze_lare_bc2_c3_signed_bias_case.py")
c1=c3.c1
c0=c3.c0

OBS_DT=c3.OBS_DT
PHYS_N=c3.PHYS_N
NFIXED=c3.NFIXED
IDX_WB=c3.IDX_WB
IDX_WT=c3.IDX_WT
THETA_S=c3.THETA_S
GATE=c3.GATE
DTS=(0.00005,0.000025)
WIDTHS=(2.5,5.0)
HISTORIES=("WT_RISE","WT_FALL")
FAMILIES=("FIXED_INTERIOR_Q","Q90","QI","QH","GEOMETRY_GI")
VARIANTS=("BASE",)+tuple("REMOVE_"+x for x in FAMILIES)

def rms(values):
    a=np.asarray(values,dtype=float)
    return float(np.sqrt(np.mean(a*a))) if a.size else 0.0

def family_vectors(errors):
    elementary=c3.contribution_vectors(errors)
    fixed=np.sum(np.stack([elementary[k] for k in c3.FIXED_KEYS[:-1]]),axis=0)
    return {
        "FIXED_INTERIOR_Q":fixed,
        "Q90":elementary["Q90"],
        "QI":elementary["QI"],
        "QH":elementary["QH"],
        "GEOMETRY_GI":elementary["GEOMETRY_GI"],
    }

def run_route(history,d,dt,init_meta,init_nodes,states,nodes):
    shape={v:[] for v in VARIANTS}
    wb={v:[] for v in VARIANTS}
    wt={v:[] for v in VARIANTS}
    total={v:[] for v in VARIANTS}
    improved={v:0 for v in VARIANTS if v!="BASE"}
    blocked={v:[] for v in VARIANTS if v!="BASE"}

    max_add=0.0
    max_teacher_ledger=0.0
    max_reference_ledger=0.0
    max_q90_teacher_identity=0.0
    max_q90_reference_identity=0.0
    max_qi_mass_neutral=0.0
    max_gi_mass_neutral=0.0
    max_q90_mass_neutral=0.0
    max_fixed_mass_neutral=0.0

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
        max_q90_teacher_identity=max(max_q90_teacher_identity,abs(float(qteach[-1])-float(teacher["q90"])))
        max_q90_reference_identity=max(max_q90_reference_identity,abs(float(qref[-1])-float(refs["q90"])))

        Gi_teacher=(float(yt[IDX_WB]-y0p[IDX_WB])/OBS_DT)-float(qteach[-1])+float(teacher["qi"])
        Gi_ref=(float(yrp[IDX_WB]-y0p[IDX_WB])/OBS_DT)-float(qref[-1])+float(refs["qi"])

        errors={}
        for j,key in enumerate(c3.FIXED_KEYS):
            errors[key]=float(qteach[j]-qref[j])
        errors["QI"]=float(teacher["qi"])-float(refs["qi"])
        errors["QH"]=float(teacher["qH"])-float(refs["qH"])
        errors["GEOMETRY_GI"]=Gi_teacher-Gi_ref

        fam=family_vectors(errors)
        local=yt-yrp
        summed=np.sum(np.stack(list(fam.values())),axis=0)
        max_add=max(max_add,float(np.max(np.abs(summed-local))))

        max_qi_mass_neutral=max(max_qi_mass_neutral,abs(float(np.sum(fam["QI"]))))
        max_gi_mass_neutral=max(max_gi_mass_neutral,abs(float(np.sum(fam["GEOMETRY_GI"]))))
        max_q90_mass_neutral=max(max_q90_mass_neutral,abs(float(np.sum(fam["Q90"]))))
        max_fixed_mass_neutral=max(max_fixed_mass_neutral,abs(float(np.sum(fam["FIXED_INTERIOR_Q"]))))

        tledger=float(np.sum(yt-y0p))+float(teacher["qH"])*OBS_DT-THETA_S*(H1-H0)
        rledger=float(np.sum(yrp-y0p))+float(refs["qH"])*OBS_DT-THETA_S*(H1-H0)
        max_teacher_ledger=max(max_teacher_ledger,abs(tledger))
        max_reference_ledger=max(max_reference_ledger,abs(rledger))

        base_sr,_=c3.shape_rms(local,H1,d)
        shape["BASE"].append(base_sr)
        wb["BASE"].append(float(local[IDX_WB]))
        wt["BASE"].append(float(local[IDX_WT]))
        total["BASE"].append(float(np.sum(local)))

        for family in FAMILIES:
            variant="REMOVE_"+family
            residual=local-fam[family]
            cf=np.array(teacher["y"],dtype=float,copy=True)
            cf[:PHYS_N]=yrp+residual
            try:
                c0.hydraulic_state(cf,H1,d)
            except (ValueError,RuntimeError,FloatingPointError) as exc:
                blocked[variant].append({"step":step,"reason":str(exc)})
                continue
            sr,_=c3.shape_rms(residual,H1,d)
            shape[variant].append(sr)
            wb[variant].append(float(residual[IDX_WB]))
            wt[variant].append(float(residual[IDX_WT]))
            total[variant].append(float(np.sum(residual)))
            if sr < base_sr:
                improved[variant]+=1

    n=c0.HISTORY_STEPS[history]
    summaries={}
    for variant in VARIANTS:
        admissible=(variant=="BASE") or len(blocked[variant])==0
        count=len(shape[variant])
        summaries[variant]={
            "admissible_all_intervals":admissible and count==n,
            "evaluated_interval_count":count,
            "blocked_interval_count":0 if variant=="BASE" else len(blocked[variant]),
            "blocked_examples":[] if variant=="BASE" else blocked[variant][:8],
            "pooled_rms_shape_error_theta":rms(shape[variant]),
            "mean_shape_error_theta":float(np.mean(shape[variant])) if count else None,
            "max_shape_error_theta":float(np.max(shape[variant])) if count else None,
            "rms_Wb_endpoint_error_cm":rms(wb[variant]),
            "rms_Wt_endpoint_error_cm":rms(wt[variant]),
            "rms_total_physical_storage_endpoint_error_cm":rms(total[variant]),
            "fraction_intervals_lower_shape_error_than_BASE":(
                None if variant=="BASE" else (improved[variant]/n)
            )
        }

    admissible_removals=[
        v for v in VARIANTS if v!="BASE" and summaries[v]["admissible_all_intervals"]
    ]
    rank=sorted(admissible_removals,key=lambda v:(summaries[v]["pooled_rms_shape_error_theta"],v))
    qi=summaries["REMOVE_QI"]
    all_controls_admissible=all(summaries[v]["admissible_all_intervals"] for v in VARIANTS if v!="BASE")
    qi_strict_vs_base=(
        qi["admissible_all_intervals"]
        and qi["pooled_rms_shape_error_theta"] < summaries["BASE"]["pooled_rms_shape_error_theta"]
    )
    qi_unique_best=(
        all_controls_admissible
        and bool(rank)
        and rank[0]=="REMOVE_QI"
        and all(
            qi["pooled_rms_shape_error_theta"] < summaries[v]["pooled_rms_shape_error_theta"]
            for v in admissible_removals if v!="REMOVE_QI"
        )
    )

    hard={
        "max_family_state_additivity_residual_cm":max_add,
        "max_teacher_physical_ledger_residual_cm":max_teacher_ledger,
        "max_reference_physical_ledger_residual_cm":max_reference_ledger,
        "max_teacher_q90_reconstruction_identity_cm_per_day":max_q90_teacher_identity,
        "max_reference_q90_reconstruction_identity_cm_per_day":max_q90_reference_identity,
        "max_QI_mass_neutral_residual_cm":max_qi_mass_neutral,
        "max_GEOMETRY_GI_mass_neutral_residual_cm":max_gi_mass_neutral,
        "max_Q90_mass_neutral_residual_cm":max_q90_mass_neutral,
        "max_FIXED_INTERIOR_Q_mass_neutral_residual_cm":max_fixed_mass_neutral,
        "gate":GATE
    }
    hardmax=max(v for k,v in hard.items() if k!="gate")
    baseline_qualified=hardmax<=GATE
    if not baseline_qualified or not qi["admissible_all_intervals"] or not all_controls_admissible:
        decision="CASE_DIAGNOSTIC_BLOCKED"
    elif qi_strict_vs_base and qi_unique_best:
        decision="CASE_QI_UNIQUE_BEST"
    elif qi_strict_vs_base:
        decision="CASE_QI_IMPROVES_NOT_UNIQUE"
    else:
        decision="CASE_QI_NOT_IMPROVE"

    return {
        "status":"QUALIFIED" if baseline_qualified else "HARD_GATE_FAILED",
        "decision":decision,
        "dt_day":dt,
        "history":history,
        "width_cm":d,
        "interval_count":n,
        "variants":summaries,
        "single_family_removal_rank_by_pooled_shape_error":rank,
        "QI_strictly_improves_BASE":qi_strict_vs_base,
        "QI_unique_best_single_family_removal":qi_unique_best,
        "all_single_family_controls_admissible":all_controls_admissible,
        "hard_checks":hard
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c3b",required=True,type=pathlib.Path)
    ap.add_argument("--c4d",required=True,type=pathlib.Path)
    ap.add_argument("--c4b-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--width",required=True,type=float)
    ap.add_argument("--history",required=True,choices=HISTORIES)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    if args.width not in WIDTHS:
        raise SystemExit("unauthorized width")
    pre=json.loads(args.prereg.read_text())
    c3b=json.loads(args.c3b.read_text())
    c4d=json.loads(args.c4d.read_text())
    c4b=json.loads(args.c4b_closeout.read_text())
    assert pre["phase"]=="PREREGISTERED_AFTER_C3B_C4D_BEFORE_LOCAL_QI_CAUSAL_COUNTERFACTUAL"
    assert pre["pre_execution_comparison_integrity"]["before_first_C4E_execution"] is True
    assert c3b["decision"]==pre["predecessors"]["C3B"]["required_decision"]
    assert c4d["decision"]==pre["predecessors"]["C4D"]["required_decision"]
    mech=pre["predecessors"]["C4D"]["required_mechanism"]
    assert c4d["mechanisms"][mech]["supported"] is pre["predecessors"]["C4D"]["required_supported"]
    assert c4b["status"]==pre["predecessors"]["C4B"]["required_status"]

    init_meta,init_nodes,states,nodes=c0.b0.load_reference(args.reference)
    routes={}
    failures={}
    for dt in DTS:
        key=f"{dt:.8f}"
        try:
            routes[key]=run_route(args.history,args.width,dt,init_meta,init_nodes,states,nodes)
        except (ValueError,RuntimeError,FloatingPointError) as exc:
            failures[key]=str(exc)

    complete=not failures and len(routes)==2
    rank_match=(
        complete
        and routes[f"{DTS[0]:.8f}"]["single_family_removal_rank_by_pooled_shape_error"]
        == routes[f"{DTS[1]:.8f}"]["single_family_removal_rank_by_pooled_shape_error"]
    )
    result={
        "schema":"swap5.lare.bc2.c4e.case-result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C4E",
        "width_cm":args.width,
        "history":args.history,
        "complete":complete,
        "decision":"BC2_C4E_LOCAL_CAUSAL_CASE_MAPPED" if complete else "BC2_C4E_CASE_BLOCKED",
        "routes":routes,
        "primary_cross_removal_rank_match":rank_match,
        "failures":failures,
        "model_changed":False,
        "counterfactual_propagated":False,
        "groundwater_feedback_authorized":False,
        "production_rom_authorized":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "schema":result["schema"],
        "decision":result["decision"],
        "width_cm":args.width,
        "history":args.history,
        "primary_cross_removal_rank_match":rank_match,
        "routes":{
            k:{
                "decision":v["decision"],
                "rank":v["single_family_removal_rank_by_pooled_shape_error"],
                "QI_vs_BASE":v["QI_strictly_improves_BASE"],
                "QI_unique_best":v["QI_unique_best_single_family_removal"],
                "all_controls_admissible":v["all_single_family_controls_admissible"],
                "base_shape_rms":v["variants"]["BASE"]["pooled_rms_shape_error_theta"],
                "QI_shape_rms":v["variants"]["REMOVE_QI"]["pooled_rms_shape_error_theta"],
                "hard_checks":v["hard_checks"]
            } for k,v in routes.items()
        },
        "failures":failures
    },sort_keys=True))
    return 0 if complete else 2

if __name__=="__main__":
    raise SystemExit(main())
