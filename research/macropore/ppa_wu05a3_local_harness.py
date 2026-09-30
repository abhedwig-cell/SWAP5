from __future__ import annotations
from dataclasses import dataclass, replace
from math import sqrt


@dataclass(frozen=True)
class MatrixState:
    theta: float
    theta_s: float
    theta_r: float


@dataclass(frozen=True)
class MacroParams:
    volume: float
    pp: float
    dz: float
    dipo: float
    awl: float
    sorp_max: float
    sorp_alpha: float
    fr_redu_q: float = 1.0
    q_sorp_max: float = 1.0e3


@dataclass(frozen=True)
class MacroHistory:
    storage: float
    sorptivity: float = 0.0
    theta_sorption_ref: float = 0.0
    absorption_time: float = 0.0


@dataclass(frozen=True)
class StepResult:
    q_top: float
    q_absorb: float
    q_rapid: float
    q_exchange: float
    storage0: float
    storage1: float
    history1: MacroHistory
    mass_residual: float


def source_sorptivity_absorption(matrix: MatrixState, p: MacroParams, h: MacroHistory, dt: float):
    """SWABS=1 subset from exact B1.11 macrorate.f90 lines 1717-1747."""
    crit = 1.0e-8
    sat_def = max(0.0, matrix.theta_s - matrix.theta)
    time = h.absorption_time

    if sat_def < crit:
        return 0.0, h.sorptivity, h.theta_sorption_ref, True

    if time < 1.0e-8:
        theta_ref = matrix.theta_s
        denom = matrix.theta_s - matrix.theta_r
        sorp = p.sorp_max * (max(0.0, matrix.theta_s - matrix.theta) / denom) ** p.sorp_alpha
        sorp_act = sorp
    elif (h.theta_sorption_ref - matrix.theta) > crit:
        theta_ref = h.theta_sorption_ref
        denom = matrix.theta_s - matrix.theta_r
        sorp = h.sorptivity
        sorp_act = p.sorp_max * ((theta_ref - matrix.theta) / denom) ** p.sorp_alpha
    else:
        theta_ref = h.theta_sorption_ref
        sorp = h.sorptivity
        sorp_act = 0.0

    amount = sorp_act * p.pp * (4.0 * p.awl * p.dz / p.dipo) * (sqrt(time + dt) - sqrt(time))
    amount = min(p.q_sorp_max * dt * p.dz, amount)
    end_event = amount / dt <= 1.0e-7
    return max(0.0, amount), sorp, theta_ref, end_event


def accepted_history_update(p: MacroParams, h: MacroHistory, sorp: float, theta_ref: float, end_event: bool, dt: float):
    """Accepted-history subset from exact B1.11 macropore.f90 lines 1423-1451."""
    if end_event:
        return replace(h, sorptivity=0.0, theta_sorption_ref=0.0, absorption_time=0.0)

    time = h.absorption_time
    theta_ref_new = theta_ref + p.awl * p.pp * (4.0 / p.dipo) * sorp * (sqrt(time + dt) - sqrt(time))
    return replace(h, sorptivity=sorp, theta_sorption_ref=theta_ref_new, absorption_time=time + dt)


def step(enabled: bool, q_top: float, matrix: MatrixState, p: MacroParams, h: MacroHistory, dt: float, allow_absorption: bool = True) -> StepResult:
    if not enabled:
        return StepResult(0.0, 0.0, 0.0, 0.0, h.storage, h.storage, h, 0.0)

    absorbed = 0.0
    sorp = h.sorptivity
    theta_ref = h.theta_sorption_ref
    end_event = True
    if allow_absorption:
        absorbed, sorp, theta_ref, end_event = source_sorptivity_absorption(matrix, p, h, dt)

    q_absorb = min(absorbed / dt, max(0.0, h.storage / dt + q_top))
    q_rapid = 0.0  # held out until E5
    storage1 = min(p.volume, max(0.0, h.storage + (q_top - q_absorb - q_rapid) * dt))

    accepted = accepted_history_update(p, h, sorp, theta_ref, end_event, dt)
    accepted = replace(accepted, storage=storage1)

    residual = storage1 - h.storage - (q_top - q_absorb - q_rapid) * dt
    return StepResult(q_top, q_absorb, q_rapid, q_absorb, h.storage, storage1, accepted, residual)


def run_cases():
    dt = 0.1
    matrix_dry = MatrixState(theta=0.16, theta_s=0.45, theta_r=0.05)
    base = MacroParams(volume=1.2, pp=0.08, dz=10.0, dipo=4.0, awl=0.95, sorp_max=0.20, sorp_alpha=0.5)

    e0 = step(False, 5.0, matrix_dry, base, MacroHistory(storage=0.0), dt)
    assert e0.storage1 == 0.0 and e0.q_absorb == 0.0 and e0.q_top == 0.0

    e1 = step(True, 5.0, matrix_dry, replace(base, sorp_max=0.005), MacroHistory(storage=0.0), dt)
    assert e1.q_top > e1.q_absorb and e1.storage1 > 0.0
    assert abs(e1.mass_residual) < 1e-14

    strong = replace(base, sorp_max=0.50)
    e2 = step(True, 0.5, matrix_dry, strong, MacroHistory(storage=0.7), dt)
    assert e2.q_absorb > e2.q_top and e2.storage1 < e2.storage0
    assert abs(e2.mass_residual) < 1e-14

    h = MacroHistory(storage=0.8)
    series = []
    for k in range(6):
        r = step(True, 0.6, matrix_dry, strong, h, dt)
        series.append(r)
        h = r.history1
    assert series[1].q_absorb <= series[0].q_absorb + 1e-15
    assert max(abs(x.mass_residual) for x in series) < 1e-14

    print("PPA_WU05A3_E0_E2_LOCAL=PASS")


if __name__ == "__main__":
    run_cases()
