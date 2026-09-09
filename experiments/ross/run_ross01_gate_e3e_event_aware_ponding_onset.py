from __future__ import annotations

import json
import math
import struct
import sys
from pathlib import Path

import numpy as np
from scipy.optimize import least_squares

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_e3_saturation_transition_hydrologic_relevance as e3
import run_ross01_gate_e3c_tight_qualification_solver_policy as e3c

CONTRACT = "F-ROSS01_GATE_E3E_EVENT_AWARE_PONDING_ONSET_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = ("B01", "B12", "O13", "O14")
INITIAL_HEADS = (-0.2, -1.5, -5.0)
INITIAL_SURFACE = 0.0
SUPPLY_FRACTION = 1.5
BOTTOM_HEAD = -15.0
HORIZON = 0.001
STEP_COUNTS = (4, 8, 16)
REF_STEPS = 64
SURFACE_HEAD = 0.0
FLUX_HEAD_TOL = 1.0e-6
MAX_SURFACE_STORAGE = 0.025
MASS_TOL = 1.0e-9
BOTTOM_FLUX_TOL = 1.0e-3
STORAGE_TOL = 1.0e-3
CELL_STORAGE_TOL = 1.0e-3
SURFACE_STORAGE_TOL = 1.0e-3
HEAD_TOL = 0.25
TRANSITION_TIME_TOL = 2.5e-4
MAX_NFEV = 200


def pack_state(heads, surface_storage: float) -> bytes:
    return b"".join(struct.pack("!d", float(v)) for v in (*heads, surface_storage))


def surface_face(h_top: float, table, candidate: bool) -> tuple[float, str]:
    if candidate:
        q, route = e3c.expanded_candidate_face(SURFACE_HEAD, float(h_top), table)
        return float(q), "SURFACE_" + str(route)
    return float(e3.reference_face(SURFACE_HEAD, float(h_top))), "SURFACE_REFERENCE"


def internal_flux_vector(heads, q_top: float, table, candidate: bool):
    flux = [float(q_top)]
    routes = []
    for i in range(e3.N_CELLS - 1):
        if candidate:
            q, route = e3c.expanded_candidate_face(float(heads[i]), float(heads[i + 1]), table)
        else:
            q, route = e3.reference_face(float(heads[i]), float(heads[i + 1])), "REFERENCE"
        flux.append(float(q)); routes.append(str(route))
    if candidate:
        qb, route = e3c.expanded_candidate_face(float(heads[-1]), BOTTOM_HEAD, table)
    else:
        qb, route = e3.reference_face(float(heads[-1]), BOTTOM_HEAD), "REFERENCE"
    flux.append(float(qb)); routes.append(str(route))
    return tuple(flux), tuple(routes)


def trial_fluxes(new_heads, q_supply: float, table, candidate: bool, branch: str):
    if branch == "FLUX":
        q_top = q_supply
        top_route = "SURFACE_PRESCRIBED_FLUX"
    else:
        q_top, top_route = surface_face(float(new_heads[0]), table, candidate)
    q, routes = internal_flux_vector(new_heads, q_top, table, candidate)
    return q, (top_route, *routes)


def soil_residual(new_heads, old_heads, dt: float, q_supply: float, table, candidate: bool, branch: str):
    q, _ = trial_fluxes(new_heads, q_supply, table, candidate, branch)
    res = []
    for i in range(e3.N_CELLS):
        dstore = e3.DZ * (e3.theta_of_h(float(new_heads[i])) - e3.theta_of_h(float(old_heads[i])))
        res.append(dstore - dt * (q[i] - q[i + 1]))
    return np.asarray(res, dtype=np.float64)


def choose_branch(old_heads, old_surface: float, q_supply: float) -> tuple[str, float]:
    if old_surface > 0.0:
        return "HEAD_ONSET", math.inf
    ksat = float(e3.core().KSAT)
    h_required = float(old_heads[0]) + e3.DZ * (q_supply / ksat - 1.0)
    return ("FLUX" if h_required <= FLUX_HEAD_TOL else "HEAD_ONSET"), h_required


