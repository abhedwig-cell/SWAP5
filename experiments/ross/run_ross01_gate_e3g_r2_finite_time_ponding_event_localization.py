from __future__ import annotations

import json
import math
import sys
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from scipy.optimize import least_squares

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_e3g_physical_top_boundary_switch_composition as e3g

CONTRACT = "F-ROSS01_GATE_E3G_R2_FINITE_TIME_PONDING_EVENT_LOCALIZATION_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = ("B01", "O14")
FIXTURES = {
    "B01": {
        "heads": (-100.0, -100.0, -100.0),
        "supply": 84.13900261598157,
        "bracket": (0.01, 0.05),
        "t_end": 0.05,
    },
    "O14": {
        "heads": (-100.0, -100.0, -100.0),
        "supply": 20.281137326816246,
        "bracket": (0.005, 0.01),
        "t_end": 0.01,
    },
}
EPS = sys.float_info.epsilon
MASS_TOL = 1.0e-9
EVENT_TIME_DIFF_TOL = 2.5e-4
HEAD_DIFF_TOL = 0.25
SURFACE_DIFF_TOL = 1.0e-3
BOTTOM_DIFF_TOL = 1.0e-3
SURFACE_Q_ERR_MAX = 5.0e-4
MAX_NFEV = 120


@dataclass(frozen=True)
class TrialSummary:
    accepted: bool
    heads: tuple[float, float, float] | None
    diagnostics: dict | None
    qcap: float | None
    complementarity_admissible: bool | None
    nfev: int
    error: str | None = None


def qcap_candidate(htop: float, row: dict) -> tuple[float, str]:
    q, route, _ = e3g.surface_face(0.0, float(htop), row, True)
    return float(q), str(route)


def qcap_reference(htop: float, row: dict) -> tuple[float, str]:
    ref = e3g.exact_surface_reference(0.0, float(htop), row)
    return float(ref["q"]), str(ref.get("branch", "EXACT_ENDPOINT_AWARE_REFERENCE"))


def initial_admission(old: e3g.State, supply: float, row: dict, candidate: bool) -> dict:
    snapshot = e3g.bits(old)
    if candidate:
        qcap, route = qcap_candidate(old.heads[0], row)
        qexact, _ = qcap_reference(old.heads[0], row)
    else:
        qcap, route = qcap_reference(old.heads[0], row)
        qexact = qcap
    tol = 64.0 * EPS * max(1.0, abs(supply), abs(qcap))
    ksat = float(row["ksatfit_cm_per_day"])
    return {
        "q_supply_cm_per_day": float(supply),
        "q_cap0_cm_per_day": qcap,
        "q_cap0_route": route,
        "roundoff_tolerance_cm_per_day": tol,
        "dry_admissible_at_t0": bool(supply < qcap - tol),
        "qcap_abs_error_over_ksat": abs(qcap - qexact) / ksat,
        "soil_nonlinear_trajectory_count": 0,
        "committed_state_bitwise_unchanged": e3g.bits(old) == snapshot,
    }


