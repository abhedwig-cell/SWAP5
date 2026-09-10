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
import run_ross01_gate_e3e_r2r2_r3_physical_envelope_upper_snap as surf_cand
import run_ross01_gate_e3e_r2r3_identical_320_case_requalification as surf_req

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
class State:
    t_day: float
    heads: tuple[float, float, float]
    surface: float


def bits(s: State) -> bytes:
    return struct.pack("!5d", s.t_day, *s.heads, s.surface)


def internal_geometry(row: dict) -> None:
    # Surface and internal qualification modules share a mutable constitutive
    # core. Reassert 10 cm before every internal-face evaluation.
    e3.r3.e2c.LENGTH = float(e3.DZ)
    e3.r3.e2c.c1.LENGTH_CM = float(e3.DZ)
    e3.j1a.c1r.base.c1.LENGTH_CM = float(e3.DZ)
    e3.configure(row)
    e3.r3.e2c.c1.core.LENGTH_CM = float(e3.DZ)
    if float(e3.r3.e2c.LENGTH) != 10.0 or float(e3.r3.e2c.c1.core.LENGTH_CM) != 10.0:
        raise RuntimeError("internal_face_geometry_not_10cm")


def surface_geometry(row: dict) -> None:
    surf_cand.r2.old_e3e.configure_5cm(row)
    if float(surf_cand.r2.old_e3e.e2c.LENGTH) != 5.0:
        raise RuntimeError("surface_face_geometry_not_5cm")
    if float(surf_cand.r2.old_e3e.e2c.c1.core.LENGTH_CM) != 5.0:
        raise RuntimeError("surface_reference_geometry_not_5cm")


def surface_face(hs: float, ht: float, row: dict, candidate: bool):
    if not (0.0 <= hs <= S_MAX and -10000.0 <= ht <= TOP_UPPER):
        raise RuntimeError(("surface_face_outside_scope", hs, ht))
    surface_geometry(row)
    try:
        if candidate:
            q, cost, cert = surf_cand.candidate_with_envelope(hs, ht)
            return float(q), str(cost["branch"]), {
                "root_residual_evaluations": int(cost["root_residual_evaluations"]),
                "constitutive_K_evaluations": int(cost["constitutive_K_evaluations"]),
                "certificate": cert,
            }
        core = surf_cand.r2.old_e3e.e2c.c1.core
        return float(core.steady_q(hs, ht)), "SURFACE_STEADY_DARCY_REFERENCE_5CM", {}
    finally:
        internal_geometry(row)


def exact_surface_reference(hs: float, ht: float, row: dict) -> dict:
    return surf_req.primary_reference(hs, ht, row)


def internal_fluxes(heads, qtop: float, table, row: dict, candidate: bool):
    internal_geometry(row)
    q = [float(qtop)]
    routes = []
    for i in range(e3.N_CELLS - 1):
        if candidate:
            qi, route = e3.candidate_face(float(heads[i]), float(heads[i + 1]), table)
        else:
            qi, route = e3.reference_face(float(heads[i]), float(heads[i + 1])), "REFERENCE"
        q.append(float(qi))
        routes.append(str(route))
    if candidate:
        qb, route = e3.candidate_face(float(heads[-1]), BOTTOM_HEAD, table)
    else:
        qb, route = e3.reference_face(float(heads[-1]), BOTTOM_HEAD), "REFERENCE"
    q.append(float(qb))
    routes.append(str(route))
    return tuple(q), tuple(routes)


def soil_residual(heads, old_heads, dt, qtop, table, row, candidate):
    hh = tuple(float(v) for v in heads)
    q, _ = internal_fluxes(hh, qtop, table, row, candidate)
    return np.asarray([
        e3.DZ * (e3.theta_of_h(hh[i]) - e3.theta_of_h(float(old_heads[i])))
        - dt * (q[i] - q[i + 1])
        for i in range(e3.N_CELLS)
    ], dtype=np.float64)


def diagnostics(old: State, heads, surface, supply, q, dt):
    cell = [
        e3.DZ * (e3.theta_of_h(float(heads[i])) - e3.theta_of_h(float(old.heads[i])))
        - dt * (q[i] - q[i + 1])
        for i in range(e3.N_CELLS)
    ]
    soil = math.fsum(
        e3.DZ * (e3.theta_of_h(float(heads[i])) - e3.theta_of_h(float(old.heads[i])))
        for i in range(e3.N_CELLS)
    )
    surface_res = (surface - old.surface) - dt * (supply - q[0])
    composed = soil + (surface - old.surface) - dt * (supply - q[-1])
    return {
        "cell_residuals_cm": [float(v) for v in cell],
        "surface_balance_residual_cm": float(surface_res),
        "composed_balance_residual_cm": float(composed),
        "bottom_transfer_cm": float(dt * q[-1]),
    }


