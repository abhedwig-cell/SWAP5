from __future__ import annotations

import math
import random

SEED = 2026092317
CASES = 2000
EPSILONS_M = (1.0e-4, 1.0e-5, 1.0e-6)
TOL = 1.0e-11

def build_sttab(nrpri, zbotdr, swdtyp, widthr, taludr, spacing):
    n = len(zbotdr)
    zdeep = zbotdr[nrpri]
    levels = [100.0, 0.0] + [zdeep * (i - 2) / 20.0 for i in range(3, 23)]
    storage = []
    for level in levels:
        total = 0.0
        for j in range(nrpri, n):
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

def prepare(data):
    level_cm, storage_cm = build_sttab(*data)
    x = [v / 100.0 for v in reversed(level_cm)]
    bottom = storage_cm[-1]
    y = [(v - bottom) / 100.0 for v in reversed(storage_cm)]
    return x, y

def interval_slopes(x, y):
    return [(y[i + 1] - y[i]) / (x[i + 1] - x[i]) for i in range(len(x) - 1)]

def swap_storage(x, y, h):
    if h <= x[0]:
        return y[0]
    if h >= x[-1]:
        return y[-1]
    for i in range(len(x) - 1):
        if x[i] <= h <= x[i + 1]:
            f = (h - x[i]) / (x[i + 1] - x[i])
            return y[i] + f * (y[i + 1] - y[i])
    raise AssertionError(h)

def area_profile(x, y, epsilon):
    slope = interval_slopes(x, y)
    levels = [x[0]]
    areas = [slope[0]]
    zones = []
    for i in range(1, len(x) - 1):
        left = x[i] - x[i - 1]
        right = x[i + 1] - x[i]
        assert epsilon < 0.2 * min(left, right)
        levels.extend([x[i] - epsilon, x[i] + epsilon])
        areas.extend([slope[i - 1], slope[i]])
        zones.append((x[i], epsilon, slope[i - 1], slope[i]))
    levels.append(x[-1])
    areas.append(slope[-1])
    return levels, areas, zones

def integrated_knots(levels, areas):
    out = [0.0]
    for i in range(len(levels) - 1):
        dh = levels[i + 1] - levels[i]
        out.append(out[-1] + 0.5 * (areas[i] + areas[i + 1]) * dh)
    return out

def profile_storage(levels, areas, storage, h):
    if h <= levels[0]:
        return storage[0] + areas[0] * (h - levels[0])
    if h >= levels[-1]:
        return storage[-1] + areas[-1] * (h - levels[-1])
    for i in range(len(levels) - 1):
        if levels[i] <= h <= levels[i + 1]:
            dx = h - levels[i]
            dh = levels[i + 1] - levels[i]
            return storage[i] + areas[i] * dx + 0.5 * (areas[i + 1] - areas[i]) / dh * dx * dx
    raise AssertionError(h)

def main():
    rng = random.Random(SEED)
    max_error = {eps: 0.0 for eps in EPSILONS_M}
    max_bound = {eps: 0.0 for eps in EPSILONS_M}

    for case_id in range(CASES):
        x, y = prepare(make_case(rng, case_id))
        slopes = interval_slopes(x, y)
        assert all(s >= -TOL for s in slopes), (case_id, min(slopes))

        for eps in EPSILONS_M:
            levels, areas, zones = area_profile(x, y, eps)
            assert all(a >= -TOL for a in areas), (case_id, eps, min(areas))
            storage = integrated_knots(levels, areas)

            # Symmetric transitions conserve the full interval integral, so endpoint storage returns exactly.
            assert abs(storage[-1] - y[-1]) <= TOL, (case_id, eps, storage[-1], y[-1])

            local_bound = 0.0
            for knot, width, left_slope, right_slope in zones:
                bound = width * abs(right_slope - left_slope) / 4.0
                local_bound = max(local_bound, bound)

                for h in (knot - width, knot, knot + width):
                    a = profile_storage(levels, areas, storage, h)
                    b = swap_storage(x, y, h)
                    err = abs(a - b)
                    assert err <= bound + TOL, (case_id, eps, h, err, bound)
                    max_error[eps] = max(max_error[eps], err)

            max_bound[eps] = max(max_bound[eps], local_bound)

            # Probe points outside transition zones; representation must have caught up exactly.
            for i in range(len(x) - 1):
                lo = x[i] + (eps if i > 0 else 0.0)
                hi = x[i + 1] - (eps if i + 1 < len(x) - 1 else 0.0)
                if hi > lo:
                    h = 0.5 * (lo + hi)
                    err = abs(profile_storage(levels, areas, storage, h) - swap_storage(x, y, h))
                    assert err <= TOL, (case_id, eps, h, err)

    for eps in EPSILONS_M:
        assert max_error[eps] <= max_bound[eps] + TOL
        print(
            f"SW_RIB_SWM01_Q1H_EPSILON={eps:.1e} "
            f"MAX_ERROR_M3={max_error[eps]:.17g} MAX_THEOREM_BOUND_M3={max_bound[eps]:.17g}"
        )

    normalized = [max_error[e] / e for e in EPSILONS_M]
    span = max(normalized) - min(normalized)
    scale = max(max(normalized), 1.0)
    assert span <= 1e-8 * scale + 1e-10, normalized

    print(f"SW_RIB_SWM01_Q1H_CASES={CASES}")
    print("SW_RIB_SWM01_Q1H_OUTSIDE_TRANSITION_EXACT=PASS")
    print("SW_RIB_SWM01_Q1H_THEOREM_BOUND=PASS")
    print("SW_RIB_SWM01_Q1H_LINEAR_ERROR_CONTROL=PASS")
    print("SW_RIB_SWM01_Q1H_CONFIRMATORY_CHARACTERIZATION=PASS")

if __name__ == "__main__":
    main()
