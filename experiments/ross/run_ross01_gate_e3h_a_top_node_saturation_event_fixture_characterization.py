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

CONTRACT = "F-ROSS01_GATE_E3H_A_TOP_NODE_SATURATION_EVENT_FIXTURE_CHARACTERIZATION_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = ("B01", "B12", "O13", "O14")
INITIAL_HEADS = (-0.2, -1.5, -5.0)
S0 = 0.02
BOTTOM_HEAD = -15.0
SUPPLY_FRACTIONS = (1.5, 2.0, 3.0, 5.0, 8.0, 12.0)
TAU_LO = 1.0e-8
TAU_HI = 0.05
SURFACE_LO = 1.0e-12
SURFACE_HI = 1.0
H_DRY_HI = -1.0
MASS_TOL = 1.0e-9
TIME_DIFF_TOL = 2.5e-4
HEAD_DIFF_TOL = 0.25
SURFACE_DIFF_TOL = 1.0e-3
MAX_NFEV = 200
DZ = 10.0
SURFACE_FACE_LENGTH = 5.0


def bits(values) -> bytes:
    return b"".join(struct.pack("!d", float(v)) for v in values)


def configure(row: dict) -> None:
    e3g.internal_geometry(row)


def theta(h: float) -> float:
    return float(e3g.e3.theta_of_h(float(h)))


def saturated_surface_q(surface: float, row: dict) -> float:
    ks = float(row["ksatfit_cm_per_day"])
    return ks * (1.0 + float(surface) / SURFACE_FACE_LENGTH)


def internal_q(h0: float, h1: float, h2: float, row: dict, candidate: bool, table):
    configure(row)
    if candidate:
        q01, r01 = e3g.e3.candidate_face(float(h0), float(h1), table)
        q12, r12 = e3g.e3.candidate_face(float(h1), float(h2), table)
        qb, rb = e3g.e3.candidate_face(float(h2), BOTTOM_HEAD, table)
        return (float(q01), float(q12), float(qb)), (str(r01), str(r12), str(rb))
    return (
        float(e3g.e3.reference_face(float(h0), float(h1))),
        float(e3g.e3.reference_face(float(h1), float(h2))),
        float(e3g.e3.reference_face(float(h2), BOTTOM_HEAD)),
    ), ("REFERENCE", "REFERENCE", "REFERENCE")


def event_residual(x, supply: float, row: dict, candidate: bool, table):
    h1, h2, surface, tau = map(float, x)
    h0 = 0.0
    qtop = saturated_surface_q(surface, row)
    (q01, q12, qb), _ = internal_q(h0, h1, h2, row, candidate, table)
    return np.asarray([
        DZ * (theta(h0) - theta(INITIAL_HEADS[0])) - tau * (qtop - q01),
        DZ * (theta(h1) - theta(INITIAL_HEADS[1])) - tau * (q01 - q12),
        DZ * (theta(h2) - theta(INITIAL_HEADS[2])) - tau * (q12 - qb),
        (surface - S0) - tau * (supply - qtop),
    ], dtype=np.float64)


