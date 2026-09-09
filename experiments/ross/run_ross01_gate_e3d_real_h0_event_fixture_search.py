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

CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = ("B01", "B12", "O13", "O14")
INITIAL_HEADS = (-0.2, -1.5, -5.0)
Q_FRACTIONS = (0.75, 1.0, 1.25, 1.5, 2.0)
HORIZONS = (0.001, 0.002, 0.004)
SEARCH_STEPS = 16
VALIDATE_REF_STEPS = 64
VALIDATE_CANDIDATE_STEPS = 16


def case_for(q_fraction: float):
    return {
        "id": "REAL_H0_WETTING_SEARCH",
        "initial_heads": INITIAL_HEADS,
        "q_top_fraction_ksat": q_fraction,
        "bottom_head": -15.0,
        "direction": "wetting",
    }


def trajectory_summary(traj: dict):
    crossings = [x for x in traj["crossing_times"] if x is not None]
    all_heads = [float(h) for _t, heads in traj["history"] for h in heads]
    return {
        "complete": traj["completed_steps"] == traj["step_count"],
        "crossing_count": len(crossings),
        "first_crossing_day": min(crossings) if crossings else None,
        "max_head_cm": max(all_heads) if all_heads else None,
        "min_head_cm": min(all_heads) if all_heads else None,
        "solver_failure_count": traj["qualification_solver_failure_count"],
        "unqualified_face_fallback_count": traj["unqualified_face_fallback_count"],
        "max_abs_step_mass_residual_cm": traj["max_abs_step_mass_residual_cm"],
        "max_abs_cell_mass_residual_cm": traj["max_abs_cell_mass_residual_cm"],
    }


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_gate_e3d_real_h0_event_fixture_search.py OUTPUT.json")
    out = Path(sys.argv[1])
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    by = {r["sfu"]: r for r in catalog["rows"]}

    original_face = e3.candidate_face
    original_solve = e3.solve_step
    original_horizon = e3.HORIZON
    search_rows = []
    validation_rows = []
    selected = None
    try:
        e3.candidate_face = e3c.expanded_candidate_face
        e3.solve_step = e3c.tight_solve_step

        tables = {}
        for material in MATERIALS:
            e3.configure(by[material])
            tables[material] = e3.generate_c1r_table()

        # Search only with the full-accuracy reference. This is fixture discovery,
        # not qualification. Candidate validation occurs only after one shared
        # forcing/horizon tuple has been selected.
        for q_fraction in Q_FRACTIONS:
            for horizon in HORIZONS:
                per_material = []
                for material in MATERIALS:
                    e3.configure(by[material])
                    e3.HORIZON = horizon
                    traj = e3.run_trajectory(case_for(q_fraction), SEARCH_STEPS, tables[material], candidate=False)
                    s = trajectory_summary(traj)
                    s["material"] = material
                    per_material.append(s)
                shared = all(
                    r["complete"]
                    and r["solver_failure_count"] == 0
                    and r["crossing_count"] >= 1
                    and r["max_head_cm"] is not None
                    and r["max_head_cm"] < 0.8
                    and r["max_abs_step_mass_residual_cm"] <= 1e-9
                    and r["max_abs_cell_mass_residual_cm"] <= 1e-9
                    for r in per_material
                )
                row = {
                    "q_top_fraction_ksat": q_fraction,
                    "horizon_day": horizon,
                    "shared_reference_crossing": shared,
                    "materials": per_material,
                }
                search_rows.append(row)
                print(json.dumps({"phase": "search", "q": q_fraction, "horizon": horizon, "shared": shared}, sort_keys=True), flush=True)

        candidates = [r for r in search_rows if r["shared_reference_crossing"]]
        if candidates:
            # Prefer the least aggressive forcing; then the shortest event window.
            selected = min(candidates, key=lambda r: (r["q_top_fraction_ksat"], r["horizon_day"]))
            q_fraction = float(selected["q_top_fraction_ksat"])
            horizon = float(selected["horizon_day"])
            for material in MATERIALS:
                e3.configure(by[material])
                e3.HORIZON = horizon
                ref = e3.run_trajectory(case_for(q_fraction), VALIDATE_REF_STEPS, tables[material], candidate=False)
                cand = e3.run_trajectory(case_for(q_fraction), VALIDATE_CANDIDATE_STEPS, tables[material], candidate=True)
                rs = trajectory_summary(ref)
                cs = trajectory_summary(cand)
                ref_times = [x for x in ref["crossing_times"] if x is not None]
                cand_times = [x for x in cand["crossing_times"] if x is not None]
                paired = [abs(float(a) - float(b)) for a, b in zip(cand["crossing_times"], ref["crossing_times"]) if a is not None and b is not None]
                validation_rows.append({
                    "material": material,
                    "reference": rs,
                    "candidate": cs,
                    "reference_crossing_times": ref_times,
                    "candidate_crossing_times": cand_times,
                    "max_matched_crossing_time_error_day": max(paired, default=None),
                    "validation_pass": (
                        rs["complete"] and cs["complete"]
                        and rs["crossing_count"] >= 1 and cs["crossing_count"] >= 1
                        and cs["unqualified_face_fallback_count"] == 0
                        and rs["solver_failure_count"] == 0 and cs["solver_failure_count"] == 0
                        and rs["max_abs_step_mass_residual_cm"] <= 1e-9
                        and cs["max_abs_step_mass_residual_cm"] <= 1e-9
                        and rs["max_abs_cell_mass_residual_cm"] <= 1e-9
                        and cs["max_abs_cell_mass_residual_cm"] <= 1e-9
                    ),
                })

    finally:
        e3.candidate_face = original_face
        e3.solve_step = original_solve
        e3.HORIZON = original_horizon

    validation_pass = bool(selected is not None and len(validation_rows) == len(MATERIALS) and all(r["validation_pass"] for r in validation_rows))
    result = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "diagnostic": "E3D_REAL_H0_EVENT_FIXTURE_SEARCH",
        "qualification_use": false,
        "production_implementation": false,
        "search_initial_heads_cm": list(INITIAL_HEADS),
        "search_q_top_fraction_ksat": list(Q_FRACTIONS),
        "search_horizons_day": list(HORIZONS),
        "search_steps": SEARCH_STEPS,
        "search_rows": search_rows,
        "selected_fixture": None if selected is None else {
            "initial_heads_cm": list(INITIAL_HEADS),
            "q_top_fraction_ksat": selected["q_top_fraction_ksat"],
            "bottom_head_cm": -15.0,
            "horizon_day": selected["horizon_day"],
            "direction": "wetting",
        },
        "validation_reference_steps": VALIDATE_REF_STEPS,
        "validation_candidate_steps": VALIDATE_CANDIDATE_STEPS,
        "validation_rows": validation_rows,
        "shared_fixture_found": selected is not None,
        "validation_pass": validation_pass,
        "decision": (
            "REAL_H0_EVENT_FIXTURE_FOUND_READY_FOR_PRECOMMIT_QUALIFICATION_GATE"
            if validation_pass else
            "NO_SHARED_VALIDATED_H0_EVENT_FIXTURE_IN_BOUNDED_SEARCH_EXPAND_DESIGN_SPACE"
        ),
        "hard_nonclaims": [
            "This diagnostic does not qualify saturation transitions.",
            "Search selection is not an acceptance threshold and may not be tuned after the qualification fixture is frozen.",
            "No production nonlinear solver, tangent, groundwater, runtime or MultiSWAP claim follows."
        ],
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "decision": result["decision"],
        "shared_fixture_found": result["shared_fixture_found"],
        "validation_pass": result["validation_pass"],
        "selected_fixture": result["selected_fixture"],
    }, sort_keys=True), flush=True)


if __name__ == "__main__":
    main()
