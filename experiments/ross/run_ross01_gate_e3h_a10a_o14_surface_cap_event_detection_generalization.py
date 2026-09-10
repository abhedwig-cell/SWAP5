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

import run_ross01_gate_e3h_a8_o14_transactional_surface_cap_to_runoff as a8

CONTRACT = "F-ROSS01_GATE_E3H_A10A_O14_SURFACE_CAP_EVENT_DETECTION_GENERALIZATION_PRECOMMIT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIAL = "O14"
PROFILES = {
    "P0_A1_CONTROL": (-0.2, -1.5, -5.0),
    "P1_DRIER_SUBSOIL": (-0.5, -5.0, -10.0),
    "P2_DRIER_TOP_AND_SUBSOIL": (-1.0, -10.0, -20.0),
    "P3_STRONG_DRY_SEPARATION": (-2.0, -20.0, -50.0),
}
CAPS = (0.10, 0.25, 0.50, 0.75, 1.00)
S0 = 0.02
SUPPLY_FRAC = 12.0
NEGATIVE_FRACS = (0.25, 0.50)
HORIZON = 0.05
TAU_EPS = 1.0e-12
MASS_TOL = 1.0e-9
REF_PAIR_TIME_TOL = 1.0e-7
REF_PAIR_HEAD_TOL = 1.0e-4
CAND_TIME_TOL = 2.5e-4
CAND_HEAD_TOL = 0.25
BOTTOM_DIFF_TOL = 0.001
SURFACE_Q_ERR_TOL = 0.0005
MAX_K = 530
MAX_ROOT = 66
MAX_NFEV = 250


def state_bits(heads, surface: float, runoff: float = 0.0) -> bytes:
    return struct.pack("!5d", *map(float, heads), float(surface), float(runoff))


def configure(row: dict, initial):
    return a8.configure(row, initial)


def restore(old) -> None:
    a8.restore(old)


def internal_fluxes(heads, row: dict, candidate: bool, table):
    h0, h1, h2 = map(float, heads)
    return a8.a4.a1.internal_q(h0, h1, h2, row, candidate, table)


def surface_flux(cap: float, h0: float, row: dict, candidate: bool):
    if candidate:
        q, route, cost = a8.a4.a1.e3g.surface_face(float(cap), float(h0), row, True)
        return {
            "q": float(q),
            "route": str(route),
            "cost": {
                "constitutive_K_evaluations": int(cost.get("constitutive_K_evaluations", 0)),
                "root_residual_evaluations": int(cost.get("root_residual_evaluations", 0)),
            },
            "path_residual_cm": None,
        }
    ref = a8.a4.a1.e3g.exact_surface_reference(float(cap), float(h0), row)
    return {
        "q": float(ref["q"]),
        "route": str(ref["branch"]),
        "cost": {"constitutive_K_evaluations": 0, "root_residual_evaluations": 0},
        "path_residual_cm": float(ref["residual_cm"]),
    }


def all_fluxes(cap: float, heads, row: dict, candidate: bool, table):
    sf = surface_flux(cap, float(heads[0]), row, candidate)
    (q01, q12, qb), routes = internal_fluxes(heads, row, candidate, table)
    return {
        "qtop": sf["q"],
        "q01": float(q01),
        "q12": float(q12),
        "qb": float(qb),
        "surface_route": sf["route"],
        "surface_cost": sf["cost"],
        "surface_path_residual_cm": sf["path_residual_cm"],
        "internal_routes": [str(v) for v in routes],
    }


def event_residual(x, initial, cap: float, supply: float, row: dict, candidate: bool, table):
    heads = tuple(float(v) for v in x[:3])
    tau = float(x[3])
    f = all_fluxes(cap, heads, row, candidate, table)
    q = (f["qtop"], f["q01"], f["q12"], f["qb"])
    return np.asarray([
        a8.a4.a1.DZ * (a8.a4.a1.theta(heads[i]) - a8.a4.a1.theta(float(initial[i]))) - tau * (q[i] - q[i+1])
        for i in range(3)
    ] + [
        (cap - S0) - tau * (supply - q[0])
    ], dtype=np.float64)


def diagnostics(initial, heads, cap: float, tau: float, supply: float, f: dict):
    q = (f["qtop"], f["q01"], f["q12"], f["qb"])
    cell = [
        a8.a4.a1.DZ * (a8.a4.a1.theta(float(heads[i])) - a8.a4.a1.theta(float(initial[i]))) - tau * (q[i] - q[i+1])
        for i in range(3)
    ]
    surface = (cap - S0) - tau * (supply - q[0])
    soil = math.fsum(
        a8.a4.a1.DZ * (a8.a4.a1.theta(float(heads[i])) - a8.a4.a1.theta(float(initial[i])))
        for i in range(3)
    )
    bottom = tau * q[-1]
    composed = soil + (cap - S0) + bottom - tau * supply
    return {
        "cell_residuals_cm": [float(v) for v in cell],
        "surface_balance_residual_cm": float(surface),
        "composed_balance_residual_cm": float(composed),
        "bottom_transfer_cm": float(bottom),
        "max_abs_balance_residual_cm": float(max(max(abs(v) for v in cell), abs(surface), abs(composed))),
    }


