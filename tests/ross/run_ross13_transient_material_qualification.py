from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

ANCHORS = ("B01", "B12", "O01", "O05", "O14", "O18")
EXTENSIONS = (
    "B02", "B03", "B04", "B05", "B06", "B07", "B08", "B09", "B10", "B11",
    "B13", "B14", "B15", "B16", "B17", "B18",
    "O02", "O03", "O04", "O06", "O07", "O08", "O09", "O10", "O11", "O12",
    "O13", "O15", "O16", "O17",
)
CONTRACT_GATE = "TRANSIENT_36_MATERIAL_D3R_QUALIFICATION"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--research-root", required=True, type=Path)
    parser.add_argument("--contract", required=True, type=Path)
    parser.add_argument("--fingerprint-authority", required=True, type=Path)
    parser.add_argument("--mode", required=True, choices=("anchor", "extension"))
    parser.add_argument("--material", required=True)
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def import_historical_r1(research_root: Path):
    research_scripts = research_root / "experiments" / "ross"
    sys.path.insert(0, str(research_scripts))
    import run_ross01_gate_f_timestep_convergence as gate_f
    import run_ross01_gate_f_r1_piecewise_timestep_route as r1
    return gate_f, r1


def expected_anchor_row(contract: dict, material: str) -> dict:
    return next(
        row
        for row in contract["anchor_replay"]["historical_expected_matrix"]
        if row["material"] == material
    )


def semantic_match(result: dict, expected: dict) -> tuple[bool, list[str]]:
    mismatches = []
    for key, value in expected.items():
        if key == "material":
            continue
        if result.get(key) != value:
            mismatches.append(key)
    return (not mismatches), mismatches


def main() -> None:
    args = parse_args()
    contract = json.loads(args.contract.read_text())
    fingerprints = json.loads(args.fingerprint_authority.read_text())
    if contract["gate"] != CONTRACT_GATE:
        raise SystemExit("unexpected qualification contract")
    if not fingerprints.get("all_holdout_materials_passed", False):
        raise SystemExit("fingerprint authority is not all-pass")

    allowed = ANCHORS if args.mode == "anchor" else EXTENSIONS
    if args.material not in allowed:
        raise SystemExit(f"{args.material} is not admitted to {args.mode} qualification")

    gate_f, r1 = import_historical_r1(args.research_root.resolve())
    catalog_path = args.research_root / contract["immutable_authority"]["material_catalog"]["path"]
    catalog = json.loads(catalog_path.read_text())
    by_name = {row["sfu"]: row for row in catalog["rows"]}
    if args.material not in by_name:
        raise SystemExit(f"material missing from pinned catalog: {args.material}")

    cell_counts = tuple(
        contract["anchor_replay"]["cell_counts"]
        if args.mode == "anchor"
        else contract["extension_qualification"]["cell_counts"]
    )
    gate_f.CELL_COUNTS = cell_counts

    row = by_name[args.material]
    gate_f.j1a.c1r.base.c1.configure_core(row)
    table, _, generation_failures = gate_f.j1a.c1r.base.generate_table(gate_f.j1a.N)
    generated_fingerprint = hashlib.sha256(table.tobytes(order="C")).hexdigest()
    expected_fingerprint = fingerprints["fingerprints"][args.material]
    fingerprint_match = not generation_failures and generated_fingerprint == expected_fingerprint

    result = r1.run_material(row)
    expected_cases = (
        contract["anchor_replay"]["expected_base_case_count_per_material"]
        if args.mode == "anchor"
        else contract["extension_qualification"]["expected_base_case_count_per_material"]
    )
    case_count_match = int(result.get("base_case_count") or -1) == int(expected_cases)

    anchor_match = None
    anchor_mismatches: list[str] = []
    if args.mode == "anchor":
        anchor_match, anchor_mismatches = semantic_match(
            result, expected_anchor_row(contract, args.material)
        )

    ross13_pass = (
        bool(result.get("pass", False))
        and fingerprint_match
        and case_count_match
        and anchor_match is not False
    )
    result.update(
        {
            "schema_version": 1,
            "workstream": "F-ROSS",
            "work_unit": "F-ROSS13",
            "gate": "TRANSIENT_36_MATERIAL_D3R_QUALIFICATION_MATERIAL",
            "qualification_contract": args.contract.name,
            "historical_research_head": contract["immutable_authority"]["historical_research_head"],
            "qualification_mode": args.mode,
            "qualification_cell_counts": list(cell_counts),
            "expected_base_case_count": int(expected_cases),
            "base_case_count_matches_contract": case_count_match,
            "expected_table_fingerprint": expected_fingerprint,
            "generated_table_fingerprint": generated_fingerprint,
            "table_fingerprint_matches_authority": fingerprint_match,
            "table_generation_failure_count_for_fingerprint_check": len(generation_failures),
            "historical_anchor_semantic_match": anchor_match,
            "historical_anchor_semantic_mismatches": anchor_mismatches,
            "ross13_pass": ross13_pass,
            "production_implementation": False,
            "production_allowlist_changed": False,
        }
    )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(
        json.dumps(
            {
                "material": args.material,
                "mode": args.mode,
                "ross13_pass": ross13_pass,
                "base_case_count": result.get("base_case_count"),
                "piecewise_transition_route_count": result.get("piecewise_transition_route_count"),
                "table_fingerprint_matches_authority": fingerprint_match,
                "historical_anchor_semantic_match": anchor_match,
                "failed_metrics": result.get("failed_metrics", []),
            },
            sort_keys=True,
        ),
        flush=True,
    )
    raise SystemExit(0 if ross13_pass else 1)


if __name__ == "__main__":
    main()
