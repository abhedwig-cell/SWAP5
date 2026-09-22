from __future__ import annotations

import argparse
import ctypes
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
CENTER_Q_M_PER_S = -1.2492277961483046e-11
EXACT_FAILED_HEAD_M = -0.71499625613852269
EXACT_FAILED_OFFSET_PM = 2.721711744868128

GRID_OFFSETS_PM = (
    -8.0, -6.0, -4.0, -3.0, -2.0, -1.5, -1.0, -0.5,
    0.0, 0.5, 1.0, 1.5, 2.0, 2.5, EXACT_FAILED_OFFSET_PM,
    3.0, 3.5, 4.0, 5.0, 6.0, 8.0, 10.0,
)
REPEAT_OFFSETS_PM = (0.0, 2.5, EXACT_FAILED_OFFSET_PM, 3.0, 4.0)


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def one_probe(offset_pm: float) -> dict[str, object]:
    swaplib = Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(swaplib.is_file(), "missing F-GC44 bridge")

    swap = Fgc44RealSwap(swaplib)
    hcof, rhs, href = swap.initialize_configured(
        WINDOW_DAY, PREDICTOR_QBOT_CM_PER_DAY
    )
    origin = swap.state()
    require(origin == (0, 0.0, 0, 0.0), f"dirty origin: {origin}")

    head = CENTER_HEAD_M + float(offset_pm) * 1.0e-12
    q = ctypes.c_double()
    status = int(
        swap.lib.fgc44_swap_trial_c(
            float(head), ctypes.byref(q)
        )
    )
    state_after_trial = swap.state()
    require(
        state_after_trial == origin,
        f"probe {offset_pm} pm mutated authoritative state: {state_after_trial}",
    )

    q_value: float | None = None
    if status == 0:
        q_value = float(q.value)
        require(math.isfinite(q_value), f"nonfinite q at {offset_pm} pm")
        swap.discard()
        require(
            swap.state() == origin,
            f"discard after {offset_pm} pm changed authoritative state",
        )

    return {
        "offset_pm": float(offset_pm),
        "head_m": float(head),
        "status": status,
        "q_swap_m_per_s": q_value,
        "href_m": float(href),
        "hcof_m2_per_day": float(hcof),
        "rhs_m3_per_day": float(rhs),
    }


def child_main(offset_pm: float, result_path: Path) -> None:
    result = one_probe(offset_pm)
    result_path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(
        f"GC_MAP06_CHILD_OFFSET_PM={offset_pm:.17g} "
        f"HEAD_M={float(result['head_m']):.17g} "
        f"STATUS={int(result['status'])} "
        f"Q={result['q_swap_m_per_s']}"
    )


def run_fresh(offset_pm: float, workdir: Path, tag: str) -> dict[str, object]:
    result_path = workdir / f"{tag}.json"
    child = subprocess.run(
        [
            sys.executable,
            str(Path(__file__).resolve()),
            "--offset-pm",
            f"{offset_pm:.17g}",
            "--result",
            str(result_path),
        ],
        check=False,
        text=True,
        capture_output=True,
        env=os.environ.copy(),
    )
    if child.stdout:
        print(child.stdout, end="")
    if child.stderr:
        print(child.stderr, end="", file=sys.stderr)
    require(child.returncode == 0, f"probe {offset_pm} pm child failed: {child.returncode}")
    return json.loads(result_path.read_text(encoding="utf-8"))


def parent_main() -> None:
    with tempfile.TemporaryDirectory(prefix="gc-map06-") as tmp:
        workdir = Path(tmp)
        samples: list[dict[str, object]] = []
        for index, offset in enumerate(GRID_OFFSETS_PM, start=1):
            sample = run_fresh(offset, workdir, f"grid-{index}")
            samples.append(sample)
            print(
                f"GC_MAP06_GRID_OFFSET_PM={offset:.17g} "
                f"HEAD_M={float(sample['head_m']):.17g} "
                f"STATUS={int(sample['status'])} "
                f"Q={sample['q_swap_m_per_s']}"
            )

        repeated: dict[str, list[dict[str, object]]] = {}
        for offset in REPEAT_OFFSETS_PM:
            pair = [
                run_fresh(offset, workdir, f"repeat-{offset:.17g}-{rep}")
                for rep in (1, 2)
            ]
            repeated[f"{offset:.17g}"] = pair
            require(
                int(pair[0]["status"]) == int(pair[1]["status"]),
                f"nondeterministic status at {offset} pm: {pair}",
            )
            if int(pair[0]["status"]) == 0:
                q0 = float(pair[0]["q_swap_m_per_s"])
                q1 = float(pair[1]["q_swap_m_per_s"])
                require(
                    math.isclose(q0, q1, rel_tol=0.0, abs_tol=1.0e-18),
                    f"nondeterministic q at {offset} pm: {q0} {q1}",
                )

    by_offset = {float(s["offset_pm"]): s for s in samples}
    center = by_offset[0.0]
    exact_failed = by_offset[EXACT_FAILED_OFFSET_PM]

    require(int(center["status"]) == 0, f"accepted CURRENT_PLUS_U head no longer valid: {center}")
    require(
        math.isclose(
            float(center["q_swap_m_per_s"]),
            CENTER_Q_M_PER_S,
            rel_tol=0.0,
            abs_tol=1.0e-18,
        ),
        f"center q drift: {center}",
    )
    require(
        math.isclose(
            float(exact_failed["head_m"]),
            EXACT_FAILED_HEAD_M,
            rel_tol=0.0,
            abs_tol=2.0e-16,
        ),
        f"exact MAP05 failed head not reproduced: {exact_failed}",
    )
    require(
        int(exact_failed["status"]) == 6,
        f"MAP05 failed head did not reproduce status 6: {exact_failed}",
    )

    valid = [s for s in samples if int(s["status"]) == 0]
    invalid = [s for s in samples if int(s["status"]) != 0]
    require(valid, "fixed grid contains no admissible sample")
    require(invalid, "fixed grid contains no inadmissible sample")

    valid_offsets = [float(s["offset_pm"]) for s in valid]
    invalid_offsets = [float(s["offset_pm"]) for s in invalid]
    nearest_invalid_pm = min(abs(x) for x in invalid_offsets)

    statuses = [int(s["status"]) == 0 for s in samples]
    transitions = sum(a != b for a, b in zip(statuses[:-1], statuses[1:], strict=True))

    print("GC_MAP06_VALID_OFFSETS_PM=" + ",".join(f"{x:.17g}" for x in valid_offsets))
    print("GC_MAP06_INVALID_OFFSETS_PM=" + ",".join(f"{x:.17g}" for x in invalid_offsets))
    print(f"GC_MAP06_NEAREST_INVALID_DISTANCE_PM={nearest_invalid_pm:.17g}")
    print(f"GC_MAP06_VALIDITY_TRANSITIONS={transitions}")
    print("GC_MAP06_CENTER_ADMISSIBLE=PASS")
    print("GC_MAP06_MAP05_FAILED_HEAD_REPRODUCED=PASS")
    print("GC_MAP06_MIXED_VALIDITY_GRID=PASS")
    print("GC_MAP06_REPEAT_STATUS_DETERMINISM=PASS")
    print("GC_MAP06_LIVE_GATE=PASS")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--offset-pm", type=float)
    parser.add_argument("--result", type=Path)
    args = parser.parse_args()

    if args.offset_pm is None:
        require(args.result is None, "--result requires --offset-pm")
        parent_main()
    else:
        require(args.result is not None, "--offset-pm requires --result")
        child_main(float(args.offset_pm), args.result)


if __name__ == "__main__":
    main()
