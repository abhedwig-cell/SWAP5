"""Naive active-set Picard coupling map for RIBASIM-DUMMY-06.

The map deliberately combines the qualified DUMMY-05 management clipping rule
with an undamped Picard exchange update. It exists to test whether local rule
compliance implies coupled numerical convergence. It does not represent a
production Ribasim or iMOD Coupler algorithm.
"""

from __future__ import annotations

from dataclasses import dataclass
import math

from dummy_head_management_complementarity import (
    HeadDependentManagementProblem,
)


class ActiveSetPhysicalFloorError(RuntimeError):
    """A provisional active-set iterate crosses the physical Basin datum."""


def _finite(name: str, value: float) -> float:
    value = float(value)
    if not math.isfinite(value):
        raise ValueError(f"{name} must be finite")
    return value


@dataclass(frozen=True)
class ActiveSetIterationState:
    exchange_guess_m3: float
    provisional_regime: str
    delivered_m3: float
    provisional_end_level_m: float
    next_exchange_m3: float
    balance_residual_m: float


@dataclass(frozen=True)
class ActiveSetPicardProblem:
    oracle: HeadDependentManagementProblem

    @property
    def coupling_stiffness(self) -> float:
        return self.oracle.coupling_stiffness

    @property
    def explicit_start_exchange_m3(self) -> float:
        return (
            self.oracle.conductance_m2_per_time
            * self.oracle.dt
            * (self.oracle.start_level_m - self.oracle.groundwater_head_m)
        )

    @property
    def full_threshold_exchange_m3(self) -> float:
        return (
            self.oracle.basin_area_m2
            * (
                self.oracle.start_level_m
                - self.oracle.management_min_level_m
            )
            - self.oracle.requested_delivery_m3
        )

    @property
    def zero_threshold_exchange_m3(self) -> float:
        return (
            self.oracle.basin_area_m2
            * (
                self.oracle.start_level_m
                - self.oracle.management_min_level_m
            )
        )

    def step(self, exchange_guess_m3: float) -> ActiveSetIterationState:
        exchange = _finite("exchange_guess_m3", exchange_guess_m3)
        area = self.oracle.basin_area_m2
        capacity = (
            area
            * (
                self.oracle.start_level_m
                - self.oracle.management_min_level_m
            )
            - exchange
        )

        if capacity >= self.oracle.requested_delivery_m3:
            regime = "FULL"
            delivered = self.oracle.requested_delivery_m3
        elif capacity <= 0.0:
            regime = "ZERO"
            delivered = 0.0
        else:
            regime = "CURTAILED"
            delivered = capacity

        end_level = self.oracle.start_level_m - (delivered + exchange) / area
        tolerance = 1.0e-12 * max(
            1.0,
            abs(self.oracle.start_level_m),
            abs(self.oracle.datum_m),
        )
        if end_level < self.oracle.datum_m - tolerance:
            raise ActiveSetPhysicalFloorError(
                "provisional active-set iterate lies below physical datum: "
                f"end_level={end_level:.17g}, datum={self.oracle.datum_m:.17g}"
            )

        next_exchange = self.oracle.exchange_at_levels(end_level)
        balance_residual = end_level - (
            self.oracle.start_level_m - (delivered + exchange) / area
        )

        return ActiveSetIterationState(
            exchange_guess_m3=exchange,
            provisional_regime=regime,
            delivered_m3=delivered,
            provisional_end_level_m=end_level,
            next_exchange_m3=next_exchange,
            balance_residual_m=balance_residual,
        )

    def states(
        self,
        steps: int,
        *,
        initial_exchange_m3: float | None = None,
    ) -> tuple[ActiveSetIterationState, ...]:
        if steps < 0:
            raise ValueError("steps must be non-negative")
        exchange = (
            self.explicit_start_exchange_m3
            if initial_exchange_m3 is None
            else _finite("initial_exchange_m3", initial_exchange_m3)
        )
        states = []
        for _ in range(steps):
            state = self.step(exchange)
            states.append(state)
            exchange = state.next_exchange_m3
        return tuple(states)

    def exchange_guesses(
        self,
        steps: int,
        *,
        initial_exchange_m3: float | None = None,
    ) -> tuple[float, ...]:
        initial = (
            self.explicit_start_exchange_m3
            if initial_exchange_m3 is None
            else _finite("initial_exchange_m3", initial_exchange_m3)
        )
        states = self.states(steps, initial_exchange_m3=initial)
        return (initial,) + tuple(state.next_exchange_m3 for state in states)
