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
DT = 1.0
H_D = 8.03
C_D = 0.20
TOL = 1.0e-10


def drain_rate(head_m: float) -> float:
    return C_D * max(0.0, head_m - H_D)


def run_inactive(libmf6: Path) -> float:
    recharge = 0.002
    result = run_case(
        libmf6,
        "drain_inactive",
        hcof_m2_per_day=0.0,
        rhs_m3_per_day=-recharge,
        sy=S,
        newton=False,
    )
    require(bool(result["converged"]), f"inactive drain did not converge: {result}")
    head = float(result["head_m"])
    expected = H0 + recharge * DT / S
    require(
        math.isclose(head, expected, rel_tol=0.0, abs_tol=TOL),
        f"inactive drain head {head} != {expected}",
    )
    require(head < H_D, "inactive drain crossed threshold")
    require(
        math.isclose(drain_rate(head), 0.0, rel_tol=0.0, abs_tol=1.0e-14),
        "inactive drain not zero",
    )
    print(f"GC_DSW13_INACTIVE_HEAD_M={head:.17g}")
    return head


def run_active(libmf6: Path) -> float:
    recharge = 0.020
    # Q(H) = R - C_d*(H-H_d)
    hcof = -C_D
    rhs = hcof * H_D - recharge
    result = run_case(
        libmf6,
        "drain_active",
        hcof_m2_per_day=hcof,
        rhs_m3_per_day=rhs,
        sy=S,
        newton=False,
    )
    require(bool(result["converged"]), f"active drain did not converge: {result}")
    head = float(result["head_m"])

    expected = (S * H0 / DT + recharge + C_D * H_D) / (
        S / DT + C_D
    )
    require(
        math.isclose(head, expected, rel_tol=0.0, abs_tol=TOL),
        f"active drain head {head} != {expected}",
    )
    require(head > H_D, "active drain did not activate")

    drain = drain_rate(head)
    storage_gain = S * (head - H0)
    require(
        math.isclose(
            storage_gain + drain * DT,
            recharge * DT,
            rel_tol=0.0,
            abs_tol=1.0e-12,
        ),
        "active drain mass balance",
    )

    print(f"GC_DSW13_ACTIVE_HEAD_M={head:.17g}")
    print(f"GC_DSW13_ACTIVE_DRAIN_M_PER_DAY={drain:.17g}")
    print(f"GC_DSW13_ACTIVE_STORAGE_GAIN_M={storage_gain:.17g}")
    return head


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")

    inactive = run_inactive(libmf6)
    active = run_active(libmf6)

    require(
        math.isclose(inactive, 8.01, rel_tol=0.0, abs_tol=TOL),
        "inactive exact oracle",
    )
    require(
        math.isclose(active, 8.065, rel_tol=0.0, abs_tol=TOL),
        "active exact oracle",
    )
    require(
        math.isclose(drain_rate(active), 0.007, rel_tol=0.0, abs_tol=1.0e-12),
        "active drain exact oracle",
    )

    print("GC_DSW13_INACTIVE_BRANCH=PASS")
    print("GC_DSW13_ACTIVE_BRANCH=PASS")
    print("GC_DSW13_DRAIN_STORAGE_MASS=PASS")
    print("GC_DSW13_PHYSICAL_SINK_CONDUCTANCE_CLASSIFIED=PASS")
    print("GC_DSW13_LIVE_GATE=PASS")


if __name__ == "__main__":
    main()
