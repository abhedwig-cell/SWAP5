from __future__ import annotations

import math
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "research"))

from test_gc_dummy_swap_dsw01_live_modflow import run_case, require


H0 = 8.0035
DT = 0.13
S_SWAP = 0.10
S_MF = 0.10
RECHARGE = 0.010
EXPECTED = 8.01
HEAD_TOL = 1.0e-10

VARIANTS = (
    ("STRICT_1E15", 1.0e-15),
    ("STRICT_1E14", 1.0e-14),
    ("STRICT_1E13", 1.0e-13),
)


def run_variant(libmf6: Path, label: str, rclose: float) -> dict[str, object]:
    hcof = -S_SWAP / DT
    rhs = hcof * H0 - RECHARGE
    result = run_case(
        libmf6,
        f"dsw05w_{label.lower()}",
        hcof_m2_per_day=hcof,
        rhs_m3_per_day=rhs,
        sy=S_MF,
        newton=False,
        initial_head_m=H0,
        dt_day=DT,
        ims_complexity="MODERATE",
        ims_under_relaxation="NONE",
        ims_rclose=rclose,
    )
    head = float(result["head_m"])
    print(f"GC_DSW05W_{label}_RCLOSE={rclose:.17g}")
    print(f"GC_DSW05W_{label}_STATUS={result['status']}")
    print(f"GC_DSW05W_{label}_CONVERGED={1 if result['converged'] else 0}")
    print(f"GC_DSW05W_{label}_HEAD_M={head:.17g}")
    print(f"GC_DSW05W_{label}_HEAD_ERROR_M={head - EXPECTED:.17g}")
    print(f"GC_DSW05W_{label}_ITERATIONS={int(result['iterations'])}")
    return result


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")

    results = {
        label: run_variant(libmf6, label, rclose)
        for label, rclose in VARIANTS
    }

    for label, result in results.items():
        require(
            math.isclose(
                float(result["head_m"]),
                EXPECTED,
                rel_tol=0.0,
                abs_tol=HEAD_TOL,
            ),
            f"{label} physical head mismatch: {result}",
        )

    relaxed = results["STRICT_1E13"]
    require(
        bool(relaxed["converged"]),
        f"1e-13 residual closure did not certify the exact affine solve: {relaxed}",
    )

    print("GC_DSW05W_PHYSICAL_HEAD_INVARIANT=PASS")
    print("GC_DSW05W_1E13_RESIDUAL_CERTIFICATION=PASS")
    print("GC_DSW05W_DIAGNOSTIC_GATE=PASS")


if __name__ == "__main__":
    main()
