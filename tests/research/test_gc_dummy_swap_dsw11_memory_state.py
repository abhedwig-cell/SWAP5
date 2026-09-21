from __future__ import annotations

import math
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "research"))

from test_gc_dummy_swap_dsw01_live_modflow import run_case, require


H0 = 8.0
S_GW = 0.20
K_RELAX = 1.0
GAMMA = 0.10
DT = 1.0
TOL = 1.0e-10


def exact_case(w0_m: float) -> tuple[float, float, float]:
    # q_mem = k/(1+k dt) * (w0 - gamma*dh)
    beta = K_RELAX / (1.0 + K_RELAX * DT)
    dh = beta * w0_m / (S_GW / DT + beta * GAMMA)
    h1 = H0 + dh
    w1 = (
        w0_m + K_RELAX * DT * GAMMA * dh
    ) / (1.0 + K_RELAX * DT)
    transfer = w0_m - w1
    return h1, w1, transfer


def api_term(w0_m: float) -> tuple[float, float]:
    beta = K_RELAX / (1.0 + K_RELAX * DT)
    hcof = -beta * GAMMA
    q_ref = beta * w0_m
    rhs = hcof * H0 - q_ref
    return hcof, rhs


def run_memory_case(libmf6: Path, name: str, w0_m: float) -> tuple[float, float, float]:
    expected_head, expected_w1, expected_transfer = exact_case(w0_m)
    hcof, rhs = api_term(w0_m)

    result = run_case(
        libmf6,
        name,
        hcof_m2_per_day=hcof,
        rhs_m3_per_day=rhs,
        sy=S_GW,
        newton=False,
    )
    require(bool(result["converged"]), f"{name} did not converge: {result}")
    head = float(result["head_m"])

    require(
        math.isclose(head, expected_head, rel_tol=0.0, abs_tol=TOL),
        f"{name} head {head} != {expected_head}",
    )

    dh = head - H0
    w1 = (
        w0_m + K_RELAX * DT * GAMMA * dh
    ) / (1.0 + K_RELAX * DT)
    transfer = w0_m - w1
    gw_gain = S_GW * dh

    require(
        math.isclose(w1, expected_w1, rel_tol=0.0, abs_tol=1.0e-12),
        f"{name} memory state mismatch",
    )
    require(
        math.isclose(transfer, expected_transfer, rel_tol=0.0, abs_tol=1.0e-12),
        f"{name} transfer mismatch",
    )
    require(
        math.isclose(gw_gain, transfer, rel_tol=0.0, abs_tol=1.0e-12),
        f"{name} groundwater gain != memory loss",
    )
    require(
        math.isclose(S_GW * dh + w1, w0_m, rel_tol=0.0, abs_tol=1.0e-12),
        f"{name} total water not conserved",
    )

    print(f"GC_DSW11_{name.upper()}_HEAD_M={head:.17g}")
    print(f"GC_DSW11_{name.upper()}_MEMORY_FINAL_M={w1:.17g}")
    print(f"GC_DSW11_{name.upper()}_TRANSFER_M={transfer:.17g}")
    return head, w1, transfer


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")

    dry_head, _, _ = run_memory_case(libmf6, "dry_memory", 0.0)
    wet_head, wet_w1, wet_transfer = run_memory_case(libmf6, "wet_memory", 0.02)

    require(
        math.isclose(dry_head, 8.0, rel_tol=0.0, abs_tol=TOL),
        "dry memory case changed head",
    )
    require(
        math.isclose(wet_head, 8.04, rel_tol=0.0, abs_tol=TOL),
        f"wet memory head {wet_head} != 8.04",
    )
    require(
        math.isclose(wet_w1, 0.012, rel_tol=0.0, abs_tol=1.0e-12),
        "wet memory final state",
    )
    require(
        math.isclose(wet_transfer, 0.008, rel_tol=0.0, abs_tol=1.0e-12),
        "wet memory transfer",
    )
    require(
        wet_head > dry_head,
        "different memory states did not change the response",
    )

    print("GC_DSW11_SAME_HEAD_DIFFERENT_MEMORY_RESPONSE=PASS")
    print("GC_DSW11_MEMORY_GW_MASS_TRANSFER=PASS")
    print("GC_DSW11_HEAD_NOT_COMPLETE_COLUMN_STATE=PASS")
    print("GC_DSW11_LIVE_GATE=PASS")


if __name__ == "__main__":
    main()
