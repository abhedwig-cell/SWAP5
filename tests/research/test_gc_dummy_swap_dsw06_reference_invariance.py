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
RAIN_M_PER_DAY = 0.010
EXPECTED_HEAD_M = 8.05
REFS = (7.0, 8.0, 8.05, 9.0, 10.0)
TOL_M = 1.0e-8


def reanchored_term(href_m: float) -> tuple[float, float, float]:
    slope = -S_SWAP / DT_DAY
    q_ref = RAIN_M_PER_DAY + slope * (href_m - H0_M)
    hcof = slope
    rhs = hcof * href_m - q_ref
    return q_ref, hcof, rhs


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")

    terms: list[tuple[float, float]] = []
    heads: list[float] = []

    for href in REFS:
        q_ref, hcof, rhs = reanchored_term(href)
        terms.append((hcof, rhs))
        result = run_case(
            libmf6,
            f"reanchor_{href:.2f}",
            hcof_m2_per_day=hcof,
            rhs_m3_per_day=rhs,
            sy=S_MF,
            newton=False,
        )
        require(bool(result["converged"]), f"H_ref={href} did not converge: {result}")
        head = float(result["head_m"])
        heads.append(head)
        print(f"GC_DSW06_HREF_{href:.2f}_QREF={q_ref:.17g}")
        print(f"GC_DSW06_HREF_{href:.2f}_HCOF={hcof:.17g}")
        print(f"GC_DSW06_HREF_{href:.2f}_RHS={rhs:.17g}")
        print(f"GC_DSW06_HREF_{href:.2f}_HEAD_M={head:.17g}")

    hcof0, rhs0 = terms[0]
    for hcof, rhs in terms[1:]:
        require(
            math.isclose(hcof, hcof0, rel_tol=0.0, abs_tol=1.0e-14),
            "HCOF changed under reanchoring",
        )
        require(
            math.isclose(rhs, rhs0, rel_tol=0.0, abs_tol=1.0e-14),
            "RHS changed under exact affine reanchoring",
        )

    for href, head in zip(REFS, heads, strict=True):
        require(
            math.isclose(head, EXPECTED_HEAD_M, rel_tol=0.0, abs_tol=TOL_M),
            f"H_ref={href} changed physical solution: {head}",
        )

    spread = max(heads) - min(heads)
    print(f"GC_DSW06_HEAD_SPREAD_M={spread:.17g}")
    require(spread <= TOL_M, "reference point changed final head")

    print("GC_DSW06_TERM_REANCHOR_IDENTITY=PASS")
    print("GC_DSW06_REFERENCE_POINT_PHYSICS_INVARIANCE=PASS")
    print("GC_DSW06_LIVE_GATE=PASS")


if __name__ == "__main__":
    main()