def mass_ok(d: dict) -> bool:
    return (
        max(abs(v) for v in d["cell_residuals_cm"]) <= MASS_TOL
        and abs(d["surface_balance_residual_cm"]) <= MASS_TOL
        and abs(d["composed_balance_residual_cm"]) <= MASS_TOL
    )


def dry_predictor(old: State, supply: float, table, row: dict, candidate: bool) -> dict:
    snapshot = bits(old)
    fun = lambda h: soil_residual(h, old.heads, DT, supply, table, row, candidate)
    try:
        sol = least_squares(
            fun,
            np.asarray(old.heads),
            bounds=(np.full(3, -10000.0), np.full(3, TOP_UPPER)),
            xtol=1e-13, ftol=1e-13, gtol=1e-13,
            max_nfev=MAX_NFEV, x_scale="jac",
        )
        heads = tuple(float(v) for v in sol.x)
        q, routes = internal_fluxes(heads, supply, table, row, candidate)
        d = diagnostics(old, heads, 0.0, supply, q, DT)
        qcap, cap_route, cap_cost = surface_face(0.0, heads[0], row, candidate)
        tol = 64.0 * EPS * max(1.0, abs(supply), abs(qcap))
        no_unqualified = not any("UNQUALIFIED_FACE_FALLBACK" in r for r in routes)
        local_valid = bool(
            sol.success
            and all(math.isfinite(v) for v in (*heads, *q, qcap))
            and mass_ok(d)
            and no_unqualified
        )
        admissible = bool(supply <= qcap + tol)
        return {
            "solver_success": bool(sol.success),
            "nfev": int(sol.nfev),
            "local_trial_valid": local_valid,
            "complementarity_admissible": admissible,
            "accepted_as_dry_flux": bool(local_valid and admissible),
            "heads_cm": list(heads),
            "q_surface_capacity_cm_per_day": qcap,
            "capacity_route": cap_route,
            "capacity_cost": cap_cost,
            "internal_routes": list(routes),
            "diagnostics": d,
            "committed_bitwise_unchanged": bits(old) == snapshot,
        }
    except Exception as exc:
        return {
            "solver_success": False,
            "local_trial_valid": False,
            "complementarity_admissible": False,
            "accepted_as_dry_flux": False,
            "error": repr(exc),
            "committed_bitwise_unchanged": bits(old) == snapshot,
        }


def ponded_solve(old: State, supply: float, table, row: dict, candidate: bool) -> dict:
    snapshot = bits(old)
    cap0, _, _ = surface_face(0.0, old.heads[0], row, candidate)
    s_guess = old.surface if old.surface > 0.0 else min(
        0.25, max(1e-10, DT * max(supply - cap0, 1e-8))
    )

    def fun(x):
        heads = tuple(float(v) for v in x[:3])
        surface = float(x[3])
        qtop, _, _ = surface_face(surface, heads[0], row, candidate)
        sr = soil_residual(heads, old.heads, DT, qtop, table, row, candidate)
        return np.asarray([
            *sr,
            (surface - old.surface) - DT * (supply - qtop),
        ], dtype=np.float64)

    try:
        sol = least_squares(
            fun,
            np.asarray([*old.heads, s_guess]),
            bounds=(
                np.asarray([-10000.0, -10000.0, -10000.0, 0.0]),
                np.asarray([TOP_UPPER, TOP_UPPER, TOP_UPPER, S_MAX]),
            ),
            xtol=1e-13, ftol=1e-13, gtol=1e-13,
            max_nfev=MAX_NFEV, x_scale="jac",
        )
        heads = tuple(float(v) for v in sol.x[:3])
        surface = float(sol.x[3])
        qtop, top_route, top_cost = surface_face(surface, heads[0], row, candidate)
        q, routes = internal_fluxes(heads, qtop, table, row, candidate)
        d = diagnostics(old, heads, surface, supply, q, DT)
        no_unqualified = not any("UNQUALIFIED_FACE_FALLBACK" in r for r in routes)
        accepted = bool(
            sol.success
            and all(math.isfinite(v) for v in (*heads, surface, *q))
            and mass_ok(d)
            and 0.0 < surface < S_MAX
            and max(heads) <= TOP_UPPER
            and no_unqualified
        )
        exact = exact_surface_reference(surface, heads[0], row)
        q_exact = float(exact["q"])
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
            "diagnostics": d,
            "exact_surface_reference_q_cm_per_day": q_exact,
            "trajectory_surface_q_abs_difference_over_ksat": abs(qtop - q_exact) / float(row["ksatfit_cm_per_day"]),
            "committed_input_bitwise_unchanged_during_trial": bits(old) == snapshot,
            "mass_repair_or_clipping_used": False,
        }
    except Exception as exc:
        return {
            "accepted": False,
            "solver_success": False,
            "error": repr(exc),
            "committed_input_bitwise_unchanged_during_trial": bits(old) == snapshot,
            "mass_repair_or_clipping_used": False,
        }


