from __future__ import annotations

import math
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "fgc" / "support"))
sys.path.insert(0, str(ROOT / "tests" / "fgc"))

from fgc45_real_multiswap_ctypes import Fgc45RealMultiSwap
from test_fgc45_real_multiswap_modflow_end_to_end import WINDOW_DAY


HEADS_M = (
    -0.7149999691734037,
    -0.7149999684532901,
    -0.7149999677331765,
    -0.714999967013063,
    -0.7149999662929494,
)
CENTER = 2
PREDICTOR_U = 0.00003402936037279093
MASS_TOL_CM = 1.0e-12
REL_TOL = 5.0e-4


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def relative_error(value: float, reference: float) -> float:
    return abs(value - reference) / max(abs(reference), 1.0e-300)


def main() -> None:
    bridge = Path(os.environ["FGC45_MULTISWAP_LIB"]).resolve()
    require(bridge.is_file(), "missing F-GC45 bridge")

    swap = Fgc45RealMultiSwap(bridge)
    hcof, rhs, href = swap.initialize()
    require(all(math.isfinite(v) for v in (hcof, rhs, href)), "nonfinite predictor response")

    print(f"GC_MAP03_HREF_M={href:.17g}")
    print(f"GC_MAP03_HCOF_M2_PER_DAY={hcof:.17g}")
    print(f"GC_MAP03_RHS_M3_PER_DAY={rhs:.17g}")
    print(f"GC_MAP03_PREDICTOR_U={PREDICTOR_U:.17g}")

    samples: dict[int, list[dict[str, float]]] = {1: [], 2: []}
    for tile in (1, 2):
        for head in HEADS_M:
            storage_cm, total_in_cm, total_out_cm, bottom_cm, residual_cm, dt_day = (
                swap.direct_trial_diagnostics(tile, head)
            )
            values = (storage_cm, total_in_cm, total_out_cm, bottom_cm, residual_cm, dt_day)
            require(all(math.isfinite(v) for v in values), f"tile {tile} nonfinite diagnostics at {head}")
            require(math.isclose(dt_day, WINDOW_DAY, rel_tol=0.0, abs_tol=1.0e-15), f"tile {tile} dt drift")
            require(abs(residual_cm) <= MASS_TOL_CM, f"tile {tile} mass residual {residual_cm}")
            require(
                abs(storage_cm - (total_in_cm - total_out_cm)) <= MASS_TOL_CM,
                f"tile {tile} transaction mass identity at {head}",
            )
            row = {
                "head_m": head,
                "storage_m": storage_cm / 100.0,
                "total_in_m": total_in_cm / 100.0,
                "total_out_m": total_out_cm / 100.0,
                "bottom_m": bottom_cm / 100.0,
                "residual_cm": residual_cm,
                "dt_day": dt_day,
            }
            samples[tile].append(row)
            print(
                f"GC_MAP03_TILE={tile} HEAD_M={head:.17g} "
                f"STORAGE_M={row['storage_m']:.17g} TOTAL_IN_M={row['total_in_m']:.17g} "
                f"TOTAL_OUT_M={row['total_out_m']:.17g} BOTTOM_OUT_M={row['bottom_m']:.17g} "
                f"MASS_RESIDUAL_CM={residual_cm:.17g} DT_DAY={dt_day:.17g}"
            )

    for index, head in enumerate(HEADS_M):
        for key in ("storage_m", "total_in_m", "total_out_m", "bottom_m"):
            a = samples[1][index][key]
            b = samples[2][index][key]
            require(
                math.isclose(a, b, rel_tol=0.0, abs_tol=1.0e-14),
                f"identical-tile diagnostic mismatch {key} at {head}: {a} != {b}",
            )

    for radius_index, label in ((1, "RADIUS_0_25"), (0, "RADIUS_0_5")):
        plus_index = 4 - radius_index
        minus_index = radius_index
        delta = (HEADS_M[plus_index] - HEADS_M[minus_index]) / 2.0
        require(delta > 0.0, f"invalid delta {label}")

        for tile in (1, 2):
            minus = samples[tile][minus_index]
            plus = samples[tile][plus_index]
            d_storage = (plus["storage_m"] - minus["storage_m"]) / (2.0 * delta)
            d_bottom = (plus["bottom_m"] - minus["bottom_m"]) / (2.0 * delta)
            d_sum = d_storage + d_bottom
            require(all(math.isfinite(v) for v in (d_storage, d_bottom, d_sum)), f"nonfinite derivative tile {tile} {label}")

            rel_storage_u = relative_error(d_storage, PREDICTOR_U)
            rel_neg_bottom_u = relative_error(-d_bottom, PREDICTOR_U)
            cancellation_scaled = abs(d_sum) / max(abs(PREDICTOR_U), 1.0e-300)
            storage_vs_neg_bottom = relative_error(d_storage, -d_bottom)

            print(
                f"GC_MAP03_TILE={tile} {label} DELTA_M={delta:.17g} "
                f"DSTORAGE_DH={d_storage:.17g} DBOTTOM_DH={d_bottom:.17g} "
                f"DSUM_DH={d_sum:.17g} STORAGE_TO_U_RELERR={rel_storage_u:.17g} "
                f"NEG_BOTTOM_TO_U_RELERR={rel_neg_bottom_u:.17g} "
                f"STORAGE_VS_NEG_BOTTOM_RELERR={storage_vs_neg_bottom:.17g} "
                f"CANCELLATION_SCALED={cancellation_scaled:.17g}"
            )

            require(storage_vs_neg_bottom <= REL_TOL, f"tile {tile} storage/bottom derivative mismatch {label}")
            require(rel_storage_u <= REL_TOL, f"tile {tile} storage derivative versus u {label}")
            require(cancellation_scaled <= REL_TOL, f"tile {tile} storage+bottom derivative cancellation {label}")

    print("GC_MAP03_ALL_DIRECT_TRIALS_ACCEPTED_MASS_COMPLETE=PASS")
    print("GC_MAP03_TRANSACTION_MASS_IDENTITY=PASS")
    print("GC_MAP03_STORAGE_DERIVATIVE_EQUALS_U=PASS")
    print("GC_MAP03_BOTTOM_DERIVATIVE_EQUALS_MINUS_U=PASS")
    print("GC_MAP03_STORAGE_PLUS_BOTTOM_DERIVATIVE_CANCELS=PASS")
    print("GC_MAP03_LIVE_GATE=PASS")


if __name__ == "__main__":
    main()
