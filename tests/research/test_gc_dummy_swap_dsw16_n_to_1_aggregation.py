from __future__ import annotations

import itertools
import math
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "research"))

from test_gc_dummy_swap_dsw01_live_modflow import run_case, require


H0 = 8.0
DT = 1.0
TOL = 1.0e-10

COLUMNS = (
    (1, 0.20, 0.10, 0.004),
    (2, 0.30, 0.20, 0.010),
    (3, 0.50, 0.30, 0.020),
)


def aggregate(columns: tuple[tuple[int, float, float, float], ...]) -> tuple[float, float, float]:
    area_sum = sum(area for _, area, _, _ in columns)
    require(
        math.isclose(area_sum, 1.0, rel_tol=0.0, abs_tol=1.0e-14),
        "area fractions do not sum to one",
    )
    storage = sum(area * s for _, area, s, _ in columns)
    recharge = sum(area * r for _, area, _, r in columns)
    hcof = -storage / DT
    rhs = hcof * H0 - recharge
    return hcof, rhs, recharge


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")

    expected_hcof = -0.23
    expected_recharge = 0.0138
    expected_head = 8.06

    heads: list[float] = []
    terms: list[tuple[float, float]] = []

    for pindex, permutation in enumerate(itertools.permutations(COLUMNS), start=1):
        columns = tuple(permutation)
        hcof, rhs, recharge = aggregate(columns)
        require(
            math.isclose(hcof, expected_hcof, rel_tol=0.0, abs_tol=1.0e-14),
            f"permutation {pindex} HCOF",
        )
        require(
            math.isclose(recharge, expected_recharge, rel_tol=0.0, abs_tol=1.0e-14),
            f"permutation {pindex} recharge",
        )

        result = run_case(
            libmf6,
            f"n1_perm_{pindex}",
            hcof_m2_per_day=hcof,
            rhs_m3_per_day=rhs,
            sy=0.0,
            newton=False,
        )
        require(bool(result["converged"]), f"permutation {pindex} did not converge: {result}")
        head = float(result["head_m"])
        require(
            math.isclose(head, expected_head, rel_tol=0.0, abs_tol=TOL),
            f"permutation {pindex} head {head} != {expected_head}",
        )
        heads.append(head)
        terms.append((hcof, rhs))

        weighted_storage_gain = sum(
            area * storage * (head - H0)
            for _, area, storage, _ in columns
        )
        weighted_input = sum(
            area * recharge_i * DT
            for _, area, _, recharge_i in columns
        )
        require(
            math.isclose(
                weighted_storage_gain,
                weighted_input,
                rel_tol=0.0,
                abs_tol=1.0e-12,
            ),
            f"permutation {pindex} aggregate mass",
        )

        order = "-".join(str(cid) for cid, *_ in columns)
        print(
            f"GC_DSW16_PERM_{pindex}_ORDER={order} "
            f"HCOF={hcof:.17g} RHS={rhs:.17g} HEAD_M={head:.17g}"
        )

    head_spread = max(heads) - min(heads)
    hcof_spread = max(x[0] for x in terms) - min(x[0] for x in terms)
    rhs_spread = max(x[1] for x in terms) - min(x[1] for x in terms)
    print(f"GC_DSW16_HEAD_SPREAD_M={head_spread:.17g}")
    print(f"GC_DSW16_HCOF_SPREAD={hcof_spread:.17g}")
    print(f"GC_DSW16_RHS_SPREAD={rhs_spread:.17g}")

    require(head_spread <= TOL, "column permutation changed final head")
    require(abs(hcof_spread) <= 1.0e-14, "column permutation changed HCOF")
    require(abs(rhs_spread) <= 1.0e-14, "column permutation changed RHS")

    print("GC_DSW16_AREA_WEIGHTED_AGGREGATION=PASS")
    print("GC_DSW16_PERMUTATION_INVARIANCE=PASS")
    print("GC_DSW16_AGGREGATE_MASS=PASS")
    print("GC_DSW16_LIVE_GATE=PASS")


if __name__ == "__main__":
    main()
