from __future__ import annotations

import math
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "fgc" / "support"))

from fgc45_real_multiswap_ctypes import Fgc45RealMultiSwap


CM_TO_M = 0.01
PRODUCTION_U = 3.402936037279093e-05
CENTER_HEAD_M = -0.71499996773317653
LIVE_SHIFT_SCALE_M = 2.8804542084870377e-09
MULTIPLIERS = (-0.5, -0.25, 0.0, 0.25, 0.5)
HEADS_M = tuple(CENTER_HEAD_M + m * LIVE_SHIFT_SCALE_M for m in MULTIPLIERS)
MASS_TOL_CM = 1.0e-12
REL_TOL = 5.0e-4


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def rel_error(actual: float, expected: float) -> float:
    scale = max(abs(expected), 1.0e-30)
    return abs(actual - expected) / scale


def main() -> None:
    bridge = Path(os.environ["FGC45_MULTISWAP_LIB"]).resolve()
    require(bridge.is_file(), "missing F-GC45 bridge")

    swap = Fgc45RealMultiSwap(bridge)
    hcof, rhs, href = swap.initialize()
    require(all(math.isfinite(v) for v in (hcof, rhs, href)), "nonfinite predictor")
    u_from_term = (hcof / 86400.0) * (1.0e-4 * 86400.0)
    require(rel_error(u_from_term, PRODUCTION_U) <= 1.0e-12, "production-u drift")

    samples: dict[int, dict[float, tuple[float, float, float, float, float, float]]] = {
        1: {},
        2: {},
    }

    for tile in (1, 2):
        for multiplier, head in zip(MULTIPLIERS, HEADS_M, strict=True):
            storage_cm, total_in_cm, total_out_cm, bottom_cm, residual_cm, accepted_dt = (
                swap.direct_trial_diagnostics(tile, head)
            )
            values = (
                storage_cm,
                total_in_cm,
                total_out_cm,
                bottom_cm,
                residual_cm,
                accepted_dt,
            )
            require(all(math.isfinite(v) for v in values), f"nonfinite tile {tile} multiplier {multiplier}")
            require(abs(residual_cm) <= MASS_TOL_CM, f"mass residual tile {tile} multiplier {multiplier}")
            require(
                abs(storage_cm - (total_in_cm - total_out_cm)) <= MASS_TOL_CM,
                f"mass identity tile {tile} multiplier {multiplier}",
            )
            require(
                math.isclose(accepted_dt, 1.0e-4, rel_tol=0.0, abs_tol=1.0e-15),
                f"accepted dt tile {tile} multiplier {multiplier}",
            )
            samples[tile][multiplier] = values
            print(
                f"GC_MAP03_TILE={tile} MULT={multiplier:.17g} HEAD_M={head:.17g} "
                f"STORAGE_CHANGE_CM={storage_cm:.17g} TOTAL_IN_CM={total_in_cm:.17g} "
                f"TOTAL_OUT_CM={total_out_cm:.17g} BOTTOM_OUTWARD_CM={bottom_cm:.17g} "
                f"MASS_RESIDUAL_CM={residual_cm:.17g} ACCEPTED_DT_DAY={accepted_dt:.17g}"
            )

    for multiplier in MULTIPLIERS:
        a = samples[1][multiplier]
        b = samples[2][multiplier]
        for index, name in enumerate(
            ("storage", "total_in", "total_out", "bottom", "residual", "dt")
        ):
            require(
                math.isclose(a[index], b[index], rel_tol=0.0, abs_tol=1.0e-14),
                f"tile mismatch {name} multiplier {multiplier}",
            )

    for radius in (0.25, 0.5):
        delta_h = radius * LIVE_SHIFT_SCALE_M
        plus = samples[1][radius]
        minus = samples[1][-radius]

        d_storage_dh = ((plus[0] - minus[0]) * CM_TO_M) / (2.0 * delta_h)
        d_bottom_dh = ((plus[3] - minus[3]) * CM_TO_M) / (2.0 * delta_h)
        d_balance_dh = d_storage_dh + d_bottom_dh

        storage_rel = rel_error(d_storage_dh, PRODUCTION_U)
        bottom_rel = rel_error(-d_bottom_dh, PRODUCTION_U)
        cancellation_scale = abs(PRODUCTION_U)
        cancellation_rel = abs(d_balance_dh) / cancellation_scale

        print(
            f"GC_MAP03_FD_RADIUS_MULT={radius:.17g} DELTA_H_M={delta_h:.17g} "
            f"D_STORAGE_DH={d_storage_dh:.17g} D_BOTTOM_OUTWARD_DH={d_bottom_dh:.17g} "
            f"D_STORAGE_PLUS_BOTTOM_DH={d_balance_dh:.17g} "
            f"STORAGE_TO_U_RATIO={d_storage_dh/PRODUCTION_U:.17g} "
            f"MINUS_BOTTOM_TO_U_RATIO={-d_bottom_dh/PRODUCTION_U:.17g} "
            f"CANCELLATION_REL={cancellation_rel:.17g}"
        )

        require(storage_rel <= REL_TOL, f"storage derivative != u at radius {radius}")
        require(bottom_rel <= REL_TOL, f"bottom derivative != -u at radius {radius}")
        require(
            rel_error(d_storage_dh, -d_bottom_dh) <= REL_TOL,
            f"storage/bottom derivatives disagree at radius {radius}",
        )
        require(
            cancellation_rel <= REL_TOL,
            f"storage+bottom derivative does not cancel at radius {radius}",
        )

    print("GC_MAP03_TRANSACTION_MASS_COMPLETE=PASS")
    print("GC_MAP03_STORAGE_DERIVATIVE_EQUALS_U=PASS")
    print("GC_MAP03_BOTTOM_DERIVATIVE_EQUALS_MINUS_U=PASS")
    print("GC_MAP03_STORAGE_BOTTOM_SENSITIVITY_CANCELS=PASS")
    print("GC_MAP03_LIVE_GATE=PASS")


if __name__ == "__main__":
    main()
