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

PREREG = ROOT / "integration" / "research" / "GC_FIXED_INTERFACE_G09C_PREREGISTRATION.json"

STATES = (
    ("TARGET_C1_NEG", "C1_LOW_FORCING", 1.0e-4, 5.0e-7, -5.0e-6),
    ("CONTROL_C0_POS", "C0_CONTROL", 1.0e-4, 1.0e-6, 5.0e-6),
)
SCALES_M = (
    2.5e-7, 1.25e-7, 6.25e-8, 3.125e-8, 1.5625e-8,
    7.8125e-9, 3.90625e-9, 1.953125e-9, 9.765625e-10,
)
MULTIPLIERS = (-2, -1, 0, 1, 2)
SIG_FIELDS = (
    "accepted_substeps", "attempts", "retries", "solver_rejections",
    "temporal_rejections", "internal_retries",
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def load_prereg() -> None:
    p = json.loads(PREREG.read_text())
    require(p["work_unit"] == "GC-FIXED-INTERFACE-G09C", "wrong G09C preregistration")
    require(p["status"] == "PREREGISTERED_BEFORE_EXECUTION", "G09C preregistration not frozen")
    frozen = tuple(
        (
            str(x["id"]), str(x["case_id"]), float(x["duration_day"]),
            float(x["predictor_qbot_cm_per_day"]), float(x["dh_m"]),
        )
        for x in p["frozen_states"]
    )
    require(frozen == STATES, "G09C frozen states drifted")
    require(tuple(float(x) for x in p["scale_ladder_m"]) == SCALES_M, "G09C scale ladder drifted")


def raw_ready(raw: dict[str, object]) -> bool:
    return (
        int(raw["result_status"]) == 0
        and bool(raw["completed"])
        and bool(raw["candidate_ready"])
    )


def integer_signature(raw: dict[str, object]) -> tuple[int, ...] | None:
    if not raw_ready(raw):
        return None
    return tuple(int(raw[k]) for k in SIG_FIELDS)


def partition_signature(raw: dict[str, object]) -> tuple[int, float, float] | None:
    if not raw_ready(raw):
        return None
    return (
        int(raw["accepted_substeps"]),
        float(raw["min_substep"]),
        float(raw["max_substep"]),
    )


def sample_head(
    swap: Fgc44RealSwap,
    origin: tuple[int, float, int, float],
    head: float,
) -> dict[str, object]:
    status, q = trial_discard(swap, origin, head)
    raw = swap.raw_corrector_diagnostics(head)
    require(swap.state() == origin, "G09C raw diagnostic mutated accepted authority")
    return {
        "head_m": head,
        "participant_status": int(status),
        "q_swap_m_per_s": float(q) if status == 0 else None,
        "raw": raw,
        "raw_ready": raw_ready(raw),
        "integer_signature": list(integer_signature(raw)) if integer_signature(raw) is not None else None,
        "partition_signature": list(partition_signature(raw)) if partition_signature(raw) is not None else None,
    }


def slopes(samples: dict[int, dict[str, object]], d: float) -> dict[str, object]:
    q0 = samples[0]["q_swap_m_per_s"]
    require(q0 is not None, "G09C center unexpectedly inadmissible")
    qm2 = samples[-2]["q_swap_m_per_s"]
    qm1 = samples[-1]["q_swap_m_per_s"]
    qp1 = samples[1]["q_swap_m_per_s"]
    qp2 = samples[2]["q_swap_m_per_s"]
    out: dict[str, object] = {
        "central_per_s": None,
        "backward_second_order_per_s": None,
        "forward_second_order_per_s": None,
        "least_squares_per_s": None,
        "least_squares_max_error_m_per_s": None,
        "least_squares_point_count": 0,
    }
    if qm1 is not None and qp1 is not None:
        out["central_per_s"] = (float(qp1) - float(qm1)) / (2.0 * d)
    if qm1 is not None and qm2 is not None:
        out["backward_second_order_per_s"] = (
            3.0 * float(q0) - 4.0 * float(qm1) + float(qm2)
        ) / (2.0 * d)
    if qp1 is not None and qp2 is not None:
        out["forward_second_order_per_s"] = (
            -3.0 * float(q0) + 4.0 * float(qp1) - float(qp2)
        ) / (2.0 * d)
    pts = []
    for m in MULTIPLIERS:
        q = samples[m]["q_swap_m_per_s"]
        if q is not None:
            pts.append((m * d, float(q)))
    out["least_squares_point_count"] = len(pts)
    if len(pts) >= 3:
        x = np.asarray([p[0] for p in pts], dtype=float)
        y = np.asarray([p[1] for p in pts], dtype=float)
        slope, intercept = np.polyfit(x, y, 1)
        out["least_squares_per_s"] = float(slope)
        out["least_squares_max_error_m_per_s"] = float(np.max(np.abs(slope * x + intercept - y)))
    return out


def equality_against_center(
    sample: dict[str, object],
    center: dict[str, object],
) -> dict[str, object]:
    sr = sample["raw"]
    cr = center["raw"]
    integer_fields = {
        k: (
            raw_ready(sr) and raw_ready(cr)
            and int(sr[k]) == int(cr[k])
        )
        for k in SIG_FIELDS
    }
    return {
        "participant_admissible": int(sample["participant_status"]) == 0,
        "raw_ready": bool(sample["raw_ready"]),
        "all_integer_signature_equal": (
            sample["integer_signature"] is not None
            and center["integer_signature"] is not None
            and sample["integer_signature"] == center["integer_signature"]
        ),
        "all_partition_signature_equal": (
            sample["partition_signature"] is not None
            and center["partition_signature"] is not None
            and sample["partition_signature"] == center["partition_signature"]
        ),
        "integer_field_equal": integer_fields,
        "min_substep_equal": (
            raw_ready(sr) and raw_ready(cr)
            and float(sr["min_substep"]) == float(cr["min_substep"])
        ),
        "max_substep_equal": (
            raw_ready(sr) and raw_ready(cr)
            and float(sr["max_substep"]) == float(cr["max_substep"])
        ),
    }


def stable_plateaus(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    # Diagnostic only: identify adjacent finite slope pairs whose relative
    # difference is <=5%. No point is removed and this result is not an estimator.
    keys = (
        "central_per_s", "backward_second_order_per_s",
        "forward_second_order_per_s", "least_squares_per_s",
    )
    out = []
    for key in keys:
        seq = [(float(r["scale_m"]), r["derived"][key]) for r in rows if r["derived"][key] is not None]
        for (d0, s0), (d1, s1) in zip(seq[:-1], seq[1:]):
            s0f, s1f = float(s0), float(s1)
            rel = abs(s0f - s1f) / max(abs(s0f), abs(s1f))
            if rel <= 0.05:
                out.append({
                    "metric": key,
                    "coarser_scale_m": d0,
                    "finer_scale_m": d1,
                    "coarser_slope_per_s": s0f,
                    "finer_slope_per_s": s1f,
                    "relative_difference": rel,
                })
    return out


def main() -> None:
    load_prereg()
    swaplib = Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(swaplib.is_file(), "missing real SWAP bridge library")
    swap = Fgc44RealSwap(swaplib)

    state_results = []
    for state_id, case_id, duration, qbot, dh0 in STATES:
        _, _, href, origin, _ = initialize_case(swap, duration, qbot)
        h0 = href + dh0
        center = sample_head(swap, origin, h0)
        require(
            int(center["participant_status"]) == 0 and bool(center["raw_ready"]),
            f"G09C center unavailable {state_id}",
        )
        cache: dict[str, dict[str, object]] = {h0.hex(): center}
        rows = []

        def cached(head: float) -> dict[str, object]:
            key = head.hex()
            if key not in cache:
                cache[key] = sample_head(swap, origin, head)
            return cache[key]

        for d in SCALES_M:
            samples = {m: cached(h0 + m * d) for m in MULTIPLIERS}
            eq = {
                str(m): equality_against_center(samples[m], center)
                for m in MULTIPLIERS
            }
            row = {
                "state_id": state_id,
                "case_id": case_id,
                "scale_m": d,
                "samples": {str(m): samples[m] for m in MULTIPLIERS},
                "equality_to_center": eq,
                "derived": slopes(samples, d),
            }
            rows.append(row)
            print("FGC44_G09C_SCALE_JSON=" + json.dumps(row, sort_keys=True, separators=(",", ":")))

        result = {
            "state_id": state_id,
            "case_id": case_id,
            "duration_day": duration,
            "qbot_cm_per_day": qbot,
            "href_m": href,
            "center_head_m": h0,
            "center_dh_m": dh0,
            "center_integer_signature": center["integer_signature"],
            "center_partition_signature": center["partition_signature"],
            "unique_sample_count": len(cache),
            "participant_failure_count": sum(
                int(s["participant_status"]) != 0 for s in cache.values()
            ),
            "raw_ready_count": sum(bool(s["raw_ready"]) for s in cache.values()),
            "exact_integer_signature_match_count": sum(
                s["integer_signature"] == center["integer_signature"]
                for s in cache.values()
                if s["integer_signature"] is not None
            ),
            "exact_partition_signature_match_count": sum(
                s["partition_signature"] == center["partition_signature"]
                for s in cache.values()
                if s["partition_signature"] is not None
            ),
            "stable_adjacent_slope_pairs": stable_plateaus(rows),
            "rows": rows,
        }
        state_results.append(result)
        print("FGC44_G09C_STATE_JSON=" + json.dumps(result, sort_keys=True, separators=(",", ":")))
        require(swap.state() == origin, f"G09C state {state_id} mutated accepted authority")

    require(len(state_results) == 2, "G09C state matrix incomplete")
    summary = {
        "target": {
            "participant_failure_count": state_results[0]["participant_failure_count"],
            "raw_ready_count": state_results[0]["raw_ready_count"],
            "exact_integer_signature_match_count": state_results[0]["exact_integer_signature_match_count"],
            "exact_partition_signature_match_count": state_results[0]["exact_partition_signature_match_count"],
            "stable_adjacent_slope_pair_count": len(state_results[0]["stable_adjacent_slope_pairs"]),
        },
        "control": {
            "participant_failure_count": state_results[1]["participant_failure_count"],
            "raw_ready_count": state_results[1]["raw_ready_count"],
            "exact_integer_signature_match_count": state_results[1]["exact_integer_signature_match_count"],
            "exact_partition_signature_match_count": state_results[1]["exact_partition_signature_match_count"],
            "stable_adjacent_slope_pair_count": len(state_results[1]["stable_adjacent_slope_pairs"]),
        },
    }
    print("FGC44_G09C_SUMMARY_JSON=" + json.dumps(summary, sort_keys=True, separators=(",", ":")))
    print("FGC44_G09C_TRANSACTION_AUTHORITY=PASS")
    print("GC_FIXED_INTERFACE_G09C_DIAGNOSTIC=PASS")


if __name__ == "__main__":
    main()
