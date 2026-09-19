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

b9=load_module("bc2b9_c4h","analyze_lare_bc2_b9_internal_flux.py")
b8=b9.b8
b3=b9.b3

WIDTHS=(2.5,5.0)
HISTORIES=("WT_RISE","WT_FALL")
QI_GATE=1.0e-10
FACT_GATE=1.0e-12

def scalar_stats(values):
    a=np.asarray(values,dtype=float)
    return {
        "count":int(len(a)),
        "mean":float(np.mean(a)),
        "mae":float(np.mean(np.abs(a))),
        "rms":float(np.sqrt(np.mean(a*a))),
        "max_abs":float(np.max(np.abs(a))),
        "min":float(np.min(a)),
        "max":float(np.max(a)),
    }

def corr(a,b):
    x=np.asarray(a,dtype=float); y=np.asarray(b,dtype=float)
    if len(x)<2 or np.std(x)==0.0 or np.std(y)==0.0:
        return None
    return float(np.corrcoef(x,y)[0,1])

def cosine_series(a,b):
    x=np.asarray(a,dtype=float); y=np.asarray(b,dtype=float)
    den=float(np.sqrt(np.dot(x,x)*np.dot(y,y)))
    return None if den==0.0 else float(np.dot(x,y)/den)

def k_from_theta(theta):
    _,k=b3.psi_k(np.asarray([theta],dtype=float))
    return float(k[0])

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--b8-result",required=True,type=pathlib.Path)
    ap.add_argument("--b9-result",required=True,type=pathlib.Path)
    ap.add_argument("--c4g-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    r8=json.loads(args.b8_result.read_text())
    r9=json.loads(args.b9_result.read_text())
    c4g=json.loads(args.c4g_closeout.read_text())
    assert pre["phase"]=="PREREGISTERED_AFTER_C4G_BEFORE_TERMINAL_QI_FACTORISATION"
    assert pre["pre_execution_clarification"]["before_first_C4H_execution"] is True
    assert r8["decision"]==pre["predecessors"]["B8"]["required_decision"]
    assert r9["decision"]==pre["predecessors"]["B9"]["required_decision"]
    assert pre["predecessors"]["B9"]["required_preferred_operator"] in r9["preferred_operator"]
    assert c4g["status"]==pre["predecessors"]["C4G"]["required_status"]
    assert c4g["decision"]==pre["predecessors"]["C4G"]["required_decision"]

    init_meta,init_nodes,states,nodes=b3.load_reference(args.reference)
    cases={}
    max_qi_identity=0.0
    max_factor_residual=0.0
    min_K=float("inf")
    failures=[]

    for d in WIDTHS:
        cases[str(d)]={}
        for history in HISTORIES:
            rows=[]
            p0=b8.projected(init_nodes[history],init_meta[history]["total"],d)
            try:
                c0=b9.endpoint_candidates(init_nodes[history],init_meta[history]["total"],d)
            except ValueError as exc:
                failures.append({"width_cm":d,"history":history,"step":0,"error":str(exc)})
                continue

            for step in range(1,b3.HISTORY_STEPS[history]+1):
                p1=b8.projected(nodes[(history,step)],states[(history,step)]["total"],d)
                try:
                    c1=b9.endpoint_candidates(nodes[(history,step)],states[(history,step)]["total"],d)
                except ValueError as exc:
                    failures.append({"width_cm":d,"history":history,"step":step,"error":str(exc)})
                    break

                qH=states[(history,step)]["bottom_exchange"]/b3.OBS_DT
                q90=-(p1["Wfixed"]-p0["Wfixed"])/b3.OBS_DT
                Hdot=(p1["H"]-p0["H"])/b3.OBS_DT
                Gi=0.5*(p0["theta_i"]+p1["theta_i"])*Hdot
                dWb=(p1["Wb64"]-p0["Wb64"])/b3.OBS_DT
                dWt=(p1["Wt64"]-p0["Wt64"])/b3.OBS_DT
                qi_bulk=q90+Gi-dWb
                qi_term=dWt+qH-b3.THETA_S*Hdot+Gi
                max_qi_identity=max(max_qi_identity,abs(qi_bulk-qi_term))
                qi_ref=0.5*(qi_bulk+qi_term)
                qi_pred=0.5*(c0["TERMINAL_SIDE_LINEAR"]+c1["TERMINAL_SIDE_LINEAR"])

                Kref0=k_from_theta(float(p0["theta_i"]))
                Kref1=k_from_theta(float(p1["theta_i"]))
                Kref=0.5*(Kref0+Kref1)
                Kpred=0.5*(float(c0["Ki"])+float(c1["Ki"]))
                min_K=min(min_K,Kref,Kpred)
                if not (math.isfinite(Kref) and math.isfinite(Kpred) and Kref>0.0 and Kpred>0.0):
                    failures.append({"width_cm":d,"history":history,"step":step,"error":"nonpositive or nonfinite interface conductivity"})
                    break

                gref=qi_ref/Kref
                gpred=qi_pred/Kpred
                dK=Kpred-Kref
                dg=gpred-gref
                EK=dK*0.5*(gpred+gref)
                EG=dg*0.5*(Kpred+Kref)
                residual=(qi_pred-qi_ref)-(EK+EG)
                max_factor_residual=max(max_factor_residual,abs(residual))

                graw=0.5*((1.0-float(c0["a_t"]))+(1.0-float(c1["a_t"])))
                rows.append({
                    "step":step,
                    "qi_ref_cm_per_day":qi_ref,
                    "qi_pred_cm_per_day":qi_pred,
                    "qi_error_cm_per_day":qi_pred-qi_ref,
                    "K_ref_bar_cm_per_day":Kref,
                    "K_pred_bar_cm_per_day":Kpred,
                    "g_ref_effective":gref,
                    "g_pred_effective":gpred,
                    "g_pred_raw_endpoint_average":graw,
                    "g_temporal_product_correction":gpred-graw,
                    "E_K_cm_per_day":EK,
                    "E_G_cm_per_day":EG,
                    "factorisation_residual_cm_per_day":residual,
                    "gradient_component_abs_larger":abs(EG)>abs(EK),
                    "conductivity_component_abs_larger":abs(EK)>abs(EG),
                })
                p0=p1; c0=c1

            expected=b3.HISTORY_STEPS[history]
            if len(rows)!=expected:
                continue
            ek=np.asarray([r["E_K_cm_per_day"] for r in rows])
            eg=np.asarray([r["E_G_cm_per_day"] for r in rows])
            qe=np.asarray([r["qi_error_cm_per_day"] for r in rows])
            kref=np.asarray([r["K_ref_bar_cm_per_day"] for r in rows])
            kpred=np.asarray([r["K_pred_bar_cm_per_day"] for r in rows])
            gref=np.asarray([r["g_ref_effective"] for r in rows])
            gpred=np.asarray([r["g_pred_effective"] for r in rows])
            gcorr=np.asarray([r["g_temporal_product_correction"] for r in rows])

            sk=scalar_stats(ek); sg=scalar_stats(eg)
            if sg["rms"]>sk["rms"] and sg["mae"]>sk["mae"]:
                classification="GRADIENT_COMPONENT_DOMINANT"
            elif sk["rms"]>sg["rms"] and sk["mae"]>sg["mae"]:
                classification="CONDUCTIVITY_COMPONENT_DOMINANT"
            else:
                classification="MIXED_COMPONENTS"

            denom=float(np.sum(np.abs(ek)+np.abs(eg)))
            signed_cancel=0.0 if denom==0.0 else abs(float(np.sum(ek+eg)))/denom
            abs_cancel=0.0 if denom==0.0 else float(np.sum(np.abs(ek+eg)))/denom
            cases[str(d)][history]={
                "classification":classification,
                "interval_count":len(rows),
                "qi_error":scalar_stats(qe),
                "conductivity_component_EK":sk,
                "gradient_component_EG":sg,
                "fraction_abs_EG_gt_EK":float(np.mean(np.abs(eg)>np.abs(ek))),
                "fraction_abs_EK_gt_EG":float(np.mean(np.abs(ek)>np.abs(eg))),
                "component_correlation":corr(ek,eg),
                "component_cosine_over_history":cosine_series(ek,eg),
                "signed_history_cancellation_ratio":signed_cancel,
                "absolute_component_cancellation_ratio":abs_cancel,
                "K_ref_bar":scalar_stats(kref),
                "K_pred_bar":scalar_stats(kpred),
                "K_pred_minus_ref":scalar_stats(kpred-kref),
                "g_ref_effective":scalar_stats(gref),
                "g_pred_effective":scalar_stats(gpred),
                "g_pred_minus_ref":scalar_stats(gpred-gref),
                "temporal_product_correction_gpred_minus_raw_endpoint_gradient":scalar_stats(gcorr),
                "rows":rows
            }

    complete=not failures and all(h in cases[str(d)] for d in WIDTHS for h in HISTORIES)
    classes=[cases[str(d)][h]["classification"] for d in WIDTHS for h in HISTORIES if h in cases[str(d)]]
    hard_ok=complete and max_qi_identity<=QI_GATE and max_factor_residual<=FACT_GATE and min_K>0.0
    if not hard_ok:
        decision="C4H_DIAGNOSTIC_BLOCKED"
    elif all(x=="GRADIENT_COMPONENT_DOMINANT" for x in classes):
        decision="TERMINAL_QI_GRADIENT_RECONSTRUCTION_TARGET_SUPPORTED"
    elif all(x=="CONDUCTIVITY_COMPONENT_DOMINANT" for x in classes):
        decision="TERMINAL_QI_CONDUCTIVITY_RECONSTRUCTION_TARGET_SUPPORTED"
    else:
        decision="TERMINAL_QI_FACTORISATION_MIXED"

    result={
        "schema":"swap5.lare.bc2.c4h.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C4H",
        "decision":decision,
        "complete":complete,
        "hard_checks":{
            "max_abs_B8_qi_bulk_minus_terminal_cm_per_day":max_qi_identity,
            "B8_qi_identity_gate_cm_per_day":QI_GATE,
            "max_abs_symmetric_factorisation_residual_cm_per_day":max_factor_residual,
            "factorisation_gate_cm_per_day":FACT_GATE,
            "minimum_interface_conductivity_cm_per_day":min_K,
            "failure_count":len(failures)
        },
        "case_classification_counts":{
            k:classes.count(k) for k in ("GRADIENT_COMPONENT_DOMINANT","CONDUCTIVITY_COMPONENT_DOMINANT","MIXED_COMPONENTS")
        },
        "cases":cases,
        "failures":failures[:20],
        "interpretation":[
            "C4H factorises the already-authorized B9 TERMINAL_SIDE_LINEAR interval flux error. It does not alter that closure.",
            "Reference qi comes from the conservative B8 moving-control-volume ledger. Reference interface conductivity comes from the exact projected interface theta only for diagnosis.",
            "Effective gradient factors are interval-level diagnostic quantities that close q=K g exactly; they are not pointwise Richards gradients.",
            "The symmetric product-difference factorisation avoids arbitrary sequencing of conductivity and gradient updates.",
            "A unanimous component result may focus the next reconstruction study, but does not itself authorize a new closure."
        ],
        "next_authority":"PREREGISTER_COMPONENT_TARGETED_TERMINAL_RECONSTRUCTION_IF_UNANIMOUS" if hard_ok and len(set(classes))==1 else "RESOLVE_MIXED_COMPONENT_ATTRIBUTION_BEFORE_RECONSTRUCTION",
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
        "case_classification_counts":result["case_classification_counts"],
        "case_summary":{
            d:{h:{
                "classification":cases[d][h]["classification"],
                "qi_error":cases[d][h]["qi_error"],
                "EK":cases[d][h]["conductivity_component_EK"],
                "EG":cases[d][h]["gradient_component_EG"],
                "fraction_abs_EG_gt_EK":cases[d][h]["fraction_abs_EG_gt_EK"],
                "component_cosine":cases[d][h]["component_cosine_over_history"],
                "signed_history_cancellation_ratio":cases[d][h]["signed_history_cancellation_ratio"],
                "g_temporal_product_correction":cases[d][h]["temporal_product_correction_gpred_minus_raw_endpoint_gradient"]
            } for h in HISTORIES} for d in map(str,WIDTHS)
        }
    },sort_keys=True))
    return 0 if hard_ok else 2

if __name__=="__main__":
    raise SystemExit(main())
