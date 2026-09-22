from __future__ import annotations

import json
import math
import os
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "research"))
sys.path.insert(0, str(ROOT / "tests" / "fgc" / "support"))

from fgc44_real_swap_ctypes import Fgc44RealSwap
from test_gc_fixed_interface_fgc44_safeguarded_newton_g08 import (
    AREA_M2,
    DAY_TO_S,
    FLUX_TOL,
    HEAD_TOL_M,
    MAX_BACKTRACK,
    MAX_OUTER,
    initialize_case,
    scan_swap,
    groundwater_response,
    reference_root,
    residual_at,
    solve_term,
    trial_discard,
)

PREREG = ROOT / "integration" / "research" / "GC_FIXED_INTERFACE_G09_PREREGISTRATION.json"
G08_PREREG = ROOT / "integration" / "research" / "GC_FIXED_INTERFACE_G08_PREREGISTRATION.json"

TRIAL_FAILED_STATUS = 6
INITIAL_D_M = 2.5e-7
MAX_HALVINGS = 6
REL_TOL = 0.05
MERIT_ABS_TOL = 1.0e-18

BOUNDARY_STATES = (
    ("C0_CONTROL", 1.0e-4, 1.0e-6, -2.0e-6, 5.0e-6),
    ("C1_LOW_FORCING", 1.0e-4, 5.0e-7, -5.0e-6, 5.0e-6),
    ("C2_HIGH_FORCING", 1.0e-4, 2.0e-6, -5.0e-6, 2.0e-6),
    ("C3_LONG_HIGH", 2.0e-4, 2.0e-6, -5.0e-6, 2.0e-6),
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def load_prereg() -> tuple[dict[str, object], list[dict[str, object]]]:
    p = json.loads(PREREG.read_text())
    require(p["work_unit"] == "GC-FIXED-INTERFACE-G09", "wrong G09 preregistration")
    require(p["status"] == "PREREGISTERED_BEFORE_EXECUTION", "G09 preregistration not frozen")
    frozen = tuple(
        (
            str(x["case_id"]),
            float(x["duration_day"]),
            float(x["predictor_qbot_cm_per_day"]),
            float(x["negative_dh_m"]),
            float(x["positive_dh_m"]),
        )
        for x in p["frozen_boundary_states"]
    )
    require(frozen == BOUNDARY_STATES, "G09 boundary-state matrix drifted")
    g08 = json.loads(G08_PREREG.read_text())
    return p, [dict(x) for x in g08["groundwater_regimes"]]


def estimate_central(
    swap: Fgc44RealSwap,
    origin: tuple[int, float, int, float],
    head: float,
    initial_d: float = INITIAL_D_M,
    max_halvings: int = MAX_HALVINGS,
) -> dict[str, object]:
    d = initial_d
    probes: list[dict[str, object]] = []
    for halving in range(max_halvings + 1):
        sm, qm = trial_discard(swap, origin, head - d)
        sp, qp = trial_discard(swap, origin, head + d)
        probes.append({"d_m": d, "minus_status": sm, "plus_status": sp})
        if sm == 0 and sp == 0:
            slope = (qp - qm) / (2.0 * d)
            if math.isfinite(slope) and slope < 0.0:
                return {
                    "classification": "AVAILABLE",
                    "mode": "CENTRAL",
                    "slope_per_s": slope,
                    "selected_d_m": d,
                    "halvings": halving,
                    "probes": probes,
                }
        d *= 0.5
    return {
        "classification": "TANGENT_UNAVAILABLE",
        "mode": "CENTRAL",
        "halvings": max_halvings + 1,
        "probes": probes,
    }


def estimate_admissibility_aware(
    swap: Fgc44RealSwap,
    origin: tuple[int, float, int, float],
    head: float,
    initial_d: float = INITIAL_D_M,
    max_halvings: int = MAX_HALVINGS,
) -> dict[str, object]:
    s0, q0 = trial_discard(swap, origin, head)
    if s0 != 0:
        return {
            "classification": "CURRENT_HEAD_INADMISSIBLE",
            "status": s0,
            "mode": "NONE",
        }

    d = initial_d
    probes: list[dict[str, object]] = []
    for halving in range(max_halvings + 1):
        sm, qm = trial_discard(swap, origin, head - d)
        sp, qp = trial_discard(swap, origin, head + d)
        row: dict[str, object] = {
            "d_m": d,
            "minus_status": sm,
            "plus_status": sp,
        }

        if sm == 0 and sp == 0:
            slope = (qp - qm) / (2.0 * d)
            row["selected"] = "CENTRAL"
            probes.append(row)
            if math.isfinite(slope) and slope < 0.0:
                return {
                    "classification": "AVAILABLE",
                    "mode": "CENTRAL",
                    "slope_per_s": slope,
                    "selected_d_m": d,
                    "halvings": halving,
                    "probes": probes,
                }

        elif sm == 0 and sp != 0:
            s2, q2 = trial_discard(swap, origin, head - 2.0 * d)
            row["second_status"] = s2
            row["selected_direction"] = "NEGATIVE"
            probes.append(row)
            if s2 == 0:
                slope = (3.0 * q0 - 4.0 * qm + q2) / (2.0 * d)
                if math.isfinite(slope) and slope < 0.0:
                    return {
                        "classification": "AVAILABLE",
                        "mode": "ONE_SIDED_NEGATIVE",
                        "slope_per_s": slope,
                        "selected_d_m": d,
                        "halvings": halving,
                        "probes": probes,
                    }
        elif sp == 0 and sm != 0:
            s2, q2 = trial_discard(swap, origin, head + 2.0 * d)
            row["second_status"] = s2
            row["selected_direction"] = "POSITIVE"
            probes.append(row)
            if s2 == 0:
                slope = (-3.0 * q0 + 4.0 * qp - q2) / (2.0 * d)
                if math.isfinite(slope) and slope < 0.0:
                    return {
                        "classification": "AVAILABLE",
                        "mode": "ONE_SIDED_POSITIVE",
                        "slope_per_s": slope,
                        "selected_d_m": d,
                        "halvings": halving,
                        "probes": probes,
                    }
        else:
            probes.append(row)

        d *= 0.5

    return {
        "classification": "TANGENT_UNAVAILABLE",
        "mode": "NONE",
        "halvings": max_halvings + 1,
        "probes": probes,
    }


def consistency_check(
    swap: Fgc44RealSwap,
    origin: tuple[int, float, int, float],
    head: float,
    estimate: dict[str, object],
) -> dict[str, object]:
    require(estimate["classification"] == "AVAILABLE", "consistency requires available E1")
    slope = float(estimate["slope_per_s"])
    selected_d = float(estimate["selected_d_m"])
    half = estimate_admissibility_aware(
        swap, origin, head, initial_d=0.5 * selected_d, max_halvings=MAX_HALVINGS
    )
    require(half["classification"] == "AVAILABLE", "G09 E1 half-step estimate unavailable")
    half_slope = float(half["slope_per_s"])
    rel = abs(half_slope - slope) / max(abs(slope), abs(half_slope))
    return {
        "half_step_mode": half["mode"],
        "half_step_slope_per_s": half_slope,
        "relative_difference": rel,
        "pass": rel <= REL_TOL,
    }


def resolve_sy(regime: dict[str, object], u: float) -> float:
    formula = str(regime["sy_formula"])
    if formula == "0.75*u_predictor":
        return 0.75 * u
    if formula == "2.0*u_predictor":
        return 2.0 * u
    if formula == "0.15":
        return 0.15
    raise AssertionError(f"unknown G09 sy formula {formula}")


def run_policy_e1(
    policy: str,
    libmf6: Path,
    swaplib: Path,
    swap: Fgc44RealSwap,
    duration_day: float,
    qbot_cm_per_day: float,
    regime: dict[str, object],
    sy: float,
    a: float,
    intercept: float,
    reference_root_m: float,
    start_dh_m: float,
) -> dict[str, object]:
    _, _, href, origin, _ = initialize_case(swap, duration_day, qbot_cm_per_day)
    head = href + start_dh_m
    contractions_total = 0
    raw_inadmissible = 0
    merit_increases = 0
    one_sided_uses = 0
    estimator_halvings = 0
    trace: list[dict[str, object]] = []

    for outer in range(1, MAX_OUTER + 1):
        status, q, residual = residual_at(swap, origin, head, a, intercept)
        if status != 0 or q is None or residual is None:
            return {
                "classification": "CURRENT_HEAD_INADMISSIBLE",
                "outer": outer,
                "status": status,
                "contractions": contractions_total,
                "one_sided_uses": one_sided_uses,
            }

        if abs(residual) <= FLUX_TOL and abs(head - reference_root_m) <= HEAD_TOL_M:
            return {
                "classification": "CONVERGED",
                "outer": outer - 1,
                "final_head_m": head,
                "final_residual_m_per_s": residual,
                "head_error_m": head - reference_root_m,
                "contractions": contractions_total,
                "raw_inadmissible": raw_inadmissible,
                "merit_increases": merit_increases,
                "one_sided_uses": one_sided_uses,
                "estimator_halvings": estimator_halvings,
                "trace": trace,
            }

        est = estimate_admissibility_aware(swap, origin, head)
        if est["classification"] != "AVAILABLE":
            return {
                "classification": "TANGENT_UNAVAILABLE",
                "outer": outer,
                "contractions": contractions_total,
                "one_sided_uses": one_sided_uses,
                "estimator": est,
            }
        p = float(est["slope_per_s"])
        estimator_halvings += int(est["halvings"])
        if str(est["mode"]).startswith("ONE_SIDED"):
            one_sided_uses += 1

        slope_day = p * AREA_M2 * DAY_TO_S
        rhs = slope_day * head - q * AREA_M2 * DAY_TO_S
        raw_head, _, mf_iters = solve_term(
            libmf6,
            swaplib,
            duration_day,
            href,
            float(regime["k_m_per_day"]),
            float(regime["ss_per_m"]),
            sy,
            float(regime["initial_head_bias_m"]),
            slope_day,
            rhs,
        )
        raw_status, _, raw_residual = residual_at(swap, origin, raw_head, a, intercept)
        if raw_status != 0:
            raw_inadmissible += 1

        if policy == "P1_E1":
            if raw_status != 0 or raw_residual is None:
                return {
                    "classification": "RAW_PROPOSAL_INADMISSIBLE",
                    "outer": outer,
                    "raw_head_m": raw_head,
                    "status": raw_status,
                    "raw_inadmissible": raw_inadmissible,
                    "one_sided_uses": one_sided_uses,
                }
            candidate = raw_head
            candidate_residual = raw_residual
            if abs(candidate_residual) > abs(residual) + MERIT_ABS_TOL:
                merit_increases += 1

        elif policy == "P4_E1":
            candidate = raw_head
            candidate_residual = raw_residual
            accepted = (
                raw_status == 0
                and candidate_residual is not None
                and abs(candidate_residual) <= abs(residual) + MERIT_ABS_TOL
            )
            local = 0
            while not accepted and local < MAX_BACKTRACK:
                candidate = head + 0.5 * (candidate - head)
                local += 1
                cstatus, _, cres = residual_at(swap, origin, candidate, a, intercept)
                candidate_residual = cres
                accepted = (
                    cstatus == 0
                    and candidate_residual is not None
                    and abs(candidate_residual) <= abs(residual) + MERIT_ABS_TOL
                )
            contractions_total += local
            if not accepted or candidate_residual is None:
                return {
                    "classification": "SAFEGUARD_EXHAUSTED",
                    "outer": outer,
                    "raw_head_m": raw_head,
                    "raw_status": raw_status,
                    "contractions": contractions_total,
                    "raw_inadmissible": raw_inadmissible,
                    "one_sided_uses": one_sided_uses,
                }
        else:
            raise ValueError(policy)

        trace.append({
            "outer": outer,
            "head_m": candidate,
            "residual_m_per_s": float(candidate_residual),
            "raw_head_m": raw_head,
            "tangent_per_s": p,
            "tangent_mode": est["mode"],
            "tangent_d_m": est["selected_d_m"],
            "mf_iterations": mf_iters,
        })
        head = candidate

    status, _, final_residual = residual_at(swap, origin, head, a, intercept)
    return {
        "classification": "OUTER_BUDGET_EXHAUSTED",
        "outer": MAX_OUTER,
        "status": status,
        "final_head_m": head,
        "final_residual_m_per_s": final_residual,
        "head_error_m": head - reference_root_m,
        "contractions": contractions_total,
        "raw_inadmissible": raw_inadmissible,
        "merit_increases": merit_increases,
        "one_sided_uses": one_sided_uses,
        "estimator_halvings": estimator_halvings,
        "trace": trace,
    }


def main() -> None:
    _, regimes = load_prereg()
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    swaplib = Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(libmf6.is_file(), "missing live MODFLOW library")
    require(swaplib.is_file(), "missing real SWAP library")

    swap = Fgc44RealSwap(swaplib)
    estimator_rows: list[dict[str, object]] = []

    for case_id, duration, qbot, neg_dh, pos_dh in BOUNDARY_STATES:
        _, _, href, origin, _ = initialize_case(swap, duration, qbot)
        for side, dh in (("NEG", neg_dh), ("POS", pos_dh)):
            head = href + dh
            s0, _ = trial_discard(swap, origin, head)
            require(s0 == 0, f"G09 frozen boundary state no longer admissible {case_id} {side}")
            e0 = estimate_central(swap, origin, head)
            e1 = estimate_admissibility_aware(swap, origin, head)
            require(e1["classification"] == "AVAILABLE", f"G09 E1 unavailable {case_id} {side}")
            consistency = consistency_check(swap, origin, head, e1)
            require(bool(consistency["pass"]), f"G09 E1 half-step inconsistency {case_id} {side}")

            central_rel = None
            central_pass = None
            if e0["classification"] == "AVAILABLE":
                central_rel = abs(float(e1["slope_per_s"]) - float(e0["slope_per_s"])) / max(
                    abs(float(e1["slope_per_s"])), abs(float(e0["slope_per_s"]))
                )
                central_pass = central_rel <= REL_TOL
                require(central_pass, f"G09 E1/E0 disagreement {case_id} {side}")

            row = {
                "case_id": case_id,
                "side": side,
                "duration_day": duration,
                "qbot_cm_per_day": qbot,
                "dh_m": dh,
                "e0": e0,
                "e1": e1,
                "e1_half_step_consistency": consistency,
                "e1_e0_relative_difference": central_rel,
                "e1_e0_pass": central_pass,
            }
            estimator_rows.append(row)
            print("FGC44_G09_ESTIMATOR_JSON=" + json.dumps(row, sort_keys=True, separators=(",", ":")))
        require(swap.state() == origin, f"G09 estimator sweep mutated authority {case_id}")

    c2neg = next(x for x in estimator_rows if x["case_id"] == "C2_HIGH_FORCING" and x["side"] == "NEG")
    require(c2neg["e0"]["classification"] == "TANGENT_UNAVAILABLE",
            "G09 did not reproduce the G08 C2-negative central-tangent gap")
    require(c2neg["e1"]["classification"] == "AVAILABLE",
            "G09 E1 did not close C2-negative tangent gap")
    require(str(c2neg["e1"]["mode"]).startswith("ONE_SIDED"),
            "G09 C2-negative E1 did not exercise one-sided fallback")

    # Targeted policy replay: exact G08 failing state, unchanged three GW regimes.
    case_id, duration, qbot, start_dh = "C2_HIGH_FORCING", 1.0e-4, 2.0e-6, -5.0e-6
    _, _, href, origin, diag = initialize_case(swap, duration, qbot)
    scan = scan_swap(swap, origin, href)
    u = float(diag["u"])
    policy_rows: list[dict[str, object]] = []

    for regime in regimes:
        sy = resolve_sy(regime, u)
        a, intercept, fit_error = groundwater_response(libmf6, swaplib, duration, href, regime, sy)
        root = reference_root(swap, origin, scan, a, intercept)
        require(root is not None, f"G09 missing reference root for {regime['id']}")

        for policy in ("P1_E1", "P4_E1"):
            result = run_policy_e1(
                policy, libmf6, swaplib, swap, duration, qbot, regime, sy,
                a, intercept, float(root), start_dh
            )
            row = {
                "case_id": case_id,
                "regime_id": regime["id"],
                "policy": policy,
                "start_dh_m": start_dh,
                "a_per_s": a,
                "gw_fit_error_m_per_s": fit_error,
                "reference_root_m": root,
                **result,
            }
            policy_rows.append(row)
            print("FGC44_G09_POLICY_JSON=" + json.dumps(row, sort_keys=True, separators=(",", ":")))
            require(result["classification"] != "TANGENT_UNAVAILABLE",
                    f"G09 E1 policy replay retained tangent-unavailable {regime['id']} {policy}")
        require(swap.state() == origin, f"G09 policy replay mutated authority {regime['id']}")

    p1 = [x for x in policy_rows if x["policy"] == "P1_E1"]
    p4 = [x for x in policy_rows if x["policy"] == "P4_E1"]
    require(all(x["classification"] == "CONVERGED" for x in p1),
            f"G09 P1-E1 did not converge all targeted cases: {p1}")
    require(all(x["classification"] == "CONVERGED" for x in p4),
            f"G09 P4-E1 did not converge all targeted cases: {p4}")

    summary = {
        "boundary_state_count": len(estimator_rows),
        "e0_available_count": sum(x["e0"]["classification"] == "AVAILABLE" for x in estimator_rows),
        "e0_unavailable_count": sum(x["e0"]["classification"] != "AVAILABLE" for x in estimator_rows),
        "e1_available_count": sum(x["e1"]["classification"] == "AVAILABLE" for x in estimator_rows),
        "e1_one_sided_count": sum(str(x["e1"]["mode"]).startswith("ONE_SIDED") for x in estimator_rows),
        "c2_negative_e0": c2neg["e0"]["classification"],
        "c2_negative_e1": c2neg["e1"]["classification"],
        "c2_negative_e1_mode": c2neg["e1"]["mode"],
        "policy_replay_count": len(policy_rows),
        "p1_e1_converged_count": sum(x["classification"] == "CONVERGED" for x in p1),
        "p4_e1_converged_count": sum(x["classification"] == "CONVERGED" for x in p4),
        "p4_total_contractions": sum(int(x.get("contractions", 0)) for x in p4),
        "one_sided_policy_uses": sum(int(x.get("one_sided_uses", 0)) for x in policy_rows),
    }
    print("FGC44_G09_SUMMARY_JSON=" + json.dumps(summary, sort_keys=True, separators=(",", ":")))
    print("FGC44_G09_TRANSACTION_AUTHORITY=PASS")
    print("FGC44_G09_ESTIMATOR_CONSISTENCY=PASS")
    print("GC_FIXED_INTERFACE_G09_EXECUTION=PASS")


if __name__ == "__main__":
    main()
