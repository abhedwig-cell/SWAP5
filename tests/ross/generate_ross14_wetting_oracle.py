from __future__ import annotations

import argparse
import hashlib
import json
import math
import statistics
import sys
from pathlib import Path

SE_LEVELS = (0.65, 0.85, 0.98)
TARGET_TOP_INTERNAL_OVER_K = -0.025
TARGET_BOTTOM_UP_OVER_K = 0.011
EXPECTED_SCIENCE_CASES = 3
EXPECTED_KERNEL_CASES = 27


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--research-root", required=True, type=Path)
    p.add_argument("--contract", required=True, type=Path)
    p.add_argument("--fingerprint-authority", required=True, type=Path)
    p.add_argument("--material", required=True)
    p.add_argument("--fixture-out", required=True, type=Path)
    p.add_argument("--metadata-out", required=True, type=Path)
    return p.parse_args()


def import_research(root: Path):
    exp = root / "experiments" / "ross"
    sys.path.insert(0, str(exp))
    import run_ross01_gate_f_timestep_convergence as gate_f
    import ross01_d3r_fsi31_duration_adapter as d3r
    return gate_f, d3r


def head_from_se(se: float, row: dict) -> float:
    n = float(row["n"])
    m = 1.0 - 1.0 / n
    alpha = float(row["alpha_per_cm"])
    return -((se ** (-1.0 / m) - 1.0) ** (1.0 / n)) / alpha


def target_external(gate_f, initial_heads):
    ext = gate_f.fixed_external(initial_heads, "zero")
    ext["q_top"] = TARGET_TOP_INTERNAL_OVER_K * float(ext["k_top"])
    # Historical research q_bottom is downward-positive. RossFast target is
    # upward-positive, hence the sign inversion here.
    ext["q_bottom"] = -TARGET_BOTTOM_UP_OVER_K * float(ext["k_bottom"])
    return ext


def run_science_case(gate_f, material: str, se: float, row: dict, table):
    h0 = head_from_se(se, row)
    initial_heads = tuple(h0 for _ in range(16))
    theta0 = tuple(gate_f.gate_d.theta_from_head(h) for h in initial_heads)
    theta_snapshot = gate_f.float_bytes(theta0)
    heads_snapshot = gate_f.float_bytes(initial_heads)
    ext = target_external(gate_f, initial_heads)

    ref_coarse = gate_f.run_reference(theta0, table, ext, gate_f.REFERENCE_MAX_STEP_COARSE)
    ref_fine = gate_f.run_reference(theta0, table, ext, gate_f.REFERENCE_MAX_STEP_FINE)
    ref_self = gate_f.theta_span_error(ref_coarse["theta"], ref_fine["theta"])

    paths = []
    for step_count in gate_f.STEP_COUNTS:
        candidate = gate_f.run_candidate(theta0, table, ext, step_count)
        candidate["theta_span_normalized_error"] = gate_f.theta_span_error(
            candidate["theta"], ref_fine["theta"]
        )
        candidate["state_change_relative_error"] = gate_f.state_change_relative_error(
            candidate["theta"], ref_fine["theta"], theta0
        )
        paths.append(candidate)

    errors = [p["theta_span_normalized_error"] for p in paths]
    monotonic = all(
        errors[i + 1] <= errors[i] + gate_f.MONOTONIC_SLACK
        for i in range(len(errors) - 1)
    )
    e8 = next(p["theta_span_normalized_error"] for p in paths if p["step_count"] == 8)
    e16 = next(p["theta_span_normalized_error"] for p in paths if p["step_count"] == 16)
    observed_order = None
    if e8 >= gate_f.ORDER_FLOOR and e16 > 0.0:
        observed_order = math.log(e8 / e16, 2.0)

    finest = next(p for p in paths if p["step_count"] == 16)
    return {
        "material": material,
        "effective_saturation": se,
        "n_cells": 16,
        "source_sink_pattern": "zero",
        "horizon_day": gate_f.HORIZON_DAY,
        "sigma": gate_f.SIGMA,
        "initial_head_cm": h0,
        "reference_self_theta_span_normalized": ref_self,
        "reference_nonfinite_count": ref_coarse["nonfinite_count"] + ref_fine["nonfinite_count"],
        "candidate_paths": paths,
        "refinement_error_nonincreasing": monotonic,
        "observed_order_8_to_16": observed_order,
        "finest_theta_span_normalized_error": finest["theta_span_normalized_error"],
        "finest_state_change_relative_error": finest["state_change_relative_error"],
        "initial_state_bitwise_unchanged_outside_sequences": (
            gate_f.float_bytes(theta0) == theta_snapshot
            and gate_f.float_bytes(initial_heads) == heads_snapshot
        ),
        "total_candidate_cell_transition_count": sum(p["cell_transition_count"] for p in paths),
        "total_candidate_nonfinite_count": sum(p["nonfinite_count"] for p in paths),
        "total_candidate_domain_failure_count": sum(p["domain_failure_count"] for p in paths),
        "total_candidate_envelope_failure_count": sum(p["envelope_failure_count"] for p in paths),
        "total_candidate_input_mutation_count": sum(p["input_mutation_count"] for p in paths),
        "max_abs_step_mass_residual_cm": max(p["max_abs_step_mass_residual_cm"] for p in paths),
        "max_abs_horizon_mass_residual_cm": max(p["abs_horizon_mass_residual_cm"] for p in paths),
        "max_abs_cell_mass_residual_cm": max(p["max_abs_cell_mass_residual_cm"] for p in paths),
    }


