from __future__ import annotations

import math
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "research"))

from test_gc_dummy_swap_dsw01_live_modflow import run_case, require

H0 = 8.0
INPUT = 0.010
DT = 1.0
STORAGES = (0.02, 0.20, 0.80)
S_DUMMY = 0.10
S_MF = 0.10
CONDUCTANCES = (0.001, 0.1, 1000.0)
HEAD_TOL = 1.0e-8
MASS_TOL = 1.0e-12


def qlink_closed_form(c: float) -> tuple[float, float, float, float, float]:
    a = S_DUMMY / DT
    beta = c / (a + c)
    dh_mf = beta * INPUT / (S_MF / DT + beta * a)
    h_mf = H0 + dh_mf
    h_dummy = (a * H0 + INPUT + c * h_mf) / (a + c)
    q_ex = c * (h_dummy - h_mf)
    hcof = -beta * a
    rhs = hcof * H0 - beta * INPUT
    return h_dummy, h_mf, q_ex, hcof, rhs


def main() -> None:
    libmf6 = Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(), "missing libmf6")

    storage_rises: list[float] = []
    for storage in STORAGES:
        expected = H0 + INPUT / storage
        result = run_case(
            libmf6,
            f"dsw18_storage_{storage:g}",
            hcof_m2_per_day=0.0,
            rhs_m3_per_day=-INPUT,
            sy=storage,
            newton=False,
        )
        require(bool(result["converged"]), f"storage {storage} did not converge: {result}")
        head = float(result["head_m"])
        rise = head - H0
        mass = storage * rise
        storage_rises.append(rise)
        print(f"GC_DSW18_STORAGE_{storage:g}_HEAD_M={head:.17g}")
        print(f"GC_DSW18_STORAGE_{storage:g}_RISE_M={rise:.17g}")
        print(f"GC_DSW18_STORAGE_{storage:g}_MASS_M={mass:.17g}")
        require(math.isclose(head, expected, rel_tol=0.0, abs_tol=HEAD_TOL), f"storage head {storage}")
        require(math.isclose(mass, INPUT, rel_tol=0.0, abs_tol=MASS_TOL), f"storage mass {storage}")

    require(
        all(b < a for a, b in zip(storage_rises[:-1], storage_rises[1:], strict=True)),
        f"storage response not monotone: {storage_rises}",
    )

    qlink_gaps: list[float] = []
    qlink_heads: list[float] = []
    for conductance in CONDUCTANCES:
        h_dummy_expected, h_mf_expected, q_expected, hcof, rhs = qlink_closed_form(conductance)
        result = run_case(
            libmf6,
            f"dsw18_qlink_{conductance:g}",
            hcof_m2_per_day=hcof,
            rhs_m3_per_day=rhs,
            sy=S_MF,
            newton=False,
        )
        require(bool(result["converged"]), f"q-link {conductance} did not converge: {result}")
        h_mf = float(result["head_m"])
        a = S_DUMMY / DT
        h_dummy = (a * H0 + INPUT + conductance * h_mf) / (a + conductance)
        q_ex = conductance * (h_dummy - h_mf)
        gap = abs(h_dummy - h_mf)
        total_mass = S_DUMMY * (h_dummy - H0) + S_MF * (h_mf - H0)
        qlink_gaps.append(gap)
        qlink_heads.append(h_mf)

        print(f"GC_DSW18_QLINK_{conductance:g}_H_DUMMY_M={h_dummy:.17g}")
        print(f"GC_DSW18_QLINK_{conductance:g}_H_MF_M={h_mf:.17g}")
        print(f"GC_DSW18_QLINK_{conductance:g}_GAP_M={gap:.17g}")
        print(f"GC_DSW18_QLINK_{conductance:g}_TRANSFER_M={q_ex:.17g}")

        require(math.isclose(h_mf, h_mf_expected, rel_tol=0.0, abs_tol=HEAD_TOL), f"q-link MF head {conductance}")
        require(math.isclose(h_dummy, h_dummy_expected, rel_tol=0.0, abs_tol=HEAD_TOL), f"q-link dummy head {conductance}")
        require(math.isclose(q_ex, q_expected, rel_tol=0.0, abs_tol=1.0e-10), f"q-link flux {conductance}")
        require(math.isclose(total_mass, INPUT, rel_tol=0.0, abs_tol=MASS_TOL), f"q-link mass {conductance}")

    require(
        all(b < a for a, b in zip(qlink_gaps[:-1], qlink_gaps[1:], strict=True)),
        f"q-link gaps not monotone: {qlink_gaps}",
    )
    require(abs(qlink_heads[-1] - 8.05) < 1.0e-5, f"large-C shared-head limit: {qlink_heads[-1]}")

    print("GC_DSW18_STORAGE_SENSITIVITY_LIMITS=PASS")
    print("GC_DSW18_QLINK_CONDUCTANCE_LIMITS=PASS")
    print("GC_DSW18_DISTINCT_LIMIT_SIGNATURES=PASS")
    print("GC_DSW18_LIVE_GATE=PASS")


if __name__ == "__main__":
    main()
