"""Stabilization experiments for RIBASIM-DUMMY-07.

Two research algorithms are isolated here:

1. under-relaxation of the qualified DUMMY-06 active-set Picard map;
2. a direct active-set solve assembled from fixed-delivery DUMMY-04 solves.

Neither changes the physical or management equations. Neither is a production
Ribasim or iMOD Coupler implementation.
"""

from __future__ import annotations

from dataclasses import dataclass
import math

from dummy_active_set_picard import ActiveSetPicardProblem
from dummy_head_management_complementarity import (
    HeadDependentManagementProblem,
    PhysicalStorageInfeasibleError,
)


def _finite(name: str, value: float) -> float:
    value = float(value)
    if not math.isfinite(value):
        raise ValueError(f"{name} must be finite")
    return value


@dataclass(frozen=True)
class RelaxedActiveSetState:
    exchange_guess_m3: float
    provisional_regime: str
    delivered_m3: float
    provisional_end_level_m: float
    raw_next_exchange_m3: float
    relaxed_next_exchange_m3: float


@dataclass(frozen=True)
class UnderRelaxedActiveSet:
    problem: ActiveSetPicardProblem
    omega: float

    def __post_init__(self) -> None:
        omega = _finite("omega", self.omega)
        if not 0.0 < omega <= 1.0:
            raise ValueError("omega must satisfy 0 < omega <= 1")
        object.__setattr__(self, "omega", omega)

    @property
    def coupling_stiffness(self) -> float:
        return self.problem.coupling_stiffness

    @property
    def fixed_full_zero_error_factor(self) -> float:
        return 1.0 - self.omega * (1.0 + self.coupling_stiffness)

    @property
    def curtailed_error_factor(self) -> float:
        return 1.0 - self.omega

    def step(self, exchange_guess_m3: float) -> RelaxedActiveSetState:
        exchange = _finite("exchange_guess_m3", exchange_guess_m3)
        raw = self.problem.step(exchange)
        relaxed = (
            (1.0 - self.omega) * exchange
            + self.omega * raw.next_exchange_m3
        )
        return RelaxedActiveSetState(
            exchange_guess_m3=exchange,
            provisional_regime=raw.provisional_regime,
            delivered_m3=raw.delivered_m3,
            provisional_end_level_m=raw.provisional_end_level_m,
            raw_next_exchange_m3=raw.next_exchange_m3,
            relaxed_next_exchange_m3=relaxed,
        )

    def exchange_sequence(
        self,
        steps: int,
        *,
        initial_exchange_m3: float | None = None,
    ) -> tuple[float, ...]:
        if steps < 0:
            raise ValueError("steps must be non-negative")
        value = (
            self.problem.explicit_start_exchange_m3
            if initial_exchange_m3 is None
            else _finite("initial_exchange_m3", initial_exchange_m3)
        )
        values = [value]
        for _ in range(steps):
            value = self.step(value).relaxed_next_exchange_m3
            values.append(value)
        return tuple(values)

    def states(
        self,
        steps: int,
        *,
        initial_exchange_m3: float | None = None,
    ) -> tuple[RelaxedActiveSetState, ...]:
        if steps < 0:
            raise ValueError("steps must be non-negative")
        value = (
            self.problem.explicit_start_exchange_m3
            if initial_exchange_m3 is None
            else _finite("initial_exchange_m3", initial_exchange_m3)
        )
        states = []
        for _ in range(steps):
            state = self.step(value)
            states.append(state)
            value = state.relaxed_next_exchange_m3
        return tuple(states)


@dataclass(frozen=True)
class DirectActiveSetSolution:
    regime: str
    requested_delivery_m3: float
    delivered_m3: float
    shortage_m3: float
    signed_exchange_m3: float
    end_level_m: float
    exchange_residual_m3: float
    balance_residual_m: float


def direct_active_set_solve(
    problem: HeadDependentManagementProblem,
) -> DirectActiveSetSolution:
    """Solve the frozen piecewise problem without calling problem.solve()."""

    tol = 1.0e-12 * max(
        1.0,
        abs(problem.start_level_m),
        abs(problem.groundwater_head_m),
        abs(problem.management_min_level_m),
        abs(problem.datum_m),
    )

    full = problem.fixed_delivery_problem(problem.requested_delivery_m3)
    full_end = full.fixed_point_end_level_m
    zero = problem.fixed_delivery_problem(0.0)
    zero_end = zero.fixed_point_end_level_m

    if zero_end < problem.datum_m - tol:
        raise PhysicalStorageInfeasibleError(
            "direct active-set zero-withdrawal trial lies below physical datum: "
            f"end_level={zero_end:.17g}, datum={problem.datum_m:.17g}"
        )

    if full_end >= problem.management_min_level_m - tol:
        regime = "FULL"
        delivered = problem.requested_delivery_m3
        exchange = full.fixed_point_exchange_m3
        end_level = full_end
    elif zero_end <= problem.management_min_level_m + tol:
        regime = "ZERO"
        delivered = 0.0
        exchange = zero.fixed_point_exchange_m3
        end_level = zero_end
    else:
        regime = "CURTAILED"
        end_level = problem.management_min_level_m
        exchange = problem.exchange_at_levels(end_level)
        delivered = problem.delivery_for_end_level(end_level)

        volume_tol = (
            problem.basin_area_m2
            * max(1.0, abs(problem.start_level_m), abs(end_level))
            * 1.0e-12
        )
        if delivered < -volume_tol:
            raise RuntimeError("direct active-set produced negative delivery")
        if delivered > problem.requested_delivery_m3 + volume_tol:
            raise RuntimeError("direct active-set delivery exceeds request")
        delivered = min(problem.requested_delivery_m3, max(0.0, delivered))

    check = problem.fixed_delivery_problem(delivered)
    exchange_residual = exchange - check.picard_map(exchange)
    balance_residual = end_level - check.end_level_from_exchange(exchange)

    return DirectActiveSetSolution(
        regime=regime,
        requested_delivery_m3=problem.requested_delivery_m3,
        delivered_m3=delivered,
        shortage_m3=problem.requested_delivery_m3 - delivered,
        signed_exchange_m3=exchange,
        end_level_m=end_level,
        exchange_residual_m3=exchange_residual,
        balance_residual_m=balance_residual,
    )
