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
G09_PREREG = ROOT / "integration" / "research" / "GC_FIXED_INTERFACE_G09_PREREGISTRATION.json"
G08_PREREG = ROOT / "integration" / "research" / "GC_FIXED_INTERFACE_G08_PREREGISTRATION.json"

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
CLASS_FIELDS = (
    "accepted_substeps", "attempts", "retries", "solver_rejections",
    "temporal_rejections", "internal_retries", "min_substep", "max_substep",
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def load_prereg() -> list[dict[str, object]]:
    p = json.loads(PREREG.read_text())
    require(p["work_unit"] == "GC-FIXED-INTERFACE-G09D", "wrong G09D preregistration")
    require(p["status"] == "PREREGISTERED_BEFORE_EXECUTION", "G09D preregistration not frozen")
    require(tuple(float(x) for x in p["scale_ladder_m"]) == SCALES_M, "G09D scale ladder drifted")
    require(tuple(str(x) for x in p["execution_class"]["fields"]) == CLASS_FIELDS,
            "G09D execution class drifted")

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

    replay = tuple(
        (
            str(x["case_id"]),
            float(x["duration_day"]),
            float(x["predictor_qbot_cm_per_day"]),
            float(x["start_dh_m"]),
        )
        for x in p["policy_replays"]
    )
    require(replay == REPLAYS, "G09D replay matrix drifted")
    g08 = json.loads(G08_PREREG.read_text())
    return [dict(x) for x in g08["groundwater_regimes"]]


def raw_ready(raw: dict[str, object]) -> bool:
    return (
        int(raw["result_status"]) == 0
        and bool(raw["completed"])
        and bool(raw["candidate_ready"])
    )


def execution_class(sample: dict[str, object]) -> tuple[object, ...] | None:
    if int(sample["participant_status"]) != 0 or not bool(sample["raw_ready"]):
        return None
    raw = sample["raw"]
    return tuple(raw[field] for field in CLASS_FIELDS)


def sample_head(
    swap: Fgc44RealSwap,
    origin: tuple[int, float, int, float],
    head: float,
) -> dict[str, object]:
    status, q = trial_discard(swap, origin, head)
    raw = swap.raw_corrector_diagnostics(head)
    require(swap.state() == origin, "G09D diagnostic sample mutated accepted authority")
    sample = {
        "head_m": head,
        "participant_status": int(status),
        "q_swap_m_per_s": float(q) if status == 0 else None,
        "raw_ready": raw_ready(raw),
        "raw": raw,
    }
    cls = execution_class(sample)
    sample["execution_class"] = list(cls) if cls is not None else None
    return sample


def candidate_at_scale(
    center: dict[str, object],
    samples: dict[int, dict[str, object]],
    d: float,
) -> dict[str, object] | None:
    q0 = center["q_swap_m_per_s"]
    require(q0 is not None, "G09D center q unavailable")

    def ready(m: int) -> bool:
        return execution_class(samples[m]) is not None and samples[m]["q_swap_m_per_s"] is not None

    cm = execution_class(samples[-1])
    cp = execution_class(samples[1])
    if ready(-1) and ready(1) and cm == cp:
        slope = (
            float(samples[1]["q_swap_m_per_s"]) - float(samples[-1]["q_swap_m_per_s"])
        ) / (2.0 * d)
        mode = "CENTRAL"
        cls = cm
        used = (-1, 1)
    else:
        c0 = execution_class(center)
        cm1 = execution_class(samples[-1])
        cm2 = execution_class(samples[-2])
        cp1 = execution_class(samples[1])
        cp2 = execution_class(samples[2])
        if c0 is not None and ready(-1) and ready(-2) and c0 == cm1 == cm2:
            slope = (
                3.0 * float(q0)
                - 4.0 * float(samples[-1]["q_swap_m_per_s"])
                + float(samples[-2]["q_swap_m_per_s"])
            ) / (2.0 * d)
            mode = "BACKWARD"
            cls = c0
            used = (0, -1, -2)
        elif c0 is not None and ready(1) and ready(2) and c0 == cp1 == cp2:
            slope = (
                -3.0 * float(q0)
                + 4.0 * float(samples[1]["q_swap_m_per_s"])
                - float(samples[2]["q_swap_m_per_s"])
            ) / (2.0 * d)
            mode = "FORWARD"
            cls = c0
            used = (0, 1, 2)
        else:
            return None

    if not math.isfinite(slope) or slope >= 0.0:
        return None
    return {
        "mode": mode,
        "slope_per_s": float(slope),
        "scale_m": d,
        "execution_class": list(cls) if cls is not None else None,
        "used_multipliers": list(used),
    }


def estimate_e3(
    swap: Fgc44RealSwap,
    origin: tuple[int, float, int, float],
    head: float,
) -> dict[str, object]:
    cache: dict[str, dict[str, object]] = {}

    def cached(h: float) -> dict[str, object]:
        key = h.hex()
        if key not in cache:
            cache[key] = sample_head(swap, origin, h)
        return cache[key]

    center = cached(head)
    if execution_class(center) is None or center["q_swap_m_per_s"] is None:
        return {"classification": "CENTER_UNAVAILABLE", "center": center}

    scale_rows: list[dict[str, object]] = []
    candidates: list[dict[str, object] | None] = []
    for d in SCALES_M:
        samples = {m: cached(head + m * d) for m in (-2, -1, 0, 1, 2)}
        cand = candidate_at_scale(center, samples, d)
        row = {
            "scale_m": d,
            "candidate": cand,
            "samples": {
                str(m): {
                    "participant_status": samples[m]["participant_status"],
                    "execution_class": samples[m]["execution_class"],
                }
                for m in (-2, -1, 0, 1, 2)
            },
        }
        scale_rows.append(row)
        candidates.append(cand)

    for i in range(len(SCALES_M) - 1):
        coarse = candidates[i]
        fine = candidates[i + 1]
        if coarse is None or fine is None:
            continue
        s0 = float(coarse["slope_per_s"])
        s1 = float(fine["slope_per_s"])
        rel = abs(s0 - s1) / max(abs(s0), abs(s1))
        if rel <= REL_TOL:
            return {
                "classification": "AVAILABLE",
                "slope_per_s": s0,
                "selected_scale_m": float(coarse["scale_m"]),
                "selected_mode": coarse["mode"],
                "selected_execution_class": coarse["execution_class"],
                "finer_scale_m": float(fine["scale_m"]),
                "finer_mode": fine["mode"],
                "finer_slope_per_s": s1,
                "relative_difference": rel,
                "scale_rows": scale_rows,
                "unique_sample_count": len(cache),
            }

    return {
        "classification": "TANGENT_UNAVAILABLE",
        "scale_rows": scale_rows,
        "unique_sample_count": len(cache),
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
                "contractions": contractions,
                "estimator": est,
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
                    "raw_inadmissible": raw_inadmissible,
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
                    "raw_inadmissible": raw_inadmissible,
                    "estimator_modes": estimator_modes,
                }
            require(
                abs(candidate_residual) <= abs(residual) + MERIT_ABS_TOL,
                "G09D P4 accepted a merit-increasing step",
            )
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
            "tangent_finer_scale_m": est["finer_scale_m"],
            "tangent_relative_difference": est["relative_difference"],
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
            require(est["classification"] == "AVAILABLE", f"G09D E3 unavailable {case_id} {side}")
        require(swap.state() == origin, f"G09D estimator sweep mutated authority {case_id}")

    c1neg = next(x for x in estimator_rows if x["case_id"]=="C1_LOW_FORCING" and x["side"]=="NEG")
    c2neg = next(x for x in estimator_rows if x["case_id"]=="C2_HIGH_FORCING" and x["side"]=="NEG")
    c3pos = next(x for x in estimator_rows if x["case_id"]=="C3_LONG_HIGH" and x["side"]=="POS")
    require(c1neg["e3"]["selected_mode"] == "CENTRAL",
            "G09D C1 negative did not recover symmetric probe-class tangent")
    require(c2neg["e3"]["selected_mode"] in ("BACKWARD","CENTRAL"),
            "G09D C2 negative did not recover bounded tangent")
    require(c3pos["e3"]["selected_mode"] != "CENTRAL" or
            c3pos["e3"]["selected_execution_class"] == c3pos["e3"]["scale_rows"][0]["candidate"]["execution_class"],
            "G09D C3 positive used an unqualified central class")

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

            for policy in ("P1_E3","P4_E3"):
                result = run_policy(
                    policy, libmf6, swaplib, swap, duration, qbot,
                    regime, sy, a, intercept, float(root), start_dh
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
                require(
                    result["classification"] != "TANGENT_UNAVAILABLE",
                    f"G09D dynamic E3 unavailable {case_id} {regime['id']} {policy}",
                )
        require(swap.state() == origin, f"G09D replay mutated authority {case_id}")

    p1 = [x for x in policy_rows if x["policy"]=="P1_E3"]
    p4 = [x for x in policy_rows if x["policy"]=="P4_E3"]
    require(all(x["classification"]=="CONVERGED" for x in p4),
            f"G09D P4-E3 did not converge all stress replays: {p4}")

    summary = {
        "boundary_state_count": len(estimator_rows),
        "e3_available_count": sum(x["e3"]["classification"]=="AVAILABLE" for x in estimator_rows),
        "selected_modes": {
            "CENTRAL": sum(x["e3"].get("selected_mode")=="CENTRAL" for x in estimator_rows),
            "BACKWARD": sum(x["e3"].get("selected_mode")=="BACKWARD" for x in estimator_rows),
            "FORWARD": sum(x["e3"].get("selected_mode")=="FORWARD" for x in estimator_rows),
        },
        "c1_negative_mode": c1neg["e3"]["selected_mode"],
        "c1_negative_slope_per_s": c1neg["e3"]["slope_per_s"],
        "c2_negative_mode": c2neg["e3"]["selected_mode"],
        "c2_negative_slope_per_s": c2neg["e3"]["slope_per_s"],
        "c3_positive_mode": c3pos["e3"]["selected_mode"],
        "c3_positive_slope_per_s": c3pos["e3"]["slope_per_s"],
        "policy_replay_count": len(policy_rows),
        "p1_converged_count": sum(x["classification"]=="CONVERGED" for x in p1),
        "p1_failure_classes": sorted({str(x["classification"]) for x in p1 if x["classification"]!="CONVERGED"}),
        "p4_converged_count": sum(x["classification"]=="CONVERGED" for x in p4),
        "p4_total_contractions": sum(int(x.get("contractions",0)) for x in p4),
        "p4_raw_inadmissible_total": sum(int(x.get("raw_inadmissible",0)) for x in p4),
    }
    print("FGC44_G09D_SUMMARY_JSON=" + json.dumps(summary, sort_keys=True, separators=(",", ":")))
    print("FGC44_G09D_TRANSACTION_AUTHORITY=PASS")
    print("FGC44_G09D_STENCIL_MULTISCALE_ESTIMATOR=PASS")
    print("GC_FIXED_INTERFACE_G09D_EXECUTION=PASS")


if __name__ == "__main__":
    main()
