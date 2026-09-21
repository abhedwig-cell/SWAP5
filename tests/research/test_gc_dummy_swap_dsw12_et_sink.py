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
H_ET = 8.02
A_ET = 0.10
TOL = 1.0e-10


def et_rate(head_m: float) -> float:
    return A_ET * max(0.0, head_m - H_ET)


def inactive_case(libmf6: Path) -> float:
    recharge = 0.002
    result = run_case(
        libmf6,
        "et_inactive",
        hcof_m2_per_day=0.0,
        rhs_m3_per_day=-recharge,
        sy=S,
        newton=False,
    )
    require(bool(result["converged"]), f"inactive ET did not converge: {result}")
    head = float(result["head_m"])
    expected = H0 + recharge * DT / S
    require(
        math.isclose(head, expected, rel_tol=0.0, abs_tol=TOL),
        f"inactive ET head {head} != {expected}",
    )
    require(head < H_ET, "inactive ET case crossed ET threshold")
    require(
        math.isclose(et_rate(head), 0.0, rel_tol=0.0, abs_tol=1.0e-14),
        "inactive ET not zero",
    )
    print(f"GC_DSW12_INACTIVE_HEAD_M={head:.17g}")
    return head


def active_case(libmf6: Path) -> float:
    recharge = 0.020

    # Active branch:
    #   Q(H) = R - a*(H-H_ET)
    hcof = -A_ET
    rhs = hcof * H_ET - recharge
    result = run_case(
        libmf6,
        "et_active",
        hcof_m2_per_day=hcof,
        rhs_m3_per_day=rhs,
        sy=S,
        newton=False,
    )
    require(bool(result["converged"]), f"active ET did not converge: {result}")
    head = float(result["head_m"])

    expected = (S * H0 / DT + recharge + A_ET * H_ET) / (
        S / DT + A_ET
    )
    require(
        math.isclose(head, expected, rel_tol=0.0, abs_tol=TOL),
        f"active ET head {head} != {expected}",
    )
    require(head > H_ET, "active ET case did not cross threshold")

    et = et_rate(head)
    storage_gain = S * (head - H0)
    recharge_volume = recharge * DT
    et_volume = et * DT
    require(
        math.isclose(
            storage_gain + et_volume,
            recharge_volume,
            rel_tol=0.0,
            abs_tol=1.0e-12,
        ),
        "active ET mass balance",
    )

    print(f"GC_DSW12_ACTIVE_HEAD_M={head:.17g}")
    print(f"GC_DSW12_ACTIVE_ET_M_PER_DAY={et:.17g}")
    print(f"GC_DSW12_ACTIVE_STORAGE_GAIN_M={storage_gain:.17g}")
    return head


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")

    inactive = inactive_case(libmf6)
    active = active_case(libmf6)

    require(active > inactive, "active forcing did not produce larger shared head")
    print("GC_DSW12_INACTIVE_BRANCH=PASS")
    print("GC_DSW12_ACTIVE_BRANCH=PASS")
    print("GC_DSW12_ET_STORAGE_MASS=PASS")
    print("GC_DSW12_SINK_TANGENT_DISTINCT_FROM_STORAGE=PASS")
    print("GC_DSW12_LIVE_GATE=PASS")


if __name__ == "__main__":
    main()
