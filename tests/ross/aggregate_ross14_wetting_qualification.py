from __future__ import annotations

import argparse
import json
from pathlib import Path

MATERIAL_GATE = "WETTING_TOP_BOUNDARY_36_MATERIAL_TRANSIENT_QUALIFICATION_MATERIAL"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--contract", required=True, type=Path)
    parser.add_argument("--input-dir", action="append", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def load_records(input_dirs: list[Path]) -> tuple[dict[str, dict], list[str]]:
    records: dict[str, dict] = {}
    duplicates: list[str] = []
    for root in input_dirs:
        if not root.exists():
            continue
        for path in sorted(root.rglob("*.json")):
            try:
                record = json.loads(path.read_text())
            except Exception:
                continue
            if record.get("gate") != MATERIAL_GATE or record.get("work_unit") != "F-ROSS14":
                continue
            material = record.get("material")
            if not material:
                continue
            if material in records:
                duplicates.append(material)
            records[material] = record
    return records, sorted(set(duplicates))


def compact(record: dict) -> dict:
    return {
        "material": record.get("material"),
        "ross14_pass": bool(record.get("ross14_pass", False)),
        "base_case_count": record.get("base_case_count"),
        "piecewise_transition_route_count": record.get("piecewise_transition_route_count"),
        "inadmissible_transition_route_count": record.get("inadmissible_transition_route_count"),
        "table_fingerprint_matches_authority": record.get("table_fingerprint_matches_authority"),
        "forcing_mapping_matches_contract": record.get("forcing_mapping_matches_contract"),
        "failed_metrics": record.get("failed_metrics", []),
        "max_finest_candidate_theta_span_normalized_error": record.get("finest_theta_span_error_max"),
        "max_finest_candidate_state_change_relative_error": record.get("finest_state_change_relative_error_max"),
        "minimum_observed_order": record.get("minimum_observed_order"),
        "median_observed_order": record.get("median_observed_order"),
        "max_abs_step_mass_residual_cm": record.get("max_abs_step_mass_residual_cm"),
        "max_abs_horizon_mass_residual_cm": record.get("max_abs_horizon_mass_residual_cm"),
        "candidate_domain_failure_count": record.get("candidate_domain_failure_count"),
        "candidate_envelope_failure_count": record.get("candidate_envelope_failure_count"),
        "candidate_nonfinite_count": record.get("candidate_nonfinite_count"),
        "reference_nonfinite_count": record.get("reference_nonfinite_count"),
    }


def main() -> None:
    args = parse_args()
    contract = json.loads(args.contract.read_text())
    records, duplicates = load_records(args.input_dir)

    expected = list(contract["wetting_qualification"]["materials"])
    missing = [m for m in expected if m not in records]
    unexpected = sorted(m for m in records if m not in expected)
    matrix = [compact(records[m]) for m in expected if m in records]

    failed_materials = [row["material"] for row in matrix if not row["ross14_pass"]]
    fingerprint_failures = [
        row["material"] for row in matrix
        if row["table_fingerprint_matches_authority"] is not True
    ]
    forcing_mapping_failures = [
        row["material"] for row in matrix
        if row["forcing_mapping_matches_contract"] is not True
    ]

    expected_cases = int(contract["wetting_qualification"]["expected_total_base_cases"])
    observed_cases = sum(int(row["base_case_count"] or 0) for row in matrix)
    case_total_match = observed_cases == expected_cases

    passed = not any(
        (
            missing,
            duplicates,
            unexpected,
            failed_materials,
            fingerprint_failures,
            forcing_mapping_failures,
        )
    ) and case_total_match

    def max_row(key: str):
        available = [row for row in matrix if row.get(key) is not None]
        if not available:
            return None
        row = max(available, key=lambda item: float(item[key]))
        return {"material": row["material"], "value": row[key]}

    def min_row(key: str):
        available = [row for row in matrix if row.get(key) is not None]
        if not available:
            return None
        row = min(available, key=lambda item: float(item[key]))
        return {"material": row["material"], "value": row[key]}

    result = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS14",
        "gate": "WETTING_TOP_BOUNDARY_36_MATERIAL_TRANSIENT_QUALIFICATION_AGGREGATE",
        "qualification_contract": args.contract.name,
        "historical_research_head": contract["historical_authority"]["research_head"],
        "expected_material_count": len(expected),
        "observed_material_count": len(matrix),
        "expected_base_case_total": expected_cases,
        "observed_base_case_total": observed_cases,
        "base_case_total_matches_contract": case_total_match,
        "missing_materials": missing,
        "duplicate_materials": duplicates,
        "unexpected_materials": unexpected,
        "failed_materials": failed_materials,
        "fingerprint_failures": fingerprint_failures,
        "forcing_mapping_failures": forcing_mapping_failures,
        "piecewise_transition_materials": [
            {"material": row["material"], "route_count": row["piecewise_transition_route_count"]}
            for row in matrix
            if int(row.get("piecewise_transition_route_count") or 0) > 0
        ],
        "inadmissible_transition_route_count": sum(
            int(row.get("inadmissible_transition_route_count") or 0) for row in matrix
        ),
        "worst_case_diagnostics": {
            "max_abs_horizon_mass_residual_cm": max_row("max_abs_horizon_mass_residual_cm"),
            "max_abs_step_mass_residual_cm": max_row("max_abs_step_mass_residual_cm"),
            "max_finest_candidate_state_change_relative_error": max_row(
                "max_finest_candidate_state_change_relative_error"
            ),
            "max_finest_candidate_theta_span_normalized_error": max_row(
                "max_finest_candidate_theta_span_normalized_error"
            ),
            "minimum_observed_order": min_row("minimum_observed_order"),
            "minimum_median_observed_order": min_row("median_observed_order"),
        },
        "matrix": matrix,
        "production_implementation": False,
        "production_model_binding_changed": False,
        "pass": passed,
        "decision": contract["exit"]["pass"] if passed else contract["exit"]["fail"],
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(
        json.dumps(
            {
                "pass": passed,
                "observed_material_count": len(matrix),
                "observed_base_case_total": observed_cases,
                "failed_materials": failed_materials,
                "fingerprint_failures": fingerprint_failures,
                "forcing_mapping_failures": forcing_mapping_failures,
                "inadmissible_transition_route_count": result["inadmissible_transition_route_count"],
                "decision": result["decision"],
            },
            sort_keys=True,
        ),
        flush=True,
    )
    raise SystemExit(0 if passed else 1)


if __name__ == "__main__":
    main()
