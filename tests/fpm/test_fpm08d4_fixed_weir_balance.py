import math
import random

SEED = 20260910


def make_table(zdeep, channels):
    h = [100.0, 0.0] + [zdeep * (i - 2) / 20.0 for i in range(3, 23)]
    s = []
    for hh in h:
        st = 0.0
        for zb, width, talud, spacing in channels:
            if hh > zb:
                if hh <= 0.0:
                    d = hh - zb
                    vol = d * (width + d / talud)
                else:
                    d = -zb
                    vol = d * (width + d / talud)
                    breadth = width + 2.0 * d / talud
                    vol += breadth * hh
                st += vol / spacing
        s.append(st)
    return h, s


def S_of_h(hk, sk, h):
    if h < hk[-1] or h > hk[0]:
        raise ValueError("head outside table")
    for i in range(len(hk) - 1):
        if h >= hk[i + 1] and h <= hk[i]:
            f = (h - hk[i + 1]) / (hk[i] - hk[i + 1])
            return sk[i + 1] + f * (sk[i] - sk[i + 1])
    raise AssertionError("head interpolation failed")


def H_of_S(hk, sk, storage):
    if storage < sk[-1] or storage > sk[0]:
        raise ValueError("storage outside table")
    for i in range(len(sk) - 1):
        if storage >= sk[i + 1] and storage <= sk[i]:
            den = sk[i] - sk[i + 1]
            if den <= 0.0:
                raise ValueError("non-invertible storage segment")
            f = (storage - sk[i + 1]) / den
            return hk[i + 1] + f * (hk[i] - hk[i + 1])
    raise AssertionError("storage interpolation failed")


def q_rating(h, hcrest, alpha, beta):
    if h < hcrest:
        return 0.0
    return alpha * (h - hcrest) ** beta


def fixed_weir_reference(hk, sk, S0, dt, qdr, qrapid, Vtop,
                         hcrest, wldip, qcap, alpha, beta):
    if dt <= 0.0 or qcap < 0.0 or alpha <= 0.0 or beta < 0.5 or beta > 3.0:
        return {"ok": False, "reason": "invalid_input"}

    hsupply = hcrest - wldip
    if hsupply <= hk[-1] or hcrest <= hk[-1] or hcrest >= hk[0]:
        return {"ok": False, "reason": "held_D1_endpoint_or_supply_target"}

    Starget = S_of_h(hk, sk, hcrest)
    Ssupply = S_of_h(hk, sk, hsupply)
    B = S0 + dt * (qdr + qrapid) + Vtop

    qsup = 0.0
    if B < Ssupply:
        qsup = min(qcap, max(0.0, (Ssupply - B) / dt))
    Bsup = B + dt * qsup

    if Bsup < 0.0:
        return {
            "ok": False,
            "reason": "no_feasible_nonnegative_storage",
            "B": B,
            "Bsup": Bsup,
        }

    if Bsup <= Starget:
        S1 = Bsup
        h1 = H_of_S(hk, sk, S1)
        qdis = 0.0
        mass = S1 - S0 - dt * (qdr + qrapid + qsup - qdis) - Vtop
        return {
            "ok": True,
            "branch": "supply_or_no_discharge",
            "S1": S1,
            "h1": h1,
            "qsup": qsup,
            "qdis": qdis,
            "mass": mass,
            "rating_resid": 0.0,
        }

    if qsup != 0.0:
        return {"ok": False, "reason": "unexpected_supply_with_discharge"}

    Ftop = sk[0] + dt * q_rating(hk[0], hcrest, alpha, beta)
    if B > Ftop:
        return {
            "ok": False,
            "reason": "overflow_no_feasible_rating_state",
            "B": B,
            "Ftop": Ftop,
        }

    lo, hi = hcrest, hk[0]
    for _ in range(140):
        mid = 0.5 * (lo + hi)
        residual = S_of_h(hk, sk, mid) + dt * q_rating(mid, hcrest, alpha, beta) - B
        if residual < 0.0:
            lo = mid
        else:
            hi = mid

    hroot = 0.5 * (lo + hi)
    qcurve = q_rating(hroot, hcrest, alpha, beta)
    S1 = B - dt * qcurve
    if S1 < sk[-1] or S1 > sk[0]:
        return {"ok": False, "reason": "root_storage_outside_D1_domain"}

    h1 = H_of_S(hk, sk, S1)
    mass = S1 - S0 - dt * (qdr + qrapid - qcurve) - Vtop
    rating_resid = qcurve - q_rating(h1, hcrest, alpha, beta)
    storage_head_resid = S1 - S_of_h(hk, sk, hroot)
    return {
        "ok": True,
        "branch": "power_discharge",
        "S1": S1,
        "h1": h1,
        "qsup": 0.0,
        "qdis": qcurve,
        "mass": mass,
        "rating_resid": rating_resid,
        "storage_head_resid": storage_head_resid,
        "hroot": hroot,
    }


