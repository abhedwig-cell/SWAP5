from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

CONTRACT_GATE = "WETTING_TOP_BOUNDARY_36_MATERIAL_TRANSIENT_QUALIFICATION"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--research-root", required=True, type=Path)
    parser.add_argument("--contract", required=True, type=Path)
    parser.add_argument("--fingerprint-authority", required=True, type=Path)
    parser.add_argument("--material", required=True)
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def import_historical(research_root: Path):
    research_scripts = research_root / "experiments" / "ross"
    sys.path.insert(0, str(research_scripts))
    import run_ross01_gate_f_timestep_convergence as gate_f
    import run_ross01_gate_f_r1_piecewise_timestep_route as r1
    return gate_f, r1


def main() -> None:
    args = parse_args()
    contract = json.loads(args.contract.read_text())
    fingerprints = json.loads(args.fingerprint_authority.read_text())

    if contract["gate"] != CONTRACT_GATE:
        raise SystemExit("unexpected F-ROSS14 qualification contract")
    if not fingerprints.get("all_holdout_materials_passed", False):
        raise SystemExit("fingerprint authority is not all-pass")

    allowed = tuple(contract["wetting_qualification"]["materials"])
    if args.material not in allowed:
        raise SystemExit(f"{args.material} is not admitted to F-ROSS14 qualification")

    gate_f, r1 = import_historical(args.research_root.resolve())

    expected_steps = tuple(contract["wetting_qualification"]["step_counts"])
    expected_dt = tuple(contract["wetting_qualification"]["dt_days"])
    if tuple(gate_f.STEP_COUNTS) != expected_steps:
        raise SystemExit("historical step-count authority drift")
    actual_dt = tuple(gate_f.HORIZON_DAY / n for n in gate_f.STEP_COUNTS)
    if any(not math.isclose(a, b, rel_tol=0.0, abs_tol=1.0e-18) for a, b in zip(actual_dt, expected_dt)):
        raise SystemExit("historical dt authority drift")
    if not math.isclose(gate_f.SIGMA, float(contract["wetting_qualification"]["sigma"]), rel_tol=0.0, abs_tol=0.0):
        raise SystemExit("historical sigma authority drift")
    if not math.isclose(gate_f.HORIZON_DAY, float(contract["wetting_qualification"]["horizon_day"]), rel_tol=0.0, abs_tol=0.0):
        raise SystemExit("historical horizon authority drift")

    gate_f.CELL_COUNTS = tuple(contract["wetting_qualification"]["cell_counts"])
    gate_f.SOURCE_PATTERNS = tuple(contract["wetting_qualification"]["source_sink_patterns"])

    forcing = contract["wetting_qualification"]["forcing_mapping"]
    q_top_factor = float(forcing["historical_harness_top_inflow_over_K_top"])
    q_bottom_factor = float(forcing["historical_harness_bottom_downward_outflow_over_K_bottom"])
    forcing_observations: list[tuple[float, float]] = []

    def wetting_boundary_fluxes(heads):
        c = gate_f.gate_d.core()
        k_top = float(c.k_of_h(heads[0]))
        k_bottom = float(c.k_of_h(heads[-1]))
        if not math.isfinite(k_top) or not math.isfinite(k_bottom) or k_top <= 0.0 or k_bottom <= 0.0:
            raise ValueError("nonpositive or nonfinite boundary conductivity")
        q_top = q_top_factor * k_top
        q_bottom = q_bottom_factor * k_bottom
        q_scale = max(1.0e-300, min(k_top, k_bottom))
        forcing_observations.append((q_top / k_top, q_bottom / k_bottom))
        return q_top, q_bottom, q_scale, k_top, k_bottom

    gate_f.gate_d.boundary_fluxes = wetting_boundary_fluxes

    catalog_path = args.research_root / contract["historical_authority"]["fross13_transient_contract_path"]
    fross13_contract = json.loads(catalog_path.read_text())
    material_catalog_path = args.research_root / fross13_contract["immutable_authority"]["material_catalog"]["path"]
    catalog = json.loads(material_catalog_path.read_text())
    by_name = {row["sfu"]: row for row in catalog["rows"]}
    if args.material not in by_name:
        raise SystemExit(f"material missing from pinned catalog: {args.material}")

    row = by_name[args.material]
    gate_f.j1a.c1r.base.c1.configure_core(row)
    table, _, generation_failures = gate_f.j1a.c1r.base.generate_table(gate_f.j1a.N)
    generated_fingerprint = hashlib.sha256(table.tobytes(order="C")).hexdigest()
    expected_fingerprint = fingerprints["fingerprints"][args.material]
    fingerprint_match = not generation_failures and generated_fingerprint == expected_fingerprint

    result = r1.run_material(row)

    expected_cases = int(contract["wetting_qualification"]["expected_base_case_count_per_material"])
    case_count_match = int(result.get("base_case_count") or -1) == expected_cases

    if not forcing_observations:
        forcing_match = False
        top_ratios = []
        bottom_ratios = []
    else:
        top_ratios = [row[0] for row in forcing_observations]
        bottom_ratios = [row[1] for row in forcing_observations]
        forcing_match = (
            all(math.isclose(v, q_top_factor, rel_tol=0.0, abs_tol=1.0e-15) for v in top_ratios)
            and all(math.isclose(v, q_bottom_factor, rel_tol=0.0, abs_tol=1.0e-15) for v in bottom_ratios)
        )

    ross14_pass = (
        bool(result.get("pass", False))
        and fingerprint_match
        and case_count_match
        and forcing_match
    )

    result.update(
        {
            "schema_version": 1,
            "workstream": "F-ROSS",
            "work_unit": "F-ROSS14",
            "gate": "WETTING_TOP_BOUNDARY_36_MATERIAL_TRANSIENT_QUALIFICATION_MATERIAL",
            "qualification_contract": args.contract.name,
            "historical_research_head": contract["historical_authority"]["research_head"],
            "qualification_mode": "wetting",
            "qualification_cell_counts": list(gate_f.CELL_COUNTS),
            "qualification_source_sink_patterns": list(gate_f.SOURCE_PATTERNS),
            "expected_base_case_count": expected_cases,
            "base_case_count_matches_contract": case_count_match,
            "expected_table_fingerprint": expected_fingerprint,
            "generated_table_fingerprint": generated_fingerprint,
            "table_fingerprint_matches_authority": fingerprint_match,
            "table_generation_failure_count_for_fingerprint_check": len(generation_failures),
            "historical_harness_top_inflow_over_K_top": q_top_factor,
            "historical_harness_bottom_outflow_over_K_bottom": q_bottom_factor,
            "forcing_observation_count": len(forcing_observations),
            "forcing_mapping_matches_contract": forcing_match,
            "observed_top_ratio_min": min(top_ratios) if top_ratios else None,
            "observed_top_ratio_max": max(top_ratios) if top_ratios else None,
            "observed_bottom_ratio_min": min(bottom_ratios) if bottom_ratios else None,
            "observed_bottom_ratio_max": max(bottom_ratios) if bottom_ratios else None,
            "ross14_pass": ross14_pass,
            "production_implementation": False,
            "production_model_binding_changed": False,
        }
    )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")

    print(
        json.dumps(
            {
                "material": args.material,
                "ross14_pass": ross14_pass,
                "base_case_count": result.get("base_case_count"),
                "piecewise_transition_route_count": result.get("piecewise_transition_route_count"),
                "inadmissible_transition_route_count": result.get("inadmissible_transition_route_count"),
                "table_fingerprint_matches_authority": fingerprint_match,
                "forcing_mapping_matches_contract": forcing_match,
                "failed_metrics": result.get("failed_metrics", []),
            },
            sort_keys=True,
        ),
        flush=True,
    )
    raise SystemExit(0 if ross14_pass else 1)


if __name__ == "__main__":
    main()
