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
from test_gc_fixed_interface_fgc44_safeguarded_newton_g08 import initialize_case, trial_discard

PREREG = ROOT / "integration" / "research" / "GC_FIXED_INTERFACE_G09A_PREREGISTRATION.json"

STATES = (
    ("TARGET_C3_POS", "C3_LONG_HIGH", 2.0e-4, 2.0e-6, 2.0e-6),
    ("CONTROL_C2_NEG", "C2_HIGH_FORCING", 1.0e-4, 2.0e-6, -5.0e-6),
)
SCALES_M = (
    2.5e-7, 1.25e-7, 6.25e-8, 3.125e-8, 1.5625e-8,
    7.8125e-9, 3.90625e-9, 1.953125e-9, 9.765625e-10,
)
MULTIPLIERS = (-2, -1, 0, 1, 2)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def load_prereg() -> None:
    p = json.loads(PREREG.read_text())
    require(p["work_unit"] == "GC-FIXED-INTERFACE-G09A", "wrong G09A preregistration")
    require(p["status"] == "PREREGISTERED_BEFORE_EXECUTION", "G09A preregistration not frozen")
    frozen = tuple(
        (
            str(x["id"]),
            str(x["case_id"]),
            float(x["duration_day"]),
            float(x["predictor_qbot_cm_per_day"]),
            float(x["dh_m"]),
        )
        for x in p["frozen_states"]
    )
    require(frozen == STATES, "G09A frozen states drifted")
    require(tuple(float(x) for x in p["scale_ladder_m"]) == SCALES_M, "G09A scale ladder drifted")


def sample_head(
    swap: Fgc44RealSwap,
    origin: tuple[int, float, int, float],
    head: float,
) -> dict[str, object]:
    status, q = trial_discard(swap, origin, head)
    raw = swap.raw_corrector_diagnostics(head)
    require(swap.state() == origin, "G09A raw diagnostic mutated accepted authority")
    return {
        "head_m": head,
        "participant_status": int(status),
        "q_swap_m_per_s": float(q) if status == 0 else None,
        "raw": raw,
    }


def slope_if_available(samples: dict[int, dict[str, object]], d: float) -> dict[str, object]:
    q0 = samples[0]["q_swap_m_per_s"]
    require(q0 is not None, "G09A center state unexpectedly inadmissible")
    out: dict[str, object] = {
        "central_per_s": None,
        "backward_second_order_per_s": None,
        "forward_second_order_per_s": None,
        "least_squares_per_s": None,
    }

    qm = samples[-1]["q_swap_m_per_s"]
    qp = samples[1]["q_swap_m_per_s"]
    qm2 = samples[-2]["q_swap_m_per_s"]
    qp2 = samples[2]["q_swap_m_per_s"]

    if qm is not None and qp is not None:
        out["central_per_s"] = (float(qp) - float(qm)) / (2.0 * d)
    if qm is not None and qm2 is not None:
        out["backward_second_order_per_s"] = (
            3.0 * float(q0) - 4.0 * float(qm) + float(qm2)
        ) / (2.0 * d)
    if qp is not None and qp2 is not None:
        out["forward_second_order_per_s"] = (
            -3.0 * float(q0) + 4.0 * float(qp) - float(qp2)
        ) / (2.0 * d)

    points = []
    for m in MULTIPLIERS:
        q = samples[m]["q_swap_m_per_s"]
        if q is not None:
            points.append((m * d, float(q)))
    if len(points) >= 3:
        x = np.asarray([p[0] for p in points], dtype=float)
        y = np.asarray([p[1] for p in points], dtype=float)
        slope, intercept = np.polyfit(x, y, 1)
        fit = slope * x + intercept
        out["least_squares_per_s"] = float(slope)
        out["least_squares_max_error_m_per_s"] = float(np.max(np.abs(fit - y)))
        out["least_squares_point_count"] = len(points)
    else:
        out["least_squares_max_error_m_per_s"] = None
        out["least_squares_point_count"] = len(points)

    return out


def topology(rows: list[dict[str, object]]) -> dict[str, object]:
    minus = [int(row["samples"]["-1"]["participant_status"]) == 0 for row in rows]
    plus = [int(row["samples"]["1"]["participant_status"]) == 0 for row in rows]

    def transitions(seq: list[bool]) -> int:
        return sum(a != b for a, b in zip(seq[:-1], seq[1:]))

    return {
        "minus_status0_by_descending_scale": minus,
        "plus_status0_by_descending_scale": plus,
        "minus_transition_count": transitions(minus),
        "plus_transition_count": transitions(plus),
        "fragmented_minus": transitions(minus) > 1,
        "fragmented_plus": transitions(plus) > 1,
    }


