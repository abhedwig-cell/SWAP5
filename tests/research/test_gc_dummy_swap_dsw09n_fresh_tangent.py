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
OFFSETS = (1.0e-6, 1.0e-8, 1.0e-10, 1.0e-11, 1.0e-12)
OBSERVED_STALL_HEAD = 8.05615528129362


def storage_change_m(head_m: float) -> float:
    x = head_m - H0
    return S0 * x + 0.5 * K * x * x


def q_residual_m_per_day(head_m: float) -> float:
    return INPUT / DT - storage_change_m(head_m) / DT


def dq_dh_per_day(head_m: float) -> float:
    return -(S0 + K * (head_m - H0)) / DT


def exact_head_m() -> float:
    dx = (-S0 + math.sqrt(S0 * S0 + 2.0 * K * INPUT)) / K
    return H0 + dx


def fresh_tangent_case(
    libmf6: Path,
    name: str,
    href: float,
) -> dict[str, object]:
    q_ref = q_residual_m_per_day(href)
    hcof = dq_dh_per_day(href)
    rhs = hcof * href - q_ref
    affine_root = rhs / hcof

    result = run_case(
        libmf6,
        name,
        hcof_m2_per_day=hcof,
        rhs_m3_per_day=rhs,
        sy=0.0,
        newton=False,
    )
    result["href"] = href
    result["q_ref"] = q_ref
    result["hcof"] = hcof
    result["rhs"] = rhs
    result["affine_root"] = affine_root
    return result


def print_case(label: str, result: dict[str, object]) -> None:
    print(f"GC_DSW09N_{label}_HREF_M={float(result['href']):.17g}")
    print(f"GC_DSW09N_{label}_QREF={float(result['q_ref']):.17g}")
    print(f"GC_DSW09N_{label}_AFFINE_ROOT_M={float(result['affine_root']):.17g}")
    print(f"GC_DSW09N_{label}_STATUS={result['status']}")
    print(f"GC_DSW09N_{label}_CONVERGED={1 if result['converged'] else 0}")
    if math.isfinite(float(result["head_m"])):
        print(f"GC_DSW09N_{label}_HEAD_M={float(result['head_m']):.17g}")
        print(
            f"GC_DSW09N_{label}_HEAD_MINUS_AFFINE_ROOT_M="
            f"{float(result['head_m']) - float(result['affine_root']):.17g}"
        )
    else:
        print(f"GC_DSW09N_{label}_HEAD_M=NONFINITE_OR_UNAVAILABLE")
    print(f"GC_DSW09N_{label}_ITERATIONS={int(result['iterations'])}")


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")
    exact = exact_head_m()
    print(f"GC_DSW09N_EXACT_NONLINEAR_HEAD_M={exact:.17g}")

    results: dict[float, dict[str, object]] = {}
    for offset in OFFSETS:
        href = exact + offset
        label = f"OFFSET_{offset:.0e}".replace("-", "M")
        result = fresh_tangent_case(libmf6, label.lower(), href)
        results[offset] = result
        print_case(label, result)

    stall = fresh_tangent_case(
        libmf6,
        "observed_stall_replay",
        OBSERVED_STALL_HEAD,
    )
    print_case("OBSERVED_STALL_REPLAY", stall)

    # Controls chosen before this diagnostic run: corrections at 1e-6 and
    # 1e-8 m must be comfortably above any expected double-precision floor.
    for offset in (1.0e-6, 1.0e-8):
        result = results[offset]
        require(
            bool(result["converged"]),
            f"fresh tangent at offset {offset} did not converge: {result}",
        )
        require(
            math.isclose(
                float(result["head_m"]),
                float(result["affine_root"]),
                rel_tol=0.0,
                abs_tol=1.0e-10,
            ),
            f"fresh tangent root mismatch at offset {offset}",
        )

    print("GC_DSW09N_FRESH_SESSION_COARSE_RESOLUTION_CONTROL=PASS")
    print("GC_DSW09N_SMALL_OFFSET_CHARACTERIZATION_RECORDED=PASS")
    print("GC_DSW09N_DIAGNOSTIC_GATE=PASS")


if __name__ == "__main__":
    main()
