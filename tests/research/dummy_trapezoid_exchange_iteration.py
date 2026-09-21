"""Analytic trapezoidal head-exchange iteration for RIBASIM-DUMMY-04.

This module freezes one discrete temporal contract:

    V = C * dt * (((h0 + h1) / 2) - hgw)
    h1 = h0 - (U + V) / A

where signed V > 0 is Basin-to-groundwater infiltration and U is a managed
withdrawal frozen for this numerical sub-experiment.

The resulting Picard map is linear and has exact error factor
-lambda, lambda = C * dt / (2 * A).
"""

from __future__ import annotations

from dataclasses import dataclass
import math


def _finite(name: str, value: float) -> float:
    value = float(value)
    if not math.isfinite(value):
        raise ValueError(f"{name} must be finite")
    return value


@dataclass(frozen=True)
class TrapezoidExchangeProblem:
    basin_area_m2: float
    conductance_m2_per_time: float
    dt: float
    start_level_m: float
    groundwater_head_m: float
    managed_delivery_m3: float = 0.0

    def __post_init__(self) -> None:
        area = _finite("basin_area_m2", self.basin_area_m2)
        conductance = _finite(
            "conductance_m2_per_time", self.conductance_m2_per_time
        )
        dt = _finite("dt", self.dt)
        start = _finite("start_level_m", self.start_level_m)
        groundwater = _finite("groundwater_head_m", self.groundwater_head_m)
        delivery = _finite("managed_delivery_m3", self.managed_delivery_m3)

        if area <= 0.0:
            raise ValueError("basin_area_m2 must be positive")
        if conductance < 0.0:
            raise ValueError("conductance_m2_per_time must be non-negative")
        if dt <= 0.0:
            raise ValueError("dt must be positive")
        if delivery < 0.0:
            raise ValueError("managed_delivery_m3 must be non-negative")

        object.__setattr__(self, "basin_area_m2", area)
        object.__setattr__(self, "conductance_m2_per_time", conductance)
        object.__setattr__(self, "dt", dt)
        object.__setattr__(self, "start_level_m", start)
        object.__setattr__(self, "groundwater_head_m", groundwater)
        object.__setattr__(self, "managed_delivery_m3", delivery)

    @property
    def exchange_scale_m2(self) -> float:
        return self.conductance_m2_per_time * self.dt

    @property
    def coupling_stiffness(self) -> float:
        return self.exchange_scale_m2 / (2.0 * self.basin_area_m2)

    def end_level_from_exchange(self, signed_exchange_m3: float) -> float:
        exchange = _finite("signed_exchange_m3", signed_exchange_m3)
        return self.start_level_m - (
            self.managed_delivery_m3 + exchange
        ) / self.basin_area_m2

    def picard_map(self, signed_exchange_guess_m3: float) -> float:
        end_level = self.end_level_from_exchange(signed_exchange_guess_m3)
        mean_level = 0.5 * (self.start_level_m + end_level)
        return self.exchange_scale_m2 * (
            mean_level - self.groundwater_head_m
        )

    @property
    def fixed_point_exchange_m3(self) -> float:
        lam = self.coupling_stiffness
        numerator = (
            self.exchange_scale_m2
            * (self.start_level_m - self.groundwater_head_m)
            - lam * self.managed_delivery_m3
        )
        return numerator / (1.0 + lam)

    @property
    def fixed_point_end_level_m(self) -> float:
        return self.end_level_from_exchange(self.fixed_point_exchange_m3)

    @property
    def explicit_start_exchange_m3(self) -> float:
        return self.exchange_scale_m2 * (
            self.start_level_m - self.groundwater_head_m
        )

    @property
    def one_corrector_exchange_m3(self) -> float:
        return self.picard_map(self.explicit_start_exchange_m3)

    def exchange_equation_residual_m3(self, signed_exchange_m3: float) -> float:
        exchange = _finite("signed_exchange_m3", signed_exchange_m3)
        return exchange - self.picard_map(exchange)

    def water_balance_level_residual_m(
        self,
        signed_exchange_m3: float,
        end_level_m: float,
    ) -> float:
        end_level = _finite("end_level_m", end_level_m)
        return end_level - self.end_level_from_exchange(signed_exchange_m3)

    def picard_sequence(
        self,
        iterations: int,
        *,
        initial_exchange_m3: float | None = None,
    ) -> tuple[float, ...]:
        if iterations < 0:
            raise ValueError("iterations must be non-negative")
        value = (
            self.explicit_start_exchange_m3
            if initial_exchange_m3 is None
            else _finite("initial_exchange_m3", initial_exchange_m3)
        )
        values = [value]
        for _ in range(iterations):
            value = self.picard_map(value)
            values.append(value)
        return tuple(values)

    def error_sequence(
        self,
        iterations: int,
        *,
        initial_exchange_m3: float | None = None,
    ) -> tuple[float, ...]:
        fixed = self.fixed_point_exchange_m3
        return tuple(
            value - fixed
            for value in self.picard_sequence(
                iterations,
                initial_exchange_m3=initial_exchange_m3,
            )
        )
