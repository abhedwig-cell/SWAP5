#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib

PURPOSE_INFO={
    "SURF_P":{
        "required_vertical_information":"Upper-column information resolving near-surface storage and the surface-to-80-cm propagation path.",
        "terminal_member":"S8"
    },
    "GW_LB":{
        "required_vertical_information":"Lower-column information with progressively finer support toward the 160-cm lower boundary.",
        "terminal_member":"G8"
    }
}

def load_optional(path:pathlib.Path|None):
    if path is None:
        return None
    return json.loads(path.read_text())

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--state-count-result",required=True,type=pathlib.Path)
    ap.add_argument("--same-partition-result",type=pathlib.Path)
    ap.add_argument("--purpose-map-output",required=True,type=pathlib.Path)
    ap.add_argument("--closeout-output",required=True,type=pathlib.Path)
    ap.add_argument("--markdown-output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    state=json.loads(a.state_count_result.read_text())
    same=load_optional(a.same_partition_result)
    triggers=state["same_partition_richards_triggers"]

    if triggers and same is None:
        raise SystemExit("same-partition result required because terminal diagnostic was triggered")
    if not triggers and same is not None and same.get("trigger_count",0)!=0:
        raise SystemExit("unexpected same-partition result without state-count trigger")

    same_decisions={} if same is None else same["decisions"]
    purposes={}
    case_outcomes={}
    any_closure=False
    any_unavailable=False
    all_finite=True

    for purpose in ("SURF_P","GW_LB"):
        materials={}
        for material in ("B01","B14"):
            d=state["decisions"][purpose][material]
            minimum=d["minimum_tested_member"]
            terminal=PURPOSE_INFO[purpose]["terminal_member"]
            terminal_case=state["cases"][purpose][material][terminal]
            diag=d["closure_diagnostic_disposition"]

            if minimum is not None:
                representation_status="REPRESENTATION_FRONTIER_IDENTIFIED"
                closure_class="CURRENT_LAYER_FACE_SUFFICIENT_WITHIN_FROZEN_NUMERICAL_COMPARATOR"
                remaining=(
                    "The minimum tested purpose-aligned Layer-ROM representation reaches the frozen "
                    "R512_T32 numerical-comparator envelope. This does not establish application acceptance "
                    "or a mathematical/universal minimum."
                )
                outcome="PURPOSE_SPECIFIC_FINITE_REPRESENTATION_FRONTIER_SUPPORTED"
            else:
                all_finite=False
                representation_status="REPRESENTATION_FRONTIER_NOT_REACHED"
                key=f"{purpose}/{material}"
                diagnostic_decision=same_decisions.get(key,diag)
                if diagnostic_decision=="CLOSURE_DEFICIT_SUPPORTED":
                    closure_class="CURRENT_LAYER_FACE_INSUFFICIENT_RELATIVE_TO_SAME_PARTITION_RICHARDS"
                    remaining=(
                        "The terminal aligned Layer-ROM misses the comparator while numerically qualified "
                        "same-partition Richards reaches it. A propagation/closure deficit is therefore "
                        "supported for this tested case, but no replacement closure is admitted."
                    )
                    outcome="CLOSURE_DEFICIT_BECOMES_IDENTIFIABLE"
                    any_closure=True
                elif diagnostic_decision=="REPRESENTATION_OR_RESOLUTION_UNRESOLVED":
                    closure_class="UNRESOLVED"
                    remaining=(
                        "The terminal aligned Layer-ROM and same-partition Richards both miss the frozen "
                        "comparator. Representation versus coarse spatial resolution remains unresolved."
                    )
                    outcome="REPRESENTATION_DIMENSION_REMAINS_LIMITING"
                elif diagnostic_decision in (
                    "SAME_PARTITION_RICHARDS_DIAGNOSTIC_UNAVAILABLE",
                    "SAME_PARTITION_RICHARDS_DIAGNOSTIC_UNAVAILABLE_PENDING_NUMERICAL_CANDIDATE_QUALIFICATION",
                ):
                    closure_class="UNRESOLVED_DIAGNOSTIC_UNAVAILABLE"
                    remaining=(
                        "Numerical qualification prevents a clean same-partition attribution. No closure "
                        "claim is authorized."
                    )
                    outcome="DIAGNOSTIC_REMAINS_UNAVAILABLE"
                    any_unavailable=True
                else:
                    closure_class="UNRESOLVED"
                    remaining=(
                        "The frozen ladder does not identify a sufficient representation and no stronger "
                        "closure attribution is available."
                    )
                    outcome="REPRESENTATION_DIMENSION_REMAINS_LIMITING"

            case_outcomes[f"{purpose}/{material}"]=outcome
            materials[material]={
                "minimum_tested_state_count":d["minimum_tested_state_count"],
                "minimum_tested_state_placement_cm":d["minimum_tested_state_placement_cm"],
                "representation_sufficiency_status":representation_status,
                "frontier_stability":d["frontier_stability"],
                "closure_diagnostic_disposition":diag,
                "required_closure_class":closure_class,
                "remaining_fidelity_limit":remaining,
                "scientific_outcome":outcome,
                "application_authority_status":"NOT_ADJUDICATED_IN_ROM_PURPOSE_P3",
                "terminal_tested_member":terminal,
                "terminal_candidate_status":terminal_case["status"],
                "terminal_representation_sufficiency":terminal_case["representation_sufficiency"]
            }

        purposes[purpose]={
            "required_vertical_information":PURPOSE_INFO[purpose]["required_vertical_information"],
            "purpose_summary":state["purpose_summary"][purpose],
            "materials":materials
        }

    if all_finite:
        close_status="P3_CLOSED_PURPOSE_SPECIFIC_FINITE_REPRESENTATION_FRONTIER_SUPPORTED"
    elif any_closure:
        close_status="P3_CLOSED_CLOSURE_DEFICIT_IDENTIFIED_FOR_ONE_OR_MORE_CASES"
    elif any_unavailable:
        close_status="P3_CLOSED_REPRESENTATION_FRONTIER_NOT_REACHED_DIAGNOSTIC_PARTLY_UNAVAILABLE"
    else:
        close_status="P3_CLOSED_REPRESENTATION_FRONTIER_NOT_REACHED"

    purpose_map={
        "schema":"swap5.rom-purpose.p3.purpose-map.v1",
        "workstream":"ROM-PURPOSE",
        "status":"P3_RESEARCH_MAP_PERSISTED",
        "scope":"Minimum tested purpose-aligned representation within the prospectively frozen S4/S6/S8 and G4/G6/G8 ladders; not a mathematical, universal, all-soil or application minimum.",
        "purposes":purposes,
        "application_authority_status":"NOT_ADJUDICATED_IN_ROM_PURPOSE_P3",
        "scientific_firewall":{
            "application_acceptance_adjudicated":False,
            "performance_claim_authorized":False,
            "production_rom_authorized":False,
            "new_closure_family_admitted":False,
            "reference_richards_replaced":False,
            "rossfast_changed":False,
            "production_groundwater_coupling_changed":False
        }
    }

    closeout={
        "schema":"swap5.rom-purpose.p3.closeout.v1",
        "workstream":"ROM-PURPOSE",
        "work_unit":"ROM-PURPOSE-P3",
        "status":close_status,
        "central_question":"How much purpose-aligned vertical state information is required before remaining error can be attributed to propagation or closure rather than insufficient vertical representation?",
        "state_count_result":str(a.state_count_result),
        "same_partition_result":str(a.same_partition_result) if a.same_partition_result else None,
        "case_outcomes":case_outcomes,
        "purpose_map":str(a.purpose_map_output),
        "terminal_dimension":int(pre["frozen_representations"]["terminal_dimension"]),
        "closure_workstream_recommendation":(
            "A separate prospectively governed closure workstream may be considered only for cases classified CLOSURE_DEFICIT_BECOMES_IDENTIFIABLE."
            if any_closure else
            "No new closure workstream is supported by P3 evidence."
        ),
        "claims_not_made":[
            "mathematical minimum",
            "universal minimum",
            "minimum for all soils or forcing",
            "application acceptance",
            "production-ROM admission",
            "performance or speedup",
            "replacement of Reference Richards"
        ],
        "scientific_firewall":{
            "p2_reopened":False,
            "state_boundaries_retuned_after_response":False,
            "closure_tuned":False,
            "weighted_general_score_used":False,
            "materials_aggregated_for_primary_admission":False,
            "application_acceptance_adjudicated":False,
            "production_rom_authorized":False
        }
    }

    lines=[
        "# ROM-PURPOSE P3 closeout",
        "",
        f"**Status:** {close_status}",
        "",
        "P3 tested purpose-specific state-count sufficiency before permitting closure attribution. "
        "The tested ladders were frozen prospectively at S4/S6/S8 for SURF_P and G4/G6/G8 for GW_LB.",
        "",
        "## Case outcomes",
        "",
        "| Purpose | Material | Minimum tested states | Representation status | Closure class | Scientific outcome |",
        "| --- | --- | ---: | --- | --- | --- |"
    ]
    for purpose in ("SURF_P","GW_LB"):
        for material in ("B01","B14"):
            m=purposes[purpose]["materials"][material]
            n=m["minimum_tested_state_count"]
            lines.append(
                f"| {purpose} | {material} | {n if n is not None else 'not reached'} | "
                f"{m['representation_sufficiency_status']} | {m['required_closure_class']} | "
                f"{m['scientific_outcome']} |"
            )
    lines += [
        "",
        "The result is a research qualification map. It does not establish an application tolerance, "
        "a universal state-count minimum, production admission or a speedup claim.",
        "",
        "A new closure family is not admitted by this closeout."
    ]

    for path,obj in ((a.purpose_map_output,purpose_map),(a.closeout_output,closeout)):
        path.parent.mkdir(parents=True,exist_ok=True)
        path.write_text(json.dumps(obj,indent=2,sort_keys=True)+"\n")
    a.markdown_output.parent.mkdir(parents=True,exist_ok=True)
    a.markdown_output.write_text("\n".join(lines)+"\n")
    print(json.dumps({"status":close_status,"case_outcomes":case_outcomes},sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