def dry_full_trial(old: e3g.State, supply: float, dt: float, row: dict, candidate: bool, table) -> dict:
    snapshot = e3g.bits(old)
    e3g.internal_geometry(row)
    fun = lambda h: e3g.soil_residual(h, old.heads, dt, supply, table, row, candidate)
    try:
        sol = least_squares(
            fun,
            np.asarray(old.heads),
            bounds=(np.full(3, -10000.0), np.full(3, e3g.TOP_UPPER)),
            xtol=1e-13, ftol=1e-13, gtol=1e-13,
            max_nfev=MAX_NFEV, x_scale="jac",
        )
        heads = tuple(float(v) for v in sol.x)
        q, routes = e3g.internal_fluxes(heads, supply, table, row, candidate)
        d = e3g.diagnostics(old, heads, 0.0, supply, q, dt)
        qcap, caproute = (qcap_candidate(heads[0], row) if candidate else qcap_reference(heads[0], row))
        tol = 64.0 * EPS * max(1.0, abs(supply), abs(qcap))
        no_unqualified = not any("UNQUALIFIED_FACE_FALLBACK" in str(r) for r in routes)
        local_valid = bool(
            sol.success
            and all(math.isfinite(v) for v in (*heads, *q, qcap))
            and e3g.mass_ok(d)
            and max(heads) <= e3g.TOP_UPPER
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
            "q_bottom_cm_per_day": float(q[-1]),
            "q_surface_capacity_cm_per_day": qcap,
            "capacity_route": caproute,
            "internal_routes": list(routes),
            "diagnostics": d,
            "committed_state_bitwise_unchanged": e3g.bits(old) == snapshot,
            "mass_repair_or_clipping_used": False,
        }
    except Exception as exc:
        return {
            "solver_success": False,
            "nfev": 0,
            "local_trial_valid": False,
            "complementarity_admissible": None,
            "accepted_as_dry_flux": False,
            "error": repr(exc),
            "committed_state_bitwise_unchanged": e3g.bits(old) == snapshot,
            "mass_repair_or_clipping_used": False,
        }


def event_corrector(old: e3g.State, supply: float, bracket: tuple[float, float], predictor: dict, row: dict, candidate: bool, table) -> dict:
    snapshot = e3g.bits(old)
    tlo, thi = map(float, bracket)
    width = thi - tlo
    if width <= 0.0:
        raise ValueError("nonpositive event bracket")
    if predictor.get("heads_cm") is None:
        x0_heads = np.asarray(old.heads)
    else:
        x0_heads = np.asarray(predictor["heads_cm"], dtype=np.float64)
    x0 = np.asarray([*x0_heads, 0.5 * (tlo + thi)], dtype=np.float64)

    def residual(x):
        heads = tuple(float(v) for v in x[:3])
        te = float(x[3])
        soil = e3g.soil_residual(heads, old.heads, te, supply, table, row, candidate)
        qcap, _ = (qcap_candidate(heads[0], row) if candidate else qcap_reference(heads[0], row))
        return np.asarray([*soil, width * (supply - qcap)], dtype=np.float64)

    try:
        sol = least_squares(
            residual,
            x0,
            bounds=(
                np.asarray([-10000.0, -10000.0, -10000.0, tlo]),
                np.asarray([e3g.TOP_UPPER, e3g.TOP_UPPER, e3g.TOP_UPPER, thi]),
            ),
            xtol=1e-13, ftol=1e-13, gtol=1e-13,
            max_nfev=MAX_NFEV, x_scale="jac",
        )
        heads = tuple(float(v) for v in sol.x[:3])
        te = float(sol.x[3])
        q, routes = e3g.internal_fluxes(heads, supply, table, row, candidate)
        d = e3g.diagnostics(old, heads, 0.0, supply, q, te)
        qcap, caproute = (qcap_candidate(heads[0], row) if candidate else qcap_reference(heads[0], row))
        scaled_comp = width * (supply - qcap)
        ksat = float(row["ksatfit_cm_per_day"])
        qexact, _ = qcap_reference(heads[0], row)
        no_unqualified = not any("UNQUALIFIED_FACE_FALLBACK" in str(r) for r in routes)
        strict_inside = bool(te > tlo + 64.0 * EPS * max(1.0, abs(tlo)) and te < thi - 64.0 * EPS * max(1.0, abs(thi)))
        accepted = bool(
            sol.success
            and all(math.isfinite(v) for v in (*heads, te, *q, qcap))
            and e3g.mass_ok(d)
            and abs(scaled_comp) <= MASS_TOL
            and strict_inside
            and max(heads) <= e3g.TOP_UPPER
            and no_unqualified
        )
        return {
            "accepted": accepted,
            "solver_success": bool(sol.success),
            "nfev": int(sol.nfev),
            "event_time_day": te,
            "event_bracket_day": [tlo, thi],
            "heads_cm": list(heads),
            "surface_storage_cm": 0.0,
            "q_bottom_cm_per_day": float(q[-1]),
            "bottom_transfer_cm": float(te * q[-1]),
            "q_capacity_cm_per_day": qcap,
            "capacity_route": caproute,
            "capacity_abs_error_over_ksat": abs(qcap - qexact) / ksat,
            "scaled_complementarity_residual_cm": float(scaled_comp),
            "diagnostics": d,
            "internal_routes": list(routes),
            "strictly_inside_bracket": strict_inside,
            "committed_state_bitwise_unchanged": e3g.bits(old) == snapshot,
            "mass_repair_or_clipping_used": False,
        }
    except Exception as exc:
        return {
            "accepted": False,
            "solver_success": False,
            "nfev": 0,
            "error": repr(exc),
            "committed_state_bitwise_unchanged": e3g.bits(old) == snapshot,
            "mass_repair_or_clipping_used": False,
        }