def run_path(row: dict, scenario: dict, candidate: bool) -> dict:
    internal_geometry(row)
    table = e3.generate_c1r_table() if candidate else None
    old = State(2.375, INITIAL_HEADS, float(scenario["S0"]))
    supply = float(scenario["supply_fraction"]) * float(row["ksatfit_cm_per_day"])

    if scenario["id"] == "DRY_FLUX_ADMISSIBLE":
        p = dry_predictor(old, supply, table, row, candidate)
        accepted = bool(p.get("accepted_as_dry_flux"))
        return {
            "accepted": accepted,
            "mode": "DRY_FLUX" if accepted else "REJECTED",
            "heads_cm": p.get("heads_cm"),
            "surface_storage_cm": 0.0,
            "bottom_transfer_cm": None if not accepted else p["diagnostics"]["bottom_transfer_cm"],
            "diagnostics": p.get("diagnostics"),
            "dry_flux_predictor": p,
            "committed_input_bitwise_unchanged_during_trial": p["committed_bitwise_unchanged"],
            "mass_repair_or_clipping_used": False,
        }

    if scenario["id"] == "DRY_FLUX_TO_PONDED_HEAD_SWITCH":
        p = dry_predictor(old, supply, table, row, candidate)
        rejected = bool(
            p.get("local_trial_valid")
            and not p.get("complementarity_admissible")
            and not p.get("accepted_as_dry_flux")
            and p.get("committed_bitwise_unchanged")
        )
        out = ponded_solve(old, supply, table, row, candidate)
        out["dry_flux_predictor"] = p
        out["dry_flux_predictor_rejected_without_commit"] = rejected
        out["accepted"] = bool(out.get("accepted") and rejected)
        out["mode"] = "PONDED_HEAD" if out["accepted"] else "REJECTED"
        out["bottom_transfer_cm"] = (
            None if out.get("diagnostics") is None else out["diagnostics"]["bottom_transfer_cm"]
        )
        return out

    out = ponded_solve(old, supply, table, row, candidate)
    out["dry_flux_predictor"] = None
    out["dry_flux_predictor_rejected_without_commit"] = None
    out["mode"] = "PONDED_HEAD" if out.get("accepted") else "REJECTED"
    out["bottom_transfer_cm"] = (
        None if out.get("diagnostics") is None else out["diagnostics"]["bottom_transfer_cm"]
    )
    return out


def path_tests(path: dict, scenario: dict) -> dict:
    d = path.get("diagnostics")
    tests = {
        "accepted": path.get("accepted") is True,
        "mode": path.get("mode") == scenario["mode"],
        "no_repair_or_clipping": path.get("mass_repair_or_clipping_used") is False,
        "committed_input_unchanged_during_trial": path.get("committed_input_bitwise_unchanged_during_trial") is True,
        "surface_scope": 0.0 <= float(path.get("surface_storage_cm", -1.0)) < S_MAX,
        "top_node_negative_scope": (
            path.get("heads_cm") is not None and max(path["heads_cm"]) <= TOP_UPPER
        ),
    }
    if d is None:
        tests.update({"cell_mass": False, "surface_mass": False, "composed_mass": False})
    else:
        tests.update({
            "cell_mass": max(abs(v) for v in d["cell_residuals_cm"]) <= MASS_TOL,
            "surface_mass": abs(d["surface_balance_residual_cm"]) <= MASS_TOL,
            "composed_mass": abs(d["composed_balance_residual_cm"]) <= MASS_TOL,
        })

    if scenario["id"] == "DRY_FLUX_ADMISSIBLE":
        p = path.get("dry_flux_predictor") or {}
        tests["dry_flux_complementarity_admissible"] = p.get("complementarity_admissible") is True
        tests["surface_exact_zero"] = path.get("surface_storage_cm") == 0.0
    elif scenario["id"] == "DRY_FLUX_TO_PONDED_HEAD_SWITCH":
        p = path.get("dry_flux_predictor") or {}
        tests["dry_predictor_local_trial_valid"] = p.get("local_trial_valid") is True
        tests["dry_predictor_complementarity_inadmissible"] = p.get("complementarity_admissible") is False
        tests["dry_predictor_rejected_without_commit"] = path.get("dry_flux_predictor_rejected_without_commit") is True
        tests["surface_strictly_positive"] = float(path.get("surface_storage_cm", 0.0)) > 0.0
    else:
        tests["entered_head_mode_directly"] = path.get("dry_flux_predictor") is None
        tests["surface_strictly_positive"] = float(path.get("surface_storage_cm", 0.0)) > 0.0
    return tests


