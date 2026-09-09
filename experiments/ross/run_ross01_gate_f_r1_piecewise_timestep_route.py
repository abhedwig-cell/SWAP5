from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_f_timestep_convergence as gate_f

CONTRACT = "F-ROSS01_GATE_F_R1_PIECEWISE_TIMESTEP_ROUTE_CONTRACT.json"
ALLOWED_BASE_FAILURE = "candidate_table_cell_transition_count"


def endpoint_is_exact_internal_node(h: float) -> bool:
    _, frac, _ = gate_f.j1a.table_cell(h)
    return frac == 0.0


def route_check_case(case: dict, table) -> dict:
    n = int(case["n_cells"])
    profile_name = case["profile"]
    pattern = case["source_sink_pattern"]
    _, h_first, h_last = next(row for row in gate_f.PROFILE_FAMILIES if row[0] == profile_name)
    initial_heads = gate_f.gate_d.build_profile(n, h_first, h_last)
    theta0 = tuple(gate_f.gate_d.theta_from_head(h) for h in initial_heads)
    ext = gate_f.fixed_external(initial_heads, pattern)

    routes = []
    inadmissible = []
    for step_count in gate_f.STEP_COUNTS:
        dt = gate_f.HORIZON_DAY / step_count
        committed = theta0
        for step_index in range(step_count):
            start_heads = gate_f.heads_from_theta(committed)
            result = gate_f.candidate_step(committed, table, ext, dt)
            end_heads = tuple(result["heads"])
            changed = []
            for i, (h0, h1) in enumerate(zip(start_heads, end_heads)):
                c0 = gate_f.j1a.table_cell(h0)[0]
                c1 = gate_f.j1a.table_cell(h1)[0]
                if c0 != c1:
                    changed.append({
                        "component_index_zero_based": i,
                        "start_cell": int(c0),
                        "end_cell": int(c1),
                        "signed_cell_displacement": int(c1 - c0),
                        "start_head_cm": h0,
                        "end_head_cm": h1,
                        "end_head_exact_internal_node": endpoint_is_exact_internal_node(h1),
                    })
            if changed:
                admissible = (
                    len(changed) == 1
                    and abs(changed[0]["signed_cell_displacement"]) == 1
                    and not changed[0]["end_head_exact_internal_node"]
                    and result["domain_ok"]
                    and result["envelope_ok"]
                    and result["nonfinite_count"] == 0
                    and result["abs_global_mass_residual_cm"] <= gate_f.MASS_TOL_CM
                    and result["max_abs_cell_mass_residual_cm"] <= gate_f.MASS_TOL_CM
                )
                row = {
                    "step_count": step_count,
                    "dt_day": dt,
                    "step_index_zero_based": step_index,
                    "t_start_day": step_index * dt,
                    "t_end_day": (step_index + 1) * dt,
                    "transitioning_component_count": len(changed),
                    "changes": changed,
                    "abs_global_mass_residual_cm": result["abs_global_mass_residual_cm"],
                    "max_abs_cell_mass_residual_cm": result["max_abs_cell_mass_residual_cm"],
                    "admissible_adjacent_cell_route": admissible,
                    "extra_factorizations_due_to_route": 0,
                    "extra_backsolves_due_to_route": 0,
                    "retry_count_due_to_route": 0,
                    "cross_node_derivative_averaging_count": 0,
                }
                routes.append(row)
                if not admissible:
                    inadmissible.append(row)
            committed = result["theta"]
    return {
        "n_cells": n,
        "profile": profile_name,
        "source_sink_pattern": pattern,
        "route_count": len(routes),
        "inadmissible_route_count": len(inadmissible),
        "max_transitioning_components_per_route": max((r["transitioning_component_count"] for r in routes), default=0),
        "max_abs_cell_displacement": max((abs(ch["signed_cell_displacement"]) for r in routes for ch in r["changes"]), default=0),
        "exact_node_endpoint_count": sum(ch["end_head_exact_internal_node"] for r in routes for ch in r["changes"]),
        "routes": routes,
    }


def original_nontransition_gates_pass(base: dict) -> bool:
    return all(metric == ALLOWED_BASE_FAILURE for metric in base.get("failed_metrics", []))


