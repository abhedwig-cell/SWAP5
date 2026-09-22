from __future__ import annotations

import math
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "research"))

from test_gc_dummy_swap_dsw01_live_modflow import run_case, require


H0 = 8.0
S0 = 0.15
K = 1.0
INPUT = 0.010
DT = 1.0
RESIDUAL_TOL = 1.0e-12
HEAD_TOL = 1.0e-10


def storage_change_m(head_m: float) -> float:
    x = head_m - H0
    return S0 * x + 0.5 * K * x * x


def q_residual(head_m: float) -> float:
    return INPUT / DT - storage_change_m(head_m) / DT


def dq_dh(head_m: float) -> float:
    return -(S0 + K * (head_m - H0)) / DT


def exact_head() -> float:
    dx = (-S0 + math.sqrt(S0 * S0 + 2.0 * K * INPUT)) / K
    return H0 + dx


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")
    expected = exact_head()

    href = H0
    accepted = float("nan")
    for iteration in range(1, 21):
        qref = q_residual(href)
        hcof = dq_dh(href)
        rhs = hcof * href - qref

        result = run_case(
            libmf6,
            f"dsw09r_iter_{iteration}",
            hcof_m2_per_day=hcof,
            rhs_m3_per_day=rhs,
            sy=0.0,
            newton=False,
        )
        require(bool(result["converged"]), f"fresh solve {iteration} did not converge: {result}")
        head = float(result["head_m"])
        residual = q_residual(head)
        print(
            f"GC_DSW09R_ITER_{iteration}_HREF_M={href:.17g} "
            f"HEAD_M={head:.17g} Q_RESIDUAL={residual:.17g} "
            f"MF_ITERATIONS={int(result['iterations'])}"
        )

        if abs(residual) <= RESIDUAL_TOL:
            accepted = head
            break
        href = head

    require(math.isfinite(accepted), "fresh-solve reanchor replay did not close")
    require(iteration > 1, "fresh-solve diagnostic did not exercise reanchoring")
    require(
        math.isclose(accepted, expected, rel_tol=0.0, abs_tol=HEAD_TOL),
        f"fresh replay head {accepted} != {expected}",
    )
    require(abs(q_residual(accepted)) <= RESIDUAL_TOL, "fresh replay residual gate")

    print(f"GC_DSW09R_EXPECTED_HEAD_M={expected:.17g}")
    print(f"GC_DSW09R_FINAL_HEAD_M={accepted:.17g}")
    print(f"GC_DSW09R_FINAL_ERROR_M={accepted - expected:.17g}")
    print("GC_DSW09R_FRESH_SOLVE_PER_REANCHOR=PASS")
    print("GC_DSW09R_DIAGNOSTIC_GATE=PASS")


if __name__ == "__main__":
    main()
