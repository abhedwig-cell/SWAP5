from __future__ import annotations

import json
import math
import struct
import sys
from pathlib import Path

import numpy as np
from scipy.optimize import least_squares, root

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_e3_saturation_transition_hydrologic_relevance as e3

CONTRACT = "F-ROSS01_GATE_E3B_O14_QUALIFICATION_SOLVER_FAILURE_DIAGNOSTIC_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIAL = "O14"
HARD = 1.0e-9
STRONG = 1.0e-12


def pack(values) -> bytes:
    return b"".join(struct.pack("!d", float(v)) for v in values)


def case_by_id(case_id: str) -> dict:
    return next(c for c in e3.CASES if c["id"] == case_id)


def trial_metrics(heads, old_heads, dt, q_top, bottom_head, table, candidate):
    heads = tuple(float(x) for x in heads)
    finite = all(math.isfinite(x) for x in heads)
    in_bounds = finite and all(-10000.0 <= x <= 1.0 for x in heads)
    if not finite:
        return {"finite": False, "in_bounds": False, "heads": list(heads)}
    try:
        cell = tuple(float(x) for x in e3.residual(heads, old_heads, dt, q_top, bottom_head, table, candidate))
        q, routes = e3.flux_vector(heads, q_top, bottom_head, table, candidate)
        storage = math.fsum(
            e3.DZ * (e3.theta_of_h(heads[i]) - e3.theta_of_h(float(old_heads[i])))
            for i in range(e3.N_CELLS)
        )
        external = dt * (float(q[0]) - float(q[-1]))
        global_res = storage - external
        vals = (*cell, global_res, *q)
        finite_all = all(math.isfinite(float(x)) for x in vals)
        max_cell = max(abs(x) for x in cell)
        return {
            "finite": finite_all,
            "in_bounds": in_bounds,
            "heads": list(heads),
            "cell_residuals_cm": list(cell),
            "max_abs_cell_residual_cm": max_cell,
            "global_residual_cm": global_res,
            "abs_global_residual_cm": abs(global_res),
            "hard_mass_pass": bool(finite_all and in_bounds and max_cell <= HARD and abs(global_res) <= HARD),
            "strong_mass_pass": bool(finite_all and in_bounds and max_cell <= STRONG and abs(global_res) <= STRONG),
            "routes": list(routes),
        }
    except Exception as exc:
        return {"finite": False, "in_bounds": in_bounds, "heads": list(heads), "evaluation_error": repr(exc)}


def solve_variants(old_heads, dt, q_top, bottom_head, table, candidate):
    snapshot = pack(old_heads)
    fun = lambda h: e3.residual(h, old_heads, dt, q_top, bottom_head, table, candidate)
    out = []

    original = least_squares(
        fun, np.asarray(old_heads, dtype=np.float64), bounds=(-10000.0, 1.0),
        xtol=1.0e-12, ftol=1.0e-12, gtol=1.0e-12, max_nfev=e3.MAX_NFEV,
        x_scale="jac",
    )
    rr = trial_metrics(original.x, old_heads, dt, q_top, bottom_head, table, candidate)
    rr.update({
        "solver": "ORIGINAL_LEAST_SQUARES_EXACT_REPRODUCTION",
        "success": bool(original.success), "status": int(original.status), "message": str(original.message),
        "nfev": int(original.nfev), "njev": None if original.njev is None else int(original.njev),
        "cost": float(original.cost), "optimality": float(original.optimality),
    })
    out.append(rr)

    tight = least_squares(
        fun, np.asarray(old_heads, dtype=np.float64), bounds=(-10000.0, 1.0),
        xtol=1.0e-14, ftol=1.0e-14, gtol=1.0e-14, max_nfev=5000,
        x_scale="jac",
    )
    rr = trial_metrics(tight.x, old_heads, dt, q_top, bottom_head, table, candidate)
    rr.update({
        "solver": "TIGHT_LEAST_SQUARES_DIAGNOSTIC_ONLY",
        "success": bool(tight.success), "status": int(tight.status), "message": str(tight.message),
        "nfev": int(tight.nfev), "njev": None if tight.njev is None else int(tight.njev),
        "cost": float(tight.cost), "optimality": float(tight.optimality),
    })
    out.append(rr)

    for method, name, options in (
        ("hybr", "SCIPY_ROOT_HYBR_DIAGNOSTIC_ONLY", {"xtol": 1.0e-12, "maxfev": 5000}),
        ("lm", "SCIPY_ROOT_LM_DIAGNOSTIC_ONLY", {"ftol": 1.0e-13, "xtol": 1.0e-13, "gtol": 1.0e-13, "maxiter": 5000}),
    ):
        try:
            sol = root(fun, np.asarray(old_heads, dtype=np.float64), method=method, options=options)
            rr = trial_metrics(sol.x, old_heads, dt, q_top, bottom_head, table, candidate)
            rr.update({
                "solver": name, "success": bool(sol.success), "status": int(sol.status),
                "message": str(sol.message), "nfev": int(getattr(sol, "nfev", -1)),
            })
        except Exception as exc:
            rr = {"solver": name, "success": False, "exception": repr(exc), "hard_mass_pass": False, "strong_mass_pass": False}
        out.append(rr)

    unchanged = pack(old_heads) == snapshot
    return out, unchanged


