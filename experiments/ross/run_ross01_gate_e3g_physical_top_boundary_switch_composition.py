from __future__ import annotations

import json
import math
import struct
import sys
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from scipy.optimize import least_squares

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_e3_saturation_transition_hydrologic_relevance as e3
import run_ross01_gate_e3e_r2r2_r3_physical_envelope_upper_snap as surface_candidate
import run_ross01_gate_e3e_r2r2_r2_analytic_saturated_segment_candidate as surface_reference_exact
import run_ross01_gate_e3e_r2r3_identical_320_case_requalification as surface_requalification

CONTRACT = "F-ROSS01_GATE_E3G_PHYSICAL_TOP_BOUNDARY_SWITCH_COMPOSITION_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = ("B01", "B12", "O13", "O14")
INITIAL_HEADS = (-0.2, -1.5, -5.0)
BOTTOM_HEAD = -15.0
S_MAX = 1.0
TOP_UPPER = -1.0e-8
DT = 2.0e-4
MASS_TOL = 1.0e-9
HEAD_DIFF_TOL = 0.25
SURFACE_DIFF_TOL = 1.0e-3
BOTTOM_TRANSFER_DIFF_TOL = 1.0e-3
MAX_NFEV = 120
EPS = sys.float_info.epsilon

SCENARIOS = (
    {"id": "DRY_FLUX_ADMISSIBLE", "S0": 0.0, "supply_fraction": 0.25, "mode": "DRY_FLUX"},
    {"id": "DRY_FLUX_TO_PONDED_HEAD_SWITCH", "S0": 0.0, "supply_fraction": 1.5, "mode": "PONDED_HEAD"},
    {"id": "PONDED_HEAD_CONTINUATION", "S0": 0.02, "supply_fraction": 1.25, "mode": "PONDED_HEAD"},
)


@dataclass(frozen=True)
class CommittedState:
    t_day: float
    heads_cm: tuple[float, float, float]
    surface_storage_cm: float


def state_bits(s: CommittedState) -> bytes:
    return struct.pack("!5d", s.t_day, *s.heads_cm, s.surface_storage_cm)


def set_internal_geometry(row: dict) -> None:
    # The old qualification modules share a mutable constitutive core. Reassert
    # the 10 cm internal-face geometry before every internal-face evaluation so
    # a 5 cm surface-face call cannot silently contaminate the soil column.
    e3.r3.e2c.LENGTH = float(e3.DZ)
    e3.r3.e2c.c1.LENGTH_CM = float(e3.DZ)
    e3.j1a.c1r.base.c1.LENGTH_CM = float(e3.DZ)
    e3.configure(row)
    e3.r3.e2c.c1.core.LENGTH_CM = float(e3.DZ)
    if float(e3.r3.e2c.LENGTH) != float(e3.DZ):
        raise RuntimeError("internal_candidate_length_not_10cm")
    if float(e3.r3.e2c.c1.core.LENGTH_CM) != float(e3.DZ):
        raise RuntimeError("internal_reference_length_not_10cm")


def set_surface_geometry(row: dict) -> None:
    surface_candidate.r2.old_e3e.configure_5cm(row)
    if float(surface_candidate.r2.old_e3e.e2c.LENGTH) != 5.0:
        raise RuntimeError("surface_candidate_length_not_5cm")
    if float(surface_candidate.r2.old_e3e.e2c.c1.core.LENGTH_CM) != 5.0:
        raise RuntimeError("surface_reference_length_not_5cm")


def surface_face(hs: float, ht: float, row: dict, candidate: bool) -> tuple[float, str, dict]:
    if not (0.0 <= hs <= S_MAX and -10000.0 <= ht <= TOP_UPPER):
        raise RuntimeError(("surface_face_outside_frozen_scope", hs, ht))
    if candidate:
        set_surface_geometry(row)
        try:
            q, cost, cert = surface_candidate.candidate_with_envelope(float(hs), float(ht))
            meta = {
                "root_residual_evaluations": int(cost["root_residual_evaluations"]),
                "constitutive_K_evaluations": int(cost["constitutive_K_evaluations"]),
                "certificate": cert,
            }
            return float(q), str(cost["branch"]), meta
        finally:
            set_internal_geometry(row)

    # Efficient full-accuracy reference solve for the trajectory. The final
    # accepted face is cross-checked separately against the high-precision
    # endpoint-aware E3E-R2R3 oracle.
    set_surface_geometry(row)
    try:
        q = float(surface_candidate.r2.old_e3e.e2c.c1.core.steady_q(float(hs), float(ht)))
        return q, "SURFACE_STEADY_DARCY_REFERENCE_5CM", {
            "root_residual_evaluations": None,
            "constitutive_K_evaluations": None,
            "certificate": None,
        }
    finally:
        set_internal_geometry(row)