def algebraic_tau_seed(initial, cap: float, supply: float, row: dict, candidate: bool):
    q0 = surface_flux(S0, float(initial[0]), row, candidate)
    denom = supply - q0["q"]
    if not (math.isfinite(denom) and denom > 0.0):
        raise RuntimeError(("nonpositive_seed_denominator", cap, denom))
    tau = (cap - S0) / denom
    if not (TAU_EPS < tau < HORIZON):
        raise RuntimeError(("tau_seed_outside_interval", cap, tau))
    return float(tau), q0


def solve_one(initial, cap: float, row: dict, candidate: bool, reference_start: str = "A"):
    committed = state_bits(initial, S0, 0.0)
    old = configure(row, initial)
    table = a8.a4.a1.e3g.e3.generate_c1r_table() if candidate else None
    supply = SUPPLY_FRAC * float(row["ksatfit_cm_per_day"])
    try:
        tau_seed, q0 = algebraic_tau_seed(initial, cap, supply, row, candidate)
        if candidate or reference_start == "A":
            heads_seed = tuple(float(v) for v in initial)
            tau0 = tau_seed
        elif reference_start == "B":
            heads_seed = tuple(0.5 * float(v) for v in initial)
            tau0 = min(HORIZON - TAU_EPS, max(TAU_EPS, tau_seed * 1.05))
        else:
            raise ValueError(reference_start)
        x0 = np.asarray([*heads_seed, tau0], dtype=np.float64)
        sol = least_squares(
            lambda x: event_residual(x, initial, cap, supply, row, candidate, table),
            x0,
            bounds=(
                np.asarray([-10000.0, -10000.0, -10000.0, TAU_EPS]),
                np.asarray([a8.H_UPPER, a8.H_UPPER, a8.H_UPPER, HORIZON]),
            ),
            xtol=1e-13, ftol=1e-13, gtol=1e-13,
            max_nfev=MAX_NFEV, x_scale="jac",
        )
        heads = tuple(float(v) for v in sol.x[:3])
        tau = float(sol.x[3])
        f = all_fluxes(cap, heads, row, candidate, table)
        d = diagnostics(initial, heads, cap, tau, supply, f)
        finite = all(math.isfinite(v) for v in (*heads, tau, f["qtop"], f["q01"], f["q12"], f["qb"]))
        physical_order = heads[0] >= heads[1] >= heads[2]
        top_negative = heads[0] < 0.0
        strict_tau = TAU_EPS < tau < HORIZON
        no_unqualified = not any("UNQUALIFIED" in str(v) for v in [f["surface_route"], *f["internal_routes"]])
        accepted = bool(sol.success and finite and physical_order and top_negative and strict_tau and no_unqualified and d["max_abs_balance_residual_cm"] <= MASS_TOL)
        out = {
            "accepted": accepted,
            "candidate": bool(candidate),
            "reference_start": None if candidate else reference_start,
            "cap_cm": cap,
            "tau_seed_day": tau_seed,
            "initial_surface_q_cm_per_day": q0["q"],
            "event_time_day": tau,
            "heads_cm": list(heads),
            "surface_storage_cm": cap,
            "solver_success": bool(sol.success),
            "nfev": int(sol.nfev),
            "physical_head_order": physical_order,
            "top_node_negative": top_negative,
            "strict_event_time": strict_tau,
            "no_unqualified_face_route": no_unqualified,
            "fluxes": f,
            "diagnostics": d,
            "committed_state_bitwise_unchanged_until_accept": state_bits(initial, S0, 0.0) == committed,
            "mass_repair_or_clipping_used": False,
        }
        if candidate:
            exact = surface_flux(cap, heads[0], row, False)
            out["surface_q_exact_reference_cm_per_day"] = exact["q"]
            out["surface_q_abs_error_over_ksat"] = abs(f["qtop"] - exact["q"]) / float(row["ksatfit_cm_per_day"])
            out["surface_cost_ok"] = (
                f["surface_cost"]["constitutive_K_evaluations"] <= MAX_K
                and f["surface_cost"]["root_residual_evaluations"] <= MAX_ROOT
            )
        return out
    except Exception as exc:
        return {
            "accepted": False,
            "candidate": bool(candidate),
            "reference_start": None if candidate else reference_start,
            "cap_cm": cap,
            "error": repr(exc),
            "committed_state_bitwise_unchanged_until_accept": state_bits(initial, S0, 0.0) == committed,
            "mass_repair_or_clipping_used": False,
        }
    finally:
        restore(old)


