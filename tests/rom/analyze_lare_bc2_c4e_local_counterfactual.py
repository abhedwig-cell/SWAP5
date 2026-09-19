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

c3=load_module("bc2c3_c4e","analyze_lare_bc2_c3_signed_bias_case.py")
c1=c3.c1
c0=c3.c0

PRIMARY_DT=c3.PRIMARY_DT
CROSS_DT=c3.CROSS_DT
DTS=(PRIMARY_DT,CROSS_DT)
OBS_DT=c3.OBS_DT
GATE=c3.GATE
NFIXED=c3.NFIXED
PHYS_N=c3.PHYS_N
IDX_WB=c3.IDX_WB
IDX_WT=c3.IDX_WT
THETA_S=c3.THETA_S

VALID_WIDTHS=(2.5,5.0)
VALID_HISTORIES=("WT_RISE","WT_FALL")

FAMILIES=("QI","QH","GEOMETRY_GI","Q90","FIXED_INTERIOR_Q")
VARIANTS=("BASE",)+tuple("REMOVE_"+f for f in FAMILIES)


def rms(values):
    a=np.asarray(values,dtype=float)
    return float(np.sqrt(np.mean(a*a))) if a.size else 0.0


def mean(values):
    a=np.asarray(values,dtype=float)
    return float(np.mean(a)) if a.size else 0.0


def fixed_fluxes_from_storage(start,end):
    return c3.fixed_fluxes_from_storage(start,end)


def family_vectors(errors):
    elementary=c3.contribution_vectors(errors)
    out={}
    for family,members in c3.FAMILY_MEMBERS.items():
        out[family]=np.sum(
            np.stack([elementary[m] for m in members]),axis=0
        )
    return out


def physical_endpoint(endpoint,reference_full,H,d):
    y=np.array(reference_full,dtype=float,copy=True)
    y[:PHYS_N]=np.asarray(endpoint,dtype=float)
    try:
        hs=c0.hydraulic_state(y,H,d)
    except (ValueError,RuntimeError,FloatingPointError) as exc:
        return False,str(exc),None
    se=np.asarray(hs.get("se",[]),dtype=float)
    if se.size and (not np.all(np.isfinite(se)) or np.min(se)<0.0 or np.max(se)>1.0):
        return False,f"OUTSIDE_QUALIFIED_DOMAIN Se=[{float(np.min(se))},{float(np.max(se))}]",hs
    return True,None,hs


def summarize(records,base_shapes):
    shapes=[r["shape_rms_theta"] for r in records]
    wb=[r["Wb_error_cm"] for r in records]
    wt=[r["Wt_error_cm"] for r in records]
    total=[r["total_storage_error_cm"] for r in records]
    lower=sum(
        1 for r,b in zip(records,base_shapes)
        if r["shape_rms_theta"] < b
    )
    return {
        "interval_count":len(records),
        "pooled_rms_shape_error_theta":rms(shapes),
        "mean_shape_error_theta":mean(shapes),
        "max_shape_error_theta":float(max(shapes) if shapes else 0.0),
        "RMS_Wb_endpoint_error_cm":rms(wb),
        "RMS_Wt_endpoint_error_cm":rms(wt),
        "RMS_total_physical_storage_endpoint_error_cm":rms(total),
        "fraction_intervals_lower_shape_error_than_BASE":
            (float(lower)/len(records) if records else 0.0),
    }


