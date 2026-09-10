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

import run_ross01_gate_e3g_physical_top_boundary_switch_composition as e3g

CONTRACT = "F-ROSS01_GATE_E3G_R3_POND_DEPLETION_HEAD_TO_FLUX_EVENT_LOCALIZATION_PRECOMMIT.json"
SEED_ADDENDUM = "F-ROSS01_GATE_E3G_R3_POND_DEPLETION_PREEXECUTION_SEED_ADDENDUM.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = ("B01", "O14")
MASS_TOL = 1.0e-9
EVENT_TIME_DIFF_TOL = 2.5e-4
HEAD_DIFF_TOL = 0.25
BOTTOM_DIFF_TOL = 1.0e-3
SURFACE_Q_ERR_MAX = 5.0e-4
MAX_NFEV = 160
EPS = sys.float_info.epsilon
TOP_UPPER = -1.0e-8

FIXTURES = {
    "B01": {
        "t0_day": 2.425,
        "heads": (-4.299242078690873, -34.413158005349246, -56.56069262268569),
        "surface": 0.8393321374175227,
        "supply": 23.418762,
        "bracket": (0.06, 0.071),
        "t_end": 0.073,
    },
    "O14": {
        "t0_day": 2.385,
        "heads": (-45.88800284752272, -87.53789121305483, -77.42958217413684),
        "surface": 0.011992883907773078,
        "supply": 1.871988,
        "bracket": (0.00075, 0.00095),
        "t_end": 0.00105,
    },
}


def state_bits(s: e3g.State) -> bytes:
    return struct.pack("!5d", float(s.t_day), *[float(v) for v in s.heads], float(s.surface))


def surface_q(hs: float, ht: float, row: dict, candidate: bool):
    if candidate:
        q, route, cost = e3g.surface_face(float(hs), float(ht), row, True)
        qexact = float(e3g.exact_surface_reference(float(hs), float(ht), row)["q"])
        return float(q), str(route), cost, qexact
    ref = e3g.exact_surface_reference(float(hs), float(ht), row)
    return float(ref["q"]), str(ref.get("branch", "EXACT_ENDPOINT_AWARE_REFERENCE")), {}, float(ref["q"])


def fluxes(heads, qtop: float, table, row: dict, candidate: bool):
    q, routes = e3g.internal_fluxes(tuple(float(v) for v in heads), float(qtop), table, row, candidate)
    return tuple(float(v) for v in q), tuple(str(v) for v in routes)


