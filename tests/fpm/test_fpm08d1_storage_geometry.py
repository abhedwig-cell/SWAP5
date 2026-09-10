#!/usr/bin/env python3
import math
import random
import subprocess
import tempfile
from pathlib import Path

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
    depths = [deepest - k * (deepest - shallowest) / max(1, n - 1) for k in range(n)]
    zbot = [-d for d in depths]
    swdtyp = [2 if rng.random() < 0.7 else 1 for _ in range(n)]
    swdtyp[nrpri] = 2
    width = [rng.uniform(0.1, 250.0) for _ in range(n)]
    talud = [rng.uniform(0.25, 8.0) for _ in range(n)]
    spacing = [rng.uniform(100.0, 20000.0) for _ in range(n)]
    return nrpri, zbot, swdtyp, width, talud, spacing


def fortran_bottom_knot_characterization(optflag):
    src = r'''program p
  use iso_fortran_env, only: real64
  implicit none
  integer :: i, pos, neg, eq
  real(real64) :: z, knot, d, maxd
  pos=0; neg=0; eq=0; maxd=0.0_real64
  do i=1,100000
    z = -(80.0_real64 + 420.0_real64*real(i,real64)/100001.0_real64)
    knot = z * 20 / 20.0_real64
    d = knot-z
    if (d > 0.0_real64) then
      pos=pos+1
    else if (d < 0.0_real64) then
      neg=neg+1
    else
      eq=eq+1
    end if
    maxd=max(maxd,abs(d))
  end do
  write(*,'(3(I0,1X),ES24.16E3)') pos,neg,eq,maxd
end program p
'''
    with tempfile.TemporaryDirectory() as td:
        td = Path(td)
        f = td / "bottom_knot.f90"
        exe = td / "probe"
        f.write_text(src)
        subprocess.check_call(["gfortran", optflag, str(f), "-o", str(exe)])
        fields = subprocess.check_output([str(exe)], text=True).split()
    return int(fields[0]), int(fields[1]), int(fields[2]), float(fields[3])