def solve_event(row: dict, supply: float, candidate: bool, table) -> dict:
    configure(row)
    snapshot = bits((*INITIAL_HEADS, S0))
    ks = float(row["ksatfit_cm_per_day"])
    x0 = np.asarray([-1.25, -4.5, min(0.25, max(S0, S0 + 0.001 * max(supply - ks, 0.0))), 0.001], dtype=np.float64)
    try:
        sol = least_squares(
            lambda x: event_residual(x, supply, row, candidate, table),
            x0,
            bounds=(
                np.asarray([-10000.0, -10000.0, SURFACE_LO, TAU_LO]),
                np.asarray([H_DRY_HI, H_DRY_HI, SURFACE_HI, TAU_HI]),
            ),
            xtol=1e-13, ftol=1e-13, gtol=1e-13,
            max_nfev=MAX_NFEV, x_scale="jac",
        )
        h1, h2, surface, tau = map(float, sol.x)
        res = event_residual(sol.x, supply, row, candidate, table)
        qtop = saturated_surface_q(surface, row)
        (q01, q12, qb), routes = internal_q(0.0, h1, h2, row, candidate, table)
        cell0 = DZ * (theta(0.0) - theta(INITIAL_HEADS[0])) - tau * (qtop - q01)
        cell1 = DZ * (theta(h1) - theta(INITIAL_HEADS[1])) - tau * (q01 - q12)
        cell2 = DZ * (theta(h2) - theta(INITIAL_HEADS[2])) - tau * (q12 - qb)
        surface_res = (surface - S0) - tau * (supply - qtop)
        soil_storage = math.fsum([
            DZ * (theta(0.0) - theta(INITIAL_HEADS[0])),
            DZ * (theta(h1) - theta(INITIAL_HEADS[1])),
            DZ * (theta(h2) - theta(INITIAL_HEADS[2])),
        ])
        composed = soil_storage + (surface - S0) - tau * (supply - qb)
        max_balance = max(abs(cell0), abs(cell1), abs(cell2), abs(surface_res), abs(composed), max(abs(float(v)) for v in res))
        no_unqualified = not any("UNQUALIFIED" in r for r in routes)
        strict_tau = tau > TAU_LO * 10.0 and tau < TAU_HI * (1.0 - 1e-10)
        strict_surface = surface > SURFACE_LO * 10.0 and surface < SURFACE_HI
        valid = bool(
            sol.success
            and all(math.isfinite(v) for v in (h1, h2, surface, tau, qtop, q01, q12, qb, max_balance))
            and max_balance <= MASS_TOL
            and h1 <= H_DRY_HI and h2 <= H_DRY_HI
            and strict_tau and strict_surface
            and no_unqualified
        )
        return {
            "valid": valid,
            "solver_success": bool(sol.success),
            "nfev": int(sol.nfev),
            "event_time_day": tau,
            "heads_cm": [0.0, h1, h2],
            "surface_storage_cm": surface,
            "q_top_cm_per_day": qtop,
            "q_internal_cm_per_day": [q01, q12, qb],
            "internal_routes": list(routes),
            "max_abs_balance_residual_cm": max_balance,
            "composed_balance_residual_cm": float(composed),
            "strict_event_time": strict_tau,
            "strict_surface_storage": strict_surface,
            "committed_state_bitwise_unchanged": bits((*INITIAL_HEADS, S0)) == snapshot,
            "mass_repair_or_clipping_used": False,
        }
    except Exception as exc:
        return {
            "valid": False,
            "solver_success": False,
            "nfev": 0,
            "error": repr(exc),
            "committed_state_bitwise_unchanged": bits((*INITIAL_HEADS, S0)) == snapshot,
            "mass_repair_or_clipping_used": False,
        }


def compare(candidate: dict, reference: dict) -> dict:
    if not (candidate.get("valid") and reference.get("valid")):
        return {"available": False, "pass": False}
    tdiff = abs(float(candidate["event_time_day"]) - float(reference["event_time_day"]))
    hdiff = max(abs(float(a) - float(b)) for a, b in zip(candidate["heads_cm"], reference["heads_cm"]))
    sdiff = abs(float(candidate["surface_storage_cm"]) - float(reference["surface_storage_cm"]))
    tests = {
        "event_time": tdiff <= TIME_DIFF_TOL,
        "heads": hdiff <= HEAD_DIFF_TOL,
        "surface_storage": sdiff <= SURFACE_DIFF_TOL,
    }
    return {
        "available": True,
        "event_time_difference_day": tdiff,
        "max_head_difference_cm": hdiff,
        "surface_storage_difference_cm": sdiff,
        "tests": tests,
        "pass": all(tests.values()),
    }