def reproduce_failed_trial(case_id: str, step_count: int, candidate: bool, accepted_before: int, table):
    case = case_by_id(case_id)
    dt = e3.HORIZON / step_count
    q_top = float(case["q_top_fraction_ksat"]) * float(e3.core().KSAT)
    bottom_head = float(case["bottom_head"])
    committed = tuple(float(x) for x in case["initial_heads"])
    accepted = []
    for step in range(accepted_before):
        r = e3.solve_step(committed, dt, q_top, bottom_head, table, candidate)
        if not r["accepted"]:
            raise RuntimeError(("failed_before_expected_trial", case_id, step, r))
        committed = tuple(r["heads"])
        accepted.append({"step": step + 1, "heads": list(committed), "max_abs_cell_residual_cm": max(abs(x) for x in r["cell_residuals"]), "abs_global_residual_cm": abs(r["global_mass_residual"])})
    solvers, unchanged = solve_variants(committed, dt, q_top, bottom_head, table, candidate)
    original = next(x for x in solvers if x["solver"].startswith("ORIGINAL_"))
    strong = [x for x in solvers if x.get("strong_mass_pass")]
    hard = [x for x in solvers if x.get("hard_mass_pass")]
    return {
        "id": ("REFERENCE_WETTING_STEP_8_OF_64" if not candidate else "CANDIDATE_DRAINING_STEP_2_OF_16"),
        "case": case_id,
        "candidate_faces": candidate,
        "step_count": step_count,
        "dt_day": dt,
        "accepted_steps_before_failure": accepted_before,
        "accepted_prefix": accepted,
        "old_committed_heads": list(committed),
        "original_failure_reproduced": bool(not original.get("hard_mass_pass", False)),
        "diagnostic_strong_root_count": len(strong),
        "diagnostic_hard_root_count": len(hard),
        "committed_state_unchanged_during_diagnostics": unchanged,
        "solvers": solvers,
    }


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_gate_e3b_o14_qualification_solver_failure_diagnostic.py OUTPUT.json")
    out = Path(sys.argv[1])
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    row = next(r for r in catalog["rows"] if r["sfu"] == MATERIAL)
    e3.configure(row)
    table = e3.generate_c1r_table()

    trials = [
        reproduce_failed_trial("WETTING_TOP_FLUX", 64, False, 7, table),
        reproduce_failed_trial("DRAINING_BOTTOM_HEAD", 16, True, 1, table),
    ]
    original_reproduced = all(t["original_failure_reproduced"] for t in trials)
    strong_resolved = [t["diagnostic_strong_root_count"] > 0 for t in trials]
    if original_reproduced and all(strong_resolved):
        decision = "QUALIFICATION_SOLVER_BLOCKER_CONFIRMED_BOTH_O14_TRIALS_HAVE_INDEPENDENT_STRONG_MASS_ROOT"
    elif original_reproduced and any(strong_resolved):
        decision = "MIXED_O14_BLOCKER_ONLY_SUBSET_HAS_INDEPENDENT_STRONG_MASS_ROOT"
    else:
        decision = "O14_DIAGNOSTIC_DID_NOT_ISOLATE_QUALIFICATION_SOLVER_BLOCKER"
    result = {
        "schema_version": 1,
        "workstream": "F-ROSS", "work_unit": "F-ROSS01", "gate": "E3B_O14_QUALIFICATION_SOLVER_FAILURE_DIAGNOSTIC",
        "contract": CONTRACT, "production_implementation": False, "qualification_use_only": True,
        "material": MATERIAL, "hard_mass_certificate_cm": HARD, "strong_diagnostic_target_cm": STRONG,
        "original_failures_reproduced": original_reproduced,
        "strong_root_found_for_both_trials": all(strong_resolved),
        "trials": trials, "decision": decision,
        "hard_nonclaims": ["No production nonlinear solver qualification.", "No E3 column requalification.", "No physics or mass-tolerance change."]
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"decision": decision, "original_failures_reproduced": original_reproduced, "strong_root_found_for_both_trials": all(strong_resolved), "strong_counts": [t["diagnostic_strong_root_count"] for t in trials]}, sort_keys=True))
    if not original_reproduced:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