def endpoint_is_exact_internal_node(gate_f, h: float) -> bool:
    _, frac, _ = gate_f.j1a.table_cell(h)
    return frac == 0.0


def route_check_uniform_case(gate_f, case: dict, row: dict, table):
    h0 = float(case["initial_head_cm"])
    initial_heads = tuple(h0 for _ in range(16))
    theta0 = tuple(gate_f.gate_d.theta_from_head(h) for h in initial_heads)
    ext = target_external(gate_f, initial_heads)
    routes = []

    for step_count in gate_f.STEP_COUNTS:
        dt = gate_f.HORIZON_DAY / step_count
        committed = theta0
        for step_index in range(step_count):
            start_heads = gate_f.heads_from_theta(committed)
            result = gate_f.candidate_step(committed, table, ext, dt)
            end_heads = tuple(result["heads"])
            changed = []
            for i, (h_start, h_end) in enumerate(zip(start_heads, end_heads)):
                c0 = gate_f.j1a.table_cell(h_start)[0]
                c1 = gate_f.j1a.table_cell(h_end)[0]
                if c0 != c1:
                    changed.append({
                        "component_index_zero_based": i,
                        "start_cell": int(c0),
                        "end_cell": int(c1),
                        "signed_cell_displacement": int(c1 - c0),
                        "end_head_exact_internal_node": endpoint_is_exact_internal_node(gate_f, h_end),
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
                routes.append({
                    "effective_saturation": case["effective_saturation"],
                    "step_count": step_count,
                    "step_index_zero_based": step_index,
                    "transitioning_component_count": len(changed),
                    "max_abs_cell_displacement": max(abs(c["signed_cell_displacement"]) for c in changed),
                    "exact_node_endpoint_count": sum(c["end_head_exact_internal_node"] for c in changed),
                    "admissible": admissible,
                })
            committed = tuple(result["theta"])
    return routes


def evaluate_science(gate_f, material: str, row: dict, table):
    cases = []
    errors = []
    for se in SE_LEVELS:
        try:
            cases.append(run_science_case(gate_f, material, se, row, table))
        except Exception as exc:
            errors.append({"effective_saturation": se, "error": repr(exc)})

    if not cases:
        return {
            "pass": False,
            "case_count": 0,
            "errors": errors,
            "failed_metrics": ["no_valid_cases"],
            "route_count": 0,
            "inadmissible_route_count": 0,
            "exact_node_endpoint_count": 0,
            "max_transitioning_components": 0,
            "max_abs_cell_displacement": 0,
        }

    informative_orders = [
        c["observed_order_8_to_16"] for c in cases
        if c["observed_order_8_to_16"] is not None
        and math.isfinite(c["observed_order_8_to_16"])
    ]
    min_order = min(informative_orders) if informative_orders else None
    median_order = statistics.median(informative_orders) if informative_orders else None

    transition_count = sum(c["total_candidate_cell_transition_count"] for c in cases)
    route_rows = []
    for case in cases:
        if case["total_candidate_cell_transition_count"] > 0:
            route_rows.extend(route_check_uniform_case(gate_f, case, row, table))

    route_count = len(route_rows)
    inadmissible_count = sum(not r["admissible"] for r in route_rows)
    exact_node_count = sum(r["exact_node_endpoint_count"] for r in route_rows)
    max_components = max((r["transitioning_component_count"] for r in route_rows), default=0)
    max_displacement = max((r["max_abs_cell_displacement"] for r in route_rows), default=0)

    nontransition_tests = {
        "all_precommitted_cases_valid": len(cases) == EXPECTED_SCIENCE_CASES and not errors,
        "reference_self_check": max(c["reference_self_theta_span_normalized"] for c in cases) <= gate_f.REF_SELF_TOL,
        "finest_theta_span_error": max(c["finest_theta_span_normalized_error"] for c in cases) <= gate_f.FINE_SPAN_ERROR_TOL,
        "finest_state_change_relative_error": max(c["finest_state_change_relative_error"] for c in cases) <= gate_f.FINE_CHANGE_ERROR_TOL,
        "refinement_error_nonincreasing": all(c["refinement_error_nonincreasing"] for c in cases),
        "observed_order": (
            not informative_orders
            or (min_order is not None and median_order is not None
                and min_order >= gate_f.MIN_ORDER and median_order >= gate_f.MEDIAN_ORDER)
        ),
        "maximum_abs_step_mass_residual_cm": max(c["max_abs_step_mass_residual_cm"] for c in cases) <= gate_f.MASS_TOL_CM,
        "maximum_abs_horizon_mass_residual_cm": max(c["max_abs_horizon_mass_residual_cm"] for c in cases) <= gate_f.MASS_TOL_CM,
        "candidate_state_within_unsaturated_MvG_domain": sum(c["total_candidate_domain_failure_count"] for c in cases) == 0,
        "candidate_head_within_C1R_envelope": sum(c["total_candidate_envelope_failure_count"] for c in cases) == 0,
        "nonfinite_count": (
            sum(c["total_candidate_nonfinite_count"] for c in cases) == 0
            and sum(c["reference_nonfinite_count"] for c in cases) == 0
        ),
        "initial_state_bitwise_unchanged": (
            all(c["initial_state_bitwise_unchanged_outside_sequences"] for c in cases)
            and sum(c["total_candidate_input_mutation_count"] for c in cases) == 0
        ),
    }
    route_policy_pass = (
        route_count == transition_count
        and inadmissible_count == 0
        and exact_node_count == 0
        and (route_count == 0 or max_components <= 1)
        and (route_count == 0 or max_displacement <= 1)
    )
    failed = [name for name, ok in nontransition_tests.items() if not ok]
    if not route_policy_pass:
        failed.append("piecewise_route_policy")

    return {
        "pass": all(nontransition_tests.values()) and route_policy_pass,
        "case_count": len(cases),
        "errors": errors,
        "failed_metrics": failed,
        "reference_self_max": max(c["reference_self_theta_span_normalized"] for c in cases),
        "finest_theta_span_error_max": max(c["finest_theta_span_normalized_error"] for c in cases),
        "finest_state_change_relative_error_max": max(c["finest_state_change_relative_error"] for c in cases),
        "minimum_observed_order": min_order,
        "median_observed_order": median_order,
        "max_abs_step_mass_residual_cm": max(c["max_abs_step_mass_residual_cm"] for c in cases),
        "max_abs_horizon_mass_residual_cm": max(c["max_abs_horizon_mass_residual_cm"] for c in cases),
        "candidate_domain_failure_count": sum(c["total_candidate_domain_failure_count"] for c in cases),
        "candidate_envelope_failure_count": sum(c["total_candidate_envelope_failure_count"] for c in cases),
        "candidate_nonfinite_count": sum(c["total_candidate_nonfinite_count"] for c in cases),
        "reference_nonfinite_count": sum(c["reference_nonfinite_count"] for c in cases),
        "route_count": route_count,
        "inadmissible_route_count": inadmissible_count,
        "exact_node_endpoint_count": exact_node_count,
        "max_transitioning_components": max_components,
        "max_abs_cell_displacement": max_displacement,
        "cases": cases,
    }


def run_window(gate_f, theta0, table, ext, duration: float, steps: int = 8):
    theta = tuple(float(v) for v in theta0)
    dt = duration / steps
    max_global_mass = 0.0
    max_cell_mass = 0.0
    transitions = 0
    for _ in range(steps):
        result = gate_f.candidate_step(theta, table, ext, dt)
        if not result["domain_ok"] or not result["envelope_ok"] or result["nonfinite_count"]:
            raise RuntimeError(("research candidate invalid", duration, result))
        max_global_mass = max(max_global_mass, float(result["abs_global_mass_residual_cm"]))
        max_cell_mass = max(max_cell_mass, float(result["max_abs_cell_mass_residual_cm"]))
        transitions += int(result["cell_transition_count"])
        theta = tuple(float(v) for v in result["theta"])
    return (
        theta,
        tuple(float(v) for v in gate_f.heads_from_theta(theta)),
        max_global_mass,
        max_cell_mass,
        transitions,
    )


def write_vector(f, values):
    f.write(" ".join(f"{float(v):.17e}" for v in values) + "\n")


def main():
    a = parse_args()
    contract = json.loads(a.contract.read_text())
    fingerprints = json.loads(a.fingerprint_authority.read_text())
    if contract["work_unit"] != "F-ROSS14":
        raise SystemExit("unexpected F-ROSS14 contract")
    if a.material not in contract["qualification_domain"]["materials"]:
        raise SystemExit(f"material outside F-ROSS14 domain: {a.material}")

    gate_f, d3r = import_research(a.research_root.resolve())
    catalog = json.loads(
        (a.research_root / "integration" / "f-ross" / "F-ROSS01_GATE_C1_MATERIAL_CATALOG.json").read_text()
    )
    by_name = {row["sfu"]: row for row in catalog["rows"]}
    if a.material not in by_name:
        raise SystemExit(f"material missing from pinned research catalog: {a.material}")
    row = by_name[a.material]

    gate_f.j1a.c1r.base.c1.configure_core(row)
    table, preprocessing_seconds, generation_failures = gate_f.j1a.c1r.base.generate_table(gate_f.j1a.N)
    generated_fingerprint = hashlib.sha256(table.tobytes(order="C")).hexdigest()
    expected_fingerprint = fingerprints["fingerprints"][a.material]
    fingerprint_match = not generation_failures and generated_fingerprint == expected_fingerprint
    if not fingerprint_match:
        raise SystemExit(
            f"F_ROSS14_FAIL table fingerprint {a.material} generated={generated_fingerprint} expected={expected_fingerprint}"
        )

    science = evaluate_science(gate_f, a.material, row, table)
    science_pass = bool(science["pass"])

    fixture_rows = []
    max_component_mass = 0.0
    max_component_cell_mass = 0.0
    total_transitions = 0

    for se in SE_LEVELS:
        h0 = head_from_se(se, row)
        heads0 = tuple(h0 for _ in range(16))
        theta0 = tuple(float(gate_f.gate_d.theta_from_head(h)) for h in heads0)
        ext = target_external(gate_f, heads0)
        q_top = float(ext["q_top"])
        q_bottom_up = -float(ext["q_bottom"])
        span = float(row["theta_s"] - row["theta_r"])

        for attempt in range(d3r.CANONICAL_MAX_RETRIES + 1):
            duration = float(d3r.DURATION_LADDER_DAY[attempt])
            coarse_theta, _, m0, c0, t0 = run_window(gate_f, theta0, table, ext, duration)
            half_theta, _, m1, c1, t1 = run_window(gate_f, theta0, table, ext, 0.5 * duration)
            refined_theta, refined_heads, m2, c2, t2 = run_window(
                gate_f, half_theta, table, ext, 0.5 * duration
            )
            raw = max(abs(a0 - b0) for a0, b0 in zip(refined_theta, coarse_theta)) / span
            indicator = max(raw, gate_f.ORDER_FLOOR) / 1.0e-5
            if not math.isfinite(indicator) or indicator < 0.0:
                raise RuntimeError(("invalid temporal indicator", a.material, se, attempt, indicator))
            max_component_mass = max(max_component_mass, m0, m1, m2)
            max_component_cell_mass = max(max_component_cell_mass, c0, c1, c2)
            total_transitions += t0 + t1 + t2
            fixture_rows.append({
                "se": se,
                "attempt": attempt,
                "duration": duration,
                "q_top": q_top,
                "q_bottom_up": q_bottom_up,
                "indicator": indicator,
                "initial_heads": heads0,
                "initial_theta": theta0,
                "refined_heads": refined_heads,
                "refined_theta": refined_theta,
            })

    if len(fixture_rows) != EXPECTED_KERNEL_CASES:
        raise SystemExit(f"F_ROSS14_FAIL expected {EXPECTED_KERNEL_CASES} kernel cases got {len(fixture_rows)}")
    if max_component_mass > 1.0e-12 or max_component_cell_mass > 1.0e-12:
        raise SystemExit(
            f"F_ROSS14_FAIL research kernel mass global={max_component_mass} cell={max_component_cell_mass}"
        )

    a.fixture_out.parent.mkdir(parents=True, exist_ok=True)
    with a.fixture_out.open("w", encoding="utf-8") as f:
        f.write(f"{len(fixture_rows)}\n")
        for case in fixture_rows:
            f.write(
                f"{case['se']:.17e} {case['attempt']} {case['duration']:.17e} "
                f"{case['q_top']:.17e} {case['q_bottom_up']:.17e} {case['indicator']:.17e}\n"
            )
            write_vector(f, case["initial_heads"])
            write_vector(f, case["initial_theta"])
            write_vector(f, case["refined_heads"])
            write_vector(f, case["refined_theta"])

    metadata = {
        "schema_version": 2,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS14",
        "gate": "TOP_WETTING_FORCING_ENVELOPE_MATERIAL_QUALIFICATION",
        "material": a.material,
        "research_head": contract["pinned_research_authority"]["head"],
        "generated_table_fingerprint": generated_fingerprint,
        "expected_table_fingerprint": expected_fingerprint,
        "table_fingerprint_matches_authority": fingerprint_match,
        "table_generation_failure_count": len(generation_failures),
        "effective_saturation": list(SE_LEVELS),
        "science_case_count": science["case_count"],
        "expected_science_case_count": EXPECTED_SCIENCE_CASES,
        "science_pass": science_pass,
        "science_failed_metrics": science["failed_metrics"],
        "science_errors": science["errors"],
        "piecewise_transition_route_count": science["route_count"],
        "inadmissible_transition_route_count": science["inadmissible_route_count"],
        "exact_node_endpoint_count": science["exact_node_endpoint_count"],
        "max_transitioning_components_per_transition_trial": science["max_transitioning_components"],
        "max_abs_cell_displacement_on_transition_route": science["max_abs_cell_displacement"],
        "reference_self_max": science.get("reference_self_max"),
        "finest_theta_span_error_max": science.get("finest_theta_span_error_max"),
        "finest_state_change_relative_error_max": science.get("finest_state_change_relative_error_max"),
        "minimum_observed_order": science.get("minimum_observed_order"),
        "median_observed_order": science.get("median_observed_order"),
        "max_abs_step_mass_residual_cm": science.get("max_abs_step_mass_residual_cm"),
        "max_abs_horizon_mass_residual_cm": science.get("max_abs_horizon_mass_residual_cm"),
        "candidate_domain_failure_count": science.get("candidate_domain_failure_count"),
        "candidate_envelope_failure_count": science.get("candidate_envelope_failure_count"),
        "candidate_nonfinite_count": science.get("candidate_nonfinite_count"),
        "reference_nonfinite_count": science.get("reference_nonfinite_count"),
        "kernel_fixture_case_count": len(fixture_rows),
        "max_kernel_component_global_mass_residual_cm": max_component_mass,
        "max_kernel_component_cell_mass_residual_cm": max_component_cell_mass,
        "kernel_fixture_total_cell_transition_count": total_transitions,
        "target_top_internal_over_K": TARGET_TOP_INTERNAL_OVER_K,
        "target_bottom_up_over_K": TARGET_BOTTOM_UP_OVER_K,
        "production_kernel_equivalence_pass": False,
        "ross14_material_pass": False,
        "production_implementation": False,
    }
    a.metadata_out.write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "material": a.material,
        "science_pass": science_pass,
        "science_case_count": science["case_count"],
        "science_failed_metrics": science["failed_metrics"],
        "science_errors": science["errors"],
        "fingerprint_match": fingerprint_match,
        "kernel_fixture_case_count": len(fixture_rows),
        "piecewise_transition_route_count": science["route_count"],
    }, sort_keys=True), flush=True)
    raise SystemExit(0 if science_pass else 1)


if __name__ == "__main__":
    main()
