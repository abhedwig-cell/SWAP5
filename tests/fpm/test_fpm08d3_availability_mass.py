#!/usr/bin/env python3
import random

SEED = 20260910
RNG = random.Random(SEED)


def limiter(s0, dt, q_supply_available, requested):
    assert s0 >= 0.0
    assert dt > 0.0
    assert q_supply_available >= 0.0
    q_req = sum(requested)
    projected = s0 + dt * (q_req + q_supply_available)
    if projected >= 0.0:
        return 1.0, list(requested), q_req, False
    q_limited = -(s0 / dt + q_supply_available)
    alpha = q_limited / q_req
    return alpha, [alpha * q for q in requested], q_limited, True


def mass_residual(s0, s1, dt, q_drain, q_rapid, q_supply, q_discharge, v_top):
    return (s1 - s0) - (dt * (q_drain + q_rapid + q_supply - q_discharge) + v_top)


def main():
    active_cases = 0
    inactive_cases = 0
    mixed_sign_active_cases = 0
    max_limiter_closure = 0.0
    max_mass_residual = 0.0

    # Broad limiter algebra: both active and inactive cases.
    for _ in range(12000):
        n = RNG.randint(1, 8)
        s0 = RNG.uniform(0.0, 5.0)
        dt = 10.0 ** RNG.uniform(-3.0, 0.3)
        cap = RNG.uniform(0.0, 3.0)
        requested = [RNG.uniform(-5.0, 2.0) for _ in range(n)]
        alpha, limited, q_total, active = limiter(s0, dt, cap, requested)
        if active:
            active_cases += 1
            assert sum(requested) < 0.0
            assert 0.0 < alpha < 1.0
            closure = s0 + dt * (sum(limited) + cap)
            max_limiter_closure = max(max_limiter_closure, abs(closure))
            assert abs(closure) <= 5e-14 * max(1.0, s0, dt * abs(sum(limited)), dt * cap)
            assert abs(sum(limited) - q_total) <= 5e-14 * max(1.0, abs(q_total))
            if any(q > 0.0 for q in requested) and any(q < 0.0 for q in requested):
                mixed_sign_active_cases += 1
                for before, after in zip(requested, limited):
                    if before > 0.0:
                        assert 0.0 < after < before
        else:
            inactive_cases += 1
            assert alpha == 1.0
            assert limited == requested
            assert q_total == sum(requested)

    assert active_cases > 1500
    assert inactive_cases > 7000
    assert mixed_sign_active_cases > 100

    # Exact accepted-mass reconstruction for arbitrary first-class terms.
    accepted_cases = 0
    for _ in range(5000):
        dt = RNG.uniform(0.01, 2.0)
        s0 = RNG.uniform(5.0, 20.0)
        q_drain = RNG.uniform(-1.0, 2.0)
        q_rapid = RNG.uniform(0.0, 1.0)
        cap = RNG.uniform(0.0, 2.0)
        q_supply = RNG.uniform(0.0, cap)
        q_discharge = RNG.uniform(0.0, 2.0)
        v_top = RNG.uniform(-0.5, 0.5)
        s1 = s0 + dt * (q_drain + q_rapid + q_supply - q_discharge) + v_top
        if s1 < 0.0:
            continue
        recovered_supply = ((s1 - s0) - v_top) / dt - q_drain - q_rapid + q_discharge
        assert abs(recovered_supply - q_supply) <= 2e-12 * max(1.0, abs(q_supply))
        residual = mass_residual(s0, s1, dt, q_drain, q_rapid, recovered_supply, q_discharge, v_top)
        max_mass_residual = max(max_mass_residual, abs(residual))
        assert abs(residual) <= 3e-12 * max(1.0, s0, s1)
        accepted_cases += 1
    assert accepted_cases > 4500

    # Dry-floor states are admissible only when exact required supply is within capacity.
    dry_cases = 0
    for _ in range(20000):
        dt = RNG.uniform(0.05, 2.0)
        s0 = RNG.uniform(0.0, 2.0)
        q_drain = -RNG.uniform(0.0, 5.0)
        q_rapid = RNG.uniform(0.0, 0.5)
        v_top = RNG.uniform(-0.5, 0.2)
        cap = RNG.uniform(0.0, 5.0)
        required = -(s0 + v_top) / dt - q_drain - q_rapid
        if not (0.0 <= required <= cap):
            continue
        residual = mass_residual(s0, 0.0, dt, q_drain, q_rapid, required, 0.0, v_top)
        assert abs(residual) <= 2e-13 * max(1.0, s0, abs(v_top))
        max_mass_residual = max(max_mass_residual, abs(residual))
        dry_cases += 1
        if dry_cases >= 2000:
            break
    assert dry_cases == 2000

    # Source mismatch: raw WSCAP can say "no limiter" while resolved supply availability is zero.
    s0, dt, q_req = 0.1, 1.0, [-0.5]
    raw_wscap = 1.0
    alpha_raw, _, _, active_raw = limiter(s0, dt, raw_wscap, q_req)
    alpha_resolved, q_resolved, _, active_resolved = limiter(s0, dt, 0.0, q_req)
    assert active_raw is False and alpha_raw == 1.0
    assert active_resolved is True and abs(alpha_resolved - 0.2) < 1e-15
    assert abs(sum(q_resolved) + 0.1) < 1e-15

    # Legacy negative dry projection: forcing S1=0 with supply at capacity creates an unmatched mass gap.
    s0, dt, q_drain, cap, q_rapid, v_top = 0.1, 1.0, -0.299, 0.1, 0.0, 0.0
    projected = s0 + dt * (q_drain + cap + q_rapid) + v_top
    assert -0.1 <= projected < 0.0
    legacy_gap = -projected
    required_supply = -(s0 + v_top) / dt - q_drain - q_rapid
    assert required_supply > cap
    assert abs((required_supply - cap) - legacy_gap / dt) < 1e-15
    assert abs(legacy_gap - 0.099) < 1e-15

    # Positive near-zero projection can be made mass exact by using slightly less than maximum supply.
    s0, dt, cap, q_drain = 0.1, 1.0, 0.1, -0.19999995
    projected_positive = s0 + dt * (q_drain + cap)
    assert 0.0 < projected_positive < 1e-7
    exact_supply_to_floor = -s0 / dt - q_drain
    assert 0.0 <= exact_supply_to_floor <= cap
    assert abs(mass_residual(s0, 0.0, dt, q_drain, 0.0, exact_supply_to_floor, 0.0, 0.0)) < 1e-15

    # A pre-solver envelope is not final acceptance: later top-surface withdrawal can break the floor.
    s0, dt, cap = 0.1, 1.0, 0.1
    alpha, limited, _, active = limiter(s0, dt, cap, [-0.5])
    assert active and abs(s0 + dt * (sum(limited) + cap)) < 1e-15
    later_v_top = -0.05
    final_projection = s0 + dt * (sum(limited) + cap) + later_v_top
    assert final_projection < 0.0
    required_after_top = -(s0 + later_v_top) / dt - sum(limited)
    assert required_after_top > cap

    # Explicit mixed-sign example: legacy proportional scaling changes a positive local inflow.
    alpha, limited, total, active = limiter(0.1, 1.0, 0.0, [-1.0, 0.2])
    assert active and abs(alpha - 0.125) < 1e-15
    assert abs(limited[0] + 0.125) < 1e-15
    assert abs(limited[1] - 0.025) < 1e-15
    assert abs(total + 0.1) < 1e-15

    print(f"FPM08D3_ACTIVE_LIMITER_CASES={active_cases}")
    print(f"FPM08D3_INACTIVE_LIMITER_CASES={inactive_cases}")
    print(f"FPM08D3_MIXED_SIGN_ACTIVE_CASES={mixed_sign_active_cases}")
    print(f"FPM08D3_ACCEPTED_MASS_CASES={accepted_cases}")
    print(f"FPM08D3_DRY_FLOOR_EXACT_CASES={dry_cases}")
    print(f"FPM08D3_MAX_LIMITER_CLOSURE_ABS={max_limiter_closure:.17g}")
    print(f"FPM08D3_MAX_ACCEPTED_MASS_RESIDUAL_ABS={max_mass_residual:.17g}")
    print(f"FPM08D3_RAW_WSCAP_ALPHA={alpha_raw:.17g}")
    print(f"FPM08D3_RESOLVED_ZERO_SUPPLY_ALPHA={alpha_resolved:.17g}")
    print(f"FPM08D3_LEGACY_DRY_FLOOR_GAP_CM={legacy_gap:.17g}")
    print(f"FPM08D3_LEGACY_REQUIRED_SUPPLY_EXCESS={required_supply-cap:.17g}")
    print(f"FPM08D3_POSITIVE_NEAR_ZERO_PROJECTION_CM={projected_positive:.17g}")
    print(f"FPM08D3_POST_SOIL_NEGATIVE_PROJECTION_CM={final_projection:.17g}")
    print("FPM08D3_MIXED_SIGN_SCALING=HELD_FOR_SCIENTIFIC_DISPOSITION")
    print("FPM08D3_AVAILABILITY_MASS_ORACLE PASS")


if __name__ == "__main__":
    main()
