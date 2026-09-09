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

import run_ross01_gate_j1a_real_table_face_derivative as j1a
import run_ross01_gate_e2c_r3_endpoint_limit_holdout as r3

CONTRACT = "F-ROSS01_GATE_E3_RESTRICTED_SATURATION_TRANSITION_HYDROLOGIC_RELEVANCE_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = ("B01", "B12", "O13", "O14")
DZ = 10.0
N_CELLS = 3
HORIZON = 0.002
STEP_COUNTS = (4, 8, 16)
REF_STEPS = 64
MASS_TOL = 1.0e-9
BOTTOM_FLUX_TOL = 1.0e-3
STORAGE_TOL = 1.0e-3
CELL_STORAGE_TOL = 1.0e-3
HEAD_TOL = 0.25
TRANSITION_TIME_TOL = 2.5e-4
MAX_NFEV = 200

CASES = (
    {
        "id": "WETTING_TOP_FLUX",
        "initial_heads": (-0.2, -1.5, -5.0),
        "q_top_fraction_ksat": 0.5,
        "bottom_head": -15.0,
        "direction": "wetting",
    },
    {
        "id": "DRAINING_BOTTOM_HEAD",
        "initial_heads": (0.2, 0.05, -1.5),
        "q_top_fraction_ksat": 0.0,
        "bottom_head": -15.0,
        "direction": "drying",
    },
)


def pack(values) -> bytes:
    return b"".join(struct.pack("!d", float(v)) for v in values)


def core():
    return j1a.c1r.base.c1.core


def theta_of_h(h: float) -> float:
    c = core()
    if h >= 0.0:
        return float(c.THETA_S)
    s = float(c.s_of_h(h))
    return float(c.THETA_R + (c.THETA_S - c.THETA_R) * s)


def storage_cells(heads) -> tuple[float, ...]:
    return tuple(DZ * theta_of_h(float(h)) for h in heads)


def saturated_darcy(h_a: float, h_b: float) -> float:
    return float(core().KSAT) * (1.0 - (h_b - h_a) / DZ)


def configure(row: dict):
    j1a.c1r.base.c1.configure_core(row)
    # R3/e2c use the same mutable constitutive core; configure explicitly too.
    r3.e2c.configure(row)


def generate_c1r_table():
    table, _seconds, failures = j1a.c1r.base.generate_table(j1a.N)
    if failures:
        raise RuntimeError(("C1R_table_generation_failure", len(failures)))
    return table


def c1r_flux(h_a: float, h_b: float, table) -> float:
    sa = float(core().s_of_h(h_a)); sb = float(core().s_of_h(h_b))
    q, _, _ = j1a.c1r.lookup(sa, sb, table, j1a.N)
    return float(q)


def candidate_face(h_a: float, h_b: float, table) -> tuple[float, str]:
    if h_a >= 0.0 and h_b >= 0.0:
        return saturated_darcy(h_a, h_b), "SAT_SAT_ANALYTIC"
    if h_a <= -1.0 and h_b <= -1.0:
        if h_a < -10000.0 or h_b < -10000.0:
            return float(core().steady_q(h_a, h_b)), "UNQUALIFIED_FACE_FALLBACK"
        return c1r_flux(h_a, h_b, table), "C1R"
    if -1.0 <= h_a <= 1.0 and h_b <= -1.0 and h_b >= -10000.0:
        q, meta = r3.endpoint_limit_candidate(h_a, h_b)
        return float(q), "R3_" + str(meta["branch"])
    # Explicit fail-closed qualification fallback. It preserves the trajectory for
    # diagnosis but prevents a full E3 PASS.
    return float(core().steady_q(h_a, h_b)), "UNQUALIFIED_FACE_FALLBACK"


def reference_face(h_a: float, h_b: float) -> float:
    if h_a >= 0.0 and h_b >= 0.0:
        return saturated_darcy(h_a, h_b)
    return float(core().steady_q(h_a, h_b))


def flux_vector(heads, q_top: float, bottom_head: float, table, candidate: bool):
    flux = [float(q_top)]
    routes = []
    for i in range(N_CELLS - 1):
        if candidate:
            q, route = candidate_face(float(heads[i]), float(heads[i + 1]), table)
        else:
            q, route = reference_face(float(heads[i]), float(heads[i + 1])), "REFERENCE"
        flux.append(float(q)); routes.append(route)
    if candidate:
        qb, route = candidate_face(float(heads[-1]), float(bottom_head), table)
    else:
        qb, route = reference_face(float(heads[-1]), float(bottom_head)), "REFERENCE"
    flux.append(float(qb)); routes.append(route)
    return tuple(flux), tuple(routes)