def solve_step(old_heads, old_surface: float, dt: float, q_supply: float, table, candidate: bool):
    snapshot = pack_state(old_heads, old_surface)
    branch, h_required = choose_branch(old_heads, old_surface, q_supply)
    fun = lambda h: soil_residual(h, old_heads, dt, q_supply, table, candidate, branch)
    solve = least_squares(
        fun,
        np.asarray(old_heads, dtype=np.float64),
        bounds=(-10000.0, 1.0),
        xtol=1.0e-14,
        ftol=1.0e-14,
        gtol=1.0e-14,
        max_nfev=MAX_NFEV,
        x_scale="jac",
    )
    heads = tuple(float(x) for x in solve.x)
    q, routes = trial_fluxes(heads, q_supply, table, candidate, branch)
    cell_res = tuple(float(x) for x in soil_residual(heads, old_heads, dt, q_supply, table, candidate, branch))
    soil_dstore = math.fsum(
        e3.DZ * (e3.theta_of_h(heads[i]) - e3.theta_of_h(float(old_heads[i])))
        for i in range(e3.N_CELLS)
    )
    soil_global_res = math.fsum([soil_dstore, -dt * (q[0] - q[-1])])

    if branch == "FLUX":
        new_surface = float(old_surface)
    else:
        new_surface = math.fsum([float(old_surface), dt * q_supply, -dt * q[0]])
    surface_res = math.fsum([new_surface, -float(old_surface), -dt * (q_supply - q[0])])
    composed_res = math.fsum([soil_dstore, new_surface - float(old_surface), -dt * (q_supply - q[-1])])

    vals = (*heads, new_surface, *q, *cell_res, soil_global_res, surface_res, composed_res)
    finite = all(math.isfinite(float(v)) for v in vals)
    surface_nonnegative = new_surface >= 0.0
    surface_scope = new_surface <= MAX_SURFACE_STORAGE
    accepted = bool(
        solve.success
        and finite
        and max(abs(x) for x in cell_res) <= MASS_TOL
        and abs(soil_global_res) <= MASS_TOL
        and abs(surface_res) <= MASS_TOL
        and abs(composed_res) <= MASS_TOL
        and surface_nonnegative
        and surface_scope
    )
    return {
        "heads": heads,
        "surface_storage_cm": new_surface,
        "q": q,
        "routes": routes,
        "branch": branch,
        "h_surface_required_predictor_cm": h_required,
        "cell_residuals_cm": cell_res,
        "soil_global_residual_cm": soil_global_res,
        "surface_residual_cm": surface_res,
        "composed_residual_cm": composed_res,
        "nfev": int(solve.nfev),
        "solver_success": bool(solve.success),
        "finite": finite,
        "surface_nonnegative": surface_nonnegative,
        "surface_scope_pass": surface_scope,
        "accepted": accepted,
        "committed_state_bitwise_unchanged_during_trial": pack_state(old_heads, old_surface) == snapshot,
    }


def crossing_time(history):
    for k in range(1, len(history)):
        t0, h0, _s0 = history[k - 1]
        t1, h1, _s1 = history[k]
        if h0[0] < 0.0 <= h1[0]:
            denom = h1[0] - h0[0]
            frac = 1.0 if denom == 0.0 else (0.0 - h0[0]) / denom
            frac = min(1.0, max(0.0, frac))
            return t0 + frac * (t1 - t0)
    return None


def run_trajectory(step_count: int, table, candidate: bool):
    dt = HORIZON / step_count
    q_supply = SUPPLY_FRACTION * float(e3.core().KSAT)
    committed_heads = INITIAL_HEADS
    committed_surface = INITIAL_SURFACE
    initial_snapshot = pack_state(committed_heads, committed_surface)
    history = [(0.0, committed_heads, committed_surface)]
    cumulative_bottom = 0.0
    max_cell_res = max_soil_res = max_surface_res = max_composed_res = 0.0
    max_nfev = 0
    solver_failures = 0
    rejected_mutation = 0
    route_counts = {}
    branch_counts = {"FLUX": 0, "HEAD_ONSET": 0}
    max_surface = committed_surface

    for step in range(step_count):
        before = pack_state(committed_heads, committed_surface)
        r = solve_step(committed_heads, committed_surface, dt, q_supply, table, candidate)
        max_cell_res = max(max_cell_res, max(abs(x) for x in r["cell_residuals_cm"]))
        max_soil_res = max(max_soil_res, abs(r["soil_global_residual_cm"]))
        max_surface_res = max(max_surface_res, abs(r["surface_residual_cm"]))
        max_composed_res = max(max_composed_res, abs(r["composed_residual_cm"]))
        max_nfev = max(max_nfev, r["nfev"])
        solver_failures += int(not r["accepted"])
        if not r["accepted"]:
            rejected_mutation += int(pack_state(committed_heads, committed_surface) != before)
            break
        branch_counts[r["branch"]] += 1
        if candidate:
            for route in r["routes"]:
                route_counts[route] = route_counts.get(route, 0) + 1
        cumulative_bottom += dt * r["q"][-1]
        committed_heads = r["heads"]
        committed_surface = r["surface_storage_cm"]
        max_surface = max(max_surface, committed_surface)
        history.append(((step + 1) * dt, committed_heads, committed_surface))

    initial_soil = math.fsum(e3.storage_cells(INITIAL_HEADS))
    final_soil = math.fsum(e3.storage_cells(committed_heads))
    accepted_time = (len(history) - 1) * dt
    horizon_composed = math.fsum([
        final_soil - initial_soil,
        committed_surface - INITIAL_SURFACE,
        -q_supply * accepted_time,
        cumulative_bottom,
    ])
    return {
        "step_count": step_count,
        "completed_steps": len(history) - 1,
        "history": history,
        "crossing_time_day": crossing_time(history),
        "cumulative_bottom_flux_cm": cumulative_bottom,
        "final_surface_storage_cm": committed_surface,
        "max_surface_storage_cm": max_surface,
        "max_abs_cell_residual_cm": max_cell_res,
        "max_abs_soil_global_residual_cm": max_soil_res,
        "max_abs_surface_residual_cm": max_surface_res,
        "max_abs_composed_step_residual_cm": max_composed_res,
        "abs_composed_horizon_residual_cm": abs(horizon_composed),
        "max_nfev": max_nfev,
        "solver_failure_count": solver_failures,
        "branch_counts": branch_counts,
        "route_counts": route_counts,
        "unqualified_face_fallback_count": sum(v for k, v in route_counts.items() if "UNQUALIFIED_FACE_FALLBACK" in k),
        "committed_state_mutation_on_rejected_trial_count": rejected_mutation,
        "initial_state_bitwise_unchanged_until_first_commit": initial_snapshot == pack_state(INITIAL_HEADS, INITIAL_SURFACE),
    }


