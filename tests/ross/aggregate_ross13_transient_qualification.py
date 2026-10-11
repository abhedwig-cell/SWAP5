from __future__ import annotations

import argparse
import json
from pathlib import Path

MATERIAL_GATE = "TRANSIENT_36_MATERIAL_D3R_QUALIFICATION_MATERIAL"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--contract", required=True, type=Path)
    parser.add_argument("--input-dir", action="append", required=True, type=Path)
    parser.add_argument("--stage", required=True, choices=("anchors", "all"))
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
            if record.get("gate") != MATERIAL_GATE or record.get("work_unit") != "F-ROSS13":
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
        "mode": record.get("qualification_mode"),
        "ross13_pass": bool(record.get("ross13_pass", False)),
        "base_case_count": record.get("base_case_count"),
        "piecewise_transition_route_count": record.get("piecewise_transition_route_count"),
        "inadmissible_transition_route_count": record.get("inadmissible_transition_route_count"),
        "table_fingerprint_matches_authority": record.get("table_fingerprint_matches_authority"),
        "historical_anchor_semantic_match": record.get("historical_anchor_semantic_match"),
        "failed_metrics": record.get("failed_metrics", []),
        "historical_anchor_semantic_mismatches": record.get("historical_anchor_semantic_mismatches", []),
        "max_finest_candidate_theta_span_normalized_error": record.get("finest_theta_span_error_max"),
        "max_finest_candidate_state_change_relative_error": record.get("finest_state_change_relative_error_max"),
        "minimum_observed_order": record.get("minimum_observed_order"),
        "median_observed_order": record.get("median_observed_order"),
        "max_abs_step_mass_residual_cm": record.get("max_abs_step_mass_residual_cm"),
        "max_abs_horizon_mass_residual_cm": record.get("max_abs_horizon_mass_residual_cm"),
    }


def main() -> None:
    args = parse_args()
    contract = json.loads(args.contract.read_text())
    records, duplicates = load_records(args.input_dir)

    anchors = list(contract["anchor_replay"]["materials"])
    extensions = list(contract["extension_qualification"]["materials"])
    expected = anchors if args.stage == "anchors" else anchors + extensions
    missing = [material for material in expected if material not in records]
    unexpected = sorted(material for material in records if material not in expected)

    matrix = [compact(records[m]) for m in expected if m in records]
    failed_materials = [row["material"] for row in matrix if not row["ross13_pass"]]
    anchor_semantic_failures = [
        row["material"]
        for row in matrix
        if row["material"] in anchors and row["historical_anchor_semantic_match"] is not True
    ]
    fingerprint_failures = [
        row["material"]
        for row in matrix
        if row["table_fingerprint_matches_authority"] is not True
    ]

    expected_case_total = (
        contract["anchor_replay"]["expected_total_base_cases"]
        if args.stage == "anchors"
        else contract["anchor_replay"]["expected_total_base_cases"]
        + contract["extension_qualification"]["expected_total_base_cases"]
    )
    observed_case_total = sum(int(row["base_case_count"] or 0) for row in matrix)
    case_total_match = observed_case_total == expected_case_total

    passed = not any(
        (
            missing,
            duplicates,
            unexpected,
            failed_materials,
            anchor_semantic_failures,
            fingerprint_failures,
        )
    ) and case_total_match

    result = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS13",
        "gate": "TRANSIENT_36_MATERIAL_D3R_QUALIFICATION_AGGREGATE",
        "stage": args.stage,
        "qualification_contract": args.contract.name,
        "historical_research_head": contract["immutable_authority"]["historical_research_head"],
        "expected_material_count": len(expected),
        "observed_material_count": len(matrix),
        "expected_base_case_total": expected_case_total,
        "observed_base_case_total": observed_case_total,
        "base_case_total_matches_contract": case_total_match,
        "missing_materials": missing,
        "duplicate_materials": duplicates,
        "unexpected_materials": unexpected,
        "failed_materials": failed_materials,
        "anchor_semantic_failures": anchor_semantic_failures,
        "fingerprint_failures": fingerprint_failures,
        "matrix": matrix,
        "production_implementation": False,
        "production_allowlist_changed": False,
        "pass": passed,
        "decision": (
            contract["exit"]["pass"]
            if passed and args.stage == "all"
            else "ANCHOR_REPLAY_QUALIFIED_EXTENSION_GATE_OPEN"
            if passed
            else contract["exit"]["fail"]
        ),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(
        json.dumps(
            {
                "stage": args.stage,
                "pass": passed,
                "observed_material_count": len(matrix),
                "observed_base_case_total": observed_case_total,
                "missing_materials": missing,
                "failed_materials": failed_materials,
                "anchor_semantic_failures": anchor_semantic_failures,
                "fingerprint_failures": fingerprint_failures,
                "decision": result["decision"],
            },
            sort_keys=True,
        ),
        flush=True,
    )
    raise SystemExit(0 if passed else 1)


if __name__ == "__main__":
    main()
