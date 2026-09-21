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
ANCHOR = 8.056155281280944
HEAD_TOL = 1.0e-10


def storage_change(head: float) -> float:
    x = head - H0
    return S0 * x + 0.5 * K * x * x


def residual(head: float) -> float:
    return INPUT - storage_change(head)


def tangent(head: float) -> float:
    return -(S0 + K * (head - H0))


def affine_term() -> tuple[float, float, float]:
    qref = residual(ANCHOR)
    hcof = tangent(ANCHOR)
    rhs = hcof * ANCHOR - qref
    affine_root = rhs / hcof
    return hcof, rhs, affine_root


def run_variant(
    libmf6: Path,
    name: str,
    initial_head: float,
    rclose: float,
) -> dict[str, object]:
    hcof, rhs, affine_root = affine_term()
    result = run_case(
        libmf6,
        f"dsw09y_{name.lower()}",
        hcof_m2_per_day=hcof,
        rhs_m3_per_day=rhs,
        sy=0.0,
        newton=False,
        initial_head_m=initial_head,
        ims_complexity="MODERATE",
        ims_under_relaxation="NONE",
        ims_rclose=rclose,
    )
    head = float(result["head_m"])
    print(f"GC_DSW09Y_{name}_INITIAL_HEAD_M={initial_head:.17g}")
    print(f"GC_DSW09Y_{name}_RCLOSE={rclose:.17g}")
    print(f"GC_DSW09Y_{name}_AFFINE_ROOT_M={affine_root:.17g}")
    print(f"GC_DSW09Y_{name}_HEAD_M={head:.17g}")
    print(f"GC_DSW09Y_{name}_HEAD_ERROR_M={head-affine_root:.17g}")
    print(f"GC_DSW09Y_{name}_CONVERGED={1 if result['converged'] else 0}")
    print(f"GC_DSW09Y_{name}_ITERATIONS={int(result['iterations'])}")
    return {**result, "affine_root": affine_root}


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")

    qref = residual(ANCHOR)
    print(f"GC_DSW09Y_ANCHOR_QREF={qref:.17g}")

    far = run_variant(libmf6, "FAR_START_R1E15", H0, 1.0e-15)
    near_strict = run_variant(libmf6, "NEAR_START_R1E15", ANCHOR, 1.0e-15)
    near_relaxed = run_variant(libmf6, "NEAR_START_R1E13", ANCHOR, 1.0e-13)

    root = float(far["affine_root"])
    require(bool(far["converged"]), f"far strict start did not converge: {far}")
    require(
        math.isclose(float(far["head_m"]), root, rel_tol=0.0, abs_tol=HEAD_TOL),
        f"far strict root mismatch: {far}",
    )

    require(
        not bool(near_strict["converged"]),
        f"near strict start unexpectedly certified: {near_strict}",
    )
    require(
        math.isclose(
            float(near_strict["head_m"]), root, rel_tol=0.0, abs_tol=HEAD_TOL
        ),
        f"near strict physical head mismatch: {near_strict}",
    )

    require(
        bool(near_relaxed["converged"]),
        f"near rclose=1e-13 did not certify: {near_relaxed}",
    )
    require(
        math.isclose(
            float(near_relaxed["head_m"]), root, rel_tol=0.0, abs_tol=HEAD_TOL
        ),
        f"near rclose=1e-13 root mismatch: {near_relaxed}",
    )

    print("GC_DSW09Y_FAR_START_STRICT_CERTIFIES=PASS")
    print("GC_DSW09Y_NEAR_START_STRICT_STAGNATION_REPRODUCED=PASS")
    print("GC_DSW09Y_NEAR_START_R1E13_CERTIFIES=PASS")
    print("GC_DSW09Y_DIAGNOSTIC_GATE=PASS")


if __name__ == "__main__":
    main()
