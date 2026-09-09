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
import run_ross01_gate_e3c_tight_qualification_solver_policy as e3c

CONTRACT = "F-ROSS01_GATE_E3D_R1_O14_EVENT_ROOT_DIAGNOSTIC_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIAL = "O14"
INITIAL = (-0.2, -1.5, -5.0)
BOTTOM_HEAD = -15.0
Q_FRAC = 1.5
HORIZON = 0.001
HARD = 1.0e-9
STRONG = 1.0e-12
STARTS = (
    (-0.2, -1.5, -5.0),
    (-0.1, -1.5, -5.0),
    (-0.01, -1.5, -5.0),
    (0.01, -1.5, -5.0),
    (0.1, -1.5, -5.0),
)
TRIALS = ((False, 64), (True, 4), (True, 8), (True, 16))


def pack(values) -> bytes:
    return b"".join(struct.pack("!d", float(v)) for v in values)


def metrics(heads, old_heads, dt, q_top, table, candidate):
    heads = tuple(float(x) for x in heads)
    finite = all(math.isfinite(x) for x in heads)
    in_bounds = finite and all(-10000.0 <= x <= 1.0 for x in heads)
    if not finite:
        return {"finite": False, "in_bounds": False, "heads_cm": list(heads), "strong_mass_pass": False, "hard_mass_pass": False}
    try:
        cell = tuple(float(x) for x in e3.residual(heads, old_heads, dt, q_top, BOTTOM_HEAD, table, candidate))
        q, routes = e3.flux_vector(heads, q_top, BOTTOM_HEAD, table, candidate)
        storage = math.fsum(e3.DZ * (e3.theta_of_h(heads[i]) - e3.theta_of_h(old_heads[i])) for i in range(e3.N_CELLS))
        external = dt * (float(q[0]) - float(q[-1]))
        global_res = storage - external
        max_cell = max(abs(x) for x in cell)
        all_finite = all(math.isfinite(float(x)) for x in (*cell, *q, global_res))
        unqualified = sum(r == "UNQUALIFIED_FACE_FALLBACK" for r in routes) if candidate else 0
        hard = bool(all_finite and in_bounds and max_cell <= HARD and abs(global_res) <= HARD and unqualified == 0)
        strong = bool(all_finite and in_bounds and max_cell <= STRONG and abs(global_res) <= STRONG and unqualified == 0)
        return {
            "finite": all_finite,
            "in_bounds": in_bounds,
            "heads_cm": list(heads),
            "top_head_cm": heads[0],
            "top_head_sign": "SATURATED_SIDE" if heads[0] >= 0.0 else "UNSATURATED_SIDE",
            "cell_residuals_cm": list(cell),
            "max_abs_cell_residual_cm": max_cell,
            "global_residual_cm": global_res,
            "abs_global_residual_cm": abs(global_res),
            "routes": list(routes),
            "unqualified_face_fallback_count": unqualified,
            "hard_mass_pass": hard,
            "strong_mass_pass": strong,
        }
    except Exception as exc:
        return {"finite": False, "in_bounds": in_bounds, "heads_cm": list(heads), "evaluation_error": repr(exc), "hard_mass_pass": False, "strong_mass_pass": False}


def solve_all_starts(old_heads, dt, q_top, table, candidate):
    snapshot = pack(old_heads)
    fun = lambda h: e3.residual(h, old_heads, dt, q_top, BOTTOM_HEAD, table, candidate)
    rows = []
    for start in STARTS:
        ls = least_squares(
            fun, np.asarray(start, dtype=np.float64), bounds=(-10000.0, 1.0),
            xtol=1.0e-14, ftol=1.0e-14, gtol=1.0e-14,
            max_nfev=5000, x_scale="jac"
        )
        r = metrics(ls.x, old_heads, dt, q_top, table, candidate)
        r.update({"solver":"TIGHT_BOUNDED_LEAST_SQUARES","start_heads_cm":list(start),"success":bool(ls.success),"status":int(ls.status),"message":str(ls.message),"nfev":int(ls.nfev),"cost":float(ls.cost),"optimality":float(ls.optimality)})
        rows.append(r)
        for method, name, options in (
            ("hybr", "SCIPY_ROOT_HYBR", {"xtol":1e-12,"maxfev":5000}),
            ("lm", "SCIPY_ROOT_LM", {"ftol":1e-13,"xtol":1e-13,"gtol":1e-13,"maxiter":5000}),
        ):
            try:
                sol = root(fun, np.asarray(start, dtype=np.float64), method=method, options=options)
                rr = metrics(sol.x, old_heads, dt, q_top, table, candidate)
                rr.update({"solver":name,"start_heads_cm":list(start),"success":bool(sol.success),"status":int(sol.status),"message":str(sol.message),"nfev":int(getattr(sol,"nfev",-1))})
            except Exception as exc:
                rr = {"solver":name,"start_heads_cm":list(start),"success":False,"exception":repr(exc),"hard_mass_pass":False,"strong_mass_pass":False}
            rows.append(rr)
    return rows, pack(old_heads) == snapshot