def legacy_bisection(hk, sk, S0, dt, qdr, qrapid, Vtop,
                     hcrest, alpha, beta):
    B = S0 + dt * (qdr + qrapid) + Vtop
    qtop = q_rating(hk[0], hcrest, alpha, beta)
    if B - dt * qtop > sk[0]:
        return None

    lo, hi = hcrest, hk[0]
    for _ in range(100):
        hm = 0.5 * (lo + hi)
        Sm = S_of_h(hk, sk, hm)
        qm = q_rating(hm, hcrest, alpha, beta)
        Snew = B - dt * qm
        if Snew < Sm:
            hi = hm
        else:
            lo = hm
        if hi - lo <= 0.001:
            return hm, Snew, qm, Sm
    raise AssertionError("legacy loop did not stop")


def random_geometry(rng):
    zdeep = -rng.uniform(30.0, 250.0)
    nch = rng.randint(1, 4)
    bottoms = [zdeep] + [-rng.uniform(3.0, abs(zdeep) - 0.01) for _ in range(nch - 1)]
    channels = []
    for zb in bottoms:
        channels.append((
            zb,
            rng.uniform(0.5, 6.0),
            rng.uniform(0.5, 3.0),
            rng.uniform(20.0, 500.0),
        ))
    return zdeep, *make_table(zdeep, channels)


def internal_alpha(rng, beta):
    alpha_input = rng.uniform(0.1, 50.0)
    sofcu = 10 ** rng.uniform(math.log10(0.1), math.log10(100000.0))
    return alpha_input * (8.64 * (100.0 ** (1.0 - beta)) / sofcu)


