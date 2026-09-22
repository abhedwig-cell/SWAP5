from __future__ import annotations

import json
import math
from fractions import Fraction
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PREREG = ROOT / "integration" / "research" / "GC_FIXED_INTERFACE_G13_PREREGISTRATION.json"
G09D = ROOT / "integration" / "research" / "GC_FIXED_INTERFACE_G09D_RESULT.json"
G12B = ROOT / "integration" / "research" / "GC_FIXED_INTERFACE_G12B_RESULT.json"
G11 = ROOT / "integration" / "research" / "GC_FIXED_INTERFACE_G11_RESULT.json"

REL_TOL = 0.05


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def rel_diff(a: float, b: float) -> float:
    return abs(a - b) / max(abs(a), abs(b))


def first_streaming_pair(e3: dict[str, object]) -> tuple[int, dict[str, object], dict[str, object], float] | None:
    candidates = list(e3["candidates"])
    for i in range(1, len(candidates)):
        coarse = candidates[i - 1]
        fine = candidates[i]
        if coarse.get("classification") != "CANDIDATE" or fine.get("classification") != "CANDIDATE":
            continue
        s0 = float(coarse["slope_per_s"])
        s1 = float(fine["slope_per_s"])
        if not (math.isfinite(s0) and math.isfinite(s1) and s0 < 0.0 and s1 < 0.0):
            continue
        rel = rel_diff(s0, s1)
        if rel <= REL_TOL:
            return i, coarse, fine, rel
    return None


def unique_relative_heads(scales: list[float]) -> int:
    offsets = {Fraction(0, 1)}
    for scale in scales:
        d = Fraction(str(scale))
        for m in (-2, -1, 1, 2):
            offsets.add(m * d)
    return len(offsets)


def qualify_row(carrier: str, state_id: str, e3: dict[str, object]) -> dict[str, object]:
    persisted_available = str(e3["classification"]) == "AVAILABLE"
    pair = first_streaming_pair(e3)
    streaming_available = pair is not None
    require(
        persisted_available == streaming_available,
        f"G13 availability mismatch {carrier}/{state_id}",
    )

    scales = [float(x["scale_m"]) for x in e3["candidates"]]
    full_unique_heads = unique_relative_heads(scales)
    full_current_runs = 2 * full_unique_heads

    if pair is None:
        return {
            "carrier": carrier,
            "state_id": state_id,
            "classification": "TANGENT_UNAVAILABLE",
            "full_scale_count": len(scales),
            "full_unique_heads": full_unique_heads,
            "full_current_corrector_runs": full_current_runs,
        }

    i, coarse, fine, rel = pair
    streaming_scales = scales[: i + 1]
    streaming_unique_heads = unique_relative_heads(streaming_scales)
    streaming_current_runs = 2 * streaming_unique_heads
    fused_lower_bound_runs = streaming_unique_heads

    expected = {
        "selected_scale": float(e3["selected_d_m"]),
        "selected_mode": str(e3["mode"]),
        "selected_slope": float(e3["slope_per_s"]),
        "confirming_scale": float(e3["confirming_d_m"]),
        "confirming_mode": str(e3["confirming_mode"]),
        "confirming_slope": float(e3["confirming_slope_per_s"]),
    }
    observed = {
        "selected_scale": float(coarse["scale_m"]),
        "selected_mode": str(coarse["mode"]),
        "selected_slope": float(coarse["slope_per_s"]),
        "confirming_scale": float(fine["scale_m"]),
        "confirming_mode": str(fine["mode"]),
        "confirming_slope": float(fine["slope_per_s"]),
    }

    require(observed["selected_scale"] == expected["selected_scale"], f"G13 selected scale mismatch {carrier}/{state_id}")
    require(observed["selected_mode"] == expected["selected_mode"], f"G13 selected mode mismatch {carrier}/{state_id}")
    require(math.isclose(observed["selected_slope"], expected["selected_slope"], rel_tol=0.0, abs_tol=1e-18),
            f"G13 selected slope mismatch {carrier}/{state_id}")
    require(observed["confirming_scale"] == expected["confirming_scale"], f"G13 confirming scale mismatch {carrier}/{state_id}")
    require(observed["confirming_mode"] == expected["confirming_mode"], f"G13 confirming mode mismatch {carrier}/{state_id}")
    require(math.isclose(observed["confirming_slope"], expected["confirming_slope"], rel_tol=0.0, abs_tol=1e-18),
            f"G13 confirming slope mismatch {carrier}/{state_id}")
    require(i + 1 < len(scales), f"G13 streaming did not stop before the full ladder {carrier}/{state_id}")

    return {
        "carrier": carrier,
        "state_id": state_id,
        "classification": "AVAILABLE",
        "full_scale_count": len(scales),
        "streaming_scale_count": i + 1,
        "selected_scale_m": observed["selected_scale"],
        "selected_mode": observed["selected_mode"],
        "selected_slope_per_s": observed["selected_slope"],
        "confirming_scale_m": observed["confirming_scale"],
        "confirming_mode": observed["confirming_mode"],
        "confirming_slope_per_s": observed["confirming_slope"],
        "relative_difference": rel,
        "full_unique_heads": full_unique_heads,
        "streaming_unique_heads": streaming_unique_heads,
        "full_current_corrector_runs": full_current_runs,
        "streaming_current_corrector_runs": streaming_current_runs,
        "fused_trial_lower_bound_runs": fused_lower_bound_runs,
        "current_streaming_saved_runs": full_current_runs - streaming_current_runs,
        "fused_lower_bound_saved_runs": full_current_runs - fused_lower_bound_runs,
    }


