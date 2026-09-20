#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib
from collections import Counter

MATERIALS=("B02","B05","B06","B11","B12","B16")
MEMBERS=("L4","L6","R8")
GW=(
    "storage_rms_cm",
    "cumulative_bottom_rms_cm",
    "qavg_rms_cm_per_day",
    "qavg_sign_mismatch",
    "qend_rms_cm_per_day",
    "qend_sign_mismatch",
    "max_abs_final_cumulative_bottom_error_cm",
)
CONTINUOUS=(
    "storage_rms_cm",
    "cumulative_bottom_rms_cm",
    "qavg_rms_cm_per_day",
    "qend_rms_cm_per_day",
    "max_abs_final_cumulative_bottom_error_cm",
)

def no_worse(a:dict,b:dict,tol:float)->bool:
    for k in GW:
        if "sign_mismatch" in k:
            if int(a[k])>int(b[k]):
                return False
        elif float(a[k])>float(b[k])+tol:
            return False
    return True

def strict_better(a:dict,b:dict,tol:float)->bool:
    for k in GW:
        if "sign_mismatch" in k:
            if int(a[k])<int(b[k]):
                return True
        elif float(a[k])<float(b[k])-tol:
            return True
    return False

def relation(lr:dict,cor:dict,tol:float)->str:
    equivalent=True
    for k in GW:
        if "sign_mismatch" in k:
            if int(lr[k])!=int(cor[k]):
                equivalent=False
                break
        elif abs(float(lr[k])-float(cor[k]))>tol:
            equivalent=False
            break
    if equivalent:
        return "NUMERICALLY_EQUIVALENT"
    cor_nw=no_worse(cor,lr,tol)
    lr_nw=no_worse(lr,cor,tol)
    if cor_nw and strict_better(cor,lr,tol):
        return "COR_COMPONENTWISE_NO_WORSE"
    if lr_nw and strict_better(lr,cor,tol):
        return "LAYER_ROM_COMPONENTWISE_NO_WORSE"
    return "TRADEOFF"

def profile_relation(lr:dict,cor:dict,tol:float)->str:
    a=float(lr["mapped_theta_rms"])
    b=float(cor["mapped_theta_rms"])
    if abs(a-b)<=tol:
        return "NUMERICALLY_EQUIVALENT"
    return "LayerROM" if a<b else "CoRichards"

def component_ratios(lr:dict,cor:dict)->dict:
    out={}
    for k in CONTINUOUS:
        den=float(cor[k])
        out[k]=None if den==0.0 else float(lr[k])/den
    out["qavg_sign_mismatch_delta_LayerROM_minus_CoRichards"]=int(lr["qavg_sign_mismatch"])-int(cor["qavg_sign_mismatch"])
    out["qend_sign_mismatch_delta_LayerROM_minus_CoRichards"]=int(lr["qend_sign_mismatch"])-int(cor["qend_sign_mismatch"])
    return out

