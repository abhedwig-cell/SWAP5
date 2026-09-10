#!/usr/bin/env python3
import math
import random
from dataclasses import dataclass

SEED = 20260910
EPS = 0.001
POND_SWITCH = -0.1


@dataclass
class Params:
    z: float = -100.0
    kind: int = 1
    width: float = 50.0
    talud: float = 2.0
    spacing: float = 1000.0
    rdrain: float = 10.0
    rinfi: float = 20.0
    rentry: float = 0.5
    rexit: float = 0.7
    gwlinf: float = -200.0
    top_mode: int = 0
    highest: bool = False
    rsdeep: float = 10.0
    rsshallow: float = 2.0
    coef: float = 0.5
    exponent: float = 0.7
    pondmx: float = 1000.0


def legacy_value(p, gwl, wl, pond):
    if not (wl < p.pondmx or gwl < p.pondmx):
        return 0.0
    if not (gwl > p.z + EPS or wl > p.z + EPS):
        return 0.0

    if wl <= p.z + EPS:
        drain_level = p.z
        wet_perimeter = p.width if p.kind == 2 else None
    else:
        drain_level = wl
        if p.kind == 2:
            depth = wl - p.z
            wet_perimeter = p.width + 2.0 * math.sqrt(depth * depth + (depth / p.talud) ** 2)
        else:
            wet_perimeter = None

    eff = gwl - drain_level
    if gwl > POND_SWITCH:
        eff += pond
    if eff < 0.0 and gwl < p.gwlinf:
        eff = p.gwlinf - drain_level

    if p.highest and p.top_mode == 2:
        if eff < 0.0:
            raise ValueError("negative power interflow held")
        return p.coef * eff ** p.exponent

    if eff > 0.0:
        rd = p.rdrain
        re = p.rentry
        if p.highest and p.top_mode == 1:
            rd = max(p.rsdeep - eff, p.rsshallow)
    else:
        rd = p.rinfi
        re = p.rexit

    if p.kind == 2:
        return eff / (rd + re * p.spacing / wet_perimeter)
    return eff / rd


def analytic_value_and_partials(p, gwl, wl, pond):
    if not (wl < p.pondmx or gwl < p.pondmx):
        return 0.0, (0.0, 0.0, 0.0), "suppressed"
    if not (gwl > p.z + EPS or wl > p.z + EPS):
        return 0.0, (0.0, 0.0, 0.0), "inactive"

    if wl <= p.z + EPS:
        drain_level = p.z
        dlevel_dwl = 0.0
        wet_perimeter = p.width if p.kind == 2 else None
        dwet_dwl = 0.0
    else:
        drain_level = wl
        dlevel_dwl = 1.0
        if p.kind == 2:
            depth = wl - p.z
            root = math.sqrt(depth * depth + (depth / p.talud) ** 2)
            wet_perimeter = p.width + 2.0 * root
            dwet_dwl = 2.0 * depth * (1.0 + 1.0 / (p.talud * p.talud)) / root
        else:
            wet_perimeter = None
            dwet_dwl = 0.0

    raw = gwl - drain_level
    pond_on = gwl > POND_SWITCH
    if pond_on:
        raw += pond
    de = [1.0, -dlevel_dwl, 1.0 if pond_on else 0.0]
    eff = raw
    cap_active = raw < 0.0 and gwl < p.gwlinf
    if cap_active:
        eff = p.gwlinf - drain_level
        de = [0.0, -dlevel_dwl, 0.0]

    if p.highest and p.top_mode == 2:
        if eff < 0.0:
            raise ValueError("negative power interflow held")
        q = p.coef * eff ** p.exponent
        if eff == 0.0:
            return q, None, "power_activation"
        factor = p.coef * p.exponent * eff ** (p.exponent - 1.0)
        return q, tuple(factor * x for x in de), "power"

    positive = eff > 0.0
    tangent_undefined = False
    if positive:
        rd = p.rdrain
        re = p.rentry
        dr_de = 0.0
        if p.highest and p.top_mode == 1:
            unconstrained = p.rsdeep - eff
            if abs(unconstrained - p.rsshallow) <= 1e-14 * max(1.0, abs(unconstrained), abs(p.rsshallow)):
                tangent_undefined = True
            if unconstrained > p.rsshallow:
                rd = unconstrained
                dr_de = -1.0
            else:
                rd = p.rsshallow
                dr_de = 0.0
    else:
        rd = p.rinfi
        re = p.rexit
        dr_de = 0.0
        tangent_undefined = eff == 0.0

    denominator = rd + (re * p.spacing / wet_perimeter if p.kind == 2 else 0.0)
    q = eff / denominator
    if tangent_undefined:
        return q, None, "branch_kink"

    partials = []
    for index, de_dx in enumerate(de):
        dden_dx = dr_de * de_dx
        if p.kind == 2 and index == 1:
            dden_dx += -re * p.spacing * dwet_dwl / (wet_perimeter * wet_perimeter)
        partials.append((de_dx * denominator - eff * dden_dx) / (denominator * denominator))

    if cap_active:
        branch = "cap"
    else:
        branch = "normal_positive" if positive else "normal_negative"
    return q, tuple(partials), branch