def residual(new_heads, old_heads, dt, q_top, bottom_head, table, candidate):
    q, _ = flux_vector(new_heads, q_top, bottom_head, table, candidate)
    res = []
    for i in range(N_CELLS):
        storage = DZ * (theta_of_h(float(new_heads[i])) - theta_of_h(float(old_heads[i])))
        external = dt * (q[i] - q[i + 1])
        res.append(storage - external)
    return np.asarray(res, dtype=np.float64)


def solve_step(old_heads, dt, q_top, bottom_head, table, candidate):
    snapshot = pack(old_heads)
    fun = lambda h: residual(h, old_heads, dt, q_top, bottom_head, table, candidate)
    solve = least_squares(
        fun, np.asarray(old_heads, dtype=np.float64), bounds=(-10000.0, 1.0),
        xtol=1.0e-12, ftol=1.0e-12, gtol=1.0e-12, max_nfev=MAX_NFEV,
        x_scale="jac",
    )
    heads = tuple(float(x) for x in solve.x)
    q, routes = flux_vector(heads, q_top, bottom_head, table, candidate)
    cell_res = tuple(float(x) for x in residual(heads, old_heads, dt, q_top, bottom_head, table, candidate))
    global_storage = math.fsum(
        DZ * (theta_of_h(heads[i]) - theta_of_h(float(old_heads[i]))) for i in range(N_CELLS)
    )
    global_external = dt * (q[0] - q[-1])
    global_res = global_storage - global_external
    finite = all(math.isfinite(v) for v in (*heads, *q, *cell_res, global_res))
    accepted = bool(solve.success and finite and max(abs(x) for x in cell_res) <= MASS_TOL and abs(global_res) <= MASS_TOL)
    return {
        "heads": heads,
        "q": q,
        "routes": routes,
        "cell_residuals": cell_res,
        "global_mass_residual": global_res,
        "nfev": int(solve.nfev),
        "solver_success": bool(solve.success),
        "finite": finite,
        "accepted": accepted,
        "base_state_bitwise_unchanged_during_trial": pack(old_heads) == snapshot,
    }


def crossing_times(history, direction: str):
    out = [None] * N_CELLS
    for k in range(1, len(history)):
        t0, h0 = history[k - 1]; t1, h1 = history[k]
        for i in range(N_CELLS):
            if out[i] is not None:
                continue
            crossed = (direction == "wetting" and h0[i] < 0.0 <= h1[i]) or (direction == "drying" and h0[i] >= 0.0 > h1[i])
            if crossed:
                # Linear-in-head interpolation is diagnostic only; it gives a less
                # grid-quantized transition-time observable than step endpoints.
                denom = h1[i] - h0[i]
                frac = 1.0 if denom == 0.0 else (0.0 - h0[i]) / denom
                frac = min(1.0, max(0.0, frac))
                out[i] = t0 + frac * (t1 - t0)
    return tuple(out)


