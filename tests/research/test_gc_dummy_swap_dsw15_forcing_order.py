from __future__ import annotations

import math
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "research"))

from test_gc_dummy_swap_dsw01_live_modflow import run_case, require


H0 = 8.0
S = 0.20
K = 1.0
DT = 0.5
TOL = 1.0e-10
HISTORIES = {
    "early": (0.020, 0.0),
    "late": (0.0, 0.020),
}


def run_memoryless(libmf6: Path, name: str, inputs: tuple[float, float]) -> float:
    head = H0
    for step, volume in enumerate(inputs, start=1):
        rate = volume / DT
        result = run_case(
            libmf6,
            f"memoryless_{name}_{step}",
            hcof_m2_per_day=0.0,
            rhs_m3_per_day=-rate,
            sy=S,
            newton=False,
            initial_head_m=head,
            dt_day=DT,
        )
        require(bool(result["converged"]), f"memoryless {name} step {step}: {result}")
        head = float(result["head_m"])
    print(f"GC_DSW15_MEMORYLESS_{name.upper()}_HEAD_M={head:.17g}")
    return head


def run_memory(libmf6: Path, name: str, inputs: tuple[float, float]) -> tuple[float, float]:
    head = H0
    w = 0.0
    for step, volume in enumerate(inputs, start=1):
        w_new = (w + volume) / (1.0 + K * DT)
        transfer = K * DT * w_new
        rate = transfer / DT

        result = run_case(
            libmf6,
            f"memory_{name}_{step}",
            hcof_m2_per_day=0.0,
            rhs_m3_per_day=-rate,
            sy=S,
            newton=False,
            initial_head_m=head,
            dt_day=DT,
        )
        require(bool(result["converged"]), f"memory {name} step {step}: {result}")
        new_head = float(result["head_m"])
        storage_gain = S * (new_head - head)
        print(
            f"GC_DSW15_MEMORY_{name.upper()}_STEP_{step}_"
            f"HEAD_BEFORE_M={head:.17g} HEAD_AFTER_M={new_head:.17g} "
            f"STORAGE_GAIN_M={storage_gain:.17g} "
            f"EXPECTED_TRANSFER_M={transfer:.17g} "
            f"MODEL_DT_DAY={float(result['model_dt_day']):.17g}"
        )
        require(
            math.isclose(
                storage_gain,
                transfer,
                rel_tol=0.0,
                abs_tol=1.0e-12,
            ),
            f"memory transfer mismatch {name} step {step}: "
            f"storage_gain={storage_gain:.17g}, transfer={transfer:.17g}",
        )
        head = new_head
        w = w_new
        print(
            f"GC_DSW15_MEMORY_{name.upper()}_STEP_{step}_HEAD_M={head:.17g} "
            f"W_M={w:.17g} TRANSFER_M={transfer:.17g}"
        )

    require(
        math.isclose(
            S * (head - H0) + w,
            sum(inputs),
            rel_tol=0.0,
            abs_tol=1.0e-12,
        ),
        f"memory total mass {name}",
    )
    print(f"GC_DSW15_MEMORY_{name.upper()}_FINAL_HEAD_M={head:.17g}")
    print(f"GC_DSW15_MEMORY_{name.upper()}_FINAL_W_M={w:.17g}")
    return head, w


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")

    direct_early = run_memoryless(libmf6, "early", HISTORIES["early"])
    direct_late = run_memoryless(libmf6, "late", HISTORIES["late"])
    require(
        math.isclose(direct_early, 8.1, rel_tol=0.0, abs_tol=TOL),
        "memoryless early oracle",
    )
    require(
        math.isclose(direct_late, 8.1, rel_tol=0.0, abs_tol=TOL),
        "memoryless late oracle",
    )
    require(
        math.isclose(direct_early, direct_late, rel_tol=0.0, abs_tol=TOL),
        "memoryless forcing-order dependence",
    )

    memory_early, w_early = run_memory(libmf6, "early", HISTORIES["early"])
    memory_late, w_late = run_memory(libmf6, "late", HISTORIES["late"])

    require(
        math.isclose(
            memory_early,
            8.055555555555555,
            rel_tol=0.0,
            abs_tol=TOL,
        ),
        "memory early oracle",
    )
    require(
        math.isclose(
            memory_late,
            8.033333333333333,
            rel_tol=0.0,
            abs_tol=TOL,
        ),
        "memory late oracle",
    )
    require(
        math.isclose(w_early, 0.008888888888888889, rel_tol=0.0, abs_tol=1.0e-12),
        "memory early final w",
    )
    require(
        math.isclose(w_late, 0.013333333333333334, rel_tol=0.0, abs_tol=1.0e-12),
        "memory late final w",
    )
    require(memory_early > memory_late, "memory path dependence not observed")

    print("GC_DSW15_MEMORYLESS_ORDER_INVARIANCE=PASS")
    print("GC_DSW15_MEMORY_PATH_DEPENDENCE=PASS")
    print("GC_DSW15_TOTAL_MASS=PASS")
    print("GC_DSW15_LIVE_GATE=PASS")


if __name__ == "__main__":
    main()