def finite_difference(p, gwl, wl, pond, index):
    values = [gwl, wl, pond]
    step = 1e-6 * max(1.0, abs(values[index]))
    plus = values.copy()
    minus = values.copy()
    plus[index] += step
    minus[index] -= step
    return (legacy_value(p, *plus) - legacy_value(p, *minus)) / (2.0 * step)


def close_enough(a, b, rtol=4e-6, atol=2e-9):
    return abs(a - b) <= atol + rtol * max(abs(a), abs(b), 1e-12)


def main():
    rng = random.Random(SEED)
    cases = []

    for i in range(700):
        z = -rng.uniform(30.0, 300.0)
        kind = 1 if i % 2 == 0 else 2
        p = Params(
            z=z,
            kind=kind,
            width=rng.uniform(0.1, 200.0),
            talud=rng.uniform(0.1, 5.0),
            spacing=rng.uniform(100.0, 10000.0),
            rdrain=rng.uniform(2.0, 100.0),
            rinfi=rng.uniform(2.0, 100.0),
            rentry=rng.uniform(0.0, 5.0),
            rexit=rng.uniform(0.0, 5.0),
            gwlinf=z - rng.uniform(20.0, 200.0),
            pondmx=1000.0,
        )
        wl = z + rng.uniform(5.0, 80.0)
        if i % 4 < 2:
            gwl = wl + rng.uniform(2.0, 50.0)
        else:
            gwl = max(p.gwlinf + rng.uniform(2.0, 10.0), wl - rng.uniform(2.0, 20.0))
            if gwl >= wl:
                gwl = wl - rng.uniform(2.0, 10.0)
        if gwl > -1.0:
            gwl = -1.0
        cases.append((p, gwl, wl, 0.0))

    for i in range(150):
        z = -rng.uniform(30.0, 200.0)
        gwlinf = z - rng.uniform(20.0, 100.0)
        wl = z + rng.uniform(5.0, 40.0)
        gwl = gwlinf - rng.uniform(5.0, 30.0)
        p = Params(
            z=z,
            kind=1 if i % 2 == 0 else 2,
            gwlinf=gwlinf,
            width=rng.uniform(1.0, 100.0),
            talud=rng.uniform(0.2, 4.0),
            spacing=rng.uniform(100.0, 5000.0),
            rinfi=rng.uniform(2.0, 100.0),
            rexit=rng.uniform(0.0, 3.0),
            pondmx=1000.0,
        )
        cases.append((p, gwl, wl, 0.0))

    for i in range(120):
        z = -150.0
        wl = -100.0
        target_difference = 3.0 if i % 2 == 0 else 12.0
        gwl = wl + target_difference
        p = Params(
            z=z,
            kind=1 if i % 3 == 0 else 2,
            width=40.0,
            talud=2.0,
            spacing=1200.0,
            rentry=0.4,
            rdrain=50.0,
            rinfi=40.0,
            rexit=0.5,
            gwlinf=-300.0,
            top_mode=1,
            highest=True,
            rsdeep=10.0,
            rsshallow=2.0,
            pondmx=1000.0,
        )
        cases.append((p, gwl, wl, 0.0))

    for i in range(120):
        z = -150.0
        wl = -100.0
        gwl = wl + rng.uniform(0.5, 30.0)
        p = Params(
            z=z,
            kind=1 if i % 2 == 0 else 2,
            gwlinf=-300.0,
            top_mode=2,
            highest=True,
            coef=rng.uniform(0.01, 10.0),
            exponent=rng.uniform(0.1, 1.0),
            pondmx=1000.0,
        )
        cases.append((p, gwl, wl, 0.0))

    for i in range(80):
        z = -20.0
        wl = -5.0
        gwl = rng.uniform(0.2, 2.0)
        pond = rng.uniform(0.01, 3.0)
        p = Params(
            z=z,
            kind=1 if i % 2 == 0 else 2,
            width=20.0,
            talud=1.5,
            spacing=500.0,
            rdrain=20.0,
            rentry=0.3,
            gwlinf=-100.0,
            pondmx=1000.0,
        )
        cases.append((p, gwl, wl, pond))

    max_value_error = 0.0
    max_derivative_relative_error = 0.0
    derivative_checks = 0
    branch_counts = {}

    for p, gwl, wl, pond in cases:
        q, partials, branch = analytic_value_and_partials(p, gwl, wl, pond)
        source_value = legacy_value(p, gwl, wl, pond)
        max_value_error = max(max_value_error, abs(q - source_value))
        assert q == source_value or abs(q - source_value) < 1e-14
        branch_counts[branch] = branch_counts.get(branch, 0) + 1
        if partials is not None:
            for index, analytic in enumerate(partials):
                numeric = finite_difference(p, gwl, wl, pond, index)
                assert close_enough(analytic, numeric), (branch, index, analytic, numeric)
                rel = abs(analytic - numeric) / max(1e-12, abs(analytic), abs(numeric))
                max_derivative_relative_error = max(max_derivative_relative_error, rel)
                derivative_checks += 1

    p = Params(z=-100.0, pondmx=-20.0)
    assert legacy_value(p, -120.0, -120.0, 0.0) == 0.0
    assert legacy_value(p, -10.0, -10.0, 0.0) == 0.0

    p = Params(z=-100.0, top_mode=2, highest=True, gwlinf=-200.0, pondmx=1000.0)
    try:
        legacy_value(p, -70.0, -50.0, 0.0)
        raise AssertionError("negative power interflow admitted")
    except ValueError:
        pass

    p = Params(z=-100.0, kind=1, rdrain=10.0, gwlinf=-200.0, pondmx=1000.0)
    wl = -50.0
    pond = 2.0
    q_at = legacy_value(p, -0.1, wl, pond)
    q_above = legacy_value(p, -0.1 + 1e-12, wl, pond)
    pond_switch_jump = q_above - q_at
    assert abs(pond_switch_jump) > 0.19

    p = Params(z=-100.0, kind=1, rdrain=10.0, gwlinf=-200.0, pondmx=1000.0)
    wl = -110.0
    threshold = p.z + EPS
    q_at = legacy_value(p, threshold, wl, 0.0)
    q_above = legacy_value(p, threshold + 1e-10, wl, 0.0)
    activation_jump = q_above - q_at
    assert q_at == 0.0 and activation_jump > 9e-5

    p = Params(z=-100.0, kind=1, rinfi=20.0, gwlinf=-80.0, pondmx=1000.0)
    wl = -50.0
    h = 1e-6
    q_minus = legacy_value(p, p.gwlinf - h, wl, 0.0)
    q_at = legacy_value(p, p.gwlinf, wl, 0.0)
    q_plus = legacy_value(p, p.gwlinf + h, wl, 0.0)
    gwlinf_left = (q_at - q_minus) / h
    gwlinf_right = (q_plus - q_at) / h
    assert abs(gwlinf_left) < 1e-8
    assert abs(gwlinf_right - 1.0 / p.rinfi) < 1e-7

    p = Params(z=-100.0, kind=1, top_mode=1, highest=True, rsdeep=10.0, rsshallow=2.0, gwlinf=-200.0, pondmx=1000.0)
    wl = -100.0
    gwl = wl + 8.0
    h = 1e-6
    q_minus = legacy_value(p, gwl - h, wl, 0.0)
    q_at = legacy_value(p, gwl, wl, 0.0)
    q_plus = legacy_value(p, gwl + h, wl, 0.0)
    surface_left = (q_at - q_minus) / h
    surface_right = (q_plus - q_at) / h
    assert abs(surface_left - surface_right) > 0.1

    p = Params(z=-100.0, kind=1, rdrain=10.0, rinfi=20.0, gwlinf=-200.0, pondmx=1000.0)
    wl = -50.0
    gwl = wl
    h = 1e-6
    q_minus = legacy_value(p, gwl - h, wl, 0.0)
    q_at = legacy_value(p, gwl, wl, 0.0)
    q_plus = legacy_value(p, gwl + h, wl, 0.0)
    sign_left = (q_at - q_minus) / h
    sign_right = (q_plus - q_at) / h
    assert abs(sign_left - 1.0 / 20.0) < 1e-8
    assert abs(sign_right - 1.0 / 10.0) < 1e-8

    p = Params(z=-100.0, kind=1, rinfi=20.0, gwlinf=-200.0, pondmx=-20.0)
    wl = -10.0
    gwl = -20.0
    h = 1e-6
    q_at = legacy_value(p, gwl, wl, 0.0)
    q_below = legacy_value(p, gwl - h, wl, 0.0)
    ponding_sill_jump = q_at - q_below
    assert q_at == 0.0 and abs(ponding_sill_jump) > 0.49

    print(f"FPM08D2_VALUE_CASES={len(cases)}")
    print(f"FPM08D2_DERIVATIVE_CHECKS={derivative_checks}")
    print(f"FPM08D2_MAX_VALUE_ABS_ERROR={max_value_error:.17g}")
    print(f"FPM08D2_MAX_DERIVATIVE_REL_ERROR={max_derivative_relative_error:.17g}")
    print("FPM08D2_BRANCH_COUNTS=" + ",".join(f"{k}:{v}" for k, v in sorted(branch_counts.items())))
    print(f"FPM08D2_POND_SWITCH_JUMP={pond_switch_jump:.17g}")
    print(f"FPM08D2_ACTIVATION_JUMP={activation_jump:.17g}")
    print(f"FPM08D2_GWLINF_ONE_SIDED_SLOPES={gwlinf_left:.17g},{gwlinf_right:.17g}")
    print(f"FPM08D2_SURFACE_RESISTANCE_ONE_SIDED_SLOPES={surface_left:.17g},{surface_right:.17g}")
    print(f"FPM08D2_SIGN_RESISTANCE_ONE_SIDED_SLOPES={sign_left:.17g},{sign_right:.17g}")
    print(f"FPM08D2_PONDING_SILL_JUMP={ponding_sill_jump:.17g}")
    print("FPM08D2_NEGATIVE_POWER_INTERFLOW=HELD_FAIL_CLOSED")
    print("FPM08D2_EXTENDED_EXCHANGE_ORACLE PASS")


if __name__ == "__main__":
    main()