def run_trajectory(case, step_count: int, table, candidate: bool):
    dt = HORIZON / step_count
    q_top = float(case["q_top_fraction_ksat"]) * float(core().KSAT)
    bottom_head = float(case["bottom_head"])
    committed = tuple(float(x) for x in case["initial_heads"])
    initial_snapshot = pack(committed)
    history = [(0.0, committed)]
    bottom_cumulative = 0.0
    max_step_mass = 0.0
    max_cell_mass = 0.0
    max_nfev = 0
    nonfinite = 0
    solver_failures = 0
    route_counts = {}
    rejected_mutation = 0

    for step in range(step_count):
        result = solve_step(committed, dt, q_top, bottom_head, table, candidate)
        max_step_mass = max(max_step_mass, abs(result["global_mass_residual"]))
        max_cell_mass = max(max_cell_mass, max(abs(x) for x in result["cell_residuals"]))
        max_nfev = max(max_nfev, result["nfev"])
        nonfinite += int(not result["finite"])
        solver_failures += int(not result["accepted"])
        if not result["accepted"]:
            # rejected trial never commits
            rejected_mutation += int(pack(committed) != pack(history[-1][1]))
            break
        if candidate:
            for route in result["routes"]:
                route_counts[route] = route_counts.get(route, 0) + 1
        bottom_cumulative += dt * result["q"][-1]
        committed = result["heads"]
        history.append(((step + 1) * dt, committed))

    final_storage = math.fsum(storage_cells(committed))
    initial_storage = math.fsum(storage_cells(case["initial_heads"]))
    horizon_external = q_top * (len(history) - 1) * dt - bottom_cumulative
    horizon_mass = (final_storage - initial_storage) - horizon_external

    # Intentional rejected-trial lifecycle check after the accepted trajectory.
    before_reject = pack(committed)
    if len(history) > 1:
        _discarded = solve_step(committed, dt, q_top, bottom_head, table, candidate)
    after_reject = pack(committed)
    rejected_mutation += int(before_reject != after_reject)

    return {
        "step_count": step_count,
        "dt_day": dt,
        "completed_steps": len(history) - 1,
        "heads_final": list(committed),
        "history": [(t, list(h)) for t, h in history],
        "crossing_times": list(crossing_times(history, case["direction"])),
        "cumulative_bottom_flux_cm": bottom_cumulative,
        "final_total_storage_cm": final_storage,
        "final_cell_storage_cm": list(storage_cells(committed)),
        "max_abs_step_mass_residual_cm": max_step_mass,
        "max_abs_cell_mass_residual_cm": max_cell_mass,
        "abs_horizon_mass_residual_cm": abs(horizon_mass),
        "max_qualification_solver_nfev": max_nfev,
        "qualification_solver_failure_count": solver_failures,
        "nonfinite_count": nonfinite,
        "route_counts": route_counts,
        "unqualified_face_fallback_count": route_counts.get("UNQUALIFIED_FACE_FALLBACK", 0),
        "initial_state_bitwise_unchanged_until_commit": initial_snapshot == pack(case["initial_heads"]),
        "committed_state_mutation_on_rejected_trial_count": rejected_mutation,
    }


def interpolate_reference(ref, candidate):
    ref_map = {round(float(t), 15): tuple(h) for t, h in ref["history"]}
    max_head = 0.0
    max_storage = 0.0
    max_cell_storage = 0.0
    for t, heads in candidate["history"]:
        rh = ref_map[round(float(t), 15)]
        max_head = max(max_head, max(abs(float(a) - float(b)) for a, b in zip(heads, rh)))
        cs = storage_cells(heads); rs = storage_cells(rh)
        max_storage = max(max_storage, abs(math.fsum(cs) - math.fsum(rs)))
        max_cell_storage = max(max_cell_storage, max(abs(a - b) for a, b in zip(cs, rs)))
    return max_head, max_storage, max_cell_storage


