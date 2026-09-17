from __future__ import annotations

import argparse
import hashlib
import json
import math
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
    import run_ross01_gate_f_r1_piecewise_timestep_route as r1
    import ross01_d3r_fsi31_duration_adapter as d3r
    return gate_f, r1, d3r


def head_from_se(se: float, row: dict) -> float:
    n = float(row["n"])
    m = 1.0 - 1.0 / n
    alpha = float(row["alpha_per_cm"])
    return -((se ** (-1.0 / m) - 1.0) ** (1.0 / n)) / alpha


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

    gate_f, r1, d3r = import_research(a.research_root.resolve())
    catalog = json.loads(
        (a.research_root / "integration" / "f-ross" / "F-ROSS01_GATE_C1_MATERIAL_CATALOG.json").read_text()
    )
    by_name = {row["sfu"]: row for row in catalog["rows"]}
    if a.material not in by_name:
        raise SystemExit(f"material missing from pinned research catalog: {a.material}")
    row = by_name[a.material]

    gate_f.j1a.c1r.base.c1.configure_core(row)
    original_generate = gate_f.j1a.c1r.base.generate_table
    table, preprocessing_seconds, generation_failures = original_generate(gate_f.j1a.N)
    generated_fingerprint = hashlib.sha256(table.tobytes(order="C")).hexdigest()
    expected_fingerprint = fingerprints["fingerprints"][a.material]
    fingerprint_match = not generation_failures and generated_fingerprint == expected_fingerprint
    if not fingerprint_match:
        raise SystemExit(
            f"F_ROSS14_FAIL table fingerprint {a.material} generated={generated_fingerprint} expected={expected_fingerprint}"
        )

    profiles = []
    for se in SE_LEVELS:
        h0 = head_from_se(se, row)
        profiles.append((f"se_{int(round(se*100)):03d}", h0, h0))

    gate_f.CELL_COUNTS = (16,)
    gate_f.PROFILE_FAMILIES = tuple(profiles)
    gate_f.SOURCE_PATTERNS = ("zero",)

    original_fixed_external = gate_f.fixed_external

    def target_external(initial_heads, pattern):
        if pattern != "zero":
            raise ValueError("F-ROSS14 permits zero source/sink only")
        ext = original_fixed_external(initial_heads, pattern)
        ext["q_top"] = TARGET_TOP_INTERNAL_OVER_K * float(ext["k_top"])
        # Research q_bottom is downward-positive. RossFast target is upward-positive.
        ext["q_bottom"] = -TARGET_BOTTOM_UP_OVER_K * float(ext["k_bottom"])
        return ext

    gate_f.fixed_external = target_external

    # Reuse the exact generated table for Gate-F and R1 replay so fingerprint
    # provenance and science diagnostics refer to one immutable N241 table.
    def frozen_generate(n):
        if n != gate_f.j1a.N:
            raise ValueError(("unexpected table N", n))
        return table.copy(), preprocessing_seconds, []

    gate_f.j1a.c1r.base.generate_table = frozen_generate

    science = r1.run_material(row)
    science_case_count = int(science.get("base_case_count") or -1)
    science_pass = bool(science.get("pass", False)) and science_case_count == EXPECTED_SCIENCE_CASES

    fixture_rows = []
    max_component_mass = 0.0
    max_component_cell_mass = 0.0
    total_transitions = 0

    for se in SE_LEVELS:
        h0 = head_from_se(se, row)
        heads0 = tuple(h0 for _ in range(16))
        theta0 = tuple(float(gate_f.gate_d.theta_from_head(h)) for h in heads0)
        ext = target_external(heads0, "zero")
        q_top = float(ext["q_top"])
        q_bottom_up = -float(ext["q_bottom"])
        span = float(row["theta_s"] - row["theta_r"])

        for attempt in range(d3r.CANONICAL_MAX_RETRIES + 1):
            duration = float(d3r.DURATION_LADDER_DAY[attempt])
            coarse_theta, coarse_heads, m0, c0, t0 = run_window(gate_f, theta0, table, ext, duration)
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
            fixture_rows.append(
                {
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
                }
            )

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
        "schema_version": 1,
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
        "science_case_count": science_case_count,
        "expected_science_case_count": EXPECTED_SCIENCE_CASES,
        "science_pass": science_pass,
        "science_failed_metrics": science.get("failed_metrics", []),
        "base_initial_gate_f_pass": science.get("base_initial_gate_f_pass"),
        "piecewise_transition_route_count": science.get("piecewise_transition_route_count"),
        "inadmissible_transition_route_count": science.get("inadmissible_transition_route_count"),
        "exact_node_endpoint_count": science.get("exact_node_endpoint_count"),
        "max_transitioning_components_per_transition_trial": science.get("max_transitioning_components_per_transition_trial"),
        "max_abs_cell_displacement_on_transition_route": science.get("max_abs_cell_displacement_on_transition_route"),
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
    print(
        json.dumps(
            {
                "material": a.material,
                "science_pass": science_pass,
                "science_case_count": science_case_count,
                "fingerprint_match": fingerprint_match,
                "kernel_fixture_case_count": len(fixture_rows),
                "piecewise_transition_route_count": science.get("piecewise_transition_route_count"),
                "failed_metrics": science.get("failed_metrics", []),
            },
            sort_keys=True,
        ),
        flush=True,
    )
    raise SystemExit(0 if science_pass else 1)


if __name__ == "__main__":
    main()
