from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_e3_saturation_transition_hydrologic_relevance as e3
import run_ross01_gate_e3c_tight_qualification_solver_policy as e3c

CONTRACT = "F-ROSS01_GATE_E3D_REAL_H0_TRANSITION_PRECOMMIT.json"
HARNESS_REMEDIATION = "F-ROSS01_GATE_E3D_R2_FAIL_CLOSED_HARNESS_REMEDIATION_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = ("B01", "B12", "O13", "O14")
HORIZON = 0.001
STEP_COUNTS = (4, 8, 16)
REF_STEPS = 64
MAX_TRAJECTORY_HEAD_CM = 0.8
CASE = {
    "id": "REAL_H0_WETTING_TOP_FLUX",
    "initial_heads": (-0.2, -1.5, -5.0),
    "q_top_fraction_ksat": 1.5,
    "bottom_head": -15.0,
    "direction": "wetting",
}


def top_crossing_present(traj: dict) -> bool:
    x = traj["crossing_times"][0]
    return x is not None


def max_trajectory_head(traj: dict) -> float:
    vals = [float(h) for _t, heads in traj["history"] for h in heads]
    return max(vals) if vals else -math.inf


def compare_case_fail_closed(case: dict, table) -> dict:
    """E3 comparison with identical frozen thresholds, but explicit incomplete-trajectory handling."""
    ref = e3.run_trajectory(case, REF_STEPS, table, candidate=False)
    candidates = [e3.run_trajectory(case, n, table, candidate=True) for n in STEP_COUNTS]
    finest = candidates[-1]

    reference_complete = ref["completed_steps"] == REF_STEPS
    candidates_complete = all(c["completed_steps"] == c["step_count"] for c in candidates)
    ref_times = {round(float(t), 15) for t, _heads in ref["history"]}
    comparison_time_coverage = all(round(float(t), 15) in ref_times for t, _heads in finest["history"])
    comparison_available = bool(reference_complete and candidates_complete and comparison_time_coverage)

    if comparison_available:
        max_head, max_storage, max_cell_storage = e3.interpolate_reference(ref, finest)
        bottom_error = abs(finest["cumulative_bottom_flux_cm"] - ref["cumulative_bottom_flux_cm"])
    else:
        max_head = None
        max_storage = None
        max_cell_storage = None
        bottom_error = None

    c_times = finest["crossing_times"]
    r_times = ref["crossing_times"]
    candidate_event_count = sum(x is not None for x in c_times)
    reference_event_count = sum(x is not None for x in r_times)
    matched_time_errors = [
        abs(float(c) - float(r))
        for c, r in zip(c_times, r_times)
        if c is not None and r is not None
    ]
    if not comparison_available:
        transition_time_error = None
    elif matched_time_errors:
        transition_time_error = max(matched_time_errors)
    elif candidate_event_count == 0 and reference_event_count == 0:
        transition_time_error = 0.0
    else:
        transition_time_error = None

    max_step_mass = max(x["max_abs_step_mass_residual_cm"] for x in candidates)
    max_horizon_mass = max(x["abs_horizon_mass_residual_cm"] for x in candidates)
    unqualified = sum(x["unqualified_face_fallback_count"] for x in candidates)
    nonfinite = sum(x["nonfinite_count"] for x in candidates) + ref["nonfinite_count"]
    solver_failures = sum(x["qualification_solver_failure_count"] for x in candidates) + ref["qualification_solver_failure_count"]
    mutation = sum(x["committed_state_mutation_on_rejected_trial_count"] for x in candidates) + ref["committed_state_mutation_on_rejected_trial_count"]

    hydrology_tests = {
        "step_mass": max_step_mass <= e3.MASS_TOL,
        "horizon_mass": max_horizon_mass <= e3.MASS_TOL,
        "bottom_flux": comparison_available and bottom_error is not None and bottom_error <= e3.BOTTOM_FLUX_TOL,
        "storage": comparison_available and max_storage is not None and max_storage <= e3.STORAGE_TOL,
        "cell_storage": comparison_available and max_cell_storage is not None and max_cell_storage <= e3.CELL_STORAGE_TOL,
        "head": comparison_available and max_head is not None and max_head <= e3.HEAD_TOL,
        "transition_time": comparison_available and transition_time_error is not None and transition_time_error <= e3.TRANSITION_TIME_TOL,
        "candidate_transition_present": candidate_event_count >= 1,
        "reference_transition_present": reference_event_count >= 1,
        "nonfinite": nonfinite == 0,
        "solver_complete": solver_failures == 0,
        "transaction": mutation == 0,
        "comparison_available": comparison_available,
    }
    hydrology_pass = all(hydrology_tests.values())
    face_scope_pass = unqualified == 0
    if hydrology_pass and face_scope_pass:
        decision = "QUALIFIED_RESTRICTED_PHYSICAL_SATURATION_TRANSITION_COLUMN_READY_FOR_HETEROGENEOUS_AND_BOUNDARY_QUALIFICATION"
    elif hydrology_pass:
        decision = "HYDROLOGICALLY_ACCEPTABLE_SATURATION_TRANSITION_FACE_SCOPE_GAP_REQUIRES_EXPLICIT_FACE_QUALIFICATION"
    else:
        decision = "SATURATION_TRANSITION_PHYSICAL_COLUMN_NOT_QUALIFIED_RESEARCH_REQUIRED"

    unavailable_reason = None
    if not comparison_available:
        reasons = []
        if not reference_complete:
            reasons.append("REFERENCE_TRAJECTORY_INCOMPLETE")
        if not candidates_complete:
            reasons.append("CANDIDATE_TRAJECTORY_INCOMPLETE")
        if not comparison_time_coverage:
            reasons.append("REFERENCE_TIME_COVERAGE_INCOMPLETE")
        unavailable_reason = "+".join(reasons)

    return {
        "case": case["id"],
        "direction": case["direction"],
        "reference": ref,
        "candidates": candidates,
        "reference_complete": reference_complete,
        "candidates_complete": candidates_complete,
        "comparison_time_coverage": comparison_time_coverage,
        "comparison_available": comparison_available,
        "comparison_unavailable_reason": unavailable_reason,
        "finest_max_head_difference_cm": max_head,
        "finest_max_total_storage_difference_cm": max_storage,
        "finest_max_cell_storage_difference_cm": max_cell_storage,
        "finest_cumulative_bottom_flux_difference_cm": bottom_error,
        "finest_max_transition_time_difference_day": transition_time_error,
        "candidate_transition_event_count": candidate_event_count,
        "reference_transition_event_count": reference_event_count,
        "unqualified_face_fallback_count": unqualified,
        "nonfinite_count": nonfinite,
        "qualification_solver_failure_count": solver_failures,
        "committed_state_mutation_on_rejected_trial_count": mutation,
        "max_abs_step_mass_residual_cm": max_step_mass,
        "max_abs_horizon_mass_residual_cm": max_horizon_mass,
        "hydrology_tests": hydrology_tests,
        "hydrology_pass": hydrology_pass,
        "face_scope_pass": face_scope_pass,
        "decision": decision,
    }


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_e3d_real_h0_transition.py MATERIAL OUTPUT.json")
    material = sys.argv[1]
    out = Path(sys.argv[2])
    if material not in MATERIALS:
        raise SystemExit(f"material must be one of {MATERIALS}")

    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    by = {r["sfu"]: r for r in catalog["rows"]}

    original_face = e3.candidate_face
    original_solve = e3.solve_step
    original_horizon = e3.HORIZON
    original_steps = e3.STEP_COUNTS
    original_ref_steps = e3.REF_STEPS
    try:
        e3.candidate_face = e3c.expanded_candidate_face
        e3.solve_step = e3c.tight_solve_step
        e3.HORIZON = HORIZON
        e3.STEP_COUNTS = STEP_COUNTS
        e3.REF_STEPS = REF_STEPS
        e3.configure(by[material])
        table = e3.generate_c1r_table()
        base = compare_case_fail_closed(CASE, table)
    finally:
        e3.candidate_face = original_face
        e3.solve_step = original_solve
        e3.HORIZON = original_horizon
        e3.STEP_COUNTS = original_steps
        e3.REF_STEPS = original_ref_steps

    ref = base["reference"]
    finest = base["candidates"][-1]
    ref_top_cross = top_crossing_present(ref)
    cand_top_cross = top_crossing_present(finest)
    all_trajectories = [ref, *base["candidates"]]
    max_head = max(max_trajectory_head(t) for t in all_trajectories)

    added_tests = {
        "reference_top_cell_h0_crossing": ref_top_cross,
        "finest_candidate_top_cell_h0_crossing": cand_top_cross,
        "max_trajectory_head_guard": max_head <= MAX_TRAJECTORY_HEAD_CM,
        "comparison_available": base["comparison_available"],
    }
    frozen_original_tests_pass = bool(base["hydrology_pass"] and base["face_scope_pass"])
    passed = bool(frozen_original_tests_pass and all(added_tests.values()))

    result = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E3D_REAL_H0_SATURATION_TRANSITION_COLUMN",
        "contract": CONTRACT,
        "harness_remediation_contract": HARNESS_REMEDIATION,
        "material": material,
        "production_implementation": False,
        "qualification_solver_is_production_solver": False,
        "fixture": {
            "initial_heads_cm": list(CASE["initial_heads"]),
            "q_top_fraction_ksat": CASE["q_top_fraction_ksat"],
            "bottom_head_cm": CASE["bottom_head"],
            "horizon_day": HORIZON,
            "direction": CASE["direction"],
        },
        "candidate_step_counts": list(STEP_COUNTS),
        "reference_step_count": REF_STEPS,
        "original_e3_thresholds_unchanged": True,
        "fail_closed_incomplete_trajectory_reporting": True,
        "comparison_available": base["comparison_available"],
        "comparison_unavailable_reason": base["comparison_unavailable_reason"],
        "reference_completed_steps": ref["completed_steps"],
        "candidate_completed_steps": [c["completed_steps"] for c in base["candidates"]],
        "frozen_original_hydrology_pass": base["hydrology_pass"],
        "frozen_original_face_scope_pass": base["face_scope_pass"],
        "reference_top_cell_h0_crossing": ref_top_cross,
        "finest_candidate_top_cell_h0_crossing": cand_top_cross,
        "reference_top_cell_crossing_time_day": ref["crossing_times"][0],
        "finest_candidate_top_cell_crossing_time_day": finest["crossing_times"][0],
        "max_trajectory_head_cm": max_head,
        "max_trajectory_head_guard_cm": MAX_TRAJECTORY_HEAD_CM,
        "added_tests": added_tests,
        "base_comparison": base,
        "pass": passed,
        "decision": (
            "QUALIFIED_RESTRICTED_REAL_H0_SATURATION_TRANSITION_COLUMN_READY_FOR_HETEROGENEOUS_AND_BOUNDARY_QUALIFICATION"
            if passed else
            "REAL_H0_SATURATION_TRANSITION_COLUMN_NOT_QUALIFIED_PRESERVE_FAILURE"
        ),
        "hard_nonclaims": [
            "No production nonlinear solver qualification.",
            "No endpoint-limit response tangent qualification.",
            "No heterogeneous profile qualification.",
            "No production bottom-boundary or groundwater qualification.",
            "No runtime or MultiSWAP production admission."
        ],
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "material": material,
        "pass": passed,
        "decision": result["decision"],
        "comparison_available": base["comparison_available"],
        "comparison_unavailable_reason": base["comparison_unavailable_reason"],
        "reference_completed_steps": ref["completed_steps"],
        "candidate_completed_steps": [c["completed_steps"] for c in base["candidates"]],
        "reference_top_cell_h0_crossing": ref_top_cross,
        "finest_candidate_top_cell_h0_crossing": cand_top_cross,
        "reference_top_cell_crossing_time_day": ref["crossing_times"][0],
        "finest_candidate_top_cell_crossing_time_day": finest["crossing_times"][0],
        "max_trajectory_head_cm": max_head,
        "max_head_difference_cm": base["finest_max_head_difference_cm"],
        "transition_time_difference_day": base["finest_max_transition_time_difference_day"],
        "unqualified_face_fallback_count": base["unqualified_face_fallback_count"],
        "qualification_solver_failure_count": base["qualification_solver_failure_count"],
        "max_abs_step_mass_residual_cm": base["max_abs_step_mass_residual_cm"],
        "max_abs_horizon_mass_residual_cm": base["max_abs_horizon_mass_residual_cm"],
    }, sort_keys=True), flush=True)
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
