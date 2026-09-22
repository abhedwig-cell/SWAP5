from __future__ import annotations

import math
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "research"))

from test_gc_dummy_swap_dsw01_live_modflow import run_case, require


H0 = 8.0
A = 0.20
J = -0.10
Q0 = 0.003
DT = 1.0
ROOT_HEAD = H0 + Q0 / (A - J)
HEAD_TOL = 1.0e-10
RATIO_TOL = 1.0e-8
NITER = 6

POLICIES = (
    ("PHYSICAL_J", -0.10, 0.0),
    ("INTERCEPT_ONLY", 0.0, -0.5),
    ("POSITIVE_HALF", 0.05, -1.0),
    ("POSITIVE_U", 0.10, -2.0),
)


def q_swap(head_m: float) -> float:
    return Q0 + J * (head_m - H0)


def solve_reanchored(
    libmf6: Path,
    policy_name: str,
    slope: float,
    h_anchor: float,
    iteration: int,
) -> float:
    q_anchor = q_swap(h_anchor)
    hcof = slope
    rhs = slope * h_anchor - q_anchor
    result = run_case(
        libmf6,
        f"dsw21_{policy_name.lower()}_{iteration}",
        hcof_m2_per_day=hcof,
        rhs_m3_per_day=rhs,
        sy=A,
        newton=False,
        initial_head_m=H0,
        dt_day=DT,
    )
    require(
        bool(result["converged"]),
        f"{policy_name} affine solve {iteration} did not converge: {result}",
    )
    return float(result["head_m"])


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")
    require(
        math.isclose(ROOT_HEAD, 8.01, rel_tol=0.0, abs_tol=1.0e-14),
        "physical root oracle drift",
    )

    for name, slope, expected_rho in POLICIES:
        h = H0
        errors = [h - ROOT_HEAD]
        heads = [h]
        for iteration in range(1, NITER + 1):
            h = solve_reanchored(libmf6, name, slope, h, iteration)
            heads.append(h)
            errors.append(h - ROOT_HEAD)
            print(
                f"GC_DSW21_{name}_ITER_{iteration}_HEAD_M={h:.17g} "
                f"ERROR_M={errors[-1]:.17g}"
            )

        if name == "PHYSICAL_J":
            require(
                math.isclose(heads[1], ROOT_HEAD, rel_tol=0.0, abs_tol=HEAD_TOL),
                f"physical derivative did not reach root in one solve: {heads}",
            )
            print("GC_DSW21_PHYSICAL_J_ONE_STEP_ROOT=PASS")
        else:
            ratios = []
            for before, after in zip(errors[:-1], errors[1:], strict=True):
                require(abs(before) > 1.0e-14, f"{name} zero denominator before fixed horizon")
                ratio = after / before
                ratios.append(ratio)
                require(
                    math.isclose(
                        ratio,
                        expected_rho,
                        rel_tol=0.0,
                        abs_tol=RATIO_TOL,
                    ),
                    f"{name} ratio {ratio} != {expected_rho}",
                )
            print(
                f"GC_DSW21_{name}_ERROR_RATIOS="
                + ",".join(f"{r:.17g}" for r in ratios)
            )
            print(f"GC_DSW21_{name}_RHO_MATCH=PASS")

    # Algebraically singular overlap: A-s=0. The physical problem still has
    # finite storage A and a unique root, but the published affine groundwater
    # equation has no unique solution.
    singular_s = A
    singular_anchor = H0
    singular_q = q_swap(singular_anchor)
    singular_result = run_case(
        libmf6,
        "dsw21_singular_overlap",
        hcof_m2_per_day=singular_s,
        rhs_m3_per_day=singular_s * singular_anchor - singular_q,
        sy=A,
        newton=False,
        initial_head_m=H0,
        dt_day=DT,
    )
    print(f"GC_DSW21_SINGULAR_STATUS={singular_result['status']}")
    print(
        "GC_DSW21_SINGULAR_CONVERGED="
        f"{1 if bool(singular_result['converged']) else 0}"
    )
    print(f"GC_DSW21_SINGULAR_ITERATIONS={int(singular_result['iterations'])}")
    if math.isfinite(float(singular_result["head_m"])):
        print(f"GC_DSW21_SINGULAR_HEAD_M={float(singular_result['head_m']):.17g}")
    else:
        print("GC_DSW21_SINGULAR_HEAD_M=NONFINITE_OR_UNAVAILABLE")
    require(
        not bool(singular_result["converged"]),
        f"singular A-s overlap unexpectedly certified a unique solve: {singular_result}",
    )

    print("GC_DSW21_FIXED_POINT_INDEPENDENT_OF_SLOPE_POLICY=PASS")
    print("GC_DSW21_ANALYTIC_ERROR_FACTORS=PASS")
    print("GC_DSW21_SINGULAR_OVERLAP=PASS")
    print("GC_DSW21_LIVE_GATE=PASS")


if __name__ == "__main__":
    main()
