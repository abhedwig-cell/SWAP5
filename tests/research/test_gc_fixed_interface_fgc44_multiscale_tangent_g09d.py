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

PREREG = ROOT / "integration" / "research" / "GC_FIXED_INTERFACE_G09D_PREREGISTRATION.json"
G08_PREREG = ROOT / "integration" / "research" / "GC_FIXED_INTERFACE_G08_PREREGISTRATION.json"
G09_PREREG = ROOT / "integration" / "research" / "GC_FIXED_INTERFACE_G09_PREREGISTRATION.json"

REL_TOL = 0.05
MERIT_ABS_TOL = 1.0e-18
SCALES_M = (
    2.5e-7, 1.25e-7, 6.25e-8, 3.125e-8,
    1.5625e-8, 7.8125e-9, 3.90625e-9,
)
BOUNDARY_STATES = (
    ("C0_CONTROL", 1.0e-4, 1.0e-6, -2.0e-6, 5.0e-6),
    ("C1_LOW_FORCING", 1.0e-4, 5.0e-7, -5.0e-6, 5.0e-6),
    ("C2_HIGH_FORCING", 1.0e-4, 2.0e-6, -5.0e-6, 2.0e-6),
    ("C3_LONG_HIGH", 2.0e-4, 2.0e-6, -5.0e-6, 2.0e-6),
)
REPLAYS = (
    ("C1_LOW_FORCING", 1.0e-4, 5.0e-7, -5.0e-6),
    ("C2_HIGH_FORCING", 1.0e-4, 2.0e-6, -5.0e-6),
    ("C3_LONG_HIGH", 2.0e-4, 2.0e-6, 2.0e-6),
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def load_prereg() -> list[dict[str, object]]:
    p = json.loads(PREREG.read_text())
    require(p["work_unit"] == "GC-FIXED-INTERFACE-G09D", "wrong G09D preregistration")
    require(p["status"] == "PREREGISTERED_BEFORE_EXECUTION", "G09D preregistration not frozen")
    require(tuple(float(x) for x in p["scale_ladder_m"]) == SCALES_M, "G09D scale ladder drifted")
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
    require(frozen == BOUNDARY_STATES, "G09D boundary states drifted")
    g08 = json.loads(G08_PREREG.read_text())
    return [dict(x) for x in g08["groundwater_regimes"]]


def raw_ready(raw: dict[str, object]) -> bool:
    return (
        int(raw["result_status"]) == 0
        and bool(raw["completed"])
        and bool(raw["candidate_ready"])
    )


def execution_class(raw: dict[str, object]) -> tuple[object, ...] | None:
    if not raw_ready(raw):
        return None
    return (
        int(raw["accepted_substeps"]),
        int(raw["attempts"]),
        int(raw["retries"]),
        int(raw["solver_rejections"]),
        int(raw["temporal_rejections"]),
        int(raw["internal_retries"]),
        float(raw["min_substep"]),
        float(raw["max_substep"]),
    )


def sample(
    swap: Fgc44RealSwap,
    origin: tuple[int, float, int, float],
    head: float,
) -> dict[str, object]:
    status, q = trial_discard(swap, origin, head)
    raw = swap.raw_corrector_diagnostics(head)
    require(swap.state() == origin, "G09D probe mutated accepted SWAP/ledger authority")
    cls = execution_class(raw)
    return {
        "head_m": head,
        "participant_status": int(status),
        "q_swap_m_per_s": float(q) if status == 0 else None,
        "raw_ready": raw_ready(raw),
        "execution_class": list(cls) if cls is not None else None,
        "raw": {
            "result_status": int(raw["result_status"]),
            "completed": bool(raw["completed"]),
            "candidate_ready": bool(raw["candidate_ready"]),
            "accepted_substeps": int(raw["accepted_substeps"]),
            "attempts": int(raw["attempts"]),
            "retries": int(raw["retries"]),
            "solver_rejections": int(raw["solver_rejections"]),
            "temporal_rejections": int(raw["temporal_rejections"]),
            "internal_retries": int(raw["internal_retries"]),
            "min_substep": float(raw["min_substep"]),
            "max_substep": float(raw["max_substep"]),
        },
    }


def ready(s: dict[str, object]) -> bool:
    return (
        int(s["participant_status"]) == 0
        and bool(s["raw_ready"])
        and s["q_swap_m_per_s"] is not None
        and s["execution_class"] is not None
    )


def same_class(*samples: dict[str, object]) -> bool:
    return all(ready(s) for s in samples) and all(
        samples[0]["execution_class"] == s["execution_class"] for s in samples[1:]
    )


def candidate_at_scale(
    center: dict[str, object],
    minus2: dict[str, object],
    minus1: dict[str, object],
    plus1: dict[str, object],
    plus2: dict[str, object],
    d: float,
) -> dict[str, object] | None:
    q0 = float(center["q_swap_m_per_s"])

    if same_class(minus1, plus1):
        slope = (float(plus1["q_swap_m_per_s"]) - float(minus1["q_swap_m_per_s"])) / (2.0 * d)
        mode = "CENTRAL_STENCIL_CLASS"
        used = ["minus1", "plus1"]
        cls = minus1["execution_class"]
    elif same_class(center, minus1, minus2):
        slope = (
            3.0 * q0
            - 4.0 * float(minus1["q_swap_m_per_s"])
            + float(minus2["q_swap_m_per_s"])
        ) / (2.0 * d)
        mode = "BACKWARD_STENCIL_CLASS"
        used = ["center", "minus1", "minus2"]
        cls = center["execution_class"]
    elif same_class(center, plus1, plus2):
        slope = (
            -3.0 * q0
            + 4.0 * float(plus1["q_swap_m_per_s"])
            - float(plus2["q_swap_m_per_s"])
        ) / (2.0 * d)
        mode = "FORWARD_STENCIL_CLASS"
        used = ["center", "plus1", "plus2"]
        cls = center["execution_class"]
    else:
        return None

    if not math.isfinite(slope) or slope >= 0.0:
        return None
    return {
        "scale_m": d,
        "mode": mode,
        "slope_per_s": slope,
        "used": used,
        "execution_class": cls,
    }


def estimate_e3(
    swap: Fgc44RealSwap,
    origin: tuple[int, float, int, float],
    head: float,
) -> dict[str, object]:
    cache: dict[str, dict[str, object]] = {}

    def get(h: float) -> dict[str, object]:
        key = h.hex()
        if key not in cache:
            cache[key] = sample(swap, origin, h)
        return cache[key]

    center = get(head)
    if not ready(center):
        return {
            "classification": "CENTER_UNAVAILABLE",
            "center": center,
        }

    candidates: list[dict[str, object] | None] = []
    attempts: list[dict[str, object]] = []
    for d in SCALES_M:
        sm2 = get(head - 2.0 * d)
        sm1 = get(head - d)
        sp1 = get(head + d)
        sp2 = get(head + 2.0 * d)
        cand = candidate_at_scale(center, sm2, sm1, sp1, sp2, d)
        candidates.append(cand)
        attempts.append({
            "scale_m": d,
            "candidate": cand,
            "center_class": center["execution_class"],
            "minus2": {"status": sm2["participant_status"], "class": sm2["execution_class"]},
            "minus1": {"status": sm1["participant_status"], "class": sm1["execution_class"]},
            "plus1": {"status": sp1["participant_status"], "class": sp1["execution_class"]},
            "plus2": {"status": sp2["participant_status"], "class": sp2["execution_class"]},
        })

    for i in range(len(SCALES_M) - 1):
        coarse = candidates[i]
        fine = candidates[i + 1]
        if coarse is None or fine is None:
            continue
        sc = float(coarse["slope_per_s"])
        sf = float(fine["slope_per_s"])
        rel = abs(sc - sf) / max(abs(sc), abs(sf))
        if rel <= REL_TOL:
            return {
                "classification": "AVAILABLE",
                "slope_per_s": sc,
                "selected_scale_m": float(coarse["scale_m"]),
                "selected_mode": coarse["mode"],
                "confirmation_scale_m": float(fine["scale_m"]),
                "confirmation_mode": fine["mode"],
                "confirmation_slope_per_s": sf,
                "relative_difference": rel,
                "attempts": attempts[: i + 2],
                "sample_count": len(cache),
            }

    return {
        "classification": "TANGENT_UNAVAILABLE",
        "attempts": attempts,
        "sample_count": len(cache),
    }


def resolve_sy(regime: dict[str, object], u: float) -> float:
    formula = str(regime["sy_formula"])
    if formula == "0.75*u_predictor":
        return 0.75 * u
    if formula == "2.0*u_predictor":
        return 2.0 * u
    if formula == "0.15":
        return 0.15
    raise AssertionError(f"unknown G09D sy formula {formula}")


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
    raw_inadmissible = 0
    merit_increases = 0
    estimator_modes: list[str] = []
    trace: list[dict[str, object]] = []

    for outer in range(1, MAX_OUTER + 1):
        status, q, residual = residual_at(swap, origin, head, a, intercept)
        if status != 0 or q is None or residual is None:
            return {
                "classification": "CURRENT_HEAD_INADMISSIBLE",
                "outer": outer,
                "status": status,
                "contractions": contractions,
            }
        if abs(residual) <= FLUX_TOL and abs(head - root) <= HEAD_TOL_M:
            return {
                "classification": "CONVERGED",
                "outer": outer - 1,
                "final_head_m": head,
                "final_residual_m_per_s": residual,
                "head_error_m": head - root,
                "contractions": contractions,
                "raw_inadmissible": raw_inadmissible,
                "merit_increases": merit_increases,
                "estimator_modes": estimator_modes,
                "trace": trace,
            }

        est = estimate_e3(swap, origin, head)
        if est["classification"] != "AVAILABLE":
            return {
                "classification": "TANGENT_UNAVAILABLE",
                "outer": outer,
                "estimator": est,
                "contractions": contractions,
            }
        p = float(est["slope_per_s"])
        estimator_modes.append(str(est["selected_mode"]))
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

        if policy == "P1_E3":
            if raw_status != 0 or raw_residual is None:
                return {
                    "classification": "RAW_PROPOSAL_INADMISSIBLE",
                    "outer": outer,
                    "raw_head_m": raw_head,
                    "status": raw_status,
                    "contractions": contractions,
                    "estimator_modes": estimator_modes,
                }
            candidate = raw_head
            candidate_residual = raw_residual
            if abs(candidate_residual) > abs(residual) + MERIT_ABS_TOL:
                merit_increases += 1

        elif policy == "P4_E3":
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
                    "classification": "SAFEGUARD_EXHAUSTED",
                    "outer": outer,
                    "raw_head_m": raw_head,
                    "raw_status": raw_status,
                    "contractions": contractions,
                    "estimator_modes": estimator_modes,
                }
        else:
            raise ValueError(policy)

        trace.append({
            "outer": outer,
            "head_m": candidate,
            "residual_m_per_s": float(candidate_residual),
            "raw_head_m": raw_head,
            "tangent_per_s": p,
            "tangent_mode": est["selected_mode"],
            "tangent_scale_m": est["selected_scale_m"],
            "confirmation_scale_m": est["confirmation_scale_m"],
            "confirmation_relative_difference": est["relative_difference"],
            "mf_iterations": mf_iters,
        })
        head = candidate

    status, _, final_res = residual_at(swap, origin, head, a, intercept)
    return {
        "classification": "OUTER_BUDGET_EXHAUSTED",
        "outer": MAX_OUTER,
        "status": status,
        "final_head_m": head,
        "final_residual_m_per_s": final_res,
        "head_error_m": head - root,
        "contractions": contractions,
        "raw_inadmissible": raw_inadmissible,
        "merit_increases": merit_increases,
        "estimator_modes": estimator_modes,
        "trace": trace,
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
            est = estimate_e3(swap, origin, href + dh)
            require(est["classification"] == "AVAILABLE", f"G09D E3 unavailable {case_id} {side}")
            require(float(est["relative_difference"]) <= REL_TOL, f"G09D E3 inconsistency {case_id} {side}")
            row = {
                "case_id": case_id,
                "duration_day": duration,
                "qbot_cm_per_day": qbot,
                "side": side,
                "dh_m": dh,
                "e3": est,
            }
            estimator_rows.append(row)
            print("FGC44_G09D_ESTIMATOR_JSON=" + json.dumps(row, sort_keys=True, separators=(",", ":")))
        require(swap.state() == origin, f"G09D estimator sweep mutated authority {case_id}")

    c1neg = next(x for x in estimator_rows if x["case_id"] == "C1_LOW_FORCING" and x["side"] == "NEG")
    require(c1neg["e3"]["selected_mode"] == "CENTRAL_STENCIL_CLASS",
            "G09D C1-negative did not recover pairwise-class central tangent")
    require(c1neg["e3"]["confirmation_mode"] == "CENTRAL_STENCIL_CLASS",
            "G09D C1-negative confirmation not central")

    c2neg = next(x for x in estimator_rows if x["case_id"] == "C2_HIGH_FORCING" and x["side"] == "NEG")
    require(c2neg["e3"]["classification"] == "AVAILABLE", "G09D C2-negative unavailable")
    require("BACKWARD" in str(c2neg["e3"]["selected_mode"]),
            "G09D C2-negative did not use class-consistent backward stencil")

    c3pos = next(x for x in estimator_rows if x["case_id"] == "C3_LONG_HIGH" and x["side"] == "POS")
    require("BACKWARD" in str(c3pos["e3"]["selected_mode"]),
            "G09D C3-positive did not reject cross-branch central stencil")

    policy_rows: list[dict[str, object]] = []
    for case_id, duration, qbot, start_dh in REPLAYS:
        _, _, href, origin, diag = initialize_case(swap, duration, qbot)
        scan = scan_swap(swap, origin, href)
        u = float(diag["u"])
        for regime in regimes:
            sy = resolve_sy(regime, u)
            a, intercept, fit_error = groundwater_response(libmf6, swaplib, duration, href, regime, sy)
            root = reference_root(swap, origin, scan, a, intercept)
            require(root is not None, f"G09D missing reference root {case_id} {regime['id']}")
            for policy in ("P1_E3", "P4_E3"):
                result = run_policy(
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
                print("FGC44_G09D_POLICY_JSON=" + json.dumps(row, sort_keys=True, separators=(",", ":")))
                require(result["classification"] == "CONVERGED",
                        f"G09D replay failed {case_id} {regime['id']} {policy}: {result}")
        require(swap.state() == origin, f"G09D replay mutated authority {case_id}")

    p1 = [x for x in policy_rows if x["policy"] == "P1_E3"]
    p4 = [x for x in policy_rows if x["policy"] == "P4_E3"]
    summary = {
        "boundary_state_count": len(estimator_rows),
        "e3_available_count": sum(x["e3"]["classification"] == "AVAILABLE" for x in estimator_rows),
        "e3_consistent_count": sum(float(x["e3"]["relative_difference"]) <= REL_TOL for x in estimator_rows),
        "c1_negative_selected_mode": c1neg["e3"]["selected_mode"],
        "c1_negative_scale_m": c1neg["e3"]["selected_scale_m"],
        "c2_negative_selected_mode": c2neg["e3"]["selected_mode"],
        "c2_negative_scale_m": c2neg["e3"]["selected_scale_m"],
        "c3_positive_selected_mode": c3pos["e3"]["selected_mode"],
        "c3_positive_scale_m": c3pos["e3"]["selected_scale_m"],
        "policy_replay_count": len(policy_rows),
        "p1_e3_converged_count": sum(x["classification"] == "CONVERGED" for x in p1),
        "p4_e3_converged_count": sum(x["classification"] == "CONVERGED" for x in p4),
        "p4_total_contractions": sum(int(x.get("contractions", 0)) for x in p4),
        "p1_merit_increase_total": sum(int(x.get("merit_increases", 0)) for x in p1),
        "raw_inadmissible_proposals_total": sum(int(x.get("raw_inadmissible", 0)) for x in policy_rows),
    }
    print("FGC44_G09D_SUMMARY_JSON=" + json.dumps(summary, sort_keys=True, separators=(",", ":")))
    print("FGC44_G09D_TRANSACTION_AUTHORITY=PASS")
    print("FGC44_G09D_MULTISCALE_STENCIL_CONSISTENCY=PASS")
    print("GC_FIXED_INTERFACE_G09D_EXECUTION=PASS")


if __name__ == "__main__":
    main()