def exact_surface_reference(hs: float, ht: float, row: dict) -> dict:
    if hs == 0.0:
        return surface_requalification.primary_reference(hs, ht, row)
    q, residual = surface_reference_exact.reference_b(hs, ht, row)
    return {"q": float(q), "branch": "INTERIOR_ROOT", "residual_cm": float(residual)}


def internal_fluxes(heads: tuple[float, float, float], q_top: float, table, row: dict, candidate: bool):
    set_internal_geometry(row)
    q = [float(q_top)]
    routes: list[str] = []
    for i in range(e3.N_CELLS - 1):
        if candidate:
            qi, route = e3.candidate_face(float(heads[i]), float(heads[i + 1]), table)
        else:
            qi, route = e3.reference_face(float(heads[i]), float(heads[i + 1])), "REFERENCE"
        q.append(float(qi)); routes.append(str(route))
    if candidate:
        qb, route = e3.candidate_face(float(heads[-1]), BOTTOM_HEAD, table)
    else:
        qb, route = e3.reference_face(float(heads[-1]), BOTTOM_HEAD), "REFERENCE"
    q.append(float(qb)); routes.append(str(route))
    return tuple(q), tuple(routes)


def soil_residual(heads, old_heads, dt: float, q_top: float, table, row: dict, candidate: bool):
    hh = tuple(float(x) for x in heads)
    q, _ = internal_fluxes(hh, q_top, table, row, candidate)
    return np.asarray([
        e3.DZ * (e3.theta_of_h(hh[i]) - e3.theta_of_h(float(old_heads[i]))) - dt * (q[i] - q[i + 1])
        for i in range(e3.N_CELLS)
    ], dtype=np.float64)


def mass_diagnostics(old: CommittedState, new_heads, new_surface: float, q_supply: float, q, dt: float) -> dict:
    soil_dstore = math.fsum(
        e3.DZ * (e3.theta_of_h(float(new_heads[i])) - e3.theta_of_h(float(old.heads_cm[i])))
        for i in range(e3.N_CELLS)
    )
    cell = tuple(
        e3.DZ * (e3.theta_of_h(float(new_heads[i])) - e3.theta_of_h(float(old.heads_cm[i]))) - dt * (q[i] - q[i + 1])
        for i in range(e3.N_CELLS)
    )
    surface_res = (new_surface - old.surface_storage_cm) - dt * (q_supply - q[0])
    composed_res = soil_dstore + (new_surface - old.surface_storage_cm) - dt * (q_supply - q[-1])
    return {
        "soil_storage_change_cm": soil_dstore,
        "cell_residuals_cm": [float(x) for x in cell],
        "surface_balance_residual_cm": float(surface_res),
        "composed_balance_residual_cm": float(composed_res),
        "bottom_transfer_cm": float(dt * q[-1]),
    }


def numerical_ok(diag: dict) -> bool:
    return (
        max(abs(x) for x in diag["cell_residuals_cm"]) <= MASS_TOL
        and abs(diag["surface_balance_residual_cm"]) <= MASS_TOL
        and abs(diag["composed_balance_residual_cm"]) <= MASS_TOL
    )


