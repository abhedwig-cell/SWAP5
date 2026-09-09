from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import numpy as np
from scipy.optimize import least_squares

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_e3_saturation_transition_hydrologic_relevance as e3
import run_ross01_gate_e3a_r2_two_sided_k_endpoint_limit as e3a_r2

CONTRACT = "F-ROSS01_GATE_E3C_TIGHT_QUALIFICATION_SOLVER_POLICY_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = ("B01", "B12", "O13", "O14")
MASS_TOL = 1.0e-9


def expanded_candidate_face(h_a: float, h_b: float, table):
    if h_a >= 0.0 and h_b >= 0.0:
        return e3.saturated_darcy(h_a, h_b), "SAT_SAT_ANALYTIC"
    if h_a <= -1.0 and h_b <= -1.0:
        if h_a < -10000.0 or h_b < -10000.0:
            return float(e3.core().steady_q(h_a, h_b)), "UNQUALIFIED_FACE_FALLBACK"
        return e3.c1r_flux(h_a, h_b, table), "C1R"

    original_wet_dry = (-1.0 <= h_a <= 1.0 and -10000.0 <= h_b <= -1.0)
    near_near = (-1.0 <= h_a <= 0.0 and -1.0 <= h_b <= 0.0)
    dry_above_wet_below = (-10000.0 <= h_a <= -1.0 and -1.0 <= h_b <= 0.0)
    if original_wet_dry or near_near or dry_above_wet_below:
        try:
            q, cost = e3a_r2.candidate_q(float(h_a), float(h_b))
            return float(q), "E3A_R2_" + str(cost["branch"])
        except Exception:
            return float(e3.core().steady_q(h_a, h_b)), "UNQUALIFIED_FACE_FALLBACK"
    return float(e3.core().steady_q(h_a, h_b)), "UNQUALIFIED_FACE_FALLBACK"


def tight_solve_step(old_heads, dt, q_top, bottom_head, table, candidate):
    snapshot = e3.pack(old_heads)
    fun = lambda h: e3.residual(h, old_heads, dt, q_top, bottom_head, table, candidate)
    solve = least_squares(
        fun, np.asarray(old_heads, dtype=np.float64), bounds=(-10000.0, 1.0),
        xtol=1.0e-14, ftol=1.0e-14, gtol=1.0e-14, max_nfev=e3.MAX_NFEV,
        x_scale="jac",
    )
    heads = tuple(float(x) for x in solve.x)
    q, routes = e3.flux_vector(heads, q_top, bottom_head, table, candidate)
    cell_res = tuple(float(x) for x in e3.residual(heads, old_heads, dt, q_top, bottom_head, table, candidate))
    global_storage = math.fsum(
        e3.DZ * (e3.theta_of_h(heads[i]) - e3.theta_of_h(float(old_heads[i]))) for i in range(e3.N_CELLS)
    )
    global_external = dt * (q[0] - q[-1])
    global_res = global_storage - global_external
    finite = all(math.isfinite(v) for v in (*heads, *q, *cell_res, global_res))
    accepted = bool(solve.success and finite and max(abs(x) for x in cell_res) <= MASS_TOL and abs(global_res) <= MASS_TOL)
    return {
        "heads": heads, "q": q, "routes": routes, "cell_residuals": cell_res,
        "global_mass_residual": global_res, "nfev": int(solve.nfev),
        "solver_success": bool(solve.success), "finite": finite, "accepted": accepted,
        "base_state_bitwise_unchanged_during_trial": e3.pack(old_heads) == snapshot,
    }


