from __future__ import annotations
from dataclasses import dataclass, replace
from math import sqrt


@dataclass(frozen=True)
class MatrixState:
    theta: float
    theta_s: float = 0.45
    theta_r: float = 0.05
    depth_cm: float = 20.0


@dataclass(frozen=True)
class MacroporeState:
    icp_bottom_domain: int
    sorptivity: float
    theta_sorption_ref: float
    absorption_time: float
    volume: float
    water: float
    dynamic_volume: float


@dataclass(frozen=True)
class MassReceipt:
    top_input: float
    matrix_gain: float
    macro_storage_change: float
    rapid_outflow: float
    overflow: float
    residual: float


@dataclass(frozen=True)
class Candidate:
    matrix: MatrixState
    macropore: MacroporeState
    receipt: MassReceipt


def candidate_step(
    matrix: MatrixState,
    macro: MacroporeState,
    q_top: float,
    dt: float,
    sorp_max: float = 0.50,
    sorp_alpha: float = 0.5,
    rapid_resistance: float = 20.0,
    rapid_head: float = 0.0,
    capacity: float | None = None,
) -> Candidate:
    deficit = max(0.0, matrix.theta_s - matrix.theta)
    sorp = macro.sorptivity
    theta_ref = macro.theta_sorption_ref
    tabs = macro.absorption_time

    amount = 0.0
    if deficit >= 1.0e-8:
        if tabs < 1.0e-8:
            theta_ref = matrix.theta_s
            sorp = sorp_max * (deficit / (matrix.theta_s - matrix.theta_r)) ** sorp_alpha
            active = sorp
        elif theta_ref - matrix.theta > 1.0e-8:
            active = sorp_max * ((theta_ref - matrix.theta) / (matrix.theta_s - matrix.theta_r)) ** sorp_alpha
        else:
            active = 0.0

        amount = active * 0.08 * (4.0 * 0.95 * 10.0 / 4.0) * (sqrt(tabs + dt) - sqrt(tabs))
        theta_ref = theta_ref + 0.95 * 0.08 * (4.0 / 4.0) * sorp * (sqrt(tabs + dt) - sqrt(tabs))
        tabs += dt

    incoming = q_top * dt
    available = macro.water + incoming
    absorbed = min(max(0.0, amount), available)

    rapid_amount = min(
        max(0.0, available - absorbed),
        max(0.0, rapid_head / rapid_resistance) * dt,
    )

    remaining = available - absorbed - rapid_amount
    cap = macro.volume if capacity is None else capacity
    overflow_amount = max(0.0, remaining - cap)
    water1 = remaining - overflow_amount

    matrix_active_depth = (1.0 - 0.08) * matrix.depth_cm
    theta1 = min(matrix.theta_s, matrix.theta + absorbed / matrix_active_depth)
    matrix_gain = (theta1 - matrix.theta) * matrix_active_depth

    macro1 = replace(
        macro,
        sorptivity=sorp,
        theta_sorption_ref=theta_ref,
        absorption_time=tabs,
        water=water1,
    )
    matrix1 = replace(matrix, theta=theta1)

    dmacro = water1 - macro.water
    residual = dmacro + matrix_gain + rapid_amount + overflow_amount - incoming

    return Candidate(
        matrix1,
        macro1,
        MassReceipt(q_top, matrix_gain, dmacro, rapid_amount, overflow_amount, residual),
    )


def initial_sorptivity(theta: float, theta_s: float = 0.45, theta_r: float = 0.05) -> float:
    return 0.50 * ((theta_s - theta) / (theta_s - theta_r)) ** 0.5


def run():
    matrix = MatrixState(theta=0.16)
    accepted = MacroporeState(4, 0.0, 0.0, 0.0, 1.2, 0.7, 0.03)

    clean = candidate_step(matrix, accepted, q_top=0.2, dt=0.1)
    assert abs(clean.receipt.residual) < 1.0e-14
    assert accepted.water == 0.7 and matrix.theta == 0.16

    rejected = candidate_step(matrix, accepted, q_top=0.2, dt=0.1)
    del rejected
    retry = candidate_step(matrix, accepted, q_top=0.2, dt=0.1)
    assert retry == clean

    aged = replace(
        accepted,
        sorptivity=initial_sorptivity(matrix.theta),
        theta_sorption_ref=0.47,
        absorption_time=0.5,
    )
    aged_candidate = candidate_step(matrix, aged, q_top=0.2, dt=0.1)

    assert clean.receipt.matrix_gain > 4.0 * aged_candidate.receipt.matrix_gain
    assert clean.matrix.theta > aged_candidate.matrix.theta
    assert abs(aged_candidate.receipt.residual) < 1.0e-14

    print("PPA_WU05A4_R2_PRESCRIBED_G1_G4=PASS")


if __name__ == "__main__":
    run()
