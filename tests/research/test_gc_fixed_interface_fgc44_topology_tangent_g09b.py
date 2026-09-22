from __future__ import annotations

import json
import math
import os
import sys
from pathlib import Path

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

PREREG = ROOT / "integration" / "research" / "GC_FIXED_INTERFACE_G09B_PREREGISTRATION.json"
G08_PREREG = ROOT / "integration" / "research" / "GC_FIXED_INTERFACE_G08_PREREGISTRATION.json"
G09_PREREG = ROOT / "integration" / "research" / "GC_FIXED_INTERFACE_G09_PREREGISTRATION.json"

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
REPLAYS = (
    ("C2_HIGH_FORCING", 1.0e-4, 2.0e-6, -5.0e-6),
    ("C3_LONG_HIGH", 2.0e-4, 2.0e-6, 2.0e-6),
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def load_prereg() -> list[dict[str, object]]:
    p = json.loads(PREREG.read_text())
    require(p["work_unit"] == "GC-FIXED-INTERFACE-G09B", "wrong G09B preregistration")
    require(p["status"] == "PREREGISTERED_BEFORE_EXECUTION", "G09B preregistration not frozen")
    g09 = json.loads(G09_PREREG.read_text())
    frozen = tuple(
        (
            str(x["case_id"]),
            float(x["duration_day"]),
            float(x["predictor_qbot_cm_per_day"]),
            float(x["negative_dh_m"]),
            float(x["positive_dh_m"]),
        )
        for x in g09["frozen_boundary_states"]
    )
    require(frozen == BOUNDARY_STATES, "G09B boundary states drifted from G09")
    g08 = json.loads(G08_PREREG.read_text())
    return [dict(x) for x in g08["groundwater_regimes"]]


def raw_signature(raw: dict[str, object]) -> tuple[int, int, int, int, int, int]:
    require(int(raw["result_status"]) == 0, "signature requested for nonzero raw result")
    require(bool(raw["completed"]) and bool(raw["candidate_ready"]), "signature requested for incomplete raw trial")
    return (
        int(raw["accepted_substeps"]),
        int(raw["attempts"]),
        int(raw["retries"]),
        int(raw["solver_rejections"]),
        int(raw["temporal_rejections"]),
        int(raw["internal_retries"]),
    )


def sample(
    swap: Fgc44RealSwap,
    origin: tuple[int, float, int, float],
    head: float,
) -> dict[str, object]:
    status, q = trial_discard(swap, origin, head)
    raw = swap.raw_corrector_diagnostics(head)
    require(swap.state() == origin, "G09B raw diagnostic mutated accepted authority")
    compatible_raw = (
        int(raw["result_status"]) == 0
        and bool(raw["completed"])
        and bool(raw["candidate_ready"])
    )
    return {
        "head_m": head,
        "participant_status": int(status),
        "q_swap_m_per_s": float(q) if status == 0 else None,
        "raw": raw,
        "raw_ready": compatible_raw,
        "signature": list(raw_signature(raw)) if compatible_raw else None,
    }


def baseline_central(
    swap: Fgc44RealSwap,
    origin: tuple[int, float, int, float],
    head: float,
) -> dict[str, object]:
    d = INITIAL_D_M
    for halving in range(MAX_HALVINGS + 1):
        sm, qm = trial_discard(swap, origin, head - d)
        sp, qp = trial_discard(swap, origin, head + d)
        if sm == 0 and sp == 0:
            slope = (qp - qm) / (2.0 * d)
            if math.isfinite(slope) and slope < 0.0:
                return {
                    "classification": "AVAILABLE",
                    "slope_per_s": slope,
                    "selected_d_m": d,
                    "halvings": halving,
                }
        d *= 0.5
    return {"classification": "TANGENT_UNAVAILABLE"}


def estimate_e2(
    swap: Fgc44RealSwap,
    origin: tuple[int, float, int, float],
    head: float,
    initial_d: float = INITIAL_D_M,
    max_halvings: int = MAX_HALVINGS,
) -> dict[str, object]:
    center = sample(swap, origin, head)
    if int(center["participant_status"]) != 0 or not bool(center["raw_ready"]):
        return {
            "classification": "CENTER_UNAVAILABLE",
            "center": center,
        }
    q0 = float(center["q_swap_m_per_s"])
    center_sig = tuple(center["signature"])
    d = initial_d
    attempts: list[dict[str, object]] = []

    for halving in range(max_halvings + 1):
        sm2 = sample(swap, origin, head - 2.0 * d)
        sm1 = sample(swap, origin, head - d)
        sp1 = sample(swap, origin, head + d)
        sp2 = sample(swap, origin, head + 2.0 * d)

        def eligible(s: dict[str, object]) -> bool:
            return (
                int(s["participant_status"]) == 0
                and bool(s["raw_ready"])
                and tuple(s["signature"]) == center_sig
            )

        em2, em1, ep1, ep2 = map(eligible, (sm2, sm1, sp1, sp2))
        attempt = {
            "d_m": d,
            "center_signature": list(center_sig),
            "minus2": {"eligible": em2, "status": sm2["participant_status"], "signature": sm2["signature"]},
            "minus1": {"eligible": em1, "status": sm1["participant_status"], "signature": sm1["signature"]},
            "plus1": {"eligible": ep1, "status": sp1["participant_status"], "signature": sp1["signature"]},
            "plus2": {"eligible": ep2, "status": sp2["participant_status"], "signature": sp2["signature"]},
        }
        attempts.append(attempt)

        if em1 and ep1:
            slope = (float(sp1["q_swap_m_per_s"]) - float(sm1["q_swap_m_per_s"])) / (2.0 * d)
            mode = "CENTRAL_TOPOLOGY_MATCH"
        elif em1 and em2:
            slope = (
                3.0 * q0
                - 4.0 * float(sm1["q_swap_m_per_s"])
                + float(sm2["q_swap_m_per_s"])
            ) / (2.0 * d)
            mode = "BACKWARD_TOPOLOGY_MATCH"
        elif ep1 and ep2:
            slope = (
                -3.0 * q0
                + 4.0 * float(sp1["q_swap_m_per_s"])
                - float(sp2["q_swap_m_per_s"])
            ) / (2.0 * d)
            mode = "FORWARD_TOPOLOGY_MATCH"
        else:
            d *= 0.5
            continue

        if math.isfinite(slope) and slope < 0.0:
            return {
                "classification": "AVAILABLE",
                "mode": mode,
                "slope_per_s": slope,
                "selected_d_m": d,
                "halvings": halving,
                "center_signature": list(center_sig),
                "attempts": attempts,
            }
        d *= 0.5

    return {
        "classification": "TANGENT_UNAVAILABLE",
        "center_signature": list(center_sig),
        "attempts": attempts,
    }


def consistency(
    swap: Fgc44RealSwap,
    origin: tuple[int, float, int, float],
    head: float,
    e2: dict[str, object],
) -> dict[str, object]:
    require(e2["classification"] == "AVAILABLE", "E2 consistency requires available tangent")
    slope = float(e2["slope_per_s"])
    d = float(e2["selected_d_m"])
    half = estimate_e2(swap, origin, head, initial_d=0.5 * d)
    require(half["classification"] == "AVAILABLE", "G09B half-step E2 unavailable")
    half_slope = float(half["slope_per_s"])
    rel = abs(slope - half_slope) / max(abs(slope), abs(half_slope))
    return {
        "half_mode": half["mode"],
        "half_slope_per_s": half_slope,
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
    raise AssertionError(f"unknown G09B sy formula {formula}")


def run_policy(
    policy: str,
    libmf6: Path,
    swaplib: Path,
    swap: Fgc44RealSwap,
    duration: float,
    qbot: float,
    regime: dict[str, object],
    sy: float,
    a: float,
    intercept: float,
    root: float,
    start_dh: float,
) -> dict[str, object]:
    _, _, href, origin, _ = initialize_case(swap, duration, qbot)
    head = href + start_dh
    contractions = 0
    topology_modes: list[str] = []
    raw_inadmissible = 0
    merit_increases = 0
    trace: list[dict[str, object]] = []

    for outer in range(1, MAX_OUTER + 1):
        status, q, residual = residual_at(swap, origin, head, a, intercept)
        if status != 0 or q is None or residual is None:
            return {"classification":"CURRENT_HEAD_INADMISSIBLE","outer":outer,"status":status}

        if abs(residual) <= FLUX_TOL and abs(head - root) <= HEAD_TOL_M:
            return {
                "classification":"CONVERGED",
                "outer":outer-1,
                "final_head_m":head,
                "final_residual_m_per_s":residual,
                "head_error_m":head-root,
                "contractions":contractions,
                "raw_inadmissible":raw_inadmissible,
                "merit_increases":merit_increases,
                "topology_modes":topology_modes,
                "trace":trace,
            }

        est = estimate_e2(swap, origin, head)
        if est["classification"] != "AVAILABLE":
            return {
                "classification":"TANGENT_UNAVAILABLE",
                "outer":outer,
                "estimator":est,
                "contractions":contractions,
            }
        p = float(est["slope_per_s"])
        topology_modes.append(str(est["mode"]))
        slope_day = p * AREA_M2 * DAY_TO_S
        rhs = slope_day * head - q * AREA_M2 * DAY_TO_S
        raw_head, _, mf_iters = solve_term(
            libmf6,
            swaplib,
            duration,
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

        if policy == "P1_E2":
            if raw_status != 0 or raw_residual is None:
                return {
                    "classification":"RAW_PROPOSAL_INADMISSIBLE",
                    "outer":outer,
                    "raw_head_m":raw_head,
                    "status":raw_status,
                    "contractions":contractions,
                    "topology_modes":topology_modes,
                }
            candidate = raw_head
            candidate_residual = raw_residual
            if abs(candidate_residual) > abs(residual) + MERIT_ABS_TOL:
                merit_increases += 1

        elif policy == "P4_E2":
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
            contractions += local
            if not accepted or candidate_residual is None:
                return {
                    "classification":"SAFEGUARD_EXHAUSTED",
                    "outer":outer,
                    "raw_head_m":raw_head,
                    "raw_status":raw_status,
                    "contractions":contractions,
                    "topology_modes":topology_modes,
                }
        else:
            raise ValueError(policy)

        trace.append({
            "outer":outer,
            "head_m":candidate,
            "residual_m_per_s":float(candidate_residual),
            "raw_head_m":raw_head,
            "tangent_per_s":p,
            "tangent_mode":est["mode"],
            "tangent_d_m":est["selected_d_m"],
            "mf_iterations":mf_iters,
        })
        head = candidate

    status, _, final_res = residual_at(swap, origin, head, a, intercept)
    return {
        "classification":"OUTER_BUDGET_EXHAUSTED",
        "outer":MAX_OUTER,
        "status":status,
        "final_head_m":head,
        "final_residual_m_per_s":final_res,
        "head_error_m":head-root,
        "contractions":contractions,
        "raw_inadmissible":raw_inadmissible,
        "merit_increases":merit_increases,
        "topology_modes":topology_modes,
        "trace":trace,
    }


def main() -> None:
    regimes = load_prereg()
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    swaplib = Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(libmf6.is_file(), "missing live MODFLOW library")
    require(swaplib.is_file(), "missing real SWAP bridge library")

    swap = Fgc44RealSwap(swaplib)
    estimator_rows: list[dict[str, object]] = []

    for case_id, duration, qbot, neg_dh, pos_dh in BOUNDARY_STATES:
        _, _, href, origin, _ = initialize_case(swap, duration, qbot)
        for side, dh in (("NEG", neg_dh), ("POS", pos_dh)):
            head = href + dh
            base = baseline_central(swap, origin, head)
            e2 = estimate_e2(swap, origin, head)
            require(e2["classification"] == "AVAILABLE", f"G09B E2 unavailable {case_id} {side}")
            cons = consistency(swap, origin, head, e2)
            require(bool(cons["pass"]), f"G09B E2 inconsistency {case_id} {side}")
            row = {
                "case_id":case_id,
                "duration_day":duration,
                "qbot_cm_per_day":qbot,
                "side":side,
                "dh_m":dh,
                "baseline_e0":base,
                "e2":e2,
                "consistency":cons,
            }
            estimator_rows.append(row)
            print("FGC44_G09B_ESTIMATOR_JSON="+json.dumps(row,sort_keys=True,separators=(",",":")))
        require(swap.state() == origin, f"G09B estimator sweep mutated authority {case_id}")

    c2neg = next(x for x in estimator_rows if x["case_id"]=="C2_HIGH_FORCING" and x["side"]=="NEG")
    require(c2neg["baseline_e0"]["classification"]=="TANGENT_UNAVAILABLE",
            "G09B C2-negative baseline no longer reproduces central gap")
    require(c2neg["e2"]["classification"]=="AVAILABLE",
            "G09B C2-negative E2 unavailable")
    require(str(c2neg["e2"]["mode"]).startswith("BACKWARD"),
            "G09B C2-negative did not select topology-matched backward tangent")

    c3pos = next(x for x in estimator_rows if x["case_id"]=="C3_LONG_HIGH" and x["side"]=="POS")
    require(c3pos["e2"]["classification"]=="AVAILABLE",
            "G09B C3-positive E2 unavailable")
    require(str(c3pos["e2"]["mode"]).startswith("BACKWARD"),
            "G09B C3-positive did not reject mismatched positive execution branch")

    policy_rows: list[dict[str, object]] = []
    for case_id, duration, qbot, start_dh in REPLAYS:
        _, _, href, origin, diag = initialize_case(swap, duration, qbot)
        scan = scan_swap(swap, origin, href)
        u = float(diag["u"])
        for regime in regimes:
            sy = resolve_sy(regime, u)
            a, intercept, fit_error = groundwater_response(libmf6, swaplib, duration, href, regime, sy)
            root = reference_root(swap, origin, scan, a, intercept)
            require(root is not None, f"G09B missing reference root {case_id} {regime['id']}")
            for policy in ("P1_E2","P4_E2"):
                result = run_policy(
                    policy,libmf6,swaplib,swap,duration,qbot,regime,sy,a,intercept,float(root),start_dh
                )
                row = {
                    "case_id":case_id,
                    "regime_id":regime["id"],
                    "policy":policy,
                    "start_dh_m":start_dh,
                    "a_per_s":a,
                    "gw_fit_error_m_per_s":fit_error,
                    "reference_root_m":root,
                    **result,
                }
                policy_rows.append(row)
                print("FGC44_G09B_POLICY_JSON="+json.dumps(row,sort_keys=True,separators=(",",":")))
                require(result["classification"]=="CONVERGED",
                        f"G09B replay failed {case_id} {regime['id']} {policy}: {result}")
        require(swap.state() == origin, f"G09B replay mutated authority {case_id}")

    p1=[x for x in policy_rows if x["policy"]=="P1_E2"]
    p4=[x for x in policy_rows if x["policy"]=="P4_E2"]
    summary={
        "boundary_state_count":len(estimator_rows),
        "e2_available_count":sum(x["e2"]["classification"]=="AVAILABLE" for x in estimator_rows),
        "e2_consistent_count":sum(bool(x["consistency"]["pass"]) for x in estimator_rows),
        "e2_backward_count":sum(str(x["e2"]["mode"]).startswith("BACKWARD") for x in estimator_rows),
        "c2_negative_mode":c2neg["e2"]["mode"],
        "c3_positive_mode":c3pos["e2"]["mode"],
        "policy_replay_count":len(policy_rows),
        "p1_e2_converged_count":sum(x["classification"]=="CONVERGED" for x in p1),
        "p4_e2_converged_count":sum(x["classification"]=="CONVERGED" for x in p4),
        "p4_total_contractions":sum(int(x.get("contractions",0)) for x in p4),
    }
    print("FGC44_G09B_SUMMARY_JSON="+json.dumps(summary,sort_keys=True,separators=(",",":")))
    print("FGC44_G09B_TRANSACTION_AUTHORITY=PASS")
    print("FGC44_G09B_TOPOLOGY_CONSISTENCY=PASS")
    print("GC_FIXED_INTERFACE_G09B_EXECUTION=PASS")


if __name__=="__main__":
    main()