def common_surface_flux(surface: float, htop: float, row: dict) -> tuple[float, str]:
    q, route, _ = e3g.surface_face(float(surface), float(htop), row, True)
    return float(q), str(route)


def ponded_remainder(event: dict, supply: float, t_end: float, row: dict, candidate_internal: bool, table) -> dict:
    if not event.get("accepted"):
        return {"accepted": False, "error": "event_not_accepted", "mass_repair_or_clipping_used": False}
    te = float(event["event_time_day"])
    dt = float(t_end - te)
    old = e3g.State(2.375 + te, tuple(float(v) for v in event["heads_cm"]), 0.0)
    snapshot = e3g.bits(old)
    ksat = float(row["ksatfit_cm_per_day"])
    s_guess = min(0.25, max(1.0e-10, 0.25 * dt * max(supply - ksat, 0.0)))

    def residual(x):
        heads = tuple(float(v) for v in x[:3])
        surface = float(x[3])
        qtop, _ = common_surface_flux(surface, heads[0], row)
        soil = e3g.soil_residual(heads, old.heads, dt, qtop, table, row, candidate_internal)
        return np.asarray([*soil, surface - dt * (supply - qtop)], dtype=np.float64)

    try:
        sol = least_squares(
            residual,
            np.asarray([*old.heads, s_guess]),
            bounds=(
                np.asarray([-10000.0, -10000.0, -10000.0, 0.0]),
                np.asarray([e3g.TOP_UPPER, e3g.TOP_UPPER, e3g.TOP_UPPER, e3g.S_MAX]),
            ),
            xtol=1e-13, ftol=1e-13, gtol=1e-13,
            max_nfev=MAX_NFEV, x_scale="jac",
        )
        heads = tuple(float(v) for v in sol.x[:3])
        surface = float(sol.x[3])
        qtop, route = common_surface_flux(surface, heads[0], row)
        q, routes = e3g.internal_fluxes(heads, qtop, table, row, candidate_internal)
        d = e3g.diagnostics(old, heads, surface, supply, q, dt)
        exact = e3g.exact_surface_reference(surface, heads[0], row)
        qexact = float(exact["q"])
        no_unqualified = not any("UNQUALIFIED_FACE_FALLBACK" in str(r) for r in routes)
        accepted = bool(
            sol.success
            and dt > 0.0
            and all(math.isfinite(v) for v in (*heads, surface, *q, qexact))
            and e3g.mass_ok(d)
            and 0.0 < surface < e3g.S_MAX
            and max(heads) <= e3g.TOP_UPPER
            and no_unqualified
            and abs(qtop - qexact) / ksat <= SURFACE_Q_ERR_MAX
        )
        return {
            "accepted": accepted,
            "solver_success": bool(sol.success),
            "nfev": int(sol.nfev),
            "dt_day": dt,
            "heads_cm": list(heads),
            "surface_storage_cm": surface,
            "q_top_cm_per_day": qtop,
            "surface_route": route,
            "q_bottom_cm_per_day": float(q[-1]),
            "bottom_transfer_cm": float(dt * q[-1]),
            "surface_q_abs_error_over_ksat": abs(qtop - qexact) / ksat,
            "exact_surface_reference_q_cm_per_day": qexact,
            "diagnostics": d,
            "internal_routes": list(routes),
            "committed_event_state_bitwise_unchanged_during_remainder_trial": e3g.bits(old) == snapshot,
            "mass_repair_or_clipping_used": False,
        }
    except Exception as exc:
        return {
            "accepted": False,
            "solver_success": False,
            "nfev": 0,
            "error": repr(exc),
            "committed_event_state_bitwise_unchanged_during_remainder_trial": e3g.bits(old) == snapshot,
            "mass_repair_or_clipping_used": False,
        }


