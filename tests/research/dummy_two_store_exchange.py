"""Reciprocal two-store surface-groundwater exchange for RIBASIM-DUMMY-09.

Both stores are linear in head:

    S_s = A_s * h_s
    S_g = A_g * h_g

Exchange rate is q = C * (h_s - h_g), positive from surface to groundwater.
No management or external flux is present in this work unit.
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
class TwoStoreConfig:
    surface_storage_m2: float
    groundwater_storage_m2: float
    conductance_m2_per_time: float

    def __post_init__(self) -> None:
        for name in (
            "surface_storage_m2",
            "groundwater_storage_m2",
            "conductance_m2_per_time",
        ):
            object.__setattr__(self, name, _finite(name, getattr(self, name)))
        if self.surface_storage_m2 <= 0.0:
            raise ValueError("surface_storage_m2 must be positive")
        if self.groundwater_storage_m2 <= 0.0:
            raise ValueError("groundwater_storage_m2 must be positive")
        if self.conductance_m2_per_time < 0.0:
            raise ValueError("conductance_m2_per_time must be non-negative")

    @property
    def inverse_storage_sum(self) -> float:
        return 1.0 / self.surface_storage_m2 + 1.0 / self.groundwater_storage_m2

    @property
    def decay_rate_per_time(self) -> float:
        return self.conductance_m2_per_time * self.inverse_storage_sum


@dataclass(frozen=True)
class TwoStoreState:
    surface_head_m: float
    groundwater_head_m: float

    def __post_init__(self) -> None:
        object.__setattr__(
            self, "surface_head_m", _finite("surface_head_m", self.surface_head_m)
        )
        object.__setattr__(
            self,
            "groundwater_head_m",
            _finite("groundwater_head_m", self.groundwater_head_m),
        )

    @property
    def head_difference_m(self) -> float:
        return self.surface_head_m - self.groundwater_head_m


@dataclass(frozen=True)
class TwoStoreStep:
    start: TwoStoreState
    end: TwoStoreState
    dt: float
    exchange_volume_m3: float
    mu: float
    amplification: float
    surface_storage_change_m3: float
    groundwater_storage_change_m3: float
    total_storage_residual_m3: float
    exchange_equation_residual_m3: float


def total_storage_m3(config: TwoStoreConfig, state: TwoStoreState) -> float:
    return (
        config.surface_storage_m2 * state.surface_head_m
        + config.groundwater_storage_m2 * state.groundwater_head_m
    )


def weighted_equilibrium_head_m(
    config: TwoStoreConfig,
    state: TwoStoreState,
) -> float:
    return total_storage_m3(config, state) / (
        config.surface_storage_m2 + config.groundwater_storage_m2
    )


def continuous_state(
    config: TwoStoreConfig,
    start: TwoStoreState,
    *,
    dt: float,
) -> TwoStoreState:
    dt = _finite("dt", dt)
    if dt < 0.0:
        raise ValueError("dt must be non-negative")

    equilibrium = weighted_equilibrium_head_m(config, start)
    difference = start.head_difference_m * math.exp(
        -config.decay_rate_per_time * dt
    )
    total_storage = (
        config.surface_storage_m2 + config.groundwater_storage_m2
    )

    surface = equilibrium + (
        config.groundwater_storage_m2 / total_storage
    ) * difference
    groundwater = equilibrium - (
        config.surface_storage_m2 / total_storage
    ) * difference

    return TwoStoreState(
        surface_head_m=surface,
        groundwater_head_m=groundwater,
    )


def continuous_exchange_volume_m3(
    config: TwoStoreConfig,
    start: TwoStoreState,
    *,
    dt: float,
) -> float:
    end = continuous_state(config, start, dt=dt)
    return config.surface_storage_m2 * (
        start.surface_head_m - end.surface_head_m
    )


def trapezoid_step(
    config: TwoStoreConfig,
    start: TwoStoreState,
    *,
    dt: float,
) -> TwoStoreStep:
    dt = _finite("dt", dt)
    if dt <= 0.0:
        raise ValueError("dt must be positive")

    mu = 0.5 * config.conductance_m2_per_time * dt * config.inverse_storage_sum
    amplification = (1.0 - mu) / (1.0 + mu)
    exchange = (
        config.conductance_m2_per_time
        * dt
        * start.head_difference_m
        / (1.0 + mu)
    )

    surface_end = (
        start.surface_head_m
        - exchange / config.surface_storage_m2
    )
    groundwater_end = (
        start.groundwater_head_m
        + exchange / config.groundwater_storage_m2
    )
    end = TwoStoreState(surface_end, groundwater_end)

    surface_change = config.surface_storage_m2 * (
        end.surface_head_m - start.surface_head_m
    )
    groundwater_change = config.groundwater_storage_m2 * (
        end.groundwater_head_m - start.groundwater_head_m
    )
    total_residual = surface_change + groundwater_change

    expected_exchange = (
        config.conductance_m2_per_time
        * dt
        * 0.5
        * (start.head_difference_m + end.head_difference_m)
    )
    exchange_residual = exchange - expected_exchange

    return TwoStoreStep(
        start=start,
        end=end,
        dt=dt,
        exchange_volume_m3=exchange,
        mu=mu,
        amplification=amplification,
        surface_storage_change_m3=surface_change,
        groundwater_storage_change_m3=groundwater_change,
        total_storage_residual_m3=total_residual,
        exchange_equation_residual_m3=exchange_residual,
    )


def trapezoid_run(
    config: TwoStoreConfig,
    start: TwoStoreState,
    *,
    dts: tuple[float, ...] | list[float],
) -> tuple[TwoStoreStep, ...]:
    if not dts:
        raise ValueError("dts must contain at least one step")
    state = start
    steps = []
    for dt in dts:
        step = trapezoid_step(config, state, dt=dt)
        steps.append(step)
        state = step.end
    return tuple(steps)
