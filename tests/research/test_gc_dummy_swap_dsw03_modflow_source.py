from __future__ import annotations

import math
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "research"))

from test_gc_dummy_swap_dsw01_live_modflow import run_case, require


H0_M = 8.0
S_TOTAL = 0.20
DT_DAY = 1.0
Q_MF_M3_PER_DAY = 0.010
EXPECTED_HEAD_M = H0_M + Q_MF_M3_PER_DAY * DT_DAY / S_TOTAL
TOL_M = 1.0e-8


def consistent_term(alpha_swap: float) -> tuple[float, float, float]:
    s_swap = alpha_swap * S_TOTAL
    s_mf = (1.0 - alpha_swap) * S_TOTAL

    # No atmospheric input. Dummy SWAP contributes only its owned share of
    # shared-state storage:
    #   Q_dummy = -(S_swap/dt) * (H-H0)
    hcof = -s_swap / DT_DAY
    rhs = hcof * H0_M
    return s_mf, hcof, rhs


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")

    # Independent algebraic oracle.
    require(
        math.isclose(
            EXPECTED_HEAD_M,
            8.05,
            rel_tol=0.0,
            abs_tol=1.0e-14,
        ),
        "physical oracle",
    )
    print("GC_DSW03_ANALYTIC_SHARED_STATE=PASS")

    heads: list[float] = []
    errors: list[float] = []
    for alpha in (0.0, 0.25, 0.5, 0.75, 1.0):
        sy, hcof, rhs = consistent_term(alpha)
        result = run_case(
            libmf6,
            f"mf_source_partition_{alpha:.2f}",
            hcof_m2_per_day=hcof,
            rhs_m3_per_day=rhs,
            sy=sy,
            newton=False,
            well_rate_m3_per_day=Q_MF_M3_PER_DAY,
        )
        require(
            bool(result["converged"]),
            f"partition alpha={alpha} did not converge: {result}",
        )
        head = float(result["head_m"])
        error = head - EXPECTED_HEAD_M
        heads.append(head)
        errors.append(error)
        print(f"GC_DSW03_ALPHA_{alpha:.2f}_HEAD_M={head:.17g}")
        print(f"GC_DSW03_ALPHA_{alpha:.2f}_ERROR_M={error:.17g}")

    spread = max(heads) - min(heads)
    print(f"GC_DSW03_PARTITION_SPREAD_M={spread:.17g}")

    # Pre-registered adversarial probe: same split, but the dummy storage-like
    # term is deliberately given the current positive head slope.  This is
    # diagnostic only and may be singular/non-convergent.
    s_swap = 0.5 * S_TOTAL
    s_mf = S_TOTAL - s_swap
    hcof_positive = s_swap / DT_DAY
    rhs_positive = hcof_positive * H0_M
    positive = run_case(
        libmf6,
        "mf_source_positive_storage_slope",
        hcof_m2_per_day=hcof_positive,
        rhs_m3_per_day=rhs_positive,
        sy=s_mf,
        newton=False,
        well_rate_m3_per_day=Q_MF_M3_PER_DAY,
    )
    print(f"GC_DSW03_POSITIVE_SLOPE_STATUS={positive['status']}")
    print(
        "GC_DSW03_POSITIVE_SLOPE_CONVERGED="
        f"{1 if bool(positive['converged']) else 0}"
    )
    if math.isfinite(float(positive["head_m"])):
        print(
            "GC_DSW03_POSITIVE_SLOPE_HEAD_M="
            f"{float(positive['head_m']):.17g}"
        )
    else:
        print("GC_DSW03_POSITIVE_SLOPE_HEAD_M=NONFINITE_OR_UNAVAILABLE")
    print(f"GC_DSW03_POSITIVE_SLOPE_ITERATIONS={int(positive['iterations'])}")
    if positive["error"]:
        print(f"GC_DSW03_POSITIVE_SLOPE_ERROR={positive['error']}")
    print("GC_DSW03_POSITIVE_SLOPE_PROBE_RECORDED=PASS")

    require(
        max(abs(value) for value in errors) <= TOL_M,
        f"partition oracle error exceeds {TOL_M}: {errors}",
    )
    require(
        spread <= TOL_M,
        f"partition changed shared head: {heads}",
    )
    print("GC_DSW03_MODFLOW_SOURCE_CHANGES_SHARED_STATE=PASS")
    print("GC_DSW03_STORAGE_PARTITION_INVARIANCE=PASS")
    print("GC_DSW03_LIVE_GATE=PASS")


if __name__ == "__main__":
    main()
