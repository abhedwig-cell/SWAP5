from __future__ import annotations

import json
import math
import struct
import sys
from collections import Counter
from pathlib import Path

import numpy as np
from scipy.optimize import least_squares

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_e3h_a6_o14_postcap_reference_topology as a6

CONTRACT = "F-ROSS01_GATE_E3H_A7_O14_RESTRICTED_ROSS_CANDIDATE_POST_CAP_RUNOFF_CONTINUATION_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIAL = "O14"
PROFILES = tuple(a6.CAP_STATES)
HSURF = 1.0
SUPPLY_FRAC = 12.0
DT = 0.025
NSTEPS = 40
HORIZON = 1.0
HUP = -1.0e-8
SAT_MARGIN = -0.001
MASS_TOL = 1.0e-9
HEAD_DIFF_TOL = 0.25
RUNOFF_DIFF_TOL = 0.001
BOTTOM_DIFF_TOL = 0.001
STORAGE_DIFF_TOL = 0.001
FINAL_ATTRACTOR_TOL = 0.005
SURFACE_Q_ERR_OVER_KS_TOL = 0.0005
MAX_K_EVALS = 530
MAX_ROOT_EVALS = 66
MAX_NFEV = 200
ATTRACTOR = (-0.19725877123808083, -3.641715902463716, -8.5218470896173)


def bits(heads) -> bytes:
    return struct.pack("!3d", *map(float, heads))


def configure(row: dict) -> None:
    a6.configure(row)


def theta(h: float) -> float:
    return float(a6.theta(float(h)))


def candidate_flux_state(heads, row: dict, table) -> dict:
    h0, h1, h2 = map(float, heads)
    qtop, top_route, top_cost = a6.a1.e3g.surface_face(HSURF, h0, row, True)
    (q01, q12, qb), routes = a6.a1.internal_q(h0, h1, h2, row, True, table)
    qref, ref_branch, ref_res = a6.q_surface_exact(h0, row)
    ks = float(row["ksatfit_cm_per_day"])
    return {
        "qtop": float(qtop), "q01": float(q01), "q12": float(q12), "qb": float(qb),
        "surface_route": str(top_route),
        "surface_cost": {
            "constitutive_K_evaluations": int(top_cost.get("constitutive_K_evaluations", 0)),
            "root_residual_evaluations": int(top_cost.get("root_residual_evaluations", 0)),
        },
        "internal_routes": [str(x) for x in routes],
        "surface_q_exact_reference_cm_per_day": float(qref),
        "surface_q_exact_reference_branch": str(ref_branch),
        "surface_q_exact_reference_residual_cm": float(ref_res),
        "surface_q_abs_error_over_ksat": abs(float(qtop) - float(qref)) / ks,
    }


def reference_flux_state(heads, row: dict) -> dict:
    f = a6.flux_state(heads, row)
    return {
        "qtop": float(f["qtop"]), "q01": float(f["q01"]), "q12": float(f["q12"]), "qb": float(f["qb"]),
        "surface_route": str(f["surface_reference_branch"]),
        "surface_cost": {"constitutive_K_evaluations": 0, "root_residual_evaluations": 0},
        "internal_routes": [str(x) for x in f["internal_routes"]],
        "surface_q_exact_reference_cm_per_day": float(f["qtop"]),
        "surface_q_exact_reference_branch": str(f["surface_reference_branch"]),
        "surface_q_exact_reference_residual_cm": float(f["surface_reference_path_residual_cm"]),
        "surface_q_abs_error_over_ksat": 0.0,
    }


def flux_state(heads, row: dict, candidate: bool, table) -> dict:
    return candidate_flux_state(heads, row, table) if candidate else reference_flux_state(heads, row)


def residual(new_heads, old_heads, dt: float, row: dict, candidate: bool, table):
    f = flux_state(new_heads, row, candidate, table)
    q = (f["qtop"], f["q01"], f["q12"], f["qb"])
    return np.asarray([
        a6.a1.DZ * (theta(float(new_heads[i])) - theta(float(old_heads[i]))) - dt * (q[i] - q[i + 1])
        for i in range(3)
    ], dtype=np.float64)