def run_material(row: dict) -> dict:
    gate_f.j1a.c1r.base.c1.configure_core(row)
    material = row["sfu"]
    base = gate_f.run_material(row)

    transition_cases = [
        case for case in base.get("cases", [])
        if case.get("total_candidate_cell_transition_count", 0) > 0
    ]
    route_cases = []
    route_table_hash_match = True
    route_table_generation_failures = 0
    if transition_cases:
        table, _, generation_failures = gate_f.j1a.c1r.base.generate_table(gate_f.j1a.N)
        route_table_generation_failures = len(generation_failures)
        if generation_failures:
            route_table_hash_match = False
        else:
            route_hash = hashlib.sha256(table.tobytes(order="C")).hexdigest()
            route_table_hash_match = route_hash == base.get("table_sha256")
            for case in transition_cases:
                route_cases.append(route_check_case(case, table))

    route_count = sum(c["route_count"] for c in route_cases)
    inadmissible_count = sum(c["inadmissible_route_count"] for c in route_cases)
    exact_node_count = sum(c["exact_node_endpoint_count"] for c in route_cases)
    max_components = max((c["max_transitioning_components_per_route"] for c in route_cases), default=0)
    max_displacement = max((c["max_abs_cell_displacement"] for c in route_cases), default=0)
    original_transition_count = int(base.get("candidate_table_cell_transition_count", 0))

    route_policy_pass = (
        route_table_generation_failures == 0
        and route_table_hash_match
        and route_count == original_transition_count
        and inadmissible_count == 0
        and exact_node_count == 0
        and (route_count == 0 or max_components <= 1)
        and (route_count == 0 or max_displacement <= 1)
    )
    nontransition_pass = original_nontransition_gates_pass(base)
    passed = nontransition_pass and route_policy_pass

    return {
        "material": material,
        "base_initial_gate_f_pass": bool(base.get("pass", False)),
        "base_failed_metrics": list(base.get("failed_metrics", [])),
        "base_nontransition_hard_gates_pass": nontransition_pass,
        "base_case_count": base.get("case_count"),
        "base_candidate_table_cell_transition_count": original_transition_count,
        "route_case_count": len(route_cases),
        "piecewise_transition_route_count": route_count,
        "inadmissible_transition_route_count": inadmissible_count,
        "exact_node_endpoint_count": exact_node_count,
        "max_transitioning_components_per_transition_trial": max_components,
        "max_abs_cell_displacement_on_transition_route": max_displacement,
        "route_table_hash_match": route_table_hash_match,
        "route_table_generation_failures": route_table_generation_failures,
        "cross_node_derivative_averaging_count": 0,
        "extra_factorizations_due_to_transition_route": 0,
        "extra_backsolves_due_to_transition_route": 0,
        "retry_count_due_to_transition_route": 0,
        "reference_self_max": base.get("max_reference_coarse_vs_fine_theta_span_normalized"),
        "finest_theta_span_error_max": base.get("max_finest_candidate_theta_span_normalized_error"),
        "finest_state_change_relative_error_max": base.get("max_finest_candidate_state_change_relative_error"),
        "minimum_observed_order": base.get("minimum_observed_order_in_informative_cases"),
        "median_observed_order": base.get("median_observed_order_in_informative_cases"),
        "max_abs_step_mass_residual_cm": base.get("max_abs_step_mass_residual_cm"),
        "max_abs_horizon_mass_residual_cm": base.get("max_abs_horizon_mass_residual_cm"),
        "candidate_domain_failure_count": base.get("candidate_domain_failure_count"),
        "candidate_envelope_failure_count": base.get("candidate_envelope_failure_count"),
        "candidate_nonfinite_count": base.get("candidate_nonfinite_count"),
        "candidate_input_mutation_count": base.get("candidate_input_mutation_count"),
        "reference_nonfinite_count": base.get("reference_nonfinite_count"),
        "table_bitwise_unchanged": base.get("table_bitwise_unchanged"),
        "initial_state_bitwise_unchanged_all": base.get("initial_state_bitwise_unchanged_all"),
        "candidate_cost_shapes": base.get("candidate_cost_shapes"),
        "route_cases": route_cases,
        "pass": passed,
        "failed_metrics": [
            name for name, ok in (
                ("base_nontransition_hard_gates_pass", nontransition_pass),
                ("route_policy_pass", route_policy_pass),
            ) if not ok
        ],
    }


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_f_r1_piecewise_timestep_route.py MATERIAL OUTPUT.json")
    material = sys.argv[1]
    out = Path(sys.argv[2])
    catalog = json.loads(gate_f.j1a.CATALOG.read_text())
    by_name = {row["sfu"]: row for row in catalog["rows"]}
    if material not in gate_f.MATERIALS or material not in by_name:
        raise SystemExit(f"material must be one of {gate_f.MATERIALS}")
    result = run_material(by_name[material])
    result.update({
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "F_R1_PIECEWISE_C1R_TIMESTEP_CONVERGENCE",
        "contract": CONTRACT,
        "production_implementation": False,
        "sigma": gate_f.SIGMA,
        "horizon_day": gate_f.HORIZON_DAY,
        "candidate_step_counts": list(gate_f.STEP_COUNTS),
        "candidate_dt_days": [gate_f.HORIZON_DAY / n for n in gate_f.STEP_COUNTS],
        "candidate_algebra_changed_from_initial_gate_f": False,
        "mass_ledger_changed_from_initial_gate_f": False,
        "sigma_or_dt_retuned": False,
        "decision": (
            "QUALIFIED_RESTRICTED_PIECEWISE_C1R_SIGMA05_TIMESTEP_READY_FOR_SATURATION_TRANSITION_GATE"
            if result["pass"] else
            "F_TIMESTEP_REMAINS_UNQUALIFIED_CLASSIFY_TEMPORAL_MASS_ROUTE_OR_REFERENCE_FAILURE"
        ),
    })
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({k: v for k, v in result.items() if k != "route_cases"}, sort_keys=True), flush=True)
    raise SystemExit(0 if result["pass"] else 1)


if __name__ == "__main__":
    main()
