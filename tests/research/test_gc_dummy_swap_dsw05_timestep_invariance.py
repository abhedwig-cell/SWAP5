from __future__ import annotations

import math
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "research"))

from test_gc_dummy_swap_dsw01_live_modflow import run_case, require


H0 = 8.0
S_SWAP = 0.10
S_MF = 0.10
S_TOTAL = S_SWAP + S_MF
RECHARGE = 0.010
EXPECTED = 8.05
TOL = 1.0e-10

SCHEDULES = (
    (1.0,),
    (0.5, 0.5),
    (0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1),
    (0.07, 0.13, 0.20, 0.15, 0.45),
)


def run_schedule(libmf6: Path, index: int, schedule: tuple[float, ...]) -> float:
    require(
        math.isclose(sum(schedule), 1.0, rel_tol=0.0, abs_tol=1.0e-14),
        f"schedule {index} does not total one day",
    )

    head = H0
    total_input = 0.0
    for step, dt in enumerate(schedule, start=1):
        hcof = -S_SWAP / dt
        rhs = hcof * head - RECHARGE
        before = head

        result = run_case(
            libmf6,
            f"dt_schedule_{index}_step_{step}",
            hcof_m2_per_day=hcof,
            rhs_m3_per_day=rhs,
            sy=S_MF,
            newton=False,
            initial_head_m=before,
            dt_day=dt,
        )
        require(
            bool(result["converged"]),
            f"schedule {index} step {step} did not converge: {result}",
        )
        head = float(result["head_m"])
        expected_step = before + RECHARGE * dt / S_TOTAL
        require(
            math.isclose(head, expected_step, rel_tol=0.0, abs_tol=TOL),
            f"schedule {index} step {step}: {head} != {expected_step}",
        )
        require(
            math.isclose(
                float(result["model_dt_day"]),
                dt,
                rel_tol=0.0,
                abs_tol=1.0e-14,
            ),
            f"MODFLOW timestep mismatch schedule {index} step {step}",
        )
        total_input += RECHARGE * dt
        storage_change = S_TOTAL * (head - before)
        require(
            math.isclose(
                storage_change,
                RECHARGE * dt,
                rel_tol=0.0,
                abs_tol=1.0e-12,
            ),
            f"substep mass mismatch schedule {index} step {step}",
        )
        print(
            f"GC_DSW05_SCHEDULE_{index}_STEP_{step}_DT_DAY={dt:.17g} "
            f"HEAD_M={head:.17g}"
        )

    require(
        math.isclose(
            S_TOTAL * (head - H0),
            total_input,
            rel_tol=0.0,
            abs_tol=1.0e-12,
        ),
        f"schedule {index} total mass mismatch",
    )
    print(f"GC_DSW05_SCHEDULE_{index}_FINAL_HEAD_M={head:.17g}")
    return head


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")

    final_heads = [
        run_schedule(libmf6, index, schedule)
        for index, schedule in enumerate(SCHEDULES, start=1)
    ]
    for index, head in enumerate(final_heads, start=1):
        require(
            math.isclose(head, EXPECTED, rel_tol=0.0, abs_tol=TOL),
            f"schedule {index} final head {head} != {EXPECTED}",
        )

    spread = max(final_heads) - min(final_heads)
    print(f"GC_DSW05_FINAL_HEAD_SPREAD_M={spread:.17g}")
    require(spread <= TOL, f"timestep schedule changed solution: {final_heads}")

    print("GC_DSW05_SUBSTEP_MASS=PASS")
    print("GC_DSW05_TIMESTEP_INVARIANCE=PASS")
    print("GC_DSW05_LIVE_GATE=PASS")


if __name__ == "__main__":
    main()
