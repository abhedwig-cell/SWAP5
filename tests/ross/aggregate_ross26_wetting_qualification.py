from __future__ import annotations

import argparse
import json
import math
import re
from collections import Counter
from pathlib import Path

MATERIALS = tuple([f"B{i:02d}" for i in range(1,19)] + [f"O{i:02d}" for i in range(1,19)])
CASE_RE = re.compile(
    r"^F_ROSS26_CASE\|MATERIAL=(?P<material>[^|]+)\|SE=(?P<se>[^|]+)"
    r"\|TIER=(?P<tier>K2|K4|K8)\|LIN=(?P<lin>6|18|42)"
    r"\|TEMP=(?P<temp>[^|]+)\|THETA_NORM=(?P<theta>[^|]+)"
    r"\|STATE_CHANGE_REL=(?P<change>[^|]+)\|HEAD_INF_CM=(?P<head>[^|]+)"
    r"\|MASS=(?P<mass>[^|]+)\|EXACT_NODES=(?P<exact>\d+)$",
    re.MULTILINE,
)
TIER_STEPS = {
    "K2": {2,4},
    "K4": {4,8},
    "K8": {8,16},
}

def parse_args():
    p=argparse.ArgumentParser()
    p.add_argument("--input-root",required=True,type=Path)
    p.add_argument("--contract",required=True,type=Path)
    p.add_argument("--output",required=True,type=Path)
    return p.parse_args()