def compare_reference(ref, cand):
    if ref["completed_steps"] != ref["step_count"] or cand["completed_steps"] != cand["step_count"]:
        return None
    ref_map = {round(float(t), 15): (tuple(h), float(s)) for t, h, s in ref["history"]}
    max_head = max_soil_store = max_cell_store = max_surface = max_composed_store = 0.0
    for t, heads, surface in cand["history"]:
        key = round(float(t), 15)
        if key not in ref_map:
            return None
        rh, rsurf = ref_map[key]
        max_head = max(max_head, max(abs(float(a) - float(b)) for a, b in zip(heads, rh)))
        cs = e3.storage_cells(heads); cr = e3.storage_cells(rh)
        soil_delta = abs(math.fsum(cs) - math.fsum(cr))
        max_soil_store = max(max_soil_store, soil_delta)
        max_cell_store = max(max_cell_store, max(abs(a - b) for a, b in zip(cs, cr)))
        surface_delta = abs(float(surface) - rsurf)
        max_surface = max(max_surface, surface_delta)
        max_composed_store = max(max_composed_store, abs((math.fsum(cs) + surface) - (math.fsum(cr) + rsurf)))
    return {
        "max_head_difference_cm": max_head,
        "max_soil_storage_difference_cm": max_soil_store,
        "max_soil_cell_storage_difference_cm": max_cell_store,
        "max_surface_storage_difference_cm": max_surface,
        "max_composed_storage_difference_cm": max_composed_store,
        "bottom_flux_difference_cm": abs(cand["cumulative_bottom_flux_cm"] - ref["cumulative_bottom_flux_cm"]),
        "transition_time_difference_day": (
            abs(float(cand["crossing_time_day"]) - float(ref["crossing_time_day"]))
            if cand["crossing_time_day"] is not None and ref["crossing_time_day"] is not None
            else math.inf
        ),
    }


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_e3e_event_aware_ponding_onset.py MATERIAL OUTPUT.json")
    material = sys.argv[1]
    out = Path(sys.argv[2])
    if material not in MATERIALS:
        raise SystemExit(f"material must be one of {MATERIALS}")
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    row = next(r for r in catalog["rows"] if r["sfu"] == material)
    e3.configure(row)
    table = e3.generate_c1r_table()

    ref = run_trajectory(REF_STEPS, table, candidate=False)
    candidates = [run_trajectory(n, table, candidate=True) for n in STEP_COUNTS]
    finest = candidates[-1]
    comparison = compare_reference(ref, finest)

    all_traj = [ref, *candidates]
    max_cell_res = max(t["max_abs_cell_residual_cm"] for t in all_traj)
    max_soil_res = max(t["max_abs_soil_global_residual_cm"] for t in all_traj)
    max_surface_res = max(t["max_abs_surface_residual_cm"] for t in all_traj)
    max_composed_step = max(t["max_abs_composed_step_residual_cm"] for t in all_traj)
    max_composed_horizon = max(t["abs_composed_horizon_residual_cm"] for t in all_traj)
    max_surface_storage = max(t["max_surface_storage_cm"] for t in all_traj)
    unqualified = sum(t["unqualified_face_fallback_count"] for t in candidates)
    solver_failures = sum(t["solver_failure_count"] for t in all_traj)
    mutation = sum(t["committed_state_mutation_on_rejected_trial_count"] for t in all_traj)
    head_branch_count = sum(t["branch_counts"]["HEAD_ONSET"] for t in all_traj)
    positive_surface = any(t["final_surface_storage_cm"] > 0.0 for t in all_traj)
    complete = ref["completed_steps"] == REF_STEPS and all(t["completed_steps"] == t["step_count"] for t in candidates)

    tests = {
        "all_trajectories_complete": complete,
        "solver_failure_count_zero": solver_failures == 0,
        "cell_mass": max_cell_res <= MASS_TOL,
        "soil_mass": max_soil_res <= MASS_TOL,
        "surface_mass": max_surface_res <= MASS_TOL,
        "composed_step_mass": max_composed_step <= MASS_TOL,
        "composed_horizon_mass": max_composed_horizon <= MASS_TOL,
        "surface_scope": max_surface_storage <= MAX_SURFACE_STORAGE,
        "ponding_onset_branch_present": head_branch_count > 0,
        "positive_surface_storage_present": positive_surface,
        "reference_h0_crossing": ref["crossing_time_day"] is not None,
        "finest_candidate_h0_crossing": finest["crossing_time_day"] is not None,
        "face_scope": unqualified == 0,
        "transaction": mutation == 0,
        "comparison_available": comparison is not None,
        "bottom_flux": comparison is not None and comparison["bottom_flux_difference_cm"] <= BOTTOM_FLUX_TOL,
        "composed_storage": comparison is not None and comparison["max_composed_storage_difference_cm"] <= STORAGE_TOL,
        "soil_cell_storage": comparison is not None and comparison["max_soil_cell_storage_difference_cm"] <= CELL_STORAGE_TOL,
        "surface_storage": comparison is not None and comparison["max_surface_storage_difference_cm"] <= SURFACE_STORAGE_TOL,
        "head": comparison is not None and comparison["max_head_difference_cm"] <= HEAD_TOL,
        "transition_time": comparison is not None and comparison["transition_time_difference_day"] <= TRANSITION_TIME_TOL,
    }
    passed = all(tests.values())
    result = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E3E_EVENT_AWARE_PONDING_ONSET_SATURATION_TRANSITION",
        "contract": CONTRACT,
        "material": material,
        "production_implementation": False,
        "qualification_solver_is_production_solver": False,
        "fixture": {
            "initial_soil_heads_cm": list(INITIAL_HEADS),
            "initial_surface_storage_cm": INITIAL_SURFACE,
            "supply_fraction_ksat": SUPPLY_FRACTION,
            "bottom_head_cm": BOTTOM_HEAD,
            "horizon_day": HORIZON,
            "candidate_step_counts": list(STEP_COUNTS),
            "reference_step_count": REF_STEPS,
            "surface_head_in_onset_branch_cm": SURFACE_HEAD,
        },
        "reference": ref,
        "candidates": candidates,
        "finest_comparison": comparison,
        "max_abs_cell_residual_cm": max_cell_res,
        "max_abs_soil_global_residual_cm": max_soil_res,
        "max_abs_surface_residual_cm": max_surface_res,
        "max_abs_composed_step_residual_cm": max_composed_step,
        "max_abs_composed_horizon_residual_cm": max_composed_horizon,
        "max_surface_storage_cm": max_surface_storage,
        "head_onset_branch_count_all_trajectories": head_branch_count,
        "unqualified_face_fallback_count_candidates": unqualified,
        "qualification_solver_failure_count": solver_failures,
        "committed_state_mutation_on_rejected_trial_count": mutation,
        "tests": tests,
        "pass": passed,
        "decision": (
            "QUALIFIED_RESTRICTED_EVENT_AWARE_PONDING_ONSET_SATURATION_TRANSITION_READY_FOR_FINITE_PONDING_AND_HETEROGENEOUS_QUALIFICATION"
            if passed else
            "EVENT_AWARE_PONDING_ONSET_SATURATION_TRANSITION_NOT_QUALIFIED_PRESERVE_FAILURE"
        ),
        "hard_nonclaims": [
            "No finite positive ponding-head feedback or runoff qualification.",
            "No production nonlinear solver qualification.",
            "No tangent, heterogeneous-profile, groundwater, runtime or MultiSWAP admission."
        ],
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "material": material,
        "pass": passed,
        "decision": result["decision"],
        "reference_crossing_time_day": ref["crossing_time_day"],
        "candidate_crossing_time_day": finest["crossing_time_day"],
        "max_surface_storage_cm": max_surface_storage,
        "max_abs_composed_step_residual_cm": max_composed_step,
        "max_abs_composed_horizon_residual_cm": max_composed_horizon,
        "unqualified_face_fallback_count": unqualified,
        "solver_failure_count": solver_failures,
        "comparison": comparison,
    }, sort_keys=True), flush=True)
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