def main() -> None:
    prereg = json.loads(PREREG.read_text())
    g09d = json.loads(G09D.read_text())
    g12b = json.loads(G12B.read_text())
    g11 = json.loads(G11.read_text())

    require(prereg["work_unit"] == "GC-FIXED-INTERFACE-G13", "wrong G13 preregistration")
    require(prereg["status"] == "PREREGISTERED_BEFORE_EXECUTION", "G13 preregistration not frozen")
    require(g09d["work_unit"] == "GC-FIXED-INTERFACE-G09D" and g09d["workflow_conclusion"] == "success",
            "G09D authority unavailable")
    require(g12b["work_unit"] == "GC-FIXED-INTERFACE-G12B" and g12b["workflow_conclusion"] == "success",
            "G12B authority unavailable")
    require(g11["work_unit"] == "GC-FIXED-INTERFACE-G11" and g11["workflow_conclusion"] == "success",
            "G11 authority unavailable")

    rows: list[dict[str, object]] = []
    for item in g09d["estimator_results"]:
        rows.append(
            qualify_row(
                "FGC44",
                f"{item['case_id']}_{item['side']}",
                item["e3"],
            )
        )
    for item in g12b["estimator_results"]:
        rows.append(qualify_row("MAP09", str(item["label"]), item["e3"]))

    require(len(rows) == 11, f"G13 frozen state matrix drifted: {len(rows)}")
    require(all(x["classification"] == "AVAILABLE" for x in rows), "G13 lost persisted E3 availability")

    total_full_heads = sum(int(x["full_unique_heads"]) for x in rows)
    total_stream_heads = sum(int(x["streaming_unique_heads"]) for x in rows)
    total_full_runs = sum(int(x["full_current_corrector_runs"]) for x in rows)
    total_stream_runs = sum(int(x["streaming_current_corrector_runs"]) for x in rows)
    total_fused_runs = sum(int(x["fused_trial_lower_bound_runs"]) for x in rows)

    require(total_full_runs == 2 * total_full_heads, "G13 full-ladder cost contract mismatch")
    require(total_stream_runs == 2 * total_stream_heads, "G13 streaming cost contract mismatch")
    require(total_fused_runs == total_stream_heads, "G13 fused lower-bound contract mismatch")
    require(total_stream_runs < total_full_runs, "G13 streaming did not reduce logical corrector work")

    g11_contractions = int(g11["summary"]["p4_contractions"])
    require(g11_contractions == 2, "G13 contextual G11 safeguard cost drifted")

    summary = {
        "state_count": len(rows),
        "fgc44_state_count": sum(x["carrier"] == "FGC44" for x in rows),
        "map09_state_count": sum(x["carrier"] == "MAP09" for x in rows),
        "full_unique_heads": total_full_heads,
        "streaming_unique_heads": total_stream_heads,
        "full_current_corrector_runs": total_full_runs,
        "streaming_current_corrector_runs": total_stream_runs,
        "fused_trial_lower_bound_runs": total_fused_runs,
        "streaming_run_reduction_fraction": 1.0 - total_stream_runs / total_full_runs,
        "fused_lower_bound_reduction_fraction": 1.0 - total_fused_runs / total_full_runs,
        "fused_vs_streaming_reduction_fraction": 1.0 - total_fused_runs / total_stream_runs,
        "g11_p4_safeguard_contractions": g11_contractions,
    }

    for row in rows:
        print("FGC44_G13_STATE_JSON=" + json.dumps(row, sort_keys=True, separators=(",", ":")))
    print("FGC44_G13_SUMMARY_JSON=" + json.dumps(summary, sort_keys=True, separators=(",", ":")))
    print("GC_FIXED_INTERFACE_G13_STREAMING_EQUIVALENCE=PASS")
    print("GC_FIXED_INTERFACE_G13_LOGICAL_COST=PASS")
    print("GC_FIXED_INTERFACE_G13_EXECUTION=PASS")


if __name__ == "__main__":
    main()
