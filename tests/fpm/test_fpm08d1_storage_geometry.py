#!/usr/bin/env python3
import math
import random

SEED = 20260910
CASES = 1200
PROBES_PER_CASE = 16


def build_sttab(nrpri, zbotdr, swdtyp, widthr, taludr, spacing):
    nrlevs = len(zbotdr)
    assert nrpri in (0, 1)
    assert nrlevs > nrpri
    sec0 = nrpri
    assert swdtyp[sec0] == 2
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


def swstlev(levels, storage, level):
    if level < levels[-1] or level > levels[0]:
        raise ValueError("outside level domain")
    for i in range(21):
        if level >= levels[i + 1] and level <= levels[i]:
            f = (level - levels[i + 1]) / (levels[i] - levels[i + 1])
            return storage[i + 1] + f * (storage[i] - storage[i + 1])
    raise AssertionError("no interval")


def wlevst(levels, storage, swstor):
    if swstor < storage[-1] or swstor > storage[0]:
        raise ValueError("outside storage domain")
    for i in range(21):
        if swstor >= storage[i + 1] and swstor <= storage[i]:
            f = (swstor - storage[i + 1]) / (storage[i] - storage[i + 1])
            return levels[i + 1] + f * (levels[i] - levels[i + 1])
    raise AssertionError("no interval")


def analytic_storage_single_open(level, zbot, width, talud, spacing):
    if level <= zbot:
        return 0.0
    if level <= 0.0:
        d = level - zbot
        return d * (width + d / talud) / spacing
    d = -zbot
    base = d * (width + d / talud)
    breadth = width + 2.0 * d / talud
    return (base + breadth * level) / spacing


def make_case(rng, case_id):
    nrpri = case_id % 2
    nrsec = 1 + rng.randrange(6)
    n = nrpri + nrsec
    deepest = rng.uniform(80.0, 500.0)
    shallowest = rng.uniform(10.0, min(70.0, deepest - 1.0))
    depths = sorted([rng.uniform(shallowest, deepest) for _ in range(n)], reverse=True)
    # enforce strict deepest-first order with comfortable separations
    depths = [deepest - k * (deepest - shallowest) / max(1, n - 1) for k in range(n)]
    zbot = [-d for d in depths]
    swdtyp = [2 if rng.random() < 0.7 else 1 for _ in range(n)]
    swdtyp[nrpri] = 2
    width = [rng.uniform(0.1, 250.0) for _ in range(n)]
    talud = [rng.uniform(0.25, 8.0) for _ in range(n)]
    spacing = [rng.uniform(100.0, 20000.0) for _ in range(n)]
    return nrpri, zbot, swdtyp, width, talud, spacing


def main():
    rng = random.Random(SEED)
    max_level_roundtrip = 0.0
    max_storage_roundtrip = 0.0
    total_probes = 0
    single_secondary_cases = 0
    mixed_open_tube_cases = 0

    for case_id in range(CASES):
        data = make_case(rng, case_id)
        nrpri, zbot, swdtyp, width, talud, spacing = data
        levels, storage = build_sttab(*data)

        assert len(levels) == 22 and len(storage) == 22
        assert levels[0] == 100.0
        assert levels[1] == 0.0
        assert levels[-1] == zbot[nrpri]
        assert storage[-1] == 0.0
        assert all(levels[i] > levels[i + 1] for i in range(21))
        assert all(storage[i] > storage[i + 1] for i in range(21))

        if len(zbot) - nrpri == 1:
            single_secondary_cases += 1
        if any(x == 1 for x in swdtyp[nrpri:]) and any(x == 2 for x in swdtyp[nrpri:]):
            mixed_open_tube_cases += 1

        for endpoint in (levels[-1], 0.0, levels[0]):
            s = swstlev(levels, storage, endpoint)
            recovered = wlevst(levels, storage, s)
            assert recovered == endpoint or abs(recovered - endpoint) <= 2e-14 * max(1.0, abs(endpoint))

        try:
            swstlev(levels, storage, levels[-1] - 1e-9)
            raise AssertionError("below-level domain accepted")
        except ValueError:
            pass
        try:
            swstlev(levels, storage, levels[0] + 1e-9)
            raise AssertionError("above-level domain accepted")
        except ValueError:
            pass
        try:
            wlevst(levels, storage, storage[-1] - 1e-12)
            raise AssertionError("below-storage domain accepted")
        except ValueError:
            pass
        try:
            wlevst(levels, storage, storage[0] + max(1e-12, abs(storage[0]) * 1e-12))
            raise AssertionError("above-storage domain accepted")
        except ValueError:
            pass

        for _ in range(PROBES_PER_CASE):
            level = rng.uniform(levels[-1], levels[0])
            s = swstlev(levels, storage, level)
            recovered_level = wlevst(levels, storage, s)
            err_l = abs(recovered_level - level)
            max_level_roundtrip = max(max_level_roundtrip, err_l)
            assert err_l <= 2e-11 * max(1.0, abs(level))

            target_s = rng.uniform(storage[-1], storage[0])
            recovered_storage = swstlev(levels, storage, wlevst(levels, storage, target_s))
            err_s = abs(recovered_storage - target_s)
            max_storage_roundtrip = max(max_storage_roundtrip, err_s)
            assert err_s <= 2e-11 * max(1.0, abs(target_s))
            total_probes += 1

    # Explicitly prove that replacing the frozen 22-knot interpolation by the
    # analytic trapezoid formula between knots changes reference physics.
    data = (0, [-200.0], [2], [100.0], [2.0], [1000.0])
    levels, storage = build_sttab(*data)
    probe_level = -95.0
    linear_reference = swstlev(levels, storage, probe_level)
    analytic = analytic_storage_single_open(probe_level, -200.0, 100.0, 2.0, 1000.0)
    analytic_delta = abs(linear_reference - analytic)
    assert analytic_delta > 1e-6

    # Tubes must not contribute to storage geometry.
    open_only = build_sttab(0, [-200.0, -100.0], [2, 1], [50.0, 999.0], [2.0, 0.3], [1000.0, 100.0])
    no_tube = build_sttab(0, [-200.0], [2], [50.0], [2.0], [1000.0])
    assert open_only == no_tube

    print(f"FPM08D1_GEOMETRY_CASES={CASES}")
    print(f"FPM08D1_ROUNDTRIP_PROBES={total_probes}")
    print(f"FPM08D1_SINGLE_SECONDARY_CASES={single_secondary_cases}")
    print(f"FPM08D1_MIXED_OPEN_TUBE_CASES={mixed_open_tube_cases}")
    print(f"FPM08D1_MAX_LEVEL_ROUNDTRIP_ABS={max_level_roundtrip:.17g}")
    print(f"FPM08D1_MAX_STORAGE_ROUNDTRIP_ABS={max_storage_roundtrip:.17g}")
    print(f"FPM08D1_ANALYTIC_VS_REFERENCE_DELTA={analytic_delta:.17g}")
    print("FPM08D1_ENDPOINT_DOMAIN_CHECKS=PASS")
    print("FPM08D1_STRICT_MONOTONICITY=PASS")
    print("FPM08D1_TUBE_EXCLUSION=PASS")
    print("FPM08D1_REFERENCE_PIECEWISE_LINEAR_SEMANTICS=PASS")
    print("FPM08D1_STORAGE_GEOMETRY_ORACLE PASS")


if __name__ == "__main__":
    main()
