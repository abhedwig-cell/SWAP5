from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import numpy as np
from scipy.optimize import least_squares

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_e3g_physical_top_boundary_switch_composition as e3g

CONTRACT = "F-ROSS01_GATE_E3G_R3A_POND_DEPLETION_FIXTURE_CHARACTERIZATION_PRECOMMIT.json"
SEED_ADDENDUM = "F-ROSS01_GATE_E3G_R3A_POND_DEPLETION_FIXTURE_CHARACTERIZATION_PREEXECUTION_SEED_ADDENDUM.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = ("B01", "O14")
SUPPLY_FRACTIONS = (0.0, 0.25, 0.5, 0.75)
MASS_TOL = 1.0e-9
MAX_NFEV = 160
EPS = sys.float_info.epsilon
TOP_UPPER = -1.0e-8

START = {
    "B01": {
        "t_day": 2.425,
        "heads": (-4.299242078690873, -34.413158005349246, -56.56069262268569),
        "surface": 0.8393321374175227,
        "time_bounds": (1.0e-5, 0.2),
        "post_cap": 0.005,
    },
    "O14": {
        "t_day": 2.385,
        "heads": (-45.88800284752272, -87.53789121305483, -77.42958217413684),
        "surface": 0.011992883907773078,
        "time_bounds": (1.0e-6, 0.02),
        "post_cap": 0.001,
    },
}


def qtop_reference(hs: float, ht: float, row: dict) -> tuple[float, str]:
    ref = e3g.exact_surface_reference(float(hs), float(ht), row)
    return float(ref["q"]), str(ref.get("branch", "EXACT_ENDPOINT_AWARE_REFERENCE"))


def reference_fluxes(heads: tuple[float, float, float], qtop: float, row: dict):
    q, routes = e3g.internal_fluxes(heads, qtop, None, row, False)
    return tuple(float(v) for v in q), tuple(str(r) for r in routes)


def event_seed(old: e3g.State, supply: float, row: dict, bounds: tuple[float, float]) -> tuple[float, float]:
    q0, _ = qtop_reference(old.surface, old.heads[0], row)
    if not q0 > supply:
        return q0, 0.5 * (bounds[0] + bounds[1])
    raw = old.surface / (q0 - supply)
    lo, hi = bounds
    width = hi - lo
    seed = min(hi - 0.1 * width, max(lo + 0.1 * width, raw))
    return q0, float(seed)


def solve_event(old: e3g.State, supply: float, row: dict, bounds: tuple[float, float]) -> dict:
    e3g.internal_geometry(row)
    q0, tseed = event_seed(old, supply, row, bounds)
    tlo, thi = bounds
    snapshot = e3g.bits(old)

    def residual(x):
        heads = tuple(float(v) for v in x[:3])
        te = float(x[3])
        qtop, _ = qtop_reference(0.0, heads[0], row)
        soil = e3g.soil_residual(heads, old.heads, te, qtop, None, row, False)
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
            xtol=1e-13,
            ftol=1e-13,
            gtol=1e-13,
            max_nfev=MAX_NFEV,
            x_scale="jac",
        )
        heads = tuple(float(v) for v in sol.x[:3])
        te = float(sol.x[3])
        qtop, route = qtop_reference(0.0, heads[0], row)
        q, routes = reference_fluxes(heads, qtop, row)
        d = e3g.diagnostics(old, heads, 0.0, supply, q, te)
        tol = 64.0 * EPS * max(1.0, abs(supply), abs(qtop))
        strict_inside = bool(te > tlo + 64.0 * EPS * max(1.0, abs(tlo)) and te < thi - 64.0 * EPS * max(1.0, abs(thi)))
        qmargin = qtop - supply
        accepted = bool(
            sol.success
            and all(math.isfinite(v) for v in (*heads, te, qtop, *q))
            and e3g.mass_ok(d)
            and strict_inside
            and max(heads) <= TOP_UPPER
            and qmargin > tol
        )
        return {
            "accepted": accepted,
            "solver_success": bool(sol.success),
            "nfev": int(sol.nfev),
            "qtop_initial_cm_per_day": q0,
            "time_seed_day": tseed,
            "event_time_day": te,
            "time_bounds_day": [tlo, thi],
            "heads_cm": list(heads),
            "surface_storage_cm": 0.0,
            "q_top_cm_per_day": qtop,
            "q_top_minus_supply_cm_per_day": qmargin,
            "roundoff_tolerance_cm_per_day": tol,
            "surface_route": route,
            "internal_routes": list(routes),
            "q_bottom_cm_per_day": float(q[-1]),
            "bottom_transfer_cm": float(te * q[-1]),
            "diagnostics": d,
            "strictly_inside_bounds": strict_inside,
            "committed_start_bitwise_unchanged": e3g.bits(old) == snapshot,
            "mass_repair_or_clipping_used": False,
        }
    except Exception as exc:
        return {
            "accepted": False,
            "solver_success": False,
            "error": repr(exc),
            "qtop_initial_cm_per_day": q0,
            "time_seed_day": tseed,
            "committed_start_bitwise_unchanged": e3g.bits(old) == snapshot,
            "mass_repair_or_clipping_used": False,
        }