def run_route(history,d,dt,init_meta,init_nodes,states,nodes):
    records={v:[] for v in VARIANTS}
    blocked={v:[] for v in VARIANTS}
    max_add=0.0
    max_teacher_ledger=0.0
    max_reference_ledger=0.0
    max_q90_teacher_identity=0.0
    max_q90_reference_identity=0.0

    for step in range(1,c0.HISTORY_STEPS[history]+1):
        y0,p0,_=c1.exact_reference_state(
            history,step-1,d,init_meta,init_nodes,states,nodes
        )
        yr,p1,_=c1.exact_reference_state(
            history,step,d,init_meta,init_nodes,states,nodes
        )
        H0=float(p0["H"]); H1=float(p1["H"])
        teacher=c1.advance_interval(y0,H0,H1,dt,d)

        yt=np.asarray(teacher["y"][:PHYS_N],dtype=float)
        y0p=np.asarray(y0[:PHYS_N],dtype=float)
        yrp=np.asarray(yr[:PHYS_N],dtype=float)
        local=yt-yrp

        qteach=fixed_fluxes_from_storage(y0p[:NFIXED],yt[:NFIXED])
        qref=fixed_fluxes_from_storage(y0p[:NFIXED],yrp[:NFIXED])
        refs=c1.reference_fluxes(history,step,p0,p1,states)

        max_q90_teacher_identity=max(
            max_q90_teacher_identity,
            abs(float(qteach[-1])-float(teacher["q90"]))
        )
        max_q90_reference_identity=max(
            max_q90_reference_identity,
            abs(float(qref[-1])-float(refs["q90"]))
        )

        Gi_teacher=(
            float(yt[IDX_WB]-y0p[IDX_WB])/OBS_DT
            -float(qteach[-1])+float(teacher["qi"])
        )
        Gi_ref=(
            float(yrp[IDX_WB]-y0p[IDX_WB])/OBS_DT
            -float(qref[-1])+float(refs["qi"])
        )

        errors={}
        for j,key in enumerate(c3.FIXED_KEYS):
            errors[key]=float(qteach[j]-qref[j])
        errors["QI"]=float(teacher["qi"])-float(refs["qi"])
        errors["QH"]=float(teacher["qH"])-float(refs["qH"])
        errors["GEOMETRY_GI"]=Gi_teacher-Gi_ref

        elementary=c3.contribution_vectors(errors)
        summed=np.sum(np.stack(list(elementary.values())),axis=0)
        max_add=max(max_add,float(np.max(np.abs(summed-local))))

        tledger=(
            float(np.sum(yt-y0p))
            +float(teacher["qH"])*OBS_DT
            -THETA_S*(H1-H0)
        )
        rledger=(
            float(np.sum(yrp-y0p))
            +float(refs["qH"])*OBS_DT
            -THETA_S*(H1-H0)
        )
        max_teacher_ledger=max(max_teacher_ledger,abs(tledger))
        max_reference_ledger=max(max_reference_ledger,abs(rledger))

        fam=family_vectors(errors)
        endpoints={"BASE":yt}
        for family in FAMILIES:
            endpoints["REMOVE_"+family]=yt-fam[family]

        for variant,endpoint in endpoints.items():
            ok,why,_=physical_endpoint(endpoint,yr,H1,d)
            if not ok:
                blocked[variant].append({
                    "step":step,
                    "H_end_cm":H1,
                    "reason":why,
                })
                continue
            err=np.asarray(endpoint-yrp,dtype=float)
            sr,res=c3.shape_rms(err,H1,d)
            if abs(res)>GATE:
                raise RuntimeError(
                    f"HARD_GATE_FAILED shape_mass_neutral={res} "
                    f"variant={variant} step={step}"
                )
            records[variant].append({
                "step":step,
                "shape_rms_theta":sr,
                "Wb_error_cm":float(err[IDX_WB]),
                "Wt_error_cm":float(err[IDX_WT]),
                "total_storage_error_cm":float(np.sum(err)),
            })

    hard=max(
        max_add,max_teacher_ledger,max_reference_ledger,
        max_q90_teacher_identity,max_q90_reference_identity
    )
    base_complete=len(records["BASE"])==c0.HISTORY_STEPS[history] and not blocked["BASE"]
    base_shapes=[r["shape_rms_theta"] for r in records["BASE"]]

    summaries={}
    for variant in VARIANTS:
        complete=(
            len(records[variant])==c0.HISTORY_STEPS[history]
            and not blocked[variant]
        )
        summaries[variant]={
            "physically_admissible_all_intervals":complete,
            "blocked_interval_count":len(blocked[variant]),
            "blocked_intervals":blocked[variant][:16],
            "metrics":summarize(records[variant],base_shapes)
                if complete else None,
        }

    controls_complete=all(
        summaries["REMOVE_"+f]["physically_admissible_all_intervals"]
        for f in FAMILIES
    )
    qi_complete=summaries["REMOVE_QI"]["physically_admissible_all_intervals"]

    ranking=[]
    unique_best=None
    if controls_complete:
        ranking=sorted(
            ("REMOVE_"+f for f in FAMILIES),
            key=lambda v:(
                summaries[v]["metrics"]["pooled_rms_shape_error_theta"],v
            )
        )
        if len(ranking)>=2:
            first=summaries[ranking[0]]["metrics"]["pooled_rms_shape_error_theta"]
            second=summaries[ranking[1]]["metrics"]["pooled_rms_shape_error_theta"]
            if first<second:
                unique_best=ranking[0]

    base_metric=(
        summaries["BASE"]["metrics"]["pooled_rms_shape_error_theta"]
        if base_complete else None
    )
    qi_metric=(
        summaries["REMOVE_QI"]["metrics"]["pooled_rms_shape_error_theta"]
        if qi_complete else None
    )
    qi_strict_improvement=(
        base_metric is not None and qi_metric is not None and qi_metric<base_metric
    )

    return {
        "status":"QUALIFIED" if base_complete and hard<=GATE else "BASELINE_BLOCKED",
        "dt_day":dt,
        "variants":summaries,
        "all_single_family_controls_physically_admissible":controls_complete,
        "QI_physically_admissible_all_intervals":qi_complete,
        "QI_strictly_improves_BASE":qi_strict_improvement,
        "single_family_rank_by_pooled_rms_shape":ranking,
        "unique_best_single_family":unique_best,
        "hard_checks":{
            "max_channel_state_additivity_residual_cm":max_add,
            "max_teacher_physical_ledger_residual_cm":max_teacher_ledger,
            "max_reference_physical_ledger_residual_cm":max_reference_ledger,
            "max_teacher_q90_reconstruction_identity_cm_per_day":
                max_q90_teacher_identity,
            "max_reference_q90_reconstruction_identity_cm_per_day":
                max_q90_reference_identity,
            "maximum":hard,
            "gate":GATE,
        },
    }


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c3b",required=True,type=pathlib.Path)
    ap.add_argument("--c4d",required=True,type=pathlib.Path)
    ap.add_argument("--c4b-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--width",required=True,type=float)
    ap.add_argument("--history",required=True,choices=VALID_HISTORIES)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    c3b=json.loads(args.c3b.read_text())
    c4d=json.loads(args.c4d.read_text())
    c4b=json.loads(args.c4b_closeout.read_text())
    assert pre["phase"]=="PREREGISTERED_AFTER_C3B_C4D_BEFORE_LOCAL_QI_CAUSAL_COUNTERFACTUAL"
    assert c3b["decision"]==pre["predecessors"]["C3B"]["required_decision"]
    assert c4d["decision"]==pre["predecessors"]["C4D"]["required_decision"]
    assert c4d["mechanisms"]["H_CANCELLATION"]["supported"] is True
    assert c4b["status"]==pre["predecessors"]["C4B"]["required_status"]
    assert args.width in tuple(float(x) for x in pre["cases"]["widths_cm"])

    init_meta,init_nodes,states,nodes=c0.b0.load_reference(args.reference)
    routes={}
    failures={}
    for dt in DTS:
        key=f"{dt:.8f}"
        try:
            routes[key]=run_route(
                args.history,args.width,dt,init_meta,init_nodes,states,nodes
            )
            if routes[key]["status"]!="QUALIFIED":
                failures[key]=routes[key]["status"]
        except (ValueError,RuntimeError,FloatingPointError) as exc:
            failures[key]=str(exc)

    pk=f"{PRIMARY_DT:.8f}"; ck=f"{CROSS_DT:.8f}"
    baseline_qualified=(
        not failures and pk in routes and ck in routes
        and routes[pk]["status"]=="QUALIFIED"
        and routes[ck]["status"]=="QUALIFIED"
    )
    all_controls=baseline_qualified and all(
        routes[r]["all_single_family_controls_physically_admissible"]
        for r in (pk,ck)
    )
    qi_admissible=baseline_qualified and all(
        routes[r]["QI_physically_admissible_all_intervals"]
        for r in (pk,ck)
    )
    qi_improves=baseline_qualified and all(
        routes[r]["QI_strictly_improves_BASE"]
        for r in (pk,ck)
    )
    rank_match=(
        baseline_qualified
        and routes[pk]["single_family_rank_by_pooled_rms_shape"]
            == routes[ck]["single_family_rank_by_pooled_rms_shape"]
    )
    unique_qi=(
        all_controls and rank_match
        and routes[pk]["unique_best_single_family"]=="REMOVE_QI"
        and routes[ck]["unique_best_single_family"]=="REMOVE_QI"
    )

    if not baseline_qualified or not qi_admissible or not all_controls:
        decision="QI_LOCAL_CAUSAL_DIAGNOSTIC_BLOCKED"
    elif not qi_improves:
        decision="QI_LOCAL_CAUSAL_NOT_SUPPORTED"
    elif unique_qi:
        decision="QI_LOCAL_CAUSAL_SUPPORT"
    else:
        decision="QI_LOCAL_CAUSAL_MIXED"

    hard=max(
        [
            routes[r]["hard_checks"]["maximum"]
            for r in routes
            if routes[r].get("hard_checks")
        ] or [float("inf")]
    )
    result={
        "schema":"swap5.lare.bc2.c4e.case-result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C4E",
        "width_cm":args.width,
        "history":args.history,
        "decision":decision,
        "complete":baseline_qualified and hard<=GATE,
        "routes":routes,
        "route_rank_match":rank_match,
        "all_single_family_controls_physically_admissible":all_controls,
        "QI_physically_admissible_all_intervals":qi_admissible,
        "QI_strictly_improves_BASE_both_routes":qi_improves,
        "unique_QI_best_both_routes":unique_qi,
        "failures":failures,
        "hard_checks":{"maximum":hard,"gate":GATE},
        "model_changed":False,
        "next_model_change_authorized":False,
        "groundwater_feedback_authorized":False,
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":decision,
        "width_cm":args.width,
        "history":args.history,
        "route_rank_match":rank_match,
        "all_controls_admissible":all_controls,
        "QI_admissible":qi_admissible,
        "QI_improves":qi_improves,
        "unique_QI_best":unique_qi,
        "primary_rank":routes.get(pk,{}).get(
            "single_family_rank_by_pooled_rms_shape"
        ),
        "cross_rank":routes.get(ck,{}).get(
            "single_family_rank_by_pooled_rms_shape"
        ),
        "primary_BASE_shape":(
            routes.get(pk,{}).get("variants",{})
            .get("BASE",{}).get("metrics",{})
            .get("pooled_rms_shape_error_theta")
        ),
        "primary_REMOVE_QI_shape":(
            routes.get(pk,{}).get("variants",{})
            .get("REMOVE_QI",{}).get("metrics",{})
            .get("pooled_rms_shape_error_theta")
        ),
        "hard":result["hard_checks"],
    },sort_keys=True))
    return 0 if result["complete"] else 2


if __name__=="__main__":
    raise SystemExit(main())