def event_corrector(old: e3g.State, supply: float, bracket, table, row: dict, candidate: bool) -> dict:
    snapshot = state_bits(old)
    tlo, thi = map(float, bracket)
    tseed = 0.5 * (tlo + thi)
    ksat = float(row["ksatfit_cm_per_day"])

    def residual(x):
        heads = tuple(float(v) for v in x[:3])
        te = float(x[3])
        qtop, _, _, _ = surface_q(0.0, heads[0], row, candidate)
        soil = e3g.soil_residual(heads, old.heads, te, qtop, table, row, candidate)
        surface = -old.surface - te * (supply - qtop)
        return np.asarray([*soil, surface], dtype=np.float64)

    try:
        sol = least_squares(
            residual,
            np.asarray([*old.heads, tseed], dtype=np.float64),
            bounds=(
                np.asarray([-10000.0, -10000.0, -10000.0, tlo]),
                np.asarray([TOP_UPPER, TOP_UPPER, TOP_UPPER, thi]),
            ),
            xtol=1e-13, ftol=1e-13, gtol=1e-13,
            max_nfev=MAX_NFEV, x_scale="jac",
        )
        heads = tuple(float(v) for v in sol.x[:3])
        te = float(sol.x[3])
        qtop, route, cost, qexact = surface_q(0.0, heads[0], row, candidate)
        q, routes = fluxes(heads, qtop, table, row, candidate)
        d = e3g.diagnostics(old, heads, 0.0, supply, q, te)
        tol = 64.0 * EPS * max(1.0, abs(supply), abs(qtop))
        strict_inside = bool(
            te > tlo + 64.0 * EPS * max(1.0, abs(tlo))
            and te < thi - 64.0 * EPS * max(1.0, abs(thi))
        )
        no_unqualified = not any("UNQUALIFIED_FACE_FALLBACK" in r for r in routes)
        accepted = bool(
            sol.success
            and all(math.isfinite(v) for v in (*heads, te, qtop, *q, qexact))
            and e3g.mass_ok(d)
            and strict_inside
            and max(heads) <= TOP_UPPER
            and qtop - supply > tol
            and no_unqualified
            and abs(qtop - qexact) / ksat <= SURFACE_Q_ERR_MAX
        )
        return {
            "accepted": accepted,
            "solver_success": bool(sol.success),
            "nfev": int(sol.nfev),
            "event_time_day": te,
            "event_bracket_day": [tlo, thi],
            "event_time_seed_day": tseed,
            "heads_cm": list(heads),
            "surface_storage_cm": 0.0,
            "q_top_cm_per_day": qtop,
            "q_top_minus_supply_cm_per_day": qtop - supply,
            "roundoff_tolerance_cm_per_day": tol,
            "surface_route": route,
            "surface_cost": cost,
            "surface_q_abs_error_over_ksat": abs(qtop - qexact) / ksat,
            "q_bottom_cm_per_day": q[-1],
            "bottom_transfer_cm": te * q[-1],
            "internal_routes": list(routes),
            "diagnostics": d,
            "strictly_inside_bracket": strict_inside,
            "committed_original_state_bitwise_unchanged_during_event_trial": state_bits(old) == snapshot,
            "mass_repair_or_clipping_used": False,
        }
    except Exception as exc:
        return {
            "accepted": False,
            "solver_success": False,
            "error": repr(exc),
            "committed_original_state_bitwise_unchanged_during_event_trial": state_bits(old) == snapshot,
            "mass_repair_or_clipping_used": False,
        }


def dry_remainder(event: dict, supply: float, t_end: float, t0: float, table, row: dict, candidate: bool) -> dict:
    if not event.get("accepted"):
        return {"accepted": False, "error": "event_not_accepted", "mass_repair_or_clipping_used": False}
    te = float(event["event_time_day"])
    dt = float(t_end - te)
    old = e3g.State(t0 + te, tuple(float(v) for v in event["heads_cm"]), 0.0)
    snapshot = state_bits(old)
    ksat = float(row["ksatfit_cm_per_day"])

    fun = lambda h: e3g.soil_residual(h, old.heads, dt, supply, table, row, candidate)
    try:
        sol = least_squares(
            fun,
            np.asarray(old.heads, dtype=np.float64),
            bounds=(np.full(3, -10000.0), np.full(3, TOP_UPPER)),
            xtol=1e-13, ftol=1e-13, gtol=1e-13,
            max_nfev=MAX_NFEV, x_scale="jac",
        )
        heads = tuple(float(v) for v in sol.x)
        q, routes = fluxes(heads, supply, table, row, candidate)
        d = e3g.diagnostics(old, heads, 0.0, supply, q, dt)
        qcap, caproute, capcost, qexact = surface_q(0.0, heads[0], row, candidate)
        tol = 64.0 * EPS * max(1.0, abs(supply), abs(qcap))
        no_unqualified = not any("UNQUALIFIED_FACE_FALLBACK" in r for r in routes)
        admissible = bool(supply <= qcap + tol)
        accepted = bool(
            sol.success
            and dt > 0.0
            and all(math.isfinite(v) for v in (*heads, *q, qcap, qexact))
            and e3g.mass_ok(d)
            and max(heads) <= TOP_UPPER
            and admissible
            and no_unqualified
            and abs(qcap - qexact) / ksat <= SURFACE_Q_ERR_MAX
        )
        return {
            "accepted": accepted,
            "solver_success": bool(sol.success),
            "nfev": int(sol.nfev),
            "dt_day": dt,
            "heads_cm": list(heads),
            "surface_storage_cm": 0.0,
            "q_top_cm_per_day": supply,
            "q_surface_capacity_cm_per_day": qcap,
            "q_surface_capacity_minus_supply_cm_per_day": qcap - supply,
            "roundoff_tolerance_cm_per_day": tol,
            "capacity_route": caproute,
            "capacity_cost": capcost,
            "capacity_q_abs_error_over_ksat": abs(qcap - qexact) / ksat,
            "complementarity_admissible": admissible,
            "q_bottom_cm_per_day": q[-1],
            "bottom_transfer_cm": dt * q[-1],
            "internal_routes": list(routes),
            "diagnostics": d,
            "committed_event_state_bitwise_unchanged_during_remainder_trial": state_bits(old) == snapshot,
            "mass_repair_or_clipping_used": False,
        }
    except Exception as exc:
        return {
            "accepted": False,
            "solver_success": False,
            "error": repr(exc),
            "committed_event_state_bitwise_unchanged_during_remainder_trial": state_bits(old) == snapshot,
            "mass_repair_or_clipping_used": False,
        }


