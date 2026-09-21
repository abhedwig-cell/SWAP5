from __future__ import annotations

import math
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "research"))

from test_gc_dummy_swap_dsw01_live_modflow import (
    AREA_M2,
    BOT_M,
    H0_M,
    TOP_M,
    run_case,
    require,
)


DRAINABLE_POROSITY = 0.20
INPUT_M = 0.010
INPUT_M3 = AREA_M2 * INPUT_M
DT_DAY = 1.0
EXPECTED_HEAD_M = 8.05
HEAD_TOL_M = 1.0e-10
VOLUME_TOL_M3 = 1.0e-12
PARTITIONS = (0.0, 0.25, 0.50, 0.75, 1.0)


def physical_drainable_volume_m3(head_m: float) -> float:
    return AREA_M2 * DRAINABLE_POROSITY * (head_m - BOT_M)


def partition_term(alpha_swap: float) -> tuple[float, float, float]:
    s_swap = alpha_swap * DRAINABLE_POROSITY
    s_modflow = (1.0 - alpha_swap) * DRAINABLE_POROSITY
    hcof = -s_swap / DT_DAY
    rhs = hcof * H0_M - INPUT_M3 / DT_DAY
    return s_swap, s_modflow, hcof, rhs


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")

    require(math.isclose(AREA_M2, 1.0, rel_tol=0.0, abs_tol=0.0), "area drift")
    require(math.isclose(BOT_M, 0.0, rel_tol=0.0, abs_tol=0.0), "bottom drift")
    require(math.isclose(TOP_M, 10.0, rel_tol=0.0, abs_tol=0.0), "top drift")
    require(math.isclose(H0_M, 8.0, rel_tol=0.0, abs_tol=0.0), "initial head drift")
    require(H0_M < TOP_M, "initial water table is not below ground surface")

    initial_volume = physical_drainable_volume_m3(H0_M)
    expected_final_volume = physical_drainable_volume_m3(EXPECTED_HEAD_M)
    expected_geometry_gain = expected_final_volume - initial_volume

    require(
        math.isclose(initial_volume, 1.6, rel_tol=0.0, abs_tol=1.0e-14),
        "initial geometric volume oracle",
    )
    require(
        math.isclose(expected_final_volume, 1.61, rel_tol=0.0, abs_tol=1.0e-14),
        "final geometric volume oracle",
    )
    require(
        math.isclose(expected_geometry_gain, INPUT_M3, rel_tol=0.0, abs_tol=1.0e-14),
        "ten-millimetre volume oracle",
    )

    print(f"GC_DSW23_GEOMETRY_AREA_M2={AREA_M2:.17g}")
    print(f"GC_DSW23_GEOMETRY_BOTTOM_M={BOT_M:.17g}")
    print(f"GC_DSW23_GEOMETRY_TOP_M={TOP_M:.17g}")
    print(f"GC_DSW23_INITIAL_HEAD_M={H0_M:.17g}")
    print(f"GC_DSW23_INITIAL_WATER_TABLE_DEPTH_M={TOP_M-H0_M:.17g}")
    print(f"GC_DSW23_INITIAL_DRAINABLE_VOLUME_M3={initial_volume:.17g}")
    print(f"GC_DSW23_EXPECTED_FINAL_DRAINABLE_VOLUME_M3={expected_final_volume:.17g}")
    print(f"GC_DSW23_INPUT_VOLUME_M3={INPUT_M3:.17g}")
    print("GC_DSW23_GEOMETRIC_VOLUME_ORACLE=PASS")

    partition_heads: list[float] = []

    for alpha_swap in PARTITIONS:
        s_swap, s_modflow, hcof, rhs = partition_term(alpha_swap)
        result = run_case(
            libmf6,
            f"dsw23_partition_{alpha_swap:.2f}",
            hcof_m2_per_day=hcof,
            rhs_m3_per_day=rhs,
            sy=s_modflow,
            newton=False,
            initial_head_m=H0_M,
            dt_day=DT_DAY,
        )
        require(
            bool(result["converged"]),
            f"partition alpha={alpha_swap} did not converge: {result}",
        )
        head = float(result["head_m"])
        partition_heads.append(head)

        dh = head - H0_M
        modflow_owned_gain = s_modflow * AREA_M2 * dh
        swap_owned_gain = s_swap * AREA_M2 * dh
        bookkeeping_gain = modflow_owned_gain + swap_owned_gain
        geometric_gain = physical_drainable_volume_m3(head) - initial_volume

        print(f"GC_DSW23_ALPHA_{alpha_swap:.2f}_HEAD_M={head:.17g}")
        print(f"GC_DSW23_ALPHA_{alpha_swap:.2f}_MF_OWNED_GAIN_M3={modflow_owned_gain:.17g}")
        print(f"GC_DSW23_ALPHA_{alpha_swap:.2f}_SWAP_OWNED_GAIN_M3={swap_owned_gain:.17g}")
        print(f"GC_DSW23_ALPHA_{alpha_swap:.2f}_BOOKKEEPING_GAIN_M3={bookkeeping_gain:.17g}")
        print(f"GC_DSW23_ALPHA_{alpha_swap:.2f}_GEOMETRIC_GAIN_M3={geometric_gain:.17g}")

        require(
            math.isclose(head, EXPECTED_HEAD_M, rel_tol=0.0, abs_tol=HEAD_TOL_M),
            f"partition alpha={alpha_swap} head {head} != {EXPECTED_HEAD_M}",
        )
        require(
            math.isclose(bookkeeping_gain, INPUT_M3, rel_tol=0.0, abs_tol=VOLUME_TOL_M3),
            f"partition alpha={alpha_swap} bookkeeping volume",
        )
        require(
            math.isclose(geometric_gain, INPUT_M3, rel_tol=0.0, abs_tol=VOLUME_TOL_M3),
            f"partition alpha={alpha_swap} geometric volume",
        )
        require(
            math.isclose(bookkeeping_gain, geometric_gain, rel_tol=0.0, abs_tol=VOLUME_TOL_M3),
            f"partition alpha={alpha_swap} ownership/geometric mismatch",
        )

    spread = max(partition_heads) - min(partition_heads)
    print(f"GC_DSW23_PARTITION_HEAD_SPREAD_M={spread:.17g}")
    require(spread <= HEAD_TOL_M, f"ownership partition changed physical head: {partition_heads}")
    print("GC_DSW23_COEXTENSIVE_PARTITION_INVARIANCE=PASS")
    print("GC_DSW23_ENDPOINT_OWNERSHIP_CONTROLS=PASS")

    duplicate_hcof = -DRAINABLE_POROSITY / DT_DAY
    duplicate_rhs = duplicate_hcof * H0_M - INPUT_M3 / DT_DAY
    duplicate = run_case(
        libmf6,
        "dsw23_duplicate_ownership",
        hcof_m2_per_day=duplicate_hcof,
        rhs_m3_per_day=duplicate_rhs,
        sy=DRAINABLE_POROSITY,
        newton=False,
        initial_head_m=H0_M,
        dt_day=DT_DAY,
    )
    require(bool(duplicate["converged"]), f"duplicate ownership did not converge: {duplicate}")

    duplicate_head = float(duplicate["head_m"])
    duplicate_dh = duplicate_head - H0_M
    mf_bookkeeping_gain = DRAINABLE_POROSITY * AREA_M2 * duplicate_dh
    swap_bookkeeping_gain = DRAINABLE_POROSITY * AREA_M2 * duplicate_dh
    bookkeeping_total = mf_bookkeeping_gain + swap_bookkeeping_gain
    geometric_gain = physical_drainable_volume_m3(duplicate_head) - initial_volume
    physical_volume_deficit = INPUT_M3 - geometric_gain

    print(f"GC_DSW23_DUPLICATE_HEAD_M={duplicate_head:.17g}")
    print(f"GC_DSW23_DUPLICATE_MF_BOOKKEEPING_GAIN_M3={mf_bookkeeping_gain:.17g}")
    print(f"GC_DSW23_DUPLICATE_SWAP_BOOKKEEPING_GAIN_M3={swap_bookkeeping_gain:.17g}")
    print(f"GC_DSW23_DUPLICATE_BOOKKEEPING_TOTAL_M3={bookkeeping_total:.17g}")
    print(f"GC_DSW23_DUPLICATE_GEOMETRIC_GAIN_M3={geometric_gain:.17g}")
    print(f"GC_DSW23_DUPLICATE_PHYSICAL_VOLUME_DEFICIT_M3={physical_volume_deficit:.17g}")

    require(
        math.isclose(duplicate_head, 8.025, rel_tol=0.0, abs_tol=HEAD_TOL_M),
        f"duplicate ownership signature {duplicate_head}",
    )
    require(
        math.isclose(mf_bookkeeping_gain, 0.005, rel_tol=0.0, abs_tol=VOLUME_TOL_M3),
        "duplicate MODFLOW bookkeeping gain",
    )
    require(
        math.isclose(swap_bookkeeping_gain, 0.005, rel_tol=0.0, abs_tol=VOLUME_TOL_M3),
        "duplicate SWAP bookkeeping gain",
    )
    require(
        math.isclose(bookkeeping_total, INPUT_M3, rel_tol=0.0, abs_tol=VOLUME_TOL_M3),
        "duplicate numerical bookkeeping does not close",
    )
    require(
        math.isclose(geometric_gain, 0.005, rel_tol=0.0, abs_tol=VOLUME_TOL_M3),
        "duplicate physical geometry signature",
    )
    require(
        math.isclose(physical_volume_deficit, 0.005, rel_tol=0.0, abs_tol=VOLUME_TOL_M3),
        "duplicate physical ownership deficit",
    )
    require(
        not math.isclose(
            bookkeeping_total,
            geometric_gain,
            rel_tol=0.0,
            abs_tol=VOLUME_TOL_M3,
        ),
        "duplicate ownership unexpectedly matches single-volume geometry",
    )

    print("GC_DSW23_DUPLICATE_NUMERICAL_LEDGER_CLOSES=PASS")
    print("GC_DSW23_DUPLICATE_GEOMETRIC_LEDGER_FAILS=PASS")
    print("GC_DSW23_DOMAIN_OWNERSHIP_REQUIRED=PASS")
    print("GC_DSW23_LIVE_GATE=PASS")


if __name__ == "__main__":
    main()
