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

CONTRACT = "F-ROSS01_GATE_E3G_R2A_CONSTANT_SUPPLY_EVENT_FIXTURE_CHARACTERIZATION_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
INTERIOR_MATERIALS = ("B01", "O14")
CONTROL_MATERIALS = ("B12", "O13")
SUPPLY_FRACTIONS = (1.005, 1.01, 1.015, 1.02)
CONTROL_FRACTIONS = (0.995, 1.005)
SAMPLE_TIMES = (0.0, 1.0e-5, 2.0e-5, 5.0e-5, 1.0e-4, 2.0e-4, 5.0e-4, 1.0e-3)
EPS = sys.float_info.epsilon


def exact_qcap(htop: float, row: dict) -> float:
    ref = e3g.exact_surface_reference(0.0, float(htop), row)
    q = float(ref["q"])
    if not math.isfinite(q):
        raise FloatingPointError(("nonfinite_qcap", htop, ref))
    return q


def dry_reference_at(old: e3g.State, supply: float, dt: float, row: dict) -> dict:
    if dt <= 0.0:
        qcap = exact_qcap(old.heads[0], row)
        tol = 64.0 * EPS * max(1.0, abs(supply), abs(qcap))
        return {
            "dt_day": 0.0,
            "solver_executed": False,
            "solver_success": True,
            "local_trial_valid": True,
            "heads_cm": list(old.heads),
            "q_cap_cm_per_day": qcap,
            "g_supply_minus_capacity_cm_per_day": float(supply - qcap),
            "comparison_tolerance_cm_per_day": tol,
            "strictly_dry_admissible": supply < qcap - tol,
            "ponding_or_limit_reached": supply >= qcap - tol,
            "diagnostics": {
                "cell_residuals_cm": [0.0, 0.0, 0.0],
                "surface_balance_residual_cm": 0.0,
                "composed_balance_residual_cm": 0.0,
                "bottom_transfer_cm": 0.0,
            },
            "committed_state_bitwise_unchanged": True,
            "mass_repair_or_clipping_used": False,
        }

    snapshot = e3g.bits(old)
    e3g.internal_geometry(row)
    fun = lambda h: e3g.soil_residual(h, old.heads, dt, supply, None, row, False)
    try:
        sol = least_squares(
            fun,
            np.asarray(old.heads),
            bounds=(np.full(3, -10000.0), np.full(3, e3g.TOP_UPPER)),
            xtol=1e-13, ftol=1e-13, gtol=1e-13,
            max_nfev=e3g.MAX_NFEV, x_scale="jac",
        )
        heads = tuple(float(v) for v in sol.x)
        q, routes = e3g.internal_fluxes(heads, supply, None, row, False)
        d = e3g.diagnostics(old, heads, 0.0, supply, q, dt)
        qcap = exact_qcap(heads[0], row)
        tol = 64.0 * EPS * max(1.0, abs(supply), abs(qcap))
        valid = bool(
            sol.success
            and all(math.isfinite(v) for v in (*heads, *q, qcap))
            and e3g.mass_ok(d)
            and max(heads) <= e3g.TOP_UPPER
        )
        return {
            "dt_day": float(dt),
            "solver_executed": True,
            "solver_success": bool(sol.success),
            "nfev": int(sol.nfev),
            "local_trial_valid": valid,
            "heads_cm": list(heads),
            "q_cap_cm_per_day": qcap,
            "g_supply_minus_capacity_cm_per_day": float(supply - qcap),
            "comparison_tolerance_cm_per_day": tol,
            "strictly_dry_admissible": bool(valid and supply < qcap - tol),
            "ponding_or_limit_reached": bool(valid and supply >= qcap - tol),
            "internal_routes": list(routes),
            "diagnostics": d,
            "committed_state_bitwise_unchanged": e3g.bits(old) == snapshot,
            "mass_repair_or_clipping_used": False,
        }
    except Exception as exc:
        return {
            "dt_day": float(dt),
            "solver_executed": True,
            "solver_success": False,
            "local_trial_valid": False,
            "error": repr(exc),
            "committed_state_bitwise_unchanged": e3g.bits(old) == snapshot,
            "mass_repair_or_clipping_used": False,
        }


def find_brackets(samples: list[dict]) -> list[dict]:
    out = []
    for a, b in zip(samples[:-1], samples[1:]):
        if not (a.get("local_trial_valid") and b.get("local_trial_valid")):
            continue
        ga = float(a["g_supply_minus_capacity_cm_per_day"])
        gb = float(b["g_supply_minus_capacity_cm_per_day"])
        ta = float(a["comparison_tolerance_cm_per_day"])
        tb = float(b["comparison_tolerance_cm_per_day"])
        if ga < -ta and gb >= -tb:
            out.append({
                "t_left_day": a["dt_day"],
                "t_right_day": b["dt_day"],
                "g_left_cm_per_day": ga,
                "g_right_cm_per_day": gb,
                "h_top_left_cm": a["heads_cm"][0],
                "h_top_right_cm": b["heads_cm"][0],
            })
    return out