def run_material(row: dict) -> dict:
    configure(row)
    table = e3g.e3.generate_c1r_table()
    ks = float(row["ksatfit_cm_per_day"])
    rows = []
    selected = None
    for frac in SUPPLY_FRACTIONS:
        supply = float(frac) * ks
        cand = solve_event(row, supply, True, table)
        ref = solve_event(row, supply, False, None)
        cmp = compare(cand, ref)
        passed = bool(
            cand.get("valid") and ref.get("valid") and cmp.get("pass")
            and cand.get("committed_state_bitwise_unchanged") is True
            and ref.get("committed_state_bitwise_unchanged") is True
            and cand.get("mass_repair_or_clipping_used") is False
            and ref.get("mass_repair_or_clipping_used") is False
        )
        item = {
            "supply_fraction_ksat": frac,
            "q_supply_cm_per_day": supply,
            "candidate": cand,
            "reference": ref,
            "comparison": cmp,
            "pass": passed,
        }
        rows.append(item)
        if selected is None and passed:
            selected = item
    tests = {
        "frozen_grid_complete": len(rows) == len(SUPPLY_FRACTIONS),
        "selected_fixture_exists": selected is not None,
        "selected_is_lowest_passing_fraction": selected is not None and all(not r["pass"] for r in rows[:rows.index(selected)]),
        "selected_candidate_reference_valid": selected is not None and selected["candidate"]["valid"] and selected["reference"]["valid"],
        "selected_mass": selected is not None and max(selected["candidate"]["max_abs_balance_residual_cm"], selected["reference"]["max_abs_balance_residual_cm"]) <= MASS_TOL,
        "selected_event_scope": selected is not None and selected["candidate"]["heads_cm"][1] <= -1.0 and selected["reference"]["heads_cm"][1] <= -1.0,
        "selected_transaction": selected is not None and selected["candidate"]["committed_state_bitwise_unchanged"] and selected["reference"]["committed_state_bitwise_unchanged"],
    }
    return {
        "material": row["sfu"],
        "rows": rows,
        "selected_fixture": None if selected is None else {
            "supply_fraction_ksat": selected["supply_fraction_ksat"],
            "q_supply_cm_per_day": selected["q_supply_cm_per_day"],
            "candidate_event_time_day": selected["candidate"]["event_time_day"],
            "reference_event_time_day": selected["reference"]["event_time_day"],
            "candidate_event_heads_cm": selected["candidate"]["heads_cm"],
            "reference_event_heads_cm": selected["reference"]["heads_cm"],
            "candidate_surface_storage_cm": selected["candidate"]["surface_storage_cm"],
            "reference_surface_storage_cm": selected["reference"]["surface_storage_cm"],
            "candidate_max_abs_balance_residual_cm": selected["candidate"]["max_abs_balance_residual_cm"],
            "reference_max_abs_balance_residual_cm": selected["reference"]["max_abs_balance_residual_cm"],
            "event_time_difference_day": selected["comparison"]["event_time_difference_day"],
            "max_head_difference_cm": selected["comparison"]["max_head_difference_cm"],
            "surface_storage_difference_cm": selected["comparison"]["surface_storage_difference_cm"],
        },
        "tests": tests,
        "failed_metrics": [k for k,v in tests.items() if not v],
        "pass": all(tests.values()),
    }


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_e3h_a_top_node_saturation_event_fixture_characterization.py MATERIAL OUTPUT.json")
    material = sys.argv[1]
    if material not in MATERIALS:
        raise SystemExit(material)
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    row = next(r for r in catalog["rows"] if r["sfu"] == material)
    result = run_material(row)
    payload = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E3H_A_TOP_NODE_SATURATION_EVENT_FIXTURE_CHARACTERIZATION",
        "contract": CONTRACT,
        "material": material,
        "production_implementation": False,
        "qualification_use": False,
        "material_result": result,
        "pass": result["pass"],
        "decision": "CHARACTERIZED_TRUE_TOP_NODE_H0_EVENT_FIXTURE_READY_FOR_E3H_QUALIFICATION" if result["pass"] else "TOP_NODE_H0_EVENT_FIXTURE_NOT_ESTABLISHED_RESEARCH_REQUIRED",
        "hard_nonclaims": [
            "Characterization is not top-node saturation qualification.",
            "No positive top-node continuation is admitted.",
            "No automatic runtime event detection is admitted."
        ],
    }
    out = Path(sys.argv[2])
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    sf = result["selected_fixture"]
    print(json.dumps({
        "material": material,
        "pass": result["pass"],
        "selected_supply_fraction_ksat": None if sf is None else sf["supply_fraction_ksat"],
        "candidate_event_time_day": None if sf is None else sf["candidate_event_time_day"],
        "reference_event_time_day": None if sf is None else sf["reference_event_time_day"],
        "max_balance_cm": None if sf is None else max(sf["candidate_max_abs_balance_residual_cm"], sf["reference_max_abs_balance_residual_cm"]),
        "failed_metrics": result["failed_metrics"],
        "decision": payload["decision"],
    }, sort_keys=True), flush=True)
    if not result["pass"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