def compare_case(case, table):
    ref = run_trajectory(case, REF_STEPS, table, candidate=False)
    candidates = [run_trajectory(case, n, table, candidate=True) for n in STEP_COUNTS]
    finest = candidates[-1]
    max_head, max_storage, max_cell_storage = interpolate_reference(ref, finest)
    bottom_error = abs(finest["cumulative_bottom_flux_cm"] - ref["cumulative_bottom_flux_cm"])

    c_times = finest["crossing_times"]; r_times = ref["crossing_times"]
    matched_time_errors = [abs(float(c)-float(r)) for c, r in zip(c_times, r_times) if c is not None and r is not None]
    candidate_event_count = sum(x is not None for x in c_times)
    reference_event_count = sum(x is not None for x in r_times)
    transition_time_error = max(matched_time_errors, default=math.inf if candidate_event_count or reference_event_count else 0.0)

    max_step_mass = max(x["max_abs_step_mass_residual_cm"] for x in candidates)
    max_horizon_mass = max(x["abs_horizon_mass_residual_cm"] for x in candidates)
    unqualified = sum(x["unqualified_face_fallback_count"] for x in candidates)
    nonfinite = sum(x["nonfinite_count"] for x in candidates) + ref["nonfinite_count"]
    solver_failures = sum(x["qualification_solver_failure_count"] for x in candidates) + ref["qualification_solver_failure_count"]
    mutation = sum(x["committed_state_mutation_on_rejected_trial_count"] for x in candidates) + ref["committed_state_mutation_on_rejected_trial_count"]

    hydrology_tests = {
        "step_mass": max_step_mass <= MASS_TOL,
        "horizon_mass": max_horizon_mass <= MASS_TOL,
        "bottom_flux": bottom_error <= BOTTOM_FLUX_TOL,
        "storage": max_storage <= STORAGE_TOL,
        "cell_storage": max_cell_storage <= CELL_STORAGE_TOL,
        "head": max_head <= HEAD_TOL,
        "transition_time": transition_time_error <= TRANSITION_TIME_TOL,
        "candidate_transition_present": candidate_event_count >= 1,
        "reference_transition_present": reference_event_count >= 1,
        "nonfinite": nonfinite == 0,
        "solver_complete": solver_failures == 0,
        "transaction": mutation == 0,
    }
    hydrology_pass = all(hydrology_tests.values())
    face_scope_pass = unqualified == 0
    if hydrology_pass and face_scope_pass:
        decision = "QUALIFIED_RESTRICTED_PHYSICAL_SATURATION_TRANSITION_COLUMN_READY_FOR_HETEROGENEOUS_AND_BOUNDARY_QUALIFICATION"
    elif hydrology_pass:
        decision = "HYDROLOGICALLY_ACCEPTABLE_SATURATION_TRANSITION_FACE_SCOPE_GAP_REQUIRES_EXPLICIT_FACE_QUALIFICATION"
    else:
        decision = "SATURATION_TRANSITION_PHYSICAL_COLUMN_NOT_QUALIFIED_RESEARCH_REQUIRED"
    return {
        "case": case["id"],
        "direction": case["direction"],
        "reference": ref,
        "candidates": candidates,
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
        raise SystemExit("usage: run_ross01_gate_e3_saturation_transition_hydrologic_relevance.py MATERIAL OUTPUT.json")
    material = sys.argv[1]
    out = Path(sys.argv[2])
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    by = {r["sfu"]: r for r in catalog["rows"]}
    if material not in MATERIALS:
        raise SystemExit(f"material must be one of {MATERIALS}")
    configure(by[material])
    table = generate_c1r_table()
    cases = [compare_case(case, table) for case in CASES]
    hydrology_pass = all(c["hydrology_pass"] for c in cases)
    face_scope_pass = all(c["face_scope_pass"] for c in cases)
    if hydrology_pass and face_scope_pass:
        decision = "QUALIFIED_RESTRICTED_PHYSICAL_SATURATION_TRANSITION_COLUMN_READY_FOR_HETEROGENEOUS_AND_BOUNDARY_QUALIFICATION"
    elif hydrology_pass:
        decision = "HYDROLOGICALLY_ACCEPTABLE_SATURATION_TRANSITION_FACE_SCOPE_GAP_REQUIRES_EXPLICIT_FACE_QUALIFICATION"
    else:
        decision = "SATURATION_TRANSITION_PHYSICAL_COLUMN_NOT_QUALIFIED_RESEARCH_REQUIRED"
    result = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E3_RESTRICTED_SATURATION_TRANSITION_COLUMN_HYDROLOGIC_RELEVANCE",
        "contract": CONTRACT,
        "material": material,
        "production_implementation": False,
        "qualification_solver_is_production_solver": False,
        "case_count": len(cases),
        "cases": cases,
        "hydrology_pass": hydrology_pass,
        "face_scope_pass": face_scope_pass,
        "pass": hydrology_pass and face_scope_pass,
        "decision": decision,
        "hard_nonclaims": [
            "No production nonlinear solver qualification.",
            "No response tangent qualification across saturation or endpoint-limit branches.",
            "No heterogeneous profile, production bottom boundary, groundwater, runtime or MultiSWAP qualification."
        ]
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "material": material,
        "hydrology_pass": hydrology_pass,
        "face_scope_pass": face_scope_pass,
        "pass": result["pass"],
        "decision": decision,
        "cases": [{
            "case": c["case"],
            "hydrology_pass": c["hydrology_pass"],
            "face_scope_pass": c["face_scope_pass"],
            "unqualified_face_fallback_count": c["unqualified_face_fallback_count"],
            "bottom_flux_error_cm": c["finest_cumulative_bottom_flux_difference_cm"],
            "storage_error_cm": c["finest_max_total_storage_difference_cm"],
            "head_error_cm": c["finest_max_head_difference_cm"],
            "transition_time_error_day": c["finest_max_transition_time_difference_day"],
            "max_step_mass_cm": c["max_abs_step_mass_residual_cm"],
        } for c in cases]
    }, sort_keys=True), flush=True)
    # A face-scope gap is a completed, useful characterization. A hydrologic failure
    # is a scientific gate failure and returns nonzero.
    if not hydrology_pass:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