def solve_step(old_heads, dt: float, row: dict, candidate: bool, table) -> dict:
    snapshot = bits(old_heads)
    try:
        sol = least_squares(
            lambda h: residual(h, old_heads, dt, row, candidate, table),
            np.asarray(old_heads, dtype=np.float64),
            bounds=(np.full(3, -10000.0), np.full(3, HUP)),
            xtol=1e-13, ftol=1e-13, gtol=1e-13,
            max_nfev=MAX_NFEV, x_scale="jac",
        )
        hh = tuple(float(v) for v in sol.x)
        f = flux_state(hh, row, candidate, table)
        r = residual(hh, old_heads, dt, row, candidate, table)
        qsup = SUPPLY_FRAC * float(row["ksatfit_cm_per_day"])
        runoff_rate = qsup - f["qtop"]
        runoff_amount = dt * runoff_rate
        bottom_amount = dt * f["qb"]
        soil_storage = math.fsum(
            a6.a1.DZ * (theta(hh[i]) - theta(float(old_heads[i]))) for i in range(3)
        )
        system = soil_storage + runoff_amount + bottom_amount - dt * qsup
        max_mass = max(max(abs(float(v)) for v in r), abs(system))
        routes = [f["surface_route"], *f["internal_routes"]]
        qualified_routes = not any("UNQUALIFIED" in x for x in routes)
        surface_cost_ok = (
            int(f["surface_cost"]["constitutive_K_evaluations"]) <= MAX_K_EVALS
            and int(f["surface_cost"]["root_residual_evaluations"]) <= MAX_ROOT_EVALS
        )
        surface_accuracy_ok = float(f["surface_q_abs_error_over_ksat"]) <= SURFACE_Q_ERR_OVER_KS_TOL
        finite = all(math.isfinite(v) for v in (*hh, *r, runoff_rate, runoff_amount, bottom_amount, soil_storage, system, max_mass))
        accepted = bool(
            sol.success and finite and max_mass <= MASS_TOL and runoff_rate >= 0.0
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
            "top_below_saturation_margin": hh[0] < SAT_MARGIN,
            "input_state_bitwise_unchanged_during_trial": bits(old_heads) == snapshot,
            "mass_repair_or_clipping_used": False,
        }
    except Exception as exc:
        return {
            "accepted": False,
            "solver_success": False,
            "error": repr(exc),
            "dt_day": dt,
            "input_state_bitwise_unchanged_during_trial": bits(old_heads) == snapshot,
            "mass_repair_or_clipping_used": False,
        }


def trajectory(cap_heads, row: dict, candidate: bool) -> dict:
    configure(row)
    table = a6.a1.e3g.e3.generate_c1r_table() if candidate else None
    heads = tuple(float(v) for v in cap_heads)
    initial = heads
    records = []
    t = 0.0
    cum_runoff = 0.0
    cum_bottom = 0.0
    max_mass = 0.0
    max_h0 = heads[0]
    max_surface_error = 0.0
    max_k = 0
    max_root = 0
    route_counts = Counter()

    for step in range(NSTEPS):
        s = solve_step(heads, DT, row, candidate, table)
        s["step_index"] = step
        s["t0_day"] = t
        s["t1_day"] = t + DT
        records.append(s)
        if not s.get("accepted"):
            return {
                "complete": False,
                "failed_step_index": step,
                "accepted_step_count": step,
                "horizon_day": t,
                "records": records,
                "cumulative_runoff_cm": cum_runoff,
                "cumulative_bottom_transfer_cm": cum_bottom,
                "max_abs_balance_residual_cm": max_mass,
                "max_top_head_cm": max_h0,
                "max_surface_q_abs_error_over_ksat": max_surface_error,
                "max_surface_constitutive_K_evaluations": max_k,
                "max_surface_root_residual_evaluations": max_root,
                "route_counts": dict(route_counts),
            }
        heads = tuple(float(v) for v in s["heads_cm"])
        t += DT
        cum_runoff += float(s["runoff_amount_cm"])
        cum_bottom += float(s["bottom_transfer_cm"])
        max_mass = max(max_mass, float(s["max_abs_balance_residual_cm"]))
        max_h0 = max(max_h0, heads[0])
        f = s["fluxes_cm_per_day"]
        max_surface_error = max(max_surface_error, float(f["surface_q_abs_error_over_ksat"]))
        max_k = max(max_k, int(f["surface_cost"]["constitutive_K_evaluations"]))
        max_root = max(max_root, int(f["surface_cost"]["root_residual_evaluations"]))
        for route in [f["surface_route"], *f["internal_routes"]]:
            route_counts[str(route)] += 1

    final_storage = math.fsum(
        a6.a1.DZ * (theta(heads[i]) - theta(initial[i])) for i in range(3)
    )
    return {
        "complete": True,
        "failed_step_index": None,
        "accepted_step_count": NSTEPS,
        "horizon_day": t,
        "records": records,
        "initial_heads_cm": list(initial),
        "final_heads_cm": list(heads),
        "final_soil_storage_change_cm": float(final_storage),
        "cumulative_runoff_cm": float(cum_runoff),
        "cumulative_bottom_transfer_cm": float(cum_bottom),
        "max_abs_balance_residual_cm": float(max_mass),
        "max_top_head_cm": float(max_h0),
        "max_surface_q_abs_error_over_ksat": float(max_surface_error),
        "max_surface_constitutive_K_evaluations": int(max_k),
        "max_surface_root_residual_evaluations": int(max_root),
        "route_counts": dict(sorted(route_counts.items())),
    }


