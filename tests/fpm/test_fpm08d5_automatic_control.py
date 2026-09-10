import random

SEED = 20260910


def source_phase(gwl, air, head, gcrit, vcrit, hcrit):
    p = len(gcrit) - 1
    while gwl > gcrit[p] and p > 0:
        p -= 1
    while air < vcrit[p] and p > 0:
        p -= 1
    while head > hcrit[p] and p > 0:
        p -= 1
    return p


def independent_phase(gwl, air, head, gcrit, vcrit, hcrit):
    eligible = []
    for p in range(len(gcrit)):
        if gwl <= gcrit[p] and air >= vcrit[p] and head <= hcrit[p]:
            eligible.append(p)
    return max(eligible) if eligible else 0


def target_step(old, requested, dropr, dt):
    if requested < old and dropr > 0.001:
        return max(requested, old - dropr * dt)
    return requested


def main():
    rng = random.Random(SEED)

    phase_cases = 20000
    for _ in range(phase_cases):
        n = rng.randint(1, 8)
        gcrit = [0.0]
        vcrit = [0.0]
        hcrit = [0.0]
        for _p in range(1, n):
            gcrit.append(gcrit[-1] - rng.uniform(0.0, 80.0))
            vcrit.append(vcrit[-1] + rng.uniform(0.0, 3.0))
            hcrit.append(hcrit[-1] - rng.uniform(0.0, 150.0))
        gwl = rng.uniform(-500.0, 0.0)
        air = rng.uniform(0.0, 20.0)
        head = rng.uniform(-1000.0, 0.0)
        assert source_phase(gwl, air, head, gcrit, vcrit, hcrit) == independent_phase(
            gwl, air, head, gcrit, vcrit, hcrit
        )

    trigger_cases = 0
    for intwl in range(1, 32):
        explicit = {k * intwl - 1 for k in range(1, 1000 // intwl + 2)}
        for T in range(1000):
            rday = (T + 1.0) / intwl
            legacy = abs(rday - int(rday)) < 1e-5
            assert legacy == (T in explicit)
            trigger_cases += 1

    event_cases = 20000
    no_event = 0
    downward_limited = 0
    downward_unlimited = 0
    upward = 0
    max_drop = 0.0
    for _ in range(event_cases):
        old = rng.uniform(-200.0, 50.0)
        requested = rng.uniform(-200.0, 50.0)
        dt = 10 ** rng.uniform(-5.0, 1.0)
        dropr = rng.uniform(0.0, 5.0)
        is_event = rng.random() < 0.6
        selected = requested if is_event else old
        trial = target_step(old, selected, dropr, dt)
        if not is_event:
            assert trial == old
            no_event += 1
        elif requested < old:
            if dropr > 0.001:
                assert requested - 1e-14 <= trial <= old + 1e-14
                assert abs((old - trial) - min(old - requested, dropr * dt)) < 1e-10 * max(
                    1.0, abs(old), abs(requested)
                )
                downward_limited += 1
                max_drop = max(max_drop, old - trial)
            else:
                assert trial == requested
                downward_unlimited += 1
        else:
            assert trial == requested
            upward += 1
        # Pure trial semantics: retrying from the same committed old target is identical.
        assert target_step(old, selected, dropr, dt) == trial

    old = 10.0
    requested = -10.0
    dt = 1.0
    at_seam = target_step(old, requested, 0.001, dt)
    above_seam = target_step(old, requested, 0.001000001, dt)
    assert at_seam == requested and above_seam > requested
    seam_jump = above_seam - at_seam

    capacity_cases = 20000
    negative_wover = 0
    undefined_fractional = 0
    even_positive_below_crest = 0
    defined_capacity = 0
    max_rel_head_choice_diff = 0.0
    fractional = [0.5, 0.75, 1.5, 2.5]
    for _ in range(capacity_cases):
        crest = rng.uniform(-100.0, -1.0)
        target = crest + rng.uniform(1.0, 50.0)
        current = rng.uniform(crest - 100.0, target + 20.0)
        alpha = 10 ** rng.uniform(-4.0, 2.0)
        beta = rng.choice(fractional + [1.0, 2.0, 3.0])
        base = current - crest
        if base < 0.0:
            negative_wover += 1
            if beta in fractional:
                undefined_fractional += 1
            elif beta == 2.0:
                q = alpha * base ** beta
                assert q > 0.0
                even_positive_below_crest += 1
        else:
            q_current = alpha * base ** beta
            q_target = alpha * (target - crest) ** beta
            defined_capacity += 1
            rel = abs(q_current - q_target) / max(1.0, abs(q_current), abs(q_target))
            max_rel_head_choice_diff = max(max_rel_head_choice_diff, rel)

    assert negative_wover > 5000
    assert undefined_fractional > 2000
    assert even_positive_below_crest > 500

    discap = 1.234
    assert not (discap > discap)  # exact equality is the legacy overflow branch
    assert discap > discap - 1e-12

    print(f"FPM08D5_PHASE_EQUIVALENCE_CASES={phase_cases}")
    print(f"FPM08D5_INTEGER_DAY_TRIGGER_MAPPING_CASES={trigger_cases}")
    print(f"FPM08D5_EVENT_STATE_CASES={event_cases}")
    print(f"FPM08D5_NO_EVENT_WLSTAR_HOLDS={no_event}")
    print(f"FPM08D5_DOWNWARD_DROP_RATE_LIMITED_CASES={downward_limited}")
    print(f"FPM08D5_DOWNWARD_UNLIMITED_AT_OR_BELOW_SEAM_CASES={downward_unlimited}")
    print(f"FPM08D5_UPWARD_IMMEDIATE_CASES={upward}")
    print(f"FPM08D5_MAX_TRIAL_TARGET_DROP_CM={max_drop:.17g}")
    print(f"FPM08D5_DROPR_0P001_SEAM_JUMP_CM={seam_jump:.17g}")
    print(f"FPM08D5_CAPACITY_DISCREPANCY_CASES={capacity_cases}")
    print(f"FPM08D5_NEGATIVE_WOVER_CASES={negative_wover}")
    print(f"FPM08D5_UNDEFINED_FRACTIONAL_NEGATIVE_WOVER_CASES={undefined_fractional}")
    print(f"FPM08D5_EVEN_POWER_POSITIVE_CAPACITY_BELOW_CREST_CASES={even_positive_below_crest}")
    print(f"FPM08D5_DEFINED_CURRENT_HEAD_CAPACITY_CASES={defined_capacity}")
    print(f"FPM08D5_MAX_REL_CURRENT_VS_TARGET_HEAD_CAPACITY_DIFF={max_rel_head_choice_diff:.17g}")
    print("FPM08D5_STRICT_CAPACITY_EQUALITY_SEAM=PASS")
    print("FPM08D5_AUTOMATIC_CONTROL_ORACLE PASS")


if __name__ == "__main__":
    main()