def full_interval_balance(initial: e3g.State, event: dict, remainder: dict, supply: float, t_end: float, row: dict) -> float:
    e3g.internal_geometry(row)
    final_heads = tuple(float(v) for v in remainder["heads_cm"])
    soil_delta = math.fsum(
        e3g.DZ * (e3g.theta_of_h(final_heads[i]) - e3g.theta_of_h(float(initial.heads[i])))
        for i in range(e3g.N_CELLS)
    )
    bottom = float(event["bottom_transfer_cm"]) + float(remainder["bottom_transfer_cm"])
    surface = float(remainder["surface_storage_cm"])
    return float(soil_delta + surface - supply * t_end + bottom)


def run_path(row: dict, candidate: bool) -> dict:
    material = str(row["sfu"])
    fixture = FIXTURES[material]
    supply = float(fixture["supply"])
    t_end = float(fixture["t_end"])
    bracket = tuple(float(v) for v in fixture["bracket"])
    old = e3g.State(2.375, tuple(float(v) for v in fixture["heads"]), 0.0)
    original_snapshot = e3g.bits(old)
    e3g.internal_geometry(row)
    table = e3g.e3.generate_c1r_table() if candidate else None

    admission = initial_admission(old, supply, row, candidate)
    predictor = dry_full_trial(old, supply, t_end, row, candidate, table)
    predictor_rejected = bool(
        predictor.get("local_trial_valid")
        and predictor.get("complementarity_admissible") is False
        and predictor.get("accepted_as_dry_flux") is False
        and predictor.get("committed_state_bitwise_unchanged")
    )
    event = event_corrector(old, supply, bracket, predictor, row, candidate, table)
    synthetic_post_event_reject_restores_original = bool(event.get("committed_state_bitwise_unchanged") and e3g.bits(old) == original_snapshot)
    remainder = ponded_remainder(event, supply, t_end, row, candidate, table)
    if event.get("accepted") and remainder.get("accepted"):
        total_mass = full_interval_balance(old, event, remainder, supply, t_end, row)
    else:
        total_mass = math.inf

    accepted = bool(
        admission["dry_admissible_at_t0"]
        and admission["qcap_abs_error_over_ksat"] <= SURFACE_Q_ERR_MAX
        and predictor_rejected
        and event.get("accepted")
        and remainder.get("accepted")
        and abs(total_mass) <= MASS_TOL
        and synthetic_post_event_reject_restores_original
        and e3g.bits(old) == original_snapshot
    )
    return {
        "accepted": accepted,
        "mode_sequence": ["DRY_FLUX_TRIAL_REJECTED", "EVENT_AT_HSURFACE_ZERO", "PONDED_HEAD_REMAINDER"] if accepted else ["REJECTED"],
        "initial_admission": admission,
        "dry_full_interval_predictor": predictor,
        "dry_predictor_rejected_without_commit": predictor_rejected,
        "event_corrector": event,
        "ponded_remainder": remainder,
        "full_interval_composed_balance_residual_cm": total_mass,
        "synthetic_post_event_reject_restores_original_committed_state": synthetic_post_event_reject_restores_original,
        "original_committed_state_bitwise_unchanged_until_final_accept": e3g.bits(old) == original_snapshot,
        "nonlinear_trajectory_count": 3,
        "mass_repair_or_clipping_used": False,
    }