def compare(candidate: dict, reference: dict) -> dict:
    if not (candidate.get("complete") and reference.get("complete")):
        return {"available": False, "pass": False}
    max_head = 0.0
    for c, r in zip(candidate["records"], reference["records"]):
        max_head = max(max_head, max(abs(float(x) - float(y)) for x, y in zip(c["heads_cm"], r["heads_cm"])))
    runoff_diff = abs(float(candidate["cumulative_runoff_cm"]) - float(reference["cumulative_runoff_cm"]))
    bottom_diff = abs(float(candidate["cumulative_bottom_transfer_cm"]) - float(reference["cumulative_bottom_transfer_cm"]))
    storage_diff = abs(float(candidate["final_soil_storage_change_cm"]) - float(reference["final_soil_storage_change_cm"]))
    cand_attr = max(abs(float(x) - float(y)) for x, y in zip(candidate["final_heads_cm"], ATTRACTOR))
    ref_attr = max(abs(float(x) - float(y)) for x, y in zip(reference["final_heads_cm"], ATTRACTOR))
    tests = {
        "trajectory_head_difference": max_head <= HEAD_DIFF_TOL,
        "cumulative_runoff_difference": runoff_diff <= RUNOFF_DIFF_TOL,
        "cumulative_bottom_transfer_difference": bottom_diff <= BOTTOM_DIFF_TOL,
        "final_soil_storage_difference": storage_diff <= STORAGE_DIFF_TOL,
        "candidate_final_to_independent_attractor": cand_attr <= FINAL_ATTRACTOR_TOL,
        "reference_final_to_independent_attractor": ref_attr <= FINAL_ATTRACTOR_TOL,
    }
    return {
        "available": True,
        "max_trajectory_head_difference_cm": max_head,
        "cumulative_runoff_difference_cm": runoff_diff,
        "cumulative_bottom_transfer_difference_cm": bottom_diff,
        "final_soil_storage_change_difference_cm": storage_diff,
        "candidate_final_to_independent_attractor_max_abs_head_difference_cm": cand_attr,
        "reference_final_to_independent_attractor_max_abs_head_difference_cm": ref_attr,
        "tests": tests,
        "pass": all(tests.values()),
    }


