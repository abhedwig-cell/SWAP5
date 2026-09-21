"""Three-store external root forcing for RIBASIM-DUMMY-14.

DUMMY-14 extends the qualified DUMMY-13 internal-transfer ledger without
changing its coupled surface/groundwater solution.

Order:
1. derive root request from committed root state;
2. solve the qualified DUMMY-13 internal-transfer window for U and V;
3. apply external root rainfall P and prescribed loss E;
4. apply root capacity drainage D;
5. commit the three endpoint states together.

The combined ledger is:
    Delta(W_root + S_surface + S_groundwater) = P - E - D

Irrigation U and surface-groundwater exchange V remain internal transfers.
"""

from __future__ import annotations

from dataclasses import dataclass
import math

from dummy_rootzone_demand import RootZoneInfeasibleLossError, RootZoneState
from dummy_three_store_internal_ledger import (
    ThreeStoreConfig,
    ThreeStoreState,
    solve_three_store_window,
    total_three_store_water_m3,
)


def _finite(name: str, value: float) -> float:
    value = float(value)
    if not math.isfinite(value):
        raise ValueError(f"{name} must be finite")
    return value


@dataclass(frozen=True)
class ThreeStoreRootForcing:
    rainfall_m3: float = 0.0
    prescribed_loss_m3: float = 0.0

    def __post_init__(self) -> None:
        rain = _finite("rainfall_m3", self.rainfall_m3)
        loss = _finite("prescribed_loss_m3", self.prescribed_loss_m3)
        if rain < 0.0:
            raise ValueError("rainfall_m3 must be non-negative")
        if loss < 0.0:
            raise ValueError("prescribed_loss_m3 must be non-negative")
        object.__setattr__(self, "rainfall_m3", rain)
        object.__setattr__(self, "prescribed_loss_m3", loss)


@dataclass(frozen=True)
class ForcedThreeStoreWindowResult:
    start: ThreeStoreState
    forcing: ThreeStoreRootForcing
    request_m3: float
    regime: str
    delivered_m3: float
    shortage_m3: float
    exchange_volume_m3: float
    drainage_m3: float
    end: ThreeStoreState
    next_request_m3: float
    root_balance_residual_m3: float
    surface_balance_residual_m3: float
    groundwater_balance_residual_m3: float
    combined_balance_residual_m3: float


@dataclass(frozen=True)
class ForcedThreeStoreRunResult:
    initial: ThreeStoreState
    final: ThreeStoreState
    windows: tuple[ForcedThreeStoreWindowResult, ...]
    cumulative_requested_m3: float
    cumulative_delivered_m3: float
    cumulative_shortage_m3: float
    cumulative_exchange_m3: float
    cumulative_rainfall_m3: float
    cumulative_prescribed_loss_m3: float
    cumulative_drainage_m3: float
    root_balance_residual_m3: float
    surface_balance_residual_m3: float
    groundwater_balance_residual_m3: float
    combined_balance_residual_m3: float


def solve_forced_three_store_window(
    config: ThreeStoreConfig,
    state: ThreeStoreState,
    forcing: ThreeStoreRootForcing,
) -> ForcedThreeStoreWindowResult:
    start = state.validated(config)

    # Qualified DUMMY-13 physics and management solution. This is pure and
    # does not mutate the supplied state.
    base = solve_three_store_window(config, start)

    raw_root = (
        start.root.storage_m3
        + base.delivered_m3
        + forcing.rainfall_m3
        - forcing.prescribed_loss_m3
    )

    tolerance = 1.0e-12 * max(
        1.0,
        config.root.capacity_m3,
        abs(raw_root),
    )
    if raw_root < -tolerance:
        raise RootZoneInfeasibleLossError(
            "prescribed root-zone loss exceeds available water after accepted "
            f"irrigation and rainfall: raw_storage={raw_root:.17g}"
        )
    raw_root = max(0.0, raw_root)

    drainage = max(0.0, raw_root - config.root.capacity_m3)
    root_end = RootZoneState(raw_root - drainage).validated(config.root)

    end = ThreeStoreState(
        root=root_end,
        water=base.end.water,
    ).validated(config)

    next_request = max(
        0.0,
        config.root.target_m3 - root_end.storage_m3,
    )

    root_residual = (
        root_end.storage_m3
        - start.root.storage_m3
        - base.delivered_m3
        - forcing.rainfall_m3
        + forcing.prescribed_loss_m3
        + drainage
    )

    expected_total_end = (
        total_three_store_water_m3(config, start)
        + forcing.rainfall_m3
        - forcing.prescribed_loss_m3
        - drainage
    )
    combined_residual = (
        total_three_store_water_m3(config, end)
        - expected_total_end
    )

    return ForcedThreeStoreWindowResult(
        start=start,
        forcing=forcing,
        request_m3=base.request_m3,
        regime=base.regime,
        delivered_m3=base.delivered_m3,
        shortage_m3=base.shortage_m3,
        exchange_volume_m3=base.exchange_volume_m3,
        drainage_m3=drainage,
        end=end,
        next_request_m3=next_request,
        root_balance_residual_m3=root_residual,
        surface_balance_residual_m3=base.surface_balance_residual_m3,
        groundwater_balance_residual_m3=base.groundwater_balance_residual_m3,
        combined_balance_residual_m3=combined_residual,
    )


def run_forced_three_store_sequence(
    config: ThreeStoreConfig,
    *,
    initial: ThreeStoreState,
    forcings: tuple[ThreeStoreRootForcing, ...] | list[ThreeStoreRootForcing],
) -> ForcedThreeStoreRunResult:
    if not forcings:
        raise ValueError("forcings must contain at least one window")

    current = initial.validated(config)
    windows = []
    requested = delivered = shortage = exchange = 0.0
    rainfall = loss = drainage = 0.0

    for forcing in forcings:
        result = solve_forced_three_store_window(config, current, forcing)
        windows.append(result)
        requested += result.request_m3
        delivered += result.delivered_m3
        shortage += result.shortage_m3
        exchange += result.exchange_volume_m3
        rainfall += result.forcing.rainfall_m3
        loss += result.forcing.prescribed_loss_m3
        drainage += result.drainage_m3
        current = result.end

    root_residual = (
        current.root.storage_m3
        - initial.root.storage_m3
        - delivered
        - rainfall
        + loss
        + drainage
    )
    surface_residual = (
        config.stores.surface_storage_m2
        * (
            current.water.surface_head_m
            - initial.water.surface_head_m
        )
        + delivered
        + exchange
    )
    groundwater_residual = (
        config.stores.groundwater_storage_m2
        * (
            current.water.groundwater_head_m
            - initial.water.groundwater_head_m
        )
        - exchange
    )
    combined_residual = (
        total_three_store_water_m3(config, current)
        - (
            total_three_store_water_m3(config, initial)
            + rainfall
            - loss
            - drainage
        )
    )

    return ForcedThreeStoreRunResult(
        initial=initial,
        final=current,
        windows=tuple(windows),
        cumulative_requested_m3=requested,
        cumulative_delivered_m3=delivered,
        cumulative_shortage_m3=shortage,
        cumulative_exchange_m3=exchange,
        cumulative_rainfall_m3=rainfall,
        cumulative_prescribed_loss_m3=loss,
        cumulative_drainage_m3=drainage,
        root_balance_residual_m3=root_residual,
        surface_balance_residual_m3=surface_residual,
        groundwater_balance_residual_m3=groundwater_residual,
        combined_balance_residual_m3=combined_residual,
    )
