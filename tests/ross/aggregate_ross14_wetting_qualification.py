from __future__ import annotations

import argparse
import json
from pathlib import Path

MATERIALS = (
    "B01","B02","B03","B04","B05","B06","B07","B08","B09",
    "B10","B11","B12","B13","B14","B15","B16","B17","B18",
    "O01","O02","O03","O04","O05","O06","O07","O08","O09",
    "O10","O11","O12","O13","O14","O15","O16","O17","O18",
)


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--input-root", required=True, type=Path)
    p.add_argument("--contract", required=True, type=Path)
    p.add_argument("--output", required=True, type=Path)
    return p.parse_args()


def max_row(rows, key):
    valid = [r for r in rows if r.get(key) is not None]
    if not valid:
        return {"material": None, "value": None}
    row = max(valid, key=lambda r: float(r[key]))
    return {"material": row["material"], "value": float(row[key])}


def min_row(rows, key):
    valid = [r for r in rows if r.get(key) is not None]
    if not valid:
        return {"material": None, "value": None}
    row = min(valid, key=lambda r: float(r[key]))
    return {"material": row["material"], "value": float(row[key])}


def main():
    a = parse_args()
    contract = json.loads(a.contract.read_text())
    if contract["work_unit"] != "F-ROSS14":
        raise SystemExit("unexpected F-ROSS14 contract")

    rows = []
    for path in sorted(a.input_root.rglob("metadata-*.json")):
        row = json.loads(path.read_text())
        if row.get("work_unit") == "F-ROSS14":
            rows.append(row)

    by_material = {}
    duplicates = []
    for row in rows:
        material = row.get("material")
        if material in by_material:
            duplicates.append(material)
        else:
            by_material[material] = row

    missing = [m for m in MATERIALS if m not in by_material]
    unexpected = sorted(m for m in by_material if m not in MATERIALS)

    ordered = [by_material[m] for m in MATERIALS if m in by_material]
    failed_materials = sorted(
        r["material"] for r in ordered
        if not bool(r.get("ross14_material_pass", False))
    )
    fingerprint_failures = sorted(
        r["material"] for r in ordered
        if not bool(r.get("table_fingerprint_matches_authority", False))
    )
    science_failures = sorted(
        r["material"] for r in ordered
        if not bool(r.get("science_pass", False))
    )
    kernel_failures = sorted(
        r["material"] for r in ordered
        if not bool(r.get("production_kernel_equivalence_pass", False))
    )
    o0_o2_failures = sorted(
        r["material"] for r in ordered
        if not bool(r.get("production_kernel_o0_o2_identical", False))
    )
    route_failures = sorted(
        r["material"] for r in ordered
        if int(r.get("inadmissible_transition_route_count") or 0) != 0
    )
    exact_node_failures = sorted(
        r["material"] for r in ordered
        if int(r.get("exact_node_endpoint_count") or 0) != 0
    )
    domain_failures = sorted(
        r["material"] for r in ordered
        if int(r.get("candidate_domain_failure_count") or 0) != 0
        or int(r.get("candidate_envelope_failure_count") or 0) != 0
        or int(r.get("candidate_nonfinite_count") or 0) != 0
        or int(r.get("reference_nonfinite_count") or 0) != 0
    )

    science_cases = sum(int(r.get("science_case_count") or 0) for r in ordered)
    kernel_cases = sum(int(r.get("kernel_fixture_case_count") or 0) for r in ordered)
    transition_routes = sum(int(r.get("piecewise_transition_route_count") or 0) for r in ordered)

    material_count_ok = (
        len(ordered) == 36 and not missing and not duplicates and not unexpected
    )
    case_counts_ok = science_cases == 108 and kernel_cases == 972
    pass_all = (
        material_count_ok
        and case_counts_ok
        and not failed_materials
        and not fingerprint_failures
        and not science_failures
        and not kernel_failures
        and not o0_o2_failures
        and not route_failures
        and not exact_node_failures
        and not domain_failures
    )

    result = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS14",
        "gate": "TOP_WETTING_FORCING_ENVELOPE_36_MATERIAL_QUALIFICATION_AGGREGATE",
        "qualification_contract": a.contract.name,
        "production_implementation": False,
        "target_internal_top_flux_over_initial_K": -0.025,
        "target_internal_bottom_up_flux_over_initial_K": 0.011,
        "aggregate": {
            "pass": pass_all,
            "decision": (
                "WETTING_TOP_FORCING_36_MATERIAL_PREPRODUCTION_QUALIFIED_FOR_ONE_SIDED_BINDING_EXTENSION"
                if pass_all else
                "ONE_SIDED_BINDING_EXTENSION_REMAINS_BLOCKED"
            ),
            "expected_material_count": 36,
            "observed_material_count": len(ordered),
            "missing_materials": missing,
            "duplicate_materials": sorted(set(duplicates)),
            "unexpected_materials": unexpected,
            "expected_science_case_total": 108,
            "observed_science_case_total": science_cases,
            "expected_kernel_case_total": 972,
            "observed_kernel_case_total": kernel_cases,
            "failed_materials": failed_materials,
            "fingerprint_failures": fingerprint_failures,
            "science_failures": science_failures,
            "production_kernel_equivalence_failures": kernel_failures,
            "o0_o2_failures": o0_o2_failures,
            "inadmissible_piecewise_route_materials": route_failures,
            "exact_internal_node_endpoint_materials": exact_node_failures,
            "domain_or_nonfinite_failure_materials": domain_failures,
            "piecewise_transition_route_count": transition_routes,
        },
        "worst_case_diagnostics": {
            "max_reference_self_theta_span_normalized": max_row(ordered, "reference_self_max"),
            "max_finest_candidate_theta_span_normalized_error": max_row(ordered, "finest_theta_span_error_max"),
            "max_finest_candidate_state_change_relative_error": max_row(ordered, "finest_state_change_relative_error_max"),
            "minimum_observed_order": min_row(ordered, "minimum_observed_order"),
            "minimum_material_median_observed_order": min_row(ordered, "median_observed_order"),
            "max_abs_step_mass_residual_cm": max_row(ordered, "max_abs_step_mass_residual_cm"),
            "max_abs_horizon_mass_residual_cm": max_row(ordered, "max_abs_horizon_mass_residual_cm"),
            "max_kernel_component_global_mass_residual_cm": max_row(ordered, "max_kernel_component_global_mass_residual_cm"),
            "max_kernel_component_cell_mass_residual_cm": max_row(ordered, "max_kernel_component_cell_mass_residual_cm"),
        },
        "materials": {
            m: {
                "science_pass": bool(by_material[m].get("science_pass", False)),
                "kernel_equivalence_pass": bool(by_material[m].get("production_kernel_equivalence_pass", False)),
                "fingerprint_match": bool(by_material[m].get("table_fingerprint_matches_authority", False)),
                "science_case_count": int(by_material[m].get("science_case_count") or 0),
                "kernel_case_count": int(by_material[m].get("kernel_fixture_case_count") or 0),
                "piecewise_transition_route_count": int(by_material[m].get("piecewise_transition_route_count") or 0),
                "kernel_o0_o2_sha256": by_material[m].get("production_kernel_o0_o2_sha256"),
            }
            for m in MATERIALS if m in by_material
        },
        "firewall": {
            "production_source_mutated": False,
            "model_binding_mutated": False,
            "table_kernel_mutated": False,
            "table_provider_mutated": False,
            "execution_policy_mutated": False,
            "criteria_retuned": False,
        },
        "verdict": (
            "QUALIFIED_PREPRODUCTION_READY_FOR_ONE_SIDED_BINDING_EXTENSION"
            if pass_all else
            "BLOCKED_PREPRODUCTION_QUALIFICATION_FAILED"
        ),
        "next_permitted_action": (
            "Implement only the preregistered one-sided top-lower binding extension, then qualify its exact production postimage."
            if pass_all else
            "Do not mutate production source. Classify the failing material, science, fingerprint, route or kernel-equivalence evidence."
        ),
    }

    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "pass": pass_all,
        "observed_material_count": len(ordered),
        "science_cases": science_cases,
        "kernel_cases": kernel_cases,
        "failed_materials": failed_materials,
        "transition_routes": transition_routes,
        "verdict": result["verdict"],
    }, sort_keys=True))
    raise SystemExit(0 if pass_all else 1)


if __name__ == "__main__":
    main()
