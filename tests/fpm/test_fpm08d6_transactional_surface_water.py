#!/usr/bin/env python3
from dataclasses import dataclass
import math
import random
import sys

SEED = 8062026


@dataclass(frozen=True)
class State:
    swst: float
    wlstar: object = None


@dataclass
class Ledger:
    q_drain_secondary: float = 0.0
    q_rapid: float = 0.0
    q_supply: float = 0.0
    q_discharge: float = 0.0
    v_top_surface_exchange: float = 0.0

    def clone(self):
        return Ledger(**self.__dict__)


@dataclass
class Trial:
    candidate: State
    dt: float
    qd: float
    qr: float
    qs: float
    qout: float
    vtop: float
    q_supply_available: float
    complete: bool = True
    missing_mask: int = 0
    requires_auto_capacity: bool = False
    swqhr2: bool = False
    mixed_sign_active_limiter: bool = False
    unqualified_divdra: bool = False


def mass_residual(committed, trial):
    return (
        trial.candidate.swst
        - committed.swst
        - trial.dt * (trial.qd + trial.qr + trial.qs - trial.qout)
        - trial.vtop
    )


def mass_scale(committed, trial):
    return max(
        1.0,
        abs(committed.swst),
        abs(trial.candidate.swst),
        abs(trial.dt * trial.qd),
        abs(trial.dt * trial.qr),
        abs(trial.dt * trial.qs),
        abs(trial.dt * trial.qout),
        abs(trial.vtop),
    )


def numeric_mass_ok(committed, trial):
    # Numerical verification only. Completeness and physical constraints are
    # checked separately and cannot be bypassed by this roundoff-scale bound.
    bound = 256.0 * sys.float_info.epsilon * mass_scale(committed, trial)
    return abs(mass_residual(committed, trial)) <= bound


def eligible(committed, trial):
    values = [
        committed.swst,
        trial.candidate.swst,
        trial.dt,
        trial.qd,
        trial.qr,
        trial.qs,
        trial.qout,
        trial.vtop,
        trial.q_supply_available,
    ]
    if not all(math.isfinite(v) for v in values):
        return False
    if trial.dt <= 0.0 or committed.swst < 0.0 or trial.candidate.swst < 0.0:
        return False
    if not trial.complete or trial.missing_mask != 0:
        return False
    if trial.qs < 0.0 or trial.qs > trial.q_supply_available or trial.qout < 0.0:
        return False
    if (
        trial.requires_auto_capacity
        or trial.swqhr2
        or trial.mixed_sign_active_limiter
        or trial.unqualified_divdra
    ):
        return False
    return numeric_mass_ok(committed, trial)


def commit(committed, ledger, trial):
    if not eligible(committed, trial):
        return committed, ledger.clone(), False

    accepted = ledger.clone()
    accepted.q_drain_secondary += trial.dt * trial.qd
    accepted.q_rapid += trial.dt * trial.qr
    accepted.q_supply += trial.dt * trial.qs
    accepted.q_discharge += trial.dt * trial.qout
    accepted.v_top_surface_exchange += trial.vtop
    return trial.candidate, accepted, True


def ledger_net(ledger):
    return (
        ledger.q_drain_secondary
        + ledger.q_rapid
        + ledger.q_supply
        - ledger.q_discharge
        + ledger.v_top_surface_exchange
    )


def split_interval(t0, t1, events):
    cuts = [t0] + [e for e in sorted(set(events)) if t0 < e < t1] + [t1]
    return [(cuts[i], cuts[i + 1]) for i in range(len(cuts) - 1)]