def characterize_interior(row: dict) -> dict:
    ksat = float(row["ksatfit_cm_per_day"])
    old = e3g.State(2.375, e3g.INITIAL_HEADS, 0.0)
    fractions = []
    for f in SUPPLY_FRACTIONS:
        supply = f * ksat
        samples = [dry_reference_at(old, supply, dt, row) for dt in SAMPLE_TIMES]
        brackets = find_brackets(samples)
        fractions.append({
            "supply_fraction_ksat": f,
            "q_supply_cm_per_day": supply,
            "samples": samples,
            "valid_event_brackets": brackets,
            "has_valid_event_bracket": bool(brackets),
            "all_samples_committed_state_unchanged": all(s["committed_state_bitwise_unchanged"] for s in samples),
            "mass_repair_or_clipping_used": any(s["mass_repair_or_clipping_used"] for s in samples),
        })
    candidates = []
    for fr in fractions:
        if fr["has_valid_event_bracket"]:
            b = fr["valid_event_brackets"][0]
            candidates.append({
                "supply_fraction_ksat": fr["supply_fraction_ksat"],
                **b,
            })
    candidates.sort(key=lambda x: (x["supply_fraction_ksat"], x["t_right_day"]))
    selected = candidates[0] if candidates else None
    return {
        "material": row["sfu"],
        "classification_role": "INTERIOR_FINITE_TIME_EVENT_CANDIDATE",
        "fractions": fractions,
        "selected_fixture_candidate": selected,
        "pass": selected is not None,
    }


def characterize_control(row: dict) -> dict:
    ksat = float(row["ksatfit_cm_per_day"])
    old = e3g.State(2.375, e3g.INITIAL_HEADS, 0.0)
    qcap0 = exact_qcap(old.heads[0], row)
    rows = []
    for f in CONTROL_FRACTIONS:
        supply = f * ksat
        tol = 64.0 * EPS * max(1.0, abs(supply), abs(qcap0))
        immediate = supply > qcap0 + tol
        dry = supply <= qcap0 + tol
        rows.append({
            "supply_fraction_ksat": f,
            "q_supply_cm_per_day": supply,
            "q_cap0_cm_per_day": qcap0,
            "roundoff_tolerance_cm_per_day": tol,
            "classification": "IMMEDIATE_R1" if immediate else "DRY_AT_T0",
            "immediate_R1": immediate,
            "dry_at_t0": dry,
            "physical_no_event_certificate_for_sub_ksat": bool(f < 1.0 and supply < ksat <= qcap0 + tol),
            "soil_nonlinear_trajectory_count": 0,
        })
    low = next(x for x in rows if x["supply_fraction_ksat"] == 0.995)
    high = next(x for x in rows if x["supply_fraction_ksat"] == 1.005)
    tests = {
        "sub_ksat_dry_at_t0": low["dry_at_t0"],
        "sub_ksat_no_event_certificate": low["physical_no_event_certificate_for_sub_ksat"],
        "super_ksat_immediate_R1": high["immediate_R1"],
        "no_soil_trajectory_for_classification": all(x["soil_nonlinear_trajectory_count"] == 0 for x in rows),
    }
    return {
        "material": row["sfu"],
        "classification_role": "R1_AND_NO_EVENT_CONTROL",
        "rows": rows,
        "tests": tests,
        "pass": all(tests.values()),
    }


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_e3g_r2a_constant_supply_event_fixture_characterization.py MATERIAL OUTPUT.json")
    material = sys.argv[1]
    if material not in (*INTERIOR_MATERIALS, *CONTROL_MATERIALS):
        raise SystemExit(material)
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    row = next(r for r in catalog["rows"] if r["sfu"] == material)
    if material in INTERIOR_MATERIALS:
        result = characterize_interior(row)
    else:
        result = characterize_control(row)
    payload = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E3G_R2A_CONSTANT_SUPPLY_EVENT_FIXTURE_CHARACTERIZATION",
        "contract": CONTRACT,
        "material": material,
        "production_implementation": False,
        "qualification_use": False,
        "material_result": result,
        "pass": bool(result["pass"]),
        "decision": (
            "CHARACTERIZED_PHYSICALLY_VALID_FINITE_TIME_PONDING_FIXTURE_CLASS_READY_FOR_R2_PRECOMMIT"
            if result["pass"] else
            "NO_VALID_CONSTANT_SUPPLY_FINITE_TIME_FIXTURE_IN_FROZEN_SCAN_RESEARCH_REQUIRED"
        ),
        "hard_nonclaims": [
            "No finite-time event time is qualified.",
            "No candidate event locator is tested.",
            "No production event-search cadence follows from this characterization grid.",
            "No top-node positive head, pond depletion, runoff, response tangent, runtime, MultiSWAP or MODFLOW admission."
        ],
    }
    out = Path(sys.argv[2])
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "material": material,
        "pass": payload["pass"],
        "selected_fixture_candidate": result.get("selected_fixture_candidate"),
        "decision": payload["decision"],
    }, sort_keys=True), flush=True)
    if not payload["pass"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
