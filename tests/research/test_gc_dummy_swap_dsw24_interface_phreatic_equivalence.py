from __future__ import annotations

import math
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "research"))

from test_gc_dummy_swap_dsw01_live_modflow import run_case, require


H0 = 8.0
INPUT = 0.010
DT = 1.0
CONDUCTANCES = (0.01, 0.1, 1.0, 10.0, 1000.0)
HEAD_TOL = 1.0e-8
MASS_TOL = 1.0e-12
HIGH_C_HEAD_TOL = 1.0e-5


def closed_form(
    s_upper: float,
    s_modflow: float,
    conductance_per_day: float,
) -> tuple[float, float, float, float, float]:
    c = conductance_per_day
    a = s_upper / DT
    beta = c / (a + c)

    dh_mf = beta * INPUT / (s_modflow / DT + beta * a)
    h_mf = H0 + dh_mf
    h_upper = (a * H0 + INPUT + c * h_mf) / (a + c)
    q_ex = c * (h_upper - h_mf)

    hcof = -beta * a
    rhs = hcof * H0 - beta * INPUT
    return h_upper, h_mf, q_ex, hcof, rhs


def run_family(
    libmf6: Path,
    name: str,
    s_upper: float,
    s_modflow: float,
) -> tuple[list[float], list[float], list[float]]:
    upper_heads: list[float] = []
    mf_heads: list[float] = []
    gaps: list[float] = []

    for conductance in CONDUCTANCES:
        h_upper_expected, h_mf_expected, q_expected, hcof, rhs = closed_form(
            s_upper,
            s_modflow,
            conductance,
        )
        result = run_case(
            libmf6,
            f"dsw24_{name.lower()}_c_{conductance:g}",
            hcof_m2_per_day=hcof,
            rhs_m3_per_day=rhs,
            sy=s_modflow,
            newton=False,
            initial_head_m=H0,
            dt_day=DT,
        )
        require(
            bool(result["converged"]),
            f"{name} C={conductance} did not converge: {result}",
        )
        h_mf = float(result["head_m"])
        a = s_upper / DT
        h_upper = (a * H0 + INPUT + conductance * h_mf) / (
            a + conductance
        )
        q_ex = conductance * (h_upper - h_mf)

        upper_gain = s_upper * (h_upper - H0)
        mf_gain = s_modflow * (h_mf - H0)
        total_gain = upper_gain + mf_gain
        gap = abs(h_upper - h_mf)

        upper_heads.append(h_upper)
        mf_heads.append(h_mf)
        gaps.append(gap)

        print(
            f"GC_DSW24_{name}_C_{conductance:g}_H_UPPER_M="
            f"{h_upper:.17g}"
        )
        print(
            f"GC_DSW24_{name}_C_{conductance:g}_H_INTERFACE_M="
            f"{h_mf:.17g}"
        )
        print(
            f"GC_DSW24_{name}_C_{conductance:g}_HEAD_GAP_M="
            f"{gap:.17g}"
        )
        print(
            f"GC_DSW24_{name}_C_{conductance:g}_Q_EX_M_PER_DAY="
            f"{q_ex:.17g}"
        )
        print(
            f"GC_DSW24_{name}_C_{conductance:g}_TOTAL_STORAGE_GAIN_M="
            f"{total_gain:.17g}"
        )

        require(
            math.isclose(
                h_upper,
                h_upper_expected,
                rel_tol=0.0,
                abs_tol=HEAD_TOL,
            ),
            f"{name} upper head C={conductance}",
        )
        require(
            math.isclose(
                h_mf,
                h_mf_expected,
                rel_tol=0.0,
                abs_tol=HEAD_TOL,
            ),
            f"{name} MODFLOW head C={conductance}",
        )
        require(
            math.isclose(
                q_ex,
                q_expected,
                rel_tol=0.0,
                abs_tol=1.0e-10,
            ),
            f"{name} exchange C={conductance}",
        )
        require(
            math.isclose(
                total_gain,
                INPUT,
                rel_tol=0.0,
                abs_tol=MASS_TOL,
            ),
            f"{name} two-reservoir mass C={conductance}",
        )

    require(
        all(
            current < previous
            for previous, current in zip(
                gaps[:-1],
                gaps[1:],
                strict=True,
            )
        ),
        f"{name} head gaps are not monotone: {gaps}",
    )
    return upper_heads, mf_heads, gaps


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")

    consistent_upper, consistent_mf, consistent_gap = run_family(
        libmf6,
        "CONSISTENT",
        0.10,
        0.10,
    )
    target_hlink_head = 8.05

    require(
        consistent_gap[-1] < 1.0e-5,
        f"consistent high-C heads did not collapse: {consistent_gap[-1]}",
    )
    require(
        abs(consistent_upper[-1] - target_hlink_head)
        <= HIGH_C_HEAD_TOL,
        f"consistent upper high-C head {consistent_upper[-1]}",
    )
    require(
        abs(consistent_mf[-1] - target_hlink_head)
        <= HIGH_C_HEAD_TOL,
        f"consistent interface high-C head {consistent_mf[-1]}",
    )
    print("GC_DSW24_CONSISTENT_HEAD_COLLAPSE=PASS")
    print("GC_DSW24_CONSISTENT_HLINK_LIMIT=PASS")

    duplicate_upper, duplicate_mf, duplicate_gap = run_family(
        libmf6,
        "DUPLICATE",
        0.20,
        0.20,
    )
    duplicate_limit = 8.025

    require(
        duplicate_gap[-1] < 1.0e-5,
        f"duplicate high-C heads did not collapse: {duplicate_gap[-1]}",
    )
    require(
        abs(duplicate_upper[-1] - duplicate_limit)
        <= HIGH_C_HEAD_TOL,
        f"duplicate upper high-C head {duplicate_upper[-1]}",
    )
    require(
        abs(duplicate_mf[-1] - duplicate_limit)
        <= HIGH_C_HEAD_TOL,
        f"duplicate interface high-C head {duplicate_mf[-1]}",
    )
    require(
        abs(duplicate_upper[-1] - target_hlink_head) >= 0.02,
        "duplicate upper head too close to physical h-link target",
    )
    require(
        abs(duplicate_mf[-1] - target_hlink_head) >= 0.02,
        "duplicate interface head too close to physical h-link target",
    )

    shared_proxy_head = 0.5 * (
        duplicate_upper[-1] + duplicate_mf[-1]
    )
    one_volume_geometric_gain = 0.20 * (shared_proxy_head - H0)
    duplicate_two_owner_gain = (
        0.20 * (duplicate_upper[-1] - H0)
        + 0.20 * (duplicate_mf[-1] - H0)
    )

    print(
        "GC_DSW24_DUPLICATE_HIGH_C_SHARED_PROXY_HEAD_M="
        f"{shared_proxy_head:.17g}"
    )
    print(
        "GC_DSW24_DUPLICATE_ONE_VOLUME_GEOMETRIC_GAIN_M="
        f"{one_volume_geometric_gain:.17g}"
    )
    print(
        "GC_DSW24_DUPLICATE_TWO_OWNER_GAIN_M="
        f"{duplicate_two_owner_gain:.17g}"
    )

    require(
        math.isclose(
            duplicate_two_owner_gain,
            INPUT,
            rel_tol=0.0,
            abs_tol=MASS_TOL,
        ),
        "duplicate two-owner bookkeeping",
    )
    require(
        abs(one_volume_geometric_gain - 0.005) <= 2.0e-6,
        "duplicate one-volume geometric signature",
    )
    require(
        abs(one_volume_geometric_gain - INPUT) >= 0.004,
        "duplicate case unexpectedly satisfies one-volume h-link storage law",
    )

    print("GC_DSW24_DUPLICATE_HEAD_COLLAPSE=PASS")
    print("GC_DSW24_DUPLICATE_HLINK_NONEQUIVALENCE=PASS")
    print("GC_DSW24_HEAD_EQUALITY_NOT_SUFFICIENT=PASS")
    print("GC_DSW24_NUMERICAL_TWO_RESERVOIR_MASS=PASS")
    print("GC_DSW24_LIVE_GATE=PASS")


if __name__ == "__main__":
    main()