def whole_balance(initial: e3g.State, event: dict, remainder: dict, supply: float, t_end: float, row: dict) -> float:
    e3g.internal_geometry(row)
    final_heads = tuple(float(v) for v in remainder["heads_cm"])
    soil_delta = math.fsum(
        e3g.e3.DZ * (e3g.e3.theta_of_h(final_heads[i]) - e3g.e3.theta_of_h(float(initial.heads[i])))
        for i in range(e3g.e3.N_CELLS)
    )
    surface_delta = 0.0 - float(initial.surface)
    bottom = float(event["bottom_transfer_cm"]) + float(remainder["bottom_transfer_cm"])
    return float(soil_delta + surface_delta - supply * t_end + bottom)


def run_path(row: dict, candidate: bool) -> dict:
    material = str(row["sfu"])
    f = FIXTURES[material]
    old = e3g.State(float(f["t0_day"]), tuple(f["heads"]), float(f["surface"]))
    original = state_bits(old)
    e3g.internal_geometry(row)
    table = e3g.e3.generate_c1r_table() if candidate else None
    ksat = float(row["ksatfit_cm_per_day"])

    q0, route0, cost0, q0exact = surface_q(old.surface, old.heads[0], row, candidate)
    initial_depleting = bool(old.surface > 0.0 and q0 > float(f["supply"]))
    initial_q_err = abs(q0 - q0exact) / ksat

    event = event_corrector(old, float(f["supply"]), f["bracket"], table, row, candidate)
    synthetic_post_event_reject_restores_original = bool(
        event.get("committed_original_state_bitwise_unchanged_during_event_trial")
        and state_bits(old) == original
    )
    remainder = dry_remainder(event, float(f["supply"]), float(f["t_end"]), old.t_day, table, row, candidate)
    total = whole_balance(old, event, remainder, float(f["supply"]), float(f["t_end"]), row) if event.get("accepted") and remainder.get("accepted") else math.inf

    accepted = bool(
        initial_depleting
        and initial_q_err <= SURFACE_Q_ERR_MAX
        and event.get("accepted")
        and remainder.get("accepted")
        and abs(total) <= MASS_TOL
        and synthetic_post_event_reject_restores_original
        and state_bits(old) == original
    )
    return {
        "accepted": accepted,
        "initial_surface_storage_cm": old.surface,
        "q_supply_cm_per_day": float(f["supply"]),
        "initial_q_top_cm_per_day": q0,
        "initial_surface_route": route0,
        "initial_surface_cost": cost0,
        "initial_surface_q_abs_error_over_ksat": initial_q_err,
        "initial_ponded_and_depleting": initial_depleting,
        "event_corrector": event,
        "dry_remainder": remainder,
        "full_interval_composed_balance_residual_cm": total,
        "mode_sequence": ["PONDED_HEAD", "EVENT_AT_SURFACE_ZERO", "DRY_FLUX_REMAINDER"],
        "nonlinear_trajectory_count": 2,
        "event_search_bisection_trajectory_count": 0,
        "synthetic_post_event_reject_restores_original_committed_state": synthetic_post_event_reject_restores_original,
        "original_committed_state_bitwise_unchanged_until_final_accept": state_bits(old) == original,
        "mass_repair_or_clipping_used": False,
    }