def solve_dry_flux_predictor(old: CommittedState, dt: float, q_supply: float, table, row: dict, candidate: bool) -> dict:
    before = state_bits(old)
    fun = lambda h: soil_residual(h, old.heads_cm, dt, q_supply, table, row, candidate)
    try:
        sol = least_squares(
            fun,
            np.asarray(old.heads_cm, dtype=np.float64),
            bounds=(np.full(e3.N_CELLS, -10000.0), np.full(e3.N_CELLS, TOP_UPPER)),
            xtol=1.0e-13, ftol=1.0e-13, gtol=1.0e-13,
            max_nfev=MAX_NFEV, x_scale="jac",
        )
        heads = tuple(float(x) for x in sol.x)
        q, routes = internal_fluxes(heads, q_supply, table, row, candidate)
        diag = mass_diagnostics(old, heads, 0.0, q_supply, q, dt)
        qcap, cap_route, cap_cost = surface_face(0.0, heads[0], row, candidate)
        cap_tol = 64.0 * EPS * max(1.0, abs(q_supply), abs(qcap))
        complementarity_admissible = q_supply <= qcap + cap_tol
        in_scope = max(heads) <= TOP_UPPER and min(heads) >= -10000.0
        no_unqualified = not any("UNQUALIFIED_FACE_FALLBACK" in r for r in routes)
        local_valid = bool(sol.success and all(math.isfinite(x) for x in (*heads, *q, qcap)) and numerical_ok(diag) and in_scope and no_unqualified)
        local_state = CommittedState(old.t_day + dt, heads, 0.0)
        return {
            "solver_success": bool(sol.success),
            "nfev": int(sol.nfev),
            "local_trial_valid": local_valid,
            "complementarity_admissible": complementarity_admissible,
            "q_supply_cm_per_day": q_supply,
            "q_surface_capacity_cm_per_day": qcap,
            "capacity_route": cap_route,
            "capacity_cost": cap_cost,
            "heads_cm": list(heads),
            "internal_routes": list(routes),
            "diagnostics": diag,
            "local_state": {"t_day": local_state.t_day, "heads_cm": list(local_state.heads_cm), "surface_storage_cm": 0.0},
            "committed_bitwise_unchanged": state_bits(old) == before,
            "accepted_as_dry_flux": bool(local_valid and complementarity_admissible),
        }
    except Exception as exc:
        return {
            "solver_success": false,
            "local_trial_valid": false,
            "complementarity_admissible": false,
            "error": repr(exc),
            "committed_bitwise_unchanged": state_bits(old) == before,
            "accepted_as_dry_flux": false,
        }


def solve_ponded(old: CommittedState, dt: float, q_supply: float, table, row: dict, candidate: bool) -> dict:
    before = state_bits(old)
    qcap0, _, _ = surface_face(0.0, old.heads_cm[0], row, candidate)
    if old.surface_storage_cm > 0.0:
        s_guess = old.surface_storage_cm
    else:
        s_guess = min(0.25, max(1.0e-10, dt * max(q_supply - qcap0, 1.0e-8)))

    def fun(x):
        heads = tuple(float(v) for v in x[:3])
        surface = float(x[3])
        qtop, _, _ = surface_face(surface, heads[0], row, candidate)
        soil = soil_residual(heads, old.heads_cm, dt, qtop, table, row, candidate)
        surface_res = (surface - old.surface_storage_cm) - dt * (q_supply - qtop)
        return np.asarray([*soil, surface_res], dtype=np.float64)

    try:
        x0 = np.asarray([*old.heads_cm, s_guess], dtype=np.float64)
        lo = np.asarray([-10000.0, -10000.0, -10000.0, 0.0], dtype=np.float64)
        hi = np.asarray([TOP_UPPER, TOP_UPPER, TOP_UPPER, S_MAX], dtype=np.float64)
        sol = least_squares(fun, x0, bounds=(lo, hi), xtol=1.0e-13, ftol=1.0e-13, gtol=1.0e-13, max_nfev=MAX_NFEV, x_scale="jac")
        heads = tuple(float(x) for x in sol.x[:3])
        surface = float(sol.x[3])
        qtop, top_route, top_cost = surface_face(surface, heads[0], row, candidate)
        q, routes = internal_fluxes(heads, qtop, table, row, candidate)
        diag = mass_diagnostics(old, heads, surface, q_supply, q, dt)
        no_unqualified = not any("UNQUALIFIED_FACE_FALLBACK" in r for r in routes)
        finite = all(math.isfinite(x) for x in (*heads, surface, *q))
        in_scope = 0.0 < surface < S_MAX and max(heads) <= TOP_UPPER and min(heads) >= -10000.0
        accepted = bool(sol.success and finite and numerical_ok(diag) and in_scope and no_unqualified)
        state = CommittedState(old.t_day + dt, heads, surface)
        exact_ref = exact_surface_reference(surface, heads[0], row)
        exact_q_rel = abs(qtop - float(exact_ref["q"])) / float(row["ksatfit_cm_per_day"])
        return {
            "accepted": accepted,
            "solver_success": bool(sol.success),
            "nfev": int(sol.nfev),
            "heads_cm": list(heads),
            "surface_storage_cm": surface,
            "q_top_cm_per_day": qtop,
            "q_bottom_cm_per_day": q[-1],
            "top_route": top_route,
            "top_cost": top_cost,
            "internal_routes": list(routes),
            "diagnostics": diag,
            "exact_surface_reference_q_cm_per_day": float(exact_ref["q"]),
            "exact_surface_reference_residual_cm": float(exact_ref.get("residual_cm", 0.0)),
            "trajectory_surface_q_abs_difference_over_ksat": exact_q_rel,
            "committed_candidate": {"t_day": state.t_day, "heads_cm": list(state.heads_cm), "surface_storage_cm": state.surface_storage_cm},
            "committed_input_bitwise_unchanged_during_trial": state_bits(old) == before,
            "mass_repair_or_clipping_used": false,
        }
    except Exception as exc:
        return {
            "accepted": false,
            "solver_success": false,
            "error": repr(exc),
            "committed_input_bitwise_unchanged_during_trial": state_bits(old) == before,
            "mass_repair_or_clipping_used": false,
        }


