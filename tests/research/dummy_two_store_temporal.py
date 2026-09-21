"""Shared-state temporal memory for RIBASIM-DUMMY-11.

Discrete route:
  propagate accepted surface and groundwater heads through DUMMY-10 windows.

Independent continuous reference:
  solve the two-store mean/difference modes analytically while management is
  active, locate the management threshold event with a bracketed scalar solve,
  then continue physical two-store exchange with management off.

No shortage backlog is carried between windows.
"""

from __future__ import annotations

from dataclasses import dataclass
import math

from dummy_two_store_exchange import (
    TwoStoreConfig,
    TwoStoreState,
    total_storage_m3,
)
from dummy_two_store_management import TwoStoreManagementProblem


def _finite(name: str, value: float) -> float:
    value = float(value)
    if not math.isfinite(value):
        raise ValueError(f"{name} must be finite")
    return value


@dataclass(frozen=True)
class TwoStoreTemporalConfig:
    stores: TwoStoreConfig
    management_min_surface_head_m: float
    request_rate_m3_per_time: float
    surface_datum_m: float = 0.0

    def __post_init__(self) -> None:
        hmin = _finite(
            "management_min_surface_head_m",
            self.management_min_surface_head_m,
        )
        rate = _finite(
            "request_rate_m3_per_time",
            self.request_rate_m3_per_time,
        )
        datum = _finite("surface_datum_m", self.surface_datum_m)
        if rate < 0.0:
            raise ValueError("request_rate_m3_per_time must be non-negative")
        if hmin < datum:
            raise ValueError("management minimum must not lie below datum")
        object.__setattr__(self, "management_min_surface_head_m", hmin)
        object.__setattr__(self, "request_rate_m3_per_time", rate)
        object.__setattr__(self, "surface_datum_m", datum)


@dataclass(frozen=True)
class TwoStoreTemporalWindow:
    index: int
    dt: float
    start: TwoStoreState
    requested_m3: float
    regime: str
    delivered_m3: float
    shortage_m3: float
    exchange_volume_m3: float
    end: TwoStoreState
    surface_balance_residual_m3: float
    groundwater_balance_residual_m3: float
    combined_balance_residual_m3: float


@dataclass(frozen=True)
class TwoStoreTemporalRun:
    initial: TwoStoreState
    final: TwoStoreState
    windows: tuple[TwoStoreTemporalWindow, ...]
    cumulative_requested_m3: float
    cumulative_delivered_m3: float
    cumulative_shortage_m3: float
    cumulative_exchange_m3: float
    surface_balance_residual_m3: float
    groundwater_balance_residual_m3: float
    combined_balance_residual_m3: float


@dataclass(frozen=True)
class ContinuousTwoStoreEventReference:
    horizon: float
    hit_time: float | None
    final: TwoStoreState
    cumulative_requested_m3: float
    cumulative_delivered_m3: float
    cumulative_shortage_m3: float
    cumulative_exchange_m3: float
    surface_balance_residual_m3: float
    groundwater_balance_residual_m3: float
    combined_balance_residual_m3: float


def run_two_store_partition(
    config: TwoStoreTemporalConfig,
    *,
    initial: TwoStoreState,
    dts: tuple[float, ...] | list[float],
) -> TwoStoreTemporalRun:
    if initial.surface_head_m < config.surface_datum_m:
        raise ValueError("initial surface head must not lie below datum")
    if not dts:
        raise ValueError("dts must contain at least one coupling window")

    current = initial
    windows = []
    cumulative_requested = 0.0
    cumulative_delivered = 0.0
    cumulative_shortage = 0.0
    cumulative_exchange = 0.0

    for index, raw_dt in enumerate(dts):
        dt = _finite("dt", raw_dt)
        if dt <= 0.0:
            raise ValueError("all coupling-window durations must be positive")

        requested = config.request_rate_m3_per_time * dt
        problem = TwoStoreManagementProblem(
            config=config.stores,
            start=current,
            dt=dt,
            requested_m3=requested,
            management_min_surface_head_m=(
                config.management_min_surface_head_m
            ),
            surface_datum_m=config.surface_datum_m,
        )
        solution = problem.solve()

        combined_residual = (
            total_storage_m3(config.stores, solution.end)
            - (
                total_storage_m3(config.stores, current)
                - solution.delivered_m3
            )
        )

        windows.append(
            TwoStoreTemporalWindow(
                index=index,
                dt=dt,
                start=current,
                requested_m3=requested,
                regime=solution.regime,
                delivered_m3=solution.delivered_m3,
                shortage_m3=solution.shortage_m3,
                exchange_volume_m3=solution.exchange_volume_m3,
                end=solution.end,
                surface_balance_residual_m3=(
                    solution.surface_balance_residual_m3
                ),
                groundwater_balance_residual_m3=(
                    solution.groundwater_balance_residual_m3
                ),
                combined_balance_residual_m3=combined_residual,
            )
        )

        cumulative_requested += requested
        cumulative_delivered += solution.delivered_m3
        cumulative_shortage += solution.shortage_m3
        cumulative_exchange += solution.exchange_volume_m3
        current = solution.end

    surface_residual = (
        config.stores.surface_storage_m2
        * (current.surface_head_m - initial.surface_head_m)
        + cumulative_delivered
        + cumulative_exchange
    )
    groundwater_residual = (
        config.stores.groundwater_storage_m2
        * (current.groundwater_head_m - initial.groundwater_head_m)
        - cumulative_exchange
    )
    combined_residual = (
        total_storage_m3(config.stores, current)
        - (
            total_storage_m3(config.stores, initial)
            - cumulative_delivered
        )
    )

    return TwoStoreTemporalRun(
        initial=initial,
        final=current,
        windows=tuple(windows),
        cumulative_requested_m3=cumulative_requested,
        cumulative_delivered_m3=cumulative_delivered,
        cumulative_shortage_m3=cumulative_shortage,
        cumulative_exchange_m3=cumulative_exchange,
        surface_balance_residual_m3=surface_residual,
        groundwater_balance_residual_m3=groundwater_residual,
        combined_balance_residual_m3=combined_residual,
    )


