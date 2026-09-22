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
TOL = 1.0e-10


def run_variant(libmf6: Path, label: str, under_relaxation: str | None) -> dict[str, object]:
    hcof = -S_SWAP / DT
    rhs = hcof * H0 - RECHARGE
    result = run_case(
        libmf6,
        f"dsw05v_{label.lower()}",
        hcof_m2_per_day=hcof,
        rhs_m3_per_day=rhs,
        sy=S_MF,
        newton=False,
        initial_head_m=H0,
        dt_day=DT,
        ims_complexity="MODERATE",
        ims_under_relaxation=under_relaxation,
    )
    head = float(result["head_m"])
    print(f"GC_DSW05V_{label}_STATUS={result['status']}")
    print(f"GC_DSW05V_{label}_CONVERGED={1 if result['converged'] else 0}")
    print(f"GC_DSW05V_{label}_HEAD_M={head:.17g}")
    print(f"GC_DSW05V_{label}_HEAD_ERROR_M={head - EXPECTED:.17g}")
    print(f"GC_DSW05V_{label}_ITERATIONS={int(result['iterations'])}")
    return result


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")

    default = run_variant(libmf6, "MODERATE_DEFAULT", None)
    no_ur = run_variant(libmf6, "MODERATE_NO_UR", "NONE")

    require(
        math.isclose(float(default["head_m"]), EXPECTED, rel_tol=0.0, abs_tol=TOL),
        f"default head is not the physical oracle: {default}",
    )
    require(
        bool(no_ur["converged"]),
        f"MODERATE_NO_UR did not converge: {no_ur}",
    )
    require(
        math.isclose(float(no_ur["head_m"]), EXPECTED, rel_tol=0.0, abs_tol=TOL),
        f"MODERATE_NO_UR head mismatch: {no_ur}",
    )

    print("GC_DSW05V_DEFAULT_PHYSICAL_HEAD_RECORDED=PASS")
    print("GC_DSW05V_NO_UNDER_RELAXATION_STRICT_GATE=PASS")
    print("GC_DSW05V_DIAGNOSTIC_GATE=PASS")


if __name__ == "__main__":
    main()
