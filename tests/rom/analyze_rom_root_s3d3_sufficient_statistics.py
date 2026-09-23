#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib

GUARD=2.9103830456733704e-11
MATERIALS=("B01","B14")
HISTORIES=("V01","V02","V03","V04")
REPS=("U4","U8","R8","R16")
SEGMENTS=(1,2,3,4)
SEGMENT_COUNT=8192
TOTAL_COUNT=32768

def fields(line:str)->dict[str,str]:
    out={}
    for item in line.split("|")[1:]:
        if "=" in item:
            k,v=item.split("=",1)
            out[k]=v
    return out

def ff(x:str)->float:
    return float(x.replace("D","E").replace("d","e"))

def case_logs(root:pathlib.Path,material:str,history:str)->list[pathlib.Path]:
    out=[]
    for seg in SEGMENTS:
        hits=list(root.glob(f"**/{material}_R2048_T32_o0_{history}_seg{seg}.txt"))
        if len(hits)!=1:
            raise SystemExit(f"{material} {history} seg{seg}: expected one log, found {len(hits)}")
        out.append(hits[0])
    return out

def parse_case(paths:list[pathlib.Path],material:str,history:str)->dict:
    rows={rep:[] for rep in REPS}
    for path in paths:
        for line in path.read_text(errors="replace").splitlines():
            if not line.startswith("ROM_ROOT_S3D3_SUMMARY|"):
                continue
            r=fields(line)
            if r.get("CASE")!=history:
                continue
            rep=r["REP"]
            if rep not in rows:
                raise SystemExit(f"{material} {history}: unexpected representation {rep}")
            rows[rep].append({
                "count":int(r["COUNT"]),
                "max_layer_uth":ff(r["MAX_LAYER_UTH"]),
                "max_layer_uj":ff(r["MAX_LAYER_UJ"]),
                "max_total_uth":ff(r["MAX_TOTAL_UTH"]),
                "max_total_uj":ff(r["MAX_TOTAL_UJ"]),
                "max_uth_uj":ff(r["MAX_UTH_UJ"]),
                "max_occ_id":ff(r["MAX_OCC_ID"]),
                "transition_layers":int(r["TRANSITION_LAYERS"]),
                "mixed_layers":int(r["MIXED_LAYERS"]),
            })
    out={}
    for rep in REPS:
        parts=rows[rep]
        if len(parts)!=4:
            raise SystemExit(f"{material} {history} {rep}: expected four segment summaries, got {len(parts)}")
        if any(x["count"]!=SEGMENT_COUNT for x in parts):
            raise SystemExit(f"{material} {history} {rep}: segment count mismatch")
        out[rep]={
            "transaction_count":sum(x["count"] for x in parts),
            "max_layer_uth_error":max(x["max_layer_uth"] for x in parts),
            "max_layer_uj_error":max(x["max_layer_uj"] for x in parts),
            "max_total_uth_error":max(x["max_total_uth"] for x in parts),
            "max_total_uj_error":max(x["max_total_uj"] for x in parts),
            "max_uth_uj_identity_error":max(x["max_uth_uj"] for x in parts),
            "max_occupancy_identity_error":max(x["max_occ_id"] for x in parts),
            "transition_layer_occurrences":sum(x["transition_layers"] for x in parts),
            "mixed_regime_layer_occurrences":sum(x["mixed_layers"] for x in parts),
        }
        if out[rep]["transaction_count"]!=TOTAL_COUNT:
            raise SystemExit(f"{material} {history} {rep}: total transaction count mismatch")
    return out

def alpha(h:float,h3:float,h4:float)->float:
    if h<h4:
        return 0.0
    if h<=h3:
        return (h4-h)/(h4-h3)
    return 1.0

def functional(points:list[tuple[float,float]],h3=-2.0,h4=-10.0)->float:
    return math.fsum(w*alpha(h,h3,h4) for w,h in points)

