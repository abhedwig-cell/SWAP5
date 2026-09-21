"""Analytical root-zone demand state for RIBASIM-DUMMY-12.

This is a deliberately simple bucket oracle for demand semantics. It is not
SWAP Richards physics.

Request is computed once from committed start storage:
    R = max(0, W_target - W_start)

Realized supply U is limited by request and available supply. Rainfall, a
prescribed atmospheric/root-zone loss, and capacity drainage then determine the
accepted end storage. Shortage is diagnostic only and is not persisted.
"""

from __future__ import annotations

from dataclasses import dataclass
import math


class RootZoneInfeasibleLossError(RuntimeError):
    """Prescribed loss exceeds physically available bucket water."""


def _finite(name: str, value: float) -> float:
    value = float(value)
    if not math.isfinite(value):
        raise ValueError(f"{name} must be finite")
    return value


@dataclass(frozen=True)
class RootZoneConfig:
    capacity_m3: float
    target_m3: float

    def __post_init__(self) -> None:
        capacity = _finite("capacity_m3", self.capacity_m3)
        target = _finite("target_m3", self.target_m3)
        if capacity <= 0.0:
            raise ValueError("capacity_m3 must be positive")
        if not 0.0 <= target <= capacity:
            raise ValueError("target_m3 must satisfy 0 <= target <= capacity")
        object.__setattr__(self, "capacity_m3", capacity)
        object.__setattr__(self, "target_m3", target)


@dataclass(frozen=True)
class RootZoneState:
    storage_m3: float

    def validated(self, config: RootZoneConfig) -> "RootZoneState":
        storage = _finite("storage_m3", self.storage_m3)
        if not 0.0 <= storage <= config.capacity_m3:
            raise ValueError("storage_m3 must lie within root-zone capacity")
        return RootZoneState(storage)


@dataclass(frozen=True)
class RootZoneForcing:
    available_supply_m3: float = 0.0
    rainfall_m3: float = 0.0
    prescribed_loss_m3: float = 0.0

    def __post_init__(self) -> None:
        for name in (
            "available_supply_m3",
            "rainfall_m3",
            "prescribed_loss_m3",
        ):
            value = _finite(name, getattr(self, name))
            if value < 0.0:
                raise ValueError(f"{name} must be non-negative")
            object.__setattr__(self, name, value)


@dataclass(frozen=True)
class RootZoneWindowResult:
    start: RootZoneState
    request_m3: float
    delivered_m3: float
    shortage_m3: float
    rainfall_m3: float
    prescribed_loss_m3: float
    drainage_m3: float
    end: RootZoneState
    next_request_m3: float
    balance_residual_m3: float


@dataclass(frozen=True)
class RootZoneRunResult:
    initial: RootZoneState
    final: RootZoneState
    windows: tuple[RootZoneWindowResult, ...]
    cumulative_requested_m3: float
    cumulative_delivered_m3: float
    cumulative_shortage_m3: float
    cumulative_rainfall_m3: float
    cumulative_prescribed_loss_m3: float
    cumulative_drainage_m3: float
    cumulative_balance_residual_m3: float


def request_from_committed_state(
    config: RootZoneConfig,
    state: RootZoneState,
) -> float:
    state = state.validated(config)
    return max(0.0, config.target_m3 - state.storage_m3)


def prepare_rootzone_window(
    config: RootZoneConfig,
    state: RootZoneState,
    forcing: RootZoneForcing,
) -> RootZoneWindowResult:
    start = state.validated(config)
    request = request_from_committed_state(config, start)
    delivered = min(request, forcing.available_supply_m3)
    shortage = request - delivered

    raw = (
        start.storage_m3
        + delivered
        + forcing.rainfall_m3
        - forcing.prescribed_loss_m3
    )

    tolerance = 1.0e-12 * max(
        1.0,
        config.capacity_m3,
        abs(raw),
    )
    if raw < -tolerance:
        raise RootZoneInfeasibleLossError(
            "prescribed root-zone loss exceeds available water: "
            f"raw_storage={raw:.17g}"
        )
    raw = max(0.0, raw)

    drainage = max(0.0, raw - config.capacity_m3)
    end_storage = raw - drainage
    end = RootZoneState(end_storage).validated(config)
    next_request = request_from_committed_state(config, end)

    balance_residual = (
        end.storage_m3
        - start.storage_m3
        - delivered
        - forcing.rainfall_m3
        + forcing.prescribed_loss_m3
        + drainage
    )

    return RootZoneWindowResult(
        start=start,
        request_m3=request,
        delivered_m3=delivered,
        shortage_m3=shortage,
        rainfall_m3=forcing.rainfall_m3,
        prescribed_loss_m3=forcing.prescribed_loss_m3,
        drainage_m3=drainage,
        end=end,
        next_request_m3=next_request,
        balance_residual_m3=balance_residual,
    )


def run_rootzone_sequence(
    config: RootZoneConfig,
    *,
    initial: RootZoneState,
    forcings: tuple[RootZoneForcing, ...] | list[RootZoneForcing],
) -> RootZoneRunResult:
    if not forcings:
        raise ValueError("forcings must contain at least one window")

    current = initial.validated(config)
    windows = []
    requested = delivered = shortage = 0.0
    rainfall = loss = drainage = 0.0

    for forcing in forcings:
        result = prepare_rootzone_window(config, current, forcing)
        windows.append(result)
        requested += result.request_m3
        delivered += result.delivered_m3
        shortage += result.shortage_m3
        rainfall += result.rainfall_m3
        loss += result.prescribed_loss_m3
        drainage += result.drainage_m3
        current = result.end

    balance_residual = (
        current.storage_m3
        - initial.storage_m3
        - delivered
        - rainfall
        + loss
        + drainage
    )

    return RootZoneRunResult(
        initial=initial,
        final=current,
        windows=tuple(windows),
        cumulative_requested_m3=requested,
        cumulative_delivered_m3=delivered,
        cumulative_shortage_m3=shortage,
        cumulative_rainfall_m3=rainfall,
        cumulative_prescribed_loss_m3=loss,
        cumulative_drainage_m3=drainage,
        cumulative_balance_residual_m3=balance_residual,
    )