def main():
    rng = random.Random(SEED)

    fixed_accepted = 0
    fixed_attempts = 0
    max_abs_residual = 0.0
    max_rel_residual = 0.0
    while fixed_accepted < 10000:
        fixed_attempts += 1
        s0 = 10.0 ** rng.uniform(-8.0, 2.0)
        dt = 10.0 ** rng.uniform(-4.0, 0.5)
        qd = rng.uniform(-0.5, 2.0)
        qr = rng.uniform(0.0, 1.2)
        q_supply_available = rng.uniform(0.0, 2.0)
        qs = rng.uniform(0.0, q_supply_available)
        qout = rng.uniform(0.0, 1.5)
        vtop = rng.uniform(-0.2, 0.5)
        s1 = s0 + dt * (qd + qr + qs - qout) + vtop
        if s1 < 0.0:
            continue

        committed = State(s0, None)
        ledger = Ledger()
        trial = Trial(
            State(s1, None), dt, qd, qr, qs, qout, vtop, q_supply_available
        )
        before_net = ledger_net(ledger)
        committed_after, ledger_after, did_commit = commit(committed, ledger, trial)
        assert did_commit
        assert committed_after == trial.candidate
        delta_storage = committed_after.swst - committed.swst
        delta_ledger_net = ledger_net(ledger_after) - before_net
        assert abs(delta_storage - delta_ledger_net) <= (
            256.0 * sys.float_info.epsilon * mass_scale(committed, trial)
        )
        residual = mass_residual(committed, trial)
        max_abs_residual = max(max_abs_residual, abs(residual))
        max_rel_residual = max(
            max_rel_residual, abs(residual) / mass_scale(committed, trial)
        )
        fixed_accepted += 1

    missing_mass_failclosed = 0
    for i in range(2000):
        committed = State(rng.uniform(0.1, 10.0), None)
        ledger = Ledger(q_supply=rng.random())
        dt = 10.0 ** rng.uniform(-4.0, 0.5)
        qd = rng.uniform(-1.0, 1.0)
        qr = rng.uniform(0.0, 1.0)
        q_supply_available = rng.uniform(0.0, 2.0)
        qs = rng.uniform(0.0, q_supply_available)
        qout = rng.uniform(0.0, 1.0)
        vtop = rng.uniform(-0.1, 0.1)
        s1 = committed.swst + dt * (qd + qr + qs - qout) + vtop
        if s1 < 0.0:
            s1 = 0.5
            vtop = s1 - committed.swst - dt * (qd + qr + qs - qout)
        trial = Trial(
            State(s1, None),
            dt,
            qd,
            qr,
            qs,
            qout,
            vtop,
            q_supply_available,
            complete=(i % 2 == 0),
            missing_mask=(1 if i % 2 == 0 else 0),
        )
        assert abs(mass_residual(committed, trial)) <= 1.0e-12
        committed_after, ledger_after, did_commit = commit(committed, ledger, trial)
        assert not did_commit
        assert committed_after == committed
        assert ledger_after == ledger
        missing_mass_failclosed += 1

    event_split_cases = 0
    for _ in range(5000):
        t0 = rng.uniform(-100.0, 100.0)
        t1 = t0 + 10.0 ** rng.uniform(-4.0, 2.0)
        events = [rng.uniform(t0 - 1.0, t1 + 1.0) for _ in range(rng.randint(0, 8))]
        segments = split_interval(t0, t1, events)
        assert segments[0][0] == t0
        assert segments[-1][1] == t1
        assert all(b > a for a, b in segments)
        interior = [e for e in sorted(set(events)) if t0 < e < t1]
        boundaries = [b for _, b in segments[:-1]]
        assert boundaries == interior
        event_split_cases += 1

    automatic_wlstar_accepts = 0
    automatic_wlstar_rollbacks = 0
    for _ in range(2000):
        committed = State(rng.uniform(0.1, 10.0), rng.uniform(-2.0, 2.0))
        ledger = Ledger()
        target = rng.uniform(-2.0, 2.0)
        event_trial = Trial(State(committed.swst, target), 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
        committed_after, ledger_after, did_commit = commit(committed, ledger, event_trial)
        assert did_commit
        assert committed_after.wlstar == target
        assert ledger_after == ledger
        automatic_wlstar_accepts += 1

        held_trial = Trial(
            State(committed_after.swst, rng.uniform(-2.0, 2.0)),
            1.0,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            requires_auto_capacity=True,
        )
        committed_held, ledger_held, held_commit = commit(
            committed_after, ledger_after, held_trial
        )
        assert not held_commit
        assert committed_held == committed_after
        assert ledger_held == ledger_after
        automatic_wlstar_rollbacks += 1

    divdra_single_booking_cases = 0
    max_divdra_distribution_residual = 0.0
    for _ in range(5000):
        scalar = 10.0 ** rng.uniform(-8.0, 1.0)
        n = rng.randint(1, 40)
        raw = [rng.random() + 1.0e-12 for _ in range(n)]
        total = sum(raw)
        nodes = [scalar * x / total for x in raw]
        dist_residual = sum(nodes) - scalar
        max_divdra_distribution_residual = max(
            max_divdra_distribution_residual, abs(dist_residual)
        )
        assert abs(dist_residual) <= 128.0 * sys.float_info.epsilon * max(1.0, scalar)

        committed = State(100.0, None)
        ledger = Ledger()
        dt = 10.0 ** rng.uniform(-4.0, 0.5)
        s1 = committed.swst + dt * scalar
        trial = Trial(State(s1, None), dt, scalar, 0.0, 0.0, 0.0, 0.0, 0.0)
        _, ledger_after, did_commit = commit(committed, ledger, trial)
        assert did_commit
        assert abs(ledger_after.q_drain_secondary - dt * scalar) <= (
            256.0 * sys.float_info.epsilon * max(1.0, dt * scalar)
        )
        # Adding both the authoritative scalar and its node distribution would
        # double-book exactly the same physical water and is therefore forbidden.
        wrong_double_booked = dt * scalar + dt * sum(nodes)
        assert wrong_double_booked != ledger_after.q_drain_secondary
        divdra_single_booking_cases += 1

    held_route_rejections = 0
    for flag in (
        "requires_auto_capacity",
        "swqhr2",
        "mixed_sign_active_limiter",
        "unqualified_divdra",
    ):
        for _ in range(1000):
            committed = State(1.0, 0.0)
            ledger = Ledger()
            kwargs = {flag: True}
            trial = Trial(State(1.0, 0.1), 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, **kwargs)
            committed_after, ledger_after, did_commit = commit(committed, ledger, trial)
            assert not did_commit
            assert committed_after == committed
            assert ledger_after == ledger
            held_route_rejections += 1

    print(f"FPM08D6_FIXED_WEIR_ACCEPTED_CASES={fixed_accepted}")
    print(f"FPM08D6_FIXED_WEIR_ATTEMPTS={fixed_attempts}")
    print(f"FPM08D6_MISSING_MASS_FAILCLOSED_CASES={missing_mass_failclosed}")
    print(f"FPM08D6_EVENT_SPLIT_CASES={event_split_cases}")
    print(f"FPM08D6_AUTOMATIC_WLSTAR_ACCEPTED_CONTROL_ONLY_CASES={automatic_wlstar_accepts}")
    print(f"FPM08D6_AUTOMATIC_CAPACITY_HELD_WLSTAR_ROLLBACK_CASES={automatic_wlstar_rollbacks}")
    print(f"FPM08D6_DIVDRA_SINGLE_BOOKING_CASES={divdra_single_booking_cases}")
    print(f"FPM08D6_HELD_ROUTE_REJECTIONS={held_route_rejections}")
    print(f"FPM08D6_MAX_ACCEPTED_MASS_RESIDUAL_ABS={max_abs_residual:.17g}")
    print(f"FPM08D6_MAX_ACCEPTED_MASS_RESIDUAL_REL={max_rel_residual:.17g}")
    print(f"FPM08D6_MAX_DIVDRA_DISTRIBUTION_RESIDUAL_ABS={max_divdra_distribution_residual:.17g}")
    print("FPM08D6_TRANSACTION_ORACLE PASS")


if __name__ == "__main__":
    main()
