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
        base = e3.compare_case(CASE, table)
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
    }
    frozen_original_tests_pass = bool(base["hydrology_pass"] and base["face_scope_pass"])
    passed = bool(frozen_original_tests_pass and all(added_tests.values()))

    result = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E3D_REAL_H0_SATURATION_TRANSITION_COLUMN",
        "contract": CONTRACT,
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
