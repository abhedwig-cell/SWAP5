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
TARGET_HLINK = 8.05
CONDUCTANCES = (0.01, 0.1, 1.0, 10.0, 1000.0)
HEAD_TOL = 1.0e-8
MASS_TOL = 1.0e-12


def eliminated_term(
    swap_storage: float,
    conductance_per_day: float,
) -> tuple[float, float]:
    a = swap_storage / DT
    beta = conductance_per_day / (a + conductance_per_day)
    hcof = -beta * a
    rhs = hcof * H0 - beta * INPUT
    return hcof, rhs


def reconstruct_upper_head(
    swap_storage: float,
    conductance_per_day: float,
    lower_head_m: float,
) -> float:
    a = swap_storage / DT
    return (
        a * H0 + INPUT + conductance_per_day * lower_head_m
    ) / (a + conductance_per_day)


def run_case_family(
    libmf6: Path,
    label: str,
    swap_storage: float,
    modflow_storage: float,
    conductances: tuple[float, ...],
) -> list[tuple[float, float, float, float]]:
    rows: list[tuple[float, float, float, float]] = []
    for conductance in conductances:
        hcof, rhs = eliminated_term(swap_storage, conductance)
        result = run_case(
            libmf6,
            f"dsw24_{label.lower()}_{conductance:g}",
            hcof_m2_per_day=hcof,
            rhs_m3_per_day=rhs,
            sy=modflow_storage,
            newton=False,
        )
        require(
            bool(result["converged"]),
            f"{label} C={conductance} did not converge: {result}",
        )
        h_lower = float(result["head_m"])
        h_upper = reconstruct_upper_head(
            swap_storage,
            conductance,
            h_lower,
        )
        gap = abs(h_upper - h_lower)
        bookkeeping = (
            swap_storage * (h_upper - H0)
            + modflow_storage * (h_lower - H0)
        )
        rows.append((conductance, h_upper, h_lower, gap))

        print(f"GC_DSW24_{label}_C_{conductance:g}_H_UPPER_M={h_upper:.17g}")
        print(f"GC_DSW24_{label}_C_{conductance:g}_H_INTERFACE_M={h_lower:.17g}")
        print(f"GC_DSW24_{label}_C_{conductance:g}_HEAD_GAP_M={gap:.17g}")
        print(f"GC_DSW24_{label}_C_{conductance:g}_BOOKKEEPING_M={bookkeeping:.17g}")

        require(
            math.isclose(
                bookkeeping,
                INPUT,
                rel_tol=0.0,
                abs_tol=MASS_TOL,
            ),
            f"{label} C={conductance} numerical bookkeeping",
        )
    return rows


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")

    consistent = run_case_family(
        libmf6,
        "CONSISTENT",
        swap_storage=0.10,
        modflow_storage=0.10,
        conductances=CONDUCTANCES,
    )
    gaps = [row[3] for row in consistent]
    require(
        all(b < a for a, b in zip(gaps[:-1], gaps[1:], strict=True)),
        f"consistent head gaps not monotone: {gaps}",
    )

    c_hi, h_upper_hi, h_interface_hi, gap_hi = consistent[-1]
    require(c_hi == 1000.0, "unexpected high-conductance row")
    require(
        abs(h_upper_hi - TARGET_HLINK) <= 1.0e-5,
        f"upper high-C head {h_upper_hi} not near target",
    )
    require(
        abs(h_interface_hi - TARGET_HLINK) <= 1.0e-5,
        f"interface high-C head {h_interface_hi} not near target",
    )
    require(
        gap_hi <= 1.0e-5,
        f"high-C consistent heads did not collapse: {gap_hi}",
    )
    require(
        consistent[0][3] > 1.0e-2,
        "finite-resistance control did not preserve distinct heads",
    )

    duplicate = run_case_family(
        libmf6,
        "DUPLICATE",
        swap_storage=0.20,
        modflow_storage=0.20,
        conductances=(1000.0,),
    )
    _, h_upper_dup, h_interface_dup, gap_dup = duplicate[0]
    duplicate_limit = 8.025

    require(
        abs(h_upper_dup - duplicate_limit) <= 1.0e-5,
        f"duplicate upper head {h_upper_dup} != high-C 8.025 limit",
    )
    require(
        abs(h_interface_dup - duplicate_limit) <= 1.0e-5,
        f"duplicate interface head {h_interface_dup} != high-C 8.025 limit",
    )
    require(
        gap_dup <= 1.0e-5,
        f"duplicate high-C heads did not collapse: {gap_dup}",
    )
    require(
        abs(h_upper_dup - TARGET_HLINK) >= 0.02,
        "duplicate ownership unexpectedly matched target h-link",
    )
    require(
        abs(h_interface_dup - TARGET_HLINK) >= 0.02,
        "duplicate interface unexpectedly matched target h-link",
    )

    # The declared one-volume h-link has S_phys=0.20.  If either nearly common
    # duplicate head were treated as that physical state, the geometric storage
    # increase would be only half the 0.010 m input.
    geometric_gain_from_duplicate_common_head = (
        0.20 * (((h_upper_dup + h_interface_dup) / 2.0) - H0)
    )
    require(
        math.isclose(
            geometric_gain_from_duplicate_common_head,
            0.005,
            rel_tol=0.0,
            abs_tol=1.0e-6,
        ),
        "duplicate common-head geometric signature",
    )
    print(
        "GC_DSW24_DUPLICATE_COMMON_HEAD_GEOMETRIC_GAIN_M="
        f"{geometric_gain_from_duplicate_common_head:.17g}"
    )

    print("GC_DSW24_FINITE_RESISTANCE_DISTINCT_STATE=PASS")
    print("GC_DSW24_ZERO_RESISTANCE_HEAD_COLLAPSE=PASS")
    print("GC_DSW24_CONSISTENT_STORAGE_HLINK_LIMIT=PASS")
    print("GC_DSW24_HEAD_EQUALITY_NOT_SUFFICIENT=PASS")
    print("GC_DSW24_DUPLICATE_STORAGE_NONEQUIVALENCE=PASS")
    print("GC_DSW24_LIVE_GATE=PASS")


if __name__ == "__main__":
    main()