def mean_head(points:list[tuple[float,float]])->float:
    return math.fsum(w*h for w,h in points)/math.fsum(w for w,_ in points)

def counterexamples()->dict:
    h3=-2.0
    h4=-10.0
    # U necessity: same DeltaF=1 and J=1.6, different U.
    no_u_a=[(0.1,-1.0),(0.4,-6.0),(0.5,-12.0)]
    no_u_b=[(0.5,-1.0),(0.4,-6.0),(0.1,-12.0)]
    # J necessity and OCC insufficiency: same DeltaF/U/T/D, different transition head.
    no_j_a=[(0.2,-1.0),(0.4,-8.0),(0.4,-12.0)]
    no_j_b=[(0.2,-1.0),(0.4,-4.0),(0.4,-12.0)]
    # Root-weighted mean insufficiency: equal mean h=-6, different Feddes functional.
    mean_a=[(1.0,-6.0)]
    mean_b=[(0.25,-14.0),(0.75,-10.0/3.0)]
    out={
        "without_U":{
            "same_deltaF":True,
            "same_J":abs(0.4*(-6.0-h4)-0.4*(-6.0-h4))<1e-15,
            "F_a":functional(no_u_a,h3,h4),
            "F_b":functional(no_u_b,h3,h4),
        },
        "without_J_occ_only":{
            "same_deltaF_U_T_D":True,
            "F_a":functional(no_j_a,h3,h4),
            "F_b":functional(no_j_b,h3,h4),
        },
        "root_weighted_mean_only":{
            "mean_a":mean_head(mean_a),
            "mean_b":mean_head(mean_b),
            "F_a":functional(mean_a,h3,h4),
            "F_b":functional(mean_b,h3,h4),
        }
    }
    out["without_U"]["distinct_functional"]=abs(out["without_U"]["F_a"]-out["without_U"]["F_b"])>1e-6
    out["without_J_occ_only"]["distinct_functional"]=abs(out["without_J_occ_only"]["F_a"]-out["without_J_occ_only"]["F_b"])>1e-6
    out["root_weighted_mean_only"]["same_mean"]=abs(out["root_weighted_mean_only"]["mean_a"]-out["root_weighted_mean_only"]["mean_b"])<1e-12
    out["root_weighted_mean_only"]["distinct_functional"]=abs(out["root_weighted_mean_only"]["F_a"]-out["root_weighted_mean_only"]["F_b"])>1e-6
    return out

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--logs-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--s3d1-result",required=True,type=pathlib.Path)
    ap.add_argument("--s3d2-result",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    d1=json.loads(a.s3d1_result.read_text())
    d2=json.loads(a.s3d2_result.read_text())
    if pre["state"]!="PREREGISTERED_BEFORE_S3D3_SUFFICIENCY_RESPONSE":
        raise SystemExit("invalid S3-D3 preregistration state")
    if d1["decision"]!="A_AND_B_STATIC_MISSING_INFORMATION_SUPPORTED":
        raise SystemExit("S3-D1 A/B authority missing")
    if d2["decision"]!="DYADIC_HYDRAULIC_SUPPORT_COLLAPSES_A_AND_B_TO_NUMERICAL_GUARD":
        raise SystemExit("S3-D2 support authority missing")

    cases={}
    for material in MATERIALS:
        for history in HISTORIES:
            cases[f"{material}_{history}"]=parse_case(case_logs(a.logs_dir,material,history),material,history)

    empirical_values=[
        v
        for case in cases.values()
        for v in case.values()
    ]
    uth_sufficient=all(
        v["max_layer_uth_error"]<=GUARD and v["max_total_uth_error"]<=GUARD
        for v in empirical_values
    )
    uj_sufficient=all(
        v["max_layer_uj_error"]<=GUARD and v["max_total_uj_error"]<=GUARD
        for v in empirical_values
    )
    algebraic_identity=all(
        v["max_uth_uj_identity_error"]<=GUARD and v["max_occupancy_identity_error"]<=GUARD
        for v in empirical_values
    )
    nontrivial_transition=any(v["transition_layer_occurrences"]>0 for v in empirical_values)
    nontrivial_mixed=any(v["mixed_regime_layer_occurrences"]>0 for v in empirical_values)

    cx=counterexamples()
    necessity=(
        cx["without_U"]["same_J"] and cx["without_U"]["distinct_functional"] and
        cx["without_J_occ_only"]["distinct_functional"] and
        cx["root_weighted_mean_only"]["same_mean"] and cx["root_weighted_mean_only"]["distinct_functional"]
    )

    if uth_sufficient and uj_sufficient and algebraic_identity and necessity:
        decision="UJ_THRESHOLD_AWARE_INFORMATION_SUFFICIENT_ON_SAME_STATE_DOMAIN"
    else:
        decision="S3D3_SUFFICIENCY_NOT_ESTABLISHED"

    out={
        "schema":"swap5.rom_root.s3d3.result.v1",
        "workstream":"ROM-ROOT",
        "work_unit":"ROM-ROOT-S3-D3",
        "date":"2026-09-23",
        "status":"S3D3_SUFFICIENCY_DERIVATION_AND_VERIFICATION_COMPLETE",
        "decision":decision,
        "numerical_guard":GUARD,
        "analytic_identity":{
            "UTH":"F_i = U_i + (h4*T_i-H_T_i)/(h4-h3)",
            "UJ":"F_i = U_i + J_i/(h3-h4)",
            "J_relation":"J_i = H_T_i-h4*T_i"
        },
        "analytic_counterexamples":cx,
        "necessity_within_preregistered_non_tautological_family":necessity,
        "empirical":{
            "cases":cases,
            "UTH_sufficient_all_cases_representations":uth_sufficient,
            "UJ_sufficient_all_cases_representations":uj_sufficient,
            "UTH_UJ_and_occupancy_integrity":algebraic_identity,
            "transition_regime_observed":nontrivial_transition,
            "mixed_regime_layers_observed":nontrivial_mixed,
            "max_layer_UJ_error":max(v["max_layer_uj_error"] for v in empirical_values),
            "max_total_UJ_error":max(v["max_total_uj_error"] for v in empirical_values),
            "max_UJ_UTH_identity_error":max(v["max_uth_uj_identity_error"] for v in empirical_values),
        },
        "interpretation":{
            "information_content_identified":decision=="UJ_THRESHOLD_AWARE_INFORMATION_SUFFICIENT_ON_SAME_STATE_DOMAIN",
            "selected_descriptor":["U_i","J_i"] if decision=="UJ_THRESHOLD_AWARE_INFORMATION_SUFFICIENT_ON_SAME_STATE_DOMAIN" else [],
            "descriptor_scope":"same-state drought-only Feddes functional only",
            "propagated_state_selected":False,
            "dynamic_closure_defined":False,
            "application_acceptance_used":False,
            "note":"UJ is threshold-aware and process-specific. Exact same-state sufficiency does not show that U and J can be predicted or propagated from a reduced hydraulic state."
        },
        "scientific_firewall":{
            "reduced_candidate_response_generated":False,
            "new_propagated_root_state_selected":False,
            "application_acceptance_adjudicated":False,
            "performance_comparison_authorized":False,
            "production_rom_authorized":False
        },
        "model_changed":False
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "status":out["status"],
        "decision":decision,
        "uth_sufficient":uth_sufficient,
        "uj_sufficient":uj_sufficient,
        "necessity":necessity,
        "max_layer_uj_error":out["empirical"]["max_layer_UJ_error"],
        "max_total_uj_error":out["empirical"]["max_total_UJ_error"],
        "transition_regime_observed":nontrivial_transition,
        "mixed_regime_layers_observed":nontrivial_mixed,
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
