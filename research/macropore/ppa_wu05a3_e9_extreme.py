from dataclasses import dataclass
from math import sqrt


@dataclass(frozen=True)
class Params:
    capacity: float = 1.2
    dt: float = 0.05
    theta: float = 0.16
    theta_s: float = 0.45
    theta_r: float = 0.05
    pp: float = 0.08
    dz: float = 10.0
    dipo: float = 4.0
    awl: float = 0.95
    sorp_max: float = 0.50
    sorp_alpha: float = 0.5
    drain_resistance: float = 20.0
    drain_head: float = 15.0


def sorptivity_amount(p: Params, absorption_time: float = 0.0) -> float:
    deficit = max(0.0, p.theta_s - p.theta)
    sorp = p.sorp_max * (deficit / (p.theta_s - p.theta_r)) ** p.sorp_alpha
    return (
        sorp * p.pp * (4.0 * p.awl * p.dz / p.dipo)
        * (sqrt(absorption_time + p.dt) - sqrt(absorption_time))
    )


def stress_step(qin: float, storage: float, p: Params, absorption_time: float = 0.0):
    incoming = qin * p.dt
    available = storage + incoming

    absorbed = min(available, sorptivity_amount(p, absorption_time))
    remaining = available - absorbed

    drain_rate = max(0.0, p.drain_head / p.drain_resistance)
    drained = min(remaining, drain_rate * p.dt)
    remaining -= drained

    overflow = max(0.0, remaining - p.capacity)
    storage1 = remaining - overflow

    residual = storage1 - storage - (incoming - absorbed - drained - overflow)
    return storage1, absorbed / p.dt, drained / p.dt, overflow / p.dt, residual


if __name__ == "__main__":
    p = Params()
    storage0 = 0.4

    rows = []
    for qin in (0, 1, 5, 10, 25, 50, 100, 250):
        row = (qin, *stress_step(qin, storage0, p))
        rows.append(row)
        _, storage1, qabs, qdrain, qoverflow, residual = row
        assert -1.0e-14 <= storage1 <= p.capacity + 1.0e-14
        assert qabs >= 0.0 and qdrain >= 0.0 and qoverflow >= 0.0
        assert abs(residual) < 1.0e-13

    assert rows[-1][4] > 0.0
    print("PPA_WU05A3_E9_EXTREME_RAIN_LOCAL=PASS")
