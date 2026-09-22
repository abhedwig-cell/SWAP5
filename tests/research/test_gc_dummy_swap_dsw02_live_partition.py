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
RAIN_M_PER_DAY = 0.010
DT_DAY = 1.0
EXPECTED_H_M = H0_M + RAIN_M_PER_DAY * DT_DAY / S_TOTAL
TOL_M = 1.0e-8


def correct_partition_term(alpha: float) -> tuple[float, float, float]:
    s_swap = alpha * S_TOTAL
    s_mf = (1.0 - alpha) * S_TOTAL

    # Desired API inflow:
    # q_api(H) = R - S_swap*(H-H0)/dt
    # MODFLOW API convention:
    # q_api(H) = HCOF*H - RHS
    hcof = -s_swap / DT_DAY
    rhs = hcof * H0_M - RAIN_M_PER_DAY
    return s_mf, hcof, rhs


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")

    heads: list[float] = []
    partition_errors: list[float] = []
    for alpha in (0.0, 0.25, 0.5, 0.75, 1.0):
        sy, hcof, rhs = correct_partition_term(alpha)
        result = run_case(
            libmf6,
            f"partition_{alpha:.2f}",
            hcof_m2_per_day=hcof,
            rhs_m3_per_day=rhs,
            sy=sy,
            newton=False,
        )
        require(bool(result["converged"]), f"partition alpha={alpha} did not converge: {result}")
        h = float(result["head_m"])
        error = h - EXPECTED_H_M
        heads.append(h)
        partition_errors.append(error)
        print(f"GC_DSW02_ALPHA_{alpha:.2f}_HEAD_M={h:.17g}")
        print(f"GC_DSW02_ALPHA_{alpha:.2f}_ERROR_M={error:.17g}")

    partition_spread = max(heads) - min(heads)
    print(f"GC_DSW02_PARTITION_SPREAD_M={partition_spread:.17g}")

    # Deliberate overlap: MODFLOW keeps the full physical storage AND the API
    # term represents another full copy of the same storage.
    sy_double = S_TOTAL
    hcof_double = -S_TOTAL / DT_DAY
    rhs_double = hcof_double * H0_M - RAIN_M_PER_DAY
    doubled = run_case(
        libmf6,
        "double_storage",
        hcof_m2_per_day=hcof_double,
        rhs_m3_per_day=rhs_double,
        sy=sy_double,
        newton=False,
    )
    require(bool(doubled["converged"]), f"double-storage case did not converge: {doubled}")
    expected_double = H0_M + RAIN_M_PER_DAY * DT_DAY / (2.0 * S_TOTAL)
    double_error = float(doubled["head_m"]) - expected_double

    print(f"GC_DSW02_DOUBLE_STORAGE_HEAD_M={float(doubled['head_m']):.17g}")
    print(f"GC_DSW02_DOUBLE_STORAGE_ERROR_M={double_error:.17g}")

    # Emit all observations before enforcing the fixed numerical gates.
    require(
        max(abs(value) for value in partition_errors) <= TOL_M,
        f"partition oracle error exceeds {TOL_M}: {partition_errors}",
    )
    require(
        partition_spread <= TOL_M,
        f"storage partition changed final head: {heads}",
    )
    require(
        abs(double_error) <= TOL_M,
        f"double-storage signature {doubled['head_m']} != {expected_double}",
    )
    print("GC_DSW02_LIVE_PARTITION_INVARIANCE=PASS")
    print("GC_DSW02_LIVE_DOUBLE_STORAGE_SIGNATURE=PASS")
    print("GC_DSW02_LIVE_GATE=PASS")


if __name__ == "__main__":
    main()