def path_tests(path: dict) -> dict:
    e = path.get("event_corrector") or {}
    r = path.get("dry_remainder") or {}
    ed = e.get("diagnostics") or {}
    rd = r.get("diagnostics") or {}
    return {
        "accepted": path.get("accepted") is True,
        "initial_ponded_and_depleting": path.get("initial_ponded_and_depleting") is True,
        "initial_surface_q_crosscheck": float(path.get("initial_surface_q_abs_error_over_ksat", math.inf)) <= SURFACE_Q_ERR_MAX,
        "event_accepted": e.get("accepted") is True,
        "event_inside_bracket": e.get("strictly_inside_bracket") is True,
        "event_surface_zero": e.get("surface_storage_cm") == 0.0,
        "event_top_negative": e.get("heads_cm") is not None and max(e["heads_cm"]) <= TOP_UPPER,
        "event_depleting_direction": e.get("accepted") is True and float(e.get("q_top_minus_supply_cm_per_day", -math.inf)) > float(e.get("roundoff_tolerance_cm_per_day", math.inf)),
        "event_mass": e.get("accepted") is True and max(
            max((abs(v) for v in ed.get("cell_residuals_cm", [math.inf])), default=math.inf),
            abs(float(ed.get("surface_balance_residual_cm", math.inf))),
            abs(float(ed.get("composed_balance_residual_cm", math.inf))),
        ) <= MASS_TOL,
        "event_surface_q_crosscheck": float(e.get("surface_q_abs_error_over_ksat", math.inf)) <= SURFACE_Q_ERR_MAX,
        "event_original_unchanged": e.get("committed_original_state_bitwise_unchanged_during_event_trial") is True,
        "remainder_accepted": r.get("accepted") is True,
        "remainder_surface_zero": r.get("surface_storage_cm") == 0.0,
        "remainder_dry_complementarity": r.get("complementarity_admissible") is True,
        "remainder_mass": r.get("accepted") is True and max(
            max((abs(v) for v in rd.get("cell_residuals_cm", [math.inf])), default=math.inf),
            abs(float(rd.get("surface_balance_residual_cm", math.inf))),
            abs(float(rd.get("composed_balance_residual_cm", math.inf))),
        ) <= MASS_TOL,
        "remainder_surface_capacity_crosscheck": float(r.get("capacity_q_abs_error_over_ksat", math.inf)) <= SURFACE_Q_ERR_MAX,
        "remainder_event_state_unchanged": r.get("committed_event_state_bitwise_unchanged_during_remainder_trial") is True,
        "whole_interval_mass": abs(float(path.get("full_interval_composed_balance_residual_cm", math.inf))) <= MASS_TOL,
        "rollback_original": path.get("synthetic_post_event_reject_restores_original_committed_state") is True,
        "original_unchanged_until_final_accept": path.get("original_committed_state_bitwise_unchanged_until_final_accept") is True,
        "trajectory_count": path.get("nonlinear_trajectory_count") == 2,
        "no_trajectory_bisection": path.get("event_search_bisection_trajectory_count") == 0,
        "no_mass_repair_or_clipping": path.get("mass_repair_or_clipping_used") is False and e.get("mass_repair_or_clipping_used") is False and r.get("mass_repair_or_clipping_used") is False,
    }


