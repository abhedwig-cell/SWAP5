"""Three-store internal-transfer ledger for RIBASIM-DUMMY-13.

This first-stage composition joins two already qualified research authorities:

- DUMMY-12: root-zone request from committed root storage;
- DUMMY-10: surface-water management complementarity with reciprocal
  surface-groundwater exchange.

No new physical flux law is introduced here.

Irrigation U is reclassified as an internal transfer:
    surface -> root

Surface-groundwater exchange V remains internal:
    surface <-> groundwater

With no external forcing in DUMMY-13:
    Delta(W_root + S_surface + S_groundwater) = 0
"""

from __future__ import annotations

from dataclasses import dataclass
import math

from dummy_rootzone_demand import (
    RootZoneConfig,
    RootZoneState,
    request_from_committed_state,
)
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
class ThreeStoreConfig:
    root: RootZoneConfig
    stores: TwoStoreConfig
    dt: float
    management_min_surface_head_m: float
    surface_datum_m: float = 0.0

    def __post_init__(self) -> None:
        dt = _finite("dt", self.dt)
        hmin = _finite(
            "management_min_surface_head_m",
            self.management_min_surface_head_m,
        )
        datum = _finite("surface_datum_m", self.surface_datum_m)
        if dt <= 0.0:
            raise ValueError("dt must be positive")
        if hmin < datum:
            raise ValueError("management minimum must not lie below datum")
        object.__setattr__(self, "dt", dt)
        object.__setattr__(self, "management_min_surface_head_m", hmin)
        object.__setattr__(self, "surface_datum_m", datum)


@dataclass(frozen=True)
class ThreeStoreState:
    root: RootZoneState
    water: TwoStoreState

    def validated(self, config: ThreeStoreConfig) -> "ThreeStoreState":
        root = self.root.validated(config.root)
        if self.water.surface_head_m < config.surface_datum_m:
            raise ValueError("surface head must not lie below datum")
        return ThreeStoreState(root=root, water=self.water)


@dataclass(frozen=True)
class ThreeStoreWindowResult:
    start: ThreeStoreState
    request_m3: float
    regime: str
    delivered_m3: float
    shortage_m3: float
    exchange_volume_m3: float
    end: ThreeStoreState
    next_request_m3: float
    root_balance_residual_m3: float
    surface_balance_residual_m3: float
    groundwater_balance_residual_m3: float
    combined_balance_residual_m3: float


@dataclass(frozen=True)
class ThreeStoreRunResult:
    initial: ThreeStoreState
    final: ThreeStoreState
    windows: tuple[ThreeStoreWindowResult, ...]
    cumulative_requested_m3: float
    cumulative_delivered_m3: float
    cumulative_shortage_m3: float
    cumulative_exchange_m3: float
    root_balance_residual_m3: float
    surface_balance_residual_m3: float
    groundwater_balance_residual_m3: float
    combined_balance_residual_m3: float


def total_three_store_water_m3(
    config: ThreeStoreConfig,
    state: ThreeStoreState,
) -> float:
    state = state.validated(config)
    return (
        state.root.storage_m3
        + total_storage_m3(config.stores, state.water)
    )


def solve_three_store_window(
    config: ThreeStoreConfig,
    state: ThreeStoreState,
) -> ThreeStoreWindowResult:
    start = state.validated(config)
    request = request_from_committed_state(config.root, start.root)

    water_problem = TwoStoreManagementProblem(
        config=config.stores,
        start=start.water,
        dt=config.dt,
        requested_m3=request,
        management_min_surface_head_m=(
            config.management_min_surface_head_m
        ),
        surface_datum_m=config.surface_datum_m,
    )
    water = water_problem.solve()

    root_end = RootZoneState(
        start.root.storage_m3 + water.delivered_m3
    ).validated(config.root)
    end = ThreeStoreState(root=root_end, water=water.end).validated(config)
    next_request = request_from_committed_state(config.root, root_end)

    root_residual = (
        root_end.storage_m3
        - start.root.storage_m3
        - water.delivered_m3
    )

    combined_residual = (
        total_three_store_water_m3(config, end)
        - total_three_store_water_m3(config, start)
    )

    return ThreeStoreWindowResult(
        start=start,
        request_m3=request,
        regime=water.regime,
        delivered_m3=water.delivered_m3,
        shortage_m3=water.shortage_m3,
        exchange_volume_m3=water.exchange_volume_m3,
        end=end,
        next_request_m3=next_request,
        root_balance_residual_m3=root_residual,
        surface_balance_residual_m3=water.surface_balance_residual_m3,
        groundwater_balance_residual_m3=water.groundwater_balance_residual_m3,
        combined_balance_residual_m3=combined_residual,
    )


def run_three_store_sequence(
    config: ThreeStoreConfig,
    *,
    initial: ThreeStoreState,
    steps: int,
) -> ThreeStoreRunResult:
    if steps <= 0:
        raise ValueError("steps must be positive")

    current = initial.validated(config)
    windows = []
    requested = delivered = shortage = exchange = 0.0

    for _ in range(steps):
        window = solve_three_store_window(config, current)
        windows.append(window)
        requested += window.request_m3
        delivered += window.delivered_m3
        shortage += window.shortage_m3
        exchange += window.exchange_volume_m3
        current = window.end

    root_residual = (
        current.root.storage_m3
        - initial.root.storage_m3
        - delivered
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
        - total_three_store_water_m3(config, initial)
    )

    return ThreeStoreRunResult(
        initial=initial,
        final=current,
        windows=tuple(windows),
        cumulative_requested_m3=requested,
        cumulative_delivered_m3=delivered,
        cumulative_shortage_m3=shortage,
        cumulative_exchange_m3=exchange,
        root_balance_residual_m3=root_residual,
        surface_balance_residual_m3=surface_residual,
        groundwater_balance_residual_m3=groundwater_residual,
        combined_balance_residual_m3=combined_residual,
    )