def main():
    a=parse_args()
    contract=json.loads(a.contract.read_text())
    if contract.get("work_unit")!="F-ROSS26":
        raise SystemExit("unexpected F-ROSS26 contract")

    metadata={}
    for path in sorted(a.input_root.rglob("metadata-*.json")):
        row=json.loads(path.read_text())
        if row.get("work_unit")=="F-ROSS26":
            m=row["material"]
            if m in metadata:
                raise SystemExit(f"duplicate metadata for {m}")
            metadata[m]=row

    outputs={}
    for path in sorted(a.input_root.rglob("fortran-*.txt")):
        text=path.read_text(errors="replace")
        matches=list(CASE_RE.finditer(text))
        if not matches:
            continue
        m=matches[0].group("material").strip()
        if m in outputs:
            raise SystemExit(f"duplicate fortran output for {m}")
        raw_cases=[]
        for match in matches:
            case={
                "material":m,
                "se":float(match.group("se")),
                "tier":match.group("tier"),
                "linear_solves":int(match.group("lin")),
                "temporal_indicator":float(match.group("temp")),
                "theta_span_normalized_error":float(match.group("theta")),
                "state_change_relative_error":float(match.group("change")),
                "head_inf_cm":float(match.group("head")),
                "mass_residual_cm":float(match.group("mass")),
                "exact_internal_node_endpoint_count":int(match.group("exact")),
            }
            raw_cases.append(case)
        if len(raw_cases)!=6:
            raise SystemExit(f"{m}: expected 6 O0/O2 case rows got {len(raw_cases)}")
        by_se={}
        for case in raw_cases:
            by_se.setdefault(case["se"],[]).append(case)
        if sorted(by_se) != [0.65,0.85,0.98]:
            raise SystemExit(f"{m}: unexpected Se rows {sorted(by_se)}")
        cases=[]
        for se in sorted(by_se):
            pair=by_se[se]
            if len(pair)!=2 or pair[0]!=pair[1]:
                raise SystemExit(f"{m}: O0/O2 parsed case mismatch at Se={se}")
            cases.append(pair[0])
        outputs[m]=cases

    missing_meta=[m for m in MATERIALS if m not in metadata]
    missing_output=[m for m in MATERIALS if m not in outputs]
    if missing_meta or missing_output:
        raise SystemExit(f"missing metadata={missing_meta} output={missing_output}")

    all_cases=[]
    tier_counts=Counter()
    seam_by_tier=Counter()
    seam_routes=0
    historical_inadmissible_relevant=0
    material_summary={}
    historical_route_fail_materials=[]

    for m in MATERIALS:
        md=metadata[m]
        cases=outputs[m]
        if len(cases)!=3:
            raise SystemExit(f"{m}: expected 3 cases got {len(cases)}")
        if not md.get("science_pass"):
            raise SystemExit(f"{m}: non-route science gate failed")
        if not md.get("table_fingerprint_matches_authority"):
            raise SystemExit(f"{m}: table fingerprint drift")
        if not md.get("production_kernel_qualification_pass"):
            raise SystemExit(f"{m}: production kernel qualification absent")
        if not md.get("production_kernel_o0_o2_identical"):
            raise SystemExit(f"{m}: O0/O2 drift")

        if not md.get("historical_route_policy_pass",False):
            historical_route_fail_materials.append(m)

        route_rows=md.get("route_rows",[])
        per_material_seams=0
        per_material_hist_inad=0
        for case in cases:
            if not math.isfinite(case["temporal_indicator"]) or case["temporal_indicator"]>1.0:
                raise SystemExit(f"{m}: temporal gate")
            if case["theta_span_normalized_error"]>1e-5:
                raise SystemExit(f"{m}: theta reference gate")
            if case["state_change_relative_error"]>0.005:
                raise SystemExit(f"{m}: state-change reference gate")
            if abs(case["mass_residual_cm"])>1e-12:
                raise SystemExit(f"{m}: mass gate")
            if case["exact_internal_node_endpoint_count"]!=0:
                raise SystemExit(f"{m}: exact-node endpoint gate")
            tier_counts[case["tier"]]+=1

            relevant_steps=TIER_STEPS[case["tier"]]
            matched=[
                r for r in route_rows
                if abs(float(r["effective_saturation"])-case["se"])<1e-12
                and int(r["step_count"]) in relevant_steps
            ]
            per_material_seams += len(matched)
            seam_routes += len(matched)
            seam_by_tier[case["tier"]] += len(matched)
            bad=sum(not bool(r["admissible"]) for r in matched)
            per_material_hist_inad += bad
            historical_inadmissible_relevant += bad

            case["selected_tier_seam_transition_routes"]=len(matched)
            case["selected_tier_historical_f_r1_inadmissible_routes"]=bad
            case["selected_tier_max_transitioning_components"]=max(
                (int(r["transitioning_component_count"]) for r in matched), default=0
            )
            case["selected_tier_max_abs_cell_displacement"]=max(
                (int(r["max_abs_cell_displacement"]) for r in matched), default=0
            )
            all_cases.append(case)

        material_summary[m]={
            "historical_route_policy_pass":bool(md.get("historical_route_policy_pass",False)),
            "historical_total_transition_routes":int(md.get("piecewise_transition_route_count") or 0),
            "historical_total_inadmissible_routes":int(md.get("inadmissible_transition_route_count") or 0),
            "selected_tier_seam_transition_routes":per_material_seams,
            "selected_tier_historical_f_r1_inadmissible_routes":per_material_hist_inad,
            "tiers":Counter(c["tier"] for c in cases),
        }
        material_summary[m]["tiers"]=dict(material_summary[m]["tiers"])

    if len(all_cases)!=108:
        raise SystemExit(f"expected 108 cases got {len(all_cases)}")

    result={
        "schema":"swap5.f-ross26.tiered-wetting-seam-qualification-result.v1",
        "workunit":"F-ROSS26",
        "phase":"QUALIFIED_RESEARCH_ONLY",
        "contract":a.contract.name,
        "attempted_cases":108,
        "material_count":36,
        "all_nonroute_science_gates_pass":True,
        "production_source_mutation":False,
        "model_binding_widened":False,
        "tier_distribution":dict(sorted(tier_counts.items())),
        "maxima":{
            "temporal_indicator":max(c["temporal_indicator"] for c in all_cases),
            "theta_span_normalized_error":max(c["theta_span_normalized_error"] for c in all_cases),
            "state_change_relative_error":max(c["state_change_relative_error"] for c in all_cases),
            "head_inf_cm":max(c["head_inf_cm"] for c in all_cases),
            "abs_mass_residual_cm":max(abs(c["mass_residual_cm"]) for c in all_cases),
            "exact_internal_node_endpoint_count":sum(c["exact_internal_node_endpoint_count"] for c in all_cases),
        },
        "historical_f_r1_context":{
            "materials_failing_historical_route_policy":historical_route_fail_materials,
            "material_fail_count":len(historical_route_fail_materials),
            "historical_policy_is_admission_gate_here":False,
        },
        "selected_tier_seam_characterization":{
            "transition_route_count":seam_routes,
            "historical_f_r1_inadmissible_route_count":historical_inadmissible_relevant,
            "transition_routes_by_selected_tier":dict(sorted(seam_by_tier.items())),
            "interpretation":"These counts characterize seam crossings on the research reproduction of the selected tier trajectories. They are diagnostic in F-ROSS26 and do not define tangent validity across a seam."
        },
        "material_summary":material_summary,
        "cases":all_cases,
        "firewall":{
            "production_source_changed":False,
            "model_binding_changed":False,
            "reference_changed":False,
            "table_assets_changed":False,
            "temporal_threshold_changed":False,
            "tier_selection_changed":False,
            "tolerances_retuned":False,
        },
        "verdict":"QUALIFIED_RESEARCH_EVIDENCE_CURRENT_TIERED_ROSSFAST_WETTING_STATE_SOLVER_VALID_WITH_SEAM_CROSSINGS",
        "production_admission_effect":"NONE",
        "tangent_nonclaim":"No unique cross-node derivative or seam-crossing interface sensitivity is qualified.",
        "next_permitted_action":"A separate governed admission workunit may evaluate the one-sided WETTING model-binding extension using this state-solver evidence while preserving the tangent/sensitivity nonclaim."
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "attempted_cases":108,
        "tier_distribution":result["tier_distribution"],
        "maxima":result["maxima"],
        "historical_route_fail_materials":len(historical_route_fail_materials),
        "selected_tier_seam_routes":seam_routes,
        "selected_tier_historical_inadmissible":historical_inadmissible_relevant,
        "verdict":result["verdict"],
    },sort_keys=True))

if __name__=="__main__":
    main()