def _full_demand_state(
    config: TwoStoreTemporalConfig,
    initial: TwoStoreState,
    t: float,
) -> TwoStoreState:
    stores = config.stores
    C = stores.conductance_m2_per_time
    if C <= 0.0:
        raise ValueError(
            "continuous two-store event reference requires positive conductance"
        )

    t = _finite("t", t)
    if t < 0.0:
        raise ValueError("t must be non-negative")

    A_s = stores.surface_storage_m2
    A_g = stores.groundwater_storage_m2
    A_sum = A_s + A_g
    rate = config.request_rate_m3_per_time
    kappa = C * stores.inverse_storage_sum

    m0 = total_storage_m3(stores, initial) / A_sum
    mean = m0 - rate * t / A_sum

    d0 = initial.head_difference_m
    d_eq = -rate / (A_s * kappa)
    difference = d_eq + (d0 - d_eq) * math.exp(-kappa * t)

    return TwoStoreState(
        surface_head_m=mean + (A_g / A_sum) * difference,
        groundwater_head_m=mean - (A_s / A_sum) * difference,
    )


def _post_event_state(
    config: TwoStoreTemporalConfig,
    event_state: TwoStoreState,
    *,
    elapsed: float,
) -> TwoStoreState:
    elapsed = _finite("elapsed", elapsed)
    if elapsed < 0.0:
        raise ValueError("elapsed must be non-negative")

    stores = config.stores
    C = stores.conductance_m2_per_time
    if C <= 0.0:
        raise ValueError(
            "continuous two-store event reference requires positive conductance"
        )

    A_s = stores.surface_storage_m2
    A_g = stores.groundwater_storage_m2
    A_sum = A_s + A_g
    kappa = C * stores.inverse_storage_sum

    mean = total_storage_m3(stores, event_state) / A_sum
    difference = event_state.head_difference_m * math.exp(-kappa * elapsed)

    return TwoStoreState(
        surface_head_m=mean + (A_g / A_sum) * difference,
        groundwater_head_m=mean - (A_s / A_sum) * difference,
    )


def continuous_two_store_event_reference(
    config: TwoStoreTemporalConfig,
    *,
    initial: TwoStoreState,
    horizon: float,
) -> ContinuousTwoStoreEventReference:
    """Independent one-event continuous reference for constant parameters."""

    T = _finite("horizon", horizon)
    if T <= 0.0:
        raise ValueError("horizon must be positive")
    if initial.surface_head_m < config.surface_datum_m:
        raise ValueError("initial surface head must not lie below datum")
    if config.stores.conductance_m2_per_time <= 0.0:
        raise ValueError(
            "continuous two-store event reference requires positive conductance"
        )

    requested = config.request_rate_m3_per_time * T
    hmin = config.management_min_surface_head_m

    if initial.surface_head_m <= hmin:
        hit_time: float | None = 0.0
        event_state = initial
        delivered = 0.0
        final = _post_event_state(config, event_state, elapsed=T)
    else:
        full_end = _full_demand_state(config, initial, T)
        if full_end.surface_head_m >= hmin:
            hit_time = None
            delivered = requested
            final = full_end
        else:
            lo = 0.0
            hi = T
            f_lo = initial.surface_head_m - hmin
            f_hi = full_end.surface_head_m - hmin
            if not (f_lo > 0.0 and f_hi < 0.0):
                raise ValueError(
                    "continuous event root is not bracketed in the horizon"
                )

            for _ in range(160):
                mid = 0.5 * (lo + hi)
                f_mid = (
                    _full_demand_state(config, initial, mid).surface_head_m
                    - hmin
                )
                if f_mid > 0.0:
                    lo = mid
                else:
                    hi = mid

            hit_time = 0.5 * (lo + hi)
            event_state = _full_demand_state(config, initial, hit_time)
            delivered = config.request_rate_m3_per_time * hit_time
            final = _post_event_state(
                config,
                event_state,
                elapsed=T - hit_time,
            )

    tolerance = 1.0e-12 * max(
        1.0,
        abs(config.surface_datum_m),
        abs(final.surface_head_m),
    )
    if final.surface_head_m < config.surface_datum_m - tolerance:
        raise ValueError(
            "continuous reference crosses surface datum; dry-surface physics "
            "is outside DUMMY-11 scope"
        )

    exchange = (
        config.stores.groundwater_storage_m2
        * (final.groundwater_head_m - initial.groundwater_head_m)
    )
    shortage = requested - delivered

    surface_residual = (
        config.stores.surface_storage_m2
        * (final.surface_head_m - initial.surface_head_m)
        + delivered
        + exchange
    )
    groundwater_residual = (
        config.stores.groundwater_storage_m2
        * (final.groundwater_head_m - initial.groundwater_head_m)
        - exchange
    )
    combined_residual = (
        total_storage_m3(config.stores, final)
        - (
            total_storage_m3(config.stores, initial)
            - delivered
        )
    )

    return ContinuousTwoStoreEventReference(
        horizon=T,
        hit_time=hit_time,
        final=final,
        cumulative_requested_m3=requested,
        cumulative_delivered_m3=delivered,
        cumulative_shortage_m3=shortage,
        cumulative_exchange_m3=exchange,
        surface_balance_residual_m3=surface_residual,
        groundwater_balance_residual_m3=groundwater_residual,
        combined_balance_residual_m3=combined_residual,
    )