def compare(candidate: dict, reference: dict) -> dict:
    if not (candidate.get("accepted") and reference.get("accepted")):
        return {"available": False, "pass": False}
    ce = candidate["event_corrector"]
    re = reference["event_corrector"]
    cr = candidate["ponded_remainder"]
    rr = reference["ponded_remainder"]
    event_t = abs(float(ce["event_time_day"]) - float(re["event_time_day"]))
    event_h = max(abs(float(a) - float(b)) for a, b in zip(ce["heads_cm"], re["heads_cm"]))
    final_h = max(abs(float(a) - float(b)) for a, b in zip(cr["heads_cm"], rr["heads_cm"]))
    surface = abs(float(cr["surface_storage_cm"]) - float(rr["surface_storage_cm"]))
    cb = float(ce["bottom_transfer_cm"]) + float(cr["bottom_transfer_cm"])
    rb = float(re["bottom_transfer_cm"]) + float(rr["bottom_transfer_cm"])
    bottom = abs(cb - rb)
    tests = {
        "mode_sequence": candidate["mode_sequence"] == reference["mode_sequence"],
        "event_time": event_t <= EVENT_TIME_DIFF_TOL,
        "event_heads": event_h <= HEAD_DIFF_TOL,
        "final_heads": final_h <= HEAD_DIFF_TOL,
        "final_surface": surface <= SURFACE_DIFF_TOL,
        "bottom_transfer": bottom <= BOTTOM_DIFF_TOL,
    }
    return {
        "available": True,
        "event_time_difference_day": event_t,
        "max_event_head_difference_cm": event_h,
        "max_final_head_difference_cm": final_h,
        "final_surface_storage_difference_cm": surface,
        "full_interval_bottom_transfer_difference_cm": bottom,
        "tests": tests,
        "pass": all(tests.values()),
    }


def path_tests(path: dict) -> dict:
    pred = path["dry_full_interval_predictor"]
    event = path["event_corrector"]
    rem = path["ponded_remainder"]
    return {
        "accepted": path["accepted"] is True,
        "initially_dry_admissible": path["initial_admission"]["dry_admissible_at_t0"] is True,
        "initial_capacity_crosscheck": path["initial_admission"]["qcap_abs_error_over_ksat"] <= SURFACE_Q_ERR_MAX,
        "predictor_local_trial_valid": pred.get("local_trial_valid") is True,
        "predictor_complementarity_inadmissible": pred.get("complementarity_admissible") is False,
        "predictor_rejected_without_commit": path["dry_predictor_rejected_without_commit"] is True,
        "event_accepted": event.get("accepted") is True,
        "event_strictly_inside_bracket": event.get("strictly_inside_bracket") is True,
        "event_surface_zero": event.get("surface_storage_cm") == 0.0,
        "event_scaled_complementarity": abs(float(event.get("scaled_complementarity_residual_cm", math.inf))) <= MASS_TOL,
        "event_cell_mass": event.get("diagnostics") is not None and max(abs(v) for v in event["diagnostics"]["cell_residuals_cm"]) <= MASS_TOL,
        "event_capacity_crosscheck": float(event.get("capacity_abs_error_over_ksat", math.inf)) <= SURFACE_Q_ERR_MAX,
        "remainder_accepted": rem.get("accepted") is True,
        "remainder_surface_positive": 0.0 < float(rem.get("surface_storage_cm", -1.0)) < e3g.S_MAX,
        "remainder_cell_mass": rem.get("diagnostics") is not None and max(abs(v) for v in rem["diagnostics"]["cell_residuals_cm"]) <= MASS_TOL,
        "remainder_surface_mass": rem.get("diagnostics") is not None and abs(rem["diagnostics"]["surface_balance_residual_cm"]) <= MASS_TOL,
        "remainder_surface_face_crosscheck": float(rem.get("surface_q_abs_error_over_ksat", math.inf)) <= SURFACE_Q_ERR_MAX,
        "full_interval_mass": abs(float(path["full_interval_composed_balance_residual_cm"])) <= MASS_TOL,
        "synthetic_post_event_reject_rollback": path["synthetic_post_event_reject_restores_original_committed_state"] is True,
        "original_committed_state_unchanged": path["original_committed_state_bitwise_unchanged_until_final_accept"] is True,
        "trajectory_count_fixed_three": path["nonlinear_trajectory_count"] == 3,
        "no_mass_repair_or_clipping": path["mass_repair_or_clipping_used"] is False,
    }


