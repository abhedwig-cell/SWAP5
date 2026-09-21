"""Management-clock event semantics for RIBASIM-DUMMY-16.

The physical partition and total managed request are identical between clock
cases. Only the sampled management priority may differ in the second window.
"""

from __future__ import annotations

from dataclasses import dataclass
import math

from dummy_competing_claims import (
    PRIORITY_EXTERNAL_FIRST,
    PRIORITY_ROOT_FIRST,
)
from dummy_rootzone_demand import RootZoneState, request_from_committed_state
from dummy_three_store_internal_ledger import (
    ThreeStoreConfig,
    ThreeStoreState,
    total_three_store_water_m3,
)
from dummy_two_store_management import TwoStoreManagementProblem


_VALID_PRIORITIES = {PRIORITY_ROOT_FIRST, PRIORITY_EXTERNAL_FIRST}


def _finite(name: str, value: float) -> float:
    value = float(value)
    if not math.isfinite(value):
        raise ValueError(f"{name} must be finite")
    return value


@dataclass(frozen=True)
class ClockWindowResult:
    start: ThreeStoreState
    priority: str
    physical_root_deficit_m3: float
    scheduled_root_claim_m3: float
    external_claim_m3: float
    total_requested_m3: float
    total_realized_m3: float
    root_delivered_m3: float
    external_delivered_m3: float
    exchange_volume_m3: float
    regime: str
    end: ThreeStoreState
    next_root_request_m3: float
    root_balance_residual_m3: float
    surface_balance_residual_m3: float
    groundwater_balance_residual_m3: float
    combined_balance_residual_m3: float


@dataclass(frozen=True)
class ManagementClockRun:
    initial: ThreeStoreState
    final: ThreeStoreState
    windows: tuple[ClockWindowResult, ...]
    cumulative_root_delivered_m3: float
    cumulative_external_delivered_m3: float
    cumulative_exchange_m3: float
    combined_balance_residual_m3: float


def _split(
    *,
    total_m3: float,
    root_request_m3: float,
    external_request_m3: float,
    priority: str,
) -> tuple[float, float]:
    if priority not in _VALID_PRIORITIES:
        raise ValueError(f"unsupported priority: {priority}")

    remaining = total_m3
    if priority == PRIORITY_ROOT_FIRST:
        root = min(root_request_m3, remaining)
        remaining -= root
        external = min(external_request_m3, remaining)
        remaining -= external
    else:
        external = min(external_request_m3, remaining)
        remaining -= external
        root = min(root_request_m3, remaining)
        remaining -= root

    tol = 1.0e-12 * max(
        1.0,
        total_m3,
        root_request_m3 + external_request_m3,
    )
    if remaining > tol:
        raise RuntimeError("priority split left unexplained realized capacity")

    return max(0.0, root), max(0.0, external)


def solve_clock_window(
    config: ThreeStoreConfig,
    state: ThreeStoreState,
    *,
    root_claim_cap_m3: float,
    external_claim_m3: float,
    priority: str,
) -> ClockWindowResult:
    start = state.validated(config)
    root_cap = _finite("root_claim_cap_m3", root_claim_cap_m3)
    external_claim = _finite("external_claim_m3", external_claim_m3)

    if root_cap < 0.0:
        raise ValueError("root_claim_cap_m3 must be non-negative")
    if external_claim < 0.0:
        raise ValueError("external_claim_m3 must be non-negative")
    if priority not in _VALID_PRIORITIES:
        raise ValueError(f"unsupported priority: {priority}")

    physical_root_deficit = request_from_committed_state(config.root, start.root)
    scheduled_root_claim = min(physical_root_deficit, root_cap)
    total_requested = scheduled_root_claim + external_claim

    physical = TwoStoreManagementProblem(
        config=config.stores,
        start=start.water,
        dt=config.dt,
        requested_m3=total_requested,
        management_min_surface_head_m=config.management_min_surface_head_m,
        surface_datum_m=config.surface_datum_m,
    ).solve()

    root_delivered, external_delivered = _split(
        total_m3=physical.delivered_m3,
        root_request_m3=scheduled_root_claim,
        external_request_m3=external_claim,
        priority=priority,
    )

    root_end = RootZoneState(
        start.root.storage_m3 + root_delivered
    ).validated(config.root)
    end = ThreeStoreState(
        root=root_end,
        water=physical.end,
    ).validated(config)

    next_root_request = request_from_committed_state(config.root, root_end)

    root_residual = (
        root_end.storage_m3
        - start.root.storage_m3
        - root_delivered
    )

    expected_total_end = (
        total_three_store_water_m3(config, start)
        - external_delivered
    )
    combined_residual = (
        total_three_store_water_m3(config, end)
        - expected_total_end
    )

    return ClockWindowResult(
        start=start,
        priority=priority,
        physical_root_deficit_m3=physical_root_deficit,
        scheduled_root_claim_m3=scheduled_root_claim,
        external_claim_m3=external_claim,
        total_requested_m3=total_requested,
        total_realized_m3=physical.delivered_m3,
        root_delivered_m3=root_delivered,
        external_delivered_m3=external_delivered,
        exchange_volume_m3=physical.exchange_volume_m3,
        regime=physical.regime,
        end=end,
        next_root_request_m3=next_root_request,
        root_balance_residual_m3=root_residual,
        surface_balance_residual_m3=physical.surface_balance_residual_m3,
        groundwater_balance_residual_m3=physical.groundwater_balance_residual_m3,
        combined_balance_residual_m3=combined_residual,
    )


def run_management_clock(
    config: ThreeStoreConfig,
    *,
    initial: ThreeStoreState,
    priorities: tuple[str, ...] | list[str],
    root_claim_cap_m3: float,
    external_claim_m3: float,
) -> ManagementClockRun:
    if not priorities:
        raise ValueError("priorities must contain at least one window")

    current = initial.validated(config)
    windows = []
    root_total = external_total = exchange_total = 0.0

    for priority in priorities:
        result = solve_clock_window(
            config,
            current,
            root_claim_cap_m3=root_claim_cap_m3,
            external_claim_m3=external_claim_m3,
            priority=priority,
        )
        windows.append(result)
        root_total += result.root_delivered_m3
        external_total += result.external_delivered_m3
        exchange_total += result.exchange_volume_m3
        current = result.end

    expected_final_total = (
        total_three_store_water_m3(config, initial)
        - external_total
    )
    combined_residual = (
        total_three_store_water_m3(config, current)
        - expected_final_total
    )

    return ManagementClockRun(
        initial=initial,
        final=current,
        windows=tuple(windows),
        cumulative_root_delivered_m3=root_total,
        cumulative_external_delivered_m3=external_total,
        cumulative_exchange_m3=exchange_total,
        combined_balance_residual_m3=combined_residual,
    )