def unique_strong_roots(rows):
    roots = []
    for r in rows:
        if not r.get("strong_mass_pass"):
            continue
        h = tuple(round(float(x), 10) for x in r["heads_cm"])
        if h not in roots:
            roots.append(h)
    return roots


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_ross01_gate_e3d_r1_o14_event_root_diagnostic.py OUTPUT.json")
    out = Path(sys.argv[1])
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    row = next(r for r in catalog["rows"] if r["sfu"] == MATERIAL)
    e3.configure(row)
    table = e3.generate_c1r_table()
    q_top = Q_FRAC * float(e3.core().KSAT)

    original_face = e3.candidate_face
    results = []
    try:
        e3.candidate_face = e3c.expanded_candidate_face
        for candidate, steps in TRIALS:
            dt = HORIZON / steps
            rows, unchanged = solve_all_starts(INITIAL, dt, q_top, table, candidate)
            strong = [r for r in rows if r.get("strong_mass_pass")]
            hard = [r for r in rows if r.get("hard_mass_pass")]
            unique = unique_strong_roots(rows)
            results.append({
                "route": "candidate" if candidate else "reference",
                "step_count": steps,
                "dt_day": dt,
                "solver_attempt_count": len(rows),
                "hard_root_attempt_count": len(hard),
                "strong_root_attempt_count": len(strong),
                "unique_strong_roots_rounded_1e10_cm": [list(x) for x in unique],
                "strong_root_top_signs": sorted(set(r.get("top_head_sign") for r in strong)),
                "committed_state_unchanged_during_diagnostics": unchanged,
                "solvers": rows,
            })
            print(json.dumps({"route":results[-1]["route"],"steps":steps,"strong":len(strong),"unique":len(unique),"signs":results[-1]["strong_root_top_signs"]}, sort_keys=True), flush=True)
    finally:
        e3.candidate_face = original_face

    any_missing = any(r["strong_root_attempt_count"] == 0 for r in results)
    mutation = any(not r["committed_state_unchanged_during_diagnostics"] for r in results)
    if not any_missing and not mutation:
        decision = "ALL_FROZEN_O14_FIRST_TRIALS_HAVE_STRONG_MASS_ROOTS_SOLVER_START_POLICY_BLOCKER_CONFIRMED"
    elif any(r["strong_root_attempt_count"] > 0 for r in results) and not mutation:
        decision = "MIXED_O14_EVENT_ROOT_DIAGNOSTIC_ONLY_SUBSET_HAS_STRONG_MASS_ROOTS"
    else:
        decision = "O14_REAL_EVENT_FIRST_TRIAL_ROOT_EXISTENCE_NOT_ESTABLISHED"
    result = {
        "schema_version":1,
        "workstream":"F-ROSS",
        "work_unit":"F-ROSS01",
        "gate":"E3D_R1_O14_REAL_EVENT_FIRST_TRIAL_ROOT_DIAGNOSTIC",
        "contract":CONTRACT,
        "production_implementation":False,
        "qualification_use_only":True,
        "material":MATERIAL,
        "fixture":{"initial_heads_cm":list(INITIAL),"q_top_fraction_ksat":Q_FRAC,"bottom_head_cm":BOTTOM_HEAD,"horizon_day":HORIZON},
        "hard_mass_certificate_cm":HARD,
        "strong_diagnostic_target_cm":STRONG,
        "results":results,
        "all_trials_have_strong_root":not any_missing,
        "committed_state_unchanged":not mutation,
        "decision":decision,
        "hard_nonclaims":["No E3D requalification.","No production nonlinear solver qualification.","No forcing, timestep or tolerance change is admitted by this diagnostic."]
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2, sort_keys=True)+"\n", encoding="utf-8")
    print(json.dumps({"decision":decision,"all_trials_have_strong_root":result["all_trials_have_strong_root"]}, sort_keys=True))


if __name__ == "__main__":
    main()
