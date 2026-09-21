from __future__ import annotations

import math
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "research"))

from test_gc_dummy_swap_dsw01_live_modflow import run_case, require


AREA = 1.0
BOTTOM = 0.0
SURFACE = 10.0
H0 = 8.0
N_D = 0.20
DT = 1.0
INPUT = 0.010
EXPECTED = 8.05
HEAD_TOL = 1.0e-10
VOLUME_TOL = 1.0e-12


def physical_volume(head_m: float) -> float:
    require(BOTTOM <= head_m <= SURFACE, f"head outside declared coextensive column: {head_m}")
    return AREA * N_D * (head_m - BOTTOM)


def partition_term(alpha_swap: float) -> tuple[float, float, float]:
    s_swap = alpha_swap * N_D
    sy_mf = (1.0 - alpha_swap) * N_D

    # One geometric storage volume is partitioned between the two numerical
    # owners.  Dummy-SWAP contributes atmospheric input and removes only its
    # owned storage increment from the MODFLOW-facing exchange:
    #
    # Q_swap(H) = INPUT - S_swap*(H-H0)/DT.
    hcof = -s_swap / DT
    rhs = hcof * H0 - INPUT
    return sy_mf, hcof, rhs


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")

    v0 = physical_volume(H0)
    v_expected = physical_volume(EXPECTED)
    geometric_expected_gain = v_expected - v0

    require(
        math.isclose(v0, 1.6, rel_tol=0.0, abs_tol=1.0e-14),
        "initial geometric volume",
    )
    require(
        math.isclose(v_expected, 1.61, rel_tol=0.0, abs_tol=1.0e-14),
        "final geometric volume",
    )
    require(
        math.isclose(
            geometric_expected_gain,
            INPUT,
            rel_tol=0.0,
            abs_tol=1.0e-14,
        ),
        "geometric oracle",
    )

    print(f"GC_DSW23_INITIAL_GEOMETRIC_VOLUME_M3={v0:.17g}")
    print(f"GC_DSW23_EXPECTED_FINAL_GEOMETRIC_VOLUME_M3={v_expected:.17g}")
    print(f"GC_DSW23_EXPECTED_GEOMETRIC_GAIN_M3={geometric_expected_gain:.17g}")
    print("GC_DSW23_GEOMETRIC_ORACLE=PASS")

    partition_heads: list[float] = []
    for alpha in (0.0, 0.25, 0.5, 0.75, 1.0):
        sy_mf, hcof, rhs = partition_term(alpha)
        s_swap = alpha * N_D

        result = run_case(
            libmf6,
            f"dsw23_partition_{alpha:.2f}",
            hcof_m2_per_day=hcof,
            rhs_m3_per_day=rhs,
            sy=sy_mf,
            newton=False,
        )
        require(
            bool(result["converged"]),
            f"partition alpha={alpha} did not converge: {result}",
        )
        head = float(result["head_m"])
        partition_heads.append(head)

        dh = head - H0
        mf_owned_gain = sy_mf * AREA * dh
        swap_owned_gain = s_swap * AREA * dh
        owned_total_gain = mf_owned_gain + swap_owned_gain
        geometric_gain = physical_volume(head) - v0

        print(f"GC_DSW23_ALPHA_{alpha:.2f}_HEAD_M={head:.17g}")
        print(f"GC_DSW23_ALPHA_{alpha:.2f}_MF_OWNED_GAIN_M3={mf_owned_gain:.17g}")
        print(f"GC_DSW23_ALPHA_{alpha:.2f}_SWAP_OWNED_GAIN_M3={swap_owned_gain:.17g}")
        print(f"GC_DSW23_ALPHA_{alpha:.2f}_OWNED_TOTAL_GAIN_M3={owned_total_gain:.17g}")
        print(f"GC_DSW23_ALPHA_{alpha:.2f}_GEOMETRIC_GAIN_M3={geometric_gain:.17g}")

        require(
            math.isclose(head, EXPECTED, rel_tol=0.0, abs_tol=HEAD_TOL),
            f"partition alpha={alpha} head {head} != {EXPECTED}",
        )
        require(
            math.isclose(owned_total_gain, INPUT, rel_tol=0.0, abs_tol=VOLUME_TOL),
            f"partition alpha={alpha} ownership ledger",
        )
        require(
            math.isclose(geometric_gain, INPUT, rel_tol=0.0, abs_tol=VOLUME_TOL),
            f"partition alpha={alpha} geometric mass",
        )
        require(
            math.isclose(
                owned_total_gain,
                geometric_gain,
                rel_tol=0.0,
                abs_tol=VOLUME_TOL,
            ),
            f"partition alpha={alpha} ownership/geometric mismatch",
        )

    spread = max(partition_heads) - min(partition_heads)
    require(spread <= HEAD_TOL, f"partition changed physical head: {partition_heads}")
    print(f"GC_DSW23_PARTITION_HEAD_SPREAD_M={spread:.17g}")
    print("GC_DSW23_PARTITION_INVARIANCE=PASS")

    # Deliberate duplicate ownership: both numerical components claim the same
    # complete geometric drainable storage N_D=0.20.  Numerical bookkeeping
    # therefore sees 0.40 storage while the declared physical column still has
    # only 0.20 drainable storage.
    s_swap = N_D
    sy_mf = N_D
    hcof = -s_swap / DT
    rhs = hcof * H0 - INPUT
    duplicate = run_case(
        libmf6,
        "dsw23_duplicate_ownership",
        hcof_m2_per_day=hcof,
        rhs_m3_per_day=rhs,
        sy=sy_mf,
        newton=False,
    )
    require(bool(duplicate["converged"]), f"duplicate case did not converge: {duplicate}")
    duplicate_head = float(duplicate["head_m"])
    duplicate_dh = duplicate_head - H0

    mf_bookkeeping_gain = sy_mf * AREA * duplicate_dh
    swap_bookkeeping_gain = s_swap * AREA * duplicate_dh
    bookkeeping_total = mf_bookkeeping_gain + swap_bookkeeping_gain
    geometric_gain = physical_volume(duplicate_head) - v0
    physical_deficit = INPUT - geometric_gain

    print(f"GC_DSW23_DUPLICATE_HEAD_M={duplicate_head:.17g}")
    print(f"GC_DSW23_DUPLICATE_MF_BOOKKEEPING_GAIN_M3={mf_bookkeeping_gain:.17g}")
    print(f"GC_DSW23_DUPLICATE_SWAP_BOOKKEEPING_GAIN_M3={swap_bookkeeping_gain:.17g}")
    print(f"GC_DSW23_DUPLICATE_BOOKKEEPING_TOTAL_M3={bookkeeping_total:.17g}")
    print(f"GC_DSW23_DUPLICATE_GEOMETRIC_GAIN_M3={geometric_gain:.17g}")
    print(f"GC_DSW23_DUPLICATE_PHYSICAL_DEFICIT_M3={physical_deficit:.17g}")

    require(
        math.isclose(duplicate_head, 8.025, rel_tol=0.0, abs_tol=HEAD_TOL),
        f"duplicate head {duplicate_head} != 8.025",
    )
    require(
        math.isclose(
            mf_bookkeeping_gain,
            0.005,
            rel_tol=0.0,
            abs_tol=VOLUME_TOL,
        ),
        "duplicate MODFLOW bookkeeping gain",
    )
    require(
        math.isclose(
            swap_bookkeeping_gain,
            0.005,
            rel_tol=0.0,
            abs_tol=VOLUME_TOL,
        ),
        "duplicate SWAP bookkeeping gain",
    )
    require(
        math.isclose(bookkeeping_total, INPUT, rel_tol=0.0, abs_tol=VOLUME_TOL),
        "duplicate bookkeeping did not close",
    )
    require(
        math.isclose(geometric_gain, 0.005, rel_tol=0.0, abs_tol=VOLUME_TOL),
        "duplicate geometric gain",
    )
    require(
        math.isclose(physical_deficit, 0.005, rel_tol=0.0, abs_tol=VOLUME_TOL),
        "duplicate physical-volume deficit",
    )

    print("GC_DSW23_DUPLICATE_BOOKKEEPING_CLOSES=PASS")
    print("GC_DSW23_DUPLICATE_GEOMETRIC_VOLUME_FAILS=PASS")
    print("GC_DSW23_DOMAIN_OWNERSHIP_ORACLE=PASS")
    print("GC_DSW23_LIVE_GATE=PASS")


if __name__ == "__main__":
    main()