def dry_continuation(event: dict, supply: float, row: dict, post_cap: float, t0: float) -> dict:
    if not event.get("accepted"):
        return {"accepted": False, "error": "event_not_accepted", "mass_repair_or_clipping_used": False}
    te = float(event["event_time_day"])
    dt = min(0.25 * te, float(post_cap))
    old = e3g.State(t0 + te, tuple(float(v) for v in event["heads_cm"]), 0.0)
    snapshot = e3g.bits(old)
    e3g.internal_geometry(row)

    fun = lambda h: e3g.soil_residual(h, old.heads, dt, supply, None, row, False)
    try:
        sol = least_squares(
            fun,
            np.asarray(old.heads, dtype=np.float64),
            bounds=(np.full(3, -10000.0), np.full(3, TOP_UPPER)),
            xtol=1e-13,
            ftol=1e-13,
            gtol=1e-13,
            max_nfev=MAX_NFEV,
            x_scale="jac",
        )
        heads = tuple(float(v) for v in sol.x)
        q, routes = reference_fluxes(heads, supply, row)
        d = e3g.diagnostics(old, heads, 0.0, supply, q, dt)
        qcap, caproute = qtop_reference(0.0, heads[0], row)
        tol = 64.0 * EPS * max(1.0, abs(supply), abs(qcap))
        admissible = bool(supply <= qcap + tol)
        accepted = bool(
            sol.success
            and all(math.isfinite(v) for v in (*heads, *q, qcap))
            and e3g.mass_ok(d)
            and max(heads) <= TOP_UPPER
            and admissible
        )
        return {
            "accepted": accepted,
            "solver_success": bool(sol.success),
            "nfev": int(sol.nfev),
            "dt_day": dt,
            "heads_cm": list(heads),
            "surface_storage_cm": 0.0,
            "q_surface_capacity_cm_per_day": qcap,
            "capacity_route": caproute,
            "complementarity_admissible": admissible,
            "internal_routes": list(routes),
            "diagnostics": d,
            "committed_event_state_bitwise_unchanged_during_trial": e3g.bits(old) == snapshot,
            "mass_repair_or_clipping_used": False,
        }
    except Exception as exc:
        return {
            "accepted": False,
            "solver_success": False,
            "error": repr(exc),
            "dt_day": dt,
            "committed_event_state_bitwise_unchanged_during_trial": e3g.bits(old) == snapshot,
            "mass_repair_or_clipping_used": False,
        }


