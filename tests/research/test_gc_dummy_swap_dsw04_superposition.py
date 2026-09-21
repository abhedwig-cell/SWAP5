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
S_SWAP = 0.10
S_MF = 0.10
DT_DAY = 1.0
RAIN_M_PER_DAY = 0.006
Q_MF_M3_PER_DAY = 0.004
TOL_M = 1.0e-8


def api_term(rain_m_per_day: float) -> tuple[float, float]:
    # Q_dummy(H) = R - S_swap/dt * (H-H0)
    hcof = -S_SWAP / DT_DAY
    rhs = hcof * H0_M - rain_m_per_day
    return hcof, rhs


def run_physical_case(
    libmf6: Path,
    name: str,
    rain_m_per_day: float,
    mf_source_m3_per_day: float,
) -> float:
    hcof, rhs = api_term(rain_m_per_day)
    result = run_case(
        libmf6,
        name,
        hcof_m2_per_day=hcof,
        rhs_m3_per_day=rhs,
        sy=S_MF,
        newton=False,
        well_rate_m3_per_day=mf_source_m3_per_day,
    )
    require(bool(result["converged"]), f"{name} did not converge: {result}")
    return float(result["head_m"])


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")

    rain_head = run_physical_case(
        libmf6,
        "superposition_rain",
        RAIN_M_PER_DAY,
        0.0,
    )
    mf_head = run_physical_case(
        libmf6,
        "superposition_modflow",
        0.0,
        Q_MF_M3_PER_DAY,
    )
    both_head = run_physical_case(
        libmf6,
        "superposition_both",
        RAIN_M_PER_DAY,
        Q_MF_M3_PER_DAY,
    )

    expected_rain = H0_M + RAIN_M_PER_DAY * DT_DAY / S_TOTAL
    expected_mf = H0_M + Q_MF_M3_PER_DAY * DT_DAY / S_TOTAL
    expected_both = H0_M + (
        RAIN_M_PER_DAY + Q_MF_M3_PER_DAY
    ) * DT_DAY / S_TOTAL

    print(f"GC_DSW04_RAIN_HEAD_M={rain_head:.17g}")
    print(f"GC_DSW04_MODFLOW_HEAD_M={mf_head:.17g}")
    print(f"GC_DSW04_COMBINED_HEAD_M={both_head:.17g}")

    require(
        math.isclose(rain_head, expected_rain, rel_tol=0.0, abs_tol=TOL_M),
        f"rain-only {rain_head} != {expected_rain}",
    )
    require(
        math.isclose(mf_head, expected_mf, rel_tol=0.0, abs_tol=TOL_M),
        f"MODFLOW-only {mf_head} != {expected_mf}",
    )
    require(
        math.isclose(both_head, expected_both, rel_tol=0.0, abs_tol=TOL_M),
        f"combined {both_head} != {expected_both}",
    )

    combined_increment = both_head - H0_M
    summed_increment = (rain_head - H0_M) + (mf_head - H0_M)
    superposition_error = combined_increment - summed_increment
    print(f"GC_DSW04_SUPERPOSITION_ERROR_M={superposition_error:.17g}")
    require(
        abs(superposition_error) <= TOL_M,
        "linear superposition failed",
    )

    print("GC_DSW04_RAIN_ORACLE=PASS")
    print("GC_DSW04_MODFLOW_SOURCE_ORACLE=PASS")
    print("GC_DSW04_SUPERPOSITION=PASS")
    print("GC_DSW04_LIVE_GATE=PASS")


if __name__ == "__main__":
    main()