def run_path(row: dict, scenario: dict, candidate: bool) -> dict:
    set_internal_geometry(row)
    table = e3.generate_c1r_table() if candidate else None
    old = CommittedState(2.375, INITIAL_HEADS, float(scenario["S0"]))
    q_supply = float(scenario["supply_fraction"]) * float(row["ksatfit_cm_per_day"])

    if scenario["mode"] == "DRY_FLUX":
        pred = solve_dry_flux_predictor(old, DT, q_supply, table, row, candidate)
        accepted = bool(pred.get("accepted_as_dry_flux"))
        return {
            "mode": "DRY_FLUX" if accepted else "REJECTED",
            "accepted": accepted,
            "dry_flux_predictor": pred,
            "heads_cm": pred.get("heads_cm"),
            "surface_storage_cm": 0.0 if accepted else old.surface_storage_cm,
            "q_bottom_cm_per_day": None if not accepted else pred["diagnostics"]["bottom_transfer_cm"] / DT,
            "bottom_transfer_cm": None if not accepted else pred["diagnostics"]["bottom_transfer_cm"],
            "diagnostics": pred.get("diagnostics"),
            "committed_input_bitwise_unchanged_during_trial": pred["committed_bitwise_unchanged"],
            "mass_repair_or_clipping_used": false,
        }

    if scenario["id"] == "DRY_FLUX_TO_PONDED_HEAD_SWITCH":
        pred = solve_dry_flux_predictor(old, DT, q_supply, table, row, candidate)
        rejected = bool(pred.get("local_trial_valid") and not pred.get("complementarity_admissible") and not pred.get("accepted_as_dry_flux") and pred.get("committed_bitwise_unchanged"))
        ponded = solve_ponded(old, DT, q_supply, table, row, candidate)
        ponded["dry_flux_predictor"] = pred
        ponded["dry_flux_predictor_rejected_without_commit"] = rejected
        ponded["mode"] = "PONDED_HEAD" if ponded.get("accepted") and rejected else "REJECTED"
        ponded["accepted"] = bool(ponded.get("accepted") and rejected)
        ponded["bottom_transfer_cm"] = None if not ponded.get("diagnostics") else ponded["diagnostics"]["bottom_transfer_cm"]
        return ponded

    ponded = solve_ponded(old, DT, q_supply, table, row, candidate)
    ponded["dry_flux_predictor"] = None
    ponded["dry_flux_predictor_rejected_without_commit"] = None
    ponded["mode"] = "PONDED_HEAD" if ponded.get("accepted") else "REJECTED"
    ponded["bottom_transfer_cm"] = None if not ponded.get("diagnostics") else ponded["diagnostics"]["bottom_transfer_cm"]
    return ponded


