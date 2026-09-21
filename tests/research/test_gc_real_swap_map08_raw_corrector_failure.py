from __future__ import annotations

import argparse
import json
import math
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "fgc" / "support"))

from fgc44_real_swap_ctypes import Fgc44RealSwap


WINDOW_DAY = 1.0e-3
PREDICTOR_QBOT_CM_PER_DAY = 1.0e-4
CENTER_HEAD_M = -0.7149962561412444

OFFSETS_PM = (-4.0, -3.0, -0.5, 0.0, 2.0, 2.5, 2.721711744868128, 3.0)
EXPECTED_PARTICIPANT_STATUS = {
    -4.0: 6,
    -3.0: 0,
    -0.5: 6,
    0.0: 0,
    2.0: 0,
    2.5: 6,
    2.721711744868128: 6,
    3.0: 0,
}

ACCEPTANCE_KEYS = (
    "completed",
    "candidate_ready",
    "bottom_available",
    "bottom_finite",
    "terminal_finite",
    "requested_match",
    "completed_match",
    "interval_match",
)

REJECTION_KEYS = (
    "solver_rejections",
    "temporal_rejections",
    "temporal_unavailable_rejections",
    "mass_rejections",
    "internal_retries",
)


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def child_probe(mode: str, offset_pm: float, result_path: Path) -> None:
    lib = Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(lib.is_file(), "missing F-GC44 bridge")
    swap = Fgc44RealSwap(lib)
    swap.initialize_configured(WINDOW_DAY, PREDICTOR_QBOT_CM_PER_DAY)
    origin = swap.state()
    head = CENTER_HEAD_M + float(offset_pm) * 1.0e-12

    if mode == "participant":
        status, q = swap.try_trial(head)
        if status == 0:
            require(math.isfinite(q), "nonfinite participant q")
            swap.discard()
        final_state = swap.state()
        require(final_state == origin, f"participant probe mutated state: {origin} -> {final_state}")
        result = {
            "mode": mode,
            "offset_pm": float(offset_pm),
            "head_m": float(head),
            "participant_status": int(status),
            "q_swap_m_per_s": float(q) if status == 0 else None,
            "origin_state": list(origin),
            "final_state": list(final_state),
        }
    elif mode == "raw":
        diag = swap.raw_corrector_diagnostics(head)
        final_state = swap.state()
        require(final_state == origin, f"raw probe mutated state: {origin} -> {final_state}")
        result = {
            "mode": mode,
            "offset_pm": float(offset_pm),
            "head_m": float(head),
            **diag,
            "origin_state": list(origin),
            "final_state": list(final_state),
        }
    else:
        raise AssertionError(f"unknown mode {mode}")

    result_path.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("GC_MAP08_CHILD=" + json.dumps(result, sort_keys=True, separators=(",", ":")))


def run_child(mode: str, offset_pm: float, workdir: Path, index: int) -> dict:
    path = workdir / f"{mode}-{index}.json"
    proc = subprocess.run(
        [
            sys.executable,
            str(Path(__file__).resolve()),
            "--mode",
            mode,
            "--offset-pm",
            f"{offset_pm:.17g}",
            "--result",
            str(path),
        ],
        check=False,
        text=True,
        capture_output=True,
        env=os.environ.copy(),
    )
    if proc.stdout:
        print(proc.stdout, end="")
    if proc.stderr:
        print(proc.stderr, end="", file=sys.stderr)
    require(proc.returncode == 0, f"{mode} probe {offset_pm} pm child failed: {proc.returncode}")
    return json.loads(path.read_text(encoding="utf-8"))


def parent_main() -> None:
    rows: list[dict] = []
    with tempfile.TemporaryDirectory(prefix="gc-map08-") as tmp:
        workdir = Path(tmp)
        for index, offset in enumerate(OFFSETS_PM, start=1):
            participant = run_child("participant", offset, workdir, 2 * index - 1)
            raw = run_child("raw", offset, workdir, 2 * index)

            expected = EXPECTED_PARTICIPANT_STATUS[offset]
            require(
                int(participant["participant_status"]) == expected,
                f"MAP06 participant status drift at {offset} pm: {participant}",
            )

            failed_predicates = [
                key for key in ACCEPTANCE_KEYS if not bool(raw[key])
            ]
            nonzero_rejections = {
                key: int(raw[key])
                for key in REJECTION_KEYS
                if int(raw[key]) != 0
            }

            row = {
                "offset_pm": offset,
                "head_m": float(participant["head_m"]),
                "participant_status": int(participant["participant_status"]),
                "raw_result_status": int(raw["result_status"]),
                "failed_predicates": failed_predicates,
                "nonzero_rejections": nonzero_rejections,
                "transaction_calls": int(raw["transaction_calls"]),
                "accepted_substeps": int(raw["accepted_substeps"]),
                "attempts": int(raw["attempts"]),
                "retries": int(raw["retries"]),
                "trial_rollbacks": int(raw["trial_rollbacks"]),
                "solver_rejections": int(raw["solver_rejections"]),
                "temporal_rejections": int(raw["temporal_rejections"]),
                "temporal_unavailable_rejections": int(raw["temporal_unavailable_rejections"]),
                "mass_rejections": int(raw["mass_rejections"]),
                "internal_retries": int(raw["internal_retries"]),
                "min_substep": float(raw["min_substep"]),
                "max_substep": float(raw["max_substep"]),
                "completed_t": float(raw["completed_t"]),
                "candidate_t0": float(raw["candidate_t0"]),
                "candidate_t1": float(raw["candidate_t1"]),
            }
            rows.append(row)
            print("GC_MAP08_ROW=" + json.dumps(row, sort_keys=True, separators=(",", ":")))

            if expected == 0:
                require(
                    not failed_predicates,
                    f"valid participant point failed raw acceptance predicates at {offset}: {row}",
                )
            else:
                require(
                    bool(failed_predicates) or bool(nonzero_rejections) or int(raw["result_status"]) != 0,
                    f"invalid participant point has no raw failure signature at {offset}: {row}",
                )

    valid_rows = [r for r in rows if r["participant_status"] == 0]
    invalid_rows = [r for r in rows if r["participant_status"] != 0]
    require(len(valid_rows) == 4 and len(invalid_rows) == 4, "fixed valid/invalid control count drift")

    classifications = {}
    for row in invalid_rows:
        key = f"{row['offset_pm']:.17g}"
        classifications[key] = {
            "raw_result_status": row["raw_result_status"],
            "failed_predicates": row["failed_predicates"],
            "nonzero_rejections": row["nonzero_rejections"],
        }

    print("GC_MAP08_INVALID_CLASSIFICATIONS=" + json.dumps(classifications, sort_keys=True, separators=(",", ":")))
    print("GC_MAP08_MAP06_PARTICIPANT_STATUS_REPRODUCED=PASS")
    print("GC_MAP08_VALID_RAW_ACCEPTANCE=PASS")
    print("GC_MAP08_INVALID_RAW_FAILURE_IDENTIFIED=PASS")
    print("GC_MAP08_ZERO_COMMITTED_STATE_MUTATION=PASS")
    print("GC_MAP08_LIVE_GATE=PASS")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("participant", "raw"))
    parser.add_argument("--offset-pm", type=float)
    parser.add_argument("--result", type=Path)
    args = parser.parse_args()

    if args.mode is None:
        require(args.offset_pm is None and args.result is None, "child arguments incomplete")
        parent_main()
    else:
        require(args.offset_pm is not None and args.result is not None, "child arguments incomplete")
        child_probe(args.mode, float(args.offset_pm), args.result)


if __name__ == "__main__":
    main()
