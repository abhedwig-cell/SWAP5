from __future__ import annotations

import math
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "research"))

from test_gc_dummy_swap_dsw01_live_modflow import run_case, require


H0 = 8.0
S = 0.20
R_ATM = 0.020
Q_MF = 0.010
H_ET = 8.02
A_ET = 0.10
H_D = 8.04
C_D = 0.20
DT = 1.0
EXPECTED = 8.08
TOL = 1.0e-10


def et(head: float) -> float:
    return A_ET * max(0.0, head - H_ET)


def drain(head: float) -> float:
    return C_D * max(0.0, head - H_D)


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")

    # Both sink branches are pre-registered as active:
    # Q_api = R_atm - a(H-Het) - Cd(H-Hd)
    hcof = -(A_ET + C_D)
    rhs = -R_ATM - A_ET * H_ET - C_D * H_D

    result = run_case(
        libmf6,
        "composed_et_drain",
        hcof_m2_per_day=hcof,
        rhs_m3_per_day=rhs,
        sy=S,
        newton=False,
        well_rate_m3_per_day=Q_MF,
    )
    require(bool(result["converged"]), f"composed case did not converge: {result}")
    head = float(result["head_m"])

    require(
        math.isclose(head, EXPECTED, rel_tol=0.0, abs_tol=TOL),
        f"composed head {head} != {EXPECTED}",
    )
    require(head > H_ET and head > H_D, "pre-registered active branches not active")

    et_loss = et(head) * DT
    drain_loss = drain(head) * DT
    storage_gain = S * (head - H0)
    total_input = (R_ATM + Q_MF) * DT

    require(
        math.isclose(et_loss, 0.006, rel_tol=0.0, abs_tol=1.0e-12),
        f"ET term {et_loss}",
    )
    require(
        math.isclose(drain_loss, 0.008, rel_tol=0.0, abs_tol=1.0e-12),
        f"drain term {drain_loss}",
    )
    require(
        math.isclose(storage_gain, 0.016, rel_tol=0.0, abs_tol=1.0e-12),
        f"storage term {storage_gain}",
    )
    require(
        math.isclose(
            storage_gain + et_loss + drain_loss,
            total_input,
            rel_tol=0.0,
            abs_tol=1.0e-12,
        ),
        "composed water balance",
    )

    print(f"GC_DSW14_FINAL_HEAD_M={head:.17g}")
    print(f"GC_DSW14_STORAGE_GAIN_M={storage_gain:.17g}")
    print(f"GC_DSW14_ET_LOSS_M={et_loss:.17g}")
    print(f"GC_DSW14_DRAIN_LOSS_M={drain_loss:.17g}")
    print(f"GC_DSW14_TOTAL_INPUT_M={total_input:.17g}")
    print("GC_DSW14_COMPOSED_MASS=PASS")
    print("GC_DSW14_COMPONENT_ACCOUNTING=PASS")
    print("GC_DSW14_LIVE_GATE=PASS")


if __name__ == "__main__":
    main()