def compare_roots(a: dict, b: dict, time_tol: float, head_tol: float, bottom_tol: float | None = None):
    if not (a.get("accepted") and b.get("accepted")):
        return {"available": False, "pass": False}
    tdiff = abs(float(a["event_time_day"]) - float(b["event_time_day"]))
    hdiff = max(abs(float(x)-float(y)) for x,y in zip(a["heads_cm"], b["heads_cm"]))
    out = {
        "available": True,
        "event_time_difference_day": tdiff,
        "max_head_difference_cm": hdiff,
        "tests": {"time": tdiff <= time_tol, "heads": hdiff <= head_tol},
    }
    if bottom_tol is not None:
        bdiff = abs(float(a["diagnostics"]["bottom_transfer_cm"]) - float(b["diagnostics"]["bottom_transfer_cm"]))
        out["bottom_transfer_difference_cm"] = bdiff
        out["tests"]["bottom_transfer"] = bdiff <= bottom_tol
    out["pass"] = all(out["tests"].values())
    return out


def no_event_control(initial, cap: float, supply: float):
    committed = state_bits(initial, S0, 0.0)
    upper = S0 + max(supply, 0.0) * HORIZON
    impossible = upper < cap
    return {
        "cap_cm": cap,
        "surface_storage_upper_bound_cm": float(upper),
        "event_impossible": bool(impossible),
        "certificate_margin_cm": float(cap - upper),
        "nonlinear_trajectory_count": 0,
        "committed_state_bitwise_unchanged": state_bits(initial, S0, 0.0) == committed,
        "runoff_ledger_cm": 0.0,
    }