def compare_paths(candidate: dict, reference: dict) -> dict:
    if not (candidate.get("accepted") and reference.get("accepted")):
        return {"available": false, "pass": false}
    max_head = max(abs(float(a) - float(b)) for a, b in zip(candidate["heads_cm"], reference["heads_cm"]))
    surface_diff = abs(float(candidate["surface_storage_cm"]) - float(reference["surface_storage_cm"]))
    bottom_diff = abs(float(candidate["bottom_transfer_cm"]) - float(reference["bottom_transfer_cm"]))
    tests = {
        "mode_match": candidate["mode"] == reference["mode"],
        "max_abs_head_difference_cm": max_head <= HEAD_DIFF_TOL,
        "max_abs_surface_storage_difference_cm": surface_diff <= SURFACE_DIFF_TOL,
        "max_abs_bottom_transfer_difference_cm": bottom_diff <= BOTTOM_TRANSFER_DIFF_TOL,
    }
    return {
        "available": true,
        "max_abs_head_difference_cm": max_head,
        "max_abs_surface_storage_difference_cm": surface_diff,
        "max_abs_bottom_transfer_difference_cm": bottom_diff,
        "tests": tests,
        "pass": all(tests.values()),
    }


def path_tests(path: dict, scenario: dict) -> dict:
    d = path.get("diagnostics")
    tests = {
        "accepted": path.get("accepted") is true,
        "mode": path.get("mode") == scenario["mode"],
        "no_mass_repair_or_clipping": path.get("mass_repair_or_clipping_used") is false,
        "committed_input_unchanged_during_trial": path.get("committed_input_bitwise_unchanged_during_trial") is true,
    }
    if d is not None:
        tests.update({
            "cell_mass": max(abs(x) for x in d["cell_residuals_cm"]) <= MASS_TOL,
            "surface_mass": abs(d["surface_balance_residual_cm"]) <= MASS_TOL,
            "composed_mass": abs(d["composed_balance_residual_cm"]) <= MASS_TOL,
        })
    else:
        tests.update({"cell_mass": false, "surface_mass": false, "composed_mass": false})
    if path.get("heads_cm") is not None:
        tests["top_node_negative_scope"] = max(path["heads_cm"]) <= TOP_UPPER
    else:
        tests["top_node_negative_scope"] = false
    tests["surface_scope"] = 0.0 <= float(path.get("surface_storage_cm", -1.0)) < S_MAX
    if scenario["id"] == "DRY_FLUX_ADMISSIBLE":
        p = path.get("dry_flux_predictor") or {}
        tests["dry_flux_complementarity_admissible"] = p.get("complementarity_admissible") is true
        tests["surface_exact_zero"] = path.get("surface_storage_cm") == 0.0
    elif scenario["id"] == "DRY_FLUX_TO_PONDED_HEAD_SWITCH":
        p = path.get("dry_flux_predictor") or {}
        tests["dry_predictor_local_trial_valid"] = p.get("local_trial_valid") is true
        tests["dry_predictor_complementarity_inadmissible"] = p.get("complementarity_admissible") is false
        tests["dry_predictor_rejected_without_commit"] = path.get("dry_flux_predictor_rejected_without_commit") is true
        tests["surface_strictly_positive"] = float(path.get("surface_storage_cm", 0.0)) > 0.0
    else:
        tests["entered_head_mode_directly"] = path.get("dry_flux_predictor") is None
        tests["surface_strictly_positive"] = float(path.get("surface_storage_cm", 0.0)) > 0.0
    return tests