def run_profile(row: dict, profile: str) -> dict:
    cap = a6.CAP_STATES[profile]
    cand = trajectory(cap, row, True)
    ref = trajectory(cap, row, False)
    cmp = compare(cand, ref)

    def trial_guards(traj: dict, candidate: bool) -> bool:
        accepted = [x for x in traj.get("records", []) if x.get("accepted")]
        return bool(
            traj.get("complete")
            and all(x.get("input_state_bitwise_unchanged_during_trial") is True for x in accepted)
            and all(x.get("mass_repair_or_clipping_used") is False for x in accepted)
            and all(float(x.get("runoff_rate_cm_per_day", -1.0)) >= 0.0 for x in accepted)
            and (not candidate or all(x.get("qualified_routes") and x.get("surface_cost_ok") and x.get("surface_accuracy_ok") for x in accepted))
        )

    tests = {
        "candidate_complete_40_steps": cand.get("complete") is True and cand.get("accepted_step_count") == NSTEPS,
        "reference_complete_40_steps": ref.get("complete") is True and ref.get("accepted_step_count") == NSTEPS,
        "candidate_horizon": cand.get("complete") is True and abs(float(cand["horizon_day"]) - HORIZON) <= 1e-14,
        "reference_horizon": ref.get("complete") is True and abs(float(ref["horizon_day"]) - HORIZON) <= 1e-14,
        "candidate_mass": cand.get("complete") is True and float(cand["max_abs_balance_residual_cm"]) <= MASS_TOL,
        "reference_mass": ref.get("complete") is True and float(ref["max_abs_balance_residual_cm"]) <= MASS_TOL,
        "candidate_top_unsaturated": cand.get("complete") is True and float(cand["max_top_head_cm"]) < SAT_MARGIN,
        "reference_top_unsaturated": ref.get("complete") is True and float(ref["max_top_head_cm"]) < SAT_MARGIN,
        "candidate_surface_q_accuracy": cand.get("complete") is True and float(cand["max_surface_q_abs_error_over_ksat"]) <= SURFACE_Q_ERR_OVER_KS_TOL,
        "candidate_surface_cost_K": cand.get("complete") is True and int(cand["max_surface_constitutive_K_evaluations"]) <= MAX_K_EVALS,
        "candidate_surface_cost_root": cand.get("complete") is True and int(cand["max_surface_root_residual_evaluations"]) <= MAX_ROOT_EVALS,
        "candidate_trial_guards": trial_guards(cand, True),
        "reference_trial_guards": trial_guards(ref, False),
        "candidate_reference_comparison": cmp.get("pass") is True,
    }
    return {
        "profile_id": profile,
        "cap_heads_cm": list(cap),
        "candidate": {k: v for k, v in cand.items() if k != "records"},
        "reference": {k: v for k, v in ref.items() if k != "records"},
        "comparison": cmp,
        "tests": tests,
        "failed_metrics": [k for k, v in tests.items() if not v],
        "pass": all(tests.values()),
    }


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_e3h_a7_o14_ross_postcap_runoff_continuation.py PROFILE OUTPUT.json")
    profile = sys.argv[1]
    if profile not in PROFILES:
        raise SystemExit(profile)
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    row = next(r for r in catalog["rows"] if r["sfu"] == MATERIAL)
    pr = run_profile(row, profile)
    payload = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E3H_A7_O14_RESTRICTED_ROSS_CANDIDATE_POST_CAP_RUNOFF_CONTINUATION",
        "contract": CONTRACT,
        "production_implementation": False,
        "qualification_use": True,
        "material": MATERIAL,
        "profile_result": pr,
        "pass": pr["pass"],
        "decision": (
            "QUALIFIED_RESTRICTED_O14_ROSS_POST_CAP_RUNOFF_CONTINUATION_READY_FOR_BROADER_SURFACE_CAP_AND_EVENT_COMPOSITION"
            if pr["pass"] else
            "O14_ROSS_POST_CAP_RUNOFF_CONTINUATION_NOT_QUALIFIED_PRESERVE_REFERENCE_ONLY_ATTRACTOR_QUALIFICATION"
        ),
        "hard_nonclaims": [
            "No automatic runoff-onset detection or changing surface cap.",
            "No other material, surface cap, forcing or bottom boundary.",
            "No response tangent qualification during runoff continuation.",
            "No production implementation, runtime, MultiSWAP, MODFLOW or groundwater admission."
        ],
    }
    out = Path(sys.argv[2])
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "profile": profile,
        "pass": pr["pass"],
        "candidate_steps": pr["candidate"].get("accepted_step_count"),
        "reference_steps": pr["reference"].get("accepted_step_count"),
        "candidate_max_mass_cm": pr["candidate"].get("max_abs_balance_residual_cm"),
        "reference_max_mass_cm": pr["reference"].get("max_abs_balance_residual_cm"),
        "max_head_difference_cm": pr["comparison"].get("max_trajectory_head_difference_cm"),
        "runoff_difference_cm": pr["comparison"].get("cumulative_runoff_difference_cm"),
        "bottom_difference_cm": pr["comparison"].get("cumulative_bottom_transfer_difference_cm"),
        "candidate_final_to_attractor_cm": pr["comparison"].get("candidate_final_to_independent_attractor_max_abs_head_difference_cm"),
        "candidate_max_surface_q_error_over_ksat": pr["candidate"].get("max_surface_q_abs_error_over_ksat"),
        "failed_metrics": pr["failed_metrics"],
        "decision": payload["decision"],
    }, sort_keys=True), flush=True)
    if not pr["pass"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