def main():
    rng = random.Random(SEED)
    max_level_roundtrip = 0.0
    max_storage_roundtrip = 0.0
    max_bottom_knot_abs_offset = 0.0
    max_bottom_storage = 0.0
    max_forward_knot_storage_abs_difference = 0.0
    total_probes = 0
    single_secondary_cases = 0
    mixed_open_tube_cases = 0
    bottom_knot_above = 0
    bottom_knot_below = 0
    bottom_knot_exact = 0
    exact_zbot_initialization_rejected = 0
    forward_knot_storage_mismatches = 0
    forward_knot_inverse_domain_rejections = 0

    for case_id in range(CASES):
        data = make_case(rng, case_id)
        nrpri, zbot, swdtyp, width, talud, spacing = data
        levels, storage = build_sttab(*data)

        assert len(levels) == 22 and len(storage) == 22
        assert levels[0] == 100.0
        assert levels[1] == 0.0
        bottom_offset = levels[-1] - zbot[nrpri]
        max_bottom_knot_abs_offset = max(max_bottom_knot_abs_offset, abs(bottom_offset))
        assert abs(bottom_offset) <= 2.0 * math.ulp(zbot[nrpri])
        if bottom_offset > 0.0:
            bottom_knot_above += 1
        elif bottom_offset < 0.0:
            bottom_knot_below += 1
        else:
            bottom_knot_exact += 1
        assert storage[-1] >= 0.0 and math.isfinite(storage[-1])
        max_bottom_storage = max(max_bottom_storage, storage[-1])
        assert all(levels[i] > levels[i + 1] for i in range(21))
        assert all(storage[i] > storage[i + 1] for i in range(21))

        if zbot[nrpri] < levels[-1]:
            try:
                swstlev(levels, storage, zbot[nrpri])
                raise AssertionError("expected exact-zbot endpoint rejection")
            except ValueError:
                exact_zbot_initialization_rejected += 1
        else:
            swstlev(levels, storage, zbot[nrpri])

        if len(zbot) - nrpri == 1:
            single_secondary_cases += 1
        if any(x == 1 for x in swdtyp[nrpri:]) and any(x == 2 for x in swdtyp[nrpri:]):
            mixed_open_tube_cases += 1

        # Characterize exact-knot arithmetic rather than assuming mathematical
        # endpoint identities are bit identities. Frozen SWSTLEV evaluates the
        # interpolation expression even at f=0 or f=1.
        for i, knot_level in enumerate(levels):
            s = swstlev(levels, storage, knot_level)
            ds = s - storage[i]
            if ds != 0.0:
                forward_knot_storage_mismatches += 1
                max_forward_knot_storage_abs_difference = max(max_forward_knot_storage_abs_difference, abs(ds))
            if s < storage[-1] or s > storage[0]:
                forward_knot_inverse_domain_rejections += 1
            else:
                recovered = wlevst(levels, storage, s)
                err = abs(recovered - knot_level)
                max_level_roundtrip = max(max_level_roundtrip, err)
                assert err <= 2e-11 * max(1.0, abs(knot_level))

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
            wlevst(levels, storage, storage[-1] - max(1e-12, math.ulp(storage[-1])))
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

    data = (0, [-200.0], [2], [100.0], [2.0], [1000.0])
    levels, storage = build_sttab(*data)
    probe_level = -95.0
    linear_reference = swstlev(levels, storage, probe_level)
    analytic = analytic_storage_single_open(probe_level, -200.0, 100.0, 2.0, 1000.0)
    analytic_delta = abs(linear_reference - analytic)
    assert analytic_delta > 1e-6

    open_only = build_sttab(0, [-200.0, -100.0], [2, 1], [50.0, 999.0], [2.0, 0.3], [1000.0, 100.0])
    no_tube = build_sttab(0, [-200.0], [2], [50.0], [2.0], [1000.0])
    assert open_only == no_tube

    f_o0 = fortran_bottom_knot_characterization("-O0")
    f_o2 = fortran_bottom_knot_characterization("-O2")
    assert f_o0 == f_o2
    assert f_o0[0] > 0 and f_o0[1] > 0 and f_o0[2] > 0
    assert f_o0[3] > 0.0

    assert bottom_knot_above > 0 and bottom_knot_below > 0 and bottom_knot_exact > 0
    assert exact_zbot_initialization_rejected == bottom_knot_above
    assert forward_knot_storage_mismatches > 0
    assert forward_knot_inverse_domain_rejections > 0

    print(f"FPM08D1_GEOMETRY_CASES={CASES}")
    print(f"FPM08D1_ROUNDTRIP_PROBES={total_probes}")
    print(f"FPM08D1_SINGLE_SECONDARY_CASES={single_secondary_cases}")
    print(f"FPM08D1_MIXED_OPEN_TUBE_CASES={mixed_open_tube_cases}")
    print(f"FPM08D1_MAX_LEVEL_ROUNDTRIP_ABS={max_level_roundtrip:.17g}")
    print(f"FPM08D1_MAX_STORAGE_ROUNDTRIP_ABS={max_storage_roundtrip:.17g}")
    print(f"FPM08D1_ANALYTIC_VS_REFERENCE_DELTA={analytic_delta:.17g}")
    print(f"FPM08D1_BOTTOM_KNOT_ABOVE_ZBOT={bottom_knot_above}")
    print(f"FPM08D1_BOTTOM_KNOT_BELOW_ZBOT={bottom_knot_below}")
    print(f"FPM08D1_BOTTOM_KNOT_EXACT_ZBOT={bottom_knot_exact}")
    print(f"FPM08D1_EXACT_ZBOT_INITIALIZATION_REJECTED={exact_zbot_initialization_rejected}")
    print(f"FPM08D1_MAX_BOTTOM_KNOT_ABS_OFFSET={max_bottom_knot_abs_offset:.17g}")
    print(f"FPM08D1_MAX_BOTTOM_STORAGE={max_bottom_storage:.17g}")
    print(f"FPM08D1_FORWARD_KNOT_STORAGE_MISMATCHES={forward_knot_storage_mismatches}")
    print(f"FPM08D1_FORWARD_KNOT_INVERSE_DOMAIN_REJECTIONS={forward_knot_inverse_domain_rejections}")
    print(f"FPM08D1_MAX_FORWARD_KNOT_STORAGE_ABS_DIFFERENCE={max_forward_knot_storage_abs_difference:.17g}")
    print(f"FPM08D1_FORTRAN_O0_BOTTOM_KNOT_COUNTS={f_o0[0]},{f_o0[1]},{f_o0[2]}")
    print(f"FPM08D1_FORTRAN_O2_BOTTOM_KNOT_COUNTS={f_o2[0]},{f_o2[1]},{f_o2[2]}")
    print(f"FPM08D1_FORTRAN_MAX_BOTTOM_KNOT_ABS_OFFSET={f_o0[3]:.17g}")
    print("FPM08D1_BOTTOM_KNOT_ROUNDING_SEAM=CHARACTERIZED")
    print("FPM08D1_INTERPOLATION_ENDPOINT_ROUNDING_SEAM=CHARACTERIZED")
    print("FPM08D1_ENDPOINT_DOMAIN_CHECKS=PASS")
    print("FPM08D1_STRICT_MONOTONICITY=PASS")
    print("FPM08D1_TUBE_EXCLUSION=PASS")
    print("FPM08D1_REFERENCE_PIECEWISE_LINEAR_SEMANTICS=PASS")
    print("FPM08D1_STORAGE_GEOMETRY_ORACLE PASS")


if __name__ == "__main__":
    main()