def main() -> None:
    load_prereg()
    swaplib = Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(swaplib.is_file(), "missing real SWAP bridge library")
    swap = Fgc44RealSwap(swaplib)

    state_results: list[dict[str, object]] = []

    for state_id, case_id, duration, qbot, dh0 in STATES:
        _, _, href, origin, _ = initialize_case(swap, duration, qbot)
        h0 = href + dh0
        center_status, center_q = trial_discard(swap, origin, h0)
        require(center_status == 0 and math.isfinite(center_q), f"G09A center not admissible {state_id}")

        cache: dict[str, dict[str, object]] = {}
        rows: list[dict[str, object]] = []

        def cached(head: float) -> dict[str, object]:
            key = head.hex()
            if key not in cache:
                cache[key] = sample_head(swap, origin, head)
            return cache[key]

        for d in SCALES_M:
            samples: dict[int, dict[str, object]] = {
                m: cached(h0 + m * d) for m in MULTIPLIERS
            }
            derived = slope_if_available(samples, d)
            row = {
                "state_id": state_id,
                "case_id": case_id,
                "duration_day": duration,
                "qbot_cm_per_day": qbot,
                "center_head_m": h0,
                "center_dh_from_href_m": dh0,
                "scale_m": d,
                "samples": {str(m): samples[m] for m in MULTIPLIERS},
                "derived": derived,
            }
            rows.append(row)
            print("FGC44_G09A_SCALE_JSON=" + json.dumps(row, sort_keys=True, separators=(",", ":")))

        topo = topology(rows)
        failed_samples = [
            s for s in cache.values() if int(s["participant_status"]) != 0
        ]
        failed_raw = [
            {
                "head_m": s["head_m"],
                "participant_status": s["participant_status"],
                "raw_result_status": s["raw"]["result_status"],
                "raw_completed": s["raw"]["completed"],
                "raw_candidate_ready": s["raw"]["candidate_ready"],
                "raw_attempts": s["raw"]["attempts"],
                "raw_retries": s["raw"]["retries"],
                "raw_solver_rejections": s["raw"]["solver_rejections"],
                "raw_temporal_rejections": s["raw"]["temporal_rejections"],
                "raw_mass_rejections": s["raw"]["mass_rejections"],
                "raw_internal_retries": s["raw"]["internal_retries"],
            }
            for s in failed_samples
        ]
        result = {
            "state_id": state_id,
            "case_id": case_id,
            "duration_day": duration,
            "qbot_cm_per_day": qbot,
            "href_m": href,
            "center_head_m": h0,
            "center_dh_m": dh0,
            "scale_count": len(rows),
            "unique_sample_count": len(cache),
            "participant_failure_count": len(failed_samples),
            "topology": topo,
            "failed_sample_raw_diagnostics": failed_raw,
            "rows": rows,
        }
        state_results.append(result)
        print("FGC44_G09A_STATE_JSON=" + json.dumps(result, sort_keys=True, separators=(",", ":")))
        require(swap.state() == origin, f"G09A state {state_id} mutated accepted authority")

    require(len(state_results) == 2, "G09A state matrix incomplete")
    require(all(int(x["scale_count"]) == len(SCALES_M) for x in state_results), "G09A scale matrix incomplete")
    summary = {
        "state_count": len(state_results),
        "scale_count_per_state": len(SCALES_M),
        "target_topology": state_results[0]["topology"],
        "control_topology": state_results[1]["topology"],
        "target_participant_failure_count": state_results[0]["participant_failure_count"],
        "control_participant_failure_count": state_results[1]["participant_failure_count"],
        "target_failed_samples_with_solver_rejections": sum(
            int(x["raw_solver_rejections"]) > 0
            for x in state_results[0]["failed_sample_raw_diagnostics"]
        ),
        "control_failed_samples_with_solver_rejections": sum(
            int(x["raw_solver_rejections"]) > 0
            for x in state_results[1]["failed_sample_raw_diagnostics"]
        ),
    }
    print("FGC44_G09A_SUMMARY_JSON=" + json.dumps(summary, sort_keys=True, separators=(",", ":")))
    print("FGC44_G09A_TRANSACTION_AUTHORITY=PASS")
    print("GC_FIXED_INTERFACE_G09A_DIAGNOSTIC=PASS")


if __name__ == "__main__":
    main()