def main():
    rng = random.Random(SEED)
    branch_counts = {
        "max_supply": 0,
        "partial_supply": 0,
        "no_supply_no_discharge": 0,
        "power_discharge": 0,
        "overflow": 0,
        "infeasible_dry": 0,
    }
    max_mass_abs = 0.0
    max_mass_rel = 0.0
    max_rating_abs = 0.0
    max_rating_rel = 0.0
    generic_dt_min = 1e99
    generic_dt_max = 0.0

    for _ in range(12000):
        zdeep, hk, sk = random_geometry(rng)
        hcrest = rng.uniform(zdeep + max(1.0, 0.05 * abs(zdeep)), -0.2)
        maxdip = max(1e-6, hcrest - zdeep - 1e-4)
        wldip = rng.uniform(1e-6, 0.95 * maxdip)
        beta = rng.uniform(0.5, 3.0)
        alpha = internal_alpha(rng, beta)
        dt = 10 ** rng.uniform(-4.0, 0.5)
        generic_dt_min = min(generic_dt_min, dt)
        generic_dt_max = max(generic_dt_max, dt)
        Ssupply = S_of_h(hk, sk, hcrest - wldip)
        Starget = S_of_h(hk, sk, hcrest)
        qcap = 10 ** rng.uniform(-5.0, 2.0)
        case = rng.randrange(6)

        if case == 0:
            room = max(1e-10, Ssupply * 0.8)
            capvol = min(dt * qcap, room * 0.4)
            qcap = capvol / dt
            B = max(
                0.0,
                Ssupply - capvol - rng.uniform(
                    1e-10,
                    max(1e-10, min(room - capvol, Ssupply * 0.3)),
                ),
            )
            expected = "max_supply"
        elif case == 1:
            needvol = min(dt * qcap * 0.8, max(1e-10, Ssupply * 0.5))
            if needvol <= 1e-12:
                needvol = min(Ssupply * 0.25 + 1e-9, dt * qcap * 0.5 + 1e-9)
            B = max(0.0, Ssupply - needvol)
            qcap = max(qcap, 1.2 * needvol / dt)
            expected = "partial_supply"
        elif case == 2:
            B = rng.uniform(Ssupply, Starget)
            expected = "no_supply_no_discharge"
        elif case == 3:
            htrue = rng.uniform(
                hcrest + 1e-6,
                min(99.0, hcrest + 0.95 * (100.0 - hcrest)),
            )
            B = S_of_h(hk, sk, htrue) + dt * q_rating(htrue, hcrest, alpha, beta)
            expected = "power_discharge"
        elif case == 4:
            B = (
                sk[0]
                + dt * q_rating(hk[0], hcrest, alpha, beta)
                + rng.uniform(1e-8, 1.0 + 0.01 * sk[0])
            )
            expected = "overflow"
        else:
            qcap = 10 ** rng.uniform(-6.0, -2.0)
            B = -(dt * qcap + rng.uniform(1e-8, 1.0))
            expected = "infeasible_dry"

        h0 = rng.uniform(zdeep + 1e-5, min(99.0, hcrest + 20.0))
        S0 = S_of_h(hk, sk, h0)
        Vtop = rng.uniform(-0.2, 0.2)
        qrapid = rng.uniform(0.0, 0.5)
        qdr = (B - S0 - Vtop) / dt - qrapid

        result = fixed_weir_reference(
            hk, sk, S0, dt, qdr, qrapid, Vtop,
            hcrest, wldip, qcap, alpha, beta,
        )

        if expected == "overflow":
            assert not result["ok"] and result["reason"] == "overflow_no_feasible_rating_state"
            branch_counts["overflow"] += 1
            continue
        if expected == "infeasible_dry":
            assert not result["ok"] and result["reason"] == "no_feasible_nonnegative_storage"
            branch_counts["infeasible_dry"] += 1
            continue

        assert result["ok"], (expected, result)
        mass_abs = abs(result["mass"])
        mass_scale = max(
            1.0,
            abs(result["S1"]),
            abs(S0),
            abs(dt * qdr),
            abs(dt * qrapid),
            abs(dt * result["qsup"]),
            abs(dt * result["qdis"]),
            abs(Vtop),
        )
        max_mass_abs = max(max_mass_abs, mass_abs)
        max_mass_rel = max(max_mass_rel, mass_abs / mass_scale)

        rating_abs = abs(result.get("rating_resid", 0.0))
        max_rating_abs = max(max_rating_abs, rating_abs)
        max_rating_rel = max(
            max_rating_rel,
            rating_abs / max(1.0, abs(result["qdis"])),
        )

        if expected == "max_supply":
            assert result["branch"] == "supply_or_no_discharge"
            assert abs(result["qsup"] - qcap) <= 1e-10 * max(1.0, qcap)
        elif expected == "partial_supply":
            assert result["branch"] == "supply_or_no_discharge"
            assert 0.0 < result["qsup"] < qcap
        elif expected == "no_supply_no_discharge":
            assert result["branch"] == "supply_or_no_discharge"
            assert result["qsup"] == 0.0 and result["qdis"] == 0.0
        elif expected == "power_discharge":
            assert result["branch"] == "power_discharge"
            assert result["qdis"] > 0.0 and result["qsup"] == 0.0
        branch_counts[expected] += 1

    assert max_mass_rel < 5e-12
    assert max_rating_rel < 5e-10
    assert generic_dt_min < 2e-4 and generic_dt_max > 2.0

    legacy_cases = 0
    inconsistent = 0
    out_of_inverse_domain = 0
    max_storage_relation_gap = 0.0
    max_head_inverse_gap = 0.0

    for _ in range(6000):
        zdeep, hk, sk = random_geometry(rng)
        hcrest = rng.uniform(zdeep + 1.0, -0.1)
        beta = rng.uniform(0.5, 3.0)
        alpha = internal_alpha(rng, beta)
        dt = 10 ** rng.uniform(-4.0, 0.5)
        htrue = rng.uniform(
            hcrest + 1e-5,
            min(99.0, hcrest + 0.98 * (100.0 - hcrest)),
        )
        B = S_of_h(hk, sk, htrue) + dt * q_rating(htrue, hcrest, alpha, beta)
        h0 = rng.uniform(zdeep + 1e-5, min(99.0, hcrest + 10.0))
        S0 = S_of_h(hk, sk, h0)
        qrapid = rng.uniform(0.0, 0.2)
        Vtop = rng.uniform(-0.1, 0.1)
        qdr = (B - S0 - Vtop) / dt - qrapid

        legacy = legacy_bisection(
            hk, sk, S0, dt, qdr, qrapid, Vtop,
            hcrest, alpha, beta,
        )
        assert legacy is not None
        hm, Snew, _qm, Sm = legacy
        legacy_cases += 1
        gap = abs(Snew - Sm)
        max_storage_relation_gap = max(max_storage_relation_gap, gap)
        if gap > 1e-10:
            inconsistent += 1
        if Snew < sk[-1] or Snew > sk[0]:
            out_of_inverse_domain += 1
        else:
            hinv = H_of_S(hk, sk, Snew)
            max_head_inverse_gap = max(max_head_inverse_gap, abs(hinv - hm))

    assert legacy_cases == 6000
    assert inconsistent > 1000
    assert max_storage_relation_gap > 1e-6
    assert max_head_inverse_gap > 1e-6

    alpha = 2.5
    eps1, eps2 = 1e-4, 1e-8
    slope_sub_1 = q_rating(eps1, 0.0, alpha, 0.5) / eps1
    slope_sub_2 = q_rating(eps2, 0.0, alpha, 0.5) / eps2
    assert slope_sub_2 > slope_sub_1 * 50.0
    slope_linear = q_rating(eps2, 0.0, alpha, 1.0) / eps2
    assert abs(slope_linear - alpha) < 1e-12
    slope_superlinear = q_rating(eps2, 0.0, alpha, 2.0) / eps2
    assert slope_superlinear < 1e-6

    print("FPM08D4_BRANCH_COUNTS=" + ",".join(
        f"{key}:{branch_counts[key]}" for key in sorted(branch_counts)
    ))
    print(f"FPM08D4_MAX_ACCEPTED_MASS_RESIDUAL_ABS={max_mass_abs:.17g}")
    print(f"FPM08D4_MAX_ACCEPTED_MASS_RESIDUAL_REL={max_mass_rel:.17g}")
    print(f"FPM08D4_MAX_RATING_RESIDUAL_ABS={max_rating_abs:.17g}")
    print(f"FPM08D4_MAX_RATING_RESIDUAL_REL={max_rating_rel:.17g}")
    print(f"FPM08D4_GENERIC_DT_RANGE={generic_dt_min:.17g},{generic_dt_max:.17g}")
    print(f"FPM08D4_LEGACY_BISECTION_CASES={legacy_cases}")
    print(f"FPM08D4_LEGACY_INCONSISTENT_STATE_CASES={inconsistent}")
    print(f"FPM08D4_LEGACY_INVERSE_DOMAIN_REJECTIONS={out_of_inverse_domain}")
    print(f"FPM08D4_MAX_LEGACY_STORAGE_RELATION_GAP_CM={max_storage_relation_gap:.17g}")
    print(f"FPM08D4_MAX_LEGACY_HEAD_INVERSE_GAP_CM={max_head_inverse_gap:.17g}")
    print(f"FPM08D4_CREST_SUBLINEAR_SLOPE_RATIO={slope_sub_2 / slope_sub_1:.17g}")
    print(f"FPM08D4_CREST_LINEAR_SLOPE={slope_linear:.17g}")
    print(f"FPM08D4_CREST_SUPERLINEAR_SLOPE={slope_superlinear:.17g}")
    print("FPM08D4_FIXED_WEIR_ORACLE PASS")


if __name__ == "__main__":
    main()