def compare(case, table):
    ref = e3.run_trajectory(case, e3.REF_STEPS, table, candidate=False)
    candidates = [e3.run_trajectory(case, n, table, candidate=True) for n in e3.STEP_COUNTS]
    finest = candidates[-1]
    complete = ref["completed_steps"] == e3.REF_STEPS and all(c["completed_steps"] == c["step_count"] for c in candidates)
    if complete:
        max_head, max_storage, max_cell_storage = e3.interpolate_reference(ref, finest)
        bottom_error = abs(finest["cumulative_bottom_flux_cm"] - ref["cumulative_bottom_flux_cm"])
    else:
        max_head = max_storage = max_cell_storage = bottom_error = math.inf
    max_cell_mass = max([ref["max_abs_cell_mass_residual_cm"]] + [c["max_abs_cell_mass_residual_cm"] for c in candidates])
    max_step_mass = max([ref["max_abs_step_mass_residual_cm"]] + [c["max_abs_step_mass_residual_cm"] for c in candidates])
    unqualified = sum(c["unqualified_face_fallback_count"] for c in candidates)
    failures = ref["qualification_solver_failure_count"] + sum(c["qualification_solver_failure_count"] for c in candidates)
    mutation = ref["committed_state_mutation_on_rejected_trial_count"] + sum(c["committed_state_mutation_on_rejected_trial_count"] for c in candidates)
    tests = {
        "all_steps_complete": complete,
        "solver_failure_count": failures == 0,
        "cell_mass": max_cell_mass <= 1.0e-9,
        "step_mass": max_step_mass <= 1.0e-9,
        "face_scope": unqualified == 0,
        "bottom_flux": bottom_error <= 1.0e-3,
        "total_storage": max_storage <= 1.0e-3,
        "cell_storage": max_cell_storage <= 1.0e-3,
        "head": max_head <= 0.25,
        "transaction": mutation == 0,
    }
    return {
        "case": case["id"], "pass": all(tests.values()), "tests": tests,
        "reference_completed_steps": ref["completed_steps"],
        "candidate_completed_steps": [c["completed_steps"] for c in candidates],
        "max_abs_cell_mass_residual_cm": max_cell_mass,
        "max_abs_step_mass_residual_cm": max_step_mass,
        "finest_bottom_flux_difference_cm": bottom_error,
        "finest_max_head_difference_cm": max_head,
        "finest_max_total_storage_difference_cm": max_storage,
        "finest_max_cell_storage_difference_cm": max_cell_storage,
        "unqualified_face_fallback_count": unqualified,
        "qualification_solver_failure_count": failures,
        "reference_transition_count": sum(x is not None for x in ref["crossing_times"]),
        "candidate_transition_count": sum(x is not None for x in finest["crossing_times"]),
        "max_qualification_solver_nfev": max([ref["max_qualification_solver_nfev"]] + [c["max_qualification_solver_nfev"] for c in candidates]),
    }


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_gate_e3c_tight_qualification_solver_policy.py OUTPUT.json")
    out = Path(sys.argv[1])
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    by = {r["sfu"]: r for r in catalog["rows"]}
    original_face = e3.candidate_face
    original_solve = e3.solve_step
    results = []
    try:
        e3.candidate_face = expanded_candidate_face
        e3.solve_step = tight_solve_step
        for m in MATERIALS:
            e3.configure(by[m])
            table = e3.generate_c1r_table()
            cases = [compare(c, table) for c in e3.CASES]
            results.append({"material": m, "cases": cases, "pass": all(c["pass"] for c in cases)})
            print(json.dumps({"material": m, "pass": results[-1]["pass"], "cases": [{"case": c["case"], "pass": c["pass"], "max_step_mass": c["max_abs_step_mass_residual_cm"], "unqualified": c["unqualified_face_fallback_count"], "solver_failures": c["qualification_solver_failure_count"]} for c in cases]}, sort_keys=True), flush=True)
    finally:
        e3.candidate_face = original_face
        e3.solve_step = original_solve

    passed = all(r["pass"] for r in results)
    result = {
        "schema_version": 1, "workstream": "F-ROSS", "work_unit": "F-ROSS01",
        "gate": "E3C_TIGHT_LEAST_SQUARES_QUALIFICATION_SOLVER_POLICY", "contract": CONTRACT,
        "production_implementation": False, "qualification_solver_is_production_solver": False,
        "solver_policy": {"xtol": 1e-14, "ftol": 1e-14, "gtol": 1e-14, "max_nfev": e3.MAX_NFEV, "x_scale": "jac"},
        "mass_certificate_cm": 1e-9,
        "results": results,
        "event_crossing_required": False,
        "pass": passed,
        "decision": "QUALIFIED_TIGHT_E3_QUALIFICATION_SOLVER_AND_ENCOUNTERED_FACE_COMPOSITION_READY_FOR_REAL_SATURATION_EVENT_FIXTURE" if passed else "E3_QUALIFICATION_SOLVER_OR_FACE_COMPOSITION_NOT_READY_RESEARCH_REQUIRED",
        "hard_nonclaims": ["No saturation-transition qualification because no h=0 event is required here.", "No production nonlinear solver qualification.", "No tangent/runtime/MultiSWAP qualification."]
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"pass": passed, "decision": result["decision"], "material_pass_count": sum(r["pass"] for r in results)}, sort_keys=True))
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