def run_material(row: dict) -> dict:
    material = str(row["sfu"])
    spec = START[material]
    old = e3g.State(float(spec["t_day"]), tuple(spec["heads"]), float(spec["surface"]))
    ksat = float(row["ksatfit_cm_per_day"])
    results = []

    for fraction in SUPPLY_FRACTIONS:
        supply = fraction * ksat
        event = solve_event(old, supply, row, tuple(spec["time_bounds"]))
        cont = dry_continuation(event, supply, row, float(spec["post_cap"]), float(spec["t_day"]))
        event_d = event.get("diagnostics") or {}
        cont_d = cont.get("diagnostics") or {}
        tests = {
            "event_accepted": event.get("accepted") is True,
            "event_mass": event.get("accepted") is True and max(
                max((abs(v) for v in event_d.get("cell_residuals_cm", [math.inf])), default=math.inf),
                abs(float(event_d.get("surface_balance_residual_cm", math.inf))),
                abs(float(event_d.get("composed_balance_residual_cm", math.inf))),
            ) <= MASS_TOL,
            "event_depleting_direction": event.get("accepted") is True and float(event.get("q_top_minus_supply_cm_per_day", -math.inf)) > float(event.get("roundoff_tolerance_cm_per_day", math.inf)),
            "event_surface_zero": event.get("surface_storage_cm") == 0.0,
            "event_top_negative": event.get("heads_cm") is not None and max(event["heads_cm"]) <= TOP_UPPER,
            "event_start_unchanged": event.get("committed_start_bitwise_unchanged") is True,
            "dry_continuation_accepted": cont.get("accepted") is True,
            "dry_continuation_mass": cont.get("accepted") is True and max(
                max((abs(v) for v in cont_d.get("cell_residuals_cm", [math.inf])), default=math.inf),
                abs(float(cont_d.get("surface_balance_residual_cm", math.inf))),
                abs(float(cont_d.get("composed_balance_residual_cm", math.inf))),
            ) <= MASS_TOL,
            "dry_complementarity": cont.get("complementarity_admissible") is True,
            "dry_surface_zero": cont.get("surface_storage_cm") == 0.0,
            "dry_event_state_unchanged": cont.get("committed_event_state_bitwise_unchanged_during_trial") is True,
            "no_mass_repair_or_clipping": event.get("mass_repair_or_clipping_used") is False and cont.get("mass_repair_or_clipping_used") is False,
        }
        results.append({
            "supply_fraction_ksat": fraction,
            "q_supply_cm_per_day": supply,
            "event": event,
            "dry_continuation": cont,
            "tests": tests,
            "pass": all(tests.values()),
        })

    passing = [r for r in results if r["pass"]]
    selected = max(passing, key=lambda r: r["supply_fraction_ksat"]) if passing else None
    return {
        "material": material,
        "start_state": {
            "t_day": old.t_day,
            "heads_cm": list(old.heads),
            "surface_storage_cm": old.surface,
        },
        "scan": results,
        "passing_fraction_count": len(passing),
        "selected_fixture": selected,
        "pass": selected is not None,
    }


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_e3g_r3a_pond_depletion_fixture_characterization.py MATERIAL OUTPUT.json")
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
        "gate": "E3G_R3A_POND_DEPLETION_FIXTURE_CHARACTERIZATION",
        "contract": CONTRACT,
        "seed_addendum": SEED_ADDENDUM,
        "material": material,
        "production_implementation": False,
        "qualification_use": False,
        "reference_only": True,
        "material_result": mr,
        "pass": mr["pass"],
        "decision": (
            "CHARACTERIZED_POND_DEPLETION_FIXTURE_READY_FOR_R3_QUALIFICATION_PRECOMMIT"
            if mr["pass"] else
            "NO_VALID_POND_DEPLETION_FIXTURE_IN_FROZEN_SCAN_RESEARCH_REQUIRED"
        ),
        "hard_nonclaims": [
            "No pond-depletion event algorithm is qualified.",
            "No candidate RossFast path is tested.",
            "No top-node h=0 or positive-head state is qualified.",
            "No runoff, ET, snow, irrigation, response tangent, runtime, MultiSWAP or MODFLOW admission."
        ],
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    sel = mr["selected_fixture"]
    print(json.dumps({
        "material": material,
        "pass": mr["pass"],
        "passing_fraction_count": mr["passing_fraction_count"],
        "selected_supply_fraction_ksat": None if sel is None else sel["supply_fraction_ksat"],
        "selected_event_time_day": None if sel is None else sel["event"]["event_time_day"],
        "decision": payload["decision"],
    }, sort_keys=True), flush=True)
    if not mr["pass"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
