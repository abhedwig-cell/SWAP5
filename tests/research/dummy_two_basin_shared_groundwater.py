"""Exact two-Basin + shared-groundwater oracle for RIBASIM-DUMMY-17."""

from __future__ import annotations

from dataclasses import dataclass
import math


def _finite(name: str, value: float) -> float:
    value = float(value)
    if not math.isfinite(value):
        raise ValueError(f"{name} must be finite")
    return value


@dataclass(frozen=True)
class TwoBasinSharedGroundwaterConfig:
    surface_storage_m2: float
    groundwater_storage_m2: float
    exchange_conductance_m2_per_time: float
    routing_conductance_m2_per_time: float

    def __post_init__(self) -> None:
        A = _finite("surface_storage_m2", self.surface_storage_m2)
        Ag = _finite("groundwater_storage_m2", self.groundwater_storage_m2)
        C = _finite(
            "exchange_conductance_m2_per_time",
            self.exchange_conductance_m2_per_time,
        )
        Kr = _finite(
            "routing_conductance_m2_per_time",
            self.routing_conductance_m2_per_time,
        )
        if A <= 0.0 or Ag <= 0.0:
            raise ValueError("storage coefficients must be positive")
        if C < 0.0 or Kr < 0.0:
            raise ValueError("conductances must be non-negative")
        object.__setattr__(self, "surface_storage_m2", A)
        object.__setattr__(self, "groundwater_storage_m2", Ag)
        object.__setattr__(self, "exchange_conductance_m2_per_time", C)
        object.__setattr__(self, "routing_conductance_m2_per_time", Kr)


@dataclass(frozen=True)
class TwoBasinSharedGroundwaterState:
    basin1_head_m: float
    basin2_head_m: float
    groundwater_head_m: float

    def __post_init__(self) -> None:
        object.__setattr__(
            self,
            "basin1_head_m",
            _finite("basin1_head_m", self.basin1_head_m),
        )
        object.__setattr__(
            self,
            "basin2_head_m",
            _finite("basin2_head_m", self.basin2_head_m),
        )
        object.__setattr__(
            self,
            "groundwater_head_m",
            _finite("groundwater_head_m", self.groundwater_head_m),
        )


@dataclass(frozen=True)
class PathFlows:
    routing_1_to_2_m3_per_time: float
    basin1_to_groundwater_m3_per_time: float
    basin2_to_groundwater_m3_per_time: float


@dataclass(frozen=True)
class StorageRates:
    basin1_m3_per_time: float
    basin2_m3_per_time: float
    groundwater_m3_per_time: float

    @property
    def total_m3_per_time(self) -> float:
        return (
            self.basin1_m3_per_time
            + self.basin2_m3_per_time
            + self.groundwater_m3_per_time
        )


@dataclass(frozen=True)
class ModeState:
    surface_difference_m: float
    surface_mean_m: float
    surface_groundwater_contrast_m: float
    weighted_total_storage_m3: float


def total_storage_m3(
    config: TwoBasinSharedGroundwaterConfig,
    state: TwoBasinSharedGroundwaterState,
) -> float:
    A = config.surface_storage_m2
    Ag = config.groundwater_storage_m2
    return (
        A * state.basin1_head_m
        + A * state.basin2_head_m
        + Ag * state.groundwater_head_m
    )


def modes(
    config: TwoBasinSharedGroundwaterConfig,
    state: TwoBasinSharedGroundwaterState,
) -> ModeState:
    mean = 0.5 * (state.basin1_head_m + state.basin2_head_m)
    return ModeState(
        surface_difference_m=state.basin1_head_m - state.basin2_head_m,
        surface_mean_m=mean,
        surface_groundwater_contrast_m=mean - state.groundwater_head_m,
        weighted_total_storage_m3=total_storage_m3(config, state),
    )


def path_flows(
    config: TwoBasinSharedGroundwaterConfig,
    state: TwoBasinSharedGroundwaterState,
) -> PathFlows:
    return PathFlows(
        routing_1_to_2_m3_per_time=(
            config.routing_conductance_m2_per_time
            * (state.basin1_head_m - state.basin2_head_m)
        ),
        basin1_to_groundwater_m3_per_time=(
            config.exchange_conductance_m2_per_time
            * (state.basin1_head_m - state.groundwater_head_m)
        ),
        basin2_to_groundwater_m3_per_time=(
            config.exchange_conductance_m2_per_time
            * (state.basin2_head_m - state.groundwater_head_m)
        ),
    )


def storage_rates(
    config: TwoBasinSharedGroundwaterConfig,
    state: TwoBasinSharedGroundwaterState,
) -> StorageRates:
    q = path_flows(config, state)
    return StorageRates(
        basin1_m3_per_time=(
            -q.routing_1_to_2_m3_per_time
            - q.basin1_to_groundwater_m3_per_time
        ),
        basin2_m3_per_time=(
            +q.routing_1_to_2_m3_per_time
            - q.basin2_to_groundwater_m3_per_time
        ),
        groundwater_m3_per_time=(
            q.basin1_to_groundwater_m3_per_time
            + q.basin2_to_groundwater_m3_per_time
        ),
    )


def exact_state(
    config: TwoBasinSharedGroundwaterConfig,
    initial: TwoBasinSharedGroundwaterState,
    time: float,
) -> TwoBasinSharedGroundwaterState:
    t = _finite("time", time)
    if t < 0.0:
        raise ValueError("time must be non-negative")

    A = config.surface_storage_m2
    Ag = config.groundwater_storage_m2
    C = config.exchange_conductance_m2_per_time
    Kr = config.routing_conductance_m2_per_time

    initial_modes = modes(config, initial)
    total = initial_modes.weighted_total_storage_m3

    lambda_d = (2.0 * Kr + C) / A
    lambda_x = C * (1.0 / A + 2.0 / Ag)

    d = initial_modes.surface_difference_m * math.exp(-lambda_d * t)
    x = (
        initial_modes.surface_groundwater_contrast_m
        * math.exp(-lambda_x * t)
    )

    denom = 2.0 * A + Ag
    mean = (total + Ag * x) / denom
    hg = (total - 2.0 * A * x) / denom

    return TwoBasinSharedGroundwaterState(
        basin1_head_m=mean + 0.5 * d,
        basin2_head_m=mean - 0.5 * d,
        groundwater_head_m=hg,
    )


def equilibrium_head_m(
    config: TwoBasinSharedGroundwaterConfig,
    initial: TwoBasinSharedGroundwaterState,
) -> float:
    return total_storage_m3(config, initial) / (
        2.0 * config.surface_storage_m2
        + config.groundwater_storage_m2
    )