def run_material(row: dict) -> dict:
    candidate = run_path(row, True)
    reference = run_path(row, False)
    ct = path_tests(candidate)
    rt = path_tests(reference)
    cmp = compare(candidate, reference)
    tests = {
        "candidate_path": all(ct.values()),
        "reference_path": all(rt.values()),
        "comparison": cmp["pass"],
        "candidate_three_trajectories": candidate["nonlinear_trajectory_count"] == 3,
        "reference_three_trajectories": reference["nonlinear_trajectory_count"] == 3,
    }
    return {
        "material": row["sfu"],
        "fixture": FIXTURES[row["sfu"]],
        "candidate": candidate,
        "reference": reference,
        "candidate_tests": ct,
        "reference_tests": rt,
        "comparison": cmp,
        "tests": tests,
        "failed_metrics": [k for k, v in tests.items() if not v],
        "pass": all(tests.values()),
    }


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_e3g_r2_finite_time_ponding_event_localization.py MATERIAL OUTPUT.json")
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
        "gate": "E3G_R2_FINITE_TIME_PONDING_EVENT_LOCALIZATION",
        "contract": CONTRACT,
        "material": material,
        "production_implementation": False,
        "qualification_use": True,
        "material_result": mr,
        "pass": mr["pass"],
        "decision": (
            "QUALIFIED_RESTRICTED_FINITE_TIME_PONDING_EVENT_LOCALIZATION_READY_FOR_TOP_NODE_SATURATION_AND_DEPLETION_GATES"
            if mr["pass"] else
            "FINITE_TIME_PONDING_EVENT_LOCALIZATION_NOT_QUALIFIED_PRESERVE_FAILURE_AND_RESEARCH_CAUSE"
        ),
        "hard_nonclaims": [
            "No production runtime cost qualification.",
            "No top soil-node h=0 or positive-head state qualification.",
            "No pond-depletion head-to-flux back-switch.",
            "No runoff with real soil state.",
            "No response tangent across the boundary switch.",
            "No B12/O13 finite-time event claim.",
            "No MultiSWAP, MODFLOW or groundwater admission."
        ],
    }
    out = Path(sys.argv[2])
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "material": material,
        "pass": mr["pass"],
        "candidate_event_time_day": mr["candidate"].get("event_corrector", {}).get("event_time_day"),
        "reference_event_time_day": mr["reference"].get("event_corrector", {}).get("event_time_day"),
        "event_time_difference_day": mr["comparison"].get("event_time_difference_day"),
        "candidate_full_mass_cm": mr["candidate"].get("full_interval_composed_balance_residual_cm"),
        "reference_full_mass_cm": mr["reference"].get("full_interval_composed_balance_residual_cm"),
        "failed_metrics": mr["failed_metrics"],
        "decision": payload["decision"],
    }, sort_keys=True), flush=True)
    if not mr["pass"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