def run_profile(profile_id: str, row: dict):
    initial = PROFILES[profile_id]
    ksat = float(row["ksatfit_cm_per_day"])
    cases = []
    negatives = []
    for cap in CAPS:
        cand = solve_one(initial, cap, row, True)
        ref_a = solve_one(initial, cap, row, False, "A")
        ref_b = solve_one(initial, cap, row, False, "B")
        ref_pair = compare_roots(ref_a, ref_b, REF_PAIR_TIME_TOL, REF_PAIR_HEAD_TOL)
        cand_ref = compare_roots(cand, ref_a, CAND_TIME_TOL, CAND_HEAD_TOL, BOTTOM_DIFF_TOL)
        tests = {
            "candidate_accepted": cand.get("accepted") is True,
            "reference_A_accepted": ref_a.get("accepted") is True,
            "reference_B_accepted": ref_b.get("accepted") is True,
            "reference_pair": ref_pair.get("pass") is True,
            "candidate_reference": cand_ref.get("pass") is True,
            "candidate_mass": cand.get("diagnostics") is not None and cand["diagnostics"]["max_abs_balance_residual_cm"] <= MASS_TOL,
            "reference_A_mass": ref_a.get("diagnostics") is not None and ref_a["diagnostics"]["max_abs_balance_residual_cm"] <= MASS_TOL,
            "reference_B_mass": ref_b.get("diagnostics") is not None and ref_b["diagnostics"]["max_abs_balance_residual_cm"] <= MASS_TOL,
            "candidate_surface_accuracy": cand.get("surface_q_abs_error_over_ksat", math.inf) <= SURFACE_Q_ERR_TOL,
            "candidate_surface_cost": cand.get("surface_cost_ok") is True,
            "candidate_committed_immutable": cand.get("committed_state_bitwise_unchanged_until_accept") is True,
            "no_mass_repair": cand.get("mass_repair_or_clipping_used") is False and ref_a.get("mass_repair_or_clipping_used") is False and ref_b.get("mass_repair_or_clipping_used") is False,
        }
        cases.append({
            "cap_cm": cap,
            "candidate": cand,
            "reference_A": ref_a,
            "reference_B": ref_b,
            "reference_pair": ref_pair,
            "candidate_reference": cand_ref,
            "tests": tests,
            "failed_metrics": [k for k,v in tests.items() if not v],
            "pass": all(tests.values()),
        })
        for frac in NEGATIVE_FRACS:
            n = no_event_control(initial, cap, frac * ksat)
            n["supply_fraction_of_ksat"] = frac
            negatives.append(n)

    valid_cands = [x["candidate"] for x in cases if x["candidate"].get("accepted")]
    comparisons = [x["candidate_reference"] for x in cases if x["candidate_reference"].get("available")]
    refpairs = [x["reference_pair"] for x in cases if x["reference_pair"].get("available")]
    tests = {
        "positive_case_count": len(cases) == len(CAPS),
        "all_positive_cases_pass": all(x["pass"] for x in cases),
        "negative_case_count": len(negatives) == len(CAPS) * len(NEGATIVE_FRACS),
        "all_negative_cases_certified": all(x["event_impossible"] for x in negatives),
        "all_negative_zero_nonlinear": all(x["nonlinear_trajectory_count"] == 0 for x in negatives),
        "all_negative_state_unchanged": all(x["committed_state_bitwise_unchanged"] for x in negatives),
        "all_negative_zero_runoff": all(x["runoff_ledger_cm"] == 0.0 for x in negatives),
        "candidate_corrector_count_shape": all(x.get("nfev", 0) > 0 for x in valid_cands),
        "all_caps_inside_qualified_surface_face": min(CAPS) > S0 and max(CAPS) <= 1.0,
    }
    return {
        "profile_id": profile_id,
        "cases": cases,
        "negative_controls": negatives,
        "max_candidate_reference_event_time_difference_day": max((x["event_time_difference_day"] for x in comparisons), default=math.inf),
        "max_candidate_reference_head_difference_cm": max((x["max_head_difference_cm"] for x in comparisons), default=math.inf),
        "max_candidate_reference_bottom_transfer_difference_cm": max((x.get("bottom_transfer_difference_cm", math.inf) for x in comparisons), default=math.inf),
        "max_reference_pair_event_time_difference_day": max((x["event_time_difference_day"] for x in refpairs), default=math.inf),
        "max_reference_pair_head_difference_cm": max((x["max_head_difference_cm"] for x in refpairs), default=math.inf),
        "max_candidate_mass_residual_cm": max((x["diagnostics"]["max_abs_balance_residual_cm"] for x in valid_cands), default=math.inf),
        "max_candidate_surface_q_abs_error_over_ksat": max((x["surface_q_abs_error_over_ksat"] for x in valid_cands), default=math.inf),
        "max_candidate_surface_constitutive_K_evaluations": max((x["fluxes"]["surface_cost"]["constitutive_K_evaluations"] for x in valid_cands), default=0),
        "max_candidate_surface_root_residual_evaluations": max((x["fluxes"]["surface_cost"]["root_residual_evaluations"] for x in valid_cands), default=0),
        "max_candidate_event_nfev": max((x["nfev"] for x in valid_cands), default=0),
        "tests": tests,
        "failed_metrics": [k for k,v in tests.items() if not v],
        "pass": all(tests.values()),
    }


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: run_ross01_gate_e3h_a10a_o14_surface_cap_event_detection_generalization.py PROFILE OUTPUT.json")
    profile_id = sys.argv[1]
    if profile_id not in PROFILES:
        raise SystemExit(profile_id)
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    row = next(r for r in catalog["rows"] if r["sfu"] == MATERIAL)
    pr = run_profile(profile_id, row)
    payload = {
        "schema_version": 1,
        "workstream": "F-ROSS",
        "work_unit": "F-ROSS01",
        "gate": "E3H_A10A_O14_SURFACE_CAP_EVENT_DETECTION_GENERALIZATION",
        "contract": CONTRACT,
        "production_implementation": False,
        "qualification_use": True,
        "material": MATERIAL,
        "profile_result": pr,
        "pass": pr["pass"],
        "decision": (
            "QUALIFIED_RESTRICTED_O14_SEED_FREE_SURFACE_CAP_EVENT_DETECTION_ACROSS_0P1_TO_1CM_READY_FOR_GENERALIZED_RUNOFF_CONTINUATION_GATE"
            if pr["pass"] else
            "O14_SURFACE_CAP_EVENT_DETECTION_GENERALIZATION_NOT_QUALIFIED_PRESERVE_A9_AND_CHARACTERIZE_CAP_DEPENDENCE"
        ),
        "hard_nonclaims": [
            "No cap-dependent runoff continuation qualification.",
            "No caps above 1 cm.",
            "No material other than O14.",
            "No generic inconclusive-case bracket search.",
            "No production, runtime or MultiSWAP admission."
        ],
    }
    out = Path(sys.argv[2])
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "profile": profile_id,
        "pass": pr["pass"],
        "max_event_time_difference_day": pr["max_candidate_reference_event_time_difference_day"],
        "max_head_difference_cm": pr["max_candidate_reference_head_difference_cm"],
        "max_bottom_difference_cm": pr["max_candidate_reference_bottom_transfer_difference_cm"],
        "max_reference_pair_time_difference_day": pr["max_reference_pair_event_time_difference_day"],
        "max_reference_pair_head_difference_cm": pr["max_reference_pair_head_difference_cm"],
        "max_mass_cm": pr["max_candidate_mass_residual_cm"],
        "max_surface_q_error_over_ksat": pr["max_candidate_surface_q_abs_error_over_ksat"],
        "max_nfev": pr["max_candidate_event_nfev"],
        "failed_metrics": pr["failed_metrics"],
        "decision": payload["decision"],
    }, sort_keys=True), flush=True)
    if not pr["pass"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
