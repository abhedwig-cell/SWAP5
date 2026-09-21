from __future__ import annotations

import math
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "research"))

from test_gc_dummy_swap_dsw01_live_modflow import run_case, require


H_BEFORE = 8.033333333333333
W_BEFORE = 0.013333333333333334
DT = 0.5
S = 0.20
K = 1.0
EXPECTED_W_AFTER = 0.008888888888888889
EXPECTED_TRANSFER = 0.0044444444444444444
EXPECTED_HEAD = 8.055555555555555
HEAD_TOL = 1.0e-10


def run_variant(libmf6: Path, label: str, under_relaxation: str | None) -> dict[str, object]:
    w_after = W_BEFORE / (1.0 + K * DT)
    transfer = K * DT * w_after
    rate = transfer / DT
    result = run_case(
        libmf6,
        f"dsw15v_{label.lower()}",
        hcof_m2_per_day=0.0,
        rhs_m3_per_day=-rate,
        sy=S,
        newton=False,
        initial_head_m=H_BEFORE,
        dt_day=DT,
        ims_complexity="MODERATE",
        ims_under_relaxation=under_relaxation,
    )
    head = float(result["head_m"])
    storage_gain = S * (head - H_BEFORE)
    mass_error = storage_gain - transfer
    print(f"GC_DSW15V_{label}_STATUS={result['status']}")
    print(f"GC_DSW15V_{label}_CONVERGED={1 if result['converged'] else 0}")
    print(f"GC_DSW15V_{label}_HEAD_M={head:.17g}")
    print(f"GC_DSW15V_{label}_HEAD_ERROR_M={head - EXPECTED_HEAD:.17g}")
    print(f"GC_DSW15V_{label}_STORAGE_GAIN_M={storage_gain:.17g}")
    print(f"GC_DSW15V_{label}_EXPECTED_TRANSFER_M={transfer:.17g}")
    print(f"GC_DSW15V_{label}_MASS_ERROR_M={mass_error:.17g}")
    print(f"GC_DSW15V_{label}_ITERATIONS={int(result['iterations'])}")
    return {
        **result,
        "storage_gain": storage_gain,
        "transfer": transfer,
        "mass_error": mass_error,
    }


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")
    require(
        math.isclose(
            W_BEFORE / (1.0 + K * DT),
            EXPECTED_W_AFTER,
            rel_tol=0.0,
            abs_tol=1.0e-15,
        ),
        "diagnostic memory algebra changed",
    )
    require(
        math.isclose(
            K * DT * EXPECTED_W_AFTER,
            EXPECTED_TRANSFER,
            rel_tol=0.0,
            abs_tol=1.0e-15,
        ),
        "diagnostic transfer algebra changed",
    )

    default = run_variant(libmf6, "MODERATE_DEFAULT", None)
    no_ur = run_variant(libmf6, "MODERATE_NO_UR", "NONE")

    require(
        math.isclose(
            float(default["head_m"]),
            EXPECTED_HEAD,
            rel_tol=0.0,
            abs_tol=HEAD_TOL,
        ),
        f"default head outside physical head oracle: {default}",
    )
    require(
        bool(no_ur["converged"]),
        f"MODERATE_NO_UR did not converge: {no_ur}",
    )
    require(
        math.isclose(
            float(no_ur["head_m"]),
            EXPECTED_HEAD,
            rel_tol=0.0,
            abs_tol=HEAD_TOL,
        ),
        f"MODERATE_NO_UR head mismatch: {no_ur}",
    )

    print("GC_DSW15V_MEMORY_ALGEBRA_FIXED=PASS")
    print("GC_DSW15V_DEFAULT_PHYSICAL_HEAD_RECORDED=PASS")
    print("GC_DSW15V_NO_UNDER_RELAXATION_CHARACTERIZATION=PASS")
    print("GC_DSW15V_DIAGNOSTIC_GATE=PASS")


if __name__ == "__main__":
    main()