def run_material(row: dict) -> dict:
    material = str(row["sfu"])
    rows = []
    for scenario in SCENARIOS:
        candidate = run_path(row, scenario, True)
        reference = run_path(row, scenario, False)
        ctests = path_tests(candidate, scenario)
        rtests = path_tests(reference, scenario)
        compare = compare_paths(candidate, reference)
        tests = {
            "candidate": all(ctests.values()),
            "reference": all(rtests.values()),
            "comparison": compare["pass"],
        }
        rows.append({
            "scenario": scenario,
            "candidate": candidate,
            "reference": reference,
            "candidate_tests": ctests,
            "reference_tests": rtests,
            "comparison": compare,
            "tests": tests,
            "pass": all(tests.values()),
        })

    max_head_diff = max((r["comparison"].get("max_abs_head_difference_cm", math.inf) for r in rows), default=math.inf)
    max_surface_diff = max((r["comparison"].get("max_abs_surface_storage_difference_cm", math.inf) for r in rows), default=math.inf)
    max_bottom_diff = max((r["comparison"].get("max_abs_bottom_transfer_difference_cm", math.inf) for r in rows), default=math.inf)
    max_mass = 0.0
    for r in rows:
        for side in (r["candidate"], r["reference"]):
            d = side.get("diagnostics")
            if d:
                max_mass = max(max_mass, max(abs(x) for x in d["cell_residuals_cm"]), abs(d["surface_balance_residual_cm"]), abs(d["composed_balance_residual_cm"]))
    tests = {
        "scenario_count": len(rows) == 3,
        "all_rows_pass": all(r["pass"] for r in rows),
        "max_head_difference": max_head_diff <= HEAD_DIFF_TOL,
        "max_surface_difference": max_surface_diff <= SURFACE_DIFF_TOL,
        "max_bottom_transfer_difference": max_bottom_diff <= BOTTOM_TRANSFER_DIFF_TOL,
        "max_mass_residual": max_mass <= MASS_TOL,
    }
    return {
        "material": material,
        "rows": rows,
        "max_abs_head_difference_cm": max_head_diff,
        "max_abs_surface_storage_difference_cm": max_surface_diff,
        "max_abs_bottom_transfer_difference_cm": max_bottom_diff,
        "max_abs_mass_residual_cm": max_mass,
        "tests": tests,
        "failed_metrics": [k for k, v in tests.items() if not v],
        "pass": all(tests.values()),
    }


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_e3g_physical_top_boundary_switch_composition.py MATERIAL OUTPUT.json")
    material = sys.argv[1]
    out = Path(sys.argv[2])
    if material not in MATERIALS:
        raise SystemExit(material)
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    row = next(r for r in catalog["rows"] if r["sfu"] == material)
    mr = run_material(row)
    payload = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E3G_RESTRICTED_PHYSICAL_TOP_BOUNDARY_SWITCH_COMPOSITION",
        "contract": CONTRACT,
        "material": material,
        "production_implementation": false,
        "qualification_scope": "real three-cell soil update; dry flux admissibility plus t0 dry-to-ponded recomposition and already-ponded continuation; top node remains strictly negative",
        "material_result": mr,
        "pass": mr["pass"],
        "decision": "QUALIFIED_RESTRICTED_REAL_SOIL_DRY_FLUX_TO_PONDED_HEAD_SWITCH_COMPOSITION_READY_FOR_TOP_NODE_SATURATION_AND_DEPLETION_EVENT_GATES" if mr["pass"] else "RESTRICTED_REAL_SOIL_TOP_BOUNDARY_SWITCH_COMPOSITION_NOT_QUALIFIED_PRESERVE_FAILURE",
        "hard_nonclaims": [
            "No top soil-node h=0 or positive-head qualification.",
            "No physical pond-depletion head-to-flux back-switch qualification.",
            "No runoff with real soil state.",
            "No response tangent across top-boundary switching.",
            "No production, runtime, MultiSWAP, MODFLOW or groundwater admission."
        ],
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "material": material,
        "pass": mr["pass"],
        "max_head_difference_cm": mr["max_abs_head_difference_cm"],
        "max_surface_difference_cm": mr["max_abs_surface_storage_difference_cm"],
        "max_bottom_transfer_difference_cm": mr["max_abs_bottom_transfer_difference_cm"],
        "max_mass_residual_cm": mr["max_abs_mass_residual_cm"],
        "failed_metrics": mr["failed_metrics"],
        "decision": payload["decision"],
    }, sort_keys=True), flush=True)
    if not mr["pass"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
