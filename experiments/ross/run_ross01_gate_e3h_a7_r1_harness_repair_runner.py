from __future__ import annotations

import math
import sys
from pathlib import Path

import numpy as np
from scipy.optimize import least_squares

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_e3h_a7_o14_ross_postcap_runoff_continuation as a7


def candidate_flux_state_pure(heads, row: dict, table) -> dict:
    h0, h1, h2 = map(float, heads)
    qtop, top_route, top_cost = a7.a6.a1.e3g.surface_face(a7.HSURF, h0, row, True)
    (q01, q12, qb), routes = a7.a6.a1.internal_q(h0, h1, h2, row, True, table)
    return {
        "qtop": float(qtop), "q01": float(q01), "q12": float(q12), "qb": float(qb),
        "surface_route": str(top_route),
        "surface_cost": {
            "constitutive_K_evaluations": int(top_cost.get("constitutive_K_evaluations", 0)),
            "root_residual_evaluations": int(top_cost.get("root_residual_evaluations", 0)),
        },
        "internal_routes": [str(x) for x in routes],
    }


def flux_state_pure(heads, row: dict, candidate: bool, table) -> dict:
    return candidate_flux_state_pure(heads, row, table) if candidate else a7.reference_flux_state(heads, row)


def residual_pure(new_heads, old_heads, dt: float, row: dict, candidate: bool, table):
    f = flux_state_pure(new_heads, row, candidate, table)
    q = (f["qtop"], f["q01"], f["q12"], f["qb"])
    return np.asarray([
        a7.a6.a1.DZ * (a7.theta(float(new_heads[i])) - a7.theta(float(old_heads[i]))) - dt * (q[i] - q[i + 1])
        for i in range(3)
    ], dtype=np.float64)


def solve_step_repaired(old_heads, dt: float, row: dict, candidate: bool, table) -> dict:
    snapshot = a7.bits(old_heads)
    try:
        sol = least_squares(
            lambda h: residual_pure(h, old_heads, dt, row, candidate, table),
            np.asarray(old_heads, dtype=np.float64),
            bounds=(np.full(3, -10000.0), np.full(3, a7.HUP)),
            xtol=1e-13, ftol=1e-13, gtol=1e-13,
            max_nfev=a7.MAX_NFEV, x_scale="jac",
        )
        hh = tuple(float(v) for v in sol.x)
        f = flux_state_pure(hh, row, candidate, table)
        r = residual_pure(hh, old_heads, dt, row, candidate, table)
        qsup = a7.SUPPLY_FRAC * float(row["ksatfit_cm_per_day"])
        runoff_rate = qsup - f["qtop"]
        runoff_amount = dt * runoff_rate
        bottom_amount = dt * f["qb"]
        soil_storage = math.fsum(
            a7.a6.a1.DZ * (a7.theta(hh[i]) - a7.theta(float(old_heads[i]))) for i in range(3)
        )
        system = soil_storage + runoff_amount + bottom_amount - dt * qsup
        max_mass = max(max(abs(float(v)) for v in r), abs(system))

        if candidate:
            qref, ref_branch, ref_res = a7.a6.q_surface_exact(hh[0], row)
            ks = float(row["ksatfit_cm_per_day"])
            f["surface_q_exact_reference_cm_per_day"] = float(qref)
            f["surface_q_exact_reference_branch"] = str(ref_branch)
            f["surface_q_exact_reference_residual_cm"] = float(ref_res)
            f["surface_q_abs_error_over_ksat"] = abs(float(f["qtop"]) - float(qref)) / ks
        else:
            f["surface_q_abs_error_over_ksat"] = 0.0

        routes = [f["surface_route"], *f["internal_routes"]]
        qualified_routes = not any("UNQUALIFIED" in x for x in routes)
        surface_cost_ok = (
            int(f["surface_cost"]["constitutive_K_evaluations"]) <= a7.MAX_K_EVALS
            and int(f["surface_cost"]["root_residual_evaluations"]) <= a7.MAX_ROOT_EVALS
        )
        surface_accuracy_ok = float(f["surface_q_abs_error_over_ksat"]) <= a7.SURFACE_Q_ERR_OVER_KS_TOL
        finite = all(math.isfinite(v) for v in (*hh, *r, runoff_rate, runoff_amount, bottom_amount, soil_storage, system, max_mass))
        accepted = bool(
            sol.success and finite and max_mass <= a7.MASS_TOL and runoff_rate >= 0.0
            and (not candidate or (qualified_routes and surface_cost_ok and surface_accuracy_ok))
        )
        return {
            "accepted": accepted,
            "solver_success": bool(sol.success),
            "nfev": int(sol.nfev),
            "dt_day": dt,
            "heads_cm": list(hh),
            "fluxes_cm_per_day": f,
            "runoff_rate_cm_per_day": float(runoff_rate),
            "runoff_amount_cm": float(runoff_amount),
            "bottom_transfer_cm": float(bottom_amount),
            "soil_storage_change_cm": float(soil_storage),
            "cell_residuals_cm": [float(v) for v in r],
            "system_balance_residual_cm": float(system),
            "max_abs_balance_residual_cm": float(max_mass),
            "qualified_routes": qualified_routes,
            "surface_cost_ok": surface_cost_ok,
            "surface_accuracy_ok": surface_accuracy_ok,
            "top_below_saturation_margin": hh[0] < a7.SAT_MARGIN,
            "input_state_bitwise_unchanged_during_trial": a7.bits(old_heads) == snapshot,
            "mass_repair_or_clipping_used": False,
            "qualification_reference_calls_inside_candidate_residual": 0,
            "qualification_reference_calls_after_candidate_convergence": 1 if candidate else 0,
        }
    except Exception as exc:
        return {
            "accepted": False,
            "solver_success": False,
            "error": repr(exc),
            "dt_day": dt,
            "input_state_bitwise_unchanged_during_trial": a7.bits(old_heads) == snapshot,
            "mass_repair_or_clipping_used": False,
        }


a7.solve_step = solve_step_repaired

if __name__ == "__main__":
    a7.main()