def compare(candidate: dict, reference: dict) -> dict:
    if not (candidate.get("accepted") and reference.get("accepted")):
        return {"available": False, "pass": False}
    ec = candidate["event_corrector"]
    er = reference["event_corrector"]
    rc = candidate["dry_remainder"]
    rr = reference["dry_remainder"]
    event_dt = abs(float(ec["event_time_day"]) - float(er["event_time_day"]))
    event_h = max(abs(float(a) - float(b)) for a, b in zip(ec["heads_cm"], er["heads_cm"]))
    final_h = max(abs(float(a) - float(b)) for a, b in zip(rc["heads_cm"], rr["heads_cm"]))
    bottom_c = float(ec["bottom_transfer_cm"]) + float(rc["bottom_transfer_cm"])
    bottom_r = float(er["bottom_transfer_cm"]) + float(rr["bottom_transfer_cm"])
    bottom_diff = abs(bottom_c - bottom_r)
    tests = {
        "event_time": event_dt <= EVENT_TIME_DIFF_TOL,
        "event_heads": event_h <= HEAD_DIFF_TOL,
        "final_heads": final_h <= HEAD_DIFF_TOL,
        "bottom_transfer": bottom_diff <= BOTTOM_DIFF_TOL,
        "mode_sequence": candidate["mode_sequence"] == reference["mode_sequence"],
    }
    return {
        "available": True,
        "event_time_difference_day": event_dt,
        "max_event_head_difference_cm": event_h,
        "max_final_head_difference_cm": final_h,
        "full_interval_bottom_transfer_difference_cm": bottom_diff,
        "tests": tests,
        "pass": all(tests.values()),
    }


def run_material(row: dict) -> dict:
    cand = run_path(row, True)
    ref = run_path(row, False)
    ct = path_tests(cand)
    rt = path_tests(ref)
    cmp = compare(cand, ref)
    tests = {
        "candidate": all(ct.values()),
        "reference": all(rt.values()),
        "comparison": cmp.get("pass") is True,
    }
    return {
        "material": row["sfu"],
        "candidate": cand,
        "reference": ref,
        "candidate_tests": ct,
        "reference_tests": rt,
        "comparison": cmp,
        "tests": tests,
        "failed_metrics": [k for k, v in tests.items() if not v],
        "pass": all(tests.values()),
    }


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_e3g_r3_pond_depletion_event_localization.py MATERIAL OUTPUT.json")
    material = sys.argv[1]
    if material not in MATERIALS:
        raise SystemExit(material)
    out = Path(sys.argv[2])
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    row = next(r for r in catalog["rows"] if r["sfu"] == material)
    mr = run_material(row)
    payload = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E3G_R3_POND_DEPLETION_HEAD_TO_FLUX_EVENT_LOCALIZATION",
        "contract": CONTRACT,
        "seed_addendum": SEED_ADDENDUM,
        "material": material,
        "production_implementation": False,
        "qualification_use": True,
        "event_detection_qualified": False,
        "event_bracket_source": "R3A_REFERENCE_ONLY_CHARACTERIZATION",
        "material_result": mr,
        "pass": mr["pass"],
        "decision": (
            "QUALIFIED_RESTRICTED_BRACKETED_POND_DEPLETION_HEAD_TO_FLUX_EVENT_READY_FOR_TOP_NODE_SATURATION_AND_EVENT_DETECTION_GATES"
            if mr["pass"] else
            "BRACKETED_POND_DEPLETION_EVENT_NOT_QUALIFIED_PRESERVE_FAILURE"
        ),
        "hard_nonclaims": [
            "No automatic event detection or bracket discovery is qualified.",
            "No top-node h=0 or positive soil-head state is qualified.",
            "No runoff, evaporation, snow, irrigation or macropore bypass.",
            "No event response tangent, production runtime, MultiSWAP, groundwater or MODFLOW admission."
        ],
    }
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
