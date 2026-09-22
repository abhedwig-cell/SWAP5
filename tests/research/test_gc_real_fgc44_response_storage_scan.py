from __future__ import annotations

import math
import os
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "fgc" / "support"))

from fgc44_real_swap_ctypes import Fgc44RealSwap


DURATIONS_DAY = (5.0e-5, 1.0e-4, 2.0e-4)
QBOTS_CM_PER_DAY = (5.0e-7, 1.0e-6, 2.0e-6)
MASS_TOL = 1.0e-12
U_FLOOR = 1.0e-12
EPS_FACTOR = 256.0


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def close_eps(a: float, b: float) -> bool:
    scale = max(1.0, abs(a), abs(b))
    return abs(a - b) <= EPS_FACTOR * np.finfo(float).eps * scale


def main() -> None:
    library = Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(library.is_file(), "missing F-GC44 real-SWAP bridge library")
    swap = Fgc44RealSwap(library)

    rows: list[dict[str, float]] = []

    for duration in DURATIONS_DAY:
        for qbot in QBOTS_CM_PER_DAY:
            hcof, rhs, href = swap.initialize_configured(duration, qbot)
            diag = swap.e1_diagnostics()

            require(bool(diag["mass_complete"]), f"incomplete mass diagnostics dt={duration} q={qbot}")

            u = float(diag["u"])
            q_u = float(diag["q_u_cm_per_day"])
            h_start = float(diag["h_start_m"])
            h_end = float(diag["h_end_m"])
            storage_change = float(diag["storage_change_native"])
            total_in = float(diag["total_in_native"])
            total_out = float(diag["total_out_native"])
            mass_residual = float(diag["mass_residual_native"])

            reconstructed_q_u = (
                u * (h_end - h_start) * 100.0 / duration
                - qbot
            )
            expected_hcof = u / duration
            expected_rhs = expected_hcof * href - 0.01 * q_u
            mass_identity = storage_change - (total_in - total_out)

            require(
                close_eps(reconstructed_q_u, q_u),
                f"q_u algebra mismatch dt={duration} q={qbot}: {reconstructed_q_u} != {q_u}",
            )
            require(
                close_eps(hcof, expected_hcof),
                f"HCOF transform mismatch dt={duration} q={qbot}: {hcof} != {expected_hcof}",
            )
            require(
                close_eps(rhs, expected_rhs),
                f"RHS transform mismatch dt={duration} q={qbot}: {rhs} != {expected_rhs}",
            )
            require(
                abs(mass_identity - mass_residual) <= MASS_TOL,
                f"mass identity mismatch dt={duration} q={qbot}",
            )
            require(
                abs(storage_change) <= MASS_TOL,
                f"equal-boundary-flux storage change is not zero dt={duration} q={qbot}: {storage_change}",
            )
            require(math.isfinite(u) and abs(u) > U_FLOOR, f"u is zero/nonfinite dt={duration} q={qbot}: {u}")

            row = {
                "duration_day": duration,
                "qbot_cm_per_day": qbot,
                "u": u,
                "q_u_cm_per_day": q_u,
                "h_start_m": h_start,
                "h_end_m": h_end,
                "delta_h_m": h_end - h_start,
                "storage_change_native": storage_change,
                "total_in_native": total_in,
                "total_out_native": total_out,
                "mass_residual_native": mass_residual,
                "hcof_m2_per_day": hcof,
                "rhs_m3_per_day": rhs,
                "reference_head_m": href,
            }
            rows.append(row)

            label = f"DT_{duration:.0e}_Q_{qbot:.0e}".replace("-", "M")
            print(f"GC_DSW22_{label}_U={u:.17g}")
            print(f"GC_DSW22_{label}_Q_U_CM_PER_DAY={q_u:.17g}")
            print(f"GC_DSW22_{label}_H_START_M={h_start:.17g}")
            print(f"GC_DSW22_{label}_H_END_M={h_end:.17g}")
            print(f"GC_DSW22_{label}_DELTA_H_M={h_end-h_start:.17g}")
            print(f"GC_DSW22_{label}_STORAGE_CHANGE_NATIVE={storage_change:.17g}")
            print(f"GC_DSW22_{label}_TOTAL_IN_NATIVE={total_in:.17g}")
            print(f"GC_DSW22_{label}_TOTAL_OUT_NATIVE={total_out:.17g}")
            print(f"GC_DSW22_{label}_MASS_RESIDUAL_NATIVE={mass_residual:.17g}")
            print(f"GC_DSW22_{label}_HCOF_M2_PER_DAY={hcof:.17g}")
            print(f"GC_DSW22_{label}_RHS_M3_PER_DAY={rhs:.17g}")
            print(f"GC_DSW22_{label}_REFERENCE_HEAD_M={href:.17g}")

    require(len(rows) == 9, "configured matrix incomplete")
    require(all(abs(r["storage_change_native"]) <= MASS_TOL for r in rows), "zero-storage gate")
    require(all(abs(r["u"]) > U_FLOOR for r in rows), "nonzero-u gate")

    print("GC_DSW22_ALL_CONFIGURED_PREDICTORS=PASS")
    print("GC_DSW22_FGC30_QU_ALGEBRA=PASS")
    print("GC_DSW22_FGC33_HCOF_RHS_TRANSFORM=PASS")
    print("GC_DSW22_INDEPENDENT_MASS_IDENTITY=PASS")
    print("GC_DSW22_ZERO_NET_STORAGE_NONZERO_U=PASS")
    print("GC_DSW22_LIVE_GATE=PASS")


if __name__ == "__main__":
    main()