def monotonic(route:dict,tol:float)->dict:
    l4,l6,r8=route["L4"],route["L6"],route["R8"]
    return {
        "L4_to_L6_componentwise_nonworse":no_worse(l6,l4,tol),
        "L6_to_R8_componentwise_nonworse":no_worse(r8,l6,tol),
        "full_ladder_componentwise_nonworse":no_worse(l6,l4,tol) and no_worse(r8,l6,tol),
    }

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--cor-binding",required=True,type=pathlib.Path)
    ap.add_argument("--layerrom-result",required=True,type=pathlib.Path)
    ap.add_argument("--old-diagnostic",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    corb=json.loads(a.cor_binding.read_text())
    lrr=json.loads(a.layerrom_result.read_text())
    old=json.loads(a.old_diagnostic.read_text())

    if pre["phase"]!="PREREGISTERED_BEFORE_CORRECTED_FULL_PANEL_RELATION_RECOMPUTATION":
        raise SystemExit("wrong B1HCP preregistration phase")
    if pre["cohort"]["cell_count"]!=18 or not corb["all_temporal_cells_supported"]:
        raise SystemExit("CoRichards full-panel temporal authority incomplete")
    if lrr["decision"]!="B1HCMR_CORRECTED_CONTINUOUS_TIME_REDUCED_LADDER_REBASED":
        raise SystemExit("corrected Layer-ROM continuous-time authority missing")
    if lrr["semantic_repair"]["supersedes"]!="LAYER-ROM-B1HCM for continuous-time QEND-based fidelity claims":
        raise SystemExit("B1HCMR supersession contract missing")

    tol=float(pre["relation_rule"]["tolerance"])
    vectors={}
    relations={}
    profiles={}
    ratios={}
    dimension_order={"LayerROM":{},"CoRichards":{}}
    for m in MATERIALS:
        vectors[m]={}
        relations[m]={}
        profiles[m]={}
        ratios[m]={}
        lr_route={}
        cor_route={}
        for member in MEMBERS:
            lr=dict(lrr["selected_Rstar_fidelity_vectors"][m][member])
            cor=dict(corb["cells"][m][member]["CoRichards"])
            missing_lr=[k for k in GW+("mapped_theta_rms",) if k not in lr]
            missing_cor=[k for k in GW+("mapped_theta_rms",) if k not in cor]
            if missing_lr or missing_cor:
                raise SystemExit(f"{m}:{member} vector schema drift lr={missing_lr} cor={missing_cor}")
            rel=relation(lr,cor,tol)
            pro=profile_relation(lr,cor,tol)
            vectors[m][member]={"LayerROM":lr,"CoRichards":cor}
            relations[m][member]=rel
            profiles[m][member]=pro
            ratios[m][member]=component_ratios(lr,cor)
            lr_route[member]=lr
            cor_route[member]=cor
        dimension_order["LayerROM"][m]=monotonic(lr_route,tol)
        dimension_order["CoRichards"][m]=monotonic(cor_route,tol)

    relation_counts={
        member:dict(Counter(relations[m][member] for m in MATERIALS))
        for member in MEMBERS
    }
    profile_counts={
        member:dict(Counter(profiles[m][member] for m in MATERIALS))
        for member in MEMBERS
    }

    old_rel=old["original_run_relation_diagnostics"]["groundwater_relations"]
    changed=[]
    for m in MATERIALS:
        for member in MEMBERS:
            before=old_rel[m][member]
            after=relations[m][member]
            if before!=after:
                changed.append({"cell":f"{m}:{member}","before":before,"after":after})

    cor_burden=[
        f"{m}:{member}" for m in MATERIALS for member in MEMBERS
        if relations[m][member]=="COR_COMPONENTWISE_NO_WORSE"
    ]
    layer_adv=[
        f"{m}:{member}" for m in MATERIALS for member in MEMBERS
        if relations[m][member]=="LAYER_ROM_COMPONENTWISE_NO_WORSE"
    ]
    tradeoffs=[
        f"{m}:{member}" for m in MATERIALS for member in MEMBERS
        if relations[m][member]=="TRADEOFF"
    ]
    equivalents=[
        f"{m}:{member}" for m in MATERIALS for member in MEMBERS
        if relations[m][member]=="NUMERICALLY_EQUIVALENT"
    ]

    result={
        "schema":"swap5.layer-rom.phase-b1hcp.result.v1",
        "workstream":"F-ROM-LAYER",
        "work_unit":"LAYER-ROM-B1HCP",
        "decision":pre["decisions"]["complete"],
        "relation_counts_by_dimension":relation_counts,
        "groundwater_relations":relations,
        "profile_lower_error_route_counts":profile_counts,
        "profile_relations":profiles,
        "dimension_order":dimension_order,
        "component_ratios_LayerROM_over_CoRichards":ratios,
        "corrected_QEND_relation_changes_from_B1HCO_original_diagnostic":changed,
        "bounded_attribution_cells":{
            "CoRichards_componentwise_no_worse":cor_burden,
            "LayerROM_componentwise_no_worse":layer_adv,
            "tradeoff":tradeoffs,
            "numerically_equivalent":equivalents,
        },
        "continuous_time_vectors":vectors,
        "integrity":{
            "pass":True,
            "cell_count":18,
            "all_CoRichards_temporal_cells_supported":True,
            "corrected_LayerROM_QEND":True,
            "new_model_response_generated":False,
            "hydrological_model_changed":False,
        },
        "scientific_adjudication":[
            "The comparison is now temporally controlled on both routes and uses corrected terminal-Darcy QEND for Layer-ROM.",
            "A CoRichards componentwise advantage is bounded evidence for Layer-ROM-specific closure/localization burden beyond same-partition Richards spatial discretization; it is not an additive closure-error estimate.",
            "A Layer-ROM componentwise advantage shows that same-partition coarse Richards is not a universal lower-error bound and may include error compensation; it is not proof of greater physical fidelity.",
            "Profile fidelity remains a separate purpose axis from groundwater exchange.",
            "No weighted score, application threshold, performance claim or production admission is inferred."
        ],
        "application_acceptance_adjudicated":False,
        "performance_measurement_performed":False,
        "production_rom_authorized":False,
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":result["decision"],
        "relation_counts_by_dimension":relation_counts,
        "groundwater_relations":relations,
        "profile_lower_error_route_counts":profile_counts,
        "corrected_QEND_relation_changes":changed,
        "dimension_order":dimension_order,
        "bounded_attribution_cells":result["bounded_attribution_cells"],
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