def compare(candidate: dict, reference: dict) -> dict:
    if not (candidate.get("accepted") and reference.get("accepted")):
        return {"available": False, "pass": False}
    hdiff = max(abs(float(a) - float(b)) for a, b in zip(candidate["heads_cm"], reference["heads_cm"]))
    sdiff = abs(float(candidate["surface_storage_cm"]) - float(reference["surface_storage_cm"]))
    bdiff = abs(float(candidate["bottom_transfer_cm"]) - float(reference["bottom_transfer_cm"]))
    tests = {
        "mode_match": candidate["mode"] == reference["mode"],
        "head": hdiff <= HEAD_DIFF_TOL,
        "surface": sdiff <= SURFACE_DIFF_TOL,
        "bottom_transfer": bdiff <= BOTTOM_TRANSFER_DIFF_TOL,
    }
    return {
        "available": True,
        "max_abs_head_difference_cm": hdiff,
        "max_abs_surface_storage_difference_cm": sdiff,
        "max_abs_bottom_transfer_difference_cm": bdiff,
        "tests": tests,
        "pass": all(tests.values()),
    }


def run_material(row: dict) -> dict:
    rows = []
    for scenario in SCENARIOS:
        cand = run_path(row, scenario, True)
        ref = run_path(row, scenario, False)
        ct = path_tests(cand, scenario)
        rt = path_tests(ref, scenario)
        cmp = compare(cand, ref)
        rows.append({
            "scenario": scenario,
            "candidate": cand,
            "reference": ref,
            "candidate_tests": ct,
            "reference_tests": rt,
            "comparison": cmp,
            "pass": all(ct.values()) and all(rt.values()) and cmp["pass"],
        })

    max_h = max((r["comparison"].get("max_abs_head_difference_cm", math.inf) for r in rows), default=math.inf)
    max_s = max((r["comparison"].get("max_abs_surface_storage_difference_cm", math.inf) for r in rows), default=math.inf)
    max_b = max((r["comparison"].get("max_abs_bottom_transfer_difference_cm", math.inf) for r in rows), default=math.inf)
    max_mass = 0.0
    for r in rows:
        for side in (r["candidate"], r["reference"]):
            d = side.get("diagnostics")
            if d:
                max_mass = max(
                    max_mass,
                    max(abs(v) for v in d["cell_residuals_cm"]),
                    abs(d["surface_balance_residual_cm"]),
                    abs(d["composed_balance_residual_cm"]),
                )
    tests = {
        "scenario_count": len(rows) == 3,
        "all_rows_pass": all(r["pass"] for r in rows),
        "max_head_difference": max_h <= HEAD_DIFF_TOL,
        "max_surface_difference": max_s <= SURFACE_DIFF_TOL,
        "max_bottom_transfer_difference": max_b <= BOTTOM_TRANSFER_DIFF_TOL,
        "max_mass_residual": max_mass <= MASS_TOL,
    }
    return {
        "material": row["sfu"],
        "rows": rows,
        "max_abs_head_difference_cm": max_h,
        "max_abs_surface_storage_difference_cm": max_s,
        "max_abs_bottom_transfer_difference_cm": max_b,
        "max_abs_mass_residual_cm": max_mass,
        "tests": tests,
        "failed_metrics": [k for k, v in tests.items() if not v],
        "pass": all(tests.values()),
    }


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_e3g_physical_top_boundary_switch_composition.py MATERIAL OUTPUT.json")
    material = sys.argv[1]
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
        "production_implementation": False,
        "material_result": mr,
        "pass": mr["pass"],
        "decision": (
            "QUALIFIED_RESTRICTED_REAL_SOIL_DRY_FLUX_TO_PONDED_HEAD_SWITCH_COMPOSITION_READY_FOR_TOP_NODE_SATURATION_AND_DEPLETION_EVENT_GATES"
            if mr["pass"] else
            "RESTRICTED_REAL_SOIL_TOP_BOUNDARY_SWITCH_COMPOSITION_NOT_QUALIFIED_PRESERVE_FAILURE"
        ),
        "hard_nonclaims": [
            "No top soil-node h=0 or positive-head qualification.",
            "No physical pond-depletion head-to-flux back-switch qualification.",
            "No runoff with real soil state.",
            "No response tangent across top-boundary switching.",
            "No production, runtime, MultiSWAP, MODFLOW or groundwater admission."
        ],
    }
    out = Path(sys.argv[2])
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
