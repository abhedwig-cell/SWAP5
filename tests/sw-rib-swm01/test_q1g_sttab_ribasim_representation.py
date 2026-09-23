#!/usr/bin/env python3
from __future__ import annotations

import math
import random

SEED = 20260910
CASES = 1200
FRACTIONS = (0.25, 0.5, 0.75)
EXACT_TOL_M3 = 1.0e-12


def build_sttab(nrpri, zbotdr, swdtyp, widthr, taludr, spacing):
    nrlevs = len(zbotdr)
    sec0 = nrpri
    zdeep = zbotdr[sec0]
    levels = [100.0, 0.0] + [zdeep * (i - 2) / 20.0 for i in range(3, 23)]
    storage = []
    for level in levels:
        total = 0.0
        for j in range(sec0, nrlevs):
            if swdtyp[j] == 2 and level > zbotdr[j]:
                if level <= 0.0:
                    d = level - zbotdr[j]
                    volume = d * (widthr[j] + d / taludr[j])
                else:
                    d = -zbotdr[j]
                    base = d * (widthr[j] + d / taludr[j])
                    breadth = widthr[j] + 2.0 * d / taludr[j]
                    volume = base + breadth * level
                total += volume / spacing[j]
        storage.append(total)
    return levels, storage


def make_case(rng, case_id):
    nrpri = case_id % 2
    nrsec = 1 + rng.randrange(6)
    n = nrpri + nrsec
    deepest = rng.uniform(80.0, 500.0)
    shallowest = rng.uniform(10.0, min(70.0, deepest - 1.0))
    depths = [deepest - k * (deepest - shallowest) / max(1, n - 1) for k in range(n)]
    zbot = [-d for d in depths]
    swdtyp = [2 if rng.random() < 0.7 else 1 for _ in range(n)]
    swdtyp[nrpri] = 2
    width = [rng.uniform(0.1, 250.0) for _ in range(n)]
    talud = [rng.uniform(0.25, 8.0) for _ in range(n)]
    spacing = [rng.uniform(100.0, 20000.0) for _ in range(n)]
    return nrpri, zbot, swdtyp, width, talud, spacing


def ribasim_derivatives(storage, level):
    d = [0.0] * len(level)
    d[0] = (storage[1] - storage[0]) / (level[1] - level[0])
    for i in range(len(level) - 1):
        slope = (storage[i + 1] - storage[i]) / (level[i + 1] - level[i])
        d[i + 1] = 2.0 * slope - d[i]
    return d


def ribasim_storage_inside(storage, level, deriv, i, fraction):
    dh = level[i + 1] - level[i]
    dx = fraction * dh
    return (
        storage[i]
        + deriv[i] * dx
        + 0.5 * (deriv[i + 1] - deriv[i]) / dh * dx * dx
    )


def swap_storage_inside(storage, i, fraction):
    return storage[i] + fraction * (storage[i + 1] - storage[i])


def main():
    rng = random.Random(SEED)
    max_abs = 0.0
    max_rel_total = 0.0
    max_below_surface_abs = 0.0
    max_knot_error = 0.0
    max_bottom_offset_cm = 0.0
    invalid_negative_area = 0
    exact_intervals = 0
    nonexact_intervals = 0
    worst = None

    for case_id in range(CASES):
        data = make_case(rng, case_id)
        levels_desc_cm, storage_desc_cm = build_sttab(*data)

        # Ribasim uses increasing levels and zero storage at the profile bottom.
        level = [x / 100.0 for x in reversed(levels_desc_cm)]
        bottom_storage_cm = storage_desc_cm[-1]
        max_bottom_offset_cm = max(max_bottom_offset_cm, abs(bottom_storage_cm))
        storage = [
            (x - bottom_storage_cm) / 100.0
            for x in reversed(storage_desc_cm)
        ]  # m3 on 1 m2

        deriv = ribasim_derivatives(storage, level)
        if any(x < 0.0 for x in deriv):
            invalid_negative_area += 1
            continue

        # The recurrence must reproduce supplied storage knots under trapezoidal integration.
        reconstructed = [storage[0]]
        for i in range(len(level) - 1):
            dh = level[i + 1] - level[i]
            reconstructed.append(
                reconstructed[-1] + 0.5 * (deriv[i] + deriv[i + 1]) * dh
            )
        max_knot_error = max(
            max_knot_error,
            max(abs(a - b) for a, b in zip(reconstructed, storage)),
        )

        total = max(storage[-1] - storage[0], 1.0e-30)
        for i in range(len(level) - 1):
            interval_nonexact = False
            for fraction in FRACTIONS:
                sr = ribasim_storage_inside(storage, level, deriv, i, fraction)
                ss = swap_storage_inside(storage, i, fraction)
                err = sr - ss
                ae = abs(err)
                max_abs = max(max_abs, ae)
                max_rel_total = max(max_rel_total, ae / total)
                if level[i + 1] <= 0.0:
                    max_below_surface_abs = max(max_below_surface_abs, ae)
                if ae > EXACT_TOL_M3:
                    interval_nonexact = True
                    if worst is None or ae > worst["abs_error_m3"]:
                        worst = {
                            "case_id": case_id,
                            "interval": i,
                            "fraction": fraction,
                            "level_m": level[i] + fraction * (level[i + 1] - level[i]),
                            "swap_storage_m3": ss,
                            "ribasim_storage_m3": sr,
                            "abs_error_m3": ae,
                            "relative_total": ae / total,
                        }
            if interval_nonexact:
                nonexact_intervals += 1
            else:
                exact_intervals += 1

    assert max_knot_error <= 5.0e-13, max_knot_error
    assert nonexact_intervals > 0, "expected structural inter-knot mismatch"
    assert max_abs > EXACT_TOL_M3, "exact parity unexpectedly held"
    assert worst is not None

    print(f"SW_RIB_SWM01_Q1G_CASES={CASES}")
    print(f"SW_RIB_SWM01_Q1G_INVALID_NEGATIVE_AREA_CASES={invalid_negative_area}")
    print(f"SW_RIB_SWM01_Q1G_EXACT_INTERVALS={exact_intervals}")
    print(f"SW_RIB_SWM01_Q1G_NONEXACT_INTERVALS={nonexact_intervals}")
    print(f"SW_RIB_SWM01_Q1G_MAX_KNOT_ERROR_M3={max_knot_error:.17g}")
    print(f"SW_RIB_SWM01_Q1G_MAX_ABS_STORAGE_ERROR_M3={max_abs:.17g}")
    print(f"SW_RIB_SWM01_Q1G_MAX_BELOW_SURFACE_ERROR_M3={max_below_surface_abs:.17g}")
    print(f"SW_RIB_SWM01_Q1G_MAX_REL_TOTAL={max_rel_total:.17g}")
    print(f"SW_RIB_SWM01_Q1G_MAX_BOTTOM_OFFSET_CM={max_bottom_offset_cm:.17g}")
    print(
        "SW_RIB_SWM01_Q1G_WORST="
        + ",".join(f"{k}={v}" for k, v in worst.items())
    )
    print("SW_RIB_SWM01_Q1G_EXACT_DIRECT_STTAB_MAPPING=FALSIFIED")
    print("SW_RIB_SWM01_Q1G_CHARACTERIZATION=PASS")


if __name__ == "__main__":
    main()
