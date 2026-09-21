from __future__ import annotations

import math
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "research"))

from test_gc_dummy_swap_dsw01_live_modflow import run_case, require


H0 = 8.0
S_DUMMY = 0.10
S_MF = 0.10
RAIN = 0.010
DT = 1.0
CONDUCTANCES = (0.001, 0.01, 0.1, 1.0, 10.0, 1000.0)
HEAD_TOL = 1.0e-8
MASS_TOL = 1.0e-12


def closed_form(conductance_per_day: float) -> tuple[float, float, float, float, float]:
    c = conductance_per_day
    a = S_DUMMY / DT
    beta = c / (a + c)

    dh_mf = beta * RAIN / (S_MF / DT + beta * a)
    h_mf = H0 + dh_mf
    h_dummy = (a * H0 + RAIN + c * h_mf) / (a + c)
    q_ex = c * (h_dummy - h_mf)

    hcof = -beta * a
    rhs = hcof * H0 - beta * RAIN
    return h_dummy, h_mf, q_ex, hcof, rhs


def require_close(actual: float, expected: float, name: str, tol: float) -> None:
    if not math.isclose(actual, expected, rel_tol=0.0, abs_tol=tol):
        raise AssertionError(f"{name}: {actual:.17g} != {expected:.17g}")


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")

    head_differences: list[float] = []
    last_h_mf = float("nan")

    for conductance in CONDUCTANCES:
        h_dummy, h_mf_expected, q_ex_expected, hcof, rhs = closed_form(conductance)

        result = run_case(
            libmf6,
            f"q_link_c_{conductance:g}",
            hcof_m2_per_day=hcof,
            rhs_m3_per_day=rhs,
            sy=S_MF,
            newton=False,
        )
        require(bool(result["converged"]), f"C={conductance} did not converge: {result}")
        h_mf = float(result["head_m"])
        require_close(
            h_mf,
            h_mf_expected,
            f"MODFLOW head C={conductance}",
            HEAD_TOL,
        )

        # Reconstruct dummy state and physical exchange from the accepted
        # MODFLOW head, exactly as the eliminated q-link defines them.
        a = S_DUMMY / DT
        h_dummy_from_live = (
            a * H0 + RAIN + conductance * h_mf
        ) / (a + conductance)
        q_ex_live = conductance * (h_dummy_from_live - h_mf)

        require_close(
            h_dummy_from_live,
            h_dummy,
            f"dummy head C={conductance}",
            HEAD_TOL,
        )
        require_close(
            q_ex_live,
            q_ex_expected,
            f"exchange flux C={conductance}",
            1.0e-10,
        )

        mf_storage_rate = S_MF * (h_mf - H0) / DT
        require_close(
            q_ex_live,
            mf_storage_rate,
            f"MODFLOW exchange/storage balance C={conductance}",
            1.0e-10,
        )

        total_storage_change = (
            S_DUMMY * (h_dummy_from_live - H0)
            + S_MF * (h_mf - H0)
        )
        require_close(
            total_storage_change,
            RAIN * DT,
            f"total two-reservoir mass C={conductance}",
            MASS_TOL,
        )

        dh_link = abs(h_dummy_from_live - h_mf)
        head_differences.append(dh_link)
        last_h_mf = h_mf

        print(f"GC_DSW08_C_{conductance:g}_H_DUMMY_M={h_dummy_from_live:.17g}")
        print(f"GC_DSW08_C_{conductance:g}_H_MF_M={h_mf:.17g}")
        print(f"GC_DSW08_C_{conductance:g}_Q_EX_M_PER_DAY={q_ex_live:.17g}")
        print(f"GC_DSW08_C_{conductance:g}_HEAD_GAP_M={dh_link:.17g}")

    for previous, current in zip(head_differences[:-1], head_differences[1:], strict=True):
        require(
            current < previous,
            f"head gap not decreasing with conductance: {head_differences}",
        )

    require(
        abs(last_h_mf - 8.05) < 1.0e-5,
        f"large-C q-link did not approach shared-head limit: {last_h_mf}",
    )

    print("GC_DSW08_CLOSED_FORM_MODFLOW_HEAD=PASS")
    print("GC_DSW08_EXCHANGE_EQUALS_MF_STORAGE=PASS")
    print("GC_DSW08_TOTAL_TWO_RESERVOIR_MASS=PASS")
    print("GC_DSW08_HEAD_GAP_MONOTONE=PASS")
    print("GC_DSW08_ZERO_RESISTANCE_SHARED_STATE_LIMIT=PASS")
    print("GC_DSW08_LIVE_GATE=PASS")


if __name__ == "__main__":
    main()
