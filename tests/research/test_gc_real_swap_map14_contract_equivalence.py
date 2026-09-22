from __future__ import annotations

import math
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "research"))

from test_gc_dummy_swap_dsw01_live_modflow import run_case, require


H0 = 8.0
DT = 1.0
INPUT = 0.010
S_COLUMN = 0.10
S_GW = 0.10
S_TOTAL = S_COLUMN + S_GW
EXPECTED_SHARED = 8.05
HEAD_TOL = 1.0e-10
MASS_TOL = 1.0e-12


def run_shared_phreatic(libmf6: Path) -> float:
    result = run_case(
        libmf6,
        "map14_shared_phreatic",
        hcof_m2_per_day=0.0,
        rhs_m3_per_day=-INPUT,
        sy=S_TOTAL,
        newton=False,
    )
    require(bool(result["converged"]), f"shared-phreatic solve failed: {result}")
    head = float(result["head_m"])
    storage = S_TOTAL * (head - H0)
    require(
        math.isclose(head, EXPECTED_SHARED, rel_tol=0.0, abs_tol=HEAD_TOL),
        f"shared-phreatic head {head}",
    )
    require(
        math.isclose(storage, INPUT, rel_tol=0.0, abs_tol=MASS_TOL),
        f"shared-phreatic mass {storage}",
    )
    print(f"GC_MAP14_SHARED_HEAD_M={head:.17g}")
    print(f"GC_MAP14_SHARED_STORAGE_CHANGE_M={storage:.17g}")
    return head


def run_zero_resistance_boundary(libmf6: Path) -> float:
    # Mass-complete column exchange:
    #   E_bottom(H) = I - S_column*(H-H0)/dt
    # MODFLOW owns only S_gw:
    #   S_gw*(H-H0)/dt = E_bottom(H)
    hcof = -S_COLUMN / DT
    rhs = hcof * H0 - INPUT / DT
    result = run_case(
        libmf6,
        "map14_zero_resistance_boundary",
        hcof_m2_per_day=hcof,
        rhs_m3_per_day=rhs,
        sy=S_GW,
        newton=False,
    )
    require(bool(result["converged"]), f"zero-resistance boundary solve failed: {result}")
    head = float(result["head_m"])
    column_storage = S_COLUMN * (head - H0)
    groundwater_storage = S_GW * (head - H0)
    bottom_exchange = INPUT - column_storage

    require(
        math.isclose(head, EXPECTED_SHARED, rel_tol=0.0, abs_tol=HEAD_TOL),
        f"zero-resistance boundary head {head}",
    )
    require(
        math.isclose(groundwater_storage, bottom_exchange, rel_tol=0.0, abs_tol=MASS_TOL),
        "groundwater balance mismatch",
    )
    require(
        math.isclose(
            column_storage + groundwater_storage,
            INPUT,
            rel_tol=0.0,
            abs_tol=MASS_TOL,
        ),
        "zero-resistance total mass mismatch",
    )

    print(f"GC_MAP14_ZERO_R_HEAD_M={head:.17g}")
    print(f"GC_MAP14_ZERO_R_COLUMN_STORAGE_M={column_storage:.17g}")
    print(f"GC_MAP14_ZERO_R_GW_STORAGE_M={groundwater_storage:.17g}")
    print(f"GC_MAP14_ZERO_R_BOTTOM_EXCHANGE_M={bottom_exchange:.17g}")
    return head


def finite_resistance_closed_form(c_per_day: float) -> tuple[float, float, float, float, float]:
    a = S_COLUMN / DT
    beta = c_per_day / (a + c_per_day)
    dh_gw = beta * INPUT / (S_GW / DT + beta * a)
    h_gw = H0 + dh_gw
    h_column = (a * H0 + INPUT + c_per_day * h_gw) / (a + c_per_day)
    q_exchange = c_per_day * (h_column - h_gw)
    hcof = -beta * a
    rhs = hcof * H0 - beta * INPUT
    return h_column, h_gw, q_exchange, hcof, rhs


def run_finite_resistance(libmf6: Path, c_per_day: float, label: str) -> tuple[float, float]:
    h_column_expected, h_gw_expected, q_expected, hcof, rhs = finite_resistance_closed_form(c_per_day)
    result = run_case(
        libmf6,
        f"map14_{label}",
        hcof_m2_per_day=hcof,
        rhs_m3_per_day=rhs,
        sy=S_GW,
        newton=False,
    )
    require(bool(result["converged"]), f"{label} solve failed: {result}")
    h_gw = float(result["head_m"])
    a = S_COLUMN / DT
    h_column = (a * H0 + INPUT + c_per_day * h_gw) / (a + c_per_day)
    q_exchange = c_per_day * (h_column - h_gw)
    total_storage = (
        S_COLUMN * (h_column - H0)
        + S_GW * (h_gw - H0)
    )

    require(
        math.isclose(h_gw, h_gw_expected, rel_tol=0.0, abs_tol=HEAD_TOL),
        f"{label} groundwater head {h_gw}",
    )
    require(
        math.isclose(h_column, h_column_expected, rel_tol=0.0, abs_tol=HEAD_TOL),
        f"{label} column head {h_column}",
    )
    require(
        math.isclose(q_exchange, q_expected, rel_tol=0.0, abs_tol=1.0e-10),
        f"{label} exchange {q_exchange}",
    )
    require(
        math.isclose(total_storage, INPUT, rel_tol=0.0, abs_tol=MASS_TOL),
        f"{label} mass {total_storage}",
    )

    print(f"GC_MAP14_{label}_C_PER_DAY={c_per_day:.17g}")
    print(f"GC_MAP14_{label}_H_COLUMN_M={h_column:.17g}")
    print(f"GC_MAP14_{label}_H_GW_M={h_gw:.17g}")
    print(f"GC_MAP14_{label}_HEAD_GAP_M={abs(h_column-h_gw):.17g}")
    print(f"GC_MAP14_{label}_EXCHANGE_M_PER_DAY={q_exchange:.17g}")
    return h_column, h_gw


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")

    h_shared = run_shared_phreatic(libmf6)
    h_zero = run_zero_resistance_boundary(libmf6)
    require(
        math.isclose(h_shared, h_zero, rel_tol=0.0, abs_tol=HEAD_TOL),
        "shared-state and zero-resistance boundary formulations differ",
    )

    h_column, h_gw = run_finite_resistance(libmf6, 0.10, "FINITE_R")
    require(abs(h_column - h_gw) > 1.0e-3, "finite-resistance states unexpectedly collapsed")
    require(abs(h_column - EXPECTED_SHARED) > 1.0e-3, "finite-resistance column head equals shared state")
    require(abs(h_gw - EXPECTED_SHARED) > 1.0e-3, "finite-resistance groundwater head equals shared state")

    h_column_hi, h_gw_hi = run_finite_resistance(libmf6, 1000.0, "HIGH_C")
    require(
        abs(h_column_hi - EXPECTED_SHARED) < 1.0e-5
        and abs(h_gw_hi - EXPECTED_SHARED) < 1.0e-5,
        "high-conductance limit did not approach shared state",
    )

    print("GC_MAP14_SHARED_AND_ZERO_R_EQUIVALENT=PASS")
    print("GC_MAP14_FINITE_R_NONEQUIVALENT=PASS")
    print("GC_MAP14_HIGH_C_SHARED_LIMIT=PASS")
    print("GC_MAP14_MASS_LEDGER=PASS")
    print("GC_MAP14_LIVE_GATE=PASS")


if __name__ == "__main__":
    main()
