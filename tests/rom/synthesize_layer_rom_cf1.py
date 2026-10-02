#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib
from collections import Counter

DIMS=(4,6,8)
MATERIALS=("B02","B05","B06","B11","B12","B16")
MEMBER={4:"L4",6:"L6",8:"R8"}

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--phase-b",required=True,type=pathlib.Path)
    ap.add_argument("--model-form",required=True,type=pathlib.Path)
    ap.add_argument("--cost1",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    phase=json.loads(a.phase_b.read_text())
    mf=json.loads(a.model_form.read_text())
    cost=json.loads(a.cost1.read_text())

    if pre["phase"]!="PREREGISTERED_BEFORE_COST1_RESULT_EXPOSURE_TO_SYNTHESIS":
        raise SystemExit("wrong CF1 preregistration phase")
    if phase["phase"]!="FIDELITY_FROZEN_BEFORE_NEW_COST_SCREEN":
        raise SystemExit("Phase-B fidelity is not frozen")
    if mf["decision"]!="B1HCP_CORRECTED_MODEL_FORM_DECOMPOSITION_COMPLETE":
        raise SystemExit("wrong model-form authority")
    if cost["decision"]!="COST1_SHARED_HOST_SIX_MATERIAL_SCREEN_COMPLETE":
        raise SystemExit("COST1 incomplete")
    if tuple(cost["materials"])!=MATERIALS or tuple(cost["dimensions"])!=DIMS:
        raise SystemExit("COST1 panel drift")

    by_dimension={}
    for d in DIMS:
        member=MEMBER[d]
        rows={}
        relation_counts=Counter()
        for m in MATERIALS:
            c=cost["by_dimension"][str(d)]["per_material"][m]
            relation=mf["groundwater_relations"][m][member]
            if c["fidelity_relation"]!=relation:
                raise SystemExit(f"fidelity relation drift {m} {member}")
            relation_counts[relation]+=1
            rows[m]={
                "groundwater_fidelity_relation":relation,
                "BASE_over_R16":c["BASE_over_R16"],
                "FINE_over_R16":c["FINE_over_R16"],
                "BASE_over_CoRichards":c["BASE_over_CoRichards"],
                "FINE_over_CoRichards":c["FINE_over_CoRichards"],
                "FINE_over_BASE":c["FINE_over_BASE"],
                "BASE_resolved_cheaper_than_R16":c["BASE_resolved_cheaper_than_R16"],
                "FINE_resolved_cheaper_than_R16":c["FINE_resolved_cheaper_than_R16"],
                "BASE_resolved_cheaper_than_CoRichards":c["BASE_resolved_cheaper_than_CoRichards"],
                "FINE_resolved_cheaper_than_CoRichards":c["FINE_resolved_cheaper_than_CoRichards"],
            }
        src=cost["by_dimension"][str(d)]
        by_dimension[str(d)]={
            "member":member,
            "per_material":rows,
            "groundwater_fidelity_relation_counts":dict(sorted(relation_counts.items())),
            "BASE_over_R16_spread":src["BASE_over_R16_spread"],
            "FINE_over_R16_spread":src["FINE_over_R16_spread"],
            "BASE_over_CoRichards_spread":src["BASE_over_CoRichards_spread"],
            "FINE_over_CoRichards_spread":src["FINE_over_CoRichards_spread"],
            "FINE_over_BASE_spread":src["FINE_over_BASE_spread"],
            "BASE_cheaper_than_R16_count":src["BASE_cheaper_than_R16_count"],
            "FINE_cheaper_than_R16_count":src["FINE_cheaper_than_R16_count"],
            "BASE_cheaper_than_CoRichards_count":src["BASE_cheaper_than_CoRichards_count"],
            "FINE_cheaper_than_CoRichards_count":src["FINE_cheaper_than_CoRichards_count"],
            "robust_reduction_signal_vs_R16":src["robust_reduction_signal_vs_R16"],
        }

    phase_front={row["id"]:row for row in phase["representation_frontier"] if row["id"] in ("L4","L6","R8")}
    combined=[]
    for d in DIMS:
        member=MEMBER[d]
        combined.append({
            "id":member,
            "dimension":d,
            "fidelity":phase_front[member],
            "cost_screen":by_dimension[str(d)],
        })

    robust=[MEMBER[d] for d in DIMS if by_dimension[str(d)]["robust_reduction_signal_vs_R16"]]
    result={
        "schema":"swap5.layer-rom.dimension-state-closure-fidelity-cost-curve.v1",
        "workstream":"F-ROM-LAYER",
        "work_unit":"LAYER-ROM-CF1",
        "decision":"LAYER_ROM_COST_FIDELITY_CURVE_COMPLETE",
        "authority":{
            "cf1_preregistration":"integration/f-rom/LAYER_ROM_CF1_PREREGISTRATION.json",
            "phase_b_fidelity":"integration/f-rom/LAYER_ROM_PHASE_B_DIMENSION_STATE_CLOSURE_FIDELITY_CURVE.json",
            "model_form":"integration/f-rom/LAYER_ROM_B1HCP_RESULT.json",
            "cost1":"integration/f-rom/LAYER_ROM_COST1_RESULT.json",
        },
        "frontier":combined,
        "robust_shared_host_reduction_signal_vs_R16":robust,
        "scientific_interpretation":[
            "State-information dimension and propagated-fidelity dimension remain distinct: the bounded B01 state-information lower bound is L3, while the retained practical fixed-head ladder is L4/L6/R8.",
            "The fourth scalar is valuable when localized near the active lower interface; one global first moment did not replace that local resolution.",
            "Useful dimension is material- and purpose-dependent. Cost results do not alter the frozen fidelity relation labels.",
            "Same-partition CoRichards separates ordinary coarse Richards discretization from Layer-ROM-specific closure/localization burden, but neither family is universally componentwise superior at equal dimension.",
            "Any robust CPU reduction reported here is shared-host implementation screening only. It is not an application acceptance, formal CPU baseline, portable speedup, or production-ROM admission."
        ],
        "minimum_dimension_statements":{
            "state_information_lower_bound_B01":"L3 in the bounded A1 cohort only.",
            "aggressive_candidate":"L4; material-dependent fidelity.",
            "intermediate_candidate":"L6; broadly stronger fidelity but B05 closure burden persists.",
            "broad_targeted_placement_candidate":"R8; six-material placement support, with B05 groundwater tradeoff.",
            "universal_application_minimum":"UNADJUDICATED"
        },
        "cost_claim_boundary":{
            "performance_class":"SHARED_HOST_SCREENING_ONLY",
            "formal_performance_claim":False,
            "portable_speedup_claim":False,
            "application_acceptance":False
        },
        "firewalls":pre["forbidden"],
        "production_rom_authorized":False
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":result["decision"],
        "robust_shared_host_reduction_signal_vs_R16":robust,
        "dimensions":{
            str(d):{
                "fidelity_relations":by_dimension[str(d)]["groundwater_fidelity_relation_counts"],
                "BASE_over_R16_spread":by_dimension[str(d)]["BASE_over_R16_spread"],
                "FINE_over_R16_spread":by_dimension[str(d)]["FINE_over_R16_spread"],
                "BASE_over_CoRichards_spread":by_dimension[str(d)]["BASE_over_CoRichards_spread"],
                "FINE_over_CoRichards_spread":by_dimension[str(d)]["FINE_over_CoRichards_spread"],
                "robust_reduction_signal_vs_R16":by_dimension[str(d)]["robust_reduction_signal_vs_R16"],
            } for d in DIMS
        }
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
